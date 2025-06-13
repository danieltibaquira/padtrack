import XCTest
import CoreData
@testable import DataLayer

/// Tests for entity relationships and cascade behavior
final class RelationshipTests: CoreDataTestBase {
    
    // MARK: - Project Relationships Tests
    
    func testProjectToPatternRelationship() throws {
        let project = createTestProject()
        
        // Initially no patterns
        assertRelationshipCount(project, keyPath: "patterns", expectedCount: 0)
        
        // Add patterns
        let pattern1 = createTestPattern(name: "Pattern 1", project: project)
        let pattern2 = createTestPattern(name: "Pattern 2", project: project)
        
        try saveContext()
        
        // Check forward relationship
        assertRelationshipCount(project, keyPath: "patterns", expectedCount: 2)
        
        // Check inverse relationship
        XCTAssertEqual(pattern1.project, project)
        XCTAssertEqual(pattern2.project, project)
    }
    
    func testProjectToKitRelationship() throws {
        let project = createTestProject()
        
        // Create kits for the project
        let kit1 = createTestKit(name: "Kit 1")
        let kit2 = createTestKit(name: "Kit 2")
        
        kit1.project = project
        kit2.project = project
        
        try saveContext()
        
        // Check forward relationship
        assertRelationshipCount(project, keyPath: "kits", expectedCount: 2)
        
        // Check inverse relationship
        XCTAssertEqual(kit1.project, project)
        XCTAssertEqual(kit2.project, project)
    }
    
    func testProjectToPresetRelationship() throws {
        let project = createTestProject()
        
        // Create presets for the project
        let preset1 = createTestPreset(name: "Preset 1", project: project)
        let preset2 = createTestPreset(name: "Preset 2", project: project)
        
        try saveContext()
        
        // Check forward relationship
        assertRelationshipCount(project, keyPath: "presets", expectedCount: 2)
        
        // Check inverse relationship
        XCTAssertEqual(preset1.project, project)
        XCTAssertEqual(preset2.project, project)
    }
    
    func testProjectCascadeDelete() throws {
        let project = createTestProject()
        let pattern = createTestPattern(project: project)
        let kit = createTestKit()
        let preset = createTestPreset(project: project)
        
        kit.project = project
        
        try saveContext()
        
        // Verify entities exist
        XCTAssertEqual(try countEntities(ofType: Project.self), 1)
        XCTAssertEqual(try countEntities(ofType: Pattern.self), 1)
        XCTAssertEqual(try countEntities(ofType: Kit.self), 1)
        XCTAssertEqual(try countEntities(ofType: Preset.self), 1)
        
        // Delete project
        try projectRepository.delete(project)
        try saveContext()
        
        // Check cascade delete behavior
        XCTAssertEqual(try countEntities(ofType: Project.self), 0)
        XCTAssertEqual(try countEntities(ofType: Pattern.self), 0) // Should cascade
        XCTAssertEqual(try countEntities(ofType: Kit.self), 0) // Should cascade
        XCTAssertEqual(try countEntities(ofType: Preset.self), 0) // Should cascade
    }
    
    // MARK: - Pattern Relationships Tests
    
    func testPatternToTrackRelationship() throws {
        let project = createTestProject()
        let pattern = createTestPattern(project: project)
        
        // Initially no tracks
        assertRelationshipCount(pattern, keyPath: "tracks", expectedCount: 0)
        
        // Add tracks
        let track1 = createTestTrack(name: "Track 1", pattern: pattern, trackIndex: 0)
        let track2 = createTestTrack(name: "Track 2", pattern: pattern, trackIndex: 1)
        
        try saveContext()
        
        // Check forward relationship
        assertRelationshipCount(pattern, keyPath: "tracks", expectedCount: 2)
        
        // Check inverse relationship
        XCTAssertEqual(track1.pattern, pattern)
        XCTAssertEqual(track2.pattern, pattern)
    }
    
    func testPatternToTrigRelationship() throws {
        let (_, pattern, track, _) = try createTestHierarchy()
        
        // Create additional trigs
        let trig2 = createTestTrig(step: 4, track: track)
        let trig3 = createTestTrig(step: 8, track: track)
        
        try saveContext()
        
        // Check forward relationship (should have 3 trigs total)
        assertRelationshipCount(pattern, keyPath: "trigs", expectedCount: 3)
        
        // Check inverse relationship
        XCTAssertEqual(trig2.pattern, pattern)
        XCTAssertEqual(trig3.pattern, pattern)
    }
    
    func testPatternCascadeDelete() throws {
        let (project, pattern, track, trig) = try createTestHierarchy()
        
        // Create additional track and trig
        let track2 = createTestTrack(name: "Track 2", pattern: pattern, trackIndex: 1)
        let trig2 = createTestTrig(step: 4, track: track2)
        
        try saveContext()
        
        // Verify entities exist
        XCTAssertEqual(try countEntities(ofType: Pattern.self), 1)
        XCTAssertEqual(try countEntities(ofType: Track.self), 2)
        XCTAssertEqual(try countEntities(ofType: Trig.self), 2)
        
        // Delete pattern
        try patternRepository.delete(pattern)
        try saveContext()
        
        // Check cascade delete behavior
        XCTAssertEqual(try countEntities(ofType: Pattern.self), 0)
        XCTAssertEqual(try countEntities(ofType: Track.self), 0) // Should cascade
        XCTAssertEqual(try countEntities(ofType: Trig.self), 0) // Should cascade
        
        // Project should still exist
        XCTAssertEqual(try countEntities(ofType: Project.self), 1)
    }
    
