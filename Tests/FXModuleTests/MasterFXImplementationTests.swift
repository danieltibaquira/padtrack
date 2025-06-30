// MasterFXImplementationTests.swift
// DigitonePad - FXModuleTests
//
// Comprehensive test suite for Master FX Implementation

import XCTest
import MachineProtocols
@testable import FXModule

final class MasterFXImplementationTests: XCTestCase {
    
    var masterFX: MasterFXProcessor!
    let sampleRate: Double = 44100.0
    let bufferSize = 512
    
    override func setUp() {
        super.setUp()
        masterFX = MasterFXProcessor(sampleRate: sampleRate)
    }
    
    override func tearDown() {
        masterFX = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialization() {
        XCTAssertNotNil(masterFX)
        XCTAssertFalse(masterFX.isBypassed)
        XCTAssertTrue(masterFX.config.compressor.enabled)
        XCTAssertTrue(masterFX.config.overdrive.enabled)
        XCTAssertTrue(masterFX.config.limiter.enabled)
    }
    
    func testBypassedProcessing() {
        masterFX.isBypassed = true
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.5)
        let outputBuffer = masterFX.process(input: inputData.buffer)
        
        // Bypassed processor should return input unchanged
        for i in 0..<bufferSize * 2 {
            XCTAssertEqual(outputBuffer.data[i], inputData.buffer.data[i], accuracy: 0.001,
                          "Bypassed processor should pass input unchanged")
        }
        
        inputData.deallocate()
    }
    
    func testEffectEnableDisable() {
        // Test compressor enable/disable
        masterFX.setEffectEnabled(.compressor, enabled: false)
        XCTAssertFalse(masterFX.isEffectEnabled(.compressor))
        
        masterFX.setEffectEnabled(.compressor, enabled: true)
        XCTAssertTrue(masterFX.isEffectEnabled(.compressor))
        
        // Test overdrive enable/disable
        masterFX.setEffectEnabled(.overdrive, enabled: false)
        XCTAssertFalse(masterFX.isEffectEnabled(.overdrive))
        
        // Test limiter enable/disable
        masterFX.setEffectEnabled(.limiter, enabled: false)
        XCTAssertFalse(masterFX.isEffectEnabled(.limiter))
        
        // Test EQ enable/disable
        masterFX.setEffectEnabled(.eq, enabled: true)
        XCTAssertTrue(masterFX.isEffectEnabled(.eq))
    }
    
    // MARK: - Compressor Tests
    
    func testCompressorProcessing() {
        // Enable only compressor
        masterFX.setEffectEnabled(.compressor, enabled: true)
        masterFX.setEffectEnabled(.overdrive, enabled: false)
        masterFX.setEffectEnabled(.limiter, enabled: false)
        masterFX.setEffectEnabled(.eq, enabled: false)
        
        // Configure compressor for noticeable effect
        masterFX.config.compressor.threshold = -20.0
        masterFX.config.compressor.ratio = 4.0
        masterFX.config.compressor.attack = 1.0
        masterFX.config.compressor.release = 50.0
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.8)
        let outputBuffer = masterFX.process(input: inputData.buffer)
        
        // Should produce compressed output
        var outputRMS: Float = 0.0
        for i in 0..<bufferSize * 2 {
            outputRMS += outputBuffer.data[i] * outputBuffer.data[i]
        }
        outputRMS = sqrt(outputRMS / Float(bufferSize * 2))
        
        XCTAssertGreaterThan(outputRMS, 0.01, "Compressor should produce measurable output")
        
