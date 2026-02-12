import Foundation
import Combine
import SwiftUI
import Photos
import AVFoundation
import CoreData
import MobileVLCKit

struct VideoSection: Identifiable {
    let date: Date
    let videos: [VideoItem]
    var id: Date { date }
}

class DashboardViewModel: ObservableObject {
    static let supportedVideoExtensions = [
        "mp4", "mov", "m4v", "avi", "mkv", "3gp", "wmv", "flv", "webm", "ts", "mpg", "mpeg", "vob", "ogv", "divx", "asf", "m2ts", "rmvb", "rm", "mts", "swf", "dv", "m2t", "m2p", "m4p", "m4b", "flc", "f4v", "ogg", "obb", "vro", "dat",
        "rrc", "gifv", "mng", "qt", "yuv", "amv", "mpe", "mpv", "svi", "3g2", "mxf", "roq", "nsv", "f4p", "f4a", "f4b", "mod"
    ]
    
    // Access Tracking
    private var folderAccessTimes: [String: Date] {
        get {
            let dict = UserDefaults.standard.dictionary(forKey: "folderAccessTimes") as? [String: Date] ?? [:]
            return dict
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "folderAccessTimes")
        }
    }
    
    enum MainTabs: String {
        case home = "Home"
        case gallery = "Gallery"
        case search = "Search"
    }
    
    // Navigation
    @Published var selectedTab: MainTabs = .home {
        didSet {
            if selectedTab != .search {
                lastActiveDataTab = selectedTab
            }
        }
    }
    @Published var lastActiveDataTab: MainTabs = .home
    @Published var isGridView: Bool = {
        if UserDefaults.standard.object(forKey: "isGridView") == nil {
            return true   // Default value
        }
        return UserDefaults.standard.bool(forKey: "isGridView")
    }() {
        didSet {
            UserDefaults.standard.set(isGridView, forKey: "isGridView")
        }
    }

    @Published var showSortSheet: Bool = false
    @Published var isHeaderExpanded: Bool = false
    @Published var isTabBarHidden: Bool = false
    @Published var playingVideo: VideoItem? = nil
    @Published var currentPlaylist: [VideoItem] = []
    @Published var isImporting: Bool = false
    @Published var importProgress: Double = 0.0
    @Published var importStatusMessage: String = ""
    @Published var importCount: Int = 0
    @Published var importCurrentIndex: Int = 0
    @Published var isShowingSearch: Bool = false
    @Published var homeSelectedTab: String = "Video"
    @Published var navigationPath = NavigationPath()
    
    var allVideosAcrossFolders: [VideoItem] {
        func getVideos(from folder: Folder) -> [VideoItem] {
            return folder.videos + folder.subfolders.flatMap { getVideos(from: $0) }
        }
        return folders.flatMap { getVideos(from: $0) }
    }
    
    var allLocalSearchableVideos: [VideoItem] {
        return (importedVideos + allVideosAcrossFolders).sorted { $0.creationDate > $1.creationDate }
    }
    
    var allGallerySearchableVideos: [VideoItem] {
        return allGalleryVideos.sorted { $0.creationDate > $1.creationDate }
    }
    
    enum NavigationDestination: Hashable {
        case allFolders
        case folderDetail(Folder)
        case search(contextTitle: String, initialVideos: [VideoItem]?)
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .allFolders: 
                hasher.combine("allFolders")
            case .folderDetail(let folder): 
                hasher.combine(folder.id)
            case .search(let title, let videos):
                hasher.combine("search")
                hasher.combine(title)
                if let count = videos?.count {
                    hasher.combine(count)
                }
            }
        }
        
        static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
            switch (lhs, rhs) {
            case (.allFolders, .allFolders): return true
            case (.folderDetail(let f1), .folderDetail(let f2)): return f1.id == f2.id
            case (.search(let t1, let v1), .search(let t2, let v2)):
                return t1 == t2 && v1 == v2
            default: return false
            }
        }
    }
    
    // Data Sources
    @Published var videos: [VideoItem] = []
    @Published var folders: [Folder] = []
    @Published var historyVideos: [VideoItem] = []
    @Published var importedVideos: [VideoItem] = []
    @Published var groupedImportedVideos: [VideoSection] = []
    @Published var galleryAlbums: [PHAssetCollection] = []
    @Published var allGalleryAlbums: [PHAssetCollection] = []
    @Published var allGalleryVideos: [VideoItem] = []
    @Published var searchHistoryKeywords: [String] = []
    
    @Published var searchText: String = ""
    @Published var showPermissionDenied: Bool = false
    @Published var isSelectionMode: Bool = false {
        didSet {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isTabBarHidden = isSelectionMode
            }
        }
    }
    @Published var videoSortOptionRaw: String = UserDefaults.standard.string(forKey: "videoSortOptionRaw") ?? "Newest First" {
        didSet { UserDefaults.standard.set(videoSortOptionRaw, forKey: "videoSortOptionRaw") }
    }
    @Published var gallerySortOptionRaw: String = UserDefaults.standard.string(forKey: "gallerySortOptionRaw") ?? "Newest First" {
        didSet { UserDefaults.standard.set(gallerySortOptionRaw, forKey: "gallerySortOptionRaw") }
    }
    @Published var folderSortOptionRaw: String = UserDefaults.standard.string(forKey: "folderSortOptionRaw") ?? "Newest First" {
        didSet { UserDefaults.standard.set(folderSortOptionRaw, forKey: "folderSortOptionRaw") }
    }
    
    // Performance
    let imageManager = PHCachingImageManager()
    
    // Global UI State
    @Published var showCreateFolderAlert = false
    @Published var showPhotoPicker = false
    @Published var selectedVideoIds = Set<UUID>()
    @Published var isSharing: Bool = false
    @Published var showFileImporter = false
    @Published var newFolderName = ""
    @Published var showRenameFolderAlert = false
    @Published var folderToRename: Folder? = nil
    @Published var renameFolderName = ""
    @Published var showDeleteFolderAlert = false
    @Published var folderToDelete: Folder? = nil
    @Published var highlightVideoId: UUID? = nil
    @Published var activeImportFolderURL: URL? = nil
    
    
    @Published var highlightFolderId: UUID? = nil
    
    /// Highlight a video temporarily and clear it (Auto-Dismiss logic)
    func highlightWithTimeout(_ id: UUID) {
        self.highlightVideoId = id
        // Reset scroll/highlight after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if self.highlightVideoId == id {
                withAnimation {
                    self.highlightVideoId = nil
                }
            }
        }
    }
    
    /// Highlight a folder temporarily and clear it
    func highlightFolderWithTimeout(_ id: UUID) {
        self.highlightFolderId = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if self.highlightFolderId == id {
                withAnimation {
                    self.highlightFolderId = nil
                }
            }
        }
    }
    
    // Copy/Paste State
    @Published var copiedVideoIds: Set<UUID> = []
    @Published var isCutMode: Bool = false
    @Published var sourceAlbumIdentifier: String? = nil
    @Published var sourceURL: URL? = nil
    
    @Published var videosToMove: [VideoItem] = []
    
    // Album Compatibility Alert
    @Published var unsupportedVideoForAlbum: VideoItem? = nil
    @Published var showUnsupportedFormatAlert = false
    
    // Move Picker
    @Published var showMovePicker = false
    
    func validateVideosForAlbum(_ videos: [VideoItem]) -> VideoItem? {
        return videos.first(where: { !$0.isAlbumCompatible })
    }
    
    // Sharing State
    @Published var shareURL: URL? = nil
    @Published var showShareSheetGlobal = false
    
    func shareVideo(_ url: URL) {
        self.shareURL = url
        self.showShareSheetGlobal = true
    }
    
    func shareVideo(item: VideoItem) {
        getURL(for: item) { url in
            if let url = url {
                DispatchQueue.main.async {
                    self.shareVideo(url)
                }
            }
        }
    }
    
    func shareSelectedVideos() {
        shareVideos(ids: selectedVideoIds)
    }
    
    var sortedFolders: [Folder] {
        return folders.sorted { f1, f2 in
            let date1 = f1.lastAccessedDate ?? f1.creationDate
            let date2 = f2.lastAccessedDate ?? f2.creationDate
            return date1 > date2
        }
    }
    
    func markFolderAsAccessed(_ folder: Folder) {
        var times = folderAccessTimes
        let now = Date()
        if let path = folder.url?.path {
            times[path] = now
            folderAccessTimes = times
            
            // Update the local folder object to trigger UI refresh if needed
            if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                folders[index].lastAccessedDate = now
            }
        }
    }
    
    func shareVideos(ids: Set<UUID>) {
        // Collect ALL possible videos to filter selection from recursively
        let allVideos = importedVideos + allGalleryVideos + allVideosAcrossFolders
        let selectedItems = allVideos.filter { ids.contains($0.id) }
        
        // Check for album compatibility if destination is an album (though sharing is generic)
        // This is for future use or localized logic if needed.
        
        guard !selectedItems.isEmpty else { 
            print("⚠️ No items selected to share")
            return 
        }
        
        isSharing = true
        var urls: [URL] = []
        let group = DispatchGroup()
        let lock = NSLock()
        
        for item in selectedItems {
            group.enter()
            getURL(for: item) { url in
                if let url = url {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                } else {
                    print("⚠️ Could not get URL for video: \(item.title)")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.isSharing = false
            if !urls.isEmpty {
                self.activityItems = urls
                self.showShareSheetGlobal = true
            } else {
                print("❌ No URLs retrieved for sharing")
            }
        }
    }
    
    @Published var activityItems: [Any] = []
    
    private func getURL(for item: VideoItem, completion: @escaping (URL?) -> Void) {
        if let url = item.url {
            completion(url)
        } else if let asset = item.asset {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            
            let imageManager = PHImageManager.default()
            imageManager.requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    completion(urlAsset.url)
                } else {
                    // Fallback to export using resource manager (e.g. for iCloud or slow motion)
                    let resources = PHAssetResource.assetResources(for: asset)
                    guard let firstResource = resources.first else {
                        completion(nil)
                        return
                    }
                    
                    let uniqueTempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    try? FileManager.default.createDirectory(at: uniqueTempDir, withIntermediateDirectories: true)
                    let outputURL = uniqueTempDir.appendingPathComponent(firstResource.originalFilename)
                    
                    let resourceOptions = PHAssetResourceRequestOptions()
                    resourceOptions.isNetworkAccessAllowed = true
                    
                    PHAssetResourceManager.default().writeData(for: firstResource, toFile: outputURL, options: resourceOptions) { error in
                        if let error = error {
                            print("❌ Error exporting asset: \(error.localizedDescription)")
                            completion(nil)
                        } else {
                            completion(outputURL)
                        }
                    }
                }
            }
        } else {
            completion(nil)
        }
    }
    
    // Global Action Sheet State
    @Published var showActionSheet = false
    @Published var actionSheetTarget: ActionSheetTarget? = nil
    @Published var actionSheetItems: [CustomActionItem] = []
    
    enum ActionSheetTarget {
        case video(VideoItem)
        case folder(Folder)
    }
    
    var videoSortOption: SortOption {
        return SortOption(rawValue: videoSortOptionRaw) ?? .dateDesc
    }
    
    var gallerySortOption: SortOption {
        return SortOption(rawValue: gallerySortOptionRaw) ?? .dateDesc
    }
    
    var folderSortOption: SortOption {
        return SortOption(rawValue: folderSortOptionRaw) ?? .dateDesc
    }
    /// Dedicated folder for imported videos in Documents directory
    var importedVideosDirectory: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let importedVideosURL = documentsURL.appendingPathComponent("ImportedVideos", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: importedVideosURL.path) {
            try? FileManager.default.createDirectory(at: importedVideosURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        return importedVideosURL
    }
    
    var filteredVideos: [VideoItem] {
        if searchText.isEmpty {
            return videos
        } else {
            return videos.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var sortedImportedVideos: [VideoItem] {
        return sortVideos(importedVideos, by: videoSortOption)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadData()
        setupHistoryObserver()
        setupSearchHistoryObserver()
        setupGroupedVideosObserver()
    }
    
    private func setupGroupedVideosObserver() {
        // Observer for imported videos tab (uses videoSortOptionRaw)
        Publishers.CombineLatest($importedVideos, $videoSortOptionRaw)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateGroupedVideos()
            }
            .store(in: &cancellables)
        
        // Master list observer for combined videos (Search/etc) - uses DEFAULT (videoSortOptionRaw)
        Publishers.CombineLatest3($importedVideos, $allGalleryVideos, $videoSortOptionRaw)
            .receive(on: RunLoop.main)
            .sink { [weak self] imported, gallery, _ in
                guard let self = self else { return }
                let all = (imported + gallery)
                self.videos = self.sortVideos(all, by: self.videoSortOption)
            }
            .store(in: &cancellables)
    }
    
    private func sortVideos(_ items: [VideoItem], by option: SortOption) -> [VideoItem] {
        return items.sorted {
            switch option {
            case .dateDesc: return $0.creationDate > $1.creationDate
            case .dateAsc: return $0.creationDate < $1.creationDate
            case .nameAsc: return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            case .nameDesc: return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending
            case .sizeDesc: return $0.fileSizeBytes > $1.fileSizeBytes
            case .sizeAsc: return $0.fileSizeBytes < $1.fileSizeBytes
            case .durationDesc: return $0.duration > $1.duration
            case .durationAsc: return $0.duration < $1.duration
            }
        }
    }
    
    private func updateGroupedVideos() {
        let calendar = Calendar.current
        let currentSort = videoSortOption
        let sorted = sortVideos(importedVideos, by: currentSort)
        
        switch currentSort {
        case .dateDesc, .dateAsc:
            let grouped = Dictionary(grouping: sorted) { video -> Date in
                calendar.startOfDay(for: video.creationDate)
            }
            
            let sortedDates = grouped.keys.sorted(by: { 
                currentSort == .dateAsc ? $0 < $1 : $0 > $1 
            })
            
            self.groupedImportedVideos = sortedDates.map { date in
                let videosInDate = grouped[date] ?? []
                return VideoSection(date: date, videos: videosInDate)
            }
        default:
            // Non-date sorting: provide a single section with a sentinel date for a flat list
            self.groupedImportedVideos = [VideoSection(date: .distantPast, videos: sorted)]
        }
    }
    
    func loadData() {
        // Load Photos and Albums
        checkPhotoLibraryPermission()
        
        // Load Imported Videos from Document Directory
        loadImportedVideos()
        
        // Load User Folders
        loadUserFolders()
    }
    
    func setupHistoryObserver() {
        CDManager.shared.$savedHistory
            .map { items in items.map { self.videoFromHistory($0) } }
            .assign(to: \.historyVideos, on: self)
            .store(in: &cancellables)
    }
    
    func setupSearchHistoryObserver() {
        CDManager.shared.$searchHistory
            .map { items in items.compactMap { $0.keyword } }
            .assign(to: \.searchHistoryKeywords, on: self)
            .store(in: &cancellables)
    }
    
    func playNextVideo(currentVideo: VideoItem) {
        // Search in all sources for next video
        let allCurrentVideos = importedVideos + folders.flatMap { $0.videos }
        if let index = allCurrentVideos.firstIndex(where: { $0.id == currentVideo.id }) {
            let nextIndex = index + 1
            if nextIndex < allCurrentVideos.count {
                playingVideo = allCurrentVideos[nextIndex]
            }
        }
    }
    
    func toggleFavorite(for video: VideoItem) {
        // Logic for favoriting
        print("Toggle favorite for \(video.title)")
    }
    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false
    
    func createFolder(name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let baseURL = documentsURL.appendingPathComponent("Folders", isDirectory: true)
        let folderURL = baseURL.appendingPathComponent(trimmedName, isDirectory: true)
        
        // Check if folder exists
        if FileManager.default.fileExists(atPath: folderURL.path) {
            // Show alert explaining it exists
            alertMessage = "A folder named '\(trimmedName)' already exists."
            showAlert = true
            return false
        }
        
        // Ensure "Folders" directory exists
        if !FileManager.default.fileExists(atPath: baseURL.path) {
            try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        }
        
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            print("✅ Created folder: \(trimmedName)")
            
            // Immediate partial refresh to get the new folder in the list
            loadUserFolders() 
            
            newFolderName = ""
            showCreateFolderAlert = false 
            return true
        } catch {
            alertMessage = "Failed to create folder: \(error.localizedDescription)"
            showAlert = true
            return false
        }
    }
    
    func loadUserFolders() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let rootURL = documentsURL.appendingPathComponent("Folders", isDirectory: true)
            
            // Create root directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: rootURL.path) {
                try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            do {
                let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .nameKey]
                let fileURLs = try FileManager.default.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: resourceKeys, options: .skipsHiddenFiles)
                
                var newFolders: [Folder] = []
                
                for url in fileURLs {
                    if let folder = self.scanFolder(at: url) {
                        newFolders.append(folder)
                    }
                }
                
                DispatchQueue.main.async {
                    self.folders = newFolders
                    
                    // Fetch durations for all videos in folders in background
                    let allFolderVideos = newFolders.flatMap { folder -> [VideoItem] in
                        func getVideos(from f: Folder) -> [VideoItem] {
                            return f.videos + f.subfolders.flatMap { getVideos(from: $0) }
                        }
                        return getVideos(from: folder)
                    }
                    self.backgroundFetchDurations(for: allFolderVideos)
                }
            } catch {
                print("Error loading folders: \(error)")
            }
        }
    }
    
    private func scanFolder(at url: URL) -> Folder? {
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .nameKey]
        guard let resourceValues = try? url.resourceValues(forKeys: Set(resourceKeys)),
              resourceValues.isDirectory == true else {
            return nil
        }
        
        let name = resourceValues.name ?? url.lastPathComponent
        
        // Scan for contents inside
        let creationDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
        let lastAccessed = folderAccessTimes[url.path]
        
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: resourceKeys, options: .skipsHiddenFiles) else {
            return Folder(id: UUID(), name: name, videoCount: 0, videos: [], url: url, subfolders: [], creationDate: creationDate, lastAccessedDate: lastAccessed)
        }
        
        var videos: [VideoItem] = []
        var subfolders: [Folder] = []
        
        for fileURL in fileURLs {
            if let values = try? fileURL.resourceValues(forKeys: Set(resourceKeys)) {
                if values.isDirectory == true {
                    if let subfolder = scanFolder(at: fileURL) {
                        subfolders.append(subfolder)
                    }
                } else {
                    if let video = self.videoItem(from: fileURL) {
                        videos.append(video)
                    }
                }
            }
        }
        
        return Folder(
            id: UUID(),
            name: name,
            videoCount: videos.count,
            videos: videos,
            url: url,
            subfolders: subfolders,
            creationDate: creationDate,
            lastAccessedDate: lastAccessed
        )
    }
    
    private func videoItem(from url: URL) -> VideoItem? {
        guard DashboardViewModel.supportedVideoExtensions.contains(url.pathExtension.lowercased()) else { return nil }
        
        let asset = AVURLAsset(url: url)
        var duration = CMTimeGetSeconds(asset.duration)
        if duration.isNaN { duration = 0 }
        
        // Fallback to VLC for non-native formats (MKV, AVI, etc.) where AVAsset returns 0
        if duration <= 0 {
            let media = VLCMedia(url: url)
            // VLCMedia length is in milliseconds and usually available after initialization for local files
            // but for better reliability we can wait a tiny bit or just use the property if it's there.
            let length = media.length.intValue
            if length > 0 {
                duration = Double(length) / 1000.0
            }
        }
        
        let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        
        return VideoItem(
            id: stableUUID(from: url.absoluteString),
            asset: nil,
            title: url.deletingPathExtension().lastPathComponent,
            duration: duration,
            creationDate: creationDate,
            fileSizeBytes: size,
            thumbnailPath: nil,
            url: url
        )
    }
    
    func videoItem(from asset: PHAsset) -> VideoItem {
        // We no longer access PHAsset properties (like filename via KVC) on the main thread here
        // as it triggers "Missing prefetched properties" errors and degrades performance.
        // Instead, we initialize with a placeholder and resolve the title asynchronously.
        
        return VideoItem(
            id: stableUUID(from: asset.localIdentifier),
            asset: asset,
            title: VideoItem.titlePlaceholder, 
            duration: asset.duration,
            creationDate: asset.creationDate ?? Date(),
            fileSizeBytes: 0
        )
    }
    
    func loadTitle(for video: VideoItem, completion: @escaping (String) -> Void) {
        // If we already have a non-placeholder, non-generic title, just return it.
        if video.title != VideoItem.titlePlaceholder && !video.isGenericTitle {
            completion(video.title)
            return
        }
        
        guard let asset = video.asset else {
            if let url = video.url {
                let name = url.deletingPathExtension().lastPathComponent
                completion(name)
            } else {
                completion("Video")
            }
            return
        }
        
        // Use background queue for ALL PHAsset property access
        DispatchQueue.global(qos: .userInitiated).async {
            var bestFilename: String? = nil
            
            // 1. Try PHAssetResource (reliable source for original filename)
            // We capture this even if it IS generic (e.g. IMG_1234) because the user wants to see it.
            let resources = PHAssetResource.assetResources(for: asset)
            if let first = resources.first {
                let name = (first.originalFilename as NSString).deletingPathExtension
                bestFilename = name
            }
            
            // 2. Fallback to KVC if needed
            if bestFilename == nil {
                if let filename = asset.value(forKey: "filename") as? String {
                    let name = (filename as NSString).deletingPathExtension
                    bestFilename = name
                }
            }
            
            // 3. Use the found filename if available
            if let foundName = bestFilename, !foundName.isEmpty {
                DispatchQueue.main.async { completion(foundName) }
                return
            }
            
            // 4. No filename found? Fallback to metadata-free generation (e.g. Dates)
            // We consciously avoid requestAVAsset here to prevent "FigApplicationStateMonitor" errors.
            self.fallbackTitle(for: asset, video: video, bestFilename: nil, completion: completion)
        }
    }
    
    private func fallbackTitle(for asset: PHAsset, video: VideoItem, bestFilename: String?, completion: @escaping (String) -> Void) {
        // 1. If we found a valid filename (even generic), use it.
        if let filename = bestFilename, !filename.isEmpty {
            DispatchQueue.main.async { completion(filename) }
            return
        }
        
        // 2. Check for screen recordings specifically
        if asset.mediaSubtypes.contains(.videoScreenRecording) {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM yyyy, HH:mm"
            let dateStr = formatter.string(from: asset.creationDate ?? Date())
            DispatchQueue.main.async { completion("Screen Recording \(dateStr)") }
            return
        }
        
        // 3. If we have any existing title that isn't a placeholder, keep it
        if video.title != VideoItem.titlePlaceholder && !video.title.isEmpty {
            DispatchQueue.main.async { completion(video.title) }
            return
        }
        
        // 4. Ultimate fallback: Date-based title
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let fallback = "Video " + formatter.string(from: asset.creationDate ?? Date())
        DispatchQueue.main.async { completion(fallback) }
    }
    
    private func stableUUID(from identifier: String) -> UUID {
        if let uuid = UUID(uuidString: identifier) { return uuid }
        
        // Use a consistent way to generate a UUID from a string
        // Hasher is randomly seeded in Swift, so we cannot use it for stable persistence.
        // Instead, we use a simple deterministic hash (DJB2-like) or just byte mapping.
        
        var hash: UInt64 = 5381
        for byte in identifier.utf8 {
            hash = 127 * (hash & 0x00FFFFFFFFFFFFFF) + UInt64(byte)
        }
        
        // Generate two 64-bit parts for the 128-bit UUID
        let part1 = hash
        let part2 = hash ^ 0x5555555555555555
        
        // We construct a UUID from these bytes
        let uuidString = String(format: "%08X-%04X-%04X-%04X-%012X", 
                                (part1 >> 32) & 0xFFFFFFFF,
                                (part1 >> 16) & 0xFFFF,
                                part1 & 0xFFFF,
                                (part2 >> 48) & 0xFFFF,
                                part2 & 0xFFFFFFFFFFFF)
        
        return UUID(uuidString: uuidString) ?? UUID()
    }
    
    func pasteVideosToGallery(album: PHAssetCollection? = nil) async {
        let allPossibleVideos = importedVideos + allGalleryVideos + folders.flatMap { $0.videos }
        let videosToPaste = allPossibleVideos.filter { copiedVideoIds.contains($0.id) }
        
        guard !videosToPaste.isEmpty else { return }
        
        isImporting = true
        let wasCutMode = isCutMode
        let sourceId = sourceAlbumIdentifier
        let sourceURL = sourceURL
        
        // --- ALBUM COMPATIBILITY CHECK ---
        if let album = album {
            if let incompatibleVideo = validateVideosForAlbum(videosToPaste) {
                isImporting = false
                self.unsupportedVideoForAlbum = incompatibleVideo
                self.showUnsupportedFormatAlert = true
                return
            }
        }
        // ---------------------------------
        
        // Split into Gallery vs Local items
        let galleryVideos = videosToPaste.filter { $0.asset != nil }
        let localVideos = videosToPaste.filter { $0.asset == nil }
        
        Task {
            // 1. Handle Gallery Items (Add to Album, No Deletion)
            if !galleryVideos.isEmpty, let album = album {
                // Check for duplicates first
                let fetchOptions = PHFetchOptions()
                fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
                let existingAssets = PHAsset.fetchAssets(in: album, options: fetchOptions)
                
                var assetsToAdd: [PHAsset] = []
                var firstDuplicate: VideoItem? = nil
                
                for video in galleryVideos {
                    if let asset = video.asset {
                        var alreadyExists = false
                        existingAssets.enumerateObjects { existingAsset, _, stop in
                            if existingAsset.localIdentifier == asset.localIdentifier {
                                alreadyExists = true
                                if firstDuplicate == nil { firstDuplicate = video }
                                stop.pointee = true
                            }
                        }
                        
                        if !alreadyExists {
                            assetsToAdd.append(asset)
                        }
                    }
                }
                
                if assetsToAdd.isEmpty && !galleryVideos.isEmpty {
                    // All were duplicates
                    await MainActor.run {
                        self.isImporting = false
                        self.alertMessage = "These videos are already in this album."
                        self.showAlert = true
                    }
                    return
                }
                
                if !assetsToAdd.isEmpty && assetsToAdd.count < galleryVideos.count {
                    // Partial duplicates
                    await MainActor.run {
                        self.alertMessage = "Some videos were already in this album and were skipped."
                        self.showAlert = true
                    }
                }
                
                do {
                    try await PHPhotoLibrary.shared().performChanges {
                        let request = PHAssetCollectionChangeRequest(for: album)
                        request?.addAssets(assetsToAdd as NSArray)
                    }
                    print("✅ Successfully added \(assetsToAdd.count) existing assets to album")
                } catch {
                    print("❌ Failed to add existing assets to album: \(error)")
                }
            }
            
            // 2. Handle Local Items (Import to Library/Album, Delete if Move)
            if !localVideos.isEmpty {
                var urls: [URL] = []
                for video in localVideos {
                    if let url = await getURLAsync(for: video) {
                        urls.append(url)
                    }
                }
                
                do {
                    try await PHPhotoLibrary.shared().performChanges {
                        let libraryRequest = PHPhotoLibrary.shared()
                        let requests = urls.map { PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: $0) }
                        
                        if let album = album {
                            let placeholders = requests.compactMap({ $0?.placeholderForCreatedAsset })
                            if !placeholders.isEmpty {
                                let albumRequest = PHAssetCollectionChangeRequest(for: album)
                                albumRequest?.addAssets(placeholders as NSArray)
                            }
                        }
                    }
                    print("✅ Successfully imported \(urls.count) local videos to Photo Library")
                } catch {
                    print("❌ Failed to import local videos to Photo Library: \(error)")
                }
            }
            
            // 3. Handle Removal if Move (Album to Album)
            if wasCutMode, let sourceId = sourceId {
                let sourceCollections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [sourceId], options: nil)
                if let sourceAlbum = sourceCollections.firstObject {
                    do {
                        try await PHPhotoLibrary.shared().performChanges {
                            let assetsToRemove = galleryVideos.compactMap { $0.asset } as NSArray
                            let request = PHAssetCollectionChangeRequest(for: sourceAlbum)
                            request?.removeAssets(assetsToRemove)
                        }
                        print("✅ Successfully removed \(galleryVideos.count) assets from source album")
                    } catch {
                        print("❌ Failed to remove assets from source album: \(error)")
                    }
                }
            }
            
            // 4. Only delete LOCAL files if Move
            if wasCutMode && !localVideos.isEmpty {
                await MainActor.run {
                    for video in localVideos {
                        self.deleteVideo(video)
                    }
                }
                // Refresh local storage views
                self.loadImportedVideos()
                self.loadUserFolders()
            }
        } // This closes the Task block.
        
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay for indexing
        
        await MainActor.run {
            self.isImporting = false
            print("✅ Copied/Moved to Gallery Complete")
            
            // Always clear clipboard
            self.copiedVideoIds.removeAll()
            self.isCutMode = false
            self.sourceAlbumIdentifier = nil
            self.sourceURL = nil
            self.videosToMove = []
            
            // Refresh everything
            self.fetchAssets()
            self.fetchAlbums()
            self.loadImportedVideos()
            self.loadUserFolders()
            
            // Clear selection mode now that operation is complete
            self.isSelectionMode = false
            self.selectedVideoIds.removeAll()
        }
    }
    
    
    func renameVideo(_ video: VideoItem, to newName: String) {
        // Only rename local imported videos
        guard let oldURL = video.url else { return }
        
        let fileManager = FileManager.default
        let directory = oldURL.deletingLastPathComponent()
        let extensionStr = oldURL.pathExtension
        let newURL = directory.appendingPathComponent(newName).appendingPathExtension(extensionStr)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                if fileManager.fileExists(atPath: newURL.path) {
                    print("⚠️ Destination already exists: \(newURL.lastPathComponent)")
                }
                
                try fileManager.moveItem(at: oldURL, to: newURL)
                print("✅ Renamed: \(oldURL.lastPathComponent) -> \(newURL.lastPathComponent)")
                
                // Update HistoryItem in Core Data
                let context = CDManager.shared.container.viewContext
                let fetchRequest: NSFetchRequest<HistoryItem> = HistoryItem.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "videoUrlString == %@", oldURL.absoluteString)
                
                if let results = try? context.fetch(fetchRequest), let historyItem = results.first {
                    historyItem.videoUrlString = newURL.absoluteString
                    historyItem.title = (newURL.lastPathComponent as NSString).deletingPathExtension
                    try? context.save()
                    print("💾 Updated HistoryItem in DB")
                }
                
                DispatchQueue.main.async {
                    self.loadImportedVideos()
                    self.loadUserFolders()
                }
            } catch {
                print("❌ Rename failed: \(error.localizedDescription)")
            }
        }
    }
    
    func copyVideos(ids: Set<UUID>, isCut: Bool, sourceURL: URL? = nil, sourceAlbumId: String? = nil) {
        self.copiedVideoIds = ids
        self.isCutMode = isCut
        self.sourceURL = sourceURL
        self.sourceAlbumIdentifier = sourceAlbumId
        
        // Resolve VideoItem objects for the move picker logic recursively
        let allPossibleVideos = importedVideos + allGalleryVideos + allVideosAcrossFolders
        self.videosToMove = allPossibleVideos.filter { ids.contains($0.id) }
        
        print("📋 \(isCut ? "Cut" : "Copied") \(ids.count) videos")
    }
    
    func pasteVideos(to destination: URL) {
        let allPossibleVideos = importedVideos + allGalleryVideos + allVideosAcrossFolders
        let videosToPaste = allPossibleVideos.filter { copiedVideoIds.contains($0.id) }
        
        guard !videosToPaste.isEmpty else { return }
        
        let wasCutMode = isCutMode
        let sourceAlbumId = sourceAlbumIdentifier
        
        Task {
            var urls: [URL] = []
            var names: [String] = []
            
            for video in videosToPaste {
                if let url = await getURLAsync(for: video) {
                    urls.append(url)
                    // CRITICAL: Always use the actual filename from the resolved URL.
                    // For gallery items, getURLAsync provides a temp file with the original name.
                    // Using video.title here can result in 'Fetching Title...' or empty names.
                    names.append(url.lastPathComponent)
                }
            }
            
            // 1. Import/Move
            let results = await self.importVideos(from: urls, names: names, to: destination, shouldMove: wasCutMode)
            
            // 2. Cleanup
            await MainActor.run {
                if wasCutMode && !results.isEmpty {
                    for video in videosToPaste {
                        // If file was successfully imported/moved to destination, handle source UI removal
                        if let url = video.url {
                            // Check if the source file is gone (moved) or still there (duplicate or copy)
                            if !FileManager.default.fileExists(atPath: url.path) {
                                // moved successfully - already gone from filesystem
                                withAnimation {
                                    self.importedVideos.removeAll { $0.id == video.id }
                                }
                            } else {
                                // File still exists (copied or failed move/duplicate during cut), 
                                // we should delete it IF it's not the one we just pasted (same path check)
                                // But simpler: if Move mode and results contains the new destination,
                                // we can delete the source if it's different from all results.
                                // Higher level: Results contains only SUCCESSFUL paste operations.
                                if results.contains(where: { $0.url?.lastPathComponent == url.lastPathComponent }) {
                                    // The file was successfully pasted with this name.
                                    // If the source path is different from any successful destination path, delete source.
                                    if !results.contains(where: { $0.url?.path == url.path }) {
                                        self.deleteVideo(video)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Gallery handling
                    if let albumId = sourceAlbumId {
                        let galleryVideos = videosToPaste.filter { $0.asset != nil }
                        if !galleryVideos.isEmpty {
                            Task {
                                let sourceCollections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumId], options: nil)
                                if let sourceAlbum = sourceCollections.firstObject {
                                    try? await PHPhotoLibrary.shared().performChanges {
                                        let assetsToRemove = galleryVideos.compactMap { $0.asset } as NSArray
                                        let request = PHAssetCollectionChangeRequest(for: sourceAlbum)
                                        request?.removeAssets(assetsToRemove)
                                    }
                                    await MainActor.run {
                                        self.loadData()
                                    }
                                }
                            }
                        }
                    }
                }
                self.copiedVideoIds.removeAll()
                self.isCutMode = false
                self.sourceURL = nil
                self.sourceAlbumIdentifier = nil
                self.isSelectionMode = false
                self.selectedVideoIds.removeAll()
                
                self.loadImportedVideos()
                self.loadUserFolders()
            }
        }
    }
    
    private func getURLAsync(for item: VideoItem) async -> URL? {
        return await withCheckedContinuation { continuation in
            getURL(for: item) { url in
                continuation.resume(returning: url)
            }
        }
    }
    
    func renameFolder(_ folder: Folder, to newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let oldURL = folder.url else { return }
        
        // Don't rename if name is the same
        if trimmedName == folder.name { return }
        
        let newURL = oldURL.deletingLastPathComponent().appendingPathComponent(trimmedName)
        
        if FileManager.default.fileExists(atPath: newURL.path) {
            alertMessage = "A folder named '\(trimmedName)' already exists."
            showAlert = true
            return
        }
        
        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            loadUserFolders()
        } catch {
            alertMessage = "Failed to rename folder: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    func deleteFolder(_ folder: Folder) {
        guard let url = folder.url else { return }
        do {
            try FileManager.default.removeItem(at: url)
            loadUserFolders()
        } catch {
            print("❌ Failed to delete folder: \(error)")
        }
    }
    
    func deleteVideo(_ video: VideoItem) {
        // 1. Immediate UI update for smooth animation
        DispatchQueue.main.async {
            withAnimation(.spring()) {
                self.importedVideos.removeAll { $0.id == video.id }
                self.allGalleryVideos.removeAll { $0.id == video.id }
                // Also update grouping if needed, though loadImportedVideos will fix it
            }
        }
        
        // 2. Delete from file system if it's an imported video
        if let url = video.url {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.removeItem(at: url)
                    print("✅ Deleted video file: \(url.lastPathComponent)")
                    DispatchQueue.main.async {
                        self.loadImportedVideos()
                        self.loadUserFolders()
                    }
                } catch {
                    print("❌ Failed to delete file: \(error.localizedDescription)")
                }
            }
        }
        
        // 3. Remove from albums/folders if it's a Photo Library video
        if let asset = video.asset {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("✅ Deleted photo library asset")
                        withAnimation {
                            self.fetchAssets()
                            self.fetchAlbums()
                        }
                    } else {
                        print("❌ Failed to delete asset: \(error?.localizedDescription ?? "unknown")")
                        // Optional: Rollback UI if deletion failed
                        self.loadImportedVideos()
                        self.fetchAssets()
                        self.fetchAlbums()
                    }
                }
            }
        }
    }
    
    func videoActions(for video: VideoItem) -> [CustomActionItem] {
        var items: [CustomActionItem] = []
        
        items.append(CustomActionItem(title: "Share", icon: "square.and.arrow.up", role: nil, action: {
            self.shareVideo(item: video)
        }))
        
        items.append(CustomActionItem(title: "Copy", icon: "doc.on.doc", role: nil, action: {
            self.copyVideos(ids: Set([video.id]), isCut: false)
        }))
        
        items.append(CustomActionItem(title: "Move", icon: "arrow.right.doc.on.clipboard", role: nil, action: {
            self.copyVideos(ids: Set([video.id]), isCut: true)
            self.videosToMove = [video]
            // Extra safety delay to ensure sheet doesn't conflict with dismissing action sheet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showMovePicker = true
            }
        }))
        
        items.append(CustomActionItem(title: "Delete", icon: "trash", role: .destructive, action: {
            self.deleteVideo(video)
        }))
        
        return items
    }
    
    func importVideo(from url: URL, withName name: String? = nil, to destination: URL? = nil, autoPlay: Bool = false) {
        // If it's an external URL, check if we already have it imported by filename
        if let existing = checkDuplicate(url: url) {
            Task { @MainActor in
                self.playingVideo = existing
            }
            return
        }
        
        Task {
            if autoPlay, let firstItem = (await importVideos(from: [url], names: name != nil ? [name!] : nil, to: destination)).first {
                await MainActor.run {
                    self.playingVideo = firstItem
                }
            }
        }
    }
    
    private func checkDuplicate(url: URL) -> VideoItem? {
        // Check both imported and gallery videos
        let all = importedVideos + allGalleryVideos + folders.flatMap { $0.videos }
        // Proper check: compare full filename with extension
        let targetName = url.lastPathComponent.lowercased()
        return all.first(where: { ($0.url?.lastPathComponent)?.lowercased() == targetName })
    }
    
    func startImportSession(count: Int) {
        self.isImporting = true
        self.importCount = count
        self.importCurrentIndex = 0
        self.importProgress = 0.0
        self.importStatusMessage = "Starting..."
    }
    
    func finalizeImportSession() {
        self.loadData()
        self.isImporting = false
        self.importProgress = 0.0
        self.importStatusMessage = ""
        self.isSelectionMode = false
    }
    
    @discardableResult
    func importSingleVideo(from url: URL, name: String? = nil, to destination: URL? = nil, shouldMove: Bool = false) async -> VideoItem? {
        let items = await importVideos(from: [url], names: name != nil ? [name!] : nil, to: destination, shouldMove: shouldMove, isInternalSession: true)
        return items.first
    }
    
    // Import logic
    @discardableResult
    func importVideos(from urls: [URL], names: [String]? = nil, to destination: URL? = nil, shouldMove: Bool = false, isInternalSession: Bool = false) async -> [VideoItem] {
        
        // 1. Setup State on Main Actor
        let targetDirectory = destination ?? self.activeImportFolderURL ?? self.importedVideosDirectory
        
        if !isInternalSession {
            await MainActor.run {
                self.importCount = urls.count
                self.importCurrentIndex = 1
                self.importProgress = 0.0
                self.importStatusMessage = "Starting import..."
                self.isImporting = true
            }
        }
        
        // 2. Perform Heavy Work in Detached Task
        return await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return [] }
            
            var successfulItems: [VideoItem] = []
            let fileManager = FileManager.default
            // Note: We only access context inside MainActor.run blocks, so this is safe to capture reference
            let context = CDManager.shared.container.viewContext 
            
            for (index, url) in urls.enumerated() {
                var filename: String
                if let names = names, index < names.count {
                    filename = names[index]
                } else {
                    filename = url.lastPathComponent
                }
                
                var destinationURL = targetDirectory.appendingPathComponent(filename)
                
                // If a file already exists at the destination, generate a unique name
                if fileManager.fileExists(atPath: destinationURL.path) {
                    // Check if it's the exact SAME file being re-imported from the same location (skip case)
                    if url.path == destinationURL.path {
                        print("ℹ️ File already exists at destination and is the same source. Skipping copy.")
                        if let item = await self.videoItemAsync(from: destinationURL) {
                            successfulItems.append(item)
                        }
                        continue
                    }
                    
                    // Generate unique name: "video (1).mp4", "video (2).mp4", etc.
                    let baseName = (filename as NSString).deletingPathExtension
                    let ext = (filename as NSString).pathExtension
                    var counter = 1
                    var uniqueName = filename
                    
                    while fileManager.fileExists(atPath: targetDirectory.appendingPathComponent(uniqueName).path) {
                        uniqueName = "\(baseName) (\(counter)).\(ext)"
                        counter += 1
                    }
                    
                    filename = uniqueName
                    destinationURL = targetDirectory.appendingPathComponent(filename)
                    print("🔄 Renamed duplicate to: \(filename)")
                }
                
                // 1. Save to History (Core Data) - Must be on MainActor
                await MainActor.run {
                    let newItem = HistoryItem(context: context)
                    newItem.id = UUID()
                    newItem.videoUrlString = destinationURL.absoluteString
                    
                    let cleanTitle = (filename as NSString).deletingPathExtension
                    newItem.title = cleanTitle != VideoItem.titlePlaceholder ? cleanTitle : "Video_\(Int(Date().timeIntervalSince1970))"
                    
                    newItem.timestamp = Date()
                    try? context.save()
                }
                
                // 2. Copy/Move File
                do {
                    // Update progress
                    await MainActor.run {
                        if !isInternalSession || urls.count > 1 {
                            self.importCurrentIndex = (isInternalSession ? self.importCurrentIndex : index + 1)
                            self.importStatusMessage = "Copying \(filename)..."
                            if !isInternalSession {
                                self.importProgress = (Double(index) + 0.5) / Double(urls.count)
                            }
                        }
                    }
                    
                    // Ensure access
                    let gainedAccess = url.startAccessingSecurityScopedResource()
                    defer { if gainedAccess { url.stopAccessingSecurityScopedResource() } }
                    
                    // Try to move if requested, otherwise copy
                    // BLOCKING IO - now safe in detached task
                    do {
                        if shouldMove {
                            try fileManager.moveItem(at: url, to: destinationURL)
                            if let item = await self.videoItemAsync(from: destinationURL) {
                                successfulItems.append(item)
                            }
                            print("⚡ Moved (instant): \(filename)")
                        } else {
                            try fileManager.copyItem(at: url, to: destinationURL)
                            if let item = await self.videoItemAsync(from: destinationURL) {
                                successfulItems.append(item)
                            }
                            print("✅ Copied: \(filename)")
                        }
                    } catch {
                        // Fallback to copy if move fails (e.g. across volumes)
                        if shouldMove {
                            do {
                                try fileManager.copyItem(at: url, to: destinationURL)
                                if let item = await self.videoItemAsync(from: destinationURL) {
                                    successfulItems.append(item)
                                }
                                print("✅ Copied (Move fallback): \(filename)")
                            } catch {
                                print("❌ Error importing \(url.lastPathComponent): \(error)")
                                await MainActor.run {
                                    self.alertMessage = "Failed to copy '\(filename)': \(error.localizedDescription)"
                                    self.showAlert = true
                                }
                            }
                        } else {
                            print("❌ Error copying \(url.lastPathComponent): \(error)")
                            await MainActor.run {
                                self.alertMessage = "Failed to copy '\(filename)': \(error.localizedDescription)"
                                self.showAlert = true
                            }
                        }
                    }
                    
                    if !isInternalSession {
                        await MainActor.run {
                            self.importProgress = Double(index + 1) / Double(urls.count)
                        }
                    }
                }
            }
            
            // 3. Finalize
            if !isInternalSession {
                await MainActor.run {
                    self.loadImportedVideos() // This triggers UI refresh
                    self.loadUserFolders()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isImporting = false
                        self.importProgress = 0.0
                        self.importStatusMessage = ""
                        self.activeImportFolderURL = nil
                        self.isSelectionMode = false 
                    }
                }
            }
            
            return successfulItems
        }.value
    }
    
    // Helper to get video item safely from detached task (accesses non-isolated VideoItem init or MainActor helper?)
    // VideoItem init is simple struct/data init, so it should be fine. 
    // BUT self.videoItem(...) calls videoItem(from: VideoItem.swift logic?). 
    // self.videoItem(from: URL) is likely just reading attributes.
    // Let's assume videoItem(from:) is safe or we need to wrap it.
    private func videoItemAsync(from url: URL) async -> VideoItem? {
        // Since we are traversing files, it's safer to just do it here or call a non-ui helper.
        // Assuming self.videoItem(from: url) is available and thread-safe or we run it on MainActor if needed.
        // Actually, creating the VideoItem involves reading file attributes. Better do it in background.
        // Let's create a local helper or use MainActor if the existing one is MainActor-isolated.
        // DashboardViewModel is usually @MainActor.
        
        return await MainActor.run {
            return self.videoItem(from: url)
        }
    }
    
    func findFolder(byId id: UUID) -> Folder? {
        return findFolder(byId: id, in: folders)
    }
    
    private func findFolder(byId id: UUID, in searchFolders: [Folder]) -> Folder? {
        for folder in searchFolders {
            if folder.id == id { return folder }
            if let nested = findFolder(byId: id, in: folder.subfolders) { return nested }
        }
        return nil
    }
    
    func findFolder(byURL url: URL) -> Folder? {
        return findFolder(byURL: url, in: folders)
    }
    
    private func findFolder(byURL url: URL, in searchFolders: [Folder]) -> Folder? {
        for folder in searchFolders {
            if folder.url == url { return folder }
            if let nested = findFolder(byURL: url, in: folder.subfolders) { return nested }
        }
        return nil
    }
    
    // MARK: - Helpers
    
    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            self.showPermissionDenied = false
            fetchAssets()
            fetchAlbums()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.showPermissionDenied = true
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        self?.showPermissionDenied = false
                        self?.fetchAssets()
                        self?.fetchAlbums()
                    } else {
                        self?.showPermissionDenied = true
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    private func fetchAssets() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        var newVideos: [VideoItem] = []
        
        fetchResult.enumerateObjects { asset, _, _ in
            newVideos.append(self.videoItem(from: asset))
        }
        
        DispatchQueue.main.async {
            self.allGalleryVideos = newVideos
            
            // Start pre-fetching titles in small batches to avoid overhead
            self.preFetchTitles(for: newVideos)
            
            // Pre-warm thumbnail cache for gallery videos
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) {
                ThumbnailCacheManager.shared.prewarmCache(for: newVideos)
            }
        }
    }
    
    func preFetchTitles(for videos: [VideoItem]) {
        // Only pre-fetch the first 30 videos to avoid overwhelming the system
        // The rest will be loaded on-demand when the view appears.
        let limit = min(videos.count, 30)
        let prioritizedVideos = Array(videos.prefix(limit))
        
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            for video in prioritizedVideos {
                self.loadTitle(for: video) { resolvedTitle in
                    DispatchQueue.main.async {
                        // Update in allGalleryVideos
                        if let index = self.allGalleryVideos.firstIndex(where: { $0.id == video.id }) {
                            self.allGalleryVideos[index].title = resolvedTitle
                        }
                        
                        // Update in importedVideos (for mixed local/gallery collections)
                        if let index = self.importedVideos.firstIndex(where: { $0.id == video.id }) {
                            self.importedVideos[index].title = resolvedTitle
                        }
                        
                        // Update in folders
                        for i in 0..<self.folders.count {
                            if let vIndex = self.folders[i].videos.firstIndex(where: { $0.id == video.id }) {
                                self.folders[i].videos[vIndex].title = resolvedTitle
                            }
                        }
                        
                        // Master list for search
                        if let index = self.videos.firstIndex(where: { $0.id == video.id }) {
                            self.videos[index].title = resolvedTitle
                        }
                    }
                }
            }
        }
    }
    
    
    
    private func loadImportedVideos() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let videosPath = self.importedVideosDirectory
            
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: videosPath, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey], options: .skipsHiddenFiles)
                
                let videoFiles = fileURLs.filter { DashboardViewModel.supportedVideoExtensions.contains($0.pathExtension.lowercased()) }
                
                let loadedVideos = videoFiles.compactMap { url -> VideoItem? in
                    // Verify file exists and has size
                    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                    let size = attributes?[.size] as? Int64 ?? 0
                    guard size > 0 else { return nil }
                    
                    let duration: Double = 0 // Will fetch in background
                    
                    let resources = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                    
                    return VideoItem(
                        id: self.stableUUID(from: url.absoluteString),
                        asset: nil,
                        title: url.deletingPathExtension().lastPathComponent,
                        duration: duration,
                        creationDate: resources?.creationDate ?? Date(),
                        fileSizeBytes: size,
                        thumbnailPath: nil,
                        url: url
                    )
                }.sorted(by: { $0.creationDate > $1.creationDate })
                
                DispatchQueue.main.async {
                    withAnimation {
                        self.importedVideos = loadedVideos
                        self.isImporting = false
                    }
                    
                    // Start background metadata fetching (Titles and Durations)
                    self.backgroundFetchTitles(for: loadedVideos)
                    self.backgroundFetchDurations(for: loadedVideos)
                    
                    // Pre-warm thumbnail cache in background
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) {
                        ThumbnailCacheManager.shared.prewarmCache(for: loadedVideos)
                    }
                }
            } catch {
                print("Error loading imported videos: \(error)")
                DispatchQueue.main.async {
                    self.isImporting = false
                }
            }
        }
    }
    
    private func videoFromHistory(_ item: HistoryItem) -> VideoItem {
        // CRITICAL: Must use the stored ID from Core Data, not generate random UUIDs
        // Otherwise deletion will never work because IDs won't match
        let videoId = item.id ?? UUID()
        
        // Try to get the URL for imported videos
        var videoURL: URL? = nil
        if let urlString = item.videoUrlString, !urlString.hasPrefix("PH://") {
            videoURL = URL(string: urlString)
        }
        
        return VideoItem(
            id: videoId, // Use stored ID from Core Data
            asset: fetchAsset(for: item.videoUrlString),
            title: item.title ?? "Unknown",
            duration: item.duration,
            creationDate: item.timestamp ?? Date(),
            fileSizeBytes: item.fileSizeBytes,
            thumbnailPath: nil,
            url: videoURL
        )
    }
    
    private func backgroundFetchTitles(for videos: [VideoItem]) {
        let videosWithPlaceholders = videos.filter { $0.asset != nil && $0.title == VideoItem.titlePlaceholder }
        guard !videosWithPlaceholders.isEmpty else { return }
        
        // Process in small batches to avoid overwhelming the system
        DispatchQueue.global(qos: .utility).async {
            for video in videosWithPlaceholders {
                guard let asset = video.asset else { continue }
                let resources = PHAssetResource.assetResources(for: asset)
                if let filename = resources.first?.originalFilename {
                    DispatchQueue.main.async {
                        // Update in importedVideos
                        if let index = self.importedVideos.firstIndex(where: { $0.id == video.id }) {
                            self.importedVideos[index].title = filename
                        }
                        // Update in master videos list
                        if let index = self.videos.firstIndex(where: { $0.id == video.id }) {
                            self.videos[index].title = filename
                        }
                        // Update in folders if present
                        for i in 0..<self.folders.count {
                            if let vIndex = self.folders[i].videos.firstIndex(where: { $0.id == video.id }) {
                                self.folders[i].videos[vIndex].title = filename
                            }
                        }
                        if self.playingVideo?.id == video.id {
                            self.playingVideo?.title = filename
                        }
                        self.objectWillChange.send()
                    }
                }
            }
        }
    }
    
    private func backgroundFetchDurations(for videos: [VideoItem]) {
        let localVideos = videos.filter { $0.url != nil && ($0.duration <= 0 || $0.duration.isNaN) }
        guard !localVideos.isEmpty else { return }
        
        DispatchQueue.global(qos: .utility).async {
            for video in localVideos {
                guard let url = video.url else { continue }
                
                // Check if VLC Format (basically anything not natively supported by AVAsset)
                let ext = url.pathExtension.lowercased()
                let nativeExtensions = ["mp4", "mov", "m4v"]
                if !nativeExtensions.contains(ext) {
                    // Use Helper to fetch duration asynchronously via Delegate
                    let helper = VLCDurationHelper()
                    // We need to keep a reference to helper until it finishes. 
                    // Since we are in a loop in a background queue, we can't easily wait.
                    // We will create a standalone Task or method to handle this life cycle.
                    
                    Task {
                        let duration = await helper.fetchDuration(for: url)
                        if duration > 0 {
                            await MainActor.run {
                                self.updateDuration(for: video.id, duration: duration)
                            }
                        }
                    }
                    continue
                }
                
                // Native Formats
                let asset = AVURLAsset(url: url)
                Task {
                    if let d = try? await asset.load(.duration) {
                        let duration = CMTimeGetSeconds(d)
                        await MainActor.run {
                            self.updateDuration(for: video.id, duration: duration)
                        }
                    }
                }
            }
        }
    }
    
    private func updateDuration(for id: UUID, duration: Double) {
        if let index = self.importedVideos.firstIndex(where: { $0.id == id }) {
            self.importedVideos[index].duration = duration
        }
        if let index = self.videos.firstIndex(where: { $0.id == id }) {
            self.videos[index].duration = duration
        }
        
        func updateFolderRecursively(_ folder: inout Folder) {
            if let vIndex = folder.videos.firstIndex(where: { $0.id == id }) {
                folder.videos[vIndex].duration = duration
            }
            for i in 0..<folder.subfolders.count {
                updateFolderRecursively(&folder.subfolders[i])
            }
        }
        
        for i in 0..<self.folders.count {
            updateFolderRecursively(&self.folders[i])
        }
        
        self.objectWillChange.send()
    }
    
    private func fetchAsset(for identifier: String?) -> PHAsset? {
        guard let identifier = identifier else { return nil }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return fetchResult.firstObject
    }
    
    // MARK: - Models (Using existing Folder and VideoItem)
    
    enum SortOption: String, CaseIterable {
        case dateDesc = "Newest First"
        case dateAsc = "Oldest First"
        case nameAsc = "Name (A-Z)"
        case nameDesc = "Name (Z-A)"
        case sizeDesc = "Size (Large to Small)"
        case sizeAsc = "Size (Small to Large)"
        case durationDesc = "Duration (Long to Short)"
        case durationAsc = "Duration (Short to Long)"
    }
    
    // MARK: - History Management
    
    var historyItems: [HistoryItem] {
        return CDManager.shared.savedHistory
    }
    
    func deleteHistoryItems(_ items: [VideoItem]) {
        print("🗑️ Attempting to delete \(items.count) history items")
        
        let historyToDelete = historyVideos.filter { historyVideo in
            items.contains(where: { $0.id == historyVideo.id })
        }
        
        print("📋 Found \(historyToDelete.count) matching history videos to delete")
        
        // We need to map back to Core Data HistoryItem objects to delete them
        let validIds = historyToDelete.map { $0.id }
        let cdItems = CDManager.shared.savedHistory.filter { validIds.contains($0.id ?? UUID()) }
        
        print("💾 Found \(cdItems.count) matching Core Data items")
        
        for item in cdItems {
            print("  - Deleting: \(item.title ?? "Unknown")")
            CDManager.shared.deleteHistoryItem(item: item)
        }
        
        print("✅ Deletion complete")
        // History will refresh automatically via setupHistoryObserver Combine publisher
    }
    
    func isFavorite(_ video: VideoItem) -> Bool {
        // Implementation for checking favorite status
        return folders.first(where: { $0.name == "Favorites" })?.videos.contains(where: { $0.id == video.id }) ?? false
    }
    
    func fetchAlbums() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            print("⚠️ Skipping fetchAlbums: Not authorized (\(status.rawValue))")
            return
        }
        
        // Use regular fetch (requestAuthorization is not needed if status is already OK)
        performAlbumFetch()
    }
    
    private func performAlbumFetch() {
        let fetchOptions = PHFetchOptions()
        // Sort user albums by title
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
        
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        var videoAlbums: [PHAssetCollection] = []
        var userDestinations: [PHAssetCollection] = [] // Writable targets
        
        let processCollections = { (fetchResult: PHFetchResult<PHAssetCollection>, isUserAlbum: Bool) in
            fetchResult.enumerateObjects { collection, _, _ in
                let title = collection.localizedTitle ?? ""
                if title.lowercased() == "recents" || title.lowercased() == "recent" {
                    return
                }
                
                // User albums are always destination candidates
                if isUserAlbum {
                    userDestinations.append(collection)
                }
                
                let options = PHFetchOptions()
                options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
                let assets = PHAsset.fetchAssets(in: collection, options: options)
                
                if assets.count > 0 {
                    videoAlbums.append(collection)
                }
            }
        }
        
        processCollections(smartAlbums, false)
        processCollections(userAlbums, true)
        
        DispatchQueue.main.async {
            self.galleryAlbums = videoAlbums
            self.allGalleryAlbums = userDestinations // Only user-created albums for pasting
            self.objectWillChange.send()
        }
        
    }
}

