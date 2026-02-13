import SwiftUI

extension Color {
    // Core Theme
    static let themeBackground = Color(red: 0.05, green: 0.05, blue: 0.07) 
    static let themeSurface = Color(red: 0.1, green: 0.1, blue: 0.12)
    static let themeAccent = Color.blue
    static let themePrimary = Color.white
    static let themeSecondary = Color.gray
    static let themeFab = Color.orange

    // Home Screen specific
    static let homeBackground = Color(red: 0.05, green: 0.05, blue: 0.07)
    static let homeCardBackground = Color(red: 0.12, green: 0.12, blue: 0.15)
    static let homeTextPrimary = Color.white
    static let homeTextSecondary = Color.gray.opacity(0.8)
    static let homeTint = Color.white 
    static let homeAccent = Color.orange
    
    // Standard Sheet Design
    static let sheetBackground = Color(red: 0.08, green: 0.08, blue: 0.1)
    static let sheetSurface = Color(red: 0.15, green: 0.15, blue: 0.18)
    static let sheetDivider = Color.white.opacity(0.1)
    static let sheetTextPrimary = Color.white
    static let sheetTextDestructive = Color.red

    // Premium Sheet Design
    static let premiumGradientTop = Color(red: 0.07, green: 0.07, blue: 0.09) // Darker for premium feel
    static let premiumGradientBottom = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let premiumCardBackground = Color.white.opacity(0.05)
    static let premiumCardBorder = Color.white.opacity(0.1)
    static let premiumCircleBackground = Color.white.opacity(0.1)
    
    // Hex helper
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
