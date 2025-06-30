import Foundation
import CoreData

@objc(Project)
public class Project: NSManagedObject {

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()

        // Set default values
        let now = Date()
        createdAt = now
        updatedAt = now

        // Set default name if not provided
        if name == nil || name?.isEmpty == true {
            name = "Untitled Project"
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
        default:
            break
        }
    }

    private func validateName(_ name: String?) throws {
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName("Project name cannot be empty")
        }

        guard name.count <= 100 else {
            throw ValidationError.invalidName("Project name cannot exceed 100 characters")
        }
    }

    // MARK: - Convenience Methods

    /// Creates a new pattern for this project
    /// - Parameter name: The name for the new pattern
    /// - Returns: The newly created pattern
    public func createPattern(name: String = "New Pattern") -> Pattern {
        let pattern = Pattern(context: managedObjectContext!)
        pattern.name = name
        pattern.project = self
        pattern.length = 16 // Default pattern length
        pattern.tempo = 120.0 // Default tempo
        return pattern
    }

    /// Creates a new kit for this project
    /// - Parameter name: The name for the new kit
    /// - Returns: The newly created kit
    public func createKit(name: String = "New Kit") -> Kit {
        let kit = Kit(context: managedObjectContext!)
        kit.name = name
        kit.project = self
        return kit
    }

    /// Creates a new preset for this project
    /// - Parameters:
    ///   - name: The name for the new preset
    ///   - category: The category/type of the preset
    /// - Returns: The newly created preset
    public func createPreset(name: String = "New Preset", category: String? = nil) -> Preset {
        let preset = Preset(context: managedObjectContext!)
        preset.name = name
        preset.category = category
        preset.project = self
        return preset
    }
}