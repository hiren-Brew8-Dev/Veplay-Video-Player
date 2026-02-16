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
    
    @ObservedObject var subscriptionStore = SubscriptionStore()
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
            ScrollView(showsIndicators: false) {
                VStack(spacing: isIpad ? 30 : 10) {
                   
                    ZStack {
                        
                       
                        
                        VStack(alignment: .center, spacing: 6) {
                            Text("Unlock\nUnlimited Use")
                            
                                .appFont(.manropeRegular, size: 40 )
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.4)
                                .multilineTextAlignment(.center)
                            
                        }
                        .responsivePadding(edge: .top, fraction: 0.25)
                    }
                 
                    HStack {
                        Text("Not sure? Enable free trial")
                            .appFont(.manropeMedium, size: 14)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        //MARK: Not Sure?
                        CustomButton(image: remoteConfigManager.currentSelectedPaywallPlan == 0
                                     ? .multiSwitchOnPaywall
                                     : .multiSwitchOffPaywall) {
                            HapticsManager.shared.generate(.selection)
                            withAnimation(.easeInOut(duration: 0.1)) {
                                if remoteConfigManager.currentSelectedPaywallPlan != 0 {
                                    remoteConfigManager.currentSelectedPaywallPlan = 0
                                } else {
                                    remoteConfigManager.currentSelectedPaywallPlan = 1
                                }
                            }
                        }
                                     .responsiveWidth(iphoneWidth: 0.13)
                    }
                    .padding(isIpad ? 25 : 16)
                    .background(.white.opacity(0.08)) // dark grey pill
                    .cornerRadius(isIpad ? 40 : 20)
                    .padding(.horizontal, 25)
                    .aspectRatio(345/58, contentMode: .fit)
                    
                    let weeklyPlan = subscriptionStore.subscriptions.first { $0.id == "com.wildrr.app.weekly" }
                    let yearlyPlan = subscriptionStore.subscriptions.first { $0.id == "com.wildrr.app.yearly" }
                    let lifeTimePlan = subscriptionStore.subscriptions.first { $0.id == "com.wildrr.app.lifetime" }
                    
                    HStack(spacing: isIpad ? 40 : 16) {
                        SubscriptionOption(
                            title: "Weekly",
                            price: weeklyPlan?.displayPrice ?? "$0.00",
                            duration: "per week",
                            isSelected: remoteConfigManager.currentSelectedPaywallPlan == 0,
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    remoteConfigManager.currentSelectedPaywallPlan = 0
                                    HapticsManager.shared.generateOnboardingVibrate()
                                }
                                
                            },
                            description: "Free For\n3 Days"
                        )
                        SubscriptionOption(
                            title: "Yearly",
                            price: !remoteConfigManager.isNeedToShowWeeklyPriceOnYearly ? "\(yearlyPlan?.displayPrice ?? "$0.00")" : "\(self.calculateYearToWeeklyPrice(actualPrice: yearlyPlan?.price ?? 0, currencyCode: yearlyPlan?.priceFormatStyle.currencyCode ?? "") ?? "$0.00")",
                            duration: remoteConfigManager.isNeedToShowWeeklyPriceOnYearly ? "per week" : "per year",
                            isSelected: remoteConfigManager.currentSelectedPaywallPlan == 1,
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    remoteConfigManager.currentSelectedPaywallPlan = 1
                                    HapticsManager.shared.generateOnboardingVibrate()
                                }
                                
                            },
                            description: "Party\nAll Year"
                        )
                        SubscriptionOption(
                            title: "Lifetime",
                            price: lifeTimePlan?.displayPrice ?? "$0.00",
                            duration: "one time",
                            isSelected: remoteConfigManager.currentSelectedPaywallPlan == 2,
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    remoteConfigManager.currentSelectedPaywallPlan = 2
                                    HapticsManager.shared.generateOnboardingVibrate()
                                }
                                
                            },
                            description: "Limited\nTime Offer"
                        )
                    }
                    .padding()
                    
                    
                    // MARK: No Payment Now
                    switch remoteConfigManager.currentSelectedPaywallPlan {
                    case 0 :
                        Text("\(remoteConfigManager.planInfoTitleTextYearly)Auto-renews @ just \(weeklyPlan?.displayPrice ?? "$00.00")/week")
                            .appFont(.manropeMedium, size: 14)
                    case 1 :
                        Text("Auto-renews @ just \(yearlyPlan?.displayPrice ?? "$00.00")/year")
                            .appFont(.manropeMedium, size: 14)
                    case 2 :
                        Text("Pay once, Forever yours")
                            .appFont(.manropeMedium, size: 14)
                    default :
                        Text("")
                    }
                    
                    Button(action: {
                        withAnimation(.easeIn(duration: 0.3)) {
                            HapticsManager.shared.generateOnboardingVibrate()
                            AnalyticsManager.shared.log(.userClickedTryFree)
                            switch remoteConfigManager.currentSelectedPaywallPlan {
                            case 0:
                                self.purchaseProduct(purchaseProduct: weeklyPlan)
                            case 1:
                                self.purchaseProduct(purchaseProduct: yearlyPlan)
                            case 2:
                                self.purchaseProduct(purchaseProduct: lifeTimePlan)
                            default:
                                self.purchaseProduct(purchaseProduct: weeklyPlan)
                            }
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .aspectRatio(355/64, contentMode: .fit)
                                .shadow(radius: 4)
                                .cornerRadius(60)
                            
                            Text(remoteConfigManager.currentSelectedPaywallPlan == 0 &&  remoteConfigManager.isTrialPriceUnabled ? "\(remoteConfigManager.continueBtnText) \(formattedTrialPrice(for: yearlyPlan))" : "Continue")
                                .appFont(.manropeRegular, size: 20)
                                .foregroundStyle(.black)
                        }
                        .responsiveWidth(iphoneWidth: 0.95, ipadWidth: 0.6)
                    }
                    
                    .responsiveWidth(iphoneWidth: 0.95, ipadWidth: 0.6)
                    .padding(.horizontal, isIpad ? 80 : 20)
                    .padding(.top, isIpad ? 15 : 8)
                    .disabled(isProccesing)
                    
                    Text("🔒 Secured with iTunes. Cancel anytime")
                        .appFont(.manropeMedium, size: 13)
                        .padding(.vertical)
                      
                    VStack(spacing: 10) {
                        
                        HStack(spacing: isIpad ? 16 : 8) {
                            
                            FooterLinkButton(text: "Restore") {
                                withAnimation(.easeIn(duration: 0.2)) {
                                    HapticsManager.shared.generateOnboardingVibrate()
                                    restorePurchase()
                                    AnalyticsManager.shared.log(.userClickedRestore)
                                }
                            }
                            
                            Rectangle()
                                .frame(width: isIpad ? 1 : 0.5, height:  isIpad ? 18 : 15)
                                .foregroundColor(.white)
                                .padding(.horizontal, 3)
                            
                            FooterLinkButton(text: "Privacy policy", action: {
                                HapticsManager.shared.generate(.light)
                                withAnimation(.easeIn(duration: 0.2)) {
                                    openWebPage("https://sites.google.com/view/shivshankarapps/privacy-policy", title: "Privacy Policy")
                                    AnalyticsManager.shared.log(.privacyPolicyTapped)
                                }
                            })
                            
                            Rectangle()
                                .frame(width:  isIpad ? 1 : 0.5, height:  isIpad ? 18 : 15)
                                .foregroundColor(.white)
                                .padding(.horizontal, 3)
                            
                            FooterLinkButton(text: "Terms of use", action: {
                                HapticsManager.shared.generate(.light)
                                withAnimation(.easeIn(duration: 0.2)) {
                                    
                                    openWebPage("https://sites.google.com/view/shivshankarapps/terms-conditions", title: "Terms & Conditions")
                                    
                                    AnalyticsManager.shared.log(.termsAndConditionTapped)
                                }
                            })
                        }
                        .padding(.top, -10)
                        
                        
                        Text("Premium membership unlocks all the packs and content. This is an auto-renew subscription. Subscriptions will automatically renew and you will be charged for renewal within 24 hours prior to end of each period unless auto renew is tuned off at least 24-hours before the end of each period. You can manage your subscription settings and auto-renewal may turned off by going to Apple ID Account Settings after purchase.")
                            .foregroundStyle(.gray)
                            .appFont(.manropeRegular, size: 10)
                        
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    
                    Spacer()
                }
                .responsivePadding(edge: .top, fraction: isIpad ? -0.03 : -0.04)
                
                .scrollIndicators(.hidden)
                
            }
            
            .scrollBounceBehavior(.basedOnSize)
            .responsiveWidth(iphoneWidth: 1.0, ipadWidth: 0.5)
            
            VStack {
                
                HStack {
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.easeIn(duration: 0.2)) {
                            HapticsManager.shared.generateOnboardingVibrate()
                            if isFromIntialPaywall {
                                isNeedToMoveToInitialDetails.toggle()
                            } else {
                                if isFromOnboarding {
                                    navigationManager.push(.dashboard)
                                } else {
                                    navigationManager.pop()
                                }
                            }
                            AnalyticsManager.shared.log(.skipButtonTapped)
                        }
                    } label: {
                        if isNeedToShowCross {
                            Image(.closePaywall)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30)
                                .padding(.vertical, 5)
                                .shadow(radius: 10)
                        }
                    }
                }
                
                Spacer()
            }
            .responsivePadding(edge: .top, fraction: 0.07)
            .responsivePadding(edge: .trailing, fraction: 0.1)
            
            
            
            if !subscriptionStore.isReady || isProccesing {
                loaderOverlay()
                    .transition(.opacity)
            }
            
            
        }
        .navigationBarBackButtonHidden()
        .ignoresSafeArea()
        .fullScreenCover(item: $webViewData) { data in
            URLWebView(titleName: data.title, urlString: data.url)
        }
        
        .navigationDestination(isPresented: $isNeedToMoveToInitialDetails, destination: {
            Onboarding1View()
        })
        .onAppear {
            checkPaywallXTypes()
            
            // Print trial info for debugging
             if let weekly = subscriptionStore.subscriptions.first(where: { $0.id == "com.wildrr.app.weekly" }) {
                 print("Intro Offer Weekly:", weekly.subscription?.introductoryOffer as Any)
             }

             if let yearly = subscriptionStore.subscriptions.first(where: { $0.id == "com.wildrr.app.yearly" }) {
                 print("Intro Offer Yearly:", yearly.subscription?.introductoryOffer as Any)
             }
            
            // Trigger the animation for each feature row
            for i in 0..<featureVisibility.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                    featureVisibility[i] = true
                }
            }
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
                        
                        if purchaseProduct?.id == "com.wildrr.app.weekly" {
                            AppReviewManager.submitReview(isShowAppleReviewScreen: false)
                        }
                        if isFromIntialPaywall {
                            
                            navigationManager.push(.onboarding1)
                        } else if isFromOnboarding {
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
                if isFromIntialPaywall {
                    navigationManager.push(.onboarding1)
                } else if isFromOnboarding {
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
            Rectangle()
                .fill(.white.opacity(0.9))
                .frame(width: 80, height: 80)
                .cornerRadius(15)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                .scaleEffect(1.5)
        }
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
                .appFont(.manropeMedium, size: 15)
            
                .foregroundColor(.white)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(icon)
                .resizable()
                .frame(width: isIpad ? 24 : 20, height: isIpad ? 24 : 20)
            Text(text)
                .appFont(.manropeMedium, size: 18)
                .tracking(1.0)
                .foregroundColor(.white)
            
        }
    }
}

