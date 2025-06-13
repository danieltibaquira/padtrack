import Foundation
import CoreData

/// Service for caching Core Data objects and query results
public final class CacheService: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = CacheService()
    
    private init() {}
    
    // MARK: - Cache Storage
    
    private var objectCache: NSCache<NSString, NSManagedObject> = {
        let cache = NSCache<NSString, NSManagedObject>()
        cache.countLimit = 1000 // Maximum number of objects to cache
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB memory limit
        return cache
    }()
    
    private var queryCache: NSCache<NSString, NSArray> = {
        let cache = NSCache<NSString, NSArray>()
        cache.countLimit = 100 // Maximum number of query results to cache
        cache.totalCostLimit = 20 * 1024 * 1024 // 20MB memory limit
        return cache
    }()
    
    private var objectIDCache: NSCache<NSString, NSManagedObjectID> = {
        let cache = NSCache<NSString, NSManagedObjectID>()
        cache.countLimit = 2000 // Maximum number of object IDs to cache
        return cache
    }()
    
    // MARK: - Cache Keys
    
    private func objectCacheKey(for objectID: NSManagedObjectID) -> NSString {
        return NSString(string: objectID.uriRepresentation().absoluteString)
    }
    
    private func queryCacheKey(for request: NSFetchRequest<NSManagedObject>) -> NSString {
        var keyComponents: [String] = []
        
        // Entity name
        if let entityName = request.entityName {
            keyComponents.append("entity:\(entityName)")
        }
        
        // Predicate
        if let predicate = request.predicate {
            keyComponents.append("predicate:\(predicate.predicateFormat)")
        }
        
        // Sort descriptors
        if let sortDescriptors = request.sortDescriptors {
            let sortKeys = sortDescriptors.map { "\($0.key ?? ""):\($0.ascending)" }
            keyComponents.append("sort:\(sortKeys.joined(separator:","))")
        }
        
        // Fetch limit and offset
        if request.fetchLimit > 0 {
            keyComponents.append("limit:\(request.fetchLimit)")
        }
        if request.fetchOffset > 0 {
            keyComponents.append("offset:\(request.fetchOffset)")
        }
        
        return NSString(string: keyComponents.joined(separator:"|"))
    }
    
    // MARK: - Object Caching
    
    /// Cache a managed object
    /// - Parameters:
    ///   - object: The object to cache
    ///   - cost: The memory cost of the object (optional)
    public func cacheObject(_ object: NSManagedObject, cost: Int = 0) {
        let key = objectCacheKey(for: object.objectID)
        objectCache.setObject(object, forKey: key, cost: cost)
        
        // Also cache the object ID for quick lookups
        let idKey = NSString(string: "id:\(object.objectID.uriRepresentation().absoluteString)")
        objectIDCache.setObject(object.objectID, forKey: idKey)
    }
    
    /// Retrieve a cached object by its object ID
    /// - Parameter objectID: The object ID to look up
    /// - Returns: The cached object if found, nil otherwise
    public func cachedObject(for objectID: NSManagedObjectID) -> NSManagedObject? {
        let key = objectCacheKey(for: objectID)
        return objectCache.object(forKey: key)
    }
    
    /// Remove an object from the cache
    /// - Parameter objectID: The object ID to remove
    public func removeCachedObject(for objectID: NSManagedObjectID) {
        let key = objectCacheKey(for: objectID)
        objectCache.removeObject(forKey: key)
        
        let idKey = NSString(string: "id:\(objectID.uriRepresentation().absoluteString)")
        objectIDCache.removeObject(forKey: idKey)
    }
    
    // MARK: - Query Result Caching
    
    /// Cache query results
    /// - Parameters:
    ///   - results: The query results to cache
    ///   - request: The fetch request that produced these results
    ///   - cost: The memory cost of the results (optional)
    public func cacheQueryResults<T: NSManagedObject>(_ results: [T], for request: NSFetchRequest<T>, cost: Int = 0) {
        let key = queryCacheKey(for: request as! NSFetchRequest<NSManagedObject>)
        let nsArray = NSArray(array: results)
        queryCache.setObject(nsArray, forKey: key, cost: cost)
        
        // Also cache individual objects
        for object in results {
            cacheObject(object)
        }
    }
    
    /// Retrieve cached query results
    /// - Parameter request: The fetch request to look up
    /// - Returns: The cached results if found, nil otherwise
    public func cachedQueryResults<T: NSManagedObject>(for request: NSFetchRequest<T>) -> [T]? {
        let key = queryCacheKey(for: request as! NSFetchRequest<NSManagedObject>)
        guard let nsArray = queryCache.object(forKey: key) else { return nil }
        return nsArray as? [T]
    }
    
    /// Remove cached query results
    /// - Parameter request: The fetch request to remove from cache
    public func removeCachedQueryResults<T: NSManagedObject>(for request: NSFetchRequest<T>) {
        let key = queryCacheKey(for: request as! NSFetchRequest<NSManagedObject>)
        queryCache.removeObject(forKey: key)
    }
    
    // MARK: - Cache Management
    
    /// Clear all cached objects
    public func clearObjectCache() {
        objectCache.removeAllObjects()
        objectIDCache.removeAllObjects()
    }
    
    /// Clear all cached query results
    public func clearQueryCache() {
        queryCache.removeAllObjects()
    }
    
    /// Clear all caches
    public func clearAllCaches() {
        clearObjectCache()
        clearQueryCache()
    }
    
    /// Get cache statistics
    /// - Returns: Dictionary containing cache statistics
    public func getCacheStatistics() -> [String: Any] {
        return [
            "objectCacheCount": objectCache.countLimit,
            "objectCacheTotalCost": objectCache.totalCostLimit,
            "queryCacheCount": queryCache.countLimit,
            "queryCacheTotalCost": queryCache.totalCostLimit,
            "objectIDCacheCount": objectIDCache.countLimit
        ]
    }
    
    // MARK: - Cache Configuration
    
    /// Configure object cache limits
    /// - Parameters:
    ///   - countLimit: Maximum number of objects to cache
    ///   - totalCostLimit: Maximum memory cost in bytes
    public func configureObjectCache(countLimit: Int, totalCostLimit: Int) {
        objectCache.countLimit = countLimit
        objectCache.totalCostLimit = totalCostLimit
    }
    
    /// Configure query cache limits
    /// - Parameters:
    ///   - countLimit: Maximum number of query results to cache
    ///   - totalCostLimit: Maximum memory cost in bytes
    public func configureQueryCache(countLimit: Int, totalCostLimit: Int) {
        queryCache.countLimit = countLimit
        queryCache.totalCostLimit = totalCostLimit
    }
    
    // MARK: - Smart Caching
    
    /// Intelligently cache objects based on access patterns
    /// - Parameters:
    ///   - objects: Objects to potentially cache
    ///   - accessFrequency: How frequently these objects are accessed (1-10 scale)
    public func smartCache<T: NSManagedObject>(_ objects: [T], accessFrequency: Int = 5) {
        let baseCost = 1024 // 1KB base cost per object
        let adjustedCost = baseCost * max(1, min(10, accessFrequency))
        
        for object in objects {
            cacheObject(object, cost: adjustedCost)
        }
    }
    
    /// Preload frequently accessed objects into cache
    /// - Parameters:
    ///   - entityName: The entity name to preload
    ///   - context: The managed object context
    ///   - limit: Maximum number of objects to preload
    /// - Throws: DataLayerError.fetchError if preloading fails
    public func preloadCache(entityName: String, context: NSManagedObjectContext, limit: Int = 100) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.fetchLimit = limit
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)] // Most recently updated first
        
        do {
            let objects = try context.fetch(request)
            smartCache(objects, accessFrequency: 8) // High frequency for preloaded objects
        } catch {
            throw DataLayerError.fetchError(error)
        }
    }
    
    // MARK: - Cache Invalidation

    /// Invalidate cache for a specific entity type
    /// - Parameter entityName: The entity name to invalidate
    public func invalidateCache(for entityName: String) {
        // Since NSCache doesn't provide a way to iterate through keys,
        // we'll clear the entire query cache when invalidating for an entity type
        // This is a conservative approach that ensures consistency
        clearQueryCache()

        // Note: We don't remove individual objects as they might still be valid
        // and removing them would require iterating through all cached objects
    }
    
    /// Invalidate cache when objects are modified
    /// - Parameter objectIDs: Array of object IDs that were modified
    public func invalidateCacheForModifiedObjects(_ objectIDs: [NSManagedObjectID]) {
        for objectID in objectIDs {
            removeCachedObject(for: objectID)
        }
        
        // Clear query cache as results might be stale
        clearQueryCache()
    }
    
    // MARK: - Memory Pressure Handling
    
    /// Handle memory pressure by reducing cache sizes
    public func handleMemoryPressure() {
        // Reduce cache limits by 50%
        objectCache.countLimit = objectCache.countLimit / 2
        objectCache.totalCostLimit = objectCache.totalCostLimit / 2
        queryCache.countLimit = queryCache.countLimit / 2
        queryCache.totalCostLimit = queryCache.totalCostLimit / 2
        
        // Clear half of the cached items (NSCache will handle this automatically)
        // by setting lower limits
    }
    
    /// Restore normal cache limits after memory pressure
    public func restoreNormalCacheLimits() {
        configureObjectCache(countLimit: 1000, totalCostLimit: 50 * 1024 * 1024)
        configureQueryCache(countLimit: 100, totalCostLimit: 20 * 1024 * 1024)
    }
}
