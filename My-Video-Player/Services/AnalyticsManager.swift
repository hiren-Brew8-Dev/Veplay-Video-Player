//
//  AnalyticsManager.swift
//  My-Video-Player
//
//  Created by Auto-generated on 13/02/26.
//

import Foundation

enum AnalyticsEvent {
    case paywallPlanSubscribed(planDetails: PlanDetails)
    case userClickedTryFree
    case userClickedRestore
    case privacyPolicyTapped
    case termsAndConditionTapped
    case skipButtonTapped
}

struct PlanDetails {
    let planName: String
    let planPrice: String
    let planExpiry: String
}

class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private init() {}
    
    func log(_ event: AnalyticsEvent) {
        // Placeholder for analytics logging
        print("Analytics Event: \(event)")
    }
}
