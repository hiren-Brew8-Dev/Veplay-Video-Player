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

    @Published var showWeeklyPriceOnYearly: Bool = false
    @Published var isShowNeverrCardView: Bool = false
    @Published var currentSelectedPaywallPlan: Int = 0
    @Published var minimumRequiredVersion: Double = 1.0
    @Published var continueBtnText: String = "Continue"
    @Published var isNeedToShowForceUpdate = false
    @Published var currentPaywallXType: Int = 0
    @Published var isTrialPriceUnabled: Bool = false
    @Published var planInfoTitleTextWeek: String = "Weekly Access"
    @Published var planInfoTitleTextWeekDummy: String = "Weekly Access"
    @Published var weekly_plan_description: String = "Free for \n3 days"
    @Published var yearly_plan_description: String = "Design All Year"
    @Published var lifetime_plan_description: String = "Limited\nTime offer"
    @Published var week_plan_bottom_line_description: String = ""
    @Published var year_plan_bottom_line_description: String = ""
    @Published var lifetime_plan_bottom_line_description: String = ""
    @Published var isTrialPriceUnabledWeekly: Bool = false
    @Published var paywallPlanTitleOpacity: Double = 60.0
    @Published var paywallFreeTrialPlan: Int = 0

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
            
            "paywall_X_type": 0 as NSObject,
            "is_Trail_Price_Unable": false as NSObject,
            "weekly_plan_description": "Free for \n3 days" as NSObject,
            "yearly_plan_description": "Design All Year" as NSObject,
            "lifetime_plan_description": "Limited\nTime offer" as NSObject,
            "week_plan_bottom_line_description": "🔥 No Payment Now! Auto-renew @ just [Pricing]/week" as NSObject,
            "year_plan_bottom_line_description": "Auto-renews @ just [Pricing]/year" as NSObject,
            "lifetime_plan_bottom_line_description": "Pay once, Forever yours" as NSObject,
            "isTrialPriceUnabledWeekly": false as NSObject,
            "paywall_plan_title_opacity": 60.0 as NSObject,
            "paywall_freeTrial_plan" : 0 as NSObject
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
                    self.showWeeklyPriceOnYearly = self.remoteConfig["showWeeklyPriceOnYearly"].boolValue
                    self.currentSelectedPaywallPlan = self.remoteConfig["Current_Selected_Paywall_Plan"].numberValue.intValue
                    self.minimumRequiredVersion = self.remoteConfig["min_required_version"].numberValue.doubleValue
                    self.continueBtnText = self.remoteConfig["contine_Button_Text"].stringValue
                    self.currentPaywallXType = self.remoteConfig["paywall_X_type"].numberValue.intValue
                  
                    self.isTrialPriceUnabled = self.remoteConfig["is_Trail_Price_Unable"].boolValue
                    
                    self.weekly_plan_description = self.remoteConfig["weekly_plan_description"].stringValue.replacingOccurrences(of: "\\n", with: "\n")
                    self.yearly_plan_description = self.remoteConfig["yearly_plan_description"].stringValue.replacingOccurrences(of: "\\n", with: "\n")
                    self.lifetime_plan_description = self.remoteConfig["lifetime_plan_description"].stringValue.replacingOccurrences(of: "\\n", with: "\n")
                    
                    self.week_plan_bottom_line_description = self.remoteConfig["week_plan_bottom_line_description"].stringValue .replacingOccurrences(of: "\\n", with: "\n")
                    self.year_plan_bottom_line_description = self.remoteConfig["year_plan_bottom_line_description"].stringValue.replacingOccurrences(of: "\\n", with: "\n")
                    self.lifetime_plan_bottom_line_description = self.remoteConfig["lifetime_plan_bottom_line_description"].stringValue.replacingOccurrences(of: "\\n", with: "\n")
                    self.isTrialPriceUnabledWeekly = self.remoteConfig["isTrialPriceUnabledWeekly"].boolValue
                    self.paywallPlanTitleOpacity = self.remoteConfig["paywall_plan_title_opacity"].numberValue.doubleValue
                    self.paywallFreeTrialPlan = self.remoteConfig["paywall_freeTrial_plan"].numberValue.intValue
                    
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
