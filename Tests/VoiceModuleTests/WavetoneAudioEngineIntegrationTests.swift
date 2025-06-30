import XCTest
@testable import VoiceModule
@testable import MachineProtocols
@testable import AudioEngine

/// Comprehensive test suite for WAVETONE Audio Engine Integration
final class WavetoneAudioEngineIntegrationTests: XCTestCase {
    
    var voiceMachine: WavetoneVoiceMachine!
    var audioBuffer: AudioBuffer!
    
    override func setUp() {
        super.setUp()
        
        // Initialize voice machine with higher polyphony for testing
        voiceMachine = WavetoneVoiceMachine(name: "Test WAVETONE", polyphony: 8)
        
        // Initialize audio buffer for testing
        let bufferSize = 512
        audioBuffer = AudioBuffer(channelCount: 2, frameCount: bufferSize)
    }
    
    override func tearDown() {
        voiceMachine = nil
        audioBuffer = nil
        super.tearDown()
    }
    
    // MARK: - Polyphony Management Tests
    
    func testPolyphonicNoteOnOff() {
        // Test basic polyphonic operation
        let notes: [UInt8] = [60, 64, 67, 72]  // C major chord
        
        // Start multiple notes
        for note in notes {
            voiceMachine.noteOn(note: note, velocity: 100, channel: 0)
        }
        
        // Check polyphony info
        let polyInfo = voiceMachine.getPolyphonyInfo()
        XCTAssertEqual(polyInfo.active, 4, "Should have 4 active voices")
        XCTAssertEqual(polyInfo.total, 8, "Should have 8 total voices available")
        XCTAssertEqual(polyInfo.usage, 0.5, accuracy: 0.01, "Should be 50% polyphony usage")
        
        // Process audio to ensure all voices are generating sound
        voiceMachine.processAudio(buffer: audioBuffer)
        
        var hasNonZeroSamples = false
        for channel in 0..<audioBuffer.channelCount {
            for frame in 0..<audioBuffer.frameCount {
                if abs(audioBuffer.getSample(channel: channel, frame: frame)) > 0.001 {
                    hasNonZeroSamples = true
                    break
                }
            }
            if hasNonZeroSamples { break }
        }
        
        XCTAssertTrue(hasNonZeroSamples, "Should generate audio with multiple voices")
        
        // Release notes
        for note in notes {
            voiceMachine.noteOff(note: note, channel: 0)
        }
    }
    
    func testVoiceStealingBehavior() {
        // Fill up all available voices
        for i in 0..<8 {
            voiceMachine.noteOn(note: 60 + UInt8(i), velocity: 100, channel: 0)
        }
        
        let polyInfo1 = voiceMachine.getPolyphonyInfo()
        XCTAssertEqual(polyInfo1.active, 8, "Should have 8 active voices")
        
        // Try to add one more voice (should trigger voice stealing)
        voiceMachine.noteOn(note: 72, velocity: 100, channel: 0)
        
        let polyInfo2 = voiceMachine.getPolyphonyInfo()
        XCTAssertLessThanOrEqual(polyInfo2.active, 8, "Should not exceed polyphony limit")
        
        voiceMachine.allNotesOff()
    }
    
    func testVoiceCleanup() {
        // Start and stop notes to test voice cleanup
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        voiceMachine.noteOn(note: 64, velocity: 100, channel: 0)
        
        // Process some audio
        for _ in 0..<10 {
            voiceMachine.processAudio(buffer: audioBuffer)
        }
        
        // Release notes
        voiceMachine.noteOff(note: 60, channel: 0)
        voiceMachine.noteOff(note: 64, channel: 0)
        
        // Process more audio to let envelopes finish
        for _ in 0..<100 {
            voiceMachine.processAudio(buffer: audioBuffer)
        }
        
        // Check that voices are cleaned up
        let polyInfo = voiceMachine.getPolyphonyInfo()
        XCTAssertEqual(polyInfo.active, 0, "Should have no active voices after cleanup")
    }
    
    // MARK: - Audio Processing Tests
    
