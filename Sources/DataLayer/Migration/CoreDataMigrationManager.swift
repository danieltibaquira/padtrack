import CoreData
import Foundation

/// Manages Core Data model migrations and versioning
public class CoreDataMigrationManager {
    
    // MARK: - Properties
    
    private let modelName: String
    private let storeURL: URL
    
    // MARK: - Initialization
    
    public init(modelName: String, storeURL: URL) {
        self.modelName = modelName
        self.storeURL = storeURL
    }
    
    // MARK: - Migration Management
    
    /// Checks if migration is required for the persistent store
    /// - Returns: True if migration is needed, false otherwise
    public func requiresMigration() throws -> Bool {
        guard let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        ) else {
            // No existing store, no migration needed
            return false
        }
        
        guard let currentModel = currentModel() else {
            throw CoreDataError.persistentStoreError(
                NSError(domain: "CoreDataMigrationManager", 
                       code: 1001, 
                       userInfo: [NSLocalizedDescriptionKey: "Could not load current model"])
            )
        }
        
        return !currentModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
    }
    
    /// Performs migration if required
    /// - Throws: CoreDataError if migration fails
    public func migrateStoreIfNeeded() throws {
        guard try requiresMigration() else {
            print("✅ No migration required")
            return
        }
        
        print("🔄 Starting Core Data migration...")
        
        try performMigration()
        
        print("✅ Core Data migration completed successfully")
    }
    
    // MARK: - Private Migration Methods
    
    private func performMigration() throws {
        guard let sourceMetadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        ) else {
            throw CoreDataError.persistentStoreError(
                NSError(domain: "CoreDataMigrationManager", 
                       code: 1002, 
                       userInfo: [NSLocalizedDescriptionKey: "Could not load source metadata"])
            )
        }
        
        guard let sourceModel = compatibleModel(for: sourceMetadata) else {
            throw CoreDataError.persistentStoreError(
                NSError(domain: "CoreDataMigrationManager", 
                       code: 1003, 
                       userInfo: [NSLocalizedDescriptionKey: "Could not find compatible source model"])
            )
        }
        
        guard let destinationModel = currentModel() else {
            throw CoreDataError.persistentStoreError(
                NSError(domain: "CoreDataMigrationManager", 
                       code: 1004, 
                       userInfo: [NSLocalizedDescriptionKey: "Could not load destination model"])
            )
        }
        
        // Try lightweight migration first
        if try attemptLightweightMigration(from: sourceModel, to: destinationModel) {
            print("✅ Lightweight migration completed")
            return
        }
        
        // Fall back to progressive migration
        try performProgressiveMigration(from: sourceModel, to: destinationModel)
    }
    
    private func attemptLightweightMigration(from sourceModel: NSManagedObjectModel, 
                                           to destinationModel: NSManagedObjectModel) throws -> Bool {
        // Check if lightweight migration is possible
        guard let mappingModel = try? NSMappingModel.inferredMappingModel(
            forSourceModel: sourceModel,
            destinationModel: destinationModel
        ) else {
            return false
        }
        
        let migrationManager = NSMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
        
        let tempURL = storeURL.appendingPathExtension("temp")
        
        do {
            try migrationManager.migrateStore(
                from: storeURL,
                sourceType: NSSQLiteStoreType,
                options: nil,
                with: mappingModel,
                toDestinationURL: tempURL,
                destinationType: NSSQLiteStoreType,
                destinationOptions: nil
            )
            
            // Replace original store with migrated store
            try replaceStore(at: storeURL, with: tempURL)
            
            return true
        } catch {
            // Clean up temp file if migration failed
            try? FileManager.default.removeItem(at: tempURL)
            throw CoreDataError.persistentStoreError(error)
        }
    }
    
    private func performProgressiveMigration(from sourceModel: NSManagedObjectModel, 
                                           to destinationModel: NSManagedObjectModel) throws {
        // Get migration path from source to destination
        let migrationSteps = try migrationSteps(from: sourceModel, to: destinationModel)
        
        var currentStoreURL = storeURL
        
        for (index, step) in migrationSteps.enumerated() {
            print("🔄 Performing migration step \(index + 1)/\(migrationSteps.count)")
            
            let tempURL = storeURL.appendingPathExtension("temp_\(index)")
            
            let migrationManager = NSMigrationManager(
                sourceModel: step.sourceModel,
                destinationModel: step.destinationModel
            )
            
            do {
                try migrationManager.migrateStore(
                    from: currentStoreURL,
                    sourceType: NSSQLiteStoreType,
                    options: nil,
                    with: step.mappingModel,
                    toDestinationURL: tempURL,
                    destinationType: NSSQLiteStoreType,
                    destinationOptions: nil
                )
                
                // Clean up previous temp file if not the original
                if currentStoreURL != storeURL {
                    try? FileManager.default.removeItem(at: currentStoreURL)
                }
                
                currentStoreURL = tempURL
                
            } catch {
                // Clean up temp files
                try? FileManager.default.removeItem(at: tempURL)
                if currentStoreURL != storeURL {
                    try? FileManager.default.removeItem(at: currentStoreURL)
                }
                throw CoreDataError.persistentStoreError(error)
            }
        }
        
        // Replace original store with final migrated store
        try replaceStore(at: storeURL, with: currentStoreURL)
    }
    
    // MARK: - Model Management
    
    private func currentModel() -> NSManagedObjectModel? {
        return NSManagedObjectModel.mergedModel(from: [Bundle.module])
    }
    
    private func compatibleModel(for metadata: [String: Any]) -> NSManagedObjectModel? {
        return NSManagedObjectModel.mergedModel(from: [Bundle.module], 
                                              forStoreMetadata: metadata)
    }
    
    private func allModelVersions() -> [NSManagedObjectModel] {
        // In a real implementation, this would load all model versions
        // For now, return current model as baseline
        guard let currentModel = currentModel() else { return [] }
        return [currentModel]
    }
    
    // MARK: - Migration Path Calculation
    
    private struct MigrationStep {
        let sourceModel: NSManagedObjectModel
        let destinationModel: NSManagedObjectModel
        let mappingModel: NSMappingModel
    }
    
    private func migrationSteps(from sourceModel: NSManagedObjectModel, 
                               to destinationModel: NSManagedObjectModel) throws -> [MigrationStep] {
        // For now, attempt direct migration
        // In a full implementation, this would calculate the shortest path through model versions
        
        guard let mappingModel = try? NSMappingModel.inferredMappingModel(
            forSourceModel: sourceModel,
            destinationModel: destinationModel
        ) else {
            throw CoreDataError.persistentStoreError(
                NSError(domain: "CoreDataMigrationManager", 
                       code: 1005, 
                       userInfo: [NSLocalizedDescriptionKey: "Could not create mapping model"])
            )
        }
        
        return [MigrationStep(
            sourceModel: sourceModel,
            destinationModel: destinationModel,
            mappingModel: mappingModel
        )]
    }
    
    // MARK: - File Management
    
    private func replaceStore(at originalURL: URL, with newURL: URL) throws {
        let fileManager = FileManager.default
        
        // Create backup
        let backupURL = originalURL.appendingPathExtension("backup")
        
        do {
            // Remove existing backup if it exists
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            
            // Move original to backup
            try fileManager.moveItem(at: originalURL, to: backupURL)
            
            // Move new store to original location
            try fileManager.moveItem(at: newURL, to: originalURL)
            
            // Remove backup after successful migration
            try fileManager.removeItem(at: backupURL)
            
        } catch {
            // Attempt to restore from backup if replacement failed
            if fileManager.fileExists(atPath: backupURL.path) && 
               !fileManager.fileExists(atPath: originalURL.path) {
                try? fileManager.moveItem(at: backupURL, to: originalURL)
            }
            throw error
        }
    }
}

// MARK: - Migration Utilities

public extension CoreDataMigrationManager {
    
    /// Validates the integrity of the migrated data
    /// - Parameter context: The managed object context to validate
    /// - Returns: True if validation passes, false otherwise
    func validateMigratedData(in context: NSManagedObjectContext) -> Bool {
        do {
            // Perform basic validation by attempting to fetch from each entity
            let entityNames = ["Project", "Pattern", "Kit", "Track", "Trig", "Preset"]
            
            for entityName in entityNames {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
                fetchRequest.fetchLimit = 1
                _ = try context.fetch(fetchRequest)
            }
            
            return true
        } catch {
            print("❌ Data validation failed: \(error)")
            return false
        }
    }
    
    /// Creates a backup of the current store
    /// - Returns: URL of the backup file
    func createBackup() throws -> URL {
        let backupURL = storeURL.appendingPathExtension("backup_\(Date().timeIntervalSince1970)")
        try FileManager.default.copyItem(at: storeURL, to: backupURL)
        return backupURL
    }
    
    /// Restores from a backup file
    /// - Parameter backupURL: URL of the backup file to restore
    func restoreFromBackup(at backupURL: URL) throws {
        try replaceStore(at: storeURL, with: backupURL)
    }
} 