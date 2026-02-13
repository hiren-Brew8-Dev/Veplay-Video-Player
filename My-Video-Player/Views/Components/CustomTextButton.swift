//
//  CustomTextButton.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 05/11/25.
//

import SwiftUI

struct CustomTextButton: View {
    var title: String
    var aspectRatio: CGFloat
    var iphoneWidth: CGFloat
    var ipadWidth: CGFloat = 0.35
    var foregroundColor: Color = .black
    var backgroundColor: Color = .white
    var cornerRadius: CGFloat = 50
    var shadowRadius: CGFloat = 4
    
    var font: AppFont = .manropeMedium
    var iphoneFontSize: CGFloat = 18
    
    var borderColor: Color = .clear
    var borderWidth: CGFloat = 0
    
    var gradientColors: [Color]? = nil
    var gradientDirection: GradientBorderDirection = .leftToRight
    var useGradientBackground: Bool = false
    
    var action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticsManager.shared.generate(.soft)
            action()
        }) {
            ZStack {
                ZStack {
                    if useGradientBackground, let gradientColors {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: gradientColors,
                                    startPoint: gradientDirection.start(),
                                    endPoint: gradientDirection.end()
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(backgroundColor)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .aspectRatio(aspectRatio, contentMode: .fit)
                .responsiveWidth(iphoneWidth: iphoneWidth, ipadWidth: ipadWidth)
                .shadow(radius: shadowRadius)
                
                Text(title)
                    .appFont(font, size: iphoneFontSize)
                    .foregroundColor(foregroundColor)
            }
        }
    }
}
