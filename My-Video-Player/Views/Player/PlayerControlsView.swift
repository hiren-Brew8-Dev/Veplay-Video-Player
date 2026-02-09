import SwiftUI
import AVKit
import Photos
import AVFoundation
import UniformTypeIdentifiers
import MobileVLCKit

struct PlayerControlsView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @StateObject private var volumeManager = SystemVolumeManager()
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    let videoTitle: String
    let toggleControls: () -> Void
    let onBack: () -> Void
    let onSeek: (Double) -> Void
    let onSmoothSeek: (Double) -> Void
    
    // Auto-hide
    @State private var hideTimer: Timer?
    @State private var showSubtitleSettings = false
    @State private var showSleepTimer = false
    
    // Casting State
    @State private var showCastingSheet = false
    @State private var selectedCastingMode: CastingModeSheet.CastingMode?
    @State private var showAirPlayPicker = false
    
    // Settings Sheet State
    @State private var showSettingsSheet = false
    
    // Track Selection State
    @State private var showTrackSelection = false
    @State private var showPlayingModeSheet = false
    @State private var showPlaybackSpeedSheet = false
    @State private var showAudioCaptionsSheet = false
    @State private var isSystemMenuActive = false
    @State private var systemMenuDeactivateWorkItem: DispatchWorkItem?
    
    @Namespace private var lockNamespace
    @State private var lockPillPosition: CGPoint = .zero
    
    // Navigation State
    @State private var returnToSettings = false
    @State private var showBookmarkButton: Bool = false
    @State private var showFloatingBookmarkControls = true
    
    // Sharing State
    @State private var shareInfo: ShareInfo?
    
    // Gesture Feedback State
    @State private var showDoubleTapFeedback: Bool? = nil // true = forward, false = backward, nil = hidden
    
    private var activeSheetType: String {
        if showSettingsSheet { return "settings" }
        if showSubtitleSettings { return "subtitles" }
        if showTrackSelection { return "tracks" }
        if showCastingSheet { return "casting" }
        if showSleepTimer { return "sleep" }
        if showPlayingModeSheet { return "mode" }
        if showPlaybackSpeedSheet { return "speed" }
        if showAudioCaptionsSheet { return "audiocaptions" }
        return "none"
    }
    
    private func beginSystemMenuInteraction(timeout: TimeInterval = 8.0) {
        systemMenuDeactivateWorkItem?.cancel()
        isSystemMenuActive = true
        
        // Keep controls visible + stop auto-hide while the system menu is up.
        hideTimer?.invalidate()
        hideTimer = nil
        viewModel.isControlsVisible = true
        
        let workItem = DispatchWorkItem {
            isSystemMenuActive = false
            resetTimer()
        }
        systemMenuDeactivateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
    }
    
    private func endSystemMenuInteraction() {
        systemMenuDeactivateWorkItem?.cancel()
        systemMenuDeactivateWorkItem = nil
        isSystemMenuActive = false
    }
    
    private func handleLockToggle() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            viewModel.isLocked.toggle()
            if viewModel.isLocked {
                viewModel.isControlsVisible = false
            } else {
                viewModel.isControlsVisible = true
                resetTimer()
            }
        }
    }
    
    var body: some View {
        ZStack {
            gestureOverlay
                .allowsHitTesting(!isSystemMenuActive)
                .zIndex(1)
            
            controlsOverlay // Indice 3, fades out when isLocked
                .zIndex(3)
            
            lockCornerAnchor // Invisible target in the corner
                .zIndex(0)
            
            lockOverlay // Tap catcher
                .zIndex(100)
            
            persistentLockIcon // The ONLY lock icon instance - HIGHEST Z
                .zIndex(101)
            
            settingsOverlay
                .zIndex(200)
            
            sliderOverlay
                .zIndex(10)
        }
        .sheet(isPresented: $showAirPlayPicker) {
            airPlayPickerSheet
        }
        .sheet(item: $shareInfo) { info in
            ActivityViewController(activityItems: info.items)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: selectedCastingMode) { oldVal, mode in
            if let mode = mode {
                switch mode {
                case .airplayBluetooth:
                    showAirPlayPicker = true
                case .castingDevice:
                    print("Casting device selected - to be implemented")
                }
                selectedCastingMode = nil
            }
        }
        .onAppear {
            resetTimer()
        }
        .onChange(of: volumeManager.showVolumeUI) { oldVal, show in
            if show {
                viewModel.hideBrightnessUI()
                viewModel.isControlsVisible = false
            }
        }
        .onChange(of: viewModel.showBrightnessUI) { oldVal, show in
            if show {
                volumeManager.hideVolumeUI()
                viewModel.isControlsVisible = false
            }
        }
        .onChange(of: viewModel.isControlsVisible) { oldVal, visible in
            viewModel.hideBrightnessUI()
            volumeManager.hideVolumeUI()
            
            if visible {
                resetTimer()
            }
        }
        .onChange(of: viewModel.isSleepTimerActive) { oldVal, active in
            if active {
                withAnimation { showSleepTimerToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { showSleepTimerToast = false }
                }
            }
        }
        .alert("Picture in Picture", isPresented: $viewModel.showPiPError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Picture in Picture is not currently supported for this video format.")
        }
        .onChange(of: viewModel.bookmarks) { _ in
            // If bookmarks exist on load, enable the feature so indicator shows
            if !viewModel.bookmarks.isEmpty {
                showBookmarkButton = true
            }
            // If all bookmarks removed (and feature was on), disable it (auto-hide logic)
            // But wait, user said "if any video has not" - so this is correct.
            else if viewModel.bookmarks.isEmpty && showBookmarkButton {
                showBookmarkButton = false
            }
        }
    }
    
    // MARK: - Subviews
    
    private var gestureOverlay: some View {
        PlayerGestureOverlay(
            viewModel: viewModel,
            volumeManager: volumeManager,
            toggleControls: toggleControls,
            onShowTapFeedback: { isForward in
                showDoubleTapFeedback = isForward
                resetTimer()
            }
        )
    }
    
    @ViewBuilder
    private var controlsOverlay: some View {
        if viewModel.isControlsVisible && !viewModel.isLocked {
            ZStack {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .allowsHitTesting(false)
                
                ZStack {
                    VStack {
                    PlayerTopBar(
                        title: videoTitle,
                        onBack: onBack,
                        viewModel: viewModel,
                        lockNamespace: lockNamespace,
                        onMenu: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showSettingsSheet = true
                                viewModel.isControlsVisible = false
                            }
                        },
                        onTimer: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                returnToSettings = false
                                showSleepTimer = true
                                viewModel.isControlsVisible = false
                            }
                        },
                        onCast: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showCastingSheet = true
                                viewModel.isControlsVisible = false
                            }
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                    
                    VStack(spacing: 0) {
                        PlayerBottomBar(
                            currentTime: Binding(
                                get: { viewModel.currentTime },
                                set: { newTime in
                                    viewModel.seek(to: newTime)
                                }
                            ),
                            duration: viewModel.duration,
                            isPlaying: viewModel.isPlaying,
                            bookmarks: viewModel.bookmarks,
                            currentAspectRatio: viewModel.aspectRatio,
                            onPlayPause: {
                                viewModel.togglePlayPause()
                                resetTimer()
                            },
                            onSkipBackward: {
                                viewModel.seek(to: viewModel.currentTime - 10)
                                resetTimer()
                            },
                            onSkipForward: {
                                viewModel.seek(to: viewModel.currentTime + 10)
                                resetTimer()
                            },
                            onSeek: { val in
                                self.onSeek(val)
                                resetTimer()
                            },
                            onSmoothSeek: { val in
                                self.onSmoothSeek(val)
                                resetTimer()
                            },
                            playbackSpeed: viewModel.playbackSpeed,
                            onSpeedChange: { speed in
                                viewModel.setSpeed(speed)
                                endSystemMenuInteraction()
                                resetTimer()
                            },
                            onPIP: {
                                viewModel.togglePiP()
                                resetTimer()
                            },
                            onAspectRatio: { ratio in
                                viewModel.updateAspectRatio(to: ratio)
                                endSystemMenuInteraction()
                                resetTimer()
                            },
                            onLock: {
                                handleLockToggle()
                            },
                            onAudioCaptions: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    returnToSettings = false
                                    showAudioCaptionsSheet = true
                                    viewModel.isControlsVisible = false
                                }
                            },
                            onMenu: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showSettingsSheet = true
                                    viewModel.isControlsVisible = false
                                }
                            },
                            showBookmarkControls: showBookmarkButton && showFloatingBookmarkControls,
                            onSeekToPrevBookmark: {
                                viewModel.seekToPreviousBookmark()
                                resetTimer()
                            },
                            onSeekToNextBookmark: {
                                viewModel.seekToNextBookmark()
                                resetTimer()
                            },
                            onToggleBookmark: {
                                viewModel.toggleBookmark()
                                resetTimer()
                            },
                            hasPrevBookmark: viewModel.hasPreviousBookmark,
                            hasNextBookmark: viewModel.hasNextBookmark,
                            isAtBookmark: viewModel.isAtBookmark,
                            isSubtitleEnabled: viewModel.subtitleManager.isEnabled,
                            onRotate: {
                                // Simple rotation trigger
                                let keyWindow = UIApplication.shared.connectedScenes
                                    .filter({$0.activationState == .foregroundActive})
                                    .compactMap({$0 as? UIWindowScene})
                                    .first?.windows
                                    .filter({$0.isKeyWindow}).first
                                
                                if let windowScene = keyWindow?.windowScene {
                                    let geometryRequest = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: isLandscape ? .portrait : .landscapeRight)
                                    windowScene.requestGeometryUpdate(geometryRequest)
                                }
                                resetTimer()
                            },
                            activeMenu: Binding(
                                get: { viewModel.activeMenu },
                                set: { viewModel.activeMenu = $0 }
                            ),
                            onMenuOpened: {
                                beginSystemMenuInteraction(timeout: 3600) // Effectively infinite, as requested
                            },
                            onDismissMenu: {
                                viewModel.activeMenu = .none
                                endSystemMenuInteraction()
                                resetTimer()
                            }
                        )
                    }
                    }
                    
                    centerControls
                }
            }
        }
    }
    
    private var centerControls: some View {
        HStack(spacing: isLandscape ? 50 : 30) {
            // Skip Backward 10s
            Button(action: {
                viewModel.performDoubleTapSeek(forward: false)
                showDoubleTapFeedback = false
                resetTimer()
            }) {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundColor(.white)
                    .frame(width: 54, height: 54)
                    .contentShape(Rectangle())
            }
            
            // Play/Pause
            Button(action: {
                viewModel.togglePlayPause()
                resetTimer()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 74, height: 74)
                    
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.black)
                }
            }
            
            // Skip Forward 10s
            Button(action: {
                viewModel.performDoubleTapSeek(forward: true)
                showDoubleTapFeedback = true
                resetTimer()
            }) {
                Image(systemName: "goforward.10")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundColor(.white)
                    .frame(width: 54, height: 54)
                    .contentShape(Rectangle())
            }
        }
    }
    
    
    @ViewBuilder
    private var lockOverlay: some View {
        if viewModel.isLocked {
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isControlsVisible.toggle()
                    }
                    if viewModel.isControlsVisible {
                        resetTimer()
                    }
                }
                .highPriorityGesture(DragGesture().onChanged { _ in })
                .highPriorityGesture(MagnificationGesture().onChanged { _ in })
                .highPriorityGesture(TapGesture(count: 2).onEnded { }) 
                .ignoresSafeArea()
        }
    }
    
    @ViewBuilder
    private var persistentLockIcon: some View {
        Button(action: handleLockToggle) {
            Image(systemName: "lock.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .padding(12) // Ensure good tap area
        }
        .matchedGeometryEffect(id: "lockIcon", in: lockNamespace, isSource: false)
        .opacity(viewModel.isControlsVisible ? 1.0 : 0.0)
    }
    
    @ViewBuilder
    private var lockCornerAnchor: some View {
        VStack {
            HStack {
                Spacer()
                // Mirror the TopBar placeholder position when locked
                Color.clear
                    .frame(width: 35, height: 44)
                    .padding(.trailing, isLandscape ? 50 : 8)
                    .padding(.top, isLandscape ? 20 : 40)
                    .matchedGeometryEffect(id: "lockIcon", in: lockNamespace, isSource: viewModel.isLocked)
            }
            Spacer()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    @ViewBuilder
    private var settingsOverlay: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let anySheetVisible = showSettingsSheet || showSubtitleSettings || showTrackSelection || showCastingSheet || showSleepTimer || showPlayingModeSheet || showPlaybackSpeedSheet || showAudioCaptionsSheet
            
            ZStack {
                // Background Scrim
                if anySheetVisible {
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                closeAllSheets()
                            }
                        }
                        .transition(.opacity)
                }
                
                // Sheet Content
                if anySheetVisible {
                    Group {
                        if isLandscape {
                            // Landscape: right-to-left transition, full height
                            HStack(spacing: 0) {
                                Spacer()
                                sheetContent(isLandscape: true)
                                    .frame(width: 400)
                                    .frame(maxHeight: .infinity)
                                    .background(Color.clear)
                            }
                            .transition(.move(edge: .trailing))
                        } else {
                            // Portrait: bottom-to-top transition
                            VStack(spacing: 0) {
                                Spacer()
                                sheetContent(isLandscape: false)
                                    .frame(maxWidth: .infinity)
                                    .if(showSettingsSheet) { $0.frame(height: geometry.size.height * 0.5) }
                                    .background(Color.clear)
                            }
                            .transition(.move(edge: .bottom))
                        }
                    }
                    .id(activeSheetType)
                    .zIndex(1)
                }
            }
        }
        .overlay(snapshotToastOverlay)
        .overlay(sleepTimerToastOverlay) // Add Sleep Timer Toast
        .allowsHitTesting(showSettingsSheet || showSubtitleSettings || showTrackSelection || showCastingSheet || showSleepTimer || showPlayingModeSheet || showPlaybackSpeedSheet || showAudioCaptionsSheet)
    }

    private func closeAllSheets() {
        showSettingsSheet = false
        showSubtitleSettings = false
        showTrackSelection = false
        showCastingSheet = false
        showSleepTimer = false
        showPlayingModeSheet = false
        showPlaybackSpeedSheet = false
        showAudioCaptionsSheet = false
    }

    @ViewBuilder
    private func sheetContent(isLandscape: Bool) -> some View {
        if showSettingsSheet {
            SettingsSheetView(
                viewModel: viewModel,
                isPresented: $showSettingsSheet,
                isLandscape: isLandscape,
                onAudioTrack: { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        returnToSettings = true
                        showSettingsSheet = false
                        showTrackSelection = true 
                    }
                },
                onAirPlay: { showCastingSheet = true },
                onSubtitle: { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        returnToSettings = true
                        showSettingsSheet = false
                        showSubtitleSettings = true 
                    }
                },
                onSleepTimer: { 
                     withAnimation(.easeInOut(duration: 0.3)) {
                         returnToSettings = true
                         showSettingsSheet = false
                         showSleepTimer = true
                     }
                },
                onScreenshot: { 
                    viewModel.captureSnapshot { image in
                        if let image = image {
                            viewModel.saveImageToPhotos(image)
                            showSettingsSheet = false
                        }
                    }
                },
                onShare: { 
                    viewModel.prepareVideoForSharing { url in
                        guard let url = url else { return }
                        DispatchQueue.main.async {
                            shareInfo = ShareInfo(items: [url])
                        }
                    }
                },
                onPlayingMode: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        returnToSettings = true
                        showSettingsSheet = false
                        showPlayingModeSheet = true
                    }
                },
                onPlaybackSpeed: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        returnToSettings = true
                        showSettingsSheet = false
                        showPlaybackSpeedSheet = true
                    }
                }
            )
        } else if showSubtitleSettings {
            SubtitleSettingsView(
                subtitleManager: viewModel.subtitleManager,
                isPresented: $showSubtitleSettings,
                isLandscape: isLandscape,
                onBack: returnToSettings ? {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSubtitleSettings = false
                        showSettingsSheet = true
                    }
                } : nil
            )
        } else if showTrackSelection {
            AudioTrackSettingsView(
                viewModel: viewModel,
                isPresented: $showTrackSelection,
                isLandscape: isLandscape,
                onBack: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showTrackSelection = false
                        if returnToSettings {
                            showSettingsSheet = true
                        }
                    }
                }
            )
        } else if showCastingSheet {
            CastingModeSheet(
                viewModel: viewModel,
                isPresented: $showCastingSheet,
                selectedMode: $selectedCastingMode,
                isLandscape: isLandscape
            )
//            .if(!isLandscape) { $0.frame(height: 450) }
        } else if showSleepTimer {
            SleepTimerView(
                viewModel: viewModel,
                isPresented: $showSleepTimer,
                isLandscape: isLandscape,
                onBack: returnToSettings ? {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSleepTimer = false
                        showSettingsSheet = true
                    }
                
                } : nil
            )
            .if(!isLandscape) { $0.frame(height: 450) }
        } else if showPlayingModeSheet {
            PlayingModeSheet(
                viewModel: viewModel,
                isPresented: $showPlayingModeSheet,
                isLandscape: isLandscape,
                onBack: returnToSettings ? {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showPlayingModeSheet = false
                        showSettingsSheet = true
                    }
                } : nil
            )
            .if(!isLandscape) { $0.frame(height: 400) }
        } else if showPlaybackSpeedSheet {
            PlaybackSpeedSheet(
                viewModel: viewModel,
                isPresented: $showPlaybackSpeedSheet,
                isLandscape: isLandscape,
                onBack: returnToSettings ? {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showPlaybackSpeedSheet = false
                        showSettingsSheet = true
                    }
                } : nil
            )
            .if(!isLandscape) { $0.frame(height: 450) }
        } else if showAudioCaptionsSheet {
            AudioCaptionsSheet(
                viewModel: viewModel,
                isPresented: $showAudioCaptionsSheet,
                isLandscape: isLandscape,
                onBack: returnToSettings ? {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAudioCaptionsSheet = false
                        showSettingsSheet = true
                    }
                } : nil
            )
            .if(!isLandscape) { $0.frame(height: 500) }
        }
    }

    private var sleepTimerIconOverlay: some View {
        Group {
            if viewModel.isSleepTimerActive {
                VStack {
                    HStack {
                         Image(systemName: "timer")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .padding(.top, 50)
                            .padding(.leading, 16)
                         Spacer()
                    }
                    Spacer()
                }
            }
        }
    }
    
    private var sleepTimerToastOverlay: some View {
        Group {
            if let message = viewModel.sleepTimerRemainingString, viewModel.isSleepTimerActive, showSleepTimerToast {
                 VStack {
                     HStack {
                         Spacer()
                         Text("Sleep Timer - \(message)")
                             .font(.system(size: 14, weight: .medium))
                             .foregroundColor(.white)
                             .padding(.vertical, 12)
                             .padding(.horizontal, 24)
                             .background(Color.orange)
                             .cornerRadius(20)
                         Spacer()
                     }
                     .padding(.top, 100)
                     .transition(.move(edge: .top).combined(with: .opacity))
                     Spacer()
                 }
                 .zIndex(250)
            }
        }
    }
    
    @State private var showSleepTimerToast = false

    private var snapshotToastOverlay: some View {
        Group {
            if viewModel.showSnapshotSavedToast {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Snapshot Saved to Photos")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(10)
                    .padding(.bottom, 50)
                }
                .transition(.opacity)
            }
        }
    }

    private var sliderOverlay: some View {
        HStack {
            if viewModel.showBrightnessUI {
                VerticalSliderView(value: viewModel.currentBrightness, iconName: "sun.max.fill")
                    .transition(.opacity)
                    .padding(.leading, 20)
            }
            
            Spacer()
            
            if volumeManager.showVolumeUI {
                VerticalSliderView(value: volumeManager.currentVolume, iconName: "speaker.wave.3.fill")
                    .transition(.opacity)
                    .padding(.trailing, 20)
            }
        }
        .padding(.vertical, 40)
        .safeAreaPadding(.horizontal)
        .allowsHitTesting(false)
    }
    
    private var airPlayPickerSheet: some View {
        VStack {
            Text("Select a device")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
            
            AirPlayPickerWrapper(tintColor: .white)
                .frame(width: 300, height: 60)
            
            Button("Close") {
                showAirPlayPicker = false
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)))
        .presentationDetents([.medium])
    }
    
    private func resetTimer() {
        hideTimer?.invalidate()
        let anySheetVisible = showSettingsSheet || showSubtitleSettings || showTrackSelection || showCastingSheet
        if !anySheetVisible && !isSystemMenuActive && viewModel.activeMenu == .none {
             viewModel.isControlsVisible = true
             
             hideTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
                 viewModel.isControlsVisible = false
             }
        }
    }
    
    private func playbackButton(icon: String, size: CGFloat, frameSize: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                .fill(Color.black.opacity(0.4))
                .frame(width: frameSize, height: frameSize)
                Image(systemName: icon)
                    .font(.system(size: size))
                    .foregroundColor(.white)
                    .animation(nil, value: icon)
            }
        }
    }
}


struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // UIActivityViewController doesn't support dynamic updates to items once presented.
        // It relies on presentation with correct items.
    }
}

struct ShareInfo: Identifiable {
    let id = UUID()
    let items: [Any]
}

// MARK: - SettingsSheetView

struct SettingsSheetView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Binding var isPresented: Bool
    let isLandscape: Bool
    
    // Callbacks for actions
    var onAudioTrack: () -> Void
    var onAirPlay: () -> Void
    var onSubtitle: () -> Void
    var onSleepTimer: () -> Void
    var onScreenshot: () -> Void
    var onShare: () -> Void
    let onPlayingMode: () -> Void
    let onPlaybackSpeed: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if !isLandscape {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
            }
            
            settingsHeader
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            if isLandscape {
                landscapeBody
            } else {
                portraitBody
            }
        }
        .padding(.trailing, isLandscape ? 30 : 0)
        .background(Color(UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)))
        .if(isLandscape) { view in
            view.cornerRadiusLocal(20, corners: [.topLeft, .bottomLeft])
        }
        .if(!isLandscape) { view in
            view.cornerRadiusLocal(20, corners: [.topLeft, .topRight])
        }
        .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: isLandscape ? 0 : -5)
    }
    
    private var settingsHeader: some View {
        HStack {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isPresented = false
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
            }
            
            Spacer()
            
            Text("Settings")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.clear)
                .padding(10)
        }
        .padding(.horizontal)
    }
    
    private var settingsControls: some View {
        VStack(spacing: 20) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                SettingsGridItem(icon: "timer", title: "Sleep Timer", isActive: viewModel.isSleepTimerActive, action: onSleepTimer)
                SettingsGridItem(icon: "camera", title: "Screenshot", action: onScreenshot)
                SettingsGridItem(icon: "square.and.arrow.up", title: "Share", action: onShare)
                AirPlayGridItem(viewModel: viewModel, onDismiss: { isPresented = false })
            }
            
        }
    }
    
    private var portraitBody: some View {
        VStack(spacing: 0) {
            settingsControls
                .padding(16)
            
            Divider().background(Color.gray.opacity(0.3))
            
            queueList
        }
        .padding(.bottom, 20)
    }
    
    private var landscapeBody: some View {
        VStack(spacing: 0) {
            settingsControls
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            queueList
        }
    }
    
    private var queueList: some View {
        VStack(alignment: .leading, spacing: 3) { // 3px spacing between header and list
            HStack {
                Text("Queue")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onPlayingMode) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.playingMode.iconName)
                            .font(.system(size: 14))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(viewModel.playlist.enumerated()), id: \.element.id) { index, video in
                        VideoQueueRow(
                            video: video,
                            isCurrent: index == viewModel.currentIndex,
                            onTap: {
                                viewModel.selectFromQueue(at: index, forceAutoPlay: true)
                            }
                        )
                        .id(video.id)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                    }
                    .onMove(perform: move)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
                .onAppear {
                    if let currentVideoId = viewModel.currentVideoItem?.id {
                        proxy.scrollTo(currentVideoId, anchor: .center)
                    }
                }
            }
        }
    }
    
    private func move(from source: IndexSet, to destination: Int) {
        viewModel.playlist.move(fromOffsets: source, toOffset: destination)
        if let currentVideoId = viewModel.currentVideoItem?.id {
            if let newIndex = viewModel.playlist.firstIndex(where: { $0.id == currentVideoId }) {
                viewModel.currentIndex = newIndex
            }
        }
    }
}

