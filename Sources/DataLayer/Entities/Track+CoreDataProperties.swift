import Foundation
import CoreData

extension Track {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Track> {
        return NSFetchRequest<Track>(entityName: "Track")
    }

    @NSManaged public var name: String?
    @NSManaged public var volume: Float
    @NSManaged public var pan: Float
    @NSManaged public var isMuted: Bool
    @NSManaged public var isSolo: Bool
    @NSManaged public var trackIndex: Int16
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var pattern: Pattern?
    @NSManaged public var kit: Kit?
    @NSManaged public var preset: Preset?
    @NSManaged public var trigs: NSSet?

}

// MARK: Generated accessors for trigs
extension Track {

    @objc(addTrigsObject:)
    @NSManaged public func addToTrigs(_ value: Trig)

    @objc(removeTrigsObject:)
    @NSManaged public func removeFromTrigs(_ value: Trig)

    @objc(addTrigs:)
    @NSManaged public func addToTrigs(_ values: NSSet)

    @objc(removeTrigs:)
    @NSManaged public func removeFromTrigs(_ values: NSSet)

} 