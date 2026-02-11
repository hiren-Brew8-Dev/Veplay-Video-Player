import SwiftUI

struct AddFolderCardView: View {
    var action: () -> Void
    var size: CGFloat = 160 // Default size for horizontal scroll
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // 1. Icon Section
                ZStack {
                    Color.white.opacity(0.05)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.homeAccent)
                        
                        Text("New Folder")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.homeTextSecondary)
                    }
                }
                .frame(width: size - 16, height: size - 16)
                .clipped()
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.top, 8)
                .padding(.horizontal, 8)
                
                // 2. Info Section
                HStack(alignment: .center, spacing: 0) {
                    Text("Create Folder")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.homeTextPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                }
                .padding(.leading, 12)
                .padding(.bottom, 8)
            }
            .frame(width: size)
            .background(Color.premiumCardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.premiumCardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.scalable)
    }
}