    // MARK: - Track Relationships Tests
    
    func testTrackToTrigRelationship() throws {
        let (_, _, track, _) = try createTestHierarchy()
        
        // Create additional trigs
        let trig2 = createTestTrig(step: 4, track: track)
        let trig3 = createTestTrig(step: 8, track: track)
        
        try saveContext()
        
        // Check forward relationship
        assertRelationshipCount(track, keyPath: "trigs", expectedCount: 3)
        
        // Check inverse relationship
        XCTAssertEqual(trig2.track, track)
        XCTAssertEqual(trig3.track, track)
    }
    
    func testTrackToKitRelationship() throws {
        let (_, pattern, _, _) = try createTestHierarchy()
        let kit = createTestKit()
        let track = createTestTrack(pattern: pattern, trackIndex: 1)
        
        // Set kit relationship
        track.kit = kit
        
        try saveContext()
        
        // Check forward relationship
        XCTAssertEqual(track.kit, kit)
        
        // Check inverse relationship
        assertRelationshipCount(kit, keyPath: "tracks", expectedCount: 1)
    }
    
    func testTrackToPresetRelationship() throws {
        let (project, pattern, _, _) = try createTestHierarchy()
        let preset = createTestPreset(project: project)
        let track = createTestTrack(pattern: pattern, trackIndex: 1)
        
        // Set preset relationship
        track.preset = preset
        
        try saveContext()
        
        // Check forward relationship
        XCTAssertEqual(track.preset, preset)
        
        // Check inverse relationship
        assertRelationshipCount(preset, keyPath: "tracks", expectedCount: 1)
    }
    
    func testTrackCascadeDelete() throws {
        let (_, _, track, _) = try createTestHierarchy()
        
        // Create additional trigs
        let trig2 = createTestTrig(step: 4, track: track)
        let trig3 = createTestTrig(step: 8, track: track)
        
        try saveContext()
        
        // Verify entities exist
        XCTAssertEqual(try countEntities(ofType: Track.self), 1)
        XCTAssertEqual(try countEntities(ofType: Trig.self), 3)
        
        // Delete track
        try trackRepository.delete(track)
        try saveContext()
        
        // Check cascade delete behavior
        XCTAssertEqual(try countEntities(ofType: Track.self), 0)
        XCTAssertEqual(try countEntities(ofType: Trig.self), 0) // Should cascade
    }
    
    // MARK: - Kit Relationships Tests
    
    func testKitToTrackRelationship() throws {
        let (_, pattern, _, _) = try createTestHierarchy()
        let kit = createTestKit()
        
        // Create tracks that use this kit
        let track1 = createTestTrack(name: "Track 1", pattern: pattern, trackIndex: 1)
        let track2 = createTestTrack(name: "Track 2", pattern: pattern, trackIndex: 2)
        
        track1.kit = kit
        track2.kit = kit
        
        try saveContext()
        
        // Check forward relationship
        assertRelationshipCount(kit, keyPath: "tracks", expectedCount: 2)
        
        // Check inverse relationship
        XCTAssertEqual(track1.kit, kit)
        XCTAssertEqual(track2.kit, kit)
    }
    
    func testKitDeleteWithTrackReferences() throws {
        let (_, pattern, _, _) = try createTestHierarchy()
        let kit = createTestKit()
        let track = createTestTrack(pattern: pattern, trackIndex: 1)
        
        track.kit = kit
        
        try saveContext()
        
        // Verify relationship exists
        XCTAssertEqual(track.kit, kit)
        assertRelationshipCount(kit, keyPath: "tracks", expectedCount: 1)
        
        // Delete kit
        try kitRepository.delete(kit)
        try saveContext()
        
        // Track should still exist but kit reference should be nil
        XCTAssertEqual(try countEntities(ofType: Track.self), 2) // Original + new track
        XCTAssertEqual(try countEntities(ofType: Kit.self), 0)
        XCTAssertNil(track.kit)
    }
    
    // MARK: - Preset Relationships Tests
    
    func testPresetToTrackRelationship() throws {
        let (project, pattern, _, _) = try createTestHierarchy()
        let preset = createTestPreset(project: project)
        
        // Create tracks that use this preset
        let track1 = createTestTrack(name: "Track 1", pattern: pattern, trackIndex: 1)
        let track2 = createTestTrack(name: "Track 2", pattern: pattern, trackIndex: 2)
        
        track1.preset = preset
        track2.preset = preset
        
        try saveContext()
        
        // Check forward relationship
        assertRelationshipCount(preset, keyPath: "tracks", expectedCount: 2)
        
        // Check inverse relationship
        XCTAssertEqual(track1.preset, preset)
        XCTAssertEqual(track2.preset, preset)
    }
    
