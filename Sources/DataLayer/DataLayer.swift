// DataLayer.swift
// DigitonePad - DataLayer Module
//
// This module handles data persistence and Core Data management.

import Foundation
import CoreData
import MachineProtocols
import DataModel

// Core Data entities are imported from DataModel

// Export new managers
public typealias PlusDriveManager = PlusDriveManager
public typealias PresetPool = PresetPool
public typealias ProjectFileManager = ProjectFileManager
public typealias DataMigrator = DataMigrator

// MARK: - Error Types

/// Errors that can occur in the DataLayer
public enum DataLayerError: LocalizedError {
    case saveError(Error)
    case fetchError(Error)
    case deleteError(Error)
    case validationError(String)
    case migrationError(String)
    case configurationError(String)

    public var errorDescription: String? {
        switch self {
        case .saveError(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .fetchError(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .deleteError(let error):
            return "Failed to delete data: \(error.localizedDescription)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .migrationError(let message):
            return "Migration error: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}



/// Main interface for data persistence operations
///
/// The `DataLayerManager` is the primary interface for interacting with the DataLayer package.
/// It provides access to all entity repositories and manages the underlying persistence layer.
///
/// ## Usage
///
/// ```swift
/// let persistenceController = PersistenceController()
/// let dataLayerManager = DataLayerManager(persistenceController: persistenceController)
///
/// // Create a new project
/// let project = dataLayerManager.projectRepository.createProject(name: "My Project")
/// try dataLayerManager.save()
/// ```
///
/// ## Thread Safety
///
/// The DataLayerManager is thread-safe and can be used from multiple threads. However,
/// Core Data objects should only be accessed from the thread/queue where they were created.
/// Use background contexts for heavy operations.
///
/// ## Performance
///
/// The DataLayerManager includes built-in caching and optimization features:
/// - Automatic query result caching
/// - Object-level caching
/// - Fetch request optimization
/// - Memory pressure handling
public final class DataLayerManager: @unchecked Sendable {
    public static let shared = DataLayerManager()

    // MARK: - Core Data Stack

    private let persistenceController: PersistenceController

    // MARK: - Repositories

    public lazy var projectRepository: ProjectRepository = {
        ProjectRepository(context: self.viewContext)
    }()

    public lazy var patternRepository: PatternRepository = {
        PatternRepository(context: self.viewContext)
    }()

    public lazy var trackRepository: TrackRepository = {
        TrackRepository(context: self.viewContext)
    }()

    public lazy var trigRepository: TrigRepository = {
        TrigRepository(context: self.viewContext)
    }()

    public lazy var kitRepository: KitRepository = {
        KitRepository(context: self.viewContext)
    }()

    public lazy var presetRepository: PresetRepository = {
        PresetRepository(context: self.viewContext)
    }()

    // MARK: - Initialization

    private init() {
        persistenceController = PersistenceController.shared
    }

    /// Initialize with custom persistence controller (for testing)
    /// - Parameter persistenceController: Custom persistence controller
    public init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }

    // MARK: - Context Access

    /// The main view context for UI operations
    public var viewContext: NSManagedObjectContext {
        return persistenceController.container.viewContext
    }

    /// Creates a new background context for data operations
    /// - Returns: A new background managed object context
    public func newBackgroundContext() -> NSManagedObjectContext {
        return persistenceController.newBackgroundContext()
    }

    /// Performs a block on a background context
    /// - Parameter block: The block to perform
    public func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistenceController.performBackgroundTask(block)
    }

    // MARK: - Save Operations

    /// Saves the main view context
    /// - Throws: DataLayerError.saveError if save fails
    public func save() throws {
        do {
            try persistenceController.save()
        } catch {
            throw DataLayerError.saveError(error)
        }
    }

    /// Saves a specific context
    /// - Parameter context: The context to save
    /// - Throws: DataLayerError.saveError if save fails
    public func saveContext(_ context: NSManagedObjectContext) throws {
        do {
            try persistenceController.saveContext(context)
        } catch {
            throw DataLayerError.saveError(error)
        }
    }

    // MARK: - Batch Operations

    /// Executes a batch delete request
    /// - Parameters:
    ///   - entityName: The entity name to delete from
    ///   - predicate: The predicate to filter entities
    /// - Throws: DataLayerError.deleteError if delete fails
    public func batchDelete(entityName: String, predicate: NSPredicate?) throws {
        let request = NSBatchDeleteRequest(fetchRequest: NSFetchRequest(entityName: entityName))
        request.resultType = .resultTypeObjectIDs

        if let predicate = predicate {
            request.fetchRequest.predicate = predicate
        }

        do {
            let result = try viewContext.execute(request) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                let changes = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
            }
        } catch {
            throw DataLayerError.deleteError(error)
        }
    }

    /// Executes a batch update request
    /// - Parameters:
    ///   - entityName: The entity name to update
    ///   - predicate: The predicate to filter entities
    ///   - propertiesToUpdate: Dictionary of properties to update
    /// - Throws: DataLayerError.saveError if update fails
    public func batchUpdate(entityName: String, predicate: NSPredicate?, propertiesToUpdate: [String: Any]) throws {
        let request = NSBatchUpdateRequest(entityName: entityName)
        request.predicate = predicate
        request.propertiesToUpdate = propertiesToUpdate
        request.resultType = .updatedObjectIDsResultType

        do {
            let result = try viewContext.execute(request) as? NSBatchUpdateResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                let changes = [NSUpdatedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
            }
        } catch {
            throw DataLayerError.saveError(error)
        }
    }

    // MARK: - Migration Support

    /// Creates a backup of the current data store
    /// - Returns: URL of the backup file
    /// - Throws: Error if backup fails
    public func createBackup() throws -> URL {
        return try persistenceController.createBackup()
    }

    /// Validates migrated data integrity
    /// - Throws: Error if validation fails
    public func validateMigratedData() throws {
        let isValid = persistenceController.validateDataIntegrity()
        if !isValid {
            throw DataLayerError.validationError("Data integrity validation failed")
        }
    }

    // MARK: - High-Level Operations

    /// Creates a complete new project with default structure
    /// - Parameter name: The project name
    /// - Returns: The newly created project with default pattern and kit
    /// - Throws: DataLayerError if creation fails
    public func createNewProject(name: String) throws -> DataModel.Project {
        let project = projectRepository.createProject(name: name)

        // Create default pattern
        let defaultPattern = patternRepository.createPattern(name: "Pattern 1", project: project)

        // Create default kit
        let defaultKit = kitRepository.createKit(name: "Kit 1")

        // Create 16 default tracks
        for i in 0..<16 {
            let track = trackRepository.createTrack(
                name: "Track \(i + 1)",
                pattern: defaultPattern,
                trackIndex: Int16(i)
            )
            track.kit = defaultKit
        }

        try save()
        return project
    }

    /// Duplicates an existing project
    /// - Parameters:
    ///   - project: The project to duplicate
    ///   - newName: The name for the duplicated project
    /// - Returns: The duplicated project
    /// - Throws: DataLayerError if duplication fails
    public func duplicateProject(_ project: DataModel.Project, withName newName: String) throws -> DataModel.Project {
        let newProject = projectRepository.createProject(name: newName)

        // Duplicate all patterns
        if let patterns = project.patterns as? Set<Pattern> {
            for pattern in patterns {
                _ = try duplicatePattern(pattern, toProject: newProject)
            }
        }

        // Duplicate all kits
        if let kits = project.kits as? Set<Kit> {
            for kit in kits {
                _ = try duplicateKit(kit, toProject: newProject)
            }
        }

        // Duplicate all presets
        if let presets = project.presets as? Set<Preset> {
            for preset in presets {
                _ = try duplicatePreset(preset, toProject: newProject)
            }
        }

        try save()
        return newProject
    }

    /// Duplicates a pattern to another project
    /// - Parameters:
    ///   - pattern: The pattern to duplicate
    ///   - project: The target project
    /// - Returns: The duplicated pattern
    /// - Throws: DataLayerError if duplication fails
    public func duplicatePattern(_ pattern: DataModel.Pattern, toProject project: DataModel.Project) throws -> DataModel.Pattern {
        let newPattern = patternRepository.createPattern(
            name: pattern.name ?? "Duplicated Pattern",
            project: project,
            length: pattern.length,
            tempo: pattern.tempo
        )

        // Duplicate all tracks
        if let tracks = pattern.tracks as? Set<Track> {
            for track in tracks {
                _ = try duplicateTrack(track, toPattern: newPattern)
            }
        }

        return newPattern
    }

    /// Duplicates a track to another pattern
    /// - Parameters:
    ///   - track: The track to duplicate
    ///   - pattern: The target pattern
    /// - Returns: The duplicated track
    /// - Throws: DataLayerError if duplication fails
    public func duplicateTrack(_ track: DataModel.Track, toPattern pattern: DataModel.Pattern) throws -> DataModel.Track {
        let newTrack = trackRepository.createTrack(
            name: track.name ?? "Duplicated Track",
            pattern: pattern,
            trackIndex: track.trackIndex
        )

        newTrack.volume = track.volume
        newTrack.pan = track.pan
        newTrack.isMuted = track.isMuted
        newTrack.isSolo = track.isSolo
        newTrack.kit = track.kit
        newTrack.preset = track.preset

        // Duplicate all trigs
        if let trigs = track.trigs as? Set<Trig> {
            for trig in trigs {
                _ = try duplicateTrig(trig, toTrack: newTrack)
            }
        }

        return newTrack
    }

    /// Duplicates a trig to another track
    /// - Parameters:
    ///   - trig: The trig to duplicate
    ///   - track: The target track
    /// - Returns: The duplicated trig
    /// - Throws: DataLayerError if duplication fails
    public func duplicateTrig(_ trig: DataModel.Trig, toTrack track: DataModel.Track) throws -> DataModel.Trig {
        let newTrig = trigRepository.createTrig(
            step: trig.step,
            note: trig.note,
            velocity: trig.velocity,
            track: track
        )

        newTrig.isActive = trig.isActive
        newTrig.duration = trig.duration
        newTrig.probability = trig.probability
        newTrig.microTiming = trig.microTiming
        newTrig.retrigCount = trig.retrigCount
        newTrig.retrigRate = trig.retrigRate
        newTrig.pLocks = trig.pLocks

        return newTrig
    }

    /// Duplicates a kit to another project
    /// - Parameters:
    ///   - kit: The kit to duplicate
    ///   - project: The target project
    /// - Returns: The duplicated kit
    /// - Throws: DataLayerError if duplication fails
    public func duplicateKit(_ kit: DataModel.Kit, toProject project: DataModel.Project) throws -> DataModel.Kit {
        let newKit = kitRepository.createKit(
            name: kit.name ?? "Duplicated Kit"
        )

        newKit.soundFiles = kit.soundFiles

        return newKit
    }

    /// Duplicates a preset to another project
    /// - Parameters:
    ///   - preset: The preset to duplicate
    ///   - project: The target project
    /// - Returns: The duplicated preset
    /// - Throws: DataLayerError if duplication fails
    public func duplicatePreset(_ preset: DataModel.Preset, toProject project: DataModel.Project) throws -> DataModel.Preset {
        let newPreset = presetRepository.createPreset(
            name: preset.name ?? "Duplicated Preset",
            project: project
        )

        newPreset.settings = preset.settings

        return newPreset
    }

    // MARK: - Cleanup Operations

    /// Removes unused presets from a project
    /// - Parameter project: The project to clean up
    /// - Throws: DataLayerError if cleanup fails
    public func removeUnusedPresets(from project: DataModel.Project) throws {
        let presets = try presetRepository.fetchPresets(for: project)

        for preset in presets {
            if preset.tracks?.count == 0 {
                try presetRepository.delete(preset)
            }
        }

        try save()
    }

    /// Removes empty patterns from a project
    /// - Parameter project: The project to clean up
    /// - Throws: DataLayerError if cleanup fails
    public func removeEmptyPatterns(from project: DataModel.Project) throws {
        let patterns = try patternRepository.fetchPatterns(for: project)

        for pattern in patterns {
            let tracks = try trackRepository.fetchTracks(for: pattern)
            let hasActiveTrigs = tracks.contains { track in
                (try? trigRepository.fetchActiveTrigs(for: track).isEmpty == false) ?? false
            }

            if !hasActiveTrigs {
                try patternRepository.delete(pattern)
            }
        }

        try save()
    }
}

// MARK: - Repository Implementations
// These are included here to ensure they're compiled with the DataLayer module

/// Generic repository protocol for CRUD operations
public protocol Repository {
    associatedtype Entity: NSManagedObject

    func create() -> Entity
    func fetch(predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]?) throws -> [Entity]
    func fetchFirst(predicate: NSPredicate?) throws -> Entity?
    func save() throws
    func delete(_ entity: Entity) throws
    func deleteAll(predicate: NSPredicate?) throws
}

/// Base repository implementation providing CRUD operations for Core Data entities
///
/// The `BaseRepository` class provides a generic implementation of common database operations
/// for Core Data entities. It includes built-in caching, optimization, and validation features.
///
/// ## Generic Type Parameter
///
/// - `T`: The Core Data entity type that this repository manages. Must conform to `NSManagedObject`.
///
/// ## Features
///
/// - **CRUD Operations**: Create, read, update, and delete operations
/// - **Caching**: Automatic caching of query results and objects
/// - **Optimization**: Fetch request optimization and batching
/// - **Validation**: Built-in data validation before save operations
/// - **Thread Safety**: Safe to use across multiple threads
///
/// ## Usage
///
/// Typically, you don't instantiate `BaseRepository` directly. Instead, use the specialized
/// repository classes like `ProjectRepository`, `PatternRepository`, etc.
///
/// ```swift
/// // Example with a custom repository
/// class MyEntityRepository: BaseRepository<MyEntity> {
///     func findByCustomProperty(_ value: String) throws -> [MyEntity] {
///         let predicate = NSPredicate(format: "customProperty == %@", value)
///         return try fetch(predicate: predicate)
///     }
/// }
/// ```
public class BaseRepository<T: NSManagedObject>: Repository {
    public typealias Entity = T

