// TrackFXImplementationTests.swift
// DigitonePad - FXModuleTests
//
// Comprehensive test suite for Track FX Implementation

import XCTest
import MachineProtocols
@testable import FXModule

final class TrackFXImplementationTests: XCTestCase {
    
    var trackFX: TrackFXProcessor!
    let sampleRate: Double = 44100.0
    let bufferSize = 512
    
    override func setUp() {
        super.setUp()
        trackFX = TrackFXProcessor(trackId: 1, sampleRate: sampleRate)
    }
    
    override func tearDown() {
        trackFX = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialization() {
        XCTAssertNotNil(trackFX)
        XCTAssertEqual(trackFX.trackId, 1)
        XCTAssertFalse(trackFX.isBypassed)
        XCTAssertFalse(trackFX.isMuted)
    }
    
    func testBypassedProcessing() {
        trackFX.isBypassed = true
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.5)
        let outputBuffer = trackFX.process(input: inputData.buffer)
        
        // Bypassed processor should return input unchanged
        for i in 0..<bufferSize * 2 {
            XCTAssertEqual(outputBuffer.data[i], inputData.buffer.data[i], accuracy: 0.001,
                          "Bypassed processor should pass input unchanged")
        }
        
        inputData.deallocate()
    }
    
    func testMutedProcessing() {
        trackFX.isMuted = true
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.5)
        let outputBuffer = trackFX.process(input: inputData.buffer)
        
        // Muted processor should return silence
        for i in 0..<bufferSize * 2 {
            XCTAssertEqual(outputBuffer.data[i], 0.0, accuracy: 0.001,
                          "Muted processor should return silence")
        }
        
