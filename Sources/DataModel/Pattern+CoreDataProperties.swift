//
//  Pattern+CoreDataProperties.swift
//  DigitonePad
//
//  Auto-generated from Core Data model
//

import Foundation
import CoreData

extension Pattern {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Pattern> {
        return NSFetchRequest<Pattern>(entityName: "Pattern")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var length: Int16
    @NSManaged public var name: String?
    @NSManaged public var tempo: Double
    @NSManaged public var updatedAt: Date?
    @NSManaged public var kit: Kit?
    @NSManaged public var project: Project?
    @NSManaged public var tracks: NSSet?
    @NSManaged public var trigs: NSSet?

}

// MARK: Generated accessors for tracks
extension Pattern {

    @objc(addTracksObject:)
    @NSManaged public func addToTracks(_ value: Track)

    @objc(removeTracksObject:)
    @NSManaged public func removeFromTracks(_ value: Track)

    @objc(addTracks:)
    @NSManaged public func addToTracks(_ values: NSSet)

    @objc(removeTracks:)
    @NSManaged public func removeFromTracks(_ values: NSSet)

}

// MARK: Generated accessors for trigs
extension Pattern {

    @objc(addTrigsObject:)
    @NSManaged public func addToTrigs(_ value: Trig)

    @objc(removeTrigsObject:)
    @NSManaged public func removeFromTrigs(_ value: Trig)

    @objc(addTrigs:)
    @NSManaged public func addToTrigs(_ values: NSSet)

    @objc(removeTrigs:)
    @NSManaged public func removeFromTrigs(_ values: NSSet)

}