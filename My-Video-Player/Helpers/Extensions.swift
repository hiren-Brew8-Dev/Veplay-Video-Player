//
//  Extensions.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 16/02/26.
//

import Foundation
import SwiftUI



extension Color {
   
    
    static func blend(_ color1: Color, _ color2: Color, ratio: Double = 0.5) -> Color {
            // Convert to UIColor for blending
            let ui1 = UIColor(color1)
            let ui2 = UIColor(color2)
            
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            
            ui1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            ui2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            
            return Color(
                red: Double(r1 + (r2 - r1) * CGFloat(ratio)),
                green: Double(g1 + (g2 - g1) * CGFloat(ratio)),
                blue: Double(b1 + (b2 - b1) * CGFloat(ratio))
            )
        }
}

extension View {
  
    func placeholder<Content: View>(when shouldShow: Bool, alignment: Alignment = .leading, @ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            self
            if shouldShow {
                content()
                    .padding(.horizontal)
            }
        }
    }
    
    func snapshot(size: CGSize) -> UIImage {
        let controller = UIHostingController(rootView: self)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
    
    func takeScreenshot(origin: CGPoint, size: CGSize) -> UIImage {
        let window = UIWindow(frame: CGRect(origin: origin, size: size))
        let hosting = UIHostingController(rootView: self)
        hosting.view.frame = window.frame
        window.addSubview(hosting.view)
        window.makeKeyAndVisible()
        return hosting.view.screenShot
    }
    
    
    func snapshot() -> UIImage? {
        let controller = UIHostingController(rootView: self.ignoresSafeArea().fixedSize(horizontal: true, vertical: true))
        guard let view = controller.view else { return nil }
        let targetSize = view.intrinsicContentSize
        if targetSize.width <= 0 || targetSize.height <= 0 {
            return nil
        }
        view.bounds = CGRect(origin: .zero, size: targetSize)
        view.backgroundColor = .systemBackground // Or .clear if preferred
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
   
}

extension UIView {
    var screenShot: UIImage {
        let rect = self.bounds
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        let context: CGContext = UIGraphicsGetCurrentContext()!
        self.layer.render(in: context)
        let capturedImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return capturedImage
    }
}



let figmaBaseWidth: CGFloat = 393
let figmaBaseHeight: CGFloat = 852


extension View {
    
    
    @ViewBuilder func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    func responsiveWidth(
        iphoneWidth: CGFloat,
        ipadWidth: CGFloat? = nil,
        alignment: Alignment = .center
    ) -> some View {

        let screenWidth = UIScreen.main.bounds.width
        let isPad = UIDevice.current.userInterfaceIdiom == .pad

        // FIGMA scaling for iPhone baseline
        let figmaScaledIphone = (screenWidth / figmaBaseWidth) * iphoneWidth

        // If ipadWidth is provided → scale it using figma as well
        let figmaScaledIpad = ipadWidth != nil
            ? (screenWidth / figmaBaseWidth) * ipadWidth!
            : figmaScaledIphone   // fallback

        let width = isPad ? figmaScaledIpad : figmaScaledIphone

        return self
            .frame(width: width, alignment: alignment)
            .aspectRatio(contentMode: .fit)
    }


    func responsiveHeight(
        iphoneHeight: CGFloat,
        ipadHeight: CGFloat? = nil,
        alignment: Alignment = .center
    ) -> some View {

        let screenHeight = UIScreen.main.bounds.height
        let isPad = UIDevice.current.userInterfaceIdiom == .pad

        // FIGMA scaling for iPhone baseline
        let figmaScaledIphone = (screenHeight / figmaBaseHeight) * iphoneHeight

        // Optional iPad value, scaled the same way
        let figmaScaledIpad = ipadHeight != nil
            ? (screenHeight / figmaBaseHeight) * ipadHeight!
            : figmaScaledIphone

        let height = isPad ? figmaScaledIpad : figmaScaledIphone

        return self
            .frame(height: height, alignment: alignment)
            .aspectRatio(contentMode: .fit)
    }

    
   
    
    func responsivePadding(edge: Edge.Set, fraction: CGFloat) -> some View {

        let screen = UIScreen.main.bounds

        var scaled: CGFloat = 0

        // Horizontal → width scaling
        if edge == .leading || edge == .trailing || edge == .horizontal {
            scaled = (screen.width / figmaBaseWidth) * fraction
        }
        // Vertical → height scaling
        else if edge == .top || edge == .bottom || edge == .vertical {
            scaled = (screen.height / figmaBaseHeight) * fraction
        }
        // Default
        else {
            scaled = (screen.height / figmaBaseHeight) * fraction
        }

        return self.padding(edge, scaled)
    }
    
    func hideNavigationBar() -> some View {
        self.toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Blur View Helper
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

extension View {
    func responsiveHeight(
        iphoneHeight: CGFloat? = nil,
        ipadHeight: CGFloat? = 0.09,
        alignment: Alignment = .center
    ) -> some View {
        
        let screenHeight = UIScreen.main.bounds.height
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        
        // Determine height
        let height: CGFloat? = {
            if isPad, let ipadHeight = ipadHeight {
                return screenHeight * ipadHeight
            } else if let iphoneHeight = iphoneHeight {
                return (screenHeight / figmaBaseHeight) * iphoneHeight
            } else {
                return nil
            }
        }()
        
        // Apply height if available
        return self
            .frame(height: height, alignment: alignment)
            
    }
}

extension View {
    
    func responsiveWidth(
        iphoneWidth: CGFloat? = nil,
        ipadWidth: CGFloat? = 0.09,
        alignment: Alignment = .center
    ) -> some View {
        
        let screenWidth = UIScreen.main.bounds.width
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        
        // Determine width
        let width: CGFloat? = {
            if isPad, let ipadWidth = ipadWidth {
                return screenWidth * ipadWidth
            } else if let iphoneWidth = iphoneWidth {
                return (screenWidth / figmaBaseWidth) * iphoneWidth
            } else {
                return nil
            }
        }()
        
        // Apply width if available
        return self
            .frame(width: width, alignment: alignment)
    }
}

extension Notification.Name {
    static let gameDidComplete = Notification.Name("gameDidComplete")
    static let spinComplate = Notification.Name("spinComplate")
}


extension String {
    var firstWord: String {
        self.split(separator: " ").first.map(String.init) ?? ""
    }
}

extension Binding where Value == String {
    func limit(_ length: Int) -> Binding<String> {
        Binding(
            get: { self.wrappedValue },
            set: { self.wrappedValue = String($0.prefix(length)) }
        )
    }
}

extension UIApplication {
//    func endEditing() {
//        sendAction(#selector(UIResponder.resignFirstResponder),
//                   to: nil, from: nil, for: nil)
//    }
}





extension View {

    func responsiveFrame(
        minWidth: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        alignment: Alignment = .center
    ) -> some View {
        
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        
        // Calculate responsive widths
        let calculatedMinWidth: CGFloat? = minWidth != nil ? (screenWidth / figmaBaseWidth) * minWidth! : nil
        let calculatedMaxWidth: CGFloat? = maxWidth != nil ? (screenWidth / figmaBaseWidth) * maxWidth! : nil
        
        // Calculate responsive heights
        let calculatedMinHeight: CGFloat? = minHeight != nil ? (screenHeight / figmaBaseHeight) * minHeight! : nil
        let calculatedMaxHeight: CGFloat? = maxHeight != nil ? (screenHeight / figmaBaseHeight) * maxHeight! : nil
        
        return self
            .frame(
                minWidth: calculatedMinWidth,
                maxWidth: calculatedMaxWidth,
                minHeight: calculatedMinHeight,
                maxHeight: calculatedMaxHeight,
                alignment: alignment
            )
    }
}
