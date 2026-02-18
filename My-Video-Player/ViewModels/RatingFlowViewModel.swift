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
        resetValue()
        loadValue()
        observeICloudChanges()
    }

    // MARK: - Keys
    private let ratingKey = "is_already_show_rating_popup_video_player"

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
    }

    // MARK: - Reset
    
    func resetValue() {
        updateLocal(false)
        updateCloud(false)
        isAlreadyShown = false
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
        AppReviewManager.submitReview(isShowAppleReviewScreen: isShowAppleReviewScreen)
        showUnlockCategoryPopup = false
        isAlreadyShown = true
    }

    // MARK: - Submit Stars
    func submitStars(stars: Int) {
        if stars > 3 {
            AppReviewManager.submitReview(isShowAppleReviewScreen: true)
        } else {
            openFeedbackMail()
        }
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
        let subject = "App Feedback"
        let body = ""

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let urlString = "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)"

        guard let url = URL(string: urlString),
              UIApplication.shared.canOpenURL(url) else { return }

        UIApplication.shared.open(url)
    }
}