struct SubscriptionOption: View {
    var title: String
    var price: String
    var duration: String
    var isSelected: Bool
    var onSelect: () -> Void
    var description: String
    
    var body: some View {
        ZStack {
            VStack(alignment: .center, spacing: 0) {
                
                VStack(spacing: 6) {
                    Text(title)
                        .appFont(.manropeMedium, size: 16)
                    
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(price)
                        .appFont(.manropeMedium, size: 18)
                    
                        .foregroundColor(.white)
                    
                    
                    Text(duration)
                        .appFont(.manropeMedium, size: 14)
                    
                        .foregroundColor(.white)
                }
                .padding(.top, 14)
                
                Spacer()
                
                ZStack(alignment: .center) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.white : .white.opacity(0.12))
                        .aspectRatio(115/53, contentMode: .fit)
                        .padding([.leading, .trailing], 5)
                    
                    Text(description)
                        .appFont(.manropeBold, size: 14)
                    
                        .foregroundColor(isSelected ? .black : .white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding([.leading, .trailing], 6)
                }
                .padding(.bottom, 5)
            }
            .aspectRatio(110/154, contentMode: .fit)
            .responsiveWidth(iphoneWidth: 0.28, ipadWidth: 0.2)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.12), lineWidth: 2)
            )
            .onTapGesture {
                onSelect()
            }
        }
    }
}

#Preview {
    PaywallView()
}


