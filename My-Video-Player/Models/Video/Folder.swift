import Foundation

struct Folder: Identifiable, Hashable {
    let id: UUID
    let name: String
    let videoCount: Int
    var videos: [VideoItem] // Cached video list for this folder
    let url: URL? // For user folders
    var subfolders: [Folder]
    
    init(id: UUID = UUID(), name: String, videoCount: Int, videos: [VideoItem] = [], url: URL? = nil, subfolders: [Folder] = []) {
        self.id = id
        self.name = name
        self.videoCount = videoCount
        self.videos = videos
        self.url = url
        self.subfolders = subfolders
    }
}
