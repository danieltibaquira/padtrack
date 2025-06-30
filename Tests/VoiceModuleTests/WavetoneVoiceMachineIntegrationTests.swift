import XCTest
@testable import VoiceModule
@testable import MachineProtocols
@testable import AudioEngine

/// Integration tests for WAVETONE Voice Machine with oscillator modulation
final class WavetoneVoiceMachineIntegrationTests: XCTestCase {
    
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
    
    // MARK: - Basic Integration Tests
    
    func testVoiceMachineInitialization() {
        XCTAssertNotNil(voiceMachine)
        XCTAssertEqual(voiceMachine.voiceCount, 0)
        XCTAssertFalse(voiceMachine.isActive)
    }
    
    func testNoteOnOffCycle() {
        // Test basic note on/off functionality
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        XCTAssertEqual(voiceMachine.voiceCount, 1)
        XCTAssertTrue(voiceMachine.isActive)
        
        voiceMachine.noteOff(note: 60, channel: 0)
        // Voice should still be active during release phase
        XCTAssertTrue(voiceMachine.isActive)
    }
    
    func testAudioProcessing() {
        // Start a note
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        
        // Process audio buffer
        voiceMachine.processAudio(buffer: audioBuffer)
        
        // Check that audio was generated
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
        
        XCTAssertTrue(hasNonZeroSamples, "Voice machine should generate audio output")
    }
    
    // MARK: - Ring Modulation Integration Tests
    
    func testRingModulationIntegration() {
        // Configure ring modulation
        voiceMachine.setParameter("ring_mod_amount", value: 1.0)
        
        // Start a note
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        
        // Process audio with ring modulation
        voiceMachine.processAudio(buffer: audioBuffer)
        
        // Store ring modulated output
        var ringModBuffer = Array<Float>(repeating: 0.0, count: audioBuffer.frameCount)
        for frame in 0..<audioBuffer.frameCount {
            ringModBuffer[frame] = audioBuffer.getSample(channel: 0, frame: frame)
        }
        
        // Reset and test without ring modulation
        voiceMachine.allNotesOff()
        voiceMachine.setParameter("ring_mod_amount", value: 0.0)
        audioBuffer.clear()
        
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        voiceMachine.processAudio(buffer: audioBuffer)
        
        // Compare outputs - they should be different
        var outputsDiffer = false
        for frame in 0..<audioBuffer.frameCount {
            let dryOutput = audioBuffer.getSample(channel: 0, frame: frame)
            if abs(ringModBuffer[frame] - dryOutput) > 0.001 {
                outputsDiffer = true
                break
            }
        }
        
        XCTAssertTrue(outputsDiffer, "Ring modulation should change the audio output")
    }
    
    // MARK: - Hard Sync Integration Tests
    
    func testHardSyncIntegration() {
        // Enable hard sync
        voiceMachine.setParameter("hard_sync_enable", value: 1.0)
        
        // Set different oscillator frequencies for sync effect
        voiceMachine.setParameter("osc1_tuning", value: 0.0)   // Base frequency
        voiceMachine.setParameter("osc2_tuning", value: 7.0)   // Perfect fifth higher
        
        // Start a note
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        
        // Process audio with hard sync
        voiceMachine.processAudio(buffer: audioBuffer)
        
        // Store hard sync output
        var hardSyncBuffer = Array<Float>(repeating: 0.0, count: audioBuffer.frameCount)
        for frame in 0..<audioBuffer.frameCount {
            hardSyncBuffer[frame] = audioBuffer.getSample(channel: 0, frame: frame)
        }
        
        // Reset and test without hard sync
        voiceMachine.allNotesOff()
        voiceMachine.setParameter("hard_sync_enable", value: 0.0)
        audioBuffer.clear()
        
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        voiceMachine.processAudio(buffer: audioBuffer)
        
        // Compare outputs - they should be different
        var outputsDiffer = false
        for frame in 0..<audioBuffer.frameCount {
            let noSyncOutput = audioBuffer.getSample(channel: 0, frame: frame)
            if abs(hardSyncBuffer[frame] - noSyncOutput) > 0.001 {
                outputsDiffer = true
                break
            }
        }
        
        XCTAssertTrue(outputsDiffer, "Hard sync should change the audio output")
    }
    
    // MARK: - Modulation Matrix Integration Tests
    
