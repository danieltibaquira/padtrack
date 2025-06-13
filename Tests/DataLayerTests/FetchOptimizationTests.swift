import XCTest
import CoreData
@testable import DataLayer

/// Tests for fetch optimization functionality
final class FetchOptimizationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var testContainer: NSPersistentContainer!
    var testContext: NSManagedObjectContext!
    var optimizationService: FetchOptimizationService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        try setupInMemoryCoreDataStack()
        optimizationService = FetchOptimizationService.shared
    }
    
    override func tearDownWithError() throws {
        testContext = nil
        testContainer = nil
        optimizationService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Setup Methods
    
    private func setupInMemoryCoreDataStack() throws {
        // Create a simple managed object model for optimization testing
        let model = createOptimizationTestModel()
        
        // Create in-memory persistent container
        testContainer = NSPersistentContainer(name: "OptimizationTestModel", managedObjectModel: model)
        
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
    
    private func createOptimizationTestModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Create a test entity
        let testEntity = NSEntityDescription()
        testEntity.name = "OptimizationTestEntity"
        testEntity.managedObjectClassName = "NSManagedObject"
        
        let nameAttr = NSAttributeDescription()
        nameAttr.name = "name"
        nameAttr.attributeType = .stringAttributeType
        nameAttr.isOptional = true
        
        let valueAttr = NSAttributeDescription()
        valueAttr.name = "value"
        valueAttr.attributeType = .doubleAttributeType
        valueAttr.defaultValue = 0.0
        
        let categoryAttr = NSAttributeDescription()
        categoryAttr.name = "category"
        categoryAttr.attributeType = .stringAttributeType
        categoryAttr.isOptional = true
        
        testEntity.properties = [nameAttr, valueAttr, categoryAttr]
        
        model.entities = [testEntity]
        return model
    }
    
    private func createTestEntities(count: Int) throws {
        for i in 1...count {
            let entity = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["OptimizationTestEntity"]!, insertInto: testContext)
            entity.setValue("Entity \(i)", forKey: "name")
            entity.setValue(Double(i * 10), forKey: "value")
            entity.setValue(i % 3 == 0 ? "Category A" : "Category B", forKey: "category")
        }
        try testContext.save()
    }
    
    // MARK: - Optimization Service Tests
    
    func testOptimizationServiceSingleton() throws {
        // Test that FetchOptimizationService is a singleton
        let service1 = FetchOptimizationService.shared
        let service2 = FetchOptimizationService.shared
        
        XCTAssertTrue(service1 === service2, "FetchOptimizationService should be a singleton")
    }
    
    func testOptimizedFetch() throws {
        // Create test data
        try createTestEntities(count: 50)
        
        // Create fetch request
        let request = NSFetchRequest<NSManagedObject>(entityName: "OptimizationTestEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        // Test optimized fetch
        let results = try optimizationService.optimizedFetch(
            request,
            in: testContext,
            batchSize: 10
        )
        
        XCTAssertEqual(results.count, 50)
        XCTAssertEqual(request.fetchBatchSize, 10)
        XCTAssertFalse(request.returnsObjectsAsFaults)
    }
    
    func testPaginatedFetch() throws {
        // Create test data
        try createTestEntities(count: 25)
        
        // Create fetch request
        let request = NSFetchRequest<NSManagedObject>(entityName: "OptimizationTestEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        // Test first page
        let page1 = try optimizationService.paginatedFetch(
            request,
            in: testContext,
            page: 0,
            pageSize: 10
        )
        
        XCTAssertEqual(page1.count, 10)
        
        // Test second page
        let page2 = try optimizationService.paginatedFetch(
            request,
            in: testContext,
            page: 1,
            pageSize: 10
        )
        
        XCTAssertEqual(page2.count, 10)
        
        // Test third page (partial)
        let page3 = try optimizationService.paginatedFetch(
            request,
            in: testContext,
            page: 2,
            pageSize: 10
        )
        
        XCTAssertEqual(page3.count, 5)
        
        // Verify no overlap between pages
        let page1Names = page1.compactMap { $0.value(forKey: "name") as? String }
        let page2Names = page2.compactMap { $0.value(forKey: "name") as? String }
        
        XCTAssertTrue(Set(page1Names).isDisjoint(with: Set(page2Names)))
    }
    
    func testCountOptimization() throws {
        // Create test data
        try createTestEntities(count: 100)
        
        // Test count without predicate
        let request1 = NSFetchRequest<NSManagedObject>(entityName: "OptimizationTestEntity")
        let totalCount = try optimizationService.count(for: request1, in: testContext)
        XCTAssertEqual(totalCount, 100)
        
        // Test count with predicate
        let request2 = NSFetchRequest<NSManagedObject>(entityName: "OptimizationTestEntity")
        request2.predicate = NSPredicate(format: "category == %@", "Category A")
        let categoryACount = try optimizationService.count(for: request2, in: testContext)
        
        // Every 3rd entity is Category A, so we should have 33 entities
        XCTAssertEqual(categoryACount, 33)
    }
    
    func testFetchProperties() throws {
        // Create test data
        try createTestEntities(count: 10)

        // Test fetching only specific properties
        let properties = try optimizationService.fetchProperties(
            entityName: "OptimizationTestEntity",
            in: testContext,
            propertiesToFetch: ["name", "value"],
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
        )

        XCTAssertEqual(properties.count, 10)

        // Verify that only requested properties are present
        for property in properties {
            XCTAssertNotNil(property["name"])
            XCTAssertNotNil(property["value"])
            XCTAssertNil(property["category"]) // This should not be fetched
        }
    }
    
    func testPredicateOptimization() throws {
        // Test IN predicate creation
        let inPredicate = optimizationService.createInPredicate(
            keyPath: "category",
            values: ["Category A", "Category B"]
        )
        
        XCTAssertEqual(inPredicate.predicateFormat, "category IN {\"Category A\", \"Category B\"}")
        
        // Test AND predicate creation
        let predicate1 = NSPredicate(format: "value > %f", 50.0)
        let predicate2 = NSPredicate(format: "category == %@", "Category A")
        let andPredicate = optimizationService.createAndPredicate([predicate1, predicate2])
        
        XCTAssertTrue(andPredicate is NSCompoundPredicate)
        
        // Test OR predicate creation
        let orPredicate = optimizationService.createOrPredicate([predicate1, predicate2])
        
        XCTAssertTrue(orPredicate is NSCompoundPredicate)
    }
    
    func testPerformanceMeasurement() throws {
        // Create test data
        try createTestEntities(count: 1000)
        
        // Test performance measurement
        let request = NSFetchRequest<NSManagedObject>(entityName: "OptimizationTestEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        let (results, executionTime) = try optimizationService.measureFetchPerformance(
            request,
            in: testContext,
            label: "Test Fetch"
        )
        
        XCTAssertEqual(results.count, 1000)
        XCTAssertGreaterThan(executionTime, 0.0)
        XCTAssertLessThan(executionTime, 5.0) // Should complete within 5 seconds
    }
    
    func testObjectIDFetching() throws {
        // Create test data
        try createTestEntities(count: 20)

        // Test fetching object IDs
        let objectIDs = try optimizationService.fetchObjectIDs(
            entityName: "OptimizationTestEntity",
            in: testContext
        )

        XCTAssertEqual(objectIDs.count, 20)

        // Test converting object IDs back to objects
        let objects = try optimizationService.objectsFromIDs(objectIDs, in: testContext)

        XCTAssertEqual(objects.count, 20)
    }
    
    func testBatchFetch() throws {
        // Create test data
        try createTestEntities(count: 30)

        // Create multiple fetch requests
        let request1 = NSFetchRequest<NSManagedObject>(entityName: "OptimizationTestEntity")
        request1.predicate = NSPredicate(format: "category == %@", "Category A")

        let request2 = NSFetchRequest<NSManagedObject>(entityName: "OptimizationTestEntity")
        request2.predicate = NSPredicate(format: "category == %@", "Category B")

        // Test batch fetch
        let results = try optimizationService.batchFetch(
            requests: [request1, request2],
            in: testContext
        )

        XCTAssertEqual(results.keys.count, 1) // Only one entity type
        XCTAssertNotNil(results["OptimizationTestEntity"])

        // The batch fetch executes both requests but only returns the last one
        // So we should get the Category B results (20 entities)
        let totalResults = results["OptimizationTestEntity"]?.count ?? 0
        XCTAssertEqual(totalResults, 20) // Category B entities
    }
    
    func testMemoryOptimization() throws {
        // Create test data
        try createTestEntities(count: 50)
        
        // Fetch objects
        let request = NSFetchRequest<NSManagedObject>(entityName: "OptimizationTestEntity")
        let objects = try testContext.fetch(request)
        
        // Test refreshing objects (turning them into faults)
        optimizationService.refreshObjects(objects, in: testContext, mergeChanges: false)
        
        // Verify objects are now faults
        for object in objects {
            XCTAssertTrue(object.isFault)
        }
        
        // Test context reset
        optimizationService.resetContext(testContext)
        
        // After reset, all objects should be invalidated
        for object in objects {
            XCTAssertTrue(object.isDeleted || object.isFault)
        }
    }
}
