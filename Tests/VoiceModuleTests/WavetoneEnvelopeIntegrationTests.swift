import XCTest
@testable import VoiceModule
@testable import MachineProtocols
@testable import AudioEngine

/// Integration tests for WAVETONE Voice Machine envelope system
final class WavetoneEnvelopeIntegrationTests: XCTestCase {
    
    var voiceMachine: WavetoneVoiceMachine!
    var audioBuffer: AudioBuffer!
    
    override func setUp() {
        super.setUp()
        
        // Initialize voice machine
        voiceMachine = WavetoneVoiceMachine()
        
        // Initialize audio buffer for testing
        let bufferSize = 512
        audioBuffer = AudioBuffer(channelCount: 2, frameCount: bufferSize)
    }
    
    override func tearDown() {
        voiceMachine = nil
        audioBuffer = nil
        super.tearDown()
    }
    
    // MARK: - Basic Envelope Integration Tests
    
    func testEnvelopeSystemInitialization() {
        XCTAssertNotNil(voiceMachine)
        // Voice machine should have envelope system initialized
        // We can't directly access it, but we can test through parameters
        
        // Test that envelope parameters exist
        voiceMachine.setParameter("amp_attack", value: 0.5)
        voiceMachine.setParameter("amp_decay", value: 0.3)
        voiceMachine.setParameter("amp_sustain", value: 0.7)
        voiceMachine.setParameter("amp_release", value: 1.0)
        
        // Should not crash
        XCTAssertTrue(true)
    }
    
    func testEnvelopeNoteOnOffCycle() {
        // Start a note
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        
        // Process some audio to let envelope start
        for _ in 0..<10 {
            voiceMachine.processAudio(buffer: audioBuffer)
        }
        
        // Check that audio is being generated
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
        
        XCTAssertTrue(hasNonZeroSamples, "Should generate audio during attack phase")
        
        // Release the note
        voiceMachine.noteOff(note: 60, channel: 0)
        
        // Process more audio during release
        for _ in 0..<10 {
            voiceMachine.processAudio(buffer: audioBuffer)
        }
        
        // Should still have some audio during release
        hasNonZeroSamples = false
        for channel in 0..<audioBuffer.channelCount {
            for frame in 0..<audioBuffer.frameCount {
                if abs(audioBuffer.getSample(channel: channel, frame: frame)) > 0.001 {
                    hasNonZeroSamples = true
                    break
                }
            }
            if hasNonZeroSamples { break }
        }
        
        XCTAssertTrue(hasNonZeroSamples, "Should still generate audio during release phase")
    }
    
    // MARK: - Envelope Parameter Tests
    
    func testAmplitudeEnvelopeParameters() {
        // Test attack parameter
        voiceMachine.setParameter("amp_attack", value: 0.1)
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        
        // Process audio and check for gradual amplitude increase
        var previousLevel: Float = 0.0
        var attackDetected = false
        
        for _ in 0..<20 {
            voiceMachine.processAudio(buffer: audioBuffer)
            
            // Get average level of this buffer
            var bufferLevel: Float = 0.0
            for frame in 0..<audioBuffer.frameCount {
                bufferLevel += abs(audioBuffer.getSample(channel: 0, frame: frame))
            }
            bufferLevel /= Float(audioBuffer.frameCount)
            
            if bufferLevel > previousLevel {
                attackDetected = true
            }
            previousLevel = bufferLevel
        }
        
        XCTAssertTrue(attackDetected, "Should detect amplitude increase during attack")
        
        voiceMachine.allNotesOff()
    }
    
    func testSustainLevel() {
        // Set specific sustain level
        voiceMachine.setParameter("amp_sustain", value: 0.5)
        voiceMachine.setParameter("amp_attack", value: 0.001)  // Very fast attack
        voiceMachine.setParameter("amp_decay", value: 0.001)   // Very fast decay
        
        voiceMachine.noteOn(note: 60, velocity: 127, channel: 0)  // Full velocity
        
        // Process enough audio to reach sustain phase
        for _ in 0..<50 {
            voiceMachine.processAudio(buffer: audioBuffer)
        }
        
        // Check that we're in sustain phase with appropriate level
        var sustainLevel: Float = 0.0
        for frame in 0..<audioBuffer.frameCount {
            sustainLevel += abs(audioBuffer.getSample(channel: 0, frame: frame))
        }
        sustainLevel /= Float(audioBuffer.frameCount)
        
        // Should be at sustain level (approximately 50% of full level)
        XCTAssertGreaterThan(sustainLevel, 0.1, "Should have significant sustain level")
        XCTAssertLessThan(sustainLevel, 0.8, "Should not be at full level during sustain")
        
        voiceMachine.allNotesOff()
    }
    
    func testReleasePhase() {
        // Set up envelope with long release
        voiceMachine.setParameter("amp_release", value: 0.5)
        voiceMachine.setParameter("amp_attack", value: 0.001)
        voiceMachine.setParameter("amp_decay", value: 0.001)
        voiceMachine.setParameter("amp_sustain", value: 0.8)
        
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        
        // Let envelope reach sustain
        for _ in 0..<20 {
            voiceMachine.processAudio(buffer: audioBuffer)
        }
        
        // Get sustain level
        var sustainLevel: Float = 0.0
        for frame in 0..<audioBuffer.frameCount {
            sustainLevel += abs(audioBuffer.getSample(channel: 0, frame: frame))
        }
        sustainLevel /= Float(audioBuffer.frameCount)
        
        // Release note
        voiceMachine.noteOff(note: 60, channel: 0)
        
        // Process some release audio
        for _ in 0..<10 {
            voiceMachine.processAudio(buffer: audioBuffer)
        }
        
        // Get release level
        var releaseLevel: Float = 0.0
        for frame in 0..<audioBuffer.frameCount {
            releaseLevel += abs(audioBuffer.getSample(channel: 0, frame: frame))
        }
        releaseLevel /= Float(audioBuffer.frameCount)
        
        // Release level should be lower than sustain level
        XCTAssertLessThan(releaseLevel, sustainLevel, "Release level should be lower than sustain")
        XCTAssertGreaterThan(releaseLevel, 0.001, "Should still have some level during release")
    }
    
