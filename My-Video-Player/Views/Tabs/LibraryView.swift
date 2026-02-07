import SwiftUI

struct LibraryView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.homeBackground.edgesIgnoringSafeArea(.all)
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Library")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.homeTextPrimary)
                        .padding()
                    
                    List {
                        Section {
                            NavigationLink(destination: HistoryView(historyItems: viewModel.historyItems)) {
                                Label("Recent Played", systemImage: "clock.arrow.circlepath")
                            }
                            
                            NavigationLink(destination: FavoritesView(viewModel: viewModel)) {
                                Label("Favorites", systemImage: "heart.fill")
                            }
                            
                            NavigationLink(destination: FolderDetailView(initialFolder: Folder(name: "Downloads", videoCount: viewModel.videos.count, videos: viewModel.videos), viewModel: viewModel)) { // viewModel.videos contains imported/downloaded
                                Label("Downloads", systemImage: "arrow.down.circle")
                            }
                            
                            NavigationLink(destination: PrivateFolderView(viewModel: viewModel)) {
                                Label("Private Folder", systemImage: "lock.shield")
                            }
                        }
                        .listRowBackground(Color.homeCardBackground)
                    }
                    .listStyle(InsetGroupedListStyle())
                    .preferredColorScheme(.dark)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }
}
