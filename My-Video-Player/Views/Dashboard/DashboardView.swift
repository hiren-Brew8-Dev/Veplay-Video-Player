import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct DashboardView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.scenePhase) var scenePhase
    @AppStorage("isDarkMode") private var isDarkMode = true
    @EnvironmentObject var navigationManager: NavigationManager
    
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
        viewModel.playingVideo == nil
    }
    
    var body: some View {
        ZStack {
            TabView(selection: $viewModel.selectedTab) {
                Tab("Videos", systemImage: "play.circle", value: DashboardViewModel.MainTabs.home) {
                    homeTabContent
                }
                
                Tab("Gallery", systemImage: "photo.on.rectangle", value: DashboardViewModel.MainTabs.gallery) {
                    galleryTabContent
                }
                
                Tab("Folders", systemImage: "folder", value: DashboardViewModel.MainTabs.folders) {
                    foldersTabContent
                }
                
                Tab(value: DashboardViewModel.MainTabs.search, role: .search) {
                    searchTabContent
                }
            }
            .accentColor(.homeAccent)
            .background(Color.clear)
            .onChange(of: viewModel.selectedTab) { _, newTab in
                handleTabChange(to: newTab)
            }
            
            tabOverlays
        }
        .ignoresSafeArea(edges: .bottom)
        .fullScreenCover(item: $viewModel.playingVideo) { video in
            playerView(for: video)
        }
        .fullScreenCover(item: $navigationManager.fullScreenDestination) { destination in
            fullScreenView(for: destination)
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
        .onAppear {
            viewModel.loadData()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.fetchAlbums()
                viewModel.fetchAssets()
            }
        }
    }

    // MARK: - Subviews & Helpers

    /// handleTabChange
    /// - Description: Called when the user taps a tab. Triggers lightweight data refreshes only when needed.
    /// - How to use: Bound to .onChange(of: viewModel.selectedTab).
    private func handleTabChange(to newTab: DashboardViewModel.MainTabs) {
        HapticsManager.shared.selectionVibrate()
        navigationManager.currentTab = newTab
        
        // Proactive refresh when entering specific tabs.
        // fetchAlbums() is lightweight (album list only) — safe to call on every gallery visit.
        // fetchAssets() is heavy (PHAsset enumeration over entire library) — only call when not yet loaded
        // to avoid freezing the UI on every tab-switch back to Videos.
        if newTab == .gallery {
            viewModel.fetchAlbums()
        } else if newTab == .home && viewModel.allGalleryVideos.isEmpty {
            viewModel.fetchAssets()
        }
    }

    @ViewBuilder
    private var tabOverlays: some View {
        if showTabBar && (viewModel.selectedTab == .home || viewModel.selectedTab == .folders) {
            PlusButtonOverlay(viewModel: viewModel)
        }
        
        if viewModel.showUnsupportedFormatAlert {
            UnsupportedFormatAlert(video: viewModel.unsupportedVideoForAlbum, isPresented: $viewModel.showUnsupportedFormatAlert)
        }
        
        if viewModel.showConflictResolution {
            ConflictResolutionOverlay(viewModel: viewModel)
                .zIndex(1000)
        }
    }

    @ViewBuilder
    private func playerView(for video: VideoItem) -> some View {
        PlayerView(
            video: video,
            playlist: viewModel.currentPlaylist,
            onPlaybackEnded: {
                viewModel.playingVideo = nil
            }
        )
        .environmentObject(viewModel)
    }

    // MARK: - Tab Contents
    
    @ViewBuilder
    private var homeTabContent: some View {
        NavigationStack(path: $navigationManager.homePath) {
            VStack(spacing: 0) {
                VideoSectionView(viewModel: viewModel, paddingBottom: .constant(0))
                    .ignoresSafeArea(edges: .top)
                    .background {
                        AppGlobalBackground()
                            .allowsHitTesting(false)
                    }
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
        }
        .toolbar(showTabBar ? .visible : .hidden, for: .tabBar)
    }
    
    @ViewBuilder
    private var galleryTabContent: some View {
        NavigationStack(path: $navigationManager.galleryPath) {
            VStack(spacing: 0) {
                AlbumSectionView(viewModel: viewModel)
                    .ignoresSafeArea(edges: .top)
                    .background {
                        AppGlobalBackground()
                            .allowsHitTesting(false)
                    }
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
        }
        .toolbar(showTabBar ? .visible : .hidden, for: .tabBar)
    }
    
    @ViewBuilder
    private var foldersTabContent: some View {
        NavigationStack(path: $navigationManager.foldersPath) {
            VStack(spacing: 0) {
                FolderSectionView(viewModel: viewModel)
                    .ignoresSafeArea(edges: .top)
                    .background {
                        AppGlobalBackground()
                            .allowsHitTesting(false)
                    }
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
        }
        .toolbar(showTabBar ? .visible : .hidden, for: .tabBar)
    }
    
    @ViewBuilder
    private var searchTabContent: some View {
        NavigationStack(path: $navigationManager.searchPath) {
            SearchView(viewModel: viewModel)
                .navigationDestination(for: NavigationDestination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .toolbar(showTabBar ? .visible : .hidden, for: .tabBar)
    }

    @ViewBuilder
    private func fullScreenView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .settings:
            SettingsView()
                .environmentObject(viewModel)
        case .paywall(let isFromOnboarding):
            PaywallView(isFromOnboarding: isFromOnboarding)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .allFolders:
            FolderSectionView(viewModel: viewModel)
        case .folderDetail(let folder):
            FolderDetailView(initialFolder: folder, viewModel: viewModel)
        case .search(let title, let videos):
            SearchView(viewModel: viewModel, contextTitle: title, initialVideos: videos)
        case .rating:
            RatingView()
        default:
            EmptyView()
        }
    }

    private var headerView: some View {
        headerView(title: "Videos")
    }

    private func headerView(title: String) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(title)
                    .font(.system(size: AppDesign.Icons.headerSize + 4, weight: .bold))
                    .foregroundColor(.homeTextPrimary)
            }
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
        .padding(.vertical, 8)
        .background(Color.clear)
    }

    @ViewBuilder
    private var folderAlertContent: some View {
        TextField("Folder Name", text: $viewModel.newFolderName)
        Button("Cancel", role: .cancel) {
            HapticsManager.shared.generate(.medium)
            viewModel.newFolderName = ""
        }
        Button("Create") {
            HapticsManager.shared.generate(.success)
            let name = viewModel.newFolderName
            if viewModel.createFolder(name: name) {
                // Stay in current tab
            }
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
}

private struct PlusButtonOverlay: View {
    @ObservedObject var viewModel: DashboardViewModel
    @EnvironmentObject var navigationManager: NavigationManager
    var isIpad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                ZStack {
                    if viewModel.selectedTab == .folders && navigationManager.foldersPath.isEmpty {
                        Button(action: { 
                            HapticsManager.shared.generate(.medium)
                            viewModel.showCreateFolderAlert = true 
                        }) {
                            plusButtonLabel
                        }
                        .glassProminentButtonStyle()
                        .buttonBorderShape(.circle)
                        .adaptiveButtonSizing(isFitted: true)
                        .tint(Color.homeAccent)
                    } else {
                        Menu {
                            Button(action: {
                                HapticsManager.shared.generate(.selection)
                                viewModel.showPhotoPicker = true
                            }) {
                                Label("Import from Photos", systemImage: "photo.on.rectangle")
                            }
                            Button(action: {
                                HapticsManager.shared.generate(.selection)
                                viewModel.showFileImporter = true
                            }) {
                                Label("Add From iOS Files", systemImage: "plus.rectangle.on.folder")
                            }
                        } label: {
                            plusButtonLabel
                        }
                        .glassProminentButtonStyle()
                        .buttonBorderShape(.circle)
                        .adaptiveButtonSizing(isFitted: true)
                        .tint(Color.homeAccent)
                    }
                }
            }
            .padding(.trailing, 22 + (isIpad ? 16 : 0))
            .padding(.bottom, (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) + (isIpad ? 80 : 60))
            .ignoresSafeArea(.keyboard)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private var plusButtonLabel: some View {
        ZStack {
            Image(systemName: "plus")
                .font(.system(size: isIpad ? 28 : 24, weight: .bold))
                .foregroundColor(.black)
        }
        .frame(width: isIpad ? 65 : 45, height: isIpad ? 65 : 45)
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

#Preview {
    DashboardView()
        .environmentObject(DashboardViewModel())
        .environmentObject(NavigationManager())
}
