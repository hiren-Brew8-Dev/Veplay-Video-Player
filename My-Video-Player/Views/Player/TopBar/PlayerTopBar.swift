import SwiftUI

struct PlayerTopBar: View {
    let title: String
    var onBack: @MainActor () -> Void
    @ObservedObject var viewModel: PlayerViewModel
    let lockNamespace: Namespace.ID
    var onMenu: @MainActor () -> Void
    var onTimer: @MainActor () -> Void
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    init(title: String,
        onBack: @escaping @MainActor () -> Void,
        viewModel: PlayerViewModel,
        lockNamespace: Namespace.ID,
        onMenu: @escaping @MainActor () -> Void,
        onTimer: @escaping @MainActor () -> Void) {
        self.title = title
        self.onBack = onBack
        self.viewModel = viewModel
        self.lockNamespace = lockNamespace
        self.onMenu = onMenu
        self.onTimer = onTimer
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
                HStack(spacing: 5) {
                    // Active Sleep Timer Indicator
                    if viewModel.isSleepTimerActive {
                        Button(action: onTimer) {
                            Image(systemName: "timer")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                        }
                        .frame(width: 40, height: 44)
                    }
                    
                    CastButton(viewModel: viewModel)
                    
                    Color.clear
                        .frame(width: 40, height: 44)
                        .matchedGeometryEffect(id: "lockIcon", in: lockNamespace, isSource: !viewModel.isLocked)
                    
                    Button(action: onMenu) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    .frame(width: 40, height: 44)
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
