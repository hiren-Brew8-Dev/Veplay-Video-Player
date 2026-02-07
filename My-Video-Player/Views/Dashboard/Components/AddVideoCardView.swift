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
                    Color.homeCardBackground
                    
                    VStack(spacing: 8) {
                        Image(systemName: "plus")
                            .appIconStyle(size: 30, weight: .bold, color: .homeAccent)
                        
                        Text("Add Video")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.homeTextPrimary.opacity(0.3))
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
                            .foregroundColor(.homeTextPrimary)
                            .lineLimit(1)
                        
                        Text("From Photos or Files")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.homeTextSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .background(Color.homeCardBackground.opacity(0.4))
            .cornerRadius(20)
        }
    }
}
