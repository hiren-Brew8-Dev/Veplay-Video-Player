import SwiftUI

struct PlayerTopBar: View {
    let title: String
    var onBack: @MainActor () -> Void
    @ObservedObject var viewModel: PlayerViewModel
    let lockNamespace: Namespace.ID
    var onMenu: @MainActor () -> Void
    var onTimer: @MainActor () -> Void
    var onCast: @MainActor () -> Void
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    init(title: String,
        onBack: @escaping @MainActor () -> Void,
        viewModel: PlayerViewModel,
        lockNamespace: Namespace.ID,
        onMenu: @escaping @MainActor () -> Void,
        onTimer: @escaping @MainActor () -> Void,
        onCast: @escaping @MainActor () -> Void) {
        self.title = title
        self.onBack = onBack
        self.viewModel = viewModel
        self.lockNamespace = lockNamespace
        self.onMenu = onMenu
        self.onTimer = onTimer
        self.onCast = onCast
    }
    
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                // Left Group
                if !viewModel.isLocked {
                    StandardIconButton(icon: "chevron.left", color: .white, bg: Color.black.opacity(0.5), action: onBack)
                    
                    // Title - Truncated based on device
                    let prefixLimit = isIpad ? 40 : 15
                    Text(title.count > prefixLimit ? String(title.prefix(prefixLimit)) + "..." : title)
                        .font(.system(size: isIpad ? 24 : 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(height: isIpad ? 32 : 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, isIpad ? 16 : 8)
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
                                .font(.system(size: isIpad ? 24 : 20))
                                .foregroundColor(.orange)
                        }
                        .frame(width: isIpad ? 60 : 40, height: isIpad ? 60 : 44)
                    }
                    
                    CastButton(viewModel: viewModel, action: onCast)
                    
                    Color.clear
                        .frame(width: 40, height: 44)
                        .matchedGeometryEffect(id: "lockIcon", in: lockNamespace, isSource: !viewModel.isLocked)
                    
                    Button(action: onMenu) {
                        Image(systemName: "gearshape")
                            .font(.system(size: isIpad ? 24 : 20))
                            .foregroundColor(.white)
                    }
                    .frame(width: isIpad ? 60 : 40, height: isIpad ? 60 : 44)
                }
            }
            .padding(.horizontal, isLandscape ? (isIpad ? 80 : 50) : (isIpad ? 30 : 8))
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