    func testPresetDeleteWithTrackReferences() throws {
        let (project, pattern, _, _) = try createTestHierarchy()
        let preset = createTestPreset(project: project)
        let track = createTestTrack(pattern: pattern, trackIndex: 1)
        
        track.preset = preset
        
        try saveContext()
        
        // Verify relationship exists
        XCTAssertEqual(track.preset, preset)
        assertRelationshipCount(preset, keyPath: "tracks", expectedCount: 1)
        
        // Delete preset
        try presetRepository.delete(preset)
        try saveContext()
        
        // Track should still exist but preset reference should be nil
        XCTAssertEqual(try countEntities(ofType: Track.self), 2) // Original + new track
        XCTAssertEqual(try countEntities(ofType: Preset.self), 0)
        XCTAssertNil(track.preset)
    }
    
    // MARK: - Complex Relationship Tests
    
    func testCompleteHierarchyRelationships() throws {
        let project = createTestProject()
        let pattern = createTestPattern(project: project)
        let kit = createTestKit()
        let preset = createTestPreset(project: project)
        
        kit.project = project
        
        // Create tracks with kit and preset relationships
        let track1 = createTestTrack(name: "Track 1", pattern: pattern, trackIndex: 0)
        let track2 = createTestTrack(name: "Track 2", pattern: pattern, trackIndex: 1)
        
        track1.kit = kit
        track1.preset = preset
        track2.kit = kit
        
        // Create trigs for tracks
        let trig1 = createTestTrig(step: 0, track: track1)
        let trig2 = createTestTrig(step: 4, track: track1)
        let trig3 = createTestTrig(step: 8, track: track2)
        
        try saveContext()
        
        // Verify all relationships
        assertRelationshipCount(project, keyPath: "patterns", expectedCount: 1)
        assertRelationshipCount(project, keyPath: "kits", expectedCount: 1)
        assertRelationshipCount(project, keyPath: "presets", expectedCount: 1)
        
        assertRelationshipCount(pattern, keyPath: "tracks", expectedCount: 2)
        assertRelationshipCount(pattern, keyPath: "trigs", expectedCount: 3)
        
        assertRelationshipCount(track1, keyPath: "trigs", expectedCount: 2)
        assertRelationshipCount(track2, keyPath: "trigs", expectedCount: 1)
        
        assertRelationshipCount(kit, keyPath: "tracks", expectedCount: 2)
        assertRelationshipCount(preset, keyPath: "tracks", expectedCount: 1)
        
        // Verify inverse relationships
        XCTAssertEqual(pattern.project, project)
        XCTAssertEqual(kit.project, project)
        XCTAssertEqual(preset.project, project)
        
        XCTAssertEqual(track1.pattern, pattern)
        XCTAssertEqual(track2.pattern, pattern)
        XCTAssertEqual(track1.kit, kit)
        XCTAssertEqual(track2.kit, kit)
        XCTAssertEqual(track1.preset, preset)
        
        XCTAssertEqual(trig1.track, track1)
        XCTAssertEqual(trig2.track, track1)
        XCTAssertEqual(trig3.track, track2)
        XCTAssertEqual(trig1.pattern, pattern)
        XCTAssertEqual(trig2.pattern, pattern)
        XCTAssertEqual(trig3.pattern, pattern)
    }
    
    func testOrphanedEntityCleanup() throws {
        let (project, pattern, track, trig) = try createTestHierarchy()
        
        // Create orphaned entities (not properly linked)
        let orphanedPattern = Pattern(context: testContext)
        orphanedPattern.name = "Orphaned Pattern"
        orphanedPattern.length = 16
        orphanedPattern.tempo = 120.0
        // Note: No project relationship set
        
        let orphanedTrack = Track(context: testContext)
        orphanedTrack.name = "Orphaned Track"
        orphanedTrack.trackIndex = 0
        // Note: No pattern relationship set
        
        try saveContext()
        
        // Verify entities exist
        XCTAssertEqual(try countEntities(ofType: Pattern.self), 2)
        XCTAssertEqual(try countEntities(ofType: Track.self), 2)
        
        // Delete the project (should only cascade to properly linked entities)
        try projectRepository.delete(project)
        try saveContext()
        
        // Properly linked entities should be deleted
        XCTAssertEqual(try countEntities(ofType: Project.self), 0)
        
        // Orphaned entities should still exist (they weren't cascade deleted)
        let remainingPatterns = try fetchAllEntities(ofType: Pattern.self)
        let remainingTracks = try fetchAllEntities(ofType: Track.self)
        
        XCTAssertEqual(remainingPatterns.count, 1)
        XCTAssertEqual(remainingPatterns.first?.name, "Orphaned Pattern")
        
        XCTAssertEqual(remainingTracks.count, 1)
        XCTAssertEqual(remainingTracks.first?.name, "Orphaned Track")
    }
}
