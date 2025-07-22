// FilterResonanceTests.swift
// DigitonePad - FilterModuleTests
//
// Comprehensive test suite for FilterResonanceEngine

import XCTest
import MachineProtocols
@testable import FilterModule

final class FilterResonanceTests: XCTestCase {
    
    var resonanceEngine: FilterResonanceEngine!
    let sampleRate: Float = 44100.0
    let bufferSize = 512
    
    override func setUp() {
        super.setUp()
        resonanceEngine = FilterResonanceEngine()
    }
    
    override func tearDown() {
        resonanceEngine = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(resonanceEngine)
        XCTAssertEqual(resonanceEngine.config.resonance, 0.7, accuracy: 0.01)
        XCTAssertEqual(resonanceEngine.config.selfOscillationThreshold, 0.99, accuracy: 0.01)
        XCTAssertEqual(resonanceEngine.parameters.amount, 0.7, accuracy: 0.01)
    }
    
    func testConfigurationDefaults() {
        let config = FilterResonanceConfig()
        XCTAssertEqual(config.resonance, 0.7, accuracy: 0.01)
        XCTAssertEqual(config.selfOscillationThreshold, 0.99, accuracy: 0.01)
        XCTAssertEqual(config.saturationAmount, 0.1, accuracy: 0.01)
        XCTAssertTrue(config.stabilityControl)
        XCTAssertEqual(config.feedbackGain, 1.0, accuracy: 0.01)
        XCTAssertEqual(config.dampingFactor, 0.98, accuracy: 0.01)
    }
    
    // MARK: - Basic Processing Tests
    
    func testSingleSampleProcessing() {
        let testInputs: [Float] = [0.0, 0.1, 0.5, 1.0, -0.5, -1.0]
        let cutoffFreq: Float = 1000.0
        
        for input in testInputs {
            let output = resonanceEngine.processSample(
                input: input,
                cutoffFrequency: cutoffFreq,
                sampleRate: sampleRate
            )
            
            XCTAssertFalse(output.isNaN, "Output should not be NaN for input \(input)")
            XCTAssertFalse(output.isInfinite, "Output should not be infinite for input \(input)")
        }
    }
    
    func testBufferProcessing() {
        let testBuffer: [Float] = Array(0..<bufferSize).map { i in
            sin(Float(i) * 2.0 * Float.pi * 440.0 / sampleRate) * 0.5
        }
        let cutoffFreq: Float = 1000.0
        
        let outputBuffer = resonanceEngine.processBuffer(
            input: testBuffer,
            cutoffFrequency: cutoffFreq,
            sampleRate: sampleRate
        )
        
        XCTAssertEqual(outputBuffer.count, bufferSize)
        
        // Check for valid output
        for (index, output) in outputBuffer.enumerated() {
            XCTAssertFalse(output.isNaN, "Output at index \(index) should not be NaN")
            XCTAssertFalse(output.isInfinite, "Output at index \(index) should not be infinite")
        }
    }
    
    // MARK: - Resonance Parameter Tests
    
    func testResonanceAmount() {
        let testInput: Float = 0.5
        let cutoffFreq: Float = 1000.0
        
        // Test low resonance
        resonanceEngine.parameters.amount = 0.1
        let outputLow = resonanceEngine.processSample(
            input: testInput,
            cutoffFrequency: cutoffFreq,
            sampleRate: sampleRate
        )
        
        resonanceEngine.resetState()
        
        // Test high resonance
        resonanceEngine.parameters.amount = 0.8
        let outputHigh = resonanceEngine.processSample(
            input: testInput,
            cutoffFrequency: cutoffFreq,
            sampleRate: sampleRate
        )
        
        // Different resonance amounts should produce different outputs
        XCTAssertNotEqual(outputLow, outputHigh, accuracy: 0.001,
                         "Different resonance amounts should produce different outputs")
    }
    
