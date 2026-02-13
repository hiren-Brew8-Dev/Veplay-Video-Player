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
    @State private var showDeleteSelectedAlert = false
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
    
    private var displayVideos: [VideoItem] {
        return (folder.videos.isEmpty && !asyncVideos.isEmpty) ? asyncVideos : folder.videos
    }
    
    var sortedVideos: [VideoItem] {
        let sorted = displayVideos.sorted {
            switch sortOption {
            case .recents, .dateDesc: return $0.creationDate > $1.creationDate
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
            Color.homeBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                if viewModel.isSelectionMode {
                    selectionHeader
                } else {
                    standardHeader
                }
                
                if !viewModel.isSelectionMode && !displayVideos.isEmpty {
                    utilityRow
                        .padding(.horizontal, AppDesign.Icons.horizontalPadding)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                }
                
                if isLoading {
                    ProgressView()
                        .padding(.top, 50)
                } else if isGridView {
                    gridView
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        listView
                            .padding(.bottom, viewModel.isSelectionMode ? 140 : 90)
                    }
                }
            }
            
            if viewModel.isSelectionMode {
                selectionActionBar
            }

            // Syncing Overlay

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
        .alert("Delete Selected Videos", isPresented: $showDeleteSelectedAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                let selectedVideos = folder.videos.filter { selectedVideoIds.contains($0.id) }
                for video in selectedVideos {
                    viewModel.deleteVideo(video)
                }
                viewModel.isSelectionMode = false
                selectedVideoIds.removeAll()
            }
        } message: {
            Text("Are you sure you want to delete \(selectedVideoIds.count) videos? This cannot be undone.")
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
            viewModel.markFolderAsAccessed(folder)
            // Resolve titles for album videos if not already done
            if folder.url == nil {
                viewModel.preFetchTitles(for: folder.videos)
            }
        }
        .task {
            await fetchAlbumVideos()
        }
        .onChange(of: viewModel.isSelectionMode) { oldVal, isSelectionMode in
            if !isSelectionMode {
                selectedVideoIds.removeAll()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var utilityRow: some View {
        HStack(spacing: isIpad ? 12 : 8) {
            // Selection Mode (Leading)
            Button(action: {
                withAnimation {
                    viewModel.isSelectionMode = true
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            // Sort Button
            Button(action: {
                withAnimation {
                    showSortSheet = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Sort by")
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
                .foregroundColor(.white)
            }
            
            Spacer()
            
            // View Mode Toggle (Trailing)
            Button(action: {
                withAnimation {
                    isGridView.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
    }

    var standardHeader: some View {
        HStack {
            Button(action: {
                if !viewModel.navigationPath.isEmpty {
                    viewModel.navigationPath.removeLast()
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.premiumCircleBackground)
                        .frame(width: AppDesign.Icons.circleButtonSize, height: AppDesign.Icons.circleButtonSize)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: isIpad ? 22 : 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            Text(folder.name)
                .font(.system(size: isIpad ? 24 : 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.leading, 8)
            
            Spacer()
            
            if !displayVideos.isEmpty {
                HStack(spacing: 12) {
                    Button(action: { 
                        let updatedVideos = displayVideos.map { liveVideo($0) }
                        viewModel.navigationPath.append(DashboardViewModel.NavigationDestination.search(contextTitle: folder.name, initialVideos: updatedVideos))
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.premiumCircleBackground)
                                .frame(width: AppDesign.Icons.circleButtonSize, height: AppDesign.Icons.circleButtonSize)
                            
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: isIpad ? 22 : 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    
                }
            }
        }
        
        .padding(.horizontal, AppDesign.Icons.horizontalPadding)
        .padding(.bottom, isIpad ? 20 : 10)
        .padding(.top, isIpad ? 20 : 0)
        .background(Color.clear)
    
    }
    
    var selectionHeader: some View {
        HStack {
            Button(action: {
                if isAllSelected {
                    selectedVideoIds.removeAll()
                } else {
                    selectedVideoIds = Set(displayVideos.map { $0.id })
                }
            }) {
                ZStack {
                    Circle()
                        .stroke(isAllSelected ? Color.orange : Color.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    
                    if isAllSelected {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 14, height: 14)
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(10)
            }
            
            Spacer()
            
            Text("Selected (\(selectedVideoIds.count)/\(displayVideos.count))")
                .font(.system(size: isIpad ? 24 : 17, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button("Done") {
                viewModel.isSelectionMode = false
                selectedVideoIds.removeAll()
            }
            .font(.system(size: isIpad ? 20 : 15, weight: .bold))
            .foregroundColor(.orange)
            .padding(.trailing, AppDesign.Icons.horizontalPadding)
        }
        .padding(.horizontal, AppDesign.Icons.horizontalPadding)
        .padding(.bottom, 10)
        .background(Color.clear)
    
    }
    
    private var gridView: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let currentWidth = geometry.size.width
            
            ScrollView {
                LazyVGrid(columns: GridLayout.gridColumns(isLandscape: isLandscape), spacing: GridLayout.spacing(isLandscape: isLandscape)) {
                    // Folders Section
                    if !folder.subfolders.isEmpty {
                        Section(header: sectionHeaderLabel("Folders")) {
                            ForEach(folder.subfolders) { subfolder in
                                NavigationLink(value: DashboardViewModel.NavigationDestination.folderDetail(subfolder)) {
                                    FolderCardView(folder: subfolder, viewModel: viewModel, onMenuAction: {
                                        activeActionItem = .folder(subfolder)
                                        showActionSheet = true
                                    }, size: GridLayout.itemSize(for: currentWidth, isLandscape: isLandscape))
                                }
                            }
                        }
                    }
                    
                    // Videos Section (Unified or Grouped)
                    if folder.url == nil && (sortOption == .dateAsc || sortOption == .dateDesc) {
                        // ALBUM MODE: Show Date Sections
                        ForEach(groupedVideos, id: \.id) { section in
                            Section(header: sectionHeader(for: section.date)) {
                                ForEach(section.videos, id: \.id) { video in
                                    gridVideoItem(liveVideo(video), isLandscape: isLandscape, width: currentWidth)
                                }
                            }
                        }
                    } else {
                        // FOLDER MODE: Flat List (User Preference)
                        Section {
                            // Import Button (independent item)
                            if !viewModel.isSelectionMode && folder.url != nil {
                                importButton(isLandscape: isLandscape, width: currentWidth)
                            }
                            
                            ForEach(sortedVideos, id: \.id) { video in
                                gridVideoItem(liveVideo(video), isLandscape: isLandscape, width: currentWidth)
                            }
                        }
                    }
                }
                .padding(.horizontal, GridLayout.horizontalPadding)
                .padding(.bottom, viewModel.isSelectionMode ? 140 : 90)
            }
        }
    }
    
    private var listView: some View {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            if !folder.subfolders.isEmpty {
                Section(header: sectionHeaderLabel("Folders")) {
                    ForEach(folder.subfolders) { subfolder in
                        NavigationLink(value: DashboardViewModel.NavigationDestination.folderDetail(subfolder)) {
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
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
            
            // Videos
            Group {
                if folder.url == nil && (sortOption == .dateAsc || sortOption == .dateDesc) {
                    // ALBUM MODE: Show Date Sections
                    ForEach(groupedVideos, id: \.id) { section in
                        Section {
                            VStack(spacing: 0) {
                                ForEach(section.videos.indices, id: \.self) { index in
                                    videoRow(liveVideo(section.videos[index]))
                                    
                                    if index < section.videos.count - 1 {
                                        Divider()
                                            .background(Color.white.opacity(0.1))
                                            .padding(.leading, 124)
                                    }
                                }
                            }
                            .background(Color.premiumCardBackground)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.premiumCardBorder, lineWidth: 1)
                            )
                            .padding(.horizontal, AppDesign.Icons.horizontalPadding)
                        } header: {
                            sectionHeader(for: section.date)
                        }
                    }
                } else {
                    // FOLDER MODE: Import New section
                    if !viewModel.isSelectionMode && folder.url != nil {
                        Section {
                            VStack(spacing: 0) {
                                AddVideoRowView(action: {
                                    showImportOptions = true
                                })
                            }
                            .background(Color.premiumCardBackground)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.premiumCardBorder, lineWidth: 1)
                            )
                            .padding(.horizontal, AppDesign.Icons.horizontalPadding)
                            .padding(.bottom, 20)
                        }
                    }
                    
                    // Video list - ALL in ONE section card
                    Section {
                        VStack(spacing: 0) {
                            ForEach(sortedVideos.indices, id: \.self) { index in
                                videoRow(liveVideo(sortedVideos[index]))
                                
                                if index < sortedVideos.count - 1 {
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                        .padding(.leading, 124)
                                }
                            }
                        }
                        .background(Color.premiumCardBackground)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.premiumCardBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, AppDesign.Icons.horizontalPadding)
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
            Text(text.uppercased())
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, AppDesign.Icons.horizontalPadding)
    }
    
    private func gridVideoItem(_ video: VideoItem, isLandscape: Bool, width: CGFloat) -> some View {
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
                },
                itemSize: GridLayout.itemSize(for: width, isLandscape: isLandscape)
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
        VStack(spacing: 0) {
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
            .padding(.top, isIpad ? 20 : 12)
            .padding(.bottom, max(10, UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0))
            .background(
                LinearGradient(
                    colors: [.premiumGradientTop, .premiumGradientBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                VStack {
                    Rectangle()
                        .fill(Color.premiumCardBorder)
                        .frame(height: 1)
                    Spacer()
                }
            )
            .clipShape(RoundedCorner(radius: 32, corners: [.topLeft, .topRight]))
            .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: -5)
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .transition(.move(edge: .bottom))
    }
    
    private func selectionBarItem(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(selectedVideoIds.isEmpty ? Color.white.opacity(0.05) : Color.orange.opacity(0.1))
                        .frame(width: isIpad ? 64 : 44, height: isIpad ? 64 : 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: isIpad ? 28 : 20, weight: .semibold))
                        .foregroundColor(selectedVideoIds.isEmpty ? .white.opacity(0.3) : .orange)
                }
                
                Text(title)
                    .font(.system(size: isIpad ? 16 : 11, weight: .bold))
                    .foregroundColor(selectedVideoIds.isEmpty ? .white.opacity(0.3) : .white)
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
        showDeleteSelectedAlert = true
    }
    
    // MARK: - Grouping Logic
    
    var isAllSelected: Bool {
        return !displayVideos.isEmpty && selectedVideoIds.count == displayVideos.count
    }
    
    var groupedVideos: [VideoSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: displayVideos) { video -> Date in
            calendar.startOfDay(for: video.creationDate)
        }
        let sortedDates = grouped.keys.sorted {
            return (sortOption == .dateAsc) ? $0 < $1 : $0 > $1
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
                viewModel.showMovePicker = true
            }))
        }
        
        items.append(CustomActionItem(title: "Delete", icon: "trash", role: .destructive, action: {
            videoToDelete = video
            showDeleteVideoAlert = true
        }))
        
        return items
    }

    
    private func importButton(isLandscape: Bool, width: CGFloat) -> some View {
        AddVideoCardView(action: {
            showImportOptions = true
        }, size: GridLayout.itemSize(for: width, isLandscape: isLandscape))
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



