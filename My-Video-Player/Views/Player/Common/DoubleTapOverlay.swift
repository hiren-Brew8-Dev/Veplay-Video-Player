import SwiftUI

struct DoubleTapOverlay: View {
    let isForward: Bool
    let onClose: () -> Void
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    private var skipAmountText: String {
        let totalSeconds = Int(viewModel.accumulatedSkipAmount)
        return "\(isForward ? ">>" : "<<") \(totalSeconds) secs"
    }
    
    var body: some View {
        ZStack {
            // Invisible area - no hit testing anyway
            Color.clear
            
            if isLandscape {
                // LANDSCAPE: Show near the side skip buttons, perfectly centered vertically
                HStack(spacing: 0) {
                    if !isForward {
                        // Backward indicator on the left
                        indicatorText
                            .padding(.leading, 120) // Increased to clear the skip button icon
                        Spacer()
                    } else {
                        // Forward indicator on the right
                        Spacer()
                        indicatorText
                            .padding(.trailing, 120) // Increased to clear the skip button icon
                    }
                }
            } else {
                // PORTRAIT: 
                VStack {
                    Spacer()
                    indicatorText
                        // ONLY push it below the center if the large Play button is visible
                        .padding(.top, viewModel.isControlsVisible ? 120 : 0) 
                    Spacer()
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private var indicatorText: some View {
        Text(skipAmountText)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 4)
    }
}
