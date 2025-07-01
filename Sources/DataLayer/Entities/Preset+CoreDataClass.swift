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
        if category == nil || category?.isEmpty == true {
            category = "User"
        }
        if machineType == nil || machineType?.isEmpty == true {
            machineType = "FM TONE"
        }
        isDefault = false
        isFavorite = false
        rating = 0
        usageCount = 0
        version = "1.0"
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
        case "machineType":
            try validateMachineType(value.pointee as? String)
        case "description":
            try validateDescription(value.pointee as? String)
        case "author":
            try validateAuthor(value.pointee as? String)
        case "version":
            try validateVersion(value.pointee as? String)
        case "tags":
            try validateTags(value.pointee as? String)
        case "rating":
            try validateRating(value.pointee as? NSNumber)
        case "usageCount":
            try validateUsageCount(value.pointee as? NSNumber)
        case "tempo":
            try validateTempo(value.pointee as? NSNumber)
        case "key":
            try validateKey(value.pointee as? String)
        default:
            break
        }
    }

    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateRelationships()
        try validateParameters()
    }

    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateRelationships()
        try validateParameters()
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

    private func validateMachineType(_ machineType: String?) throws {
        guard let machineType = machineType, !machineType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidValue("Preset machine type cannot be empty")
        }

        let validMachineTypes = ["FM TONE", "FM DRUM", "WAVETONE", "SWARMER", "FILTER", "FX"]
        guard validMachineTypes.contains(machineType) else {
            throw ValidationError.invalidValue("Invalid machine type: \(machineType). Valid types: \(validMachineTypes.joined(separator: ", "))")
        }
    }

    private func validateDescription(_ description: String?) throws {
        if let description = description {
            guard description.count <= 1000 else {
                throw ValidationError.invalidValue("Preset description cannot exceed 1000 characters")
            }
        }
    }

    private func validateAuthor(_ author: String?) throws {
        if let author = author {
            guard !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError.invalidValue("Preset author cannot be empty if specified")
            }
            
            guard author.count <= 100 else {
                throw ValidationError.invalidValue("Preset author cannot exceed 100 characters")
            }
        }
    }

    private func validateVersion(_ version: String?) throws {
        if let version = version {
            guard !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError.invalidValue("Preset version cannot be empty if specified")
            }
            
            guard version.count <= 20 else {
                throw ValidationError.invalidValue("Preset version cannot exceed 20 characters")
            }
            
            // Basic version format validation (e.g., "1.0", "2.1.3")
            let versionRegex = try! NSRegularExpression(pattern: "^\\d+(\\.\\d+)*$")
            let range = NSRange(location: 0, length: version.utf16.count)
            guard versionRegex.firstMatch(in: version, options: [], range: range) != nil else {
                throw ValidationError.invalidValue("Invalid version format: \(version). Use format like '1.0' or '2.1.3'")
            }
        }
    }

    private func validateTags(_ tags: String?) throws {
        if let tags = tags {
            guard tags.count <= 200 else {
                throw ValidationError.invalidValue("Preset tags cannot exceed 200 characters")
            }
            
            // Validate individual tags (comma-separated)
            let tagArray = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            for tag in tagArray {
                guard !tag.isEmpty else {
                    throw ValidationError.invalidValue("Empty tags are not allowed")
                }
                guard tag.count <= 30 else {
                    throw ValidationError.invalidValue("Individual tag '\(tag)' cannot exceed 30 characters")
                }
            }
        }
    }

    private func validateRating(_ rating: NSNumber?) throws {
        if let rating = rating?.int16Value {
            guard rating >= 0 && rating <= 5 else {
                throw ValidationError.invalidValue("Preset rating must be between 0 and 5 stars")
            }
        }
    }

    private func validateUsageCount(_ usageCount: NSNumber?) throws {
        if let usageCount = usageCount?.int32Value {
            guard usageCount >= 0 else {
                throw ValidationError.invalidValue("Preset usage count cannot be negative")
            }
        }
    }

    private func validateTempo(_ tempo: NSNumber?) throws {
        if let tempo = tempo?.doubleValue {
            guard tempo >= 30.0 && tempo <= 300.0 else {
                throw ValidationError.invalidValue("Preset tempo must be between 30 and 300 BPM")
            }
        }
    }

    private func validateKey(_ key: String?) throws {
        if let key = key {
            guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError.invalidValue("Preset key cannot be empty if specified")
            }
            
            let validKeys = [
                "C", "C#", "Db", "D", "D#", "Eb", "E", "F", "F#", "Gb", "G", "G#", "Ab", "A", "A#", "Bb", "B",
                "Cm", "C#m", "Dbm", "Dm", "D#m", "Ebm", "Em", "Fm", "F#m", "Gbm", "Gm", "G#m", "Abm", "Am", "A#m", "Bbm", "Bm"
            ]
            guard validKeys.contains(key) else {
                throw ValidationError.invalidValue("Invalid musical key: \(key)")
            }
        }
    }

    private func validateRelationships() throws {
        // Preset can exist without being assigned to a project (for global presets)
        // But if it has a project, validate the relationship
        if let project = project {
            guard !project.isDeleted else {
                throw ValidationError.relationshipConstraint("Preset cannot belong to a deleted project")
            }
        }
    }

    private func validateParameters() throws {
        if let parametersData = parameters {
            // Validate that parameters data is not corrupted
            do {
                _ = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSDictionary.self, from: parametersData)
            } catch {
                throw ValidationError.invalidValue("Preset parameters data is corrupted: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Parameter Management

    /// Sets parameters for the preset
    /// - Parameter params: Dictionary of parameter values
    public func setParameters(_ params: [String: Any]) throws {
        do {
            parameters = try NSKeyedArchiver.archivedData(withRootObject: params, requiringSecureCoding: false)
        } catch {
            throw ValidationError.invalidValue("Failed to encode preset parameters: \(error.localizedDescription)")
        }
    }

    /// Gets parameters for the preset
    /// - Returns: Dictionary of parameter values
    public func getParameters() -> [String: Any] {
        guard let parametersData = parameters else { return [:] }
        
        do {
            if let params = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSDictionary.self, from: parametersData) as? [String: Any] {
                return params
            }
        } catch {
            print("Failed to decode preset parameters: \(error)")
        }
        
        return [:]
    }

    /// Sets a specific parameter value
    /// - Parameters:
    ///   - key: Parameter name
    ///   - value: Parameter value
    public func setParameter(key: String, value: Any) throws {
        var params = getParameters()
        params[key] = value
        try setParameters(params)
    }

    /// Gets a specific parameter value
    /// - Parameter key: Parameter name
    /// - Returns: Parameter value if it exists
    public func getParameter(key: String) -> Any? {
        return getParameters()[key]
    }

    // MARK: - Convenience Methods

    /// Increments the usage count
    public func incrementUsageCount() {
        usageCount += 1
    }

    /// Gets tags as an array
    /// - Returns: Array of individual tags
    public func getTagsArray() -> [String] {
        guard let tags = tags, !tags.isEmpty else { return [] }
        return tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// Sets tags from an array
    /// - Parameter tagArray: Array of tags
    public func setTags(_ tagArray: [String]) {
        let cleanedTags = tagArray.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        tags = cleanedTags.joined(separator: ", ")
    }

    /// Checks if preset has a specific tag
    /// - Parameter tag: Tag to check for
    /// - Returns: True if preset has the tag
    public func hasTag(_ tag: String) -> Bool {
        return getTagsArray().contains(tag.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Creates a copy of this preset with a new name
    /// - Parameter newName: Name for the copied preset
    /// - Returns: The newly created preset copy
    public func copy(withName newName: String) -> Preset {
        let presetCopy = Preset(context: managedObjectContext!)
        presetCopy.name = newName
        presetCopy.category = self.category
        presetCopy.machineType = self.machineType
        presetCopy.description = self.description
        presetCopy.author = self.author
        presetCopy.version = self.version
        presetCopy.tags = self.tags
        presetCopy.tempo = self.tempo
        presetCopy.key = self.key
        presetCopy.parameters = self.parameters
        presetCopy.isDefault = false // Copies are never default
        presetCopy.isFavorite = false // Copies start unfavorited
        presetCopy.rating = 0 // Copies start unrated
        presetCopy.usageCount = 0 // Copies start with zero usage
        return presetCopy
    }

    /// Exports preset as a dictionary for sharing
    /// - Returns: Dictionary representation of the preset
    public func exportDictionary() -> [String: Any] {
        var exportDict: [String: Any] = [:]
        
        exportDict["name"] = name
        exportDict["category"] = category
        exportDict["machineType"] = machineType
        exportDict["description"] = description
        exportDict["author"] = author
        exportDict["version"] = version
        exportDict["tags"] = tags
        exportDict["tempo"] = tempo
        exportDict["key"] = key
        exportDict["parameters"] = getParameters()
        exportDict["exportDate"] = Date()
        
        return exportDict
    }
}