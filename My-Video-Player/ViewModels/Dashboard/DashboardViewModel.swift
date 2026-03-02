import Foundation
import Combine
import SwiftUI
import Photos
import PhotosUI
import AVFoundation
import CoreData
import MobileVLCKit

struct VideoSection: Identifiable, Equatable {
    let date: Date
    let videos: [VideoItem]
    var id: Date { date }
    
    static func == (lhs: VideoSection, rhs: VideoSection) -> Bool {
        return lhs.date == rhs.date && lhs.videos == rhs.videos
    }
}

struct FolderSection: Identifiable {
    let date: Date
    let folders: [Folder]
    var id: Date { date }
}

class DashboardViewModel: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    static let supportedVideoExtensions = [
        "mp4", "mov", "m4v", "avi", "mkv", "3gp", "wmv", "flv", "webm", "ts", "mpg", "mpeg", "vob", "ogv", "divx", "asf", "m2ts", "rmvb", "rm", "mts", "swf", "dv", "m2t", "m2p", "m4p", "m4b", "flc", "f4v", "ogg", "obb", "vro", "dat",
        "rrc", "gifv", "mng", "qt", "yuv", "amv", "mpe", "mpv", "svi", "3g2", "mxf", "roq", "nsv", "f4p", "f4a", "f4b", "mod", "mov"
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
        case folders = "Folders"
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
    @Published var isImportCancelled: Bool = false
    @Published var isShowingSearch: Bool = false
    @Published var homeSelectedTab: String = "Video"
    
    var allVideosAcrossFolders: [VideoItem] {
        func getVideos(from folder: Folder) -> [VideoItem] {
            return folder.videos + folder.subfolders.flatMap { getVideos(from: $0) }
        }
        return folders.flatMap { getVideos(from: $0) }
    }
    
    var allLocalSearchableVideos: [VideoItem] {
        return sortVideos(importedVideos + allVideosAcrossFolders, by: videoSortOption)
    }
    
    var allGallerySearchableVideos: [VideoItem] {
        // Use pre-sorted array when available to avoid sorting on main thread
        return sortedAllGalleryVideos.isEmpty ? sortVideos(allGalleryVideos, by: gallerySortOption) : sortedAllGalleryVideos
    }
    
    // Data Sources
    @Published var videos: [VideoItem] = []
    @Published var folders: [Folder] = []
    @Published var historyVideos: [VideoItem] = []
    @Published var importedVideos: [VideoItem] = []
    @Published var isInitialLoading: Bool = true
    @Published var groupedImportedVideos: [VideoSection] = []
    @Published var galleryAlbums: [PHAssetCollection] = []
    @Published var allGalleryAlbums: [PHAssetCollection] = []
    @Published var allGalleryVideos: [VideoItem] = []
    @Published var lastGalleryUpdate = Date()
    @Published var albumAssetCounts: [String: Int] = [:]
    /// localIdentifier of the "All Videos" smart album — used by FolderDetailView to skip fetch
    @Published var allVideosAlbumIdentifier: String?
    /// allGalleryVideos pre-sorted by gallerySortOption on a background thread.
    /// FolderDetailView reads this directly so it never sorts on the main thread.
    @Published var sortedAllGalleryVideos: [VideoItem] = []
    private var galleryStateSignature: String = ""

    // Stored fetch result — used by photoLibraryDidChange to compute ONLY the delta
    // (removed/inserted assets) instead of re-enumerating all 10,000+ videos.
    // Protected by a serial queue to prevent main-thread / Photos-callback races.
    private let fetchResultLock = DispatchQueue(label: "com.videoplayer.fetchResultLock")
    private var _currentAssetFetchResult: PHFetchResult<PHAsset>?
    private var currentAssetFetchResult: PHFetchResult<PHAsset>? {
        get { fetchResultLock.sync { _currentAssetFetchResult } }
        set { fetchResultLock.sync { _currentAssetFetchResult = newValue } }
    }
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
    @Published var showCreateFolderAlert = false {
        didSet {
            if showCreateFolderAlert {
                newFolderName = ""
            }
        }
    }
    @Published var showPhotoPicker = false
    @Published var selectedVideoIds = Set<UUID>()
    @Published var selectedFolderIds = Set<UUID>()
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
    
    // MARK: - Conflict Resolution State
    
    struct ConflictItem: Identifiable {
        let id = UUID()
        let sourceTitle: String
        let sourceDuration: String?
        let sourceSize: Int64
        let sourceURL: URL? // Used for direct file imports
        let sourceVideo: VideoItem? // Used for paste operations
        let destinationURL: URL? // Optional for local folder operations
        let destinationAlbum: PHAssetCollection? // For gallery operations
        let destinationAsset: PHAsset? // The specific asset that conflicts
        let message: String
        
        var destinationTitle: String {
            destinationURL?.lastPathComponent ?? destinationAsset?.localIdentifier ?? "Existing Asset"
        }
        
        var formattedSize: String {
            let bcf = ByteCountFormatter()
            bcf.allowedUnits = [.useAll]
            bcf.countStyle = .file
            return bcf.string(fromByteCount: sourceSize)
        }
    }
    
    enum ConflictAction {
        case skip
        case replace
        case keepBoth
    }
    
    @Published var conflictQueue: [ConflictItem] = []
    @Published var currentConflict: ConflictItem? = nil
    @Published var showConflictResolution: Bool = false
    @Published var conflictOperation: OperationType = .paste
    
    enum OperationType {
        case paste
        case fileImport
        case galleryPaste
    }

    // Paste State
    @Published var pendingPasteDestination: URL? = nil
    @Published var pendingPasteItems: [VideoItem] = []
    @Published var processedPasteItems: [VideoItem] = []
    @Published var pendingPasteNames: [String] = []
    @Published var processedPasteNames: [String] = []
    @Published var isPasteMoveOperation: Bool = false
    @Published var pendingGalleryAlbum: PHAssetCollection? = nil
    
    // Generic Import State
    @Published var pendingImportDestination: URL? = nil
    @Published var pendingImportURLs: [URL] = []
    @Published var processedImportURLs: [URL] = []
    @Published var pendingImportNames: [String] = []
    @Published var processedImportNames: [String] = []
    @Published var isImportMoveOperation: Bool = false
    private var tempExistingAlbumTitles: Set<String> = []

    
    var sortedFolders: [Folder] {
        let option = SortOption(rawValue: folderSortOptionRaw) ?? .dateDesc
        
        return folders.sorted { f1, f2 in
            switch option {
            case .recents:
                let date1 = f1.lastAccessedDate ?? f1.creationDate
                let date2 = f2.lastAccessedDate ?? f2.creationDate
                return date1 > date2
            case .nameAsc:
                return f1.name.localizedStandardCompare(f2.name) == .orderedAscending
            case .nameDesc:
                return f1.name.localizedStandardCompare(f2.name) == .orderedDescending
            case .dateDesc:
                return f1.creationDate > f2.creationDate
            case .dateAsc:
                return f1.creationDate < f2.creationDate
            default:
                return f1.creationDate > f2.creationDate
            }
        }
    }
    
    var groupedFolders: [FolderSection] {
        let option = SortOption(rawValue: folderSortOptionRaw) ?? .dateDesc
        
        // Date sections only for Recents, Newest First, and Oldest First
        guard option == .recents || option == .dateDesc || option == .dateAsc else {
            return [FolderSection(date: .distantPast, folders: sortedFolders)]
        }
        
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sortedFolders) { folder -> Date in
            let date = option == .recents ? (folder.lastAccessedDate ?? folder.creationDate) : folder.creationDate
            return calendar.startOfDay(for: date)
        }
        
        let sortedDates = grouped.keys.sorted { d1, d2 in
            return option == .dateAsc ? d1 < d2 : d1 > d2
        }
        
        return sortedDates.map { date in
            FolderSection(date: date, folders: grouped[date] ?? [])
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
            return videos.filter { video in
                video.title.localizedCaseInsensitiveContains(searchText) ||
                (video.url?.lastPathComponent.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var sortedImportedVideos: [VideoItem] {
        return sortVideos(importedVideos, by: videoSortOption)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        loadData()
        setupHistoryObserver()
        setupSearchHistoryObserver()
        setupGroupedVideosObserver()
        setupDemoVideoObserver()
        
        // Register for Photos library changes only if authorized to avoid premature permission prompt
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            PHPhotoLibrary.shared().register(self)
        }
    }
    
    private func setupDemoVideoObserver() {
        RemoteConfigManager.shared.$isDemoVideoEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                if enabled {
                    self?.setupDemoVideoIfEnabled()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupDemoVideoIfEnabled() {
        guard RemoteConfigManager.shared.isDemoVideoEnabled else { return }
        
        let versionKey = "isDemoVideoAdded_v3" // Use new key to ensure both video and srt are added
        let isAdded = UserDefaults.standard.bool(forKey: versionKey)
        guard !isAdded else { return }
        
        // Paths in bundle: "Sample/demo-video.MOV" and "Sample/demo-srt.srt"
        guard let videoBundleURL = Bundle.main.url(forResource: "demo-video", withExtension: "mp4"),
              let srtBundleURL = Bundle.main.url(forResource: "demo-srt", withExtension: "srt") else {
            print("❌ Demo files not found in bundle at 'Sample/'")
            return
        }
        
        let fileManager = FileManager.default
        
        // 1. Copy to ImportedVideos
        let importedDir = importedVideosDirectory
        let destinationVideoURL = importedDir.appendingPathComponent("demo-video.mp4")
        let destinationSrtURL = importedDir.appendingPathComponent("demo-video.srt") // Name it same as video for auto-pick
        
        // 2. Create Folders/demo and copy there
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let foldersDir = documentsURL.appendingPathComponent("Folders", isDirectory: true)
        let demoFolderDir = foldersDir.appendingPathComponent("demo", isDirectory: true)
        let demoFolderVideoURL = demoFolderDir.appendingPathComponent("demo-video.mp4")
        let demoFolderSrtURL = demoFolderDir.appendingPathComponent("demo-video.srt") // Name it same as video
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                // Ensure directories exist
                if !fileManager.fileExists(atPath: importedDir.path) {
                    try fileManager.createDirectory(at: importedDir, withIntermediateDirectories: true)
                }
                if !fileManager.fileExists(atPath: demoFolderDir.path) {
                    try fileManager.createDirectory(at: demoFolderDir, withIntermediateDirectories: true)
                }
                
                // Copy Video to ImportedVideos
                if !fileManager.fileExists(atPath: destinationVideoURL.path) {
                    try fileManager.copyItem(at: videoBundleURL, to: destinationVideoURL)
                    print("✅ Copied demo video to ImportedVideos")
                }
                
                // Copy SRT to ImportedVideos
                if !fileManager.fileExists(atPath: destinationSrtURL.path) {
                    try fileManager.copyItem(at: srtBundleURL, to: destinationSrtURL)
                    print("✅ Copied demo srt to ImportedVideos")
                }
                
                // Copy Video to Folders/demo
                if !fileManager.fileExists(atPath: demoFolderVideoURL.path) {
                    try fileManager.copyItem(at: videoBundleURL, to: demoFolderVideoURL)
                    print("✅ Copied demo video to Folders/demo")
                }
                
                // Copy SRT to Folders/demo
                if !fileManager.fileExists(atPath: demoFolderSrtURL.path) {
                    try fileManager.copyItem(at: srtBundleURL, to: demoFolderSrtURL)
                    print("✅ Copied demo srt to Folders/demo")
                }
                
                UserDefaults.standard.set(true, forKey: versionKey)
                
                DispatchQueue.main.async {
                    self.loadData()
                }
            } catch {
                print("❌ Failed to setup demo video/srt: \(error.localizedDescription)")
            }
        }
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    // PHPhotoLibraryChangeObserver — called on a background thread by the system.
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // Use PHChange.changeDetails to compute ONLY what changed (deleted/inserted)
        // instead of re-enumerating all 10,000 assets on every library event.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            guard let fetchResult = self.currentAssetFetchResult,
                  let details = changeInstance.changeDetails(for: fetchResult) else {
                // No stored result yet, or change cannot be diffed — full refresh.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.fetchAssets()
                    self?.fetchAlbums()
                }
                return
            }

            // Advance the stored snapshot to the latest fetch result.
            self.currentAssetFetchResult = details.fetchResultAfterChanges

            guard details.hasIncrementalChanges else {
                // No video-level changes (e.g., album metadata only) — just refresh albums.
                DispatchQueue.main.async { [weak self] in self?.fetchAlbums() }
                return
            }

            // Build lightweight delta: only the IDs/items that actually changed.
            let removedIds = Set(details.removedObjects.map { self.stableUUID(from: $0.localIdentifier) })
            let insertedItems = details.insertedObjects.map { self.videoItem(from: $0) }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                // 1. Remove deleted videos from gallery list and master search list.
                if !removedIds.isEmpty {
                    self.allGalleryVideos.removeAll { removedIds.contains($0.id) }
                    self.videos.removeAll { removedIds.contains($0.id) }
                }

                // 2. Prepend newly added videos (our sort is newest-first).
                if !insertedItems.isEmpty {
                    self.allGalleryVideos.insert(contentsOf: insertedItems, at: 0)
                    self.preFetchTitles(for: insertedItems)
                }

                // 3. Refresh album cards (counts / cover images may have changed).
                self.fetchAlbums()
            }
        }
    }
    
    private func setupGroupedVideosObserver() {
        // Observer for imported videos tab (uses videoSortOptionRaw)
        Publishers.CombineLatest($importedVideos, $videoSortOptionRaw)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main) // Prevent rapid fire during pre-fetching
            .sink { [weak self] _, _ in
                self?.updateGroupedVideos()
            }
            .store(in: &cancellables)

        // Master list observer for combined videos (Search/etc) - uses DEFAULT (videoSortOptionRaw)
        Publishers.CombineLatest3($importedVideos, $allGalleryVideos, $videoSortOptionRaw)
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] imported, gallery, _ in
                guard let self = self else { return }
                let all = (imported + gallery)
                let sortedAll = self.sortVideos(all, by: self.videoSortOption)
                DispatchQueue.main.async {
                    self.videos = sortedAll
                }
            }
            .store(in: &cancellables)

        // Pre-sort allGalleryVideos for the "All Videos" FolderDetailView.
        // Runs on background so displayVideos never sorts on the main thread.
        Publishers.CombineLatest($allGalleryVideos, $gallerySortOptionRaw)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] videos, _ in
                guard let self = self else { return }
                let sorted = self.sortVideos(videos, by: self.gallerySortOption)
                DispatchQueue.main.async {
                    self.sortedAllGalleryVideos = sorted
                }
            }
            .store(in: &cancellables)
    }
    
    func sortVideos(_ items: [VideoItem], by option: SortOption) -> [VideoItem] {
        return items.sorted {
            switch option {
            case .recents, .dateDesc: return $0.importDate > $1.importDate
            case .dateAsc: return $0.importDate < $1.importDate
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
        let itemsToGroup = importedVideos
        
        // Perform heavy sorting/grouping on background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let sorted = self.sortVideos(itemsToGroup, by: currentSort)
            
            var newSections: [VideoSection] = []
            
            switch currentSort {
            case .recents, .dateDesc, .dateAsc:
                let grouped = Dictionary(grouping: sorted) { video -> Date in
                    calendar.startOfDay(for: video.importDate)
                }
                
                let sortedDates = grouped.keys.sorted(by: { 
                    currentSort == .dateAsc ? $0 < $1 : $0 > $1 
                })
                
                newSections = sortedDates.map { date in
                    let videosInDate = grouped[date] ?? []
                    return VideoSection(date: date, videos: videosInDate)
                }
                
            default:
                // Non-date sorting: provide a single section with a sentinel date for a flat list
                newSections = [VideoSection(date: .distantPast, videos: sorted)]
            }
            
            DispatchQueue.main.async {
                if self.groupedImportedVideos != newSections {
                    self.groupedImportedVideos = newSections
                }
            }
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
                    self.isInitialLoading = false // Folders ready
                    
                    // Fetch durations for all videos in folders in background
                    let allFolderVideos = newFolders.flatMap { folder -> [VideoItem] in
                        func getVideos(from f: Folder) -> [VideoItem] {
                            return f.videos + f.subfolders.flatMap { getVideos(from: $0) }
                        }
                        return getVideos(from: folder)
                    }
                    self.backgroundFetchMetadata(for: allFolderVideos)
                }
            } catch {
                print("Error loading folders: \(error)")
                DispatchQueue.main.async {
                    self.isInitialLoading = false
                }
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
        let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
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
    
    private func videoItem(from url: URL, fast: Bool = true) -> VideoItem? {
        guard DashboardViewModel.supportedVideoExtensions.contains(url.pathExtension.lowercased()) else { return nil }
        
        // 1. Initial metadata (Size and Date)
        let resources = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
        let creationDate = resources?.creationDate ?? Date()
        let size = Int64(resources?.fileSize ?? 0)
        
        // 2. Duration Extraction (Skip if fast=true for instant folder loading)
        var duration: Double = 0
        if !fast {
            let asset = AVURLAsset(url: url)
            duration = CMTimeGetSeconds(asset.duration)
            if duration.isNaN { duration = 0 }
            
            // Comprehensive fallback for duration (Legacy formats or corrupt files)
            if duration <= 0 {
                let media = VLCMedia(url: url)
                // Parse and poll for duration to allow VLC to index legacy formats like MPEG/RM/VOB.
                media.parse(options: .fetchLocal, timeout: 5000)
                // Poll for length (usually available very quickly for local files after parse)
                var pollCount = 0
                while media.length.intValue <= 0 && pollCount < 15 {
                    Thread.sleep(forTimeInterval: 0.1)
                    pollCount += 1
                }
                
                let length = media.length.intValue
                if length > 0 {
                    duration = Double(length) / 1000.0
                }
            }
        }
        
        return VideoItem(
            id: stableUUID(from: url.absoluteString),
            asset: nil,
            title: url.lastPathComponent,
            duration: duration,
            creationDate: creationDate,
            importDate: creationDate, // For local files, the file date is the import date
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
            importDate: asset.creationDate ?? Date(), // Use capture date for Gallery sorting till it is imported
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
                let name = url.lastPathComponent
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
                let name = (first.originalFilename as NSString) as String
                bestFilename = name
            }
            
            // 2. Fallback to KVC if needed
            if bestFilename == nil {
                if let filename = asset.value(forKey: "filename") as? String {
                    let name = (filename as NSString) as String
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
    
    // Static formatters for fallbackTitle — called per video when title resolution fails.
    private static let screenRecordingDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy, HH:mm"
        return f
    }()
    private static let fallbackVideoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private func fallbackTitle(for asset: PHAsset, video: VideoItem, bestFilename: String?, completion: @escaping (String) -> Void) {
        // 1. If we found a valid filename (even generic), use it.
        if let filename = bestFilename, !filename.isEmpty {
            DispatchQueue.main.async { completion(filename) }
            return
        }

        // 2. Check for screen recordings specifically
        if asset.mediaSubtypes.contains(.videoScreenRecording) {
            let dateStr = Self.screenRecordingDateFormatter.string(from: asset.creationDate ?? Date())
            DispatchQueue.main.async { completion("Screen Recording \(dateStr)") }
            return
        }

        // 3. If we have any existing title that isn't a placeholder, keep it
        if video.title != VideoItem.titlePlaceholder && !video.title.isEmpty {
            DispatchQueue.main.async { completion(video.title) }
            return
        }

        // 4. Ultimate fallback: Date-based title
        let fallback = "Video " + Self.fallbackVideoDateFormatter.string(from: asset.creationDate ?? Date())
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
        
        // Initialize State for Conflict Checking
        self.pendingGalleryAlbum = album
        self.isPasteMoveOperation = isCutMode
        self.conflictOperation = .galleryPaste
        self.pendingPasteItems = []
        self.processedPasteItems = []
        self.pendingPasteNames = []
        self.processedPasteNames = []
        self.conflictQueue = []
        
        isImporting = true

        Task {
            var conflicts: [ConflictItem] = []
            var safeItems: [VideoItem] = []
            var safeNames: [String] = []
            
            // If target is an album, check for name conflicts
            var existingTitles: [String: PHAsset] = [:]
            if let album = album {
                existingTitles = await getExistingVideoTitlesInAlbum(album)
            }
            let allTitles = Set(existingTitles.keys)
            await MainActor.run {
                self.tempExistingAlbumTitles = allTitles
            }
            
            for video in videosToPaste {
                let filename = video.fullNameWithExtension
                
                if let conflictAsset = existingTitles[filename] {
                    // Conflict found in Gallery Album!
                    let conflict = ConflictItem(
                        sourceTitle: video.title,
                        sourceDuration: video.formattedDuration,
                        sourceSize: video.fileSizeBytes,
                        sourceURL: await getURLAsync(for: video),
                        sourceVideo: video,
                        destinationURL: nil,
                        destinationAlbum: album,
                        destinationAsset: conflictAsset,
                        message: "A video named \"\(filename)\" already exists in this album."
                    )
                    conflicts.append(conflict)
                    
                    self.pendingPasteItems.append(video)
                    self.pendingPasteNames.append(filename)
                } else {
                    // No conflict (at least by name)
                    safeItems.append(video)
                    safeNames.append(filename)
                }
            }
            
            await MainActor.run {
                self.processedPasteItems.append(contentsOf: safeItems)
                self.processedPasteNames.append(contentsOf: safeNames)
                
                if !conflicts.isEmpty {
                    self.conflictQueue = conflicts
                    self.currentConflict = conflicts.first
                    self.showConflictResolution = true
                    self.isImporting = false // Stop progress if we need user input
                } else {
                    self.finalizeGalleryPasteOperation()
                }
            }
        }
    }
    
    private func getExistingVideoTitlesInAlbum(_ album: PHAssetCollection) async -> [String: PHAsset] {
        return await Task.detached {
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
            let assets = PHAsset.fetchAssets(in: album, options: fetchOptions)
            
            var titlesMap: [String: PHAsset] = [:]
            assets.enumerateObjects { asset, _, _ in
                let resources = PHAssetResource.assetResources(for: asset)
                if let filename = resources.first?.originalFilename {
                    titlesMap[filename] = asset
                }
            }
            return titlesMap
        }.value
    }

    private func handleGalleryPasteConflict(current: ConflictItem, action: ConflictAction, applyToAll: Bool) {
        let identifier = current.destinationAsset?.localIdentifier ?? current.sourceTitle
        guard let index = pendingPasteNames.firstIndex(of: identifier) else {
            processNextConflict()
            return
        }
        
        let video = pendingPasteItems[index]
        let originalName = pendingPasteNames[index]
        
        switch action {
        case .skip:
            break
        case .replace:
            // "Replace" is hidden in UI for Gallery operations, but keep logic safe just in case
            processedPasteItems.append(video)
            processedPasteNames.append(originalName)
            if let asset = current.destinationAsset {
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.deleteAssets([asset] as NSArray)
                }
            }
        case .keepBoth:
            // 1. Same Asset ID Check (Gallery -> Gallery)
            if let destAsset = current.destinationAsset, let sourceAsset = video.asset, destAsset.localIdentifier == sourceAsset.localIdentifier {
                // If it's the exact same asset, just skip adding it again to avoid issues
                break
            }
            
            // 2. Different Asset (Import -> Gallery OR Different Asset Same Name)
            // Generate unique name for the new file import to avoid collision
            let fileManager = FileManager.default
            let baseName = (originalName as NSString).deletingPathExtension
            let ext = (originalName as NSString).pathExtension
            var counter = 1
            var uniqueName = originalName
            
            // Check against existing names (destination asset local ID isn't a filename check, but we assume conflict means name match)
            // We use a simple counter strategy just to be safe if we are importing a file
            if video.asset == nil {
                // Only rename for local file imports
                // Check against processed names AND existing album content
                while processedPasteNames.contains(uniqueName) || tempExistingAlbumTitles.contains(uniqueName) {
                    uniqueName = "\(baseName) (\(counter)).\(ext)"
                    counter += 1
                }
                
                while processedPasteNames.contains(uniqueName) || tempExistingAlbumTitles.contains(uniqueName) {
                    uniqueName = "\(baseName) (\(counter)).\(ext)"
                    counter += 1
                }
            }
            
            processedPasteItems.append(video)
            processedPasteNames.append(uniqueName)
        }
        
        pendingPasteItems.remove(at: index)
        pendingPasteNames.remove(at: index)
        
        if applyToAll {
            let remaining = conflictQueue.dropFirst()
            for conflict in remaining {
                let pId = conflict.destinationAsset?.localIdentifier ?? conflict.sourceTitle
                guard let pIndex = pendingPasteNames.firstIndex(of: pId) else { continue }
                let pVideo = pendingPasteItems[pIndex]
                
                switch action {
                case .skip: break
                case .replace:
                    processedPasteItems.append(pVideo)
                    processedPasteNames.append(conflict.sourceTitle)
                    if let asset = conflict.destinationAsset {
                        PHPhotoLibrary.shared().performChanges {
                            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
                        }
                    }
                case .keepBoth:
                    processedPasteItems.append(pVideo)
                    processedPasteNames.append(conflict.sourceTitle)
                }
            }
            conflictQueue.removeAll()
            currentConflict = nil
            showConflictResolution = false
            finalizeGalleryPasteOperation()
            return
        }
        
        processNextConflict()
    }

    private func finalizeGalleryPasteOperation() {
        guard !processedPasteItems.isEmpty else {
            cleanupPasteState()
            isImporting = false
            return
        }
        
        let album = pendingGalleryAlbum
        let wasCutMode = isPasteMoveOperation
        let sourceId = sourceAlbumIdentifier
        
        isImporting = true
        
        Task {
            let galleryVideos = processedPasteItems.filter { $0.asset != nil }
            let localVideos = processedPasteItems.filter { $0.asset == nil }
            
            // 1. Existing Gallery Assets
            if !galleryVideos.isEmpty, let album = album {
                let assetsToAdd = galleryVideos.compactMap { $0.asset }
                do {
                    try await PHPhotoLibrary.shared().performChanges {
                        let request = PHAssetCollectionChangeRequest(for: album)
                        request?.addAssets(assetsToAdd as NSArray)
                    }
                } catch {
                    print("❌ Gallery Paste error: \(error)")
                }
            }
            
                // 2. Local Videos (Import)
            if !localVideos.isEmpty {
                var urls: [URL] = []
                var tempFilePaths: [URL] = []
                
                for video in localVideos {
                    // Check if we have a rename request in processedPasteNames
                    guard let index = processedPasteItems.firstIndex(where: { $0.id == video.id }) else { continue }
                    
                    if let originalURL = await getURLAsync(for: video) {
                        let targetName = processedPasteNames[index]
                        if targetName != video.fullNameWithExtension {
                            // Rename Required! Re-export to new container to ensure unique hash
                            // iOS Photos aggressively deduplicates based on content hash.
                            // AVAssetExportSession with passthrough creates a new container structure.
                            let tempDir = FileManager.default.temporaryDirectory
                            let newURL = tempDir.appendingPathComponent(targetName)
                            
                            let asset = AVAsset(url: originalURL)
                            if let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) {
                                exportSession.outputURL = newURL
                                
                                let ext = (targetName as NSString).pathExtension.lowercased()
                                if ext == "mov" {
                                    exportSession.outputFileType = .mov
                                } else if ext == "m4v" {
                                    exportSession.outputFileType = .m4v
                                } else {
                                    exportSession.outputFileType = .mp4
                                }
                                
                                await exportSession.export()
                                
                                if exportSession.status == .completed {
                                    urls.append(newURL)
                                    tempFilePaths.append(newURL)
                                } else {
                                    print("⚠️ Export failed: \(String(describing: exportSession.error))")
                                    // Fallback to copy + null byte hack if export fails
                                    try? FileManager.default.copyItem(at: originalURL, to: newURL)
                                    do {
                                        let handle = try FileHandle(forWritingTo: newURL)
                                        defer {
                                            if #available(iOS 13.0, *) { try? handle.close() }
                                            else { handle.closeFile() }
                                        }
                                        if #available(iOS 13.4, *) {
                                            try handle.seekToEnd(); try handle.write(contentsOf: Data([0]))
                                        } else {
                                            handle.seekToEndOfFile(); handle.write(Data([0]))
                                        }
                                    } catch { print("⚠️ Hash mod failed: \(error)") }
                                    urls.append(newURL)
                                    tempFilePaths.append(newURL)
                                }
                            } else {
                                // Fallback if session creation fails
                                try? FileManager.default.copyItem(at: originalURL, to: newURL)
                                urls.append(newURL)
                                tempFilePaths.append(newURL)
                            }
                        } else {
                            urls.append(originalURL)
                        }
                    }
                }
                
                if !urls.isEmpty {
                    do {
                        try await PHPhotoLibrary.shared().performChanges {
                            let requests = urls.map { PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: $0) }
                            if let album = album {
                                let placeholders = requests.compactMap({ $0?.placeholderForCreatedAsset })
                                if !placeholders.isEmpty {
                                    let albumRequest = PHAssetCollectionChangeRequest(for: album)
                                    albumRequest?.addAssets(placeholders as NSArray)
                                }
                            }
                        }
                        // Cleanup temp files
                        for url in tempFilePaths {
                            try? FileManager.default.removeItem(at: url)
                        }
                    } catch {
                         print("❌ Gallery Import error: \(error)")
                    }
                }
            }
            
            // 3. Move Cleanup (Remove from Source Album)
            if wasCutMode, let sourceId = sourceId {
                let sourceCollections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [sourceId], options: nil)
                if let sourceAlbum = sourceCollections.firstObject {
                    let assetsToRemove = galleryVideos.compactMap { $0.asset } as NSArray
                    if assetsToRemove.count > 0 {
                        try? await PHPhotoLibrary.shared().performChanges {
                            PHAssetCollectionChangeRequest(for: sourceAlbum)?.removeAssets(assetsToRemove)
                        }
                    }
                }
            }
            
            // 4. Move Cleanup (Delete local files if were moved)
            if wasCutMode && !localVideos.isEmpty {
                 await MainActor.run {
                     for video in localVideos {
                         self.deleteVideo(video)
                     }
                 }
            }
            
            await MainActor.run {
                self.isImporting = false
                self.cleanupPasteState()
                self.loadData()
            }
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

        // Initialize State for Conflict Checking
        self.pendingPasteDestination = destination
        self.isPasteMoveOperation = isCutMode
        self.conflictOperation = .paste
        self.pendingPasteItems = []
        self.processedPasteItems = []
        self.pendingPasteNames = []
        self.processedPasteNames = []
        self.conflictQueue = []

        Task {
            var conflicts: [ConflictItem] = []
            var safeItems: [VideoItem] = []
            var safeNames: [String] = []

            for video in videosToPaste {
                // Resolve filename WITHOUT slow async URL resolution:
                // • PHAsset: read original filename from PHAssetResource (synchronous, zero network calls)
                // • Local file: use url.lastPathComponent directly
                // The old approach called requestAVAsset per asset — for 1720 gallery videos that meant
                // 30+ minutes of sequential async waiting before the operation could even start.
                let filename: String
                if let asset = video.asset {
                    filename = PHAssetResource.assetResources(for: asset).first?.originalFilename ?? video.title
                } else if let url = video.url {
                    filename = url.lastPathComponent
                } else {
                    continue // orphan item with neither asset nor url
                }

                let destinationURL = destination.appendingPathComponent(filename)

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    // Conflict found — sourceURL only needed for local files (conflict UI preview)
                    let conflict = ConflictItem(
                        sourceTitle: video.title,
                        sourceDuration: video.formattedDuration,
                        sourceSize: video.fileSizeBytes,
                        sourceURL: video.url, // nil for PHAssets — that's fine
                        sourceVideo: video,
                        destinationURL: destinationURL,
                        destinationAlbum: nil,
                        destinationAsset: nil,
                        message: "A file named \"\(filename)\" already exists in this folder."
                    )
                    conflicts.append(conflict)
                    self.pendingPasteItems.append(video)
                    self.pendingPasteNames.append(filename)
                } else {
                    safeItems.append(video)
                    safeNames.append(filename)
                }
            }

            await MainActor.run {
                self.processedPasteItems.append(contentsOf: safeItems)
                self.processedPasteNames.append(contentsOf: safeNames)

                if !conflicts.isEmpty {
                    self.conflictQueue = conflicts
                    self.currentConflict = conflicts.first
                    self.showConflictResolution = true
                } else {
                    self.finalizePasteOperation()
                }
            }
        }
    }
    
    func resolveConflict(action: ConflictAction, applyToAll: Bool) {
        guard let current = currentConflict else {
            processNextConflict()
            return
        }
        
        if conflictOperation == .paste {
            handlePasteConflict(current: current, action: action, applyToAll: applyToAll)
        } else if conflictOperation == .fileImport {
            handleImportConflict(current: current, action: action, applyToAll: applyToAll)
        } else {
            handleGalleryPasteConflict(current: current, action: action, applyToAll: applyToAll)
        }
    }
    
    private func handlePasteConflict(current: ConflictItem, action: ConflictAction, applyToAll: Bool) {
        let identifier = current.destinationURL?.lastPathComponent ?? current.sourceTitle
        guard let index = pendingPasteNames.firstIndex(of: identifier) else {
            processNextConflict()
            return
        }
        
        let video = pendingPasteItems[index]
        let originalName = pendingPasteNames[index]
        
        // Define logic for Current Item
        switch action {
        case .skip:
            // Do not add to processed list. Just remove from pending.
            break
        case .replace:
            // Add to processed list. Import logic will overwrite.
            processedPasteItems.append(video)
            processedPasteNames.append(originalName)
            
            // Should delete existing file at destination to ensure clean replace?
            // Actually importVideos handles overwrite if we implement it, 
            // OR we can delete it right here.
            // Let's delete strictly here to be safe and ensure the "Replace" logic holds.
            if let destURL = current.destinationURL {
                try? FileManager.default.removeItem(at: destURL)
            }
            
        case .keepBoth:
            // Generate new name: "Video (1).mp4"
            let fileManager = FileManager.default
            let baseName = (originalName as NSString).deletingPathExtension
            let ext = (originalName as NSString).pathExtension
            var counter = 1
            var uniqueName = originalName
            
            while (current.destinationURL != nil && fileManager.fileExists(atPath: current.destinationURL!.deletingLastPathComponent().appendingPathComponent(uniqueName).path)) ||
                    processedPasteNames.contains(uniqueName) { // Also check against names we just decided to add
                uniqueName = "\(baseName) (\(counter)).\(ext)"
                counter += 1
            }
            
            processedPasteItems.append(video)
            processedPasteNames.append(uniqueName)
        }
        
        // Remove from pending now that we decided
        pendingPasteItems.remove(at: index)
        pendingPasteNames.remove(at: index)
        
        // Apply to All Logic
        if applyToAll {
            // We need to apply the SAME action to all remaining items in the conflict queue
            // But we must be careful: "Keep Both" implies generating unique names for each.
            // "Replace" implies deleting existing for each.
            // "Skip" implies dropping each.
            
            // The conflictQueue contains the REMAINING conflicts (including current).
            // We already handled 'current'. Now handle the rest.
            let remainingConflicts = conflictQueue.dropFirst()
            
            for conflict in remainingConflicts {
                guard let destURL = conflict.destinationURL else { continue }
                guard let pIndex = pendingPasteNames.firstIndex(of: destURL.lastPathComponent) else { continue }
                let pVideo = pendingPasteItems[pIndex]
                let pName = pendingPasteNames[pIndex]
                
                switch action {
                case .skip:
                    break
                case .replace:
                    processedPasteItems.append(pVideo)
                    processedPasteNames.append(pName)
                    if let destURL = conflict.destinationURL {
                        try? FileManager.default.removeItem(at: destURL)
                    }
                case .keepBoth:
                    let fileManager = FileManager.default
                    let baseName = (pName as NSString).deletingPathExtension
                    let ext = (pName as NSString).pathExtension
                    var counter = 1
                    var uniqueName = pName
                    
                    while (conflict.destinationURL != nil && fileManager.fileExists(atPath: conflict.destinationURL!.deletingLastPathComponent().appendingPathComponent(uniqueName).path)) ||
                            processedPasteNames.contains(uniqueName) {
                        uniqueName = "\(baseName) (\(counter)).\(ext)"
                        counter += 1
                    }
                    processedPasteItems.append(pVideo)
                    processedPasteNames.append(uniqueName)
                }
                
                // We don't remove from pending loop here safely, so just let the queue finish
            }
            
            // Clear pending since we've handled all
            pendingPasteItems.removeAll()
            pendingPasteNames.removeAll()

            // Clear queue effectively
            conflictQueue.removeAll()
            currentConflict = nil
            showConflictResolution = false
            finalizePasteOperation()
            return
        }
        
        // Move to next
        processNextConflict()
    }
    
    private func processNextConflict() {
        if !conflictQueue.isEmpty {
            conflictQueue.removeFirst()
        }
        
        if let next = conflictQueue.first {
            currentConflict = next
        } else {
            showConflictResolution = false
            currentConflict = nil
            if conflictOperation == .paste {
                finalizePasteOperation()
            } else if conflictOperation == .fileImport {
                finalizeImportOperation()
            } else {
                finalizeGalleryPasteOperation()
            }
        }
    }
    
    // MARK: - New Import Flow with Conflicts
    
    private func handleImportConflict(current: ConflictItem, action: ConflictAction, applyToAll: Bool) {
        let identifier = current.destinationURL?.lastPathComponent ?? current.sourceTitle
        guard let index = pendingImportNames.firstIndex(of: identifier) else {
            processNextConflict()
            return
        }
        
        let url = pendingImportURLs[index]
        let originalName = pendingImportNames[index]
        
        switch action {
        case .skip:
            break
        case .replace:
            processedImportURLs.append(url)
            processedImportNames.append(originalName)
            if let destURL = current.destinationURL {
                try? FileManager.default.removeItem(at: destURL)
            }
        case .keepBoth:
            let fileManager = FileManager.default
            let baseName = (originalName as NSString).deletingPathExtension
            let ext = (originalName as NSString).pathExtension
            var counter = 1
            var uniqueName = originalName
            while (current.destinationURL != nil && fileManager.fileExists(atPath: current.destinationURL!.deletingLastPathComponent().appendingPathComponent(uniqueName).path)) ||
                    processedImportNames.contains(uniqueName) {
                uniqueName = "\(baseName) (\(counter)).\(ext)"
                counter += 1
            }
            processedImportURLs.append(url)
            processedImportNames.append(uniqueName)
        }
        
        pendingImportURLs.remove(at: index)
        pendingImportNames.remove(at: index)
        
        if applyToAll {
            let remainingConflicts = conflictQueue.dropFirst()
            for conflict in remainingConflicts {
                guard let destURL = conflict.destinationURL else { continue }
                guard let pIndex = pendingImportNames.firstIndex(of: destURL.lastPathComponent) else { continue }
                let pURL = pendingImportURLs[pIndex]
                let pName = pendingImportNames[pIndex]
                
                switch action {
                case .skip:
                    break
                case .replace:
                    processedImportURLs.append(pURL)
                    processedImportNames.append(pName)
                    if let destURL = conflict.destinationURL {
                        try? FileManager.default.removeItem(at: destURL)
                    }
                case .keepBoth:
                    let fileManager = FileManager.default
                    let baseName = (pName as NSString).deletingPathExtension
                    let ext = (pName as NSString).pathExtension
                    var counter = 1
                    var uniqueName = pName
                    while (conflict.destinationURL != nil && fileManager.fileExists(atPath: conflict.destinationURL!.deletingLastPathComponent().appendingPathComponent(uniqueName).path)) ||
                            processedImportNames.contains(uniqueName) {
                        uniqueName = "\(baseName) (\(counter)).\(ext)"
                        counter += 1
                    }
                    processedImportURLs.append(pURL)
                    processedImportNames.append(uniqueName)
                    if let destURL = conflict.destinationURL {
                        try? FileManager.default.removeItem(at: destURL)
                    }
                }
            }
            
            // Clear pending since we've handled all
            pendingImportURLs.removeAll()
            pendingImportNames.removeAll()
            
            conflictQueue.removeAll()
            currentConflict = nil
            showConflictResolution = false
            finalizeImportOperation()
            return
        }
        processNextConflict()
    }

    func initiateImportFlow(urls: [URL], names: [String]? = nil, to destination: URL? = nil, shouldMove: Bool = false) {
        let targetDirectory = destination ?? self.activeImportFolderURL ?? self.importedVideosDirectory
        
        self.pendingImportDestination = targetDirectory
        self.isImportMoveOperation = shouldMove
        self.conflictOperation = .fileImport
        self.pendingImportURLs = urls
        self.processedImportURLs = []
        self.pendingImportNames = names ?? urls.map { $0.lastPathComponent }
        self.processedImportNames = []
        self.conflictQueue = []
        
        Task {
            var conflicts: [ConflictItem] = []
            var safeURLs: [URL] = []
            var safeNames: [String] = []
            
            for (index, url) in self.pendingImportURLs.enumerated() {
                let filename = self.pendingImportNames[index]
                let destinationURL = targetDirectory.appendingPathComponent(filename)
                
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    // Check if SAME source
                    if url.path == destinationURL.path {
                        safeURLs.append(url)
                        safeNames.append(filename)
                        continue
                    }
                    
                    // Fetch metadata for conflict UI
                    let asset = AVURLAsset(url: url)
                    let duration: CMTime? = try? await asset.load(.duration)
                    let durationStr = duration.map { VideoItem(title: "", duration: $0.seconds, creationDate: Date(), fileSizeBytes: 0).formattedDuration }
                    let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    
                    let conflict = ConflictItem(
                        sourceTitle: filename,
                        sourceDuration: durationStr,
                        sourceSize: Int64(fileSize),
                        sourceURL: url,
                        sourceVideo: nil,
                        destinationURL: destinationURL,
                        destinationAlbum: nil,
                        destinationAsset: nil,
                        message: "A file named \"\(filename)\" already exists in this folder."
                    )
                    conflicts.append(conflict)
                } else {
                    safeURLs.append(url)
                    safeNames.append(filename)
                }
            }
            
            await MainActor.run {
                self.processedImportURLs.append(contentsOf: safeURLs)
                self.processedImportNames.append(contentsOf: safeNames)
                
                // Remove safe items from pending
                for url in safeURLs {
                    if let idx = self.pendingImportURLs.firstIndex(of: url) {
                        self.pendingImportURLs.remove(at: idx)
                        self.pendingImportNames.remove(at: idx)
                    }
                }
                
                if !conflicts.isEmpty {
                    self.conflictQueue = conflicts
                    self.currentConflict = conflicts.first
                    self.showConflictResolution = true
                } else {
                    self.finalizeImportOperation()
                }
            }
        }
    }

    private func finalizeImportOperation() {
        guard let destination = pendingImportDestination, !processedImportURLs.isEmpty else {
            cleanupImportState()
            return
        }
        
        Task {
            await self.importVideos(from: processedImportURLs, names: processedImportNames, to: destination, shouldMove: isImportMoveOperation)
            await MainActor.run {
                cleanupImportState()
                self.loadImportedVideos()
                self.loadUserFolders()
            }
        }
    }

    private func cleanupImportState() {
        self.pendingImportDestination = nil
        self.pendingImportURLs = []
        self.processedImportURLs = []
        self.pendingImportNames = []
        self.processedImportNames = []
        self.conflictQueue = []
        self.currentConflict = nil
        self.showConflictResolution = false
    }
    
    // The Final Step: Actually Run the Import
    private func finalizePasteOperation() {
        guard let destination = pendingPasteDestination, !processedPasteItems.isEmpty else {
            cleanupPasteState()
            return
        }

        Task {
            // Split into PHAsset-backed and local-file-backed videos while keeping
            // index alignment: processedPasteItems[i] ↔ processedPasteNames[i].
            var localURLs: [URL] = []
            var localNames: [String] = []
            var assetItems: [(video: VideoItem, name: String)] = []

            for (video, name) in zip(processedPasteItems, processedPasteNames) {
                if video.asset != nil {
                    assetItems.append((video, name))
                } else if let url = video.url {
                    localURLs.append(url)
                    localNames.append(name)
                }
                // Items with neither asset nor url are silently skipped (orphans)
            }

            // 1. Export PHAsset videos directly to destination.
            //    PHAssetResourceManager.writeData copies the original file bytes — no requestAVAsset,
            //    no re-encoding, works for on-device AND iCloud assets.
            let exportOptions = PHAssetResourceRequestOptions()
            exportOptions.isNetworkAccessAllowed = true
            for (video, name) in assetItems {
                guard let asset = video.asset,
                      let resource = PHAssetResource.assetResources(for: asset).first else { continue }
                let destURL = destination.appendingPathComponent(name)
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    PHAssetResourceManager.default().writeData(for: resource, toFile: destURL, options: exportOptions) { _ in
                        continuation.resume()
                    }
                }
            }

            // 2. Copy/move local file videos using importVideos (handles progress, history, dedup).
            if !localURLs.isEmpty {
                await importVideos(from: localURLs, names: localNames, to: destination, shouldMove: isPasteMoveOperation)
            }

            // 3. Move cleanup.
            await MainActor.run {
                if isPasteMoveOperation {
                    // Remove successfully moved local-file videos from importedVideos list
                    for video in processedPasteItems where video.asset == nil {
                        if let url = video.url, !FileManager.default.fileExists(atPath: url.path) {
                            withAnimation { self.importedVideos.removeAll { $0.id == video.id } }
                        }
                    }

                    // Remove PHAsset videos from source album if they were cut from a specific album
                    if let albumId = sourceAlbumIdentifier {
                        let galleryVideos = processedPasteItems.filter { $0.asset != nil }
                        if !galleryVideos.isEmpty {
                            Task {
                                let sourceCollections = PHAssetCollection.fetchAssetCollections(
                                    withLocalIdentifiers: [albumId], options: nil)
                                if let sourceAlbum = sourceCollections.firstObject {
                                    try? await PHPhotoLibrary.shared().performChanges {
                                        let assetsToRemove = galleryVideos.compactMap { $0.asset } as NSArray
                                        PHAssetCollectionChangeRequest(for: sourceAlbum)?.removeAssets(assetsToRemove)
                                    }
                                    await MainActor.run { self.loadData() }
                                }
                            }
                        }
                    }
                }

                cleanupPasteState()
                self.loadImportedVideos()
                self.loadUserFolders()
            }
        }
    }
    
    private func cleanupPasteState() {
        self.copiedVideoIds.removeAll()
        self.isCutMode = false
        self.sourceURL = nil
        self.sourceAlbumIdentifier = nil
        self.isSelectionMode = false
        self.selectedVideoIds.removeAll()
        
        self.pendingPasteDestination = nil
        self.pendingPasteItems = []
        self.processedPasteItems = []
        self.pendingPasteNames = []
        self.processedPasteNames = []
        self.conflictQueue = []
        self.currentConflict = nil
        self.showConflictResolution = false
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
        deleteVideos(ids: Set([video.id]))
    }
    
    func deleteVideos(ids: Set<UUID>) {
        // Collect videos to delete
        let allVideos = importedVideos + allGalleryVideos + allVideosAcrossFolders
        let videosToDelete = allVideos.filter { ids.contains($0.id) }
        
        guard !videosToDelete.isEmpty else { return }
        
        let localVideos = videosToDelete.filter { $0.asset == nil }
        let galleryVideos = videosToDelete.filter { $0.asset != nil }
        let localIds = Set(localVideos.map { $0.id })
        
        // 1. Immediate UI update for smooth animation ONLY for local videos
        if !localIds.isEmpty {
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    self.importedVideos.removeAll { localIds.contains($0.id) }
                    
                    // Update master lists silently
                    self.videos.removeAll { localIds.contains($0.id) }
                    
                    // Update folders recursively without full reload
                    func removeFromFolderRecursively(_ folder: inout Folder) {
                        folder.videos.removeAll { localIds.contains($0.id) }
                        for j in 0..<folder.subfolders.count {
                            removeFromFolderRecursively(&folder.subfolders[j])
                        }
                    }
                    
                    for i in 0..<self.folders.count {
                        removeFromFolderRecursively(&self.folders[i])
                    }
                    
                    // If it was the playing video, stop it
                    if let playing = self.playingVideo, localIds.contains(playing.id) {
                        self.playingVideo = nil
                    }
                    
                    // Update grouping for Imported section manually for smoothness
                    self.updateGroupedVideos()
                }
            }
        }
        
        // 2. Physical Deletion - Local Files
        if !localVideos.isEmpty {
            DispatchQueue.global(qos: .userInitiated).async {
                for video in localVideos {
                    if let url = video.url {
                        try? FileManager.default.removeItem(at: url)
                        print("✅ Deleted video file: \(url.lastPathComponent)")
                    }
                }
            }
        }
        
        // 3. Physical Deletion - Gallery Assets (Batch)
        let assetsToDelete = galleryVideos.compactMap { $0.asset }
        let galleryIds = Set(galleryVideos.map { $0.id })
        
        if !assetsToDelete.isEmpty {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
            }) { success, error in
                if success {
                    print("✅ Successfully deleted \(assetsToDelete.count) assets from Gallery")
                    // ONLY remove from UI if the system deletion actually succeeded
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            self.allGalleryVideos.removeAll { galleryIds.contains($0.id) }
                            self.videos.removeAll { galleryIds.contains($0.id) }
                            
                            func removeFromFolderRecursively(_ folder: inout Folder) {
                                folder.videos.removeAll { galleryIds.contains($0.id) }
                                for j in 0..<folder.subfolders.count {
                                    removeFromFolderRecursively(&folder.subfolders[j])
                                }
                            }
                            
                            for i in 0..<self.folders.count {
                                removeFromFolderRecursively(&self.folders[i])
                            }
                            
                            if let playing = self.playingVideo, galleryIds.contains(playing.id) {
                                self.playingVideo = nil
                            }
                            
                            // Update Gallery counts immediately
                            self.performAlbumFetch()
                        }
                    }
                } else {
                    print("❌ Failed to delete assets or user canceled: \(error?.localizedDescription ?? "user canceled")")
                    // No UI removal - the items stay in place since deletion was rejected or failed
                }
            }
        }
    }
    
    func videoActions(for video: VideoItem) -> [CustomActionItem] {
        var items: [CustomActionItem] = []
        
        // Determine source context automatically for search results or generic actions
        let sourceURL = video.url?.deletingLastPathComponent()
        var sourceAlbumId: String? = nil
        if let asset = video.asset {
            // Correct API to find user albums containing this specific asset
            let collections = PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .album, options: nil)
            sourceAlbumId = collections.firstObject?.localIdentifier
        }
        
        items.append(CustomActionItem(title: "Share", icon: "square.and.arrow.up", role: nil, action: {
            self.shareVideo(item: video)
        }))
        
        items.append(CustomActionItem(title: "Copy to", icon: "doc.on.doc", role: nil, action: {
            self.copyVideos(ids: Set([video.id]), isCut: false, sourceURL: sourceURL, sourceAlbumId: sourceAlbumId)
            // Sheet is opened after a short delay to allow background state to settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showMovePicker = true
            }
        }))
        
        items.append(CustomActionItem(title: "Move to", icon: "arrow.right.doc.on.clipboard", role: nil, action: {
            self.copyVideos(ids: Set([video.id]), isCut: true, sourceURL: sourceURL, sourceAlbumId: sourceAlbumId)
            // Sheet is opened after a short delay to allow background state to settle
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
        self.isImportCancelled = false  // always reset before a new session
        self.importCount = count
        self.importCurrentIndex = 0
        self.importProgress = 0.0
        self.importStatusMessage = "Starting..."
    }
    
    func finalizeImportSession() {
        self.loadData()
        self.isImporting = false
        self.isImportCancelled = false
        self.importProgress = 0.0
        self.importStatusMessage = ""
        self.isSelectionMode = false
    }
    
    /// cancelImport
    /// - Description: Signals the running importVideos loop to stop after the current file. Already-copied
    ///   files remain in the library (user keeps partial progress).
    /// - How to use: Called from the Cancel button in ImportingOverlay.
    func cancelImport() {
        isImportCancelled = true
        importStatusMessage = "Cancelling…"
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
                self.isImportCancelled = false  // reset so a new session always starts clean
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
                // Check cancellation before starting each new file.
                // Already-copied files are kept; only the remaining queue is skipped.
                let cancelled = await MainActor.run { self.isImportCancelled }
                if cancelled { break }
                
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
                            // Update creation date to 'now' to reflect arrival time in app
                            try? fileManager.setAttributes([.creationDate: Date()], ofItemAtPath: destinationURL.path)
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
                                // Update creation date to 'now' to reflect arrival time in app
                                try? fileManager.setAttributes([.creationDate: Date()], ofItemAtPath: destinationURL.path)
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
    
    func requestPhotoPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            self.showPermissionDenied = false
            fetchAssets()
            fetchAlbums()
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if newStatus == .authorized || newStatus == .limited {
                        PHPhotoLibrary.shared().register(self)
                        self.showPermissionDenied = false
                        self.fetchAssets()
                        self.fetchAlbums()
                        completion(true)
                    } else {
                        self.showPermissionDenied = true
                        completion(false)
                    }
                }
            }
        case .denied, .restricted:
            self.showPermissionDenied = true
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            PHPhotoLibrary.shared().register(self)
            self.showPermissionDenied = false
            fetchAssets()
            fetchAlbums()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.showPermissionDenied = true
            }
        case .notDetermined:
            // Don't request permission here. Let PhotoLibraryAccessView handle it.
            return
        @unknown default:
            break
        }
    }
    
    func fetchAssets() {
        // Move ALL work to background — with 10,000+ gallery videos, enumerating PHAssets
        // on the main thread freezes the UI for hundreds of milliseconds.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)

            let fetchResult = PHAsset.fetchAssets(with: fetchOptions)

            // Store the live result so photoLibraryDidChange can compute deltas
            // instead of re-enumerating all assets on every library change.
            self.currentAssetFetchResult = fetchResult

            var newVideos: [VideoItem] = []
            newVideos.reserveCapacity(fetchResult.count) // Avoid repeated array reallocations

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
    }
    
    func preFetchTitles(for videos: [VideoItem]) {
        // Only pre-fetch the first 30 videos to avoid overwhelming the system.
        let limit = min(videos.count, 30)
        let prioritizedVideos = Array(videos.prefix(limit))

        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            // Collect all resolved titles concurrently, then apply in ONE batch on main thread.
            // Previously each title fired a separate DispatchQueue.main.async, causing
            // 30 separate @Published updates → 30 SwiftUI re-renders + 30 Combine pipeline
            // executions on a 10,000-item list. Now it's a single update.
            let lock = NSLock()
            var resolved: [(id: UUID, title: String)] = []
            resolved.reserveCapacity(limit)
            let group = DispatchGroup()

            for video in prioritizedVideos {
                group.enter()
                self.loadTitle(for: video) { resolvedTitle in
                    lock.lock()
                    resolved.append((id: video.id, title: resolvedTitle))
                    lock.unlock()
                    group.leave()
                }
            }

            group.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                // Build a lookup dict from the resolved entries (O(1) per lookup).
                // Previously used firstIndex(where:) per entry × each collection —
                // O(30 × 10,000) = 300,000 comparisons on the main thread causing lag.
                // Now it's one pass per collection = O(collection_size) total.
                let resolvedTitles = Dictionary(uniqueKeysWithValues: resolved.map { ($0.id, $0.title) })

                for i in 0..<self.allGalleryVideos.count {
                    if let title = resolvedTitles[self.allGalleryVideos[i].id] {
                        self.allGalleryVideos[i].title = title
                    }
                }
                for i in 0..<self.importedVideos.count {
                    if let title = resolvedTitles[self.importedVideos[i].id] {
                        self.importedVideos[i].title = title
                    }
                }
                for i in 0..<self.folders.count {
                    for j in 0..<self.folders[i].videos.count {
                        if let title = resolvedTitles[self.folders[i].videos[j].id] {
                            self.folders[i].videos[j].title = title
                        }
                    }
                }
                for i in 0..<self.videos.count {
                    if let title = resolvedTitles[self.videos[i].id] {
                        self.videos[i].title = title
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
                    return self.videoItem(from: url, fast: true)
                }.sorted(by: { $0.creationDate > $1.creationDate })
                
                DispatchQueue.main.async {
                    self.isInitialLoading = false // Videos ready
                    withAnimation {
                        self.importedVideos = loadedVideos
                        self.isImporting = false
                    }
                    
                    // Start background metadata fetching (Titles, Durations, and Actual Creation Dates)
                    self.backgroundFetchTitles(for: loadedVideos)
                    self.backgroundFetchMetadata(for: loadedVideos)
                    
                    // Pre-warm thumbnail cache in background
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) {
                        ThumbnailCacheManager.shared.prewarmCache(for: loadedVideos)
                    }
                }
            } catch {
                print("Error loading imported videos: \(error)")
                DispatchQueue.main.async {
                    self.isImporting = false
                    self.isInitialLoading = false
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
            importDate: item.timestamp ?? Date(), // Use stored timestamp as import date
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
    
    private func backgroundFetchMetadata(for videos: [VideoItem]) {
        // We fetch for all local videos to ensure actual creation date is retrieved
        let localVideos = videos.filter { $0.url != nil }
        guard !localVideos.isEmpty else { return }
        
        DispatchQueue.global(qos: .utility).async {
            for video in localVideos {
                guard let url = video.url else { continue }
                
                let ext = url.pathExtension.lowercased()
                let nativeExtensions = ["mp4", "mov", "m4v"]
                
                if !nativeExtensions.contains(ext) {
                    // VLC/Non-native: Only duration for now as metadata date extraction is tougher for these
                    let helper = VLCDurationHelper()
                    Task {
                        let duration = await helper.fetchDuration(for: url)
                        if duration > 0 {
                            await MainActor.run {
                                self.updateVideoMetadata(for: video.id, duration: duration, creationDate: nil)
                            }
                        }
                    }
                    continue
                }
                
                // Native Formats: Fetch Duration and Creation Date
                let asset = AVURLAsset(url: url)
                Task {
                    var fetchedDuration: Double? = nil
                    var fetchedDate: Date? = nil
                    
                    // 1. Load Duration
                    if let d = try? await asset.load(.duration) {
                        fetchedDuration = CMTimeGetSeconds(d)
                    }
                    
                    // 2. Load Creation Date from Metadata
                    if let metadata = try? await asset.load(.metadata) {
                        // Priority 1: Common Key Creation Date
                        if let dateItem = AVMetadataItem.metadataItems(from: metadata, withKey: AVMetadataKey.commonKeyCreationDate, keySpace: .common).first,
                           let dateString = dateItem.value as? String {
                            fetchedDate = self.parseISO8601Date(dateString)
                        }
                        
                        // Priority 2: QuickTime Creation Date
                        if fetchedDate == nil,
                           let dateItem = AVMetadataItem.metadataItems(from: metadata, withKey: AVMetadataKey.quickTimeMetadataKeyCreationDate, keySpace: .quickTimeMetadata).first,
                           let dateString = dateItem.value as? String {
                            fetchedDate = self.parseISO8601Date(dateString)
                        }
                    }
                    
                    if fetchedDuration != nil || fetchedDate != nil {
                        await MainActor.run {
                            self.updateVideoMetadata(for: video.id, duration: fetchedDuration, creationDate: fetchedDate)
                        }
                    }
                }
            }
        }
    }
    
    // Static formatters — DateFormatter and ISO8601DateFormatter are expensive to allocate.
    // parseISO8601Date is called per video during background metadata fetch; creating 4+1
    // new formatters per call results in thousands of allocs across a typical library.
    private static let iso8601DateFormatter: ISO8601DateFormatter = ISO8601DateFormatter()
    private static let iso8601DateFormatterWithMillis: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    private static let iso8601DateFormatterBasic: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    private static let iso8601DateFormatterNoT: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    private static let iso8601DateFormatterDateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// parseISO8601Date
    /// - Description: Parses common ISO-8601 date strings found in video file metadata.
    /// - How to use: Called from backgroundFetchMetadata per video. Uses cached static formatters to avoid alloc churn.
    private func parseISO8601Date(_ dateString: String) -> Date? {
        // Try static formatters in order of most-common first (avoids unnecessary work)
        if let date = Self.iso8601DateFormatterBasic.date(from: dateString) { return date }
        if let date = Self.iso8601DateFormatterWithMillis.date(from: dateString) { return date }
        if let date = Self.iso8601DateFormatterNoT.date(from: dateString) { return date }
        if let date = Self.iso8601DateFormatterDateOnly.date(from: dateString) { return date }
        // Fallback: ISO8601DateFormatter handles edge cases
        return Self.iso8601DateFormatter.date(from: dateString)
    }

    private func updateVideoMetadata(for id: UUID, duration: Double?, creationDate: Date?) {
        var didChange = false
        
        func updateItem(_ item: inout VideoItem) {
            if let duration = duration, duration > 0 {
                item.duration = duration
                didChange = true
            }
            if let creationDate = creationDate {
                item.creationDate = creationDate
                didChange = true
            }
        }
        
        // Update in importedVideos
        if let index = self.importedVideos.firstIndex(where: { $0.id == id }) {
            updateItem(&self.importedVideos[index])
        }
        
        // Update in allGalleryVideos
        if let index = self.allGalleryVideos.firstIndex(where: { $0.id == id }) {
            updateItem(&self.allGalleryVideos[index])
        }
        
        // Update in master videos list
        if let index = self.videos.firstIndex(where: { $0.id == id }) {
            updateItem(&self.videos[index])
        }
        
        // Update in folders recursively
        func updateFolderRecursively(_ folder: inout Folder) {
            if let vIndex = folder.videos.firstIndex(where: { $0.id == id }) {
                updateItem(&folder.videos[vIndex])
            }
            for i in 0..<folder.subfolders.count {
                updateFolderRecursively(&folder.subfolders[i])
            }
        }
        
        for i in 0..<self.folders.count {
            updateFolderRecursively(&self.folders[i])
        }
        
        if didChange {
            // Trigger re-sorting if needed
            self.updateGroupedVideos()
            self.objectWillChange.send()
        }
    }
    
    private func fetchAsset(for identifier: String?) -> PHAsset? {
        guard let identifier = identifier else { return nil }
        
        // Safety check: Don't call fetchAssets if permission is not granted yet to avoid auto-prompt
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return nil
        }
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return fetchResult.firstObject
    }
    
    // MARK: - Models (Using existing Folder and VideoItem)
    
    enum SortOption: String, CaseIterable {
        case recents = "Recents"
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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
            
            let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
            let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
            
            var videoAlbums: [PHAssetCollection] = []
            var userDestinations: [PHAssetCollection] = []
            var albumCounts: [String: Int] = [:]
            var firstAssetIDs: [String: String] = [:]
            var allVideosId: String? = nil

            let processCollections = { (fetchResult: PHFetchResult<PHAssetCollection>, isUserAlbum: Bool) in
                fetchResult.enumerateObjects { collection, _, _ in
                    let title = collection.localizedTitle ?? ""
                    let lowerTitle = title.lowercased()
                    if lowerTitle == "recents" || lowerTitle == "recent" || lowerTitle == "recently saved" || lowerTitle == "favorites" || collection.assetCollectionSubtype == .smartAlbumFavorites {
                        return
                    }

                    // Track "All Videos" smart album so FolderDetailView can skip the fetch
                    if collection.assetCollectionSubtype == .smartAlbumVideos {
                        allVideosId = collection.localIdentifier
                    }

                    if isUserAlbum {
                        userDestinations.append(collection)
                    }

                    let options = PHFetchOptions()
                    options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
                    // Get first asset for thumb verification
                    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

                    let assets = PHAsset.fetchAssets(in: collection, options: options)

                    if assets.count > 0 {
                        videoAlbums.append(collection)
                        albumCounts[collection.localIdentifier] = assets.count
                        firstAssetIDs[collection.localIdentifier] = assets.firstObject?.localIdentifier ?? ""
                    }
                }
            }

            processCollections(smartAlbums, false)
            processCollections(userAlbums, true)

            // Calculate state signature - include count and first asset ID
            let newSignature = videoAlbums.map {
                "\($0.localIdentifier)_\(albumCounts[$0.localIdentifier] ?? 0)_\(firstAssetIDs[$0.localIdentifier] ?? "")"
            }.joined(separator: "|")

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                // Always update allVideosAlbumIdentifier so FolderDetailView can use the fast path
                if self.allVideosAlbumIdentifier == nil, let id = allVideosId {
                    self.allVideosAlbumIdentifier = id
                }

                // Only update and trigger UI refresh if data actually changed
                if self.galleryStateSignature != newSignature {
                    self.galleryStateSignature = newSignature
                    self.galleryAlbums = videoAlbums
                    self.allGalleryAlbums = userDestinations
                    self.albumAssetCounts = albumCounts
                    self.lastGalleryUpdate = Date()
                    self.objectWillChange.send()
                }
            }
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

// MARK: - Centralized Import Handlers
extension DashboardViewModel {
    @MainActor
    func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            self.initiateImportFlow(urls: urls)
        case .failure(let error):
            print("File import failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    func handlePhotoImport(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        
        let totalCount = items.count
        
        // Start session immediately
        self.startImportSession(count: totalCount)
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            var collectedURLs: [URL] = []
            var collectedNames: [String] = []
            
            for (index, item) in items.enumerated() {
                // 1. Resolve Filename (Background)
                var fileName: String?
                if let localID = item.itemIdentifier {
                    let result = PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil)
                    if let asset = result.firstObject {
                        let resources = PHAssetResource.assetResources(for: asset)
                        fileName = resources.first?.originalFilename
                    }
                }
                
                // 2. Setup Live Progress Reporting
                await MainActor.run {
                    self.importCurrentIndex = index + 1
                    self.importStatusMessage = "Preparing items..."
                    self.importProgress = Double(index) / Double(totalCount)
                }
                
                let progressTask = Task {
                    var simulatedProgress = 0.0
                    while !Task.isCancelled && simulatedProgress < 0.9 {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        simulatedProgress += 0.01
                        await MainActor.run {
                            let base = Double(index) / Double(totalCount)
                            let currentItemContribution = simulatedProgress * (1.0 / Double(totalCount))
                            self.importProgress = min(base + currentItemContribution, Double(index + 1) / Double(totalCount) - 0.01)
                            self.importStatusMessage = "Exporting: \(Int(simulatedProgress * 100))%"
                        }
                    }
                }
                
                // 3. Load Transferable
                if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                    progressTask.cancel()
                    collectedURLs.append(movie.url)
                    collectedNames.append(fileName ?? movie.url.lastPathComponent)
                } else {
                    progressTask.cancel()
                }
            }
            
            // Finalize Session and Start Conflict Flow
            await MainActor.run {
                self.finalizeImportSession()
                if !collectedURLs.isEmpty {
                    self.initiateImportFlow(urls: collectedURLs, names: collectedNames)
                }
            }
        }
    }
}
