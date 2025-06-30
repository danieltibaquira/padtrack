import XCTest
import SwiftUI
@testable import DigitonePad
@testable import FXModule
@testable import MachineProtocols

/// Unit tests for track effects functionality
class TrackEffectsTests: XCTestCase {
    
    var trackProcessor: TrackEffectsProcessor!
    var mockAudioBuffer: MockAudioBuffer!
    
    override func setUp() {
        super.setUp()
        trackProcessor = TrackEffectsProcessor(trackId: 1)
        mockAudioBuffer = MockAudioBuffer(frameCount: 512, channelCount: 2, sampleRate: 44100.0)
        
        // Fill with test signal
        for i in 0..<mockAudioBuffer.samples.count {
            mockAudioBuffer.samples[i] = sin(Float(i) * 0.1) * 0.5
        }
    }
    
    override func tearDown() {
        trackProcessor = nil
        mockAudioBuffer = nil
        super.tearDown()
    }
    
    // MARK: - Track Processor Tests
    
    func testTrackProcessor_Initialization() {
        XCTAssertEqual(trackProcessor.trackId, 1)
        XCTAssertFalse(trackProcessor.isBypassed)
        XCTAssertFalse(trackProcessor.isMuted)
        XCTAssertFalse(trackProcessor.isSoloed)
        XCTAssertEqual(trackProcessor.inputGain, 0.0)
        XCTAssertEqual(trackProcessor.outputGain, 0.0)
        XCTAssertEqual(trackProcessor.pan, 0.0)
        XCTAssertEqual(trackProcessor.effectCount, 0)
    }
    
    func testTrackProcessor_AddEffect() {
        // Test adding bit reduction effect
        let success = trackProcessor.addEffect(.bitReduction)
        XCTAssertTrue(success)
        XCTAssertEqual(trackProcessor.effectCount, 1)
        
        // Test adding overdrive effect
        let success2 = trackProcessor.addEffect(.overdrive)
        XCTAssertTrue(success2)
        XCTAssertEqual(trackProcessor.effectCount, 2)
        
        // Verify effect types
        let effects = trackProcessor.getEffects()
        XCTAssertEqual(effects[0].effectType, .bitCrusher)
        XCTAssertEqual(effects[1].effectType, .overdrive)
    }
    
    func testTrackProcessor_RemoveEffect() {
        // Add effects first
        _ = trackProcessor.addEffect(.bitReduction)
        _ = trackProcessor.addEffect(.overdrive)
        XCTAssertEqual(trackProcessor.effectCount, 2)
        
        // Remove first effect
        let removedEffect = trackProcessor.removeEffect(at: 0)
        XCTAssertNotNil(removedEffect)
        XCTAssertEqual(removedEffect?.effectType, .bitCrusher)
        XCTAssertEqual(trackProcessor.effectCount, 1)
        
        // Verify remaining effect
        let remainingEffects = trackProcessor.getEffects()
        XCTAssertEqual(remainingEffects[0].effectType, .overdrive)
    }
    
    func testTrackProcessor_MoveEffect() {
        // Add effects
        _ = trackProcessor.addEffect(.bitReduction)
        _ = trackProcessor.addEffect(.overdrive)
        _ = trackProcessor.addEffect(.sampleRateReduction)
        
        // Move first effect to last position
        let success = trackProcessor.moveEffect(from: 0, to: 2)
        XCTAssertTrue(success)
        
        // Verify new order
        let effects = trackProcessor.getEffects()
        XCTAssertEqual(effects[0].effectType, .overdrive)
        XCTAssertEqual(effects[1].effectType, .sampleRateReduction)
        XCTAssertEqual(effects[2].effectType, .bitCrusher)
    }
    
    func testTrackProcessor_ClearEffects() {
        // Add effects
        _ = trackProcessor.addEffect(.bitReduction)
        _ = trackProcessor.addEffect(.overdrive)
        XCTAssertEqual(trackProcessor.effectCount, 2)
        
        // Clear all effects
        trackProcessor.clearEffects()
        XCTAssertEqual(trackProcessor.effectCount, 0)
    }
    
    // MARK: - Audio Processing Tests
    
    func testTrackProcessor_ProcessCleanSignal() {
        // Process without effects
        let output = trackProcessor.process(input: mockAudioBuffer)
        
        // Output should be identical to input (no effects)
        for i in 0..<output.samples.count {
            XCTAssertEqual(output.samples[i], mockAudioBuffer.samples[i], accuracy: 0.001)
        }
    }
    
    func testTrackProcessor_ProcessWithBypass() {
        // Add effect and bypass track
        _ = trackProcessor.addEffect(.overdrive)
        trackProcessor.setBypass(true)
        
        let output = trackProcessor.process(input: mockAudioBuffer)
        
        // Output should be identical to input (bypassed)
        for i in 0..<output.samples.count {
            XCTAssertEqual(output.samples[i], mockAudioBuffer.samples[i], accuracy: 0.001)
        }
    }
    
    func testTrackProcessor_ProcessWithMute() {
        // Mute track
        trackProcessor.setMute(true)
        
        let output = trackProcessor.process(input: mockAudioBuffer)
        
        // Output should be silent
        for i in 0..<output.samples.count {
            XCTAssertEqual(output.samples[i], 0.0, accuracy: 0.001)
        }
    }
    
