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
        if isIpad {
            sheetContent
        } else {
            VStack(spacing: 0) {
                Spacer()
                sheetContent
            }
            .edgesIgnoringSafeArea(.bottom)
        }
    }
    
    private var sheetContent: some View {
        VStack(spacing: 0) {
            if !isIpad {
                // Drag Handle
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
            }
                
            // Header Section
            if let target = target {
                headerView(for: target)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 28)
            }
            
            // Actions Card
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button(action: {
                        withAnimation {
                            isPresented = false
                        }
                        // Increased delay to allow sheet to fully dismiss and UI to stabilize
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            item.action()
                        }
                    }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(item.role == .destructive ? Color.red.opacity(0.1) : Color.premiumCircleBackground)
                                    .frame(width: isIpad ? 48 : 36, height: isIpad ? 48 : 36)
                                
                                Image(systemName: item.icon)
                                    .font(.system(size: isIpad ? 22 : 16, weight: .semibold))
                                    .foregroundColor(item.role == .destructive ? .red : .white)
                            }
                            
                            Text(item.title)
                                .font(.system(size: isIpad ? 20 : 16, weight: .medium))
                                .foregroundColor(item.role == .destructive ? .red : .white)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(height: isIpad ? 72 : 56)
                        .contentShape(Rectangle())
                    }
                    
                    if index < items.count - 1 {
                        Rectangle()
                            .fill(Color.premiumCardBorder)
                            .frame(height: 1)
                            .padding(.leading, 68)
                            .padding(.trailing, 16)
                    }
                }
            }
            .background(Color.premiumCardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.premiumCardBorder, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 40) // Extra padding for safe area
        }
        .background(
            LinearGradient(
                colors: [.premiumGradientTop, .premiumGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .applyIf(isIpad) { $0.cornerRadius(28) }
        .applyIf(!isIpad) { $0.cornerRadiusLocal(28, corners: [.topLeft, .topRight]) }
        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: isIpad ? 10 : -10)
    }
    
    @ViewBuilder
    private func headerView(for target: DashboardViewModel.ActionSheetTarget) -> some View {
        HStack(spacing: 16) {
            switch target {
            case .video(let video):
                ZStack(alignment: .bottomTrailing) {
                    ActionSheetThumbnailView(video: video)
                        .frame(width: isIpad ? 140 : 90, height: isIpad ? 88 : 56)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    Text(formatDuration(video.duration))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .padding(4)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    ActionSheetHeaderTitleView(video: video)
                        .font(.system(size: isIpad ? 22 : 17, weight: .bold))
                    
                    if video.asset != nil {
                         Text("\(formatDate(video.creationDate))")
                            .font(.system(size: isIpad ? 17 : 13))
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        Text("\(formatDate(video.creationDate)) • \(formatBytes(video.fileSizeBytes))")
                            .font(.system(size: isIpad ? 17 : 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
            case .folder(let folder):
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: isIpad ? 140 : 90, height: isIpad ? 88 : 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                        )
                    
                    Image(systemName: "folder.fill")
                        .font(.system(size: isIpad ? 36 : 24))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.name)
                        .font(.system(size: isIpad ? 22 : 17, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(folder.videos.count) Videos")
                        .font(.system(size: isIpad ? 17 : 13))
                        .foregroundColor(.white.opacity(0.5))
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
        Text(resolvedTitle.isEmpty ? video.fullNameWithExtension : resolvedTitle.withExtension(video.url?.pathExtension ?? ""))
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .lineLimit(2)
            .truncationMode(.tail)
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
                    .fill(Color.white.opacity(0.05))
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
        ThumbnailCacheManager.shared.getThumbnail(for: video) { image in
            self.thumbnail = image
        }
    }
}
