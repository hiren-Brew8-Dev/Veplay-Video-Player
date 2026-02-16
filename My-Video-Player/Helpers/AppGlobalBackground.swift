import SwiftUI

struct AppGlobalBackground: View {
    var isIpad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    
    var body: some View {
        ZStack {
            // MARK: - Dark Base
            Color(red: 0.05, green: 0.05, blue: 0.06)
                .ignoresSafeArea()
            
            // MARK: - Decorative Blurred Circles
            // Using a slightly higher opacity (0.12) than onboarding (0.08) 
            // but lower than paywall (0.15) for better visibility in main app views
            Group {
                Circle()
                    .foregroundColor(.bgBlurOrange1.opacity(0.12))
                    .frame(width: isIpad ? 450 : 300, height: isIpad ? 450 : 300)
                    .blur(radius: isIpad ? 120 : 80)
                    .offset(x: isIpad ? -280 : -180, y: isIpad ? 500 : 350)
                
                Circle()
                    .foregroundColor(.bgBlurOrange2.opacity(0.12))
                    .frame(width: isIpad ? 450 : 300, height: isIpad ? 450 : 300)
                    .blur(radius: isIpad ? 120 : 80)
                    .offset(x: isIpad ? 280 : 180, y: isIpad ? -500 : -350)
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    AppGlobalBackground()
}
