import XCTest
import SwiftUI
import Combine
@testable import DigitonePad
@testable import FXModule
@testable import MachineProtocols

/// Comprehensive tests for master effects system
class MasterEffectsTests: XCTestCase {
    
    var masterEffects: MasterEffectsProcessor!
    var mockAudioBuffer: MockAudioBuffer!
    
    override func setUp() {
        super.setUp()
        
        masterEffects = MasterEffectsProcessor()
        mockAudioBuffer = MockAudioBuffer(frameCount: 512, channelCount: 2, sampleRate: 44100.0)
        
        // Fill with test signal
        for i in 0..<mockAudioBuffer.samples.count {
            mockAudioBuffer.samples[i] = sin(Float(i) * 0.1) * 0.5
        }
    }
    
    override func tearDown() {
        masterEffects = nil
        mockAudioBuffer = nil
        super.tearDown()
    }
    
    // MARK: - Master Effects Processor Tests
    
    func testMasterEffectsProcessor_Initialization() {
        XCTAssertFalse(masterEffects.masterBypass)
        XCTAssertEqual(masterEffects.masterGain, 0.0)
        XCTAssertEqual(masterEffects.effectsOrder.count, 3)
        XCTAssertTrue(masterEffects.effectsOrder.contains(.compressor))
        XCTAssertTrue(masterEffects.effectsOrder.contains(.overdrive))
        XCTAssertTrue(masterEffects.effectsOrder.contains(.limiter))
    }
    
    func testMasterEffectsProcessor_AudioProcessing() {
        let output = masterEffects.process(input: mockAudioBuffer)
        
        XCTAssertEqual(output.samples.count, mockAudioBuffer.samples.count)
        XCTAssertEqual(output.channelCount, mockAudioBuffer.channelCount)
        XCTAssertEqual(output.frameCount, mockAudioBuffer.frameCount)
    }
    
    func testMasterEffectsProcessor_MasterBypass() {
        masterEffects.masterBypass = true
        
        let output = masterEffects.process(input: mockAudioBuffer)
        
        // With bypass, output should be identical to input (except for master gain)
        for i in 0..<min(output.samples.count, mockAudioBuffer.samples.count) {
            XCTAssertEqual(output.samples[i], mockAudioBuffer.samples[i], accuracy: 0.001)
        }
    }
    
    func testMasterEffectsProcessor_MasterGain() {
        masterEffects.masterGain = 6.0 // +6dB
        masterEffects.masterBypass = true // Bypass effects to test only gain
        
        let output = masterEffects.process(input: mockAudioBuffer)
        
        let expectedGain = pow(10.0, 6.0 / 20.0) // ~2.0
        for i in 0..<min(output.samples.count, mockAudioBuffer.samples.count) {
            let expectedSample = mockAudioBuffer.samples[i] * expectedGain
            XCTAssertEqual(output.samples[i], expectedSample, accuracy: 0.01)
        }
    }
    
    func testMasterEffectsProcessor_EffectsOrder() {
        let newOrder: [MasterEffectType] = [.limiter, .compressor, .overdrive]
        masterEffects.setEffectsOrder(newOrder)
        
        XCTAssertEqual(masterEffects.effectsOrder, newOrder)
    }
    
    func testMasterEffectsProcessor_InvalidEffectsOrder() {
        let invalidOrder: [MasterEffectType] = [.compressor, .overdrive] // Missing limiter
        masterEffects.setEffectsOrder(invalidOrder)
        
        // Should not change the order
        XCTAssertNotEqual(masterEffects.effectsOrder, invalidOrder)
    }
    
    // MARK: - Compressor Tests
    
    func testCompressor_Parameters() {
        let compressor = masterEffects.compressor
        
        compressor.threshold = -10.0
        XCTAssertEqual(compressor.threshold, -10.0)
        
        compressor.ratio = 4.0
        XCTAssertEqual(compressor.ratio, 4.0)
        
        compressor.attackTime = 5.0
        XCTAssertEqual(compressor.attackTime, 5.0)
        
        compressor.releaseTime = 100.0
        XCTAssertEqual(compressor.releaseTime, 100.0)
    }
    
    func testCompressor_ParameterClamping() {
        let compressor = masterEffects.compressor
        
        compressor.threshold = -100.0 // Should be clamped
        XCTAssertGreaterThanOrEqual(compressor.threshold, -60.0)
        
        compressor.ratio = 100.0 // Should be clamped
        XCTAssertLessThanOrEqual(compressor.ratio, 20.0)
    }
    
