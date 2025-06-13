import Foundation
import CoreData

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

    private func validateName(_ name: String?) throws {
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName("Preset name cannot be empty")
        }

        guard name.count <= 50 else {
            throw ValidationError.invalidName("Preset name cannot exceed 50 characters")
        }
    }

    private func validateCategory(_ category: String?) throws {
        if let category = category {
            guard !category.isEmpty else {
                throw ValidationError.invalidValue("Preset category cannot be empty if specified")
            }

            guard category.count <= 30 else {
                throw ValidationError.invalidValue("Preset category cannot exceed 30 characters")
            }

            // Validate against known categories
            let validCategories = ["FM TONE", "FM DRUM", "WAVETONE", "SWARMER", "FILTER", "FX"]
            guard validCategories.contains(category) else {
                throw ValidationError.invalidValue("Invalid preset category: \(category)")
            }
        }
    }

    // MARK: - Convenience Methods

    /// Gets the preset settings as a dictionary
    /// - Returns: Dictionary of preset parameters
    public func getSettings() -> [String: Any] {
        guard let settingsData = settings else { return [:] }

        do {
            if let settingsDict = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(settingsData) as? [String: Any] {
                return settingsDict
            }
        } catch {
            print("Failed to decode preset settings: \(error)")
        }

        return [:]
    }

    /// Sets the preset settings
    /// - Parameter settingsDict: Dictionary of preset parameters
    public func setSettings(_ settingsDict: [String: Any]) {
        do {
            settings = try NSKeyedArchiver.archivedData(withRootObject: settingsDict, requiringSecureCoding: false)
        } catch {
            print("Failed to encode preset settings: \(error)")
        }
    }

    /// Gets a specific parameter value
    /// - Parameter parameter: The parameter name
    /// - Returns: The parameter value if it exists
    public func getParameter(_ parameter: String) -> Any? {
        return getSettings()[parameter]
    }

    /// Sets a specific parameter value
    /// - Parameters:
    ///   - parameter: The parameter name
    ///   - value: The parameter value
    public func setParameter(_ parameter: String, value: Any) {
        var currentSettings = getSettings()
        currentSettings[parameter] = value
        setSettings(currentSettings)
    }

    /// Removes a parameter
    /// - Parameter parameter: The parameter name to remove
    public func removeParameter(_ parameter: String) {
        var currentSettings = getSettings()
        currentSettings.removeValue(forKey: parameter)
        setSettings(currentSettings)
    }

    /// Creates a copy of this preset
    /// - Parameter newName: Name for the copied preset
    /// - Returns: A new preset with copied settings
    public func copy(withName newName: String) -> Preset {
        let newPreset = Preset(context: managedObjectContext!)
        newPreset.name = newName
        newPreset.category = category
        newPreset.project = project
        newPreset.setSettings(getSettings())
        return newPreset
    }

    /// Gets all tracks using this preset
    /// - Returns: Array of tracks using this preset
    public func associatedTracks() -> [Track] {
        guard let tracks = tracks as? Set<Track> else { return [] }
        return Array(tracks).sorted { $0.trackIndex < $1.trackIndex }
    }
}