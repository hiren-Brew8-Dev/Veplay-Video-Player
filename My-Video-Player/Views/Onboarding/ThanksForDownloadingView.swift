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
    @State private var heartRotation: Double = 0
    
    var body: some View {
        ZStack {
            // MARK: - Background
            Color.black
                .ignoresSafeArea()
            
            // Decorative Background Accents
            Group {
                Circle()
                    .foregroundColor(Color(red: 0.98, green: 0.69, blue: 0.27).opacity(0.12))
                    .responsiveWidth(iphoneWidth: 256, ipadWidth: 400)
                    .responsiveHeight(iphoneHeight: 256, ipadHeight: 400)
                    .blur(radius: isIpad ? 120 : 80)
                    .offset(x: isIpad ? -250 : -164.50, y: isIpad ? 600 : 410)
                
                Circle()
                    .foregroundColor(Color(red: 1, green: 0.67, blue: 0.21).opacity(0.12))
                    .responsiveWidth(iphoneWidth: 256, ipadWidth: 400)
                    .responsiveHeight(iphoneHeight: 256, ipadHeight: 400)
                    .blur(radius: isIpad ? 120 : 80)
                    .offset(x: isIpad ? 250 : 161.50, y: isIpad ? -600 : -410)
            }
            .opacity(isAnimating ? 1 : 0)
            .animation(.easeIn(duration: 1.0), value: isAnimating)
            
            VStack(spacing: 0) {
                Spacer()
                    .responsiveHeight(iphoneHeight: 50, ipadHeight: 80)
                
                // MARK: - Title
                Text("Thanks For\nRating Us")
                    .appFont(.figtreeBold, size: 52)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .scaleEffect(isAnimating ? 1 : 0.95)
                    .offset(y: isAnimating ? 0 : 30)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1), value: isAnimating)
                
                Spacer()
                
                // MARK: - Central Illustration (Hand + Heart)
                ZStack {
                    // Illustration Group
                    ZStack(alignment: .top) {
                        // Heart with Animation
                        Image("heart_tfr")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .responsiveWidth(iphoneWidth: 130, ipadWidth: 70)
                            .responsivePadding(edge: .leading, fraction: -10)
                            .offset(y: isIpad ? -80 : -60)
                            .rotation3DEffect(
                                .degrees(heartRotation),
                                axis: (x: 0.0, y: 1.0, z: 0.0)
                            )
                            .animation(
                                Animation.linear(duration: 5.0)
                                    .repeatForever(autoreverses: false),
                                value: 0
                            )
                        
                        // Hand
                        Image("hand_tfr")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .responsiveWidth(iphoneWidth: 170, ipadWidth: 240)
                    }
                    
                    // Specific Red Blur behind Heart
                    Circle()
                        .fill(Color(red: 1, green: 0.36, blue: 0.36).opacity(0.20))
                        .responsiveWidth(iphoneWidth: 100, ipadWidth: 150)
                        .responsiveHeight(iphoneHeight: 100, ipadHeight: 150)
                        .blur(radius: 40)
                        .offset(y: isIpad ? -80 : -60)
                }
                .scaleEffect(isAnimating ? 1 : 0.7)
                .offset(y: isAnimating ? 0 : 50)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.3), value: isAnimating)
                
                Spacer()
                
              
                
                // MARK: - Action Button
                Button(action: {
                    HapticsManager.shared.generate(.medium)
                    navManager.push(.paywall(isFromOnboarding: true))
                }) {
                    Text("Continue")
                        .appFont(.figtreeBold, size: isIpad ? 26 : 20)
                        .foregroundColor(Color(red: 0.05, green: 0.05, blue: 0.06))
                        .aspectRatio(321/52, contentMode: .fit)
                        .responsiveWidth(iphoneWidth: 321, ipadWidth: 321)
                        .responsiveHeight(iphoneHeight: 52, ipadHeight: 52)
                        .background(Color.premiumAccent)
                        .cornerRadius(isIpad ? 50 : 40)
                }
                .responsivePadding(edge: .horizontal, fraction: isIpad ? 60 : 30)
                .responsivePadding(edge: .bottom, fraction: isIpad ? 30 : 10)
                .scaleEffect(isAnimating ? 1 : 0.9)
                .opacity(isAnimating ? 1 : 0)
                
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.6), value: isAnimating)
            }
        }
        .hideNavigationBar()
        .onAppear {
            isAnimating = true
            heartRotation = 360
            
            // Still trigger review prompt as context implies "Thanks for Rating"
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
