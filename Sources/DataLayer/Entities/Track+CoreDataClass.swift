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
            name = "New Track"
        }
        if trackIndex == 0 {
            trackIndex = 0
        }
        if volume == 0 {
            volume = 0.8 // Default volume
        }
        pan = 0.0 // Center pan
        pitch = 0.0 // No pitch offset
        length = 16 // Default length
        isMuted = false
        isSoloed = false
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
        case "trackIndex":
            try validateTrackIndex(value.pointee as? NSNumber)
        case "volume":
            try validateVolume(value.pointee as? NSNumber)
        case "pan":
            try validatePan(value.pointee as? NSNumber)
        case "pitch":
            try validatePitch(value.pointee as? NSNumber)
        case "length":
            try validateLength(value.pointee as? NSNumber)
        case "send1Level":
            try validateSendLevel(value.pointee as? NSNumber, sendName: "Send 1")
        case "send2Level":
            try validateSendLevel(value.pointee as? NSNumber, sendName: "Send 2")
        case "microTiming":
            try validateMicroTiming(value.pointee as? NSNumber)
        case "chance":
            try validateChance(value.pointee as? NSNumber)
        case "retrigCount":
            try validateRetrigCount(value.pointee as? NSNumber)
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
            throw ValidationError.invalidName("Track name cannot be empty")
        }

        guard name.count <= 30 else {
            throw ValidationError.invalidName("Track name cannot exceed 30 characters")
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
            throw ValidationError.invalidValue("Track pan must be between -1.0 (left) and 1.0 (right)")
        }
    }

    private func validatePitch(_ pitch: NSNumber?) throws {
        guard let pitch = pitch?.floatValue else {
            throw ValidationError.invalidValue("Track pitch must be specified")
        }

        guard pitch >= -24.0 && pitch <= 24.0 else {
            throw ValidationError.invalidValue("Track pitch must be between -24.0 and 24.0 semitones")
        }
    }

    private func validateLength(_ length: NSNumber?) throws {
        guard let length = length?.int16Value else {
            throw ValidationError.invalidValue("Track length must be specified")
        }

        guard length >= 1 && length <= 128 else {
            throw ValidationError.invalidValue("Track length must be between 1 and 128 steps")
        }
    }

    private func validateSendLevel(_ sendLevel: NSNumber?, sendName: String) throws {
        guard let sendLevel = sendLevel?.floatValue else {
            throw ValidationError.invalidValue("\(sendName) level must be specified")
        }

        guard sendLevel >= 0.0 && sendLevel <= 1.0 else {
            throw ValidationError.invalidValue("\(sendName) level must be between 0.0 and 1.0")
        }
    }

    private func validateMicroTiming(_ microTiming: NSNumber?) throws {
        guard let microTiming = microTiming?.floatValue else {
            throw ValidationError.invalidValue("Track micro timing must be specified")
        }

        guard microTiming >= -50.0 && microTiming <= 50.0 else {
            throw ValidationError.invalidValue("Track micro timing must be between -50.0 and 50.0 milliseconds")
        }
    }

    private func validateChance(_ chance: NSNumber?) throws {
        guard let chance = chance?.int16Value else {
            throw ValidationError.invalidValue("Track chance must be specified")
        }

        guard chance >= 0 && chance <= 100 else {
            throw ValidationError.invalidValue("Track chance must be between 0 and 100 percent")
        }
    }

    private func validateRetrigCount(_ retrigCount: NSNumber?) throws {
        guard let retrigCount = retrigCount?.int16Value else {
            throw ValidationError.invalidValue("Track retrig count must be specified")
        }

        guard retrigCount >= 0 && retrigCount <= 8 else {
            throw ValidationError.invalidValue("Track retrig count must be between 0 and 8")
        }
    }

    private func validateRelationships() throws {
        guard pattern != nil else {
            throw ValidationError.relationshipConstraint("Track must belong to a pattern")
        }

        // Validate track index uniqueness within pattern
        if let pattern = pattern, let tracks = pattern.tracks as? Set<Track> {
            let tracksWithSameIndex = tracks.filter { $0.trackIndex == self.trackIndex && $0 != self }
            if !tracksWithSameIndex.isEmpty {
                throw ValidationError.relationshipConstraint("Track index \(trackIndex) is already used in this pattern")
            }
        }
    }

    // MARK: - Convenience Methods

    /// Creates a new trig for this track
    /// - Parameters:
    ///   - step: The step position (0-127)
    ///   - note: The MIDI note (0-127)
    ///   - velocity: The velocity (1-127)
    /// - Returns: The newly created trig
    public func createTrig(step: Int16, note: Int16 = 60, velocity: Int16 = 100) -> Trig {
        let trig = Trig(context: managedObjectContext!)
        trig.step = step
        trig.note = note
        trig.velocity = velocity
        trig.track = self
        trig.pattern = self.pattern
        return trig
    }

    /// Gets all trigs sorted by step
    /// - Returns: Array of trigs sorted by step position
    public func sortedTrigs() -> [Trig] {
        guard let trigs = trigs as? Set<Trig> else { return [] }
        return trigs.sorted { $0.step < $1.step }
    }

    /// Gets trig at specific step
    /// - Parameter step: The step position
    /// - Returns: Trig at the step, if any
    public func trigAt(step: Int16) -> Trig? {
        guard let trigs = trigs as? Set<Trig> else { return nil }
        return trigs.first { $0.step == step }
    }

    /// Toggles mute state
    public func toggleMute() {
        isMuted.toggle()
    }

    /// Toggles solo state
    public func toggleSolo() {
        isSoloed.toggle()
    }
}