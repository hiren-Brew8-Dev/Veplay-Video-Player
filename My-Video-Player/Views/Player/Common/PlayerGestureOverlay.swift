import SwiftUI
import UIKit
import Combine

struct PlayerGestureOverlay: View {
    @ObservedObject var viewModel: PlayerViewModel
    @ObservedObject var volumeManager: SystemVolumeManager
    let toggleControls: () -> Void
    let onShowTapFeedback: (Bool) -> Void // true = forward
    
    // Tap Tracking for Samsung-style skip
    @State private var lastTapTime: Date = .distantPast
    @State private var lastTapForward: Bool? = nil
    @State private var pendingToggleTask: Task<Void, Never>? = nil
    
    // Gesture State
    @State private var dragStartValue: Float = 0.0
    @State private var isDraggingLeft = false
    @State private var isDraggingRight = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Invisible Tap Areas
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { location in
                        if viewModel.isLocked || viewModel.isPiPActive || viewModel.duration.isInfinite || viewModel.duration <= 0 { 
                            toggleControls()
                            return 
                        }
                        
                        let screenWidth = geo.size.width
                        let tapX = location.x
                        
                        // Interaction Zones: Left 30%, Center 40%, Right 30%
                        let leftLimit = screenWidth * 0.30
                        let rightLimit = screenWidth * 0.70
                        
                        let isLeftSide = tapX < leftLimit
                        let isRightSide = tapX > rightLimit
                        let isCenterZone = tapX >= leftLimit && tapX <= rightLimit
                        let isForward = tapX > screenWidth / 2
                        
                        let now = Date()
                        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
                        
                        if (isLeftSide || isRightSide) && !isCenterZone {
                            // SIDE TAP LOGIC: Double Tap detection and continuous tap accumulation
                            if viewModel.isSeekUIActive || (timeSinceLastTap < 0.35 && lastTapForward == isForward) {
                                // Double tap or subsequent tap detected
                                pendingToggleTask?.cancel()
                                pendingToggleTask = nil
                                
                                viewModel.performDoubleTapSeek(forward: isForward)
                                onShowTapFeedback(isForward)
                                
                                lastTapTime = now
                                lastTapForward = isForward
                            } else {
                                // Potential first tap of a double-tap
                                lastTapTime = now
                                lastTapForward = isForward
                                
                                // Delay the single-tap action (controls toggle) to allow for a second tap
                                pendingToggleTask?.cancel()
                                pendingToggleTask = Task {
                                    try? await Task.sleep(nanoseconds: 250_000_000) // 250ms as per OTT standards
                                    guard !Task.isCancelled else { return }
                                    await MainActor.run {
                                        // ONLY toggle if we are NOT currently seeking (prevents fighting with UI)
                                        if !viewModel.isSeekUIActive {
                                            toggleControls()
                                        }
                                    }
                                }
                            }
                        } else {
                            // CENTER TAP LOGIC: Instant response, no double-tap allowed
                            pendingToggleTask?.cancel()
                            pendingToggleTask = nil
                            toggleControls()
                            
                            // Reset state for side tracking
                            lastTapTime = .distantPast
                            lastTapForward = nil
                        }
                    }
            }
            // 3. Global Drag Gesture
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onChanged { value in
                        if viewModel.isLocked || viewModel.isPiPActive { return }
                        
                        let totalHeight = geo.size.height
                        // Define 20% edge threshold for Brightness/Volume
                        let edgeThreshold = geo.size.width * 0.20
                        
                        if !isDraggingLeft && !isDraggingRight {
                            if value.startLocation.x < edgeThreshold {
                                isDraggingLeft = true
                                dragStartValue = viewModel.currentBrightness
                                viewModel.triggerBrightnessUI()
                            } else if value.startLocation.x > (geo.size.width - edgeThreshold) {
                                isDraggingRight = true
                                dragStartValue = volumeManager.currentVolume
                                volumeManager.triggerVolumeUI()
                            } else {
                                return 
                            }
                        }
                        
                        let deltaPercentage = Float(-value.translation.height / (totalHeight * 0.5))
                        let newValue = min(max(dragStartValue + deltaPercentage, 0.0), 1.0)
                        
                        if isDraggingLeft {
                            viewModel.setBrightness(newValue)
                        } else if isDraggingRight {
                            volumeManager.setVolume(newValue)
                        }
                    }
                    .onEnded { _ in
                        isDraggingLeft = false
                        isDraggingRight = false
                    }
            )
        }
    }
}