    internal let context: NSManagedObjectContext
    private let entityName: String

    public init(context: NSManagedObjectContext) {
        self.context = context
        self.entityName = String(describing: T.self)
    }

    public func create() -> T {
        return T(context: context)
    }

    public func fetch(predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors

        // Check cache first
        if let cachedResults = DataLayerCacheService.shared.cachedQueryResults(for: request) {
            return cachedResults
        }

        // Use optimization service for better performance
        let results = try DataLayerFetchOptimizationService.shared.optimizedFetch(request, in: context)

        // Cache the results
        DataLayerCacheService.shared.cacheQueryResults(results, for: request)

        return results
    }

    public func fetchFirst(predicate: NSPredicate? = nil) throws -> T? {
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = predicate
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            throw DataLayerError.fetchError(error)
        }
    }

    public func save() throws {
        guard context.hasChanges else { return }

        // Collect object IDs that will be modified
        let insertedObjectIDs = context.insertedObjects.map { $0.objectID }
        let updatedObjectIDs = context.updatedObjects.map { $0.objectID }
        let deletedObjectIDs = context.deletedObjects.map { $0.objectID }

        do {
            try context.save()

            // Invalidate cache for modified objects
            let allModifiedIDs = insertedObjectIDs + updatedObjectIDs + deletedObjectIDs
            if !allModifiedIDs.isEmpty {
                DataLayerCacheService.shared.invalidateCacheForModifiedObjects(allModifiedIDs)
            }
        } catch {
            context.rollback()
            throw DataLayerError.saveError(error)
        }
    }

