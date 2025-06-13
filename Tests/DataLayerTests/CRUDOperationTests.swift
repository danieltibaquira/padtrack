import XCTest
import CoreData
@testable import DataLayer

/// Tests for CRUD operations on all entities
final class CRUDOperationTests: CoreDataTestBase {
    
    // MARK: - Project CRUD Tests
    
    func testCreateProject() throws {
        let project = projectRepository.createProject(name: "Test Project")
        
        XCTAssertEqual(project.name, "Test Project")
        XCTAssertNotNil(project.createdAt)
        XCTAssertNotNil(project.updatedAt)
        
        try saveContext()
        
        let count = try countEntities(ofType: Project.self)
        XCTAssertEqual(count, 1)
    }
    
    func testFetchAllProjects() throws {
        // Create multiple projects
        let project1 = projectRepository.createProject(name: "Project A")
        let project2 = projectRepository.createProject(name: "Project B")
        let project3 = projectRepository.createProject(name: "Project C")
        
        try saveContext()
        
        let projects = try projectRepository.fetchAllProjects()
        XCTAssertEqual(projects.count, 3)
        
        // Should be sorted by name
        XCTAssertEqual(projects[0].name, "Project A")
        XCTAssertEqual(projects[1].name, "Project B")
        XCTAssertEqual(projects[2].name, "Project C")
    }
    
    func testFindProjectByName() throws {
        let project = projectRepository.createProject(name: "Unique Project")
        try saveContext()
        
        let foundProject = try projectRepository.findProject(byName: "Unique Project")
        XCTAssertNotNil(foundProject)
        XCTAssertEqual(foundProject?.name, "Unique Project")
        
        let notFoundProject = try projectRepository.findProject(byName: "Non-existent Project")
        XCTAssertNil(notFoundProject)
    }
    
    func testDeleteProject() throws {
        let project = projectRepository.createProject(name: "To Delete")
        try saveContext()
        
        XCTAssertEqual(try countEntities(ofType: Project.self), 1)
        
        try projectRepository.delete(project)
        try saveContext()
        
        XCTAssertEqual(try countEntities(ofType: Project.self), 0)
    }
    
    // MARK: - Pattern CRUD Tests
    
    func testCreatePattern() throws {
        let project = createTestProject()
        let pattern = patternRepository.createPattern(name: "Test Pattern", project: project, length: 32, tempo: 140.0)
        
        XCTAssertEqual(pattern.name, "Test Pattern")
        XCTAssertEqual(pattern.length, 32)
        XCTAssertEqual(pattern.tempo, 140.0)
        XCTAssertEqual(pattern.project, project)
        
        try saveContext()
        
        let count = try countEntities(ofType: Pattern.self)
        XCTAssertEqual(count, 1)
    }
    
    func testFetchPatternsForProject() throws {
        let project1 = createTestProject(name: "Project 1")
        let project2 = createTestProject(name: "Project 2")
        
        let pattern1 = patternRepository.createPattern(name: "Pattern 1", project: project1)
        let pattern2 = patternRepository.createPattern(name: "Pattern 2", project: project1)
        let pattern3 = patternRepository.createPattern(name: "Pattern 3", project: project2)
        
        try saveContext()
        
        let project1Patterns = try patternRepository.fetchPatterns(for: project1)
        XCTAssertEqual(project1Patterns.count, 2)
        
        let project2Patterns = try patternRepository.fetchPatterns(for: project2)
        XCTAssertEqual(project2Patterns.count, 1)
    }
    
    func testFetchPatternsByTempoRange() throws {
        let project = createTestProject()
        
        let slowPattern = patternRepository.createPattern(name: "Slow", project: project, tempo: 80.0)
        let mediumPattern = patternRepository.createPattern(name: "Medium", project: project, tempo: 120.0)
        let fastPattern = patternRepository.createPattern(name: "Fast", project: project, tempo: 160.0)
        
        try saveContext()
        
        let mediumRangePatterns = try patternRepository.fetchPatterns(tempoRange: 100.0, maxTempo: 140.0)
        XCTAssertEqual(mediumRangePatterns.count, 1)
        XCTAssertEqual(mediumRangePatterns.first?.name, "Medium")
    }
    
    // MARK: - Track CRUD Tests
    
    func testCreateTrack() throws {
        let (_, pattern, _, _) = try createTestHierarchy()
        let track = trackRepository.createTrack(name: "Test Track", pattern: pattern, trackIndex: 5)
        
        XCTAssertEqual(track.name, "Test Track")
        XCTAssertEqual(track.trackIndex, 5)
        XCTAssertEqual(track.pattern, pattern)
        XCTAssertEqual(track.volume, 0.75) // Default value
        XCTAssertEqual(track.pan, 0.0) // Default value
        XCTAssertFalse(track.isMuted) // Default value
        XCTAssertFalse(track.isSolo) // Default value
        
        try saveContext()
        
        let count = try countEntities(ofType: Track.self)
        XCTAssertEqual(count, 2) // One from createTestHierarchy + one we just created
    }
    
