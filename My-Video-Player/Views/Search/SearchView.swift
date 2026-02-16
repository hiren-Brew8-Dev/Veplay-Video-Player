import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var isSearchFocused: Bool
    
    // Context can be used to filter search specifically for a folder or album
    var contextTitle: String = ""
    var initialVideos: [VideoItem]? = nil 
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let currentWidth = geometry.size.width
            
            ZStack {
                Color.homeBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Header
                    customHeader
                    
                    // Custom Search Bar
                    customSearchBar
                        .padding(.horizontal, AppDesign.Icons.horizontalPadding)
                        .padding(.bottom, isIpad ? 24 : 16)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            if viewModel.searchText.isEmpty {
                                // History Section
                                if !viewModel.searchHistoryKeywords.isEmpty {
                                    historySection
                                }
                            } else {
                                // Results Section
                                resultsSection(isLandscape: isLandscape, currentWidth: currentWidth)
                            }
                        }
                        .padding(.top, 10)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if viewModel.selectedTab == .search {
                    viewModel.isTabBarHidden = false
                } else {
                    viewModel.isTabBarHidden = true
                }
                viewModel.searchText = "" // Reset on every open
                isSearchFocused = true
            }
            .onDisappear {
                if viewModel.selectedTab != .search {
                    viewModel.isTabBarHidden = false
                }
                // Auto-save search keyword when navigating back
                let trimmedText = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedText.isEmpty {
                    viewModel.persistSearchKeyword(trimmedText)
                }
            }
        }
    }
    
    // MARK: - Custom Header & Search
    
    private var customHeader: some View {
        HStack {
            Button(action: {
                if viewModel.selectedTab == .search {
                    // If in Search Tab, switch back to the previous tab
                    viewModel.selectedTab = viewModel.lastActiveDataTab
                } else {
                    navigationManager.pop()
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
            
            Text("Search in \(contextTitle.isEmpty ? viewModel.lastActiveDataTab.rawValue : contextTitle)")
                .font(.system(size: isIpad ? 24 : 18, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.leading, 8)
            
            Spacer()
        }
        .padding(.horizontal, AppDesign.Icons.horizontalPadding)
        .padding(.vertical, isIpad ? 20 : 10)
        .background(Color.clear)
    }
    
    private var customSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.5))
            
            TextField("Search", text: $viewModel.searchText)
                .font(.system(size: isIpad ? 20 : 16))
                .foregroundColor(.white)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onSubmit {
                    if !viewModel.searchText.isEmpty {
                        viewModel.persistSearchKeyword(viewModel.searchText)
                    }
                }
            
            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("History")
                    .font(.system(size: isIpad ? 24 : 18, weight: .bold))
                    .foregroundColor(.homeTextPrimary)
                
                Spacer()
                
                Button(action: {
                    viewModel.clearSearchHistory()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal)
            
            FlexibleView(
                data: viewModel.searchHistoryKeywords,
                spacing: 10,
                alignment: .leading
            ) { keyword in
                Button(action: {
                    viewModel.searchText = keyword
                    viewModel.persistSearchKeyword(keyword)
                    isSearchFocused = false
                }) {
                    Text(keyword)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func resultsSection(isLandscape: Bool, currentWidth: CGFloat) -> some View {
        // Always show video results, even for Folders tab
        videoResultsSection(isLandscape: isLandscape, currentWidth: currentWidth)
    }

    @ViewBuilder
    private func videoResultsSection(isLandscape: Bool, currentWidth: CGFloat) -> some View {
        let baseVideos: [VideoItem] = {
            if let initialVideos = initialVideos {
                return initialVideos
            }
            
            // STRICT Context Filtering
            if viewModel.lastActiveDataTab == .home {
                return viewModel.importedVideos // Only Imported Videos
            } else if viewModel.lastActiveDataTab == .gallery {
                return viewModel.allGallerySearchableVideos // Only Gallery
            } else if viewModel.lastActiveDataTab == .folders {
                 // Flatten all folders to get all videos
                 return viewModel.folders.flatMap { $0.videos }
            } else {
                 return []
            }
        }()
        
        let query = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = baseVideos.filter { video in
            if query.isEmpty { return true }
            return video.title.localizedCaseInsensitiveContains(query) ||
            (video.url?.lastPathComponent.localizedCaseInsensitiveContains(query) ?? false)
        }
        
        VStack(alignment: .leading, spacing: 16) {
            if filtered.isEmpty {
                emptyResultsView
            } else {
                if isIpad {
                    LazyVGrid(columns: GridLayout.gridColumns(isLandscape: isLandscape), spacing: GridLayout.spacing(isLandscape: isLandscape)) {
                        ForEach(filtered) { video in
                            Button(action: {
                                isSearchFocused = false
                                viewModel.currentPlaylist = filtered
                                viewModel.playingVideo = video
                            }) {
                                VideoCardView(
                                    video: video,
                                    viewModel: viewModel,
                                    onMenuAction: {
                                        isSearchFocused = false
                                        viewModel.actionSheetTarget = .video(video)
                                        viewModel.actionSheetItems = viewModel.videoActions(for: video)
                                        viewModel.showActionSheet = true
                                    },
                                    itemSize: GridLayout.itemSize(for: currentWidth, isLandscape: isLandscape)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered.indices, id: \.self) { index in
                            let video = filtered[index]
                            Button(action: {
                                isSearchFocused = false
                                viewModel.currentPlaylist = filtered
                                viewModel.playingVideo = video
                            }) {
                                VideoRowView(
                                    video: video,
                                    viewModel: viewModel,
                                    onMenuAction: {
                                        isSearchFocused = false
                                        viewModel.actionSheetTarget = .video(video)
                                        viewModel.actionSheetItems = viewModel.videoActions(for: video)
                                        viewModel.showActionSheet = true
                                    }
                                )
                            }
                            .buttonStyle(.scalable)
                            
                            if index < filtered.count - 1 {
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
    
    private var emptyResultsView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 100)
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 44))
                    .foregroundColor(.white.opacity(0.2))
            }
            
            Text("No results found for \"\(viewModel.searchText)\"")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}


// Improved FlowLayout implementation
struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        ZStack(alignment: Alignment(horizontal: alignment, vertical: .center)) {
            Color.clear
                .frame(height: 1)
                .readSize { size in
                    availableWidth = size.width
                }

            _FlexibleView(
                availableWidth: availableWidth,
                data: data,
                spacing: spacing,
                alignment: alignment,
                content: content
            )
        }
    }
}

struct _FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let availableWidth: CGFloat
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content
    @State private var elementsSize: [Data.Element: CGSize] = [:]

    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            ForEach(computeRows(), id: \.self) { rowElements in
                HStack(spacing: spacing) {
                    ForEach(rowElements, id: \.self) { element in
                        content(element)
                            .fixedSize()
                            .readSize { size in
                                elementsSize[element] = size
                            }
                    }
                }
            }
        }
    }

    private func computeRows() -> [[Data.Element]] {
        var rows: [[Data.Element]] = [[]]
        var currentRowWidth: CGFloat = 0

        for element in data {
            let elementWidth = elementsSize[element]?.width ?? 0
            if currentRowWidth + elementWidth + spacing > availableWidth {
                if !rows[0].isEmpty {
                    rows.append([element])
                    currentRowWidth = elementWidth
                } else {
                    rows[rows.count - 1].append(element)
                    currentRowWidth += elementWidth + spacing
                }
            } else {
                rows[rows.count - 1].append(element)
                currentRowWidth += elementWidth + spacing
            }
        }

        return rows
    }
}

extension View {
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometry.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}