struct SettingsGridItem: View {
    let icon: String
    let title: String
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: isActive ? .bold : .regular))
                    .foregroundColor(isActive ? .orange : .white)
                
                Text(title)
                    .font(.system(size: 11, weight: isActive ? .medium : .regular))
                    .foregroundColor(isActive ? .orange : .gray)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct SettingsListItem: View {
    let icon: String
    let title: String
    let value: String
    var rightIcon: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
              
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if let rIcon = rightIcon {
                        Image(systemName: rIcon)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    
                    if icon != "infinity" {
                        Text(value)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 6) // Reduced from 16
        }
    }
}

struct AirPlayGridItem: View {
    @ObservedObject var viewModel: PlayerViewModel
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                Image(systemName: "airplayaudio")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                
                Text("AirPlay")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            
            SettingsAirPlayPicker()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(0.02)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onDismiss()
                        }
                    }
                )
        }
    }
}

struct SettingsAirPlayPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.activeTintColor = .white
        picker.tintColor = .clear
        picker.prioritizesVideoDevices = true
        return picker
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

// MARK: - PlayingQueueView

// MARK: - VideoQueueRow

// MARK: - VideoQueueRow struct below

// Helper Extension for Array move
extension Array {
    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let itemsToMove = source.map { self[$0] }
        for (index, oldIndex) in source.enumerated() {
            self.remove(at: oldIndex - index)
        }
        let targetIndex = destination > self.count ? self.count : (destination < 0 ? 0 : destination)
        self.insert(contentsOf: itemsToMove, at: targetIndex)
    }
}

