import UIKit
import SwiftUI

struct GridLayout {
    
    // MARK: - Global Configuration
    
    /// Dynamic spacing based on device and orientation
    static func spacing(isLandscape: Bool) -> CGFloat {
        if isIpad {
            return isLandscape ? 24 : 20
        }
        return 15
    }
    
    static var horizontalPadding: CGFloat { 
        AppDesign.Icons.horizontalPadding 
    }
    
    /// Dynamic columns based on device and orientation
    static func columns(isLandscape: Bool) -> Int {
        if isIpad {
            return isLandscape ? 5 : 3
        }
        return isLandscape ? 4 : 2
    }
    
    // MARK: - Helper Methods
    
    /// Calculate item size based on available width and orientation
    static func itemSize(for width: CGFloat, isLandscape: Bool) -> CGFloat {
        let cols = CGFloat(columns(isLandscape: isLandscape))
        let space = spacing(isLandscape: isLandscape)
        
        let totalSpacing = (cols - 1) * space
        let totalPadding = horizontalPadding * 2
        
        let availableWidth = width - totalSpacing - totalPadding
        return floor(availableWidth / cols)
    }
    
    /// SwiftUI GridItem array for LazyVGrid
    static func gridColumns(isLandscape: Bool) -> [GridItem] {
        let cols = columns(isLandscape: isLandscape)
        let space = spacing(isLandscape: isLandscape)
        return Array(repeating: GridItem(.flexible(), spacing: space), count: cols)
    }
}
