//
//  RatingView.swift
//  My-Video-Player
//

import SwiftUI
import StoreKit

struct RatingView: View {
    @EnvironmentObject var navigationManager: NavigationManager
    
    @State private var showTop = false
    @State private var heartScale: CGFloat = 1.0
    @State private var showHeart = false
    @State private var showButton = false
    
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted: Bool = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: isIpad ? 40 : 20) {
                VStack(spacing: 8) {
                    Text("Thanks for\nDownloading")
                        .appFont(.manropeBold, size: 40)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("You’ve not just downloaded our app, but you’ve given us the opportunity to help you make your phone clean. We’re glad to have you here!\n\n~Team Video Player")
                        .appFont(.manropeRegular, size: 16)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                }
                .opacity(showTop ? 1 : 0)
                .offset(y: showTop ? 0 : -50)
                
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color(hex: "F9B041").opacity(0.1))
                        .frame(width: 250, height: 250)
                    
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Color(hex: "F9B041"))
                        .scaleEffect(heartScale)
                }
                .opacity(showHeart ? 1 : 0)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                    ) {
                        heartScale = 1.1
                    }
                }
                
                Spacer()
                
                CustomTextButton(
                    title: "Continue",
                    aspectRatio: 345/52,
                    iphoneWidth: 345,
                    ipadWidth: 250,
                    foregroundColor: .black,
                    backgroundColor: Color(hex: "F9B041"),
                    cornerRadius: 26
                ) {
                    isOnboardingCompleted = true
                    HapticsManager.shared.generate(.soft)
                    navigationManager.push(.dashboard)
                }
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 50)
            }
            .padding(.vertical, 60)
        }
        .onAppear { animateIn() }
        .hideNavigationBar()
    }
    
    private func animateIn() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) { showTop = true }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.3)) { showHeart = true }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.5)) { showButton = true }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            AppReviewManager.submitReview(isShowAppleReviewScreen: false)
        }
    }
}

#Preview {
    RatingView()
        .environmentObject(NavigationManager())
}
