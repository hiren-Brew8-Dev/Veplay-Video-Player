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
    
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var textOffset: CGFloat = 20
    @State private var textOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // App Icon / Logo
                ZStack {
                    Circle()
                        .fill(Color.premiumAccent.opacity(0.1))
                        .frame(width: 140, height: 140)
                        .blur(radius: 20)
                    
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.premiumAccent)
                        .shadow(color: .premiumAccent.opacity(0.4), radius: 15)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                
                // App Name
                VStack(spacing: 8) {
                    Text("My Video Player")
                        .appFont(.figtreeBold, size: 28)
                        .foregroundColor(.white)
                    
                    Text("Pro Media Experience")
                        .appFont(.figtreeRegular, size: 14)
                        .foregroundColor(.white.opacity(0.6))
                        .kerning(2)
                }
                .offset(y: textOffset)
                .opacity(textOpacity)
            }
        }
        .hideNavigationBar()
        .onAppear {
            animateIn()
            
            // Route to next screen after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                routeNext()
            }
        }
    }
    
    
    private func routeNext() {
        if !isOnboardingCompleted {
            navigationManager.push(.onboarding1)
        } else {
            // Onboarding done → show paywall first, it will navigate to dashboard on dismiss
            navigationManager.push(.paywall(isFromOnboarding: true))
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
