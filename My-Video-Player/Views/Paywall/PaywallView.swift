//
//  PaywallView.swift
//  Truth Or Dare
//
//  Created by Shivshankar T Tiwari on 14/11/25.
//

import Foundation
import SwiftUI
import StoreKit
import Combine

struct PaywallView: View {
    
    struct WebViewData: Identifiable {
        let id = UUID()
        let title: String
        let url: String
    }
    
    @State private var webViewData: WebViewData? = nil
    
    @ObservedObject var subscriptionStore = SubscriptionStore.shared
    @ObservedObject private var remoteConfigManager = RemoteConfigManager.shared
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var navigationManager : NavigationManager
    
    @State private var isNeedToMoveToGift: Bool = false
    
    @State private var navigateToWebView: Bool = false
    @State private var webViewURL: URL?
    @State private var webViewNavTitle: String = ""
    
    @State private var isNeedToShowCross: Bool = false
    @State private var isNeedToMoveToInitialDetails: Bool = false
    @State var isProccesing: Bool = false
    var isFromOnboarding: Bool = false
    var isFromIntialPaywall: Bool = false
    
    @State private var currentPage = 0
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    let numberOfImages = 3
    
    @State private var featureVisibility: [Bool] = [false, false, false, false]
    
    
    var body: some View {
        ZStack {
            // MARK: - Background
            Color.black.ignoresSafeArea()
            
            // Decorative Blurred Circles
            ZStack {
                
                Circle()
                    .foregroundColor(.bgBlurOrange2.opacity(0.14))
                    .aspectRatio(1.0, contentMode: .fit)
                    .responsiveWidth(iphoneWidth: 356)
                    .blur(radius: 130)
                
                
                Circle()
                    .foregroundColor(.bgBlurOrange1.opacity(0.15))
                    .aspectRatio(1.0, contentMode: .fit)
                    .responsiveWidth(iphoneWidth: 300)
                    .blur(radius: 80)
                    .offset(x: -164.5, y: 368.5)
                
                Circle()
                    .foregroundColor(.bgBlurOrange2.opacity(0.15))
                    .aspectRatio(1.0, contentMode: .fit)
                    .responsiveWidth(iphoneWidth: 300)
                    .blur(radius: 80)
                    .offset(x: 161.5, y: -451.5)
            }
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    
                    HStack {
                        Spacer()
                        ZStack {
                            Rectangle()
                                .fill(.black.opacity(0.001))
                                .aspectRatio(1.0, contentMode: .fit)
                                .responsiveWidth(iphoneWidth: 35)
                            Button {
                                HapticsManager.shared.generateOnboardingVibrate()
                                if isFromOnboarding {
                                    navigationManager.push(.dashboard)
                                } else {
                                    navigationManager.pop()
                                }
                            } label: {
                                if isNeedToShowCross {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white.opacity(0.6))
                                        .aspectRatio(1.0, contentMode: .fit)
                                        .responsiveWidth(iphoneWidth: 35)
                                        .padding(7)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                
                            }
                        }
                      
                    }
                       
                    // MARK: - Header "Unlock Premium"
                    HStack(spacing: 12) {
                        Text("Unlock")
                            .appFont(.figtreeExtraBold, size: 44)
                            .foregroundColor(.white)
                        
                        Text("Premium")
                            .appFont(.figtreeExtraBold, size: 44)
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .background(Color.premiumAccent)
                    }
                    .responsivePadding(edge: .top, fraction: 15)
                    
                    // MARK: - Features
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "feature_1_paywall", text: "Unlimited Folders")
                        FeatureRow(icon: "feature_2_paywall", text: "Background Playback")
                        FeatureRow(icon: "feature_3_paywall", text: "Ad-Free Experience")
                    }
                    .responsivePadding(edge: .top, fraction: 40)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .responsivePadding(edge: .leading, fraction: 55)
                    
