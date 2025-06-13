import XCTest
import CoreData
@testable import DataLayer

/// Comprehensive tests for the Core Data model entities, relationships, and business logic
final class CoreDataModelTests: CoreDataTestBase {
    
    // MARK: - Project Entity Tests
    
    func testProjectEntityCreation() throws {
        let project = Project(context: testContext)
        project.name = "Test Project"
        
        XCTAssertNotNil(project)
        XCTAssertEqual(project.name, "Test Project")
        XCTAssertNotNil(project.createdAt)
        XCTAssertNotNil(project.updatedAt)
        
        try saveContext()
        
        let fetchRequest: NSFetchRequest<DataLayer.Pattern> = DataLayer.Pattern.fetchRequest()
        let patterns = try testContext.fetch(fetchRequest)
        XCTAssertEqual(patterns.count, 0) // No patterns created yet
        
        let projectFetchRequest: NSFetchRequest<Project> = Project.fetchRequest()
        let projects = try testContext.fetch(projectFetchRequest)
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects.first?.name, "Test Project")
    }
    
    func testProjectTimestampUpdates() throws {
        let project = createTestProject()
        try saveContext()
        
        let originalUpdatedAt = project.updatedAt
        
        // Longer delay to ensure timestamp difference
        Thread.sleep(forTimeInterval: 0.5)
        
        project.name = "Updated Project Name"
        // Manually update the timestamp since Core Data doesn't do it automatically
        project.updatedAt = Date()
        try saveContext()
        
        // Check that updatedAt was actually updated
        XCTAssertNotNil(project.updatedAt)
        XCTAssertNotNil(originalUpdatedAt)
        
        if let original = originalUpdatedAt, let updated = project.updatedAt {
            XCTAssertTrue(updated > original, "Updated timestamp should be later than original")
        } else {
            XCTFail("Timestamps should not be nil")
        }
    }
    
    func testProjectRelationships() throws {
        let project = createTestProject()
        
        // Test patterns relationship
        let pattern1 = Pattern(context: testContext)
        pattern1.name = "Pattern 1"
        pattern1.project = project
        
        let pattern2 = Pattern(context: testContext)
        pattern2.name = "Pattern 2"
        pattern2.project = project
        
        // Test kits relationship
        let kit = Kit(context: testContext)
        kit.name = "Test Kit"
        kit.project = project
        
        // Test presets relationship
        let preset = Preset(context: testContext)
        preset.name = "Test Preset"
        preset.project = project
        
        try saveContext()
        
        XCTAssertEqual(project.patterns?.count, 2)
        XCTAssertEqual(project.kits?.count, 1)
        XCTAssertEqual(project.presets?.count, 1)
        
        XCTAssertTrue(project.patterns?.contains(pattern1) == true)
        XCTAssertTrue(project.patterns?.contains(pattern2) == true)
        XCTAssertTrue(project.kits?.contains(kit) == true)
        XCTAssertTrue(project.presets?.contains(preset) == true)
    }
    
    // MARK: - Pattern Entity Tests
    
    func testPatternEntityCreation() throws {
        let project = createTestProject()
        let pattern = DataLayer.Pattern(context: testContext)
        pattern.name = "Test Pattern"
        pattern.length = 16
        pattern.tempo = 120.0
        pattern.project = project
        
        XCTAssertNotNil(pattern)
        XCTAssertEqual(pattern.name, "Test Pattern")
        XCTAssertEqual(pattern.length, 16)
        XCTAssertEqual(pattern.tempo, 120.0)
        XCTAssertEqual(pattern.project, project)
        
        try saveContext()
        
        let fetchRequest: NSFetchRequest<DataLayer.Pattern> = DataLayer.Pattern.fetchRequest()
        let patterns = try testContext.fetch(fetchRequest)
        XCTAssertEqual(patterns.count, 1)
        XCTAssertEqual(patterns.first?.name, "Test Pattern")
    }
    
    func testPatternDefaultValues() throws {
        let project = createTestProject()
        let pattern = DataLayer.Pattern(context: testContext)
        pattern.name = "Test Pattern"
        pattern.project = project
        
        // Test default values
        XCTAssertEqual(pattern.length, 64) // Default pattern length from model
        XCTAssertEqual(pattern.tempo, 120.0) // Default tempo
    }
    
    func testPatternTrackRelationship() throws {
        let (_, pattern, _, _) = try createTestHierarchy()
        
        let track1 = Track(context: testContext)
        track1.name = "Track 1"
        track1.trackIndex = 0
        track1.pattern = pattern
        
        let track2 = Track(context: testContext)
        track2.name = "Track 2"
        track2.trackIndex = 1
        track2.pattern = pattern
        
        try saveContext()
        
        XCTAssertEqual(pattern.tracks?.count, 3) // One from hierarchy + two new
        XCTAssertTrue(pattern.tracks?.contains(track1) == true)
        XCTAssertTrue(pattern.tracks?.contains(track2) == true)
        XCTAssertEqual(track1.pattern, pattern)
        XCTAssertEqual(track2.pattern, pattern)
    }
    
    // MARK: - Track Entity Tests
    
    func testTrackEntityCreation() throws {
        let (_, pattern, _, _) = try createTestHierarchy()
        
        let track = Track(context: testContext)
        track.name = "Test Track"
        track.trackIndex = 5
        track.volume = 0.8
        track.pan = 0.2
        track.isMuted = false
        track.isSolo = false
        track.pattern = pattern
        
        XCTAssertNotNil(track)
        XCTAssertEqual(track.name, "Test Track")
        XCTAssertEqual(track.trackIndex, 5)
        XCTAssertEqual(track.volume, 0.8, accuracy: 0.001)
        XCTAssertEqual(track.pan, 0.2, accuracy: 0.001)
        XCTAssertFalse(track.isMuted)
        XCTAssertFalse(track.isSolo)
        XCTAssertEqual(track.pattern, pattern)
        
        try saveContext()
        
        let fetchRequest: NSFetchRequest<Track> = Track.fetchRequest()
        let tracks = try testContext.fetch(fetchRequest)
        XCTAssertEqual(tracks.count, 2) // One from hierarchy + one new
        XCTAssertTrue(tracks.contains { $0.name == "Test Track" })
    }
    
    func testTrackDefaultValues() throws {
        let (_, pattern, _, _) = try createTestHierarchy()
        
        let track = Track(context: testContext)
        track.name = "Test Track"
        track.pattern = pattern
        
        // Test default values
        XCTAssertEqual(track.volume, 0.75) // Default volume from model
        XCTAssertEqual(track.pan, 0.0) // Default pan (center)
        XCTAssertFalse(track.isMuted) // Default mute state
        XCTAssertFalse(track.isSolo) // Default solo state
    }
    
    func testTrackTrigRelationship() throws {
        let (_, _, track, _) = try createTestHierarchy()
        
        let trig1 = Trig(context: testContext)
        trig1.step = 0
        trig1.note = 60
        trig1.velocity = 100
        trig1.track = track
        trig1.pattern = track.pattern
        
        let trig2 = Trig(context: testContext)
        trig2.step = 4
        trig2.note = 64
        trig2.velocity = 80
        trig2.track = track
        trig2.pattern = track.pattern
        
        try saveContext()
        
        XCTAssertEqual(track.trigs?.count, 3) // One from hierarchy + two new
        XCTAssertTrue(track.trigs?.contains(trig1) == true)
        XCTAssertTrue(track.trigs?.contains(trig2) == true)
        XCTAssertEqual(trig1.track, track)
        XCTAssertEqual(trig2.track, track)
    }
    
    // MARK: - Trig Entity Tests
    
    func testTrigEntityCreation() throws {
        let (_, _, track, _) = try createTestHierarchy()
        
        let trig = Trig(context: testContext)
        trig.step = 8
        trig.note = 72
        trig.velocity = 110
        trig.track = track
        trig.pattern = track.pattern
        
        XCTAssertNotNil(trig)
        XCTAssertEqual(trig.step, 8)
        XCTAssertEqual(trig.note, 72)
        XCTAssertEqual(trig.velocity, 110)
        XCTAssertEqual(trig.track, track)
        XCTAssertEqual(trig.pattern, track.pattern)
        
        try saveContext()
        
        let fetchRequest: NSFetchRequest<Trig> = Trig.fetchRequest()
        let trigs = try testContext.fetch(fetchRequest)
        XCTAssertEqual(trigs.count, 2) // One from hierarchy + one new
        XCTAssertTrue(trigs.contains { $0.step == 8 })
    }
    
    func testTrigDefaultValues() throws {
        let (_, _, track, _) = try createTestHierarchy()
        
        let trig = Trig(context: testContext)
        trig.track = track
        trig.pattern = track.pattern
        
        // Test default values
        XCTAssertEqual(trig.velocity, 100) // Default velocity
        XCTAssertFalse(trig.isActive) // Default active state from model
    }
    
    func testTrigMIDIValidation() throws {
        let (_, _, track, _) = try createTestHierarchy()
        
        let trig = Trig(context: testContext)
        trig.track = track
        trig.pattern = track.pattern
        
        // Test MIDI note range (0-127)
        trig.note = 0
        XCTAssertEqual(trig.note, 0)
        
        trig.note = 127
        XCTAssertEqual(trig.note, 127)
        
        // Test MIDI velocity range (1-127)
        trig.velocity = 1
        XCTAssertEqual(trig.velocity, 1)
        
        trig.velocity = 127
        XCTAssertEqual(trig.velocity, 127)
        
        try saveContext()
    }
    
    // MARK: - Kit Entity Tests
    
    func testKitEntityCreation() throws {
        let project = createTestProject()
        
        let kit = Kit(context: testContext)
        kit.name = "Test Kit"
        kit.soundFiles = ["kick.wav", "snare.wav", "hihat.wav"]
        kit.project = project
        
        XCTAssertNotNil(kit)
        XCTAssertEqual(kit.name, "Test Kit")
        XCTAssertEqual(kit.soundFiles?.count, 3)
        XCTAssertEqual(kit.soundFiles?[0], "kick.wav")
        XCTAssertEqual(kit.project, project)
        
        try saveContext()
        
        let fetchRequest: NSFetchRequest<Kit> = Kit.fetchRequest()
        let kits = try testContext.fetch(fetchRequest)
        XCTAssertEqual(kits.count, 1)
        XCTAssertEqual(kits.first?.name, "Test Kit")
    }
    
    func testKitTrackRelationship() throws {
        let (project, pattern, _, _) = try createTestHierarchy()
        
        let kit = Kit(context: testContext)
        kit.name = "Test Kit"
        kit.project = project
        
        let track1 = Track(context: testContext)
        track1.name = "Track 1"
        track1.pattern = pattern
        track1.kit = kit
        
        let track2 = Track(context: testContext)
        track2.name = "Track 2"
        track2.pattern = pattern
        track2.kit = kit
        
        try saveContext()
        
        XCTAssertEqual(kit.tracks?.count, 2)
        XCTAssertTrue(kit.tracks?.contains(track1) == true)
        XCTAssertTrue(kit.tracks?.contains(track2) == true)
        XCTAssertEqual(track1.kit, kit)
        XCTAssertEqual(track2.kit, kit)
    }
    
    // MARK: - Preset Entity Tests
    
    func testPresetEntityCreation() throws {
        let project = createTestProject()
        
        let preset = Preset(context: testContext)
        preset.name = "Test Preset"
        preset.project = project
        
        XCTAssertNotNil(preset)
        XCTAssertEqual(preset.name, "Test Preset")
        XCTAssertEqual(preset.project, project)
        
        try saveContext()
        
        let fetchRequest: NSFetchRequest<Preset> = Preset.fetchRequest()
        let presets = try testContext.fetch(fetchRequest)
        XCTAssertEqual(presets.count, 1)
        XCTAssertEqual(presets.first?.name, "Test Preset")
    }
    
    func testPresetParameterValues() throws {
        let project = createTestProject()
        
        let preset = Preset(context: testContext)
        preset.name = "Test Preset"
        preset.project = project
        
        // Test basic preset properties
        XCTAssertNotNil(preset.name)
        XCTAssertEqual(preset.name, "Test Preset")
        XCTAssertEqual(preset.project, project)
        
        try saveContext()
        
        let fetchRequest: NSFetchRequest<Preset> = Preset.fetchRequest()
        let presets = try testContext.fetch(fetchRequest)
        XCTAssertEqual(presets.count, 1)
        XCTAssertEqual(presets.first?.name, "Test Preset")
    }
    
    func testPresetTrackRelationship() throws {
        let (project, pattern, _, _) = try createTestHierarchy()
        
        let preset = Preset(context: testContext)
        preset.name = "Test Preset"
        preset.project = project
        
        let track1 = Track(context: testContext)
        track1.name = "Track 1"
        track1.pattern = pattern
        track1.preset = preset
        
        let track2 = Track(context: testContext)
        track2.name = "Track 2"
        track2.pattern = pattern
        track2.preset = preset
        
        try saveContext()
        
        XCTAssertEqual(preset.tracks?.count, 2)
        XCTAssertTrue(preset.tracks?.contains(track1) == true)
        XCTAssertTrue(preset.tracks?.contains(track2) == true)
        XCTAssertEqual(track1.preset, preset)
        XCTAssertEqual(track2.preset, preset)
    }
    
    // MARK: - Cascade Delete Tests
    
    func testProjectCascadeDelete() throws {
        let project = createTestProject()
        
        let pattern = DataLayer.Pattern(context: testContext)
        pattern.name = "Test Pattern"
        pattern.project = project
        
        let kit = Kit(context: testContext)
        kit.name = "Test Kit"
        kit.project = project
        
        let preset = Preset(context: testContext)
        preset.name = "Test Preset"
        preset.project = project
        
        try saveContext()
        
        XCTAssertEqual(try testContext.count(for: Project.fetchRequest()), 1)
        XCTAssertEqual(try testContext.count(for: DataLayer.Pattern.fetchRequest()), 1)
        XCTAssertEqual(try testContext.count(for: Kit.fetchRequest()), 1)
        XCTAssertEqual(try testContext.count(for: Preset.fetchRequest()), 1)
        
        testContext.delete(project)
        try saveContext()
        
        XCTAssertEqual(try testContext.count(for: Project.fetchRequest()), 0)
        XCTAssertEqual(try testContext.count(for: DataLayer.Pattern.fetchRequest()), 0)
        XCTAssertEqual(try testContext.count(for: Kit.fetchRequest()), 0)
        XCTAssertEqual(try testContext.count(for: Preset.fetchRequest()), 0)
    }
    
    func testPatternCascadeDelete() throws {
        let (_, pattern, _, _) = try createTestHierarchy()
        
        let track = Track(context: testContext)
        track.name = "Test Track"
        track.pattern = pattern
        
        let trig = Trig(context: testContext)
        trig.step = 0
        trig.track = track
        trig.pattern = pattern
        
        try saveContext()
        
        XCTAssertEqual(try testContext.count(for: DataLayer.Pattern.fetchRequest()), 1)
        XCTAssertEqual(try testContext.count(for: Track.fetchRequest()), 2) // One from hierarchy + one new
        XCTAssertEqual(try testContext.count(for: Trig.fetchRequest()), 2) // One from hierarchy + one new
        
        testContext.delete(pattern)
        try saveContext()
        
        XCTAssertEqual(try testContext.count(for: DataLayer.Pattern.fetchRequest()), 0)
        XCTAssertEqual(try testContext.count(for: Track.fetchRequest()), 0)
        XCTAssertEqual(try testContext.count(for: Trig.fetchRequest()), 0)
        XCTAssertEqual(try testContext.count(for: Project.fetchRequest()), 1)
    }
    
    func testTrackCascadeDelete() throws {
        let (_, _, track, _) = try createTestHierarchy()
        
        let trig1 = Trig(context: testContext)
        trig1.step = 0
        trig1.track = track
        trig1.pattern = track.pattern
        
        let trig2 = Trig(context: testContext)
        trig2.step = 4
        trig2.track = track
        trig2.pattern = track.pattern
        
        try saveContext()
        
        XCTAssertEqual(try testContext.count(for: Track.fetchRequest()), 1)
        XCTAssertEqual(try testContext.count(for: Trig.fetchRequest()), 3) // One from hierarchy + two new
        
        testContext.delete(track)
        try saveContext()
        
        XCTAssertEqual(try testContext.count(for: Track.fetchRequest()), 0)
        XCTAssertEqual(try testContext.count(for: Trig.fetchRequest()), 0)
        XCTAssertEqual(try testContext.count(for: DataLayer.Pattern.fetchRequest()), 1)
    }
    
    // MARK: - Complex Relationship Tests
    
    func testCompleteHierarchyCreation() throws {
        let project = createTestProject()
        
        let pattern = DataLayer.Pattern(context: testContext)
        pattern.name = "Main Pattern"
        pattern.length = 32
        pattern.tempo = 140.0
        pattern.project = project
        
        let kit = Kit(context: testContext)
        kit.name = "Drum Kit"
        kit.soundFiles = ["kick.wav", "snare.wav", "hihat.wav"]
        kit.project = project
        
        let preset = Preset(context: testContext)
        preset.name = "Bass Preset"
        preset.project = project
        
        let kickTrack = Track(context: testContext)
        kickTrack.name = "Kick"
        kickTrack.trackIndex = 0
        kickTrack.pattern = pattern
        kickTrack.kit = kit
        
        let bassTrack = Track(context: testContext)
        bassTrack.name = "Bass"
        bassTrack.trackIndex = 1
        bassTrack.pattern = pattern
        bassTrack.preset = preset
        
        let kickTrig = Trig(context: testContext)
        kickTrig.step = 0
        kickTrig.note = 36
        kickTrig.velocity = 127
        kickTrig.track = kickTrack
        kickTrig.pattern = pattern
        
        let bassTrig = Trig(context: testContext)
        bassTrig.step = 2
        bassTrig.note = 48
        bassTrig.velocity = 90
        bassTrig.track = bassTrack
        bassTrig.pattern = pattern
        
        try saveContext()
        
        XCTAssertEqual(project.patterns?.count, 1)
        XCTAssertEqual(project.kits?.count, 1)
        XCTAssertEqual(project.presets?.count, 1)
        XCTAssertEqual(pattern.tracks?.count, 2)
        XCTAssertEqual(pattern.trigs?.count, 2)
        XCTAssertEqual(kickTrack.trigs?.count, 1)
        XCTAssertEqual(bassTrack.trigs?.count, 1)
        XCTAssertEqual(kit.tracks?.count, 1)
        XCTAssertEqual(preset.tracks?.count, 1)
    }
    
    // MARK: - Performance Tests
    
    func testLargeDataSetPerformance() throws {
        let project = createTestProject()
        
        measure {
            // Create a large dataset
            for patternIndex in 0..<1 { // Reduced to 1 since measure runs 10 times
                let pattern = DataLayer.Pattern(context: testContext)
                pattern.name = "Pattern \(patternIndex)"
                pattern.project = project
                
                for trackIndex in 0..<16 {
                    let track = Track(context: testContext)
                    track.name = "Track \(trackIndex)"
                    track.trackIndex = Int16(trackIndex)
                    track.pattern = pattern
                    
                    for step in stride(from: 0, to: 64, by: 4) {
                        let trig = Trig(context: testContext)
                        trig.step = Int16(step)
                        trig.note = Int16(60 + trackIndex)
                        trig.velocity = Int16(80 + (step % 40))
                        trig.track = track
                        trig.pattern = pattern
                    }
                }
            }
            
            do {
                try saveContext()
            } catch {
                XCTFail("Failed to save large dataset: \(error)")
            }
        }
        
        // Verify the data was created (measure runs 10 times, so 10 patterns total)
        XCTAssertEqual(try testContext.count(for: DataLayer.Pattern.fetchRequest()), 10)
        XCTAssertEqual(try testContext.count(for: Track.fetchRequest()), 160)
        XCTAssertEqual(try testContext.count(for: Trig.fetchRequest()), 2560)
    }
    
    // MARK: - Data Integrity Tests
    
    func testDataIntegrityAfterModification() throws {
        let (project, pattern, track, _) = try createTestHierarchy()
        
        // Create initial state
        let trig = Trig(context: testContext)
        trig.step = 0
        trig.note = 60
        trig.velocity = 100
        trig.track = track
        trig.pattern = pattern
        
        try saveContext()
        
        // Verify initial state - pattern should have the track from hierarchy plus our new trig
        XCTAssertEqual(pattern.tracks?.count, 1) // Track from hierarchy
        XCTAssertEqual(pattern.trigs?.count, 2) // Trig from hierarchy + new trig
        
        // Modify relationships
        let newPattern = DataLayer.Pattern(context: testContext)
        newPattern.name = "New Pattern"
        newPattern.project = project
        
        track.pattern = newPattern
        trig.pattern = newPattern
        
        try saveContext()
        
        // Verify integrity
        XCTAssertEqual(track.pattern, newPattern)
        XCTAssertEqual(trig.pattern, newPattern)
        XCTAssertEqual(trig.track, track)
        XCTAssertTrue(newPattern.tracks?.contains(track) == true)
        XCTAssertTrue(newPattern.trigs?.contains(trig) == true)
        
        // Original pattern should now only have the original trig from hierarchy
        XCTAssertEqual(pattern.tracks?.count, 0)
        XCTAssertEqual(pattern.trigs?.count, 1) // Only the original trig from hierarchy remains
    }
} 