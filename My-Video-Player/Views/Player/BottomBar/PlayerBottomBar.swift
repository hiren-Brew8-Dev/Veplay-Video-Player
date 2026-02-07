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
    let onAspectRatio: @MainActor () -> Void
    let onLock: @MainActor () -> Void
    let onAudioCaptions: @MainActor () -> Void
    let onMenu: @MainActor () -> Void
    let onSpeedSheet: @MainActor () -> Void
    
    // Bookmark Props
    let showBookmarkControls: Bool
    let onSeekToPrevBookmark: @MainActor () -> Void
    let onSeekToNextBookmark: @MainActor () -> Void
    let onToggleBookmark: @MainActor () -> Void
    let hasPrevBookmark: Bool
    let hasNextBookmark: Bool
    let isAtBookmark: Bool // To styling the center button
    let isSubtitleEnabled: Bool // For styling if needed
    let onRotate: @MainActor () -> Void
    
    
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
    
    @State private var isShowingSpeedInline: Bool = false
    
    var body: some View {
        VStack(spacing: 8) { // Reduced from 20 to 8 for tighter fit
            // 1. Seek Bar + Time Labels Below
            VStack(spacing: 4) { // Reduced from 8 to 4
                seekSlider
                
                HStack {
                    Text(formatTime(displayTime))
                        .font(.system(size: 11, weight: .semibold)) // Smalled font
                        .foregroundColor(.white)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Text(formatTime(duration))
                        .font(.system(size: 11, weight: .semibold)) // Smalled font
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, isLandscape ? 50 : 20)
            
            // 2. Control Buttons Row
            ZStack {
                // Layer 1: Center (Audio & Captions) - Always centered
                if !isShowingSpeedInline {
                    Button(action: onAudioCaptions) {
                        HStack(spacing: 6) {
                            Image(systemName: "captions.bubble.fill")
                                .font(.system(size: 14))
                            Text(isLandscape ? "Audio & CC" : "Audio & CC")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .transition(.opacity)
                }
                
                // Layer 2: Left and Right Controls
                HStack(spacing: 0) {
                    // Left side: Aspect Ratio
                    if !isShowingSpeedInline {
                        Button(action: onAspectRatio) {
                            HStack(spacing: 6) {
                                Image(systemName: "aspectratio")
                                    .font(.system(size: 14))
                                Text(currentAspectRatio.shortLabel)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    
                    Spacer()
                    
                    // Right side items
                    HStack(spacing: 8) {
                        if isShowingSpeedInline {
                            // In-line speed selector replaces everything in this row
                            HStack(spacing: 12) {
                                Button(action: { withAnimation { isShowingSpeedInline = false } }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.white.opacity(0.2))
                                        .clipShape(Circle())
                                }
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                                            Button(action: {
                                                onSpeedChange(Float(speed))
                                                withAnimation { isShowingSpeedInline = false }
                                            }) {
                                                Text(String(format: "%.1fx", speed))
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(Float(speed) == playbackSpeed ? .homeAccent : .white)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(Color.white.opacity(0.1))
                                                    .cornerRadius(6)
                                            }
                                        }
                                    }
                                }
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        } else {
                            // Speed Pill
                            Button(action: { withAnimation { isShowingSpeedInline = true } }) {
                                Text(String(format: "%.1fx", playbackSpeed))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            
                            // Rotate button
                            Button(action: onRotate) {
                                Image(systemName: "viewfinder")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 32, height: 32)
                        }
                    }
                }
            }
            .padding(.horizontal, isLandscape ? 50 : 16)
        }
        .padding(.bottom, isLandscape ? 15 : 30) // Adjusted for safe area balance
        .background(Color.black.opacity(0.001))
        .contentShape(Rectangle())
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
        .accentColor(.homeAccent)
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
                                    .foregroundColor(isAtBookmark ? .homeAccent : .white)
                                    .padding(8)
                                    .background(isAtBookmark ? Color.white : Color.homeAccent)
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
                                Color.black.opacity(0.001)
                                Button(action: {}) {
                                    Color.clear
                                }
                            }
                        )
                        .frame(height: 38) // Reduced height from default ~50
                        .clipShape(Capsule())
                        
                        // The "Dash" (vertical line) connecting to the seekbar
                        Rectangle()
                            .fill(Color.homeAccent)
                            .frame(width: 2, height: 12) // Restored dash height
                    }
                    .allowsHitTesting(true)
                    .position(x: xOffset, y: -25) // Shifted down to touch thumb
                }
            }
        )
    }
    
    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20)) // Slightly smaller icons as per detailed look
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }
}
