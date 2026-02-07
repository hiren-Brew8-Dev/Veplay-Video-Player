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
        return "\(seconds)s"
    }
    
    var body: some View {
        ZStack {
            if isLandscape {
                // Landscape: Show on sides
                HStack {
                    if !isForward {
                        skipIndicator
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    
                    Spacer()
                    
                    if isForward {
                        skipIndicator
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 40)
            } else {
                // Portrait: Show below center (below play/pause button area)
                VStack {
                    Spacer()
                    
                    skipIndicator
                        .padding(.bottom, 120) // Position above bottom bar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    
                    Spacer()
                        .frame(height: 100) // Space for bottom controls
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                onClose()
            }
        }
    }
    
    private var skipIndicator: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                if !isForward {
                    Image(systemName: "backward.fill")
                    Image(systemName: "backward.fill")
                    Image(systemName: "backward.fill")
                } else {
                    Image(systemName: "forward.fill")
                    Image(systemName: "forward.fill")
                    Image(systemName: "forward.fill")
                }
            }
            .font(.system(size: 24))
            .foregroundColor(.white)
            
            Text(skipAmount)
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
                .blur(radius: 8)
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
        )
    }
}