    public func delete(_ entity: T) throws {
        context.delete(entity)
        try save()
    }

    public func deleteAll(predicate: NSPredicate? = nil) throws {
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = predicate

        do {
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            try save()
        } catch {
            throw DataLayerError.deleteError(error)
        }
    }

    // MARK: - Optimized Fetch Methods

    /// Fetch with pagination support
    /// - Parameters:
    ///   - predicate: Optional predicate to filter results
    ///   - sortDescriptors: Optional sort descriptors
    ///   - page: Page number (0-based)
    ///   - pageSize: Number of items per page
    /// - Returns: Array of entities for the specified page
    /// - Throws: DataLayerError.fetchError if fetch fails
    public func fetchPaginated(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        page: Int,
        pageSize: Int
    ) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors

        return try DataLayerFetchOptimizationService.shared.paginatedFetch(
            request,
            in: context,
            page: page,
            pageSize: pageSize
        )
    }

    /// Count entities without fetching them
    /// - Parameter predicate: Optional predicate to filter results
    /// - Returns: Count of entities matching the predicate
    /// - Throws: DataLayerError.fetchError if count fails
    public func count(predicate: NSPredicate? = nil) throws -> Int {
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = predicate

        return try DataLayerFetchOptimizationService.shared.count(for: request, in: context)
    }

    /// Fetch with relationship prefetching
    /// - Parameters:
    ///   - predicate: Optional predicate to filter results
    ///   - sortDescriptors: Optional sort descriptors
    ///   - relationshipKeyPaths: Key paths for relationships to prefetch
    /// - Returns: Array of entities with prefetched relationships
    /// - Throws: DataLayerError.fetchError if fetch fails
    public func fetchWithPrefetching(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        relationshipKeyPaths: [String]
    ) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors

        return try DataLayerFetchOptimizationService.shared.optimizedFetch(
            request,
            in: context,
            relationshipKeyPaths: relationshipKeyPaths
        )
    }

    // MARK: - Cache Management

    /// Clear cache for this entity type
    public func clearCache() {
        DataLayerCacheService.shared.invalidateCache(for: entityName)
    }

    /// Preload frequently accessed objects into cache
    /// - Parameter limit: Maximum number of objects to preload
    /// - Throws: DataLayerError.fetchError if preloading fails
    public func preloadCache(limit: Int = 100) throws {
        try DataLayerCacheService.shared.preloadCache(entityName: entityName, context: context, limit: limit)
    }

    /// Fetch with explicit caching control
    /// - Parameters:
    ///   - predicate: Optional predicate to filter results
    ///   - sortDescriptors: Optional sort descriptors
    ///   - useCache: Whether to use cache for this fetch
    ///   - cacheResults: Whether to cache the results
    /// - Returns: Array of entities
    /// - Throws: DataLayerError.fetchError if fetch fails
    public func fetchWithCacheControl(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        useCache: Bool = true,
        cacheResults: Bool = true
    ) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors

        // Check cache first if enabled
        if useCache, let cachedResults = DataLayerCacheService.shared.cachedQueryResults(for: request) {
            return cachedResults
        }

        // Fetch from Core Data
        let results = try DataLayerFetchOptimizationService.shared.optimizedFetch(request, in: context)

        // Cache the results if enabled
        if cacheResults {
            DataLayerCacheService.shared.cacheQueryResults(results, for: request)
        }

        return results
    }
}