// Extension to DashboardViewModel for missing methods
extension DashboardViewModel {
    func getFavoriteVideos() -> [VideoItem] {
        // Return videos from "Favorites" folder
        if let favFolder = folders.first(where: { $0.name == "Favorites" }) {
            return favFolder.videos
        }
        return []
    }
    
    func moveVideo(_ video: VideoItem, to targetFolder: Folder) {
        // Move video file to target folder
        guard let sourceURL = video.url, let folderURL = targetFolder.url else { return }
        let destinationURL = folderURL.appendingPathComponent(sourceURL.lastPathComponent)
        
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            
            // Refresh
            loadImportedVideos() // If moved from import
            loadUserFolders()    // If moved to folder
        } catch {
            print("Failed to move video: \(error)")
        }
    }
    
    // MARK: - Search Actions
    
    func persistSearchKeyword(_ keyword: String) {
        CDManager.shared.saveSearchKeyword(keyword)
    }
    
    func deleteSearchKeyword(_ keyword: String) {
        if let item = CDManager.shared.searchHistory.first(where: { $0.keyword == keyword }) {
            CDManager.shared.deleteSearchKeyword(item)
        }
    }
    
    func clearSearchHistory() {
        CDManager.shared.clearAllSearchHistory()
    }
}

class VLCDurationHelper: NSObject, VLCMediaDelegate {
    private var completion: ((Double) -> Void)?
    private var media: VLCMedia?
    private var retainSelf: VLCDurationHelper? // Keep alive
    
    func fetchDuration(for url: URL) async -> Double {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                self.retainSelf = self // Retain cycle intentionally
                self.completion = { duration in
                    continuation.resume(returning: duration)
                    self.retainSelf = nil // Release
                }
                
                self.media = VLCMedia(url: url)
                self.media?.delegate = self
                self.media?.parse(options: [])
            }
        }
    }
    
    func mediaDidFinishParsing(_ aMedia: VLCMedia) {
        let length = aMedia.length
        let duration = Double(length.intValue) / 1000.0
        Task { @MainActor in
            completion?(duration)
        }
    }
}
