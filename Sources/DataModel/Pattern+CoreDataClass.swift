import Foundation
import CoreData

@objc(Pattern)
public class Pattern: NSManagedObject {
    
    // MARK: - Convenience Initializers
    
    /// Create a new pattern with default values
    public static func create(in context: NSManagedObjectContext, name: String, project: Project) -> Pattern {
        let pattern = Pattern(context: context)
        pattern.id = UUID()
        pattern.name = name
        pattern.length = 16
        pattern.resolution = 16
        pattern.tempo = project.tempo
        pattern.timeSignatureNumerator = 4
        pattern.timeSignatureDenominator = 4
        pattern.isPlaying = false
        pattern.isMuted = false
        pattern.isSoloed = false
        pattern.swing = 0.0
        pattern.shuffle = 0.0
        pattern.createdDate = Date()
        pattern.modifiedDate = Date()
        pattern.project = project
        
        // Create default kit
        let kit = Kit.create(in: context, name: "\(name) Kit")
        pattern.kit = kit
        
        // Create default tracks (16 tracks)
        for trackNumber in 1...16 {
            let track = Track.create(in: context, trackNumber: Int16(trackNumber), pattern: pattern)
            pattern.addToTracks(track)
        }
        
        return pattern
    }
    
    // MARK: - Computed Properties
    
    /// Number of tracks in this pattern
    public var trackCount: Int {
        return tracks?.count ?? 0
    }
    
    /// Number of active trigs across all tracks
    public var activeTrigCount: Int {
        guard let tracks = tracks?.allObjects as? [Track] else { return 0 }
        return tracks.compactMap { $0.activeTrigCount }.reduce(0, +)
    }
    
    /// Total number of trigs across all tracks
    public var totalTrigCount: Int {
        return trackCount * Int(length)
    }
    
    /// Duration in seconds based on tempo and length
    public var durationInSeconds: Double {
        let beatsPerBar = Double(timeSignatureNumerator)
        let bars = Double(length) / (Double(resolution) / beatsPerBar)
        let beatsPerMinute = Double(tempo)
        return (bars * beatsPerBar * 60.0) / beatsPerMinute
    }
    
    /// Sorted tracks by track number
    public var sortedTracks: [Track] {
        guard let tracks = tracks?.allObjects as? [Track] else { return [] }
        return tracks.sorted { $0.trackNumber < $1.trackNumber }
    }
    
    /// Whether this pattern has any active tracks
    public var hasActiveTracks: Bool {
        return sortedTracks.contains { !$0.isMuted }
    }
    
    /// Pattern complexity score (0-10)
    public var complexityScore: Int {
        let trigDensity = Double(activeTrigCount) / Double(totalTrigCount)
        let parameterLockCount = sortedTracks.flatMap { $0.sortedTrigs }.flatMap { $0.sortedParameterLocks }.count
        let effectCount = kit?.enabledEffectsCount ?? 0
        
        let score = (trigDensity * 5) + (Double(parameterLockCount) * 0.1) + (Double(effectCount) * 0.5)
        return min(10, Int(score))
    }
    
    // MARK: - Track Management
    
    /// Get track by track number
    public func track(number: Int16) -> Track? {
        return sortedTracks.first { $0.trackNumber == number }
    }
    
    /// Get tracks that are not muted
    public var activeTracks: [Track] {
        return sortedTracks.filter { !$0.isMuted }
    }
    
    /// Mute all tracks
    public func muteAllTracks() {
        for track in sortedTracks {
            track.isMuted = true
        }
        updateModifiedDate()
    }
    
    /// Unmute all tracks
    public func unmuteAllTracks() {
        for track in sortedTracks {
            track.isMuted = false
        }
        updateModifiedDate()
    }
    
    /// Solo a specific track (mutes all others)
    public func soloTrack(_ track: Track) {
        for t in sortedTracks {
            t.isSoloed = (t == track)
        }
        updateModifiedDate()
    }
    
    /// Clear all solo states
    public func clearAllSolos() {
        for track in sortedTracks {
            track.isSoloed = false
        }
        updateModifiedDate()
    }
    
    // MARK: - Pattern Configuration
    
    /// Update the pattern's modified date
    public func updateModifiedDate() {
        modifiedDate = Date()
        project?.updateModifiedDate()
    }
    
    /// Change pattern length and adjust trigs accordingly
    public func changeLength(to newLength: Int16) {
        let oldLength = length
        length = newLength
        
        if newLength > oldLength {
            // Add new trigs for extended length
            for track in sortedTracks {
                for stepNumber in (oldLength + 1)...newLength {
                    let trig = Trig.create(in: managedObjectContext!, stepNumber: stepNumber, track: track)
                    track.addToTrigs(trig)
                }
            }
        } else if newLength < oldLength {
            // Remove trigs beyond new length
            for track in sortedTracks {
                let trigsToRemove = track.sortedTrigs.filter { $0.stepNumber > newLength }
                for trig in trigsToRemove {
                    managedObjectContext?.delete(trig)
                }
            }
        }
        
        updateModifiedDate()
    }
    
