import SwiftUI

struct PlaylistView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    
    var body: some View {
        ZStack {
            Color.homeBackground.edgesIgnoringSafeArea(.all)
            VStack {
                Image(systemName: "play.rectangle.on.rectangle")
                    .appSecondaryIconStyle(size: 80, color: .homeTextSecondary)
                Text("Playlists")
                    .font(.title2)
                    .foregroundColor(.homeTextPrimary)
                    .padding(.top)
                Button(action: {}) {
                    Text("Create New Playlist")
                        .fontWeight(.bold)
                        .padding()
                        .background(Color.homeAccent)
                        .foregroundColor(.homeTextPrimary)
                        .cornerRadius(10)
                }
                .padding(.top)
            }
            .padding(.bottom, 80)
            
            
            // CustomTabBarOverlay(viewModel: viewModel)
        }
        .navigationBarTitle("Playlists", displayMode: .inline)
    }
}
