import Foundation
import CoreData

@objc(Trig)
public class Trig: NSManagedObject {

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()

        // Set default values
        let now = Date()
        createdAt = now
        updatedAt = now

        // Set default values
        if step == 0 {
            step = 0 // Default to first step
        }
        if note == 0 {
            note = 60 // Default to middle C
        }
        if velocity == 0 {
            velocity = 100 // Default velocity
        }
        if duration == 0 {
            duration = 1.0 // Default duration (1 step)
        }
        if probability == 0 {
            probability = 100 // Default 100% probability
        }
        microTiming = 0.0 // No micro timing by default
        retrigCount = 0 // No retrigs by default
        retrigRate = 0.25 // Default retrig rate
        isActive = false // Inactive by default
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
        case "step":
            try validateStep(value.pointee as? NSNumber)
        case "note":
            try validateNote(value.pointee as? NSNumber)
        case "velocity":
            try validateVelocity(value.pointee as? NSNumber)
        case "duration":
            try validateDuration(value.pointee as? NSNumber)
        case "probability":
            try validateProbability(value.pointee as? NSNumber)
        case "microTiming":
            try validateMicroTiming(value.pointee as? NSNumber)
        case "retrigCount":
            try validateRetrigCount(value.pointee as? NSNumber)
        default:
            break
        }
    }

    private func validateStep(_ step: NSNumber?) throws {
        guard let step = step?.int16Value else {
            throw ValidationError.invalidValue("Trig step must be specified")
        }

        guard step >= 0 && step <= 127 else {
            throw ValidationError.invalidValue("Trig step must be between 0 and 127")
        }
    }

    private func validateNote(_ note: NSNumber?) throws {
        guard let note = note?.int16Value else {
            throw ValidationError.invalidValue("Trig note must be specified")
        }

        guard note >= 0 && note <= 127 else {
            throw ValidationError.invalidValue("Trig note must be between 0 and 127 (MIDI range)")
        }
    }

    private func validateVelocity(_ velocity: NSNumber?) throws {
        guard let velocity = velocity?.int16Value else {
            throw ValidationError.invalidValue("Trig velocity must be specified")
        }

        guard velocity >= 1 && velocity <= 127 else {
            throw ValidationError.invalidValue("Trig velocity must be between 1 and 127")
        }
    }

    private func validateDuration(_ duration: NSNumber?) throws {
        guard let duration = duration?.floatValue else {
            throw ValidationError.invalidValue("Trig duration must be specified")
        }

        guard duration >= 0.1 && duration <= 16.0 else {
            throw ValidationError.invalidValue("Trig duration must be between 0.1 and 16.0 steps")
        }
    }

    private func validateProbability(_ probability: NSNumber?) throws {
        guard let probability = probability?.int16Value else {
            throw ValidationError.invalidValue("Trig probability must be specified")
        }

        guard probability >= 0 && probability <= 100 else {
            throw ValidationError.invalidValue("Trig probability must be between 0 and 100 percent")
        }
    }

    private func validateMicroTiming(_ microTiming: NSNumber?) throws {
        guard let microTiming = microTiming?.floatValue else {
            throw ValidationError.invalidValue("Trig micro timing must be specified")
        }

        guard microTiming >= -50.0 && microTiming <= 50.0 else {
            throw ValidationError.invalidValue("Trig micro timing must be between -50.0 and 50.0 milliseconds")
        }
    }

    private func validateRetrigCount(_ retrigCount: NSNumber?) throws {
        guard let retrigCount = retrigCount?.int16Value else {
            throw ValidationError.invalidValue("Trig retrig count must be specified")
        }

        guard retrigCount >= 0 && retrigCount <= 8 else {
            throw ValidationError.invalidValue("Trig retrig count must be between 0 and 8")
        }
    }

    // MARK: - Convenience Methods

    /// Toggles the active state of this trig
    public func toggle() {
        isActive.toggle()
    }

    /// Sets parameter lock data for a specific parameter
    /// - Parameters:
    ///   - parameter: The parameter name
    ///   - value: The parameter value
    public func setParameterLock(parameter: String, value: Any) {
        var locks: [String: Any] = [:]

        // Decode existing pLocks if any
        if let pLocksData = pLocks {
            do {
                if let existingLocks = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSDictionary.self, from: pLocksData) as? [String: Any] {
                    locks = existingLocks
                }
            } catch {
                print("Failed to decode existing pLocks: \(error)")
            }
        }

        // Set new parameter lock
        locks[parameter] = value

        // Encode and save
        do {
            pLocks = try NSKeyedArchiver.archivedData(withRootObject: locks, requiringSecureCoding: false)
        } catch {
            print("Failed to encode pLocks: \(error)")
        }
    }

    /// Gets parameter lock value for a specific parameter
    /// - Parameter parameter: The parameter name
    /// - Returns: The parameter value if it exists
    public func getParameterLock(parameter: String) -> Any? {
        guard let pLocksData = pLocks else { return nil }

        do {
            if let locks = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSDictionary.self, from: pLocksData) as? [String: Any] {
                return locks[parameter]
            }
        } catch {
            print("Failed to decode pLocks: \(error)")
        }

        return nil
    }

    /// Removes a parameter lock
    /// - Parameter parameter: The parameter name to remove
    public func removeParameterLock(parameter: String) {
        guard let pLocksData = pLocks else { return }

        do {
            if var locks = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSDictionary.self, from: pLocksData) as? [String: Any] {
                locks.removeValue(forKey: parameter)

                if locks.isEmpty {
                    pLocks = nil
                } else {
                    pLocks = try NSKeyedArchiver.archivedData(withRootObject: locks, requiringSecureCoding: false)
                }
            }
        } catch {
            print("Failed to update pLocks: \(error)")
        }
    }
}