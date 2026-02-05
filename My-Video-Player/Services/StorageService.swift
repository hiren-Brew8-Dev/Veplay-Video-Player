import AVFoundation

class StorageService {
    static let shared = StorageService()
    
    private let fileManager = FileManager.default
    
    private var documentsDirectory: URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    var importsDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("ImportedVideos")
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        return url
    }
    
    // MARK: - Video Operations
    
    func saveVideo(_ sourceUrl: URL, fileName: String? = nil, to folderUrl: URL? = nil) -> URL? {
        let destinationFolder = folderUrl ?? importsDirectory
        let name = fileName ?? sourceUrl.lastPathComponent
        let destinationUrl = destinationFolder.appendingPathComponent(name)
        
        do {
            if fileManager.fileExists(atPath: destinationUrl.path) {
                try fileManager.removeItem(at: destinationUrl)
            }
            try fileManager.copyItem(at: sourceUrl, to: destinationUrl)
            
            // Force update creation/modification date to effectively "Touch" the file
            // This ensures "Import Date" is "Now", so it sorts to the top
            let now = Date()
            let attributes: [FileAttributeKey: Any] = [
                .creationDate: now,
                .modificationDate: now
            ]
            try fileManager.setAttributes(attributes, ofItemAtPath: destinationUrl.path)
            
            return destinationUrl
        } catch {
            print("Error saving video: \(error)")
            return nil
        }
    }
    
    func fetchImportedVideos() -> [VideoItem] {
        return fetchVideos(in: importsDirectory)
    }
    
    private func fetchVideos(in directory: URL) -> [VideoItem] {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey], options: .skipsHiddenFiles)
            
            return fileURLs.compactMap { url -> VideoItem? in
                // Skip directories
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    return nil
                }
                
                let resources = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                let creationDate = resources?.creationDate ?? Date()
                let fileSize = Int64(resources?.fileSize ?? 0)
                let duration = getDuration(for: url)
                
                return VideoItem(
                    id: UUID(), 
                    asset: nil,
                    title: url.lastPathComponent,
                    duration: duration, 
                    creationDate: creationDate,
                    fileSizeBytes: fileSize,
                    thumbnailPath: nil,
                    url: url
                )
            }
        } catch {
            print("Error fetching local videos: \(error)")
            return []
        }
    }
    
    func fetchUserFolders() -> [Folder] {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: importsDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
            return fileURLs.compactMap { url -> Folder? in
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    let videos = fetchVideos(in: url)
                    return Folder(name: url.lastPathComponent, videoCount: videos.count, videos: videos, url: url) // Assuming Folder has URL 
                }
                return nil
            }
        } catch {
            return []
        }
    }
    
    private func getDuration(for url: URL) -> Double {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }
    
    func deleteVideo(at url: URL) {
        try? fileManager.removeItem(at: url)
    }
    
    func renameVideo(at url: URL, to newName: String) -> URL? {
        let directory = url.deletingLastPathComponent()
        let newUrl = directory.appendingPathComponent(newName).appendingPathExtension(url.pathExtension)
        
        do {
            try fileManager.moveItem(at: url, to: newUrl)
            return newUrl
        } catch {
            print("Rename failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Folder Operations
    
    func createFolder(name: String) -> Bool {
        let folderUrl = importsDirectory.appendingPathComponent(name)
        do {
            try fileManager.createDirectory(at: folderUrl, withIntermediateDirectories: true, attributes: nil)
            return true
        } catch {
            print("Create folder failed: \(error)")
            return false
        }
    }
    
    func deleteFolder(at url: URL) {
        try? fileManager.removeItem(at: url)
    }
    
    func renameFolder(at url: URL, to newName: String) -> Bool {
        let directory = url.deletingLastPathComponent()
        let newUrl = directory.appendingPathComponent(newName)
        
        do {
            try fileManager.moveItem(at: url, to: newUrl)
            return true
        } catch {
            print("Rename folder failed: \(error)")
            return false
        }
    }
    
    func moveVideo(at videoUrl: URL, to folderUrl: URL) -> Bool {
        let destinationUrl = folderUrl.appendingPathComponent(videoUrl.lastPathComponent)
        do {
             try fileManager.moveItem(at: videoUrl, to: destinationUrl)
             return true
        } catch {
            print("Move video failed: \(error)")
            return false
        }
    }
}
