import SwiftUI

struct FolderCardView: View {
    let folder: Folder
    let viewModel: DashboardViewModel?
    var onMenuAction: (() -> Void)? = nil
    var size: CGFloat = GridLayout.itemSize
    
    var body: some View {
        let padding: CGFloat = 8 // Internal padding to match VideoCardView logic
        let thumbnailSize = size // Fill the calculated grid item size
        
        VStack(alignment: .leading, spacing: 12) {
            // 1. Icon / Preview Section (Mimicking Thumbnail)
            ZStack {
                Color.white.opacity(0.05)
                
                VStack(spacing: AppDesign.Icons.internalSpacing) {
                    Image(systemName: "folder.fill")
                        .appIconStyle(size: AppDesign.Icons.largeIconSize, color: .homeAccent)
                    
                    Text("\(folder.videos.count) Videos")
                        .font(.system(size: 11, weight: .medium))
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
            .padding(.top, 8)
            .padding(.horizontal, 8)
            
            // 2. Bottom Info Bar
            HStack(alignment: .center, spacing: 0) {
                Text(folder.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.homeTextPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: {
                    onMenuAction?()
                }) {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.homeTextPrimary)
                        .padding(8)
                        .contentShape(Circle())
                }
                .buttonStyle(.scalable)
            }
            .padding(.leading, 12)
            .padding(.trailing, 0)
            .padding(.bottom, 8)
        }
        .frame(width: size)
        .background(
            ZStack {
                Color.premiumCardBackground
                if viewModel?.highlightFolderId == folder.id {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.orange, lineWidth: 2)
                }
            }
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.premiumCardBorder, lineWidth: 1)
        )
        .scaleEffect(viewModel?.highlightFolderId == folder.id ? 1.05 : 1.0)
        .animation(.spring(), value: viewModel?.highlightFolderId)
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }
}
