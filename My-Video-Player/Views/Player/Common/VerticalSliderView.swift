import SwiftUI

struct VerticalSliderView: View {
    let value: Float // 0.0 to 1.0
    let iconName: String

    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var useCompactSlider: Bool {
        // Apply compact styling to all iPhone orientations, keep normal for iPad
        return !isIpad
    }
    
    // Adaptive values
    private var sliderWidth: CGFloat { useCompactSlider ? 4 : 6 }
    private var sliderHeight: CGFloat { useCompactSlider ? 124 : 150 }
    private var iconSize: CGFloat { useCompactSlider ? 18 : 20 }
    private var fontSize: CGFloat { useCompactSlider ? 10 : 12 }
    private var containerSpacing: CGFloat { useCompactSlider ? 8 : 12 }
    private var containerPaddingVertical: CGFloat { useCompactSlider ? 12 : 16 }
    private var containerPaddingHorizontal: CGFloat { useCompactSlider ? 6 : 8 }

    var body: some View {
        VStack(spacing: containerSpacing) {
            iconView
            
            sliderBody
            
            Text("\(Int(value * 100))%")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(.white)
                .frame(width: useCompactSlider ? 36 : 40)
        }
        .padding(.vertical, containerPaddingVertical)
        .padding(.horizontal, containerPaddingHorizontal)
        .background(Color.black.opacity(0.6))
        .cornerRadius(useCompactSlider ? 16 : 20)
        .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
    }
    
    private var iconView: some View {
        Image(systemName: iconName)
            .font(.system(size: iconSize, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
    }
    
    private var sliderBody: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let filledHeight = CGFloat(value) * height
            
            ZStack(alignment: .bottom) {
                // Background Track
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: sliderWidth, height: height)
                
                // Filled Track
                Capsule()
                    .fill(Color.white)
                    .frame(width: sliderWidth, height: filledHeight)
            }
            .frame(width: sliderWidth)
            .frame(maxHeight: .infinity)
        }
        .frame(width: sliderWidth, height: sliderHeight)
    }
}
