import XCTest
import CoreData
@testable import DataLayer
@testable import DataModel

class DataIntegrityTests: CoreDataTestBase {
    
    // MARK: - Relationship Integrity Tests
    
    func testProjectCascadeDeletion() throws {
        // Test that deleting a project cascades properly
        let project = createCompleteProjectHierarchy()
        let projectId = project.objectID
        
        // Count initial entities
        let initialPatternCount = try countEntities(entityName: "Pattern")
        let initialTrackCount = try countEntities(entityName: "Track")
        let initialPresetCount = try countEntities(entityName: "Preset")
        let initialTrigCount = try countEntities(entityName: "Trig")
        
        XCTAssertGreaterThan(initialPatternCount, 0)
        XCTAssertGreaterThan(initialTrackCount, 0)
        XCTAssertGreaterThan(initialPresetCount, 0)
        XCTAssertGreaterThan(initialTrigCount, 0)
        
        // Delete project
        testContext.delete(project)
        try testContext.save()
        
        // Verify cascade deletion
        XCTAssertEqual(try countEntities(entityName: "Pattern"), 0)
        XCTAssertEqual(try countEntities(entityName: "Track"), 0)
        XCTAssertEqual(try countEntities(entityName: "Preset"), 0)
        XCTAssertEqual(try countEntities(entityName: "Trig"), 0)
        
        // Verify project is deleted
        let fetchRequest = NSFetchRequest<Project>(entityName: "Project")
        fetchRequest.predicate = NSPredicate(format: "SELF == %@", projectId)
        let results = try testContext.fetch(fetchRequest)
        XCTAssertEqual(results.count, 0)
    }
    
    func testPatternTrackRelationshipIntegrity() throws {
        // Test pattern-track relationship integrity
        let project = createTestProject()
        let pattern = createPattern(in: project, name: "Test Pattern")
        
        // Add tracks
        let tracks = (1...8).map { i in
            createTrack(in: pattern, number: i)
        }
        
        try testContext.save()
        
        // Verify relationships
        XCTAssertEqual(pattern.tracks?.count, 8)
        
        for track in tracks {
            XCTAssertEqual(track.pattern, pattern)
        }
        
        // Test nullify on pattern deletion
        testContext.delete(pattern)
        try testContext.save()
        
        // Tracks should still exist but with nil pattern
        for track in tracks {
            XCTAssertNil(track.pattern)
        }
    }
    
    func testPresetKitTrackConsistency() throws {
        // Test that presets maintain consistency with kit and track
        let project = createTestProject()
        let pattern = createPattern(in: project, name: "Pattern 1")
        let kit = createKit(in: pattern, name: "Kit 1")
        let track = createTrack(in: pattern, number: 1)
        let preset = createPreset(in: kit, for: track, name: "Preset 1")
        
        try testContext.save()
        
        // Verify initial state
        XCTAssertEqual(preset.kit, kit)
        XCTAssertEqual(preset.track, track)
        XCTAssertTrue(kit.presets?.contains(preset) ?? false)
        
        // Test orphaned preset prevention
        testContext.delete(track)
        try testContext.save()
        
        // Preset should be deleted when track is deleted
        let presetFetch = NSFetchRequest<Preset>(entityName: "Preset")
        presetFetch.predicate = NSPredicate(format: "name == %@", "Preset 1")
        let presets = try testContext.fetch(presetFetch)
        XCTAssertEqual(presets.count, 0)
    }
    
    // MARK: - Data Validation Tests
    
    func testRequiredFieldValidation() throws {
        // Test that required fields are enforced
        
        // Project without name
        let project = NSEntityDescription.insertNewObject(forEntityName: "Project", into: testContext) as! Project
        project.bpm = 120
        
        do {
            try testContext.save()
            XCTFail("Should have failed validation for missing project name")
        } catch {
            // Expected validation error
            testContext.rollback()
        }
        
        // Track without number
        let validProject = createTestProject()
        let pattern = createPattern(in: validProject, name: "Pattern")
        let track = NSEntityDescription.insertNewObject(forEntityName: "Track", into: testContext) as! Track
        track.pattern = pattern
        // Missing track.number
        
        do {
            try testContext.save()
            XCTFail("Should have failed validation for missing track number")
        } catch {
            // Expected validation error
            testContext.rollback()
        }
    }
    
