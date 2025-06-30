import XCTest
@testable import VoiceModule
@testable import MachineProtocols

/// Comprehensive test suite for WAVETONE Parameter Management System
final class WavetoneParameterManagementTests: XCTestCase {
    
    var voiceMachine: WavetoneVoiceMachine!
    
    override func setUp() {
        super.setUp()
        voiceMachine = WavetoneVoiceMachine()
    }
    
    override func tearDown() {
        voiceMachine = nil
        super.tearDown()
    }
    
    // MARK: - Parameter System Tests
    
    func testParameterSystemInitialization() {
        XCTAssertNotNil(voiceMachine)
        
        // Test that all expected parameters exist
        let expectedParameters = [
            "osc1_tuning", "osc1_wavetable_pos", "osc1_phase_distortion", "osc1_level",
            "osc2_tuning", "osc2_wavetable_pos", "osc2_phase_distortion", "osc2_level",
            "ring_mod_amount", "hard_sync_enable",
            "noise_level", "noise_type", "noise_base_freq", "noise_width", "noise_grain", "noise_resonance", "noise_character",
            "amp_attack", "amp_decay", "amp_sustain", "amp_release",
            "mod_wheel", "aftertouch", "velocity", "lfo1_rate", "lfo1_depth"
        ]
        
        for parameterID in expectedParameters {
            XCTAssertNotNil(voiceMachine.parameters.getParameter(parameterID), "Parameter \(parameterID) should exist")
        }
    }
    
    func testOscillatorParameterUpdates() {
        // Test oscillator 1 parameters
        voiceMachine.setParameter("osc1_tuning", value: 7.0)
        voiceMachine.setParameter("osc1_wavetable_pos", value: 0.5)
        voiceMachine.setParameter("osc1_phase_distortion", value: 0.3)
        voiceMachine.setParameter("osc1_level", value: 0.6)
        
        // Test oscillator 2 parameters
        voiceMachine.setParameter("osc2_tuning", value: -12.0)
        voiceMachine.setParameter("osc2_wavetable_pos", value: 0.8)
        voiceMachine.setParameter("osc2_phase_distortion", value: 0.7)
        voiceMachine.setParameter("osc2_level", value: 0.4)
        
        // Verify parameters were set
        XCTAssertEqual(voiceMachine.getParameter("osc1_tuning"), 7.0, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("osc1_wavetable_pos"), 0.5, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("osc1_phase_distortion"), 0.3, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("osc1_level"), 0.6, accuracy: 0.01)
        
        XCTAssertEqual(voiceMachine.getParameter("osc2_tuning"), -12.0, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("osc2_wavetable_pos"), 0.8, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("osc2_phase_distortion"), 0.7, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("osc2_level"), 0.4, accuracy: 0.01)
    }
    
    func testNoiseParameterUpdates() {
        // Test all noise parameters
        voiceMachine.setParameter("noise_level", value: 0.7)
        voiceMachine.setParameter("noise_type", value: 2.0)  // Brown noise
        voiceMachine.setParameter("noise_base_freq", value: 2000.0)
        voiceMachine.setParameter("noise_width", value: 500.0)
        voiceMachine.setParameter("noise_grain", value: 0.8)
        voiceMachine.setParameter("noise_resonance", value: 0.6)
        voiceMachine.setParameter("noise_character", value: 0.3)
        
        // Verify parameters were set
        XCTAssertEqual(voiceMachine.getParameter("noise_level"), 0.7, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("noise_type"), 2.0, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("noise_base_freq"), 2000.0, accuracy: 1.0)
        XCTAssertEqual(voiceMachine.getParameter("noise_width"), 500.0, accuracy: 1.0)
        XCTAssertEqual(voiceMachine.getParameter("noise_grain"), 0.8, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("noise_resonance"), 0.6, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("noise_character"), 0.3, accuracy: 0.01)
    }
    
    func testEnvelopeParameterUpdates() {
        // Test envelope parameters
        voiceMachine.setParameter("amp_attack", value: 0.5)
        voiceMachine.setParameter("amp_decay", value: 0.8)
        voiceMachine.setParameter("amp_sustain", value: 0.6)
        voiceMachine.setParameter("amp_release", value: 2.0)
        
        // Verify parameters were set
        XCTAssertEqual(voiceMachine.getParameter("amp_attack"), 0.5, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("amp_decay"), 0.8, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("amp_sustain"), 0.6, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("amp_release"), 2.0, accuracy: 0.01)
    }
    
