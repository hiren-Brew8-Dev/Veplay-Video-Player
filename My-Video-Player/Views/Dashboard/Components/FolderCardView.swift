import SwiftUI

struct FolderCardView: View {
    let folder: Folder
    var onMenuAction: (() -> Void)? = nil
    
    var body: some View {
        let size = GridLayout.itemSize
        let padding: CGFloat = 8 // Internal padding to match VideoCardView logic
        let thumbnailSize = size // Fill the calculated grid item size
        
        VStack(alignment: .leading, spacing: 12) { // Match VideoCardView spacing
            // 1. Icon / Preview Section (Mimicking Thumbnail)
            ZStack {
                Color.homeCardBackground
                
                VStack(spacing: AppDesign.Icons.internalSpacing) {
                    Image(systemName: "folder.fill")
                        .appIconStyle(size: AppDesign.Icons.largeIconSize, color: .homeAccent)
                    
                    Text("\(folder.videos.count) Videos")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.homeTextSecondary)
                }
            }
            .frame(width: thumbnailSize - 16, height: thumbnailSize - 16) // Subtracted padding from size (8+8)
            .clipped()
            .cornerRadius(10) // Match VideoCardView thumbnail radius
            .padding(.top, 8)
            .padding(.horizontal, 8) // Equal spacing
            
            // 2. Bottom Info Bar
            HStack(alignment: .top, spacing: 0) {
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
                        .appIconStyle(size: AppDesign.Icons.rowIconSize - 2, weight: .bold, color: .homeTextPrimary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .offset(y: -4) // Visual adjustment to align with text baseline
            }
            .padding(.leading, 12)
            .padding(.trailing, 0) // Match VideoCardView alignment
            .padding(.bottom, 8)
        }
        // Removed outer padding(8) to let card fill grid cell and handle internal padding like VideoCardView
        .background(Color.homeCardBackground.opacity(0.4))
        .cornerRadius(20)
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }
}
