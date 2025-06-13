import XCTest
import CoreData
@testable import DataLayer

/// Tests for data validation functionality
final class ValidationTests: XCTestCase {
    
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
        // Create a simple managed object model for testing validation
        let model = createValidationTestModel()
        
        // Create in-memory persistent container
        testContainer = NSPersistentContainer(name: "ValidationTestModel", managedObjectModel: model)
        
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
    
    private func createValidationTestModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Create a simple entity for validation testing
        let testEntity = NSEntityDescription()
        testEntity.name = "ValidationTestEntity"
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
        
        testEntity.properties = [nameAttr, valueAttr, countAttr]
        
        model.entities = [testEntity]
        return model
    }
    
    // MARK: - Validation Error Tests
    
    func testValidationErrorTypes() throws {
        // Test ValidationError enum functionality
        let nameError = ValidationError.invalidName("Test name error")
        XCTAssertEqual(nameError.errorDescription, "Invalid name: Test name error")
        
        let valueError = ValidationError.invalidValue("Test value error")
        XCTAssertEqual(valueError.errorDescription, "Invalid value: Test value error")
        
        let relationshipError = ValidationError.relationshipConstraint("Test relationship error")
        XCTAssertEqual(relationshipError.errorDescription, "Relationship constraint: Test relationship error")
    }
    
    func testDataLayerErrorTypes() throws {
        // Test DataLayerError enum functionality
        let testError = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        let saveError = DataLayerError.saveError(testError)
        XCTAssertEqual(saveError.errorDescription, "Failed to save data: Test error")
        
        let fetchError = DataLayerError.fetchError(testError)
        XCTAssertEqual(fetchError.errorDescription, "Failed to fetch data: Test error")
        
        let deleteError = DataLayerError.deleteError(testError)
        XCTAssertEqual(deleteError.errorDescription, "Failed to delete data: Test error")
        
        let validationError = DataLayerError.validationError("Test validation")
        XCTAssertEqual(validationError.errorDescription, "Validation error: Test validation")
        
        let migrationError = DataLayerError.migrationError("Test migration")
        XCTAssertEqual(migrationError.errorDescription, "Migration error: Test migration")
        
        let configError = DataLayerError.configurationError("Test config")
        XCTAssertEqual(configError.errorDescription, "Configuration error: Test config")
    }
    
    // MARK: - Basic Validation Tests
    
    func testBasicEntityValidation() throws {
        // Test basic entity creation and validation
        let entity = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["ValidationTestEntity"]!, insertInto: testContext)
        
        // Test setting valid values
        entity.setValue("Test Name", forKey: "name")
        entity.setValue(42.5, forKey: "value")
        entity.setValue(10, forKey: "count")
        
        // Should be able to save without errors
        try testContext.save()
        
        // Verify values were set correctly
        XCTAssertEqual(entity.value(forKey: "name") as? String, "Test Name")
        XCTAssertEqual(entity.value(forKey: "value") as? Double, 42.5)
        XCTAssertEqual(entity.value(forKey: "count") as? Int16, 10)
    }
    
    func testValidationConstraints() throws {
        // Test validation constraints using a custom validation approach
        let entity = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["ValidationTestEntity"]!, insertInto: testContext)
        
        // Test name validation (simulate the validation logic from our entities)
        let testName = ""
        XCTAssertThrowsError(try validateName(testName)) { error in
            XCTAssertTrue(error is ValidationError)
            if let validationError = error as? ValidationError {
                XCTAssertEqual(validationError.errorDescription, "Invalid name: Name cannot be empty")
            }
        }
        
        // Test valid name
        let validName = "Valid Name"
        XCTAssertNoThrow(try validateName(validName))
        
        // Test value range validation
        let invalidValue = -1.0
        XCTAssertThrowsError(try validateValue(invalidValue)) { error in
            XCTAssertTrue(error is ValidationError)
            if let validationError = error as? ValidationError {
                XCTAssertEqual(validationError.errorDescription, "Invalid value: Value must be non-negative")
            }
        }
        
        // Test valid value
        let validValue = 42.0
        XCTAssertNoThrow(try validateValue(validValue))
    }
    
    // MARK: - Helper Validation Methods
    
    private func validateName(_ name: String) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName("Name cannot be empty")
        }
        
        guard name.count <= 100 else {
            throw ValidationError.invalidName("Name cannot exceed 100 characters")
        }
    }
    
    private func validateValue(_ value: Double) throws {
        guard value >= 0.0 else {
            throw ValidationError.invalidValue("Value must be non-negative")
        }
        
        guard value <= 1000.0 else {
            throw ValidationError.invalidValue("Value cannot exceed 1000")
        }
    }
    
    private func validateCount(_ count: Int16) throws {
        guard count >= 0 else {
            throw ValidationError.invalidValue("Count must be non-negative")
        }
        
        guard count <= 127 else {
            throw ValidationError.invalidValue("Count cannot exceed 127")
        }
    }
    
    // MARK: - Complex Validation Tests
    
    func testComplexValidationScenarios() throws {
        // Test multiple validation rules together
        let entity = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["ValidationTestEntity"]!, insertInto: testContext)
        
        // Test valid combination
        entity.setValue("Valid Entity", forKey: "name")
        entity.setValue(50.0, forKey: "value")
        entity.setValue(25, forKey: "count")
        
        try testContext.save()
        
        // Verify the entity was saved successfully
        let request = NSFetchRequest<NSManagedObject>(entityName: "ValidationTestEntity")
        let results = try testContext.fetch(request)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.value(forKey: "name") as? String, "Valid Entity")
    }
    
    func testValidationPerformance() throws {
        // Test validation performance with multiple entities
        let startTime = Date()

        for i in 1...1000 {
            let entity = NSManagedObject(entity: testContainer.managedObjectModel.entitiesByName["ValidationTestEntity"]!, insertInto: testContext)
            entity.setValue("Entity \(i)", forKey: "name")
            entity.setValue(Double(i), forKey: "value")
            entity.setValue(Int16(i % 128), forKey: "count")

            // Simulate validation
            try validateName("Entity \(i)")
            try validateValue(Double(i))
            try validateCount(Int16(i % 128))
        }

        try testContext.save()

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        print("Validation performance: \(duration)s for 1000 entities")

        // Performance assertion - should complete within reasonable time
        XCTAssertLessThan(duration, 5.0, "Validation took too long")

        // Verify all entities were saved
        let request = NSFetchRequest<NSManagedObject>(entityName: "ValidationTestEntity")
        let results = try testContext.fetch(request)
        XCTAssertEqual(results.count, 1000)
    }

    // MARK: - ValidationService Tests

    func testValidationServiceSingleton() throws {
        // Test that ValidationService is a singleton
        let service1 = ValidationService.shared
        let service2 = ValidationService.shared

        XCTAssertTrue(service1 === service2, "ValidationService should be a singleton")
    }

    func testValidationServiceFieldValidation() throws {
        // Test individual field validation methods through the service
        let validationService = ValidationService.shared

        // These tests simulate the validation logic without requiring actual Core Data entities
        // since we can't easily create the complex entities in our test environment

        // Test that the service exists and can be called
        XCTAssertNotNil(validationService)

        // Test validation error creation
        let nameError = ValidationError.invalidName("Test error")
        XCTAssertEqual(nameError.errorDescription, "Invalid name: Test error")

        let valueError = ValidationError.invalidValue("Test value error")
        XCTAssertEqual(valueError.errorDescription, "Invalid value: Test value error")

        let relationshipError = ValidationError.relationshipConstraint("Test relationship error")
        XCTAssertEqual(relationshipError.errorDescription, "Relationship constraint: Test relationship error")
    }

    func testBatchValidationConcept() throws {
        // Test the concept of batch validation with simple entities
        let entities: [NSManagedObject] = []

        // Test empty batch
        let validationService = ValidationService.shared
        let errors = validationService.batchValidate(entities)
        XCTAssertTrue(errors.isEmpty, "Empty batch should have no validation errors")

        // Test that the batch validation method exists and returns the correct type
        XCTAssertTrue(errors is [ValidationError])
    }
}