        inputData.deallocate()
    }
    
    func testCompressorParameters() {
        // Test threshold parameter
        masterFX.config.compressor.threshold = -15.0
        XCTAssertEqual(masterFX.config.compressor.threshold, -15.0, accuracy: 0.1)
        
        // Test ratio parameter
        masterFX.config.compressor.ratio = 6.0
        XCTAssertEqual(masterFX.config.compressor.ratio, 6.0, accuracy: 0.1)
        
        // Test attack parameter
        masterFX.config.compressor.attack = 2.0
        XCTAssertEqual(masterFX.config.compressor.attack, 2.0, accuracy: 0.1)
        
        // Test release parameter
        masterFX.config.compressor.release = 200.0
        XCTAssertEqual(masterFX.config.compressor.release, 200.0, accuracy: 0.1)
    }
    
    func testCompressorCharacters() {
        let characters: [CompressorCharacter] = [.clean, .vintage, .aggressive, .smooth]
        
        for character in characters {
            masterFX.config.compressor.character = character
            XCTAssertEqual(masterFX.config.compressor.character, character)
            
            let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.7)
            let outputBuffer = masterFX.process(input: inputData.buffer)
            
            // Should process without crashing
            XCTAssertEqual(outputBuffer.frameCount, bufferSize)
            
            inputData.deallocate()
        }
    }
    
    // MARK: - Overdrive Tests
    
    func testOverdriveProcessing() {
        // Enable only overdrive
        masterFX.setEffectEnabled(.compressor, enabled: false)
        masterFX.setEffectEnabled(.overdrive, enabled: true)
        masterFX.setEffectEnabled(.limiter, enabled: false)
        masterFX.setEffectEnabled(.eq, enabled: false)
        
        // Configure overdrive for noticeable effect
        masterFX.config.overdrive.drive = 3.0
        masterFX.config.overdrive.saturation = .tube
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.5)
        let outputBuffer = masterFX.process(input: inputData.buffer)
        
        // Should produce distorted output
        var isDifferent = false
        for i in 0..<bufferSize * 2 {
            if abs(outputBuffer.data[i] - inputData.buffer.data[i]) > 0.01 {
                isDifferent = true
                break
            }
        }
        XCTAssertTrue(isDifferent, "Overdrive should modify the signal")
        
        inputData.deallocate()
    }
    
    func testOverdriveSaturationTypes() {
        let saturationTypes: [SaturationType] = [.tube, .transistor, .tape, .digital, .vintage]
        
        for saturationType in saturationTypes {
            masterFX.config.overdrive.saturation = saturationType
            XCTAssertEqual(masterFX.config.overdrive.saturation, saturationType)
            
            let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.8)
            let outputBuffer = masterFX.process(input: inputData.buffer)
            
            // Should process without crashing
            XCTAssertEqual(outputBuffer.frameCount, bufferSize)
            
            inputData.deallocate()
        }
    }
    
    func testOverdriveParameters() {
        // Test drive parameter
        masterFX.config.overdrive.drive = 5.0
        XCTAssertEqual(masterFX.config.overdrive.drive, 5.0, accuracy: 0.1)
        
        // Test tone parameter
        masterFX.config.overdrive.tone = 0.7
        XCTAssertEqual(masterFX.config.overdrive.tone, 0.7, accuracy: 0.01)
        
        // Test presence parameter
        masterFX.config.overdrive.presence = 3.0
        XCTAssertEqual(masterFX.config.overdrive.presence, 3.0, accuracy: 0.1)
        
        // Test warmth parameter
        masterFX.config.overdrive.warmth = -2.0
        XCTAssertEqual(masterFX.config.overdrive.warmth, -2.0, accuracy: 0.1)
    }
    
    // MARK: - Limiter Tests
    
    func testLimiterProcessing() {
        // Enable only limiter
        masterFX.setEffectEnabled(.compressor, enabled: false)
        masterFX.setEffectEnabled(.overdrive, enabled: false)
        masterFX.setEffectEnabled(.limiter, enabled: true)
        masterFX.setEffectEnabled(.eq, enabled: false)
        
        // Configure limiter for noticeable effect
        masterFX.config.limiter.ceiling = -6.0
        masterFX.config.limiter.release = 50.0
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 1.2) // Over ceiling
        let outputBuffer = masterFX.process(input: inputData.buffer)
        
        // Should limit peaks
        var maxPeak: Float = 0.0
        for i in 0..<bufferSize * 2 {
            maxPeak = max(maxPeak, abs(outputBuffer.data[i]))
        }
        
        let ceilingLinear = pow(10.0, -6.0 / 20.0) // -6dB in linear
        XCTAssertLessThanOrEqual(maxPeak, ceilingLinear * 1.1, "Limiter should control peaks")
        
        inputData.deallocate()
    }
    
    func testLimiterParameters() {
        // Test ceiling parameter
        masterFX.config.limiter.ceiling = -3.0
        XCTAssertEqual(masterFX.config.limiter.ceiling, -3.0, accuracy: 0.1)
        
        // Test release parameter
        masterFX.config.limiter.release = 150.0
        XCTAssertEqual(masterFX.config.limiter.release, 150.0, accuracy: 0.1)
        
        // Test lookahead parameter
        masterFX.config.limiter.lookahead = 8.0
        XCTAssertEqual(masterFX.config.limiter.lookahead, 8.0, accuracy: 0.1)
        
        // Test oversampling parameter
        masterFX.config.limiter.oversampling = 2
        XCTAssertEqual(masterFX.config.limiter.oversampling, 2)
    }
    
    // MARK: - EQ Tests
    
    func testEQProcessing() {
        // Enable only EQ
        masterFX.setEffectEnabled(.compressor, enabled: false)
        masterFX.setEffectEnabled(.overdrive, enabled: false)
        masterFX.setEffectEnabled(.limiter, enabled: false)
        masterFX.setEffectEnabled(.eq, enabled: true)
        
        // Configure EQ for noticeable effect
        masterFX.config.eq.lowShelf.gain = 3.0
        masterFX.config.eq.highShelf.gain = -2.0
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.5)
        let outputBuffer = masterFX.process(input: inputData.buffer)
        
        // Should produce EQ'd output
        var isDifferent = false
        for i in 0..<bufferSize * 2 {
            if abs(outputBuffer.data[i] - inputData.buffer.data[i]) > 0.001 {
                isDifferent = true
                break
            }
        }
        XCTAssertTrue(isDifferent, "EQ should modify the signal")
        
        inputData.deallocate()
    }
    
    func testEQBands() {
        // Test low shelf
        masterFX.config.eq.lowShelf.frequency = 200.0
        masterFX.config.eq.lowShelf.gain = 4.0
        masterFX.config.eq.lowShelf.q = 0.8
        
        XCTAssertEqual(masterFX.config.eq.lowShelf.frequency, 200.0, accuracy: 0.1)
        XCTAssertEqual(masterFX.config.eq.lowShelf.gain, 4.0, accuracy: 0.1)
        XCTAssertEqual(masterFX.config.eq.lowShelf.q, 0.8, accuracy: 0.01)
        
        // Test high shelf
        masterFX.config.eq.highShelf.frequency = 8000.0
        masterFX.config.eq.highShelf.gain = -3.0
        
        XCTAssertEqual(masterFX.config.eq.highShelf.frequency, 8000.0, accuracy: 0.1)
        XCTAssertEqual(masterFX.config.eq.highShelf.gain, -3.0, accuracy: 0.1)
    }
    
    // MARK: - Effect Chain Tests
    
    func testEffectChainOrder() {
        // Test default order
        let defaultOrder: [MasterEffectType] = [.eq, .compressor, .overdrive, .limiter]
        XCTAssertEqual(masterFX.config.chain.order, defaultOrder)
        
        // Test custom order
        let customOrder: [MasterEffectType] = [.compressor, .eq, .limiter, .overdrive]
        masterFX.config.chain.order = customOrder
        XCTAssertEqual(masterFX.config.chain.order, customOrder)
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.5)
        let outputBuffer = masterFX.process(input: inputData.buffer)
        
        // Should process without crashing
        XCTAssertEqual(outputBuffer.frameCount, bufferSize)
        
        inputData.deallocate()
    }
    
    func testParallelCompression() {
        masterFX.config.chain.parallelCompression = true
        masterFX.config.chain.parallelCompressionMix = 0.3
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.7)
        let outputBuffer = masterFX.process(input: inputData.buffer)
        
        // Should process with parallel compression
        XCTAssertEqual(outputBuffer.frameCount, bufferSize)
        
        inputData.deallocate()
    }
    
    func testMidSideProcessing() {
        masterFX.config.chain.midSideProcessing = true
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.5, channelCount: 2)
        let outputBuffer = masterFX.process(input: inputData.buffer)
        
        // Should process in mid-side mode
        XCTAssertEqual(outputBuffer.channelCount, 2)
        
        inputData.deallocate()
    }
    
    // MARK: - Master Output Tests
    
    func testMasterOutput() {
        // Configure master output
        masterFX.config.output.gain = 3.0
        masterFX.config.output.stereoWidth = 1.2
        masterFX.config.output.dcBlock = true
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.5)
        let outputBuffer = masterFX.process(input: inputData.buffer)
        
        // Should apply master output processing
        XCTAssertEqual(outputBuffer.frameCount, bufferSize)
        
        inputData.deallocate()
    }
    
    func testDithering() {
        masterFX.config.output.dithering = true
        masterFX.config.output.ditherType = .triangular
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.5)
        let outputBuffer = masterFX.process(input: inputData.buffer)
        
        // Should apply dithering
        XCTAssertEqual(outputBuffer.frameCount, bufferSize)
        
        inputData.deallocate()
    }
    
    // MARK: - Performance Tests
    
    func testPerformance() {
        // Enable all effects for maximum load
        masterFX.setEffectEnabled(.eq, enabled: true)
        masterFX.setEffectEnabled(.compressor, enabled: true)
        masterFX.setEffectEnabled(.overdrive, enabled: true)
        masterFX.setEffectEnabled(.limiter, enabled: true)
        
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.5)
        
        measure {
            for _ in 0..<100 {
                _ = masterFX.process(input: inputData.buffer)
            }
        }
        
        inputData.deallocate()
    }
    
    // MARK: - Reset Tests
    
    func testReset() {
        // Process some audio to establish internal state
        let inputData = createTestBuffer(frequency: 1000.0, amplitude: 0.8)
        
        for _ in 0..<10 {
            _ = masterFX.process(input: inputData.buffer)
        }
        
        // Reset processor
        masterFX.reset()
        
        // Process silence and check for clean state
        let silentData = createTestBuffer(frequency: 1000.0, amplitude: 0.0)
        let outputBuffer = masterFX.process(input: silentData.buffer)
        
        // Should produce minimal output after reset
        for i in 0..<bufferSize * 2 {
            XCTAssertLessThan(abs(outputBuffer.data[i]), 0.01, "Reset should clear internal state")
        }
        
        inputData.deallocate()
        silentData.deallocate()
    }
    
    // MARK: - Helper Methods
    
    private func createTestBuffer(frequency: Float = 1000.0, amplitude: Float = 0.5, channelCount: Int = 2) -> (buffer: MachineProtocols.AudioBuffer, deallocate: () -> Void) {
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize * channelCount)
        
        // Generate test signal
        for i in 0..<bufferSize {
            let phase = Float(i) * 2.0 * Float.pi * frequency / Float(sampleRate)
            let sample = sin(phase) * amplitude
            
            for channel in 0..<channelCount {
                inputData[i * channelCount + channel] = sample
            }
        }
        
        let buffer = MachineProtocols.AudioBuffer(
            data: inputData,
            frameCount: bufferSize,
            channelCount: channelCount,
            sampleRate: sampleRate
        )
        
        return (buffer, { inputData.deallocate() })
    }
}
