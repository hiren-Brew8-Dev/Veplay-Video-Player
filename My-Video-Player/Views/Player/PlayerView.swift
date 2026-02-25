import SwiftUI
import MobileVLCKit

struct PlayerView: View {
    let video: VideoItem
    let playlist: [VideoItem]
    var onPlaybackEnded: (() -> Void)? = nil
    @StateObject private var viewModel = PlayerViewModel()
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.scenePhase) var scenePhase // Monitor app state
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @State private var resolvedTitle: String? = nil
    @State private var dismissOffset: CGFloat = 0
    @State private var isDismissGestureActive = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                videoLayer
                overlayLayer(geo: geo)
                controlsLayer(geo: geo)
            }
            .onChange(of: geo.size) { oldSize, newSize in
                viewModel.updateAspectRatio(with: newSize)
            }
            .onAppear {
                viewModel.updateAspectRatio(with: geo.size)
            }
            .simultaneousGesture(dismissGesture(geo: geo))
            .offset(y: dismissOffset)
        }
        .edgesIgnoringSafeArea(.all)
        .ignoresSafeArea(.all)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
        .onAppear {
            let initialTitle = dashboardViewModel.allGalleryVideos.first(where: { $0.id == video.id })?.title ?? video.title
            viewModel.setupPlayer(with: video, title: initialTitle, playlist: (playlist.isEmpty ? [video] : playlist))
            AppDelegate.orientationLock = .all
            resolveCurrentTitle(for: video)
            UINavigationBar.appearance().isHidden = true
        }
        .onDisappear {
            AppDelegate.orientationLock = .portrait
            if #available(iOS 16.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                }
            } else {
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                UIViewController.attemptRotationToDeviceOrientation()
            }
            if !presentationMode.wrappedValue.isPresented && !viewModel.isPiPActive {
                viewModel.cleanup()
            }
            UINavigationBar.appearance().isHidden = false
        }
        .onChange(of: viewModel.currentVideoItem) { oldVal, newVal in
            if let nextVideo = newVal {
                resolveCurrentTitle(for: nextVideo)
            }
        }
        .onChange(of: viewModel.didFinishPlayback) { oldVal, finished in
            if finished {
                onPlaybackEnded?()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .inactive || newPhase == .background {
                if dismissOffset > 0 {
                    withAnimation(.spring()) {
                        dismissOffset = 0
                    }
                }
            }
        }
        .onChange(of: viewModel.shouldDismissPlayer) { oldVal, shouldDismiss in
            if shouldDismiss {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                    presentationMode.wrappedValue.dismiss()
                    return
                }
                if windowScene.interfaceOrientation.isLandscape {
                    if #available(iOS 16.0, *) {
                        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
                            print("Rotation failed: \(error.localizedDescription)")
                        }
                    } else {
                        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                        UIViewController.attemptRotationToDeviceOrientation()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        viewModel.cleanup()
                        presentationMode.wrappedValue.dismiss()
                    }
                } else {
                    viewModel.cleanup()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .fullScreenCover(isPresented: $viewModel.showPaywall) {
            PaywallView(isFromOnboarding: false)
        }
    }
    
    // MARK: - Subviews
    
    private var videoLayer: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if viewModel.isVLC, let vlcPlayer = viewModel.vlcPlayer {
                VLCPlayerView(mediaPlayer: vlcPlayer, isPiPActive: $viewModel.isPiPActive)
                    .id(ObjectIdentifier(vlcPlayer))
                    .edgesIgnoringSafeArea(.all)
            } else if let player = viewModel.player {
                ZStack {
                    if viewModel.aspectRatio.isUnconstrained {
                        CustomVideoPlayer(
                            player: player,
                            videoGravity: viewModel.aspectRatio.gravity,
                            isPiPActive: $viewModel.isPiPActive,
                            onRestore: { viewModel.handleRestoreFromPiP() }
                        )
                        .edgesIgnoringSafeArea(.all)
                    } else {
                        CustomVideoPlayer(
                            player: player,
                            videoGravity: viewModel.aspectRatio.gravity,
                            isPiPActive: $viewModel.isPiPActive,
                            onRestore: { viewModel.handleRestoreFromPiP() }
                        )
                        .aspectRatio(viewModel.aspectRatio.ratioValue, contentMode: .fit)
                        .edgesIgnoringSafeArea(.all)
                    }
                    
                    if viewModel.isExternalPlaybackActive {
                        VStack(spacing: 20) {
                            Image(systemName: "airplayvideo")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            Text("This video is playing on AirPlay")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                        .edgesIgnoringSafeArea(.all)
                    }
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
    }
    
    private func overlayLayer(geo: GeometryProxy) -> some View {
        ZStack {
//            SubtitleOverlay(text: viewModel.subtitleManager.currentSubtitle)
//                .allowsHitTesting(false)
//            
            dismissGuideLayer(geo: geo)
            
            if viewModel.isSeekUIActive || viewModel.isLongPress2xActive {
                DoubleTapOverlay(
                    isForward: viewModel.isLongPress2xActive ? true : viewModel.isSeekForward,
                    onClose: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            viewModel.isSeekUIActive = false
                        }
                    },
                    viewModel: viewModel
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                .zIndex(2)
            }
        }
    }

    private func dismissGuideLayer(geo: GeometryProxy) -> some View {
        let screenWidth = geo.size.width
        let screenHeight = geo.size.height
        let isPortrait = screenHeight > screenWidth
        let horizontalBound = screenWidth * (isPortrait ? 0.15 : 0.20) // 30% P / 40% L
        let verticalBound = screenHeight * (isPortrait ? 0.30 : 0.20) // 60% P / 40% L
        
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                .foregroundColor(.white.opacity(0.3))
                .frame(width: horizontalBound * 2, height: verticalBound * 2)
            
            VStack(spacing: 4) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .bold))
                Text("Swipe down to close")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.4))
        }
        .opacity(0) // Logic confirmed: Area is 30% width, 60% height. Hiding visual guide for production.
        .animation(.easeInOut(duration: 0.3), value: viewModel.isControlsVisible)
        .allowsHitTesting(false)
    }
    
    private func controlsLayer(geo: GeometryProxy) -> some View {
        PlayerControlsView(
            viewModel: viewModel,
            videoTitle: viewModel.videoTitle,
            toggleControls: {
                if viewModel.activeMenu == .none && !viewModel.isSeekUIActive {
                    viewModel.isControlsVisible.toggle()
                }
            },
            onBack: {
                handleBackAction()
            },
            onSeek: { val in
                viewModel.seek(to: val)
            },
            onSmoothSeek: { val in
                viewModel.smoothSeek(to: val)
            }
        )
    }
    
    // MARK: - Gestures
    
    private func dismissGesture(geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                // 1. Initial validation only on the first frame of the gesture
                if !isDismissGestureActive {
                    // STRICT CONSTRAINTS TO AVOID CONFLICTS:
                    // We now allow dismissal even when controls are visible, as requested.
                    guard !viewModel.isAnySheetVisible else { return }
                    guard !viewModel.isLongPress2xActive else { return }
                    
                    let startY = value.startLocation.y
                    let startX = value.startLocation.x
                    let screenHeight = geo.size.height
                    let screenWidth = geo.size.width
                    let isPortrait = screenHeight > screenWidth
                    
                    // MIDDLE AREA FROM CENTER:
                    let horizontalBound = screenWidth * (isPortrait ? 0.15 : 0.25) // 30% P / 40% L
                    let verticalBound = screenHeight * (isPortrait ? 0.30 : 0.20) // 60% P / 40% L
                    let centerX = screenWidth / 2
                    let centerY = screenHeight / 2
                    
                    let isInX = startX > (centerX - horizontalBound) && startX < (centerX + horizontalBound)
                    let isInY = startY > (centerY - verticalBound) && startY < (centerY + verticalBound)
                    
                    if isInX && isInY {
                        isDismissGestureActive = true
                    } else {
                        return 
                    }
                }
                
                // 2. If valid, handle the drag
                guard isDismissGestureActive else { return }
                guard value.translation.height > -20 else { return } // Allow slight upward movement but lock it
                
                let resistance: CGFloat = 0.6
                let dampedTranslation = max(0, value.translation.height) * resistance
                
                var transaction = SwiftUI.Transaction(animation: nil)
                transaction.disablesAnimations = true

                withTransaction(transaction) {
                    dismissOffset = dampedTranslation
                }

               
            }
            .onEnded { value in
                guard isDismissGestureActive else { return }
                
                let translation = value.translation.height
                let velocity = value.velocity.height
                
                let isFastSwipe = velocity > 800
                let isLongSwipe = translation > 150
                let isMediumSwipe = translation > 80 && velocity > 400
                
                if (isFastSwipe || isLongSwipe || isMediumSwipe) && translation > 0 {
                    HapticsManager.shared.generate(.medium)
                    withAnimation(.easeOut(duration: 0.25)) {
                        dismissOffset = geo.size.height
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        viewModel.shouldDismissPlayer = true
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        dismissOffset = 0
                    }
                }
                
                // RESET STATE
                isDismissGestureActive = false
            }
    }
    
    // MARK: - Actions
    
    private func handleBackAction() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            presentationMode.wrappedValue.dismiss()
            return
        }
        
        if windowScene.interfaceOrientation.isLandscape {
            if #available(iOS 16.0, *) {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
                    print("Rotation failed: \(error.localizedDescription)")
                }
            } else {
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                UIViewController.attemptRotationToDeviceOrientation()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                viewModel.cleanup()
                presentationMode.wrappedValue.dismiss()
            }
        } else {
            viewModel.cleanup()
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func resolveCurrentTitle(for video: VideoItem) {
        if video.isGenericTitle {
            dashboardViewModel.loadTitle(for: video) { title in
                self.resolvedTitle = title
                self.viewModel.videoTitle = title
                self.viewModel.updateNowPlayingInfo()
                if let index = viewModel.playlist.firstIndex(where: { $0.id == video.id }) {
                    viewModel.playlist[index].title = title
                }
            }
        } else {
            self.viewModel.videoTitle = video.title
            self.viewModel.updateNowPlayingInfo()
        }
    }
}
