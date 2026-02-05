import SwiftUI

struct PlayerBottomBar: View {
    @Binding var currentTime: Double
    let duration: Double
    let isPlaying: Bool
    let bookmarks: [BookmarkItem]
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
    // Bookmark Props
    let showBookmarkControls: Bool
    let onSeekToPrevBookmark: @MainActor () -> Void
    let onSeekToNextBookmark: @MainActor () -> Void
    let onToggleBookmark: @MainActor () -> Void
    let hasPrevBookmark: Bool
    let hasNextBookmark: Bool
    let isAtBookmark: Bool // To styling the center button
    let isSubtitleEnabled: Bool // For CC red dot
    
    
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
        .padding(.top, 60) // Extend hit area upwards to cover floating bookmarks
        .padding(.horizontal, isLandscape ? 50 : 14)
        .padding(.bottom, 20)
        .background(Color.black.opacity(0.001)) // Transparent touch catcher
        .contentShape(Rectangle()) // Ensure entire area captures taps
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
                            .monospacedDigit()
                            .frame(width: 65, alignment: .leading)
                        Spacer()
                        Text(formatTime(duration))
                            .monospacedDigit()
                            .frame(width: 65, alignment: .trailing)
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
            HStack(spacing: 20) {
                // Left Group: Lock, CC, Aspect
                controlButton(icon: "lock.fill", action: onLock)
                ccButton
                aspectRatioMenu
                
                Spacer() // Pushes Rotate to the right
                
                // Right Group
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
                    .monospacedDigit()
                    .frame(width: 65, alignment: .leading)
                
                seekSlider
                
                Text(formatTime(duration))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .frame(width: 65, alignment: .trailing)
            }
            
            // 2. Bottom Icon Row
            HStack(spacing: 25) {
                controlButton(icon: "lock.fill", action: onLock)
                // controlButton(icon: "pip.enter", action: onPIP) // Hidden as requested "logically present, UI absent"
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
            bookmarks: bookmarks,
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
        .overlay(
            GeometryReader { geo in
                let width = geo.size.width
                // Calculate position: (time / duration) * width
                // Clamp to [0, width]
                let ratio = max(0, min(1, (isDragging ? dragValue : currentTime) / max(duration, 0.001)))
                let xOffset = CGFloat(ratio) * width
                
                // Movable Bookmark Controls
                if showBookmarkControls {
                    VStack(spacing: 0) { // No gap between cluster and line
                        // The Control Cluster
                        HStack(spacing: 0) {
                            // Prev Arrow (Always present for symmetry)
                            Button(action: onSeekToPrevBookmark) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40) // Fixed larger hit area
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(!hasPrevBookmark)
                            .opacity(hasPrevBookmark ? 1 : 0.001) // Invisible but keeps layout

                            // Central Toggle Button
                            Button(action: onToggleBookmark) {
                                Image(systemName: isAtBookmark ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 16))
                                    .foregroundColor(isAtBookmark ? .orange : .white)
                                    .padding(8)
                                    .background(isAtBookmark ? Color.white : Color.orange)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .highPriorityGesture(TapGesture().onEnded { onToggleBookmark() })
                            .padding(4)
                            .padding(.vertical, 2)

                            // Next Arrow (Always present for symmetry)
                            Button(action: onSeekToNextBookmark) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40) // Fixed larger hit area
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(!hasNextBookmark)
                            .opacity(hasNextBookmark ? 1 : 0.001) // Invisible but keeps layout
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            ZStack {
                                Color.black.opacity(0.8)
                                Button(action: {}) {
                                    Color.clear
                                }
                            }
                        )
                        .frame(height: 38) // Reduced height from default ~50
                        .clipShape(Capsule())
                        
                        // The "Dash" (vertical line) connecting to the seekbar
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: 2, height: 12) // Restored dash height
                    }
                    .allowsHitTesting(true)
                    .position(x: xOffset, y: -25) // Shifted down to touch thumb
                }
            }
        )
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
                    .opacity(isSubtitleEnabled ? 1 : 0)
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
