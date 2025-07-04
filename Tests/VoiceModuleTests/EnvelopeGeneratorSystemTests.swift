// EnvelopeGeneratorSystemTests.swift
// DigitonePad - VoiceModuleTests
//
// Comprehensive test suite for Envelope Generator System

import XCTest
import AudioEngine
import MachineProtocols
@testable import VoiceModule

final class EnvelopeGeneratorSystemTests: XCTestCase {
    
    var envelopeGenerator: EnvelopeGenerator!
    var wavetoneEnvelopeSystem: WavetoneEnvelopeSystem!
    let sampleRate: Double = 44100.0
    
    override func setUp() {
        super.setUp()
        let config = EnvelopeGeneratorConfig()
        envelopeGenerator = EnvelopeGenerator(config: config, sampleRate: sampleRate)
        wavetoneEnvelopeSystem = WavetoneEnvelopeSystem()
    }
    
    override func tearDown() {
        envelopeGenerator = nil
        wavetoneEnvelopeSystem = nil
        super.tearDown()
    }
    
    // MARK: - Basic Envelope Generator Tests
    
    func testEnvelopeGeneratorInitialization() {
        XCTAssertNotNil(envelopeGenerator)
        XCTAssertEqual(envelopeGenerator.stage, .idle)
        XCTAssertEqual(envelopeGenerator.level, 0.0)
        XCTAssertFalse(envelopeGenerator.isActive)
    }
    
    func testEnvelopeNoteOnOff() {
        // Test note on
        envelopeGenerator.noteOn(velocity: 1.0, noteNumber: 60)
        XCTAssertTrue(envelopeGenerator.isActive)
        XCTAssertNotEqual(envelopeGenerator.stage, .idle)
        
        // Process some samples to advance through attack
        for _ in 0..<100 {
            _ = envelopeGenerator.processSample()
        }
        
        // Test note off
        envelopeGenerator.noteOff()
        XCTAssertEqual(envelopeGenerator.stage, .release)
    }
    
    func testEnvelopeStageProgression() {
        var config = EnvelopeGeneratorConfig()
        config.delay.time = 0.01
        config.attack.time = 0.02
        config.decay.time = 0.03
        config.sustain.level = 0.7
        config.release.time = 0.04
        
        envelopeGenerator.config = config
        envelopeGenerator.noteOn(velocity: 1.0, noteNumber: 60)
        
        // Should start in delay stage (if delay > 0)
        XCTAssertEqual(envelopeGenerator.stage, .delay)
        
        // Process through delay stage
        let delaySamples = Int(config.delay.time * Float(sampleRate))
        for _ in 0..<delaySamples + 10 {
            _ = envelopeGenerator.processSample()
        }
        
        // Should be in attack stage
        XCTAssertEqual(envelopeGenerator.stage, .attack)
        
        // Process through attack stage
        let attackSamples = Int(config.attack.time * Float(sampleRate))
        for _ in 0..<attackSamples + 10 {
            _ = envelopeGenerator.processSample()
        }
        
        // Should be in decay stage
        XCTAssertEqual(envelopeGenerator.stage, .decay)
        
        // Process through decay stage
        let decaySamples = Int(config.decay.time * Float(sampleRate))
        for _ in 0..<decaySamples + 10 {
            _ = envelopeGenerator.processSample()
        }
        
        // Should be in sustain stage
        XCTAssertEqual(envelopeGenerator.stage, .sustain)
    }
    