    func testTrackProcessor_ProcessWithGain() {
        // Set input gain to +6dB
        trackProcessor.setInputGain(6.0)
        
        let output = trackProcessor.process(input: mockAudioBuffer)
        
        // Output should be amplified
        let expectedGain = pow(10.0, 6.0 / 20.0) // ~2.0
        for i in 0..<output.samples.count {
            let expectedSample = mockAudioBuffer.samples[i] * expectedGain
            XCTAssertEqual(output.samples[i], expectedSample, accuracy: 0.01)
        }
    }
    
    func testTrackProcessor_ProcessWithEffects() {
        // Add overdrive effect
        _ = trackProcessor.addEffect(.overdrive)
        
        let output = trackProcessor.process(input: mockAudioBuffer)
        
        // Output should be different from input (processed)
        var isDifferent = false
        for i in 0..<output.samples.count {
            if abs(output.samples[i] - mockAudioBuffer.samples[i]) > 0.001 {
                isDifferent = true
                break
            }
        }
        XCTAssertTrue(isDifferent, "Output should be different from input when effects are applied")
    }
    
    // MARK: - Control Tests
    
    func testTrackProcessor_GainControls() {
        // Test input gain
        trackProcessor.setInputGain(12.0)
        XCTAssertEqual(trackProcessor.inputGain, 12.0)
        
        // Test clamping
        trackProcessor.setInputGain(100.0)
        XCTAssertEqual(trackProcessor.inputGain, 20.0) // Should be clamped to max
        
        trackProcessor.setInputGain(-100.0)
        XCTAssertEqual(trackProcessor.inputGain, -60.0) // Should be clamped to min
        
        // Test output gain
        trackProcessor.setOutputGain(-6.0)
        XCTAssertEqual(trackProcessor.outputGain, -6.0)
    }
    
    func testTrackProcessor_PanControl() {
        // Test pan
        trackProcessor.setPan(0.5)
        XCTAssertEqual(trackProcessor.pan, 0.5)
        
        // Test clamping
        trackProcessor.setPan(2.0)
        XCTAssertEqual(trackProcessor.pan, 1.0) // Should be clamped to max
        
        trackProcessor.setPan(-2.0)
        XCTAssertEqual(trackProcessor.pan, -1.0) // Should be clamped to min
    }
    
    func testTrackProcessor_StateControls() {
        // Test bypass
        trackProcessor.setBypass(true)
        XCTAssertTrue(trackProcessor.isBypassed)
        
        trackProcessor.setBypass(false)
        XCTAssertFalse(trackProcessor.isBypassed)
        
        // Test mute
        trackProcessor.setMute(true)
        XCTAssertTrue(trackProcessor.isMuted)
        
        // Test solo
        trackProcessor.setSolo(true)
        XCTAssertTrue(trackProcessor.isSoloed)
    }
    
    // MARK: - Preset Tests
    
    func testTrackProcessor_SaveAndLoadPreset() {
        // Configure track
        trackProcessor.setInputGain(6.0)
        trackProcessor.setOutputGain(-3.0)
        trackProcessor.setPan(0.3)
        _ = trackProcessor.addEffect(.overdrive)
        _ = trackProcessor.addEffect(.bitReduction)
        
        // Save preset
        let preset = trackProcessor.savePreset(name: "Test Preset")
        XCTAssertEqual(preset.name, "Test Preset")
        XCTAssertEqual(preset.trackId, 1)
        XCTAssertEqual(preset.inputGain, 6.0)
        XCTAssertEqual(preset.outputGain, -3.0)
        XCTAssertEqual(preset.pan, 0.3)
        XCTAssertEqual(preset.effectPresets.count, 2)
        
        // Clear track and load preset
        trackProcessor.clearEffects()
        trackProcessor.setInputGain(0.0)
        trackProcessor.setOutputGain(0.0)
        trackProcessor.setPan(0.0)
        
        trackProcessor.loadPreset(preset)
        
        // Verify loaded state
        XCTAssertEqual(trackProcessor.inputGain, 6.0)
        XCTAssertEqual(trackProcessor.outputGain, -3.0)
        XCTAssertEqual(trackProcessor.pan, 0.3)
        XCTAssertEqual(trackProcessor.effectCount, 2)
    }
    
    // MARK: - Factory Method Tests
    
    func testTrackProcessor_CreateWithPreset() {
        let lofiProcessor = TrackEffectsProcessor.createWithPreset(.lofi, trackId: 2)
        XCTAssertEqual(lofiProcessor.trackId, 2)
        XCTAssertGreaterThan(lofiProcessor.effectCount, 0)
        
        let cleanProcessor = TrackEffectsProcessor.createWithPreset(.clean, trackId: 3)
        XCTAssertEqual(cleanProcessor.trackId, 3)
        XCTAssertEqual(cleanProcessor.effectCount, 0)
        
        let extremeProcessor = TrackEffectsProcessor.createWithPreset(.extreme, trackId: 4)
        XCTAssertEqual(extremeProcessor.trackId, 4)
        XCTAssertGreaterThan(extremeProcessor.effectCount, 1)
    }
    
    // MARK: - Performance Tests
    
    func testTrackProcessor_ProcessingPerformance() {
        // Add multiple effects
        _ = trackProcessor.addEffect(.overdrive)
        _ = trackProcessor.addEffect(.bitReduction)
        _ = trackProcessor.addEffect(.sampleRateReduction)
        
        measure {
            for _ in 0..<100 {
                _ = trackProcessor.process(input: mockAudioBuffer)
            }
        }
    }
    
    func testTrackProcessor_EffectManagementPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = trackProcessor.addEffect(.overdrive)
                _ = trackProcessor.removeEffect(at: 0)
            }
        }
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
