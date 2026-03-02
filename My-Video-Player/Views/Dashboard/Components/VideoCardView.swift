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
                colors: [.black.opacity(0), .black.opacity(0.5), .black.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: size * 0.75)
            
            // 2. Info Overlay
            VStack(spacing: 0) {
                // Top Row: Menu / Selection
                HStack {
                    Spacer()
                    if isSelectionMode {
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.homeAccent : Color.black.opacity(0.5))
                                .frame(width: 22, height: 22)
                            
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.black)
                            } else {
                                Circle()
                                    .stroke(Color.white, lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                            }
                        }
                    } else {
                        Button(action: {
                            HapticsManager.shared.generate(.medium)
                            onMenuAction?()
                        }) {
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
                        HStack {  Text(resolvedTitle?.withExtension(video.url?.pathExtension ?? "") ?? video.fullNameWithExtension)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)
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
                        
                        HStack(spacing: 4) {
                            Text(formatDate(video.importDate))
                            if video.asset == nil {
                                Text("•")
                                Text(formatBytes(video.fileSizeBytes))
                            }
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                    }
                }
                .padding(16)
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
            // Skip if already loaded — cells can reappear after light scroll without needing reload
            if thumbnail == nil { loadThumbnail() }
            if resolvedTitle == nil { loadTitle() }
        }
        .onDisappear {
            // Cancel any in-flight thumbnail request — prevents stale completions from
            // triggering extra SwiftUI renders after the cell has left the viewport
            ThumbnailCacheManager.shared.cancelRequest(for: video.id)
        }
    }
    
    // MARK: - Helpers

    // Static formatters — DateFormatter/DateComponentsFormatter are expensive to allocate.
    // Creating them per-render with a large video grid is a major source of lag.
    private static let shortDurationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.minute, .second]
        f.unitsStyle = .positional
        f.zeroFormattingBehavior = .pad
        return f
    }()

    private static let longDurationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute, .second]
        f.unitsStyle = .positional
        f.zeroFormattingBehavior = .pad
        return f
    }()

    private static let cardDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = duration >= 3600 ? Self.longDurationFormatter : Self.shortDurationFormatter
        return formatter.string(from: duration) ?? "00:00"
    }

    private func formatDate(_ date: Date) -> String {
        return Self.cardDateFormatter.string(from: date)
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
    
    /// loadThumbnail
    /// - Description: Two-stage instant loading:
    ///   1. getThumbnailSync — NSCache (µs) or disk JPEG (0.3ms). Sets @State in the
    ///      same render frame — zero placeholder flash for any previously seen video.
    ///   2. getThumbnail async — only fires if no JPEG exists yet. Generates, writes JPEG,
    ///      next scroll it will be instant forever.
    /// - How to use: Called from .onAppear guarded by thumbnail == nil.
    private func loadThumbnail() {
        // Sync path — instant, same render frame, no state-change flash
        if let instant = ThumbnailCacheManager.shared.getThumbnailSync(for: video) {
            thumbnail = instant
            return
        }
        // Async fallback — first-ever generation only
        ThumbnailCacheManager.shared.getThumbnail(for: video, requestId: video.id) { image in
            DispatchQueue.main.async { self.thumbnail = image }
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
