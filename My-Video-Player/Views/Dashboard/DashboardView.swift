import SwiftUI
import PhotosUI
import UIKit

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @State private var selectedPhotoItems = [PhotosPickerItem]()
    
    init() {
        // Configure system tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.homeBackground)
        
        // Hide top line
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    private var showTabBar: Bool {
        !viewModel.isSelectionMode &&
        !viewModel.isHeaderExpanded &&
        !viewModel.isTabBarHidden &&
        !viewModel.showActionSheet &&
        viewModel.playingVideo == nil &&
        viewModel.navigationPath.isEmpty
    }
    

    var body: some View {
        ZStack {
            TabView(selection: $viewModel.selectedTab) {
                // MARK: Home
                Tab("Home", systemImage: "house", value: .home) {
                    NavigationStack(path: $viewModel.navigationPath) {
                        VStack(spacing: 0) {
                            if !viewModel.isSelectionMode {
                                headerView
                            }
                            VideoSectionView(viewModel: viewModel, paddingBottom: .constant(0))
                        }
                        .background(Color.homeBackground)
                        .navigationBarHidden(true)
                        .toolbar(showTabBar ? .visible : .hidden, for: .tabBar)
                        .navigationDestination(for: DashboardViewModel.NavigationDestination.self) { destination in
                            destinationView(for: destination)
                                .toolbar(.hidden, for: .tabBar)
                        }
                        .navigationDestination(for: String.self) { value in
                            if value == "Settings" {
                                SettingsView()
                                    .toolbar(.hidden, for: .tabBar)
                                    .navigationBarHidden(true)
                            }
                        }
                    }
                }
                
                // MARK: Gallery
                Tab("Gallery", systemImage: "photo.on.rectangle", value: .gallery) {
                    NavigationStack(path: $viewModel.navigationPath) {
                        VStack(spacing: 0) {
                            if !viewModel.isSelectionMode {
                                headerView
                            }
                            AlbumSectionView(viewModel: viewModel)
                        }
                        .background(Color.homeBackground)
                        .navigationBarHidden(true)
                        .toolbar(showTabBar ? .visible : .hidden, for: .tabBar)
                        .navigationDestination(for: DashboardViewModel.NavigationDestination.self) { destination in
                            destinationView(for: destination)
                                .toolbar(.hidden, for: .tabBar)
                        }
                        .navigationDestination(for: String.self) { value in
                            if value == "Settings" {
                                SettingsView()
                                    .toolbar(.hidden, for: .tabBar)
                                    .navigationBarHidden(true)
                            }
                        }
                    }
                }
                
                // MARK: Search
                Tab(value: .search, role: .search) {
                    NavigationStack {
                        SearchView(viewModel: viewModel)
                            .toolbar(showTabBar ? .visible : .hidden, for: .tabBar)
                    }
                }
            }
            .accentColor(.homeAccent)
            // .toolbar modifier removed from here
            
            if showTabBar && viewModel.selectedTab == .home {
                PlusButtonOverlay(viewModel: viewModel)
            }
            
            // Global Overlays (Keep as is)
            if viewModel.isImporting {
                importingOverlay
            }
            
            if viewModel.showActionSheet {
                actionSheetOverlay
            }
            
            if viewModel.showUnsupportedFormatAlert {
                UnsupportedFormatAlert(video: viewModel.unsupportedVideoForAlbum, isPresented: $viewModel.showUnsupportedFormatAlert)
            }
        }
        .background(Color.homeBackground.ignoresSafeArea())
        .ignoresSafeArea(edges: .bottom)
        .fullScreenCover(item: $viewModel.playingVideo) { video in
            PlayerView(
                video: video,
                playlist: viewModel.currentPlaylist,
                onPlaybackEnded: {
                    viewModel.playingVideo = nil
                }
            )
            .environmentObject(viewModel)
        }
        
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: viewModel.showActionSheet)
        .environmentObject(viewModel)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onOpenURL { url in
            viewModel.importVideo(from: url, autoPlay: true)
        }
        .alert("Create New Folder", isPresented: $viewModel.showCreateFolderAlert) {
            folderAlertContent
        } message: {
            Text("Enter a name for the new folder")
        }
        .alert("Folder Error", isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        .sheet(isPresented: $viewModel.showMovePicker) {
            MoveDestinationPickerView(viewModel: viewModel, videosToMove: viewModel.videosToMove, isCutOperation: viewModel.isCutMode)
        }
        .fileImporter(
            isPresented: $viewModel.showFileImporter,
            allowedContentTypes: [.movie, .video, .quickTimeMovie, .mpeg4Movie, .mpeg, .avi, .item],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .photosPicker(
            isPresented: $viewModel.showPhotoPicker,
            selection: $selectedPhotoItems,
            matching: .videos
        )
        .onChange(of: selectedPhotoItems) { oldItems, newItems in
            handlePhotoImport(newItems)
        }
        .sheet(isPresented: $viewModel.showShareSheetGlobal) {
            shareSheetContent
        }
        .overlay {
            if viewModel.isSharing {
                sharingOverlay
            }
        }
        .onChange(of: viewModel.playingVideo) { oldVideo, newVideo in
            viewModel.isTabBarHidden = (newVideo != nil)
        }
        .sheet(isPresented: $viewModel.showSortSheet) {
            CustomSortingView(sortOptionRaw: $viewModel.videoSortOptionRaw, title: "Videos")
        }
    }

    @ViewBuilder
    private func destinationView(for destination: DashboardViewModel.NavigationDestination) -> some View {
        switch destination {
        case .allFolders:
            FolderSectionView(viewModel: viewModel)
        case .folderDetail(let folder):
            FolderDetailView(initialFolder: folder, viewModel: viewModel)
        case .search(let title, let videos):
            SearchView(viewModel: viewModel, contextTitle: title, initialVideos: videos)
        }
    }

    private var headerView: some View {
        HStack(spacing: 0) {
            // Logo & Title
            HStack(spacing: AppDesign.Icons.internalSpacing) {
                Image(systemName: "play.circle.fill")
                    .appIconStyle(size: AppDesign.Icons.headerSize)
                Text("PLAYER")
                    .font(.system(size: AppDesign.Icons.headerSize, weight: .bold))
                    .foregroundColor(.homeTextPrimary)
            }
            .padding(.leading, AppDesign.Icons.horizontalPadding)
            
            Spacer()
            
            HStack(spacing: isIpad ? 20 : 12) {
                // Settings Button (Trailing, before 3-dots)
                Button(action: {
                    viewModel.navigationPath.append("Settings")
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.premiumCircleBackground)
                            .frame(width: AppDesign.Icons.circleButtonSize, height: AppDesign.Icons.circleButtonSize)
                        
                        Image(systemName: "gearshape")
                            .font(.system(size: isIpad ? 22 : 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Ellipsis Menu (Shown only on Home/Video for now)
                if viewModel.selectedTab == .home {
                    Menu {
                        Button(action: { 
                            withAnimation { viewModel.isSelectionMode = true }
                        }) {
                            Label("Select", systemImage: "checkmark.circle")
                        }
                        
                        Divider()
                        
                        Picker(selection: Binding(
                            get: { viewModel.isGridView },
                            set: { viewModel.isGridView = $0 }
                        ), label: EmptyView()) {
                            Label("Grid", systemImage: "square.grid.2x2").tag(true)
                            Label("List", systemImage: "list.bullet").tag(false)
                        }
                        .pickerStyle(.inline)
                        
                        Divider()
                        
                        Button(action: { 
                            withAnimation {
                                viewModel.showSortSheet = true 
                            }
                        }) {
                            Label("Sort by", systemImage: "arrow.up.arrow.down")
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.premiumCircleBackground)
                                .frame(width: AppDesign.Icons.circleButtonSize, height: AppDesign.Icons.circleButtonSize)
                            
                            Image(systemName: "ellipsis")
                                .rotationEffect(.degrees(90))
                                .font(.system(size: isIpad ? 22 : 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(.trailing, AppDesign.Icons.horizontalPadding)
        }
        .frame(height: AppDesign.Icons.headerHeight)
        .padding(.vertical, 8)
        .background(Color.homeBackground.ignoresSafeArea())
    }

    private var actionSheetOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation {
                        viewModel.showActionSheet = false
                    }
                }
                .transition(.opacity)
            
            CustomActionSheet(
                target: viewModel.actionSheetTarget,
                items: viewModel.actionSheetItems,
                isPresented: $viewModel.showActionSheet
            )
            .iPad { view in
                view.frame(maxWidth: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(radius: 20)
            }
            .transition(isIpad ? .scale.combined(with: .opacity) : .move(edge: .bottom))
        }
        .zIndex(200)
    }

    @ViewBuilder
    private var folderAlertContent: some View {
        TextField("Folder Name", text: $viewModel.newFolderName)
        Button("Cancel", role: .cancel) { viewModel.newFolderName = "" }
        Button("Create") {
            let name = viewModel.newFolderName
            if viewModel.createFolder(name: name) {
                viewModel.selectedTab = .home
                viewModel.homeSelectedTab = "Video"
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                await viewModel.importVideos(from: urls)
                await MainActor.run {
                    viewModel.selectedTab = .home
                    viewModel.homeSelectedTab = "Video"
                }
            }
        case .failure(let error):
            print("File import failed: \(error.localizedDescription)")
        }
    }

    private func handlePhotoImport(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        viewModel.isImporting = true
        Task {
            var importedURLs = [URL]()
            var importedNames = [String]()
            for item in items {
                var fileName: String?
                if let localID = item.itemIdentifier {
                    let result = PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil)
                    if let asset = result.firstObject {
                        let resources = PHAssetResource.assetResources(for: asset)
                        fileName = resources.first?.originalFilename
                    }
                }
                if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                    importedURLs.append(movie.url)
                    importedNames.append(fileName ?? movie.url.lastPathComponent)
                }
            }
            await MainActor.run {
                selectedPhotoItems.removeAll()
                viewModel.selectedTab = .home
                viewModel.homeSelectedTab = "Video"
            }
            await viewModel.importVideos(from: importedURLs, names: importedNames)
        }
    }

    @ViewBuilder
    private var shareSheetContent: some View {
        if !viewModel.activityItems.isEmpty {
            ShareSheet(activityItems: viewModel.activityItems)
        } else if let url = viewModel.shareURL {
            ShareSheet(activityItems: [url])
        }
    
    }
    
    private var sharingOverlay: some View {
        ZStack {
            Color.homeBackground.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // Animated Loader (Custom)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                VStack(spacing: 8) {
                    Text("Sharing...")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("Preparing your files")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 40)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.premiumGradientBottom.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.premiumCardBorder, lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 30, x: 0, y: 15)
        }
    }
    
    private var importingOverlay: some View {
        ZStack {
            Color.homeBackground.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.3)
                
                Text("Syncing...")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 30)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.premiumCardBackground.opacity(0.7))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.premiumCardBorder, lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .zIndex(100)
    }
}

struct PlusButtonOverlay: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                ZStack {
                    // Static Background (No Glitch)
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                        
                        Circle()
                            .fill(Color.white.opacity(0.05))
                    }
                    .frame(width: isIpad ? 80 : 56, height: isIpad ? 80 : 56)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: isIpad ? 15 : 10, x: 0, y: 5)
                    
                    // Interactive Menu (Overlay)
                    Menu {
                        Button(action: { viewModel.showCreateFolderAlert = true }) {
                            Label("Create Folder", systemImage: "folder.badge.plus")
                        }
                        Button(action: { viewModel.showPhotoPicker = true }) {
                            Label("Import from Photos", systemImage: "photo.on.rectangle")
                        }
                        Button(action: { viewModel.showFileImporter = true }) {
                            Label("Add From iOS Files", systemImage: "plus.rectangle.on.folder")
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.clear)
                                .contentShape(Circle())
                            
                            Image(systemName: "plus")
                                .font(.system(size: isIpad ? 36 : 24, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(width: isIpad ? 80 : 56, height: isIpad ? 80 : 56)
                    }
                }
            }
            .padding(.trailing, AppDesign.Icons.horizontalPadding + (isIpad ? 16 : 0))
            .padding(.bottom, (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) + (isIpad ? 100 : 60))
            .ignoresSafeArea(.keyboard)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