    func testCompressor_Processing() {
        let compressor = masterEffects.compressor
        compressor.isEnabled = true
        compressor.threshold = -20.0
        compressor.ratio = 4.0
        
        let output = compressor.process(input: mockAudioBuffer)
        
        XCTAssertEqual(output.samples.count, mockAudioBuffer.samples.count)
    }
    
    func testCompressor_Presets() {
        let compressor = masterEffects.compressor
        
        compressor.applyPreset(.aggressive)
        XCTAssertEqual(compressor.threshold, -8.0)
        XCTAssertEqual(compressor.ratio, 8.0)
        
        compressor.applyPreset(.gentle)
        XCTAssertEqual(compressor.threshold, -18.0)
        XCTAssertEqual(compressor.ratio, 2.0)
    }
    
    // MARK: - Overdrive Tests
    
    func testOverdrive_Parameters() {
        let overdrive = masterEffects.overdrive
        
        overdrive.driveAmount = 3.0
        XCTAssertEqual(overdrive.driveAmount, 3.0)
        
        overdrive.saturationType = .tube
        XCTAssertEqual(overdrive.saturationType, .tube)
        
        overdrive.outputLevel = -2.0
        XCTAssertEqual(overdrive.outputLevel, -2.0)
    }
    
    func testOverdrive_SaturationTypes() {
        let overdrive = masterEffects.overdrive
        
        for saturationType in MasterOverdriveEffect.SaturationType.allCases {
            overdrive.saturationType = saturationType
            XCTAssertEqual(overdrive.saturationType, saturationType)
        }
    }
    
    func testOverdrive_Processing() {
        let overdrive = masterEffects.overdrive
        overdrive.isEnabled = true
        overdrive.driveAmount = 2.0
        
        let output = overdrive.process(input: mockAudioBuffer)
        
        XCTAssertEqual(output.samples.count, mockAudioBuffer.samples.count)
    }
    
    func testOverdrive_Presets() {
        let overdrive = masterEffects.overdrive
        
        overdrive.applyPreset(.warm)
        XCTAssertEqual(overdrive.driveAmount, 2.0)
        XCTAssertEqual(overdrive.saturationType, .tube)
        
        overdrive.applyPreset(.aggressive)
        XCTAssertEqual(overdrive.driveAmount, 5.0)
        XCTAssertEqual(overdrive.saturationType, .digital)
    }
    
    // MARK: - Limiter Tests
    
    func testLimiter_Parameters() {
        let limiter = masterEffects.limiter
        
        limiter.ceiling = -1.0
        XCTAssertEqual(limiter.ceiling, -1.0)
        
        limiter.releaseTime = 50.0
        XCTAssertEqual(limiter.releaseTime, 50.0)
        
        limiter.lookaheadTime = 5.0
        XCTAssertEqual(limiter.lookaheadTime, 5.0)
    }
    
    func testLimiter_OversamplingFactor() {
        let limiter = masterEffects.limiter
        
        limiter.oversamplingFactor = 4
        XCTAssertEqual(limiter.oversamplingFactor, 4)
        
        limiter.oversamplingFactor = 3 // Invalid, should default to 4
        XCTAssertEqual(limiter.oversamplingFactor, 4)
    }
    
    func testLimiter_Processing() {
        let limiter = masterEffects.limiter
        limiter.isEnabled = true
        limiter.ceiling = -3.0
        
        let output = limiter.process(input: mockAudioBuffer)
        
        XCTAssertEqual(output.samples.count, mockAudioBuffer.samples.count)
    }
    
    func testLimiter_Presets() {
        let limiter = masterEffects.limiter
        
        limiter.applyPreset(.mastering)
        XCTAssertEqual(limiter.ceiling, -0.1)
        XCTAssertEqual(limiter.oversamplingFactor, 8)
        
        limiter.applyPreset(.broadcast)
        XCTAssertEqual(limiter.ceiling, -1.0)
        XCTAssertEqual(limiter.oversamplingFactor, 4)
    }
    
    // MARK: - Preset System Tests
    