    func testModulationParameterUpdates() {
        // Test modulation parameters
        voiceMachine.setParameter("ring_mod_amount", value: 0.5)
        voiceMachine.setParameter("hard_sync_enable", value: 1.0)
        voiceMachine.setParameter("mod_wheel", value: 0.7)
        voiceMachine.setParameter("aftertouch", value: 0.3)
        voiceMachine.setParameter("lfo1_rate", value: 3.0)
        voiceMachine.setParameter("lfo1_depth", value: 0.8)
        
        // Verify parameters were set
        XCTAssertEqual(voiceMachine.getParameter("ring_mod_amount"), 0.5, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("hard_sync_enable"), 1.0, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("mod_wheel"), 0.7, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("aftertouch"), 0.3, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("lfo1_rate"), 3.0, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("lfo1_depth"), 0.8, accuracy: 0.01)
    }
    
    // MARK: - Parameter Range Tests
    
    func testParameterRangeValidation() {
        // Test that parameters are clamped to valid ranges
        voiceMachine.setParameter("osc1_level", value: 2.0)  // Above max
        XCTAssertLessThanOrEqual(voiceMachine.getParameter("osc1_level"), 1.0)
        
        voiceMachine.setParameter("osc1_level", value: -0.5)  // Below min
        XCTAssertGreaterThanOrEqual(voiceMachine.getParameter("osc1_level"), 0.0)
        
        voiceMachine.setParameter("amp_attack", value: 0.0001)  // Below min
        XCTAssertGreaterThanOrEqual(voiceMachine.getParameter("amp_attack"), 0.001)
        
        voiceMachine.setParameter("amp_attack", value: 20.0)  // Above max
        XCTAssertLessThanOrEqual(voiceMachine.getParameter("amp_attack"), 10.0)
    }
    
    func testParameterCategories() {
        // Test that parameters have correct categories
        let synthParams = ["osc1_tuning", "osc1_level", "noise_level"]
        let envelopeParams = ["amp_attack", "amp_decay", "amp_sustain", "amp_release"]
        let modParams = ["ring_mod_amount", "mod_wheel", "lfo1_rate"]
        
        for paramID in synthParams {
            if let param = voiceMachine.parameters.getParameter(paramID) {
                XCTAssertEqual(param.category, .synthesis, "Parameter \(paramID) should be in synthesis category")
            }
        }
        
        for paramID in envelopeParams {
            if let param = voiceMachine.parameters.getParameter(paramID) {
                XCTAssertEqual(param.category, .envelope, "Parameter \(paramID) should be in envelope category")
            }
        }
        
        for paramID in modParams {
            if let param = voiceMachine.parameters.getParameter(paramID) {
                XCTAssertEqual(param.category, .modulation, "Parameter \(paramID) should be in modulation category")
            }
        }
    }
    
    // MARK: - Preset Management Tests
    
    func testPresetSaving() {
        // Set some parameter values
        voiceMachine.setParameter("osc1_level", value: 0.7)
        voiceMachine.setParameter("osc2_tuning", value: 7.0)
        voiceMachine.setParameter("amp_attack", value: 0.5)
        voiceMachine.setParameter("noise_level", value: 0.3)
        
        // Save preset
        let preset = voiceMachine.savePreset(name: "Test Preset", description: "Test description", category: "Test")
        
        // Verify preset data
        XCTAssertEqual(preset.name, "Test Preset")
        XCTAssertEqual(preset.description, "Test description")
        XCTAssertEqual(preset.category, "Test")
        XCTAssertEqual(preset.parameters["osc1_level"], 0.7, accuracy: 0.01)
        XCTAssertEqual(preset.parameters["osc2_tuning"], 7.0, accuracy: 0.01)
        XCTAssertEqual(preset.parameters["amp_attack"], 0.5, accuracy: 0.01)
        XCTAssertEqual(preset.parameters["noise_level"], 0.3, accuracy: 0.01)
    }
    
    func testPresetLoading() {
        // Create a test preset
        let testParameters: [String: Float] = [
            "osc1_level": 0.6,
            "osc2_tuning": -12.0,
            "amp_attack": 2.0,
            "amp_sustain": 0.8,
            "noise_level": 0.5
        ]
        
        let preset = WavetoneVoiceMachine.WavetonePreset(
            name: "Load Test",
            parameters: testParameters
        )
        
        // Load preset
        voiceMachine.loadPreset(preset)
        
        // Verify parameters were loaded
        XCTAssertEqual(voiceMachine.getParameter("osc1_level"), 0.6, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("osc2_tuning"), -12.0, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("amp_attack"), 2.0, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("amp_sustain"), 0.8, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("noise_level"), 0.5, accuracy: 0.01)
    }
    
