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
    
    // Selection State
    @State private var selectedVideoIds = Set<UUID>()
    @State private var showShareSheet = false
    
    
    
    var isAllSelected: Bool {
        return !viewModel.importedVideos.isEmpty && selectedVideoIds.count == viewModel.importedVideos.count
    }
    
    @AppStorage("isGridView") private var isGridView: Bool = true
    @State private var showSortSheet: Bool = false
    @Binding var isHeaderExpanded: Bool
    @State private var showSearch = false

    var body: some View {
        ZStack {
            Color.themeBackground.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                if viewModel.isSelectionMode {
                    selectionHeader
                } else if isHeaderExpanded {
                    expandedHeader
                }
                
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
        .sheet(isPresented: $showShareSheet) {
            let items = viewModel.importedVideos.filter { selectedVideoIds.contains($0.id) }.compactMap { $0.url }
            ShareSheet(activityItems: items)
        }
        .background(Color.themeBackground)
        .sheet(isPresented: $showSortSheet) {
            CustomSortingView(sortOptionRaw: $viewModel.sortOptionRaw, title: "Videos")
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
    
    // MARK: - Headers
    
    private var expandedHeader: some View {
        HStack {
            Text("Videos")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: { viewModel.isSelectionMode = true }) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                }
                
                Button(action: { showSearch = true }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                .navigationDestination(isPresented: $showSearch) {
                    SearchView(viewModel: viewModel, contextTitle: "Videos")
                }
                
                Button(action: { showSortSheet = true }) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                }
                
                Button(action: { isGridView.toggle() }) {
                    Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                }
                
                Button(action: {
                    withAnimation(.spring()) {
                        isHeaderExpanded.toggle()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.orange)
                        .clipShape(Circle())
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
                if isAllSelected {
                    selectedVideoIds.removeAll()
                } else {
                    selectedVideoIds = Set(viewModel.importedVideos.map { $0.id })
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
            
            Text("Selected (\(selectedVideoIds.count)/\(viewModel.importedVideos.count))")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button("Done") {
                viewModel.isSelectionMode = false
                selectedVideoIds.removeAll()
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.orange)
            .padding(.trailing, 10)
        }
        .padding(.horizontal, 5)
        .padding(.bottom, 10)
        .background(Color.themeBackground)
    }
    
    private var selectionActionBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 0) {
                selectionBarItem(icon: "text.badge.plus", title: "AddtoPlaylist", action: { 
                    print("Add to Playlist dummy")
                })
                
                selectionBarItem(icon: "trash", title: "Delete", action: { deleteSelected() })
                
                selectionBarItem(icon: "music.note.list", title: "Get Mp3", action: {
                     print("Get Mp3 dummy")
                })
                
                selectionBarItem(icon: "square.and.arrow.up", title: "Share", action: { showShareSheet = true })
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
        }
        .disabled(selectedVideoIds.isEmpty)
        .opacity(selectedVideoIds.isEmpty ? 0.5 : 1.0)
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
                    .padding(.horizontal, 10)
                }
            }
        }
        .padding(.bottom, paddingBottom)
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
        .padding(.bottom, paddingBottom + 80)
    }

    
    private func sectionHeader(for date: Date) -> some View {
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
                isSelected: selectedVideoIds.contains(video.id),
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
                isSelected: selectedVideoIds.contains(video.id),
                onMenuAction: {
                    triggerActionSheet(for: video)
                }
            )
        }
    }
    
    private func triggerActionSheet(for video: VideoItem) {
        viewModel.actionSheetTarget = .video(video)
        viewModel.actionSheetItems = [
            CustomActionItem(title: "Rename", icon: "pencil", role: nil, action: {
                videoToRename = video
                newVideoName = video.title
                showRenameVideoAlert = true
            }),
            CustomActionItem(title: "Share", icon: "square.and.arrow.up", role: nil, action: {
                viewModel.shareVideo(item: video)
            }),
            CustomActionItem(title: "Delete", icon: "trash", role: .destructive, action: {
                videoToDelete = video
                showDeleteVideoAlert = true
            })
        ]
        viewModel.showActionSheet = true
    }
    
    private func handleVideoTap(_ video: VideoItem) {
        if viewModel.isSelectionMode {
            if selectedVideoIds.contains(video.id) {
                selectedVideoIds.remove(video.id)
            } else {
                selectedVideoIds.insert(video.id)
            }
        } else {
            // Setup playlist context: All imported videos
            viewModel.currentPlaylist = viewModel.importedVideos
            viewModel.playingVideo = video
        }
    }
    
    private func deleteSelected() {
        let selectedVideos = viewModel.importedVideos.filter { selectedVideoIds.contains($0.id) }
        for video in selectedVideos {
            viewModel.deleteVideo(video)
        }
        viewModel.isSelectionMode = false
        selectedVideoIds.removeAll()
    }
    
}