    /// Copy all settings from another pattern
    public func copySettings(from other: Pattern) {
        tempo = other.tempo
        timeSignatureNumerator = other.timeSignatureNumerator
        timeSignatureDenominator = other.timeSignatureDenominator
        swing = other.swing
        shuffle = other.shuffle
        scale = other.scale
        key = other.key
        updateModifiedDate()
    }
    
    /// Duplicate this pattern with a new name
    public func duplicate(in project: Project) -> Pattern {
        let newPattern = Pattern.create(in: managedObjectContext!, name: "\(name!) Copy", project: project)
        
        // Copy basic settings
        newPattern.copySettings(from: self)
        newPattern.length = length
        newPattern.resolution = resolution
        
        // Copy kit reference (shared kit)
        newPattern.kit = kit
        
        // Clear default tracks and copy our tracks
        for track in newPattern.sortedTracks {
            managedObjectContext?.delete(track)
        }
        
        for track in sortedTracks {
            track.duplicate(in: newPattern)
        }
        
        return newPattern
    }
    
    /// Clear all trigs in the pattern
    public func clearAllTrigs() {
        for track in sortedTracks {
            track.clearAllTrigs()
        }
        updateModifiedDate()
    }
    
    /// Randomize pattern with specified probability
    public func randomize(trigProbability: Float = 0.3, velocityRange: ClosedRange<Float> = 0.5...1.0) {
        for track in sortedTracks {
            track.randomize(trigProbability: trigProbability, velocityRange: velocityRange)
        }
        updateModifiedDate()
    }
    
    // MARK: - Musical Functions
    
    /// Calculate the time position for a given step
    public func timePosition(for step: Int16) -> Double {
        let stepDuration = durationInSeconds / Double(length)
        return Double(step - 1) * stepDuration
    }
    
    /// Get the step number for a given time position
    public func stepNumber(for timePosition: Double) -> Int16 {
        let stepDuration = durationInSeconds / Double(length)
        return Int16(timePosition / stepDuration) + 1
    }
    
    /// Apply swing to step timing
    public func swingTiming(for step: Int16) -> Double {
        let baseTime = timePosition(for: step)
        let isOffBeat = (step - 1) % 2 == 1
        
        if isOffBeat && swing != 0.0 {
            let swingOffset = durationInSeconds / Double(length) * Double(swing) * 0.1
            return baseTime + swingOffset
        }
        
        return baseTime
    }
    
    // MARK: - Export/Import
    
    /// Export pattern data for sharing
    public func exportData() -> [String: Any] {
        var data: [String: Any] = [:]
        data["id"] = id?.uuidString
        data["name"] = name
        data["length"] = length
        data["resolution"] = resolution
        data["tempo"] = tempo
        data["timeSignature"] = [timeSignatureNumerator, timeSignatureDenominator]
        data["swing"] = swing
        data["shuffle"] = shuffle
        data["scale"] = scale
        data["key"] = key
        data["createdDate"] = createdDate?.timeIntervalSince1970
        data["modifiedDate"] = modifiedDate?.timeIntervalSince1970
        data["trackCount"] = trackCount
        data["activeTrigCount"] = activeTrigCount
        data["complexityScore"] = complexityScore
        
        // Export track data
        data["tracks"] = sortedTracks.map { $0.exportData() }
        
        return data
    }
    
    // MARK: - Validation
    
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validatePattern()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validatePattern()
    }
    
    private func validatePattern() throws {
        // Validate required fields
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName("Pattern name cannot be empty")
        }
        
        // Validate length
        if length < 1 || length > 128 {
            throw ValidationError.invalidLength("Pattern length must be between 1 and 128 steps")
        }
        
        // Validate resolution
        if resolution < 1 || resolution > 64 {
            throw ValidationError.invalidResolution("Pattern resolution must be between 1 and 64")
        }
        
        // Validate tempo
        if tempo < 60.0 || tempo > 300.0 {
            throw ValidationError.invalidTempo("Tempo must be between 60 and 300 BPM")
        }
        
        // Validate time signature
        if timeSignatureNumerator < 1 || timeSignatureNumerator > 32 {
            throw ValidationError.invalidTimeSignature("Time signature numerator must be between 1 and 32")
        }
        
        if ![1, 2, 4, 8, 16].contains(timeSignatureDenominator) {
            throw ValidationError.invalidTimeSignature("Time signature denominator must be 1, 2, 4, 8, or 16")
        }
        
        // Validate swing and shuffle
        if swing < -1.0 || swing > 1.0 {
            throw ValidationError.invalidSwing("Swing amount must be between -1.0 and 1.0")
        }
        
        if shuffle < -1.0 || shuffle > 1.0 {
            throw ValidationError.invalidShuffle("Shuffle amount must be between -1.0 and 1.0")
        }
    }
}

// MARK: - Validation Errors Extension

extension ValidationError {
    static func invalidLength(_ message: String) -> ValidationError {
        return .invalidName(message) // Reusing generic validation, could be made more specific
    }
    
    static func invalidResolution(_ message: String) -> ValidationError {
        return .invalidName(message)
    }
    
    static func invalidTimeSignature(_ message: String) -> ValidationError {
        return .invalidName(message)
    }
    
    static func invalidShuffle(_ message: String) -> ValidationError {
        return .invalidName(message)
    }
}
