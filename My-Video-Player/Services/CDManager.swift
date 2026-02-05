import Foundation
import CoreData
import Combine
import Photos

class CDManager: ObservableObject {
    static let shared = CDManager()
    
    let container: NSPersistentContainer
    
    // Published property if we want to observe changes directly provided
    @Published var savedHistory: [HistoryItem] = []
    @Published var searchHistory: [SearchKeyword] = []

    init(inMemory: Bool = false) {
        // Fallback init to try and load safely
        container = NSPersistentContainer(name: "VideoPlayer")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                print("Core Data Store Error: \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        fetchHistory()
        fetchSearchHistory()
    }
    
    // MARK: - History CRUD
    
    func saveToHistory(video: VideoItem) {
        let context = container.viewContext
        
        // internal helper to save context
        func saveContext() {
            if context.hasChanges {
                try? context.save()
            }
        }
        
        // Check duplication
        let request: NSFetchRequest<HistoryItem> = NSFetchRequest<HistoryItem>(entityName: "HistoryItem")
        // Identifier: local identifier (asset) or absolute URL string (file) or title (fallback)
        let idString = video.asset?.localIdentifier ?? video.url?.absoluteString ?? video.title
        request.predicate = NSPredicate(format: "videoUrlString == %@", idString)
        
        do {
            let results = try context.fetch(request)
            let itemToSave: HistoryItem
            
            if let existing = results.first {
                itemToSave = existing
            } else {
                itemToSave = HistoryItem(context: context)
                itemToSave.id = video.id
                itemToSave.videoUrlString = idString
                itemToSave.isLocalFile = video.asset == nil
            }
            
            // Always update these fields to ensure freshness (e.g. if Title changes from UUID to Filename)
            itemToSave.title = video.title
            itemToSave.duration = video.duration
            itemToSave.timestamp = Date()
            itemToSave.fileSizeBytes = video.fileSizeBytes
            saveContext()
            fetchHistory() // Refresh published list
            
            // Force UI Update
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        } catch {
            print("Failed to save history: \(error)")
        }
    }
    
    func fetchHistory() {
        let request: NSFetchRequest<HistoryItem> = NSFetchRequest<HistoryItem>(entityName: "HistoryItem")
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = 20
        
        do {
            self.savedHistory = try container.viewContext.fetch(request)
        } catch {
            print("Failed to fetch history: \(error)")
            self.savedHistory = []
        }
    }
    
    func deleteHistoryItem(item: HistoryItem) {
        let context = container.viewContext
        context.delete(item)
        
        // Save context to persist deletion
        do {
            try context.save()
            print("✅ History item deleted from Core Data")
        } catch {
            print("❌ Failed to save deletion: \(error.localizedDescription)")
        }
        
        // Refresh history and notify observers
        fetchHistory()
        
        // Force UI update on main thread
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Search History
    
    func saveSearchKeyword(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let context = container.viewContext
        
        // Remove existing to maintain uniqueness and update timestamp
        let request: NSFetchRequest<SearchKeyword> = NSFetchRequest<SearchKeyword>(entityName: "SearchKeyword")
        request.predicate = NSPredicate(format: "keyword ==[c] %@", trimmed)
        
        do {
            let results = try context.fetch(request)
            for item in results {
                context.delete(item)
            }
            
            let newItem = SearchKeyword(context: context)
            newItem.keyword = trimmed
            newItem.timestamp = Date()
            
            try context.save()
            fetchSearchHistory()
            
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        } catch {
            print("Failed to save search keyword: \(error)")
        }
    }
    
    func fetchSearchHistory() {
        let request: NSFetchRequest<SearchKeyword> = NSFetchRequest<SearchKeyword>(entityName: "SearchKeyword")
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = 10
        
        do {
            self.searchHistory = try container.viewContext.fetch(request)
        } catch {
            print("Failed to fetch search history: \(error)")
            self.searchHistory = []
        }
    }
    
    func deleteSearchKeyword(_ item: SearchKeyword) {
        let context = container.viewContext
        context.delete(item)
        try? context.save()
        fetchSearchHistory()
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func clearAllSearchHistory() {
        let context = container.viewContext
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "SearchKeyword")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            fetchSearchHistory()
            
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        } catch {
            print("Failed to clear search history: \(error)")
        }
    }
}

