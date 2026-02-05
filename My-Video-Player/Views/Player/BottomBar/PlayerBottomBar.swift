import SwiftUI

struct PlayerBottomBar: View {
    @Binding var currentTime: Double
    let duration: Double
    let isPlaying: Bool
    let currentAspectRatio: PlayerViewModel.VideoAspectRatio
    let onPlayPause: @MainActor () -> Void
    let onSkipBackward: @MainActor () -> Void
    let onSkipForward: @MainActor () -> Void
    let onSeek: @MainActor (Double) -> Void
    let onSmoothSeek: @MainActor (Double) -> Void
    let playbackSpeed: Float
    let onSpeedChange: @MainActor (Float) -> Void
    let onPIP: @MainActor () -> Void
    let onQueue: @MainActor () -> Void
    let onTrackSelection: @MainActor () -> Void
    let onAspectRatio: @MainActor () -> Void
    let onLock: @MainActor () -> Void
    let onRotate: @MainActor () -> Void
    let onCC: @MainActor () -> Void
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // State for smooth seeking
    @State private var isDragging: Bool = false
    @State private var dragValue: Double = 0
    
    // Formatting helper
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(max(0, seconds))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // Current value to display (either dragging value or actual time)
    private var displayTime: Double {
        isDragging ? dragValue : currentTime
    }
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    var body: some View {
        VStack(spacing: isLandscape ? 12 : 8) {
            if isLandscape {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .padding(.horizontal, isLandscape ? 50 : 14)
        .padding(.bottom, 20)
        .background(Color.black.opacity(0.001))
        .contentShape(Rectangle())
    }
    
    // MARK: - Portrait Layout (Image Reference)
    private var portraitLayout: some View {
        VStack(spacing: 10) {
            // 1. Seek Row + Playlist Button
            HStack(alignment: .center, spacing: 14) {
                VStack(spacing: 8) {
                    seekSlider
                    
                    HStack {
                        Text(formatTime(displayTime))
                        Spacer()
                        Text(formatTime(duration))
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 2)
                }
                
                playlistButton
                    .padding(.bottom, 12) // Align more with the slider track center
            }
            .padding(.horizontal, 4)
            
            // 2. Control Buttons Row (Spread out)
            HStack(spacing: 0) {
                controlButton(icon: "lock.fill", action: onLock)
                Spacer()
                controlButton(icon: "pip.enter", action: onPIP)
                Spacer()
                ccButton
                Spacer()
                aspectRatioMenu
                Spacer()
                controlButton(icon: "rotate.right", action: onRotate)
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - Landscape Layout (Image 1)
    private var landscapeLayout: some View {
        VStack(spacing: 12) {
            // 1. Seek Bar + Time Labels
            HStack(spacing: 15) {
                Text(formatTime(displayTime))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                seekSlider
                
                Text(formatTime(duration))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // 2. Bottom Icon Row
            HStack(spacing: 25) {
                controlButton(icon: "lock.fill", action: onLock)
                controlButton(icon: "pip.enter", action: onPIP)
                ccButton
                aspectRatioMenu
                controlButton(icon: "rotate.right", action: onRotate)
                
                Spacer()
                
                
                playlistButton
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Sub-components
    
    private var aspectRatioMenu: some View {
        Button(action: onAspectRatio) {
            Image(systemName: "rectangle.center.inset.filled")
                .font(.system(size: 22))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }
    
    // MARK: - Sub-components
    
    private var seekSlider: some View {
        CustomSlider(
            value: Binding(
                get: { displayTime },
                set: { newValue in dragValue = newValue }
            ),
            range: 0...max(duration, 1),
            onEditingChanged: { editing in
                if editing {
                    dragValue = currentTime
                }
                isDragging = editing
                if !editing {
                    onSeek(dragValue)
                }
            }
        )
        .accentColor(.orange)
        .onChange(of: dragValue) { oldVal, newVal in
            if isDragging {
                onSmoothSeek(newVal)
            }
        }
    }
    
    private var playlistButton: some View {
        Button(action: onQueue) {
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }
    
    private var ccButton: some View {
        Button(action: onCC) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "captions.bubble.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                
                // Red dot badge
                Circle()
                    .fill(Color.red)
                    .frame(width: 7, height: 7)
                    .offset(x: 2, y: -2)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
    }
    
    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }
}