struct VideoQueueRow: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    let video: VideoItem
    let isCurrent: Bool
    let onTap: () -> Void
    @State private var resolvedTitle: String? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack {
                if let asset = video.asset {
                    PHThumbnailView(asset: asset)
                        .frame(width: 80, height: 48)
                        .cornerRadius(6)
                } else if let path = video.thumbnailPath, let thumb = UIImage(contentsOfFile: path.path) {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 48)
                        .cornerRadius(6)
                        .clipped()
                } else if let url = video.url {
                    VideoThumbnailView(url: url)
                        .frame(width: 80, height: 48)
                        .cornerRadius(6)
                } else {
                    Color(red: 0.15, green: 0.15, blue: 0.15)
                        .frame(width: 80, height: 48)
                        .cornerRadius(6)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(resolvedTitle ?? video.title)
                    .font(.system(size: 14, weight: isCurrent ? .bold : .medium))
                    .foregroundColor(isCurrent ? Color(red: 1.0, green: 0.5, blue: 0.0) : .white)
                    .lineLimit(1)
                
                Text(video.formattedDuration)
                    .font(.system(size: 11))
                    .foregroundColor(isCurrent ? Color(red: 1.0, green: 0.5, blue: 0.0).opacity(0.8) : .gray)
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .onTapGesture(perform: onTap)
        .onAppear {
            if video.isGenericTitle {
                dashboardViewModel.loadTitle(for: video) { title in
                    self.resolvedTitle = title
                }
            }
        }
    }
}

