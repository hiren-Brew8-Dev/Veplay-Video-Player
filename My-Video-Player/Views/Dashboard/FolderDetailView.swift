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
            LinearGradient(
                colors: [.premiumGradientTop, .premiumGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
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
                    .padding(.bottom, viewModel.isSelectionMode ? 140 : 90)
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
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            Text(folder.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            if !displayVideos.isEmpty {
                HStack(spacing: 12) {
                    Button(action: { showSearch = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.premiumCircleBackground)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .navigationDestination(isPresented: $showSearch) {
                        SearchView(viewModel: viewModel, contextTitle: folder.name, initialVideos: displayVideos)
                    }
                    
                    Menu {
                        Button(action: { viewModel.isSelectionMode = true }) {
                            Label("Select", systemImage: "checkmark.circle")
                        }
                        Divider()
                        Picker(selection: $isGridView, label: EmptyView()) {
                            Label("Grid", systemImage: "square.grid.2x2").tag(true)
                            Label("List", systemImage: "list.bullet").tag(false)
                        }
                        .pickerStyle(.inline)
                        
                        Divider()
                        Button(action: { showSortSheet = true }) {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.premiumCircleBackground)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "ellipsis")
                                .rotationEffect(.degrees(90))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
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
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button("Done") {
                viewModel.isSelectionMode = false
                selectedVideoIds.removeAll()
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.orange)
            .padding(.trailing, 10)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 10)
        .background(Color.clear)
    
    }
    
    private var gridView: some View {
        LazyVGrid(columns: GridLayout.gridColumns, spacing: GridLayout.spacing) {
            // Folders Section
            if !folder.subfolders.isEmpty {
                Section(header: sectionHeaderLabel("Folders")) {
                    ForEach(folder.subfolders) { subfolder in
                        NavigationLink(value: DashboardViewModel.NavigationDestination.folderDetail(subfolder)) {
                            FolderCardView(folder: subfolder, viewModel: viewModel, onMenuAction: {
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
                            .padding(.horizontal, 10)
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
                            .padding(.horizontal, 10)
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
                        .padding(.horizontal, 10)
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
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.homeTextSecondary)
                .padding(.horizontal, 4)
            Spacer()
        }
        .padding(.top, 5)
        .padding(.bottom, 5)
        .padding(.horizontal, 10)
        .background(Color.clear)
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
            .padding(.top, 16)
            .padding(.bottom, 34) // Explicit safe area space
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
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(selectedVideoIds.isEmpty ? .white.opacity(0.3) : .orange)
                }
                
                Text(title)
                    .font(.system(size: 11, weight: .bold))
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



