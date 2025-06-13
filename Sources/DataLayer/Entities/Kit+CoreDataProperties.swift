import Foundation
import CoreData

extension Kit {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Kit> {
        return NSFetchRequest<Kit>(entityName: "Kit")
    }

    @NSManaged public var name: String?
    @NSManaged public var soundFiles: [String]?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var pattern: Pattern?
    @NSManaged public var project: Project?
    @NSManaged public var tracks: NSSet?

}

// MARK: Generated accessors for tracks
extension Kit {

    @objc(addTracksObject:)
    @NSManaged public func addToTracks(_ value: Track)

    @objc(removeTracksObject:)
    @NSManaged public func removeFromTracks(_ value: Track)

    @objc(addTracks:)
    @NSManaged public func addToTracks(_ values: NSSet)

    @objc(removeTracks:)
    @NSManaged public func removeFromTracks(_ values: NSSet)

} 