/// Project repository with specific operations
public class ProjectRepository: BaseRepository<DataModel.Project> {
    
    public override init(context: NSManagedObjectContext) {
        super.init(context: context)
    }

    /// Creates a new project with default values
    /// - Parameter name: The project name
    /// - Returns: The newly created project
    public func createProject(name: String) -> DataModel.Project {
        let project: DataModel.Project = create()
        project.name = name
        return project
    }

    /// Fetches all projects sorted by name
    /// - Returns: Array of projects sorted alphabetically
    public func fetchAllProjects() throws -> [Project] {
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        return try fetch(sortDescriptors: [sortDescriptor])
    }

    /// Fetches projects created after a specific date
    /// - Parameter date: The date to filter by
    /// - Returns: Array of projects created after the date
    public func fetchProjectsCreatedAfter(_ date: Date) throws -> [Project] {
        let predicate = NSPredicate(format: "createdAt > %@", date as NSDate)
        let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)
        return try fetch(predicate: predicate, sortDescriptors: [sortDescriptor])
    }

    /// Finds a project by name
    /// - Parameter name: The project name to search for
    /// - Returns: The project if found
    public func findProject(byName name: String) throws -> DataModel.Project? {
        let predicate = NSPredicate(format: "name == %@", name)
        return try fetchFirst(predicate: predicate)
    }
}

