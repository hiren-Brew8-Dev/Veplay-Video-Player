import SwiftUI

struct DoubleTapOverlay: View {
    let isForward: Bool
    let onClose: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            // Curved shape or just arrows
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    if !isForward {
                        Image(systemName: "backward.fill")
                        Image(systemName: "backward.fill")
                        Image(systemName: "backward.fill")
                    } else {
                        Image(systemName: "forward.fill")
                        Image(systemName: "forward.fill")
                        Image(systemName: "forward.fill")
                    }
                }
                .font(.system(size: 24))
                .foregroundColor(.white)
                
                Text("10 Seconds")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .mask(
            HStack {
                if isForward {
                    Spacer()
                    Rectangle().frame(width: UIScreen.main.bounds.width / 2) // Right half mask with curve potentially
                } else {
                    Rectangle().frame(width: UIScreen.main.bounds.width / 2)
                    Spacer()
                }
            }
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                onClose()
            }
        }
    }
}
