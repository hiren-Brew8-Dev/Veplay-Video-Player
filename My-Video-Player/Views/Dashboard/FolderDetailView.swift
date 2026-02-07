import Photos
import SwiftUI

struct FolderDetailView: View {
    let initialFolder: Folder
    @ObservedObject var viewModel: DashboardViewModel
    
    var folder: Folder {
        // Resolve from viewModel to ensure UI updates after imports/changes
        // Try ID first, then URL (since scanFolder generates new IDs on refresh)
        if let updated = viewModel.findFolder(byId: initialFolder.id) {
            return updated
        }
        if let url = initialFolder.url, let updatedByURL = viewModel.findFolder(byURL: url) {
            return updatedByURL
        }
        return initialFolder
    }
    @Environment(\.presentationMode) var presentationMode
    
    // States
    @AppStorage("isGridView") private var isGridView: Bool = true
    @State private var showSortSheet: Bool = false
    
    @State private var videoToMove: VideoItem?
    @State private var videoToRename: VideoItem?
    @State private var videoToDelete: VideoItem?
    @State private var folderToRename: Folder?
    @State private var showRenameVideoAlert = false
    @State private var showDeleteVideoAlert = false
    @State private var showRenameFolderAlert = false
    @State private var newVideoName = ""
    @State private var newFolderName = ""
    
    // Selection State
    @State private var selectedVideoIds = Set<UUID>()
    @State private var animatedVideoIds: Set<UUID> = []
    
    @State private var showActionSheet = false
    @State private var activeActionItem: ActionTarget?
    @State private var showSearch = false
    @State private var showImportOptions = false
    @State private var asyncVideos: [VideoItem] = []
    @State private var isLoading = false
    
    enum ActionTarget {
        case folder(Folder)
        case video(VideoItem)
    }
    
    // Derived
    var sortOption: DashboardViewModel.SortOption {
        if folder.url == nil {
            return viewModel.gallerySortOption
        }
        return viewModel.folderSortOption
    }
    
    var sortedVideos: [VideoItem] {
        let sourceVideos = (folder.videos.isEmpty && !asyncVideos.isEmpty) ? asyncVideos : folder.videos
        let sorted = sourceVideos.sorted {
            switch sortOption {
            case .dateDesc: return $0.creationDate > $1.creationDate
            case .dateAsc: return $0.creationDate < $1.creationDate
            case .nameAsc: return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            case .nameDesc: return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending
            case .sizeDesc: return $0.fileSizeBytes > $1.fileSizeBytes
            case .sizeAsc: return $0.fileSizeBytes < $1.fileSizeBytes
            case .durationDesc: return $0.duration > $1.duration
            case .durationAsc: return $0.duration < $1.duration
            }
        }
        return sorted
    }
    
