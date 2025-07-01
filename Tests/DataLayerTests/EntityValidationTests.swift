import XCTest
import CoreData
@testable import DataLayer

/// Tests for entity validation rules
final class EntityValidationTests: CoreDataTestBase {
    
    // MARK: - Project Validation Tests
    
    func testProjectNameValidation() throws {
        let project = Project(context: testContext)

        // Test empty name validation
        project.name = ""
        do {
            try project.validateForInsert()
            XCTFail("Expected validation error for empty name")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("Project name cannot be empty"))
        }

        // Test valid name
        project.name = "Valid Project Name"
        XCTAssertNoThrow(try project.validateForInsert())
    }
    
    func testProjectTimestamps() throws {
        let project = createTestProject()
        try saveContext()
        
        XCTAssertNotNil(project.createdAt)
        XCTAssertNotNil(project.updatedAt)
        assertDatesEqual(project.createdAt, project.updatedAt)
        
        // Test that updatedAt changes when modified
        let originalUpdatedAt = project.updatedAt
        Thread.sleep(forTimeInterval: 0.1) // Small delay to ensure timestamp difference
        
        project.name = "Updated Name"
        try saveContext()
        
        XCTAssertNotNil(project.updatedAt)
        XCTAssertNotEqual(originalUpdatedAt, project.updatedAt)
    }
    
    // MARK: - Pattern Validation Tests
    
    func testPatternNameValidation() throws {
        let project = createTestProject()
        let pattern = Pattern(context: testContext)
        pattern.project = project
        
        // Test empty name validation
        do {
            var emptyName: String? = ""
            try pattern.validateValue(&emptyName, forKey: "name")
            XCTFail("Expected validation error for empty name")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("Pattern name cannot be empty"))
        }
        
        // Test name too long
        do {
            var longName: String? = String(repeating: "a", count: 51)
            try pattern.validateValue(&longName, forKey: "name")
            XCTFail("Expected validation error for name too long")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("50 characters"))
        }
        
        // Test valid name
        var validName: String? = "Valid Pattern"
        XCTAssertNoThrow(try pattern.validateValue(&validName, forKey: "name"))
    }
    
    func testPatternLengthValidation() throws {
        let project = createTestProject()
        let pattern = Pattern(context: testContext)
        pattern.project = project
        pattern.name = "Test Pattern"
        
        // Test length too small
        do {
            var invalidLength: Int16 = 0
            try pattern.validateValue(&invalidLength, forKey: "length")
            XCTFail("Expected validation error for invalid length")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("between 1 and 128"))
        }
        
        // Test length too large
        do {
            var invalidLength: Int16 = 129
            try pattern.validateValue(&invalidLength, forKey: "length")
            XCTFail("Expected validation error for invalid length")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("between 1 and 128"))
        }
        
        // Test valid lengths
        for validLength: Int16 in [1, 16, 32, 64, 128] {
            var length = validLength
            XCTAssertNoThrow(try pattern.validateValue(&length, forKey: "length"))
        }
    }
    
    func testPatternTempoValidation() throws {
        let project = createTestProject()
        let pattern = Pattern(context: testContext)
        pattern.project = project
        pattern.name = "Test Pattern"
        
        // Test tempo too slow
        do {
            var invalidTempo: Double = 29.9
            try pattern.validateValue(&invalidTempo, forKey: "tempo")
            XCTFail("Expected validation error for invalid tempo")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("between 30.0 and 300.0"))
        }
        
        // Test tempo too fast
        do {
            var invalidTempo: Double = 300.1
            try pattern.validateValue(&invalidTempo, forKey: "tempo")
            XCTFail("Expected validation error for invalid tempo")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("between 30.0 and 300.0"))
        }
        
        // Test valid tempos
        for validTempo in [30.0, 60.0, 120.0, 180.0, 300.0] {
            var tempo = validTempo
            XCTAssertNoThrow(try pattern.validateValue(&tempo, forKey: "tempo"))
        }
    }
    
    // MARK: - Track Validation Tests
    
    func testTrackNameValidation() throws {
        let (_, pattern, _, _) = try createTestHierarchy()
        let track = Track(context: testContext)
        track.pattern = pattern
        
        // Test empty name validation
        do {
            var emptyName: String? = ""
            try track.validateValue(&emptyName, forKey: "name")
            XCTFail("Expected validation error for empty name")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("Track name cannot be empty"))
        }
        
        // Test valid name
        var validName: String? = "Valid Track"
        XCTAssertNoThrow(try track.validateValue(&validName, forKey: "name"))
    }
    
    func testTrackVolumeValidation() throws {
        let (_, pattern, _, _) = try createTestHierarchy()
        let track = Track(context: testContext)
        track.pattern = pattern
        track.name = "Test Track"
        
        // Test volume too low
        do {
            var invalidVolume: Float = -0.1
            try track.validateValue(&invalidVolume, forKey: "volume")
            XCTFail("Expected validation error for invalid volume")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("between 0.0 and 1.0"))
        }
        
        // Test volume too high
        do {
            var invalidVolume: Float = 1.1
            try track.validateValue(&invalidVolume, forKey: "volume")
            XCTFail("Expected validation error for invalid volume")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("between 0.0 and 1.0"))
        }
        
        // Test valid volumes
        for validVolume: Float in [0.0, 0.5, 0.75, 1.0] {
            var volume = validVolume
            XCTAssertNoThrow(try track.validateValue(&volume, forKey: "volume"))
        }
    }
    
    func testTrackPanValidation() throws {
        let (_, pattern, _, _) = try createTestHierarchy()
        let track = Track(context: testContext)
        track.pattern = pattern
        track.name = "Test Track"
        
        // Test pan too low
        do {
            var invalidPan: Float = -1.1
            try track.validateValue(&invalidPan, forKey: "pan")
            XCTFail("Expected validation error for invalid pan")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("between -1.0 and 1.0"))
        }
        
        // Test pan too high
        do {
            var invalidPan: Float = 1.1
            try track.validateValue(&invalidPan, forKey: "pan")
            XCTFail("Expected validation error for invalid pan")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("between -1.0 and 1.0"))
        }
        
        // Test valid pan values
        for validPan: Float in [-1.0, -0.5, 0.0, 0.5, 1.0] {
            var pan = validPan
            XCTAssertNoThrow(try track.validateValue(&pan, forKey: "pan"))
        }
    }
    
    func testTrackIndexValidation() throws {
        let (_, pattern, _, _) = try createTestHierarchy()
        let track = Track(context: testContext)
        track.pattern = pattern
        track.name = "Test Track"
        
        // Test track index too low
        do {
            var invalidIndex: Int16 = -1
            try track.validateValue(&invalidIndex, forKey: "trackIndex")
            XCTFail("Expected validation error for invalid track index")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("between 0 and 15"))
        }
        
        // Test track index too high
        do {
            var invalidIndex: Int16 = 16
            try track.validateValue(&invalidIndex, forKey: "trackIndex")
            XCTFail("Expected validation error for invalid track index")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("between 0 and 15"))
        }
        
        // Test valid track indices
        for validIndex: Int16 in 0...15 {
            var index = validIndex
            XCTAssertNoThrow(try track.validateValue(&index, forKey: "trackIndex"))
        }
    }
    
    // MARK: - Trig Validation Tests
    
    func testTrigStepValidation() throws {
        let (_, _, track, _) = try createTestHierarchy()
        let trig = Trig(context: testContext)
        trig.track = track
        trig.pattern = track.pattern
        
        // Test step too low
        do {
            var invalidStep: Int16 = -1
            try trig.validateValue(&invalidStep, forKey: "step")
            XCTFail("Expected validation error for invalid step")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("between 0 and 127"))
        }
        
        // Test step too high
        do {
            var invalidStep: Int16 = 128
            try trig.validateValue(&invalidStep, forKey: "step")
            XCTFail("Expected validation error for invalid step")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("between 0 and 127"))
        }
        
        // Test valid steps
        for validStep: Int16 in [0, 15, 63, 127] {
            var step = validStep
            XCTAssertNoThrow(try trig.validateValue(&step, forKey: "step"))
        }
    }
    
    func testTrigNoteValidation() throws {
        let (_, _, track, _) = try createTestHierarchy()
        let trig = Trig(context: testContext)
        trig.track = track
        trig.pattern = track.pattern
        
        // Test note too low
        do {
            var invalidNote: Int16 = -1
            try trig.validateValue(&invalidNote, forKey: "note")
            XCTFail("Expected validation error for invalid note")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("between 0 and 127"))
        }
        
        // Test note too high
        do {
            var invalidNote: Int16 = 128
            try trig.validateValue(&invalidNote, forKey: "note")
            XCTFail("Expected validation error for invalid note")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("between 0 and 127"))
        }
        
        // Test valid notes
        for validNote: Int16 in [0, 60, 127] {
            var note = validNote
            XCTAssertNoThrow(try trig.validateValue(&note, forKey: "note"))
        }
    }
    
    func testTrigVelocityValidation() throws {
        let (_, _, track, _) = try createTestHierarchy()
        let trig = Trig(context: testContext)
        trig.track = track
        trig.pattern = track.pattern
        
        // Test velocity too low
        do {
            var invalidVelocity: Int16 = 0
            try trig.validateValue(&invalidVelocity, forKey: "velocity")
            XCTFail("Expected validation error for invalid velocity")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("between 1 and 127"))
        }
        
        // Test velocity too high
        do {
            var invalidVelocity: Int16 = 128
            try trig.validateValue(&invalidVelocity, forKey: "velocity")
            XCTFail("Expected validation error for invalid velocity")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("between 1 and 127"))
        }
        
        // Test valid velocities
        for validVelocity: Int16 in [1, 64, 100, 127] {
            var velocity = validVelocity
            XCTAssertNoThrow(try trig.validateValue(&velocity, forKey: "velocity"))
        }
    }
    
    // MARK: - Kit Validation Tests
    
    func testKitNameValidation() throws {
        let kit = Kit(context: testContext)
        
        // Test empty name validation
        do {
            var emptyName: String? = ""
            try kit.validateValue(&emptyName, forKey: "name")
            XCTFail("Expected validation error for empty name")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("Kit name cannot be empty"))
        }
        
        // Test valid name
        var validName: String? = "Valid Kit"
        XCTAssertNoThrow(try kit.validateValue(&validName, forKey: "name"))
    }
    
    func testKitSoundFilesValidation() throws {
        let kit = Kit(context: testContext)
        kit.name = "Test Kit"
        
        // Test empty sound files array (should be valid)
        kit.soundFiles = []
        try testContext.save()
        
        // Test valid sound files
        kit.soundFiles = ["kick.wav", "snare.wav", "hihat.wav"]
        try testContext.save()
    }
    
    // MARK: - Preset Validation Tests
    
    func testPresetNameValidation() throws {
        let project = createTestProject()
        let preset = Preset(context: testContext)
        preset.project = project
        
        // Test empty name validation
        do {
            var emptyName: String? = ""
            try preset.validateValue(&emptyName, forKey: "name")
            XCTFail("Expected validation error for empty name")
        } catch let error as ValidationError {
            XCTAssertTrue(error.localizedDescription.contains("Preset name cannot be empty"))
        }
        
        // Test valid name
        var validName: String? = "Valid Preset"
        XCTAssertNoThrow(try preset.validateValue(&validName, forKey: "name"))
    }
    
    func testPresetCategoryValidation() throws {
        let project = createTestProject()
        let preset = Preset(context: testContext)
        preset.project = project
        preset.name = "Test Preset"
        
        // Test valid categories
        let validCategories = ["FM TONE", "FM DRUM", "WAVETONE", "SWARMER", "FILTER", "FX"]
        for category in validCategories {
            var categoryValue: String? = category
            XCTAssertNoThrow(try preset.validateValue(&categoryValue, forKey: "category"))
        }
    }
    
    // MARK: - Comprehensive Validation Tests
    
    func testCompleteHierarchyValidation() throws {
        // Test complete hierarchy validation
        let (project, pattern, track, trig) = try createTestHierarchy()
        
        // Validate all entities
        XCTAssertNoThrow(try ValidationService.shared.validateProject(project))
        XCTAssertNoThrow(try ValidationService.shared.validatePattern(pattern))
        XCTAssertNoThrow(try ValidationService.shared.validateTrack(track))
        XCTAssertNoThrow(try ValidationService.shared.validateTrig(trig))
    }
    
    func testBatchValidation() throws {
        let (project, pattern, track, trig) = try createTestHierarchy()
        let entities: [NSManagedObject] = [project, pattern, track, trig]
        
        let errors = ValidationService.shared.batchValidate(entities)
        XCTAssertTrue(errors.isEmpty, "Batch validation should pass for valid entities")
    }
    
    func testValidationServiceIntegration() throws {
        let validationService = ValidationService.shared
        
        // Test that ValidationService properly validates all entity types
        let project = createTestProject()
        let pattern = project.createPattern(name: "Test Pattern")
        let track = Track(context: testContext)
        track.pattern = pattern
        track.name = "Test Track"
        track.trackIndex = 0
        track.volume = 0.8
        track.pan = 0.0
        
        let trig = Trig(context: testContext)
        trig.track = track
        trig.pattern = pattern
        trig.step = 0
        trig.note = 60
        trig.velocity = 100
        trig.duration = 1.0
        trig.probability = 100
        trig.microTiming = 0.0
        trig.retrigCount = 0
        
        // All should validate successfully
        XCTAssertNoThrow(try validationService.validateEntity(project))
        XCTAssertNoThrow(try validationService.validateEntity(pattern))
        XCTAssertNoThrow(try validationService.validateEntity(track))
        XCTAssertNoThrow(try validationService.validateEntity(trig))
    }
}
