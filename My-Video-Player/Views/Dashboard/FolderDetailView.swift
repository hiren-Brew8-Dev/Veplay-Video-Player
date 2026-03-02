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
    @EnvironmentObject var navigationManager: NavigationManager
    
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
    
    @State private var showSearch = false
    @State private var showImportOptions = false
    @State private var asyncVideos: [VideoItem] = []
    @State private var isLoading = false
    
    // Cached async sort — replaces the old computed var that sorted 1700+ items on the main thread
    // on every SwiftUI re-render. Now updated via background Task only when inputs change.
    @State private var sortedDisplayVideos: [VideoItem] = []
    @State private var isSortingVideos: Bool = false

    // Derived
    var sortOption: DashboardViewModel.SortOption {
        if folder.url == nil {
            return viewModel.gallerySortOption
        }
        return viewModel.folderSortOption
    }
    
    var body: some View {
        GeometryReader { geometry in
            let safeAreaTop = geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 47)
            
            ZStack {
                AppGlobalBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if isLoading {
                        ProgressView()
                            .padding(.top, 100)
                    } else if displayVideos.isEmpty && folder.subfolders.isEmpty {
                        VStack(spacing: 0) {
                            Spacer()
                            emptyStateView
                                .responsivePadding(edge: .top, fraction: 40)
                            Spacer()
                            Spacer()
                        }
                    } else if isGridView {
                        gridView
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            listView
                                .padding(.top, 20)
                                .padding(.bottom, viewModel.isSelectionMode ? 140 : 90)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                    }
                }
                .safeAreaInset(edge: .top) {
                    VStack(spacing: 5) {
                        if viewModel.isSelectionMode {
                            selectionHeader
                                .padding(.top, safeAreaTop)
                        } else {
                            mainHeader
                                .padding(.top, safeAreaTop)
                            
                            if !displayVideos.isEmpty {
                                utilityRow
                                    .padding(.horizontal, AppDesign.Icons.horizontalPadding)
                                    .padding(.top, 0)
                                    .padding(.bottom, 0)
                            }
                        }
                    }
                    .background(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .black, location: 0.0),
                                .init(color: .black.opacity(0.7), location: 0.7),
                                .init(color: .black.opacity(0), location: 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .top)
                    )
                }
                
                if viewModel.isSelectionMode {
                    selectionActionBar
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            viewModel.isTabBarHidden = false // Ensure floating button shows
            viewModel.activeImportFolderURL = folder.url // Set target for floating button
            
            viewModel.markFolderAsAccessed(folder)
            // Resolve titles for album videos if not already done
            if folder.url == nil {
                viewModel.preFetchTitles(for: folder.videos)
            }
            
            // Prewarm thumbnail cache for file-based folders whose videos are already populated.
            // Album folders are handled after fetchAlbumVideos() completes (below).
            if folder.url != nil && !folder.videos.isEmpty {
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3) {
                    ThumbnailCacheManager.shared.prewarmCache(for: folder.videos)
                }
            }
        }
        .onDisappear {
            viewModel.activeImportFolderURL = nil // Reset target
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
                let currentSelectedIds = selectedVideoIds
                viewModel.deleteVideos(ids: currentSelectedIds)
                
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
            await resolveDisplayVideos()
        }
        // Re-resolve whenever the raw inputs change (asyncVideos, sort option, or folder.videos)
        .onChange(of: asyncVideos) { _, _ in
            Task { await resolveDisplayVideos() }
        }
        .onChange(of: viewModel.folderSortOptionRaw) { _, _ in
            Task { await resolveDisplayVideos() }
        }
        .onChange(of: viewModel.gallerySortOptionRaw) { _, _ in
            Task { await resolveDisplayVideos() }
        }
        .onChange(of: viewModel.folders) { _, _ in
            Task { await resolveDisplayVideos() }
        }
        .onChange(of: viewModel.isSelectionMode) { oldVal, isSelectionMode in
            if !isSelectionMode {
                selectedVideoIds.removeAll()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var utilityRow: some View {
        HStack(spacing: isIpad ? 6 : 4) {
            // Selection Mode (Leading)
            Button(action: {
                HapticsManager.shared.generate(.medium)
                withAnimation {
                    viewModel.isSelectionMode = true
                }
            }) {
                Image("pencil")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .frame(width: 30, height: 30)
            }
            .glassButtonStyle()
            .buttonBorderShape(.circle)
            
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 16)
            
            // Sort Menu
            Menu {
                let currentSort = (folder.url == nil ? viewModel.gallerySortOptionRaw : viewModel.folderSortOptionRaw)
                
                // Date
                let isDateActive = ["Newest First", "Oldest First"].contains(currentSort)
                if isDateActive {
                    Section {
                        dateSortButtons
                    } header: {
                        Label("Date", systemImage: "calendar")
                    }
                } else {
                    Menu {
                        dateSortButtons
                    } label: {
                        Label("Date", systemImage: "calendar")
                    }
                }
                
                // Name
                let isNameActive = ["Name (A-Z)", "Name (Z-A)"].contains(currentSort)
                if isNameActive {
                    Section {
                        nameSortButtons
                    } header: {
                        Label("Name", systemImage: "textformat")
                    }
                } else {
                    Menu {
                        nameSortButtons
                    } label: {
                        Label("Name", systemImage: "textformat")
                    }
                }
                
                // Length
                let isLengthActive = ["Duration (Long to Short)", "Duration (Short to Long)"].contains(currentSort)
                if isLengthActive {
                    Section {
                        lengthSortButtons
                    } header: {
                        Label("Length", systemImage: "clock")
                    }
                } else {
                    Menu {
                        lengthSortButtons
                    } label: {
                        Label("Length", systemImage: "clock")
                    }
                }
                
                // Size (Only if not album)
                if folder.url != nil {
                    let isSizeActive = ["Size (Large to Small)", "Size (Small to Large)"].contains(currentSort)
                    if isSizeActive {
                        Section {
                            sizeSortButtons
                        } header: {
                            Label("Size", systemImage: "sdcard")
                        }
                    } else {
                        Menu {
                            sizeSortButtons
                        } label: {
                            Label("Size", systemImage: "sdcard")
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Sort by")
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
            }
            .glassButtonStyle()
            .buttonBorderShape(.capsule)
            .padding(.leading, 4)
            Spacer()
            
            // View Mode Toggle (Trailing)
            Button(action: {
                HapticsManager.shared.generate(.light)
                withAnimation {
                    isGridView.toggle()
                }
            }) {
                Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .glassButtonStyle()
            .buttonBorderShape(.circle)
        }
    }

    var mainHeader: some View {
        HStack(spacing: 0) {
            Button(action: {
                HapticsManager.shared.generate(.medium)
                navigationManager.pop()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: isIpad ? 20 : 18, weight: .bold))
                    .frame(width: 30, height: 30)
            }
            .glassButtonStyle()
            .buttonBorderShape(.circle)
            .padding(.leading, AppDesign.Icons.horizontalPadding)
            
            Text(folder.name)
                .font(.system(size: isIpad ? 24 : 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.leading, 12)
                .lineLimit(1)
            
            Spacer()
            
            if !displayVideos.isEmpty {
                Button(action: {
                    HapticsManager.shared.generate(.medium)
                    let updatedVideos = displayVideos.map { liveVideo($0) }
                    navigationManager.push(.search(contextTitle: folder.name, initialVideos: updatedVideos))
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: isIpad ? 20 : 18, weight: .bold))
                        .frame(width: 30, height: 30)
                }
                .glassButtonStyle()
                .buttonBorderShape(.circle)
                .padding(.trailing, AppDesign.Icons.horizontalPadding)
            }
        }
        .frame(height: AppDesign.Icons.headerHeight)
        .padding(.vertical, 10)
    }
    
    var selectionHeader: some View {
        HStack {
            Button(action: {
                HapticsManager.shared.generate(.selection)
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
                .font(.system(size: isIpad ? 22 : 17, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button("Cancel") {
                viewModel.isSelectionMode = false
                selectedVideoIds.removeAll()
            }
            .font(.system(size: isIpad ? 18 : 15, weight: .bold))
            .foregroundColor(.orange)
            .padding(.trailing, AppDesign.Icons.horizontalPadding)
        }
        .frame(height: AppDesign.Icons.headerHeight)
        .padding(.vertical, 10)
    }
    
    private var gridView: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let currentWidth = geometry.size.width
            
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: GridLayout.gridColumns(isLandscape: isLandscape), spacing: GridLayout.spacing(isLandscape: isLandscape)) {
                    // Folders Section
                    if !folder.subfolders.isEmpty {
                        Section(header: sectionHeaderLabel("Folders")) {
                            ForEach(folder.subfolders) { subfolder in
                                Button(action: {
                                    HapticsManager.shared.generate(.light)
                                    navigationManager.push(.folderDetail(subfolder))
                                }) {
                                    FolderCardView(folder: subfolder, viewModel: viewModel, onMenuAction: {
                                        viewModel.actionSheetTarget = .folder(subfolder)
                                        viewModel.showActionSheet = true
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
                                    gridVideoItem(video, isLandscape: isLandscape, width: currentWidth)
                                }
                            }
                        }
                    } else {
                        // FOLDER MODE: Flat List (User Preference)
                        Section {
                            ForEach(displayVideos, id: \.id) { video in
                                gridVideoItem(video, isLandscape: isLandscape, width: currentWidth)
                            }
                        }
                    }
                }
                .padding(.horizontal, GridLayout.horizontalPadding)
                .padding(.top, 20)
                .padding(.bottom, viewModel.isSelectionMode ? 140 : 90)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
    
    private var listView: some View {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            if !folder.subfolders.isEmpty {
                Section(header: sectionHeaderLabel("Folders")) {
                            ForEach(folder.subfolders) { subfolder in
                                Button(action: {
                                    HapticsManager.shared.generate(.light)
                                    navigationManager.push(.folderDetail(subfolder))
                                }) {
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
                            ForEach(section.videos, id: \.id) { video in
                                videoRow(video)
                                    .padding(.horizontal, AppDesign.Icons.horizontalPadding)
                                    .padding(.bottom, 12)
                            }
                        } header: {
                            sectionHeader(for: section.date)
                        }
                    }
                } else {
                    // Video list - ALL in ONE section card
                    Section {
                        ForEach(displayVideos, id: \.id) { video in
                            videoRow(video)
                                .padding(.horizontal, AppDesign.Icons.horizontalPadding)
                                .padding(.bottom, 12)
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
                selectionBarItem(icon: "trash", title: "Delete", action: {
                    HapticsManager.shared.generate(.medium)
                    deleteSelected()
                })
                
                selectionBarItem(icon: "doc.on.doc", title: "Copy to", action: {
                    HapticsManager.shared.generate(.medium)
                    viewModel.copyVideos(ids: selectedVideoIds, isCut: false, sourceURL: folder.url, sourceAlbumId: folder.albumIdentifier)
                    viewModel.showMovePicker = true
                })

                if folder.albumIdentifier == nil {
                    selectionBarItem(icon: "arrow.right.doc.on.clipboard", title: "Move to", action: {
                        HapticsManager.shared.generate(.medium)
                        viewModel.copyVideos(ids: selectedVideoIds, isCut: true, sourceURL: folder.url, sourceAlbumId: folder.albumIdentifier)
                        viewModel.showMovePicker = true
                    })
                }

                selectionBarItem(icon: "square.and.arrow.up", title: "Share", action: {
                    HapticsManager.shared.generate(.medium)
                    viewModel.shareVideos(ids: selectedVideoIds)
                })
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
            HapticsManager.shared.generate(.selection)
            if selectedVideoIds.contains(video.id) {
                selectedVideoIds.remove(video.id)
            } else {
                selectedVideoIds.insert(video.id)
            }
        } else {
            // Setup playlist context: All videos in this folder/album
            HapticsManager.shared.generate(.medium)
            viewModel.currentPlaylist = displayVideos
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
            calendar.startOfDay(for: video.importDate)
        }
        let sortedDates = grouped.keys.sorted {
            return (sortOption == .dateAsc) ? $0 < $1 : $0 > $1
        }
        return sortedDates.map { date in
            let videosInDate = grouped[date] ?? []
            let sortedInDate = videosInDate.sorted { v1, v2 in
                if sortOption == .dateAsc {
                    return v1.importDate < v2.importDate
                } else {
                    return v1.importDate > v2.importDate
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
        
        items.append(CustomActionItem(title: "Copy to", icon: "doc.on.doc", role: nil, action: {
            viewModel.copyVideos(ids: Set([video.id]), isCut: false, sourceURL: folder.url, sourceAlbumId: folder.albumIdentifier)
            viewModel.showMovePicker = true
        }))
        
        if folder.albumIdentifier == nil {
            items.append(CustomActionItem(title: "Move to", icon: "arrow.right.doc.on.clipboard", role: nil, action: {
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

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "video.slash")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.2))
            }
            
            VStack(spacing: 12) {
                Text("No Videos Found")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text(folder.url == nil ? 
                     "This album doesn't have any videos yet." : 
                     "This folder is empty. Import some videos\nto see them here.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            }
            .padding(.horizontal, 40)
            
           
        }
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
    
    private static let sectionHeaderDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    func sectionHeaderTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return Self.sectionHeaderDateFormatter.string(from: date)
        }
    }
    
    /// resolveDisplayVideos
    /// - Description: Computes the sorted, filtered video list on a background Task and publishes
    ///   the result to `sortedDisplayVideos`. Prevents the O(n log n) sort from blocking the main
    ///   thread on every re-render — critical for folders with 1700+ videos.
    /// - How to use: Called from .task{} on appear and from .onChange handlers when sort/filter inputs change.
    @MainActor
    private func resolveDisplayVideos() async {
        isSortingVideos = true
        defer { isSortingVideos = false }
        
        // Snapshot all needed inputs on main thread before going to background
        let albumIdentifier = folder.albumIdentifier
        let allVideosAlbumId = viewModel.allVideosAlbumIdentifier
        let sortedGallery = viewModel.sortedAllGalleryVideos
        let allGallery = viewModel.allGalleryVideos
        let currentAsyncVideos = asyncVideos
        let folderVideos = folder.videos
        let currentSortOption = sortOption
        let allVideosAcrossFolders = viewModel.allVideosAcrossFolders
        let vmVideos = viewModel.videos
        let vm = viewModel
        
        let result: [VideoItem] = await Task.detached(priority: .userInitiated) {
            if let albumId = albumIdentifier {
                // "All Videos" smart album — already pre-sorted by Combine, zero work needed
                if let allVidsId = allVideosAlbumId, albumId == allVidsId {
                    return sortedGallery.isEmpty ? allGallery : sortedGallery
                }
                // Other album: use asyncVideos from background GCD fetch
                let baseVideos = currentAsyncVideos.isEmpty ? folderVideos : currentAsyncVideos
                return vm.sortVideos(baseVideos, by: currentSortOption)
            }
            
            // File folder: O(1) Set lookup to filter against valid video IDs
            let baseVideos = (folderVideos.isEmpty && !currentAsyncVideos.isEmpty) ? currentAsyncVideos : folderVideos
            var validIds = Set(vmVideos.map { $0.id })
            for v in allVideosAcrossFolders { validIds.insert(v.id) }
            let filtered = baseVideos.filter { validIds.contains($0.id) }
            return vm.sortVideos(filtered, by: currentSortOption)
        }.value
        
        sortedDisplayVideos = result
    }

    private func fetchAlbumVideos() async {
        guard let albumId = folder.albumIdentifier, folder.videos.isEmpty, asyncVideos.isEmpty else { return }

        // Fast path: "All Videos" is exactly viewModel.allGalleryVideos — already loaded, instant.
        if let allVidsId = viewModel.allVideosAlbumIdentifier, albumId == allVidsId {
            asyncVideos = viewModel.allGalleryVideos
            return
        }

        isLoading = true
        let vm = viewModel

        // Pure GCD fire-and-forget: returns immediately so @MainActor (main thread) is never blocked.
        // DispatchQueue.global guarantees execution outside @MainActor regardless of Swift concurrency context.
        DispatchQueue.global(qos: .userInitiated).async {
            let collectionResult = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [albumId], options: nil)

            guard let collection = collectionResult.firstObject else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }

            let options = PHFetchOptions()
            options.predicate = NSPredicate(
                format: "mediaType = %d", PHAssetMediaType.video.rawValue)
            options.sortDescriptors = [
                NSSortDescriptor(key: "creationDate", ascending: false)]
            let assets = PHAsset.fetchAssets(in: collection, options: options)

            var result: [VideoItem] = []
            result.reserveCapacity(assets.count)
            assets.enumerateObjects { asset, _, _ in
                var item = vm.videoItem(from: asset)
                // Resolve real filename so A-Z / Z-A sort works correctly.
                if let resource = PHAssetResource.assetResources(for: asset).first,
                   !resource.originalFilename.isEmpty {
                    item.title = resource.originalFilename
                }
                result.append(item)
            }

            DispatchQueue.main.async {
                self.asyncVideos = result
                self.isLoading = false
                
                // Pre-warm thumbnail cache for album videos — same pattern as loadImportedVideos().
                // Deferred by 0.5s so the grid has time to lay out before decode work starts.
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) {
                    ThumbnailCacheManager.shared.prewarmCache(for: result)
                }
            }
        }
    }
    @ViewBuilder
    private var dateSortButtons: some View {
        Button {
            if folder.url == nil {
                viewModel.gallerySortOptionRaw = "Newest First"
            } else {
                viewModel.folderSortOptionRaw = "Newest First"
            }
        } label: {
            HStack {
                Text("Newest First")
                if (folder.url == nil ? viewModel.gallerySortOptionRaw : viewModel.folderSortOptionRaw) == "Newest First" { Image(systemName: "checkmark") }
            }
        }
        .menuActionDismissBehavior(.disabled)
        
        Button {
            if folder.url == nil {
                viewModel.gallerySortOptionRaw = "Oldest First"
            } else {
                viewModel.folderSortOptionRaw = "Oldest First"
            }
        } label: {
            HStack {
                Text("Oldest First")
                if (folder.url == nil ? viewModel.gallerySortOptionRaw : viewModel.folderSortOptionRaw) == "Oldest First" { Image(systemName: "checkmark") }
            }
        }
        .menuActionDismissBehavior(.disabled)
    }

    @ViewBuilder
    private var nameSortButtons: some View {
        Button {
            if folder.url == nil {
                viewModel.gallerySortOptionRaw = "Name (A-Z)"
            } else {
                viewModel.folderSortOptionRaw = "Name (A-Z)"
            }
        } label: {
            HStack {
                Text("A to Z")
                if (folder.url == nil ? viewModel.gallerySortOptionRaw : viewModel.folderSortOptionRaw) == "Name (A-Z)" { Image(systemName: "checkmark") }
            }
        }
        .menuActionDismissBehavior(.disabled)
        
        Button {
            if folder.url == nil {
                viewModel.gallerySortOptionRaw = "Name (Z-A)"
            } else {
                viewModel.folderSortOptionRaw = "Name (Z-A)"
            }
        } label: {
            HStack {
                Text("Z to A")
                if (folder.url == nil ? viewModel.gallerySortOptionRaw : viewModel.folderSortOptionRaw) == "Name (Z-A)" { Image(systemName: "checkmark") }
            }
        }
        .menuActionDismissBehavior(.disabled)
    }

    @ViewBuilder
    private var lengthSortButtons: some View {
        Button {
            if folder.url == nil {
                viewModel.gallerySortOptionRaw = "Duration (Long to Short)"
            } else {
                viewModel.folderSortOptionRaw = "Duration (Long to Short)"
            }
        } label: {
            HStack {
                Text("Long to Short")
                if (folder.url == nil ? viewModel.gallerySortOptionRaw : viewModel.folderSortOptionRaw) == "Duration (Long to Short)" { Image(systemName: "checkmark") }
            }
        }
        .menuActionDismissBehavior(.disabled)
        
        Button {
            if folder.url == nil {
                viewModel.gallerySortOptionRaw = "Duration (Short to Long)"
            } else {
                viewModel.folderSortOptionRaw = "Duration (Short to Long)"
            }
        } label: {
            HStack {
                Text("Short to Long")
                if (folder.url == nil ? viewModel.gallerySortOptionRaw : viewModel.folderSortOptionRaw) == "Duration (Short to Long)" { Image(systemName: "checkmark") }
            }
        }
        .menuActionDismissBehavior(.disabled)
    }

    @ViewBuilder
    private var sizeSortButtons: some View {
        Button {
            viewModel.folderSortOptionRaw = "Size (Large to Small)"
        } label: {
            HStack {
                Text("Large to Small")
                if viewModel.folderSortOptionRaw == "Size (Large to Small)" { Image(systemName: "checkmark") }
            }
        }
        .menuActionDismissBehavior(.disabled)
        
        Button {
            viewModel.folderSortOptionRaw = "Size (Small to Large)"
        } label: {
            HStack {
                Text("Small to Large")
                if viewModel.folderSortOptionRaw == "Size (Small to Large)" { Image(systemName: "checkmark") }
            }
        }
        .menuActionDismissBehavior(.disabled)
    }
    @ViewBuilder
    private var recentsSortButton: some View {
        Button {
            if folder.url == nil {
                viewModel.gallerySortOptionRaw = "Recents"
            } else {
                viewModel.folderSortOptionRaw = "Recents"
            }
        } label: {
            HStack {
                Label("Recently Accessed", systemImage: "clock.arrow.circlepath")
                if (folder.url == nil ? viewModel.gallerySortOptionRaw : viewModel.folderSortOptionRaw) == "Recents" {
                    Image(systemName: "checkmark")
                }
            }
        }
        .menuActionDismissBehavior(.disabled)
    }
}