    var body: some View {
        ZStack {
            Color.homeBackground.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                if viewModel.isSelectionMode {
                    selectionHeader
                } else {
                    standardHeader
                }
                
                ScrollView(.vertical, showsIndicators: true) {
                    VStack {
                        if isLoading {
                            ProgressView()
                                .padding(.top, 50)
                        } else if isGridView {
                            gridView
                        } else {
                            listView
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            
            if viewModel.isSelectionMode {
                selectionActionBar
            }

            // Syncing Overlay
            if viewModel.isImporting {
                ZStack {
                    Color.homeBackground.opacity(0.8)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .homeAccent))
                            .scaleEffect(1.5)
                        
                        Text("Syncing...")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.homeTextPrimary)
                    }
                    .padding(40)
                    .background(Color.sheetSurface)
                    .cornerRadius(20)
                    .shadow(radius: 20)
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showSortSheet) {
            if folder.url == nil {
                CustomSortingView(sortOptionRaw: $viewModel.gallerySortOptionRaw, title: "Album")
            } else {
                CustomSortingView(sortOptionRaw: $viewModel.folderSortOptionRaw, title: folder.name)
            }
        }
        .alert("Rename Video", isPresented: $showRenameVideoAlert) {
            TextField("New Name", text: $newVideoName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let video = videoToRename {
                    viewModel.renameVideo(video, to: newVideoName)
                }
            }
        } message: {
            Text("Enter a new name for this video")
        }
        .alert("Delete Video", isPresented: $showDeleteVideoAlert) {
            Button("Cancel", role: .cancel) { videoToDelete = nil }
            Button("Delete", role: .destructive) {
                if let video = videoToDelete {
                    viewModel.deleteVideo(video)
                }
                videoToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this video? This cannot be undone.")
        }
        .alert("Rename Folder", isPresented: $showRenameFolderAlert) {
            TextField("New Name", text: $newFolderName)
            Button("Cancel", role: .cancel) { folderToRename = nil }
            Button("Rename") {
                if let folder = folderToRename {
                    viewModel.renameFolder(folder, to: newFolderName)
                }
                folderToRename = nil
            }
        } message: {
            Text("Enter a new name for this folder")
        }
        .confirmationDialog("Import Videos", isPresented: $showImportOptions, titleVisibility: .visible) {
            Button("Photos Library") {
                viewModel.activeImportFolderURL = folder.url
                viewModel.showPhotoPicker = true
            }
            Button("Files App") {
                viewModel.activeImportFolderURL = folder.url
                viewModel.showFileImporter = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            viewModel.isTabBarHidden = true
        }
        .task {
            await fetchAlbumVideos()
        }
        .onDisappear {
            viewModel.isTabBarHidden = false
        }
        .onChange(of: viewModel.playingVideo) { oldVideo, newVideo in
            if newVideo == nil {
                viewModel.isTabBarHidden = true
            }
        }
        .onChange(of: viewModel.isSelectionMode) { oldVal, isSelectionMode in
            if !isSelectionMode {
                selectedVideoIds.removeAll()
            }
        }
        .onAppear {
            viewModel.isTabBarHidden = true
            // Resolve titles for album videos if not already done
            if folder.url == nil {
                viewModel.preFetchTitles(for: folder.videos)
            }
        }
        .onDisappear {
            viewModel.isTabBarHidden = false
        }
    }
    
    // MARK: - Subviews
    
    var standardHeader: some View {
        HStack {
            StandardIconButton(icon: "chevron.left", action: {
                presentationMode.wrappedValue.dismiss()
            })
            
            Text(folder.name)
                .font(.headline)
                .foregroundColor(.homeTextPrimary)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { showSearch = true }) {
                    Image(systemName: "magnifyingglass")
                        .appIconStyle()
                }
                .navigationDestination(isPresented: $showSearch) {
                    SearchView(viewModel: viewModel, contextTitle: folder.name, initialVideos: folder.videos)
                }
                
                Menu {
                    if !viewModel.copiedVideoIds.isEmpty {
                        Button(action: { 
                            if let url = folder.url {
                                viewModel.pasteVideos(to: url)
                            } else if let albumId = folder.albumIdentifier {
                                // Paste to gallery album
                                let collection = viewModel.galleryAlbums.first(where: { $0.localIdentifier == albumId })
                                viewModel.pasteVideosToGallery(album: collection)
                            }
                        }) {
                            Label("Paste", systemImage: "doc.on.clipboard")
                        }
                        Divider()
                    }
                    
                    Button(action: { viewModel.isSelectionMode = true }) {
                        Label("Select", systemImage: "checkmark.circle")
                    }
                    Divider()
                    Button(action: { isGridView = true }) {
                        Label("Grid", systemImage: isGridView ? "checkmark" : "square.grid.2x2")
                    }
                    Button(action: { isGridView = false }) {
                        Label("List", systemImage: !isGridView ? "checkmark" : "list.bullet")
                    }
                    Divider()
                    Button(action: { showSortSheet = true }) {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .appIconStyle()
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
        .background(Color.homeBackground)
    }
    
    var selectionHeader: some View {
        HStack {
            Button(action: {
                if isAllSelected {
                    selectedVideoIds.removeAll()
                } else {
                    selectedVideoIds = Set(folder.videos.map { $0.id })
                }
            }) {
                ZStack {
                    Circle()
                        .stroke(Color.homeTextPrimary, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    
                    if isAllSelected {
                        Circle()
                            .fill(Color.homeAccent)
                            .frame(width: AppDesign.Icons.selectionIconSize, height: AppDesign.Icons.selectionIconSize)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.homeTextPrimary)
                    }
                }
                .padding(10)
            }
            
            Spacer()
            
            Text("Selected (\(selectedVideoIds.count)/\(folder.videos.count))")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.homeTextPrimary)
            
            Spacer()
            
            Button("Done") {
                viewModel.isSelectionMode = false
                selectedVideoIds.removeAll()
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.homeAccent)
            .padding(.trailing, 10)
        }
        .padding(.horizontal, 5)
        .padding(.bottom, 10)
        .background(Color.homeBackground)
    }
    
    private var gridView: some View {
        LazyVGrid(columns: GridLayout.gridColumns, spacing: GridLayout.spacing) {
            // Folders Section
            if !folder.subfolders.isEmpty {
                Section(header: sectionHeaderLabel("Folders")) {
                    ForEach(folder.subfolders) { subfolder in
                        NavigationLink(destination: FolderDetailView(initialFolder: subfolder, viewModel: viewModel)) {
                            FolderCardView(folder: subfolder, onMenuAction: {
                                activeActionItem = .folder(subfolder)
                                showActionSheet = true
                            })
                        }
                    }
                }
            }
            
            // Videos Section (Unified or Grouped)
            if folder.url == nil && (sortOption == .dateAsc || sortOption == .dateDesc) {
                // ALBUIM MODE: Show Date Sections
                ForEach(groupedVideos, id: \.id) { section in
                    Section(header: sectionHeader(for: section.date)) {
                        ForEach(section.videos, id: \.id) { video in
                            gridVideoItem(liveVideo(video))
                        }
                    }
                }
            } else {
                // FOLDER MODE: Flat List (User Preference)
                Section {
                    // Import Button (independent item)
                    if !viewModel.isSelectionMode && folder.url != nil {
                        importButton
                    }
                    
                    ForEach(sortedVideos, id: \.id) { video in
                        gridVideoItem(liveVideo(video))
                    }
                }
            }
        }
        .padding(.horizontal, GridLayout.horizontalPadding)
    }
    
    private var listView: some View {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            if !folder.subfolders.isEmpty {
                Section(header: sectionHeaderLabel("Folders")) {
                    ForEach(folder.subfolders) { subfolder in
                        NavigationLink(destination: FolderDetailView(initialFolder: subfolder, viewModel: viewModel)) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.homeTint)
                                Text(subfolder.name)
                                    .foregroundColor(.homeTextPrimary)
                                Spacer()
                                Text("\(subfolder.videos.count) Videos")
                                    .font(.caption)
                                    .foregroundColor(.homeTextSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.homeTextSecondary)
                            }
                            .padding()
                            .background(Color.homeCardBackground.opacity(0.3))
                        }
                    }
                }
            }
            
            // Videos
            Group {
                if folder.url == nil && (sortOption == .dateAsc || sortOption == .dateDesc) {
                    // ALBUM MODE: Show Date Sections
                    ForEach(groupedVideos, id: \.id) { section in
                        Section(header: sectionHeader(for: section.date)) {
                            ForEach(section.videos, id: \.id) { video in
                                videoRow(liveVideo(video))
                            }
                        }
                    }
                } else {
                    // FOLDER MODE: Flat List
                    Group {
                        if !viewModel.isSelectionMode && folder.url != nil {
                            AddVideoRowView(action: {
                                showImportOptions = true
                            })
                            .padding(.vertical, 8)
                        }
                        
                        ForEach(sortedVideos, id: \.id) { video in
                            videoRow(liveVideo(video))
                        }
                    }
                }
            }
        }
    }
    
