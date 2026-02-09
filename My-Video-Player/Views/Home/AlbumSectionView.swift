import SwiftUI
import Photos

struct AlbumSectionView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    @State private var showSearch = false
    
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.galleryAlbums.isEmpty {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 80)
                    
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(Color.homeCardBackground.opacity(0.5))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 44))
                                .foregroundColor(.homeTextSecondary)
                        }
                        
                        VStack(spacing: 8) {
                            Text("No Gallery Albums Found")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.homeTextPrimary)
                            
                            Text("Grant photo access in settings to view\nyour device's video albums.")
                                .font(.system(size: 14))
                                .foregroundColor(.homeTextSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 40)
                        
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Open Settings")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Color.homeAccent, Color.homeAccent.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(30)
                                .shadow(color: Color.homeAccent.opacity(0.4), radius: 15, x: 0, y: 8)
                        }
                        .buttonStyle(.scalable)
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: GridLayout.gridColumns, spacing: GridLayout.spacing) {
                        ForEach(viewModel.galleryAlbums, id: \.localIdentifier) { album in
                            NavigationLink(destination: albumDestination(for: album)) {
                                AlbumCardView(album: album)
                            }
                            .buttonStyle(.scalable)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 100)
                }
            }
        }
        .background(Color.homeBackground)
        .ignoresSafeArea(edges: .bottom)
    }
    
    private func albumDestination(for album: PHAssetCollection) -> some View {
        let displayTitle = (album.localizedTitle ?? "Gallery") == "Videos" ? "All Videos" : (album.localizedTitle ?? "Gallery")
        // Pass empty videos list - FolderDetailView will fetch them asynchronously
        let folder = Folder(name: displayTitle, videoCount: album.estimatedAssetCount, videos: [], url: nil, albumIdentifier: album.localIdentifier, subfolders: [])
        return FolderDetailView(initialFolder: folder, viewModel: viewModel)
    }
    
}

struct AlbumCardView: View {
    let album: PHAssetCollection

    @State private var thumbnail: UIImage?
    @State private var videoCount: Int = 0

    var body: some View {
        let size = GridLayout.itemSize
        let padding: CGFloat = 8
        let thumbnailSize = size - (padding * 2)
        
        VStack(alignment: .leading, spacing: 10) {

            // 🔥 VIDEO CARD STYLE THUMBNAIL
            ZStack(alignment: .bottomTrailing) {

                if let image = thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: thumbnailSize, height: thumbnailSize)
                        .clipped()
                } else {
                    ZStack {
                        Color.homeCardBackground
                        Image(systemName: "video.fill")
                            .appSecondaryIconStyle(size: 28, color: .homeTextPrimary.opacity(0.2))
                    }
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipped()
                }
            }
            .cornerRadius(12)

            // Info section (same spacing style)
            VStack(alignment: .leading, spacing: 4) {
                Text(albumTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.homeTextPrimary)
                    .lineLimit(1)

                Text("\(videoCount) Videos")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.homeTextSecondary)
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .background(Color.homeCardBackground.opacity(0.4))
        .cornerRadius(20)
        .onAppear {
            fetchAlbumInfo()
        }
    }

    private var albumTitle: String {
        let title = album.localizedTitle ?? "Album"
        return title == "Videos" ? "All Videos" : title
    }

    private func fetchAlbumInfo() {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType = %d",
            PHAssetMediaType.video.rawValue
        )

        let assets = PHAsset.fetchAssets(in: album, options: options)
        videoCount = assets.count

        if let firstAsset = assets.firstObject {
            let manager = PHImageManager.default()
            let requestOptions = PHImageRequestOptions()
            requestOptions.deliveryMode = .opportunistic
            requestOptions.isNetworkAccessAllowed = true
            requestOptions.version = .current

            // Calculate exact size based on display size and screen scale
            let size = GridLayout.itemSize
            let padding: CGFloat = 8
            let thumbnailSize = size - (padding * 2)
            let pixelSize = thumbnailSize * UIScreen.main.scale
            
            manager.requestImage(
                for: firstAsset,
                targetSize: CGSize(width: pixelSize, height: pixelSize),
                contentMode: .aspectFill,
                options: requestOptions
            ) { image, _ in
                if let image = image {
                    thumbnail = image
                }
            }
        }
    }
}
