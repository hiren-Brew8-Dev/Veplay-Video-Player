//
//  Onboarding5View.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 18/02/26.
//

import SwiftUI

struct Onboarding5View: View {
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
                    .foregroundColor(.bgBlurOrange1.opacity(0.12))
                    .frame(width: isIpad ? 400 : 256, height: isIpad ? 400 : 256)
                    .blur(radius: isIpad ? 120 : 80)
                    .offset(x: isIpad ? -250 : -164.50, y: isIpad ? 600 : 410)
                
                Circle()
                    .foregroundColor(.bgBlurOrange2.opacity(0.12))
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
                                .frame(width: index == 4 ? (isIpad ? 48 : 32) : (isIpad ? 10 : 7), height: isIpad ? 10 : 7)
                                .background(index == 4 ? Color.premiumAccent : Color.white.opacity(0.30))
                                .cornerRadius(24)
                        }
                    }
                    .responsivePadding(edge: .top, fraction: isIpad ? 50 : 30)
                    .responsivePadding(edge: .trailing, fraction: isIpad ? 50 : 30)
                }
                
                Spacer()
                
                // MARK: - Container for Image and Text
                ZStack(alignment: .bottom) {
                    // Mobile Image
                    Image("main_phone_view")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .responsiveWidth(iphoneWidth: 300, ipadWidth: 180)
                        // Correct fade out at the bottom
                        .overlay(
                            VStack {
                                Spacer()
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.8), .black],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: isIpad ? 180 : 140)
                            }
                        )
                        .scaleEffect(isAnimating ? 1 : 0.8)
                        .rotation3DEffect(.degrees(isAnimating ? 0 : 10), axis: (x: 1, y: 0, z: 0))
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.2), value: isAnimating)
                        .responsivePadding(edge: .bottom, fraction: 70)
                    
                    // Text Content Arriving from Bottom
                    VStack(alignment: .leading, spacing: isIpad ? 18 : 15) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Access from")
                                .appFont(.figtreeBold, size: isIpad ? 40 : 40)
                                .foregroundColor(.white)
                            
                            HStack(alignment: .center, spacing: 12) {
                                Image("photos_icon")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: isIpad ? 50 : 40, height: isIpad ? 50 : 40)
                                
                                Text("Photos")
                                    .appFont(.figtreeBold, size: isIpad ? 40 : 40)
                                    .foregroundColor(.white)
                            }
                        }
                        .scaleEffect(isAnimating ? 1 : 0.95, anchor: .leading)
                        
                        Text("Import videos directly from your gallery.")
                            .appFont(.figtreeRegular, size: isIpad ? 16 : 16)
                            .foregroundColor(Color.white.opacity(0.80))
                    }
                    .responsivePadding(edge: .horizontal, fraction: isIpad ? 60 : 30)
                    .offset(y: isAnimating ? -5 : 100) // Slide up animation into the gradient zone
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.5), value: isAnimating)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer()
                
                // MARK: - Action Button
                Button(action: {
                    HapticsManager.shared.generate(.medium)
                    navManager.push(.photoLibraryAccess)
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

#Preview {
    Onboarding5View()
        .environmentObject(NavigationManager())
}
