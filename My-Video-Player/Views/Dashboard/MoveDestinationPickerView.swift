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
                if isLocalSource {
                    Section("Sections") {
                        Button(action: {
                            viewModel.pasteVideos(to: viewModel.importedVideosDirectory)
                            dismiss()
                        }) {
                            Label("Imported Videos", systemImage: "video.fill")
                        }
                    }
                    
                    Section("Folders") {
                        if viewModel.folders.isEmpty {
                            Text("No folders found").foregroundColor(.gray)
                        } else {
                            ForEach(viewModel.folders) { folder in
                                if let url = folder.url {
                                    Button(action: {
                                        viewModel.pasteVideos(to: url)
                                        dismiss()
                                    }) {
                                        HStack {
                                            Image(systemName: "folder.fill")
                                                .foregroundColor(.blue)
                                            VStack(alignment: .leading) {
                                                Text(folder.name)
                                                Text("\(folder.videos.count) Videos").font(.caption).foregroundColor(.gray)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                if isGallerySource {
                    Section("Gallery Albums") {
                        // Option to just save to Camera Roll (Recents)
                        Button(action: {
                            viewModel.pasteVideosToGallery(album: nil)
                            dismiss()
                        }) {
                            Label("Photos Library", systemImage: "photo.on.rectangle.angled")
                                .foregroundColor(.primary)
                        }
                        
                        ForEach(viewModel.allGalleryAlbums, id: \.localIdentifier) { album in
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
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Move to...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
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
                Color.gray.opacity(0.3)
                Image(systemName: "photo.on.rectangle")
                    .foregroundColor(.gray)
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
            
            manager.requestImage(for: firstAsset, targetSize: CGSize(width: 100, height: 100), contentMode: .aspectFill, options: thumbOptions) { image, _ in
                if let image = image {
                    self.thumbnail = image
                }
            }
        }
    }
}
