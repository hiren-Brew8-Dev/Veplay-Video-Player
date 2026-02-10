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
        viewModel.playingVideo == nil
    }
    
    var body: some View {
        ZStack {
            TabView(selection: $viewModel.selectedTab) {
                NavigationStack {
                    HomeView(viewModel: viewModel, paddingBottom: .constant(0))
                }
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)
                .toolbar(showTabBar ? .visible : .hidden, for: .tabBar)
                
                // Middle Dummy Tab for space
                Color.clear
                    .tabItem {
                        Label("", systemImage: "")
                    }
                    .tag(100)
                
                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(1)
                .toolbar(showTabBar ? .visible : .hidden, for: .tabBar)
            }
            .accentColor(.homeAccent)
            .toolbar(showTabBar ? .visible : .hidden, for: .tabBar)
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
            .ignoresSafeArea(.all, edges: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            if viewModel.isImporting {
                importingOverlay
            }
            
            if viewModel.showActionSheet {
                ZStack {
                    // Background Dimming
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            withAnimation {
                                viewModel.showActionSheet = false
                            }
                        }
                        .transition(.opacity)
                    
                    // Sheet Content
                    CustomActionSheet(
                        target: viewModel.actionSheetTarget,
                        items: viewModel.actionSheetItems,
                        isPresented: $viewModel.showActionSheet
                    )
                    .transition(.move(edge: .bottom))
                }
                .zIndex(200)
            }
            
            if showTabBar {
                PlusButtonOverlay(viewModel: viewModel)
            }
            
            if viewModel.showUnsupportedFormatAlert {
                UnsupportedFormatAlert(video: viewModel.unsupportedVideoForAlbum, isPresented: $viewModel.showUnsupportedFormatAlert)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: viewModel.showActionSheet)
        .environmentObject(viewModel)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .alert("Create New Folder", isPresented: $viewModel.showCreateFolderAlert) {
            TextField("Folder Name", text: $viewModel.newFolderName)
            Button("Cancel", role: .cancel) { viewModel.newFolderName = "" }
            Button("Create") {
                let name = viewModel.newFolderName
                if viewModel.createFolder(name: name) {
                    // Success case
                    viewModel.selectedTab = 0
                    viewModel.homeSelectedTab = "Folder"
                } else {
                    // Fail case (exists or error)
                    // If it was already there, the VM would have set alertMessage
                    // We still switch to Folder tab to show the highlight if it exists
                    if viewModel.folders.contains(where: { $0.name.lowercased() == name.lowercased() }) {
                        viewModel.selectedTab = 0
                        viewModel.homeSelectedTab = "Folder"
                        viewModel.showCreateFolderAlert = false
                    }
                }
            }
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
            allowedContentTypes: [.movie, .video],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task {
                    await viewModel.importVideos(from: urls)
                    await MainActor.run {
                        // Universal rule: Move to Video section after importing
                        viewModel.selectedTab = 0
                        viewModel.homeSelectedTab = "Video"
                    }
                }
            case .failure(let error):
                print("File import failed: \(error.localizedDescription)")
            }
        }
        .photosPicker(
            isPresented: $viewModel.showPhotoPicker,
            selection: $selectedPhotoItems,
            matching: .videos
        )
        .onChange(of: selectedPhotoItems) { oldItems, newItems in
            guard !newItems.isEmpty else { return }
            viewModel.isImporting = true
            Task {
                var importedURLs = [URL]()
                var importedNames = [String]()
                
                for item in newItems {
                    // Try to get original filename
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
                    // Universal rule: Move to Video section after importing
                    viewModel.selectedTab = 0
                    viewModel.homeSelectedTab = "Video"
                }
                
                await viewModel.importVideos(from: importedURLs, names: importedNames)
            }
        }
        .sheet(isPresented: $viewModel.showShareSheetGlobal) {
            if !viewModel.activityItems.isEmpty {
                ShareSheet(activityItems: viewModel.activityItems)
            } else if let url = viewModel.shareURL {
                ShareSheet(activityItems: [url])
            }
        }
        .overlay {
            if viewModel.isSharing {
                sharingOverlay
            }
        }
        .onChange(of: viewModel.playingVideo) { oldVideo, newVideo in
            if newVideo != nil {
                viewModel.isTabBarHidden = true
            } else {
                // Restore tab bar when video player is closed
                viewModel.isTabBarHidden = false
            }
        }
        .onChange(of: viewModel.selectedTab) { oldTab, newTab in
            // Ensure tab bar visibility
            if newTab == 0 {
                viewModel.isTabBarHidden = false
            } else if newTab == 100 {
                // If user somehow taps the blank middle tab, revert to previous
                viewModel.selectedTab = oldTab
            }
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
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.premiumCardBackground)
                    .background(.ultraThinMaterial)
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
            
            ZStack {
                // Orange Action Circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.homeAccent, Color.homeAccent.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.homeAccent.opacity(0.4), radius: 10, x: 0, y: 5)
                
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
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                    
                }
            }
            .padding(.bottom, -10) // Corrected for vertical centering with native icons
            .ignoresSafeArea(.keyboard)
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
