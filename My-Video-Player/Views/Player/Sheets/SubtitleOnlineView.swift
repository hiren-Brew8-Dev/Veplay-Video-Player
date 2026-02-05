import SwiftUI

struct SubtitleOnlineView: View {
    @Binding var isPresented: Bool
    @ObservedObject var subtitleManager: SubtitleManager
    
    @StateObject private var osService = OpenSubtitlesService()
    @State private var searchText = ""
    @State private var selectedLanguage = "en"
    @State private var showLanguagePicker = false
    
    // Download state tracking
    @State private var downloadingFileIds: Set<Int> = []
    @State private var downloadedFileIds: Set<Int> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text("Online Search")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .foregroundColor(.blue)
            }
            .padding()
            .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)))
            
            onlineSearchView
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet(selectedLanguageCode: $selectedLanguage, isPresented: $showLanguagePicker)
                .presentationDetents([.medium, .large])
        }
    }
    
    // MARK: - Online View
    var onlineSearchView: some View {
        VStack(spacing: 0) {
            // Search Area
            VStack(alignment: .leading, spacing: 10) {
                Text("Search subtitle from: opensubtitles.org")
                    .foregroundColor(.orange)
                    .font(.caption)
                
                Button(action: { showLanguagePicker = true }) {
                    Text("Languages: \(languageName(for: selectedLanguage)) >")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                
                HStack {
                    TextField("Search...", text: $searchText)
                        .padding(8)
                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    
                    Button("Search") {
                        hideKeyboard()
                        osService.search(query: searchText, language: selectedLanguage)
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding()
            
            Divider().background(Color.gray)
            
            // List or Loader
            if osService.isLoading {
                Spacer()
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Loading...")
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(osService.searchResults) { result in
                            // Extract title and info (Updated for OSSubtitleItem)
                            let title = result.attributes.feature_details?.title ?? result.attributes.files?.first?.file_name ?? "Unknown"
                            let fileId = result.attributes.files?.first?.file_id ?? 0
                            let fileName = result.attributes.files?.first?.file_name ?? title
                            
                            onlineResultRow(
                                title: title,
                                lang: result.attributes.language,
                                fileId: fileId,
                                isDownloading: downloadingFileIds.contains(fileId),
                                isDownloaded: downloadedFileIds.contains(fileId)
                            ) {
                                // Download Logic
                                downloadingFileIds.insert(fileId)
                                osService.downloadSubtitle(fileId: fileId, fileName: fileName) { url in
                                    downloadingFileIds.remove(fileId)
                                    if let url = url {
                                        downloadedFileIds.insert(fileId)
                                        subtitleManager.loadSubtitle(from: url)
                                        
                                        // Auto-dismiss after successful download and load
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            isPresented = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Downloaded View
    var downloadedListView: some View {
        List {
            ForEach(osService.downloadedFiles) { file in
                Button(action: {
                    subtitleManager.loadSubtitle(from: file.url)
                    isPresented = false
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(file.name)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(file.date.formatted())
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        Spacer()
                        if subtitleManager.currentSubtitle == file.name { // Simple logic if we tracked name
                            Image(systemName: "checkmark").foregroundColor(.green)
                        }
                    }
                }
                .listRowBackground(Color.black)
            }
            .onDelete { indexSet in
                osService.deleteFile(at: indexSet)
            }
        }
        .listStyle(PlainListStyle())
        .onAppear {
            osService.refreshDownloadedFiles()
        }
    }
    
    func onlineResultRow(title: String, lang: String, fileId: Int, isDownloading: Bool, isDownloaded: Bool, onDownload: @escaping () -> Void) -> some View {
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
        .padding()
        .background(Color.black)
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
