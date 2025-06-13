import Foundation
import CoreData

@objc(Kit)
public class Kit: NSManagedObject {

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()

        // Set default values
        let now = Date()
        createdAt = now
        updatedAt = now

        // Set default values
        if name == nil || name?.isEmpty == true {
            name = "New Kit"
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
        case "soundFiles":
            try validateSoundFiles(value.pointee)
        default:
            break
        }
    }

    private func validateName(_ name: String?) throws {
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName("Kit name cannot be empty")
        }

        guard name.count <= 50 else {
            throw ValidationError.invalidName("Kit name cannot exceed 50 characters")
        }
    }

    private func validateSoundFiles(_ soundFiles: Any?) throws {
        if let soundFiles = soundFiles as? [String] {
            // Validate each sound file path
            for filePath in soundFiles {
                guard !filePath.isEmpty else {
                    throw ValidationError.invalidValue("Sound file path cannot be empty")
                }

                // Basic path validation
                guard filePath.count <= 500 else {
                    throw ValidationError.invalidValue("Sound file path too long")
                }
            }
        }
    }

    // MARK: - Convenience Methods

    /// Gets the sound files as a string array
    /// - Returns: Array of sound file paths
    public func getSoundFiles() -> [String] {
        return soundFiles ?? []
    }

    /// Sets the sound files array
    /// - Parameter files: Array of sound file paths
    public func setSoundFiles(_ files: [String]) {
        soundFiles = files
    }

    /// Adds a sound file to the kit
    /// - Parameter filePath: The path to the sound file
    public func addSoundFile(_ filePath: String) {
        var files = getSoundFiles()
        if !files.contains(filePath) {
            files.append(filePath)
            setSoundFiles(files)
        }
    }

    /// Removes a sound file from the kit
    /// - Parameter filePath: The path to the sound file to remove
    public func removeSoundFile(_ filePath: String) {
        var files = getSoundFiles()
        files.removeAll { $0 == filePath }
        setSoundFiles(files)
    }

    /// Gets all tracks associated with this kit
    /// - Returns: Array of tracks using this kit
    public func associatedTracks() -> [Track] {
        guard let tracks = tracks as? Set<Track> else { return [] }
        return Array(tracks).sorted { $0.trackIndex < $1.trackIndex }
    }
}