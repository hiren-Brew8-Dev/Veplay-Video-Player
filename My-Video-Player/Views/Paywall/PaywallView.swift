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
    @State private var isAnimating = false
    
    
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
            .opacity(isAnimating ? 1 : 0)
            .animation(.easeIn(duration: 0.6), value: isAnimating)
            
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
                                    // Check if presented as a sheet/cover first
                                    if presentationMode.wrappedValue.isPresented {
                                        presentationMode.wrappedValue.dismiss()
                                    } else {
                                        navigationManager.pop()
                                    }
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
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.easeIn(duration: 0.3).delay(0.6), value: isAnimating)
                       
                    // MARK: - Header "Unlock Premium"
                    VStack(spacing: 12) {
                        Text("Unlock")
                            .appFont(.figtreeExtraBold, size: 44)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment : .leading)
                        
                        Text("Premium")
                            .appFont(.figtreeExtraBold, size: 44)
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .background(Color.premiumAccent)
                            .frame(maxWidth: .infinity, alignment : .leading)
                    }
                    .responsivePadding(edge: .top, fraction: -35)
                    .responsivePadding(edge: .horizontal, fraction: 25)
                    .frame(maxWidth: .infinity, alignment : .leading)
                    .offset(y: isAnimating ? 0 : 20)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: isAnimating)
                    
                    // Feature rows with staggered entrance
                    VStack(alignment: .leading, spacing: 24) {
                        FeatureRow(
                            icon: "feature_1_paywall",
                            title: "Supports 20+ Video Formats",
                            subtitle: "MKV, MP4, AVI & more without transcoding."
                        )
                        .offset(x: isAnimating ? 0 : 20)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: isAnimating)
                        
                        FeatureRow(
                            icon: "feature_2_paywall",
                            title: "Secure with Face ID",
                            subtitle: "Lock your app with face authentication."
                        )
                        .offset(x: isAnimating ? 0 : 20)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: isAnimating)
                        
                        FeatureRow(
                            icon: "feature_3_paywall",
                            title: "Background Audio Playback",
                            subtitle: "Keep listening even when screen is locked."
                        )
                        .offset(x: isAnimating ? 0 : 20)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: isAnimating)
                        
                        FeatureRow(
                            icon: "feature_4_paywall",
                            title: "Seamless AirPlay Support",
                            subtitle: "Cast 4K content to any device wirelessly."
                        )
                        .offset(x: isAnimating ? 0 : 20)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: isAnimating)
                    }

                    .responsivePadding(edge: .top, fraction: 30)
                    .responsivePadding(edge: .horizontal, fraction: 25)
                    .frame(maxWidth: .infinity, alignment : .leading)
                   
                    
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
                        .scaleEffect(isAnimating ? 1 : 0.85)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.35), value: isAnimating)
                        
                        SubscriptionOption(
                            title: "Yearly",
                            price: !remoteConfigManager.showWeeklyPriceOnYearly ? "\(yearlyPlan?.displayPrice ?? "$0.00")" : "\(self.calculateYearToWeeklyPrice(actualPrice: yearlyPlan?.price ?? 0, currencyCode: yearlyPlan?.priceFormatStyle.currencyCode ?? "") ?? "$0.00")",
                            duration: remoteConfigManager.showWeeklyPriceOnYearly ? "per week" : "per year",
                            isSelected: remoteConfigManager.currentSelectedPaywallPlan == 1,
                            description: remoteConfigManager.yearly_plan_description,
                            onSelect: { selectPlan(1) }
                        )
                        .scaleEffect(isAnimating ? 1 : 0.85)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4), value: isAnimating)
                        
                        SubscriptionOption(
                            title: "Lifetime",
                            price: lifeTimePlan?.displayPrice ?? "$0.00",
                            duration: "one time",
                            isSelected: remoteConfigManager.currentSelectedPaywallPlan == 2,
                            description: remoteConfigManager.lifetime_plan_description,
                            onSelect: { selectPlan(2) }
                        )
                        .scaleEffect(isAnimating ? 1 : 0.85)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.45), value: isAnimating)
                    }
                    
                    .responsivePadding(edge: .top, fraction: 30)
                    .responsivePadding(edge: .horizontal, fraction: 20)
                    
                    // Status text
                    VStack(spacing: 6) {
                        Text(currentBottomLineDescription)
                            .appFont(.figtreeBold, size: 16)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .responsivePadding(edge: .top, fraction: 25)
                        
                        Text(currentBottomPricingDescription)
                            .appFont(.figtreeMedium, size: 12)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                           
                    }
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.easeIn(duration: 0.3).delay(0.45), value: isAnimating)
                
                    
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
                    .responsivePadding(edge: .top, fraction: 20)
                    .disabled(isProccesing)
                    .scaleEffect(isAnimating ? 1 : 0.95)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.55), value: isAnimating)
                    
                    Text("🔒 Secured with iTunes. Cancel anytime")
                        .appFont(.figtreeMedium, size: 11)
                        .foregroundColor(.white.opacity(0.6))
                        .responsivePadding(edge: .top, fraction: 15)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.easeIn(duration: 0.3).delay(0.55), value: isAnimating)
                        
                    
                    // MARK: - Footer Links
                    HStack(spacing: 8) {
                        FooterLinkButton(text: "Restore") {
                            HapticsManager.shared.generateOnboardingVibrate()
                            restorePurchase()
                        }
                        Text("|").foregroundColor(.white.opacity(0.3))
                        FooterLinkButton(text: "Privacy policy") {
                            HapticsManager.shared.generate(.light)
                            openWebPage("https://sites.google.com/view/shivshankarttiwari/privacy-policy", title: "Privacy Policy")
                        }
                        Text("|").foregroundColor(.white.opacity(0.3))
                        FooterLinkButton(text: "Terms of use") {
                            HapticsManager.shared.generate(.light)
                            openWebPage("https://sites.google.com/view/shivshankarttiwari/terms-conditions", title: "Terms & Conditions")
                        }
                    }
                    .responsivePadding(edge: .top, fraction: 15)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.easeIn(duration: 0.3).delay(0.6), value: isAnimating)
                    
                    Text("Premium membership unlocks all the packs and content. This is an auto-renew subscription. Subscriptions will automatically renew and you will be charged for renewal within 24 hours prior to end of each period unless auto renew is tuned off at least 24-hours before the end of each period. You can manage your subscription settings and auto-renewal may turned off by going to Apple ID Account Settings after purchase.")
                        .appFont(.figtreeRegular, size: 8)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .responsivePadding(edge: .horizontal, fraction: 30)
                        .responsivePadding(edge: .vertical, fraction: 20)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.easeIn(duration: 0.3).delay(0.65), value: isAnimating)
                    
                    Spacer(minLength: 50)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .responsiveWidth(iphoneWidth: 393, ipadWidth: 300)
            
            
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
            isAnimating = true
            
            // Force Portrait on iPhone
            if UIDevice.current.userInterfaceIdiom == .phone {
                AppDelegate.orientationLock = .portrait
                if #available(iOS 16.0, *) {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                    }
                } else {
                    UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                    UIViewController.attemptRotationToDeviceOrientation()
                }
            }
        }
        .onDisappear {
            // Reset to allow all orientations when leaving
            if UIDevice.current.userInterfaceIdiom == .phone {
                AppDelegate.orientationLock = .all
            }
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
    
    private var currentBottomPricingDescription: String {
        let description: String
        let price: String
        
        switch remoteConfigManager.currentSelectedPaywallPlan {
        case 0:
            description = "Auto-renews @ just [Pricing]/week"
            price = subscriptionStore.subscriptions.first { $0.id == "com.video.player.veeplay.app.weekly" }?.displayPrice ?? ""
        case 1:
            description = "Auto-renews @ just [Pricing]/year"
            price = subscriptionStore.subscriptions.first { $0.id == "com.video.player.veeplay.app.yearly" }?.displayPrice ?? ""
        case 2:
            description = "Pay once, Forever yours"
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
                        
                        if isFromOnboarding {
                            navigationManager.push(.dashboard)
                        } else {
                            if presentationMode.wrappedValue.isPresented {
                                presentationMode.wrappedValue.dismiss()
                            } else {
                                navigationManager.pop()
                            }
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
                    if presentationMode.wrappedValue.isPresented {
                        presentationMode.wrappedValue.dismiss()
                    } else {
                        navigationManager.pop()
                    }
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
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                
                Image(icon)
                    .resizable()
                    .aspectRatio(1.0,contentMode: .fit)
                    .responsiveWidth(iphoneWidth: 48, ipadWidth: 35)
                    .foregroundColor(Color.premiumAccent) // Design shows icon is orange-ish in dark theme usually, but code said white. Let's stick to design code: foregroundColor(.white) or the specific color?
                    // Figma code for icon container doesn't specify icon color, but context implies it.
                    // Actually, the previous inline code I wrote used .white. Let's use .premiumAccent if it's the icon color, or .white.
                    // The screenshot shows Golden/Orange icons!
                    .foregroundColor(Color.premiumAccent)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .appFont(.figtreeSemiBold, size: 19)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(subtitle)
                    .appFont(.figtreeRegular, size: 13)
                    .foregroundColor(Color(red: 0.62, green: 0.62, blue: 0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
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
