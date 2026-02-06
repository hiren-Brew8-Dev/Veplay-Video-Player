import SwiftUI
import PhotosUI
import UIKit

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @State private var selectedPhotoItems = [PhotosPickerItem]()
    
    init() {
        UITabBar.appearance().barTintColor = UIColor(Color.themeSurface)
        UITabBar.appearance().unselectedItemTintColor = UIColor.gray
        UITabBar.appearance().isHidden = false
    }
    
    var body: some View {
        ZStack {
            NavigationStack {
                ZStack {
                    switch viewModel.selectedTab {
                    case 0:
                        HomeView(viewModel: viewModel, paddingBottom: .constant(80))
                    case 1:
                        PlaylistView()
                    case 2:
                        BrowseView()
                    case 3:
                        SettingsView()
                    default:
                        HomeView(viewModel: viewModel, paddingBottom: .constant(80))
                    }
                }
                .navigationBarHidden(true)
            }
            .fullScreenCover(item: $viewModel.playingVideo) { video in
                PlayerView(
                    video: video,
                    playlist: viewModel.currentPlaylist,
                    onPlaybackEnded: {
                        viewModel.playingVideo = nil
                    }
                )
                .environmentObject(viewModel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            if viewModel.isImporting {
                importingOverlay
            }
            
            if viewModel.showActionSheet {
                CustomActionSheet(
                    target: viewModel.actionSheetTarget,
                    items: viewModel.actionSheetItems,
                    isPresented: $viewModel.showActionSheet
                )
                .zIndex(200)
            }
            
            if !viewModel.isHeaderExpanded && !viewModel.isTabBarHidden && !viewModel.showActionSheet && viewModel.playingVideo == nil {
                CustomTabBarOverlay(viewModel: viewModel)
            }
        }
        .environmentObject(viewModel)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .alert("Create New Folder", isPresented: $viewModel.showCreateFolderAlert) {
            TextField("Folder Name", text: $viewModel.newFolderName)
            Button("Cancel", role: .cancel) { viewModel.newFolderName = "" }
            Button("Create") {
                viewModel.createFolder(name: viewModel.newFolderName)
                viewModel.newFolderName = ""
            }
        } message: {
            Text("Enter a name for the new folder")
        }
        .alert("Already Imported", isPresented: Binding(
            get: { viewModel.duplicateVideo != nil },
            set: { if !$0 { viewModel.duplicateVideo = nil } }
        )) {
            Button("Cancel", role: .cancel) { viewModel.duplicateVideo = nil }
            Button("Show") {
                if let video = viewModel.duplicateVideo {
                    viewModel.highlightVideoId = video.id
                    viewModel.duplicateVideo = nil
                }
            }
        } message: {
            if let video = viewModel.duplicateVideo {
                Text("\"\(video.title)\" has already been imported.")
            }
        }
        .sheet(isPresented: $viewModel.showMovePicker) {
            MoveDestinationPickerView(viewModel: viewModel, videosToMove: viewModel.videosToMove, isCutOperation: viewModel.isCutMode)
        }
        .fileImporter(
            isPresented: $viewModel.showFileImporter,
            allowedContentTypes: [.movie, .video],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.importVideos(from: urls)
            case .failure(let error):
                print("File import failed: \(error.localizedDescription)")
            }
        }
        .photosPicker(
            isPresented: $viewModel.showPhotoPicker,
            selection: $selectedPhotoItems,
            matching: .videos
        )
        .onChange(of: selectedPhotoItems) { oldItems, newItems in
            guard !newItems.isEmpty else { return }
            viewModel.isImporting = true
            Task {
                var importedURLs = [URL]()
                var importedNames = [String]()
                
                for item in newItems {
                    // Try to get original filename
                    var fileName: String?
                    if let localID = item.itemIdentifier {
                        let result = PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil)
                        if let asset = result.firstObject {
                            let resources = PHAssetResource.assetResources(for: asset)
                            fileName = resources.first?.originalFilename
                        }
                    }
                    
                    if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                        importedURLs.append(movie.url)
                        importedNames.append(fileName ?? movie.url.lastPathComponent)
                    }
                }
                
                await MainActor.run {
                    viewModel.importVideos(from: importedURLs, names: importedNames)
                    selectedPhotoItems.removeAll()
                }
            }
        }
        .sheet(isPresented: $viewModel.showShareSheetGlobal) {
            if !viewModel.activityItems.isEmpty {
                ShareSheet(activityItems: viewModel.activityItems)
            } else if let url = viewModel.shareURL {
                ShareSheet(activityItems: [url])
            }
        }
        .overlay {
            if viewModel.isSharing {
                sharingOverlay
            }
        }
        .onChange(of: viewModel.playingVideo) { oldVideo, newVideo in
            if newVideo != nil {
                viewModel.isTabBarHidden = true
            } else {
                viewModel.isTabBarHidden = false
            }
        }
    }
    
    private var sharingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    .scaleEffect(1.5)
                
                Text("Sharing...")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(Color.themeSurface)
            .cornerRadius(20)
            .shadow(radius: 20)
        }
    }
    
    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                
                Text("Syncing...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 30)
            .background(Material.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .zIndex(100)
    }
}

struct CustomTabBarOverlay: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        if !viewModel.isSelectionMode {
            VStack {
                Spacer()
                ZStack(alignment: .top) {
                    HStack {
                        Spacer()
                        tabBarItem(index: 0, icon: "house.fill", title: "Home")
                        Spacer()
                        tabBarItem(index: 3, icon: "gearshape.fill", title: "Settings")
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                    .background(Color.themeSurface)
                    .cornerRadius(30, corners: [.topLeft, .topRight])
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: -5)
                    
                    Button(action: {}) {
                        Menu {
                            Button(action: { viewModel.showCreateFolderAlert = true }) {
                                Label("Create Folder", systemImage: "folder.badge.plus")
                            }
                            Button(action: { viewModel.showPhotoPicker = true }) {
                                Label("Import from Photos", systemImage: "photo.on.rectangle")
                            }
                            Button(action: { viewModel.showFileImporter = true }) {
                                Label("Add From iOS Files", systemImage: "folder.badge.plus")
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.orange)
                                .clipShape(Circle())
                                .shadow(color: Color.orange.opacity(0.4), radius: 10, x: 0, y: 5)
                                .overlay(
                                    Circle()
                                        .stroke(Color.themeBackground, lineWidth: 4)
                                )
                        }
                    }
                    .offset(y: -30)
                }
            }
            .edgesIgnoringSafeArea(.bottom)
        }
    }
    
    private func tabBarItem(index: Int, icon: String, title: String) -> some View {
        Button(action: {
            viewModel.selectedTab = index
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(viewModel.selectedTab == index ? .orange : .gray)
            .frame(maxWidth: .infinity)
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
