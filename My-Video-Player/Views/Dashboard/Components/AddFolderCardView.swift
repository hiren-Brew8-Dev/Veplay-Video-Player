import SwiftUI

struct AddFolderCardView: View {
    var action: () -> Void
    var size: CGFloat = 160 // Default size for horizontal scroll
    
    var body: some View {
        Button(action: {
            HapticsManager.shared.generate(.selection)
            action()
        }) {
            VStack(alignment: .center, spacing: 12) {
                // Main Action Area
                ZStack {
                    // Unique Background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.homeAccent.opacity(0.05))
                    
                    // Dashed Border
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .foregroundColor(Color.homeAccent.opacity(0.3))
                    
                    VStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.homeAccent)
                        
                        Text("New Folder")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.homeAccent)
                    }
                }
                .frame(width: size - 16, height: size - 16)
                .padding(.top, 8)
                
                Text("Create Folder")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.homeTextSecondary)
                    .padding(.bottom, 8)
            }
            .frame(width: size)
            .background(Color.white.opacity(0.03))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.scalable)
    }
}
