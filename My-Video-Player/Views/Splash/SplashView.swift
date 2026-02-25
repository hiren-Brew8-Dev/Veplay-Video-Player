//
//  SplashView.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 13/02/26.
//

import SwiftUI
struct SplashView : View {
    
    
    @EnvironmentObject var navigationManager: NavigationManager
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted = false
    
    @State private var hasNavigated = false
    @State private var timerScheduled = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var textOffset: CGFloat = 20
    @State private var textOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Decorative background circles
            Group {
                Circle()
                    .fill(Color.bgBlurOrange1.opacity(0.12))
                    .responsiveWidth(iphoneWidth: 280, ipadWidth: 500)
                    .blur(radius: isIpad ? 100 : 70)
                    .offset(x: isIpad ? -150 : -80, y: isIpad ? -300 : -200)
                
                Circle()
                    .fill(Color.bgBlurOrange2.opacity(0.12))
                    .responsiveWidth(iphoneWidth: 280, ipadWidth: 500)
                    .blur(radius: isIpad ? 150 : 80)
                    .offset(x: isIpad ? 150 : 80, y: isIpad ? 300 : 200)
            }
            .opacity(logoOpacity)
            
            ZStack {
                // Logo perfectly centered on screen
                Image("splash_app_icon")
                    .resizable()
                    .aspectRatio(1.0, contentMode: .fit)
                    .responsiveWidth(iphoneWidth: 120, ipadWidth: 100)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                
                // App Name at the bottom
                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("Veplay")
                            .appFont(.figtreeBold, size: 28)
                            .foregroundColor(.white)
                        
                        Text("Video Player")
                            .appFont(.figtreeRegular, size: 14)
                            .foregroundColor(.white.opacity(0.6))
                            .kerning(2)
                    }
                    .responsivePadding(edge: .bottom, fraction: 40)
                    .offset(y: textOffset)
                    .opacity(textOpacity)
                }
            }
        }
        .hideNavigationBar()
        .onAppear {
            if !timerScheduled {
                timerScheduled = true
                animateIn()
                
                // Route to next screen after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    routeNext()
                }
            }
        }
    }
    
    
    private func routeNext() {
        guard !hasNavigated && !navigationManager.isDashboardRoot else { return }
        hasNavigated = true
        
        if !isOnboardingCompleted {
            navigationManager.push(.onboarding1)
        } else {
            if !Global.shared.getIsUserPro() {
                navigationManager.push(.paywall(isFromOnboarding: true))
            } else {
                navigationManager.push(.dashboard)
            }
        }
    }
    
    private func animateIn() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
            textOffset = 0
            textOpacity = 1.0
        }
        
        // Haptic feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            HapticsManager.shared.generate(.medium)
        }
    }
}


#Preview {
    SplashView()
}
