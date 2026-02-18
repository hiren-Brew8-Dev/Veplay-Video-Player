import SwiftUI
import Photos

struct AlbumSectionView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @EnvironmentObject var navigationManager: NavigationManager
    
    @State private var showSearch = false
    
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let currentWidth = geometry.size.width
            let safeAreaTop = geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 47)

            ZStack {
                if viewModel.galleryAlbums.isEmpty {
                    VStack(spacing: 0) {
                        Spacer()
                        emptyStateView
                            .responsivePadding(edge: .top, fraction: 0)
                        Spacer()
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: GridLayout.gridColumns(isLandscape: isLandscape), spacing: GridLayout.spacing(isLandscape: isLandscape)) {
                            ForEach(viewModel.galleryAlbums, id: \.localIdentifier) { album in
                                let folder = Folder(name: albumDestinationTitle(for: album), videoCount: album.estimatedAssetCount, videos: [], url: nil, albumIdentifier: album.localIdentifier, subfolders: [])
                                Button(action: {
                                    HapticsManager.shared.generate(.light)
                                    navigationManager.push(.folderDetail(folder))
                                }) {
                                    let count = viewModel.albumAssetCounts[album.localIdentifier] ?? 0
                                    AlbumCardView(album: album, isLandscape: isLandscape, availableWidth: currentWidth, videoCountPreload: count, refreshTrigger: viewModel.lastGalleryUpdate)
                                }
                                .buttonStyle(.scalable)
                            }
                        }
                        .padding(.horizontal, GridLayout.horizontalPadding)
                        .padding(.top, 20)
                        .padding(.bottom, 100)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .safeAreaInset(edge: .top) {
                mainHeader
                    .padding(.top, safeAreaTop)
                    .background(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .black, location: 0.0),
                                .init(color: .black.opacity(0.8), location: 0.8),
                                .init(color: .black.opacity(0), location: 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .top)
                    )
            }
            .onAppear {
                viewModel.fetchAlbums()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.clear)
    }
    
    private var mainHeader: some View {
        HStack(spacing: 0) {
            Text("Gallery")
                .font(.system(size: AppDesign.Icons.headerSize + 4, weight: .bold))
                .foregroundColor(.white)
                .padding(.leading, AppDesign.Icons.horizontalPadding)
            
            Spacer()
            
            HStack(spacing: isIpad ? 20 : 5) {
                Button(action: {
                    HapticsManager.shared.generate(.medium)
                    navigationManager.push(.settings)
                }) {
                    ZStack {
                        Image(systemName: "gearshape")
                            .font(.system(size: isIpad ? 22 : 18, weight: .medium))
                            .frame(width: 30, height: 30)
                    }
                }
                .glassButtonStyle()
                .buttonBorderShape(.circle)
                
                if !Global.shared.getIsUserPro() {
                    Button {
                        HapticsManager.shared.generate(.medium)
                        navigationManager.push(.paywall(isFromOnboarding: false))
                    } label: {
                        ZStack {
                            Image(systemName: "crown.fill")
                                .font(.system(size: isIpad ? 20 : 18, weight: .medium))
                                .foregroundColor(.black)
                                .frame(width: 30, height: 30)
                        }
                    }
                    .adaptiveButtonSizing()
                    .glassProminentButtonStyle()
                    .buttonBorderShape(.circle)
                    .tint(.premiumIconBackground)
                }
            }
            .padding(.trailing, AppDesign.Icons.horizontalPadding)
        }
        .frame(height: AppDesign.Icons.headerHeight)
        .padding(.vertical, 10)
        
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 100, height: 100)
                
                Image(systemName: viewModel.showPermissionDenied ? "photo.on.rectangle.angled" : "video.slash")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.2))
            }
            
            VStack(spacing: 12) {
                Text(viewModel.showPermissionDenied ? "No Gallery Access" : "No Video Albums Found")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text(viewModel.showPermissionDenied ?
                     "Grant photo access in settings to view\nyour device's video albums." :
                        "We couldn't find any video albums in your\nPhotos library.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            }
            .padding(.horizontal, 40)
            
            if viewModel.showPermissionDenied {
                Button(action: {
                    HapticsManager.shared.generate(.medium)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Open Settings")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.homeAccent, Color.homeAccent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(30)
                }
                .buttonStyle(.scalable)
                .padding(.top, 8)
            }
        }
    }
    
    private func albumDestinationTitle(for album: PHAssetCollection) -> String {
        let displayTitle = (album.localizedTitle ?? "Gallery") == "Videos" ? "All Videos" : (album.localizedTitle ?? "Gallery")
        return displayTitle
    }
}

struct AlbumCardView: View {
    let album: PHAssetCollection
    let isLandscape: Bool
    let availableWidth: CGFloat

    @State private var thumbnail: UIImage?
    @State private var videoCount: Int = 0
    let videoCountPreload: Int
    let refreshTrigger: Date

    var body: some View {
        let size = GridLayout.itemSize(for: availableWidth, isLandscape: isLandscape)
        
        ZStack(alignment: .bottom) {
            // 1. Thumbnail Background
            if let image = thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size * 1.1)
                    .clipped()
            } else {
                ZStack {
                    Color.premiumCardBackground
                    Image(systemName: "photo.on.rectangle.angled")
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
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(albumTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                    
                    Text("\(videoCount) Videos")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
        .frame(width: size, height: size * 1.1)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            fetchAlbumInfo()
        }
        .onChange(of: refreshTrigger) { _, _ in
            fetchAlbumInfo()
        }
    }

    private var albumTitle: String {
        let title = album.localizedTitle ?? "Album"
        return title == "Videos" ? "All Videos" : title
    }

    private func fetchAlbumInfo() {
        // Use preloaded count if available
        if self.videoCount != videoCountPreload {
            self.videoCount = videoCountPreload
        }
        
        // Fetch first asset for thumbnail only
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType = %d",
            PHAssetMediaType.video.rawValue
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1

        let assets = PHAsset.fetchAssets(in: album, options: options)

        if let firstAsset = assets.firstObject {
            let manager = PHImageManager.default()
            let requestOptions = PHImageRequestOptions()
            requestOptions.deliveryMode = .opportunistic
            requestOptions.isNetworkAccessAllowed = true
            requestOptions.version = .current

            // Calculate exact size based on display size and screen scale
            let size = GridLayout.itemSize(for: availableWidth, isLandscape: isLandscape)
            let padding: CGFloat = 8
            let thumbnailSize = size - (padding * 2)
            let pixelSize = thumbnailSize * UIScreen.main.scale
            
            manager.requestImage(
                for: firstAsset,
                targetSize: CGSize(width: pixelSize, height: pixelSize),
                contentMode: .aspectFill,
                options: requestOptions
            ) { image, _ in
                if let image = image {
                    thumbnail = image
                }
            }
        }
    }
}
