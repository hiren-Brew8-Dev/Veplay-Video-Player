import SwiftUI

struct ActionSheetOverlay: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var isIpad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation {
                        viewModel.showActionSheet = false
                    }
                }
                .transition(.opacity)
            
            CustomActionSheet(
                target: viewModel.actionSheetTarget,
                items: viewModel.actionSheetItems,
                isPresented: $viewModel.showActionSheet
            )
            .applyIf(isIpad) { view in
                view.frame(maxWidth: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(radius: 20)
            }
            .transition(isIpad ? .scale.combined(with: .opacity) : .move(edge: .bottom))
        }
        .zIndex(200)
    }
}