/// Pattern repository with specific operations
public class PatternRepository: BaseRepository<DataModel.Pattern> {
    
    public override init(context: NSManagedObjectContext) {
        super.init(context: context)
    }

    /// Creates a new pattern for a project
    /// - Parameters:
    ///   - name: The pattern name
    ///   - project: The parent project
    ///   - length: The pattern length (default: 16)
    ///   - tempo: The pattern tempo (default: 120.0)
    /// - Returns: The newly created pattern
    public func createPattern(name: String, project: DataModel.Project, length: Int16 = 16, tempo: Double = 120.0) -> DataModel.Pattern {
        let pattern: DataModel.Pattern = create()
        pattern.name = name
        pattern.project = project
        pattern.length = length
        pattern.tempo = tempo
        return pattern
    }

    /// Fetches all patterns for a project
    /// - Parameter project: The project to fetch patterns for
    /// - Returns: Array of patterns sorted by name
    public func fetchPatterns(for project: DataModel.Project) throws -> [Pattern] {
        let predicate = NSPredicate(format: "project == %@", project)
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        return try fetch(predicate: predicate, sortDescriptors: [sortDescriptor])
    }

    /// Fetches patterns with specific tempo range
    /// - Parameters:
    ///   - minTempo: Minimum tempo
    ///   - maxTempo: Maximum tempo
    /// - Returns: Array of patterns within tempo range
    public func fetchPatterns(tempoRange minTempo: Double, maxTempo: Double) throws -> [Pattern] {
        let predicate = NSPredicate(format: "tempo >= %f AND tempo <= %f", minTempo, maxTempo)
        let sortDescriptor = NSSortDescriptor(key: "tempo", ascending: true)
        return try fetch(predicate: predicate, sortDescriptors: [sortDescriptor])
    }
}

/// Track repository with specific operations
public class TrackRepository: BaseRepository<DataModel.Track> {
    
    public override init(context: NSManagedObjectContext) {
        super.init(context: context)
    }

    /// Creates a new track for a pattern
    /// - Parameters:
    ///   - name: The track name
    ///   - pattern: The parent pattern
    ///   - trackIndex: The track index (0-15)
    /// - Returns: The newly created track
    public func createTrack(name: String, pattern: DataModel.Pattern, trackIndex: Int16) -> DataModel.Track {
        let track: DataModel.Track = create()
        track.name = name
        track.pattern = pattern
        track.trackIndex = trackIndex
        return track
    }

