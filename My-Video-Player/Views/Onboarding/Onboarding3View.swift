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
                                .frame(width: index == 2 ? (isIpad ? 48 : 32) : (isIpad ? 10 : 7), height: isIpad ? 10 : 7)
                                .background(index == 2 ? Color.premiumAccent : Color.white.opacity(0.30))
                                .cornerRadius(24)
                        }
                    }
                    .responsivePadding(edge: .top, fraction: isIpad ? 50 : 30)
                    .responsivePadding(edge: .trailing, fraction: isIpad ? 50 : 30)
                }
                
                Spacer()
                
                // MARK: - Folder Cards Section (Zigzagged and Tilted)
                VStack(spacing: isIpad ? 35 : 25) {
                    // Card 1: Downloads
                    OnboardingFolderRow(title: "Downloads", count: "16 Videos", gradientSide: .right)
                        .rotationEffect(.degrees(-1))
                        .rotation3DEffect(.degrees(isAnimating ? 0 : 20), axis: (x: 0, y: 1, z: 0))
                        .scaleEffect(isAnimating ? 1 : 0.8)
                        .offset(x: isAnimating ? -20 : -100)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: isAnimating)
                    
                    // Card 2: Vacation 2025
                    OnboardingFolderRow(title: "Vacation 2025", count: "42 Videos", gradientSide: .left)
                        .rotationEffect(.degrees(2))
                        .rotation3DEffect(.degrees(isAnimating ? 0 : -20), axis: (x: 0, y: 1, z: 0))
                        .scaleEffect(isAnimating ? 1 : 0.8)
                        .offset(x: isAnimating ? 20 : 100)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: isAnimating)
                    
                    // Card 3: Office Work
                    OnboardingFolderRow(title: "Office Work", count: "12 Videos", gradientSide: .right)
                        .rotationEffect(.degrees(-1))
                        .rotation3DEffect(.degrees(isAnimating ? 0 : 20), axis: (x: 0, y: 1, z: 0))
                        .scaleEffect(isAnimating ? 1 : 0.8)
                        .offset(x: isAnimating ? -20 : -100)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: isAnimating)
                    
                    // Card 4: College Documentary
                    OnboardingFolderRow(title: "College Documentary", count: "20 Videos", gradientSide: .left)
                        .rotationEffect(.degrees(2))
                        .rotation3DEffect(.degrees(isAnimating ? 0 : -20), axis: (x: 0, y: 1, z: 0))
                        .scaleEffect(isAnimating ? 1 : 0.8)
                        .offset(x: isAnimating ? 20 : 100)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: isAnimating)
                }
                .frame(height: isIpad ? 420 : 420)
                
                Spacer()
                
                // MARK: - Text Content
                VStack(alignment: .leading, spacing: isIpad ? 18 : 12) {
                    Text("Organize Easily\nIn Folders")
                        .appFont(.figtreeBold, size: isIpad ? 40 : 40)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .scaleEffect(isAnimating ? 1 : 0.95, anchor: .leading)
                    
                    Text("Create folders to keep your videos arranged.")
                        .appFont(.figtreeRegular, size: isIpad ? 16 : 16)
                        .foregroundColor(Color.white.opacity(0.80))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .responsivePadding(edge: .horizontal, fraction: isIpad ? 60 : 30)
                .offset(y: isAnimating ? 0 : 30)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.5), value: isAnimating)
                
                Spacer()
                
                // MARK: - Action Button
                Button(action: {
                    HapticsManager.shared.generate(.medium)
                    navManager.push(.onboarding4)
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
        }
    }
}

enum GradientSide {
    case left, right
}

struct OnboardingFolderRow: View {
    let title: String
    let count: String
    let gradientSide: GradientSide
    
    var body: some View {
        HStack(spacing: isIpad ? 24 : 16) {
            // Icon Section
            ZStack {
                RoundedRectangle(cornerRadius: isIpad ? 16 : 12)
                    .fill(Color.black.opacity(0.4))
                    .frame(width: isIpad ? 72 : 52, height: isIpad ? 72 : 52)
                
                Image(systemName: "folder.fill")
                    .font(.system(size: isIpad ? 32 : 24))
                    .foregroundColor(.premiumAccent)
            }
            
            // Info Section
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .appFont(.figtreeBold, size: 16)
                    .foregroundColor(.white)
                
                Text(count)
                    .appFont(.figtreeMedium, size:  14)
                    .foregroundColor(Color.white.opacity(0.5))
            }
            
            Spacer()
            
            // Actions (Ellipsis)
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .font(.system(size: isIpad ? 18 : 14, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, isIpad ? 18 : 12)
        .padding(.vertical, isIpad ? 12 : 8)
        .responsiveWidth(iphoneWidth: 310, ipadWidth: 220)
        .background(
            ZStack {
                Color.white.opacity(0.1)
                    .background(BlurView(style: .systemThinMaterialDark).opacity(0.6))
                
                // Alternating Gradient Highlight
                LinearGradient(
                    colors: gradientSide == .right ? [.clear, .premiumAccent.opacity(0.15)] : [.premiumAccent.opacity(0.15), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
    
        .cornerRadius(18)
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
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    Onboarding3View()
        .environmentObject(NavigationManager())
}
