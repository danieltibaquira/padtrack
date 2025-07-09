import Foundation
import CoreData
import DataModel

/// Manages the "+Drive" emulation system for storing multiple projects and presets
public class PlusDriveManager {
    
    // MARK: - Properties
    
    private let context: NSManagedObjectContext
    private let fileManager: ProjectFileManager
    private let backupManager: BackupManager
    private var storageQuotaMB: Int = 1000 // Default 1GB
    private var isAutomaticBackupEnabled: Bool = true
    private var backupRetentionDays: Int = 30
    private var maxBackupsPerProject: Int = 10
    
    // MARK: - Initialization
    
    public init(context: NSManagedObjectContext) {
        self.context = context
        self.fileManager = ProjectFileManager(context: context)
        self.backupManager = BackupManager(context: context)
    }
    
    // MARK: - Project Management
    
    /// Creates a new project
    public func createProject(name: String) throws -> Project {
        // Check storage quota
        let currentUsage = try getUsedStorage()
        let estimatedProjectSize = 1_000_000 // 1MB estimated
        
        if currentUsage + estimatedProjectSize > storageQuotaMB * 1024 * 1024 {
            throw PlusDriveError.storageQuotaExceeded
        }
        
        let project = NSEntityDescription.insertNewObject(forEntityName: "Project", into: context) as! Project
        project.name = name
        project.createdAt = Date()
        project.updatedAt = Date()
        project.bpm = 120.0
        
        // Create default pattern
        let pattern = NSEntityDescription.insertNewObject(forEntityName: "Pattern", into: context) as! Pattern
        pattern.name = "Pattern 1"
        pattern.length = 64
        pattern.project = project
        
        // Create default kit
        let kit = NSEntityDescription.insertNewObject(forEntityName: "Kit", into: context) as! Kit
        kit.name = "Kit 1"
        kit.pattern = pattern
        
        try context.save()
        
        // Create automatic backup if enabled
        if isAutomaticBackupEnabled {
            _ = try backupManager.createBackup(for: project)
        }
        
        return project
    }
    
    /// Lists all projects in the +Drive
    public func listProjects() throws -> [Project] {
        let fetchRequest = NSFetchRequest<Project>(entityName: "Project")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        return try context.fetch(fetchRequest)
    }
    
    /// Loads a specific project
    public func loadProject(id: NSManagedObjectID) throws -> Project {
        guard let project = try context.existingObject(with: id) as? Project else {
            throw PlusDriveError.projectNotFound
        }
        return project
    }
    
    /// Saves a project
    public func saveProject(_ project: Project) throws {
        project.updatedAt = Date()
        
        try context.save()
        
        // Create automatic backup if enabled
        if isAutomaticBackupEnabled {
            _ = try backupManager.createBackup(for: project)
        }
    }
    
    // MARK: - Export/Import
    
    /// Exports a project to data
    public func exportProject(_ project: Project) throws -> Data {
        return try fileManager.exportProject(project, format: .current)
    }
    
    /// Imports a project from data
    public func importProject(from data: Data) throws -> Project {
        return try fileManager.importProject(data)
    }
    
    // MARK: - Versioning
    
    /// Saves a version of the project
    public func saveProjectVersion(_ project: Project) throws -> ProjectVersion {
        let version = ProjectVersion(project: project, context: context)
        version.versionNumber = try getNextVersionNumber(for: project)
        version.createdAt = Date()
        version.projectData = try exportProject(project)
        
        try context.save()
        
        // Clean up old versions if needed
        try cleanupOldVersions(for: project)
        
        return version
    }
    
    /// Gets all versions for a project
    public func getProjectVersions(projectId: NSManagedObjectID) throws -> [ProjectVersion] {
        let project = try loadProject(id: projectId)
        return backupManager.getVersions(for: project)
    }
    
    /// Restores a project from a specific version
    public func restoreProjectVersion(_ version: ProjectVersion) throws -> Project {
        guard let data = version.projectData else {
            throw PlusDriveError.versionNotFound
        }
        
        return try importProject(from: data)
    }
    
    // MARK: - Storage Management
    
    /// Sets the storage quota in megabytes
    public func setStorageQuota(megabytes: Int) {
        storageQuotaMB = megabytes
    }
    
