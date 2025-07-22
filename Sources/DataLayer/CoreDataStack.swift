import CoreData
import Foundation
import DataModel

/// Errors that can occur during Core Data operations
public enum CoreDataError: LocalizedError {
    case saveError(Error)
    case fetchError(Error)
    case contextMergeError(Error)
    case persistentStoreError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .saveError(let error):
            return "Failed to save Core Data context: \(error.localizedDescription)"
        case .fetchError(let error):
            return "Failed to fetch data from Core Data: \(error.localizedDescription)"
        case .contextMergeError(let error):
            return "Failed to merge Core Data contexts: \(error.localizedDescription)"
        case .persistentStoreError(let error):
            return "Failed to load persistent store: \(error.localizedDescription)"
        }
    }
}

/// Manages the Core Data stack for the DigitonePad application
///
/// The `PersistenceController` is responsible for setting up and managing the Core Data stack,
/// including the persistent container, contexts, and migration handling.
///
/// ## Features
///
/// - **Automatic Migration**: Handles lightweight and custom migrations automatically
/// - **Thread Safety**: Provides thread-safe context management
/// - **Background Operations**: Supports background context operations
/// - **Data Validation**: Validates data integrity after migrations
/// - **Backup Support**: Can create backups of the data store
/// - **Memory Management**: Optimized for memory usage and performance
///
/// ## Usage
///
/// ```swift
/// // Use the shared instance for production
/// let persistenceController = PersistenceController.shared
///
/// // Or create a custom instance
/// let controller = PersistenceController(inMemory: false)
///
/// // For testing, use in-memory store
/// let testController = PersistenceController(inMemory: true)
/// ```
///
/// ## Thread Safety
///
/// The PersistenceController is thread-safe and handles context merging automatically.
/// Use `performBackgroundTask(_:)` for heavy operations to avoid blocking the UI.
///
/// ## Migration
///
/// The controller automatically handles Core Data migrations when the app starts.
/// It supports both lightweight migrations and custom migration policies.
public final class PersistenceController: @unchecked Sendable {

    // MARK: - Singleton

    /// Shared instance for production use
    public static let shared = PersistenceController()

    /// Preview instance for SwiftUI previews and testing
    public static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // Add sample data for previews
        let sampleProject = DataModel.Project(context: context)
        sampleProject.name = "Sample Project"
        sampleProject.createdAt = Date()
        sampleProject.updatedAt = Date()
        
        do {
            try context.save()
        } catch {
            print("Failed to save preview data: \(error)")
        }
        
        return controller
    }()
    
    // MARK: - Properties
    
    /// The persistent container that manages the Core Data stack
    public let container: NSPersistentContainer
    
    /// Migration manager for handling model changes
    private let migrationManager: CoreDataMigrationManager
    
    // MARK: - Initialization
    
    /// Initialize the persistence controller
    /// - Parameter inMemory: Whether to use in-memory store (for testing/previews)
    public init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "DigitonePad")
        
        // Set up migration manager
        let storeURL: URL
        if inMemory {
            storeURL = URL(fileURLWithPath: "/dev/null")
        } else {
            storeURL = container.persistentStoreDescriptions.first?.url ?? {
                let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                return urls[urls.count-1].appendingPathComponent("DigitonePad.sqlite")
            }()
        }
        migrationManager = CoreDataMigrationManager(modelName: "DigitonePad", storeURL: storeURL)
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure persistent store
        configurePersistentStore()
        
        // Perform migration if needed (only for non-in-memory stores)
        if !inMemory {
            performMigrationIfNeeded()
        }
        
        // Load persistent stores
        loadPersistentStores()
        
        // Configure contexts
        configureContexts()
    }
    
    // MARK: - Private Setup Methods
    
    private func configurePersistentStore() {
        guard let storeDescription = container.persistentStoreDescriptions.first else {
            return
        }
        
        // Enable automatic migration for lightweight migrations
        storeDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        storeDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        // Enable persistent history tracking
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        // Enable remote change notifications (iOS 13.0+/macOS 10.15+)
        if #available(iOS 13.0, macOS 10.15, *) {
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
    }
    
    private func performMigrationIfNeeded() {
        do {
            try migrationManager.migrateStoreIfNeeded()
        } catch {
            print("Migration failed: \(error)")
            // In production, you might want to handle this more gracefully
            fatalError("Failed to migrate Core Data store: \(error)")
        }
    }
    
    private func loadPersistentStores() {
        container.loadPersistentStores { [weak self] _, error in
            if let error = error {
                print("Failed to load persistent store: \(error)")
                // In production, you might want to handle this more gracefully
                fatalError("Failed to load Core Data store: \(error)")
            }
            
            // Validate migrated data if migration occurred
            if let self = self {
                let isValid = self.migrationManager.validateMigratedData(in: self.container.viewContext)
                if !isValid {
                    print("⚠️ Data validation failed after migration")
                }
            }
        }
    }
    
    private func configureContexts() {
        // Configure view context for UI operations
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        
        // Set up context save notifications
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleContextDidSave(notification)
        }
    }
    
    // MARK: - Context Management
    
    /// Creates a new background context for data operations
    /// - Returns: A new background managed object context
    public func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return context
    }
    
    /// Performs a block on a background context
    /// - Parameter block: The block to perform
    public func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let context = newBackgroundContext()
        context.perform {
            block(context)
        }
    }
    
    // MARK: - Save Operations
    
    /// Saves the view context if it has changes
    /// - Throws: CoreDataError.saveError if save fails
    public func save() throws {
        try saveContext(container.viewContext)
    }
    
    /// Saves a specific context if it has changes
    /// - Parameter context: The context to save
    /// - Throws: CoreDataError.saveError if save fails
    public func saveContext(_ context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            // Rollback changes on save failure
            context.rollback()
            throw CoreDataError.saveError(error)
        }
    }
    
    /// Saves a context and its parent contexts up the chain
    /// - Parameter context: The context to save
    /// - Throws: CoreDataError.saveError if any save fails
    public func saveContextAndParents(_ context: NSManagedObjectContext) throws {
        var currentContext: NSManagedObjectContext? = context
        
        while let ctx = currentContext {
            if ctx.hasChanges {
                do {
                    try ctx.save()
                } catch {
                    ctx.rollback()
                    throw CoreDataError.saveError(error)
                }
            }
            currentContext = ctx.parent
        }
    }
    
    // MARK: - Notification Handling
    
    private func handleContextDidSave(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext else { return }
        
        // Merge changes into view context if needed
        if context != container.viewContext && context.persistentStoreCoordinator == container.persistentStoreCoordinator {
            container.viewContext.perform {
                self.container.viewContext.mergeChanges(fromContextDidSave: notification)
            }
        }
    }
    
    // MARK: - Utilities
    
    /// Creates a backup of the current data store
    /// - Returns: URL of the backup file
    /// - Throws: Error if backup creation fails
    public func createBackup() throws -> URL {
        return try migrationManager.createBackup()
    }
    
    /// Validates the current data integrity
    /// - Returns: True if data is valid, false otherwise
    public func validateDataIntegrity() -> Bool {
        return migrationManager.validateMigratedData(in: container.viewContext)
    }
}

