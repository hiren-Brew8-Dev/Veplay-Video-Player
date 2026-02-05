//
//  SearchKeyword+CoreDataProperties.swift
//  Video Player
//
//  Created by Shivshankar T Tiwari on 27/01/26.
//
//

public import Foundation
public import CoreData


public typealias SearchKeywordCoreDataPropertiesSet = NSSet

extension SearchKeyword {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SearchKeyword> {
        return NSFetchRequest<SearchKeyword>(entityName: "SearchKeyword")
    }

    @NSManaged public var keyword: String?
    @NSManaged public var timestamp: Date?

}

extension SearchKeyword : Identifiable {

}
