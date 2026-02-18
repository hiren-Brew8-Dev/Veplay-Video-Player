//
//  ThanksForDownloadingView.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 13/02/26.
//

import SwiftUI

struct ThanksForDownloadingView: View {
    @EnvironmentObject var navManager: NavigationManager
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted = false
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // MARK: - Background
            Color.black
                .ignoresSafeArea()
            
            // Decorative Blurred Circles
            Group {
                Circle()
                    .foregroundColor(.bgBlurOrange1.opacity(0.2))
                    .responsiveWidth(iphoneWidth: 256)
                    .responsiveHeight(iphoneHeight: 256)
                    .blur(radius: 80)
                    .offset(x: -164.50, y: 410)
                
                Circle()
                    .foregroundColor(.bgBlurOrange2.opacity(0.2))
                    .responsiveWidth(iphoneWidth: 256)
                    .responsiveHeight(iphoneHeight: 256)
                    .blur(radius: 80)
                    .offset(x: 161.50, y: -410)
            }
            
            VStack(spacing: 0) {
                Spacer()
                    .responsiveHeight(iphoneHeight: 80)
                
                // MARK: - Title
                Text("Thanks for\nDownloading")
                    .appFont(.figtreeBold, size: 52)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .scaleEffect(isAnimating ? 1 : 0.9)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1), value: isAnimating)
                
                Spacer()
                
                // MARK: - Message Card
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 0) {
                        // Message Text
                        Text("You’ve not just downloaded our app, but you’ve given us the opportunity to help you make your phone clean. We’re glad to have you here!")
                            .appFont(.figtreeMedium, size: 18)
                            .lineSpacing(10)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                            .responsiveWidth(iphoneWidth: 15)
                        
                        // Hand/Heart Illustration Group
                        ZStack (alignment: .top){
                            // Orange Glow
                            
                            VStack(spacing: -30) {
                                Image("heart_tfr")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .responsiveWidth(iphoneWidth: 60)
                                    .responsiveHeight(iphoneHeight: 60)
                                
                                Image("hand_tfr")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .responsiveWidth(iphoneWidth: 70)
                                    .responsiveHeight(iphoneHeight: 120)
                            }
                            .responsivePadding(edge: .top, fraction: -20)
                        }
                        .scaleEffect(isAnimating ? 1 : 0.6)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.4), value: isAnimating)
                    }
                    
                    
                    Spacer()
                    
                    // Team Signature
                    Text("~Team Video Player")
                        .appFont(.figtreeBold, size: 20)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                
                .responsivePadding(edge: .all, fraction: 20)
                .aspectRatio(321/365, contentMode: .fit)
                .responsiveWidth(iphoneWidth: 321, ipadWidth : 230)
                .background(
                    ZStack {
                        Color(red: 1, green: 1, blue: 1).opacity(0.10)
                        
    
                    }
                )
                .cornerRadius(isIpad ? 27 : 24)
                .offset(y: isAnimating ? 0 : 50)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: isAnimating)
                
                Spacer()
                
                // MARK: - Action Button
                Button(action: {
                    HapticsManager.shared.generate(.medium)
                    isOnboardingCompleted = true
                   
                    if !Global.shared.getIsUserPro() {
                        navManager.push(.paywall(isFromOnboarding: true))
                    } else {
                        navManager.push(.dashboard)
                    }
                }) {
                    Text("Continue")
                        .appFont(.figtreeBold, size: 20)
                        .foregroundColor(Color(red: 0.05, green: 0.05, blue: 0.06))
                        .responsiveWidth(iphoneWidth: 321)
                        .responsiveHeight(iphoneHeight: 52)
                        .background(Color.premiumAccent)
                        .cornerRadius(40)
                }
                .responsivePadding(edge: .bottom, fraction: 20)
                .scaleEffect(isAnimating ? 1 : 0.8)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: isAnimating)
            }
            .responsivePadding(edge: .horizontal, fraction: 30)
        }
        .hideNavigationBar()
        .onAppear {
            isAnimating = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                AppReviewManager.submitReview()
            }
        }
    }
}

#Preview {
    ThanksForDownloadingView()
        .environmentObject(NavigationManager())
        .environmentObject(DashboardViewModel())
}