struct PHThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 48)
                    .clipped()
            } else {
                Color(red: 0.15, green: 0.15, blue: 0.15)
            }
        }
        .onAppear {
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            
            manager.requestImage(for: asset, targetSize: CGSize(width: 160, height: 96), contentMode: .aspectFill, options: options) { img, _ in
                self.image = img
            }
        }
    }
}

struct VideoThumbnailView: View {
    let url: URL
    @State private var image: UIImage?
    @State private var vlcLoader: VLCThumbnailHelper?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.gray.opacity(0.3)
                    .overlay(
                        Image(systemName: "play.fill")
                            .foregroundColor(.white.opacity(0.3))
                            .font(.system(size: 14))
                    )
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }

    private func generateThumbnail() {
        let ext = url.pathExtension.lowercased()
        let vlcExtensions = ["mkv", "avi", "wmv", "flv", "webm", "3gp", "vob", "mpg", "mpeg", "ts", "m2ts", "divx", "asf"]
        
        if vlcExtensions.contains(ext) {
            let loader = VLCThumbnailHelper()
            self.vlcLoader = loader
            loader.generate(for: url) { image in
                self.image = image
                self.vlcLoader = nil
            }
            return
        }

        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, _, _ in
            if let image = image {
                DispatchQueue.main.async {
                    self.image = UIImage(cgImage: image)
                }
            }
        }
    }
}

