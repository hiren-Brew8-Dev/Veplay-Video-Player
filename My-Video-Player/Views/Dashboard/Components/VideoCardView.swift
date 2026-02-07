import SwiftUI
import Photos
import MobileVLCKit

struct VideoCardView: View {
    let video: VideoItem
    let viewModel: DashboardViewModel?
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onMenuAction: (() -> Void)? = nil
    
    @State private var thumbnail: UIImage?
    @State private var resolvedTitle: String? = nil
    @State private var vlcLoader: VLCThumbnailHelper? // Retain the loader
    
    var body: some View {
        let size = GridLayout.itemSize
        let padding: CGFloat = 0 // Remove internal extra padding to fit grid better
        let thumbnailSize = size // Fill the calculated grid item size
        
        VStack(alignment: .leading, spacing: 12) {
            // 1. Thumbnail Section
            ZStack(alignment: .bottomTrailing) {
                if let thumb = thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(width: thumbnailSize - 16, height: thumbnailSize - 16) // Subtracted padding from size
                        .clipped()
                        .cornerRadius(10)
                    
                } else {
                    ZStack {
                        Color.homeCardBackground
                        Image(systemName: "video.fill")
                            .appSecondaryIconStyle(size: AppDesign.Icons.largeIconSize - 10, color: .homeTextPrimary.opacity(0.15))
                    }
                    .frame(width: thumbnailSize - 16, height: thumbnailSize - 16)
                    .clipped()
                    .cornerRadius(10)
                }
                
                // Duration Overlay
                Text(formatDuration(video.duration))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.homeBackground.opacity(0.7))
                    .cornerRadius(4)
                    .padding(14) // Adjusted for thumbnail internal padding
                
                // Selection Overlay
                if isSelectionMode {
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.homeAccent : Color.homeBackground.opacity(0.3))
                                    .frame(width: AppDesign.Icons.selectionIconSize, height: AppDesign.Icons.selectionIconSize)
                                
                                if isSelected {
                                    Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.homeTextPrimary)
                                } else {
                                    Circle()
                                        .stroke(Color.homeTextPrimary, lineWidth: 1.5)
                                        .frame(width: 24, height: 24)
                                }
                            }
                            .padding(14) // Adjusted for thumbnail internal padding
                        }
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.horizontal, 8) // This gives equal spacing on both sides
            
            // 2. Info Section
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(resolvedTitle ?? video.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.homeTextPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(formatDate(video.creationDate))
                        if video.asset == nil { // Only show file size for imported/local videos
                            Text("•")
                            Text(formatBytes(video.fileSizeBytes))
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.homeTextSecondary)
                }
                
                Spacer()
                
                if !isSelectionMode {
                    Button(action: { onMenuAction?() }) {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .appIconStyle(size: AppDesign.Icons.rowIconSize - 2, weight: .bold, color: .homeTextPrimary)
                            .padding(8) // Hit area
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(
            ZStack {
                Color.homeCardBackground.opacity(0.4)
                if viewModel?.highlightVideoId == video.id {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.homeAccent, lineWidth: 3)
                }
            }
        )
        .cornerRadius(20)
        .scaleEffect(viewModel?.highlightVideoId == video.id ? 1.05 : 1.0)
        .animation(.spring(), value: viewModel?.highlightVideoId)
        .onAppear {
            loadThumbnail()
            loadTitle()
        }
        .contentShape(RoundedRectangle(cornerRadius: 20)) // Fix: Constrain button tap area strictly to card shape
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let doubleBytes = Double(bytes)
        let kb = doubleBytes / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        } else {
             return String(format: "%.0f KB", kb)
        }
    }
    
    private func loadThumbnail() {
        // Use the persistent cache manager for instant loading
        ThumbnailCacheManager.shared.getThumbnail(for: video) { [self] image in
            DispatchQueue.main.async {
                self.thumbnail = image
            }
        }
    }
    
    private func loadTitle() {
        if video.isGenericTitle {
            viewModel?.loadTitle(for: video) { title in
                self.resolvedTitle = title
            }
        }
    }
}
