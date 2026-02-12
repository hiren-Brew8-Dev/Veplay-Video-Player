import Foundation
import UIKit
import AVFoundation
import Photos
import Kingfisher

/// Manages video thumbnail caching using Kingfisher
class ThumbnailCacheManager {
    static let shared = ThumbnailCacheManager()
    
    private let cache: ImageCache
    
    private init() {
        // Configure Kingfisher cache
        cache = ImageCache(name: "VideoThumbnails")
        
        // Memory cache: 100 images
        cache.memoryStorage.config.countLimit = 100
        cache.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Disk cache: 500MB, 30 days expiration
        cache.diskStorage.config.sizeLimit = 500 * 1024 * 1024 // 500MB
        cache.diskStorage.config.expiration = .days(30)
        
        print("📸 Kingfisher ThumbnailCache initialized")
    }
    
    // MARK: - Public API
    
    /// Get cache key for a video
    func getCacheKey(for video: VideoItem) -> String {
        if let asset = video.asset {
            return "thumb_asset_\(asset.localIdentifier)"
        } else if let url = video.url {
            return "thumb_file_\(url.lastPathComponent)_\(url.path.hashValue)"
        } else {
            return "thumb_\(video.id.uuidString)"
        }
    }
    
    /// Get thumbnail directly (for SwiftUI)
    func getThumbnail(for video: VideoItem, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = getCacheKey(for: video)
        
        // Check cache first
        cache.retrieveImage(forKey: cacheKey) { [weak self] result in
            guard let self = self else {
                completion(nil)
                return
            }
            
            switch result {
            case .success(let value):
                if let image = value.image {
                    // Found in cache
                    DispatchQueue.main.async {
                        completion(image)
                    }
                } else {
                    // Not in cache, generate it
                    self.generateThumbnail(for: video, cacheKey: cacheKey, completion: completion)
                }
            case .failure:
                // Cache error, try to generate
                self.generateThumbnail(for: video, cacheKey: cacheKey, completion: completion)
            }
        }
    }
    
    /// Pre-warm cache for multiple videos
    func prewarmCache(for videos: [VideoItem]) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            // Limit to first 50 videos to avoid overwhelming the system
            let videosToCache = Array(videos.prefix(50))
            
            for video in videosToCache {
                let cacheKey = self.getCacheKey(for: video)
                
                // Try to retrieve from cache (non-blocking)
                self.cache.retrieveImage(forKey: cacheKey) { [weak self] result in
                    guard let self = self else { return }
                    
                    // If not in cache, generate it
                    if case .success(let value) = result, value.image == nil {
                        self.generateThumbnail(for: video, cacheKey: cacheKey) { _ in
                            // Thumbnail generated and cached
                        }
                    }
                }
                
                // Small delay between requests to avoid overwhelming the system
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
    }
    
    /// Clear cache
    func clearCache(completion: (() -> Void)? = nil) {
        cache.clearCache {
            print("🗑️ Thumbnail cache cleared")
            completion?()
        }
    }
    
    /// Get cache statistics
    func getCacheStats(completion: @escaping (UInt, UInt) -> Void) {
        cache.calculateDiskStorageSize { result in
            switch result {
            case .success(let size):
                let memoryCount = self.cache.memoryStorage.config.countLimit
                completion(UInt(memoryCount), size)
            case .failure:
                completion(0, 0)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func generateThumbnail(for video: VideoItem, cacheKey: String, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            if let asset = video.asset {
                let thumbnail = self.generateThumbnailFromAsset(asset)
                if let thumb = thumbnail {
                    self.cache.store(thumb, forKey: cacheKey)
                }
                DispatchQueue.main.async {
                    completion(thumbnail)
                }
            } else if let url = video.url {
                // Prioritize VLC for non-native legacy formats (mpeg, avi, mkv, flv, rm, etc.)
                // to avoid black frames or failures from AVAssetImageGenerator.
                let ext = url.pathExtension.lowercased()
                let nativeExtensions = ["mp4", "mov", "m4v"]
                
                if nativeExtensions.contains(ext) {
                    if let thumb = self.generateThumbnailFromFile(url) {
                        self.cache.store(thumb, forKey: cacheKey)
                        DispatchQueue.main.async { completion(thumb) }
                        return
                    }
                }
                
                // Fallback or Direct VLC path
                VLCThumbnailRequestManager.shared.request(for: url) { vlcThumb in
                    if let vlcThumb = vlcThumb {
                        self.cache.store(vlcThumb, forKey: cacheKey)
                    }
                    DispatchQueue.main.async {
                        completion(vlcThumb)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    private func generateThumbnailFromAsset(_ asset: PHAsset) -> UIImage? {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact // Better quality
        options.isNetworkAccessAllowed = true
        
        // Increase target size slightly for modern screens
        let targetDimension: CGFloat = 150 * UIScreen.main.scale
        let targetSize = CGSize(width: targetDimension * 1.6, height: targetDimension)
        
        var resultImage: UIImage?
        
        manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
            resultImage = image
        }
        
        return resultImage
    }
    
    private func generateThumbnailFromFile(_ url: URL) -> UIImage? {
        // First try standard AVFoundation
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400) // Slightly larger for better quality
        
        let time = CMTime(seconds: 1, preferredTimescale: 600)
        
        do {
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            // AVFoundation failed. This is typical for MKV/FLV etc.
            // For MKV, AVAsset might still report duration but no video tracks accessible via generator.
            
            // Fallback attempt at 0 seconds
            do {
                let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
                return UIImage(cgImage: cgImage)
            } catch {
                // Both standard attempts failed. 
                // Return nil so the UI can show a placeholder or we can implement 
                // a heavier VLC-based thumbnailer if absolutely necessary.
                print("⚠️ Thumbnail generation failed for: \(url.lastPathComponent)")
                return nil
            }
        }
    }
}
