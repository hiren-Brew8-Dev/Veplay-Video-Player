import SwiftUI
import Photos

struct MoveDestinationPickerView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let videosToMove: [VideoItem]
    let isCutOperation: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Background Gradient
            // Background Gradient
            AppGlobalBackground().ignoresSafeArea()
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Drag Handle
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                
                // Header (Preview of item being moved)
                headerView
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Locations Card
                        let isAlreadyInImported = if let sourceURL = viewModel.sourceURL {
                            (sourceURL.path as NSString).standardizingPath == (viewModel.importedVideosDirectory.path as NSString).standardizingPath
                        } else {
                            false // If it's nil, it's likely from Gallery or another non-file source
                        }
                        
                        if isGallerySource || !isAlreadyInImported {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("LOCATIONS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.leading, 16)
                                
                                destinationCard {
                                    destinationRow(
                                        title: "Imported Videos",
                                        subtitle: nil,
                                        icon: "video.fill",
                                        iconColor: .homeAccent,
                                        action: {
                                            viewModel.pasteVideos(to: viewModel.importedVideosDirectory)
                                            dismiss()
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Folders Card
                        let otherFolders = viewModel.folders.filter { folder in
                            guard let folderURL = folder.url, let sourceURL = viewModel.sourceURL else { return true }
                            return (folderURL.path as NSString).standardizingPath != (sourceURL.path as NSString).standardizingPath
                        }
                        if !otherFolders.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("FOLDERS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.leading, 16)
                                
                                destinationCard {
                                    ForEach(Array(otherFolders.enumerated()), id: \.element.id) { index, folder in
                                        if let url = folder.url {
                                            destinationRow(
                                                title: folder.name,
                                                subtitle: "\(folder.videos.count) Videos",
                                                icon: "folder.fill",
                                                iconColor: .orange,
                                                action: {
                                                    viewModel.pasteVideos(to: url)
                                                    dismiss()
                                                }
                                            )
                                            
                                            if index < otherFolders.count - 1 {
                                                divider
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Gallery Albums Card
                        let otherAlbums = viewModel.allGalleryAlbums.filter { $0.localIdentifier != viewModel.sourceAlbumIdentifier }
                        if !otherAlbums.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("GALLERY ALBUMS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.leading, 16)
                                
                                destinationCard {
                                    ForEach(Array(otherAlbums.enumerated()), id: \.element.localIdentifier) { index, album in
                                        albumRow(album: album) {
                                            Task {
                                                await viewModel.pasteVideosToGallery(album: album)
                                                await MainActor.run {
                                                    dismiss()
                                                }
                                            }
                                        }
                                        
                                        if index < otherAlbums.count - 1 {
                                            divider
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            viewModel.fetchAlbums()
        }
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 16) {
            // Preview Thumbnail
            ZStack {
                if videosToMove.count == 1, let video = videosToMove.first {
                    ActionSheetThumbnailView(video: video)
                        .frame(width: 90, height: 56)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 90, height: 56)
                        .overlay(
                            Image(systemName: "square.grid.2x2.fill")
                                .foregroundColor(.homeAccent)
                                .font(.system(size: 20))
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(isCutOperation ? "Move to..." : "Copy to...")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                
                Text(videosToMove.count == 1 ? (videosToMove.first?.title ?? "Loading...") : "\(videosToMove.count) items selected")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {
                HapticsManager.shared.generate(.medium)
                dismiss()
            }) {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
    }
    
    private func destinationCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color.premiumCardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.premiumCardBorder, lineWidth: 1)
        )
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.premiumCardBorder)
            .frame(height: 1)
            .padding(.leading, 64)
            .padding(.trailing, 16)
    }
    
    private func destinationRow(title: String, subtitle: String?, icon: String, iconColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticsManager.shared.generate(.selection)
            action()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .frame(height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func albumRow(album: PHAssetCollection, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticsManager.shared.generate(.selection)
            action()
        }) {
            HStack(spacing: 16) {
                AlbumThumbnailView(album: album)
                    .frame(width: 32, height: 32)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.localizedTitle ?? "Album")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("\(videoCount(for: album)) Videos")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .frame(height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var isGallerySource: Bool {
        guard !videosToMove.isEmpty else { return false }
        return videosToMove.allSatisfy { $0.asset != nil }
    }
    
    private var isLocalSource: Bool {
        guard !videosToMove.isEmpty else { return false }
        return videosToMove.allSatisfy { $0.asset == nil }
    }
    
    private func videoCount(for collection: PHAssetCollection) -> Int {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        return PHAsset.fetchAssets(in: collection, options: options).count
    }
}

struct AlbumThumbnailView: View {
    let album: PHAssetCollection
    @State private var thumbnail: UIImage?
    
    var body: some View {
        ZStack {
            if let image = thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.homeCardBackground
                Image(systemName: "photo.on.rectangle")
                    .appSecondaryIconStyle(size: 30, color: .homeTextSecondary)
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1
        
        let assets = PHAsset.fetchAssets(in: album, options: options)
        if let firstAsset = assets.firstObject {
            let manager = PHImageManager.default()
            let thumbOptions = PHImageRequestOptions()
            thumbOptions.isNetworkAccessAllowed = true
            thumbOptions.deliveryMode = .opportunistic
            thumbOptions.resizeMode = .exact // Better quality
            
            // Calculate pixel size for retina display (50pt * scale)
            let scale = UIScreen.main.scale
            let targetSize = CGSize(width: 50 * scale, height: 50 * scale)
            
            manager.requestImage(for: firstAsset, targetSize: targetSize, contentMode: .aspectFill, options: thumbOptions) { image, _ in
                if let image = image {
                    self.thumbnail = image
                }
            }
        }
    }
}