    func testMasterEffects_PresetSaveLoad() {
        // Configure master effects
        masterEffects.masterGain = 2.0
        masterEffects.compressor.threshold = -10.0
        masterEffects.compressor.ratio = 4.0
        masterEffects.overdrive.driveAmount = 3.0
        masterEffects.limiter.ceiling = -1.0
        
        // Save preset
        let preset = masterEffects.savePreset(name: "Test Preset")
        XCTAssertEqual(preset.name, "Test Preset")
        XCTAssertEqual(preset.masterGain, 2.0)
        
        // Reset and load preset
        masterEffects.resetAllEffects()
        masterEffects.loadPreset(preset)
        
        // Verify loaded state
        XCTAssertEqual(masterEffects.masterGain, 2.0)
        XCTAssertEqual(masterEffects.compressor.threshold, -10.0)
        XCTAssertEqual(masterEffects.compressor.ratio, 4.0)
        XCTAssertEqual(masterEffects.overdrive.driveAmount, 3.0)
        XCTAssertEqual(masterEffects.limiter.ceiling, -1.0)
    }
    
    func testMasterEffects_QuickPresets() {
        masterEffects.applyQuickPreset(.warm)
        XCTAssertTrue(masterEffects.compressor.isEnabled)
        XCTAssertTrue(masterEffects.overdrive.isEnabled)
        
        masterEffects.applyQuickPreset(.transparent)
        XCTAssertFalse(masterEffects.compressor.isEnabled)
        XCTAssertFalse(masterEffects.overdrive.isEnabled)
        XCTAssertTrue(masterEffects.limiter.isEnabled)
    }
    
    // MARK: - Performance Tests
    
    func testMasterEffects_ProcessingPerformance() {
        // Enable all effects
        masterEffects.compressor.isEnabled = true
        masterEffects.overdrive.isEnabled = true
        masterEffects.limiter.isEnabled = true
        
        measure {
            for _ in 0..<100 {
                _ = masterEffects.process(input: mockAudioBuffer)
            }
        }
    }
    
    func testMasterEffects_PerformanceMonitoring() {
        // Process some audio to generate metrics
        for _ in 0..<10 {
            _ = masterEffects.process(input: mockAudioBuffer)
        }
        
        let metrics = masterEffects.getPerformanceMetrics()
        
        XCTAssertGreaterThan(metrics.processCallCount, 0)
        XCTAssertGreaterThan(metrics.totalSamplesProcessed, 0)
        XCTAssertGreaterThan(metrics.totalProcessingTime, 0)
        
        // Reset metrics
        masterEffects.resetPerformanceMetrics()
        let resetMetrics = masterEffects.getPerformanceMetrics()
        
        XCTAssertEqual(resetMetrics.processCallCount, 0)
        XCTAssertEqual(resetMetrics.totalSamplesProcessed, 0)
        XCTAssertEqual(resetMetrics.totalProcessingTime, 0)
    }
    
    // MARK: - Edge Cases
    
    func testMasterEffects_EdgeCases() {
        // Test with empty buffer
        let emptyBuffer = MockAudioBuffer(frameCount: 0, channelCount: 2, sampleRate: 44100.0)
        let output = masterEffects.process(input: emptyBuffer)
        XCTAssertEqual(output.samples.count, 0)
        
        // Test with extreme gain values
        masterEffects.masterGain = 100.0 // Very high gain
        let highGainOutput = masterEffects.process(input: mockAudioBuffer)
        XCTAssertEqual(highGainOutput.samples.count, mockAudioBuffer.samples.count)
        
        masterEffects.masterGain = -100.0 // Very low gain
        let lowGainOutput = masterEffects.process(input: mockAudioBuffer)
        XCTAssertEqual(lowGainOutput.samples.count, mockAudioBuffer.samples.count)
    }
    
    func testMasterEffects_StateReset() {
        // Configure effects
        masterEffects.compressor.threshold = -5.0
        masterEffects.overdrive.driveAmount = 5.0
        masterEffects.limiter.ceiling = -2.0
        masterEffects.masterGain = 3.0
        
        // Reset all effects
        masterEffects.resetAllEffects()
        
        // Verify reset state
        XCTAssertEqual(masterEffects.masterGain, 0.0)
        XCTAssertFalse(masterEffects.masterBypass)
    }
}

// MARK: - Mock Audio Buffer

private struct MockAudioBuffer: AudioBufferProtocol {
    let data: UnsafeMutablePointer<Float>
    let frameCount: Int
    let channelCount: Int
    let sampleRate: Double
    var samples: [Float]
    
    init(frameCount: Int, channelCount: Int, sampleRate: Double) {
        self.frameCount = frameCount
        self.channelCount = channelCount
        self.sampleRate = sampleRate
        self.samples = Array(repeating: 0.0, count: frameCount * channelCount)
        self.data = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount)
    }
}
