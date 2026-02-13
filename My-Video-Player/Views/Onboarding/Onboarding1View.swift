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
            Color(red: 0.05, green: 0.05, blue: 0.06)
                .ignoresSafeArea()
            
            // MARK: - Decorative Blurred Circles
            Group {
                Circle()
                    .foregroundColor(Color(red: 0.98, green: 0.69, blue: 0.27).opacity(0.08))
                    .frame(width: 256, height: 256)
                    .blur(radius: 80)
                    .offset(x: -164.50, y: 410)
                
                Circle()
                    .foregroundColor(Color(red: 1, green: 0.67, blue: 0.21).opacity(0.08))
                    .frame(width: 256, height: 256)
                    .blur(radius: 80)
                    .offset(x: 161.50, y: -410)
            }
            
            VStack(spacing: 0) {
                // MARK: - Header (Pagination Dots)
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 32, height: 7)
                            .background(Color(red: 1, green: 0.67, blue: 0.21))
                            .cornerRadius(24)
                        
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 7, height: 7)
                            .background(Color.white.opacity(0.50))
                            .cornerRadius(24)
                        
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 7, height: 7)
                            .background(Color.white.opacity(0.50))
                            .cornerRadius(24)
                    }
                    .responsivePadding(edge: .top, fraction: 30)
                    .responsivePadding(edge: .trailing, fraction: 30)
                }
                
                Spacer()
                
                // MARK: - Image Cards Section
                ZStack {
                    // Left Top Card
                    OnboardingImageCard(
                        imageName: "Image_1_left_top_onb_1",
                        width: 171,
                        height: 213,
                        playButtonSize: 35
                    )
                    .rotationEffect(.degrees(-8))
                    .offset(x: isAnimating ? -80 : -150, y: isAnimating ? -100 : -150)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1), value: isAnimating)
                    
                    // Right Top Card
                    OnboardingImageCard(
                        imageName: "Image_2_right_top_onb_1",
                        width: 171,
                        height: 189,
                        playButtonSize: 31.34
                    )
                    .rotationEffect(.degrees(12))
                    .offset(x: isAnimating ? 85 : 150, y: isAnimating ? -80 : -130)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: isAnimating)
                    
                    // Bottom Center Card
                    OnboardingImageCard(
                        imageName: "Image_3_bottom_center_onb_1",
                        width: 201,
                        height: 215,
                        playButtonSize: 40
                    )
                    .offset(x: -15, y: isAnimating ? 60 : 130)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: isAnimating)
                }
                .responsiveHeight(iphoneHeight: 400)
                
                Spacer()
                
                // MARK: - Text Content
                VStack(alignment: .leading, spacing: 12) {
                    Text("Play Any Video\nEffortlessly")
                        .font(Font.custom("Figtree-Bold", size: 40))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Open and play videos without extra steps.")
                        .font(Font.custom("Figtree-Regular", size: 16))
                        .foregroundColor(Color.white.opacity(0.80))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .responsivePadding(edge: .horizontal, fraction: 30)
                .offset(y: isAnimating ? 0 : 50)
                .opacity(isAnimating ? 1 : 0)
                .animation(.easeOut(duration: 0.8).delay(0.4), value: isAnimating)
                
                Spacer()
                
                // MARK: - Action Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    navManager.push(.onboarding2)
                }) {
                    Text("Continue")
                        .font(Font.custom("Figtree-Bold", size: 20))
                        .foregroundColor(Color(red: 0.05, green: 0.05, blue: 0.06))
                        .responsiveWidth(iphoneWidth: 321)
                        .responsiveHeight(iphoneHeight: 52)
                        .background(Color(red: 1, green: 0.67, blue: 0.21))
                        .cornerRadius(40)
                }
                .responsivePadding(edge: .horizontal, fraction: 30)
                .responsivePadding(edge: .bottom, fraction: 10)
                .offset(y: isAnimating ? 0 : 30)
                .opacity(isAnimating ? 1 : 0)
                .animation(.easeOut(duration: 0.8).delay(0.5), value: isAnimating)
            }
        }
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
                .responsiveFrame(minWidth: width, minHeight: height)
                .clipped()
            
            // Play Button Overlay
            Circle()
                .fill(Color.black.opacity(0.50))
                .responsiveFrame(minWidth: playButtonSize, minHeight: playButtonSize)
                .overlay(
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                        .font(.system(size: playButtonSize * 0.4))
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
