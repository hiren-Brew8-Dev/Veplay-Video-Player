import SwiftUI
import PhotosUI

struct VideoSectionView: View {
    @ObservedObject var viewModel: DashboardViewModel
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
            
            ZStack {
//            Color.clear.edgesIgnoringSafeArea(.all)
            
                VStack(spacing: 0) {
                    // Header
                    if viewModel.isSelectionMode {
                        selectionHeader
                    } else if !viewModel.groupedImportedVideos.isEmpty && !viewModel.isInitialLoading {
                         Divider()
                             .background(Color.white.opacity(0.1))
                         
                         // Utility Row (Sort, View Mode, Selection) - Fixed
                        utilityRow
                            .padding(.horizontal, AppDesign.Icons.horizontalPadding)
                            .padding(.top, 10)
                            .padding(.bottom, 10)
                            .background(Color.homeBackground) // Ensure opaque background
                    }
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 24) {
                                // Content Start
                                
                                // Imported Videos Section
                                if viewModel.importedVideos.isEmpty && !viewModel.isImporting && !viewModel.isInitialLoading {
                                    emptyStateView
                                        .frame(minHeight: geometry.size.height * 0.6)
                                } else if !viewModel.isInitialLoading || !viewModel.importedVideos.isEmpty {
                                    if viewModel.isGridView {
                                        videosGrid(isLandscape: isLandscape, width: currentWidth)
                                    } else {
                                        listView(isLandscape: isLandscape)
                                    }
                                }
                            }
                            .padding(.bottom, viewModel.isSelectionMode ? 140 : 100)
                        }
                        .onChange(of: viewModel.highlightVideoId) { oldId, newId in
                            if let id = newId {
                                withAnimation(.spring()) {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                            }
                        }
                    }
                }
                
                if viewModel.isSelectionMode {
                    selectionActionBar
                }
                
                // Syncing Overlay

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
                let allVideos = viewModel.importedVideos + viewModel.allGalleryVideos
                let selectedVideos = allVideos.filter { viewModel.selectedVideoIds.contains($0.id) }
                for video in selectedVideos {
                    viewModel.deleteVideo(video)
                }
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
        HStack {
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
            
            HStack(spacing: isIpad ? 10 : 8) {
                // View Mode Toggle (Direct Icon)
                Button(action: {
                    withAnimation {
                        viewModel.isGridView.toggle()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: viewModel.isGridView ? "list.bullet" : "square.grid.2x2")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                // Vertical Divider
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 24)
                    
                
                // Selection Mode
                Button(action: {
                    withAnimation {
                        viewModel.isSelectionMode = true
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "pencil") // Using pencil as per image analysis (edit/select)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    // Previous Folders Code Removed

    private var expandedHeader: some View {
        HStack {
            Text("Videos")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.homeTextPrimary)
            
            Spacer()
            
            HStack(spacing: 20) {
                Button(action: { showSearch = true }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(.homeTint)
                }
                .navigationDestination(isPresented: $showSearch) {
                    SearchView(viewModel: viewModel, contextTitle: "Videos", initialVideos: viewModel.importedVideos)
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
            
            Button("Done") {
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
                selectionBarItem(icon: "trash", title: "Delete", action: { deleteSelected() })
                
                selectionBarItem(icon: "doc.on.doc", title: "Copy", action: { 
                    viewModel.copyVideos(ids: viewModel.selectedVideoIds, isCut: false, sourceURL: viewModel.importedVideosDirectory)
                    viewModel.showMovePicker = true
                })

                selectionBarItem(icon: "arrow.right.doc.on.clipboard", title: "Move", action: { 
                    viewModel.copyVideos(ids: viewModel.selectedVideoIds, isCut: true, sourceURL: viewModel.importedVideosDirectory)
                    viewModel.showMovePicker = true
                })

                selectionBarItem(icon: "square.and.arrow.up", title: "Share", action: { viewModel.shareSelectedVideos() })
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
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "video.slash")
                    .font(.system(size: 44))
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
                        viewModel.showPhotoPicker = true
                    }) {
                        Label("Import from Photos", systemImage: "photo.on.rectangle")
                    }
                    
                    Button(action: {
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
                    .foregroundColor(.white)
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
//                    .shadow(color: Color.homeAccent.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
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
                    .background(Color.homeCardBackground)
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
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(viewModel.groupedImportedVideos) { section in
                Section {
                    VStack(spacing: 0) {
                        ForEach(section.videos.indices, id: \.self) { index in
                            videoRow(section.videos[index])
                            
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
                    .padding(.horizontal, isLandscape ? (isIpad ? 80 : 40) : 10)
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
            .padding(.horizontal, 10)
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
        
        items.append(CustomActionItem(title: "Copy", icon: "doc.on.doc", role: nil, action: {
            viewModel.copyVideos(ids: Set([video.id]), isCut: false, sourceURL: viewModel.importedVideosDirectory)
            viewModel.showMovePicker = true
        }))
        
        items.append(CustomActionItem(title: "Move", icon: "arrow.right.doc.on.clipboard", role: nil, action: {
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
            if viewModel.selectedVideoIds.contains(video.id) {
                viewModel.selectedVideoIds.remove(video.id)
            } else {
                viewModel.selectedVideoIds.insert(video.id)
            }
        } else {
            // Setup playlist context: All imported videos (sorted)
            viewModel.currentPlaylist = viewModel.sortedImportedVideos
            viewModel.playingVideo = video
        }
    }
    
    private func deleteSelected() {
        showDeleteSelectedAlert = true
    }
}
