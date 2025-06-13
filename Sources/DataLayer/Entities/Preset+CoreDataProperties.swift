import Foundation
import CoreData

extension Preset {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Preset> {
        return NSFetchRequest<Preset>(entityName: "Preset")
    }

    @NSManaged public var name: String?
    @NSManaged public var category: String?
    @NSManaged public var settings: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var project: Project?
    @NSManaged public var tracks: NSSet?

}

// MARK: Generated accessors for tracks
extension Preset {

    @objc(addTracksObject:)
    @NSManaged public func addToTracks(_ value: Track)

    @objc(removeTracksObject:)
    @NSManaged public func removeFromTracks(_ value: Track)

    @objc(addTracks:)
    @NSManaged public func addToTracks(_ values: NSSet)

    @objc(removeTracks:)
    @NSManaged public func removeFromTracks(_ values: NSSet)

} 