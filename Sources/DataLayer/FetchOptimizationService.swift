import Foundation
import CoreData

/// Service for optimizing Core Data fetch requests
public final class FetchOptimizationService: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = FetchOptimizationService()
    
    private init() {}
    
    // MARK: - Optimized Fetch Methods
    
    /// Optimized fetch with batching and prefetching
    /// - Parameters:
    ///   - request: The fetch request to optimize
    ///   - context: The managed object context
    ///   - batchSize: The batch size for fetching (default: 20)
    ///   - relationshipKeyPaths: Key paths for relationships to prefetch
    /// - Returns: Array of fetched objects
    /// - Throws: DataLayerError.fetchError if fetch fails
    public func optimizedFetch<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        in context: NSManagedObjectContext,
        batchSize: Int = 20,
        relationshipKeyPaths: [String] = []
    ) throws -> [T] {
        // Set batch size for memory efficiency
        request.fetchBatchSize = batchSize
        
        // Prefetch relationships to avoid faulting
        if !relationshipKeyPaths.isEmpty {
            request.relationshipKeyPathsForPrefetching = relationshipKeyPaths
        }
        
        // Use property values only when possible to reduce memory usage
        request.returnsObjectsAsFaults = false
        
        do {
            return try context.fetch(request)
        } catch {
            throw DataLayerError.fetchError(error)
        }
    }
    
    /// Fetch with pagination support
    /// - Parameters:
    ///   - request: The fetch request
    ///   - context: The managed object context
    ///   - page: The page number (0-based)
    ///   - pageSize: The number of items per page
    /// - Returns: Array of fetched objects for the specified page
    /// - Throws: DataLayerError.fetchError if fetch fails
    public func paginatedFetch<T: NSManagedObject>(
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
    
    /// Count objects without fetching them
    /// - Parameters:
    ///   - request: The fetch request
    ///   - context: The managed object context
    /// - Returns: Count of objects matching the request
    /// - Throws: DataLayerError.fetchError if count fails
    public func count<T: NSManagedObject>(
        for request: NSFetchRequest<T>,
        in context: NSManagedObjectContext
    ) throws -> Int {
        do {
            return try context.count(for: request)
        } catch {
            throw DataLayerError.fetchError(error)
        }
    }
    
    /// Fetch only specific properties (useful for large objects)
    /// - Parameters:
    ///   - entityName: The entity name
    ///   - context: The managed object context
    ///   - propertiesToFetch: Array of property names to fetch
    ///   - predicate: Optional predicate to filter results
    ///   - sortDescriptors: Optional sort descriptors
    /// - Returns: Array of dictionaries containing the requested properties
    /// - Throws: DataLayerError.fetchError if fetch fails
    public func fetchProperties(
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
    
    // MARK: - Background Operations
    // Note: Background fetch methods temporarily disabled for Swift 6 migration
    // Use performBackgroundTask directly with optimizedFetch for now
    
    // MARK: - Batch Operations
    
    /// Batch fetch multiple entity types efficiently
    /// - Parameters:
    ///   - requests: Array of fetch requests
    ///   - context: The managed object context
    /// - Returns: Dictionary mapping entity names to their fetched objects
    /// - Throws: DataLayerError.fetchError if any fetch fails
    public func batchFetch(
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
    
    // MARK: - Predicate Optimization
    
    /// Creates an optimized predicate for common patterns
    /// - Parameters:
    ///   - keyPath: The key path to filter on
    ///   - values: Array of values to match
    /// - Returns: Optimized predicate using IN operator
    public func createInPredicate(keyPath: String, values: [Any]) -> NSPredicate {
        return NSPredicate(format: "%K IN %@", keyPath, values)
    }
    
    /// Creates a compound predicate with AND logic
    /// - Parameter predicates: Array of predicates to combine
    /// - Returns: Compound predicate
    public func createAndPredicate(_ predicates: [NSPredicate]) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
    
    /// Creates a compound predicate with OR logic
    /// - Parameter predicates: Array of predicates to combine
    /// - Returns: Compound predicate
    public func createOrPredicate(_ predicates: [NSPredicate]) -> NSPredicate {
        return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
    }
    
    // MARK: - Performance Monitoring
    
    /// Measures fetch performance
    /// - Parameters:
    ///   - request: The fetch request to measure
    ///   - context: The managed object context
    ///   - label: Label for the measurement
    /// - Returns: Tuple containing results and execution time
    /// - Throws: DataLayerError.fetchError if fetch fails
    public func measureFetchPerformance<T: NSManagedObject>(
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
    
    // MARK: - Cache-Friendly Fetching
    
    /// Fetch with object ID only (useful for caching)
    /// - Parameters:
    ///   - entityName: The entity name
    ///   - context: The managed object context
    ///   - predicate: Optional predicate to filter results
    /// - Returns: Array of NSManagedObjectID
    /// - Throws: DataLayerError.fetchError if fetch fails
    public func fetchObjectIDs(
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
    
    /// Convert object IDs back to objects efficiently
    /// - Parameters:
    ///   - objectIDs: Array of object IDs
    ///   - context: The managed object context
    /// - Returns: Array of managed objects
    /// - Throws: DataLayerError.fetchError if conversion fails
    public func objectsFromIDs(
        _ objectIDs: [NSManagedObjectID],
        in context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        var objects: [NSManagedObject] = []
        
        for objectID in objectIDs {
            do {
                let object = try context.existingObject(with: objectID)
                objects.append(object)
            } catch {
                // Skip objects that no longer exist
                continue
            }
        }
        
        return objects
    }
    
    // MARK: - Memory Optimization
    
    /// Refresh objects to free memory (turn into faults)
    /// - Parameters:
    ///   - objects: Array of objects to refresh
    ///   - context: The managed object context
    ///   - mergeChanges: Whether to merge changes before refreshing
    public func refreshObjects(
        _ objects: [NSManagedObject],
        in context: NSManagedObjectContext,
        mergeChanges: Bool = false
    ) {
        for object in objects {
            context.refresh(object, mergeChanges: mergeChanges)
        }
    }
    
    /// Reset context to free memory
    /// - Parameter context: The managed object context to reset
    public func resetContext(_ context: NSManagedObjectContext) {
        context.reset()
    }
}