    /// Fetches all tracks for a pattern
    /// - Parameter pattern: The pattern to fetch tracks for
    /// - Returns: Array of tracks sorted by track index
    public func fetchTracks(for pattern: DataModel.Pattern) throws -> [Track] {
        let predicate = NSPredicate(format: "pattern == %@", pattern)
        let sortDescriptor = NSSortDescriptor(key: "trackIndex", ascending: true)
        return try fetch(predicate: predicate, sortDescriptors: [sortDescriptor])
    }

    /// Fetches muted tracks
    /// - Returns: Array of muted tracks
    public func fetchMutedTracks() throws -> [Track] {
        let predicate = NSPredicate(format: "isMuted == YES")
        return try fetch(predicate: predicate)
    }

    /// Fetches solo tracks
    /// - Returns: Array of solo tracks
    public func fetchSoloTracks() throws -> [Track] {
        let predicate = NSPredicate(format: "isSolo == YES")
        return try fetch(predicate: predicate)
    }
}

/// Trig repository with specific operations
public class TrigRepository: BaseRepository<DataModel.Trig> {
    
    public override init(context: NSManagedObjectContext) {
        super.init(context: context)
    }

    /// Creates a new trig for a track
    /// - Parameters:
    ///   - step: The step position
    ///   - note: The MIDI note
    ///   - velocity: The velocity
    ///   - track: The parent track
    /// - Returns: The newly created trig
    public func createTrig(step: Int16, note: Int16, velocity: Int16, track: DataModel.Track) -> DataModel.Trig {
        let trig: DataModel.Trig = create()
        trig.step = step
        trig.note = note
        trig.velocity = velocity
        trig.track = track
        trig.pattern = track.pattern
        trig.isActive = true
        return trig
    }

    /// Fetches all trigs for a track
    /// - Parameter track: The track to fetch trigs for
    /// - Returns: Array of trigs sorted by step
    public func fetchTrigs(for track: DataModel.Track) throws -> [Trig] {
        let predicate = NSPredicate(format: "track == %@", track)
        let sortDescriptor = NSSortDescriptor(key: "step", ascending: true)
        return try fetch(predicate: predicate, sortDescriptors: [sortDescriptor])
    }

    /// Fetches active trigs for a track
    /// - Parameter track: The track to fetch active trigs for
    /// - Returns: Array of active trigs sorted by step
    public func fetchActiveTrigs(for track: DataModel.Track) throws -> [Trig] {
        let predicate = NSPredicate(format: "track == %@ AND isActive == YES", track)
        let sortDescriptor = NSSortDescriptor(key: "step", ascending: true)
        return try fetch(predicate: predicate, sortDescriptors: [sortDescriptor])
    }

    /// Fetches trigs within a step range
    /// - Parameters:
    ///   - startStep: The start step
    ///   - endStep: The end step
    ///   - track: The track to search in
    /// - Returns: Array of trigs within the step range
    public func fetchTrigs(startStep: Int16, endStep: Int16, track: DataModel.Track) throws -> [Trig] {
        let predicate = NSPredicate(format: "track == %@ AND step >= %d AND step <= %d", track, startStep, endStep)
        let sortDescriptor = NSSortDescriptor(key: "step", ascending: true)
        return try fetch(predicate: predicate, sortDescriptors: [sortDescriptor])
    }
}

/// Kit repository with specific operations
public class KitRepository: BaseRepository<DataModel.Kit> {
    
    public override init(context: NSManagedObjectContext) {
        super.init(context: context)
    }

    /// Creates a new kit
    /// - Parameter name: The kit name
    /// - Returns: The newly created kit
    public func createKit(name: String) -> DataModel.Kit {
        let kit: DataModel.Kit = create()
        kit.name = name
        return kit
    }

    /// Fetches all kits sorted by name
    /// - Returns: Array of kits sorted alphabetically
    public func fetchAllKits() throws -> [Kit] {
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        return try fetch(sortDescriptors: [sortDescriptor])
    }

    /// Finds a kit by name
    /// - Parameter name: The kit name to search for
    /// - Returns: The kit if found
    public func findKit(byName name: String) throws -> DataModel.Kit? {
        let predicate = NSPredicate(format: "name == %@", name)
        return try fetchFirst(predicate: predicate)
    }
}

/// Preset repository with specific operations
public class PresetRepository: BaseRepository<DataModel.Preset> {
    
    public override init(context: NSManagedObjectContext) {
        super.init(context: context)
    }

    /// Creates a new preset for a project
    /// - Parameters:
    ///   - name: The preset name
    ///   - project: The parent project
    /// - Returns: The newly created preset
    public func createPreset(name: String, project: DataModel.Project) -> DataModel.Preset {
        let preset: DataModel.Preset = create()
        preset.name = name
        preset.project = project
        return preset
    }