    func testValueRangeValidation() throws {
        // Test that values are within valid ranges
        let project = createTestProject()
        
        // Test BPM range
        project.bpm = -1
        XCTAssertThrowsError(try testContext.save())
        testContext.rollback()
        
        project.bpm = 301
        XCTAssertThrowsError(try testContext.save())
        testContext.rollback()
        
        // Valid BPM
        project.bpm = 120
        XCTAssertNoThrow(try testContext.save())
        
        // Test track number range
        let pattern = createPattern(in: project, name: "Pattern")
        let track = createTrack(in: pattern, number: 0)
        XCTAssertThrowsError(try testContext.save())
        testContext.rollback()
        
        track.number = 17
        XCTAssertThrowsError(try testContext.save())
        testContext.rollback()
        
        // Valid track number
        track.number = 8
        XCTAssertNoThrow(try testContext.save())
    }
    
    // MARK: - Concurrent Modification Tests
    
    func testConcurrentDataModification() throws {
        // Test data integrity during concurrent modifications
        let project = createCompleteProjectHierarchy()
        let expectation = XCTestExpectation(description: "Concurrent modifications")
        
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        var errors: [Error] = []
        let errorLock = NSLock()
        
        // Perform concurrent modifications
        for i in 0..<10 {
            group.enter()
            queue.async {
                defer { group.leave() }
                
                // Create a private context for each thread
                let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
                privateContext.parent = self.testContext
                
                privateContext.performAndWait {
                    do {
                        // Fetch the project in this context
                        let fetchRequest = NSFetchRequest<Project>(entityName: "Project")
                        fetchRequest.fetchLimit = 1
                        guard let contextProject = try privateContext.fetch(fetchRequest).first else {
                            return
                        }
                        
                        // Make modifications
                        if i % 2 == 0 {
                            // Add pattern
                            let pattern = NSEntityDescription.insertNewObject(forEntityName: "Pattern", into: privateContext) as! Pattern
                            pattern.name = "Concurrent Pattern \(i)"
                            pattern.project = contextProject
                        } else {
                            // Modify existing data
                            contextProject.name = "Modified \(i)"
                            contextProject.updatedAt = Date()
                        }
                        
                        // Save to parent context
                        try privateContext.save()
                    } catch {
                        errorLock.lock()
                        errors.append(error)
                        errorLock.unlock()
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            // Save parent context
            do {
                try self.testContext.save()
            } catch {
                errors.append(error)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        XCTAssertTrue(errors.isEmpty, "Concurrent modification errors: \(errors)")
        
        // Verify data integrity
        XCTAssertTrue(try validateProjectIntegrity(project))
    }
    
    // MARK: - Transaction Rollback Tests
    
    func testTransactionRollback() throws {
        // Test that failed transactions don't corrupt data
        let project = createTestProject()
        let initialName = project.name
        
        // Start transaction
        let pattern1 = createPattern(in: project, name: "Pattern 1")
        let pattern2 = createPattern(in: project, name: "Pattern 2")
        
        // Modify project
        project.name = "Modified Project"
        
        // Create invalid data to force rollback
        let invalidTrack = NSEntityDescription.insertNewObject(forEntityName: "Track", into: testContext) as! Track
        invalidTrack.pattern = pattern1
        // Missing required track.number
        
        // Attempt save (should fail)
        do {
            try testContext.save()
            XCTFail("Should have failed due to invalid track")
        } catch {
            // Rollback
            testContext.rollback()
        }
        
        // Verify rollback restored original state
        XCTAssertEqual(project.name, initialName)
        XCTAssertEqual(project.patterns?.count ?? 0, 0)
        XCTAssertFalse(testContext.hasChanges)
    }
    
    // MARK: - Memory Integrity Tests
    
    func testMemoryIntegrityUnderLoad() throws {
        // Test data integrity under memory pressure
        var projects: [Project] = []
        
        // Create many projects with full hierarchy
        for i in 0..<10 {
            autoreleasepool {
                let project = createCompleteProjectHierarchy()
                project.name = "Load Test \(i)"
                projects.append(project)
                
                do {
                    try testContext.save()
                } catch {
                    XCTFail("Failed to save project \(i): \(error)")
                }
            }
        }
        
        // Verify all projects maintain integrity
        for project in projects {
            XCTAssertTrue(try validateProjectIntegrity(project))
        }
        
        // Test with fault firing
        testContext.reset()
        
        // Re-fetch and verify
        let fetchRequest = NSFetchRequest<Project>(entityName: "Project")
        let refetchedProjects = try testContext.fetch(fetchRequest)
        
        XCTAssertEqual(refetchedProjects.count, projects.count)
        
        for project in refetchedProjects {
            XCTAssertTrue(try validateProjectIntegrity(project))
        }
    }
    
    // MARK: - Unique Constraint Tests
    
    func testUniqueConstraints() throws {
        // Test that unique constraints are enforced
        let project = createTestProject()
        let pattern = createPattern(in: project, name: "Pattern 1")
        
        // Create track with number 1
        let track1 = createTrack(in: pattern, number: 1)
        try testContext.save()
        
        // Attempt to create another track with same number in same pattern
        let track2 = createTrack(in: pattern, number: 1)
        
        do {
            try testContext.save()
            XCTFail("Should have failed due to duplicate track number")
        } catch {
            // Expected constraint violation
            testContext.rollback()
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestProject() -> Project {
        let project = NSEntityDescription.insertNewObject(forEntityName: "Project", into: testContext) as! Project
        project.name = "Test Project"
        project.bpm = 120.0
        project.createdAt = Date()
        project.updatedAt = Date()
        return project
    }
    
    private func createPattern(in project: Project, name: String) -> Pattern {
        let pattern = NSEntityDescription.insertNewObject(forEntityName: "Pattern", into: testContext) as! Pattern
        pattern.name = name
        pattern.project = project
        pattern.length = 64
        return pattern
    }
    
    private func createKit(in pattern: Pattern, name: String) -> Kit {
        let kit = NSEntityDescription.insertNewObject(forEntityName: "Kit", into: testContext) as! Kit
        kit.name = name
        kit.pattern = pattern
        return kit
    }
    
    private func createTrack(in pattern: Pattern, number: Int) -> Track {
        let track = NSEntityDescription.insertNewObject(forEntityName: "Track", into: testContext) as! Track
        track.number = Int16(number)
        track.pattern = pattern
        track.isMuted = false
        track.volume = 1.0
        return track
    }
    
    private func createPreset(in kit: Kit, for track: Track, name: String) -> Preset {
        let preset = NSEntityDescription.insertNewObject(forEntityName: "Preset", into: testContext) as! Preset
        preset.name = name
        preset.kit = kit
        preset.track = track
        preset.machine = "fmTone"
        return preset
    }
    
    private func createCompleteProjectHierarchy() -> Project {
        let project = createTestProject()
        
        // Create patterns
        for i in 1...4 {
            let pattern = createPattern(in: project, name: "Pattern \(i)")
            let kit = createKit(in: pattern, name: "Kit \(i)")
            
            // Create tracks
            for j in 1...8 {
                let track = createTrack(in: pattern, number: j)
                let preset = createPreset(in: kit, for: track, name: "Preset \(i)-\(j)")
                
                // Create trigs
                for k in stride(from: 0, to: 64, by: 4) {
                    let trig = NSEntityDescription.insertNewObject(forEntityName: "Trig", into: testContext) as! Trig
                    trig.step = Int16(k)
                    trig.velocity = 100
                    trig.track = track
                }
            }
        }
        
        return project
    }
    
    private func countEntities(entityName: String) throws -> Int {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        return try testContext.count(for: fetchRequest)
    }
    
    private func validateProjectIntegrity(_ project: Project) throws -> Bool {
        // Verify all relationships are valid
        guard project.name != nil,
              project.bpm > 0 && project.bpm <= 300 else {
            return false
        }
        
        // Check patterns
        if let patterns = project.patterns?.allObjects as? [Pattern] {
            for pattern in patterns {
                guard pattern.project == project,
                      pattern.name != nil else {
                    return false
                }
                
                // Check tracks
                if let tracks = pattern.tracks?.allObjects as? [Track] {
                    for track in tracks {
                        guard track.pattern == pattern,
                              track.number > 0 && track.number <= 16 else {
                            return false
                        }
                    }
                }
            }
        }
        
        return true
    }
}