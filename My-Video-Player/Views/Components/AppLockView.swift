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
                        .frame(width: isIpad ? 500 : 300, height: isIpad ? 500 : 300)
                        .blur(radius: isIpad ? 100 : 60)
                        .offset(x: isIpad ? -150 : -100, y: isIpad ? -200 : -150)
                    
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: isIpad ? 400 : 250, height: isIpad ? 400 : 250)
                        .blur(radius: isIpad ? 80 : 50)
                        .offset(x: isIpad ? 200 : 120, y: isIpad ? 150 : 100)
                }
                Spacer()
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // Icon Section with subtle pulse
                ZStack {
                    Circle()
                        .fill(Color.homeAccent.opacity(0.15))
                        .frame(width: isIpad ? 200 : 120, height: isIpad ? 200 : 120)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .opacity(isAnimating ? 0.3 : 0.7)
                    
                    Circle()
                        .fill(Color.homeAccent.opacity(0.2))
                        .frame(width: isIpad ? 160 : 100, height: isIpad ? 160 : 100)
                    
                    Image(systemName: "faceid")
                        .font(.system(size: isIpad ? 72 : 48, weight: .semibold))
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
                
                VStack(spacing: isIpad ? 20 : 12) {
                    Text("App Locked")
                        .font(.system(size: isIpad ? 44 : 28, weight: .bold))
                        .foregroundColor(.homeTextPrimary)
                    
                    Text("Please authenticate to access your videos")
                        .font(.system(size: isIpad ? 22 : 16))
                        .foregroundColor(.homeTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, isIpad ? 100 : 40)
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