    func testFactoryPresets() {
        let factoryPresets = WavetoneVoiceMachine.getFactoryPresets()
        
        // Should have multiple factory presets
        XCTAssertGreaterThan(factoryPresets.count, 0)
        
        // Test loading each factory preset
        for preset in factoryPresets {
            voiceMachine.loadPreset(preset)
            
            // Verify preset loaded without errors
            XCTAssertNotNil(preset.name)
            XCTAssertNotNil(preset.category)
            XCTAssertGreaterThan(preset.parameters.count, 0)
        }
    }
    
    func testDefaultPreset() {
        // Load default preset
        voiceMachine.loadDefaultPreset()
        
        // Verify default values
        XCTAssertEqual(voiceMachine.getParameter("osc1_level"), 0.8, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("osc2_level"), 0.0, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("osc1_tuning"), 0.0, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("osc2_tuning"), 0.0, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("noise_level"), 0.0, accuracy: 0.01)
    }
    
    // MARK: - Performance Tests
    
    func testParameterUpdatePerformance() {
        let parameterIDs = ["osc1_level", "osc2_tuning", "amp_attack", "noise_level", "mod_wheel"]
        
        measure {
            for _ in 0..<1000 {
                for paramID in parameterIDs {
                    voiceMachine.setParameter(paramID, value: Float.random(in: 0.0...1.0))
                }
            }
        }
    }
    
    func testPresetSaveLoadPerformance() {
        // Set up some parameter values
        voiceMachine.setParameter("osc1_level", value: 0.7)
        voiceMachine.setParameter("osc2_tuning", value: 7.0)
        voiceMachine.setParameter("amp_attack", value: 0.5)
        
        measure {
            for i in 0..<100 {
                let preset = voiceMachine.savePreset(name: "Perf Test \(i)")
                voiceMachine.loadPreset(preset)
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testInvalidParameterIDs() {
        // Test setting invalid parameter IDs (should not crash)
        voiceMachine.setParameter("invalid_param", value: 0.5)
        voiceMachine.setParameter("", value: 0.5)
        voiceMachine.setParameter("osc3_level", value: 0.5)  // Non-existent oscillator
        
        // Should complete without crashing
        XCTAssertTrue(true)
    }
    
    func testExtremeParameterValues() {
        // Test with extreme values
        voiceMachine.setParameter("osc1_level", value: Float.infinity)
        voiceMachine.setParameter("osc2_tuning", value: Float.nan)
        voiceMachine.setParameter("amp_attack", value: -Float.infinity)
        
        // Parameters should handle extreme values gracefully
        XCTAssertFalse(voiceMachine.getParameter("osc1_level").isInfinite)
        XCTAssertFalse(voiceMachine.getParameter("osc2_tuning").isNaN)
        XCTAssertFalse(voiceMachine.getParameter("amp_attack").isInfinite)
    }
    
    func testRapidParameterChanges() {
        // Test rapid parameter changes
        for _ in 0..<1000 {
            voiceMachine.setParameter("osc1_level", value: Float.random(in: 0.0...1.0))
            voiceMachine.setParameter("osc2_tuning", value: Float.random(in: -24.0...24.0))
        }
        
        // Should handle rapid changes without issues
        XCTAssertTrue(true)
    }
    
    // MARK: - Integration Tests
    
    func testParameterAudioIntegration() {
        // Test that parameter changes affect audio output
        let audioBuffer = AudioBuffer(channelCount: 2, frameCount: 512)
        
        // Start a note
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        
        // Process audio with default settings
        voiceMachine.processAudio(buffer: audioBuffer)
        let defaultOutput = audioBuffer.getSample(channel: 0, frame: 100)
        
        // Change oscillator level and process again
        voiceMachine.setParameter("osc1_level", value: 0.1)  // Much lower level
        audioBuffer.clear()
        voiceMachine.processAudio(buffer: audioBuffer)
        let lowLevelOutput = audioBuffer.getSample(channel: 0, frame: 100)
        
        // Output should be different (lower amplitude)
        XCTAssertNotEqual(defaultOutput, lowLevelOutput, accuracy: 0.001)
        XCTAssertLessThan(abs(lowLevelOutput), abs(defaultOutput))
        
        voiceMachine.allNotesOff()
    }
}
