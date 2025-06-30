// TrackFXProcessorTests.swift
// DigitonePad - FXModuleTests
//
// Comprehensive test suite for Track FX Processor

import XCTest
import Accelerate
@testable import FXModule

final class TrackFXProcessorTests: XCTestCase {
    
    var trackFX: TrackFXProcessor!
    let sampleRate: Double = 44100.0
    let testTolerance: Float = 0.001
    
    override func setUp() {
        super.setUp()
        trackFX = TrackFXProcessor(sampleRate: sampleRate)
    }
    
    override func tearDown() {
        trackFX = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialization() {
        XCTAssertEqual(trackFX.machineType, "TrackFX")
        XCTAssertEqual(trackFX.parameterCount, 8)
        XCTAssertTrue(trackFX.enabled)
        
        // Test parameter names
        XCTAssertEqual(trackFX.getParameterName(index: 0), "BIT_DEPTH")
        XCTAssertEqual(trackFX.getParameterName(index: 1), "BIT_BYPASS")
        XCTAssertEqual(trackFX.getParameterName(index: 2), "SR_FACTOR")
        XCTAssertEqual(trackFX.getParameterName(index: 3), "SR_BYPASS")
        XCTAssertEqual(trackFX.getParameterName(index: 4), "OD_DRIVE")
        XCTAssertEqual(trackFX.getParameterName(index: 5), "OD_TONE")
        XCTAssertEqual(trackFX.getParameterName(index: 6), "OD_BYPASS")
        XCTAssertEqual(trackFX.getParameterName(index: 7), "GLOBAL_BYPASS")
    }
    
    func testParameterAccess() {
        // Test bit depth parameter
        trackFX.setParameterValue(index: 0, value: 8.0)
        XCTAssertEqual(trackFX.getParameterValue(index: 0), 8.0, accuracy: testTolerance)
        XCTAssertEqual(trackFX.getParameterDisplayValue(index: 0), "8 bits")
        
        // Test sample rate factor
        trackFX.setParameterValue(index: 2, value: 4.0)
        XCTAssertEqual(trackFX.getParameterValue(index: 2), 4.0, accuracy: testTolerance)
        XCTAssertEqual(trackFX.getParameterDisplayValue(index: 2), "1/4")
        
        // Test overdrive drive
        trackFX.setParameterValue(index: 4, value: 0.7)
        XCTAssertEqual(trackFX.getParameterValue(index: 4), 0.7, accuracy: testTolerance)
        XCTAssertEqual(trackFX.getParameterDisplayValue(index: 4), "70.0%")
        
        // Test bypass parameters
        trackFX.setParameterValue(index: 1, value: 1.0)  // Bit reduction bypass
        XCTAssertEqual(trackFX.getParameterDisplayValue(index: 1), "BYPASS")
        
        trackFX.setParameterValue(index: 1, value: 0.0)  // Bit reduction on
        XCTAssertEqual(trackFX.getParameterDisplayValue(index: 1), "ON")
    }
    
    func testGlobalBypass() {
        let inputSample: Float = 0.5
        
        // Enable global bypass
        trackFX.setParameterValue(index: 7, value: 1.0)
        let bypassOutput = trackFX.processSample(inputSample)
        XCTAssertEqual(bypassOutput, inputSample, accuracy: testTolerance, "Global bypass should pass input unchanged")
        
        // Disable global bypass
        trackFX.setParameterValue(index: 7, value: 0.0)
        let processedOutput = trackFX.processSample(inputSample)
        // Output might be the same if no effects are enabled, but should not error
        XCTAssertFalse(processedOutput.isNaN, "Processed output should not be NaN")
        XCTAssertFalse(processedOutput.isInfinite, "Processed output should not be infinite")
    }
    
    // MARK: - Bit Reduction Tests
    
    func testBitReductionProcessor() {
        let bitProcessor = BitReductionProcessor(sampleRate: sampleRate)
        
        // Test various bit depths
        let bitDepths: [Float] = [1.0, 4.0, 8.0, 12.0, 16.0]
        let testInput: Float = 0.7
        
        for bitDepth in bitDepths {
            var config = BitReductionConfig()
            config.bitDepth = bitDepth
            bitProcessor.config = config
            
            let output = bitProcessor.processSample(testInput)
            
            XCTAssertFalse(output.isNaN, "Output should not be NaN for \(bitDepth) bits")
            XCTAssertFalse(output.isInfinite, "Output should not be infinite for \(bitDepth) bits")
            XCTAssertLessThanOrEqual(abs(output), 1.0, "Output should be within [-1, 1] range")
        }
    }
    
    func testBitReductionQuantization() {
        let bitProcessor = BitReductionProcessor(sampleRate: sampleRate)
        
        // Test 4-bit quantization
        var config = BitReductionConfig()
        config.bitDepth = 4.0  // 16 levels
        bitProcessor.config = config
        
        let testInputs: [Float] = [0.0, 0.1, 0.5, 0.9, -0.3, -0.8]
        
        for input in testInputs {
            let output = bitProcessor.processSample(input)
            
            // With 4 bits (16 levels), quantization should be noticeable
            let expectedLevels = pow(2.0, 4.0) - 1.0  // 15 levels
            let quantizedValue = round(input * expectedLevels) / expectedLevels
            
            // Allow some tolerance due to processing
            XCTAssertEqual(output, quantizedValue, accuracy: 0.1, "4-bit quantization should match expected levels")
        }
    }
    
    func testBitReductionBypass() {
        let bitProcessor = BitReductionProcessor(sampleRate: sampleRate)
        let testInput: Float = 0.6
        
        // Test bypass
        var config = BitReductionConfig()
        config.bypass = true
        bitProcessor.config = config
        
        let bypassOutput = bitProcessor.processSample(testInput)
        XCTAssertEqual(bypassOutput, testInput, accuracy: testTolerance, "Bypass should pass input unchanged")
        
        // Test processing
        config.bypass = false
        config.bitDepth = 6.0  // Should cause noticeable quantization
        bitProcessor.config = config
        
        let processedOutput = bitProcessor.processSample(testInput)
        XCTAssertNotEqual(processedOutput, testInput, accuracy: testTolerance, "Processing should quantize the input")
    }
    
    func testBitReductionDithering() {
        let bitProcessor = BitReductionProcessor(sampleRate: sampleRate)
        
        var config = BitReductionConfig()
        config.bitDepth = 4.0
        config.dithering = true
        bitProcessor.config = config
        
        let testInput: Float = 0.33
        var outputs: [Float] = []
        
        // Process the same input multiple times to check for dither variation
        for _ in 0..<100 {
            outputs.append(bitProcessor.processSample(testInput))
        }
        
        // With dithering, outputs should vary slightly
        let uniqueOutputs = Set(outputs.map { round($0 * 1000) / 1000 })
        XCTAssertGreaterThan(uniqueOutputs.count, 1, "Dithering should create variation in output")
    }
    
    // MARK: - Sample Rate Reduction Tests
    
    func testSampleRateReductionProcessor() {
        let srProcessor = SampleRateReductionProcessor(sampleRate: sampleRate)
        
        // Test various downsample factors
        let factors = [1, 2, 4, 8, 16]
        let testInput: Float = 0.5
        
        for factor in factors {
            var config = SampleRateReductionConfig()
            config.downsampleFactor = factor
            srProcessor.config = config
            
            let output = srProcessor.processSample(testInput)
            
            XCTAssertFalse(output.isNaN, "Output should not be NaN for factor \(factor)")
            XCTAssertFalse(output.isInfinite, "Output should not be infinite for factor \(factor)")
        }
    }
    
    func testSampleRateReductionHoldMode() {
        let srProcessor = SampleRateReductionProcessor(sampleRate: sampleRate)
        
        var config = SampleRateReductionConfig()
        config.downsampleFactor = 4
        config.holdMode = true
        srProcessor.config = config
        
        // Process a sequence and verify hold behavior
        let inputs: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
        var outputs: [Float] = []
        
        for input in inputs {
            outputs.append(srProcessor.processSample(input))
        }
        
        // With factor 4, every 4th sample should be held
        // outputs[0] should equal inputs[0], outputs[1-3] should equal outputs[0], etc.
        XCTAssertEqual(outputs[0], inputs[0], accuracy: testTolerance, "First sample should pass through")
        XCTAssertEqual(outputs[1], outputs[0], accuracy: testTolerance, "Hold mode should repeat samples")
        XCTAssertEqual(outputs[2], outputs[0], accuracy: testTolerance, "Hold mode should repeat samples")
        XCTAssertEqual(outputs[3], outputs[0], accuracy: testTolerance, "Hold mode should repeat samples")
        XCTAssertEqual(outputs[4], inputs[4], accuracy: testTolerance, "Next hold should start at sample 4")
    }
    
    func testSampleRateReductionBypass() {
        let srProcessor = SampleRateReductionProcessor(sampleRate: sampleRate)
        let testInput: Float = 0.7
        
        // Test bypass
        var config = SampleRateReductionConfig()
        config.bypass = true
        srProcessor.config = config
        
        let bypassOutput = srProcessor.processSample(testInput)
        XCTAssertEqual(bypassOutput, testInput, accuracy: testTolerance, "Bypass should pass input unchanged")
        
        // Test processing
        config.bypass = false
        config.downsampleFactor = 8
        srProcessor.config = config
        
        let processedOutput = srProcessor.processSample(testInput)
        // First sample should pass through in hold mode
        XCTAssertEqual(processedOutput, testInput, accuracy: testTolerance, "First sample should pass through")
    }
    
    // MARK: - Overdrive Tests
    
    func testOverdriveProcessor() {
        let overdriveProcessor = OverdriveProcessor(sampleRate: sampleRate)
        
        // Test different overdrive types
        let overdriveTypes: [OverdriveType] = [.analog, .tube, .transistor, .digital, .fuzz]
        let testInput: Float = 0.5
        
        for overdriveType in overdriveTypes {
            var config = OverdriveConfig()
            config.overdriveType = overdriveType
            config.drive = 0.7
            overdriveProcessor.config = config
            
            let output = overdriveProcessor.processSample(testInput)
            
            XCTAssertFalse(output.isNaN, "Output should not be NaN for \(overdriveType)")
            XCTAssertFalse(output.isInfinite, "Output should not be infinite for \(overdriveType)")
            XCTAssertLessThanOrEqual(abs(output), 1.0, "Output should be clipped to [-1, 1]")
        }
    }
    
    func testOverdriveDriveAmount() {
        let overdriveProcessor = OverdriveProcessor(sampleRate: sampleRate)
        let testInput: Float = 0.3
        
        // Test no drive
        var config = OverdriveConfig()
        config.drive = 0.0
        overdriveProcessor.config = config
        let noDriveOutput = overdriveProcessor.processSample(testInput)
        
        // Test high drive
        config.drive = 0.9
        overdriveProcessor.config = config
        let highDriveOutput = overdriveProcessor.processSample(testInput)
        
        // High drive should produce different (typically larger) output
        XCTAssertNotEqual(noDriveOutput, highDriveOutput, accuracy: testTolerance,
                         "Different drive amounts should produce different outputs")
    }
    
    func testOverdriveToneControl() {
        let overdriveProcessor = OverdriveProcessor(sampleRate: sampleRate)
        let testInput: Float = 0.5
        
        // Test different tone settings
        let toneSettings: [Float] = [-1.0, -0.5, 0.0, 0.5, 1.0]
        var outputs: [Float] = []
        
        for tone in toneSettings {
            var config = OverdriveConfig()
            config.drive = 0.5
            config.tone = tone
            overdriveProcessor.config = config
            
            let output = overdriveProcessor.processSample(testInput)
            outputs.append(output)
            
            XCTAssertFalse(output.isNaN, "Output should not be NaN for tone \(tone)")
            XCTAssertFalse(output.isInfinite, "Output should not be infinite for tone \(tone)")
        }
        
        // Different tone settings should produce different results
        let uniqueOutputs = Set(outputs.map { round($0 * 1000) / 1000 })
        XCTAssertGreaterThan(uniqueOutputs.count, 1, "Different tone settings should produce different outputs")
    }
    
    func testOverdriveBypass() {
        let overdriveProcessor = OverdriveProcessor(sampleRate: sampleRate)
        let testInput: Float = 0.6
        
        // Test bypass
        var config = OverdriveConfig()
        config.bypass = true
        overdriveProcessor.config = config
        
        let bypassOutput = overdriveProcessor.processSample(testInput)
        XCTAssertEqual(bypassOutput, testInput, accuracy: testTolerance, "Bypass should pass input unchanged")
        
        // Test processing
        config.bypass = false
        config.drive = 0.8
        overdriveProcessor.config = config
        
        let processedOutput = overdriveProcessor.processSample(testInput)
        XCTAssertNotEqual(processedOutput, testInput, accuracy: testTolerance, "Processing should modify the input")
    }
    
    // MARK: - Complete Chain Tests
    
    func testCompleteEffectChain() {
        // Configure all effects
        trackFX.setParameterValue(index: 0, value: 8.0)   // 8-bit reduction
        trackFX.setParameterValue(index: 1, value: 0.0)   // Bit reduction on
        trackFX.setParameterValue(index: 2, value: 2.0)   // 1/2 sample rate
        trackFX.setParameterValue(index: 3, value: 0.0)   // Sample rate reduction on
        trackFX.setParameterValue(index: 4, value: 0.6)   // 60% overdrive
        trackFX.setParameterValue(index: 5, value: 0.3)   // Bright tone
        trackFX.setParameterValue(index: 6, value: 0.0)   // Overdrive on
        trackFX.setParameterValue(index: 7, value: 0.0)   // Global bypass off
        
        let testInput: Float = 0.4
        let output = trackFX.processSample(testInput)
        
        XCTAssertFalse(output.isNaN, "Complete chain output should not be NaN")
        XCTAssertFalse(output.isInfinite, "Complete chain output should not be infinite")
        XCTAssertLessThanOrEqual(abs(output), 1.0, "Complete chain output should be within valid range")
        XCTAssertNotEqual(output, testInput, accuracy: testTolerance, "Complete chain should process the input")
    }
    
    func testEffectProcessingOrder() {
        // Test different processing orders
        let order1: [TrackFXType] = [.bitReduction, .sampleRateReduction, .overdrive]
        let order2: [TrackFXType] = [.overdrive, .bitReduction, .sampleRateReduction]
        
        let testInput: Float = 0.5
        
        // Configure effects with noticeable settings
        trackFX.setParameterValue(index: 0, value: 6.0)   // 6-bit reduction
        trackFX.setParameterValue(index: 2, value: 4.0)   // 1/4 sample rate
        trackFX.setParameterValue(index: 4, value: 0.8)   // High overdrive
        
        // Test first order
        trackFX.setProcessingOrder(order1)
        let output1 = trackFX.processSample(testInput)
        
        // Reset and test second order
        trackFX = TrackFXProcessor(sampleRate: sampleRate)
        trackFX.setParameterValue(index: 0, value: 6.0)
        trackFX.setParameterValue(index: 2, value: 4.0)
        trackFX.setParameterValue(index: 4, value: 0.8)
        trackFX.setProcessingOrder(order2)
        let output2 = trackFX.processSample(testInput)
        
        // Different processing orders should potentially produce different results
        // (Though they might be similar depending on the effects)
        XCTAssertFalse(output1.isNaN, "First order output should not be NaN")
        XCTAssertFalse(output2.isNaN, "Second order output should not be NaN")
    }
    
    func testBufferProcessing() {
        let frameCount = 512
        var inputBuffer = [Float](repeating: 0.0, count: frameCount)
        var outputBuffer = [Float](repeating: 0.0, count: frameCount)
        
        // Generate test signal
        for i in 0..<frameCount {
            let phase = 2.0 * Float.pi * 440.0 * Float(i) / Float(sampleRate)
            inputBuffer[i] = sin(phase) * 0.5
        }
        
        // Configure some effects
        trackFX.setParameterValue(index: 0, value: 10.0)  // 10-bit reduction
        trackFX.setParameterValue(index: 4, value: 0.4)   // Moderate overdrive
        
        trackFX.processBuffer(
            input: inputBuffer,
            output: &outputBuffer,
            frameCount: frameCount
        )
        
        // Verify processing
        let inputRMS = calculateRMS(inputBuffer)
        let outputRMS = calculateRMS(outputBuffer)
        
        XCTAssertGreaterThan(outputRMS, 0.0, "Output should have signal")
        XCTAssertLessThan(abs(outputRMS - inputRMS) / inputRMS, 2.0, "Output should be reasonable compared to input")
        
        // Check for any NaN or infinite values
        for i in 0..<frameCount {
            XCTAssertFalse(outputBuffer[i].isNaN, "Output sample \(i) should not be NaN")
            XCTAssertFalse(outputBuffer[i].isInfinite, "Output sample \(i) should not be infinite")
        }
    }
    
    // MARK: - Configuration Tests
    
    func testConfigurationPersistence() {
        // Test TrackFXConfig encoding/decoding
        var config = TrackFXConfig()
        config.bitReduction.bitDepth = 6.0
        config.bitReduction.dithering = true
        config.sampleRateReduction.downsampleFactor = 8
        config.sampleRateReduction.antiAliasing = true
        config.overdrive.drive = 0.7
        config.overdrive.tone = -0.3
        config.overdrive.overdriveType = .tube
        config.globalBypass = false
        config.processingOrder = [.overdrive, .bitReduction, .sampleRateReduction]
        
        do {
            let data = try JSONEncoder().encode(config)
            let decodedConfig = try JSONDecoder().decode(TrackFXConfig.self, from: data)
            
            XCTAssertEqual(config.bitReduction.bitDepth, decodedConfig.bitReduction.bitDepth, accuracy: testTolerance)
            XCTAssertEqual(config.bitReduction.dithering, decodedConfig.bitReduction.dithering)
            XCTAssertEqual(config.sampleRateReduction.downsampleFactor, decodedConfig.sampleRateReduction.downsampleFactor)
            XCTAssertEqual(config.sampleRateReduction.antiAliasing, decodedConfig.sampleRateReduction.antiAliasing)
            XCTAssertEqual(config.overdrive.drive, decodedConfig.overdrive.drive, accuracy: testTolerance)
            XCTAssertEqual(config.overdrive.tone, decodedConfig.overdrive.tone, accuracy: testTolerance)
            XCTAssertEqual(config.overdrive.overdriveType, decodedConfig.overdrive.overdriveType)
            XCTAssertEqual(config.globalBypass, decodedConfig.globalBypass)
            XCTAssertEqual(config.processingOrder, decodedConfig.processingOrder)
        } catch {
            XCTFail("Configuration should be encodable/decodable: \(error)")
        }
    }
    
    func testParameterValidation() {
        // Test bit depth validation
        trackFX.setParameterValue(index: 0, value: -5.0)  // Should clamp to 1
        XCTAssertEqual(trackFX.getParameterValue(index: 0), 1.0, accuracy: testTolerance)
        
        trackFX.setParameterValue(index: 0, value: 25.0)  // Should clamp to 16
        XCTAssertEqual(trackFX.getParameterValue(index: 0), 16.0, accuracy: testTolerance)
        
        // Test downsample factor validation
        trackFX.setParameterValue(index: 2, value: 0.0)   // Should clamp to 1
        XCTAssertEqual(trackFX.getParameterValue(index: 2), 1.0, accuracy: testTolerance)
        
        trackFX.setParameterValue(index: 2, value: 100.0) // Should clamp to 64
        XCTAssertEqual(trackFX.getParameterValue(index: 2), 64.0, accuracy: testTolerance)
        
        // Test overdrive drive validation
        trackFX.setParameterValue(index: 4, value: -0.5)  // Should clamp to 0
        XCTAssertEqual(trackFX.getParameterValue(index: 4), 0.0, accuracy: testTolerance)
        
        trackFX.setParameterValue(index: 4, value: 1.5)   // Should clamp to 1
        XCTAssertEqual(trackFX.getParameterValue(index: 4), 1.0, accuracy: testTolerance)
        
        // Test tone validation
        trackFX.setParameterValue(index: 5, value: -2.0)  // Should clamp to -1
        XCTAssertEqual(trackFX.getParameterValue(index: 5), -1.0, accuracy: testTolerance)
        
        trackFX.setParameterValue(index: 5, value: 2.0)   // Should clamp to 1
        XCTAssertEqual(trackFX.getParameterValue(index: 5), 1.0, accuracy: testTolerance)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceBenchmark() {
        let frameCount = 44100  // 1 second at 44.1kHz
        var inputBuffer = [Float](repeating: 0.0, count: frameCount)
        var outputBuffer = [Float](repeating: 0.0, count: frameCount)
        
        // Generate complex test signal
        for i in 0..<frameCount {
            let t = Float(i) / Float(sampleRate)
            inputBuffer[i] = sin(2.0 * Float.pi * 440.0 * t) * 0.3 +
                           sin(2.0 * Float.pi * 880.0 * t) * 0.2 +
                           sin(2.0 * Float.pi * 1320.0 * t) * 0.1
        }
        
        // Configure all effects
        trackFX.setParameterValue(index: 0, value: 8.0)   // 8-bit
        trackFX.setParameterValue(index: 2, value: 2.0)   // 1/2 sample rate
        trackFX.setParameterValue(index: 4, value: 0.5)   // Moderate overdrive
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        trackFX.processBuffer(
            input: inputBuffer,
            output: &outputBuffer,
            frameCount: frameCount
        )
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        let realTimeRatio = processingTime / 1.0  // 1 second of audio
        
        XCTAssertLessThan(realTimeRatio, 0.1, "Processing should be much faster than real-time")
        
        print("Track FX Performance: \(realTimeRatio * 100)% of real-time")
    }
    
    func testStabilityWithExtremeSettings() {
        // Test with extreme parameter combinations
        trackFX.setParameterValue(index: 0, value: 1.0)   // 1-bit (extreme quantization)
        trackFX.setParameterValue(index: 2, value: 32.0)  // 1/32 sample rate
        trackFX.setParameterValue(index: 4, value: 1.0)   // Maximum overdrive
        trackFX.setParameterValue(index: 5, value: 1.0)   // Maximum brightness
        
        let testInputs: [Float] = [0.0, 0.1, 0.5, 0.9, -0.5, -0.9]
        
        for input in testInputs {
            let output = trackFX.processSample(input)
            
            XCTAssertFalse(output.isNaN, "Output should not be NaN with extreme settings for input \(input)")
            XCTAssertFalse(output.isInfinite, "Output should not be infinite with extreme settings for input \(input)")
            XCTAssertLessThanOrEqual(abs(output), 2.0, "Output should be reasonable magnitude")
        }
    }
    
    // MARK: - Individual Effect Configuration Tests
    
    func testIndividualEffectConfiguration() {
        // Test individual effect configuration methods
        var bitConfig = BitReductionConfig()
        bitConfig.bitDepth = 4.0
        bitConfig.dithering = true
        trackFX.setBitReduction(bitConfig)
        
        XCTAssertEqual(trackFX.getParameterValue(index: 0), 4.0, accuracy: testTolerance)
        
        var srConfig = SampleRateReductionConfig()
        srConfig.downsampleFactor = 8
        srConfig.antiAliasing = true
        trackFX.setSampleRateReduction(srConfig)
        
        XCTAssertEqual(trackFX.getParameterValue(index: 2), 8.0, accuracy: testTolerance)
        
        var overdriveConfig = OverdriveConfig()
        overdriveConfig.drive = 0.8
        overdriveConfig.tone = -0.5
        overdriveConfig.overdriveType = .fuzz
        trackFX.setOverdrive(overdriveConfig)
        
        XCTAssertEqual(trackFX.getParameterValue(index: 4), 0.8, accuracy: testTolerance)
        XCTAssertEqual(trackFX.getParameterValue(index: 5), -0.5, accuracy: testTolerance)
    }
    
    // MARK: - Helper Functions
    
    private func calculateRMS(_ buffer: [Float]) -> Float {
        var sum: Float = 0.0
        for sample in buffer {
            sum += sample * sample
        }
        return sqrt(sum / Float(buffer.count))
    }
    
    private func generateTestSignal(frequency: Float, amplitude: Float, frameCount: Int) -> [Float] {
        var buffer = [Float](repeating: 0.0, count: frameCount)
        for i in 0..<frameCount {
            let phase = 2.0 * Float.pi * frequency * Float(i) / Float(sampleRate)
            buffer[i] = sin(phase) * amplitude
        }
        return buffer
    }
    
    // MARK: - Integration Tests
    
    func testFXMachineProtocolCompliance() {
        // Test FXMachine protocol compliance
        XCTAssertGreaterThan(trackFX.parameterCount, 0, "Should have parameters")
        
        for i in 0..<trackFX.parameterCount {
            let name = trackFX.getParameterName(index: i)
            XCTAssertFalse(name.isEmpty, "Parameter \(i) should have a name")
            
            let value = trackFX.getParameterValue(index: i)
            XCTAssertFalse(value.isNaN, "Parameter \(i) value should not be NaN")
            
            let displayValue = trackFX.getParameterDisplayValue(index: i)
            XCTAssertFalse(displayValue.isEmpty, "Parameter \(i) should have display value")
        }
    }
    
    func testEffectChainConsistency() {
        // Test that effect chain produces consistent results
        let testInput: Float = 0.6
        
        // Configure effects
        trackFX.setParameterValue(index: 0, value: 8.0)
        trackFX.setParameterValue(index: 2, value: 2.0)
        trackFX.setParameterValue(index: 4, value: 0.5)
        
        // Process same input multiple times
        var outputs: [Float] = []
        for _ in 0..<10 {
            outputs.append(trackFX.processSample(testInput))
        }
        
        // All outputs should be the same (no random variation unless dithering is enabled)
        let firstOutput = outputs[0]
        for output in outputs {
            XCTAssertEqual(output, firstOutput, accuracy: testTolerance,
                          "Effect chain should produce consistent results")
        }
    }
}