import SwiftUI

struct PermissionDeniedView: View {
    var body: some View {
        ZStack {
            Color.homeBackground.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: isIpad ? 120 : 80))
                    .foregroundColor(.homeAccent)
                    .padding(.bottom, isIpad ? 40 : 20)
                
                Text("Permission Required")
                    .font(isIpad ? .title : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(.homeTextPrimary)
                
                Text("We need access to your Photo Library to display your videos. Please enable access in Settings.")
                    .font(isIpad ? .title3 : .body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.homeTextSecondary)
                    .padding(.horizontal, isIpad ? 80 : 20)
                
                Button(action: {
                    HapticsManager.shared.generate(.medium)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Open Settings")
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.homeTint)
                        .cornerRadius(10)
                }
                .padding(.top, isIpad ? 40 : 20)
                .padding(.horizontal, isIpad ? 80 : 40)
                .iPad { $0.frame(maxWidth: 400) }
            }
        }
    }
}
