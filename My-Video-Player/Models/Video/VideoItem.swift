import Foundation
import CoreGraphics
import Photos
import UIKit
import MobileVLCKit

struct VideoItem: Identifiable, Hashable {
    let id: UUID
    let asset: PHAsset?
    var title: String
    var duration: TimeInterval
    let creationDate: Date
    let fileSizeBytes: Int64
    var thumbnailPath: URL?
    let url: URL?
    
    static let titlePlaceholder = "Fetching Title..."
    
    var isAlbumCompatible: Bool {
        // iOS Photos Library (PHAsset) primarily supports mp4, mov, m4v.
        // Others like mkv, avi, webm are not supported for saving to library.
        if asset != nil { return true } // Already in gallery
        guard let url = url else { return false }
        let ext = url.pathExtension.lowercased()
        let supported = ["mp4", "mov", "m4v"]
        return supported.contains(ext)
    }
    
    var isGenericTitle: Bool {
        let t = title.lowercased()
        let genericPatterns = ["img_", "dsc_", "mov_", "pxl_", "video_", "movie", "video"]
        
        if title == VideoItem.titlePlaceholder || title.isEmpty {
            return true
        }
        
        for pattern in genericPatterns {
            if t.starts(with: pattern) || t == pattern {
                return true
            }
        }
        
        return false
    }
    
    init(id: UUID = UUID(), asset: PHAsset? = nil, title: String, duration: TimeInterval, creationDate: Date, fileSizeBytes: Int64, thumbnailPath: URL? = nil, url: URL? = nil) {
        self.id = id
        self.asset = asset
        self.title = title
        self.duration = duration
        self.creationDate = creationDate
        self.fileSizeBytes = fileSizeBytes
        self.thumbnailPath = thumbnailPath
        self.url = url
    }
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00"
    }
    
    var truncatedTitle: String {
        let baseName = title
        let ext = url?.pathExtension.lowercased() ?? ""
        
        if ext.isEmpty {
            return baseName.count > 15 ? String(baseName.prefix(12)) + "..." : baseName
        }
        
        let fullDisplayName = baseName + "." + ext
        if fullDisplayName.count <= 16 {
            return fullDisplayName
        }
        
        let prefix = String(baseName.prefix(min(baseName.count, 8)))
        return "\(prefix)...\(ext)"
    }
}

extension String {
    func truncated(ext: String) -> String {
        if ext.isEmpty {
            return self.count > 15 ? String(self.prefix(12)) + "..." : self
        }
        
        let fullDisplayName = self + "." + ext
        if fullDisplayName.count <= 16 {
            return fullDisplayName
        }
        
        let prefix = String(self.prefix(min(self.count, 8)))
        return "\(prefix)...\(ext)"
    }
}

// Global Helper for VLC Thumbnails
class VLCThumbnailHelper: NSObject, VLCMediaThumbnailerDelegate {
    private var thumbnailer: VLCMediaThumbnailer?
    private var completion: ((UIImage?) -> Void)?
    
    func generate(for url: URL, completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        let media = VLCMedia(url: url)
        // Wait for media to be indexed to ensure we can get a thumbnail at a specific position
        media.parse(options: .fetchLocal, timeout: 5000)
        var pollCount = 0
        while media.length.intValue <= 0 && pollCount < 15 {
            Thread.sleep(forTimeInterval: 0.1)
            pollCount += 1
        }
        
        self.thumbnailer = VLCMediaThumbnailer(media: media, andDelegate: self)
        self.thumbnailer?.snapshotPosition = 0.1 // Try 10% into the video instead of just the start
        self.thumbnailer?.fetchThumbnail()
    }
    
    func mediaThumbnailer(_ mediaThumbnailer: VLCMediaThumbnailer, didFinishThumbnail thumbnail: CGImage) {
        let image = UIImage(cgImage: thumbnail)
        DispatchQueue.main.async {
            self.completion?(image)
            self.completion = nil
            self.thumbnailer = nil
        }
    }
    
    func mediaThumbnailerDidTimeOut(_ mediaThumbnailer: VLCMediaThumbnailer) {
        DispatchQueue.main.async {
            print("VLC Thumbnail Timed Out")
            self.completion?(nil)
            self.completion = nil
            self.thumbnailer = nil
        }
    }
}
