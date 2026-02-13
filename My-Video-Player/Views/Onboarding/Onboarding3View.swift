//
//  Onboarding3View.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 13/02/26.
//

import SwiftUI

struct Onboarding3View: View {
    @EnvironmentObject var navManager: NavigationManager
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // MARK: - Background
            Color(red: 0.05, green: 0.05, blue: 0.06)
                .ignoresSafeArea()
            
            // MARK: - Decorative Background Accents
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
            .opacity(isAnimating ? 1 : 0)
            .animation(.easeIn(duration: 1.0), value: isAnimating)
            
            VStack(spacing: 0) {
                // MARK: - Header (Pagination Dots)
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
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
                        
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 32, height: 7)
                            .background(Color(red: 1, green: 0.67, blue: 0.21))
                            .cornerRadius(24)
                    }
                    .responsivePadding(edge: .top, fraction: 30)
                    .responsivePadding(edge: .trailing, fraction: 30)
                }
                
                Spacer()
                
                // MARK: - Player Preview Section
                VStack(spacing: 24) {
                    // Main Player Card
                    ZStack {
                        Image("VideoPlayerThumbnail")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 355, height: 296)
                            .clipped()
                        
                        // Play Overlay
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 52, height: 52)
                            .scaleEffect(isAnimating ? 1 : 0.5)
                            .opacity(isAnimating ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.4), value: isAnimating)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 20, weight: .bold))
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 0.5)
                            )
                        
                        // Progress Bar & Controls
                        VStack {
                            Spacer()
                            
                            // Progress Bar
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 323, height: 4)
                                    .cornerRadius(16)
                                
                                Rectangle()
                                    .fill(Color(red: 1, green: 0.67, blue: 0.21))
                                    .frame(width: isAnimating ? 120 : 0, height: 4)
                                    .cornerRadius(16)
                            }
                            .padding(.bottom, 8)
                            .animation(.easeOut(duration: 1.0).delay(0.6), value: isAnimating)
                            
                            HStack {
                                Text("00:00")
                                    .font(Font.custom("Figtree-SemiBold", size: 14))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("02:23")
                                    .font(Font.custom("Figtree-SemiBold", size: 14))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                            .opacity(isAnimating ? 1 : 0)
                            .animation(.easeIn(duration: 0.5).delay(0.7), value: isAnimating)
                        }
                    }
                    .frame(width: 355, height: 296)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .scaleEffect(isAnimating ? 1 : 0.8)
                    .rotation3DEffect(.degrees(isAnimating ? 0 : 10), axis: (x: 1, y: 0, z: 0))
                    .offset(y: isAnimating ? 0 : -50)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: isAnimating)
                    
                    // Feature Tags (Centered Row)
                    HStack(alignment: .center, spacing: 12) {
                        OnboardingTag(icon: "rectangle.inset.filled", text: "Fill")
                            .rotationEffect(.degrees(-6))
                            .offset(y: 5)
                            .scaleEffect(isAnimating ? 1 : 0.5)
                            .opacity(isAnimating ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.4), value: isAnimating)
                        
                        OnboardingTag(icon: "text.bubble.fill", text: "Audio & CC")
                            .scaleEffect(isAnimating ? 1 : 0.5)
                            .opacity(isAnimating ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.5), value: isAnimating)
                        
                        OnboardingTag(text: "1.0x")
                            .rotationEffect(.degrees(6))
                            .offset(y: 5)
                            .scaleEffect(isAnimating ? 1 : 0.5)
                            .opacity(isAnimating ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.6), value: isAnimating)
                    }
                }
                .responsivePadding(edge: .top, fraction: 10)
                .responsivePadding(edge: .bottom, fraction: 20)
                
                Spacer()
                
                // MARK: - Text Content
                VStack(alignment: .leading, spacing: 12) {
                    Text("Clean Playback\nExperience")
                        .font(Font.custom("Figtree-Bold", size: 40))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .scaleEffect(isAnimating ? 1 : 0.95, anchor: .leading)
                    
                    Text("A simple player with clear controls.")
                        .font(Font.custom("Figtree-Regular", size: 16))
                        .foregroundColor(Color.white.opacity(0.80))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .responsivePadding(edge: .horizontal, fraction: 30)
                .offset(y: isAnimating ? 0 : 30)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.7), value: isAnimating)
                
                Spacer()
                
                // MARK: - Action Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    navManager.push(.onboarding4)
                }) {
                    Text("Continue")
                        .font(Font.custom("Figtree-Bold", size: 20))
                        .foregroundColor(Color(red: 0.05, green: 0.05, blue: 0.06))
                        .responsiveWidth(iphoneWidth: 321)
                        .responsiveHeight(iphoneHeight: 52)
                        .background(Color(red: 1, green: 0.67, blue: 0.21))
                        .cornerRadius(40)
                }
                .responsivePadding(edge: .bottom, fraction: 10)
                .scaleEffect(isAnimating ? 1 : 0.9)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.8), value: isAnimating)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct OnboardingTag: View {
    var icon: String? = nil
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            Text(text)
                .font(Font.custom("Figtree-SemiBold", size: 14))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.12))
        .cornerRadius(40)
    }
}

#Preview {
    Onboarding3View()
        .environmentObject(NavigationManager())
}
