import SwiftUI

struct FavoritesView: View {
    @ObservedObject var viewModel: DashboardViewModel
    private let columns = GridLayout.gridColumns
    
    var body: some View {
        ZStack {
            Color.homeBackground.edgesIgnoringSafeArea(.all)
            
            VStack {
                // Header
                HStack {
                    Button(action: {
                        // Dismiss handled by nav
                    }) {
                        // Back handled by NavLink usually, but customized here if needed
                    }
                    Text("Favorites")
                        .font(.system(size: AppDesign.Icons.headerSize, weight: .bold))
                        .foregroundColor(.homeTextPrimary)
                    Spacer()
                }
                .padding()
                
                let favorites = viewModel.getFavoriteVideos()
                
                if favorites.isEmpty {
                    EmptyStateView(icon: "heart.slash", message: "No favorites yet")
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(favorites) { video in
                                Button(action: {
                                    viewModel.playingVideo = video
                                }) {
                                    VideoCardView(video: video, viewModel: viewModel)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
