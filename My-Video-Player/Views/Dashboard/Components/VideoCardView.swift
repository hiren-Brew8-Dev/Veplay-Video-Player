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
                        Color.themeSurface
                        Image(systemName: "video.fill")
                            .foregroundColor(.white.opacity(0.15))
                            .font(.system(size: 30))
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
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                    .padding(14) // Adjusted for thumbnail internal padding
                
                // Selection Overlay
                if isSelectionMode {
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.orange : Color.black.opacity(0.3))
                                    .frame(width: 24, height: 24)
                                
                                if isSelected {
                                    Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                } else {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1.5)
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
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(formatDate(video.creationDate))
                        if video.asset == nil { // Only show file size for imported/local videos
                            Text("•")
                            Text(formatBytes(video.fileSizeBytes))
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
                }
                
                Spacer()
                
                Button(action: {
                    onMenuAction?()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 44, height: 44) // Increased touch area
                    .contentShape(Rectangle())
                }
                .offset(x: 4, y: -4)
            }
            .padding(.horizontal, 12) // Match the 8px + 4px alignment
            .padding(.bottom, 8)
        }
        //.padding(padding) // Removed to fix spacing
        .background(
            ZStack {
                Color.themeSurface.opacity(0.4)
                if viewModel?.highlightVideoId == video.id {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.orange, lineWidth: 3)
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
        if let asset = video.asset {
            let manager = viewModel?.imageManager ?? PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            
            let targetDimension: CGFloat = 300 * UIScreen.main.scale
            let targetSize = CGSize(width: targetDimension * 1.6, height: targetDimension)
            
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
                self.thumbnail = image
            }
        } else if let url = video.url {
            Task {
                let asset = AVAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                
                // Check for VLC Format
                if ["mkv", "avi", "wmv", "flv", "webm", "3gp"].contains(url.pathExtension.lowercased()) {
                    let loader = VLCThumbnailHelper()
                    await MainActor.run {
                        self.vlcLoader = loader // Retain it
                        loader.generate(for: url) { image in
                            self.thumbnail = image
                            self.vlcLoader = nil // Release
                        }
                    }
                    return
                }
                
                // Try to load duration asynchronously
                let dur = try? await asset.load(.duration)
                let durationValue = CMTimeGetSeconds(dur ?? .zero)
                
                let timeToCapture = durationValue > 2.0 ? 1.0 : 0.0
                let time = CMTime(seconds: timeToCapture, preferredTimescale: 60)
                
                if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                    let uiImage = UIImage(cgImage: cgImage)
                    await MainActor.run {
                        self.thumbnail = uiImage
                    }
                } else {
                    // Fallback to 0 if 1 sec failed
                    if let cg = try? generator.copyCGImage(at: .zero, actualTime: nil) {
                        let uiImage = UIImage(cgImage: cg)
                        await MainActor.run {
                            self.thumbnail = uiImage
                        }
                    }
                }
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
