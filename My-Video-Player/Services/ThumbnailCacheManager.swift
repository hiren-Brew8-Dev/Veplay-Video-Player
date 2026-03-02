import Foundation
import UIKit
import AVFoundation
import Photos
import Kingfisher

/// ThumbnailCacheManager
/// - Description: Manages async video thumbnail loading with:
///   • Max-4 concurrent generations (semaphore) — prevents CPU spike during fast scroll
///   • .utility QoS — below render loop priority, no frame drops
///   • 300-item memory cache — covers ~3 screen-heights of scroll buffer
///   • Cancel-on-disappear — in-flight work is discarded when cell leaves screen
/// - How to use: Call getThumbnail(for:id:completion:) from VideoCardView.onAppear,
///   call cancelRequest(for:) from VideoCardView.onDisappear.
class ThumbnailCacheManager {
    static let shared = ThumbnailCacheManager()
    
    private let cache: ImageCache
    
    // Limits simultaneous thumbnail generation to 4 — prevents CPU spike during fast scroll.
    // Render thread runs at .userInteractive; unlimited .userInitiated tasks starve it.
    private let generationSemaphore = DispatchSemaphore(value: 4)
    
    // Tracks active PHImageRequest IDs for cancellation
    private let activeRequestsLock = NSLock()
    private var activePhotoRequestIDs: [UUID: PHImageRequestID] = [:]
    
    // Tracks cancelled video IDs — generation workers check this before calling completion
    private var cancelledIDs: Set<UUID> = []
    
    private init() {
        cache = ImageCache(name: "VideoThumbnails")
        
        // Memory cache: 300 images (~3 screen-heights of scroll buffer at 3-column grid)
        cache.memoryStorage.config.countLimit = 300
        cache.memoryStorage.config.totalCostLimit = 80 * 1024 * 1024 // 80MB
        
        // Disk cache: 500MB, 30 days
        cache.diskStorage.config.sizeLimit = 500 * 1024 * 1024
        cache.diskStorage.config.expiration = .days(30)
        
        print("📸 ThumbnailCacheManager initialized (semaphore=4, memCache=300)")
    }
    
    // MARK: - Public API
    
    /// getCacheKey
    /// - Description: Stable cache key for a video, survives app container path changes.
    /// - How to use: Used internally and externally (prewarm, etc.)
    func getCacheKey(for video: VideoItem) -> String {
        if let asset = video.asset {
            return "thumb_asset_\(asset.localIdentifier)"
        } else if let url = video.url {
            return "thumb_file_\(url.lastPathComponent)_\(video.fileSizeBytes)_\(Int(video.creationDate.timeIntervalSince1970))"
        } else {
            return "thumb_\(video.id.uuidString)"
        }
    }
    
    /// getThumbnail
    /// - Description: Returns thumbnail async — checks memory/disk first, generates if missing.
    ///   Pass `requestId` (video.id) to support cancellation via cancelRequest(for:).
    /// - How to use: Call from VideoCardView.onAppear with video.id as requestId.
    func getThumbnail(for video: VideoItem, requestId: UUID? = nil, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = getCacheKey(for: video)
        let id = requestId ?? video.id
        
        // Clear any stale cancel flag for this ID (reappearing cell)
        activeRequestsLock.lock()
        cancelledIDs.remove(id)
        activeRequestsLock.unlock()
        
        cache.retrieveImage(forKey: cacheKey) { [weak self] result in
            guard let self = self else { completion(nil); return }
            
            switch result {
            case .success(let value):
                if let image = value.image {
                    // Memory/disk hit — instant return
                    DispatchQueue.main.async { completion(image) }
                } else {
                    self.generateThumbnail(for: video, cacheKey: cacheKey, requestId: id, completion: completion)
                }
            case .failure:
                self.generateThumbnail(for: video, cacheKey: cacheKey, requestId: id, completion: completion)
            }
        }
    }
    
    /// cancelRequest
    /// - Description: Marks a thumbnail request as cancelled. Any in-flight generation for
    ///   this ID will discard its result instead of calling completion. PHImageRequests
    ///   are also cancelled immediately.
    /// - How to use: Call from VideoCardView.onDisappear.
    func cancelRequest(for id: UUID) {
        activeRequestsLock.lock()
        cancelledIDs.insert(id)
        if let pid = activePhotoRequestIDs.removeValue(forKey: id) {
            PHImageManager.default().cancelImageRequest(pid)
        }
        activeRequestsLock.unlock()
    }
    
    /// prewarmCache
    /// - Description: Generates thumbnails for up to 50 videos in background (utility priority).
    /// - How to use: Called after loadImportedVideos / fetchAlbumVideos completes.
    func prewarmCache(for videos: [VideoItem]) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let videosToCache = Array(videos.prefix(50))
            
