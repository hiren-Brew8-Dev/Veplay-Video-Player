import SwiftUI

struct AddVideoCardView: View {
    var action: () -> Void
    
    var body: some View {
        let size = GridLayout.itemSize
        let padding: CGFloat = 8
        let innerSize = size - (padding * 2)
        
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Placeholder Thumbnail Section
                ZStack {
                    Color.themeSurface
                    
                    VStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.orange)
                        
                        Text("Add Video")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .frame(width: innerSize, height: innerSize)
                .clipped()
                .cornerRadius(12)
                
                // Info Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("Import New")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("From Photos or Files")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray.opacity(0.8))
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }
            .padding(8)
            .background(Color.themeSurface.opacity(0.4))
            .cornerRadius(20)
        }
        .buttonStyle(.scalable)
    }
}