    func testPolyphonicAudioMixing() {
        // Test that multiple voices mix correctly
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)  // C
        voiceMachine.noteOn(note: 64, velocity: 100, channel: 0)  // E
        voiceMachine.noteOn(note: 67, velocity: 100, channel: 0)  // G
        
        // Process audio
        voiceMachine.processAudio(buffer: audioBuffer)
        
        // Store polyphonic output
        var polyOutput = Array<Float>(repeating: 0.0, count: audioBuffer.frameCount)
        for frame in 0..<audioBuffer.frameCount {
            polyOutput[frame] = audioBuffer.getSample(channel: 0, frame: frame)
        }
        
        // Clear and test single note
        voiceMachine.allNotesOff()
        audioBuffer.clear()
        
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        voiceMachine.processAudio(buffer: audioBuffer)
        
        // Compare outputs - polyphonic should be different (and likely louder)
        var outputsDiffer = false
        for frame in 0..<audioBuffer.frameCount {
            let monoOutput = audioBuffer.getSample(channel: 0, frame: frame)
            if abs(polyOutput[frame] - monoOutput) > 0.001 {
                outputsDiffer = true
                break
            }
        }
        
        XCTAssertTrue(outputsDiffer, "Polyphonic output should differ from monophonic")
        
        voiceMachine.allNotesOff()
    }
    
    func testAudioScalingWithPolyphony() {
        // Test that audio scaling prevents clipping with many voices
        let notes: [UInt8] = [60, 62, 64, 65, 67, 69, 71, 72]  // C major scale
        
        // Start all notes
        for note in notes {
            voiceMachine.noteOn(note: note, velocity: 127, channel: 0)  // Full velocity
        }
        
        // Process audio
        voiceMachine.processAudio(buffer: audioBuffer)
        
        // Check that output doesn't clip
        var maxSample: Float = 0.0
        for channel in 0..<audioBuffer.channelCount {
            for frame in 0..<audioBuffer.frameCount {
                let sample = abs(audioBuffer.getSample(channel: channel, frame: frame))
                maxSample = max(maxSample, sample)
            }
        }
        
        XCTAssertLessThanOrEqual(maxSample, 1.0, "Audio should not clip with full polyphony")
        
        voiceMachine.allNotesOff()
    }
    
    // MARK: - Parameter Integration Tests
    
    func testGlobalParameterPropagation() {
        // Start multiple voices
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        voiceMachine.noteOn(note: 64, velocity: 100, channel: 0)
        
        // Change a global parameter
        voiceMachine.setParameter("osc1_level", value: 0.3)
        
        // Process audio
        voiceMachine.processAudio(buffer: audioBuffer)
        
        // Store output with low level
        var lowLevelOutput = Array<Float>(repeating: 0.0, count: audioBuffer.frameCount)
        for frame in 0..<audioBuffer.frameCount {
            lowLevelOutput[frame] = audioBuffer.getSample(channel: 0, frame: frame)
        }
        
        // Change parameter again
        voiceMachine.setParameter("osc1_level", value: 0.8)
        audioBuffer.clear()
        voiceMachine.processAudio(buffer: audioBuffer)
        
        // Compare outputs
        var outputsDiffer = false
        for frame in 0..<audioBuffer.frameCount {
            let highLevelOutput = audioBuffer.getSample(channel: 0, frame: frame)
            if abs(lowLevelOutput[frame] - highLevelOutput) > 0.001 {
                outputsDiffer = true
                break
            }
        }
        
        XCTAssertTrue(outputsDiffer, "Parameter changes should affect all active voices")
        
        voiceMachine.allNotesOff()
    }
    
    func testParameterCaching() {
        // Test that parameter cache works correctly
        voiceMachine.setParameter("osc1_tuning", value: 7.0)
        voiceMachine.setParameter("osc2_level", value: 0.6)
        voiceMachine.setParameter("noise_level", value: 0.2)
        
        // Start a new voice - should inherit cached parameters
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        
        // Verify parameters were applied
        XCTAssertEqual(voiceMachine.getParameter("osc1_tuning"), 7.0, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("osc2_level"), 0.6, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.getParameter("noise_level"), 0.2, accuracy: 0.01)
        
        voiceMachine.allNotesOff()
    }
    
    // MARK: - Performance Tests
    
    func testPolyphonicPerformance() {
        // Test performance with full polyphony
        let notes: [UInt8] = [60, 62, 64, 65, 67, 69, 71, 72]
        
        measure {
            // Start all voices
            for note in notes {
                voiceMachine.noteOn(note: note, velocity: 100, channel: 0)
            }
            
            // Process many audio buffers
            for _ in 0..<100 {
                voiceMachine.processAudio(buffer: audioBuffer)
            }
            
            // Release all voices
            voiceMachine.allNotesOff()
        }
    }
    
    func testVoiceAllocationPerformance() {
        // Test rapid voice allocation/deallocation
        measure {
            for i in 0..<100 {
                let note = UInt8(60 + (i % 12))
                voiceMachine.noteOn(note: note, velocity: 100, channel: 0)
                voiceMachine.processAudio(buffer: audioBuffer)
                voiceMachine.noteOff(note: note, channel: 0)
                voiceMachine.processAudio(buffer: audioBuffer)
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testRapidNoteOnOff() {
        // Test rapid note on/off cycles
        for _ in 0..<50 {
            voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
            voiceMachine.noteOff(note: 60, channel: 0)
        }
        
        // Should handle rapid changes without issues
        let polyInfo = voiceMachine.getPolyphonyInfo()
        XCTAssertLessThanOrEqual(polyInfo.active, 8, "Should not exceed polyphony limit")
    }
    
    func testSameNoteMultipleTimes() {
        // Test playing the same note multiple times
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        
        let polyInfo = voiceMachine.getPolyphonyInfo()
        XCTAssertGreaterThan(polyInfo.active, 0, "Should have active voices")
        XCTAssertLessThanOrEqual(polyInfo.active, 8, "Should not exceed polyphony limit")
        
        voiceMachine.allNotesOff()
    }
    
    func testZeroPolyphony() {
        // Test with zero polyphony (edge case)
        let zeroPolyVoice = WavetoneVoiceMachine(name: "Zero Poly", polyphony: 0)
        
        zeroPolyVoice.noteOn(note: 60, velocity: 100, channel: 0)
        zeroPolyVoice.processAudio(buffer: audioBuffer)
        
        let polyInfo = zeroPolyVoice.getPolyphonyInfo()
        XCTAssertEqual(polyInfo.active, 0, "Should have no active voices with zero polyphony")
    }
    
    // MARK: - Audio Quality Tests
    
    func testAudioQualityWithPolyphony() {
        // Test audio quality with multiple voices
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        voiceMachine.noteOn(note: 64, velocity: 100, channel: 0)
        voiceMachine.noteOn(note: 67, velocity: 100, channel: 0)
        
        // Process audio and check for quality issues
        for _ in 0..<100 {
            voiceMachine.processAudio(buffer: audioBuffer)
            
            // Check for NaN or infinite values
            for channel in 0..<audioBuffer.channelCount {
                for frame in 0..<audioBuffer.frameCount {
                    let sample = audioBuffer.getSample(channel: channel, frame: frame)
                    XCTAssertFalse(sample.isNaN, "Audio should not contain NaN values")
                    XCTAssertFalse(sample.isInfinite, "Audio should not contain infinite values")
                }
            }
        }
        
        voiceMachine.allNotesOff()
    }
    
    func testSilenceWhenNoVoices() {
        // Test that output is silent when no voices are active
        voiceMachine.processAudio(buffer: audioBuffer)
        
        // Check for silence
        for channel in 0..<audioBuffer.channelCount {
            for frame in 0..<audioBuffer.frameCount {
                let sample = audioBuffer.getSample(channel: channel, frame: frame)
                XCTAssertEqual(sample, 0.0, accuracy: 0.001, "Output should be silent when no voices are active")
            }
        }
    }
}
