import Foundation
import CoreData

extension Trig {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Trig> {
        return NSFetchRequest<Trig>(entityName: "Trig")
    }

    @NSManaged public var step: Int16
    @NSManaged public var isActive: Bool
    @NSManaged public var note: Int16
    @NSManaged public var velocity: Int16
    @NSManaged public var duration: Float
    @NSManaged public var probability: Int16
    @NSManaged public var microTiming: Float
    @NSManaged public var retrigCount: Int16
    @NSManaged public var retrigRate: Float
    @NSManaged public var pLocks: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var track: Track?
    @NSManaged public var pattern: Pattern?

} 