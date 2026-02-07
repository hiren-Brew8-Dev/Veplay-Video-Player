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
    
    // Sheet specific
    static let sheetBackground = Color(red: 0.08, green: 0.08, blue: 0.1)
    static let sheetSurface = Color(red: 0.15, green: 0.15, blue: 0.18)
    static let sheetDivider = Color.white.opacity(0.1)
    static let sheetTextPrimary = Color.white
    static let sheetTextDestructive = Color.red
}
