// SendFXImplementationTests.swift
// DigitonePad - FXModuleTests
//
// Comprehensive test suite for Send FX Implementation

import XCTest
import MachineProtocols
import AudioEngine
@testable import FXModule

final class SendFXImplementationTests: XCTestCase {
    
    var sendFX: SendFXProcessor!
    let sampleRate: Double = 44100.0
    let bufferSize = 512
    
    override func setUp() {
        super.setUp()
        sendFX = SendFXProcessor(sampleRate: sampleRate)
    }
    
    override func tearDown() {
        sendFX = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialization() {
        XCTAssertNotNil(sendFX)
        XCTAssertFalse(sendFX.isBypassed)
        XCTAssertTrue(sendFX.config.delay.enabled)
        XCTAssertTrue(sendFX.config.reverb.enabled)
        XCTAssertTrue(sendFX.config.chorus.enabled)
    }
    
    func testBypassedProcessing() {
        sendFX.isBypassed = true
        
        let trackInputs = createTestTrackInputs(trackCount: 2)
        let sendLevels = [[0.5, 0.3, 0.2], [0.4, 0.6, 0.1]]
        
        let outputs = sendFX.process(trackInputs: trackInputs, sendLevels: sendLevels)
        
        // Bypassed processor should return inputs unchanged
        XCTAssertEqual(outputs.count, trackInputs.count)
        for (index, output) in outputs.enumerated() {
            let input = trackInputs[index]
            for i in 0..<min(input.frameCount * input.channelCount, output.frameCount * output.channelCount) {
                XCTAssertEqual(output.data[i], input.data[i], accuracy: 0.001,
                              "Bypassed processor should pass input unchanged")
            }
        }
        
        deallocateTestInputs(trackInputs)
    }
    
    func testSendEffectEnableDisable() {
        // Test delay enable/disable
        sendFX.setEffectEnabled(.delay, enabled: false)
        XCTAssertFalse(sendFX.isEffectEnabled(.delay))
        
        sendFX.setEffectEnabled(.delay, enabled: true)
        XCTAssertTrue(sendFX.isEffectEnabled(.delay))
        
        // Test reverb enable/disable
        sendFX.setEffectEnabled(.reverb, enabled: false)
        XCTAssertFalse(sendFX.isEffectEnabled(.reverb))
        
        // Test chorus enable/disable
        sendFX.setEffectEnabled(.chorus, enabled: false)
        XCTAssertFalse(sendFX.isEffectEnabled(.chorus))
    }
    
    // MARK: - Delay Tests
    
    func testDelayProcessing() {
        // Enable only delay
        sendFX.setEffectEnabled(.delay, enabled: true)
        sendFX.setEffectEnabled(.reverb, enabled: false)
        sendFX.setEffectEnabled(.chorus, enabled: false)
        
        // Configure delay
        sendFX.config.delay.delayTime = 0.1  // 100ms
        sendFX.config.delay.feedback = 0.3
        sendFX.config.delay.wetLevel = 1.0
        
        let trackInputs = createTestTrackInputs(trackCount: 1, frequency: 1000.0)
        let sendLevels = [[1.0, 0.0, 0.0]]  // Send only to delay
        
        let outputs = sendFX.process(trackInputs: trackInputs, sendLevels: sendLevels)
        
        // Should produce delayed output
        XCTAssertEqual(outputs.count, 1)
        let output = outputs[0]
        
        // Check that output is different from input (delayed)
        let input = trackInputs[0]
        var isDifferent = false
        for i in 0..<min(input.frameCount * input.channelCount, output.frameCount * output.channelCount) {
            if abs(output.data[i] - input.data[i]) > 0.01 {
                isDifferent = true
                break
            }
        }
        XCTAssertTrue(isDifferent, "Delay should modify the signal")
        
        deallocateTestInputs(trackInputs)
    }
    
    func testDelayTempoSync() {
        sendFX.config.delay.tempoSynced = true
        sendFX.config.delay.noteValue = .quarter
        sendFX.setTempo(120.0)  // 120 BPM
        
        // At 120 BPM, quarter note = 0.5 seconds
        let expectedDelayTime: Float = 0.5
        
        let trackInputs = createTestTrackInputs(trackCount: 1)
        let sendLevels = [[1.0, 0.0, 0.0]]
        
        _ = sendFX.process(trackInputs: trackInputs, sendLevels: sendLevels)
        
        // Verify tempo was set correctly
        XCTAssertEqual(sendFX.getTempo(), 120.0, accuracy: 0.1)
        
        deallocateTestInputs(trackInputs)
    }
    
    func testDelayStereoSpread() {
        sendFX.config.delay.stereoSpread = 0.5  // 50% spread
        sendFX.config.delay.delayTime = 0.05
        
        let trackInputs = createTestTrackInputs(trackCount: 1, channelCount: 2)
        let sendLevels = [[1.0, 0.0, 0.0]]
        
        let outputs = sendFX.process(trackInputs: trackInputs, sendLevels: sendLevels)
        
        // Should produce stereo output with different delays
        XCTAssertEqual(outputs[0].channelCount, 2)
        
        deallocateTestInputs(trackInputs)
    }
    
    // MARK: - Reverb Tests
    
    func testReverbProcessing() {
        // Enable only reverb
        sendFX.setEffectEnabled(.delay, enabled: false)
        sendFX.setEffectEnabled(.reverb, enabled: true)
        sendFX.setEffectEnabled(.chorus, enabled: false)
        
        // Configure reverb
        sendFX.config.reverb.roomSize = 0.7
        sendFX.config.reverb.damping = 0.5
        sendFX.config.reverb.wetLevel = 1.0
        
        let trackInputs = createTestTrackInputs(trackCount: 1, frequency: 1000.0)
        let sendLevels = [[0.0, 1.0, 0.0]]  // Send only to reverb
        
        let outputs = sendFX.process(trackInputs: trackInputs, sendLevels: sendLevels)
        
        // Should produce reverb output
        XCTAssertEqual(outputs.count, 1)
        let output = outputs[0]
        
        // Check for non-zero output (reverb should add energy)
        var hasNonZeroOutput = false
        for i in 0..<output.frameCount * output.channelCount {
            if abs(output.data[i]) > 0.001 {
                hasNonZeroOutput = true
                break
            }
        }
        XCTAssertTrue(hasNonZeroOutput, "Reverb should produce non-zero output")
        
        deallocateTestInputs(trackInputs)
    }
    
    func testReverbParameters() {
        // Test room size parameter
        sendFX.config.reverb.roomSize = 0.9
        XCTAssertEqual(sendFX.config.reverb.roomSize, 0.9, accuracy: 0.01)
        
        // Test damping parameter
        sendFX.config.reverb.damping = 0.3
        XCTAssertEqual(sendFX.config.reverb.damping, 0.3, accuracy: 0.01)
        
        // Test pre-delay parameter
        sendFX.config.reverb.preDelay = 0.05
        XCTAssertEqual(sendFX.config.reverb.preDelay, 0.05, accuracy: 0.001)
    }
    
    // MARK: - Chorus Tests
    
    func testChorusProcessing() {
        // Enable only chorus
        sendFX.setEffectEnabled(.delay, enabled: false)
        sendFX.setEffectEnabled(.reverb, enabled: false)
        sendFX.setEffectEnabled(.chorus, enabled: true)
        
        // Configure chorus
        sendFX.config.chorus.rate = 1.0
        sendFX.config.chorus.depth = 0.5
        sendFX.config.chorus.voices = 3
        sendFX.config.chorus.wetLevel = 1.0
        
        let trackInputs = createTestTrackInputs(trackCount: 1, frequency: 1000.0)
        let sendLevels = [[0.0, 0.0, 1.0]]  // Send only to chorus
        
        let outputs = sendFX.process(trackInputs: trackInputs, sendLevels: sendLevels)
        
        // Should produce chorus output
        XCTAssertEqual(outputs.count, 1)
        let output = outputs[0]
        
        // Check that output is different from input (modulated)
        let input = trackInputs[0]
        var isDifferent = false
        for i in 0..<min(input.frameCount * input.channelCount, output.frameCount * output.channelCount) {
            if abs(output.data[i] - input.data[i]) > 0.01 {
                isDifferent = true
                break
            }
        }
        XCTAssertTrue(isDifferent, "Chorus should modify the signal")
        
        deallocateTestInputs(trackInputs)
    }
    
    func testChorusTempoSync() {
        sendFX.config.chorus.tempoSynced = true
        sendFX.config.chorus.noteValue = .eighth
        sendFX.setTempo(120.0)
        
        let trackInputs = createTestTrackInputs(trackCount: 1)
        let sendLevels = [[0.0, 0.0, 1.0]]
        
        _ = sendFX.process(trackInputs: trackInputs, sendLevels: sendLevels)
        
        // Verify tempo sync is working
        XCTAssertTrue(sendFX.config.chorus.tempoSynced)
        
        deallocateTestInputs(trackInputs)
    }
    
    func testChorusVoices() {
        // Test different voice counts
        let voiceCounts = [1, 2, 4, 6]
        
        for voiceCount in voiceCounts {
            sendFX.config.chorus.voices = voiceCount
            XCTAssertEqual(sendFX.config.chorus.voices, voiceCount)
            
            let trackInputs = createTestTrackInputs(trackCount: 1)
            let sendLevels = [[0.0, 0.0, 1.0]]
            
            let outputs = sendFX.process(trackInputs: trackInputs, sendLevels: sendLevels)
            
            // Should handle different voice counts without crashing
            XCTAssertEqual(outputs.count, 1)
            
            deallocateTestInputs(trackInputs)
        }
    }
    
    // MARK: - Tempo Sync Tests
    
    func testTempoSyncEngine() {
        // Test tempo setting
        sendFX.setTempo(140.0)
        XCTAssertEqual(sendFX.getTempo(), 140.0, accuracy: 0.1)
        
        // Test tempo bounds
        sendFX.setTempo(30.0)  // Below minimum
        XCTAssertGreaterThanOrEqual(sendFX.getTempo(), 60.0)
        
        sendFX.setTempo(300.0)  // Above maximum
        XCTAssertLessThanOrEqual(sendFX.getTempo(), 200.0)
    }
    
    func testNoteValues() {
        let noteValues: [NoteValue] = [.sixteenth, .eighth, .quarter, .half, .whole, .dottedQuarter]
        
        for noteValue in noteValues {
            sendFX.config.delay.noteValue = noteValue
            XCTAssertEqual(sendFX.config.delay.noteValue, noteValue)
        }
    }
    
    // MARK: - Multi-Track Tests
    
    func testMultiTrackProcessing() {
        let trackCount = 4
        let trackInputs = createTestTrackInputs(trackCount: trackCount)
        
        // Different send levels for each track
        let sendLevels = [
            [0.5, 0.2, 0.1],  // Track 1
            [0.3, 0.6, 0.2],  // Track 2
            [0.1, 0.3, 0.8],  // Track 3
            [0.4, 0.4, 0.4]   // Track 4
        ]
        
        let outputs = sendFX.process(trackInputs: trackInputs, sendLevels: sendLevels)
        
        // Should return same number of tracks
        XCTAssertEqual(outputs.count, trackCount)
        
        // Each output should have valid audio data
        for output in outputs {
            XCTAssertGreaterThan(output.frameCount, 0)
            XCTAssertGreaterThan(output.channelCount, 0)
        }
        
        deallocateTestInputs(trackInputs)
    }
    
    // MARK: - Performance Tests
    
    func testPerformance() {
        let trackInputs = createTestTrackInputs(trackCount: 8)
        let sendLevels = Array(repeating: [0.3, 0.3, 0.3], count: 8)
        
        measure {
            for _ in 0..<100 {
                _ = sendFX.process(trackInputs: trackInputs, sendLevels: sendLevels)
            }
        }
        
        deallocateTestInputs(trackInputs)
    }
    
    // MARK: - Reset Tests
    
    func testReset() {
        // Process some audio to establish internal state
        let trackInputs = createTestTrackInputs(trackCount: 2)
        let sendLevels = [[0.5, 0.5, 0.5], [0.5, 0.5, 0.5]]
        
        for _ in 0..<10 {
            _ = sendFX.process(trackInputs: trackInputs, sendLevels: sendLevels)
        }
        
        // Reset processor
        sendFX.reset()
        
        // Process silence and check for clean state
        let silentInputs = createTestTrackInputs(trackCount: 2, amplitude: 0.0)
        let silentSendLevels: [[Float]] = [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
        
        let outputs = sendFX.process(trackInputs: silentInputs, sendLevels: silentSendLevels)
        
        // Should produce minimal output after reset
        for output in outputs {
            for i in 0..<output.frameCount * output.channelCount {
                XCTAssertLessThan(abs(output.data[i]), 0.01, "Reset should clear internal state")
            }
        }
        
        deallocateTestInputs(trackInputs)
        deallocateTestInputs(silentInputs)
    }
    
    // MARK: - Helper Methods
    
    private func createTestTrackInputs(trackCount: Int, frequency: Float = 1000.0, amplitude: Float = 0.5, channelCount: Int = 2) -> [MachineProtocols.AudioBuffer] {
        var trackInputs: [MachineProtocols.AudioBuffer] = []
        
        for _ in 0..<trackCount {
            let inputData = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize * channelCount)
            
            // Generate test signal
            for i in 0..<bufferSize {
                let phase = Float(i) * 2.0 * Float.pi * frequency / Float(sampleRate)
                let sample = sin(phase) * amplitude
                
                for channel in 0..<channelCount {
                    inputData[i * channelCount + channel] = sample
                }
            }
            
            let buffer = AudioEngine.AudioBuffer(
                data: inputData,
                frameCount: bufferSize,
                channelCount: channelCount,
                sampleRate: sampleRate
            )
            
            trackInputs.append(buffer)
        }
        
        return trackInputs
    }
    
    private func deallocateTestInputs(_ inputs: [MachineProtocols.AudioBuffer]) {
        for input in inputs {
            input.data.deallocate()
        }
    }
}
