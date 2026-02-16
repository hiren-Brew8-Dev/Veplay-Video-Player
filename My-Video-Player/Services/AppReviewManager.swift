//
//  AppReviewManager.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 30/12/25.
//

import UIKit
import StoreKit

enum AppReviewManager {

    // MARK: - Keys
    private static let reviewAttemptKey = "review_attempt_count"

    // MARK: - Storage
    private static let userDefaults = UserDefaults.standard
    private static let iCloudStore = NSUbiquitousKeyValueStore.default

    // MARK: - Public API
    static func submitReview(isShowAppleReviewScreen : Bool = false) {
        
        let attempts = currentAttempts()

        // Limit to 2 system prompts (global via iCloud)
        if attempts < 3 {
            requestSystemReview()
            saveAttempts(attempts + 1)
        } else {
            if isShowAppleReviewScreen {
                openAppStoreReview()
            }
        }
        
    }

    // MARK: - Attempts Handling
    private static func currentAttempts() -> Int {
        if iCloudStore.object(forKey: reviewAttemptKey) != nil {
            return Int(iCloudStore.longLong(forKey: reviewAttemptKey))
        } else {
            let local = userDefaults.integer(forKey: reviewAttemptKey)
            iCloudStore.set(Int64(local), forKey: reviewAttemptKey)
            iCloudStore.synchronize()
            return local
        }
    }

    private static func saveAttempts(_ value: Int) {
        userDefaults.set(value, forKey: reviewAttemptKey)
        iCloudStore.set(Int64(value), forKey: reviewAttemptKey)
        iCloudStore.synchronize()
    }

    // MARK: - Review Actions
    private static func requestSystemReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }

        SKStoreReviewController.requestReview(in: scene)
    }

    private static func openAppStoreReview() {
        let appID = Global.shared.appID
        let urlString = "https://apps.apple.com/app/id\(appID)?action=write-review"

        guard let url = URL(string: urlString),
              UIApplication.shared.canOpenURL(url) else { return }

        UIApplication.shared.open(url)
    }

    // MARK: - Testing
    static func resetForTesting() {
        userDefaults.removeObject(forKey: reviewAttemptKey)
        iCloudStore.removeObject(forKey: reviewAttemptKey)
        iCloudStore.synchronize()
    }
}
