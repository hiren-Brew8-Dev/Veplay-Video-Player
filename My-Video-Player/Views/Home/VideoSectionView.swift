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
            Color.clear.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                if viewModel.isSelectionMode {
                    selectionHeader
                }
                
                if viewModel.importedVideos.isEmpty && !viewModel.isImporting {
                    emptyStateView
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 20) {
                                if isGridView {
                                    contentView
                                } else {
                                    listView
                                }
                            }
                            .padding(.bottom, 90)
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
            }
            
            if viewModel.isSelectionMode {
                selectionActionBar
            }
            
            // Syncing Overlay

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
        .background(Color.clear)
        .ignoresSafeArea(edges: .bottom)
    }
    
    var isAllSelected: Bool {
        return !viewModel.importedVideos.isEmpty && viewModel.selectedVideoIds.count == viewModel.importedVideos.count
    }
    
    // MARK: - Headers
    
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
                    
                    Button(action: { isGridView = true }) {
                        Label("Grid", systemImage: "square.grid.2x2")
                    }
                    .accentColor(isGridView ? .orange : .white)
                    
                    Button(action: { isGridView = false }) {
                        Label("List", systemImage: "list.bullet")
                    }
                    .accentColor(!isGridView ? .orange : .white)
                    
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
            .padding(.trailing, 10)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
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
                        .fill(viewModel.selectedVideoIds.isEmpty ? Color.white.opacity(0.05) : Color.orange.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(viewModel.selectedVideoIds.isEmpty ? .white.opacity(0.3) : .orange)
                }
                
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(viewModel.selectedVideoIds.isEmpty ? .white.opacity(0.3) : .white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10) // Larger hit area
        }
        .disabled(viewModel.selectedVideoIds.isEmpty)
        .opacity(viewModel.selectedVideoIds.isEmpty ? 0.5 : 1.0)
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 80)
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "video.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.2))
                }
                
                VStack(spacing: 8) {
                    Text("No Videos Imported")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Start by importing videos from your photos\nor files to build your local library.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 40)
                
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
                    .shadow(color: Color.homeAccent.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
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
                    .padding(.horizontal, 10)
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
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.homeTextSecondary)
                    .padding(.horizontal, 4)
                Spacer()
            }
            .padding(.top, 24)
            .padding(.bottom, 12)
            .padding(.horizontal, 10)
            .background(Color.clear)
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
        let allVideos = viewModel.importedVideos + viewModel.allGalleryVideos
        let selectedVideos = allVideos.filter { viewModel.selectedVideoIds.contains($0.id) }
        for video in selectedVideos {
            viewModel.deleteVideo(video)
        }
        viewModel.isSelectionMode = false
        viewModel.selectedVideoIds.removeAll()
    }
}