    /// Fetches all presets for a project
    /// - Parameter project: The project to fetch presets for
    /// - Returns: Array of presets sorted by name
    public func fetchPresets(for project: DataModel.Project) throws -> [Preset] {
        let predicate = NSPredicate(format: "project == %@", project)
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        return try fetch(predicate: predicate, sortDescriptors: [sortDescriptor])
    }

    /// Finds a preset by name within a project
    /// - Parameters:
    ///   - name: The preset name to search for
    ///   - project: The project to search in
    /// - Returns: The preset if found
    public func findPreset(byName name: String, in project: DataModel.Project) throws -> DataModel.Preset? {
        let predicate = NSPredicate(format: "name == %@ AND project == %@", name, project)
        return try fetchFirst(predicate: predicate)
    }
}

// MARK: - Internal Services

/// Internal cache service for the DataLayer
internal final class DataLayerCacheService: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = DataLayerCacheService()

    private init() {}

    // MARK: - Cache Storage

    private var objectCache: NSCache<NSString, NSManagedObject> = {
        let cache = NSCache<NSString, NSManagedObject>()
        cache.countLimit = 1000
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        return cache
    }()

    private var queryCache: NSCache<NSString, NSArray> = {
        let cache = NSCache<NSString, NSArray>()
        cache.countLimit = 100
        cache.totalCostLimit = 20 * 1024 * 1024 // 20MB
        return cache
    }()

    // MARK: - Cache Keys

    private func objectCacheKey(for objectID: NSManagedObjectID) -> NSString {
        return NSString(string: objectID.uriRepresentation().absoluteString)
    }

    private func queryCacheKey(for request: NSFetchRequest<NSManagedObject>) -> NSString {
        var keyComponents: [String] = []

        if let entityName = request.entityName {
            keyComponents.append("entity:\(entityName)")
        }

        if let predicate = request.predicate {
            keyComponents.append("predicate:\(predicate.predicateFormat)")
        }

        if let sortDescriptors = request.sortDescriptors {
            let sortKeys = sortDescriptors.map { "\($0.key ?? ""):\($0.ascending)" }
            keyComponents.append("sort:\(sortKeys.joined(separator:","))")
        }

        if request.fetchLimit > 0 {
            keyComponents.append("limit:\(request.fetchLimit)")
        }
        if request.fetchOffset > 0 {
            keyComponents.append("offset:\(request.fetchOffset)")
        }

        return NSString(string: keyComponents.joined(separator:"|"))
    }

    // MARK: - Object Caching

    func cacheObject(_ object: NSManagedObject, cost: Int = 0) {
        let key = objectCacheKey(for: object.objectID)
        objectCache.setObject(object, forKey: key, cost: cost)
    }

    func cachedObject(for objectID: NSManagedObjectID) -> NSManagedObject? {
        let key = objectCacheKey(for: objectID)
        return objectCache.object(forKey: key)
    }

    func removeCachedObject(for objectID: NSManagedObjectID) {
        let key = objectCacheKey(for: objectID)
        objectCache.removeObject(forKey: key)
    }

    // MARK: - Query Result Caching

    func cacheQueryResults<T: NSManagedObject>(_ results: [T], for request: NSFetchRequest<T>, cost: Int = 0) {
        let key = queryCacheKey(for: request as! NSFetchRequest<NSManagedObject>)
        let nsArray = NSArray(array: results)
        queryCache.setObject(nsArray, forKey: key, cost: cost)

        for object in results {
            cacheObject(object)
        }
    }

    func cachedQueryResults<T: NSManagedObject>(for request: NSFetchRequest<T>) -> [T]? {
        let key = queryCacheKey(for: request as! NSFetchRequest<NSManagedObject>)
        guard let nsArray = queryCache.object(forKey: key) else { return nil }
        return nsArray as? [T]
    }

    func removeCachedQueryResults<T: NSManagedObject>(for request: NSFetchRequest<T>) {
        let key = queryCacheKey(for: request as! NSFetchRequest<NSManagedObject>)
        queryCache.removeObject(forKey: key)
    }

    // MARK: - Cache Management

    func clearObjectCache() {
        objectCache.removeAllObjects()
    }

    func clearQueryCache() {
        queryCache.removeAllObjects()
    }

    func clearAllCaches() {
        clearObjectCache()
        clearQueryCache()
    }

    func invalidateCache(for entityName: String) {
        clearQueryCache()
    }

    func invalidateCacheForModifiedObjects(_ objectIDs: [NSManagedObjectID]) {
        for objectID in objectIDs {
            removeCachedObject(for: objectID)
        }
        clearQueryCache()
    }

    func preloadCache(entityName: String, context: NSManagedObjectContext, limit: Int = 100) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.fetchLimit = limit
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

        do {
            let objects = try context.fetch(request)
            for object in objects {
                cacheObject(object, cost: 1024 * 8) // High frequency for preloaded objects
            }
        } catch {
            throw DataLayerError.fetchError(error)
        }
    }

    func handleMemoryPressure() {
        objectCache.countLimit = objectCache.countLimit / 2
        objectCache.totalCostLimit = objectCache.totalCostLimit / 2
        queryCache.countLimit = queryCache.countLimit / 2
        queryCache.totalCostLimit = queryCache.totalCostLimit / 2
    }

    func restoreNormalCacheLimits() {
        objectCache.countLimit = 1000
        objectCache.totalCostLimit = 50 * 1024 * 1024
        queryCache.countLimit = 100
        queryCache.totalCostLimit = 20 * 1024 * 1024
    }
}

