import SwiftUI

struct FolderRowView: View {
    let folder: Folder
    let viewModel: DashboardViewModel?
    var onMenuAction: (() -> Void)? = nil
    
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            if isSelectionMode {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.homeAccent : Color.clear)
                        .frame(width: AppDesign.Icons.selectionIconSize - 2, height: AppDesign.Icons.selectionIconSize - 2)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: isIpad ? 14 : 10, weight: .bold))
                            .foregroundColor(.homeTextPrimary)
                    } else {
                        Circle()
                            .stroke(Color.homeTextSecondary, lineWidth: 1.5)
                            .frame(width: isIpad ? 30 : 22, height: isIpad ? 30 : 22)
                    }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            // 1. Icon Section
            ZStack {
                Color.white.opacity(0.05)
                
                Image(systemName: "folder.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.homeAccent)
            }
            .frame(width: 50, height: 50)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            // 2. Info Section
            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.homeTextPrimary)
                    .lineLimit(1)
                
                Text("\(folder.videos.count) Videos")
                    .font(.system(size: 13))
                    .foregroundColor(.homeTextSecondary)
            }
            
            Spacer()
            
            // 3. Actions
            if !isSelectionMode {
                Button(action: {
                    onMenuAction?()
                }) {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.homeTextPrimary)
                        .padding(12)
                        .contentShape(Circle())
                }
                .buttonStyle(.scalable)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            ZStack {
                if viewModel?.highlightFolderId == folder.id {
                    Color.orange.opacity(0.1)
                } else {
                    Color.homeBackground.opacity(0.001) // Capture taps
                }
            }
        )
        .cornerRadius(16)
        .overlay(
            Group {
                if viewModel?.highlightFolderId == folder.id {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange, lineWidth: 1)
                }
            }
        )
        .contentShape(Rectangle())
    }
}
