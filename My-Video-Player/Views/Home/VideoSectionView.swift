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
    @State private var newVideoName = ""
    
    @AppStorage("isGridView") private var isGridView: Bool = true
    @State private var showSortSheet: Bool = false
    @State private var showSearch = false
    @State private var showImportOptions = false

    var body: some View {
        ZStack {
            Color.themeBackground.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                if viewModel.isSelectionMode {
                    selectionHeader
                }
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            if viewModel.importedVideos.isEmpty && !viewModel.isImporting {
                                emptyStateView
                            } else if isGridView {
                                contentView
                            } else {
                                listView
                            }
                        }
                        .padding(.top)
                        .padding(.bottom, 100)
                    }
                    .onChange(of: viewModel.highlightVideoId) { oldId, newId in
                        if let id = newId {
                            withAnimation(.spring()) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                            // Reset highlight after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                viewModel.highlightVideoId = nil
                            }
                        }
                    }
                }
            }
            
            if viewModel.isSelectionMode {
                selectionActionBar
            }
            
            // Syncing Overlay
            if viewModel.isImporting {
                ZStack {
                    Color.black.opacity(0.6)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                            .scaleEffect(1.5)
                        
                        Text("Syncing...")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(40)
                    .background(Color.themeSurface)
                    .cornerRadius(20)
                    .shadow(radius: 20)
                }
                .transition(.opacity)
            }
        }
        .background(Color.themeBackground)
        .sheet(isPresented: $showSortSheet) {
            CustomSortingView(sortOptionRaw: $viewModel.videoSortOptionRaw, title: "Videos")
        }
        .sheet(item: $videoToMove) { video in
            MoveToFolderSheet(viewModel: viewModel, video: video)
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
    }
    
    var isAllSelected: Bool {
        return !viewModel.importedVideos.isEmpty && viewModel.selectedVideoIds.count == viewModel.importedVideos.count
    }
    
    // MARK: - Headers
    
    private var expandedHeader: some View {
        HStack {
            Text("Videos")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            HStack(spacing: 20) {
                Button(action: { showSearch = true }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                .navigationDestination(isPresented: $showSearch) {
                    SearchView(viewModel: viewModel, contextTitle: "Videos", initialVideos: viewModel.importedVideos)
                }
                
                Button(action: { showImportOptions = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.orange)
                }
                
                Menu {
                    Button(action: { showSortSheet = true }) {
                        Label("Sort by", systemImage: "arrow.up.arrow.down")
                    }
                    
                    Button(action: { isGridView.toggle() }) {
                        Label(isGridView ? "List View" : "Grid View", systemImage: isGridView ? "list.bullet" : "square.grid.2x2")
                    }
                    
                    Button(action: { viewModel.isSelectionMode = true }) {
                        Label("Select", systemImage: "checkmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.themeBackground)
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
                        .stroke(Color.white, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    
                    if isAllSelected {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(10)
            }
            
            Spacer()
            
            let allVideos = viewModel.importedVideos
            Text("Selected (\(viewModel.selectedVideoIds.count)/\(allVideos.count))")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button("Done") {
                viewModel.isSelectionMode = false
                viewModel.selectedVideoIds.removeAll()
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.orange)
            .padding(10) // Larger hit area
        }
        .padding(.horizontal, 5)
        .padding(.bottom, 10)
        .background(Color.themeBackground)
    }
    
    private var selectionActionBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 0) {
                selectionBarItem(icon: "trash", title: "Delete", action: { deleteSelected() })
                
                selectionBarItem(icon: "doc.on.doc", title: "Copy", action: { 
                    viewModel.copyVideos(ids: viewModel.selectedVideoIds, isCut: false, sourceURL: viewModel.importedVideosDirectory)
                })

                selectionBarItem(icon: "arrow.right.doc.on.clipboard", title: "Move", action: { 
                    viewModel.copyVideos(ids: viewModel.selectedVideoIds, isCut: true, sourceURL: viewModel.importedVideosDirectory)
                    viewModel.showMovePicker = true
                })

                selectionBarItem(icon: "square.and.arrow.up", title: "Share", action: { viewModel.shareSelectedVideos() })
            }
            .padding(.top, 12)
            .padding(.bottom, 25)
            .background(Color.themeSurface)
            .cornerRadius(20, corners: [.topLeft, .topRight])
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: -5)
        }
        .edgesIgnoringSafeArea(.bottom)
        .transition(.move(edge: .bottom))
    }
    
    private func selectionBarItem(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10) // Larger hit area
        }
        .disabled(viewModel.selectedVideoIds.isEmpty)
        .opacity(viewModel.selectedVideoIds.isEmpty ? 0.5 : 1.0)
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 50)
            Image(systemName: "video.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No Videos Imported")
                .font(.headline)
                .foregroundColor(.gray)
            Text("Import videos to start watching")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }
    
    private var contentView: some View {
        VStack(spacing: 20) {
            videosGrid
        }
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
                    .background(Color.gray.opacity(0.2))
                    .overlay(Color.black.opacity(0.3))
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("All Videos")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("\(viewModel.importedVideos.count) Videos")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.black.opacity(0.6))
                        }
                    )
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
    
    private var videosGrid: some View {
        LazyVStack(alignment: .leading, spacing: 15, pinnedViews: [.sectionHeaders]) {
            ForEach(viewModel.groupedImportedVideos) { section in
                Section(header: sectionHeader(for: section.date)) {
                    LazyVGrid(columns: GridLayout.gridColumns, spacing: GridLayout.spacing) {
                         ForEach(section.videos) { video in
                             videoItemView(for: video)
                         }
                    }
                    .padding(.horizontal, GridLayout.horizontalPadding)
                }
            }
        }
    }
    
    private var listView: some View {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(viewModel.groupedImportedVideos) { section in
                Section(header: sectionHeader(for: section.date)) {
                    ForEach(section.videos) { video in
                        videoRow(video)
                    }
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
                Text(formattedSectionDate(date))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                    .padding(.vertical, 10)
                    .padding(.horizontal)
                Spacer()
            }
            .background(Color.themeBackground)
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
    
    private func videoItemView(for video: VideoItem) -> some View {
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
                }
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
        }))
        
        items.append(CustomActionItem(title: "Move", icon: "arrow.right.doc.on.clipboard", role: nil, action: {
            viewModel.copyVideos(ids: Set([video.id]), isCut: true, sourceURL: viewModel.importedVideosDirectory)
            videoToMove = video
            viewModel.showMovePicker = true
        }))
        
        items.append(CustomActionItem(title: "Delete", icon: "trash", role: .destructive, action: {
            videoToDelete = video
            showDeleteVideoAlert = true
        }))
        
        viewModel.actionSheetItems = items
        viewModel.showActionSheet = true
    }
    
    private func handleVideoTap(_ video: VideoItem) {
        if viewModel.isSelectionMode {
            if viewModel.selectedVideoIds.contains(video.id) {
                viewModel.selectedVideoIds.remove(video.id)
            } else {
                viewModel.selectedVideoIds.insert(video.id)
            }
        } else {
            // Setup playlist context: All imported videos
            viewModel.currentPlaylist = viewModel.importedVideos
            viewModel.playingVideo = video
        }
    }
    
    private func deleteSelected() {
        let allVideos = viewModel.importedVideos + viewModel.allGalleryVideos
        let selectedVideos = allVideos.filter { viewModel.selectedVideoIds.contains($0.id) }
        for video in selectedVideos {
            viewModel.deleteVideo(video)
        }
        viewModel.isSelectionMode = false
        viewModel.selectedVideoIds.removeAll()
    }
    
}
