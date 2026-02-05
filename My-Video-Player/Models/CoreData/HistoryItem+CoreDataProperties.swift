//
//  HistoryItem+CoreDataProperties.swift
//  Video Player - All in one
//
//  Created by Shivshankar T Tiwari on 23/01/26.
//
//

public import Foundation
public import CoreData


public typealias HistoryItemCoreDataPropertiesSet = NSSet

extension HistoryItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<HistoryItem> {
        return NSFetchRequest<HistoryItem>(entityName: "HistoryItem")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var videoUrlString: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var duration: Double
    @NSManaged public var isLocalFile: Bool
    @NSManaged public var fileSizeBytes: Int64

}

extension HistoryItem : Identifiable {

}
