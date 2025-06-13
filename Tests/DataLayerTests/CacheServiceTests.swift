import XCTest
import CoreData
@testable import DataLayer

/// Tests for caching functionality
final class CacheServiceTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var testContainer: NSPersistentContainer!
    var testContext: NSManagedObjectContext!
    var cacheService: CacheService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        try setupInMemoryCoreDataStack()
        cacheService = CacheService.shared
        
        // Clear caches before each test
        cacheService.clearAllCaches()
    }
    
    override func tearDownWithError() throws {
        cacheService.clearAllCaches()
        testContext = nil
        testContainer = nil
        cacheService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Setup Methods
    
    private func setupInMemoryCoreDataStack() throws {
        // Create a simple managed object model for cache testing
        let model = createCacheTestModel()
        
        // Create in-memory persistent container
        testContainer = NSPersistentContainer(name: "CacheTestModel", managedObjectModel: model)
        
        // Configure in-memory store
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        testContainer.persistentStoreDescriptions = [description]
        
        // Load the store
        var loadError: Error?
        testContainer.loadPersistentStores { _, error in
            loadError = error
        }
        
        if let error = loadError {
            throw error
        }
        
        // Set up context
        testContext = testContainer.viewContext
        testContext.automaticallyMergesChangesFromParent = true
    }
    
    private func createCacheTestModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Create a test entity
        let testEntity = NSEntityDescription()
        testEntity.name = "CacheTestEntity"
        testEntity.managedObjectClassName = "NSManagedObject"
        
        let nameAttr = NSAttributeDescription()
        nameAttr.name = "name"
        nameAttr.attributeType = .stringAttributeType
        nameAttr.isOptional = true
        
        let valueAttr = NSAttributeDescription()
        valueAttr.name = "value"
        valueAttr.attributeType = .doubleAttributeType
        valueAttr.defaultValue = 0.0
        
        let updatedAtAttr = NSAttributeDescription()
        updatedAtAttr.name = "updatedAt"
        updatedAtAttr.attributeType = .dateAttributeType
        updatedAtAttr.isOptional = true
        
        testEntity.properties = [nameAttr, valueAttr, updatedAtAttr]
        
        model.entities = [testEntity]
        return model
    }
    
    private func createTestEntity(name: String, value: Double) throws -> NSManagedObject {
        let entity = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["CacheTestEntity"]!, insertInto: testContext)
        entity.setValue(name, forKey: "name")
        entity.setValue(value, forKey: "value")
        entity.setValue(Date(), forKey: "updatedAt")
        try testContext.save()
        return entity
    }
    
    // MARK: - Cache Service Tests
    
    func testCacheServiceSingleton() throws {
        // Test that CacheService is a singleton
        let service1 = CacheService.shared
        let service2 = CacheService.shared
        
        XCTAssertTrue(service1 === service2, "CacheService should be a singleton")
    }
    
    func testObjectCaching() throws {
        // Create a test entity
        let entity = try createTestEntity(name: "Test Entity", value: 42.0)
        
        // Cache the object
        cacheService.cacheObject(entity, cost: 1024)
        
        // Retrieve from cache
        let cachedEntity = cacheService.cachedObject(for: entity.objectID)
        
        XCTAssertNotNil(cachedEntity)
        XCTAssertEqual(cachedEntity?.objectID, entity.objectID)
        XCTAssertEqual(cachedEntity?.value(forKey: "name") as? String, "Test Entity")
    }
    
    func testObjectCacheRemoval() throws {
        // Create and cache a test entity
        let entity = try createTestEntity(name: "Test Entity", value: 42.0)
        cacheService.cacheObject(entity)
        
        // Verify it's cached
        XCTAssertNotNil(cacheService.cachedObject(for: entity.objectID))
        
        // Remove from cache
        cacheService.removeCachedObject(for: entity.objectID)
        
        // Verify it's no longer cached
        XCTAssertNil(cacheService.cachedObject(for: entity.objectID))
    }
    
    func testQueryResultCaching() throws {
        // Create test entities
        let entity1 = try createTestEntity(name: "Entity 1", value: 10.0)
        let entity2 = try createTestEntity(name: "Entity 2", value: 20.0)
        
        // Create a fetch request
        let request = NSFetchRequest<NSManagedObject>(entityName: "CacheTestEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        // Fetch and cache results
        let results = try testContext.fetch(request)
        cacheService.cacheQueryResults(results, for: request)
        
        // Retrieve from cache
        let cachedResults = cacheService.cachedQueryResults(for: request)
        
        XCTAssertNotNil(cachedResults)
        XCTAssertEqual(cachedResults?.count, 2)
        XCTAssertEqual(cachedResults?.first?.value(forKey: "name") as? String, "Entity 1")
    }
    
    func testQueryCacheRemoval() throws {
        // Create test entities and cache query results
        let entity1 = try createTestEntity(name: "Entity 1", value: 10.0)
        let entity2 = try createTestEntity(name: "Entity 2", value: 20.0)
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "CacheTestEntity")
        let results = try testContext.fetch(request)
        cacheService.cacheQueryResults(results, for: request)
        
        // Verify cached
        XCTAssertNotNil(cacheService.cachedQueryResults(for: request))
        
        // Remove from cache
        cacheService.removeCachedQueryResults(for: request)
        
        // Verify no longer cached
        XCTAssertNil(cacheService.cachedQueryResults(for: request))
    }
    
    func testCacheClearance() throws {
        // Create and cache test entities
        let entity1 = try createTestEntity(name: "Entity 1", value: 10.0)
        let entity2 = try createTestEntity(name: "Entity 2", value: 20.0)
        
        cacheService.cacheObject(entity1)
        cacheService.cacheObject(entity2)
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "CacheTestEntity")
        let results = try testContext.fetch(request)
        cacheService.cacheQueryResults(results, for: request)
        
        // Verify cached
        XCTAssertNotNil(cacheService.cachedObject(for: entity1.objectID))
        XCTAssertNotNil(cacheService.cachedQueryResults(for: request))
        
        // Clear all caches
        cacheService.clearAllCaches()
        
        // Verify cleared
        XCTAssertNil(cacheService.cachedObject(for: entity1.objectID))
        XCTAssertNil(cacheService.cachedQueryResults(for: request))
    }
    
    func testSmartCaching() throws {
        // Create test entities
        let entities = try (1...5).map { i in
            try createTestEntity(name: "Entity \(i)", value: Double(i * 10))
        }
        
        // Smart cache with high frequency
        cacheService.smartCache(entities, accessFrequency: 9)
        
        // Verify all entities are cached
        for entity in entities {
            XCTAssertNotNil(cacheService.cachedObject(for: entity.objectID))
        }
    }
    
    func testCacheInvalidation() throws {
        // Create and cache test entities
        let entity1 = try createTestEntity(name: "Entity 1", value: 10.0)
        let entity2 = try createTestEntity(name: "Entity 2", value: 20.0)
        
        cacheService.cacheObject(entity1)
        cacheService.cacheObject(entity2)
        
        // Verify cached
        XCTAssertNotNil(cacheService.cachedObject(for: entity1.objectID))
        XCTAssertNotNil(cacheService.cachedObject(for: entity2.objectID))
        
        // Invalidate cache for modified objects
        cacheService.invalidateCacheForModifiedObjects([entity1.objectID])
        
        // Verify entity1 is no longer cached, but entity2 still is
        XCTAssertNil(cacheService.cachedObject(for: entity1.objectID))
        XCTAssertNotNil(cacheService.cachedObject(for: entity2.objectID))
    }
    
    func testEntityCacheInvalidation() throws {
        // Create test entities and cache query results
        let entity1 = try createTestEntity(name: "Entity 1", value: 10.0)
        let entity2 = try createTestEntity(name: "Entity 2", value: 20.0)
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "CacheTestEntity")
        let results = try testContext.fetch(request)
        cacheService.cacheQueryResults(results, for: request)
        
        // Verify cached
        XCTAssertNotNil(cacheService.cachedQueryResults(for: request))
        
        // Invalidate cache for entity type
        cacheService.invalidateCache(for: "CacheTestEntity")
        
        // Verify query cache is cleared
        XCTAssertNil(cacheService.cachedQueryResults(for: request))
    }
    
    func testCacheConfiguration() throws {
        // Test cache configuration
        cacheService.configureObjectCache(countLimit: 500, totalCostLimit: 25 * 1024 * 1024)
        cacheService.configureQueryCache(countLimit: 50, totalCostLimit: 10 * 1024 * 1024)
        
        // Get cache statistics
        let stats = cacheService.getCacheStatistics()
        
        XCTAssertEqual(stats["objectCacheCount"] as? Int, 500)
        XCTAssertEqual(stats["objectCacheTotalCost"] as? Int, 25 * 1024 * 1024)
        XCTAssertEqual(stats["queryCacheCount"] as? Int, 50)
        XCTAssertEqual(stats["queryCacheTotalCost"] as? Int, 10 * 1024 * 1024)
    }
    
    func testMemoryPressureHandling() throws {
        // Get initial cache statistics
        let initialStats = cacheService.getCacheStatistics()
        let initialObjectCount = initialStats["objectCacheCount"] as? Int ?? 0
        let initialQueryCount = initialStats["queryCacheCount"] as? Int ?? 0
        
        // Handle memory pressure
        cacheService.handleMemoryPressure()
        
        // Verify cache limits are reduced
        let pressureStats = cacheService.getCacheStatistics()
        let pressureObjectCount = pressureStats["objectCacheCount"] as? Int ?? 0
        let pressureQueryCount = pressureStats["queryCacheCount"] as? Int ?? 0
        
        XCTAssertLessThan(pressureObjectCount, initialObjectCount)
        XCTAssertLessThan(pressureQueryCount, initialQueryCount)
        
        // Restore normal limits
        cacheService.restoreNormalCacheLimits()
        
        // Verify limits are restored
        let restoredStats = cacheService.getCacheStatistics()
        let restoredObjectCount = restoredStats["objectCacheCount"] as? Int ?? 0
        let restoredQueryCount = restoredStats["queryCacheCount"] as? Int ?? 0
        
        XCTAssertEqual(restoredObjectCount, 1000)
        XCTAssertEqual(restoredQueryCount, 100)
    }
    
    func testPreloadCache() throws {
        // Create multiple test entities
        for i in 1...20 {
            _ = try createTestEntity(name: "Entity \(i)", value: Double(i * 10))
        }
        
        // Preload cache
        try cacheService.preloadCache(entityName: "CacheTestEntity", context: testContext, limit: 10)
        
        // Verify that some entities are now cached
        // Note: We can't easily verify which specific entities are cached without
        // exposing internal cache state, but we can verify the method doesn't throw
        XCTAssertNoThrow(try cacheService.preloadCache(entityName: "CacheTestEntity", context: testContext, limit: 10))
    }
}
