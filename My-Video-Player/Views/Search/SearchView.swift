import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var isSearchFocused: Bool
    
    // Context can be used to filter search specifically for a folder or album
    var contextTitle: String = "Video&Music"
    var initialVideos: [VideoItem]? = nil 
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar Header
            searchBarHeader
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if viewModel.searchText.isEmpty {
                        // History Section
                        if !viewModel.searchHistoryKeywords.isEmpty {
                            historySection
                        }
                    } else {
                        // Results Section
                        resultsSection
                    }
                }
                .padding(.top, 20)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .background(Color.homeBackground.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        .onAppear {
            viewModel.isTabBarHidden = true
            viewModel.searchText = "" // Reset on every open
            isSearchFocused = true
        }
        .onTapGesture {
            isSearchFocused = false
        }
        .onDisappear {
            viewModel.isTabBarHidden = false
            // Auto-save search keyword when navigating back
            let trimmedText = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedText.isEmpty {
                viewModel.persistSearchKeyword(trimmedText)
            }
        }
    }
    
    private var searchBarHeader: some View {
        HStack(spacing: 12) {
            StandardIconButton(icon: "chevron.left", action: {
                presentationMode.wrappedValue.dismiss()
            })
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .appSecondaryIconStyle(size: AppDesign.Icons.rowIconSize)
                
                TextField("Keyword of \(contextTitle)", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.homeTextPrimary)
                    .focused($isSearchFocused)
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
                            .appSecondaryIconStyle(size: AppDesign.Icons.rowIconSize)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.3))
            .cornerRadius(20)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.homeBackground)
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("History")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.homeTextPrimary)
                
                Spacer()
                
                Button(action: {
                    viewModel.clearSearchHistory()
                }) {
                    Image(systemName: "trash")
                        .appSecondaryIconStyle(size: AppDesign.Icons.rowIconSize)
                        .padding(8)
                        .background(Color.homeCardBackground)
                        .clipShape(Circle())
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
                        .font(.system(size: 14))
                        .foregroundColor(.homeTextPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.homeCardBackground)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var resultsSection: some View {
        let baseVideos: [VideoItem] = {
            let sources: [VideoItem]
            if let initial = initialVideos {
                sources = initial
            } else {
                sources = viewModel.videos
            }
            
            // Re-resolve from viewModel.videos to get latest titles
            return sources.map { video in
                if let latest = viewModel.videos.first(where: { $0.id == video.id }) {
                    return latest
                }
                return video
            }
        }()
        
        let query = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = baseVideos.filter {
            query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
        }
        
        VStack(alignment: .leading, spacing: 16) {
            if filtered.isEmpty {
                VStack(spacing: 20) {
                    Spacer().frame(height: 100)
                    Image(systemName: "magnifyingglass")
                        .appSecondaryIconStyle(size: 60, color: .homeTextSecondary.opacity(0.3))
                    Text("No results found for \"\(viewModel.searchText)\"")
                        .foregroundColor(.homeTextSecondary)
                }
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: GridLayout.gridColumns, spacing: GridLayout.spacing) {
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
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 15)
            }
        }
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
