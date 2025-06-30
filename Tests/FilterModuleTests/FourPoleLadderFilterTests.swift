// FourPoleLadderFilterTests.swift
// DigitonePad - FilterModuleTests
//
// Comprehensive test suite for 4-Pole Ladder Filter

import XCTest
import MachineProtocols
@testable import FilterModule

final class FourPoleLadderFilterTests: XCTestCase {
    
    var ladderFilter: FourPoleLadderFilter!
    let sampleRate: Double = 44100.0
    let bufferSize = 512
    
    override func setUp() {
        super.setUp()
        var config = LadderFilterConfig()
        config.cutoff = 1000.0
        config.resonance = 0.0
        config.drive = 1.0
        ladderFilter = FourPoleLadderFilter(config: config, sampleRate: sampleRate)
    }
    
    override func tearDown() {
        ladderFilter = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialization() {
        XCTAssertNotNil(ladderFilter)
        XCTAssertEqual(ladderFilter.name, "4-Pole Ladder")
        XCTAssertEqual(ladderFilter.filterType, .lowpass)
        XCTAssertEqual(ladderFilter.slope, .slope24dB)
        XCTAssertEqual(ladderFilter.quality, .high)
        XCTAssertTrue(ladderFilter.isEnabled)
        XCTAssertTrue(ladderFilter.isActive)
    }
    
    func testConfigurationAccess() {
        // Test cutoff property
        ladderFilter.cutoff = 2000.0
        XCTAssertEqual(ladderFilter.cutoff, 2000.0, accuracy: 0.1)
        
        // Test resonance property
        ladderFilter.resonance = 0.5
        XCTAssertEqual(ladderFilter.resonance, 0.5, accuracy: 0.01)
        
        // Test drive property
        ladderFilter.drive = 2.0
        XCTAssertEqual(ladderFilter.drive, 2.0, accuracy: 0.01)
    }
    
    func testParameterBounds() {
        // Test cutoff bounds
        ladderFilter.cutoff = -100.0
        XCTAssertGreaterThanOrEqual(ladderFilter.cutoff, 20.0, "Cutoff should be clamped to minimum")
        
        ladderFilter.cutoff = 50000.0
        XCTAssertLessThanOrEqual(ladderFilter.cutoff, 20000.0, "Cutoff should be clamped to maximum")
        
        // Test resonance bounds
        ladderFilter.resonance = -0.5
        XCTAssertGreaterThanOrEqual(ladderFilter.resonance, 0.0, "Resonance should be clamped to minimum")
        
        ladderFilter.resonance = 1.5
        XCTAssertLessThanOrEqual(ladderFilter.resonance, 1.0, "Resonance should be clamped to maximum")
        
        // Test drive bounds
        ladderFilter.drive = -1.0
        XCTAssertGreaterThanOrEqual(ladderFilter.drive, 0.0, "Drive should be clamped to minimum")
        
        ladderFilter.drive = 20.0
        XCTAssertLessThanOrEqual(ladderFilter.drive, 10.0, "Drive should be clamped to maximum")
    }
    
    // MARK: - Audio Processing Tests
    
    func testAudioProcessing() {
        // Create test input buffer
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize * 2)
        inputData.initialize(repeating: 0.0, count: bufferSize * 2)
        
        // Fill with test signal (1kHz sine wave)
        for i in 0..<bufferSize {
            let phase = Float(i) * 2.0 * Float.pi * 1000.0 / Float(sampleRate)
            let sample = sin(phase) * 0.5
            inputData[i * 2] = sample      // Left channel
            inputData[i * 2 + 1] = sample  // Right channel
        }
        
        let inputBuffer = MachineProtocols.AudioBuffer(
            data: inputData,
            frameCount: bufferSize,
            channelCount: 2,
            sampleRate: sampleRate
        )
        
        // Process audio
        let outputBuffer = ladderFilter.process(input: inputBuffer)
        
        XCTAssertEqual(outputBuffer.frameCount, bufferSize)
        XCTAssertEqual(outputBuffer.channelCount, 2)
        XCTAssertEqual(outputBuffer.sampleRate, sampleRate)
        
        // Check that output is not silent
        var hasNonZeroOutput = false
        for i in 0..<bufferSize * 2 {
            if abs(outputBuffer.data[i]) > 0.001 {
                hasNonZeroOutput = true
                break
            }
        }
        XCTAssertTrue(hasNonZeroOutput, "Filter should produce non-zero output")
        
        inputData.deallocate()
    }
    
    func testSingleSampleProcessing() {
        // Test with various input levels
        let testInputs: [Float] = [0.0, 0.1, 0.5, 1.0, -0.5, -1.0]
        
        for input in testInputs {
            let output = ladderFilter.processSample(input)
            
            XCTAssertFalse(output.isNaN, "Output should not be NaN for input \(input)")
            XCTAssertFalse(output.isInfinite, "Output should not be infinite for input \(input)")
            
            // For a lowpass filter, output should generally be smaller than input for high frequencies
            if abs(input) > 0.1 {
                XCTAssertLessThanOrEqual(abs(output), abs(input) * 2.0, "Output should be reasonable for input \(input)")
            }
        }
    }
    
