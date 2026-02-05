import SwiftUI

struct VerticalSliderView: View {
    let value: Float // 0.0 to 1.0
    let iconName: String

    
    var body: some View {
        VStack(spacing: 12) {
            iconView
            
            sliderBody
            
            Text("\(Int(value * 100))%")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
    }
    
    private var iconView: some View {
        Image(systemName: iconName)
            .font(.system(size: 20, weight: .bold))
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
                    .frame(width: 6, height: height)
                
                // Filled Track
                Capsule()
                    .fill(Color.white)
                    .frame(width: 6, height: filledHeight)
            }
            .frame(width: 6)
            .frame(maxHeight: .infinity)
        }
        .frame(width: 6, height: 150) // Fixed height for visual consistency
    }
}
