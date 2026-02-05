import Foundation
import Photos
import SwiftUI
import Combine

class VideoFetcher: ObservableObject {
    @Published var permissionStatus: PHAuthorizationStatus = .notDetermined
    
    func requestPermission() {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                self.permissionStatus = status
            }
        }
    }
    
    func fetchVideos() -> [VideoItem] {
        guard PHPhotoLibrary.authorizationStatus() == .authorized || PHPhotoLibrary.authorizationStatus() == .limited else {
            return generateMockVideos()
        }
        
        // 1. Fetch All Videos (Camera Roll / Recent)
        let allVideos = fetchAssets(in: PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumVideos, options: nil).firstObject)
        
        // Use a Set to avoid duplicates if we merge logic later, but for "All Videos" we just want the smart album or a predicate fetch
        if !allVideos.isEmpty {
            return allVideos
        } else {
            // Fallback: Fetch all assets with mediaType = video
            return fetchAllVideoAssets()
        }
    }
    
    // Fetch folders (Smart Albums + User Albums)
    func fetchAlbums() -> [Folder] {
        guard PHPhotoLibrary.authorizationStatus() == .authorized || PHPhotoLibrary.authorizationStatus() == .limited else {
            return []
        }
        
        var folders: [Folder] = []
        
        // 1. Smart Albums (Recent, Favorites, etc.)
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
        smartAlbums.enumerateObjects { collection, _, _ in
            let videos = self.fetchAssets(in: collection)
            if !videos.isEmpty {
                folders.append(Folder(name: collection.localizedTitle ?? "Album", videoCount: videos.count, videos: videos))
            }
        }
        
        // 2. User Collections (WhatsApp, Instagram, Created Albums)
        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        userAlbums.enumerateObjects { collection, _, _ in
            let videos = self.fetchAssets(in: collection)
            if !videos.isEmpty {
                folders.append(Folder(name: collection.localizedTitle ?? "Album", videoCount: videos.count, videos: videos))
            }
        }
        
        return folders
    }
    
    private func fetchAllVideoAssets() -> [VideoItem] {
        var videos: [VideoItem] = []
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        let assets = PHAsset.fetchAssets(with: fetchOptions)
        assets.enumerateObjects { asset, _, _ in
            videos.append(self.convertAssetToVideoItem(asset))
        }
        return videos
    }

    private func fetchAssets(in collection: PHAssetCollection?) -> [VideoItem] {
        guard let collection = collection else { return [] }
        var videos: [VideoItem] = []
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        
        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        assets.enumerateObjects { asset, _, _ in
            videos.append(self.convertAssetToVideoItem(asset))
        }
        return videos
    }
    
    private func convertAssetToVideoItem(_ asset: PHAsset) -> VideoItem {
        // We defer filename/title resolution to the background fetch mechanism (DashboardViewModel.loadTitle)
        // to avoid "Missing prefetched properties" errors and main thread lag.
        
        return VideoItem(
            id: UUID(),
            asset: asset,
            title: VideoItem.titlePlaceholder,
            duration: asset.duration,
            creationDate: asset.creationDate ?? Date(),
            fileSizeBytes: 0,
            thumbnailPath: nil,
            url: nil
        )
    }
    
    // Made public/accessible for previews
    // Clean mock logic removed for production
    func generateMockVideos() -> [VideoItem] {
        return []
    }
    
    func fetchThumbnail(for asset: PHAsset?, completion: @escaping (UIImage?) -> Void) {
        guard let asset = asset else {
            completion(nil)
            return
        }
        
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .fastFormat
        
        manager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: options) { image, _ in
            completion(image)
        }
    }
}
