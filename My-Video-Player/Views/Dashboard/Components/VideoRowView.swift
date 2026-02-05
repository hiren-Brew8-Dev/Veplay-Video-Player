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
                        .fill(isSelected ? Color.orange : Color.clear)
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .stroke(Color.gray, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                    }
                }
            }

            ZStack(alignment: .bottomTrailing) {
                if let thumb = thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 60)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 60)
                        .cornerRadius(8)
                }

                Text(video.formattedDuration)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(2)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(2)
                    .padding(2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(resolvedTitle ?? video.title)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack {
                    Text(formattedDate(video.creationDate))
                    if video.url != nil {
                        Text("•")
                        Text(formatBytes(video.fileSizeBytes))
                    }
                }
                .font(.caption)
                .foregroundColor(.gray)
            }

            Spacer()

            if !isSelectionMode {
                Button(action: {
                    onMenuAction?()
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onAppear { 
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
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func loadThumbnail() {
        if let asset = video.asset {
            let manager = viewModel?.imageManager ?? PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            
            let targetDimension: CGFloat = 300 * UIScreen.main.scale
            manager.requestImage(for: asset, targetSize: CGSize(width: targetDimension, height: targetDimension * 0.6), contentMode: .aspectFill, options: options) { image, _ in
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
                
                if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
                    let uiImage = UIImage(cgImage: cgImage)
                    await MainActor.run { self.thumbnail = uiImage }
                }
            }
        }
    }
}
