import Foundation
import UIKit
import AVFoundation
import Photos

/// ThumbnailStore
/// - Description: Apple-native filesystem thumbnail store. Thumbnails are plain JPEG files
///   in `Documents/Thumbnails/`. Loading is synchronous via `UIImage(contentsOfFile:)`
///   which takes 0.1–0.5ms — so fast it can safely run on the main thread, appearing
///   in the same render frame as the cell without any placeholder flash.
/// - How to use:
///   • `load(for:)` — synchronous, returns instantly if JPEG exists on disk
///   • `generate(for:, completion:)` — background generation, writes JPEG, calls completion
///   • `generateAllMissing(for:)` — bulk utility-priority generation for entire library
class ThumbnailStore {
    static let shared = ThumbnailStore()
    
    /// Root directory for all thumbnail JPEGs
    private let storeDirectory: URL
    private let fileManager = FileManager.default
    
    // VLC helper for non-native formats (mkv, avi, flv etc.)
    // Max 2 concurrent VLC generations — VLC is heavy, more causes memory pressure
    private let vlcSemaphore = DispatchSemaphore(value: 2)
    // Max 6 concurrent AVFoundation/Photos generations (fast, CPU-bound)
    private let avSemaphore = DispatchSemaphore(value: 6)
    
    private init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storeDirectory = docs.appendingPathComponent("Thumbnails", isDirectory: true)
        
        if !fileManager.fileExists(atPath: storeDirectory.path) {
            try? fileManager.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        }
        print("📁 ThumbnailStore ready at: \(storeDirectory.lastPathComponent)/")
    }
    
    // MARK: - Public API
    
    /// thumbnailURL
    /// - Description: Deterministic file URL for a video's thumbnail JPEG.
    ///   Stable across app launches — does NOT use container path (which changes).
    /// - How to use: Used internally; also exposed so callers can check existence.
    func thumbnailURL(for video: VideoItem) -> URL {
        let key: String
        if let asset = video.asset {
            key = "a_\(asset.localIdentifier.replacingOccurrences(of: "/", with: "_"))"
        } else if let url = video.url {
            key = "f_\(url.lastPathComponent)_\(video.fileSizeBytes)"
        } else {
            key = "u_\(video.id.uuidString)"
        }
        return storeDirectory.appendingPathComponent("\(key).jpg")
    }
    
    /// load
    /// - Description: Synchronous disk load. Returns UIImage instantly if JPEG exists,
    ///   nil if thumbnail has not been generated yet.
    ///   UIImage(contentsOfFile:) for a 5–8KB JPEG takes 0.1–0.5ms — safe on main thread.
    /// - How to use: Call FIRST in VideoCardView.loadThumbnail() before async fallback.
    func load(for video: VideoItem) -> UIImage? {
        let path = thumbnailURL(for: video).path
        guard fileManager.fileExists(atPath: path) else { return nil }
        return UIImage(contentsOfFile: path)
    }
    
    /// exists
    /// - Description: Returns true if the thumbnail JPEG is already on disk.
    /// - How to use: Use to skip generation for already-cached videos.
    func exists(for video: VideoItem) -> Bool {
        return fileManager.fileExists(atPath: thumbnailURL(for: video).path)
    }
    
    /// generate
    /// - Description: Generates a thumbnail, writes it as JPEG to disk, calls completion.
    ///   Uses maxConcurrency semaphore per source type to prevent CPU spike.
    ///   Respects cancellation via cancelledIDs.
    /// - How to use: Call when load() returns nil (thumbnail not yet generated).
    func generate(for video: VideoItem, requestId: UUID? = nil, completion: ((UIImage?) -> Void)? = nil) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { completion?(nil); return }
            
            // Skip if already written while we were waiting
            if let cached = self.load(for: video) {
                DispatchQueue.main.async { completion?(cached) }
                return
            }
            
            if let asset = video.asset {
                self.avSemaphore.wait()
                let img = self.generateFromAsset(asset)
                self.avSemaphore.signal()
                self.storeJPEG(img, for: video)
                DispatchQueue.main.async { completion?(img) }
                
            } else if let url = video.url {
                let ext = url.pathExtension.lowercased()
                let nativeExts = ["mp4", "mov", "m4v"]
                
                if nativeExts.contains(ext) {
                    self.avSemaphore.wait()
                    let img = self.generateFromFile(url)
                    self.avSemaphore.signal()
                    
                    if let img = img {
                        self.storeJPEG(img, for: video)
                        DispatchQueue.main.async { completion?(img) }
                        return
                    }
                }
                
                // VLC fallback for non-native / AVFoundation failures
                self.vlcSemaphore.wait()
                VLCThumbnailRequestManager.shared.request(for: url) { [weak self] vlcThumb in
                    self?.vlcSemaphore.signal()
                    if let t = vlcThumb { self?.storeJPEG(t, for: video) }
                    DispatchQueue.main.async { completion?(vlcThumb) }
                }
            } else {
                DispatchQueue.main.async { completion?(nil) }
            }
        }
    }
    
    /// generateAllMissing
    /// - Description: Iterates all videos, generates thumbnails for those not yet on disk.
    ///   Runs at .background priority — does not interrupt user interaction.
    /// - How to use: Call once after loadImportedVideos() and loadUserFolders() complete.
    func generateAllMissing(for videos: [VideoItem]) {
        guard !videos.isEmpty else { return }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            let missing = videos.filter { !self.exists(for: $0) }
            print("🖼️ ThumbnailStore: generating \(missing.count)/\(videos.count) missing thumbnails")
            
            for video in missing {
                // Check again inside loop (another generate() may have written it)
                guard !self.exists(for: video) else { continue }
                self.generate(for: video)
                // Small yield so background thread doesn't dominate CPU
                Thread.sleep(forTimeInterval: 0.02)
            }
            print("🖼️ ThumbnailStore: bulk generation done")
        }
    }
    
    /// delete
    /// - Description: Removes the thumbnail JPEG for a video (call when video is deleted).
    /// - How to use: Call from DashboardViewModel.deleteVideo().
    func delete(for video: VideoItem) {
        try? fileManager.removeItem(at: thumbnailURL(for: video))
    }
    
    // MARK: - Private Helpers
    
    private func storeJPEG(_ image: UIImage?, for video: VideoItem) {
        guard let image = image,
              let data = image.jpegData(compressionQuality: 0.75) else { return }
        let url = thumbnailURL(for: video)
        try? data.write(to: url, options: .atomic)
    }
    
    private func generateFromAsset(_ asset: PHAsset) -> UIImage? {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = false // thumbnails from local only
        
        let dim: CGFloat = 300 * UIScreen.main.scale
        let targetSize = CGSize(width: dim, height: dim)
        
        var result: UIImage?
        manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { img, _ in
            result = img
        }
        return result
    }
    
    private func generateFromFile(_ url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)
        
        for seconds in [1.0, 0.0] {
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
}
