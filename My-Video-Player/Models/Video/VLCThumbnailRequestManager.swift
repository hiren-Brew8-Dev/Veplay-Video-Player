import Foundation
import UIKit
import MobileVLCKit

class VLCThumbnailRequestManager {
    static let shared = VLCThumbnailRequestManager()
    
    // Keep strong references to helpers while they work
    private var activeHelpers: [UUID: VLCThumbnailHelper] = [:]
    private let queue = DispatchQueue(label: "com.videoplayer.vlc_thumbs")
    
    func request(for url: URL, completion: @escaping (UIImage?) -> Void) {
        let id = UUID()
        let helper = VLCThumbnailHelper()
        
        queue.async {
            self.activeHelpers[id] = helper
        }
        
        helper.generate(for: url) { [weak self] image in
            completion(image)
            self?.queue.async {
                self?.activeHelpers.removeValue(forKey: id)
            }
        }
    }
}
