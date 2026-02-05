import SwiftUI

struct PlaylistView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    
    var body: some View {
        ZStack {
            Color.themeBackground.edgesIgnoringSafeArea(.all)
            VStack {
                Image(systemName: "play.rectangle.on.rectangle")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
                Text("Playlists")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.top)
                Button(action: {}) {
                    Text("Create New Playlist")
                        .fontWeight(.bold)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
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