/// Internal fetch optimization service for the DataLayer
internal final class DataLayerFetchOptimizationService: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = DataLayerFetchOptimizationService()

    private init() {}

    // MARK: - Optimized Fetch Methods

    func optimizedFetch<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        in context: NSManagedObjectContext,
        batchSize: Int = 20,
        relationshipKeyPaths: [String] = []
    ) throws -> [T] {
        request.fetchBatchSize = batchSize

        if !relationshipKeyPaths.isEmpty {
            request.relationshipKeyPathsForPrefetching = relationshipKeyPaths
        }

        request.returnsObjectsAsFaults = false

        do {
            return try context.fetch(request)
        } catch {
            throw DataLayerError.fetchError(error)
        }
    }

    func paginatedFetch<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        in context: NSManagedObjectContext,
        page: Int,
        pageSize: Int
    ) throws -> [T] {
        request.fetchLimit = pageSize
        request.fetchOffset = page * pageSize
        request.fetchBatchSize = pageSize

        do {
            return try context.fetch(request)
        } catch {
            throw DataLayerError.fetchError(error)
        }
    }

    func count<T: NSManagedObject>(
        for request: NSFetchRequest<T>,
        in context: NSManagedObjectContext
    ) throws -> Int {
        do {
            return try context.count(for: request)
        } catch {
            throw DataLayerError.fetchError(error)
        }
    }

    func fetchProperties(
        entityName: String,
        in context: NSManagedObjectContext,
        propertiesToFetch: [String],
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil
    ) throws -> [[String: Any]] {
        let request = NSFetchRequest<NSDictionary>(entityName: entityName)
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = propertiesToFetch
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors

        do {
            let results = try context.fetch(request)
            return results.compactMap { $0 as? [String: Any] }
        } catch {
            throw DataLayerError.fetchError(error)
        }
    }

    // Note: Background fetch methods temporarily disabled for Swift 6 migration
    // Use performBackgroundTask directly with optimizedFetch for now

    func batchFetch(
        requests: [NSFetchRequest<NSManagedObject>],
        in context: NSManagedObjectContext
    ) throws -> [String: [NSManagedObject]] {
        var results: [String: [NSManagedObject]] = [:]

        for request in requests {
            let entityName = request.entityName ?? "Unknown"
            do {
                let objects = try optimizedFetch(request, in: context)
                results[entityName] = objects
            } catch {
                throw DataLayerError.fetchError(error)
            }
        }

        return results
    }

    func measureFetchPerformance<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        in context: NSManagedObjectContext,
        label: String = "Fetch"
    ) throws -> (results: [T], executionTime: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()

        let results = try optimizedFetch(request, in: context)

        let executionTime = CFAbsoluteTimeGetCurrent() - startTime

        print("[\(label)] Fetched \(results.count) objects in \(String(format: "%.4f", executionTime))s")

        return (results, executionTime)
    }

    func fetchObjectIDs(
        entityName: String,
        in context: NSManagedObjectContext,
        predicate: NSPredicate? = nil
    ) throws -> [NSManagedObjectID] {
        let request = NSFetchRequest<NSManagedObjectID>(entityName: entityName)
        request.resultType = .managedObjectIDResultType
        request.predicate = predicate

        do {
            return try context.fetch(request)
        } catch {
            throw DataLayerError.fetchError(error)
        }
    }

    func objectsFromIDs(
        _ objectIDs: [NSManagedObjectID],
        in context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        var objects: [NSManagedObject] = []

        for objectID in objectIDs {
            do {
                let object = try context.existingObject(with: objectID)
                objects.append(object)
            } catch {
                continue
            }
        }

        return objects
    }
}