import Foundation
import CoreData
import Photos

class HistoryService {
    static let shared = HistoryService()
    private let context = PersistenceController.shared.container.viewContext
    
    func addToHistory(video: VideoItem) {
        // Check if item already exists to avoid duplicates (optional logic: move to top)
        let fetchRequest: NSFetchRequest<HistoryItem> = NSFetchRequest<HistoryItem>(entityName: "HistoryItem")
        fetchRequest.predicate = NSPredicate(format: "videoUrlString == %@", video.asset?.localIdentifier ?? video.title)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let existingItem = results.first {
                // Update timestamp
                existingItem.timestamp = Date()
            } else {
                // Create new
                let newItem = HistoryItem(context: context)
                newItem.id = video.id
                newItem.title = video.title
                newItem.timestamp = Date()
                newItem.duration = video.duration
                newItem.isLocalFile = video.asset == nil
                
                // Store identifier
                // If it's a PHAsset, store localIdentifier. If local file, store path/name.
                if let asset = video.asset {
                    newItem.videoUrlString = asset.localIdentifier
                } else {
                    newItem.videoUrlString = video.title // Simplified for demo
                }
            }
            save()
        } catch {
            print("Error saving history: \(error)")
        }
    }
    
    func fetchHistory() -> [HistoryItem] {
        let request: NSFetchRequest<HistoryItem> = NSFetchRequest<HistoryItem>(entityName: "HistoryItem")
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = 20
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    private func save() {
        if context.hasChanges {
            try? context.save()
        }
    }
}
