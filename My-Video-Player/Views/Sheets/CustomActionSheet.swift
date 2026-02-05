import SwiftUI
import Photos
import AVFoundation
import MobileVLCKit

struct CustomActionItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let role: ButtonRole?
    let action: () -> Void
}

struct CustomActionSheet: View {
    let target: DashboardViewModel.ActionSheetTarget?
    let items: [CustomActionItem]
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            if isPresented {
                // Dimmed Background
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        isPresented = false
                    }
                    .transition(.opacity)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        // Handle
                        Capsule()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 4)
                            .padding(.top, 12)
                            .padding(.bottom, 20)
                        
                        // Header Section
                        if let target = target {
                            headerView(for: target)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 24)
                        }
                        
                        // Actions List
                        VStack(spacing: 0) {
                            ForEach(items) { item in
                                Button(action: {
                                    isPresented = false
                                    // Small delay to allow sheet to start dismissing
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        item.action()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: item.icon)
                                            .font(.system(size: 18))
                                            .foregroundColor(item.role == .destructive ? .red : .white)
                                            .frame(width: 24)
                                        
                                        Text(item.title)
                                            .font(.system(size: 16))
                                            .foregroundColor(item.role == .destructive ? .red : .white)
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 16)
                                    .padding(.horizontal, 20)
                                    .background(Color.themeSurface)
                                }
                                
                                if item.id != items.last?.id {
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                }
                            }
                        }
                        .background(Color.themeSurface)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40) // Extra padding for safe area
                    }
                    .background(Color.themeBackground)
                    .cornerRadius(24, corners: [.topLeft, .topRight])
                    .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: -5)
                }
                .edgesIgnoringSafeArea(.bottom)
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPresented)
    }
    
    @ViewBuilder
    private func headerView(for target: DashboardViewModel.ActionSheetTarget) -> some View {
        HStack(spacing: 16) {
            switch target {
            case .video(let video):
                ZStack(alignment: .bottomTrailing) {
                    ActionSheetThumbnailView(video: video)
                        .frame(width: 80, height: 50)
                        .cornerRadius(8)
                    
                    Text(formatDuration(video.duration))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(3)
                        .padding(4)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    ActionSheetHeaderTitleView(video: video)
                    
                    if video.asset != nil {
                         Text("\(formatDate(video.creationDate))")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    } else {
                        Text("\(formatDate(video.creationDate)) • \(formatBytes(video.fileSizeBytes))")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
            case .folder(let folder):
                Image(systemName: "folder.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.orange)
                    .frame(width: 80, height: 50)
                    .background(Color.themeSurface)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(folder.videos.count) Videos")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
    }
    
    // Helper Formatters
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct ActionSheetHeaderTitleView: View {
    let video: VideoItem
    @State private var resolvedTitle: String = ""
    
    var body: some View {
        Text(resolvedTitle.isEmpty ? video.title : resolvedTitle)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .lineLimit(2)
            .onAppear {
                if video.title == "Loading..." || video.title == VideoItem.titlePlaceholder {
                    loadTitle()
                } else {
                    resolvedTitle = video.title
                }
            }
    }
    
    private func loadTitle() {
        guard let asset = video.asset else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let resources = PHAssetResource.assetResources(for: asset)
            let filename = resources.first?.originalFilename ?? "Video"
            DispatchQueue.main.async {
                self.resolvedTitle = filename
            }
        }
    }
}

struct ActionSheetThumbnailView: View {
    let video: VideoItem
    @State private var thumbnail: UIImage? = nil
    @State private var vlcLoader: VLCThumbnailHelper? = nil
    
    var body: some View {
        Group {
            if let thumb = thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.themeSurface)
                    .overlay(
                        Image(systemName: "video.fill")
                            .foregroundColor(.white.opacity(0.15))
                            .font(.system(size: 20))
                    )
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        if let asset = video.asset {
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 200, height: 125),
                contentMode: .aspectFill,
                options: options
            ) { result, _ in
                self.thumbnail = result
            }
        } else if let path = video.thumbnailPath, let image = UIImage(contentsOfFile: path.path) {
            self.thumbnail = image
        } else if let url = video.url {
            let ext = url.pathExtension.lowercased()
            let vlcExtensions = ["mkv", "avi", "wmv", "flv", "webm", "3gp", "vob", "mpg", "mpeg", "ts", "m2ts", "divx", "asf"]
            
            if vlcExtensions.contains(ext) {
                let loader = VLCThumbnailHelper()
                self.vlcLoader = loader
                loader.generate(for: url) { image in
                    self.thumbnail = image
                    self.vlcLoader = nil
                }
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                let asset = AVAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                
                let duration = asset.duration.seconds
                let timeToCapture = duration > 2.0 ? 1.0 : 0.0
                let time = CMTime(seconds: timeToCapture, preferredTimescale: 60)
                
                do {
                    let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                    let uiImage = UIImage(cgImage: cgImage)
                    DispatchQueue.main.async {
                        self.thumbnail = uiImage
                    }
                } catch {
                    print("Thumbnail generation failed for action sheet: \(error)")
                }
            }
        }
    }
}