    private func sectionHeader(for date: Date) -> some View {
        sectionHeaderLabel(sectionHeaderTitle(for: date))
    }
    
    private func sectionHeaderLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.homeTextSecondary)
                .padding(.vertical, 10)
                .padding(.horizontal)
            Spacer()
        }
        .background(Color.homeBackground)
        .overlay(
            VStack {
                Spacer()
                Divider().background(Color.sheetDivider)
            }
        )
    }
    
    private func gridVideoItem(_ video: VideoItem) -> some View {
        Button {
            handleVideoTap(video)
        } label: {
            VideoCardView(
                video: video,
                viewModel: viewModel,
                isSelectionMode: viewModel.isSelectionMode,
                isSelected: selectedVideoIds.contains(video.id),
                onMenuAction: {
                    viewModel.actionSheetTarget = .video(video)
                    viewModel.actionSheetItems = videoActions(for: video)
                    viewModel.showActionSheet = true
                }
            )
            .opacity(viewModel.isSelectionMode && !selectedVideoIds.contains(video.id) ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
    }
    
    private func videoRow(_ video: VideoItem) -> some View {
        Button {
            handleVideoTap(video)
        } label: {
            VideoRowView(
                video: video,
                viewModel: viewModel,
                isSelectionMode: viewModel.isSelectionMode,
                isSelected: selectedVideoIds.contains(video.id),
                onMenuAction: {
                    viewModel.actionSheetTarget = .video(video)
                    viewModel.actionSheetItems = videoActions(for: video)
                    viewModel.showActionSheet = true
                }
            )
        }
        .buttonStyle(.plain)
    }
    
    private var selectionActionBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 0) {
                selectionBarItem(icon: "trash", title: "Delete", action: { deleteSelected() })
                
                selectionBarItem(icon: "doc.on.doc", title: "Copy", action: { 
                    viewModel.copyVideos(ids: selectedVideoIds, isCut: false, sourceURL: folder.url, sourceAlbumId: folder.albumIdentifier)
                    viewModel.showMovePicker = true
                })

                if folder.albumIdentifier == nil {
                    selectionBarItem(icon: "arrow.right.doc.on.clipboard", title: "Move", action: { 
                        viewModel.copyVideos(ids: selectedVideoIds, isCut: true, sourceURL: folder.url, sourceAlbumId: folder.albumIdentifier)
                        viewModel.showMovePicker = true
                    })
                }

                selectionBarItem(icon: "square.and.arrow.up", title: "Share", action: { viewModel.shareVideos(ids: selectedVideoIds) })
            }
            .padding(.top, 12)
            .padding(.bottom, 25)
            .background(Color.sheetSurface)
            .cornerRadius(20, corners: [.topLeft, .topRight])
            .shadow(color: Color.homeBackground.opacity(0.3), radius: 10, x: 0, y: -5)
        }
        .edgesIgnoringSafeArea(.bottom)
        .transition(.move(edge: .bottom))
    }
    
    private func selectionBarItem(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .appIconStyle(size: AppDesign.Icons.actionSheetIconSize, weight: .semibold, color: .homeAccent)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.homeTextPrimary)
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(selectedVideoIds.isEmpty)
        .opacity(selectedVideoIds.isEmpty ? 0.5 : 1.0)
    }
    
    // MARK: - Actions
    
    private func handleVideoTap(_ video: VideoItem) {
        if viewModel.isSelectionMode {
            if selectedVideoIds.contains(video.id) {
                selectedVideoIds.remove(video.id)
            } else {
                selectedVideoIds.insert(video.id)
            }
        } else {
            // Setup playlist context: All videos in this folder/album
            viewModel.currentPlaylist = sortedVideos
            viewModel.playingVideo = video
        }
    }
    
    private func toggleSelectionFavorites() {
        let selectedVideos = folder.videos.filter { selectedVideoIds.contains($0.id) }
        for video in selectedVideos {
            viewModel.toggleFavorite(for: video)
        }
        viewModel.isSelectionMode = false
        selectedVideoIds.removeAll()
    }
    
    private func deleteSelected() {
        let selectedVideos = folder.videos.filter { selectedVideoIds.contains($0.id) }
        for video in selectedVideos {
            viewModel.deleteVideo(video)
        }
        viewModel.isSelectionMode = false
        selectedVideoIds.removeAll()
    }
    
    // MARK: - Grouping Logic
    
    var isAllSelected: Bool {
        return !folder.videos.isEmpty && selectedVideoIds.count == folder.videos.count
    }
    
    var groupedVideos: [VideoSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: folder.videos) { video -> Date in
            calendar.startOfDay(for: video.creationDate)
        }
        let sortedDates = grouped.keys.sorted {
            return sortOption == .dateAsc ? $0 < $1 : $0 > $1
        }
        return sortedDates.map { date in
            let videosInDate = grouped[date] ?? []
            let sortedInDate = videosInDate.sorted { v1, v2 in
                if sortOption == .dateAsc {
                    return v1.creationDate < v2.creationDate
                } else {
                    return v1.creationDate > v2.creationDate
                }
            }
            return VideoSection(date: date, videos: sortedInDate)
        }
    }
    
    private func videoActions(for video: VideoItem) -> [CustomActionItem] {
        var items: [CustomActionItem] = []
        
        if video.asset == nil {
             items.append(CustomActionItem(title: "Rename", icon: "pencil", role: nil, action: {
                videoToRename = video
                newVideoName = video.title
                showRenameVideoAlert = true
            }))
        }
        
        items.append(CustomActionItem(title: "Share", icon: "square.and.arrow.up", role: nil, action: {
            viewModel.shareVideo(item: video)
        }))
        
        items.append(CustomActionItem(title: "Copy", icon: "doc.on.doc", role: nil, action: {
            viewModel.copyVideos(ids: Set([video.id]), isCut: false, sourceURL: folder.url, sourceAlbumId: folder.albumIdentifier)
            viewModel.showMovePicker = true
        }))
        
        if folder.albumIdentifier == nil {
            items.append(CustomActionItem(title: "Move", icon: "arrow.right.doc.on.clipboard", role: nil, action: {
                viewModel.copyVideos(ids: Set([video.id]), isCut: true, sourceURL: folder.url, sourceAlbumId: folder.albumIdentifier)
                videoToMove = video
                viewModel.showMovePicker = true
            }))
        }
        
        items.append(CustomActionItem(title: "Delete", icon: "trash", role: .destructive, action: {
            videoToDelete = video
            showDeleteVideoAlert = true
        }))
        
        return items
    }

    
    private var importButton: some View {
        AddVideoCardView(action: {
            showImportOptions = true
        })
    }
    
    // MARK: - Helpers
    
    private func liveVideo(_ video: VideoItem) -> VideoItem {
        // Resolve the latest state from the master lists in the view model
        // This ensures that background title resolution is reflected in this view
        if let asset = video.asset {
            return viewModel.allGalleryVideos.first(where: { $0.id == video.id }) ?? video
        } else {
            return viewModel.videos.first(where: { $0.id == video.id }) ?? video
        }
    }
    
    func sectionHeaderTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }
        }
    }
    
    private func fetchAlbumVideos() async {
        guard let albumId = folder.albumIdentifier, folder.videos.isEmpty else { return }
        
        await MainActor.run { isLoading = true }
        
        // Fetch on background
        let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumId], options: nil)
        guard let album = fetchResult.firstObject else { 
            await MainActor.run { isLoading = false }
            return 
        }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        let assets = PHAsset.fetchAssets(in: album, options: fetchOptions)
        
        var videos: [VideoItem] = []
        assets.enumerateObjects { asset, _, _ in
            videos.append(viewModel.videoItem(from: asset))
        }
        
        await MainActor.run {
            self.asyncVideos = videos
            self.isLoading = false
        }
    }
}


