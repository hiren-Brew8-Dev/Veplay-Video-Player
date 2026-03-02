import Foundation
import UIKit
import MobileVLCKit

class VLCThumbnailRequestManager {
    static let shared = VLCThumbnailRequestManager()

    // Keep strong references to helpers while they work
    private var activeHelpers: [UUID: VLCThumbnailHelper] = [:]
    private let helperQueue = DispatchQueue(label: "com.videoplayer.vlc_thumbs")

    // Limit concurrent VLC thumbnail generation to prevent thread-pool exhaustion.
    // VLCThumbnailHelper blocks a thread with polling; too many concurrent ones
    // saturate the GCD thread pool and cause app-wide lag.
    private let concurrencySemaphore = DispatchSemaphore(value: 3)

    // Dedicated serial queue for VLC work — avoids polluting the global thread pool.
    private let workQueue = DispatchQueue(label: "com.videoplayer.vlc_thumb_work", qos: .utility, attributes: .concurrent)

    func request(for url: URL, completion: @escaping (UIImage?) -> Void) {
        let id = UUID()
        let helper = VLCThumbnailHelper()

        helperQueue.async {
            self.activeHelpers[id] = helper
        }

        // Run on dedicated queue with concurrency limit.
        workQueue.async { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }
            // Throttle: wait until a slot is available (max 3 concurrent).
            self.concurrencySemaphore.wait()
            defer { self.concurrencySemaphore.signal() }

            helper.generate(for: url) { image in
                completion(image)
                self.helperQueue.async {
                    self.activeHelpers.removeValue(forKey: id)
                }
            }
        }
    }
}
