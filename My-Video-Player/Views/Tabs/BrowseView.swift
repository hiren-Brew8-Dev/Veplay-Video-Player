import SwiftUI

struct BrowseView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    
    var body: some View {
        ZStack {
            Color.homeBackground.edgesIgnoringSafeArea(.all)
            VStack {
                Image(systemName: "globe")
                    .appSecondaryIconStyle(size: 80, color: .homeTextSecondary)
                Text("Browse")
                    .font(.title2)
                    .foregroundColor(.homeTextPrimary)
                    .padding(.top)
                Text("Network Stream & Browser")
                    .foregroundColor(.homeTextSecondary)
            }
            // .padding(.bottom, 80) // Removed as tab bar is moved
            
            // CustomTabBarOverlay(viewModel: viewModel)
        }
        .navigationBarTitle("Browse", displayMode: .inline)
    }
}