    func testEnvelopeLevels() {
        var config = EnvelopeGeneratorConfig()
        config.attack.time = 0.01
        config.decay.time = 0.01
        config.sustain.level = 0.5
        config.release.time = 0.01
        
        envelopeGenerator.config = config
        envelopeGenerator.noteOn(velocity: 1.0, noteNumber: 60)
        
        // Process through attack - should reach peak
        let attackSamples = Int(config.attack.time * Float(sampleRate))
        for _ in 0..<attackSamples {
            _ = envelopeGenerator.processSample()
        }
        
        // Should be near peak level
        XCTAssertGreaterThan(envelopeGenerator.level, 0.8, "Should reach near peak during attack")
        
        // Process through decay - should reach sustain level
        let decaySamples = Int(config.decay.time * Float(sampleRate))
        for _ in 0..<decaySamples + 100 {
            _ = envelopeGenerator.processSample()
        }
        
        // Should be at sustain level
        XCTAssertEqual(envelopeGenerator.level, config.sustain.level, accuracy: 0.1, "Should reach sustain level")
        
        // Note off and process release
        envelopeGenerator.noteOff()
        let releaseSamples = Int(config.release.time * Float(sampleRate))
        for _ in 0..<releaseSamples + 100 {
            _ = envelopeGenerator.processSample()
        }
        
        // Should be near zero
        XCTAssertLessThan(envelopeGenerator.level, 0.1, "Should reach near zero after release")
    }
    
    func testVelocitySensitivity() {
        var config = EnvelopeGeneratorConfig()
        config.velocitySensitivity = 1.0  // Full velocity sensitivity
        config.attack.time = 0.01
        
        envelopeGenerator.config = config
        
        // Test low velocity
        envelopeGenerator.reset()
        envelopeGenerator.noteOn(velocity: 0.5, noteNumber: 60)
        
        let attackSamples = Int(config.attack.time * Float(sampleRate))
        for _ in 0..<attackSamples {
            _ = envelopeGenerator.processSample()
        }
        
        let lowVelocityLevel = envelopeGenerator.level
        
        // Test high velocity
        envelopeGenerator.reset()
        envelopeGenerator.noteOn(velocity: 1.0, noteNumber: 60)
        
        for _ in 0..<attackSamples {
            _ = envelopeGenerator.processSample()
        }
        
        let highVelocityLevel = envelopeGenerator.level
        
        // High velocity should produce higher level
        XCTAssertGreaterThan(highVelocityLevel, lowVelocityLevel, "High velocity should produce higher level")
    }
    
    func testEnvelopeCurves() {
        let curves: [EnvelopeCurveType] = [.linear, .exponential, .logarithmic, .sine, .cosine, .power]
        
        for curve in curves {
            var config = EnvelopeGeneratorConfig()
            config.attack.curve = curve
            config.attack.time = 0.1
            
            envelopeGenerator.config = config
            envelopeGenerator.reset()
            envelopeGenerator.noteOn(velocity: 1.0, noteNumber: 60)
            
            var levels: [Float] = []
            let attackSamples = Int(config.attack.time * Float(sampleRate))
            
            for _ in 0..<attackSamples {
                levels.append(envelopeGenerator.processSample())
            }
            
            // Should have progression from 0 to peak
            XCTAssertLessThan(levels.first ?? 1.0, 0.1, "Should start near zero for \(curve)")
            XCTAssertGreaterThan(levels.last ?? 0.0, 0.8, "Should end near peak for \(curve)")
            
            // Should be monotonically increasing (for attack)
            for i in 1..<levels.count {
                XCTAssertGreaterThanOrEqual(levels[i], levels[i-1] - 0.01, "Should be increasing for \(curve)")
            }
        }
    }
    
    // MARK: - WAVETONE Envelope System Tests
    
    func testWavetoneEnvelopeSystemInitialization() {
        XCTAssertNotNil(wavetoneEnvelopeSystem)
        XCTAssertFalse(wavetoneEnvelopeSystem.getCurrentState().isActive)
        XCTAssertEqual(wavetoneEnvelopeSystem.getCurrentLevel(), 0.0)
    }
    