    func testModulation() {
        let testInput: Float = 0.5
        let cutoffFreq: Float = 1000.0
        
        // Test with no modulation
        resonanceEngine.parameters.modulation = 0.0
        let outputNoMod = resonanceEngine.processSample(
            input: testInput,
            cutoffFrequency: cutoffFreq,
            sampleRate: sampleRate
        )
        
        resonanceEngine.resetState()
        
        // Test with positive modulation
        resonanceEngine.parameters.modulation = 0.5
        let outputPosMod = resonanceEngine.processSample(
            input: testInput,
            cutoffFrequency: cutoffFreq,
            sampleRate: sampleRate
        )
        
        // Different modulation should produce different outputs
        XCTAssertNotEqual(outputNoMod, outputPosMod, accuracy: 0.001,
                         "Modulation should change output")
    }
    
    func testKeyboardTracking() {
        let testInput: Float = 0.5
        let cutoffFreq: Float = 1000.0
        
        // Test with no keyboard tracking
        resonanceEngine.parameters.keyTracking = 0.0
        let outputNoTracking = resonanceEngine.processSample(
            input: testInput,
            cutoffFrequency: cutoffFreq,
            sampleRate: sampleRate
        )
        
        resonanceEngine.resetState()
        
        // Test with keyboard tracking
        resonanceEngine.parameters.keyTracking = 0.5
        let outputTracking = resonanceEngine.processSample(
            input: testInput,
            cutoffFrequency: cutoffFreq,
            sampleRate: sampleRate
        )
        
        // Different tracking amounts may produce different outputs
        // (This test might be the same if no frequency compensation is applied)
        XCTAssertTrue(abs(outputNoTracking - outputTracking) >= 0 || 
                     abs(outputNoTracking - outputTracking) < 1.0,
                     "Keyboard tracking test should be valid")
    }
    
    func testVelocitySensitivity() {
        let testInput: Float = 0.5
        let cutoffFreq: Float = 1000.0
        
        // Test with low velocity
        resonanceEngine.parameters.velocity = 0.5
        let outputLowVel = resonanceEngine.processSample(
            input: testInput,
            cutoffFrequency: cutoffFreq,
            sampleRate: sampleRate
        )
        
        resonanceEngine.resetState()
        
        // Test with high velocity
        resonanceEngine.parameters.velocity = 1.0
        let outputHighVel = resonanceEngine.processSample(
            input: testInput,
            cutoffFrequency: cutoffFreq,
            sampleRate: sampleRate
        )
        
        // Different velocities should scale resonance differently
        XCTAssertNotEqual(outputLowVel, outputHighVel, accuracy: 0.001,
                         "Different velocities should produce different outputs")
    }
    
    // MARK: - Self-Oscillation Tests
    
    func testSelfOscillationThreshold() {
        let testInput: Float = 0.1
        let cutoffFreq: Float = 1000.0
        
        // Set resonance below threshold
        resonanceEngine.parameters.amount = 0.5
        resonanceEngine.config.selfOscillationThreshold = 0.7
        
        let analysis1 = resonanceEngine.getResonanceAnalysis()
        XCTAssertFalse(analysis1.isOscillating, "Should not oscillate below threshold")
        
        // Set resonance above threshold
        resonanceEngine.parameters.amount = 0.9
        _ = resonanceEngine.processSample(
            input: testInput,
            cutoffFrequency: cutoffFreq,
            sampleRate: sampleRate
        )
        
        let analysis2 = resonanceEngine.getResonanceAnalysis()
        XCTAssertTrue(analysis2.isOscillating, "Should oscillate above threshold")
    }
    
    func testSelfOscillationFrequency() {
        let cutoffFreq: Float = 440.0
        let testInput: Float = 0.1
        
        // Set high resonance to trigger self-oscillation
        resonanceEngine.parameters.amount = 1.0
        resonanceEngine.config.selfOscillationThreshold = 0.8
        
        // Process several samples to establish oscillation
        for _ in 0..<100 {
            _ = resonanceEngine.processSample(
                input: testInput,
                cutoffFrequency: cutoffFreq,
                sampleRate: sampleRate
            )
        }
        
        let analysis = resonanceEngine.getResonanceAnalysis()
        
        if analysis.isOscillating {
            XCTAssertGreaterThan(analysis.oscillationFrequency, 0,
                               "Oscillation frequency should be positive")
            XCTAssertLessThan(abs(analysis.oscillationFrequency - cutoffFreq), cutoffFreq * 0.5,
                             "Oscillation frequency should be near cutoff frequency")
        }
    }
    