    func testFetchTracksForPattern() throws {
        let (_, pattern, _, _) = try createTestHierarchy()
        
        // Create additional tracks
        let track2 = trackRepository.createTrack(name: "Track 2", pattern: pattern, trackIndex: 1)
        let track3 = trackRepository.createTrack(name: "Track 3", pattern: pattern, trackIndex: 2)
        
        try saveContext()
        
        let tracks = try trackRepository.fetchTracks(for: pattern)
        XCTAssertEqual(tracks.count, 3)
        
        // Should be sorted by trackIndex
        XCTAssertEqual(tracks[0].trackIndex, 0)
        XCTAssertEqual(tracks[1].trackIndex, 1)
        XCTAssertEqual(tracks[2].trackIndex, 2)
    }
    
    func testFetchMutedAndSoloTracks() throws {
        let (_, pattern, track1, _) = try createTestHierarchy()
        
        let track2 = trackRepository.createTrack(name: "Track 2", pattern: pattern, trackIndex: 1)
        let track3 = trackRepository.createTrack(name: "Track 3", pattern: pattern, trackIndex: 2)
        
        // Set mute and solo states
        track1.isMuted = true
        track2.isSolo = true
        
        try saveContext()
        
        let mutedTracks = try trackRepository.fetchMutedTracks()
        XCTAssertEqual(mutedTracks.count, 1)
        XCTAssertEqual(mutedTracks.first?.name, track1.name)
        
        let soloTracks = try trackRepository.fetchSoloTracks()
        XCTAssertEqual(soloTracks.count, 1)
        XCTAssertEqual(soloTracks.first?.name, track2.name)
    }
    
    // MARK: - Trig CRUD Tests
    
    func testCreateTrig() throws {
        let (_, _, track, _) = try createTestHierarchy()
        let trig = trigRepository.createTrig(step: 8, note: 72, velocity: 110, track: track)
        
        XCTAssertEqual(trig.step, 8)
        XCTAssertEqual(trig.note, 72)
        XCTAssertEqual(trig.velocity, 110)
        XCTAssertEqual(trig.track, track)
        XCTAssertEqual(trig.pattern, track.pattern)
        XCTAssertTrue(trig.isActive)
        
        try saveContext()
        
        let count = try countEntities(ofType: Trig.self)
        XCTAssertEqual(count, 2) // One from createTestHierarchy + one we just created
    }
    
    func testFetchTrigsForTrack() throws {
        let (_, _, track, _) = try createTestHierarchy()
        
        // Create additional trigs
        let trig2 = trigRepository.createTrig(step: 4, note: 64, velocity: 90, track: track)
        let trig3 = trigRepository.createTrig(step: 12, note: 67, velocity: 100, track: track)
        
        try saveContext()
        
        let trigs = try trigRepository.fetchTrigs(for: track)
        XCTAssertEqual(trigs.count, 3)
        
        // Should be sorted by step
        XCTAssertEqual(trigs[0].step, 0) // From createTestHierarchy
        XCTAssertEqual(trigs[1].step, 4)
        XCTAssertEqual(trigs[2].step, 12)
    }
    
    func testFetchActiveTrigs() throws {
        let (_, _, track, trig1) = try createTestHierarchy()
        
        let trig2 = trigRepository.createTrig(step: 4, note: 64, velocity: 90, track: track)
        let trig3 = trigRepository.createTrig(step: 8, note: 67, velocity: 100, track: track)
        
        // Set one trig to inactive
        trig2.isActive = false
        
        try saveContext()
        
        let activeTrigs = try trigRepository.fetchActiveTrigs(for: track)
        XCTAssertEqual(activeTrigs.count, 2)
        
        let allTrigs = try trigRepository.fetchTrigs(for: track)
        XCTAssertEqual(allTrigs.count, 3)
    }
    
    func testFetchTrigsInStepRange() throws {
        let (_, _, track, _) = try createTestHierarchy()
        
        // Create trigs at various steps
        let trig2 = trigRepository.createTrig(step: 4, note: 64, velocity: 90, track: track)
        let trig3 = trigRepository.createTrig(step: 8, note: 67, velocity: 100, track: track)
        let trig4 = trigRepository.createTrig(step: 12, note: 69, velocity: 105, track: track)
        
        try saveContext()
        
        let rangeTrigs = try trigRepository.fetchTrigs(startStep: 3, endStep: 9, track: track)
        XCTAssertEqual(rangeTrigs.count, 2) // Steps 4 and 8
        XCTAssertEqual(rangeTrigs[0].step, 4)
        XCTAssertEqual(rangeTrigs[1].step, 8)
    }
    
