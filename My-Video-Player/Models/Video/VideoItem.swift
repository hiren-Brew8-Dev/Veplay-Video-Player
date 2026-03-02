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
    var creationDate: Date // Actual video creation date (from metadata)
    var importDate: Date   // When it was imported into the app
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
    
    init(id: UUID = UUID(), asset: PHAsset? = nil, title: String, duration: TimeInterval, creationDate: Date, importDate: Date? = nil, fileSizeBytes: Int64, thumbnailPath: URL? = nil, url: URL? = nil) {
        self.id = id
        self.asset = asset
        self.title = title
        self.duration = duration
        self.creationDate = creationDate
        self.importDate = importDate ?? creationDate
        self.fileSizeBytes = fileSizeBytes
        self.thumbnailPath = thumbnailPath
        self.url = url
    }
    
    // Static formatters — allocating DateComponentsFormatter is expensive; reuse them.
    private static let shortDurationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.minute, .second]
        f.unitsStyle = .positional
        f.zeroFormattingBehavior = .pad
        return f
    }()

    private static let longDurationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute, .second]
        f.unitsStyle = .positional
        f.zeroFormattingBehavior = .pad
        return f
    }()

    var formattedDuration: String {
        let formatter = duration >= 3600 ? Self.longDurationFormatter : Self.shortDurationFormatter
        return formatter.string(from: duration) ?? "00:00"
    }
    
    var fullNameWithExtension: String {
        let baseName = title
        let ext = url?.pathExtension.lowercased() ?? ""
        
        if ext.isEmpty {
            return baseName
        }
        
        // If title already ends with extension, don't duplicate it
        if baseName.lowercased().hasSuffix(".\(ext)") {
            return baseName
        }
        
        return "\(baseName).\(ext)"
    }

    static func == (lhs: VideoItem, rhs: VideoItem) -> Bool {
        // Optimized comparison for performance
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.duration == rhs.duration &&
               lhs.thumbnailPath == rhs.thumbnailPath &&
               lhs.fileSizeBytes == rhs.fileSizeBytes
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension String {
    func withExtension(_ ext: String) -> String {
        if ext.isEmpty { return self }
        
        // If string already ends with extension, return as is
        if self.lowercased().hasSuffix(".\(ext.lowercased())") {
            return self
        }
        
        return "\(self).\(ext)"
    }
}

// Global Helper for VLC Thumbnails
class VLCThumbnailHelper: NSObject, VLCMediaThumbnailerDelegate {
    private var thumbnailer: VLCMediaThumbnailer?
    private var completion: ((UIImage?) -> Void)?
    
    func generate(for url: URL, completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        let media = VLCMedia(url: url)
        // Wait for media to be indexed to ensure we can get a thumbnail at a specific position.
        // Reduced timeout from 5000ms to 3000ms and poll count from 15 to 8 (max 0.8s wait)
        // to prevent long thread blocking.
        media.parse(options: .fetchLocal, timeout: 3000)
        var pollCount = 0
        while media.length.intValue <= 0 && pollCount < 8 {
            Thread.sleep(forTimeInterval: 0.1)
            pollCount += 1
        }

        self.thumbnailer = VLCMediaThumbnailer(media: media, andDelegate: self)
        self.thumbnailer?.snapshotPosition = 0.1
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
