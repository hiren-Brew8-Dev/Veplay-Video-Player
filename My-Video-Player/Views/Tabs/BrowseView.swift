import SwiftUI

struct BrowseView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    
    var body: some View {
        ZStack {
            Color.themeBackground.edgesIgnoringSafeArea(.all)
            VStack {
                Image(systemName: "globe")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
                Text("Browse")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.top)
                Text("Network Stream & Browser")
                    .foregroundColor(.gray)
            }
            // .padding(.bottom, 80) // Removed as tab bar is moved
            
            // CustomTabBarOverlay(viewModel: viewModel)
        }
        .navigationBarTitle("Browse", displayMode: .inline)
    }
}
