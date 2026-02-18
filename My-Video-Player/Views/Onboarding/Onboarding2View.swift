//
//  Onboarding2View.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 18/02/26.
//

import SwiftUI

struct Onboarding2View: View {
    @EnvironmentObject var navManager: NavigationManager
    @State private var isAnimating = false
    
    // File formats to display
    let formatsTop = ["webm", "m4v", "mgp"]
    let formatsMid1 = ["mp4", "swf", "mov"]
    let formatsMid2 = ["ogv", "mkv", "mts"]
    let formatsBottom = ["avi", "ts", "3gp"]
    
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
                                .frame(width: index == 1 ? (isIpad ? 48 : 32) : (isIpad ? 10 : 7), height: isIpad ? 10 : 7)
                                .background(index == 1 ? Color.premiumAccent : Color.white.opacity(0.30))
                                .cornerRadius(24)
                        }
                    }
                    .responsivePadding(edge: .top, fraction: isIpad ? 50 : 30)
                    .responsivePadding(edge: .trailing, fraction: isIpad ? 50 : 30)
                }
                
                Spacer()
                
                // MARK: - Formats Badges Section
                VStack(spacing: isIpad ? 30 : 20) {
                    // Top Row
                    HStack(spacing: isIpad ? 25 : 15) {
                        FormatBadge(text: "webm", isAnimating: isAnimating)
                            .offset(y: isAnimating ? 10 : 30)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: isAnimating)
                        
                        FormatBadge(text: "m4v", isPrimary: true, isAnimating: isAnimating)
                            .offset(y: isAnimating ? 0 : 40)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: isAnimating)
                        
                        FormatBadge(text: "mgp", isAnimating: isAnimating)
                            .offset(y: isAnimating ? 10 : 35)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15), value: isAnimating)
                    }
                    
                    // Middle Row 1
                    HStack(spacing: isIpad ? 25 : 15) {
                        FormatBadge(text: "mp4", isPrimary: true, isAnimating: isAnimating)
                            .offset(y: isAnimating ? 0 : 45)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.25), value: isAnimating)
                        
                        FormatBadge(text: "swf", isAnimating: isAnimating)
                            .offset(y: isAnimating ? -10 : 25)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: isAnimating)
                        
                        FormatBadge(text: "mov", isPrimary: true, isAnimating: isAnimating)
                            .offset(y: isAnimating ? 0 : 50)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: isAnimating)
                    }
                    
                    // Middle Row 2
                    HStack(spacing: isIpad ? 25 : 15) {
                        FormatBadge(text: "ogv", isAnimating: isAnimating)
                            .offset(y: isAnimating ? -5 : 40)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: isAnimating)
                        
                        FormatBadge(text: "mkv", isPrimary: true, isAnimating: isAnimating)
                            .offset(y: isAnimating ? 0 : 30)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.35), value: isAnimating)
                        
                        FormatBadge(text: "mts", isAnimating: isAnimating)
                            .offset(y: isAnimating ? -5 : 45)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15), value: isAnimating)
                    }
                    
                    // Bottom Row
                    HStack(spacing: isIpad ? 25 : 15) {
                        FormatBadge(text: "avi", isPrimary: true, isAnimating: isAnimating)
                            .offset(y: isAnimating ? 0 : 35)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: isAnimating)
                        
                        FormatBadge(text: "ts", isAnimating: isAnimating)
                            .offset(y: isAnimating ? -10 : 50)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: isAnimating)
                        
                        FormatBadge(text: "3gp", isPrimary: true, isAnimating: isAnimating)
                            .offset(y: isAnimating ? 0 : 40)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: isAnimating)
                    }
                }
                // "+20 More" badge
                ZStack {
                    // Orange Blur Glow
                    Circle()
                        .fill(Color.premiumAccent.opacity(0.4))
                        .frame(width: isIpad ? 150 : 100, height: isIpad ? 80 : 50)
                        .blur(radius: isIpad ? 40 : 25)
                        .offset(y: 10)
                    
                    Text("+20 More")
                        .appFont(.figtreeBold, size: isIpad ? 28 : 20)
                        .foregroundColor(.white)
                        .padding(.horizontal, isIpad ? 35 : 25)
                        .padding(.vertical, isIpad ? 16 : 12)
                        .background(
                            Color.white.opacity(0.1)
                                .background(BlurView(style: .systemThinMaterialDark).opacity(0.6))
                        )
                        .cornerRadius(40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 40)
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
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                .responsivePadding(edge: .top, fraction: isIpad ? 30 : 20)
                .scaleEffect(isAnimating ? 1 : 0.5)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.5), value: isAnimating)
                
                Spacer()
                
                // MARK: - Text Content
                VStack(alignment: .leading, spacing: isIpad ? 18 : 12) {
                    Text("Supports\nAll Formats")
                        .appFont(.figtreeBold, size: isIpad ? 40 : 40)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .scaleEffect(isAnimating ? 1 : 0.95, anchor: .leading)
                    
                    Text("Compatible with major video formats.")
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
                    navManager.push(.onboarding3)
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
            .scaleEffect(isAnimating ? 1 : 0.8)
            .opacity(isAnimating ? 1 : 0)
            
           
        }
        
        .hideNavigationBar()
        .onAppear {
            isAnimating = true
        }
    }
}

struct FormatBadge: View {
    let text: String
    var isPrimary: Bool = false
    var isAnimating: Bool
    
    @State private var floatOffset: CGFloat = 0
    
    var body: some View {
        Text(text)
            .appFont(.figtreeBold, size: isPrimary ? (isIpad ? 30 : 30) : (isIpad ? 26 : 28))
            .foregroundColor(isPrimary ? .black : .white)
            .padding(.horizontal, isPrimary ? (isIpad ? 35 : 25) : (isIpad ? 30 : 20))
            .padding(.vertical, isPrimary ? (isIpad ? 16 : 12) : (isIpad ? 14 : 10))
            .background(
                ZStack {
                    if isPrimary {
                        Color.white
                    } else {
                        Color.white.opacity(0.1)
                            .background(BlurView(style: .systemThinMaterialDark).opacity(0.6))
                    }
                }
            )
            .cornerRadius(40)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .scaleEffect(isAnimating ? 1 : 0.5)
            .opacity(isAnimating ? 1 : 0)
            .offset(y: floatOffset)
            .onAppear {
                if isAnimating {
                    withAnimation(
                        .easeInOut(duration: Double.random(in: 2.0...4.0))
                        .repeatForever(autoreverses: true)
                    ) {
                        floatOffset = CGFloat.random(in: -10...10)
                    }
                }
            }
            .onChange(of: isAnimating) { newValue in
                if newValue {
                    withAnimation(
                        .easeInOut(duration: Double.random(in: 2.0...4.0))
                        .repeatForever(autoreverses: true)
                    ) {
                        floatOffset = CGFloat.random(in: -10...10)
                    }
                }
            }
    }
}

// Add a helper for animation in subviews
extension EnvironmentValues {
    var isAnimating: Bool {
        get { self[IsAnimatingKey.self] }
        set { self[IsAnimatingKey.self] = newValue }
    }
}

struct IsAnimatingKey: EnvironmentKey {
    static var defaultValue: Bool = false
}

#Preview {
    Onboarding2View()
        .environmentObject(NavigationManager())
}
