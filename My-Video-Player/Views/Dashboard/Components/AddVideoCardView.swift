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
                    Color.white.opacity(0.05)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.homeAccent)
                        
                        Text("Add Video")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.homeTextSecondary)
                    }
                }
                .frame(width: thumbnailSize - 16, height: thumbnailSize - 16)
                .clipped()
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.horizontal, 8)
                
                // 2. Info Section
                HStack(alignment: .center, spacing: 0) {
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
                .padding(.leading, 12)
                .padding(.trailing, 0)
                .padding(.bottom, 8)
            }
            .background(Color.premiumCardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.premiumCardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
