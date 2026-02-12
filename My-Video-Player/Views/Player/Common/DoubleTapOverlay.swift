import SwiftUI

struct DoubleTapOverlay: View {
    let isForward: Bool
    let onClose: () -> Void
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    private var overlayText: String {
        if viewModel.isLongPress2xActive {
            return "2.0x >>"
        }
        let totalSeconds = Int(viewModel.accumulatedSkipAmount)
        // If we are in the middle of a transition and speed mode just ended, keep showing speed text
        // Or if it's a genuine skip of 0 (which shouldn't happen), return empty or previous state.
        if totalSeconds == 0 {
            return "2.0x >>"
        }
        return "\(isForward ? ">>" : "<<") \(totalSeconds) secs"
    }
    
    private var isActuallySpeedMode: Bool {
        viewModel.isLongPress2xActive || Int(viewModel.accumulatedSkipAmount) == 0
    }
    
    var body: some View {
        ZStack {
            // Invisible area - no hit testing anyway
            Color.clear
            
            if isActuallySpeedMode {
                // TOP CENTER for 2x Speed in ALL orientations
                VStack {
                    HStack {
                        Spacer()
                        indicatorText
                            .padding(.top, isLandscape ? isIpad ? 40 : 20 : isIpad ? 80 : 50)
                        Spacer()
                    }
                    Spacer()
                }
            } else {
                // Regular Skip UI
                if isLandscape || isIpad {
                    HStack(spacing: 0) {
                        if !isForward {
                            indicatorText
                                .padding(.leading, 120)
                            Spacer()
                        } else {
                            Spacer()
                            indicatorText
                                .padding(.trailing, 120)
                        }
                    }
                } else {
                    VStack {
                        Spacer()
                        indicatorText
                            .padding(.top, viewModel.isControlsVisible ? 120 : 0) 
                        Spacer()
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private var indicatorText: some View {
        Text(overlayText)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 4)
    }
}
