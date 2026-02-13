import SwiftUI
import Photos
import AVFoundation

struct VideoRowView: View {
    let video: VideoItem
    let viewModel: DashboardViewModel?
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    @State private var thumbnail: UIImage?
    @State private var resolvedTitle: String? = nil
    @State private var vlcLoader: VLCThumbnailHelper? // Retain the loader
    var onMenuAction: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
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
            }
            
            ZStack(alignment: .bottomTrailing) {
                if let thumb = thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: isIpad ? 140 : 96, height: isIpad ? 100 : 72)
                        .clipped()
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: isIpad ? 140 : 96, height: isIpad ? 100 : 72)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                
                Text(video.formattedDuration)
                    .font(isIpad ? .caption : .caption2)
                    .foregroundColor(.homeTextPrimary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 3)
                    .background(Color.homeBackground.opacity(0.7))
                    .clipShape(.capsule)
                    .padding(4)
            }
            
            VStack(alignment: .leading, spacing: isIpad ? 8 : 4) {
                Text(resolvedTitle?.truncated(ext: video.url?.pathExtension ?? "") ?? video.truncatedTitle)
                    .font(.system(size: isIpad ? 22 : 16, weight: .semibold))
                    .foregroundColor(.homeTextPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(formattedDate(video.creationDate))
                    if video.asset == nil { // Only show file size for imported/local videos
                        Text("•")
                        Text(formatBytes(video.fileSizeBytes))
                    }
                }
                .font(.system(size: isIpad ? 16 : 12))
                .foregroundColor(.homeTextSecondary)
            }
            
            Spacer()
            
            if !isSelectionMode {
                Button(action: { onMenuAction?() }) {
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
        .background(Color.homeBackground.opacity(0.001)) // Foolproof tap capture
        .contentShape(Rectangle())
        .scaleEffect(viewModel?.highlightVideoId == video.id ? 1.02 : 1.0)
        .animation(.spring(), value: viewModel?.highlightVideoId)
        .onAppear {
            loadThumbnail()
            loadTitle()
        }
        .onChange(of: video.id) { _, _ in
            loadThumbnail()
            loadTitle()
        }
    }
    
    private func loadTitle() {
        if video.isGenericTitle {
            viewModel?.loadTitle(for: video) { title in
                self.resolvedTitle = title
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let doubleBytes = Double(bytes)
        let kb = doubleBytes / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        if gb >= 1.0 { return String(format: "%.1f GB", gb) }
        else if mb >= 1.0 { return String(format: "%.1f MB", mb) }
        else { return String(format: "%.0f KB", kb) }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
    private func loadThumbnail() {
        // Use the persistent cache manager for instant loading
        ThumbnailCacheManager.shared.getThumbnail(for: video) { [self] image in
            DispatchQueue.main.async {
                self.thumbnail = image
            }
        }
    }
}

#Preview {
    ZStack {
        Color.homeBackground.ignoresSafeArea()
        
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                VideoRowView(
                    video: VideoItem(
                        title: "Intro Animation.mp4",
                        duration: 45,
                        creationDate: Date(),
                        fileSizeBytes: 1024 * 1024 * 5,
                        url: URL(fileURLWithPath: "v1.mp4")
                    ),
                    viewModel: nil
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.leading, 124) // Align past the thumbnail
                
                VideoRowView(
                    video: VideoItem(
                        title: "Travel Vlog 2024.mov",
                        duration: 320,
                        creationDate: Date().addingTimeInterval(-86400),
                        fileSizeBytes: 1024 * 1024 * 128,
                        url: URL(fileURLWithPath: "v2.mp4")
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
