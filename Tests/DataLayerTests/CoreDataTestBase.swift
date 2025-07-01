import XCTest
import CoreData
@testable import DataLayer

/// Base class for Core Data tests with in-memory store setup
class CoreDataTestBase: XCTestCase {
    
    var testContainer: NSPersistentContainer!
    var testContext: NSManagedObjectContext!
    var dataLayerManager: DataLayerManager?
    
    // Repository instances for testing
    var projectRepository: ProjectRepository!
    var patternRepository: PatternRepository!
    var trackRepository: TrackRepository!
    var trigRepository: TrigRepository!
    var kitRepository: KitRepository!
    var presetRepository: PresetRepository!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        try setupInMemoryCoreDataStack()
        setupRepositories()
    }
    
    override func tearDownWithError() throws {
        // Clean up
        projectRepository = nil
        patternRepository = nil
        trackRepository = nil
        trigRepository = nil
        kitRepository = nil
        presetRepository = nil
        dataLayerManager = nil
        testContext = nil
        testContainer = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Setup Methods
    
    // Shared model to avoid NSManagedObject subclass conflicts
    private static let sharedTestModel: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        // Create Project entity
        let projectEntity = NSEntityDescription()
        projectEntity.name = "Project"
        projectEntity.managedObjectClassName = "DataLayer.Project"

        let projectName = NSAttributeDescription()
        projectName.name = "name"
        projectName.attributeType = .stringAttributeType
        projectName.isOptional = true

        let projectCreatedAt = NSAttributeDescription()
        projectCreatedAt.name = "createdAt"
        projectCreatedAt.attributeType = .dateAttributeType
        projectCreatedAt.isOptional = true

        let projectUpdatedAt = NSAttributeDescription()
        projectUpdatedAt.name = "updatedAt"
        projectUpdatedAt.attributeType = .dateAttributeType
        projectUpdatedAt.isOptional = true

        projectEntity.properties = [projectName, projectCreatedAt, projectUpdatedAt]

        // Create Pattern entity
        let patternEntity = NSEntityDescription()
        patternEntity.name = "Pattern"
        patternEntity.managedObjectClassName = "DataLayer.Pattern"

        let patternName = NSAttributeDescription()
        patternName.name = "name"
        patternName.attributeType = .stringAttributeType
        patternName.isOptional = true

        let patternLength = NSAttributeDescription()
        patternLength.name = "length"
        patternLength.attributeType = .integer16AttributeType
        patternLength.defaultValue = 64

        let patternTempo = NSAttributeDescription()
        patternTempo.name = "tempo"
        patternTempo.attributeType = .doubleAttributeType
        patternTempo.defaultValue = 120.0

        let patternCreatedAt = NSAttributeDescription()
        patternCreatedAt.name = "createdAt"
        patternCreatedAt.attributeType = .dateAttributeType
        patternCreatedAt.isOptional = true

        let patternUpdatedAt = NSAttributeDescription()
        patternUpdatedAt.name = "updatedAt"
        patternUpdatedAt.attributeType = .dateAttributeType
        patternUpdatedAt.isOptional = true

        patternEntity.properties = [patternName, patternLength, patternTempo, patternCreatedAt, patternUpdatedAt]

        // Create Track entity
        let trackEntity = NSEntityDescription()
        trackEntity.name = "Track"
        trackEntity.managedObjectClassName = "DataLayer.Track"

        let trackName = NSAttributeDescription()
        trackName.name = "name"
        trackName.attributeType = .stringAttributeType
        trackName.isOptional = true

        let trackVolume = NSAttributeDescription()
        trackVolume.name = "volume"
        trackVolume.attributeType = .floatAttributeType
        trackVolume.defaultValue = 0.75

        let trackPan = NSAttributeDescription()
        trackPan.name = "pan"
        trackPan.attributeType = .floatAttributeType
        trackPan.defaultValue = 0.0

        let trackIsMuted = NSAttributeDescription()
        trackIsMuted.name = "isMuted"
        trackIsMuted.attributeType = .booleanAttributeType
        trackIsMuted.defaultValue = false

        let trackIsSolo = NSAttributeDescription()
        trackIsSolo.name = "isSolo"
        trackIsSolo.attributeType = .booleanAttributeType
        trackIsSolo.defaultValue = false

        let trackIndex = NSAttributeDescription()
        trackIndex.name = "trackIndex"
        trackIndex.attributeType = .integer16AttributeType
        trackIndex.defaultValue = 0

        let trackCreatedAt = NSAttributeDescription()
        trackCreatedAt.name = "createdAt"
        trackCreatedAt.attributeType = .dateAttributeType
        trackCreatedAt.isOptional = true

        let trackUpdatedAt = NSAttributeDescription()
        trackUpdatedAt.name = "updatedAt"
        trackUpdatedAt.attributeType = .dateAttributeType
        trackUpdatedAt.isOptional = true

        trackEntity.properties = [trackName, trackVolume, trackPan, trackIsMuted, trackIsSolo, trackIndex, trackCreatedAt, trackUpdatedAt]

        // Create Trig entity
        let trigEntity = NSEntityDescription()
        trigEntity.name = "Trig"
        trigEntity.managedObjectClassName = "DataLayer.Trig"

        let trigStep = NSAttributeDescription()
        trigStep.name = "step"
        trigStep.attributeType = .integer16AttributeType
        trigStep.defaultValue = 0

        let trigIsActive = NSAttributeDescription()
        trigIsActive.name = "isActive"
        trigIsActive.attributeType = .booleanAttributeType
        trigIsActive.defaultValue = false

        let trigNote = NSAttributeDescription()
        trigNote.name = "note"
        trigNote.attributeType = .integer16AttributeType
        trigNote.defaultValue = 60

        let trigVelocity = NSAttributeDescription()
        trigVelocity.name = "velocity"
        trigVelocity.attributeType = .integer16AttributeType
        trigVelocity.defaultValue = 100

        let trigDuration = NSAttributeDescription()
        trigDuration.name = "duration"
        trigDuration.attributeType = .floatAttributeType
        trigDuration.defaultValue = 1.0

        let trigProbability = NSAttributeDescription()
        trigProbability.name = "probability"
        trigProbability.attributeType = .integer16AttributeType
        trigProbability.defaultValue = 100

        let trigMicroTiming = NSAttributeDescription()
        trigMicroTiming.name = "microTiming"
        trigMicroTiming.attributeType = .floatAttributeType
        trigMicroTiming.defaultValue = 0.0

        let trigRetrigCount = NSAttributeDescription()
        trigRetrigCount.name = "retrigCount"
        trigRetrigCount.attributeType = .integer16AttributeType
        trigRetrigCount.defaultValue = 0

        let trigRetrigRate = NSAttributeDescription()
        trigRetrigRate.name = "retrigRate"
        trigRetrigRate.attributeType = .floatAttributeType
        trigRetrigRate.defaultValue = 0.25

        let trigPLocks = NSAttributeDescription()
        trigPLocks.name = "pLocks"
        trigPLocks.attributeType = .transformableAttributeType
        trigPLocks.isOptional = true

        let trigCreatedAt = NSAttributeDescription()
        trigCreatedAt.name = "createdAt"
        trigCreatedAt.attributeType = .dateAttributeType
        trigCreatedAt.isOptional = true

        let trigUpdatedAt = NSAttributeDescription()
        trigUpdatedAt.name = "updatedAt"
        trigUpdatedAt.attributeType = .dateAttributeType
        trigUpdatedAt.isOptional = true

        trigEntity.properties = [trigStep, trigIsActive, trigNote, trigVelocity, trigDuration, trigProbability, trigMicroTiming, trigRetrigCount, trigRetrigRate, trigPLocks, trigCreatedAt, trigUpdatedAt]

        // Create Kit entity
        let kitEntity = NSEntityDescription()
        kitEntity.name = "Kit"
        kitEntity.managedObjectClassName = "DataLayer.Kit"

        let kitName = NSAttributeDescription()
        kitName.name = "name"
        kitName.attributeType = .stringAttributeType
        kitName.isOptional = true

        let kitSoundFiles = NSAttributeDescription()
        kitSoundFiles.name = "soundFiles"
        kitSoundFiles.attributeType = .transformableAttributeType
        kitSoundFiles.isOptional = true

        let kitCreatedAt = NSAttributeDescription()
        kitCreatedAt.name = "createdAt"
        kitCreatedAt.attributeType = .dateAttributeType
        kitCreatedAt.isOptional = true

        let kitUpdatedAt = NSAttributeDescription()
        kitUpdatedAt.name = "updatedAt"
        kitUpdatedAt.attributeType = .dateAttributeType
        kitUpdatedAt.isOptional = true

        kitEntity.properties = [kitName, kitSoundFiles, kitCreatedAt, kitUpdatedAt]

        // Create Preset entity
        let presetEntity = NSEntityDescription()
        presetEntity.name = "Preset"
        presetEntity.managedObjectClassName = "DataLayer.Preset"

        let presetName = NSAttributeDescription()
        presetName.name = "name"
        presetName.attributeType = .stringAttributeType
        presetName.isOptional = true

        let presetParameterValues = NSAttributeDescription()
        presetParameterValues.name = "parameterValues"
        presetParameterValues.attributeType = .transformableAttributeType
        presetParameterValues.isOptional = true

        let presetCreatedAt = NSAttributeDescription()
        presetCreatedAt.name = "createdAt"
        presetCreatedAt.attributeType = .dateAttributeType
        presetCreatedAt.isOptional = true

        let presetUpdatedAt = NSAttributeDescription()
        presetUpdatedAt.name = "updatedAt"
        presetUpdatedAt.attributeType = .dateAttributeType
        presetUpdatedAt.isOptional = true

        presetEntity.properties = [presetName, presetParameterValues, presetCreatedAt, presetUpdatedAt]

        // Set up all relationships to match the actual Core Data model with correct delete rules
        
        // Project relationships (cascade delete for owned entities)
        let projectPatterns = NSRelationshipDescription()
        projectPatterns.name = "patterns"
        projectPatterns.destinationEntity = patternEntity
        projectPatterns.maxCount = 0 // to-many
        projectPatterns.deleteRule = .cascadeDeleteRule
        
        let projectKits = NSRelationshipDescription()
        projectKits.name = "kits"
        projectKits.destinationEntity = kitEntity
        projectKits.maxCount = 0 // to-many
        projectKits.deleteRule = .cascadeDeleteRule
        
        let projectPresets = NSRelationshipDescription()
        projectPresets.name = "presets"
        projectPresets.destinationEntity = presetEntity
        projectPresets.maxCount = 0 // to-many
        projectPresets.deleteRule = .cascadeDeleteRule
        
        // Pattern relationships
        let patternProject = NSRelationshipDescription()
        patternProject.name = "project"
        patternProject.destinationEntity = projectEntity
        patternProject.maxCount = 1 // to-one
        patternProject.deleteRule = .nullifyDeleteRule
        
        let patternTracks = NSRelationshipDescription()
        patternTracks.name = "tracks"
        patternTracks.destinationEntity = trackEntity
        patternTracks.maxCount = 0 // to-many
        patternTracks.deleteRule = .cascadeDeleteRule
        
        let patternKit = NSRelationshipDescription()
        patternKit.name = "kit"
        patternKit.destinationEntity = kitEntity
        patternKit.maxCount = 1 // to-one
        patternKit.deleteRule = .nullifyDeleteRule
        
        let patternTrigs = NSRelationshipDescription()
        patternTrigs.name = "trigs"
        patternTrigs.destinationEntity = trigEntity
        patternTrigs.maxCount = 0 // to-many
        patternTrigs.deleteRule = .cascadeDeleteRule
        
        // Track relationships
        let trackPattern = NSRelationshipDescription()
        trackPattern.name = "pattern"
        trackPattern.destinationEntity = patternEntity
        trackPattern.maxCount = 1 // to-one
        trackPattern.deleteRule = .nullifyDeleteRule
        
        let trackKit = NSRelationshipDescription()
        trackKit.name = "kit"
        trackKit.destinationEntity = kitEntity
        trackKit.maxCount = 1 // to-one
        trackKit.deleteRule = .nullifyDeleteRule
        
        let trackPreset = NSRelationshipDescription()
        trackPreset.name = "preset"
        trackPreset.destinationEntity = presetEntity
        trackPreset.maxCount = 1 // to-one
        trackPreset.deleteRule = .nullifyDeleteRule
        
        let trackTrigs = NSRelationshipDescription()
        trackTrigs.name = "trigs"
        trackTrigs.destinationEntity = trigEntity
        trackTrigs.maxCount = 0 // to-many
        trackTrigs.deleteRule = .cascadeDeleteRule
        
        // Trig relationships
        let trigTrack = NSRelationshipDescription()
        trigTrack.name = "track"
        trigTrack.destinationEntity = trackEntity
        trigTrack.maxCount = 1 // to-one
        trigTrack.deleteRule = .nullifyDeleteRule
        
        let trigPattern = NSRelationshipDescription()
        trigPattern.name = "pattern"
        trigPattern.destinationEntity = patternEntity
        trigPattern.maxCount = 1 // to-one
        trigPattern.deleteRule = .nullifyDeleteRule
        
        // Kit relationships
        let kitProject = NSRelationshipDescription()
        kitProject.name = "project"
        kitProject.destinationEntity = projectEntity
        kitProject.maxCount = 1 // to-one
        kitProject.deleteRule = .nullifyDeleteRule
        
        let kitTracks = NSRelationshipDescription()
        kitTracks.name = "tracks"
        kitTracks.destinationEntity = trackEntity
        kitTracks.maxCount = 0 // to-many
        kitTracks.deleteRule = .nullifyDeleteRule
        
        // Preset relationships
        let presetProject = NSRelationshipDescription()
        presetProject.name = "project"
        presetProject.destinationEntity = projectEntity
        presetProject.maxCount = 1 // to-one
        presetProject.deleteRule = .nullifyDeleteRule
        
        let presetTracks = NSRelationshipDescription()
        presetTracks.name = "tracks"
        presetTracks.destinationEntity = trackEntity
        presetTracks.maxCount = 0 // to-many
        presetTracks.deleteRule = .nullifyDeleteRule

        // Set up inverse relationships
        projectPatterns.inverseRelationship = patternProject
        patternProject.inverseRelationship = projectPatterns
        
        projectKits.inverseRelationship = kitProject
        kitProject.inverseRelationship = projectKits
        
        projectPresets.inverseRelationship = presetProject
        presetProject.inverseRelationship = projectPresets
        
        patternTracks.inverseRelationship = trackPattern
        trackPattern.inverseRelationship = patternTracks
        
        // Note: patternKit is a one-way relationship (Kit doesn't have inverse pattern relationship)
        
        patternTrigs.inverseRelationship = trigPattern
        trigPattern.inverseRelationship = patternTrigs
        
        trackTrigs.inverseRelationship = trigTrack
        trigTrack.inverseRelationship = trackTrigs
        
        trackKit.inverseRelationship = kitTracks
        kitTracks.inverseRelationship = trackKit
        
        trackPreset.inverseRelationship = presetTracks
        presetTracks.inverseRelationship = trackPreset

        // Add relationships to entities
        projectEntity.properties.append(contentsOf: [projectPatterns, projectKits, projectPresets])
        patternEntity.properties.append(contentsOf: [patternProject, patternTracks, patternKit, patternTrigs])
        trackEntity.properties.append(contentsOf: [trackPattern, trackKit, trackPreset, trackTrigs])
        trigEntity.properties.append(contentsOf: [trigTrack, trigPattern])
        kitEntity.properties.append(contentsOf: [kitProject, kitTracks])
        presetEntity.properties.append(contentsOf: [presetProject, presetTracks])

        // Add entities to model
        model.entities = [projectEntity, patternEntity, trackEntity, trigEntity, kitEntity, presetEntity]

        return model
    }()
    
    private func setupInMemoryCoreDataStack() throws {
        // Use the shared model to avoid NSManagedObject subclass conflicts
        testContainer = NSPersistentContainer(name: "DigitonePadTest", managedObjectModel: Self.sharedTestModel)

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
    
    private func setupRepositories() {
        projectRepository = ProjectRepository(context: testContext)
        patternRepository = PatternRepository(context: testContext)
        trackRepository = TrackRepository(context: testContext)
        trigRepository = TrigRepository(context: testContext)
        kitRepository = KitRepository(context: testContext)
        presetRepository = PresetRepository(context: testContext)

        // Don't create DataLayerManager for now to avoid model loading issues
        dataLayerManager = nil
    }
    
    // MARK: - Helper Methods
    
    /// Saves the test context and handles errors
    func saveContext() throws {
        if testContext.hasChanges {
            try testContext.save()
        }
    }
    
    /// Creates a test project with default values
    func createTestProject(name: String = "Test Project") -> Project {
        let project = projectRepository.createProject(name: name)
        return project
    }
    
    /// Creates a test pattern for a project
    func createTestPattern(name: String = "Test Pattern", project: Project, length: Int16 = 16, tempo: Double = 120.0) -> DataLayer.Pattern {
        let pattern = patternRepository.createPattern(name: name, project: project, length: length, tempo: tempo)
        return pattern
    }

    /// Creates a test track for a pattern
    func createTestTrack(name: String = "Test Track", pattern: DataLayer.Pattern, trackIndex: Int16 = 0) -> Track {
        let track = trackRepository.createTrack(name: name, pattern: pattern, trackIndex: trackIndex)
        return track
    }
    
    /// Creates a test trig for a track
    func createTestTrig(step: Int16 = 0, note: Int16 = 60, velocity: Int16 = 100, track: Track) -> Trig {
        let trig = trigRepository.createTrig(step: step, note: note, velocity: velocity, track: track)
        return trig
    }
    
    /// Creates a test kit
    func createTestKit(name: String = "Test Kit") -> Kit {
        let kit = kitRepository.createKit(name: name)
        return kit
    }
    
    /// Creates a test preset for a project
    func createTestPreset(name: String = "Test Preset", project: Project) -> Preset {
        let preset = presetRepository.createPreset(name: name, project: project)
        return preset
    }
    
    /// Creates a complete test hierarchy: Project -> Pattern -> Track -> Trig
    func createTestHierarchy() throws -> (project: Project, pattern: DataLayer.Pattern, track: Track, trig: Trig) {
        let project = createTestProject()
        let pattern = createTestPattern(project: project)
        let track = createTestTrack(pattern: pattern)
        let trig = createTestTrig(track: track)
        
        try saveContext()
        
        return (project, pattern, track, trig)
    }
    
    /// Asserts that a validation error is thrown
    func assertValidationError<T>(_ expression: @autoclosure () throws -> T, 
                                 expectedError: ValidationError,
                                 file: StaticString = #filePath,
                                 line: UInt = #line) {
        do {
            _ = try expression()
            XCTFail("Expected validation error to be thrown", file: file, line: line)
        } catch let error as ValidationError {
            switch (error, expectedError) {
            case (.invalidName(let actual), .invalidName(let expected)):
                XCTAssertEqual(actual, expected, file: file, line: line)
            case (.invalidValue(let actual), .invalidValue(let expected)):
                XCTAssertEqual(actual, expected, file: file, line: line)
            case (.relationshipConstraint(let actual), .relationshipConstraint(let expected)):
                XCTAssertEqual(actual, expected, file: file, line: line)
            default:
                XCTFail("Validation error type mismatch. Expected: \(expectedError), Actual: \(error)", file: file, line: line)
            }
        } catch {
            XCTFail("Expected ValidationError but got: \(error)", file: file, line: line)
        }
    }
    
    /// Counts entities of a specific type
    func countEntities<T: NSManagedObject>(ofType type: T.Type) throws -> Int {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        return try testContext.count(for: request)
    }
    
    /// Fetches all entities of a specific type
    func fetchAllEntities<T: NSManagedObject>(ofType type: T.Type) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        return try testContext.fetch(request)
    }
    
    /// Clears all data from the test context
    func clearAllData() throws {
        // Delete all entities in dependency order (children first)
        let trigRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trig")
        let trigDeleteRequest = NSBatchDeleteRequest(fetchRequest: trigRequest)
        try testContext.execute(trigDeleteRequest)
        
        let trackRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Track")
        let trackDeleteRequest = NSBatchDeleteRequest(fetchRequest: trackRequest)
        try testContext.execute(trackDeleteRequest)
        
        let patternRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Pattern")
        let patternDeleteRequest = NSBatchDeleteRequest(fetchRequest: patternRequest)
        try testContext.execute(patternDeleteRequest)
        
        let kitRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Kit")
        let kitDeleteRequest = NSBatchDeleteRequest(fetchRequest: kitRequest)
        try testContext.execute(kitDeleteRequest)
        
        let presetRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Preset")
        let presetDeleteRequest = NSBatchDeleteRequest(fetchRequest: presetRequest)
        try testContext.execute(presetDeleteRequest)
        
        let projectRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Project")
        let projectDeleteRequest = NSBatchDeleteRequest(fetchRequest: projectRequest)
        try testContext.execute(projectDeleteRequest)
        
        try saveContext()
    }
    
    // MARK: - Assertion Helpers
    
    /// Asserts that two dates are approximately equal (within 1 second)
    func assertDatesEqual(_ date1: Date?, _ date2: Date?, accuracy: TimeInterval = 1.0, file: StaticString = #filePath, line: UInt = #line) {
        guard let date1 = date1, let date2 = date2 else {
            XCTFail("One or both dates are nil", file: file, line: line)
            return
        }
        XCTAssertEqual(date1.timeIntervalSince1970, date2.timeIntervalSince1970, accuracy: accuracy, file: file, line: line)
    }
    
    /// Asserts that a relationship count matches expected value
    func assertRelationshipCount<T: NSManagedObject>(_ object: T, keyPath: String, expectedCount: Int, file: StaticString = #filePath, line: UInt = #line) {
        guard let relationship = object.value(forKey: keyPath) as? NSSet else {
            XCTFail("Relationship \(keyPath) is not an NSSet", file: file, line: line)
            return
        }
        XCTAssertEqual(relationship.count, expectedCount, "Relationship \(keyPath) count mismatch", file: file, line: line)
    }
}