        inputData.deallocate()
    }
    
    func testCleanProcessing() {
        // With no effects enabled, should pass signal through with gain
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.5)
        let outputBuffer = trackFX.process(input: inputData.buffer)
        
        // Should get non-zero output
        var hasNonZeroOutput = false
        for i in 0..<bufferSize * 2 {
            if abs(outputBuffer.data[i]) > 0.001 {
                hasNonZeroOutput = true
                break
            }
        }
        XCTAssertTrue(hasNonZeroOutput, "Clean processing should produce non-zero output")
        
        inputData.deallocate()
    }
    
    // MARK: - Bit Reduction Tests
    
    func testBitReduction() {
        // Enable bit reduction
        trackFX.config.bitReduction.enabled = true
        trackFX.config.bitReduction.bitDepth = 8.0
        trackFX.config.bitReduction.wetLevel = 1.0
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.8)
        let outputBuffer = trackFX.process(input: inputData.buffer)
        
        // Check that output is different from input (quantized)
        var isDifferent = false
        for i in 0..<bufferSize * 2 {
            if abs(outputBuffer.data[i] - inputData.buffer.data[i]) > 0.01 {
                isDifferent = true
                break
            }
        }
        XCTAssertTrue(isDifferent, "Bit reduction should modify the signal")
        
        // Check that output is quantized (should have fewer unique values)
        let inputValues = Set((0..<bufferSize * 2).map { round(inputData.buffer.data[$0] * 1000) })
        let outputValues = Set((0..<bufferSize * 2).map { round(outputBuffer.data[$0] * 1000) })
        
        XCTAssertLessThan(outputValues.count, inputValues.count, "Bit reduction should reduce unique values")
        
        inputData.deallocate()
    }
    
    func testBitReductionWithDither() {
        trackFX.config.bitReduction.enabled = true
        trackFX.config.bitReduction.bitDepth = 4.0
        trackFX.config.bitReduction.ditherAmount = 0.5
        trackFX.config.bitReduction.ditherType = .triangular
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.5)
        let outputBuffer = trackFX.process(input: inputData.buffer)
        
        // Should produce output without NaN or infinite values
        for i in 0..<bufferSize * 2 {
            XCTAssertFalse(outputBuffer.data[i].isNaN, "Dithered bit reduction should not produce NaN")
            XCTAssertFalse(outputBuffer.data[i].isInfinite, "Dithered bit reduction should not produce infinite values")
        }
        
        inputData.deallocate()
    }
    
    // MARK: - Sample Rate Reduction Tests
    
    func testSampleRateReduction() {
        trackFX.config.sampleRateReduction.enabled = true
        trackFX.config.sampleRateReduction.targetSampleRate = 11025.0
        trackFX.config.sampleRateReduction.antiAliasing = false
        trackFX.config.sampleRateReduction.wetLevel = 1.0
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.5)
        let outputBuffer = trackFX.process(input: inputData.buffer)
        
        // Should produce stepped/aliased output
        var hasSteppedOutput = false
        var lastValue = outputBuffer.data[0]
        var sameValueCount = 0
        
        for i in 1..<bufferSize * 2 {
            if abs(outputBuffer.data[i] - lastValue) < 0.001 {
                sameValueCount += 1
            } else {
                if sameValueCount > 2 {  // Found a step
                    hasSteppedOutput = true
                    break
                }
                lastValue = outputBuffer.data[i]
                sameValueCount = 0
            }
        }
        
        XCTAssertTrue(hasSteppedOutput, "Sample rate reduction should produce stepped output")
        
        inputData.deallocate()
    }
    
    func testSampleRateReductionWithAntiAliasing() {
        trackFX.config.sampleRateReduction.enabled = true
        trackFX.config.sampleRateReduction.targetSampleRate = 8000.0
        trackFX.config.sampleRateReduction.antiAliasing = true
        trackFX.config.sampleRateReduction.filterCutoff = 0.4
        
        let inputData = createTestBuffer(frequency: 5000.0, amplitude: 0.5)
        let outputBuffer = trackFX.process(input: inputData.buffer)
        
        // Should produce filtered output
        var outputRMS: Float = 0.0
        for i in 0..<bufferSize * 2 {
            outputRMS += outputBuffer.data[i] * outputBuffer.data[i]
        }
        outputRMS = sqrt(outputRMS / Float(bufferSize * 2))
        
        XCTAssertGreaterThan(outputRMS, 0.01, "Anti-aliased sample rate reduction should produce measurable output")
        
        inputData.deallocate()
    }
    
    // MARK: - Overdrive Tests
    
    func testOverdrive() {
        trackFX.config.overdrive.enabled = true
        trackFX.config.overdrive.driveAmount = 3.0
        trackFX.config.overdrive.clippingCurve = .soft
        trackFX.config.overdrive.wetLevel = 1.0
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.8)
        let outputBuffer = trackFX.process(input: inputData.buffer)
        
        // Should produce distorted output
        var inputRMS: Float = 0.0
        var outputRMS: Float = 0.0
        
        for i in 0..<bufferSize * 2 {
            inputRMS += inputData.buffer.data[i] * inputData.buffer.data[i]
            outputRMS += outputBuffer.data[i] * outputBuffer.data[i]
        }
        
        inputRMS = sqrt(inputRMS / Float(bufferSize * 2))
        outputRMS = sqrt(outputRMS / Float(bufferSize * 2))
        
        // Overdrive should change the signal characteristics
        XCTAssertNotEqual(inputRMS, outputRMS, accuracy: 0.01, "Overdrive should change signal characteristics")
        
        inputData.deallocate()
    }
    
    func testOverdriveClippingCurves() {
        let clippingCurves: [ClippingCurve] = [.soft, .hard, .tube, .asymmetric]
        let testInput: Float = 1.5  // High input to trigger clipping
        
        var outputs: [Float] = []
        
        for curve in clippingCurves {
            trackFX.config.overdrive.enabled = true
            trackFX.config.overdrive.driveAmount = 2.0
            trackFX.config.overdrive.clippingCurve = curve
            trackFX.reset()
            
            let inputData = createTestBuffer(frequency: 1000.0, amplitude: testInput)
            let outputBuffer = trackFX.process(input: inputData.buffer)
            
            // Get peak output
            var peak: Float = 0.0
            for i in 0..<bufferSize * 2 {
                peak = max(peak, abs(outputBuffer.data[i]))
            }
            outputs.append(peak)
            
            inputData.deallocate()
        }
        
        // Different clipping curves should produce different peak levels
        let uniqueOutputs = Set(outputs.map { round($0 * 100) / 100 })
        XCTAssertGreaterThan(uniqueOutputs.count, 1, "Different clipping curves should produce different outputs")
    }
    
    // MARK: - Preset Tests
    
    func testPresetCreation() {
        let presetTypes: [TrackFXPresetType] = [.clean, .lofi, .vintage, .aggressive, .telephone, .radio, .crushed, .warm, .digital]
        
        for presetType in presetTypes {
            let processor = TrackFXProcessor.createWithPreset(presetType, trackId: 1, sampleRate: sampleRate)
            
            XCTAssertNotNil(processor, "Should create processor with preset \(presetType)")
            XCTAssertEqual(processor.trackId, 1, "Should set correct track ID")
            
            // Test that preset was applied
            let config = processor.config
            
            switch presetType {
            case .clean:
                XCTAssertFalse(config.bitReduction.enabled, "Clean preset should disable bit reduction")
                XCTAssertFalse(config.sampleRateReduction.enabled, "Clean preset should disable sample rate reduction")
                XCTAssertFalse(config.overdrive.enabled, "Clean preset should disable overdrive")
                
            case .lofi:
                XCTAssertTrue(config.bitReduction.enabled, "Lo-fi preset should enable bit reduction")
                XCTAssertTrue(config.sampleRateReduction.enabled, "Lo-fi preset should enable sample rate reduction")
                XCTAssertEqual(config.bitReduction.bitDepth, 8.0, "Lo-fi preset should use 8-bit depth")
                
            case .aggressive:
                XCTAssertTrue(config.bitReduction.enabled, "Aggressive preset should enable bit reduction")
                XCTAssertTrue(config.overdrive.enabled, "Aggressive preset should enable overdrive")
                XCTAssertLessThan(config.bitReduction.bitDepth, 8.0, "Aggressive preset should use low bit depth")
                
            default:
                break
            }
        }
    }
    
    func testPresetApplication() {
        // Start with clean preset
        trackFX.applyPreset(.clean)
        XCTAssertFalse(trackFX.config.bitReduction.enabled, "Should start with clean preset")
        
        // Apply lo-fi preset
        trackFX.applyPreset(.lofi)
        XCTAssertTrue(trackFX.config.bitReduction.enabled, "Should apply lo-fi preset")
        XCTAssertTrue(trackFX.config.sampleRateReduction.enabled, "Should apply lo-fi preset")
        
        // Apply vintage preset
        trackFX.applyPreset(.vintage)
        XCTAssertTrue(trackFX.config.bitReduction.enabled, "Should apply vintage preset")
        XCTAssertEqual(trackFX.config.bitReduction.bitDepth, 12.0, "Should apply vintage bit depth")
    }
    
    // MARK: - Effect Chain Tests
    
    func testEffectOrder() {
        // Configure all effects
        trackFX.config.bitReduction.enabled = true
        trackFX.config.bitReduction.bitDepth = 8.0
        trackFX.config.sampleRateReduction.enabled = true
        trackFX.config.sampleRateReduction.targetSampleRate = 11025.0
        trackFX.config.overdrive.enabled = true
        trackFX.config.overdrive.driveAmount = 2.0
        
        // Test default order
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.5)
        let output1 = trackFX.process(input: inputData.buffer)
        
        // Change effect order
        trackFX.config.effectOrder = [.overdrive, .bitReduction, .sampleRateReduction]
        trackFX.reset()
        
        let output2 = trackFX.process(input: inputData.buffer)
        
        // Different orders should produce different results
        var isDifferent = false
        for i in 0..<bufferSize * 2 {
            if abs(output1.data[i] - output2.data[i]) > 0.01 {
                isDifferent = true
                break
            }
        }
        XCTAssertTrue(isDifferent, "Different effect orders should produce different results")
        
        inputData.deallocate()
    }
    
    // MARK: - Gain and Mix Tests
    
    func testInputGain() {
        trackFX.config.inputGain = 6.0  // +6dB
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.5)
        let outputBuffer = trackFX.process(input: inputData.buffer)
        
        // Output should be approximately 2x louder (+6dB)
        let expectedGain = pow(10.0, 6.0 / 20.0)  // ~2.0
        
        for i in 0..<min(10, bufferSize * 2) {  // Check first few samples
            let expectedOutput = inputData.buffer.data[i] * expectedGain
            XCTAssertEqual(outputBuffer.data[i], expectedOutput, accuracy: 0.1,
                          "Input gain should amplify signal correctly")
        }
        
        inputData.deallocate()
    }
    
    func testOutputGain() {
        trackFX.config.outputGain = -6.0  // -6dB
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.5)
        let outputBuffer = trackFX.process(input: inputData.buffer)
        
        // Output should be approximately 0.5x quieter (-6dB)
        let expectedGain = pow(10.0, -6.0 / 20.0)  // ~0.5
        
        for i in 0..<min(10, bufferSize * 2) {  // Check first few samples
            let expectedOutput = inputData.buffer.data[i] * expectedGain
            XCTAssertEqual(outputBuffer.data[i], expectedOutput, accuracy: 0.1,
                          "Output gain should attenuate signal correctly")
        }
        
        inputData.deallocate()
    }
    
    func testWetDryMix() {
        trackFX.config.overdrive.enabled = true
        trackFX.config.overdrive.driveAmount = 5.0
        trackFX.config.wetLevel = 0.5
        trackFX.config.dryLevel = 0.5
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.5)
        let outputBuffer = trackFX.process(input: inputData.buffer)
        
        // Output should be a mix of wet and dry signals
        // Check that it's different from both pure wet and pure dry
        var isDifferentFromInput = false
        for i in 0..<bufferSize * 2 {
            if abs(outputBuffer.data[i] - inputData.buffer.data[i]) > 0.01 {
                isDifferentFromInput = true
                break
            }
        }
        XCTAssertTrue(isDifferentFromInput, "Wet/dry mix should produce different output from input")
        
        inputData.deallocate()
    }
    
    // MARK: - Performance Tests
    
    func testPerformance() {
        // Configure all effects for maximum load
        trackFX.applyPreset(.crushed)
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.5)
        
        measure {
            for _ in 0..<100 {
                _ = trackFX.process(input: inputData.buffer)
            }
        }
        
        inputData.deallocate()
    }
    
    // MARK: - Helper Methods
    
    private func createTestBuffer(frequency: Float, amplitude: Float) -> (buffer: MachineProtocols.AudioBuffer, deallocate: () -> Void) {
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize * 2)
        
        // Generate stereo sine wave
        for i in 0..<bufferSize {
            let phase = Float(i) * 2.0 * Float.pi * frequency / Float(sampleRate)
            let sample = sin(phase) * amplitude
            inputData[i * 2] = sample      // Left channel
            inputData[i * 2 + 1] = sample  // Right channel
        }
        
        let buffer = MachineProtocols.AudioBuffer(
            data: inputData,
            frameCount: bufferSize,
            channelCount: 2,
            sampleRate: sampleRate
        )
        
        return (buffer, { inputData.deallocate() })
    }
}
