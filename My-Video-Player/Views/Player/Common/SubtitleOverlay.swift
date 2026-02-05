import SwiftUI

struct SubtitleOverlay: View {
    let text: String
    
    // Customize from AppStorage (matching new SubtitleEditView)
    @AppStorage("subtitleSize") private var subtitleSize: String = "N"
    @AppStorage("subtitleColor") private var subtitleColor: String = "White"
    @AppStorage("subtitleBold") private var isBold: Bool = false // Keeping if we ever use it, or default false
    // Note: Background toggle was removed from new design, assuming transparent or default style? 
    // Screenshot showed standard text. OLD code had background. 
    // I will keep background logic optional or remove it if not in design. 
    // User request "Make it properly... with all configuration as per feature implemented". 
    // Prioritize clean look. I'll default to a subtle shadow instead of box if box option is gone.
    // Or just keep the box if it helps readability. The new "Fill Color" usually implies text color.
    
    var body: some View {
        if !text.isEmpty {
            VStack {
                Spacer()
                
                Text(text)
                    .font(.system(size: sizeForString(subtitleSize), weight: .bold))
                    .foregroundColor(colorFromName(subtitleColor))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .shadow(color: .black, radius: 2, x: 1, y: 1) // Add shadow for legibility since we removed bg box toggle
                    .padding(.horizontal, 40)
                    .padding(.bottom, 120)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // Map string size tags to CGFloat
    private func sizeForString(_ size: String) -> CGFloat {
        switch size {
        case "LL": return 32
        case "L": return 26
        case "N": return 20
        case "S": return 16
        case "SS": return 12
        default: return 20
        }
    }
    
    // Convert color name to Color
    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "White": return .white
        case "Black": return .black
        case "Gray": return .gray
        case "Red": return .red
        case "Yellow": return .yellow
        case "Blue": return .blue
        case "Cyan": return .cyan
        case "Pink": return .pink
        case "Purple": return .purple
        case "Green": return .green
        default: return .white
        }
    }
}
