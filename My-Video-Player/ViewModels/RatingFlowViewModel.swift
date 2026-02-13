//
//  RatingFlowViewModel.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 13/01/26.
//

import Foundation
import Combine
import UIKit

final class RatingFlowViewModel: ObservableObject {

    // MARK: - Singleton
    static let shared = RatingFlowViewModel()
    private init() {
        loadValue()
        observeICloudChanges()
    }

    // MARK: - Keys
    private let ratingKey = "is_already_show_rating_popup"
    private let snoozeDateKey = "ratingFlowSnoozeDate"

    // MARK: - Storage
    private let userDefaults = UserDefaults.standard
    private let iCloudStore = NSUbiquitousKeyValueStore.default

    // MARK: - Published State
    @Published private(set) var isAlreadyShown: Bool = false
    
    @Published var showUnlockCategoryPopup: Bool = false
    @Published var showCustomRatingPopup: Bool = false
    

    // MARK: - Load
    func loadValue() {
        // Prefer iCloud value if exists
        if iCloudStore.object(forKey: ratingKey) != nil {
            let value = iCloudStore.bool(forKey: ratingKey)
            updateLocal(value)
        } else {
            let localValue = userDefaults.bool(forKey: ratingKey)
            updateCloud(localValue)
            isAlreadyShown = localValue
        }
    }

    // MARK: - Set
    func setValue(_ value: Bool) {
        updateLocal(value)
        updateCloud(value)
        isAlreadyShown = value
        // If set to true (forever), clear snooze
        if value {
             userDefaults.removeObject(forKey: snoozeDateKey)
        }
    }
    
    func snoozeRatingPopup() {
        let calendar = Calendar.current
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
           let nextMidnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) {
            
            userDefaults.set(nextMidnight, forKey: snoozeDateKey)
            customRatingDismiss()
        }
    }
    
    var isSnoozed: Bool {
        if let snoozeDate = userDefaults.object(forKey: snoozeDateKey) as? Date {
            if Date() < snoozeDate {
                return true
            } else {
                userDefaults.removeObject(forKey: snoozeDateKey)
                return false
            }
        }
        return false
    }

    // MARK: - Reset
    
    func resetValue() {
        updateLocal(false)
        updateCloud(false)
        isAlreadyShown = false
        userDefaults.removeObject(forKey: snoozeDateKey)
        AppReviewManager.shared.resetForTesting()
    }

    // MARK: - Private Helpers
    private func updateLocal(_ value: Bool) {
        userDefaults.set(value, forKey: ratingKey)
        isAlreadyShown = value
    }

    private func updateCloud(_ value: Bool) {
        iCloudStore.set(value, forKey: ratingKey)
        iCloudStore.synchronize()
    }

    // MARK: - iCloud Sync Listener
    private func observeICloudChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )
    }

    @objc private func iCloudDidChange(_ notification: Notification) {
        let value = iCloudStore.bool(forKey: ratingKey)
        updateLocal(value)
        DispatchQueue.main.async {
            self.isAlreadyShown = value
        }
    }
}

extension RatingFlowViewModel {

    // MARK: - Submit Review (button tap)
    func submitReview(isShowAppleReviewScreen : Bool = false) {
        setValue(true)
        AppReviewManager.shared.submitReview(isShowAppleReviewScreen: isShowAppleReviewScreen)
        showUnlockCategoryPopup = false
        isAlreadyShown = true
    }

    // MARK: - Submit Stars
    func submitStars(stars: Int) {
        
        if stars > 3 {
            AppReviewManager.shared.submitReview(isShowAppleReviewScreen: true)
        } else {
            openFeedbackMail()
        }
        AppReviewManager.shared.hideRatingCardForever()
        setValue(true)
        showCustomRatingPopup = false
        isAlreadyShown = true
    }
    
    func customRatingDismiss() {
        showCustomRatingPopup = false
    }
}

extension RatingFlowViewModel {

    func openFeedbackMail() {
        let email = "ishivshankartiwari70@gmail.com"
        let subject = "Feedback"
        let body = ""

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let urlString = "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)"

        guard let url = URL(string: urlString),
              UIApplication.shared.canOpenURL(url) else { return }

        UIApplication.shared.open(url)
    }
}
