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
        if kitType == nil || kitType?.isEmpty == true {
            kitType = "standard"
        }
        masterVolume = 0.8 // Default master volume
        masterTune = 0.0 // No master tuning offset
        compressorEnabled = false
        reverbEnabled = false
        delayEnabled = false
        distortionEnabled = false
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
        case "kitType":
            try validateKitType(value.pointee as? String)
        case "description":
            try validateDescription(value.pointee as? String)
        case "masterVolume":
            try validateMasterVolume(value.pointee as? NSNumber)
        case "masterTune":
            try validateMasterTune(value.pointee as? NSNumber)
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

    private func validateKitType(_ kitType: String?) throws {
        guard let kitType = kitType, !kitType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidValue("Kit type cannot be empty")
        }

        let validKitTypes = ["standard", "drum", "percussion", "melodic", "bass", "lead", "pad", "fx"]
        guard validKitTypes.contains(kitType.lowercased()) else {
            throw ValidationError.invalidValue("Invalid kit type: \(kitType). Valid types: \(validKitTypes.joined(separator: ", "))")
        }
    }

    private func validateDescription(_ description: String?) throws {
        if let description = description {
            guard description.count <= 500 else {
                throw ValidationError.invalidValue("Kit description cannot exceed 500 characters")
            }
        }
    }

    private func validateMasterVolume(_ masterVolume: NSNumber?) throws {
        guard let masterVolume = masterVolume?.floatValue else {
            throw ValidationError.invalidValue("Kit master volume must be specified")
        }

        guard masterVolume >= 0.0 && masterVolume <= 1.0 else {
            throw ValidationError.invalidValue("Kit master volume must be between 0.0 and 1.0")
        }
    }

    private func validateMasterTune(_ masterTune: NSNumber?) throws {
        guard let masterTune = masterTune?.floatValue else {
            throw ValidationError.invalidValue("Kit master tune must be specified")
        }

        guard masterTune >= -12.0 && masterTune <= 12.0 else {
            throw ValidationError.invalidValue("Kit master tune must be between -12.0 and 12.0 semitones")
        }
    }

    private func validateSoundFiles() throws {
        if let soundFilesData = soundFiles {
            do {
                if let soundFileArray = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: soundFilesData) as? [String] {
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
            } catch let error as ValidationError {
                throw error
            } catch {
                throw ValidationError.invalidValue("Failed to decode sound files data: \(error.localizedDescription)")
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
        
        do {
            soundFiles = try NSKeyedArchiver.archivedData(withRootObject: filePaths, requiringSecureCoding: false)
        } catch {
            throw ValidationError.invalidValue("Failed to encode sound files: \(error.localizedDescription)")
        }
    }

    /// Gets sound file paths
    /// - Returns: Array of sound file paths
    public func getSoundFiles() -> [String] {
        guard let soundFilesData = soundFiles else { return [] }
        
        do {
            if let soundFileArray = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: soundFilesData) as? [String] {
                return soundFileArray
            }
        } catch {
            print("Failed to decode sound files: \(error)")
        }
        
        return []
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
        kitCopy.kitType = self.kitType
        kitCopy.description = self.description
        kitCopy.masterVolume = self.masterVolume
        kitCopy.masterTune = self.masterTune
        kitCopy.compressorEnabled = self.compressorEnabled
        kitCopy.reverbEnabled = self.reverbEnabled
        kitCopy.delayEnabled = self.delayEnabled
        kitCopy.distortionEnabled = self.distortionEnabled
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