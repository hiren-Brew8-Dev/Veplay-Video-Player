import SwiftUI

struct AppDesign {
    struct Icons {
        // Standard Weights
        static let primaryWeight: Font.Weight = .semibold
        static let secondaryWeight: Font.Weight = .medium
        static let boldWeight: Font.Weight = .bold
        
        // Standard Sizes
        static let headerSize: CGFloat = 22
        static let toolbarSize: CGFloat = 20
        static let rowIconSize: CGFloat = 18
        static let cardIconSize: CGFloat = 16
        static let largeIconSize: CGFloat = 40
        static let selectionIconSize: CGFloat = 24
        static let actionSheetIconSize: CGFloat = 20
        
        // Standard Spacing
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 12
        static let internalSpacing: CGFloat = 10
        static let itemSpacing: CGFloat = 12
    }
}

extension View {
    /// Apply standard style to primary toolbar or action icons
    func appIconStyle(size: CGFloat = AppDesign.Icons.toolbarSize, weight: Font.Weight = AppDesign.Icons.primaryWeight, color: Color = .homeTint) -> some View {
        self.font(.system(size: size, weight: weight))
            .foregroundColor(color)
    }
    
    /// Apply standard style to metadata or secondary icons
    func appSecondaryIconStyle(size: CGFloat = AppDesign.Icons.cardIconSize, weight: Font.Weight = AppDesign.Icons.secondaryWeight, color: Color = .homeTextSecondary) -> some View {
        self.font(.system(size: size, weight: weight))
            .foregroundColor(color)
    }
}

/// A standard circular icon button used for navigation (Back, Close)
struct StandardIconButton: View {
    let icon: String // System name
    var size: CGFloat = 20
    var weight: Font.Weight = .bold
    var color: Color = .homeTextPrimary
    var bg: Color = .homeCardBackground
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: weight))
                .foregroundColor(color)
                .padding(10)
                .background(bg)
                .clipShape(Circle())
        }
    }
}
