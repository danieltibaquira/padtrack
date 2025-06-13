import Foundation
import CoreData

@objc(Track)
public class Track: NSManagedObject {

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()

        // Set default values
        let now = Date()
        createdAt = now
        updatedAt = now

        // Set default values
        if name == nil || name?.isEmpty == true {
            name = "Track"
        }
        if volume == 0 {
            volume = 0.75 // Default volume
        }
        if pan == 0 {
            pan = 0.0 // Center pan
        }
        isMuted = false
        isSolo = false
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
        case "volume":
            try validateVolume(value.pointee as? NSNumber)
        case "pan":
            try validatePan(value.pointee as? NSNumber)
        case "trackIndex":
            try validateTrackIndex(value.pointee as? NSNumber)
        default:
            break
        }
    }

    private func validateName(_ name: String?) throws {
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName("Track name cannot be empty")
        }

        guard name.count <= 30 else {
            throw ValidationError.invalidName("Track name cannot exceed 30 characters")
        }
    }

    private func validateVolume(_ volume: NSNumber?) throws {
        guard let volume = volume?.floatValue else {
            throw ValidationError.invalidValue("Track volume must be specified")
        }

        guard volume >= 0.0 && volume <= 1.0 else {
            throw ValidationError.invalidValue("Track volume must be between 0.0 and 1.0")
        }
    }

    private func validatePan(_ pan: NSNumber?) throws {
        guard let pan = pan?.floatValue else {
            throw ValidationError.invalidValue("Track pan must be specified")
        }

        guard pan >= -1.0 && pan <= 1.0 else {
            throw ValidationError.invalidValue("Track pan must be between -1.0 and 1.0")
        }
    }

    private func validateTrackIndex(_ trackIndex: NSNumber?) throws {
        guard let trackIndex = trackIndex?.int16Value else {
            throw ValidationError.invalidValue("Track index must be specified")
        }

        guard trackIndex >= 0 && trackIndex <= 15 else {
            throw ValidationError.invalidValue("Track index must be between 0 and 15")
        }
    }

    // MARK: - Convenience Methods

    /// Creates a new trig for this track
    /// - Parameters:
    ///   - step: The step position (0-127)
    ///   - note: The MIDI note number (0-127)
    ///   - velocity: The velocity (1-127)
    /// - Returns: The newly created trig
    public func createTrig(step: Int16, note: Int16 = 60, velocity: Int16 = 100) -> Trig {
        let trig = Trig(context: managedObjectContext!)
        trig.step = step
        trig.note = note
        trig.velocity = velocity
        trig.track = self
        trig.pattern = self.pattern
        trig.isActive = true
        return trig
    }

    /// Gets all trigs sorted by step
    /// - Returns: Array of trigs sorted by step position
    public func sortedTrigs() -> [Trig] {
        guard let trigs = trigs as? Set<Trig> else { return [] }
        return trigs.sorted { $0.step < $1.step }
    }

    /// Gets active trigs only
    /// - Returns: Array of active trigs
    public func activeTrigs() -> [Trig] {
        return sortedTrigs().filter { $0.isActive }
    }

    /// Checks if track has any active trigs
    /// - Returns: True if track has active trigs
    public func hasActiveTrigs() -> Bool {
        guard let trigs = trigs as? Set<Trig> else { return false }
        return trigs.contains { $0.isActive }
    }
}