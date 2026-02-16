//
//  RemoteConfigManager.swift
//  My-Video-Player
//
//  Created by Auto-generated on 13/02/26.
//

import Foundation
import FirebaseRemoteConfig
import SwiftUI
import Combine

class RemoteConfigManager: ObservableObject {
    static let shared = RemoteConfigManager()

    @Published var isNeedToShowWeeklyPriceOnYearly: Bool = false
    @Published var isShowNeverrCardView: Bool = false
    @Published var currentSelectedPaywallPlan: Int = 0
    @Published var minimumRequiredVersion: Double = 1.0
    @Published var continueBtnText: String = "Continue"
    @Published var isNeedToShowForceUpdate = false
    @Published var currentPaywallXType: Int = 0
    @Published var planInfoTitleTextYearly: String = "Secured by Apple, Cancel Anytime"
    @Published var isTrialPriceUnabled: Bool = false
    @Published var planInfoTitleTextWeekly: String = "Weekly Access"
    @Published var planInfoTitleTextWeeklyDummy: String = "Weekly Access"
    @Published var planInfoTitleTextMonthly: String = "Monthly Access"
    @Published var weeklyPlanDescription: String = "Best Value\nFor Money"
    @Published var monthlyPlanDescription: String = "Most Popular"
    @Published var yearlyPlanDescription: String = "Save 80%"
    
    // Paywall customization colors
    @Published var paywallPlanTitleColor: String = "#FFFFFF"
    @Published var paywallPlanTitleOpacity: Double = 50.0
    @Published var isTrialPriceUnabledWeekly: Bool = false

    private let remoteConfig = RemoteConfig.remoteConfig()

    private init() {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 43200 // 12 hours
        remoteConfig.configSettings = settings
        
        remoteConfig.setDefaults([
            "is_show_neverr_card_view": false as NSObject,
            "showWeeklyPriceOnYearly": false as NSObject,
            "Current_Selected_Paywall_Plan": 0 as NSObject,
            "min_required_version": 1.0 as NSObject,
            "contine_Button_Text": "Continue" as NSObject,
            "planInfo_Title_Text_Yearly": "🔥 No Payment Now!" as NSObject,
            "paywall_X_type": 0 as NSObject,
            "is_Trail_Price_Unable": false as NSObject,
            "planInfoTitleTextWeekly": "Weekly Access" as NSObject,
            "planInfoTitleTextWeeklyDummy": "Weekly Access" as NSObject,
            "planInfoTitleTextMonthly": "Monthly Access" as NSObject,
            "weeklyPlanDescription": "Best Value\nFor Money" as NSObject,
            "monthlyPlanDescription": "Most Popular" as NSObject,
            "yearlyPlanDescription": "Save 80%" as NSObject,
            "isTrialPriceUnabledWeekly": false as NSObject
        ])

        fetchRemoteConfig()
        setupListener()
    }

    func fetchRemoteConfig() {
        remoteConfig.fetchAndActivate { [weak self] (status, error) in
            guard let self = self else { return }

            if let error = error {
                print("Error fetching remote config: \(error.localizedDescription)")
                return
            }

            if status == .successFetchedFromRemote || status == .successUsingPreFetchedData {
                DispatchQueue.main.async {
                    self.isShowNeverrCardView = self.remoteConfig["is_show_neverr_card_view"].boolValue
                    self.isNeedToShowWeeklyPriceOnYearly = self.remoteConfig["showWeeklyPriceOnYearly"].boolValue
                    self.currentSelectedPaywallPlan = self.remoteConfig["Current_Selected_Paywall_Plan"].numberValue.intValue
                    self.minimumRequiredVersion = self.remoteConfig["min_required_version"].numberValue.doubleValue
                    self.continueBtnText = self.remoteConfig["contine_Button_Text"].stringValue ?? "Continue"
                    self.currentPaywallXType = self.remoteConfig["paywall_X_type"].numberValue.intValue
                    self.planInfoTitleTextYearly = self.remoteConfig["planInfo_Title_Text_Yearly"].stringValue ?? ""
                    self.isTrialPriceUnabled = self.remoteConfig["is_Trail_Price_Unable"].boolValue
                    
                    self.planInfoTitleTextWeekly = self.remoteConfig["planInfoTitleTextWeekly"].stringValue ?? "Weekly Access"
                    self.planInfoTitleTextWeeklyDummy = self.remoteConfig["planInfoTitleTextWeeklyDummy"].stringValue ?? "Weekly Access"
                    self.planInfoTitleTextMonthly = self.remoteConfig["planInfoTitleTextMonthly"].stringValue ?? "Monthly Access"
                    
                    self.weeklyPlanDescription = self.remoteConfig["weeklyPlanDescription"].stringValue ?? "Best Value\nFor Money"
                    self.monthlyPlanDescription = self.remoteConfig["monthlyPlanDescription"].stringValue ?? "Most Popular"
                    self.yearlyPlanDescription = self.remoteConfig["yearlyPlanDescription"].stringValue ?? "Save 80%"
                    self.isTrialPriceUnabledWeekly = self.remoteConfig["isTrialPriceUnabledWeekly"].boolValue
                    
                    self.checkForceUpdate()
                }
            }
        }
    }
   
    private func setupListener() {
        remoteConfig.addOnConfigUpdateListener { [weak self] configueUpdate, error in
            guard let self = self else { return }
            if let error = error {
                print("Remote Config Error: \(error.localizedDescription)")
                 return
            }
            self.remoteConfig.activate { _, _ in
                self.fetchRemoteConfig()
            }
        }
    }
    
    func checkForceUpdate() {
        let currentAppVersion = getAppVersion()
        isNeedToShowForceUpdate = currentAppVersion < minimumRequiredVersion
    }
    
    func getAppVersion() -> Double {
        if let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            let versionComponents = versionString.split(separator: ".")
            let versionDoubleString = versionComponents.joined(separator: ".")
            return Double(versionDoubleString) ?? 0.0
        }
        return 0.0
    }
}
