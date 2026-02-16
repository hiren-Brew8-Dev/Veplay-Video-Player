import SwiftUI

struct AppGlobalBackground: View {
    var isIpad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    
    var body: some View {
        ZStack {
            // MARK: - Dark Base
            Color.black
                .ignoresSafeArea()
            
            // MARK: - Decorative Blurred Circles
            // Using a slightly higher opacity (0.12) than onboarding (0.08) 
            // but lower than paywall (0.15) for better visibility in main app views
            Group {
                Circle()
                    .foregroundColor(.bgBlurOrange1.opacity(0.12))
                    .frame(width: isIpad ? 400 : 256, height: isIpad ? 400 : 256)
                    .blur(radius: isIpad ? 120 : 80)
                    .offset(x: isIpad ? -250 : -164.50, y: isIpad ? 600 : 410)
                
                Circle()
                    .foregroundColor(.bgBlurOrange2.opacity(0.12))
                    .frame(width: isIpad ? 400 : 256, height: isIpad ? 400 : 256)
                    .blur(radius: isIpad ? 120 : 80)
                    .offset(x: isIpad ? 250 : 161.50, y: isIpad ? -600 : -410)
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    AppGlobalBackground()
}
