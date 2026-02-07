import SwiftUI

struct SyncingOverlayView: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.homeBackground.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .homeTextPrimary))
                    .scaleEffect(1.5)
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.homeAccent)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.sheetSurface)
            )
            .shadow(radius: 10)
        }
        .transition(.opacity)
    }
}

#Preview {
    SyncingOverlayView(message: "Syncing...")
}
