import SwiftUI
import Photos

struct MoveDestinationPickerView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let videosToMove: [VideoItem]
    let isCutOperation: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.sourceURL != viewModel.importedVideosDirectory {
                    Section("Sections") {
                        Button(action: {
                            viewModel.pasteVideos(to: viewModel.importedVideosDirectory)
                            dismiss()
                        }) {
                            Label {
                                Text("Imported Videos")
                            } icon: {
                                Image(systemName: "video.fill")
                                    .appIconStyle(size: AppDesign.Icons.rowIconSize, color: .homeAccent)
                            }
                        }
                    }
                }
                
                Section("Folders") {
                    let otherFolders = viewModel.folders.filter { $0.url != viewModel.sourceURL }
                    if otherFolders.isEmpty {
                        Text("No other folders found").foregroundColor(.homeTextSecondary)
                    } else {
                        ForEach(otherFolders) { folder in
                            if let url = folder.url {
                                Button(action: {
                                    viewModel.pasteVideos(to: url)
                                    dismiss()
                                }) {
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .appIconStyle(size: AppDesign.Icons.rowIconSize, color: .homeTint)
                                        VStack(alignment: .leading) {
                                            Text(folder.name)
                                            Text("\(folder.videos.count) Videos").font(.caption).foregroundColor(.homeTextSecondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section("Gallery Albums") {
                    // Option to just save to Camera Roll (Recents)
                    // Only show if source is NOT the main Photos Library (no albumId and no sourceURL)
                    let otherAlbums = viewModel.allGalleryAlbums.filter { $0.localIdentifier != viewModel.sourceAlbumIdentifier }
                    let selectionHasIncompatible = viewModel.validateVideosForAlbum(videosToMove) != nil
                    
                    if viewModel.sourceAlbumIdentifier != nil || viewModel.sourceURL != nil {
                        Button(action: {
                            viewModel.pasteVideosToGallery(album: nil)
                            dismiss()
                        }) {
                            HStack {
                                Label {
                                    Text("Photos Library")
                                        .foregroundColor(.primary)
                                } icon: {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .appIconStyle(size: AppDesign.Icons.rowIconSize, color: .homeAccent)
                                }
                                Spacer()
                                if selectionHasIncompatible {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    
                    ForEach(otherAlbums, id: \.localIdentifier) { album in
                        Button(action: {
                            viewModel.pasteVideosToGallery(album: album)
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                AlbumThumbnailView(album: album)
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(8)
                                
                                VStack(alignment: .leading) {
                                    Text(album.localizedTitle ?? "Album")
                                        .foregroundColor(.primary)
                                        .font(.system(size: 16, weight: .medium))
                                    Text("\(videoCount(for: album)) Videos")
                                        .font(.caption)
                                        .foregroundColor(.homeTextSecondary)
                                }
                                Spacer()
                                if selectionHasIncompatible {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(isCutOperation ? "Move to..." : "Copy to...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                viewModel.fetchAlbums()
            }
        }
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