// Extension to View and RoundedCornerLocal remains at the bottom
extension View {
    func cornerRadiusLocal(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCornerLocal(radius: radius, corners: corners) )
    }
    
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct RoundedCornerLocal: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - SleepTimerView
// MARK: - SleepTimerView
struct SleepTimerView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Binding var isPresented: Bool
    let isLandscape: Bool
    var onBack: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle (Only visible in portrait)
            if !isLandscape {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
            }
            
            // Header
            HStack {
                if let onBack = onBack {
                    Button(action: {
                        onBack()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                    }
                } else {
                    // Spacer to maintain title alignment if back button is hidden, 
                    // or we can just left align the title. 
                    // Given the layout, let's keep the title centered.
                    Image(systemName: "chevron.left")
                         .font(.system(size: 18, weight: .semibold))
                         .foregroundColor(.clear)
                         .padding(10)
                }
                
                Spacer()
                
                Text(titleText)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Invisible spacer to balance the back button
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.clear)
                    .padding(10)
            }
            .padding(.horizontal)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            ScrollView {
                VStack(spacing: 0) {
                    timerOptionRow(minutes: 5)
                    Divider().background(Color.gray.opacity(0.2)).padding(.leading, 16)
                    
                    timerOptionRow(minutes: 10)
                    Divider().background(Color.gray.opacity(0.2)).padding(.leading, 16)
                    
                    timerOptionRow(minutes: 15)
                    Divider().background(Color.gray.opacity(0.2)).padding(.leading, 16)
                    
                    timerOptionRow(minutes: 30)
                    Divider().background(Color.gray.opacity(0.2)).padding(.leading, 16)
                    
                    timerOptionRow(minutes: 45)
                    Divider().background(Color.gray.opacity(0.2)).padding(.leading, 16)
                    
                    timerOptionRow(minutes: 60)
                    Divider().background(Color.gray.opacity(0.2)).padding(.leading, 16)
                    
                    endOfTrackOptionRow
                    
                    if viewModel.isSleepTimerActive {
                        Divider().background(Color.gray.opacity(0.2)).padding(.leading, 16)
                        
                        Button(action: {
                            viewModel.cancelSleepTimer()
                            withAnimation { isPresented = false }
                        }) {
                            HStack {
                                Text("Turn off timer")
                                    .font(.system(size: 15))
                                    .foregroundColor(.red)
                                    .padding(.leading, 16)
                                Spacer()
                            }
                            .frame(height: 54)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .padding(.trailing, isLandscape ? 30 : 0)
        .background(Color(UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)))
        .if(isLandscape) { view in
            view.cornerRadiusLocal(20, corners: [.topLeft, .bottomLeft])
        }
        .if(!isLandscape) { view in
            view.cornerRadiusLocal(20, corners: [.topLeft, .topRight])
        }
    }
    
    private var titleText: String {
        if let remaining = viewModel.sleepTimerRemainingString, viewModel.isSleepTimerActive {
            return "Sleep Timer"
        }
        return "Sleep Timer"
    }
    
    func timerOptionRow(minutes: Int) -> some View {
        let isSelected = isTimerSet(minutes: minutes)
        
        return Button(action: {
            viewModel.startSleepTimer(minutes: minutes)
            withAnimation(.easeInOut(duration: 0.3)) {
                isPresented = false
            }
        }) {
            HStack {
                Text("\(minutes) minutes")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.leading, 16)
                
                Spacer()
                
                radioButton(isSelected: isSelected)
                    .padding(.trailing, 16)
            }
            .frame(height: 54)
            .contentShape(Rectangle())
        }
    }
    
    private var endOfTrackOptionRow: some View {
        let isSelected = (viewModel.sleepTimerMode == .endOfTrack)
        
        return Button(action: {
            viewModel.setSleepTimerEndOfTrack()
            withAnimation(.easeInOut(duration: 0.3)) {
                isPresented = false
            }
        }) {
            HStack {
                Text("End of track")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.leading, 16)
                
                Spacer()
                
                radioButton(isSelected: isSelected)
                    .padding(.trailing, 16)
            }
            .frame(height: 54)
            .contentShape(Rectangle())
        }
    }
    
    private func radioButton(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color.orange : Color.gray.opacity(0.5), lineWidth: 2)
                .frame(width: 22, height: 22)
            
            if isSelected {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 12, height: 12)
            }
        }
    }
    
    private func isTimerSet(minutes: Int) -> Bool {
        if let original = viewModel.sleepTimerOriginalDuration {
             return original == TimeInterval(minutes * 60)
        }
        return false
    }
}

