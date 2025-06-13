import Foundation
import CoreData

/// Centralized validation service for DataLayer entities
public final class ValidationService: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = ValidationService()
    
    private init() {}
    
    // MARK: - Validation Rules
    
    /// Validates a project entity
    /// - Parameter project: The project to validate
    /// - Throws: ValidationError if validation fails
    public func validateProject(_ project: Project) throws {
        try validateProjectName(project.name)
        try validateTimestamps(createdAt: project.createdAt, updatedAt: project.updatedAt)
    }
    
    /// Validates a pattern entity
    /// - Parameter pattern: The pattern to validate
    /// - Throws: ValidationError if validation fails
    public func validatePattern(_ pattern: Pattern) throws {
        try validatePatternName(pattern.name)
        try validatePatternLength(pattern.length)
        try validatePatternTempo(pattern.tempo)
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
        
        // Validate relationship
        guard track.pattern != nil else {
            throw ValidationError.relationshipConstraint("Track must belong to a pattern")
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
        try validateTimestamps(createdAt: trig.createdAt, updatedAt: trig.updatedAt)
        
        // Validate relationships
        guard trig.track != nil else {
            throw ValidationError.relationshipConstraint("Trig must belong to a track")
        }
        guard trig.pattern != nil else {
            throw ValidationError.relationshipConstraint("Trig must belong to a pattern")
        }
    }
    
    /// Validates a kit entity
    /// - Parameter kit: The kit to validate
    /// - Throws: ValidationError if validation fails
    public func validateKit(_ kit: Kit) throws {
        try validateKitName(kit.name)
        try validateKitSoundFiles(kit.soundFiles)
        try validateTimestamps(createdAt: kit.createdAt, updatedAt: kit.updatedAt)
    }
    
    /// Validates a preset entity
    /// - Parameter preset: The preset to validate
    /// - Throws: ValidationError if validation fails
    public func validatePreset(_ preset: Preset) throws {
        try validatePresetName(preset.name)
        try validatePresetCategory(preset.category)
        try validateTimestamps(createdAt: preset.createdAt, updatedAt: preset.updatedAt)
        
        // Validate relationship
        guard preset.project != nil else {
            throw ValidationError.relationshipConstraint("Preset must belong to a project")
        }
    }
    
    // MARK: - Individual Field Validation
    
    private func validateProjectName(_ name: String?) throws {
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName("Project name cannot be empty")
        }
        
        guard name.count <= 100 else {
            throw ValidationError.invalidName("Project name cannot exceed 100 characters")
        }
    }
    
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
    
    private func validateKitName(_ name: String?) throws {
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName("Kit name cannot be empty")
        }
        
        guard name.count <= 50 else {
            throw ValidationError.invalidName("Kit name cannot exceed 50 characters")
        }
    }
    
    private func validateKitSoundFiles(_ soundFiles: [String]?) throws {
        if let soundFiles = soundFiles {
            for filePath in soundFiles {
                guard !filePath.isEmpty else {
                    throw ValidationError.invalidValue("Sound file path cannot be empty")
                }
                
                guard filePath.count <= 500 else {
                    throw ValidationError.invalidValue("Sound file path too long")
                }
            }
        }
    }
    
    private func validatePresetName(_ name: String?) throws {
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName("Preset name cannot be empty")
        }
        
        guard name.count <= 50 else {
            throw ValidationError.invalidName("Preset name cannot exceed 50 characters")
        }
    }
    
    private func validatePresetCategory(_ category: String?) throws {
        if let category = category {
            guard !category.isEmpty else {
                throw ValidationError.invalidValue("Preset category cannot be empty if specified")
            }
            
            guard category.count <= 30 else {
                throw ValidationError.invalidValue("Preset category cannot exceed 30 characters")
            }
            
            let validCategories = ["FM TONE", "FM DRUM", "WAVETONE", "SWARMER", "FILTER", "FX"]
            guard validCategories.contains(category) else {
                throw ValidationError.invalidValue("Invalid preset category: \(category)")
            }
        }
    }
    
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
            throw ValidationError.invalidValue("Unknown entity type for validation")
        }
    }
}