// MARK: - Convenience Extensions

public extension PersistenceController {
    
    /// Fetches all objects of a given type
    /// - Parameter type: The NSManagedObject subclass type
    /// - Returns: Array of fetched objects
    /// - Throws: CoreDataError.fetchError if fetch fails
    func fetchAll<T: NSManagedObject>(_ type: T.Type) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            throw CoreDataError.fetchError(error)
        }
    }
    
    /// Fetches objects with a predicate
    /// - Parameters:
    ///   - type: The NSManagedObject subclass type
    ///   - predicate: The predicate to filter results
    /// - Returns: Array of fetched objects
    /// - Throws: CoreDataError.fetchError if fetch fails
    func fetch<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.predicate = predicate
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            throw CoreDataError.fetchError(error)
        }
    }
    
    /// Counts objects of a given type
    /// - Parameter type: The NSManagedObject subclass type
    /// - Returns: Count of objects
    /// - Throws: CoreDataError.fetchError if count fails
    func count<T: NSManagedObject>(_ type: T.Type) throws -> Int {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        
        do {
            return try container.viewContext.count(for: request)
        } catch {
            throw CoreDataError.fetchError(error)
        }
    }
}

// MARK: - Entity Extensions

extension DataModel.Project {
    /// Convenience method to create a new Project
    public static func create(in context: NSManagedObjectContext, name: String) -> Project {
        let project = Project(context: context)
        project.name = name
        project.createdAt = Date()
        project.updatedAt = Date()
        return project
    }
}

extension DataModel.Pattern {
    /// Convenience method to create a new Pattern
    public static func create(in context: NSManagedObjectContext, name: String, project: Project) -> Pattern {
        let pattern = Pattern(context: context)
        pattern.name = name
        pattern.length = 64
        pattern.tempo = 120.0
        pattern.project = project
        return pattern
    }
}

extension DataModel.Kit {
    /// Convenience method to create a new Kit
    public static func create(in context: NSManagedObjectContext, name: String, project: Project) -> Kit {
        let kit = Kit(context: context)
        kit.name = name
        kit.createdAt = Date()
        kit.updatedAt = Date()
        kit.project = project
        kit.soundFiles = []
        return kit
    }
}

extension DataModel.Track {
    /// Convenience method to create a new Track
    public static func create(in context: NSManagedObjectContext, name: String, pattern: Pattern, kit: Kit) -> Track {
        let track = Track(context: context)
        track.name = name
        track.volume = 0.75
        track.pan = 0.0
        track.isMuted = false
        track.isSolo = false
        track.trackIndex = 0
        track.createdAt = Date()
        track.updatedAt = Date()
        track.pattern = pattern
        track.kit = kit
        return track
    }
}

extension DataModel.Preset {
    /// Convenience method to create a new Preset
    public static func create(in context: NSManagedObjectContext, name: String, category: String?, project: Project) -> Preset {
        let preset = Preset(context: context)
        preset.name = name
        preset.category = category
        preset.createdAt = Date()
        preset.updatedAt = Date()
        preset.project = project
        return preset
    }
}

extension DataModel.Trig {
    /// Convenience method to create a new Trig
    public static func create(in context: NSManagedObjectContext, step: Int16, track: Track, pattern: Pattern) -> Trig {
        let trig = Trig(context: context)
        trig.step = step
        trig.isActive = false
        trig.note = 60 // Middle C
        trig.velocity = 100
        trig.duration = 1.0
        trig.probability = 100
        trig.microTiming = 0.0
        trig.retrigCount = 0
        trig.retrigRate = 0.25
        trig.createdAt = Date()
        trig.updatedAt = Date()
        trig.track = track
        trig.pattern = pattern
        return trig
    }
} 