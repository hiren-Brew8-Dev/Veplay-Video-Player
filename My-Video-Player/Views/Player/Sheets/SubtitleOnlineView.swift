import SwiftUI

struct SubtitleOnlineView: View {
    @Binding var isPresented: Bool
    @ObservedObject var subtitleManager: SubtitleManager
    let isLandscape: Bool // Add this prop
    
    @StateObject private var yifyService = YIFYSubtitleService()
    @State private var searchText = ""
    @State private var selectedLanguage = "en"
    @State private var showLanguagePicker = false
    @State private var selectedMovie: YIFYSubtitle? // Track selected movie for 2-step flow
    
    // Download state tracking
    @State private var downloadingIds: Set<UUID> = []
    @State private var downloadedIds: Set<UUID> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle (Portrait)
            if !isLandscape {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
            }
            
            // Header
            HStack {
                StandardIconButton(icon: "chevron.left", action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                })
                
                Spacer()
                
                Text("Online Search")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Invisible spacer for balance
                StandardIconButton(icon: "chevron.left", color: .clear, bg: .clear, action: {})
            }
            .padding(.horizontal)
            
            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.bottom, 16)
            
            onlineSearchView
        }
        .padding(.trailing, isLandscape ? 30 : 0)
        .background(Color(UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)))
        .if(isLandscape) { view in
             view.cornerRadiusLocal(20, corners: [.topLeft, .bottomLeft])
        }
        .if(!isLandscape) { view in
             view.cornerRadiusLocal(20, corners: [.topLeft, .topRight])
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet(selectedLanguageCode: $selectedLanguage, isPresented: $showLanguagePicker)
                .presentationDetents([.medium, .large])
        }
    }
    

    
    // MARK: - Online View
    @State private var subtitlesList: [YIFYSubtitle] = []
    
    var onlineSearchView: some View {
        VStack(spacing: 0) {
            // Search Area
            VStack(alignment: .leading, spacing: 12) {
                // Info Row
                HStack {
                    Link(destination: URL(string: "https://yifysubtitles.org")!) {
                        HStack(spacing: 4) {
                            Text("Source: YIFY Subtitles")
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption2)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    Spacer()
                }
                
                // Search Bar
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search movie...", text: $searchText)
                            .foregroundColor(.white)
                            .submitLabel(.search)
                            .onSubmit {
                                hideKeyboard()
                                selectedMovie = nil
                                yifyService.search(query: searchText)
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)
                    
                    Button("Search") {
                        hideKeyboard()
                        selectedMovie = nil
                        yifyService.search(query: searchText)
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
            
            Divider().background(Color.gray.opacity(0.3))
            
            // Content
            if yifyService.isLoading {
                Spacer()
                ProgressView().scaleEffect(1.2).padding()
                Spacer()
            } else if let movie = selectedMovie {
                // Movie Selected - Show Subtitles
                VStack(spacing: 0) {
                    // Back Button
                    Button(action: {
                        withAnimation { selectedMovie = nil }
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back to Results")
                        }
                        .foregroundColor(.blue)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider().background(Color.gray.opacity(0.3))
                    
                    if subtitlesList.isEmpty {
                         Spacer()
                         Text("No subtitles found for this movie.").foregroundColor(.gray)
                         Spacer()
                    } else {
                        List {
                            ForEach(subtitlesList) { sub in
                                onlineResultRow(
                                    title: sub.title,
                                    lang: sub.language,
                                    isDownloading: downloadingIds.contains(sub.id),
                                    isDownloaded: downloadedIds.contains(sub.id)
                                ) {
                                    handleSubtitleDownload(sub)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.visible)
                                .listRowSeparatorTint(.gray.opacity(0.3))
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            } else if !yifyService.searchResults.isEmpty {
                // Show Movie Results
                List {
                    ForEach(yifyService.searchResults) { item in
                        Button(action: {
                            handleMovieTap(item)
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.title)
                                        .foregroundColor(.white)
                                        .font(.headline)
                                    Text("Select to view subtitles")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.visible)
                        .listRowSeparatorTint(.gray.opacity(0.3))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else {
                Spacer()
                Text("Search for a movie above.").foregroundColor(.gray)
                Spacer()
            }
        }
    }
    
    func handleMovieTap(_ item: YIFYSubtitle) {
        selectedMovie = item
        yifyService.fetchSubtitles(for: item.url) { subs in
            // Filter common languages if needed, or sort
            self.subtitlesList = subs.sorted { $0.language < $1.language }
        }
    }
    
    func handleSubtitleDownload(_ sub: YIFYSubtitle) {
        downloadingIds.insert(sub.id)
        yifyService.downloadSubtitle(from: sub.url) { url in
            downloadingIds.remove(sub.id)
            if let url = url {
                downloadedIds.insert(sub.id)
                subtitleManager.loadSubtitle(from: url)
                
                // Show success toast or dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                     isPresented = false
                }
            }
        }
    }
    
    // MARK: - Downloaded View

    
    func onlineResultRow(title: String, lang: String, isDownloading: Bool, isDownloaded: Bool, onDownload: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 16))
                    .lineLimit(1)
                Text(lang)
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            Spacer()
            
            if isDownloading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            } else if isDownloaded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 20))
            } else {
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.to.line")
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    func languageName(for code: String) -> String {
        let langs = [
            "en": "English", "hi": "Hindi", "es": "Spanish", "fr": "French",
            "de": "German", "it": "Italian", "zh": "Chinese", "ms": "Malay"
        ]
        return langs[code] ?? code
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
