//
//  Onboarding4View.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 13/02/26.
//

import SwiftUI
import Photos

struct Onboarding4View: View {
    @EnvironmentObject var navManager: NavigationManager
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // ... (rest of the view)
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
                Spacer()
                
                // MARK: - Central Illustration
                ZStack {
                    let scaleW = UIScreen.main.bounds.width / 393
                    let scaleH = UIScreen.main.bounds.height / 852
                    
                    // Large Transparent Circle
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 160 * scaleW, height: 160 * scaleW)
                        .scaleEffect(isAnimating ? 1 : 0.5)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: isAnimating)
                    
                    // Main Icon (Stacked Effect)
                    VStack(spacing: 8 * scaleH) {
                        // Top line
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 45 * scaleW, height: 4 * scaleH)
                        
                        // Middle line
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 63 * scaleW, height: 4 * scaleH)
                        
                        // Main Block
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .frame(width: 80 * scaleW, height: 57 * scaleH)
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 32 * scaleW))
                                .foregroundColor(Color(red: 0.09, green: 0.06, blue: 0.03))
                        }
                    }
                    .scaleEffect(isAnimating ? 1 : 0.3)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.2), value: isAnimating)
                    
                    // Lock Overlay (Pill Shape from Figma)
                    ZStack {
                        VStack {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 24 * scaleW, weight: .bold))
                                .foregroundColor(Color(red: 0.09, green: 0.06, blue: 0.03))
                        }
                        .padding(.vertical, 13 * scaleH)
                        .padding(.horizontal, 10 * scaleW)
                        .background(Color(red: 1, green: 0.67, blue: 0.21))
                        .cornerRadius(56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 56)
                                .stroke(Color(red: 0.09, green: 0.06, blue: 0.03), lineWidth: 3)
                        )
                    }
                    .offset(x: 60 * scaleW, y: 55 * scaleH)
                    .scaleEffect(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.5), value: isAnimating)
                }
                .responsivePadding(edge: .bottom, fraction: 50)
                
                // MARK: - Description Text
                Text("Allow access to your videos to begin.")
                    .font(Font.custom("Figtree-Medium", size: 16))
                    .foregroundColor(Color.white.opacity(0.80))
                    .multilineTextAlignment(.center)
                    .offset(y: isAnimating ? 0 : 20)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.6), value: isAnimating)
                
                Spacer()
                    .responsiveHeight(iphoneHeight: 100)
                
                // MARK: - Main Title
                Text("Let’s Get Started")
                    .font(Font.custom("Figtree-Bold", size: 40))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .scaleEffect(isAnimating ? 1 : 0.9)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.7), value: isAnimating)
                
                Spacer()
                
                // MARK: - Action Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                        DispatchQueue.main.async {
                            navManager.push(.thanksForDownloading)
                        }
                    }
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
                .scaleEffect(isAnimating ? 1 : 0.8)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.8), value: isAnimating)
            }
            .responsivePadding(edge: .horizontal, fraction: 30)
        }
        .hideNavigationBar()
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    Onboarding4View()
        .environmentObject(NavigationManager())
}