    // MARK: - Filter Characteristics Tests
    
    func testLowpassCharacteristics() {
        ladderFilter.cutoff = 1000.0
        ladderFilter.resonance = 0.0
        
        // Test frequency response at different frequencies
        let testFrequencies: [Float] = [100.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0]
        var responses: [Float] = []
        
        for frequency in testFrequencies {
            let response = ladderFilter.getFrequencyResponse(at: frequency)
            responses.append(response.magnitude)
        }
        
        // For a lowpass filter, magnitude should decrease with frequency above cutoff
        for i in 1..<responses.count {
            if testFrequencies[i] > ladderFilter.cutoff {
                XCTAssertLessThanOrEqual(responses[i], responses[i-1] * 1.1, 
                                       "Lowpass filter should attenuate higher frequencies")
            }
        }
    }
    
    func testResonanceEffect() {
        ladderFilter.cutoff = 1000.0
        
        // Test with no resonance
        ladderFilter.resonance = 0.0
        let responseNoRes = ladderFilter.getFrequencyResponse(at: 1000.0)
        
        // Test with high resonance
        ladderFilter.resonance = 0.8
        let responseHighRes = ladderFilter.getFrequencyResponse(at: 1000.0)
        
        // High resonance should increase magnitude at cutoff frequency
        XCTAssertGreaterThan(responseHighRes.magnitude, responseNoRes.magnitude, 
                           "High resonance should boost cutoff frequency")
    }
    
    func testDriveEffect() {
        let testInput: Float = 0.5
        
        // Test with low drive
        ladderFilter.drive = 0.5
        let outputLowDrive = ladderFilter.processSample(testInput)
        
        // Reset filter state
        ladderFilter.reset()
        
        // Test with high drive
        ladderFilter.drive = 5.0
        let outputHighDrive = ladderFilter.processSample(testInput)
        
        // High drive should generally produce different (often larger) output
        XCTAssertNotEqual(outputLowDrive, outputHighDrive, accuracy: 0.001, 
                         "Different drive amounts should produce different outputs")
    }
    
    // MARK: - Saturation Tests
    
    func testSaturationCurves() {
        let testInput: Float = 2.0  // High input to trigger saturation
        ladderFilter.drive = 3.0
        
        let saturationCurves: [SaturationCurve] = [.tanh, .atan, .cubic, .asymmetric, .tube]
        var outputs: [Float] = []
        
        for curve in saturationCurves {
            ladderFilter.config.saturationCurve = curve
            ladderFilter.reset()
            
            let output = ladderFilter.processSample(testInput)
            outputs.append(output)
            
            XCTAssertFalse(output.isNaN, "Saturation curve \(curve) should not produce NaN")
            XCTAssertFalse(output.isInfinite, "Saturation curve \(curve) should not produce infinite values")
        }
        
        // Different saturation curves should produce different outputs
        let uniqueOutputs = Set(outputs.map { round($0 * 1000) / 1000 })
        XCTAssertGreaterThan(uniqueOutputs.count, 1, "Different saturation curves should produce different outputs")
    }
    
    // MARK: - Parameter Tests
    
    func testParameterUpdates() {
        // Test cutoff parameter
        try? ladderFilter.parameters.updateParameter(id: "ladder_cutoff", value: 2000.0)
        XCTAssertEqual(ladderFilter.cutoff, 2000.0, accuracy: 0.1, "Parameter update should change cutoff")
        
        // Test resonance parameter
        try? ladderFilter.parameters.updateParameter(id: "ladder_resonance", value: 0.7)
        XCTAssertEqual(ladderFilter.resonance, 0.7, accuracy: 0.01, "Parameter update should change resonance")
        
        // Test drive parameter
        try? ladderFilter.parameters.updateParameter(id: "ladder_drive", value: 3.0)
        XCTAssertEqual(ladderFilter.drive, 3.0, accuracy: 0.01, "Parameter update should change drive")
        
        // Test saturation parameter
        try? ladderFilter.parameters.updateParameter(id: "ladder_saturation", value: 1.0)
        XCTAssertEqual(ladderFilter.config.saturationCurve, .atan, "Parameter update should change saturation curve")
    }
    
    // MARK: - Keyboard Tracking Tests
    
    func testKeyboardTracking() {
        ladderFilter.keyTracking = 0.5  // 50% tracking
        let baseCutoff: Float = 1000.0
        
        // Test with different notes
        ladderFilter.setCutoffWithKeyTracking(baseFreq: baseCutoff, note: 60, velocity: 100) // C4
        let c4Cutoff = ladderFilter.cutoff
        
        ladderFilter.setCutoffWithKeyTracking(baseFreq: baseCutoff, note: 72, velocity: 100) // C5
        let c5Cutoff = ladderFilter.cutoff
        
        // Higher note should increase cutoff with positive tracking
        XCTAssertGreaterThan(c5Cutoff, c4Cutoff, "Higher note should increase cutoff with positive tracking")
    }
    
