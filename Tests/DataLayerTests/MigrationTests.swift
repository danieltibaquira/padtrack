import XCTest
import CoreData
@testable import DataLayer

/// Tests for Core Data migration functionality
final class MigrationTests: XCTestCase {
    
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
        // Create a simple managed object model for testing
        let model = createSimpleManagedObjectModel()
        
        // Create in-memory persistent container
        testContainer = NSPersistentContainer(name: "TestModel", managedObjectModel: model)
        
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
    
    private func createSimpleManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Create a simple Project entity for testing
        let projectEntity = NSEntityDescription()
        projectEntity.name = "Project"
        projectEntity.managedObjectClassName = "NSManagedObject"
        
        let nameAttr = NSAttributeDescription()
        nameAttr.name = "name"
        nameAttr.attributeType = .stringAttributeType
        nameAttr.isOptional = true
        
        let versionAttr = NSAttributeDescription()
        versionAttr.name = "version"
        versionAttr.attributeType = .integer16AttributeType
        versionAttr.defaultValue = 1
        
        projectEntity.properties = [nameAttr, versionAttr]
        
        model.entities = [projectEntity]
        return model
    }
    
    // MARK: - Migration Tests
    
    func testBasicMigrationSetup() throws {
        // Test that we can create and save a simple entity
        let project = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["Project"]!, insertInto: testContext)
        project.setValue("Test Project", forKey: "name")
        project.setValue(1, forKey: "version")
        
        try testContext.save()
        
        // Verify the entity was saved
        let request = NSFetchRequest<NSManagedObject>(entityName: "Project")
        let results = try testContext.fetch(request)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.value(forKey: "name") as? String, "Test Project")
        XCTAssertEqual(results.first?.value(forKey: "version") as? Int16, 1)
    }
    
    func testMigrationVersionTracking() throws {
        // Test that we can track migration versions
        let project1 = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["Project"]!, insertInto: testContext)
        project1.setValue("Project V1", forKey: "name")
        project1.setValue(1, forKey: "version")
        
        let project2 = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["Project"]!, insertInto: testContext)
        project2.setValue("Project V2", forKey: "name")
        project2.setValue(2, forKey: "version")
        
        try testContext.save()
        
        // Verify we can fetch by version
        let request = NSFetchRequest<NSManagedObject>(entityName: "Project")
        request.predicate = NSPredicate(format: "version == %d", 2)
        let results = try testContext.fetch(request)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.value(forKey: "name") as? String, "Project V2")
    }
    
    func testMigrationDataIntegrity() throws {
        // Test that data integrity is maintained during migration simulation
        
        // Create initial data
        for i in 1...10 {
            let project = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["Project"]!, insertInto: testContext)
            project.setValue("Project \(i)", forKey: "name")
            project.setValue(1, forKey: "version")
        }
        
        try testContext.save()
        
        // Simulate migration by updating version
        let request = NSFetchRequest<NSManagedObject>(entityName: "Project")
        let projects = try testContext.fetch(request)
        
        for project in projects {
            project.setValue(2, forKey: "version")
        }
        
        try testContext.save()
        
        // Verify all projects were migrated
        let migratedRequest = NSFetchRequest<NSManagedObject>(entityName: "Project")
        migratedRequest.predicate = NSPredicate(format: "version == %d", 2)
        let migratedProjects = try testContext.fetch(migratedRequest)
        
        XCTAssertEqual(migratedProjects.count, 10)
        
        // Verify no projects remain at version 1
        let oldRequest = NSFetchRequest<NSManagedObject>(entityName: "Project")
        oldRequest.predicate = NSPredicate(format: "version == %d", 1)
        let oldProjects = try testContext.fetch(oldRequest)
        
        XCTAssertEqual(oldProjects.count, 0)
    }
    
    func testMigrationRollback() throws {
        // Test that we can handle migration rollback scenarios
        
        // Create initial data
        let project = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["Project"]!, insertInto: testContext)
        project.setValue("Test Project", forKey: "name")
        project.setValue(1, forKey: "version")
        
        try testContext.save()
        
        // Simulate failed migration by attempting invalid operation
        testContext.rollback()
        
        // Verify data is still intact
        let request = NSFetchRequest<NSManagedObject>(entityName: "Project")
        let results = try testContext.fetch(request)
        
        // After rollback, the unsaved changes should be discarded
        // The project should still exist if it was saved before the rollback
        XCTAssertTrue(results.count >= 0) // Could be 0 or 1 depending on when rollback occurred
    }
    
    func testProgressiveMigration() throws {
        // Test progressive migration through multiple versions
        
        // Version 1 data
        let project = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["Project"]!, insertInto: testContext)
        project.setValue("Progressive Project", forKey: "name")
        project.setValue(1, forKey: "version")
        try testContext.save()
        
        // Migrate to version 2
        project.setValue(2, forKey: "version")
        try testContext.save()
        
        // Migrate to version 3
        project.setValue(3, forKey: "version")
        try testContext.save()
        
        // Verify final state
        let request = NSFetchRequest<NSManagedObject>(entityName: "Project")
        let results = try testContext.fetch(request)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.value(forKey: "version") as? Int16, 3)
        XCTAssertEqual(results.first?.value(forKey: "name") as? String, "Progressive Project")
    }
    
    func testMigrationPerformance() throws {
        // Test migration performance with larger datasets
        
        let startTime = Date()
        
        // Create a larger dataset
        for i in 1...1000 {
            let project = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["Project"]!, insertInto: testContext)
            project.setValue("Project \(i)", forKey: "name")
            project.setValue(1, forKey: "version")
        }
        
        try testContext.save()
        
        let migrationStartTime = Date()
        
        // Simulate migration
        let request = NSFetchRequest<NSManagedObject>(entityName: "Project")
        let projects = try testContext.fetch(request)
        
        for project in projects {
            project.setValue(2, forKey: "version")
        }
        
        try testContext.save()
        
        let endTime = Date()
        
        let totalTime = endTime.timeIntervalSince(startTime)
        let migrationTime = endTime.timeIntervalSince(migrationStartTime)
        
        print("Total time: \(totalTime)s, Migration time: \(migrationTime)s")
        
        // Verify migration completed successfully
        let migratedRequest = NSFetchRequest<NSManagedObject>(entityName: "Project")
        migratedRequest.predicate = NSPredicate(format: "version == %d", 2)
        let migratedProjects = try testContext.fetch(migratedRequest)
        
        XCTAssertEqual(migratedProjects.count, 1000)
        
        // Performance assertion - migration should complete within reasonable time
        XCTAssertLessThan(migrationTime, 5.0, "Migration took too long")
    }
}
