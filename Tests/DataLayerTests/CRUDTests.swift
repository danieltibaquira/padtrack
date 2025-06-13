import XCTest
import CoreData
@testable import DataLayer

/// Tests for CRUD (Create, Read, Update, Delete) operations
final class CRUDTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var testContainer: NSPersistentContainer!
    var testContext: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        try setupInMemoryCoreDataStack()
    }
    
    override func tearDownWithError() throws {
        testContext = nil
        testContainer = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Setup Methods
    
    private func setupInMemoryCoreDataStack() throws {
        // Create a simple managed object model for CRUD testing
        let model = createCRUDTestModel()
        
        // Create in-memory persistent container
        testContainer = NSPersistentContainer(name: "CRUDTestModel", managedObjectModel: model)
        
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
    
    private func createCRUDTestModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Create a simple entity for CRUD testing
        let testEntity = NSEntityDescription()
        testEntity.name = "CRUDTestEntity"
        testEntity.managedObjectClassName = "NSManagedObject"
        
        let nameAttr = NSAttributeDescription()
        nameAttr.name = "name"
        nameAttr.attributeType = .stringAttributeType
        nameAttr.isOptional = true
        
        let valueAttr = NSAttributeDescription()
        valueAttr.name = "value"
        valueAttr.attributeType = .doubleAttributeType
        valueAttr.defaultValue = 0.0
        
        let countAttr = NSAttributeDescription()
        countAttr.name = "count"
        countAttr.attributeType = .integer16AttributeType
        countAttr.defaultValue = 0
        
        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = "createdAt"
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = true
        
        let updatedAtAttr = NSAttributeDescription()
        updatedAtAttr.name = "updatedAt"
        updatedAtAttr.attributeType = .dateAttributeType
        updatedAtAttr.isOptional = true
        
        testEntity.properties = [nameAttr, valueAttr, countAttr, createdAtAttr, updatedAtAttr]
        
        model.entities = [testEntity]
        return model
    }
    
    // MARK: - Create Tests
    
    func testCreateEntity() throws {
        // Test creating a new entity
        let entity = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["CRUDTestEntity"]!, insertInto: testContext)
        
        // Set values
        entity.setValue("Test Entity", forKey: "name")
        entity.setValue(42.5, forKey: "value")
        entity.setValue(10, forKey: "count")
        entity.setValue(Date(), forKey: "createdAt")
        entity.setValue(Date(), forKey: "updatedAt")
        
        // Save the entity
        try testContext.save()
        
        // Verify the entity was created
        let request = NSFetchRequest<NSManagedObject>(entityName: "CRUDTestEntity")
        let results = try testContext.fetch(request)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.value(forKey: "name") as? String, "Test Entity")
        XCTAssertEqual(results.first?.value(forKey: "value") as? Double, 42.5)
        XCTAssertEqual(results.first?.value(forKey: "count") as? Int16, 10)
    }
    
    func testCreateMultipleEntities() throws {
        // Test creating multiple entities
        for i in 1...5 {
            let entity = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["CRUDTestEntity"]!, insertInto: testContext)
            entity.setValue("Entity \(i)", forKey: "name")
            entity.setValue(Double(i * 10), forKey: "value")
            entity.setValue(Int16(i), forKey: "count")
            entity.setValue(Date(), forKey: "createdAt")
            entity.setValue(Date(), forKey: "updatedAt")
        }
        
        try testContext.save()
        
        // Verify all entities were created
        let request = NSFetchRequest<NSManagedObject>(entityName: "CRUDTestEntity")
        let results = try testContext.fetch(request)
        
        XCTAssertEqual(results.count, 5)
    }
    
    // MARK: - Read Tests
    
    func testReadEntity() throws {
        // Create an entity first
        let entity = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["CRUDTestEntity"]!, insertInto: testContext)
        entity.setValue("Read Test Entity", forKey: "name")
        entity.setValue(100.0, forKey: "value")
        entity.setValue(20, forKey: "count")
        try testContext.save()
        
        // Read the entity back
        let request = NSFetchRequest<NSManagedObject>(entityName: "CRUDTestEntity")
        request.predicate = NSPredicate(format: "name == %@", "Read Test Entity")
        let results = try testContext.fetch(request)
        
        XCTAssertEqual(results.count, 1)
        let fetchedEntity = results.first!
        XCTAssertEqual(fetchedEntity.value(forKey: "name") as? String, "Read Test Entity")
        XCTAssertEqual(fetchedEntity.value(forKey: "value") as? Double, 100.0)
        XCTAssertEqual(fetchedEntity.value(forKey: "count") as? Int16, 20)
    }
    
    func testReadWithSorting() throws {
        // Create multiple entities with different values
        let names = ["Charlie", "Alice", "Bob"]
        for name in names {
            let entity = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["CRUDTestEntity"]!, insertInto: testContext)
            entity.setValue(name, forKey: "name")
            entity.setValue(Double.random(in: 1...100), forKey: "value")
            entity.setValue(Int16.random(in: 1...50), forKey: "count")
        }
        try testContext.save()
        
        // Read with sorting
        let request = NSFetchRequest<NSManagedObject>(entityName: "CRUDTestEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let results = try testContext.fetch(request)
        
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].value(forKey: "name") as? String, "Alice")
        XCTAssertEqual(results[1].value(forKey: "name") as? String, "Bob")
        XCTAssertEqual(results[2].value(forKey: "name") as? String, "Charlie")
    }
    
    func testReadWithFiltering() throws {
        // Create entities with different values
        for i in 1...10 {
            let entity = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["CRUDTestEntity"]!, insertInto: testContext)
            entity.setValue("Entity \(i)", forKey: "name")
            entity.setValue(Double(i * 10), forKey: "value")
            entity.setValue(Int16(i), forKey: "count")
        }
        try testContext.save()
        
        // Read with filtering
        let request = NSFetchRequest<NSManagedObject>(entityName: "CRUDTestEntity")
        request.predicate = NSPredicate(format: "value > %f", 50.0)
        let results = try testContext.fetch(request)
        
        XCTAssertEqual(results.count, 5) // Entities 6-10 have values > 50
    }
    
    // MARK: - Update Tests
    
    func testUpdateEntity() throws {
        // Create an entity first
        let entity = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["CRUDTestEntity"]!, insertInto: testContext)
        entity.setValue("Original Name", forKey: "name")
        entity.setValue(50.0, forKey: "value")
        entity.setValue(5, forKey: "count")
        try testContext.save()
        
        // Update the entity
        entity.setValue("Updated Name", forKey: "name")
        entity.setValue(75.0, forKey: "value")
        entity.setValue(15, forKey: "count")
        entity.setValue(Date(), forKey: "updatedAt")
        try testContext.save()
        
        // Verify the update
        let request = NSFetchRequest<NSManagedObject>(entityName: "CRUDTestEntity")
        let results = try testContext.fetch(request)
        
        XCTAssertEqual(results.count, 1)
        let updatedEntity = results.first!
        XCTAssertEqual(updatedEntity.value(forKey: "name") as? String, "Updated Name")
        XCTAssertEqual(updatedEntity.value(forKey: "value") as? Double, 75.0)
        XCTAssertEqual(updatedEntity.value(forKey: "count") as? Int16, 15)
    }
    
    func testBatchUpdate() throws {
        // Create multiple entities
        for i in 1...5 {
            let entity = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["CRUDTestEntity"]!, insertInto: testContext)
            entity.setValue("Entity \(i)", forKey: "name")
            entity.setValue(Double(i * 10), forKey: "value")
            entity.setValue(Int16(i), forKey: "count")
        }
        try testContext.save()
        
        // Update all entities
        let request = NSFetchRequest<NSManagedObject>(entityName: "CRUDTestEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)] // Ensure consistent order
        let entities = try testContext.fetch(request)

        for entity in entities {
            let currentValue = entity.value(forKey: "value") as? Double ?? 0.0
            entity.setValue(currentValue * 2, forKey: "value") // Double all values
            entity.setValue(Date(), forKey: "updatedAt")
        }
        try testContext.save()

        // Verify the updates
        let updatedRequest = NSFetchRequest<NSManagedObject>(entityName: "CRUDTestEntity")
        updatedRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let updatedEntities = try testContext.fetch(updatedRequest)
        XCTAssertEqual(updatedEntities.count, 5)

        for (index, entity) in updatedEntities.enumerated() {
            let expectedValue = Double((index + 1) * 10 * 2) // Original value * 2
            XCTAssertEqual(entity.value(forKey: "value") as? Double, expectedValue)
        }
    }
    
    // MARK: - Delete Tests
    
    func testDeleteEntity() throws {
        // Create an entity first
        let entity = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["CRUDTestEntity"]!, insertInto: testContext)
        entity.setValue("To Be Deleted", forKey: "name")
        entity.setValue(99.0, forKey: "value")
        entity.setValue(99, forKey: "count")
        try testContext.save()
        
        // Verify it exists
        let request = NSFetchRequest<NSManagedObject>(entityName: "CRUDTestEntity")
        var results = try testContext.fetch(request)
        XCTAssertEqual(results.count, 1)
        
        // Delete the entity
        testContext.delete(entity)
        try testContext.save()
        
        // Verify it's gone
        results = try testContext.fetch(request)
        XCTAssertEqual(results.count, 0)
    }
    
    func testDeleteMultipleEntities() throws {
        // Create multiple entities
        var entitiesToDelete: [NSManagedObject] = []
        for i in 1...10 {
            let entity = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["CRUDTestEntity"]!, insertInto: testContext)
            entity.setValue("Entity \(i)", forKey: "name")
            entity.setValue(Double(i * 10), forKey: "value")
            entity.setValue(Int16(i), forKey: "count")
            
            if i % 2 == 0 { // Mark even-numbered entities for deletion
                entitiesToDelete.append(entity)
            }
        }
        try testContext.save()
        
        // Delete the marked entities
        for entity in entitiesToDelete {
            testContext.delete(entity)
        }
        try testContext.save()
        
        // Verify only odd-numbered entities remain
        let request = NSFetchRequest<NSManagedObject>(entityName: "CRUDTestEntity")
        let results = try testContext.fetch(request)
        XCTAssertEqual(results.count, 5) // 5 odd-numbered entities should remain
    }
    
    // MARK: - Complex CRUD Tests
    
    func testComplexCRUDWorkflow() throws {
        // Test a complete CRUD workflow
        
        // 1. Create
        let entity = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["CRUDTestEntity"]!, insertInto: testContext)
        entity.setValue("Workflow Entity", forKey: "name")
        entity.setValue(100.0, forKey: "value")
        entity.setValue(10, forKey: "count")
        entity.setValue(Date(), forKey: "createdAt")
        entity.setValue(Date(), forKey: "updatedAt")
        try testContext.save()
        
        // 2. Read
        let request = NSFetchRequest<NSManagedObject>(entityName: "CRUDTestEntity")
        request.predicate = NSPredicate(format: "name == %@", "Workflow Entity")
        var results = try testContext.fetch(request)
        XCTAssertEqual(results.count, 1)
        let fetchedEntity = results.first!
        
        // 3. Update
        fetchedEntity.setValue("Updated Workflow Entity", forKey: "name")
        fetchedEntity.setValue(200.0, forKey: "value")
        fetchedEntity.setValue(Date(), forKey: "updatedAt")
        try testContext.save()
        
        // Verify update
        results = try testContext.fetch(request)
        XCTAssertEqual(results.count, 0) // Old name should not be found
        
        request.predicate = NSPredicate(format: "name == %@", "Updated Workflow Entity")
        results = try testContext.fetch(request)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.value(forKey: "value") as? Double, 200.0)
        
        // 4. Delete
        testContext.delete(results.first!)
        try testContext.save()
        
        // Verify deletion
        results = try testContext.fetch(request)
        XCTAssertEqual(results.count, 0)
    }
}
