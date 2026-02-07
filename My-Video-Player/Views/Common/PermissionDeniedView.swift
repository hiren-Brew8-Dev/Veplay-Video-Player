import SwiftUI

struct PermissionDeniedView: View {
    var body: some View {
        ZStack {
            Color.homeBackground.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.homeAccent)
                    .padding(.bottom, 20)
                
                Text("Permission Required")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.homeTextPrimary)
                
                Text("We need access to your Photo Library to display your videos. Please enable access in Settings.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.homeTextSecondary)
                    .padding(.horizontal)
                
                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Open Settings")
                        .fontWeight(.bold)
                        .foregroundColor(.homeTextPrimary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.homeTint)
                        .cornerRadius(10)
                }
                .padding(.top, 20)
                .padding(.horizontal, 40)
            }
        }
    }
}
