import SwiftUI

struct PlayerTopBar: View {
    let title: String
    var onBack: @MainActor () -> Void
    @ObservedObject var viewModel: PlayerViewModel
    var onCC: @MainActor () -> Void
    var onMenu: @MainActor () -> Void
    var onSleepTimer: @MainActor () -> Void
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Left Group
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 44, height: 44)
                
                // Title - Left aligned but constrained to available space
                MarqueeText(
                    text: title,
                    font: .system(size: 17, weight: .semibold),
                    leftFade: 5,
                    rightFade: 5,
                    startDelay: 0.8
                )
                .frame(height: 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                .clipped()
                
                // Right Group
                HStack(spacing: 0) {
                    CastButton(viewModel: viewModel)
                        .frame(width: 34, height: 44)
                    
                    Button(action: onMenu) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    .frame(width: 34, height: 44)
                }
                .padding(.trailing, 0)
            }
            .padding(.horizontal, isLandscape ? 50 : 8)
            
        }
        .padding(.top, isLandscape ? 20 : 40)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.8), Color.clear]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
