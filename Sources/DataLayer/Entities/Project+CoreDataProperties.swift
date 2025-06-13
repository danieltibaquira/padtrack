import Foundation
import CoreData

extension Project {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Project> {
        return NSFetchRequest<Project>(entityName: "Project")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var name: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var patterns: NSSet?
    @NSManaged public var kits: NSSet?
    @NSManaged public var presets: NSSet?

}

// MARK: Generated accessors for patterns
extension Project {

    @objc(addPatternsObject:)
    @NSManaged public func addToPatterns(_ value: Pattern)

    @objc(removePatternsObject:)
    @NSManaged public func removeFromPatterns(_ value: Pattern)

    @objc(addPatterns:)
    @NSManaged public func addToPatterns(_ values: NSSet)

    @objc(removePatterns:)
    @NSManaged public func removeFromPatterns(_ values: NSSet)

}

// MARK: Generated accessors for kits
extension Project {

    @objc(addKitsObject:)
    @NSManaged public func addToKits(_ value: Kit)

    @objc(removeKitsObject:)
    @NSManaged public func removeFromKits(_ value: Kit)

    @objc(addKits:)
    @NSManaged public func addToKits(_ values: NSSet)

    @objc(removeKits:)
    @NSManaged public func removeFromKits(_ values: NSSet)

}

// MARK: Generated accessors for presets
extension Project {

    @objc(addPresetsObject:)
    @NSManaged public func addToPresets(_ value: Preset)

    @objc(removePresetsObject:)
    @NSManaged public func removeFromPresets(_ value: Preset)

    @objc(addPresets:)
    @NSManaged public func addToPresets(_ values: NSSet)

    @objc(removePresets:)
    @NSManaged public func removeFromPresets(_ values: NSSet)

} 