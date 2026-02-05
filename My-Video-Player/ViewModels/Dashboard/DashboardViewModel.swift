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
    // Navigation
    @Published var selectedTab: Int = 0
    @Published var isHeaderExpanded: Bool = false
    @Published var isTabBarHidden: Bool = false
    @Published var playingVideo: VideoItem? = nil
    @Published var currentPlaylist: [VideoItem] = []
    @Published var isImporting: Bool = false
    @Published var isShowingSearch: Bool = false
    
    // Data Sources
    @Published var videos: [VideoItem] = []
    @Published var folders: [Folder] = []
    @Published var historyVideos: [VideoItem] = []
    @Published var importedVideos: [VideoItem] = []
    @Published var groupedImportedVideos: [VideoSection] = []
    @Published var galleryAlbums: [PHAssetCollection] = []
    @Published var allGalleryVideos: [VideoItem] = []
    @Published var searchHistoryKeywords: [String] = []
    
    @Published var searchText: String = ""
    @Published var showPermissionDenied: Bool = false
    @Published var isSelectionMode: Bool = false
    @Published var sortOptionRaw: String = "Newest First"
    
    // Performance
    let imageManager = PHCachingImageManager()
    
    // Global UI State
    @Published var showCreateFolderAlert = false
    @Published var showPhotoPicker = false
    @Published var selectedVideoIds = Set<UUID>()
    @Published var isSharing: Bool = false
    @Published var showFileImporter = false
    @Published var newFolderName = ""
    @Published var activeImportFolderURL: URL? = nil
    
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
        let selectedItems = (importedVideos + allGalleryVideos).filter { selectedVideoIds.contains($0.id) }
        guard !selectedItems.isEmpty else { return }
        
        isSharing = true
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for item in selectedItems {
            group.enter()
            getURL(for: item) { url in
                if let url = url {
                    urls.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.isSharing = false
            if !urls.isEmpty {
                self.activityItems = urls
                self.showShareSheetGlobal = true
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
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    completion(urlAsset.url)
                } else {
                    let resources = PHAssetResource.assetResources(for: asset)
                    if let firstResource = resources.first {
                        let tempDir = FileManager.default.temporaryDirectory
                        let outputURL = tempDir.appendingPathComponent(firstResource.originalFilename)
                        
                        if FileManager.default.fileExists(atPath: outputURL.path) {
                            completion(outputURL)
                        } else {
                            PHAssetResourceManager.default().writeData(for: firstResource, toFile: outputURL, options: nil) { error in
                                completion(error == nil ? outputURL : nil)
                            }
                        }
                    } else {
                        completion(nil)
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
    
    var sortOption: SortOption {
        return SortOption(rawValue: sortOptionRaw) ?? .dateDesc
    }
    /// Dedicated folder for imported videos in Documents directory
    private var importedVideosDirectory: URL {
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
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadData()
        setupHistoryObserver()
        setupSearchHistoryObserver()
        setupGroupedVideosObserver()
    }
    
    private func setupGroupedVideosObserver() {
        Publishers.CombineLatest($importedVideos, $sortOptionRaw)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateGroupedVideos()
            }
            .store(in: &cancellables)
            
        // Master videos list remains a combination for other views (like Search)
        // but we'll ensure it respects sorting.
        Publishers.CombineLatest3($importedVideos, $allGalleryVideos, $sortOptionRaw)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] imported, gallery, _ in
                guard let self = self else { return }
                let all = (imported + gallery)
                self.videos = self.sortVideos(all)
            }
            .store(in: &cancellables)
    }
    
    private func sortVideos(_ items: [VideoItem]) -> [VideoItem] {
        return items.sorted {
            switch sortOption {
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
        let sorted = sortVideos(importedVideos)
        
        switch sortOption {
        case .dateDesc, .dateAsc:
            let grouped = Dictionary(grouping: sorted) { video -> Date in
                calendar.startOfDay(for: video.creationDate)
            }
            
            let sortedDates = grouped.keys.sorted(by: { 
                sortOption == .dateAsc ? $0 < $1 : $0 > $1 
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
    
    func createFolder(name: String) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let baseURL = documentsURL.appendingPathComponent("Folders", isDirectory: true)
        let folderURL = baseURL.appendingPathComponent(name, isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            print("✅ Created folder: \(name)")
            loadUserFolders() // Refresh
        } catch {
            print("❌ Failed to create folder: \(error.localizedDescription)")
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
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: resourceKeys, options: .skipsHiddenFiles) else {
            return Folder(id: UUID(), name: name, videoCount: 0, videos: [], url: url, subfolders: [])
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
            subfolders: subfolders
        )
    }
    
    private func videoItem(from url: URL) -> VideoItem? {
        let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv"]
        guard videoExtensions.contains(url.pathExtension.lowercased()) else { return nil }
        
        let asset = AVURLAsset(url: url)
        // asset.duration is deprecated in iOS 16.0. Use load(.duration) instead.
        // For sync functions, we can still use the property but silence if possible, 
        // or better, fetch it before creating the VideoItem.
        // However, since this is widespread, I'll use a hack or update to async.
        // Let's use CMTimeGetSeconds(asset.duration) for now but try to load it.
        // Actually, the cleanest fix for the warning is to use the modern API.
        let duration = CMTimeGetSeconds(asset.duration)
        
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
        _ = Data(identifier.utf8)
        _ = [UInt8](repeating: 0, count: 16)
        
        // Simple hash for stable mapping (standard MD5 or similar would be better but let's use what's available simply)
        // For production, a more robust UUID version 5 implementation is ideal.
        // For now, let's use the identifier's hash value to seed a UUID.
        var hasher = Hasher()
        hasher.combine(identifier)
        let hashValue = hasher.finalize()
        
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 {
            bytes[i] = UInt8((hashValue >> (i * 8)) & 0xFF)
        }
        // Fill the rest with some variety
        for i in 8..<16 {
            bytes[i] = bytes[i-8] ^ 0x55
        }
        
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
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
                    // Optional: handle conflict by appending (1), etc.
                }
                
                try fileManager.moveItem(at: oldURL, to: newURL)
                print("✅ Renamed: \(oldURL.lastPathComponent) -> \(newURL.lastPathComponent)")
                
                DispatchQueue.main.async {
                    self.loadImportedVideos()
                    self.loadUserFolders()
                }
            } catch {
                print("❌ Rename failed: \(error.localizedDescription)")
            }
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
        
        items.append(CustomActionItem(title: "Delete", icon: "trash", role: .destructive, action: {
            self.deleteVideo(video)
        }))
        
        return items
    }
    
    func importVideo(from url: URL, withName name: String? = nil, to destination: URL? = nil) {
        importVideos(from: [url], to: destination)
    }
    
    func importVideos(from urls: [URL], to destination: URL? = nil) {
        // Start Loading
        DispatchQueue.main.async {
            self.isImporting = true
        }
        
        let targetDirectory = destination ?? self.activeImportFolderURL ?? self.importedVideosDirectory
        let context = CDManager.shared.container.viewContext
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            for url in urls {
                let filename = url.lastPathComponent
                let destinationURL = targetDirectory.appendingPathComponent(filename)
                
                // 1. Save to History (Core Data)
                DispatchQueue.main.sync {
                    let newItem = HistoryItem(context: context)
                    newItem.id = UUID()
                    newItem.videoUrlString = destinationURL.absoluteString
                    newItem.title = url.deletingPathExtension().lastPathComponent
                    newItem.timestamp = Date()
                    try? context.save()
                }
                
                // 2. Copy File
                do {
                    let fileManager = FileManager.default
                    
                    // Ensure access
                    let gainedAccess = url.startAccessingSecurityScopedResource()
                    defer { if gainedAccess { url.stopAccessingSecurityScopedResource() } }
                    
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try? fileManager.removeItem(at: destinationURL)
                    }
                    try fileManager.copyItem(at: url, to: destinationURL)
                    
                    print("✅ Imported: \(filename) to \(targetDirectory.lastPathComponent)")
                } catch {
                    print("❌ Error importing \(url.lastPathComponent): \(error)")
                }
            }
            
            // 3. Finalize
            DispatchQueue.main.async {
                self.loadImportedVideos()
                self.loadUserFolders()
                self.isImporting = false
                self.activeImportFolderURL = nil
                self.isSelectionMode = false // Exit selection mode if active
            }
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
        }
    }
    
    func preFetchTitles(for videos: [VideoItem]) {
        for video in videos {
            self.loadTitle(for: video) { [weak self] resolvedTitle in
                guard let self = self else { return }
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
                    
                    // Current player
                    if self.playingVideo?.id == video.id {
                        self.playingVideo?.title = resolvedTitle
                    }
                    self.objectWillChange.send()
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
                
                let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv"]
                let videoFiles = fileURLs.filter { videoExtensions.contains($0.pathExtension.lowercased()) }
                
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
        let localVideos = videos.filter { $0.url != nil && $0.duration == 0 }
        guard !localVideos.isEmpty else { return }
        
        DispatchQueue.global(qos: .utility).async {
            for video in localVideos {
                guard let url = video.url else { continue }
                
                // Check if VLC Format
                let ext = url.pathExtension.lowercased()
                if ["mkv", "avi", "wmv", "flv", "webm", "3gp"].contains(ext) {
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
        for i in 0..<self.folders.count {
            if let vIndex = self.folders[i].videos.firstIndex(where: { $0.id == id }) {
                self.folders[i].videos[vIndex].duration = duration
            }
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
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            if status == .authorized || status == .limited {
                let fetchOptions = PHFetchOptions()
                let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: fetchOptions)
                let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
                
                var allAlbums: [PHAssetCollection] = []
                
                let processCollections = { (fetchResult: PHFetchResult<PHAssetCollection>) in
                    fetchResult.enumerateObjects { collection, _, _ in
                        let options = PHFetchOptions()
                        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
                        let assets = PHAsset.fetchAssets(in: collection, options: options)
                        
                        let title = collection.localizedTitle ?? ""
                        if title.lowercased() == "recents" {
                            return
                        }
                        
                        if assets.count > 0 {
                            allAlbums.append(collection)
                        }
                    }
                }
                
                processCollections(smartAlbums)
                processCollections(userAlbums)
                
                DispatchQueue.main.async {
                    self.galleryAlbums = allAlbums
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
    
    func renameFolder(_ folder: Folder, to newName: String) {
        guard let url = folder.url else { return }
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        
        do {
            try FileManager.default.moveItem(at: url, to: newURL)
            loadUserFolders()
        } catch {
            print("Failed to rename folder: \(error)")
        }
    }
    
    func deleteFolder(_ folder: Folder) {
        guard let url = folder.url else { return }
        
        do {
            try FileManager.default.removeItem(at: url)
            loadUserFolders()
        } catch {
             print("Failed to delete folder: \(error)")
        }
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