    // MARK: - Kit CRUD Tests
    
    func testCreateKit() throws {
        let kit = kitRepository.createKit(name: "Test Kit")
        
        XCTAssertEqual(kit.name, "Test Kit")
        XCTAssertNotNil(kit.createdAt)
        XCTAssertNotNil(kit.updatedAt)
        
        try saveContext()
        
        let count = try countEntities(ofType: Kit.self)
        XCTAssertEqual(count, 1)
    }
    
    func testFetchAllKits() throws {
        let kit1 = kitRepository.createKit(name: "Kit A")
        let kit2 = kitRepository.createKit(name: "Kit B")
        let kit3 = kitRepository.createKit(name: "Kit C")
        
        try saveContext()
        
        let kits = try kitRepository.fetchAllKits()
        XCTAssertEqual(kits.count, 3)
        
        // Should be sorted by name
        XCTAssertEqual(kits[0].name, "Kit A")
        XCTAssertEqual(kits[1].name, "Kit B")
        XCTAssertEqual(kits[2].name, "Kit C")
    }
    
    func testFindKitByName() throws {
        let kit = kitRepository.createKit(name: "Unique Kit")
        try saveContext()
        
        let foundKit = try kitRepository.findKit(byName: "Unique Kit")
        XCTAssertNotNil(foundKit)
        XCTAssertEqual(foundKit?.name, "Unique Kit")
        
        let notFoundKit = try kitRepository.findKit(byName: "Non-existent Kit")
        XCTAssertNil(notFoundKit)
    }
    
    // MARK: - Preset CRUD Tests
    
    func testCreatePreset() throws {
        let project = createTestProject()
        let preset = presetRepository.createPreset(name: "Test Preset", project: project)
        
        XCTAssertEqual(preset.name, "Test Preset")
        XCTAssertEqual(preset.project, project)
        XCTAssertNotNil(preset.createdAt)
        XCTAssertNotNil(preset.updatedAt)
        
        try saveContext()
        
        let count = try countEntities(ofType: Preset.self)
        XCTAssertEqual(count, 1)
    }
    
    func testFetchPresetsForProject() throws {
        let project1 = createTestProject(name: "Project 1")
        let project2 = createTestProject(name: "Project 2")
        
        let preset1 = presetRepository.createPreset(name: "Preset 1", project: project1)
        let preset2 = presetRepository.createPreset(name: "Preset 2", project: project1)
        let preset3 = presetRepository.createPreset(name: "Preset 3", project: project2)
        
        try saveContext()
        
        let project1Presets = try presetRepository.fetchPresets(for: project1)
        XCTAssertEqual(project1Presets.count, 2)
        
        let project2Presets = try presetRepository.fetchPresets(for: project2)
        XCTAssertEqual(project2Presets.count, 1)
    }
    
    func testFindPresetByNameInProject() throws {
        let project = createTestProject()
        let preset = presetRepository.createPreset(name: "Unique Preset", project: project)
        try saveContext()
        
        let foundPreset = try presetRepository.findPreset(byName: "Unique Preset", in: project)
        XCTAssertNotNil(foundPreset)
        XCTAssertEqual(foundPreset?.name, "Unique Preset")
        
        let notFoundPreset = try presetRepository.findPreset(byName: "Non-existent Preset", in: project)
        XCTAssertNil(notFoundPreset)
    }
    
    // MARK: - Batch Operations Tests
    
    func testBatchDelete() throws {
        // Create multiple projects
        for i in 1...5 {
            _ = projectRepository.createProject(name: "Project \(i)")
        }
        try saveContext()
        
        XCTAssertEqual(try countEntities(ofType: Project.self), 5)
        
        // Delete all projects
        let allProjects = try projectRepository.fetchAllProjects()
        for project in allProjects {
            try projectRepository.delete(project)
        }
        try saveContext()
        
        XCTAssertEqual(try countEntities(ofType: Project.self), 0)
    }
    
    func testTransactionRollback() throws {
        let project = createTestProject()
        try saveContext()
        
        XCTAssertEqual(try countEntities(ofType: Project.self), 1)
        
        // Start a transaction that will fail
        do {
            let invalidProject = Project(context: testContext)
            invalidProject.name = "" // This should cause validation to fail
            try saveContext()
            XCTFail("Should have thrown validation error")
        } catch {
            // Expected to fail
            testContext.rollback()
        }
        
        // Original project should still exist
        XCTAssertEqual(try countEntities(ofType: Project.self), 1)
    }
}
