import SwiftUI

/// Global variable to check if the current device is an iPad
let isIpad = UIDevice.current.userInterfaceIdiom == .pad

extension View {
    /// Helper to apply iPad specific modifications
    @ViewBuilder
    func iPad<Content: View>(_ transform: (Self) -> Content) -> some View {
        if isIpad {
            transform(self)
        } else {
            self
        }
    }
}

extension CGFloat {
    /// Scaled value based on device type
    static func scaled(_ value: CGFloat, pad: CGFloat? = nil) -> CGFloat {
        if let padValue = pad, isIpad {
            return padValue
        }
        return value
    }
}
