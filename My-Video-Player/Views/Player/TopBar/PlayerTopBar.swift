import SwiftUI

struct PlayerTopBar: View {
    let title: String
    var onBack: @MainActor () -> Void
    @ObservedObject var viewModel: PlayerViewModel
    var onMenu: @MainActor () -> Void
    var onLock: @MainActor () -> Void
    var onUnlock: (@MainActor () -> Void)? = nil // Optional for non-locked view
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Left Group
                if !viewModel.isLocked {
                    StandardIconButton(icon: "chevron.left", color: .white, bg: Color.black.opacity(0.5), action: onBack)
                    
                    // Title - Truncated after 15 characters
                    Text(title.count > 15 ? String(title.prefix(15)) + "..." : title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(height: 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
                        .lineLimit(1)
                } else {
                    Spacer()
                }
                
                // Right Group
                HStack(spacing: 8) {
                    if !viewModel.isLocked {
                        CastButton(viewModel: viewModel)
                        
                        Button(action: onLock) {
                            Image(systemName: "lock")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        .frame(width: 44, height: 44)
                        
                        Button(action: onMenu) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        .frame(width: 44, height: 44)
                    } else {
                        // When locked, show only the lock icon at the settings position
                        Button(action: {
                            onUnlock?()
                        }) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        .frame(width: 44, height: 44)
                    }
                }
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
