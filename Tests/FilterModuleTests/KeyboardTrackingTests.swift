// KeyboardTrackingTests.swift
// DigitonePad - FilterModuleTests
//
// Comprehensive test suite for Keyboard Tracking functionality

import XCTest
import MachineProtocols
@testable import FilterModule

final class KeyboardTrackingTests: XCTestCase {
    
    var keyboardTracking: KeyboardTrackingEngine!
    let baseCutoff: Float = 1000.0  // 1kHz base cutoff
    
    override func setUp() {
        super.setUp()
        keyboardTracking = KeyboardTrackingEngine()
    }
    
    override func tearDown() {
        keyboardTracking = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialization() {
        XCTAssertNotNil(keyboardTracking)
        XCTAssertEqual(keyboardTracking.config.referenceNote, 60) // C4
        XCTAssertEqual(keyboardTracking.config.trackingAmount, 0.0) // Off by default
        XCTAssertFalse(keyboardTracking.parameters.isNoteActive)
    }
    
    func testNoTrackingWhenDisabled() {
        // With tracking amount = 0, should return base cutoff regardless of note
        keyboardTracking.config.trackingAmount = 0.0
        keyboardTracking.noteOn(note: 72, velocity: 100) // C5 (one octave up)
        
        let trackedFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        XCTAssertEqual(trackedFreq, baseCutoff, accuracy: 0.1, "No tracking should return base cutoff")
    }
    
    func testNoTrackingWhenNoNoteActive() {
        // With no note active, should return base cutoff regardless of tracking amount
        keyboardTracking.config.trackingAmount = 100.0
        // Don't call noteOn
        
        let trackedFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        XCTAssertEqual(trackedFreq, baseCutoff, accuracy: 0.1, "No active note should return base cutoff")
    }
    
    // MARK: - Linear Tracking Tests
    
    func testLinearTrackingOneOctaveUp() {
        keyboardTracking.config.trackingAmount = 100.0 // Full tracking
        keyboardTracking.config.trackingCurve = .linear
        keyboardTracking.noteOn(note: 72, velocity: 100) // C5 (one octave up from C4)
        
        let trackedFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        let expectedFreq = baseCutoff * 2.0 // Should double for one octave up
        
        XCTAssertEqual(trackedFreq, expectedFreq, accuracy: 1.0, "One octave up should double frequency with 100% tracking")
    }
    
    func testLinearTrackingOneOctaveDown() {
        keyboardTracking.config.trackingAmount = 100.0 // Full tracking
        keyboardTracking.config.trackingCurve = .linear
        keyboardTracking.noteOn(note: 48, velocity: 100) // C3 (one octave down from C4)
        
        let trackedFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        let expectedFreq = baseCutoff * 0.5 // Should halve for one octave down
        
        XCTAssertEqual(trackedFreq, expectedFreq, accuracy: 1.0, "One octave down should halve frequency with 100% tracking")
    }
    
    func testLinearTrackingPartial() {
        keyboardTracking.config.trackingAmount = 50.0 // Half tracking
        keyboardTracking.config.trackingCurve = .linear
        keyboardTracking.noteOn(note: 72, velocity: 100) // C5 (one octave up)
        
        let trackedFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        let expectedFreq = baseCutoff * 1.5 // Should be halfway between 1x and 2x
        
        XCTAssertEqual(trackedFreq, expectedFreq, accuracy: 1.0, "50% tracking should give halfway effect")
    }
    
    func testLinearTrackingNegative() {
        keyboardTracking.config.trackingAmount = -50.0 // Negative tracking
        keyboardTracking.config.trackingCurve = .linear
        keyboardTracking.noteOn(note: 72, velocity: 100) // C5 (one octave up)
        
        let trackedFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        // With negative tracking, higher notes should lower the cutoff
        XCTAssertLessThan(trackedFreq, baseCutoff, "Negative tracking should lower cutoff for higher notes")
    }
    
    // MARK: - Tracking Curve Tests
    
    func testExponentialCurve() {
        keyboardTracking.config.trackingAmount = 100.0
        keyboardTracking.config.trackingCurve = .exponential
        keyboardTracking.noteOn(note: 84, velocity: 100) // C6 (two octaves up)
        
        let trackedFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        let linearExpected = baseCutoff * 4.0 // Linear would be 4x for two octaves
        
        // Exponential should be more dramatic than linear
        XCTAssertGreaterThan(trackedFreq, linearExpected, "Exponential curve should be more dramatic than linear")
    }
    
    func testLogarithmicCurve() {
        keyboardTracking.config.trackingAmount = 100.0
        keyboardTracking.config.trackingCurve = .logarithmic
        keyboardTracking.noteOn(note: 84, velocity: 100) // C6 (two octaves up)
        
        let trackedFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        let linearExpected = baseCutoff * 4.0 // Linear would be 4x for two octaves
        
        // Logarithmic should be less dramatic than linear
        XCTAssertLessThan(trackedFreq, linearExpected, "Logarithmic curve should be less dramatic than linear")
        XCTAssertGreaterThan(trackedFreq, baseCutoff, "But should still increase for higher notes")
    }
    
    func testSCurve() {
        keyboardTracking.config.trackingAmount = 100.0
        keyboardTracking.config.trackingCurve = .sCurve
        
        // Test multiple notes to verify S-curve behavior
        let testNotes: [UInt8] = [36, 48, 60, 72, 84, 96] // C2 to C7
        var frequencies: [Float] = []
        
        for note in testNotes {
            keyboardTracking.noteOn(note: note, velocity: 100)
            let freq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
            frequencies.append(freq)
        }
        
        // S-curve should show smooth transitions
        for i in 1..<frequencies.count {
            XCTAssertGreaterThan(frequencies[i], frequencies[i-1], "S-curve should be monotonically increasing")
        }
    }
    
    // MARK: - Velocity Sensitivity Tests
    
    func testVelocitySensitivity() {
        keyboardTracking.config.trackingAmount = 100.0
        keyboardTracking.config.velocitySensitivity = 0.5 // 50% velocity sensitivity
        
        // Test low velocity
        keyboardTracking.noteOn(note: 60, velocity: 64, channel: 0) // Half velocity
        let lowVelFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        
        // Test high velocity
        keyboardTracking.noteOn(note: 60, velocity: 127, channel: 0) // Full velocity
        let highVelFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        
        XCTAssertGreaterThan(highVelFreq, lowVelFreq, "Higher velocity should increase cutoff frequency")
    }
    
    func testVelocitySensitivityDisabled() {
        keyboardTracking.config.trackingAmount = 100.0
        keyboardTracking.config.velocitySensitivity = 0.0 // No velocity sensitivity
        
        // Test different velocities
        keyboardTracking.noteOn(note: 60, velocity: 1, channel: 0)
        let lowVelFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        
        keyboardTracking.noteOn(note: 60, velocity: 127, channel: 0)
        let highVelFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        
        XCTAssertEqual(lowVelFreq, highVelFreq, accuracy: 0.1, "No velocity sensitivity should give same result")
    }
    
    // MARK: - Pitch Bend Tests
    
    func testPitchBend() {
        keyboardTracking.config.trackingAmount = 100.0
        keyboardTracking.noteOn(note: 60, velocity: 100) // C4
        
        // Test no pitch bend
        let normalFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        
        // Test positive pitch bend
        keyboardTracking.pitchBend(amount: 1.0) // Full up
        let bendUpFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        
        // Test negative pitch bend
        keyboardTracking.pitchBend(amount: -1.0) // Full down
        let bendDownFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        
        XCTAssertGreaterThan(bendUpFreq, normalFreq, "Positive pitch bend should increase frequency")
        XCTAssertLessThan(bendDownFreq, normalFreq, "Negative pitch bend should decrease frequency")
    }
    
    // MARK: - Frequency Range Tests
    
    func testFrequencyRangeLimits() {
        keyboardTracking.config.trackingAmount = 100.0
        keyboardTracking.config.trackingRange = 100.0...2000.0 // Limited range
        
        // Test very high note that would exceed upper limit
        keyboardTracking.noteOn(note: 108, velocity: 100) // C8
        let highFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        XCTAssertLessThanOrEqual(highFreq, 2000.0, "Should clamp to upper limit")
        
        // Test very low note that would go below lower limit
        keyboardTracking.noteOn(note: 24, velocity: 100) // C1
        let lowFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        XCTAssertGreaterThanOrEqual(lowFreq, 100.0, "Should clamp to lower limit")
    }
    
    // MARK: - Portamento Tests
    
    func testPortamento() {
        keyboardTracking.config.trackingAmount = 100.0
        keyboardTracking.setPortamentoTime(0.1) // 100ms portamento
        
        // Start with one note
        keyboardTracking.noteOn(note: 60, velocity: 100) // C4
        let startFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        
        // Change to another note
        keyboardTracking.noteOn(note: 72, velocity: 100) // C5
        
        // First calculation should be between start and target
        let intermediateFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        let targetFreq = baseCutoff * 2.0 // Expected final frequency
        
        XCTAssertGreaterThan(intermediateFreq, startFreq, "Should start moving toward target")
        XCTAssertLessThan(intermediateFreq, targetFreq, "Should not reach target immediately")
    }
    
    // MARK: - MIDI Integration Tests
    
    func testNoteOnOff() {
        keyboardTracking.config.trackingAmount = 100.0
        
        // Test note on
        keyboardTracking.noteOn(note: 72, velocity: 100)
        XCTAssertTrue(keyboardTracking.parameters.isNoteActive, "Note should be active after note on")
        XCTAssertEqual(keyboardTracking.parameters.currentNote, 72, "Should track current note")
        
        // Test note off
        keyboardTracking.noteOff(note: 72)
        XCTAssertFalse(keyboardTracking.parameters.isNoteActive, "Note should be inactive after note off")
    }
    
    func testNoteOffWrongNote() {
        keyboardTracking.config.trackingAmount = 100.0
        
        // Note on
        keyboardTracking.noteOn(note: 72, velocity: 100)
        XCTAssertTrue(keyboardTracking.parameters.isNoteActive)
        
        // Note off for different note
        keyboardTracking.noteOff(note: 60)
        XCTAssertTrue(keyboardTracking.parameters.isNoteActive, "Should remain active for wrong note off")
    }
    
    // MARK: - Preset Tests
    
    func testPresetLoading() {
        let presetNames = ["Off", "Subtle", "Standard", "Full", "Inverse", "Exponential", "Smooth"]
        
        for presetName in presetNames {
            keyboardTracking.config.loadPreset(presetName)
            
            // Verify preset was loaded (basic check)
            XCTAssertNotNil(keyboardTracking.config, "Config should exist after loading preset \(presetName)")
            
            // Test specific presets
            switch presetName {
            case "Off":
                XCTAssertEqual(keyboardTracking.config.trackingAmount, 0.0, "Off preset should have 0% tracking")
            case "Full":
                XCTAssertEqual(keyboardTracking.config.trackingAmount, 100.0, "Full preset should have 100% tracking")
            case "Inverse":
                XCTAssertLessThan(keyboardTracking.config.trackingAmount, 0.0, "Inverse preset should have negative tracking")
            case "Exponential":
                XCTAssertEqual(keyboardTracking.config.trackingCurve, .exponential, "Exponential preset should use exponential curve")
            default:
                break
            }
        }
    }
    
    // MARK: - Utility Function Tests
    
    func testMIDINoteToFrequency() {
        // Test A4 = 440Hz
        let a4Freq = KeyboardTrackingEngine.midiNoteToFrequency(69)
        XCTAssertEqual(a4Freq, 440.0, accuracy: 0.1, "A4 should be 440Hz")
        
        // Test C4 (middle C)
        let c4Freq = KeyboardTrackingEngine.midiNoteToFrequency(60)
        XCTAssertEqual(c4Freq, 261.63, accuracy: 0.1, "C4 should be ~261.63Hz")
        
        // Test octave relationship
        let c5Freq = KeyboardTrackingEngine.midiNoteToFrequency(72)
        XCTAssertEqual(c5Freq, c4Freq * 2.0, accuracy: 0.1, "C5 should be double C4")
    }
    
    func testFrequencyToMIDINote() {
        // Test A4 = 440Hz
        let a4Note = KeyboardTrackingEngine.frequencyToMidiNote(440.0)
        XCTAssertEqual(a4Note, 69, "440Hz should be MIDI note 69")
        
        // Test C4
        let c4Note = KeyboardTrackingEngine.frequencyToMidiNote(261.63)
        XCTAssertEqual(c4Note, 60, "261.63Hz should be MIDI note 60")
    }
    
    // MARK: - Edge Case Tests
    
    func testExtremeNotes() {
        keyboardTracking.config.trackingAmount = 100.0
        
        // Test very low note
        keyboardTracking.noteOn(note: 0, velocity: 100)
        let lowFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        XCTAssertFalse(lowFreq.isNaN, "Should handle very low notes without NaN")
        XCTAssertFalse(lowFreq.isInfinite, "Should handle very low notes without infinity")
        
        // Test very high note
        keyboardTracking.noteOn(note: 127, velocity: 100)
        let highFreq = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
        XCTAssertFalse(highFreq.isNaN, "Should handle very high notes without NaN")
        XCTAssertFalse(highFreq.isInfinite, "Should handle very high notes without infinity")
    }
    
    func testReset() {
        // Set up some state
        keyboardTracking.config.trackingAmount = 100.0
        keyboardTracking.noteOn(note: 72, velocity: 100)
        keyboardTracking.pitchBend(amount: 0.5)
        keyboardTracking.setPortamentoTime(0.5)
        
        // Reset
        keyboardTracking.reset()
        
        // Verify reset state
        XCTAssertFalse(keyboardTracking.parameters.isNoteActive, "Should be inactive after reset")
        XCTAssertEqual(keyboardTracking.parameters.currentNote, keyboardTracking.config.referenceNote, "Should return to reference note")
        XCTAssertEqual(keyboardTracking.parameters.pitchBend, 0.0, "Should reset pitch bend")
    }
    
    // MARK: - Performance Tests
    
    func testPerformance() {
        keyboardTracking.config.trackingAmount = 100.0
        keyboardTracking.noteOn(note: 60, velocity: 100)
        
        measure {
            for _ in 0..<10000 {
                _ = keyboardTracking.calculateTrackedFrequency(baseCutoff: baseCutoff)
            }
        }
    }
}
