import SwiftUI
import Photos

import UniformTypeIdentifiers

struct VideosTabView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Binding var showImportMenu: Bool
    // @State private var selectedVideo: VideoItem? // Removed in favor of viewModel.playingVideo
    // @State private var selectedVideo: VideoItem? // Removed in favor of viewModel.playingVideo
    
    var body: some View {
        if viewModel.showPermissionDenied {
            PermissionDeniedView()
        
        } else {
            ZStack(alignment: .bottom) {
                Color.homeBackground.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .appIconStyle(size: AppDesign.Icons.headerSize, color: .homeTint)
                        Text("PLAYER")
                            .font(.system(size: AppDesign.Icons.headerSize, weight: .bold))
                            .foregroundColor(.homeTextPrimary)
                        Spacer()
                        Button(action: {
                            HapticsManager.shared.generate(.medium)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                    Text("Premium")
                                    .fontWeight(.bold)
                                    .foregroundColor(.homeTextPrimary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.homeAccent)
                            .cornerRadius(20)
                        }
                    }
                    .padding()
                    
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            
                            // History Section
                            if !viewModel.historyItems.isEmpty {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text("History")
                                            .font(.headline)
                                            .foregroundColor(.homeTextPrimary)
                                        Spacer()
//                                        NavigationLink(destination: HistoryView(historyItems: viewModel.historyItems)) {
//                                            Text("View All")
//                                                .font(.subheadline)
//                                                .foregroundColor(.homeTextSecondary)
//                                        }
                                    }
                                    .padding(.horizontal)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 15) {
                                            ForEach(viewModel.historyVideos) { video in
                                                Button(action: {
                                                    HapticsManager.shared.generate(.selection)
                                                    viewModel.playingVideo = video
                                                }) {
                                                    VideoCardView(video: video, viewModel: viewModel)
                                                        .frame(width: 120)
                                                }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // Albums Section
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Albums")
                                        .font(.headline)
                                        .foregroundColor(.homeTextPrimary)
                                    Spacer()
                                    NavigationLink(destination: AlbumsView(folders: viewModel.folders, viewModel: viewModel)) {
                                        Text("View All")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 15) {
                                        ForEach(viewModel.folders) { folder in
                                            NavigationLink(destination: FolderDetailView(initialFolder: folder, viewModel: viewModel)) {
                                                FolderCardView(folder: folder, viewModel: viewModel)
                                                    .frame(width: 110)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text("Videos")
                                            .font(.headline)
                                            .foregroundColor(.homeTextPrimary)
                                        Spacer()
                                        // "View All" functionality
                                        NavigationLink(destination: FolderDetailView(initialFolder: Folder(name: "All Videos", videoCount: viewModel.videos.count, videos: viewModel.videos), viewModel: viewModel)) {
                                            Text("View All")
                                                .font(.subheadline)
                                                .foregroundColor(.homeTextSecondary)
                                        }
                                    }
                                    .padding(.horizontal)
                                
                                GeometryReader { geometry in
                                    let isLandscape = geometry.size.width > geometry.size.height
                                    let currentWidth = geometry.size.width
                                    
                                    LazyVGrid(columns: GridLayout.gridColumns(isLandscape: isLandscape), spacing: GridLayout.spacing(isLandscape: isLandscape)) {
                                        ForEach(viewModel.videos.prefix(6)) { video in
                                            Button(action: {
                                                HapticsManager.shared.generate(.selection)
                                                // self.selectedVideo = video
                                                viewModel.playingVideo = video
                                            }) {
                                                VideoCardView(video: video, viewModel: viewModel, itemSize: GridLayout.itemSize(for: currentWidth, isLandscape: isLandscape))
                                            }
                                        }
                                    }
                                }
                                .frame(height: 400) // Give it enough height for the items
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 80)
                    }
                }
                
                // FAB
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            HapticsManager.shared.generate(.medium)
                            showImportMenu = true
                        }) {
                            Image(systemName: "plus")
                            .appIconStyle(size: 24, weight: .bold, color: .homeTextPrimary)
                            .frame(width: 56, height: 56)
                            .background(Color.homeAccent)
                            .cornerRadius(28)
                            .shadow(radius: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                        .actionSheet(isPresented: $showImportMenu) {
                            ActionSheet(title: Text("Import Videos"), buttons: [
                                .default(Text("Import from Photos")) { 
                                    HapticsManager.shared.generate(.selection)
                                    viewModel.showPhotoPicker = true
                                },
                                .default(Text("Add From iOS Files")) { 
                                    HapticsManager.shared.generate(.selection)
                                    viewModel.showFileImporter = true
                                },
                                .default(Text("Connect to Computer")) {
                                    HapticsManager.shared.generate(.selection)
                                    /* Show Wifi IP */
                                },
                                .default(Text("New Folder")) {
                                    HapticsManager.shared.generate(.selection)
                                    /* Create Folder */
                                },
                                .cancel()
                            ])
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .environmentObject(viewModel) // Inject VM for child views

            
            
        }
    }
}


