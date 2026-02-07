import SwiftUI
import Photos

struct PhotoAlbumDetailView: View {
    let album: PHAssetCollection
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: DashboardViewModel
    @State private var assets: [PHAsset] = []
    @State private var isLoading = true
    
    let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 2)
    ]
    
    var body: some View {
        ZStack {
            Color.homeBackground.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                StandardIconButton(icon: "chevron.left", action: {
                    presentationMode.wrappedValue.dismiss()
                })
                    
                    Spacer()
                    
                    Text(album.localizedTitle ?? "Album")
                        .font(.headline)
                        .foregroundColor(.homeTextPrimary)
                    
                    Spacer()
                    
                    // Invisible spacer for alignment
                    Spacer().frame(width: 44)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(Color.homeBackground)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if assets.isEmpty {
                     Spacer()
                     Text("No videos in this album")
                         .foregroundColor(.homeTextSecondary)
                     Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(assets, id: \.localIdentifier) { asset in
                                Button(action: {
                                    viewModel.playingVideo = viewModel.videoItem(from: asset)
                                }) {
                                    GeometryReader { geo in
                                        PhotoAssetItem(asset: asset)
                                            .frame(width: geo.size.width, height: geo.size.width) // Square
                                            .clipped()
                                    }
                                }
                                .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.isTabBarHidden = true
            fetchAssets()
        }
        .onDisappear {
            viewModel.isTabBarHidden = false
        }
    }
    
    private func fetchAssets() {
        DispatchQueue.global(qos: .userInitiated).async {
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let result = PHAsset.fetchAssets(in: self.album, options: fetchOptions)
            var fetchedAssets: [PHAsset] = []
            result.enumerateObjects { asset, _, _ in
                fetchedAssets.append(asset)
            }
            
            DispatchQueue.main.async {
                self.assets = fetchedAssets
                self.isLoading = false
            }
        }
    }
}

struct PhotoAssetItem: View {
    let asset: PHAsset
    @EnvironmentObject var viewModel: DashboardViewModel
    @State private var image: UIImage?
    @State private var durationString: String = ""
    @State private var title: String = ""
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            GeometryReader { geo in
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.homeCardBackground)
                }
            }
            
            // Bottom Info Overlay
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                
                HStack(alignment: .bottom) {
                    if !title.isEmpty && title != VideoItem.titlePlaceholder {
                        Text(title)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.homeTextPrimary)
                            .lineLimit(1)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.homeBackground.opacity(0.4))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Text(durationString)
                        .font(.caption2)
                        .foregroundColor(.homeTextPrimary)
                        .padding(4)
                        .background(Color.homeBackground.opacity(0.6))
                        .cornerRadius(4)
                }
                .padding(4)
            }
        }
        .onAppear {
            loadImage()
            formatDuration()
            resolveTitle()
        }
    }
    
    private func resolveTitle() {
        // Use the common background resolution logic in DashboardViewModel
        let video = viewModel.videoItem(from: asset)
        viewModel.loadTitle(for: video) { resolvedTitle in
            // Show whatever title we resolved, even if it's "IMG_1234" (as requested by user)
            self.title = resolvedTitle
        }
    }
    
    private func loadImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        
        manager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: options) { result, _ in
            if let result = result {
                self.image = result
            }
        }
    }
    
    private func formatDuration() {
        let duration = asset.duration
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        self.durationString = formatter.string(from: duration) ?? ""
    }
}