            for video in videosToCache {
                let cacheKey = self.getCacheKey(for: video)
                self.cache.retrieveImage(forKey: cacheKey) { [weak self] result in
                    guard let self = self else { return }
                    if case .success(let value) = result, value.image == nil {
                        self.getThumbnail(for: video) { _ in }
                    }
                }
                // Small delay so prewarm doesn't consume all semaphore slots at once
                Thread.sleep(forTimeInterval: 0.04)
            }
        }
    }
    
    /// clearCache
    /// - Description: Clears both memory and disk thumbnail caches.
    /// - How to use: Call from Settings if user wants to free storage.
    func clearCache(completion: (() -> Void)? = nil) {
        cache.clearCache {
            print("🗑️ Thumbnail cache cleared")
            completion?()
        }
    }
    
    /// getCacheStats
    /// - Description: Returns (memoryItemCount, diskBytes) for diagnostics.
    /// - How to use: Call from debug/settings screen.
    func getCacheStats(completion: @escaping (UInt, UInt) -> Void) {
        cache.calculateDiskStorageSize { result in
            switch result {
            case .success(let size):
                completion(UInt(self.cache.memoryStorage.config.countLimit), size)
            case .failure:
                completion(0, 0)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// generateThumbnail
    /// - Description: Dispatches thumbnail generation at .utility QoS behind a semaphore(4)
    ///   concurrency cap. Checks cancelledIDs before calling completion to avoid stale renders.
    /// - How to use: Internal — called when cache miss occurs.
    private func generateThumbnail(for video: VideoItem, cacheKey: String, requestId: UUID, completion: @escaping (UIImage?) -> Void) {
        // Use .utility — below render thread priority, won't starve frame delivery
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { completion(nil); return }
            
            // Throttle: block until a slot is free (max 4 concurrent)
            self.generationSemaphore.wait()
            
            // Check if cancelled while waiting for semaphore slot
            self.activeRequestsLock.lock()
            let isCancelled = self.cancelledIDs.contains(requestId)
            self.activeRequestsLock.unlock()
            
            guard !isCancelled else {
                self.generationSemaphore.signal()
                return
            }
            
            defer { self.generationSemaphore.signal() }
            
            if let asset = video.asset {
                self.generateFromAsset(asset, requestId: requestId, cacheKey: cacheKey, completion: completion)
            } else if let url = video.url {
                let ext = url.pathExtension.lowercased()
                let nativeExts = ["mp4", "mov", "m4v"]
                
                if nativeExts.contains(ext), let thumb = self.generateFromFile(url) {
                    self.cache.store(thumb, forKey: cacheKey)
                    self.activeRequestsLock.lock()
                    let cancelled = self.cancelledIDs.contains(requestId)
                    self.activeRequestsLock.unlock()
                    guard !cancelled else { return }
                    DispatchQueue.main.async { completion(thumb) }
                    return
                }
                
                // VLC fallback (non-native or AVFoundation failure)
                VLCThumbnailRequestManager.shared.request(for: url) { [weak self] vlcThumb in
                    guard let self = self else { return }
                    if let t = vlcThumb { self.cache.store(t, forKey: cacheKey) }
                    self.activeRequestsLock.lock()
                    let cancelled = self.cancelledIDs.contains(requestId)
                    self.activeRequestsLock.unlock()
                    guard !cancelled else { return }
                    DispatchQueue.main.async { completion(vlcThumb) }
                }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    /// generateFromAsset
    /// - Description: Requests thumbnail from Photos framework asynchronously (isSynchronous:false).
    ///   Uses a DispatchSemaphore to wait for completion without blocking the thread pool.
    /// - How to use: Internal — called for PHAsset-backed gallery videos.
    private func generateFromAsset(_ asset: PHAsset, requestId: UUID, cacheKey: String, completion: @escaping (UIImage?) -> Void) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false          // non-blocking — semaphore handles wait
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        
        let targetDimension: CGFloat = 150 * UIScreen.main.scale
        let targetSize = CGSize(width: targetDimension * 1.6, height: targetDimension)
        
        let waiter = DispatchSemaphore(value: 0)
        
        let pid = manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { [weak self] image, _ in
            guard let self = self else { waiter.signal(); return }
            if let img = image { self.cache.store(img, forKey: cacheKey) }
            
            self.activeRequestsLock.lock()
            self.activePhotoRequestIDs.removeValue(forKey: requestId)
            let cancelled = self.cancelledIDs.contains(requestId)
            self.activeRequestsLock.unlock()
            
            if !cancelled, let img = image {
                DispatchQueue.main.async { completion(img) }
            }
            waiter.signal()
        }
        
        // Track PID so cancelRequest can cancel it immediately if cell disappears
        activeRequestsLock.lock()
        activePhotoRequestIDs[requestId] = pid
        activeRequestsLock.unlock()
        
        waiter.wait()
    }
    
    /// generateFromFile
    /// - Description: Generates thumbnail from a local file URL using AVAssetImageGenerator.
    ///   Returns nil for non-native formats (MKV, AVI etc.) — VLC handles those.
    /// - How to use: Internal — called for file-URL-backed imported videos.
    private func generateFromFile(_ url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)
        
        let time = CMTime(seconds: 1, preferredTimescale: 600)
        if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
            return UIImage(cgImage: cgImage)
        }
        if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}
