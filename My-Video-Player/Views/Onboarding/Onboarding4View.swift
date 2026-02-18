//
//  Onboarding4View.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 13/02/26.
//

import SwiftUI
import Photos

struct Onboarding4View: View {
    @EnvironmentObject var navManager: NavigationManager
    @EnvironmentObject var viewModel: DashboardViewModel
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // ... (rest of the view)
            // MARK: - Background
            Color.black
                .ignoresSafeArea()
            
            // MARK: - Decorative Background Accents
            Group {
                Circle()
                    .foregroundColor(.bgBlurOrange1.opacity(0.2))
                    .frame(width: isIpad ? 400 : 256, height: isIpad ? 400 : 256)
                    .blur(radius: isIpad ? 120 : 80)
                    .offset(x: isIpad ? -250 : -164.50, y: isIpad ? 600 : 410)
                
                Circle()
                    .foregroundColor(.bgBlurOrange2.opacity(0.2))
                    .frame(width: isIpad ? 400 : 256, height: isIpad ? 400 : 256)
                    .blur(radius: isIpad ? 120 : 80)
                    .offset(x: isIpad ? 250 : 161.50, y: isIpad ? -600 : -410)
            }
            .opacity(isAnimating ? 1 : 0)
            .animation(.easeIn(duration: 1.0), value: isAnimating)
            
            VStack(spacing: 0) {
                Spacer()
                
                // MARK: - Central Illustration
                ZStack {
                    // Large Transparent Circle
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: isIpad ? 240 : 160, height: isIpad ? 240 : 160)
                        .scaleEffect(isAnimating ? 1 : 0.5)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: isAnimating)
                    
                    // Main Icon (Stacked Effect)
                    VStack(spacing: isIpad ? 12 : 8) {
                        // Top line
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.5))
                            .frame(width: isIpad ? 67 : 45, height: isIpad ? 6 : 4)
                        
                        // Middle line
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.8))
                            .frame(width: isIpad ? 94 : 63, height: isIpad ? 6 : 4)
                        
                        // Main Block
                        ZStack {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.white)
                                .frame(width: isIpad ? 120 : 80, height: isIpad ? 85 : 57)
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: isIpad ? 48 : 32))
                                .foregroundColor(Color(red: 0.09, green: 0.06, blue: 0.03))
                        }
                    }
                    .scaleEffect(isAnimating ? 1 : 0.3)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.2), value: isAnimating)
                    
                    // Lock Overlay (Pill Shape)
                    ZStack {
                        VStack {
                            Image(systemName: "lock.fill")
                                .font(.system(size: isIpad ? 36 : 24, weight: .bold))
                                .foregroundColor(Color(red: 0.09, green: 0.06, blue: 0.03))
                        }
                        .padding(.vertical, isIpad ? 20 : 13)
                        .padding(.horizontal, isIpad ? 15 : 10)
                        .background(Color.premiumAccent)
                        .cornerRadius(56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 56)
                                .stroke(Color(red: 0.09, green: 0.06, blue: 0.03), lineWidth: 3)
                        )
                    }
                    .offset(x: isIpad ? 90 : 60, y: isIpad ? 80 : 55)
                    .scaleEffect(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.5), value: isAnimating)
                }
                .responsivePadding(edge: .bottom, fraction: isIpad ? 80 : 50)
                
                // MARK: - Description Text
                Text("Allow access to your videos to begin.")
                    .appFont(.figtreeMedium, size: isIpad ? 18 : 16)
                    .foregroundColor(Color.white.opacity(0.80))
                    .multilineTextAlignment(.center)
                    .offset(y: isAnimating ? 0 : 20)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.6), value: isAnimating)
                
                Spacer()
                    .responsiveHeight(iphoneHeight: isIpad ? 150 : 100)
                
                // MARK: - Main Title
                Text("Let’s Get Started")
                    .appFont(.figtreeBold, size: isIpad ? 60 : 40)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .scaleEffect(isAnimating ? 1 : 0.9)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.7), value: isAnimating)
                
                Spacer()
                
                // MARK: - Action Button
                Button(action: {
                    HapticsManager.shared.generate(.medium)
                    checkPhotoPermission()
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
                .responsivePadding(edge: .bottom, fraction: isIpad ? 30 : 10)
                .scaleEffect(isAnimating ? 1 : 0.8)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.8), value: isAnimating)
            }
            .responsivePadding(edge: .horizontal, fraction: 30)
        }
        .hideNavigationBar()
        .onAppear {
            isAnimating = true
        }
    }
    
    private func checkPhotoPermission() {
        viewModel.requestPhotoPermission { _ in
            // Even if denied, we proceed in onboarding to keep flow,
            // but user won't see videos until they fix it in settings.
            proceedToNext()
        }
    }
    
    private func proceedToNext() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        navManager.push(.thanksForDownloading)
    }
}

#Preview {
    Onboarding4View()
        .environmentObject(NavigationManager())
        .environmentObject(DashboardViewModel())
}
