import SwiftUI
import Photos
import PhotosUI
import UniformTypeIdentifiers

struct VideosTabView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Binding var showImportMenu: Bool
    // @State private var selectedVideo: VideoItem? // Removed in favor of viewModel.playingVideo
    @State private var showFileImporter = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
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
                        Button(action: {}) {
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
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            
                            // History Section
                            if !viewModel.historyItems.isEmpty {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text("History")
                                            .font(.headline)
                                            .foregroundColor(.homeTextPrimary)
                                        Spacer()
                                        NavigationLink(destination: HistoryView(historyItems: viewModel.historyItems)) {
                                            Text("View All")
                                                .font(.subheadline)
                                                .foregroundColor(.homeTextSecondary)
                                        }
                                    }
                                    .padding(.horizontal)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 15) {
                                            ForEach(viewModel.historyVideos) { video in
                                                Button(action: {
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
                                                FolderCardView(folder: folder)
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
                                
                                LazyVGrid(columns: GridLayout.gridColumns, spacing: GridLayout.spacing) {
                                    ForEach(viewModel.videos.prefix(6)) { video in
                                        Button(action: {
                                            // self.selectedVideo = video
                                            viewModel.playingVideo = video
                                        }) {
                                            VideoCardView(video: video, viewModel: viewModel)
                                        }
                                    }
                                }
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
                        Button(action: { showImportMenu = true }) {
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
                                    showPhotoPicker = true
                                },
                                .default(Text("Add From iOS Files")) { 
                                    showFileImporter = true
                                },
                                .default(Text("Connect to Computer")) { /* Show Wifi IP */ },
                                .default(Text("New Folder")) { /* Create Folder */ },
                                .cancel()
                            ])
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .environmentObject(viewModel) // Inject VM for child views
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.movie, .video],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let firstUrl = urls.first {
                        viewModel.importVideo(from: firstUrl)
                    }
                case .failure(let error):
                    print("File import failed: \(error.localizedDescription)")
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .videos)
            .onChange(of: selectedPhotoItem) { oldItem, newItem in
                Task {
                    if let newItem = newItem {
                        // 1. Try to get filename from PHAsset if possible (requires local identifier)
                        var fileName: String?
                        if let localID = newItem.itemIdentifier {
                            let result = PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil)
                            if let asset = result.firstObject {
                                let resources = PHAssetResource.assetResources(for: asset)
                                fileName = resources.first?.originalFilename
                            }
                        }
                        
                        // 2. Load the video file
                        if let movie = try? await newItem.loadTransferable(type: VideoTransferable.self) {
                            // 3. Import with the correct filename
                            // We need to extend importVideo to accept a custom filename
                            viewModel.importVideo(from: movie.url, withName: fileName)
                        }
                    }
                }
            }
            
            
        }
    }
}

// Helper for PhotosPicker transfer
struct VideoTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(received.file.lastPathComponent)
            // Remove existing if any (temp files might be reused)
            if FileManager.default.fileExists(atPath: copy.path) {
                try? FileManager.default.removeItem(at: copy)
            }
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self.init(url: copy)
        }
    }
}
