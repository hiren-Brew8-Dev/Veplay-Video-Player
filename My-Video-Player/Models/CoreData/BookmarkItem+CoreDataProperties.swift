import Foundation
import CoreData


extension BookmarkItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<BookmarkItem> {
        return NSFetchRequest<BookmarkItem>(entityName: "BookmarkItem")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var videoIdString: String?
    @NSManaged public var name: String?
    @NSManaged public var time: Double
    @NSManaged public var createdAt: Date?

}

extension BookmarkItem : Identifiable {

}
