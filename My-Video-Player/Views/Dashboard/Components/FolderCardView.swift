import SwiftUI

struct FolderCardView: View {
    let folder: Folder
    var onMenuAction: (() -> Void)? = nil
    
    var body: some View {
        let size = GridLayout.itemSize
        let padding: CGFloat = 8
        let thumbnailSize = size - (padding * 2)
        
        VStack(spacing: 12) {
            ZStack {
                // Folder Surface
                Color.themeSurface
                
                // Icon / Preview
                VStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("\(folder.videos.count) Videos")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: thumbnailSize, height: thumbnailSize)
            .cornerRadius(12)
            
            // Bottom Info Bar
            HStack(alignment: .top) {
                Text(folder.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: {
                    onMenuAction?()
                }) {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .offset(y: -2)
            }
            .padding(.horizontal, 8)
        }
        .padding(8)
        .background(Color.themeSurface.opacity(0.4))
        .cornerRadius(20)
    }
}
