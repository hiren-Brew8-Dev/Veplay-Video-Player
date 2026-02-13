import SwiftUI

struct FolderCardView: View {
    let folder: Folder
    let viewModel: DashboardViewModel?
    var onMenuAction: (() -> Void)? = nil
    var size: CGFloat = 160
    var aspectRatio : CGFloat = 173.0/184.0
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    
    var body: some View {
        let cardSize = size
        
        VStack(spacing: 0) {
            // 1. Top Section - Icon Area
            ZStack {
                VStack(spacing: 12) {
                    Spacer()
                    
                    // Folder Icon Container
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.4))
                            .frame(width: cardSize * 0.42, height: cardSize * 0.42)
                        
                        Image(systemName: "folder.fill")
                            .font(.system(size: cardSize * 0.20))
                            .foregroundColor(Color(hex: "F9CB8A"))
                    }
                    
                    Text("\(folder.videos.count) Videos")
                        .font(.system(size: isIpad ? 18 : 13, weight: .medium))
                        .foregroundColor(.homeTextPrimary.opacity(0.8))
                    
                    Spacer()
                }
                
                // Selection Mode Overlay (Top Right)
                if isSelectionMode {
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.homeAccent : Color.black.opacity(0.3))
                                    .frame(width: 22, height: 22)
                                
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.black)
                                } else {
                                    Circle()
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                                        .frame(width: 22, height: 22)
                                }
                            }
                            .padding(12)
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: cardSize * 0.85)
            
            // 2. Bottom Section - Title & Menu
            HStack(alignment: .center, spacing: 3) {
                Text(folder.name)
                    .font(.system(size: isIpad ? 22 : 16, weight: .bold))
                    .foregroundColor(.homeTextPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                if !isSelectionMode {
                    Button(action: { onMenuAction?() }) {
                        Image(systemName: "ellipsis")
                            
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.homeTextPrimary)
                            .padding(5)
                            
                            .contentShape(Circle())
                            .rotationEffect(.degrees(90))
                    }
                    .buttonStyle(.scalable)
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
            .padding(.bottom, 16)
        }
        .frame(width: cardSize, height: cardSize * 1.1)
        .background(
            ZStack {
                Color.premiumCardBackground
                
                if viewModel?.highlightFolderId == folder.id {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.orange, lineWidth: 2)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.premiumCardBorder, lineWidth: 1)
        )
        .scaleEffect(viewModel?.highlightFolderId == folder.id ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel?.highlightFolderId)
        .contentShape(RoundedRectangle(cornerRadius: 24))
    }
}

#Preview {
    ZStack {
        Color.homeBackground.ignoresSafeArea()
        
        FolderCardView(
            folder: Folder(
                name: "Downloads",
                videoCount: 16,
                videos: Array(repeating: VideoItem(
                    title: "test",
                    duration: 120,
                    creationDate: Date(),
                    fileSizeBytes: 1024 * 1024,
                    url: URL(fileURLWithPath: "test.mp4")
                ), count: 16)
            ),
            viewModel: nil,
            onMenuAction: {},
            size: 160
        )
    }
}

