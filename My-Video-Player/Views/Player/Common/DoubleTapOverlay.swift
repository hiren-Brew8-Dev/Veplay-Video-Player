import SwiftUI

struct DoubleTapOverlay: View {
    let isForward: Bool
    let onClose: () -> Void
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    private var skipAmount: String {
        let seconds = Int(viewModel.accumulatedSkipAmount)
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    var body: some View {
        ZStack {
            // Invisible touch area to capture taps for dismissal
            Color.black.opacity(0.001)
                .edgesIgnoringSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    onClose()
                }
            
            // Central Indicator
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    skipIndicator
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { // Matched VM duration
                onClose()
            }
        }
    }
    
    private var skipIndicator: some View {
        HStack(spacing: 4) {
            if !isForward {
                // Backward
                Text("< \(skipAmount)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            } else {
                // Forward
                Text("> \(skipAmount)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
        }
    }
}