    /// Gets the used storage in bytes
    public func getUsedStorage() throws -> Int64 {
        var totalSize: Int64 = 0
        
        // Calculate size of all projects
        let projects = try listProjects()
        for project in projects {
            let projectData = try exportProject(project)
            totalSize += Int64(projectData.count)
        }
        
        // Add backup sizes
        totalSize += try backupManager.getTotalBackupSize()
        
        return totalSize
    }
    
    // MARK: - Backup Management
    
    /// Enables or disables automatic backup
    public func enableAutomaticBackup(_ enabled: Bool) {
        isAutomaticBackupEnabled = enabled
    }
    
    /// Sets backup retention in days
    public func setBackupRetentionDays(_ days: Int) {
        backupRetentionDays = days
    }
    
    /// Sets maximum backups per project
    public func setMaxBackupsPerProject(_ count: Int) {
        maxBackupsPerProject = count
    }
    
    /// Lists backups for a project
    public func listBackups(for projectId: NSManagedObjectID) throws -> [ProjectBackup] {
        let project = try loadProject(id: projectId)
        return backupManager.listBackups(for: project)
    }
    
    /// Restores from the latest backup
    public func restoreFromLatestBackup(projectId: NSManagedObjectID) throws -> Project {
        let project = try loadProject(id: projectId)
        guard let latestBackup = backupManager.getLatestBackup(for: project),
              let backupData = latestBackup.projectData else {
            throw PlusDriveError.backupNotFound
        }
        
        return try importProject(from: backupData)
    }
    
    // MARK: - Recovery
    
    /// Attempts to recover data from corrupted file
    public func attemptRecovery(from data: Data) -> Result<Project, Error> {
        return fileManager.attemptRecovery(from: data)
    }
    
    // MARK: - Private Methods
    
    private func getNextVersionNumber(for project: Project) throws -> Int {
        let versions = backupManager.getVersions(for: project)
        let maxVersion = versions.map { $0.versionNumber }.max() ?? 0
        return maxVersion + 1
    }
    
    private func cleanupOldVersions(for project: Project) throws {
        let versions = backupManager.getVersions(for: project).sorted { $0.createdAt! > $1.createdAt! }
        
        // Remove versions beyond the limit
        if versions.count > maxBackupsPerProject {
            let versionsToDelete = versions.suffix(from: maxBackupsPerProject)
            for version in versionsToDelete {
                context.delete(version)
            }
        }
        
        // Remove versions older than retention period
        let cutoffDate = Date().addingTimeInterval(-Double(backupRetentionDays) * 24 * 60 * 60)
        for version in versions {
            if let createdAt = version.createdAt, createdAt < cutoffDate {
                context.delete(version)
            }
        }
        
        try context.save()
    }
}

// MARK: - Supporting Classes

/// Manages project file operations
class ProjectFileManager {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func exportProject(_ project: Project, format: ProjectFileFormat = .current, compressed: Bool = false) throws -> Data {
        // Create export structure
        var exportData: [String: Any] = [
            "version": format.version,
            "identifier": "DigitonePad",
            "exportDate": Date(),
            "project": try encodeProject(project)
        ]
        
        // Add metadata if available
        if let metadata = project.metadata {
            exportData["metadata"] = metadata
        }
        
        // Convert to data
        var data = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        
        // Compress if requested
        if compressed {
            data = try compress(data)
        }
        
        return data
    }
    
    func importProject(_ data: Data, format: ProjectFileFormat = .current) throws -> Project {
        // Decompress if needed
        let jsonData = isCompressed(data) ? try decompress(data) : data
        
        // Parse JSON
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw ProjectFileError.corruptedFile
        }
        
        // Verify version
        guard let version = json["version"] as? Int else {
            throw ProjectFileError.missingRequiredData
        }
        
        if version > format.version {
            throw ProjectFileError.unsupportedVersion
        }
        
        // Decode project
        guard let projectData = json["project"] as? [String: Any] else {
            throw ProjectFileError.missingRequiredData
        }
        
        let project = try decodeProject(from: projectData)
        
        // Apply metadata if available
        if let metadata = json["metadata"] as? [String: Any] {
            project.metadata = metadata
        }
        