                    // MARK: - Trial Toggle
                    HStack {
                        Text("Not sure? Enable free trial")
                            .appFont(.figtreeMedium, size: 14)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        CustomToggle(isOn: remoteConfigManager.currentSelectedPaywallPlan == remoteConfigManager.paywallFreeTrialPlan)
                            .onTapGesture {
                                HapticsManager.shared.generate(.selection)
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    let trialPlan = remoteConfigManager.paywallFreeTrialPlan

                                    if remoteConfigManager.currentSelectedPaywallPlan != trialPlan {
                                        
                                        // Turn ON trial → switch to trial plan
                                        remoteConfigManager.currentSelectedPaywallPlan = trialPlan
                                        
                                    } else {
                                        
                                        // Turn OFF trial → switch to first non-trial plan
                                        if let firstNonTrialPlan = [0,1,2].first(where: { $0 != trialPlan }) {
                                            remoteConfigManager.currentSelectedPaywallPlan = firstNonTrialPlan
                                        }
                                    }

                                }
                            }
                    }
                    .padding(isIpad ? 25 : 16)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(isIpad ? 30 : 20)
                    .padding(.horizontal)
                    
                    .responsivePadding(edge: .top, fraction: 40)
                    
                    // MARK: - Subscription Plans
                    let weeklyPlan = subscriptionStore.subscriptions.first { $0.id == "com.video.player.veeplay.app.weekly" }
                    let yearlyPlan = subscriptionStore.subscriptions.first { $0.id == "com.video.player.veeplay.app.yearly" }
                    let lifeTimePlan = subscriptionStore.subscriptions.first { $0.id == "com.video.player.veeplay.app.lifetime" }
                    
                    HStack(spacing: isIpad ? 30 : 12) {
                        SubscriptionOption(
                            title: "Weekly",
                            price: weeklyPlan?.displayPrice ?? "$0.00",
                            duration: "per week",
                            isSelected: remoteConfigManager.currentSelectedPaywallPlan == 0,
                            description: remoteConfigManager.weekly_plan_description,
                            onSelect: { selectPlan(0) }
                        )
                        
                        SubscriptionOption(
                            title: "Yearly",
                            price: !remoteConfigManager.showWeeklyPriceOnYearly ? "\(yearlyPlan?.displayPrice ?? "$0.00")" : "\(self.calculateYearToWeeklyPrice(actualPrice: yearlyPlan?.price ?? 0, currencyCode: yearlyPlan?.priceFormatStyle.currencyCode ?? "") ?? "$0.00")",
                            duration: remoteConfigManager.showWeeklyPriceOnYearly ? "per week" : "per year",
                            isSelected: remoteConfigManager.currentSelectedPaywallPlan == 1,
                            description: remoteConfigManager.yearly_plan_description,
                            onSelect: { selectPlan(1) }
                        )
                        
                        SubscriptionOption(
                            title: "Lifetime",
                            price: lifeTimePlan?.displayPrice ?? "$0.00",
                            duration: "one time",
                            isSelected: remoteConfigManager.currentSelectedPaywallPlan == 2,
                            description: remoteConfigManager.lifetime_plan_description,
                            onSelect: { selectPlan(2) }
                        )
                    }
                    
                    .responsivePadding(edge: .top, fraction: 30)
                    .padding(.horizontal)
                    
                    // Status text
                    VStack(spacing: 4) {
                        Text(currentBottomLineDescription)
                            .appFont(.figtreeMedium, size: 14)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .responsivePadding(edge: .top, fraction: 25)
                    }
                
                    
                    // MARK: - Main Button
                    Button(action: {
                        HapticsManager.shared.generateOnboardingVibrate()
                        switch remoteConfigManager.currentSelectedPaywallPlan {
                        case 0: self.purchaseProduct(purchaseProduct: weeklyPlan)
                        case 1: self.purchaseProduct(purchaseProduct: yearlyPlan)
                        case 2: self.purchaseProduct(purchaseProduct: lifeTimePlan)
                        default: self.purchaseProduct(purchaseProduct: weeklyPlan)
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.premiumAccent)
                                .aspectRatio(321/52, contentMode: .fit)
                                .shadow(radius: 4)
                                .cornerRadius(60)
                            
                            Text(remoteConfigManager.currentSelectedPaywallPlan == remoteConfigManager.paywallFreeTrialPlan &&  remoteConfigManager.isTrialPriceUnabled ? "\(remoteConfigManager.continueBtnText) \(formattedTrialPrice(for: yearlyPlan))" : "Continue")
                                .appFont(.figtreeExtraBold, size: 20)
                                .foregroundStyle(.black)
                                
                        }
                        
                    }
                    .responsivePadding(edge: .horizontal, fraction: 20)
                    .responsivePadding(edge: .top, fraction: 30)
                    .disabled(isProccesing)
                    
                    Text("🔒 Secured with iTunes. Cancel anytime")
                        .appFont(.figtreeMedium, size: 11)
                        .foregroundColor(.white.opacity(0.6))
                        .responsivePadding(edge: .top, fraction: 15)
                        
                    
                    // MARK: - Footer Links
                    HStack(spacing: 8) {
                        FooterLinkButton(text: "Restore") {
                            HapticsManager.shared.generateOnboardingVibrate()
                            restorePurchase()
                        }
                        Text("|").foregroundColor(.white.opacity(0.3))
                        FooterLinkButton(text: "Privacy policy") {
                            openWebPage("https://sites.google.com/view/shivshankarapps/privacy-policy", title: "Privacy Policy")
                        }
                        Text("|").foregroundColor(.white.opacity(0.3))
                        FooterLinkButton(text: "Terms of use") {
                            openWebPage("https://sites.google.com/view/shivshankarapps/terms-conditions", title: "Terms & Conditions")
                        }
                    }
                    .responsivePadding(edge: .top, fraction: 15)
                    
                    Text("Premium membership unlocks all the packs and content. This is an auto-renew subscription. Subscriptions will automatically renew and you will be charged for renewal within 24 hours prior to end of each period unless auto renew is tuned off at least 24-hours before the end of each period. You can manage your subscription settings and auto-renewal may turned off by going to Apple ID Account Settings after purchase.")
                        .appFont(.figtreeRegular, size: 8)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 20)
                    
                    Spacer(minLength: 50)
                }
            }
            .responsiveWidth(iphoneWidth: 393, ipadWidth: 280)
            
            
            if !subscriptionStore.isReady || isProccesing {
                loaderOverlay()
            }
        }
       
        
        .navigationBarBackButtonHidden()
        
        .fullScreenCover(item: $webViewData) { data in
            URLWebView(titleName: data.title, urlString: data.url)
        }
        .navigationDestination(isPresented: $isNeedToMoveToInitialDetails) {
            Onboarding1View()
        }
        .onAppear {
            checkPaywallXTypes()
        }
    }
    
    // MARK: - Helpers
    
    private var currentBottomLineDescription: String {
        let description: String
        let price: String
        
        switch remoteConfigManager.currentSelectedPaywallPlan {
        case 0:
            description = remoteConfigManager.week_plan_bottom_line_description
            price = subscriptionStore.subscriptions.first { $0.id == "com.video.player.veeplay.app.weekly" }?.displayPrice ?? ""
        case 1:
            description = remoteConfigManager.year_plan_bottom_line_description
            price = subscriptionStore.subscriptions.first { $0.id == "com.video.player.veeplay.app.yearly" }?.displayPrice ?? ""
        case 2:
            description = remoteConfigManager.lifetime_plan_bottom_line_description
            price = subscriptionStore.subscriptions.first { $0.id == "com.video.player.veeplay.app.lifetime" }?.displayPrice ?? ""
        default:
            return ""
        }
        
        return description.replacingOccurrences(of: "[Pricing]", with: price)
    }
    
    private var bindingForPlan: Binding<Bool> {
        Binding(
            get: { remoteConfigManager.currentSelectedPaywallPlan == remoteConfigManager.paywallFreeTrialPlan },
            set: { newValue in
                let trialPlan = remoteConfigManager.paywallFreeTrialPlan
                
                if newValue {
                    // Toggle ON → switch to trial plan
                    remoteConfigManager.currentSelectedPaywallPlan = trialPlan
                } else {
                    // Toggle OFF → switch to first non-trial plan
                    if let nonTrial = [0,1,2].first(where: { $0 != trialPlan }) {
                        remoteConfigManager.currentSelectedPaywallPlan = nonTrial
                    }
                }
            }
        )
    }
    
    private func selectPlan(_ index: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            remoteConfigManager.currentSelectedPaywallPlan = index
            HapticsManager.shared.generateOnboardingVibrate()
        }
    }
    
    func formattedTrialPrice(for product: Product?) -> String {
        guard let product = product else {
            return "0.00"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        
        // Use the product's priceLocale for correct currency & formatting
        formatter.locale = product.priceFormatStyle.locale
        
        // Format zero price for trial display (0.00 in correct format)
        let zeroPrice = 0.0
        let formattedZeroPrice = formatter.string(from: NSNumber(value: zeroPrice)) ?? "0.00"
        
        return formattedZeroPrice
    }
    
    func checkPaywallXTypes(){
        
        switch remoteConfigManager.currentPaywallXType {
        case 0:
            isNeedToShowCross = true
        case 1:
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0){
                isNeedToShowCross = true
            }
        case 2:
            isNeedToShowCross = false
        default:
            isNeedToShowCross = true
        }
    }
    
    func gettrailPeriod(product:Product?) -> String {
        let trailPeriod: String
        
        if let subscriptionPeriod = product?.subscription?.introductoryOffer?.period {
            
            let periodValue = subscriptionPeriod.value
            let periodUnit: String
            
            switch subscriptionPeriod.unit {
            case .day:
                periodUnit = periodValue == 1 ? "Day" : "Days"
            case .week:
                periodUnit = periodValue == 1 ? "Week" : "Weeks"
            case .month:
                periodUnit = periodValue == 1 ? "Month" : "Months"
            case .year:
                periodUnit = periodValue == 1 ? "Year" : "Years"
            @unknown default:
                periodUnit = "Unknown"
            }
            
            trailPeriod = "\(periodValue) \(periodUnit)"
        } else {
            trailPeriod = "No Trial"
        }
        
        return trailPeriod
    }
    
    private func calculateYearToWeeklyPrice(actualPrice: Decimal,currencyCode:String) -> String? {
        if actualPrice <= 0 {
            return nil
        }else{
            let weeksInYear: Decimal = 52.14
            
            // Calculate weekly price
            var weeklyPrice = actualPrice / weeksInYear
            
            // Round to 2 decimal places
            var roundedWeeklyPrice = Decimal()
            NSDecimalRound(&roundedWeeklyPrice, &weeklyPrice, 2, .up)
            
            // Format as localized currency string
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currencyCode
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            formatter.locale = Locale.current // Or use a specific one like Locale(identifier: "en_US")
            
            if let formattedPrice = formatter.string(from: roundedWeeklyPrice as NSDecimalNumber) {
                print("Year to Weekly price: \(formattedPrice)")
                return formattedPrice
            }else{
                return nil
            }
        }
    }
    
    func purchaseProduct(purchaseProduct:Product?){
        if let product = purchaseProduct {
            isProccesing = true
            Task {
                defer {
                    isProccesing = false
                }
                do {
                    if let transaction = try await subscriptionStore.purchase(product) {
                        AnalyticsManager.shared.log(.paywallPlanSubscribed(planDetails: PlanDetails(planName: transaction.productID, planPrice: "\(transaction.price ?? 0.0)", planExpiry: "\(String(describing: transaction.expirationDate))")))
                        
                        if purchaseProduct?.id == "com.video.player.veeplay.app.weekly" {
                            AppReviewManager.submitReview(isShowAppleReviewScreen: false)
                        }
                        if isFromOnboarding {
                            navigationManager.push(.dashboard)
                        } else {
                            navigationManager.pop()
                        }
                        
                        print(transaction)
                    }
                }
                catch{
                    print(error.localizedDescription)
                }
            }
        }
    }
    
    func restorePurchase(){
        isProccesing = true
        Task {
            defer {
                isProccesing = false
            }
            do {
                try await subscriptionStore.restorePurchases()
                //  AnalyticsManager.shared.log(.userClickedRestore)
                if isFromOnboarding {
                    navigationManager.push(.dashboard)
                } else {
                    navigationManager.pop()
                }
            }
            catch{
                print(error.localizedDescription)
            }
        }
    }
    
    private func loaderOverlay() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(1.0))
                .aspectRatio(1.0, contentMode: .fit)
                .responsiveWidth(iphoneWidth: 100, ipadWidth: 60)
                
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                .scaleEffect(1.5)
                
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4))
        .ignoresSafeArea()
        
    }
    
    private func openWebPage(_ urlString: String, title: String) {
        webViewData = WebViewData(title: title, url: urlString)
    }
    
}

