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
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.homeTextPrimary)
                    } else {
                        Circle()
                            .stroke(Color.homeTextSecondary, lineWidth: 1.5)
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
                        .fill(Color.homeCardBackground)
                        .frame(width: 100, height: 60)
                        .cornerRadius(8)
                }

                Text(video.formattedDuration)
                    .font(.caption2)
                    .foregroundColor(.homeTextPrimary)
                    .padding(2)
                    .background(Color.homeBackground.opacity(0.7))
                    .cornerRadius(2)
                    .padding(2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(resolvedTitle ?? video.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.homeTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(video.formattedDuration) // The "time"
                    Text("•")
                    Text(formattedDate(video.creationDate))
                }
                .font(.system(size: 12))
                .foregroundColor(.homeTextSecondary)
            }

            Spacer()

            if video.url != nil {
                Text(formatBytes(video.fileSizeBytes)) // The "size"
                    .font(.system(size: 12))
                    .foregroundColor(.homeTextSecondary)
                    .padding(.trailing, 2) // Close to the dots
            }
            if !isSelectionMode {
                Button(action: { onMenuAction?() }) {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.homeTint)
                        .padding(8)
                        .contentShape(Circle())
                }
                .buttonStyle(.scalable)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 16) // Exactly 16 to match header
        .padding(.vertical, 8)
        .background(
            ZStack {
                Color.homeBackground
                if viewModel?.highlightVideoId == video.id {
                    Color.homeAccent.opacity(0.1)
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.homeAccent, lineWidth: 2)
                }
            }
        )
        .contentShape(Rectangle())
        .scaleEffect(viewModel?.highlightVideoId == video.id ? 1.02 : 1.0)
        .animation(.spring(), value: viewModel?.highlightVideoId)
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
