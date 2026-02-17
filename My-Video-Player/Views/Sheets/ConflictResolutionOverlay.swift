import SwiftUI

struct ConflictResolutionOverlay: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        if viewModel.showConflictResolution, let conflict = viewModel.currentConflict {
            ZStack {
                Color.black.opacity(0.6)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                
                ConflictResolutionView(viewModel: viewModel, conflict: conflict)
                    .id(conflict.id)
                    .transition(AnyTransition.scale.combined(with: .opacity))
                    .zIndex(300)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.showConflictResolution)
        }
    }
}
