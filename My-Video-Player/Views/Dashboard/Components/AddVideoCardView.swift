import SwiftUI

struct AddVideoCardView: View {
    var action: () -> Void
    var size: CGFloat = 150
    
    var body: some View {
        let size = size
        
        Button(action: action) {
            ZStack(alignment: .bottom) {
                // 1. Background Section
                ZStack {
                    Color.premiumCardBackground
                    
                    VStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.homeAccent)
                        
                        Text("Add Video")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.2))
                    }
                }
                .frame(width: size, height: size * 1.1)
                
                // Gradient Overlay
                LinearGradient(
                    colors: [.black.opacity(0), .black.opacity(0.5), .black.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: size * 0.75)
                
                // 2. Info Overlay
                VStack(spacing: 0) {
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Import New")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text("From Photos or Files")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                }
            }
            .frame(width: size, height: size * 1.1)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
