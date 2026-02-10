import SwiftUI

struct SyncingOverlayView: View {
    let message: String
    
    var body: some View {
        ZStack {
            // Darkened blurred backdrop
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .background(.ultraThinMaterial)
            
            VStack(spacing: 24) {
                // Animated Loader
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(rotationDegrees))
                        .onAppear {
                            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                rotationDegrees = 360
                            }
                        }
                }
                
                VStack(spacing: 8) {
                    Text(message)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Please wait a moment")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 40)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.premiumGradientBottom.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.premiumCardBorder, lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 30, x: 0, y: 15)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    @State private var rotationDegrees = 0.0
}

#Preview {
    ZStack {
        Color.gray
        SyncingOverlayView(message: "Syncing Files...")
    }
}