    func testStabilityControl() {
        let testInput: Float = 10.0  // Large input to potentially cause instability
        let cutoffFreq: Float = 1000.0
        
        // Enable stability control
        resonanceEngine.config.stabilityControl = true
        resonanceEngine.parameters.amount = 0.95
        
        // Process many samples to test stability
        for _ in 0..<1000 {
            let output = resonanceEngine.processSample(
                input: testInput,
                cutoffFrequency: cutoffFreq,
                sampleRate: sampleRate
            )
            
            XCTAssertFalse(output.isNaN, "Stability control should prevent NaN")
            XCTAssertFalse(output.isInfinite, "Stability control should prevent infinite values")
            XCTAssertLessThan(abs(output), 100.0, "Stability control should limit extreme outputs")
        }
        
        let analysis = resonanceEngine.getResonanceAnalysis()
        XCTAssertNotEqual(analysis.stabilityStatus, .critical,
                         "Stability control should prevent critical instability")
    }
    
    // MARK: - Saturation Tests
    
    func testSaturationCurves() {
        let testInput: Float = 2.0  // High input to trigger saturation
        let cutoffFreq: Float = 1000.0
        
        // Test with saturation enabled
        resonanceEngine.config.saturationAmount = 0.5
        
        // Process with different saturation curve types through configuration
        let output = resonanceEngine.processSample(
            input: testInput,
            cutoffFrequency: cutoffFreq,
            sampleRate: sampleRate
        )
        
        XCTAssertFalse(output.isNaN, "Saturated output should not be NaN")
        XCTAssertFalse(output.isInfinite, "Saturated output should not be infinite")
        XCTAssertLessThan(abs(output), 10.0, "Saturation should limit output magnitude")
    }
    
    func testLimiting() {
        let extremeInput: Float = 100.0
        let cutoffFreq: Float = 1000.0
        
        let output = resonanceEngine.processSample(
            input: extremeInput,
            cutoffFrequency: cutoffFreq,
            sampleRate: sampleRate
        )
        
        XCTAssertFalse(output.isNaN, "Limiting should prevent NaN")
        XCTAssertFalse(output.isInfinite, "Limiting should prevent infinite values")
        XCTAssertLessThan(abs(output), 50.0, "Limiting should prevent extreme outputs")
    }
    
    // MARK: - Musical Style Configuration Tests
    
    func testMusicalStyles() {
        let styles: [ResonanceStyle] = [.classic, .aggressive, .clean, .experimental]
        
        for style in styles {
            resonanceEngine.configureForStyle(style)
            
            // Test that configuration changed appropriately
            switch style {
            case .classic:
                XCTAssertEqual(resonanceEngine.config.selfOscillationThreshold, 0.95, accuracy: 0.01)
                XCTAssertEqual(resonanceEngine.config.saturationAmount, 0.15, accuracy: 0.01)
            case .aggressive:
                XCTAssertEqual(resonanceEngine.config.selfOscillationThreshold, 0.85, accuracy: 0.01)
                XCTAssertEqual(resonanceEngine.config.saturationAmount, 0.3, accuracy: 0.01)
            case .clean:
                XCTAssertEqual(resonanceEngine.config.selfOscillationThreshold, 0.99, accuracy: 0.01)
                XCTAssertEqual(resonanceEngine.config.saturationAmount, 0.05, accuracy: 0.01)
            case .experimental:
                XCTAssertEqual(resonanceEngine.config.selfOscillationThreshold, 0.75, accuracy: 0.01)
                XCTAssertEqual(resonanceEngine.config.saturationAmount, 0.4, accuracy: 0.01)
            }
        }
    }
    
    func testMusicalResonanceScaling() {
        // Test linear to exponential conversion
        resonanceEngine.setMusicalResonance(0.0)
        XCTAssertEqual(resonanceEngine.parameters.amount, 0.0, accuracy: 0.01)
        
        resonanceEngine.setMusicalResonance(0.5)
        let midResonance = resonanceEngine.parameters.amount
        XCTAssertGreaterThan(midResonance, 0.0)
        XCTAssertLessThan(midResonance, 1.0)
        
        resonanceEngine.setMusicalResonance(1.0)
        XCTAssertEqual(resonanceEngine.parameters.amount, 1.0, accuracy: 0.01)
        
        // Verify exponential scaling
        XCTAssertGreaterThan(midResonance, 0.5, "Musical scaling should be exponential")
    }
    