        return project
    }
    
    func getFormatInfo(from data: Data) throws -> (version: Int, identifier: String) {
        let jsonData = isCompressed(data) ? try decompress(data) : data
        
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let version = json["version"] as? Int,
              let identifier = json["identifier"] as? String else {
            throw ProjectFileError.corruptedFile
        }
        
        return (version, identifier)
    }
    
    func attemptRecovery(from data: Data) -> Result<Project, Error> {
        do {
            // Try normal import first
            let project = try importProject(data)
            return .success(project)
        } catch {
            // Attempt partial recovery
            if let partialProject = tryPartialRecovery(from: data) {
                return .success(partialProject)
            }
            return .failure(error)
        }
    }
    
    private func encodeProject(_ project: Project) throws -> [String: Any] {
        var encoded: [String: Any] = [
            "name": project.name ?? "Untitled",
            "bpm": project.bpm,
            "createdAt": project.createdAt ?? Date(),
            "updatedAt": project.updatedAt ?? Date()
        ]
        
        // Encode patterns
        if let patterns = project.patterns?.allObjects as? [Pattern] {
            encoded["patterns"] = try patterns.map { try encodePattern($0) }
        }
        
        // Encode preset pool
        if let presets = project.presets?.allObjects as? [Preset] {
            encoded["presetPool"] = try presets.map { try encodePreset($0) }
        }
        
        return encoded
    }
    
    private func encodePattern(_ pattern: Pattern) throws -> [String: Any] {
        var encoded: [String: Any] = [
            "name": pattern.name ?? "Untitled",
            "length": pattern.length
        ]
        
        // Encode kit
        if let kit = pattern.kit {
            encoded["kit"] = try encodeKit(kit)
        }
        
        // Encode tracks
        if let tracks = pattern.tracks?.allObjects as? [Track] {
            encoded["tracks"] = try tracks.map { try encodeTrack($0) }
        }
        
        return encoded
    }
    
    private func encodeKit(_ kit: Kit) throws -> [String: Any] {
        return [
            "name": kit.name ?? "Untitled"
        ]
    }
    
    private func encodeTrack(_ track: Track) throws -> [String: Any] {
        var encoded: [String: Any] = [
            "number": track.number,
            "isMuted": track.isMuted,
            "volume": track.volume
        ]
        
        // Encode trigs
        if let trigs = track.trigs?.allObjects as? [Trig] {
            encoded["trigs"] = try trigs.map { try encodeTrig($0) }
        }
        
        return encoded
    }
    
    private func encodeTrig(_ trig: Trig) throws -> [String: Any] {
        var encoded: [String: Any] = [
            "step": trig.step,
            "velocity": trig.velocity
        ]
        
        if let parameterLocks = trig.parameterLocks {
            encoded["parameterLocks"] = parameterLocks
        }
        
        return encoded
    }
    
    private func encodePreset(_ preset: Preset) throws -> [String: Any] {
        var encoded: [String: Any] = [
            "name": preset.name ?? "Untitled",
            "machine": preset.machine ?? "fmTone",
            "category": preset.category ?? "Uncategorized"
        ]
        
        if let tags = preset.tags {
            encoded["tags"] = tags
        }
        
        if let parameterData = preset.parameterData {
            encoded["parameterData"] = parameterData.base64EncodedString()
        }
        
        return encoded
    }
    
    private func decodeProject(from data: [String: Any]) throws -> Project {
        let project = NSEntityDescription.insertNewObject(forEntityName: "Project", into: context) as! Project
        
        project.name = data["name"] as? String ?? "Untitled"
        project.bpm = data["bpm"] as? Double ?? 120.0
        project.createdAt = data["createdAt"] as? Date ?? Date()
        project.updatedAt = data["updatedAt"] as? Date ?? Date()
        
        // Decode patterns
        if let patternsData = data["patterns"] as? [[String: Any]] {
            for patternData in patternsData {
                let pattern = try decodePattern(from: patternData)
                pattern.project = project
            }
        }
        
        // Decode preset pool
        if let presetsData = data["presetPool"] as? [[String: Any]] {
            for presetData in presetsData {
                let preset = try decodePreset(from: presetData)
                preset.project = project
            }
        }
        
        return project
    }
    
    private func decodePattern(from data: [String: Any]) throws -> Pattern {
        let pattern = NSEntityDescription.insertNewObject(forEntityName: "Pattern", into: context) as! Pattern
        
        pattern.name = data["name"] as? String ?? "Untitled"
        pattern.length = data["length"] as? Int16 ?? 64
        
        // Decode kit
        if let kitData = data["kit"] as? [String: Any] {
            let kit = try decodeKit(from: kitData)
            kit.pattern = pattern
        }
        
        // Decode tracks
        if let tracksData = data["tracks"] as? [[String: Any]] {
            for trackData in tracksData {
                let track = try decodeTrack(from: trackData)
                track.pattern = pattern
            }
        }
        
        return pattern
    }
    
    private func decodeKit(from data: [String: Any]) throws -> Kit {
        let kit = NSEntityDescription.insertNewObject(forEntityName: "Kit", into: context) as! Kit
        kit.name = data["name"] as? String ?? "Untitled"
        return kit
    }
    
    private func decodeTrack(from data: [String: Any]) throws -> Track {
        let track = NSEntityDescription.insertNewObject(forEntityName: "Track", into: context) as! Track
        
        track.number = data["number"] as? Int16 ?? 1
        track.isMuted = data["isMuted"] as? Bool ?? false
        track.volume = data["volume"] as? Float ?? 1.0
        
        // Decode trigs
        if let trigsData = data["trigs"] as? [[String: Any]] {
            for trigData in trigsData {
                let trig = try decodeTrig(from: trigData)
                trig.track = track
            }
        }
        
        return track
    }
    
    private func decodeTrig(from data: [String: Any]) throws -> Trig {
        let trig = NSEntityDescription.insertNewObject(forEntityName: "Trig", into: context) as! Trig
        
        trig.step = data["step"] as? Int16 ?? 0
        trig.velocity = data["velocity"] as? Int16 ?? 100
        trig.parameterLocks = data["parameterLocks"] as? [String: Double]
        
        return trig
    }
    
    private func decodePreset(from data: [String: Any]) throws -> Preset {
        let preset = NSEntityDescription.insertNewObject(forEntityName: "Preset", into: context) as! Preset
        
        preset.name = data["name"] as? String ?? "Untitled"
        preset.machine = data["machine"] as? String ?? "fmTone"
        preset.category = data["category"] as? String ?? "Uncategorized"
        preset.tags = data["tags"] as? [String]
        
        if let parameterDataString = data["parameterData"] as? String,
           let parameterData = Data(base64Encoded: parameterDataString) {
            preset.parameterData = parameterData
        }
        
        return preset
    }
    
    private func isCompressed(_ data: Data) -> Bool {
        // Check for gzip magic number
        return data.count >= 2 && data[0] == 0x1f && data[1] == 0x8b
    }
    
    private func compress(_ data: Data) throws -> Data {
        return try (data as NSData).compressed(using: .zlib) as Data
    }
    
    private func decompress(_ data: Data) throws -> Data {
        return try (data as NSData).decompressed(using: .zlib) as Data
    }
    
    private func tryPartialRecovery(from data: Data) -> Project? {
        // Attempt to recover whatever we can from corrupted data
        // This is a simplified implementation
        return nil
    }
}