    // MARK: - Velocity Sensitivity Tests
    
    func testVelocitySensitivity() {
        voiceMachine.setParameter("amp_attack", value: 0.001)
        voiceMachine.setParameter("amp_decay", value: 0.001)
        voiceMachine.setParameter("amp_sustain", value: 1.0)
        
        // Test low velocity
        voiceMachine.noteOn(note: 60, velocity: 32, channel: 0)  // 25% velocity
        
        for _ in 0..<20 {
            voiceMachine.processAudio(buffer: audioBuffer)
        }
        
        var lowVelocityLevel: Float = 0.0
        for frame in 0..<audioBuffer.frameCount {
            lowVelocityLevel += abs(audioBuffer.getSample(channel: 0, frame: frame))
        }
        lowVelocityLevel /= Float(audioBuffer.frameCount)
        
        voiceMachine.allNotesOff()
        audioBuffer.clear()
        
        // Test high velocity
        voiceMachine.noteOn(note: 60, velocity: 127, channel: 0)  // 100% velocity
        
        for _ in 0..<20 {
            voiceMachine.processAudio(buffer: audioBuffer)
        }
        
        var highVelocityLevel: Float = 0.0
        for frame in 0..<audioBuffer.frameCount {
            highVelocityLevel += abs(audioBuffer.getSample(channel: 0, frame: frame))
        }
        highVelocityLevel /= Float(audioBuffer.frameCount)
        
        // High velocity should produce higher amplitude
        XCTAssertGreaterThan(highVelocityLevel, lowVelocityLevel, "High velocity should produce higher amplitude")
        
        voiceMachine.allNotesOff()
    }
    
    // MARK: - Performance Tests
    
    func testEnvelopePerformance() {
        // Test performance with envelope processing
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        
        measure {
            for _ in 0..<100 {
                voiceMachine.processAudio(buffer: audioBuffer)
            }
        }
        
        voiceMachine.allNotesOff()
    }
    
    func testMultipleNotesWithEnvelopes() {
        // Test performance with multiple overlapping notes
        let noteCount = 4
        
        measure {
            // Start multiple notes
            for i in 0..<noteCount {
                voiceMachine.noteOn(note: 60 + UInt8(i), velocity: 100, channel: 0)
            }
            
            // Process audio
            for _ in 0..<50 {
                voiceMachine.processAudio(buffer: audioBuffer)
            }
            
            // Release notes
            for i in 0..<noteCount {
                voiceMachine.noteOff(note: 60 + UInt8(i), channel: 0)
            }
            
            // Process release
            for _ in 0..<50 {
                voiceMachine.processAudio(buffer: audioBuffer)
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testExtremeEnvelopeParameters() {
        // Test with extreme parameter values
        voiceMachine.setParameter("amp_attack", value: 0.001)   // Minimum attack
        voiceMachine.setParameter("amp_decay", value: 10.0)     // Maximum decay
        voiceMachine.setParameter("amp_sustain", value: 0.0)    // Zero sustain
        voiceMachine.setParameter("amp_release", value: 10.0)   // Maximum release
        
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        
        // Should not crash with extreme parameters
        for _ in 0..<100 {
            voiceMachine.processAudio(buffer: audioBuffer)
        }
        
        voiceMachine.noteOff(note: 60, channel: 0)
        
        for _ in 0..<100 {
            voiceMachine.processAudio(buffer: audioBuffer)
        }
        
        // Should complete without crashing
        XCTAssertTrue(true)
        
        voiceMachine.allNotesOff()
    }
    
    func testRapidNoteOnOff() {
        // Test rapid note on/off cycles
        for _ in 0..<10 {
            voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
            voiceMachine.processAudio(buffer: audioBuffer)
            voiceMachine.noteOff(note: 60, channel: 0)
            voiceMachine.processAudio(buffer: audioBuffer)
        }
        
        // Should handle rapid changes without issues
        XCTAssertTrue(true)
    }
    
    // MARK: - Audio Quality Tests
    
    func testEnvelopeAudioQuality() {
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        
        // Process audio and check for quality issues
        for _ in 0..<100 {
            voiceMachine.processAudio(buffer: audioBuffer)
            
            // Check for NaN or infinite values
            for channel in 0..<audioBuffer.channelCount {
                for frame in 0..<audioBuffer.frameCount {
                    let sample = audioBuffer.getSample(channel: channel, frame: frame)
                    XCTAssertFalse(sample.isNaN, "Audio should not contain NaN values")
                    XCTAssertFalse(sample.isInfinite, "Audio should not contain infinite values")
                    XCTAssertLessThanOrEqual(abs(sample), 1.0, "Audio should not exceed ±1.0")
                }
            }
        }
        
        voiceMachine.allNotesOff()
    }
}
