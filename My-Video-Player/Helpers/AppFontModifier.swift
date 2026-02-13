//
//  AppFontModifier.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 20/11/25.
//

import Foundation
import SwiftUI

// MARK: - Font Modifier

struct AppFontModifier: ViewModifier {
    var font: AppFont
    var size: CGFloat

    func body(content: Content) -> some View {
        let adjustedBaseSize = size + (isIpad ? 8 : 0)
        let finalSize = adjustedBaseSize.adaptiveFontSize()
        content.font(font.size(finalSize))
    }
}

extension View {
    func appFont(_ font: AppFont, size: CGFloat) -> some View {
        self.modifier(AppFontModifier(font: font, size: size))
    }
}

// MARK: - Enum for Fonts

enum AppFont: String {
    case manropeBold = "Manrope-Bold"
    case manropeLight = "Manrope-Light"
    case manropeMedium = "Manrope-Medium"
    case manropeRegular = "Manrope-Regular"
    case manropeSemiBold = "Manrope-SemiBold"
    case manropeExtraBold = "Manrope-ExtraBold"

    func size(_ size: CGFloat) -> Font {
        Font.custom(self.rawValue, size: size)
    }
}

extension CGFloat {
    func adaptiveFontSize() -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let isIpad = UIDevice.current.userInterfaceIdiom == .pad
        let baseWidth: CGFloat = isIpad ? 820 : 390
        let scaleFactor = screenWidth / baseWidth
        return self * scaleFactor
    }
}
