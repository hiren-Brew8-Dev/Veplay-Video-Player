import SwiftUI

struct AppLockView: View {
    let onUnlock: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background with specialized dark glow
            Color.homeBackground.edgesIgnoringSafeArea(.all)
            
            // Abstract decorative circles
            VStack {
                ZStack {
                    Circle()
                        .fill(Color.homeAccent.opacity(0.1))
                        .frame(width: 300, height: 300)
                        .blur(radius: 60)
                        .offset(x: -100, y: -150)
                    
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 250, height: 250)
                        .blur(radius: 50)
                        .offset(x: 120, y: 100)
                }
                Spacer()
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // Icon Section with subtle pulse
                ZStack {
                    Circle()
                        .fill(Color.homeAccent.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .opacity(isAnimating ? 0.3 : 0.7)
                    
                    Circle()
                        .fill(Color.homeAccent.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "faceid")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundColor(.homeAccent)
                }
                .onTapGesture {
                    onUnlock()
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                    
                    // Auto-trigger authentication
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onUnlock()
                    }
                }
                
                VStack(spacing: 12) {
                    Text("App Locked")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.homeTextPrimary)
                    
                    Text("Please authenticate to access your videos")
                        .font(.system(size: 16))
                        .foregroundColor(.homeTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                Spacer()
            }
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    AppLockView(onUnlock: {})
        .preferredColorScheme(.dark)
}
