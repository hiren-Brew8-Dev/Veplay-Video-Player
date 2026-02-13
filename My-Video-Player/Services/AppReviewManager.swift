//
//  AppReviewManager.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 30/12/25.
//

import Foundation
import UIKit
import StoreKit
import Combine

class AppReviewManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = AppReviewManager()
    
    // MARK: - Keys
    private static let reviewAttemptKey = "review_attempt_count"
    private static let isRatingCardHiddenKey = "isRatingCardHidden"
    private static let snoozeDateKey = "ratingCardSnoozeDate"
    
    // MARK: - Storage
    private let userDefaults = UserDefaults.standard
    private let iCloudStore = NSUbiquitousKeyValueStore.default
    
    @Published var isRatingCardHidden: Bool = false
    
    private init() {
        checkSnoozeStatus()
    }
    
    private func checkSnoozeStatus() {
        // Check if permanently hidden
        if userDefaults.bool(forKey: AppReviewManager.isRatingCardHiddenKey) {
            isRatingCardHidden = true
            return
        }
        
        // Check if snoozed
        if let snoozeDate = userDefaults.object(forKey: AppReviewManager.snoozeDateKey) as? Date {
            if Date() < snoozeDate {
                isRatingCardHidden = true
            } else {
                // Snooze expired
                isRatingCardHidden = false
                userDefaults.removeObject(forKey: AppReviewManager.snoozeDateKey)
            }
        } else {
            isRatingCardHidden = false
        }
    }
    
    // MARK: - Public API
    func submitReview(isShowAppleReviewScreen: Bool = false) {
        let attempts = currentAttempts()
        
        // Limit to 3 system prompts (global via iCloud)
        if attempts < 3 {
            requestSystemReview()
            saveAttempts(attempts + 1)
        } else {
            if isShowAppleReviewScreen {
                openAppStoreReview()
            }
        }
    }
    
    func snoozeRatingCard() {
        // Calculate tomorrow at 00:00
        let calendar = Calendar.current
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
           let nextMidnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) {
            
            userDefaults.set(nextMidnight, forKey: AppReviewManager.snoozeDateKey)
            isRatingCardHidden = true
        }
    }
    
    func hideRatingCardForever() {
        userDefaults.set(true, forKey: AppReviewManager.isRatingCardHiddenKey)
        // Clear any existing snooze since it's now hidden forever
        userDefaults.removeObject(forKey: AppReviewManager.snoozeDateKey)
        isRatingCardHidden = true
    }
    
    func ratingPopupViewViewedSet() {
        hideRatingCardForever()
    }
    
    // MARK: - Attempts Handling
    private func currentAttempts() -> Int {
        if iCloudStore.object(forKey: AppReviewManager.reviewAttemptKey) != nil {
            return Int(iCloudStore.longLong(forKey: AppReviewManager.reviewAttemptKey))
        } else {
            let local = userDefaults.integer(forKey: AppReviewManager.reviewAttemptKey)
            iCloudStore.set(Int64(local), forKey: AppReviewManager.reviewAttemptKey)
            return local
        }
    }
    
    private func saveAttempts(_ value: Int) {
        userDefaults.set(value, forKey: AppReviewManager.reviewAttemptKey)
        iCloudStore.set(Int64(value), forKey: AppReviewManager.reviewAttemptKey)
        iCloudStore.synchronize()
    }
    
    // MARK: - Review Actions
    private func requestSystemReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }
        
        SKStoreReviewController.requestReview(in: scene)
    }
    
    func openAppStoreReview() {
        let appID = Global.shared.appID
        let urlString = "https://apps.apple.com/app/id\(appID)?action=write-review"
        
        guard let url = URL(string: urlString),
              UIApplication.shared.canOpenURL(url) else { return }
        
        UIApplication.shared.open(url)
    }
    
    // MARK: - Testing
    func resetForTesting() {
        userDefaults.removeObject(forKey: AppReviewManager.reviewAttemptKey)
        userDefaults.removeObject(forKey: AppReviewManager.isRatingCardHiddenKey)
        userDefaults.removeObject(forKey: AppReviewManager.snoozeDateKey)
        iCloudStore.removeObject(forKey: AppReviewManager.reviewAttemptKey)
        iCloudStore.synchronize()
        isRatingCardHidden = false
    }
}