    func testModulationMatrixIntegration() {
        // Test modulation matrix functionality
        voiceMachine.setParameter("mod_wheel", value: 0.8)
        
        // Start a note
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        
        // Process audio
        voiceMachine.processAudio(buffer: audioBuffer)
        
        // Verify that modulation wheel affects the output
        // (This is a basic test - more specific tests would require access to internal state)
        var hasOutput = false
        for frame in 0..<audioBuffer.frameCount {
            if abs(audioBuffer.getSample(channel: 0, frame: frame)) > 0.001 {
                hasOutput = true
                break
            }
        }
        
        XCTAssertTrue(hasOutput, "Voice machine should produce output with modulation")
    }
    
    // MARK: - Performance Integration Tests
    
    func testPolyphonicPerformance() {
        // Test performance with multiple voices
        let noteCount = 8
        
        measure {
            // Start multiple notes
            for i in 0..<noteCount {
                voiceMachine.noteOn(note: 60 + i, velocity: 100, channel: 0)
            }
            
            // Process audio buffers
            for _ in 0..<100 {  // Process 100 buffers
                voiceMachine.processAudio(buffer: audioBuffer)
            }
            
            // Stop all notes
            voiceMachine.allNotesOff()
        }
    }
    
    func testModulationPerformance() {
        // Test performance with heavy modulation
        voiceMachine.setParameter("ring_mod_amount", value: 1.0)
        voiceMachine.setParameter("hard_sync_enable", value: 1.0)
        voiceMachine.setParameter("osc1_phase_distortion", value: 0.8)
        voiceMachine.setParameter("osc2_phase_distortion", value: 0.6)
        
        measure {
            voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
            
            // Process many audio buffers with heavy modulation
            for _ in 0..<1000 {
                voiceMachine.processAudio(buffer: audioBuffer)
            }
            
            voiceMachine.allNotesOff()
        }
    }
    
    // MARK: - Edge Case Integration Tests
    
    func testExtremeParameterValues() {
        // Test with extreme parameter values
        voiceMachine.setParameter("ring_mod_amount", value: 10.0)  // Beyond normal range
        voiceMachine.setParameter("osc1_tuning", value: -24.0)     // Minimum tuning
        voiceMachine.setParameter("osc2_tuning", value: 24.0)      // Maximum tuning
        
        voiceMachine.noteOn(note: 60, velocity: 127, channel: 0)
        voiceMachine.processAudio(buffer: audioBuffer)
        
        // Should not crash or produce invalid audio
        var hasValidOutput = true
        for channel in 0..<audioBuffer.channelCount {
            for frame in 0..<audioBuffer.frameCount {
                let sample = audioBuffer.getSample(channel: channel, frame: frame)
                if sample.isNaN || sample.isInfinite {
                    hasValidOutput = false
                    break
                }
            }
            if !hasValidOutput { break }
        }
        
        XCTAssertTrue(hasValidOutput, "Voice machine should produce valid audio even with extreme parameters")
    }
    
    func testRapidParameterChanges() {
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        
        // Rapidly change parameters while processing audio
        for i in 0..<100 {
            let ringModAmount = Float(i % 2)  // Alternate between 0 and 1
            voiceMachine.setParameter("ring_mod_amount", value: ringModAmount)
            voiceMachine.processAudio(buffer: audioBuffer)
        }
        
        // Should complete without crashing
        XCTAssertTrue(voiceMachine.isActive)
    }
    
    // MARK: - Audio Quality Tests
    
    func testAudioOutputRange() {
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0)
        voiceMachine.processAudio(buffer: audioBuffer)
        
        // Check that audio output is within reasonable range
        for channel in 0..<audioBuffer.channelCount {
            for frame in 0..<audioBuffer.frameCount {
                let sample = audioBuffer.getSample(channel: channel, frame: frame)
                XCTAssertLessThanOrEqual(abs(sample), 1.0, "Audio output should not exceed ±1.0")
            }
        }
    }
    
    func testSilenceWhenNoNotes() {
        // Process audio without any active notes
        voiceMachine.processAudio(buffer: audioBuffer)
        
        // Output should be silent
        for channel in 0..<audioBuffer.channelCount {
            for frame in 0..<audioBuffer.frameCount {
                let sample = audioBuffer.getSample(channel: channel, frame: frame)
                XCTAssertEqual(sample, 0.0, accuracy: 0.001, "Output should be silent when no notes are active")
            }
        }
    }
}
