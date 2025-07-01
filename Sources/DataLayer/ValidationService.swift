import Foundation
import CoreData

/// Centralized validation service for DataLayer entities
public final class ValidationService: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = ValidationService()
    
    private init() {}
    
    // MARK: - Core Entity Validation
    
    /// Validates a project entity
    /// - Parameter project: The project to validate
    /// - Throws: ValidationError if validation fails
    public func validateProject(_ project: Project) throws {
        try validateProjectName(project.name)
        try validateTimestamps(createdAt: project.createdAt, updatedAt: project.updatedAt)
        try validateProjectTempo(project.tempo)
        try validateProjectDescription(project.description)
        try validateProjectVersion(project.version)
        try validateProjectColorTheme(project.colorTheme)
        try validateProjectMasterVolume(project.masterVolume)
        try validateProjectSwingAmount(project.swingAmount)
    }
    
    /// Validates a pattern entity
    /// - Parameter pattern: The pattern to validate
    /// - Throws: ValidationError if validation fails
    public func validatePattern(_ pattern: Pattern) throws {
        try validatePatternName(pattern.name)
        try validatePatternLength(pattern.length)
        try validatePatternTempo(pattern.tempo)
        try validatePatternResolution(pattern.resolution)
        try validatePatternTimeSignature(pattern.timeSignatureNumerator, pattern.timeSignatureDenominator)
        try validateTimestamps(createdAt: pattern.createdAt, updatedAt: pattern.updatedAt)
        
        // Validate relationship
        guard pattern.project != nil else {
            throw ValidationError.relationshipConstraint("Pattern must belong to a project")
        }
    }
    
    /// Validates a track entity
    /// - Parameter track: The track to validate
    /// - Throws: ValidationError if validation fails
    public func validateTrack(_ track: Track) throws {
        try validateTrackName(track.name)
        try validateTrackIndex(track.trackIndex)
        try validateTrackVolume(track.volume)
        try validateTrackPan(track.pan)
        try validateTrackPitch(track.pitch)
        try validateTrackLength(track.length)
        try validateTrackSendLevels(track.send1Level, track.send2Level)
        try validateTrackMicroTiming(track.microTiming)
        try validateTrackChance(track.chance)
        try validateTrackRetrigCount(track.retrigCount)
        
        // Validate relationship
        guard track.pattern != nil else {
            throw ValidationError.relationshipConstraint("Track must belong to a pattern")
        }
        
        // Validate track index uniqueness within pattern
        if let pattern = track.pattern, let tracks = pattern.tracks as? Set<Track> {
            let duplicateIndexTracks = tracks.filter { $0.trackIndex == track.trackIndex && $0 != track }
            if !duplicateIndexTracks.isEmpty {
                throw ValidationError.relationshipConstraint("Track index \(track.trackIndex) is already used in this pattern")
            }
        }
    }
    
    /// Validates a trig entity
    /// - Parameter trig: The trig to validate
    /// - Throws: ValidationError if validation fails
    public func validateTrig(_ trig: Trig) throws {
        try validateTrigStep(trig.step)
        try validateTrigNote(trig.note)
        try validateTrigVelocity(trig.velocity)
        try validateTrigDuration(trig.duration)
        try validateTrigProbability(trig.probability)
        try validateTrigMicroTiming(trig.microTiming)
        try validateTrigRetrigCount(trig.retrigCount)
        try validateTrigRetrigRate(trig.retrigRate)
        try validateTimestamps(createdAt: trig.createdAt, updatedAt: trig.updatedAt)
        
        // Validate relationships
        guard trig.track != nil else {
            throw ValidationError.relationshipConstraint("Trig must belong to a track")
        }
        guard trig.pattern != nil else {
            throw ValidationError.relationshipConstraint("Trig must belong to a pattern")
        }
        
        // Validate step is within track/pattern length
        if let track = trig.track {
            guard trig.step < track.length else {
                throw ValidationError.invalidValue("Trig step \(trig.step) exceeds track length \(track.length)")
            }
        }
    }
    
    /// Validates a kit entity
    /// - Parameter kit: The kit to validate
    /// - Throws: ValidationError if validation fails
    public func validateKit(_ kit: Kit) throws {
        try validateKitName(kit.name)
        try validateKitType(kit.kitType)
        try validateKitDescription(kit.description)
        try validateKitMasterVolume(kit.masterVolume)
        try validateKitMasterTune(kit.masterTune)
        try validateTimestamps(createdAt: kit.createdAt, updatedAt: kit.updatedAt)
    }
    
    /// Validates a preset entity
    /// - Parameter preset: The preset to validate
    /// - Throws: ValidationError if validation fails
    public func validatePreset(_ preset: Preset) throws {
        try validatePresetName(preset.name)
        try validatePresetCategory(preset.category)
        try validatePresetMachineType(preset.machineType)
        try validatePresetDescription(preset.description)
        try validatePresetAuthor(preset.author)
        try validatePresetVersion(preset.version)
        try validatePresetTags(preset.tags)
        try validatePresetRating(preset.rating)
        try validatePresetUsageCount(preset.usageCount)
        try validatePresetTempo(preset.tempo)
        try validatePresetKey(preset.key)
        try validateTimestamps(createdAt: preset.createdAt, updatedAt: preset.updatedAt)
    }
    
    // MARK: - Machine Entity Validation
    
    /// Validates a machine entity (base validation)
    /// - Parameter machine: The machine to validate
    /// - Throws: ValidationError if validation fails
    public func validateMachine(_ machine: NSManagedObject) throws {
        // This would be implemented when machine entities are created
        // For now, basic validation placeholder
        guard machine.managedObjectContext != nil else {
            throw ValidationError.relationshipConstraint("Machine must have a managed object context")
        }
    }
    
    // MARK: - Project Field Validation
    
    private func validateProjectName(_ name: String?) throws {
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName("Project name cannot be empty")
        }
        
        guard name.count <= 100 else {
            throw ValidationError.invalidName("Project name cannot exceed 100 characters")
        }
        
        // Check for invalid file system characters
        let invalidCharacters = CharacterSet(charactersIn: "<>:\"/\\|?*")
        guard name.rangeOfCharacter(from: invalidCharacters) == nil else {
            throw ValidationError.invalidName("Project name contains invalid characters")
        }
    }
    
    private func validateProjectTempo(_ tempo: Double) throws {
        guard tempo >= 30.0 && tempo <= 300.0 else {
            throw ValidationError.invalidValue("Project tempo must be between 30.0 and 300.0 BPM")
        }
    }
    
    private func validateProjectDescription(_ description: String?) throws {
        if let description = description {
            guard description.count <= 1000 else {
                throw ValidationError.invalidValue("Project description cannot exceed 1000 characters")
            }
        }
    }
    
    private func validateProjectVersion(_ version: String?) throws {
        if let version = version {
            guard !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError.invalidValue("Project version cannot be empty if specified")
            }
            
            guard version.count <= 20 else {
                throw ValidationError.invalidValue("Project version cannot exceed 20 characters")
            }
        }
    }
    
    private func validateProjectColorTheme(_ colorTheme: String?) throws {
        if let colorTheme = colorTheme {
            let validThemes = ["default", "dark", "light", "blue", "green", "red", "purple", "orange"]
            guard validThemes.contains(colorTheme.lowercased()) else {
                throw ValidationError.invalidValue("Invalid color theme: \(colorTheme)")
            }
        }
    }
    
    private func validateProjectMasterVolume(_ masterVolume: Float) throws {
        guard masterVolume >= 0.0 && masterVolume <= 1.0 else {
            throw ValidationError.invalidValue("Project master volume must be between 0.0 and 1.0")
        }
    }
    
    private func validateProjectSwingAmount(_ swingAmount: Float) throws {
        guard swingAmount >= 0.0 && swingAmount <= 1.0 else {
            throw ValidationError.invalidValue("Project swing amount must be between 0.0 and 1.0")
        }
    }
    
    // MARK: - Pattern Field Validation
    
    private func validatePatternName(_ name: String?) throws {
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName("Pattern name cannot be empty")
        }
        
        guard name.count <= 50 else {
            throw ValidationError.invalidName("Pattern name cannot exceed 50 characters")
        }
    }
    
    private func validatePatternLength(_ length: Int16) throws {
        guard length >= 1 && length <= 128 else {
            throw ValidationError.invalidValue("Pattern length must be between 1 and 128 steps")
        }
    }
    
    private func validatePatternTempo(_ tempo: Double) throws {
        guard tempo >= 30.0 && tempo <= 300.0 else {
            throw ValidationError.invalidValue("Pattern tempo must be between 30.0 and 300.0 BPM")
        }
    }
    
    private func validatePatternResolution(_ resolution: Int16) throws {
        let validResolutions: [Int16] = [1, 2, 4, 8, 16, 32, 64]
        guard validResolutions.contains(resolution) else {
            throw ValidationError.invalidValue("Invalid pattern resolution: \(resolution). Valid values: \(validResolutions)")
        }
    }
    
    private func validatePatternTimeSignature(_ numerator: Int16, _ denominator: Int16) throws {
        guard numerator >= 1 && numerator <= 16 else {
            throw ValidationError.invalidValue("Time signature numerator must be between 1 and 16")
        }
        
        let validDenominators: [Int16] = [1, 2, 4, 8, 16]
        guard validDenominators.contains(denominator) else {
            throw ValidationError.invalidValue("Invalid time signature denominator: \(denominator). Valid values: \(validDenominators)")
        }
    }
    
    // MARK: - Track Field Validation
    
    private func validateTrackName(_ name: String?) throws {
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName("Track name cannot be empty")
        }
        
        guard name.count <= 30 else {
            throw ValidationError.invalidName("Track name cannot exceed 30 characters")
        }
    }
    
    private func validateTrackIndex(_ index: Int16) throws {
        guard index >= 0 && index <= 15 else {
            throw ValidationError.invalidValue("Track index must be between 0 and 15")
        }
    }
    
    private func validateTrackVolume(_ volume: Float) throws {
        guard volume >= 0.0 && volume <= 1.0 else {
            throw ValidationError.invalidValue("Track volume must be between 0.0 and 1.0")
        }
    }
    
    private func validateTrackPan(_ pan: Float) throws {
        guard pan >= -1.0 && pan <= 1.0 else {
            throw ValidationError.invalidValue("Track pan must be between -1.0 and 1.0")
        }
    }
    
    private func validateTrackPitch(_ pitch: Float) throws {
        guard pitch >= -24.0 && pitch <= 24.0 else {
            throw ValidationError.invalidValue("Track pitch must be between -24.0 and 24.0 semitones")
        }
    }
    
    private func validateTrackLength(_ length: Int16) throws {
        guard length >= 1 && length <= 128 else {
            throw ValidationError.invalidValue("Track length must be between 1 and 128 steps")
        }
    }
    
    private func validateTrackSendLevels(_ send1: Float, _ send2: Float) throws {
        guard send1 >= 0.0 && send1 <= 1.0 else {
            throw ValidationError.invalidValue("Track send 1 level must be between 0.0 and 1.0")
        }
        
        guard send2 >= 0.0 && send2 <= 1.0 else {
            throw ValidationError.invalidValue("Track send 2 level must be between 0.0 and 1.0")
        }
    }
    
    private func validateTrackMicroTiming(_ microTiming: Float) throws {
        guard microTiming >= -50.0 && microTiming <= 50.0 else {
            throw ValidationError.invalidValue("Track micro timing must be between -50.0 and 50.0 milliseconds")
        }
    }
    
    private func validateTrackChance(_ chance: Int16) throws {
        guard chance >= 0 && chance <= 100 else {
            throw ValidationError.invalidValue("Track chance must be between 0 and 100 percent")
        }
    }
    
    private func validateTrackRetrigCount(_ retrigCount: Int16) throws {
        guard retrigCount >= 0 && retrigCount <= 8 else {
            throw ValidationError.invalidValue("Track retrig count must be between 0 and 8")
        }
    }
    
    // MARK: - Trig Field Validation
    
    private func validateTrigStep(_ step: Int16) throws {
        guard step >= 0 && step <= 127 else {
            throw ValidationError.invalidValue("Trig step must be between 0 and 127")
        }
    }
    
    private func validateTrigNote(_ note: Int16) throws {
        guard note >= 0 && note <= 127 else {
            throw ValidationError.invalidValue("Trig note must be between 0 and 127 (MIDI range)")
        }
    }
    
    private func validateTrigVelocity(_ velocity: Int16) throws {
        guard velocity >= 1 && velocity <= 127 else {
            throw ValidationError.invalidValue("Trig velocity must be between 1 and 127")
        }
    }
    
    private func validateTrigDuration(_ duration: Float) throws {
        guard duration >= 0.1 && duration <= 16.0 else {
            throw ValidationError.invalidValue("Trig duration must be between 0.1 and 16.0 steps")
        }
    }
    
    private func validateTrigProbability(_ probability: Int16) throws {
        guard probability >= 0 && probability <= 100 else {
            throw ValidationError.invalidValue("Trig probability must be between 0 and 100 percent")
        }
    }
    
    private func validateTrigMicroTiming(_ microTiming: Float) throws {
        guard microTiming >= -50.0 && microTiming <= 50.0 else {
            throw ValidationError.invalidValue("Trig micro timing must be between -50.0 and 50.0 milliseconds")
        }
    }
    
    private func validateTrigRetrigCount(_ retrigCount: Int16) throws {
        guard retrigCount >= 0 && retrigCount <= 8 else {
            throw ValidationError.invalidValue("Trig retrig count must be between 0 and 8")
        }
    }
    
    private func validateTrigRetrigRate(_ retrigRate: Float) throws {
        guard retrigRate >= 0.125 && retrigRate <= 2.0 else {
            throw ValidationError.invalidValue("Trig retrig rate must be between 0.125 and 2.0")
        }
    }
    
    // MARK: - Kit Field Validation
    
    private func validateKitName(_ name: String?) throws {
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName("Kit name cannot be empty")
        }
        
        guard name.count <= 50 else {
            throw ValidationError.invalidName("Kit name cannot exceed 50 characters")
        }
    }
    
    private func validateKitType(_ kitType: String?) throws {
        guard let kitType = kitType, !kitType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidValue("Kit type cannot be empty")
        }
        
        let validKitTypes = ["standard", "drum", "percussion", "melodic", "bass", "lead", "pad", "fx"]
        guard validKitTypes.contains(kitType.lowercased()) else {
            throw ValidationError.invalidValue("Invalid kit type: \(kitType)")
        }
    }
    
    private func validateKitDescription(_ description: String?) throws {
        if let description = description {
            guard description.count <= 500 else {
                throw ValidationError.invalidValue("Kit description cannot exceed 500 characters")
            }
        }
    }
    
    private func validateKitMasterVolume(_ masterVolume: Float) throws {
        guard masterVolume >= 0.0 && masterVolume <= 1.0 else {
            throw ValidationError.invalidValue("Kit master volume must be between 0.0 and 1.0")
        }
    }
    
    private func validateKitMasterTune(_ masterTune: Float) throws {
        guard masterTune >= -12.0 && masterTune <= 12.0 else {
            throw ValidationError.invalidValue("Kit master tune must be between -12.0 and 12.0 semitones")
        }
    }
    
    // MARK: - Preset Field Validation
    
    private func validatePresetName(_ name: String?) throws {
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
    
    private func validatePresetCategory(_ category: String?) throws {
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
    
    private func validatePresetMachineType(_ machineType: String?) throws {
        guard let machineType = machineType, !machineType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidValue("Preset machine type cannot be empty")
        }
        
        let validMachineTypes = ["FM TONE", "FM DRUM", "WAVETONE", "SWARMER", "FILTER", "FX"]
        guard validMachineTypes.contains(machineType) else {
            throw ValidationError.invalidValue("Invalid machine type: \(machineType)")
        }
    }
    
    private func validatePresetDescription(_ description: String?) throws {
        if let description = description {
            guard description.count <= 1000 else {
                throw ValidationError.invalidValue("Preset description cannot exceed 1000 characters")
            }
        }
    }
    
    private func validatePresetAuthor(_ author: String?) throws {
        if let author = author {
            guard !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError.invalidValue("Preset author cannot be empty if specified")
            }
            
            guard author.count <= 100 else {
                throw ValidationError.invalidValue("Preset author cannot exceed 100 characters")
            }
        }
    }
    
    private func validatePresetVersion(_ version: String?) throws {
        if let version = version {
            guard !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError.invalidValue("Preset version cannot be empty if specified")
            }
            
            guard version.count <= 20 else {
                throw ValidationError.invalidValue("Preset version cannot exceed 20 characters")
            }
            
            // Basic version format validation
            let versionRegex = try! NSRegularExpression(pattern: "^\\d+(\\.\\d+)*$")
            let range = NSRange(location: 0, length: version.utf16.count)
            guard versionRegex.firstMatch(in: version, options: [], range: range) != nil else {
                throw ValidationError.invalidValue("Invalid version format: \(version)")
            }
        }
    }
    
    private func validatePresetTags(_ tags: String?) throws {
        if let tags = tags {
            guard tags.count <= 200 else {
                throw ValidationError.invalidValue("Preset tags cannot exceed 200 characters")
            }
            
            // Validate individual tags
            let tagArray = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            for tag in tagArray {
                guard !tag.isEmpty else {
                    throw ValidationError.invalidValue("Empty tags are not allowed")
                }
                guard tag.count <= 30 else {
                    throw ValidationError.invalidValue("Individual tag cannot exceed 30 characters")
                }
            }
        }
    }
    
    private func validatePresetRating(_ rating: Int16) throws {
        guard rating >= 0 && rating <= 5 else {
            throw ValidationError.invalidValue("Preset rating must be between 0 and 5 stars")
        }
    }
    
    private func validatePresetUsageCount(_ usageCount: Int32) throws {
        guard usageCount >= 0 else {
            throw ValidationError.invalidValue("Preset usage count cannot be negative")
        }
    }
    
    private func validatePresetTempo(_ tempo: Double) throws {
        if tempo > 0 {
            guard tempo >= 30.0 && tempo <= 300.0 else {
                throw ValidationError.invalidValue("Preset tempo must be between 30 and 300 BPM")
            }
        }
    }
    
    private func validatePresetKey(_ key: String?) throws {
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
    
    // MARK: - Common Validation
    
    private func validateTimestamps(createdAt: Date?, updatedAt: Date?) throws {
        if let createdAt = createdAt, let updatedAt = updatedAt {
            guard updatedAt >= createdAt else {
                throw ValidationError.invalidValue("Updated timestamp cannot be before created timestamp")
            }
        }
    }
    
    // MARK: - Batch Validation
    
    /// Validates multiple entities in a batch
    /// - Parameter entities: Array of NSManagedObject entities to validate
    /// - Returns: Array of validation errors (empty if all valid)
    public func batchValidate(_ entities: [NSManagedObject]) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        for entity in entities {
            do {
                try validateEntity(entity)
            } catch let error as ValidationError {
                errors.append(error)
            } catch {
                errors.append(ValidationError.invalidValue("Unknown validation error: \(error.localizedDescription)"))
            }
        }
        
        return errors
    }
    
    /// Validates a single entity based on its type
    /// - Parameter entity: The entity to validate
    /// - Throws: ValidationError if validation fails
    public func validateEntity(_ entity: NSManagedObject) throws {
        switch entity {
        case let project as Project:
            try validateProject(project)
        case let pattern as Pattern:
            try validatePattern(pattern)
        case let track as Track:
            try validateTrack(track)
        case let trig as Trig:
            try validateTrig(trig)
        case let kit as Kit:
            try validateKit(kit)
        case let preset as Preset:
            try validatePreset(preset)
        default:
            // Handle machine entities and other types
            try validateMachine(entity)
        }
    }
    
    // MARK: - Validation Rules Enforcement
    
    /// Validates business rules across multiple entities
    /// - Parameter context: The managed object context
    /// - Throws: ValidationError if business rules are violated
    public func validateBusinessRules(in context: NSManagedObjectContext) throws {
        // Validate project limits
        try validateProjectLimits(in: context)
        
        // Validate pattern track consistency
        try validatePatternTrackConsistency(in: context)
        
        // Validate preset machine type consistency
        try validatePresetMachineTypeConsistency(in: context)
    }
    
    private func validateProjectLimits(in context: NSManagedObjectContext) throws {
        let projectRequest: NSFetchRequest<Project> = Project.fetchRequest()
        let projectCount = try context.count(for: projectRequest)
        
        // Arbitrary limit for demo purposes
        guard projectCount <= 100 else {
            throw ValidationError.invalidValue("Maximum number of projects (100) exceeded")
        }
    }
    
    private func validatePatternTrackConsistency(in context: NSManagedObjectContext) throws {
        let patternRequest: NSFetchRequest<Pattern> = Pattern.fetchRequest()
        let patterns = try context.fetch(patternRequest)
        
        for pattern in patterns {
            if let tracks = pattern.tracks as? Set<Track> {
                // Validate no duplicate track indices
                let trackIndices = tracks.map { $0.trackIndex }
                let uniqueIndices = Set(trackIndices)
                
                guard trackIndices.count == uniqueIndices.count else {
                    throw ValidationError.relationshipConstraint("Pattern '\(pattern.name ?? "")' has duplicate track indices")
                }
                
                // Validate track count
                guard tracks.count <= 16 else {
                    throw ValidationError.relationshipConstraint("Pattern '\(pattern.name ?? "")' cannot have more than 16 tracks")
                }
            }
        }
    }
    
    private func validatePresetMachineTypeConsistency(in context: NSManagedObjectContext) throws {
        let presetRequest: NSFetchRequest<Preset> = Preset.fetchRequest()
        let presets = try context.fetch(presetRequest)
        
        for preset in presets {
            if let machineType = preset.machineType, let category = preset.category {
                // Validate that machine type and category are compatible
                let validMachineTypes = ["FM TONE", "FM DRUM", "WAVETONE", "SWARMER", "FILTER", "FX"]
                guard validMachineTypes.contains(machineType) else {
                    throw ValidationError.relationshipConstraint("Preset '\(preset.name ?? "")' has invalid machine type: \(machineType)")
                }
            }
        }
    }
}

// MARK: - Validation Errors

public enum ValidationError: LocalizedError {
    case invalidName(String)
    case invalidValue(String)
    case relationshipConstraint(String)
    case businessRuleViolation(String)

    public var errorDescription: String? {
        switch self {
        case .invalidName(let message):
            return "Invalid name: \(message)"
        case .invalidValue(let message):
            return "Invalid value: \(message)"
        case .relationshipConstraint(let message):
            return "Relationship constraint: \(message)"
        case .businessRuleViolation(let message):
            return "Business rule violation: \(message)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidName:
            return "Please provide a valid name following the specified format and length requirements."
        case .invalidValue:
            return "Please ensure the value is within the valid range and format."
        case .relationshipConstraint:
            return "Please ensure all required relationships are properly established."
        case .businessRuleViolation:
            return "Please review and correct the data to comply with business rules."
        }
    }
}
