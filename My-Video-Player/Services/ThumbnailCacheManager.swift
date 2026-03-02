import Foundation
import UIKit
import Photos

/// ThumbnailCacheManager
/// - Description: Two-level instant thumbnail cache:
///   L1 — NSCache<NSString, UIImage> — microsecond hits, auto-evicts on memory warning
///   L2 — ThumbnailStore — JPEG files on disk, UIImage(contentsOfFile:) ≈ 0.3ms
///   getThumbnailSync() checks both levels synchronously — returns in the SAME render
///   frame as onAppear with zero placeholder flash.
/// - How to use:
///   1. Call `getThumbnailSync(for:)` first — if non-nil, set @State directly, done.
///   2. If nil, call `getThumbnail(for:, requestId:, completion:)` for async generation.
///   3. Call `cancelRequest(for:)` from onDisappear.
class ThumbnailCacheManager {
    static let shared = ThumbnailCacheManager()

    // L1: NSCache — native Apple cache, thread-safe, auto-evicts under memory pressure
    private let memoryCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 300          // ~3 screen-heights of scroll buffer
        c.totalCostLimit = 80 * 1024 * 1024 // 80MB
        return c
    }()

    private let lock = NSLock()
    private var cancelledIDs: Set<UUID> = []

    private init() {}

    // MARK: - Public API

    /// getThumbnailSync
    /// - Description: Synchronous L1+L2 check. Safe on main thread — total time <1ms.
    ///   Returns nil only if thumbnail has never been generated.
    /// - How to use: Call as the FIRST step in VideoCardView.loadThumbnail().
    func getThumbnailSync(for video: VideoItem) -> UIImage? {
        let key = cacheKey(for: video) as NSString

        // L1: NSCache (microseconds)
        if let cached = memoryCache.object(forKey: key) { return cached }

        // L2: Disk JPEG (0.3ms typical)
        if let diskImage = ThumbnailStore.shared.load(for: video) {
            memoryCache.setObject(diskImage, forKey: key)
            return diskImage
        }
        return nil
    }

    /// getThumbnail
    /// - Description: Async fallback — called only when getThumbnailSync returns nil.
    ///   Generates via ThumbnailStore, caches in NSCache L1, calls completion on main.
    /// - How to use: Call from VideoCardView when getThumbnailSync returned nil.
    func getThumbnail(for video: VideoItem, requestId: UUID? = nil, completion: @escaping (UIImage?) -> Void) {
        let id = requestId ?? video.id
        let key = cacheKey(for: video) as NSString

        lock.lock(); cancelledIDs.remove(id); lock.unlock()

        // Re-check sync — another cell may have generated it since our first check
        if let instant = getThumbnailSync(for: video) {
            completion(instant); return
        }

        ThumbnailStore.shared.generate(for: video, requestId: id) { [weak self] image in
            guard let self = self else { return }
            self.lock.lock()
            let cancelled = self.cancelledIDs.contains(id)
            self.lock.unlock()
            guard !cancelled, let img = image else { return }
            self.memoryCache.setObject(img, forKey: key)
            completion(img)
        }
    }

    /// cancelRequest
    /// - Description: Marks a request cancelled so stale async completions are discarded.
    /// - How to use: Call from VideoCardView.onDisappear.
    func cancelRequest(for id: UUID) {
        lock.lock(); cancelledIDs.insert(id); lock.unlock()
    }

    /// prewarmCache
    /// - Description: Delegates to ThumbnailStore.generateAllMissing at .background priority.
    /// - How to use: Call after initial video load completes.
    func prewarmCache(for videos: [VideoItem]) {
        ThumbnailStore.shared.generateAllMissing(for: videos)
    }

    /// clearMemoryCache
    /// - Description: Evicts NSCache layer (disk JPEGs are kept).
    /// - How to use: Call on memory warning or from Settings.
    func clearCache(completion: (() -> Void)? = nil) {
        memoryCache.removeAllObjects()
        completion?()
    }

    // MARK: - Private

    private func cacheKey(for video: VideoItem) -> String {
        ThumbnailStore.shared.thumbnailURL(for: video).lastPathComponent
    }
}
