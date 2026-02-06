import SwiftUI
import Photos

struct AlbumSectionView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    @State private var showSearch = false
    
    
    var body: some View {
        VStack(spacing: 0) {
            // Add a sub-header for Gallery section to match Video section if possible
            ScrollView {
                 if viewModel.galleryAlbums.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                        .frame(height: 50)
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No Gallery Albums Found")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("Grant photo access to see gallery")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.top, 50)
            } else {
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
        .background(Color.themeBackground)
    }
    
    private func albumDestination(for album: PHAssetCollection) -> some View {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        let assets = PHAsset.fetchAssets(in: album, options: fetchOptions)
        
        var videos: [VideoItem] = []
        assets.enumerateObjects { asset, _, _ in
            videos.append(viewModel.videoItem(from: asset))
        }
        
        let displayTitle = (album.localizedTitle ?? "Gallery") == "Videos" ? "All Videos" : (album.localizedTitle ?? "Gallery")
        let folder = Folder(name: displayTitle, videoCount: videos.count, videos: videos, url: nil, albumIdentifier: album.localIdentifier, subfolders: [])
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
                        Color.themeSurface
                        Image(systemName: "video.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.2))
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
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(videoCount) Videos")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .background(Color.themeSurface.opacity(0.4))
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
            requestOptions.deliveryMode = .fastFormat
            requestOptions.isNetworkAccessAllowed = true

            let thumbSize: CGFloat = 120 * UIScreen.main.scale
            manager.requestImage(
                for: firstAsset,
                targetSize: CGSize(width: thumbSize, height: thumbSize),
                contentMode: .aspectFill,
                options: requestOptions
            ) { image, _ in
                thumbnail = image
            }
        }
    }
}
