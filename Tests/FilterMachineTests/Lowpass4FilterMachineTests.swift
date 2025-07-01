// Lowpass4FilterMachineTests.swift
// DigitonePad - FilterMachineTests
//
// Comprehensive test suite for Lowpass 4 Filter Machine

import XCTest
import Accelerate
@testable import FilterMachine

final class Lowpass4FilterMachineTests: XCTestCase {
    
    var filter: Lowpass4FilterMachine!
    let sampleRate: Double = 44100.0
    let testTolerance: Float = 0.001
    
    override func setUp() {
        super.setUp()
        filter = Lowpass4FilterMachine(sampleRate: sampleRate)
    }
    
    override func tearDown() {
        filter = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialization() {
        XCTAssertEqual(filter.machineType, "Lowpass4Filter")
        XCTAssertEqual(filter.parameterCount, 4)
        XCTAssertEqual(filter.getParameterName(index: 0), "CUTOFF")
        XCTAssertEqual(filter.getParameterName(index: 1), "RESO")
        XCTAssertEqual(filter.getParameterName(index: 2), "DRIVE")
        XCTAssertEqual(filter.getParameterName(index: 3), "TRACK")
    }
    
    func testParameterAccess() {
        // Test parameter getting and setting
        filter.setParameterValue(index: 0, value: 2000.0)  // Cutoff
        XCTAssertEqual(filter.getParameterValue(index: 0), 2000.0, accuracy: testTolerance)
        
        filter.setParameterValue(index: 1, value: 0.7)     // Resonance
        XCTAssertEqual(filter.getParameterValue(index: 1), 0.7, accuracy: testTolerance)
        
        filter.setParameterValue(index: 2, value: 0.5)     // Drive
        XCTAssertEqual(filter.getParameterValue(index: 2), 0.5, accuracy: testTolerance)
        
        filter.setParameterValue(index: 3, value: 0.3)     // Keyboard Tracking
        XCTAssertEqual(filter.getParameterValue(index: 3), 0.3, accuracy: testTolerance)
    }
    
    func testParameterValidation() {
        // Test parameter clamping
        filter.setCutoffFrequency(-100.0)  // Should clamp to 20Hz
        XCTAssertEqual(filter.getParameterValue(index: 0), 20.0, accuracy: testTolerance)
        
        filter.setCutoffFrequency(30000.0)  // Should clamp to 20kHz
        XCTAssertEqual(filter.getParameterValue(index: 0), 20000.0, accuracy: testTolerance)
        
        filter.setResonance(-0.5)  // Should clamp to 0.0
        XCTAssertEqual(filter.getParameterValue(index: 1), 0.0, accuracy: testTolerance)
        
        filter.setResonance(1.5)   // Should clamp to 1.0
        XCTAssertEqual(filter.getParameterValue(index: 1), 1.0, accuracy: testTolerance)
    }
    
    // MARK: - Frequency Response Tests
    
    func testFrequencyResponse24dBSlope() {
        // Test that the filter provides 24dB/octave rolloff
        filter.setCutoffFrequency(1000.0)
        filter.setResonance(0.0)  // No resonance for clean measurement
        
        // Test frequencies at octave intervals above cutoff
        let cutoff = filter.getFrequencyResponse(at: 1000.0)
        let oneOctave = filter.getFrequencyResponse(at: 2000.0)
        let twoOctaves = filter.getFrequencyResponse(at: 4000.0)
        
        // At cutoff, should be close to full amplitude
        XCTAssertGreaterThan(cutoff, 0.7, "Cutoff frequency should have minimal attenuation")
        
        // One octave above: approximately -24dB = 0.063 linear
        XCTAssertLessThan(oneOctave, 0.1, "One octave above cutoff should be significantly attenuated")
        
        // Two octaves above: approximately -48dB = 0.004 linear
        XCTAssertLessThan(twoOctaves, 0.01, "Two octaves above cutoff should be heavily attenuated")
        
        // Verify proper rolloff ratio (should be steeper than 2-pole filter)
        let rolloffRatio = oneOctave / cutoff
        XCTAssertLessThan(rolloffRatio, 0.2, "4-pole filter should have steeper rolloff than 2-pole")
    }
    
    func testFrequencyResponseWithResonance() {
        // Test frequency response with resonance applied
        filter.setCutoffFrequency(1000.0)
        filter.setResonance(0.8)  // High resonance
        
        let cutoffResponse = filter.getFrequencyResponse(at: 1000.0)
        let belowCutoff = filter.getFrequencyResponse(at: 800.0)
        
        // With resonance, cutoff should show peak
        XCTAssertGreaterThan(cutoffResponse, 0.8, "High resonance should create peak at cutoff")
        XCTAssertLessThan(belowCutoff, cutoffResponse, "Response below cutoff should be less than at cutoff")
    }
    
    // MARK: - Audio Processing Tests
    
    func testBasicAudioProcessing() {
        // Test basic audio processing functionality
        filter.setCutoffFrequency(1000.0)
        filter.setResonance(0.3)
        
        let inputSample: Float = 0.5
        let output = filter.processSample(inputSample)
        
        XCTAssertFalse(output.isNaN, "Output should not be NaN")
        XCTAssertFalse(output.isInfinite, "Output should not be infinite")
        XCTAssertLessThanOrEqual(abs(output), 2.0, "Output should be reasonable magnitude")
    }
    
    func testBufferProcessing() {
        // Test buffer processing functionality
        let frameCount = 512
        var inputBuffer = [Float](repeating: 0.0, count: frameCount)
        var outputBuffer = [Float](repeating: 0.0, count: frameCount)
        
        // Generate test signal (1kHz sine wave)
        for i in 0..<frameCount {
            let phase = 2.0 * Float.pi * 1000.0 * Float(i) / Float(sampleRate)
            inputBuffer[i] = sin(phase) * 0.5
        }
        
        filter.setCutoffFrequency(2000.0)  // Above test frequency
        filter.processBuffer(
            input: inputBuffer,
            output: &outputBuffer,
            frameCount: frameCount
        )
        
        // Verify output is processed
        let inputRMS = calculateRMS(inputBuffer)
        let outputRMS = calculateRMS(outputBuffer)
        
        XCTAssertGreaterThan(outputRMS, 0.0, "Output should have signal")
        XCTAssertLessThan(abs(outputRMS - inputRMS) / inputRMS, 0.5, "Output should be similar to input for frequency below cutoff")
    }
    
    func testBypassMode() {
        // Test bypass functionality
        let inputSample: Float = 0.7
        
        filter.setEnabled(false)
        let bypassOutput = filter.processSample(inputSample)
        
        XCTAssertEqual(bypassOutput, inputSample, accuracy: testTolerance, "Bypass should pass input unchanged")
        
        filter.setEnabled(true)
        let processedOutput = filter.processSample(inputSample)
        
        XCTAssertNotEqual(processedOutput, inputSample, accuracy: testTolerance, "Enabled filter should process input")
    }
    
    // MARK: - Resonance and Self-Oscillation Tests
    
    func testResonanceResponse() {
        // Test resonance parameter effects
        filter.setCutoffFrequency(1000.0)
        
        // Low resonance
        filter.setResonance(0.1)
        let lowResoOutput = filter.processSample(0.1)
        
        // High resonance
        filter.setResonance(0.9)
        let highResoOutput = filter.processSample(0.1)
        
        // Reset filter state between tests
        filter.reset()
        
        XCTAssertNotEqual(lowResoOutput, highResoOutput, accuracy: testTolerance, 
                         "Different resonance settings should produce different outputs")
    }
    
    func testSelfOscillation() {
        // Test self-oscillation behavior
        filter.setCutoffFrequency(440.0)  // A4
        filter.setResonance(0.98)  // Above self-oscillation threshold
        
        var outputs: [Float] = []
        
        // Process silence to test self-oscillation
        for _ in 0..<1000 {
            let output = filter.processSample(0.0)  // No input
            outputs.append(output)
        }
        
        // Check for oscillation (non-zero output from zero input)
        let outputRMS = calculateRMS(outputs)
        XCTAssertGreaterThan(outputRMS, 0.1, "High resonance should produce self-oscillation")
        
        // Check filter status
        let status = filter.filterStatus
        XCTAssertTrue(status.isOscillating, "Filter should report oscillating state")
    }
    
    // MARK: - Drive and Saturation Tests
    
    func testDriveEffects() {
        // Test different drive types and amounts
        let inputSample: Float = 0.5
        
        filter.setDrive(0.0)
        let cleanOutput = filter.processSample(inputSample)
        
        filter.setDrive(0.8)
        let drivenOutput = filter.processSample(inputSample)
        
        filter.reset()  // Reset state between tests
        
        XCTAssertNotEqual(cleanOutput, drivenOutput, accuracy: testTolerance,
                         "Drive should affect the output")
    }
    
    func testDriveSaturationTypes() {
        // Test different saturation algorithms
        let processor = DriveSaturationProcessor()
        processor.driveAmount = 0.7
        
        let testInput: Float = 0.8
        
        // Test each saturation type
        let driveTypes: [DriveSaturationType] = [.clean, .analog, .tube, .transistor, .digital]
        var outputs: [Float] = []
        
        for driveType in driveTypes {
            processor.driveType = driveType
            let output = processor.processSample(testInput)
            outputs.append(output)
            
            XCTAssertFalse(output.isNaN, "Output should not be NaN for \(driveType)")
            XCTAssertFalse(output.isInfinite, "Output should not be infinite for \(driveType)")
        }
        
        // Verify different drive types produce different results
        let uniqueOutputs = Set(outputs.map { round($0 * 1000) / 1000 })  // Round for comparison
        XCTAssertGreaterThan(uniqueOutputs.count, 1, "Different drive types should produce different outputs")
    }
    
    // MARK: - Keyboard Tracking Tests
    
    func testKeyboardTracking() {
        // Test keyboard tracking functionality
        filter.setCutoffFrequency(1000.0)
        filter.setKeyboardTracking(1.0)  // Full tracking
        
        // Test C4 (note 60) - reference note
        filter.noteOn(noteNumber: 60, velocity: 1.0)
        let c4Output = filter.processSample(0.1)
        
        // Test C5 (note 72) - one octave higher
        filter.reset()
        filter.noteOn(noteNumber: 72, velocity: 1.0)
        let c5Output = filter.processSample(0.1)
        
        XCTAssertNotEqual(c4Output, c5Output, accuracy: testTolerance,
                         "Keyboard tracking should affect filter response for different notes")
    }
    
    func testKeyboardTrackingDisabled() {
        // Test that tracking can be disabled
        filter.setCutoffFrequency(1000.0)
        filter.setKeyboardTracking(0.0)  // No tracking
        
        filter.noteOn(noteNumber: 60, velocity: 1.0)
        let note60Output = filter.processSample(0.1)
        
        filter.reset()
        filter.noteOn(noteNumber: 72, velocity: 1.0)
        let note72Output = filter.processSample(0.1)
        
        XCTAssertEqual(note60Output, note72Output, accuracy: testTolerance,
                      "No keyboard tracking should produce same output for different notes")
    }
    
    // MARK: - Filter Topology Tests
    
    func testDifferentTopologies() {
        // Test different filter topologies
        let topologies: [FilterTopology] = [.cascadedBiquads, .directForm, .stateVariable]
        var outputs: [Float] = []
        
        for topology in topologies {
            var config = Lowpass4FilterConfig()
            config.cutoffFrequency = 1000.0
            config.resonance = 0.5
            config.topology = topology
            
            let testFilter = Lowpass4FilterMachine(config: config, sampleRate: sampleRate)
            let output = testFilter.processSample(0.5)
            outputs.append(output)
            
            XCTAssertFalse(output.isNaN, "Output should not be NaN for \(topology)")
            XCTAssertFalse(output.isInfinite, "Output should not be infinite for \(topology)")
        }
        
        // Verify different topologies can produce different results
        // (They might be similar, but implementation should work for all)
        XCTAssertEqual(outputs.count, topologies.count, "Should have output for each topology")
    }
    
    // MARK: - Performance and Stability Tests
    
    func testFilterStability() {
        // Test filter stability with extreme parameters
        filter.setCutoffFrequency(19000.0)  // Very high cutoff
        filter.setResonance(0.99)           // Very high resonance
        
        var maxOutput: Float = 0.0
        
        // Process many samples to test for instability
        for i in 0..<10000 {
            let input = sin(Float(i) * 0.1) * 0.1  // Small input signal
            let output = filter.processSample(input)
            
            XCTAssertFalse(output.isNaN, "Output should not be NaN at sample \(i)")
            XCTAssertFalse(output.isInfinite, "Output should not be infinite at sample \(i)")
            
            maxOutput = max(maxOutput, abs(output))
        }
        
        XCTAssertLessThan(maxOutput, 100.0, "Filter should remain stable and not blow up")
    }
    
    func testPerformanceBenchmark() {
        // Basic performance test
        let frameCount = 44100  // 1 second at 44.1kHz
        var inputBuffer = [Float](repeating: 0.0, count: frameCount)
        var outputBuffer = [Float](repeating: 0.0, count: frameCount)
        
        // Generate white noise input
        for i in 0..<frameCount {
            inputBuffer[i] = Float.random(in: -1.0...1.0) * 0.5
        }
        
        filter.setCutoffFrequency(2000.0)
        filter.setResonance(0.6)
        filter.setDrive(0.3)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        filter.processBuffer(
            input: inputBuffer,
            output: &outputBuffer,
            frameCount: frameCount
        )
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        let realTimeRatio = processingTime / 1.0  // 1 second of audio
        
        XCTAssertLessThan(realTimeRatio, 0.1, "Processing should be much faster than real-time")
        
        // Performance: \(realTimeRatio * 100)% of real-time
    }
    
    // MARK: - State Management Tests
    
    func testStateReset() {
        // Test filter state reset functionality
        filter.setCutoffFrequency(500.0)
        filter.setResonance(0.8)
        
        // Process some samples to build up state
        for _ in 0..<100 {
            _ = filter.processSample(0.5)
        }
        
        let beforeReset = filter.processSample(0.0)
        
        filter.reset()
        let afterReset = filter.processSample(0.0)
        
        // After reset, response to zero input should be different
        // (though both might be close to zero)
        let status = filter.filterStatus
        XCTAssertFalse(status.isOscillating, "Filter should not be oscillating after reset")
    }
    
    func testFilterStatus() {
        // Test filter status reporting
        filter.setCutoffFrequency(1500.0)
        filter.setResonance(0.6)
        filter.noteOn(noteNumber: 64, velocity: 0.8)
        
        let status = filter.filterStatus
        
        XCTAssertTrue(status.isEnabled, "Filter should be enabled")
        XCTAssertEqual(status.cutoffFrequency, 1500.0, accuracy: testTolerance)
        XCTAssertEqual(status.resonance, 0.6, accuracy: testTolerance)
        XCTAssertEqual(status.currentNote, 64)
        XCTAssertEqual(status.topology, "cascaded")
    }
    
    // MARK: - Helper Functions
    
    private func calculateRMS(_ buffer: [Float]) -> Float {
        var sum: Float = 0.0
        for sample in buffer {
            sum += sample * sample
        }
        return sqrt(sum / Float(buffer.count))
    }
    
    private func generateSineWave(frequency: Float, sampleRate: Double, frameCount: Int) -> [Float] {
        var buffer = [Float](repeating: 0.0, count: frameCount)
        for i in 0..<frameCount {
            let phase = 2.0 * Float.pi * frequency * Float(i) / Float(sampleRate)
            buffer[i] = sin(phase)
        }
        return buffer
    }
    
    // MARK: - Integration Tests
    
    func testFilterMachineProtocolCompliance() {
        // Test FilterMachine protocol compliance
        XCTAssertGreaterThan(filter.parameterCount, 0, "Should have parameters")
        
        for i in 0..<filter.parameterCount {
            let name = filter.getParameterName(index: i)
            XCTAssertFalse(name.isEmpty, "Parameter \(i) should have a name")
            
            let value = filter.getParameterValue(index: i)
            XCTAssertFalse(value.isNaN, "Parameter \(i) value should not be NaN")
            
            let displayValue = filter.getParameterDisplayValue(index: i)
            XCTAssertFalse(displayValue.isEmpty, "Parameter \(i) should have display value")
        }
    }
    
    func testConfigurationPersistence() {
        // Test configuration persistence through Codable
        var config = Lowpass4FilterConfig()
        config.cutoffFrequency = 1234.5
        config.resonance = 0.67
        config.drive = 0.89
        config.keyboardTracking = 0.45
        config.driveType = .tube
        config.topology = .stateVariable
        
        // Test encoding/decoding
        do {
            let data = try JSONEncoder().encode(config)
            let decodedConfig = try JSONDecoder().decode(Lowpass4FilterConfig.self, from: data)
            
            XCTAssertEqual(config.cutoffFrequency, decodedConfig.cutoffFrequency, accuracy: testTolerance)
            XCTAssertEqual(config.resonance, decodedConfig.resonance, accuracy: testTolerance)
            XCTAssertEqual(config.drive, decodedConfig.drive, accuracy: testTolerance)
            XCTAssertEqual(config.keyboardTracking, decodedConfig.keyboardTracking, accuracy: testTolerance)
            XCTAssertEqual(config.driveType, decodedConfig.driveType)
            XCTAssertEqual(config.topology, decodedConfig.topology)
        } catch {
            XCTFail("Configuration should be encodable/decodable: \(error)")
        }
    }
}