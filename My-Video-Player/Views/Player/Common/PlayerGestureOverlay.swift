import SwiftUI
import UIKit
import Combine

struct PlayerGestureOverlay: View {
    @ObservedObject var viewModel: PlayerViewModel
    @ObservedObject var volumeManager: SystemVolumeManager
    let toggleControls: () -> Void
    let onShowTapFeedback: (Bool) -> Void // true = forward
    
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
                    .onTapGesture { toggleControls() }
            }
            // 2. Global Drag Gesture
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onChanged { value in
                        if viewModel.isLocked { return }
                        
                        let totalHeight = geo.size.height
                        // Define 20% threshold
                        let edgeThreshold = geo.size.width * 0.20
                        
                        // Initialize drag state if just started
                        if !isDraggingLeft && !isDraggingRight {
                            if value.startLocation.x < edgeThreshold {
                                // Left 20% -> Brightness
                                isDraggingLeft = true
                                viewModel.triggerBrightnessUI()
                                dragStartValue = viewModel.currentBrightness
                            } else if value.startLocation.x > (geo.size.width - edgeThreshold) {
                                // Right 20% -> Volume
                                isDraggingRight = true
                                volumeManager.triggerVolumeUI()
                                dragStartValue = volumeManager.currentVolume
                            } else {
                                // Center 60% -> Ignore vertical drag
                                return 
                            }
                        }
                        
                        // Calculate change based on vertical movement
                        // Invert deltaY because dragging UP should increase value
                        let deltaPercentage = Float(-value.translation.height / (totalHeight * 0.5)) // Sensitivity
                        let newValue = min(max(dragStartValue + deltaPercentage, 0.0), 1.0)
                        
                        if isDraggingLeft {
                            viewModel.setBrightness(newValue)
                        } else {
                            volumeManager.setVolume(newValue)
                        }
                    }
                    .onEnded { _ in
                        isDraggingLeft = false
                        isDraggingRight = false
                        // The managers handle their own auto-hide now
                    }
            )
        }
    }
}