    func testWavetoneEnvelopeSystemNoteOnOff() {
        // Test note on (trigger)
        wavetoneEnvelopeSystem.trigger(velocity: 1.0, noteNumber: 60)
        XCTAssertTrue(wavetoneEnvelopeSystem.getCurrentState().isActive)

        // Should be in attack phase initially
        XCTAssertEqual(wavetoneEnvelopeSystem.getCurrentPhase(), .attack)

        // Test note off (release)
        wavetoneEnvelopeSystem.release()

        // Should be in release phase
        XCTAssertEqual(wavetoneEnvelopeSystem.getCurrentPhase(), .release)
    }
    
    func testWavetoneEnvelopeProcessing() {
        wavetoneEnvelopeSystem.trigger(velocity: 1.0, noteNumber: 60)

        // Process envelope
        let envelopeValue = wavetoneEnvelopeSystem.processSample()

        // Should get a valid envelope value
        XCTAssertGreaterThanOrEqual(envelopeValue, 0.0)
        XCTAssertLessThanOrEqual(envelopeValue, 1.0)

        // Process multiple samples to test progression
        var values: [Float] = []
        for _ in 0..<10 {
            values.append(wavetoneEnvelopeSystem.processSample())
        }

        // Values should be in valid range
        for value in values {
            XCTAssertGreaterThanOrEqual(value, 0.0)
            XCTAssertLessThanOrEqual(value, 1.0)
        }
    }
    
    // TODO: Implement preset configurations when WavetonePresetType is available
    /*
    func testWavetonePresetConfigurations() {
        let presetTypes: [WavetonePresetType] = [.lead, .pad, .pluck, .bass, .organ]

        for presetType in presetTypes {
            let config = WavetoneEnvelopeSystem.createPresetConfiguration(type: presetType)

            // Verify configuration is valid
            XCTAssertGreaterThan(config.amplitudeConfig.attack.time, 0.0, "Attack time should be positive for \(presetType)")
            XCTAssertGreaterThan(config.amplitudeConfig.release.time, 0.0, "Release time should be positive for \(presetType)")
            XCTAssertGreaterThanOrEqual(config.amplitudeConfig.sustain.level, 0.0, "Sustain level should be non-negative for \(presetType)")
            XCTAssertLessThanOrEqual(config.amplitudeConfig.sustain.level, 1.0, "Sustain level should not exceed 1.0 for \(presetType)")

            // Test that configuration can be applied
            let testSystem = WavetoneEnvelopeSystem(configuration: config, sampleRate: sampleRate)
            XCTAssertNotNil(testSystem, "Should be able to create system with \(presetType) preset")
        }
    }
    */
    
    // MARK: - Parameter Manager Tests
    
    // TODO: Implement parameter manager when EnvelopeParameterManager is available
    /*
    func testEnvelopeParameterManager() {
        let parameterManager = EnvelopeParameterManager(envelopeSystem: wavetoneEnvelopeSystem)
        let parameters = parameterManager.createParameters()

        // Should create parameters for all envelope types
        XCTAssertGreaterThan(parameters.count, 10, "Should create multiple parameters")

        // Check for specific parameters
        let parameterIDs = parameters.map { $0.id }
        XCTAssertTrue(parameterIDs.contains("amp_attack"), "Should have amplitude attack parameter")
        XCTAssertTrue(parameterIDs.contains("filter_decay"), "Should have filter decay parameter")
        XCTAssertTrue(parameterIDs.contains("pitch_sustain"), "Should have pitch sustain parameter")
        XCTAssertTrue(parameterIDs.contains("aux_release"), "Should have aux release parameter")
    }

    func testParameterUpdates() {
        let parameterManager = EnvelopeParameterManager(envelopeSystem: wavetoneEnvelopeSystem)

        // Test amplitude attack parameter update
        let originalAttack = wavetoneEnvelopeSystem.amplitudeEnvelope.config.attack.time
        parameterManager.handleParameterUpdate(parameterID: "amp_attack", value: 0.5)
        let newAttack = wavetoneEnvelopeSystem.amplitudeEnvelope.config.attack.time

        XCTAssertNotEqual(originalAttack, newAttack, "Parameter update should change envelope config")
        XCTAssertEqual(newAttack, 0.5, accuracy: 0.01, "Should set attack time to new value")

        // Test filter sustain parameter update
        parameterManager.handleParameterUpdate(parameterID: "filter_sustain", value: 0.3)
        let filterSustain = wavetoneEnvelopeSystem.filterEnvelope.config.sustain.level
        XCTAssertEqual(filterSustain, 0.3, accuracy: 0.01, "Should set filter sustain level")
    }
    */
    