/// Manages project backups
class BackupManager {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func createBackup(for project: Project) throws -> ProjectBackup {
        let backup = ProjectBackup(project: project, context: context)
        backup.createdAt = Date()
        backup.projectData = try ProjectFileManager(context: context).exportProject(project)
        
        try context.save()
        return backup
    }
    
    func listBackups(for project: Project) -> [ProjectBackup] {
        // In a real implementation, this would fetch from Core Data
        return []
    }
    
    func getLatestBackup(for project: Project) -> ProjectBackup? {
        return listBackups(for: project).first
    }
    
    func getVersions(for project: Project) -> [ProjectVersion] {
        // In a real implementation, this would fetch from Core Data
        return []
    }
    
    func getTotalBackupSize() throws -> Int64 {
        // In a real implementation, this would calculate actual backup sizes
        return 0
    }
}

// MARK: - Supporting Types

/// Represents a project version
class ProjectVersion {
    var versionNumber: Int = 0
    var createdAt: Date?
    var projectData: Data?
    
    init(project: Project, context: NSManagedObjectContext) {
        // Initialize version
    }
}

/// Represents a project backup
class ProjectBackup {
    var createdAt: Date?
    var projectData: Data?
    
    init(project: Project, context: NSManagedObjectContext) {
        // Initialize backup
    }
}