struct FooterLinkButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .appFont(.figtreeMedium, size: 12)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: isIpad ? 40 : 24, height: isIpad ? 40 : 24)
            
            Text(text)
                .appFont(.figtreeSemiBold, size: 18)
                .foregroundColor(.white)
        }
    }
}

struct CustomToggle: View {
    var isOn: Bool
    
    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            RoundedRectangle(cornerRadius: 33)
                .fill(isOn ? Color.premiumAccent : Color.white.opacity(0.12))
                .frame(width: 50, height: 26)
            
            Circle()
                .fill(Color.white)
                .frame(width: 22, height: 22)
                .padding(2)
        }
    }
}

struct SubscriptionOption: View {
    var title: String
    var price: String
    var duration: String
    var isSelected: Bool
    var description: String
    var onSelect: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(title)
                    .appFont(isSelected ? .figtreeRegular : .figtreeBold, size: 16)
                    .foregroundColor(isSelected ? .black :  .white.opacity(RemoteConfigManager.shared.paywallPlanTitleOpacity / 100.0))
                
                Text(price)
                    .appFont(isSelected ? .figtreeExtraBold : .figtreeMedium, size: 18)
                    .foregroundColor(isSelected ? .black : .white)
                
                Text(duration)
                    .appFont(isSelected ? .figtreeExtraBold : .figtreeMedium, size: 14)
                    .foregroundColor(isSelected ? .black : .white)
            }
            .padding(.top, 14)
            
            Spacer()
            
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.black : .white.opacity(0.06))
                    .aspectRatio(100/53, contentMode: .fit)
                    .padding([.leading, .trailing], 5)
                
                Text(description)
                    .appFont(isSelected ? .figtreeBold : .figtreeMedium, size: 15)
                    .foregroundColor(isSelected ? .white : .white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding([.leading, .trailing], 10)
                   
            }
            .responsivePadding(edge: .bottom, fraction: isIpad ? 5 : 5)
        }
        .aspectRatio(110/154, contentMode: .fit)
//        .responsiveWidth(iphoneWidth: 110, ipadWidth: 80)
        
        .background(isSelected ? Color.premiumAccent : Color.clear)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
        )
        .onTapGesture {
            onSelect()
        }
    }
}

#Preview {
    PaywallView()
}