    // MARK: - Performance Tests
    
    func testEnvelopePerformance() {
        envelopeGenerator.noteOn(velocity: 1.0, noteNumber: 60)
        
        measure {
            for _ in 0..<10000 {
                _ = envelopeGenerator.processSample()
            }
        }
    }
    
    func testWavetoneSystemPerformance() {
        wavetoneEnvelopeSystem.trigger(velocity: 1.0, noteNumber: 60)

        measure {
            for _ in 0..<1000 {
                _ = wavetoneEnvelopeSystem.processSample()
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEnvelopeReset() {
        envelopeGenerator.noteOn(velocity: 1.0, noteNumber: 60)
        
        // Process some samples
        for _ in 0..<100 {
            _ = envelopeGenerator.processSample()
        }
        
        // Reset envelope
        envelopeGenerator.reset()
        
        XCTAssertEqual(envelopeGenerator.stage, .idle)
        XCTAssertEqual(envelopeGenerator.level, 0.0)
        XCTAssertFalse(envelopeGenerator.isActive)
    }
    
    func testZeroTimings() {
        var config = EnvelopeGeneratorConfig()
        config.attack.time = 0.0
        config.decay.time = 0.0
        config.release.time = 0.0
        
        envelopeGenerator.config = config
        envelopeGenerator.noteOn(velocity: 1.0, noteNumber: 60)
        
        // Should handle zero timings without crashing
        for _ in 0..<100 {
            let level = envelopeGenerator.processSample()
            XCTAssertFalse(level.isNaN, "Level should not be NaN with zero timings")
            XCTAssertFalse(level.isInfinite, "Level should not be infinite with zero timings")
        }
    }
    
    func testExtremeVelocities() {
        // Test zero velocity
        envelopeGenerator.noteOn(velocity: 0.0, noteNumber: 60)
        for _ in 0..<100 {
            let level = envelopeGenerator.processSample()
            XCTAssertGreaterThanOrEqual(level, 0.0, "Level should be non-negative with zero velocity")
        }
        
        // Test maximum velocity
        envelopeGenerator.reset()
        envelopeGenerator.noteOn(velocity: 1.0, noteNumber: 60)
        for _ in 0..<100 {
            let level = envelopeGenerator.processSample()
            XCTAssertLessThanOrEqual(level, 1.0, "Level should not exceed 1.0 with max velocity")
        }
    }
    
    func testKeyTracking() {
        var config = EnvelopeGeneratorConfig()
        config.keyTracking = 0.5  // Positive key tracking
        config.attack.time = 0.1
        
        envelopeGenerator.config = config
        
        // Test low note
        envelopeGenerator.noteOn(velocity: 1.0, noteNumber: 36)  // Low C
        let attackSamples = Int(config.attack.time * Float(sampleRate))
        for _ in 0..<attackSamples / 2 {
            _ = envelopeGenerator.processSample()
        }
        let lowNoteLevel = envelopeGenerator.level
        
        // Test high note
        envelopeGenerator.reset()
        envelopeGenerator.noteOn(velocity: 1.0, noteNumber: 84)  // High C
        for _ in 0..<attackSamples / 2 {
            _ = envelopeGenerator.processSample()
        }
        let highNoteLevel = envelopeGenerator.level
        
        // With positive key tracking, higher notes should have faster envelopes
        // (reach higher levels in the same time)
        XCTAssertGreaterThan(highNoteLevel, lowNoteLevel, "Higher notes should have faster envelopes with positive key tracking")
    }
}
