//
//  Onboarding1View.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 13/02/26.
//

import SwiftUI

struct Onboarding1View: View {
    @EnvironmentObject var navManager: NavigationManager
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // MARK: - Background
            Color.black
                .ignoresSafeArea()
            
            // MARK: - Decorative Blurred Circles
            Group {
                Circle()
                    .foregroundColor(.bgBlurOrange1.opacity(0.08))
                    .frame(width: isIpad ? 400 : 256, height: isIpad ? 400 : 256)
                    .blur(radius: isIpad ? 120 : 80)
                    .offset(x: isIpad ? -250 : -164.50, y: isIpad ? 600 : 410)
                
                Circle()
                    .foregroundColor(.bgBlurOrange2.opacity(0.08))
                    .frame(width: isIpad ? 400 : 256, height: isIpad ? 400 : 256)
                    .blur(radius: isIpad ? 120 : 80)
                    .offset(x: isIpad ? 250 : 161.50, y: isIpad ? -600 : -410)
            }
            
            VStack(spacing: 0) {
                // MARK: - Header (Pagination Dots)
                HStack {
                    Spacer()
                    HStack(spacing: isIpad ? 6 : 4) {
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: isIpad ? 48 : 32, height: isIpad ? 10 : 7)
                            .background(Color.premiumAccent)
                            .cornerRadius(24)
                        
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: isIpad ? 10 : 7, height: isIpad ? 10 : 7)
                            .background(Color.white.opacity(0.50))
                            .cornerRadius(24)
                        
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: isIpad ? 10 : 7, height: isIpad ? 10 : 7)
                            .background(Color.white.opacity(0.50))
                            .cornerRadius(24)
                    }
                    .responsivePadding(edge: .top, fraction: isIpad ? 50 : 30)
                    .responsivePadding(edge: .trailing, fraction: isIpad ? 50 : 30)
                }
                
                Spacer()
                
                // MARK: - Image Cards Section
                ZStack {
                   
                    // Right Top Card
                    OnboardingImageCard(
                        imageName: "Image_2_right_top_onb_1",
                        width: isIpad ? 121 : 171,
                        height: isIpad ? 139 : 189,
                        playButtonSize: isIpad ? 21.34 : 31.34
                    )
                    .rotationEffect(.degrees(12))
                    .scaleEffect(isAnimating ? 1 : 0.6)
                    .offset(
                        x: isAnimating ? (isIpad ? 130 : 85) : (isIpad ? 150 : 150),
                        y: isAnimating ? (isIpad ? -80 : 10) : (isIpad ? -130 : -130)
                    )
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: isAnimating)
                    
                    
                    // Left Top Card
                    OnboardingImageCard(
                        imageName: "Image_1_left_top_onb_1",
                        width: isIpad ? 131 : 171,
                        height: isIpad ? 163 : 213,
                        playButtonSize: isIpad ? 25 : 35
                    )
                    .rotationEffect(.degrees(-8))
                    .scaleEffect(isAnimating ? 1 : 0.6)
                    .offset(
                        x: isAnimating ? (isIpad ? -130 : -80) : (isIpad ? -150 : -150),
                        y: isAnimating ? (isIpad ? -100 : -10) : (isIpad ? -150 : -150)
                    )
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: isAnimating)
                    
                    
                    // Bottom Center Card
                    OnboardingImageCard(
                        imageName: "Image_3_bottom_center_onb_1",
                        width: isIpad ? 141: 210,
                        height: isIpad ? 125 : 230,
                        playButtonSize: isIpad ? 30 : 40
                    )
                    .scaleEffect(isAnimating ? 1 : 0.7)
                    .offset(x: isIpad ? 0 : -15, y: isAnimating ? (isIpad ? 140 : 100) : (isIpad ? 300 : 130))
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.3), value: isAnimating)
                }
                .frame(height: isIpad ? 500 : 400)
                
                Spacer()
                
                // MARK: - Text Content
                VStack(alignment: .leading, spacing: isIpad ? 18 : 12) {
                    Text("Play Any Video\nEffortlessly")
                        .appFont(.figtreeBold, size: isIpad ? 40 : 40)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .scaleEffect(isAnimating ? 1 : 0.95, anchor: .leading)
                    
                    Text("Open and play videos without extra steps.")
                        .appFont(.figtreeRegular, size: isIpad ? 16 : 16)
                        .foregroundColor(Color.white.opacity(0.80))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .responsivePadding(edge: .horizontal, fraction: isIpad ? 60 : 30)
                .offset(y: isAnimating ? 0 : 30)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4), value: isAnimating)
                
                Spacer()
                
                // MARK: - Action Button
                Button(action: {
                    HapticsManager.shared.generate(.medium)
                    navManager.push(.onboarding2)
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
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: isAnimating)
            }
        }
        .hideNavigationBar()
        .onAppear {
            isAnimating = true
        }
    }
}

struct OnboardingImageCard: View {
    let imageName: String
    let width: CGFloat
    let height: CGFloat
    let playButtonSize: CGFloat
    
    var body: some View {
        ZStack {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .responsiveWidth(iphoneWidth: width)
               
                .clipped()
            
            // Play Button Overlay
            Circle()
                .fill(Color.black.opacity(0.50))
                .responsiveWidth(iphoneWidth: playButtonSize)
                
                .overlay(
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                        .font(.system(size: playButtonSize * ( isIpad ? 0.7 : 0.4)))
                )
                .overlay(
                    Circle()
                        .inset(by: 0.38)
                        .stroke(.white, lineWidth: 0.38)
                )
        }
        .cornerRadius(16)
       
    
    }
}

#Preview {
    Onboarding1View()
        .environmentObject(NavigationManager())
}
