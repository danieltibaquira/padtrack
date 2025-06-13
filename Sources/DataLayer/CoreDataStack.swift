import CoreData
import Foundation

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

/// PersistenceController manages the Core Data stack using modern NSPersistentContainer
public final class PersistenceController {
    
    // MARK: - Shared Instances
    
    /// Shared instance for production use
    public static let shared = PersistenceController()
    
    /// Preview instance for SwiftUI previews and testing with in-memory store
    public static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // Create sample data for previews
        let project = Project(context: context)
        project.name = "Sample Project"
        project.createdAt = Date()
        project.updatedAt = Date()
        
        let pattern = Pattern(context: context)
        pattern.name = "Pattern 1"
        pattern.length = 64
        pattern.tempo = 120.0
        pattern.project = project
        
        do {
            try context.save()
        } catch {
            fatalError("Preview data creation failed: \(error)")
        }
        
        return controller
    }()
    
    // MARK: - Properties
    
    /// The NSPersistentContainer that manages the Core Data stack
    public let container: NSPersistentContainer
    
    // MARK: - Initialization
    
    /// Initialize the PersistenceController
    /// - Parameter inMemory: Whether to use in-memory store (for testing/previews)
    public init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "DigitonePad")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure persistent store description for history tracking
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, 
                                                               forKey: NSPersistentHistoryTrackingKey)
        
        // Only set remote change notification if available (iOS 10.15+)
        if #available(macOS 10.15, iOS 13.0, *) {
            container.persistentStoreDescriptions.first?.setOption(true as NSNumber, 
                                                                   forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error {
                print("Failed to load persistent store: \(error.localizedDescription)")
                fatalError("Core Data store loading failed: \(error)")
            } else {
                print("Successfully loaded persistent store: \(storeDescription.url?.absoluteString ?? "unknown")")
            }
        }
        
        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }
    
    // MARK: - Context Management
    
    /// Main context for UI operations (main thread)
    public var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    /// Creates a new background context for data operations
    public func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        return context
    }
    
    // MARK: - Save Operations
    
    /// Save the view context synchronously
    public func save() throws {
        let context = container.viewContext
        
        guard context.hasChanges else {
            print("No changes to save in view context")
            return
        }
        
        do {
            try context.save()
            print("Successfully saved view context")
        } catch {
            print("Failed to save view context: \(error.localizedDescription)")
            throw CoreDataError.saveError(error)
        }
    }
    
    /// Save a background context
    /// - Parameter context: The background context to save
    public func saveBackground(context: NSManagedObjectContext) throws {
        guard context.hasChanges else {
            print("No changes to save in background context")
            return
        }
        
        do {
            try context.save()
            print("Successfully saved background context")
        } catch {
            print("Failed to save background context: \(error.localizedDescription)")
            throw CoreDataError.saveError(error)
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Perform a background operation with automatic context management
    /// - Parameter operation: The operation to perform with the background context
    public func performBackgroundTask(_ operation: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            operation(context)
            
            if context.hasChanges {
                do {
                    try context.save()
                    print("Background task completed and saved successfully")
                } catch {
                    print("Background task save failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Batch Operations
    
    /// Execute a batch delete request
    /// - Parameter request: The batch delete request to execute
    public func executeBatchDelete(_ request: NSBatchDeleteRequest) throws {
        do {
            let result = try container.viewContext.execute(request) as? NSBatchDeleteResult
            let objectIDArray = result?.result as? [NSManagedObjectID]
            let changes = [NSDeletedObjectsKey: objectIDArray ?? []]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [container.viewContext])
            print("Batch delete completed successfully")
        } catch {
            print("Batch delete failed: \(error.localizedDescription)")
            throw CoreDataError.saveError(error)
        }
    }
    
    /// Execute a batch update request
    /// - Parameter request: The batch update request to execute
    public func executeBatchUpdate(_ request: NSBatchUpdateRequest) throws {
        request.resultType = .updatedObjectIDsResultType
        
        do {
            let result = try container.viewContext.execute(request) as? NSBatchUpdateResult
            let objectIDArray = result?.result as? [NSManagedObjectID]
            let changes = [NSUpdatedObjectsKey: objectIDArray ?? []]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [container.viewContext])
            print("Batch update completed successfully")
        } catch {
            print("Batch update failed: \(error.localizedDescription)")
            throw CoreDataError.saveError(error)
        }
    }
}

// MARK: - Entity Extensions

extension Project {
    /// Convenience method to create a new Project
    public static func create(in context: NSManagedObjectContext, name: String) -> Project {
        let project = Project(context: context)
        project.name = name
        project.createdAt = Date()
        project.updatedAt = Date()
        return project
    }
}

extension Pattern {
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

extension Kit {
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

extension Track {
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

extension Preset {
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

extension Trig {
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