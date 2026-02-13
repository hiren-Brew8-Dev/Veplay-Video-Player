import SwiftUI
import Photos
import MobileVLCKit

struct VideoCardView: View {
    let video: VideoItem
    let viewModel: DashboardViewModel?
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onMenuAction: (() -> Void)? = nil
    var itemSize: CGFloat = 150
    
    @State private var thumbnail: UIImage?
    @State private var resolvedTitle: String? = nil
    @State private var vlcLoader: VLCThumbnailHelper? // Retain the loader
    
    var body: some View {
        let size = itemSize
        
        ZStack(alignment: .bottom) {
            // 1. Thumbnail Background
            if let thumb = thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size * 1.1) // Slightly taller aspect ratio if needed, or just square/set by grid
                    .clipped()
            } else {
                ZStack {
                    Color.premiumCardBackground
                    Image(systemName: "video.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.2))
                }
                .frame(width: size, height: size * 1.1)
            }
            
            // Gradient Overlay
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.9)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: size * 0.6)
            
            // 2. Info Overlay
            VStack(spacing: 0) {
                // Top Row: Menu / Selection
                HStack {
                    Spacer()
                    if isSelectionMode {
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.homeAccent : Color.black.opacity(0.5))
                                .frame(width: 28, height: 28)
                            
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                            } else {
                                Circle()
                                    .stroke(Color.white, lineWidth: 1.5)
                                    .frame(width: 28, height: 28)
                            }
                        }
                    } else {
                        Button(action: { onMenuAction?() }) {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .background(.black.opacity(0.4))
                                    .frame(width: 32, height: 32)
                                    .clipShape(.circle)
                                    .overlay {
                                        Circle()
                                            .stroke(style: StrokeStyle(lineWidth: 1))
                                            .fill(.white.opacity(0.1))
                                    }
                                Image(systemName: "ellipsis")
                                    .rotationEffect(.degrees(90))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .padding(10)
                
                Spacer()
                
                // Bottom Row: Title & Metadata + Duration
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {  Text(resolvedTitle?.truncated(ext: video.url?.pathExtension ?? "") ?? video.truncatedTitle)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                            
                            
                            Spacer()
                            
                            // Duration Pill
                            Text(formatDuration(video.duration))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.9))
                                .cornerRadius(8)
                        }
                        
                        Text("\(formatDate(video.creationDate)) • \(formatBytes(video.fileSizeBytes))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: size, height: size * 1.1)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        // Highlight effect
        .overlay(
            Group {
                if viewModel?.highlightVideoId == video.id {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.orange, lineWidth: 3)
                }
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            loadThumbnail()
            loadTitle()
        }
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
