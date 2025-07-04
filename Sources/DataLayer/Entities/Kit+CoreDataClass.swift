import Foundation
import CoreData
import DataModel

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
        if soundFiles == nil {
            soundFiles = []
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
        default:
            break
        }
    }

    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateSoundFiles()
    }

    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateSoundFiles()
    }

    private func validateName(_ name: String?) throws {
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName("Kit name cannot be empty")
        }

        guard name.count <= 50 else {
            throw ValidationError.invalidName("Kit name cannot exceed 50 characters")
        }
    }



    private func validateSoundFiles() throws {
        if let soundFileArray = soundFiles {
            for (index, filePath) in soundFileArray.enumerated() {
                guard !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw ValidationError.invalidValue("Sound file path at index \(index) cannot be empty")
                }

                guard filePath.count <= 500 else {
                    throw ValidationError.invalidValue("Sound file path at index \(index) is too long (max 500 characters)")
                }

                // Validate file extension
                let validExtensions = ["wav", "aiff", "aif", "m4a", "mp3", "flac"]
                let fileExtension = (filePath as NSString).pathExtension.lowercased()
                guard validExtensions.contains(fileExtension) else {
                    throw ValidationError.invalidValue("Invalid sound file extension '\(fileExtension)' at index \(index). Valid extensions: \(validExtensions.joined(separator: ", "))")
                }
            }

            // Validate kit has reasonable number of sound files (max 16 for 16 tracks)
            guard soundFileArray.count <= 16 else {
                throw ValidationError.invalidValue("Kit cannot have more than 16 sound files")
            }
        }
    }

    // MARK: - Sound File Management

    /// Sets sound files for the kit
    /// - Parameter filePaths: Array of file paths
    public func setSoundFiles(_ filePaths: [String]) throws {
        // Validate each file path before setting
        for (index, filePath) in filePaths.enumerated() {
            guard !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError.invalidValue("Sound file path at index \(index) cannot be empty")
            }
            
            guard filePath.count <= 500 else {
                throw ValidationError.invalidValue("Sound file path at index \(index) is too long")
            }
        }
        
        soundFiles = filePaths
    }

    /// Gets sound file paths
    /// - Returns: Array of sound file paths
    public func getSoundFiles() -> [String] {
        return soundFiles ?? []
    }

    /// Adds a sound file to the kit
    /// - Parameter filePath: The file path to add
    public func addSoundFile(_ filePath: String) throws {
        var currentFiles = getSoundFiles()
        
        guard currentFiles.count < 16 else {
            throw ValidationError.invalidValue("Cannot add more than 16 sound files to a kit")
        }
        
        currentFiles.append(filePath)
        try setSoundFiles(currentFiles)
    }

    /// Removes a sound file from the kit
    /// - Parameter index: The index of the file to remove
    public func removeSoundFile(at index: Int) throws {
        var currentFiles = getSoundFiles()
        
        guard index >= 0 && index < currentFiles.count else {
            throw ValidationError.invalidValue("Invalid sound file index: \(index)")
        }
        
        currentFiles.remove(at: index)
        try setSoundFiles(currentFiles)
    }

    // MARK: - Convenience Methods

    /// Gets the total number of sound files in this kit
    /// - Returns: Number of sound files
    public func soundFileCount() -> Int {
        return getSoundFiles().count
    }

    /// Checks if the kit has any sound files
    /// - Returns: True if kit has sound files
    public func hasSoundFiles() -> Bool {
        return soundFileCount() > 0
    }

    /// Creates a copy of this kit with a new name
    /// - Parameter newName: Name for the copied kit
    /// - Returns: The newly created kit copy
    public func copy(withName newName: String) -> Kit {
        let kitCopy = Kit(context: managedObjectContext!)
        kitCopy.name = newName
        kitCopy.soundFiles = self.soundFiles
        return kitCopy
    }

    /// Gets all tracks associated with this kit
    /// - Returns: Array of tracks using this kit
    public func associatedTracks() -> [Track] {
        guard let tracks = tracks as? Set<Track> else { return [] }
        return Array(tracks).sorted { $0.trackIndex < $1.trackIndex }
    }
}