struct BookmarkThumbnailView: View {
    let bookmark: BookmarkItem?
    let videoURL: URL?
    let time: Double
    @State private var image: UIImage?
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.gray.opacity(0.3)
                Image(systemName: "photo")
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }
    
    private func generateThumbnail() {
        // 1. Try to load saved snapshot (VLC accurate thumb)
        if let bookmark = bookmark, let id = bookmark.id {
            let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
             let path = cachesDir.appendingPathComponent("bookmarks/\(id.uuidString).jpg").path
             if FileManager.default.fileExists(atPath: path), let uiImage = UIImage(contentsOfFile: path) {
                 self.image = uiImage
                 return
             }
        }
        
        guard let url = videoURL else { return }
        
        let fileExtension = url.pathExtension.lowercased()
        let isSupportedByAV = ["mp4", "mov", "m4v"].contains(fileExtension)
        
        if isSupportedByAV {
            DispatchQueue.global(qos: .userInitiated).async {
                let asset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.requestedTimeToleranceBefore = .zero
                generator.requestedTimeToleranceAfter = .zero
                
                // Low Quality / Memory Efficient
                let scale = UIScreen.main.scale
                generator.maximumSize = CGSize(width: 320 * scale, height: 180 * scale)
                
                let cmTime = CMTime(seconds: self.time, preferredTimescale: 600)
                
                do {
                    let img = try generator.copyCGImage(at: cmTime, actualTime: nil)
                    let uiImage = UIImage(cgImage: img)
                    DispatchQueue.main.async {
                        self.image = uiImage
                    }
                } catch {
                    print("AVThumbnail failed: \(error). Falling back to VLC.")
                    // Fallback to VLC
                    self.requestVLCThumbnail(url: url)
                }
            }
        } else {
            // Direct use of VLC for non-native formats
            requestVLCThumbnail(url: url)
        }
    }
    
    private func requestVLCThumbnail(url: URL) {
        // Use the shared manager to ensure the request completes
        VLCThumbnailRequestManager.shared.request(for: url) { img in
            self.image = img
        }
    }
}

struct BookmarkRow: View {
    @ObservedObject var bookmark: BookmarkItem
    @ObservedObject var viewModel: PlayerViewModel
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Tappable Area (Thumbnail + Info)
            HStack(spacing: 12) {
                // Thumbnail
                BookmarkThumbnailView(bookmark: bookmark, videoURL: viewModel.videoURL, time: bookmark.time)
                    .frame(width: 80, height: 48)
                    .cornerRadius(6)
                    .clipped()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(bookmark.name ?? "Bookmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(viewModel.formatTime(seconds: bookmark.time))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            
            // Buttons Area
            HStack(spacing: 16) {
                Button(action: onRename) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}
