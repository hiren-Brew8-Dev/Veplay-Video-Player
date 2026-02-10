import SwiftUI
import Photos

struct MoveDestinationPickerView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let videosToMove: [VideoItem]
    let isCutOperation: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            Capsule()
                .fill(Color.homeTextSecondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)
            
            // Header
            HStack {
                StandardIconButton(icon: "xmark", action: {
                    dismiss()
                })
                
                Spacer()
                
                Text(isCutOperation ? "Move to..." : "Copy to...")
                    .font(.headline)
                    .foregroundColor(.homeTextPrimary)
                
                Spacer()
                
                // Invisible spacer to balance
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.clear)
                    .padding(10)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            ScrollView {
                VStack(spacing: 0) {
                    // Imported Videos Section
                    if viewModel.sourceURL != viewModel.importedVideosDirectory {
                        sectionHeader("Locations")
                        
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
                        
                        Divider().background(Color.sheetDivider).padding(.leading, 56)
                    }
                    
                    // Folders Section
                    let otherFolders = viewModel.folders.filter { $0.url != viewModel.sourceURL }
                    if !otherFolders.isEmpty {
                        sectionHeader("Folders")
                        
                        ForEach(otherFolders) { folder in
                            if let url = folder.url {
                                destinationRow(
                                    title: folder.name,
                                    subtitle: "\(folder.videos.count) Videos",
                                    icon: "folder.fill",
                                    iconColor: .homeTint,
                                    action: {
                                        viewModel.pasteVideos(to: url)
                                        dismiss()
                                    }
                                )
                                
                                if folder.id != otherFolders.last?.id {
                                    Divider().background(Color.sheetDivider).padding(.leading, 56)
                                }
                            }
                        }
                    } else if viewModel.sourceURL == viewModel.importedVideosDirectory {
                         // If no other folders and we are in imported videos, maybe show an empty state or just skip
                    }
                    
                    // Gallery Albums Section
                    let otherAlbums = viewModel.allGalleryAlbums.filter { $0.localIdentifier != viewModel.sourceAlbumIdentifier }
                    let selectionHasIncompatible = viewModel.validateVideosForAlbum(videosToMove) != nil
                    
                    sectionHeader("Gallery Albums")
                    
                    // Photos Library Row
                    if viewModel.sourceAlbumIdentifier != nil || viewModel.sourceURL != nil {
                       
                        
                        if !otherAlbums.isEmpty {
                            Divider().background(Color.sheetDivider).padding(.leading, 56)
                        }
                    }
                    
                    // Specific Albums
                    ForEach(Array(otherAlbums.enumerated()), id: \.element.localIdentifier) { index, album in
                        Button(action: {
                            viewModel.pasteVideosToGallery(album: album)
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                AlbumThumbnailView(album: album)
                                    .frame(width: 44, height: 44)
                                    .cornerRadius(8)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(album.localizedTitle ?? "Album")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Text("\(videoCount(for: album)) Videos")
                                        .font(.system(size: 12))
                                        .foregroundColor(.homeTextSecondary)
                                }
                                
                                Spacer()
                                
                                if selectionHasIncompatible {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.homeTextSecondary.opacity(0.5))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 64)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        if index < otherAlbums.count - 1 {
                            Divider().background(Color.sheetDivider).padding(.leading, 72)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .background(Color.sheetBackground)
        .onAppear {
            viewModel.fetchAlbums()
        }
    }
    
    // UI Helpers
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.homeTextSecondary)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 8)
            Spacer()
        }
    }
    
    private func destinationRow(title: String, subtitle: String?, icon: String, iconColor: Color, isWarning: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.homeTextPrimary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(isWarning ? .red : .homeTextSecondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.homeTextSecondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
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
