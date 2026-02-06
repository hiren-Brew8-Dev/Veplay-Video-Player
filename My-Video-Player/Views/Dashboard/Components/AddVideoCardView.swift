import SwiftUI

struct AddVideoCardView: View {
    var action: () -> Void
    
    var body: some View {
        let size = GridLayout.itemSize
        let thumbnailSize = size
        
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // 1. Placeholder Thumbnail Section
                ZStack {
                    Color.themeSurface
                    
                    VStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 30, weight: .bold)) // Slightly smaller to match scale
                            .foregroundColor(.orange)
                        
                        Text("Add Video")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .frame(width: thumbnailSize - 16, height: thumbnailSize - 16)
                .clipped()
                .cornerRadius(10)
                .padding(.top, 8)
                .padding(.horizontal, 8)
                
                // 2. Info Section
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import New")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("From Photos or Files")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray.opacity(0.8))
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .background(Color.themeSurface.opacity(0.4))
            .cornerRadius(20)
        }
    }
}
