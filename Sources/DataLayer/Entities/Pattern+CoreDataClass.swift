import Foundation
import CoreData
import DataModel

@objc(Pattern)
public class Pattern: NSManagedObject {

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()

        // Set default values
        let now = Date()
        createdAt = now
        updatedAt = now

        // Set default values
        if name == nil || name?.isEmpty == true {
            name = "New Pattern"
        }
        if length == 0 {
            length = 16 // Default 16-step pattern
        }
        if tempo == 0 {
            tempo = 120.0 // Default 120 BPM
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
        case "length":
            try validateLength(value.pointee as? NSNumber)
        case "tempo":
            try validateTempo(value.pointee as? NSNumber)
        default:
            break
        }
    }

    private func validateName(_ name: String?) throws {
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName("Pattern name cannot be empty")
        }

        guard name.count <= 50 else {
            throw ValidationError.invalidName("Pattern name cannot exceed 50 characters")
        }
    }

    private func validateLength(_ length: NSNumber?) throws {
        guard let length = length?.int16Value else {
            throw ValidationError.invalidValue("Pattern length must be specified")
        }

        guard length >= 1 && length <= 128 else {
            throw ValidationError.invalidValue("Pattern length must be between 1 and 128 steps")
        }
    }

    private func validateTempo(_ tempo: NSNumber?) throws {
        guard let tempo = tempo?.doubleValue else {
            throw ValidationError.invalidValue("Pattern tempo must be specified")
        }

        guard tempo >= 30.0 && tempo <= 300.0 else {
            throw ValidationError.invalidValue("Pattern tempo must be between 30 and 300 BPM")
        }
    }

    // MARK: - Convenience Methods

    /// Creates a new track for this pattern
    /// - Parameters:
    ///   - name: The name for the new track
    ///   - trackIndex: The index position (0-15)
    /// - Returns: The newly created track
    public func createTrack(name: String = "New Track", trackIndex: Int16 = 0) -> Track {
        let track = Track(context: managedObjectContext!)
        track.name = name
        track.trackIndex = trackIndex
        track.pattern = self
        return track
    }

    /// Gets all tracks sorted by track index
    /// - Returns: Array of tracks sorted by index
    public func sortedTracks() -> [Track] {
        guard let tracks = tracks as? Set<Track> else { return [] }
        return tracks.sorted { $0.trackIndex < $1.trackIndex }
    }

    /// Gets the total number of steps considering all tracks
    /// - Returns: The maximum step count across all tracks
    public func totalSteps() -> Int {
        let trackSteps = sortedTracks().compactMap { track in
            guard let trigs = track.trigs as? Set<Trig> else { return 0 }
            return trigs.map { Int($0.step) }.max()
        }
        return trackSteps.max() ?? Int(length)
    }
}