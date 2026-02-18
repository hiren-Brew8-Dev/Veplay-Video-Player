import SwiftUI
import PhotosUI

struct VideoSectionView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @EnvironmentObject var navigationManager: NavigationManager
    @Binding var paddingBottom: CGFloat
    
    // Local State for Actions
    @State private var videoToMove: VideoItem?
    @State private var videoToRename: VideoItem?
    @State private var videoToDelete: VideoItem?
    @State private var showRenameVideoAlert = false
    @State private var showDeleteVideoAlert = false
    @State private var showDeleteSelectedAlert = false
    @State private var newVideoName = ""
    

    @State private var showSortSheet: Bool = false
    @State private var showSearch = false
    @State private var showImportOptions = false

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = isIpad ? (geometry.size.width > geometry.size.height) : (geometry.size.width > 500)
            let currentWidth = geometry.size.width
//            
//            let isLandscape = isIpad ? (geometry.size.width > geometry.size.height) : (geometry.size.width > 500)
//            let currentWidth = geometry.size.width
            let safeAreaTop = geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 47)
            
            ZStack {
                // Main Scrollable Content with Sticky Header
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            if !viewModel.isInitialLoading || !viewModel.importedVideos.isEmpty {
                                if viewModel.isGridView {
                                    videosGrid(isLandscape: isLandscape, width: currentWidth)
                                } else {
                                    listView(isLandscape: isLandscape)
                                }
                            }
                        }
                        .padding(.top, 20) // Extra padding between header and content
                        .padding(.bottom, viewModel.isSelectionMode ? 140 : 100)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .safeAreaInset(edge: .top) {
                        VStack(spacing: 5) {
                            if viewModel.isSelectionMode {
                                selectionHeader
                                    .padding(.top, safeAreaTop)
                            } else {
                                mainHeader
                                    .padding(.top, safeAreaTop)
                                
                                if !viewModel.groupedImportedVideos.isEmpty && !viewModel.isInitialLoading {
                                    
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
                                       .init(color: .black.opacity(0.7), location: 0.8),
                                       .init(color: .black.opacity(0), location: 1.0)
                                   ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea(edges: .top)
                        )
                    }
                    .onChange(of: viewModel.highlightVideoId) { oldId, newId in
                        if let id = newId {
                            withAnimation(.spring()) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
                
                if viewModel.importedVideos.isEmpty && !viewModel.isImporting && !viewModel.isInitialLoading {
                   emptyStateView
                        .responsivePadding(edge: .top, fraction: -10)
                }
                
                if viewModel.isSelectionMode {
                    selectionActionBar
                }
            }
        }
//        .background(Color.homeBackground.edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $showSortSheet) {
            CustomSortingView(sortOptionRaw: $viewModel.videoSortOptionRaw, title: "Videos")
        }
        .alert("Rename Video", isPresented: $showRenameVideoAlert) {
            TextField("New Name", text: $newVideoName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let video = videoToRename {
                    viewModel.renameVideo(video, to: newVideoName)
                }
            }
        }
        .alert("Delete Video", isPresented: $showDeleteVideoAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let video = videoToDelete {
                    viewModel.deleteVideo(video)
                }
            }
        }
        .alert("Delete Selected Videos", isPresented: $showDeleteSelectedAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteVideos(ids: viewModel.selectedVideoIds)
                viewModel.isSelectionMode = false
                viewModel.selectedVideoIds.removeAll()
            }
        } message: {
            Text("Are you sure you want to delete \(viewModel.selectedVideoIds.count) videos? This cannot be undone.")
        }
        .background(Color.clear)
    }
    
    var isAllSelected: Bool {
        return !viewModel.importedVideos.isEmpty && viewModel.selectedVideoIds.count == viewModel.importedVideos.count
    }
    
    // MARK: - Headers
    
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
                let currentSort = viewModel.videoSortOptionRaw
               
                
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
                
                // Size
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
                    viewModel.isGridView.toggle()
                }
            }) {
                Image(systemName: viewModel.isGridView ? "list.bullet" : "square.grid.2x2")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .glassButtonStyle()
            .buttonBorderShape(.circle)
        }
    }

    
    // Previous Folders Code Removed

    // Previous Folders Code Removed

    private var mainHeader: some View {
        HStack(spacing: 0) {
            // Title Only
            HStack(spacing: 0) {
                Text("Videos")
                    .font(.system(size: AppDesign.Icons.headerSize + 4, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.leading, AppDesign.Icons.horizontalPadding)
            
            Spacer()
            
            HStack(spacing: isIpad ? 20 : 5) {
                // Settings Button
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
                
                // Crown
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

    private var expandedHeader: some View {
        HStack {
            Text("Videos")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.homeTextPrimary)
            
            Spacer()
            
            HStack(spacing: 20) {
                Button(action: { 
                    navigationManager.push(.search(contextTitle: "Videos", initialVideos: viewModel.importedVideos))
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(.homeTint)
                }
                
                Button(action: { showImportOptions = true }) {
                    Image(systemName: "plus.circle.fill")
                        .appIconStyle(size: AppDesign.Icons.toolbarSize + 4, weight: .bold, color: .homeAccent)
                }
                
                
                Menu {
                    Button(action: { viewModel.isSelectionMode = true }) {
                        Label("Select", systemImage: "checkmark.circle")
                    }
                    
                    Divider()
                    
                    Picker(selection: $viewModel.isGridView, label: EmptyView()) {
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
                            .fill(Color.clear)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .font(.system(size: 20))
                            .foregroundColor(.homeTint)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.clear)
    }
    
    private var selectionHeader: some View {
        HStack {
            Button(action: {
                HapticsManager.shared.generate(.selection)
                let allVideos = viewModel.importedVideos
                if isAllSelected {
                    viewModel.selectedVideoIds.removeAll()
                } else {
                    viewModel.selectedVideoIds = Set(allVideos.map { $0.id })
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
            
            let allVideos = viewModel.importedVideos
            Text("Selected (\(viewModel.selectedVideoIds.count)/\(allVideos.count))")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button("Cancel") {
                HapticsManager.shared.generate(.medium)
                viewModel.isSelectionMode = false
                viewModel.selectedVideoIds.removeAll()
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.orange)
            .padding(.trailing, 10 + (isIpad ? 10 : 0))
        }
        .padding(.horizontal, AppDesign.Icons.horizontalPadding / 2)
        .padding(.vertical, isIpad ? 16 : 8)
        .background(Color.clear)
    
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
                    viewModel.copyVideos(ids: viewModel.selectedVideoIds, isCut: false, sourceURL: viewModel.importedVideosDirectory)
                    viewModel.showMovePicker = true
                })

                selectionBarItem(icon: "arrow.right.doc.on.clipboard", title: "Move to", action: {
                    HapticsManager.shared.generate(.medium)
                    viewModel.copyVideos(ids: viewModel.selectedVideoIds, isCut: true, sourceURL: viewModel.importedVideosDirectory)
                    viewModel.showMovePicker = true
                })

                selectionBarItem(icon: "square.and.arrow.up", title: "Share", action: {
                    HapticsManager.shared.generate(.medium)
                    viewModel.shareSelectedVideos()
                })
            }
            
            .padding(.top, isIpad ? 20 : 12)
            .padding(.bottom, max(10, UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0))
            
            .background(Color.homeSheetBackground)
            
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
                        .fill(viewModel.selectedVideoIds.isEmpty ? Color.white.opacity(0.05) : Color.orange.opacity(0.1))
                        .frame(width: isIpad ? 60 : 44, height: isIpad ? 60 : 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: isIpad ? 28 : 20, weight: .semibold))
                        .foregroundColor(viewModel.selectedVideoIds.isEmpty ? .white.opacity(0.3) : .orange)
                }
                
                Text(title)
                    .font(.system(size: isIpad ? 14 : 11, weight: .bold))
                    .foregroundColor(viewModel.selectedVideoIds.isEmpty ? .white.opacity(0.3) : .white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6) // Reduced from 10
        }
        .disabled(viewModel.selectedVideoIds.isEmpty)
        .opacity(viewModel.selectedVideoIds.isEmpty ? 0.5 : 1.0)
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "video.slash")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.2))
            }
            
            VStack(spacing: 12) {
                Text(viewModel.importedVideos.isEmpty ? "No Videos Imported" : "No Content Found")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text(viewModel.importedVideos.isEmpty ? 
                     "Start by importing videos from your photos\nor files to build your local library." :
                     "Your folders and videos will appear here.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 40)
            
            if viewModel.importedVideos.isEmpty && !viewModel.isImporting {
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
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                        Text("Import Videos")
                            .font(.system(size: 16, weight: .bold))
                    }
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
                .padding(.top, 8)
            }
            
            Spacer()
//            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    
    private var allVideosCard: some View {
        Button(action: {
            // Navigate to full list if needed, or just show grid below
        }) {
            VStack(alignment: .leading) {
                Image(systemName: "video.fill") // Using system image as placeholder
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(40)
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .background(Color.homeSheetBackground)
                    .overlay(Color.homeBackground.opacity(0.3))
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("All Videos")
                                        .font(.headline)
                                        .foregroundColor(.homeTextPrimary)
                                    Text("\(viewModel.importedVideos.count) Videos")
                                        .font(.caption)
                                        .foregroundColor(.homeTextSecondary)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.homeBackground.opacity(0.6))
                        }
                    )
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
    
    private func videosGrid(isLandscape: Bool, width: CGFloat) -> some View {
        LazyVStack(alignment: .leading, spacing: 15, pinnedViews: [.sectionHeaders]) {
            ForEach(viewModel.groupedImportedVideos) { section in
                Section(header: sectionHeader(for: section.date)) {
                    LazyVGrid(columns: GridLayout.gridColumns(isLandscape: isLandscape), spacing: GridLayout.spacing(isLandscape: isLandscape)) {
                         ForEach(section.videos) { video in
                             videoItemView(for: video, isLandscape: isLandscape, width: width)
                         }
                    }
                    .padding(.horizontal, GridLayout.horizontalPadding)
                }
            }
        }
    }
    
    private func listView(isLandscape: Bool) -> some View {
        LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
            ForEach(viewModel.groupedImportedVideos) { section in
                Section {
                    ForEach(section.videos) { video in
                        videoRow(video)
                            .padding(.horizontal, AppDesign.Icons.horizontalPadding)
                    }
                } header: {
                    sectionHeader(for: section.date)
                }
            }
        }
    }

    
    @ViewBuilder
    private func sectionHeader(for date: Date) -> some View {
        if date == .distantPast {
            EmptyView()
        } else {
            HStack {
                Text(formattedSectionDate(date).uppercased())
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
    }
    
    private func formattedSectionDate(_ date: Date) -> String {
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

    private func videoRow(_ video: VideoItem) -> some View {
        Button(action: {
            handleVideoTap(video)
        }) {
            VideoRowView(
                video: video,
                viewModel: viewModel,
                isSelectionMode: viewModel.isSelectionMode,
                isSelected: viewModel.selectedVideoIds.contains(video.id),
                onMenuAction: {
                    triggerActionSheet(for: video)
                }
            )
        }
        .buttonStyle(.scalable)
    }
    
    private func videoItemView(for video: VideoItem, isLandscape: Bool, width: CGFloat) -> some View {
        Button(action: {
            handleVideoTap(video)
        }) {
            VideoCardView(
                video: video,
                viewModel: viewModel,
                isSelectionMode: viewModel.isSelectionMode,
                isSelected: viewModel.selectedVideoIds.contains(video.id),
                onMenuAction: {
                    triggerActionSheet(for: video)
                },
                itemSize: GridLayout.itemSize(for: width, isLandscape: isLandscape)
            )
        }
    }
    
    private func triggerActionSheet(for video: VideoItem) {
        viewModel.actionSheetTarget = .video(video)
        var items: [CustomActionItem] = []
        
        items.append(CustomActionItem(title: "Rename", icon: "pencil", role: nil, action: {
            videoToRename = video
            newVideoName = video.title
            showRenameVideoAlert = true
        }))
        
        items.append(CustomActionItem(title: "Share", icon: "square.and.arrow.up", role: nil, action: {
            viewModel.shareVideo(item: video)
        }))
        
        items.append(CustomActionItem(title: "Copy to", icon: "doc.on.doc", role: nil, action: {
            viewModel.copyVideos(ids: Set([video.id]), isCut: false, sourceURL: viewModel.importedVideosDirectory)
            viewModel.showMovePicker = true
        }))
        
        items.append(CustomActionItem(title: "Move to", icon: "arrow.right.doc.on.clipboard", role: nil, action: {
            viewModel.copyVideos(ids: Set([video.id]), isCut: true, sourceURL: viewModel.importedVideosDirectory)
            viewModel.showMovePicker = true
        }))
        
        items.append(CustomActionItem(title: "Delete", icon: "trash", role: .destructive, action: {
            videoToDelete = video
            showDeleteVideoAlert = true
        }))
        
        viewModel.actionSheetItems = items
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            viewModel.showActionSheet = true
        }
    }
    
    private func handleVideoTap(_ video: VideoItem) {
        if viewModel.isSelectionMode {
            HapticsManager.shared.generate(.selection)
            if viewModel.selectedVideoIds.contains(video.id) {
                viewModel.selectedVideoIds.remove(video.id)
            } else {
                viewModel.selectedVideoIds.insert(video.id)
            }
        } else {
            // Setup playlist context: All imported videos (sorted)
            HapticsManager.shared.generate(.medium)
            viewModel.currentPlaylist = viewModel.sortedImportedVideos
            viewModel.playingVideo = video
        }
    }
    
    private func deleteSelected() {
        showDeleteSelectedAlert = true
    }

    @ViewBuilder
    private var dateSortButtons: some View {
        Button {
            viewModel.videoSortOptionRaw = "Newest First"
        } label: {
            HStack {
                Text("Newest First")
                if viewModel.videoSortOptionRaw == "Newest First" { Image(systemName: "checkmark") }
            }
        }
        .menuActionDismissBehavior(.disabled)
        
        Button {
            viewModel.videoSortOptionRaw = "Oldest First"
        } label: {
            HStack {
                Text("Oldest First")
                if viewModel.videoSortOptionRaw == "Oldest First" { Image(systemName: "checkmark") }
            }
        }
        .menuActionDismissBehavior(.disabled)
    }

    @ViewBuilder
    private var nameSortButtons: some View {
        Button {
            viewModel.videoSortOptionRaw = "Name (A-Z)"
        } label: {
            HStack {
                Text("A to Z")
                if viewModel.videoSortOptionRaw == "Name (A-Z)" { Image(systemName: "checkmark") }
            }
        }
        .menuActionDismissBehavior(.disabled)
        
        Button {
            viewModel.videoSortOptionRaw = "Name (Z-A)"
        } label: {
            HStack {
                Text("Z to A")
                if viewModel.videoSortOptionRaw == "Name (Z-A)" { Image(systemName: "checkmark") }
            }
        }
        .menuActionDismissBehavior(.disabled)
    }

    @ViewBuilder
    private var lengthSortButtons: some View {
        Button {
            viewModel.videoSortOptionRaw = "Duration (Long to Short)"
        } label: {
            HStack {
                Text("Long to Short")
                if viewModel.videoSortOptionRaw == "Duration (Long to Short)" { Image(systemName: "checkmark") }
            }
        }
        .menuActionDismissBehavior(.disabled)
        
        Button {
            viewModel.videoSortOptionRaw = "Duration (Short to Long)"
        } label: {
            HStack {
                Text("Short to Long")
                if viewModel.videoSortOptionRaw == "Duration (Short to Long)" { Image(systemName: "checkmark") }
            }
        }
        .menuActionDismissBehavior(.disabled)
    }

    @ViewBuilder
    private var sizeSortButtons: some View {
        Button {
            viewModel.videoSortOptionRaw = "Size (Large to Small)"
        } label: {
            HStack {
                Text("Large to Small")
                if viewModel.videoSortOptionRaw == "Size (Large to Small)" { Image(systemName: "checkmark") }
            }
        }
        .menuActionDismissBehavior(.disabled)
        
        Button {
            viewModel.videoSortOptionRaw = "Size (Small to Large)"
        } label: {
            HStack {
                Text("Small to Large")
                if viewModel.videoSortOptionRaw == "Size (Small to Large)" { Image(systemName: "checkmark") }
            }
        }
        .menuActionDismissBehavior(.disabled)
    }
    @ViewBuilder
    private var recentsSortButton: some View {
        Button {
            viewModel.videoSortOptionRaw = "Recents"
        } label: {
            HStack {
                Label("Recently Accessed", systemImage: "clock.arrow.circlepath")
                if viewModel.videoSortOptionRaw == "Recents" {
                    Image(systemName: "checkmark")
                }
            }
        }
        .menuActionDismissBehavior(.disabled)
    }
}
