//
//  Onboarding4View.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 13/02/26.
//

import SwiftUI

struct Onboarding4View: View {
    @EnvironmentObject var navManager: NavigationManager
    @State private var isAnimating = false
    @State private var currentTime: Double = 0
    
    private var formattedCurrentTime: String {
        let minutes = Int(currentTime) / 60
        let seconds = Int(currentTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        ZStack {
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
                // MARK: - Header (Pagination Dots)
                HStack {
                    Spacer()
                    HStack(spacing: isIpad ? 6 : 4) {
                        ForEach(0..<5) { index in
                            Rectangle()
                                .foregroundColor(.clear)
                                .frame(width: index == 3 ? (isIpad ? 48 : 32) : (isIpad ? 10 : 7), height: isIpad ? 10 : 7)
                                .background(index == 3 ? Color.premiumAccent : Color.white.opacity(0.30))
                                .cornerRadius(24)
                        }
                    }
                    .responsivePadding(edge: .top, fraction: isIpad ? 50 : 30)
                    .responsivePadding(edge: .trailing, fraction: isIpad ? 50 : 30)
                }
                
                Spacer()
                
                // MARK: - Player Preview Section
                VStack(spacing: isIpad ? 40 : 24) {
                    // Main Player Card
                    ZStack {
                        Image("VideoPlayerThumbnail")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: isIpad ? 480 : 355, height: isIpad ? 400 : 296)
                            .clipped()
                        
                        // Play Overlay
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: isIpad ? 72 : 52, height: isIpad ? 72 : 52)
                            .scaleEffect(isAnimating ? 1 : 0.5)
                            .opacity(isAnimating ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.4), value: isAnimating)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: isIpad ? 28 : 20, weight: .bold))
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
                                    .frame(width: isIpad ? 440 : 323, height: isIpad ? 6 : 4)
                                    .cornerRadius(16)
                                
                                Rectangle()
                                    .fill(Color.premiumAccent)
                                    .frame(width: isAnimating ? (isIpad ? 160 : 120) : 0, height: isIpad ? 6 : 4)
                                    .cornerRadius(16)
                            }
                            .padding(.bottom, isIpad ? 12 : 8)
                            .animation(.easeOut(duration: 1.0).delay(0.6), value: isAnimating)
                            
                            HStack {
                                Text(formattedCurrentTime)
                                    .appFont(.figtreeSemiBold, size: isIpad ? 18 : 14)
                                    .foregroundColor(.white)
                                    .frame(width: isIpad ? 60 : 45, alignment: .leading) // Fixed width to prevent shifting
                                Spacer()
                                Text("02:23")
                                    .appFont(.figtreeSemiBold, size: isIpad ? 18 : 14)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, isIpad ? 24 : 16)
                            .padding(.bottom, isIpad ? 24 : 16)
                            .opacity(isAnimating ? 1 : 0)
                            .animation(.easeIn(duration: 0.5).delay(0.7), value: isAnimating)
                        }
                    }
                    .frame(width: isIpad ? 480 : 355, height: isIpad ? 400 : 296)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(isIpad ? 40 : 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: isIpad ? 40 : 32)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .scaleEffect(isAnimating ? 1 : 0.8)
                    .rotation3DEffect(.degrees(isAnimating ? 0 : 10), axis: (x: 1, y: 0, z: 0))
                    .offset(y: isAnimating ? 0 : -50)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: isAnimating)
                    
                    // Feature Tags (Centered Row)
                    HStack(alignment: .center, spacing: isIpad ? 20 : 12) {
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
                .responsivePadding(edge: .top, fraction: isIpad ? 20 : 10)
                .responsivePadding(edge: .bottom, fraction: isIpad ? 40 : 20)
                
                Spacer()
                
                // MARK: - Text Content
                VStack(alignment: .leading, spacing: isIpad ? 18 : 12) {
                    Text("Clean Playback\nExperience")
                        .appFont(.figtreeBold, size: isIpad ? 40 : 40)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .scaleEffect(isAnimating ? 1 : 0.95, anchor: .leading)
                    
                    Text("A simple player with clear controls.")
                        .appFont(.figtreeRegular, size: isIpad ? 16 : 16)
                        .foregroundColor(Color.white.opacity(0.80))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .responsivePadding(edge: .horizontal, fraction: isIpad ? 60 : 30)
                .offset(y: isAnimating ? 0 : 30)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.7), value: isAnimating)
                
                Spacer()
                
                // MARK: - Action Button
                Button(action: {
                    HapticsManager.shared.generate(.medium)
                    navManager.push(.onboarding5)
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
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.8), value: isAnimating)
            }
        }
        .hideNavigationBar()
        .onAppear {
            isAnimating = true
            
            // Sync current time label with progress bar animation
            // Progress bar animation starts at 0.6s delay and lasts 1.0s
            // Total duration is 02:23 (143s). Progress is ~37% (120/323)
            let totalSeconds: Double = 143
            let progress = isIpad ? (160.0 / 440.0) : (120.0 / 323.0)
            let targetSeconds = totalSeconds * progress
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                let steps = 30
                let interval = 1.0 / Double(steps)
                let increment = targetSeconds / Double(steps)
                
                Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
                    if currentTime < targetSeconds {
                        currentTime += increment
                    } else {
                        currentTime = targetSeconds
                        timer.invalidate()
                    }
                }
            }
        }
    }
}

struct OnboardingTag: View {
    var icon: String? = nil
    let text: String
    
    var body: some View {
        HStack(spacing: isIpad ? 12 : 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: isIpad ? 18 : 14))
                    .foregroundColor(.white)
            }
            Text(text)
                .appFont(.figtreeSemiBold, size: isIpad ? 18 : 14)
                .foregroundColor(.white)
        }
        .padding(.horizontal, isIpad ? 24 : 16)
        .padding(.vertical, isIpad ? 15 : 10)
        .background(Color.white.opacity(0.12))
        .cornerRadius(isIpad ? 50 : 40)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.6),
                            .white.opacity(0.1),
                            .white.opacity(0.05),
                            .white.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    Onboarding4View()
        .environmentObject(NavigationManager())
}