    func testVelocitySensitivity() {
        ladderFilter.velocitySensitivity = 0.5
        let baseCutoff: Float = 1000.0
        
        // Test with low velocity
        ladderFilter.setCutoffWithKeyTracking(baseFreq: baseCutoff, note: 60, velocity: 64)
        let lowVelCutoff = ladderFilter.cutoff
        
        // Test with high velocity
        ladderFilter.setCutoffWithKeyTracking(baseFreq: baseCutoff, note: 60, velocity: 127)
        let highVelCutoff = ladderFilter.cutoff
        
        // Higher velocity should increase cutoff
        XCTAssertGreaterThan(highVelCutoff, lowVelCutoff, "Higher velocity should increase cutoff")
    }
    
    // MARK: - Modulation Tests
    
    func testFilterModulation() {
        let originalCutoff = ladderFilter.cutoff
        let originalResonance = ladderFilter.resonance
        
        // Apply modulation
        ladderFilter.modulateFilter(cutoffMod: 0.5, resonanceMod: 0.2)
        
        // Check that parameters were modulated
        XCTAssertGreaterThan(ladderFilter.cutoff, originalCutoff, "Positive cutoff modulation should increase cutoff")
        XCTAssertGreaterThan(ladderFilter.resonance, originalResonance, "Positive resonance modulation should increase resonance")
    }
    
    // MARK: - Reset and State Tests
    
    func testReset() {
        // Process some audio to establish internal state
        for _ in 0..<100 {
            _ = ladderFilter.processSample(0.5)
        }
        
        // Reset filter
        ladderFilter.reset()
        
        // Process a sample and check for clean state
        let output = ladderFilter.processSample(0.0)
        XCTAssertEqual(output, 0.0, accuracy: 0.001, "Reset filter should produce zero output for zero input")
        
        // Check that status is ready
        XCTAssertEqual(ladderFilter.status, .ready, "Reset filter should have ready status")
    }
    
    // MARK: - Performance Tests
    
    func testPerformance() {
        let testInput: Float = 0.5
        
        measure {
            for _ in 0..<10000 {
                _ = ladderFilter.processSample(testInput)
            }
        }
    }
    
    func testBufferPerformance() {
        let frameCount = 512
        let channelCount = 2
        
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount)
        inputData.initialize(repeating: 0.5, count: frameCount * channelCount)
        
        let inputBuffer = MachineProtocols.AudioBuffer(
            data: inputData,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: sampleRate
        )
        
        measure {
            for _ in 0..<100 {
                _ = ladderFilter.process(input: inputBuffer)
            }
        }
        
        inputData.deallocate()
    }
    
    // MARK: - Edge Case Tests
    
    func testExtremeInputs() {
        let extremeInputs: [Float] = [0.0, 1.0, -1.0, 10.0, -10.0, 100.0, -100.0]
        
        for input in extremeInputs {
            let output = ladderFilter.processSample(input)
            
            XCTAssertFalse(output.isNaN, "Should handle extreme input \(input) without NaN")
            XCTAssertFalse(output.isInfinite, "Should handle extreme input \(input) without infinity")
        }
    }
    
    func testDisabledFilter() {
        ladderFilter.isEnabled = false
        
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize * 2)
        inputData.initialize(repeating: 0.5, count: bufferSize * 2)
        
        let inputBuffer = MachineProtocols.AudioBuffer(
            data: inputData,
            frameCount: bufferSize,
            channelCount: 2,
            sampleRate: sampleRate
        )
        
        let outputBuffer = ladderFilter.process(input: inputBuffer)
        
        // Disabled filter should pass input unchanged
        for i in 0..<bufferSize * 2 {
            XCTAssertEqual(outputBuffer.data[i], inputBuffer.data[i], accuracy: 0.001, 
                          "Disabled filter should pass input unchanged")
        }
        
        inputData.deallocate()
    }
    
    func testPresetSaveLoad() {
        // Configure filter
        ladderFilter.cutoff = 1500.0
        ladderFilter.resonance = 0.6
        ladderFilter.drive = 2.5
        
        // Save preset
        let preset = ladderFilter.saveFilterPreset(name: "Test Preset")
        
        // Verify preset data
        XCTAssertEqual(preset.name, "Test Preset")
        XCTAssertEqual(preset.filterType, .lowpass)
        XCTAssertEqual(preset.cutoff, 1500.0, accuracy: 0.1)
        XCTAssertEqual(preset.resonance, 0.6, accuracy: 0.01)
        XCTAssertEqual(preset.drive, 2.5, accuracy: 0.01)
        XCTAssertEqual(preset.slope, .slope24dB)
        XCTAssertEqual(preset.quality, .high)
    }
}
