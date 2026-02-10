import SwiftUI
import AVKit
import Photos
import AVFoundation

struct SettingsSheetView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Binding var isPresented: Bool
    let isLandscape: Bool
    
    // Callbacks for actions
    var onAudioTrack: () -> Void
    var onAirPlay: () -> Void
    var onSubtitle: () -> Void
    var onSleepTimer: () -> Void
    var onScreenshot: () -> Void
    var onShare: () -> Void
    let onPlayingMode: () -> Void
    let onPlaybackSpeed: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            if !isLandscape {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
            
            settingsHeader
            
            if isLandscape {
                landscapeBody
            } else {
                portraitBody
            }
        }
        .background(
            LinearGradient(
                colors: [.premiumGradientTop, .premiumGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .applyIf(isLandscape) { view in
            view.cornerRadiusLocal(24, corners: [.topLeft, .bottomLeft])
        }
        .applyIf(!isLandscape) { view in
            view.cornerRadiusLocal(24, corners: [.topLeft, .topRight])
        }
        .shadow(color: Color.black.opacity(0.6), radius: 20, x: 0, y: isLandscape ? 0 : -10)
    }
    
    private var settingsHeader: some View {
        HStack {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isPresented = false
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.premiumCircleBackground)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("Settings")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            // Invisible spacer to balance
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, isLandscape ? 16 : 0)
        .padding(.bottom, 20)
    }
    
    private var settingsControls: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: isLandscape ? 3 : 4), spacing: 20) {
                SettingsGridItem(icon: "timer", title: "Sleep Timer", isActive: viewModel.isSleepTimerActive, action: onSleepTimer)
                SettingsGridItem(icon: "camera", title: "Screenshot", action: onScreenshot)
                SettingsGridItem(icon: "square.and.arrow.up", title: "Share", action: onShare)
                AirPlayGridItem(viewModel: viewModel, onDismiss: { isPresented = false })
            }
            .padding(.vertical, 16)
        }
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var portraitBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                settingsControls
                
                queueList
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }
    
    private var landscapeBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                settingsControls
                
                queueList
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }
    
    private var queueList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Section Header
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "list.bullet.rectangle.portrait.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    
                    Text("Queue")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: true, vertical: false)
                }
                
                Spacer()
                
                Button(action: onPlayingMode) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.playingMode.iconName)
                            .font(.system(size: 14, weight: .semibold))
                        Text(viewModel.playingMode.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(viewModel.playlist.enumerated()), id: \.element.id) { index, video in
                        VideoQueueRow(
                            video: video,
                            isCurrent: index == viewModel.currentIndex,
                            onTap: {
                                viewModel.selectFromQueue(at: index, forceAutoPlay: true)
                            }
                        )
                        .id(video.id)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    }
                    .onMove(perform: move)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: isLandscape ? 150 : 300)
                .environment(\.editMode, .constant(.active))
                .onAppear {
                    if let currentVideoId = viewModel.currentVideoItem?.id {
                        proxy.scrollTo(currentVideoId, anchor: .center)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func move(from source: IndexSet, to destination: Int) {
        viewModel.playlist.move(fromOffsets: source, toOffset: destination)
        if let currentVideoId = viewModel.currentVideoItem?.id {
            if let newIndex = viewModel.playlist.firstIndex(where: { $0.id == currentVideoId }) {
                viewModel.currentIndex = newIndex
            }
        }
    }
}

struct SettingsGridItem: View {
    let icon: String
    let title: String
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.orange.opacity(0.15) : Color.premiumCircleBackground)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isActive ? .orange : .white)
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isActive ? .orange : .white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct SettingsListItem: View {
    let icon: String
    let title: String
    let value: String
    var rightIcon: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
              
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if let rIcon = rightIcon {
                        Image(systemName: rIcon)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    
                    if icon != "infinity" {
                        Text(value)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

struct AirPlayGridItem: View {
    @ObservedObject var viewModel: PlayerViewModel
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.premiumCircleBackground)
                        .frame(width: 44, height: 44)
                
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text("AirPlay")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            
            SettingsAirPlayPicker()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(0.02)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onDismiss()
                        }
                    }
                )
        }
    }
}

struct SettingsAirPlayPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.activeTintColor = .white
        picker.tintColor = .clear
        picker.prioritizesVideoDevices = true
        return picker
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

struct VideoQueueRow: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    let video: VideoItem
    let isCurrent: Bool
    let onTap: () -> Void
    @State private var resolvedTitle: String? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack {
                if let asset = video.asset {
                    PHThumbnailView(asset: asset)
                        .frame(width: 80, height: 48)
                        .cornerRadius(6)
                } else if let path = video.thumbnailPath, let thumb = UIImage(contentsOfFile: path.path) {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 48)
                        .cornerRadius(6)
                        .clipped()
                } else if let url = video.url {
                    VideoThumbnailView(url: url)
                        .frame(width: 80, height: 48)
                        .cornerRadius(6)
                } else {
                    Color(red: 0.15, green: 0.15, blue: 0.15)
                        .frame(width: 80, height: 48)
                        .cornerRadius(6)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(resolvedTitle ?? video.title)
                    .font(.system(size: 14, weight: isCurrent ? .bold : .medium))
                    .foregroundColor(isCurrent ? Color(red: 1.0, green: 0.5, blue: 0.0) : .white)
                    .lineLimit(1)
                
                Text(video.formattedDuration)
                    .font(.system(size: 11))
                    .foregroundColor(isCurrent ? Color(red: 1.0, green: 0.5, blue: 0.0).opacity(0.8) : .gray)
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .onTapGesture(perform: onTap)
        .onAppear {
            if video.isGenericTitle {
                dashboardViewModel.loadTitle(for: video) { title in
                    self.resolvedTitle = title
                }
            }
        }
    }
}

struct PHThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 48)
                    .clipped()
            } else {
                Color(red: 0.15, green: 0.15, blue: 0.15)
            }
        }
        .onAppear {
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            
            manager.requestImage(for: asset, targetSize: CGSize(width: 160, height: 96), contentMode: .aspectFill, options: options) { img, _ in
                self.image = img
            }
        }
    }
}

struct VideoThumbnailView: View {
    let url: URL
    @State private var image: UIImage?
    @State private var vlcLoader: VLCThumbnailHelper?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.gray.opacity(0.3)
                    .overlay(
                        Image(systemName: "play.fill")
                            .foregroundColor(.white.opacity(0.3))
                            .font(.system(size: 14))
                    )
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }

    private func generateThumbnail() {
        let ext = url.pathExtension.lowercased()
        let vlcExtensions = ["mkv", "avi", "wmv", "flv", "webm", "3gp", "vob", "mpg", "mpeg", "ts", "m2ts", "divx", "asf"]
        
        if vlcExtensions.contains(ext) {
            let loader = VLCThumbnailHelper()
            self.vlcLoader = loader
            loader.generate(for: url) { image in
                self.image = image
                self.vlcLoader = nil
            }
            return
        }

        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, _, _ in
            if let image = image {
                DispatchQueue.main.async {
                    self.image = UIImage(cgImage: image)
                }
            }
        }
    }
}
