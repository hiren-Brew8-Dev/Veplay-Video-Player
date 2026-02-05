import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    let leftFade: CGFloat
    let rightFade: CGFloat
    let startDelay: Double
    
    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Measure text width
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundColor(.clear)
                    .background(
                        GeometryReader { textGeo in
                            Color.clear.preference(
                                key: WidthPreferenceKey.self,
                                value: textGeo.size.width
                            )
                        }
                    )
                
                if textWidth > geometry.size.width {
                    // Scrolling marquee for long text
                    HStack(spacing: 50) {
                        Text(text)
                            .font(font)
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundColor(.white)
                        
                        Text(text)
                            .font(font)
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundColor(.white)
                    }
                    .offset(x: offset)
                    .onAppear {
                        containerWidth = geometry.size.width
                        // Start animation after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
                            withAnimation(
                                Animation.linear(duration: Double(textWidth) / 30)
                                    .repeatForever(autoreverses: false)
                            ) {
                                offset = -(textWidth + 50)
                            }
                        }
                    }
                } else {
                    // Static text for short titles - Leading aligned
                    Text(text)
                        .font(font)
                        .lineLimit(1)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .clipped()
            .onPreferenceChange(WidthPreferenceKey.self) { width in
                textWidth = width
            }
        }
    }
}

// Preference key for measuring text width
struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