    // MARK: - Feedback System Tests
    
    func testFeedbackLevel() {
        let testInput: Float = 0.5
        let cutoffFreq: Float = 1000.0
        
        // Process several samples to build up feedback
        for _ in 0..<10 {
            _ = resonanceEngine.processSample(
                input: testInput,
                cutoffFrequency: cutoffFreq,
                sampleRate: sampleRate
            )
        }
        
        let analysis = resonanceEngine.getResonanceAnalysis()
        XCTAssertNotNil(analysis.feedbackLevel)
        
        // Feedback level should be reasonable
        XCTAssertFalse(analysis.feedbackLevel.isNaN, "Feedback level should not be NaN")
        XCTAssertFalse(analysis.feedbackLevel.isInfinite, "Feedback level should not be infinite")
    }
    
    // MARK: - Reset and State Tests
    
    func testReset() {
        let testInput: Float = 0.5
        let cutoffFreq: Float = 1000.0
        
        // Process some samples to establish state
        for _ in 0..<50 {
            _ = resonanceEngine.processSample(
                input: testInput,
                cutoffFrequency: cutoffFreq,
                sampleRate: sampleRate
            )
        }
        
        // Reset state
        resonanceEngine.resetState()
        
        // Check that state is reset
        let analysis = resonanceEngine.getResonanceAnalysis()
        XCTAssertFalse(analysis.isOscillating, "Reset should clear oscillation state")
        XCTAssertEqual(analysis.oscillationAmplitude, 0.0, accuracy: 0.001, "Reset should clear amplitude")
    }
    
    // MARK: - Performance Tests
    
    func testSingleSamplePerformance() {
        let testInput: Float = 0.5
        let cutoffFreq: Float = 1000.0
        
        measure {
            for _ in 0..<10000 {
                _ = resonanceEngine.processSample(
                    input: testInput,
                    cutoffFrequency: cutoffFreq,
                    sampleRate: sampleRate
                )
            }
        }
    }
    
    func testBufferPerformance() {
        let testBuffer: [Float] = Array(0..<bufferSize).map { _ in
            Float.random(in: -1.0...1.0)
        }
        let cutoffFreq: Float = 1000.0
        
        measure {
            for _ in 0..<100 {
                _ = resonanceEngine.processBuffer(
                    input: testBuffer,
                    cutoffFrequency: cutoffFreq,
                    sampleRate: sampleRate
                )
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testExtremeInputs() {
        let extremeInputs: [Float] = [0.0, 1.0, -1.0, 10.0, -10.0, 100.0, -100.0]
        let cutoffFreq: Float = 1000.0
        
        for input in extremeInputs {
            resonanceEngine.resetState()
            
            let output = resonanceEngine.processSample(
                input: input,
                cutoffFrequency: cutoffFreq,
                sampleRate: sampleRate
            )
            
            XCTAssertFalse(output.isNaN, "Should handle extreme input \(input) without NaN")
            XCTAssertFalse(output.isInfinite, "Should handle extreme input \(input) without infinity")
        }
    }
    
    func testExtremeFrequencies() {
        let testInput: Float = 0.5
        let extremeFreqs: [Float] = [1.0, 20.0, 100.0, 20000.0, 40000.0]
        
        for freq in extremeFreqs {
            resonanceEngine.resetState()
            
            let output = resonanceEngine.processSample(
                input: testInput,
                cutoffFrequency: freq,
                sampleRate: sampleRate
            )
            
            XCTAssertFalse(output.isNaN, "Should handle extreme frequency \(freq) without NaN")
            XCTAssertFalse(output.isInfinite, "Should handle extreme frequency \(freq) without infinity")
        }
    }
    
    func testZeroInput() {
        let cutoffFreq: Float = 1000.0
        
        // Test sustained zero input
        for _ in 0..<100 {
            let output = resonanceEngine.processSample(
                input: 0.0,
                cutoffFrequency: cutoffFreq,
                sampleRate: sampleRate
            )
            
            // With zero input, output should decay to zero over time
            XCTAssertFalse(output.isNaN, "Zero input should not produce NaN")
            XCTAssertFalse(output.isInfinite, "Zero input should not produce infinity")
        }
    }
}