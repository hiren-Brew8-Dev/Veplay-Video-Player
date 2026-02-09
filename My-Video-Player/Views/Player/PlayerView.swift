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

    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if viewModel.isVLC, let vlcPlayer = viewModel.vlcPlayer {
                    VLCPlayerView(mediaPlayer: vlcPlayer, isPiPActive: $viewModel.isPiPActive)
                        .id(ObjectIdentifier(vlcPlayer))
                        .edgesIgnoringSafeArea(.all)
                    
                    // Subtitles Layer for VLC (custom styling)
                    SubtitleOverlay(text: viewModel.subtitleManager.currentSubtitle)
                        .allowsHitTesting(false)
                } else if let player = viewModel.player {
                if viewModel.aspectRatio.isUnconstrained {
                    CustomVideoPlayer(
                        player: player,
                        videoGravity: viewModel.aspectRatio.gravity,
                        isPiPActive: $viewModel.isPiPActive,
                        onRestore: {
                            viewModel.handleRestoreFromPiP()
                        }
                    )
                    .edgesIgnoringSafeArea(.all)
                } else {
                    CustomVideoPlayer(
                        player: player,
                        videoGravity: viewModel.aspectRatio.gravity,
                        isPiPActive: $viewModel.isPiPActive,
                        onRestore: {
                            viewModel.handleRestoreFromPiP()
                        }
                    )
                    .aspectRatio(viewModel.aspectRatio.ratioValue, contentMode: .fit)
                    .edgesIgnoringSafeArea(.all)
                }
                
                // Subtitles Layer
                SubtitleOverlay(text: viewModel.subtitleManager.currentSubtitle)
                    .allowsHitTesting(false) // Let touches pass through to controls
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            
            // Seek Indicator Overlay (Display above player, below controls)
            if viewModel.isSeekUIActive {
                DoubleTapOverlay(
                    isForward: viewModel.isSeekForward,
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
            
            // New Full Screen Controls Overlay
            PlayerControlsView(
                viewModel: viewModel,
                videoTitle: viewModel.videoTitle,
                toggleControls: {
                    if viewModel.activeMenu == .none {
                        viewModel.isControlsVisible.toggle()
                    }
                },
                onBack: {
                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                        presentationMode.wrappedValue.dismiss()
                        return
                    }
                    
                    if windowScene.interfaceOrientation.isLandscape {
                        // Request portrait orientation
                        if #available(iOS 16.0, *) {
                            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
                                // Even if it fails, we should try to dismiss
                                print("Rotation failed: \(error.localizedDescription)")
                            }
                        } else {
                            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                            UIViewController.attemptRotationToDeviceOrientation()
                        }
                        
                        // Small delay to allow the orientation change to start/complete visually
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            viewModel.cleanup() // Complete cleanup on back button
                            presentationMode.wrappedValue.dismiss()
                        }
                    } else {
                        viewModel.cleanup() // Complete cleanup on back button
                        presentationMode.wrappedValue.dismiss()
                    }
                },
                onSeek: { val in
                    viewModel.seek(to: val)
                },
                onSmoothSeek: { val in
                    viewModel.smoothSeek(to: val)
                }
                )
            }
            .onChange(of: geo.size) { oldSize, newSize in
                viewModel.updateAspectRatio(with: newSize)
            }
            .onAppear {
                viewModel.updateAspectRatio(with: geo.size)
            }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        // 1. Avoid top edge (Notification Center conflict)
                        // Ignore swipes starting in the top 50pt
                        guard value.startLocation.y > 50 else { return }
                        
                        // Only allow swipe down (positive translation)
                        if value.translation.height > 0 {
                            var transaction = Transaction(animation: nil) // Disable implicit animations
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                dismissOffset = value.translation.height
                            }
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            // Dismiss threshold reached
                            withAnimation(.easeOut(duration: 0.2)) {
                               viewModel.shouldDismissPlayer = true
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dismissOffset = 0
                            }
                        }
                    }
            )
            .offset(y: dismissOffset)
        }
        .edgesIgnoringSafeArea(.all)
        .ignoresSafeArea(.all)
        // Optimization: Removed opacity change during drag as it can be heavy with video
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
        .onAppear {
            let initialTitle = dashboardViewModel.allGalleryVideos.first(where: { $0.id == video.id })?.title ?? video.title
            viewModel.setupPlayer(with: video, title: initialTitle, playlist: (playlist.isEmpty ? [video] : playlist))
            
            // Allow rotation in player
            AppDelegate.orientationLock = .all
            
            // Resolve title if it's still generic
            resolveCurrentTitle(for: video)

            // Ensure navigation bar stays hidden
            UINavigationBar.appearance().isHidden = true
        }
        .onDisappear {
            // Lock back to portrait
            AppDelegate.orientationLock = .portrait
            
            if #available(iOS 16.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                }
            } else {
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                UIViewController.attemptRotationToDeviceOrientation()
            }
            
            
            // Only cleanup if we are truly dismissing the view AND PiP is not active.
            // If the app is just backgrounding, we want audio to continue.
            if !presentationMode.wrappedValue.isPresented && !viewModel.isPiPActive {
                viewModel.cleanup()
            }
            
            // Restore navigation bar
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
                // Force reset if interrupted by Notification Center or Home Swipe
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
                    // Request portrait orientation
                    if #available(iOS 16.0, *) {
                        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
                            print("Rotation failed: \(error.localizedDescription)")
                        }
                    } else {
                        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                        UIViewController.attemptRotationToDeviceOrientation()
                    }
                    
                    // Small delay to allow the orientation change to start/complete visually
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
    }
    
    private func resolveCurrentTitle(for video: VideoItem) {
        if video.isGenericTitle {
            dashboardViewModel.loadTitle(for: video) { title in
                self.resolvedTitle = title
                self.viewModel.videoTitle = title
                self.viewModel.updateNowPlayingInfo()
                
                // Also update in playlist to sync queue UI
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
