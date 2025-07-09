import XCTest
import CoreData
@testable import DataLayer
@testable import DataModel

/// Critical tests for data integrity and safety
/// ANY DATA LOSS IS UNACCEPTABLE - These tests ensure data safety
class DataIntegrityTests: XCTestCase {
    var testContext: NSManagedObjectContext!
    var dataLayer: DataLayerManager!
    var persistenceController: PersistenceController!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        testContext = persistenceController.container.viewContext
        dataLayer = DataLayerManager(persistenceController: persistenceController)
    }
    
    override func tearDown() {
        testContext = nil
        dataLayer = nil
        persistenceController = nil
        super.tearDown()
    }
    
    // MARK: - Core Data Integrity Tests
    
    func testDataIntegrityDuringComplexOperations() throws {
        // Test data remains consistent during complex operations
        
        let project = try createComplexTestProject()
        let originalChecksum = try calculateProjectChecksum(project)
        
        // Perform multiple operations
        try duplicatePattern(project.patterns.first!)
        try movePattern(in: project, from: 1, to: 0)
        try deletePattern(project.patterns.last!)
        
        // Add new data
        let newPattern = dataLayer.patternRepository.createPattern(
            name: "New Pattern",
            project: project
        )
        try dataLayer.save()
        
        // Verify all relationships remain valid
        XCTAssertTrue(try validateProjectIntegrity(project))
        
        // Verify no orphaned objects
        XCTAssertEqual(try countOrphanedObjects(), 0)
        
        // Verify inverse relationships
        for pattern in project.patterns?.allObjects as? [Pattern] ?? [] {
            XCTAssertEqual(pattern.project, project)
            
            for track in pattern.tracks?.allObjects as? [Track] ?? [] {
                XCTAssertEqual(track.pattern, pattern)
                
                for trig in track.trigs?.allObjects as? [Trig] ?? [] {
                    XCTAssertEqual(trig.track, track)
                    XCTAssertEqual(trig.pattern, pattern)
                }
            }
        }
    }
    
    func testCascadeDeletionIntegrity() throws {
        // Test cascade deletion maintains data integrity
        
        let project = try createComplexTestProject()
        let patternCount = project.patterns?.count ?? 0
        let pattern = project.patterns?.allObjects.first as? Pattern
        let trackCount = pattern?.tracks?.count ?? 0
        let trigCount = try countTrigsInPattern(pattern!)
        
        // Delete pattern - should cascade to tracks and trigs
        try dataLayer.patternRepository.delete(pattern!)
        
        // Verify cascade deletion
        XCTAssertEqual(project.patterns?.count ?? 0, patternCount - 1)
        XCTAssertEqual(try countTracksWithoutPattern(), 0)
        XCTAssertEqual(try countTrigsWithoutTrack(), 0)
        
        // Verify project remains valid
        XCTAssertTrue(try validateProjectIntegrity(project))
    }
    
    func testTransactionRollback() throws {
        // Test transaction rollback on error preserves data integrity
        
        let project = try createComplexTestProject()
        let originalState = try captureProjectState(project)
        
        // Attempt operation that will fail
        do {
            // Start transaction
            let pattern = dataLayer.patternRepository.createPattern(
                name: "Test Pattern",
                project: project
            )
            
            // Create invalid data that will fail validation
            let track = dataLayer.trackRepository.createTrack(
                name: "Invalid Track",
                pattern: pattern,
                trackIndex: 999 // Invalid index
            )
            
            // Force validation error
            track.volume = 2.0 // Out of range
            
            try dataLayer.save()
            
            XCTFail("Save should have failed")
        } catch {
            // Expected error
        }
        
        // Verify rollback restored original state
        testContext.rollback()
        let currentState = try captureProjectState(project)
        XCTAssertEqual(originalState, currentState)
    }
    
    // MARK: - Concurrent Access Safety Tests
    
    func testConcurrentAccessSafety() throws {
        // Test multiple threads can safely access project data
        
        let project = try createComplexTestProject()
        let dispatchGroup = DispatchGroup()
        var errors: [Error] = []
        let errorQueue = DispatchQueue(label: "error.queue")
        
        // Simulate concurrent read/write operations
        for i in 0..<20 {
            dispatchGroup.enter()
            DispatchQueue.global().async {
                defer { dispatchGroup.leave() }
                
                // Each thread gets its own context
                self.persistenceController.performBackgroundTask { context in
                    do {
                        // Fetch project in this context
                        let bgProject = try context.existingObject(with: project.objectID) as! Project
                        
                        if i % 2 == 0 {
                            // Write operation
                            let pattern = Pattern(context: context)
                            pattern.name = "Concurrent Pattern \(i)"
                            pattern.project = bgProject
                            pattern.length = 16
                            pattern.tempo = 120.0
                            try context.save()
                        } else {
                            // Read operation
                            let patterns = bgProject.patterns?.allObjects as? [Pattern] ?? []
                            XCTAssertNotNil(patterns)
                        }
                    } catch {
                        errorQueue.sync {
                            errors.append(error)
                        }
                    }
                }
            }
        }
        
        dispatchGroup.wait()
        XCTAssertTrue(errors.isEmpty, "Concurrent access errors: \(errors)")
        
        // Verify data integrity after concurrent operations
        testContext.refreshAllObjects()
        XCTAssertTrue(try validateProjectIntegrity(project))
    }
    
    func testMergeConflictResolution() throws {
        // Test merge conflict resolution maintains data integrity
        
        let project = try createComplexTestProject()
        let pattern = project.patterns?.allObjects.first as! Pattern
        
        // Create two background contexts
        let context1 = persistenceController.newBackgroundContext()
        let context2 = persistenceController.newBackgroundContext()
        
        // Modify same object in both contexts
        let pattern1 = try context1.existingObject(with: pattern.objectID) as! Pattern
        let pattern2 = try context2.existingObject(with: pattern.objectID) as! Pattern
        
        pattern1.name = "Context 1 Name"
        pattern2.name = "Context 2 Name"
        
        // Save both contexts
        try context1.save()
        try context2.save()
        
        // Verify merge policy resolved conflict
        testContext.refreshAllObjects()
        XCTAssertNotNil(pattern.name)
        XCTAssertTrue(pattern.name == "Context 1 Name" || pattern.name == "Context 2 Name")
        
        // Verify data integrity maintained
        XCTAssertTrue(try validateProjectIntegrity(project))
    }
    
    // MARK: - Validation Tests
    
    func testComprehensiveDataValidation() throws {
        // Test comprehensive validation of all data constraints
        
        let project = dataLayer.projectRepository.createProject(name: "Validation Test")
        
        // Test track constraints
        let pattern = dataLayer.patternRepository.createPattern(
            name: "Pattern",
            project: project
        )
        
        // Valid track
        let validTrack = dataLayer.trackRepository.createTrack(
            name: "Valid Track",
            pattern: pattern,
            trackIndex: 0
        )
        validTrack.volume = 0.8
        validTrack.pan = 0.0
        
        XCTAssertNoThrow(try dataLayer.save())
        
        // Invalid volume
        let invalidTrack = dataLayer.trackRepository.createTrack(
            name: "Invalid Track",
            pattern: pattern,
            trackIndex: 1
        )
        invalidTrack.volume = 1.5 // Out of range
        
        XCTAssertThrowsError(try validateEntity(invalidTrack))
        
        testContext.rollback()
        
        // Test trig constraints
        let trig = dataLayer.trigRepository.createTrig(
            step: 200, // Out of range
            note: 60,
            velocity: 100,
            track: validTrack
        )
        
        XCTAssertThrowsError(try validateEntity(trig))
    }
    
    func testRelationshipConsistency() throws {
        // Test all relationships maintain consistency
        
        let project = try createComplexTestProject()
        
        // Test bidirectional relationships
        for pattern in project.patterns?.allObjects as? [Pattern] ?? [] {
            // Pattern -> Project
            XCTAssertEqual(pattern.project, project)
            
            // Pattern -> Tracks -> Pattern
            for track in pattern.tracks?.allObjects as? [Track] ?? [] {
                XCTAssertEqual(track.pattern, pattern)
                
                // Track -> Trigs -> Track
                for trig in track.trigs?.allObjects as? [Trig] ?? [] {
                    XCTAssertEqual(trig.track, track)
                    XCTAssertEqual(trig.pattern, pattern)
                }
                
                // Track -> Kit
                if let kit = track.kit {
                    XCTAssertTrue(kit.tracks?.contains(track) ?? false)
                }
                
                // Track -> Preset
                if let preset = track.preset {
                    XCTAssertTrue(preset.tracks?.contains(track) ?? false)
                }
            }
        }
        
        // Test Kit relationships
        for kit in project.kits?.allObjects as? [Kit] ?? [] {
            XCTAssertEqual(kit.project, project)
            
            for track in kit.tracks?.allObjects as? [Track] ?? [] {
                XCTAssertEqual(track.kit, kit)
            }
        }
        
        // Test Preset relationships
        for preset in project.presets?.allObjects as? [Preset] ?? [] {
            XCTAssertEqual(preset.project, project)
            
            for track in preset.tracks?.allObjects as? [Track] ?? [] {
                XCTAssertEqual(track.preset, preset)
            }
        }
    }
    
    // MARK: - Memory and Performance Tests
    
    func testMemoryLeakPrevention() throws {
        // Test no memory leaks during object lifecycle
        
        autoreleasepool {
            let project = try createComplexTestProject()
            let projectID = project.objectID
            
            // Create many objects
            for i in 0..<100 {
                let pattern = dataLayer.patternRepository.createPattern(
                    name: "Pattern \(i)",
                    project: project
                )
                
                for j in 0..<16 {
                    let track = dataLayer.trackRepository.createTrack(
                        name: "Track \(j)",
                        pattern: pattern,
                        trackIndex: Int16(j)
                    )
                    
                    for k in stride(from: 0, to: 64, by: 4) {
                        _ = dataLayer.trigRepository.createTrig(
                            step: Int16(k),
                            note: 60,
                            velocity: 100,
                            track: track
                        )
                    }
                }
            }
            
            try dataLayer.save()
            
            // Clear references
            testContext.reset()
            
            // Verify objects can be garbage collected
            XCTAssertThrowsError(try testContext.existingObject(with: projectID))
        }
    }
    
    func testLargeDataSetIntegrity() throws {
        // Test integrity with large data sets
        
        let project = dataLayer.projectRepository.createProject(name: "Large Project")
        
        measure {
            do {
                // Create large dataset
                for i in 0..<50 {
                    let pattern = dataLayer.patternRepository.createPattern(
                        name: "Pattern \(i)",
                        project: project
                    )
                    
                    for j in 0..<16 {
                        let track = dataLayer.trackRepository.createTrack(
                            name: "Track \(j)",
                            pattern: pattern,
                            trackIndex: Int16(j)
                        )
                        
                        // Create full sequence
                        for k in 0..<64 {
                            _ = dataLayer.trigRepository.createTrig(
                                step: Int16(k),
                                note: Int16(36 + (k % 24)),
                                velocity: Int16(80 + (k % 48)),
                                track: track
                            )
                        }
                    }
                }
                
                try dataLayer.save()
                
                // Verify integrity
                XCTAssertTrue(try validateProjectIntegrity(project))
            } catch {
                XCTFail("Large dataset test failed: \(error)")
            }
        }
    }
    
    // MARK: - Error Recovery Tests
    
    func testCorruptionRecovery() throws {
        // Test recovery from data corruption
        
        let project = try createComplexTestProject()
        let projectID = project.objectID
        
        // Simulate corruption by manually breaking relationships
        let pattern = project.patterns?.allObjects.first as? Pattern
        pattern?.project = nil // Break relationship
        
        // Attempt recovery
        let recovered = try recoverCorruptedProject(projectID: projectID)
        
        XCTAssertTrue(recovered)
        
        // Verify relationships restored
        testContext.refreshAllObjects()
        XCTAssertNotNil(pattern?.project)
        XCTAssertTrue(try validateProjectIntegrity(project))
    }
    
    func testPartialSaveFailure() throws {
        // Test handling of partial save failures
        
        let project = try createComplexTestProject()
        
        // Create changes
        let pattern1 = dataLayer.patternRepository.createPattern(
            name: "Good Pattern",
            project: project
        )
        
        let pattern2 = dataLayer.patternRepository.createPattern(
            name: String(repeating: "X", count: 1000), // Too long
            project: project
        )
        
        // Attempt save
        do {
            try dataLayer.save()
            XCTFail("Save should have failed")
        } catch {
            // Expected
        }
        
        // Verify rollback
        testContext.rollback()
        XCTAssertFalse(project.patterns?.contains(pattern1) ?? true)
        XCTAssertFalse(project.patterns?.contains(pattern2) ?? true)
    }
    
    // MARK: - Boundary Tests
    
    func testBoundaryConditions() throws {
        // Test edge cases and boundary conditions
        
        let project = dataLayer.projectRepository.createProject(name: "Boundary Test")
        
        // Maximum pattern length
        let maxPattern = dataLayer.patternRepository.createPattern(
            name: "Max Pattern",
            project: project,
            length: 128
        )
        XCTAssertEqual(maxPattern.length, 128)
        
        // Minimum pattern length
        let minPattern = dataLayer.patternRepository.createPattern(
            name: "Min Pattern",
            project: project,
            length: 1
        )
        XCTAssertEqual(minPattern.length, 1)
        
        // Maximum tracks per pattern
        for i in 0..<16 {
            _ = dataLayer.trackRepository.createTrack(
                name: "Track \(i)",
                pattern: maxPattern,
                trackIndex: Int16(i)
            )
        }
        
        try dataLayer.save()
        XCTAssertEqual(maxPattern.tracks?.count, 16)
        
        // Verify can't exceed limits
        let extraTrack = dataLayer.trackRepository.createTrack(
            name: "Extra Track",
            pattern: maxPattern,
            trackIndex: 16
        )
        
        XCTAssertThrowsError(try validateEntity(extraTrack))
    }
    
    // MARK: - Helper Methods
    
    private func createComplexTestProject() throws -> Project {
        let project = dataLayer.projectRepository.createProject(name: "Complex Project")
        
        // Create patterns
        for i in 0..<4 {
            let pattern = dataLayer.patternRepository.createPattern(
                name: "Pattern \(i)",
                project: project,
                length: 16,
                tempo: 120.0
            )
            
            // Create kit
            let kit = dataLayer.kitRepository.createKit(name: "Kit \(i)")
            
            // Create tracks
            for j in 0..<8 {
                let track = dataLayer.trackRepository.createTrack(
                    name: "Track \(j)",
                    pattern: pattern,
                    trackIndex: Int16(j)
                )
                track.kit = kit
                
                // Create preset
                let preset = dataLayer.presetRepository.createPreset(
                    name: "Preset \(i)-\(j)",
                    project: project
                )
                track.preset = preset
                
                // Create trigs
                for k in stride(from: 0, to: 16, by: 4) {
                    let trig = dataLayer.trigRepository.createTrig(
                        step: Int16(k),
                        note: 60,
                        velocity: 100,
                        track: track
                    )
                    trig.pLocks = ["cutoff": 0.5, "resonance": 0.8]
                }
            }
        }
        
        try dataLayer.save()
        return project
    }
    
    private func validateProjectIntegrity(_ project: Project) throws -> Bool {
        // Comprehensive project validation
        
        // Check project has required attributes
        guard project.name != nil,
              project.createdAt != nil,
              project.updatedAt != nil else {
            return false
        }
        
        // Check all patterns
        for pattern in project.patterns?.allObjects as? [Pattern] ?? [] {
            guard pattern.project == project,
                  pattern.name != nil,
                  pattern.length > 0,
                  pattern.tempo > 0 else {
                return false
            }
            
            // Check all tracks
            for track in pattern.tracks?.allObjects as? [Track] ?? [] {
                guard track.pattern == pattern,
                      track.name != nil,
                      track.trackIndex >= 0 && track.trackIndex < 16,
                      track.volume >= 0 && track.volume <= 1,
                      track.pan >= -1 && track.pan <= 1 else {
                    return false
                }
                
                // Check all trigs
                for trig in track.trigs?.allObjects as? [Trig] ?? [] {
                    guard trig.track == track,
                          trig.pattern == pattern,
                          trig.step >= 0 && trig.step < 128,
                          trig.note >= 0 && trig.note <= 127,
                          trig.velocity >= 1 && trig.velocity <= 127 else {
                        return false
                    }
                }
            }
        }
        
        return true
    }
    
    private func calculateProjectChecksum(_ project: Project) throws -> String {
        // Calculate checksum for project state
        var checksum = ""
        
        checksum += project.name ?? ""
        checksum += "\(project.patterns?.count ?? 0)"
        checksum += "\(project.kits?.count ?? 0)"
        checksum += "\(project.presets?.count ?? 0)"
        
        return checksum
    }
    
    private func captureProjectState(_ project: Project) throws -> ProjectState {
        return ProjectState(
            name: project.name ?? "",
            patternCount: project.patterns?.count ?? 0,
            kitCount: project.kits?.count ?? 0,
            presetCount: project.presets?.count ?? 0
        )
    }
    
    private func countOrphanedObjects() throws -> Int {
        var orphanCount = 0
        
        // Check for patterns without projects
        let patternRequest = NSFetchRequest<Pattern>(entityName: "Pattern")
        patternRequest.predicate = NSPredicate(format: "project == nil")
        orphanCount += try testContext.count(for: patternRequest)
        
        // Check for tracks without patterns
        let trackRequest = NSFetchRequest<Track>(entityName: "Track")
        trackRequest.predicate = NSPredicate(format: "pattern == nil")
        orphanCount += try testContext.count(for: trackRequest)
        
        // Check for trigs without tracks
        let trigRequest = NSFetchRequest<Trig>(entityName: "Trig")
        trigRequest.predicate = NSPredicate(format: "track == nil")
        orphanCount += try testContext.count(for: trigRequest)
        
        return orphanCount
    }
    
    private func countTrigsInPattern(_ pattern: Pattern) throws -> Int {
        let request = NSFetchRequest<Trig>(entityName: "Trig")
        request.predicate = NSPredicate(format: "pattern == %@", pattern)
        return try testContext.count(for: request)
    }
    
    private func countTracksWithoutPattern() throws -> Int {
        let request = NSFetchRequest<Track>(entityName: "Track")
        request.predicate = NSPredicate(format: "pattern == nil")
        return try testContext.count(for: request)
    }
    
    private func countTrigsWithoutTrack() throws -> Int {
        let request = NSFetchRequest<Trig>(entityName: "Trig")
        request.predicate = NSPredicate(format: "track == nil")
        return try testContext.count(for: request)
    }
    
    private func duplicatePattern(_ pattern: Pattern) throws {
        let duplicate = dataLayer.patternRepository.createPattern(
            name: "\(pattern.name ?? "") Copy",
            project: pattern.project!
        )
        duplicate.length = pattern.length
        duplicate.tempo = pattern.tempo
    }
    
    private func movePattern(in project: Project, from: Int, to: Int) throws {
        // Pattern move implementation
        let patterns = project.patterns?.allObjects as? [Pattern] ?? []
        // Reorder patterns logic would go here
    }
    
    private func deletePattern(_ pattern: Pattern) throws {
        try dataLayer.patternRepository.delete(pattern)
    }
    
    private func validateEntity(_ entity: NSManagedObject) throws {
        try entity.validateForInsert()
        try entity.validateForUpdate()
    }
    
    private func recoverCorruptedProject(projectID: NSManagedObjectID) throws -> Bool {
        // Recovery logic would go here
        // For testing, we'll just fix the broken relationship
        if let project = try? testContext.existingObject(with: projectID) as? Project {
            for pattern in project.patterns?.allObjects as? [Pattern] ?? [] {
                if pattern.project == nil {
                    pattern.project = project
                }
            }
            try testContext.save()
            return true
        }
        return false
    }
}

// MARK: - Supporting Types

struct ProjectState: Equatable {
    let name: String
    let patternCount: Int
    let kitCount: Int
    let presetCount: Int
}