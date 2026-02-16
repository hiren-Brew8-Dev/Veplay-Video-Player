import SwiftUI

struct FavoritesView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
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
                    GeometryReader { geometry in
                        let isLandscape = geometry.size.width > geometry.size.height
                        let currentWidth = geometry.size.width
                        
                        ScrollView(showsIndicators: false) {
                            LazyVGrid(columns: GridLayout.gridColumns(isLandscape: isLandscape), spacing: 12) {
                                ForEach(favorites) { video in
                                    Button(action: {
                                        viewModel.playingVideo = video
                                    }) {
                                        VideoCardView(video: video, viewModel: viewModel, itemSize: GridLayout.itemSize(for: currentWidth, isLandscape: isLandscape))
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
