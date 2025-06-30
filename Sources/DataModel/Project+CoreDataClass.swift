import Foundation
import CoreData

@objc(Project)
public class Project: NSManagedObject {
    
    // MARK: - Convenience Initializers
    
    /// Create a new project with default values
    public static func create(in context: NSManagedObjectContext, name: String) -> Project {
        let project = Project(context: context)
        project.id = UUID()
        project.name = name
        project.createdDate = Date()
        project.modifiedDate = Date()
        project.version = "1.0"
        project.tempo = 120.0
        project.masterVolume = 0.8
        project.swingAmount = 0.0
        project.isTemplate = false
        
        // Create default mixer settings
        let mixerSettings = MixerSettings(context: context)
        mixerSettings.id = UUID()
        mixerSettings.masterVolume = 0.8
        mixerSettings.limiterEnabled = true
        mixerSettings.limiterThreshold = 0.95
        mixerSettings.monitorMode = "stereo"
        project.mixerSettings = mixerSettings
        
        // Create default preset pool
        let presetPool = PresetPool(context: context)
        presetPool.id = UUID()
        presetPool.name = "\(name) Presets"
        presetPool.poolType = "user"
        presetPool.version = "1.0"
        presetPool.isShared = false
        presetPool.createdDate = Date()
        presetPool.modifiedDate = Date()
        project.presetPool = presetPool
        
        return project
    }
    
    // MARK: - Computed Properties
    
    /// Number of patterns in this project
    public var patternCount: Int {
        return patterns?.count ?? 0
    }
    
    /// Number of presets in the project's preset pool
    public var presetCount: Int {
        return presetPool?.presets?.count ?? 0
    }
    
    /// Total number of tracks across all patterns
    public var totalTrackCount: Int {
        guard let patterns = patterns else { return 0 }
        return patterns.compactMap { ($0 as? Pattern)?.tracks?.count }.reduce(0, +)
    }
    
    /// Whether the project has been modified recently
    public var isRecentlyModified: Bool {
        guard let modifiedDate = modifiedDate else { return false }
        return Date().timeIntervalSince(modifiedDate) < 3600 // Within last hour
    }
    
    /// Sorted patterns by creation date
    public var sortedPatterns: [Pattern] {
        guard let patterns = patterns?.allObjects as? [Pattern] else { return [] }
        return patterns.sorted { 
            ($0.createdDate ?? Date.distantPast) < ($1.createdDate ?? Date.distantPast)
        }
    }
    
    /// Color theme as enum
    public var themeColor: ProjectTheme {
        get {
            guard let colorTheme = colorTheme else { return .default }
            return ProjectTheme(rawValue: colorTheme) ?? .default
        }
        set {
            colorTheme = newValue.rawValue
            updateModifiedDate()
        }
    }
    
    // MARK: - Pattern Management
    
    /// Add a new pattern to the project
    @discardableResult
    public func addPattern(name: String) -> Pattern {
        let pattern = Pattern.create(in: managedObjectContext!, name: name, project: self)
        updateModifiedDate()
        return pattern
    }
    
    /// Remove a pattern from the project
    public func removePattern(_ pattern: Pattern) {
        managedObjectContext?.delete(pattern)
        updateModifiedDate()
    }
    
    /// Get pattern by name
    public func pattern(named name: String) -> Pattern? {
        return sortedPatterns.first { $0.name == name }
    }
    
    // MARK: - Preset Management
    
    /// Add a preset to the project's preset pool
    public func addPreset(_ preset: Preset) {
        presetPool?.addToPresets(preset)
        updateModifiedDate()
    }
    
    /// Remove a preset from the project's preset pool
    public func removePreset(_ preset: Preset) {
        presetPool?.removeFromPresets(preset)
        updateModifiedDate()
    }
    
    /// Get all presets of a specific machine type
    public func presets(ofType machineType: String) -> [Preset] {
        guard let presets = presetPool?.presets?.allObjects as? [Preset] else { return [] }
        return presets.filter { $0.machineType == machineType }
    }
    
    // MARK: - Project Configuration
    
    /// Update the project's modified date
    public func updateModifiedDate() {
        modifiedDate = Date()
    }
    
    /// Duplicate this project with a new name
    public func duplicate(withName newName: String, in context: NSManagedObjectContext) -> Project {
        let newProject = Project.create(in: context, name: newName)
        
        // Copy basic properties
        newProject.description = description
        newProject.tags = tags
        newProject.tempo = tempo
        newProject.colorTheme = colorTheme
        newProject.masterVolume = masterVolume
        newProject.swingAmount = swingAmount
        
        // Copy mixer settings
        if let originalMixer = mixerSettings {
            let newMixer = MixerSettings(context: context)
            newMixer.id = UUID()
            newMixer.copySettings(from: originalMixer)
            newProject.mixerSettings = newMixer
        }
        
        // Copy patterns
        for pattern in sortedPatterns {
            pattern.duplicate(in: newProject)
        }
        
        return newProject
    }
    
    /// Export project metadata
    public func exportMetadata() -> [String: Any] {
        var metadata: [String: Any] = [:]
        metadata["id"] = id?.uuidString
        metadata["name"] = name
        metadata["version"] = version
        metadata["tempo"] = tempo
        metadata["createdDate"] = createdDate?.timeIntervalSince1970
        metadata["modifiedDate"] = modifiedDate?.timeIntervalSince1970
        metadata["patternCount"] = patternCount
        metadata["presetCount"] = presetCount
        metadata["description"] = description
        metadata["tags"] = tags
        metadata["colorTheme"] = colorTheme
        metadata["masterVolume"] = masterVolume
        metadata["swingAmount"] = swingAmount
        metadata["isTemplate"] = isTemplate
        return metadata
    }
    
    // MARK: - Validation
    
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateProject()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateProject()
    }
    
    private func validateProject() throws {
        // Validate required fields
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName("Project name cannot be empty")
        }
        
        guard let version = version, !version.isEmpty else {
            throw ValidationError.invalidVersion("Project version cannot be empty")
        }
        
        // Validate tempo range
        if tempo < 60.0 || tempo > 300.0 {
            throw ValidationError.invalidTempo("Tempo must be between 60 and 300 BPM")
        }
        
        // Validate volume range
        if masterVolume < 0.0 || masterVolume > 1.0 {
            throw ValidationError.invalidVolume("Master volume must be between 0.0 and 1.0")
        }
        
        // Validate swing amount
        if swingAmount < -1.0 || swingAmount > 1.0 {
            throw ValidationError.invalidSwing("Swing amount must be between -1.0 and 1.0")
        }
    }
}

// MARK: - Project Theme Enum

public enum ProjectTheme: String, CaseIterable {
    case `default` = "default"
    case dark = "dark"
    case light = "light"
    case blue = "blue"
    case green = "green"
    case purple = "purple"
    case orange = "orange"
    case red = "red"
    
    public var displayName: String {
        switch self {
        case .default: return "Default"
        case .dark: return "Dark"
        case .light: return "Light"
        case .blue: return "Blue"
        case .green: return "Green"
        case .purple: return "Purple"
        case .orange: return "Orange"
        case .red: return "Red"
        }
    }
}

// MARK: - Validation Errors

public enum ValidationError: LocalizedError {
    case invalidName(String)
    case invalidVersion(String)
    case invalidTempo(String)
    case invalidVolume(String)
    case invalidSwing(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidName(let message),
             .invalidVersion(let message),
             .invalidTempo(let message),
             .invalidVolume(let message),
             .invalidSwing(let message):
            return message
        }
    }
} 