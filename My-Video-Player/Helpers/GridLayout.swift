import UIKit
import SwiftUI

struct GridLayout {
    
    // MARK: - Global Configuration
    // Change these values in ONE place to update ALL grids app-wide
    
    static let columns: Int = 2
    static let spacing: CGFloat = 15
    static let horizontalPadding: CGFloat = 15
    
    // MARK: - Computed Properties
    
    /// The calculated size for each grid item (perfect square)
    static var itemSize: CGFloat {
        return itemSize(
            columns: columns,
            spacing: spacing,
            horizontalPadding: horizontalPadding
        )
    }
    
    /// SwiftUI GridItem array for LazyVGrid (flexible columns)
    static var gridColumns: [GridItem] {
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
    }
    
    // MARK: - Helper Methods
    
    /// Calculate item size with custom parameters (for special cases)
    static func itemSize(
        columns: Int,
        spacing: CGFloat,
        horizontalPadding: CGFloat
    ) -> CGFloat {
        
        let screenWidth = UIScreen.main.bounds.width
        
        let totalSpacing = CGFloat(columns - 1) * spacing
        let totalPadding = horizontalPadding * 2
        
        let availableWidth = screenWidth - totalSpacing - totalPadding
        
        return floor(availableWidth / CGFloat(columns))
    }
}
