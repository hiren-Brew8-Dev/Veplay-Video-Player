//
//  Onboarding2View.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 13/02/26.
//

import SwiftUI

struct Onboarding2View: View {
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
                            .frame(width: 32, height: 7)
                            .background(Color(red: 1, green: 0.67, blue: 0.21))
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
                
                // MARK: - Folder Cards Section (Zigzagged and Tilted)
                VStack(spacing: 25) {
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
                .frame(height: 420)
                
                Spacer()
                
                // MARK: - Text Content
                VStack(alignment: .leading, spacing: 12) {
                    Text("Organize Easily\nIn Folders")
                        .font(Font.custom("Figtree-Bold", size: 40))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .scaleEffect(isAnimating ? 1 : 0.95, anchor: .leading)
                    
                    Text("Create folders to keep your videos arranged.")
                        .font(Font.custom("Figtree-Regular", size: 16))
                        .foregroundColor(Color.white.opacity(0.80))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .responsivePadding(edge: .horizontal, fraction: 30)
                .offset(y: isAnimating ? 0 : 30)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.5), value: isAnimating)
                
                Spacer()
                
                // MARK: - Action Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    navManager.push(.onboarding3)
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
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.6), value: isAnimating)
            }
        }
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
        HStack(spacing: 16) {
            // Icon Section
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 52, height: 52)
                
                Image(systemName: "folder.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 1, green: 0.67, blue: 0.21))
            }
            
            // Info Section
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Font.custom("Figtree-Bold", size: 16))
                    .foregroundColor(.white)
                
                Text(count)
                    .font(Font.custom("Figtree-Medium", size: 14))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            
            Spacer()
            
            // Actions (Ellipsis)
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .responsiveWidth(iphoneWidth: 310)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(white: 1.0).opacity(0.08))
                .overlay(
                    // Alternating Gradient Highlight
                    LinearGradient(
                        colors: gradientSide == .right ? [.clear, Color(red: 1, green: 0.67, blue: 0.21).opacity(0.2)] : [Color(red: 1, green: 0.67, blue: 0.21).opacity(0.2), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .cornerRadius(18)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    Onboarding2View()
        .environmentObject(NavigationManager())
}
