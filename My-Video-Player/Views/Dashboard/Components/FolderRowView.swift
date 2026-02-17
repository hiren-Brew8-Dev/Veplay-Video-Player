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
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black.opacity(0.4))
                    .frame(width: isIpad ? 80 : 64, height: isIpad ? 80 : 64)
                
                Image(systemName: "folder.fill")
                    .font(.system(size: isIpad ? 32 : 26))
                    .foregroundColor(Color(hex: "F9CB8A"))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            
            // 2. Info Section
            VStack(alignment: .leading, spacing: 6) {
                Text(folder.name)
                    .font(.system(size: isIpad ? 22 : 16, weight: .semibold))
                    .foregroundColor(.homeTextPrimary)
                    .lineLimit(1)
                
                Text("\(folder.videos.count) Videos")
                    .font(.system(size: isIpad ? 16 : 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // 3. Actions
            if !isSelectionMode {
                Button(action: {
                    onMenuAction?()
                }) {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: isIpad ? 20 : 14, weight: .bold))
                        .foregroundColor(.homeTint)
                        .padding(isIpad ? 12 : 8)
                        .contentShape(Circle())
                }
                .buttonStyle(.scalable)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.premiumCardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(viewModel?.highlightFolderId == folder.id ? Color.orange : Color.premiumCardBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

#Preview {
    ZStack {
        Color.homeBackground.ignoresSafeArea()
        
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                FolderRowView(
                    folder: Folder(
                        name: "Downloads",
                        videoCount: 16,
                        videos: []
                    ),
                    viewModel: nil
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.leading, 96) // Align divider past the icon
                
                FolderRowView(
                    folder: Folder(
                        name: "Movies",
                        videoCount: 24,
                        videos: []
                    ),
                    viewModel: nil
                )
            }
            .background(Color.premiumCardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.premiumCardBorder, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            
            Spacer()
        }
        .padding(.top, 40)
    }
}
