import Foundation
import CoreData
import DataModel

@objc(Preset)
public class Preset: NSManagedObject {

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()

        // Set default values
        let now = Date()
        createdAt = now
        updatedAt = now

        // Set default values
        if name == nil || name?.isEmpty == true {
            name = "New Preset"
        }
        if category == nil || category?.isEmpty == true {
            category = "User"
        }
    }

    public override func willSave() {
        super.willSave()

        // Update timestamp on save only if it hasn't changed recently (avoid infinite recursion)
        if !isDeleted && (updatedAt == nil || Date().timeIntervalSince(updatedAt!) > 1.0) {
            updatedAt = Date()
        }
    }

    // MARK: - Validation

    public override func validateValue(_ value: AutoreleasingUnsafeMutablePointer<AnyObject?>, forKey key: String) throws {
        try super.validateValue(value, forKey: key)

        switch key {
        case "name":
            try validateName(value.pointee as? String)
        case "category":
            try validateCategory(value.pointee as? String)
        default:
            break
        }
    }

    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateRelationships()
    }

    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateRelationships()
    }

    private func validateName(_ name: String?) throws {
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName("Preset name cannot be empty")
        }

        guard name.count <= 50 else {
            throw ValidationError.invalidName("Preset name cannot exceed 50 characters")
        }

        // Check for invalid characters
        let invalidCharacters = CharacterSet(charactersIn: "<>:\"/\\|?*")
        guard name.rangeOfCharacter(from: invalidCharacters) == nil else {
            throw ValidationError.invalidName("Preset name contains invalid characters")
        }
    }

    private func validateCategory(_ category: String?) throws {
        guard let category = category, !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidValue("Preset category cannot be empty")
        }

        guard category.count <= 30 else {
            throw ValidationError.invalidValue("Preset category cannot exceed 30 characters")
        }

        let validCategories = [
            "FM TONE", "FM DRUM", "WAVETONE", "SWARMER", "FILTER", "FX",
            "User", "Factory", "Lead", "Bass", "Pad", "Percussion", "Drum",
            "Arp", "Sequence", "Ambient", "Experimental"
        ]
        guard validCategories.contains(category) else {
            throw ValidationError.invalidValue("Invalid preset category: \(category)")
        }
    }

    private func validateRelationships() throws {
        // Basic relationship validation can be added here if needed
    }

    // MARK: - Settings Management

    /// Sets settings data for the preset
    /// - Parameter settingsDict: Dictionary of settings
    public func setSettings(_ settingsDict: [String: Any]) throws {
        do {
            settings = try NSKeyedArchiver.archivedData(withRootObject: settingsDict, requiringSecureCoding: false)
        } catch {
            throw ValidationError.invalidValue("Failed to encode preset settings: \(error.localizedDescription)")
        }
    }

    /// Gets settings data from the preset
    /// - Returns: Dictionary of settings
    public func getSettings() -> [String: Any] {
        guard let settingsData = settings else { return [:] }

        do {
            if let settingsDict = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSDictionary.self, from: settingsData) as? [String: Any] {
                return settingsDict
            }
        } catch {
            print("Failed to decode preset settings: \(error)")
        }

        return [:]
    }

    /// Creates a copy of this preset with a new name
    /// - Parameter newName: Name for the copied preset
    /// - Returns: The newly created preset copy
    public func copy(withName newName: String) -> Preset {
        let presetCopy = Preset(context: managedObjectContext!)
        presetCopy.name = newName
        presetCopy.category = self.category
        presetCopy.settings = self.settings
        return presetCopy
    }
}