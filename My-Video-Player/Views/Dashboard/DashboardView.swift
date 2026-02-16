import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct DashboardView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
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
        viewModel.playingVideo == nil &&
        viewModel.navigationPath.isEmpty
    }
    

    var body: some View {
        ZStack {
            TabView(selection: $viewModel.selectedTab) {
                // MARK: Home (Videos)
                Tab("Videos", systemImage: "play.circle", value: .home) {
                    VStack(spacing: 0) {
                        if !viewModel.isSelectionMode {
                            headerView(title: "Videos")
                        }
                        VideoSectionView(viewModel: viewModel, paddingBottom: .constant(0))
                    }
                    .toolbar(showTabBar ? .visible : .hidden, for: .tabBar)
                }
                
                // MARK: Gallery
                Tab("Gallery", systemImage: "photo.on.rectangle", value: .gallery) {
                    VStack(spacing: 0) {
                        if !viewModel.isSelectionMode {
                            headerView(title: "Gallery")
                        }
                        AlbumSectionView(viewModel: viewModel)
                    }
                    .toolbar(showTabBar ? .visible : .hidden, for: .tabBar)
                }

                // MARK: Folders
                Tab("Folders", systemImage: "folder", value: .folders) {
                    VStack(spacing: 0) {
                         if !viewModel.isSelectionMode {
                            headerView(title: "Folders")
                        }
                        FolderSectionView(viewModel: viewModel)
                    }
                    .toolbar(showTabBar ? .visible : .hidden, for: .tabBar)
                }
                
                // MARK: Search
                Tab(value: .search, role: .search) {
                    SearchView(viewModel: viewModel)
                        .toolbar(showTabBar ? .visible : .hidden, for: .tabBar)
                }
            }
            .accentColor(.homeAccent)
            
            if showTabBar && (viewModel.selectedTab == .home || viewModel.selectedTab == .folders) {
                PlusButtonOverlay(viewModel: viewModel)
            }
            

            
            if viewModel.showUnsupportedFormatAlert {
                UnsupportedFormatAlert(video: viewModel.unsupportedVideoForAlbum, isPresented: $viewModel.showUnsupportedFormatAlert)
            }
        }
        .background(AppGlobalBackground())
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
        headerView(title: "Videos")
    }

    private func headerView(title: String) -> some View {
        HStack(spacing: 0) {
            // Title Only (No Icon)
            HStack(spacing: 0) {
                Text(title)
                    .font(.system(size: AppDesign.Icons.headerSize + 4, weight: .bold)) // Slightly larger text
                    .foregroundColor(.homeTextPrimary)
            }
            .padding(.leading, AppDesign.Icons.horizontalPadding)
            
            Spacer()
            
            HStack(spacing: isIpad ? 20 : 16) {
                // Settings Button (Trailing, before 3-dots)
                Button(action: {
                    navigationManager.push(.settings)
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
                
                if !Global.shared.getIsUserPro() {
                    Button {
                        navigationManager.push(.paywall(isFromOnboarding: false))
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.premiumIconBackground)
                                .frame(width: AppDesign.Icons.circleButtonSize, height: AppDesign.Icons.circleButtonSize)
                            
                            Image(systemName: "crown.fill")
                                .font(.system(size: isIpad ? 20 : 14, weight: .bold))
                                .foregroundColor(.black)
                            
                        }
                    }
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
        Button("Cancel", role: .cancel) { viewModel.newFolderName = "" }
        Button("Create") {
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
}

private struct PlusButtonOverlay: View {
    @ObservedObject var viewModel: DashboardViewModel
    var isIpad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                ZStack {
                    // Interactive Menu or Direct Button
                    if viewModel.selectedTab == .folders {
                        // Direct Button for Folders
                        Button(action: { 
                            viewModel.showCreateFolderAlert = true 
                        }) {
                            plusButtonLabel
                        }
                    } else {
                        // Menu for Videos (Home)
                        Menu {
                            Button(action: { viewModel.showPhotoPicker = true }) {
                                Label("Import from Photos", systemImage: "photo.on.rectangle")
                            }
                            Button(action: { viewModel.showFileImporter = true }) {
                                Label("Add From iOS Files", systemImage: "plus.rectangle.on.folder")
                            }
                        } label: {
                            plusButtonLabel
                        }
                    }
                }
            }
            .padding(.trailing, 22 + (isIpad ? 16 : 0)) // Increased from 16 to 22 for visual center over Search icon
            .padding(.bottom, (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) + (isIpad ? 80 : 60))
            .ignoresSafeArea(.keyboard)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private var plusButtonLabel: some View {
        ZStack {
            Circle()
                .fill(Color.homeAccent)
                .contentShape(Circle())
            
            Image(systemName: "plus")
                .font(.system(size: isIpad ? 28 : 24, weight: .bold))
                .foregroundColor(.black)
        }
        .frame(width: isIpad ? 72 : 64, height: isIpad ? 72 : 64)
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
