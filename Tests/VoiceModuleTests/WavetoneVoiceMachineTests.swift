// WavetoneVoiceMachineTests.swift
// DigitonePad - VoiceModuleTests
//
// Comprehensive test suite for WAVETONE Voice Machine

import XCTest
import AudioEngine
import MachineProtocols
@testable import VoiceModule

final class WavetoneVoiceMachineTests: XCTestCase {
    
    var wavetoneVoice: WavetoneVoiceMachine!
    let sampleRate: Double = 44100.0
    let bufferSize = 512
    
    override func setUp() {
        super.setUp()
        wavetoneVoice = WavetoneVoiceMachine(name: "Test WAVETONE", polyphony: 8)
    }
    
    override func tearDown() {
        wavetoneVoice = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialization() {
        XCTAssertNotNil(wavetoneVoice)
        XCTAssertEqual(wavetoneVoice.name, "Test WAVETONE")
        XCTAssertEqual(wavetoneVoice.polyphony, 8)
        XCTAssertFalse(wavetoneVoice.isActive)
    }
    
    func testNoteOnOff() {
        // Test note on
        wavetoneVoice.noteOn(note: 60, velocity: 100, channel: 0, timestamp: nil)
        XCTAssertTrue(wavetoneVoice.isActive)
        
        // Test note off
        wavetoneVoice.noteOff(note: 60, velocity: 64, channel: 0, timestamp: nil)
        // Note: Voice may remain active due to envelopes
    }
    
    func testAudioProcessing() {
        // Create test input buffer
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize * 2)
        inputData.initialize(repeating: 0.0, count: bufferSize * 2)
        
        let inputBuffer = AudioEngine.AudioBuffer(
            data: inputData,
            frameCount: bufferSize,
            channelCount: 2,
            sampleRate: sampleRate
        )
        
        // Trigger a note
        wavetoneVoice.noteOn(note: 60, velocity: 100, channel: 0, timestamp: nil)
        
        // Process audio
        let outputBuffer = wavetoneVoice.process(input: inputBuffer)
        
        XCTAssertEqual(outputBuffer.frameCount, bufferSize)
        XCTAssertEqual(outputBuffer.channelCount, 2)
        XCTAssertEqual(outputBuffer.sampleRate, sampleRate)
        
        // Check that we get non-zero output
        var hasNonZeroOutput = false
        for i in 0..<bufferSize {
            if outputBuffer.data[i] != 0.0 {
                hasNonZeroOutput = true
                break
            }
        }
        XCTAssertTrue(hasNonZeroOutput, "Should produce non-zero audio output")
        
        inputData.deallocate()
    }
    
    // MARK: - Oscillator Tests
    
    func testOscillatorTuning() {
        // Test oscillator 1 tuning
        try? wavetoneVoice.parameters.updateParameter(id: "osc1_tuning", value: 12.0) // +1 octave
        
        let tuningValue = wavetoneVoice.parameters.getParameterValue(id: "osc1_tuning")
        XCTAssertEqual(tuningValue, 12.0, accuracy: 0.01)
        
        // Test oscillator 2 tuning
        try? wavetoneVoice.parameters.updateParameter(id: "osc2_tuning", value: -12.0) // -1 octave
        
        let osc2TuningValue = wavetoneVoice.parameters.getParameterValue(id: "osc2_tuning")
        XCTAssertEqual(osc2TuningValue, -12.0, accuracy: 0.01)
    }
    
    func testWavetablePosition() {
        // Test wavetable position parameter
        try? wavetoneVoice.parameters.updateParameter(id: "osc1_wavetable_pos", value: 0.5)
        
        let wavetablePos = wavetoneVoice.parameters.getParameterValue(id: "osc1_wavetable_pos")
        XCTAssertEqual(wavetablePos, 0.5, accuracy: 0.01)
        
        // Test bounds
        try? wavetoneVoice.parameters.updateParameter(id: "osc1_wavetable_pos", value: 1.5)
        let clampedValue = wavetoneVoice.parameters.getParameterValue(id: "osc1_wavetable_pos")
        XCTAssertLessThanOrEqual(clampedValue, 1.0)
    }
    
    func testPhaseDistortion() {
        // Test phase distortion parameter
        try? wavetoneVoice.parameters.updateParameter(id: "osc1_phase_distortion", value: 0.7)
        
        let phaseDistortion = wavetoneVoice.parameters.getParameterValue(id: "osc1_phase_distortion")
        XCTAssertEqual(phaseDistortion, 0.7, accuracy: 0.01)
    }
    
    // MARK: - Modulation Tests
    
    func testRingModulation() {
        // Enable ring modulation
        try? wavetoneVoice.parameters.updateParameter(id: "ring_mod_amount", value: 0.8)
        
        let ringModAmount = wavetoneVoice.parameters.getParameterValue(id: "ring_mod_amount")
        XCTAssertEqual(ringModAmount, 0.8, accuracy: 0.01)
        
        // Test audio output with ring modulation
        wavetoneVoice.noteOn(note: 60, velocity: 100, channel: 0, timestamp: nil)
        
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: 256)
        inputData.initialize(repeating: 0.0, count: 256)
        
        let inputBuffer = AudioEngine.AudioBuffer(
            data: inputData,
            frameCount: 128,
            channelCount: 2,
            sampleRate: sampleRate
        )
        
        let outputBuffer = wavetoneVoice.process(input: inputBuffer)
        
        // Should produce output with ring modulation characteristics
        var hasOutput = false
        for i in 0..<128 {
            if outputBuffer.data[i] != 0.0 {
                hasOutput = true
                break
            }
        }
        XCTAssertTrue(hasOutput, "Should produce output with ring modulation")
        
        inputData.deallocate()
    }
    
    func testHardSync() {
        // Enable hard sync
        try? wavetoneVoice.parameters.updateParameter(id: "hard_sync_enable", value: 1.0)
        
        let hardSyncEnabled = wavetoneVoice.parameters.getParameterValue(id: "hard_sync_enable")
        XCTAssertEqual(hardSyncEnabled, 1.0, accuracy: 0.01)
        
        // Test audio output with hard sync
        wavetoneVoice.noteOn(note: 60, velocity: 100, channel: 0, timestamp: nil)
        
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: 256)
        inputData.initialize(repeating: 0.0, count: 256)
        
        let inputBuffer = AudioEngine.AudioBuffer(
            data: inputData,
            frameCount: 128,
            channelCount: 2,
            sampleRate: sampleRate
        )
        
        let outputBuffer = wavetoneVoice.process(input: inputBuffer)
        
        // Should produce output with hard sync characteristics
        var hasOutput = false
        for i in 0..<128 {
            if outputBuffer.data[i] != 0.0 {
                hasOutput = true
                break
            }
        }
        XCTAssertTrue(hasOutput, "Should produce output with hard sync")
        
        inputData.deallocate()
    }
    
    // MARK: - Noise Generator Tests
    
    func testNoiseGenerator() {
        // Test noise level parameter
        try? wavetoneVoice.parameters.updateParameter(id: "noise_level", value: 0.6)
        
        let noiseLevel = wavetoneVoice.parameters.getParameterValue(id: "noise_level")
        XCTAssertEqual(noiseLevel, 0.6, accuracy: 0.01)
        
        // Test audio output with noise
        wavetoneVoice.noteOn(note: 60, velocity: 100, channel: 0, timestamp: nil)
        
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: 256)
        inputData.initialize(repeating: 0.0, count: 256)
        
        let inputBuffer = AudioEngine.AudioBuffer(
            data: inputData,
            frameCount: 128,
            channelCount: 2,
            sampleRate: sampleRate
        )
        
        let outputBuffer = wavetoneVoice.process(input: inputBuffer)
        
        // Should produce output including noise
        var hasOutput = false
        for i in 0..<128 {
            if outputBuffer.data[i] != 0.0 {
                hasOutput = true
                break
            }
        }
        XCTAssertTrue(hasOutput, "Should produce output including noise")
        
        inputData.deallocate()
    }
    
    // MARK: - Performance Tests
    
    func testPerformance() throws {
        // Performance test for audio processing
        let frameCount = 512
        let channelCount = 2
        
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount)
        inputData.initialize(repeating: 0.0, count: frameCount * channelCount)
        
        let inputBuffer = AudioEngine.AudioBuffer(
            data: inputData,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: sampleRate
        )
        
        // Trigger note
        wavetoneVoice.noteOn(note: 60, velocity: 100, channel: 0, timestamp: nil)
        
        // Measure processing time
        measure {
            for _ in 0..<100 {
                _ = wavetoneVoice.process(input: inputBuffer)
            }
        }
        
        inputData.deallocate()
    }
    
    // MARK: - Edge Case Tests
    
    func testExtremeParameterValues() throws {
        // Test with extreme parameter values
        try wavetoneVoice.parameters.updateParameter(id: "osc1_tuning", value: 24.0)
        try wavetoneVoice.parameters.updateParameter(id: "osc2_tuning", value: -24.0)
        try wavetoneVoice.parameters.updateParameter(id: "ring_mod_amount", value: 1.0)
        try wavetoneVoice.parameters.updateParameter(id: "noise_level", value: 1.0)
        
        wavetoneVoice.noteOn(note: 60, velocity: 127, channel: 0, timestamp: nil)
        
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: 256)
        inputData.initialize(repeating: 0.0, count: 256)
        
        let inputBuffer = AudioEngine.AudioBuffer(
            data: inputData,
            frameCount: 128,
            channelCount: 2,
            sampleRate: sampleRate
        )
        
        let outputBuffer = wavetoneVoice.process(input: inputBuffer)
        
        // Should not crash or produce invalid output
        for i in 0..<128 {
            XCTAssertFalse(outputBuffer.data[i].isNaN, "Output should not be NaN")
            XCTAssertFalse(outputBuffer.data[i].isInfinite, "Output should not be infinite")
        }
        
        inputData.deallocate()
    }
    
    func testAllNotesOff() {
        // Trigger multiple notes
        wavetoneVoice.noteOn(note: 60, velocity: 100, channel: 0, timestamp: nil)
        wavetoneVoice.noteOn(note: 64, velocity: 100, channel: 0, timestamp: nil)
        
        // Stop all notes
        wavetoneVoice.allNotesOff()
        
        // Process some audio to let envelopes finish
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: 1024)
        inputData.initialize(repeating: 0.0, count: 1024)
        
        let inputBuffer = AudioEngine.AudioBuffer(
            data: inputData,
            frameCount: 512,
            channelCount: 2,
            sampleRate: sampleRate
        )
        
        for _ in 0..<10 {
            _ = wavetoneVoice.process(input: inputBuffer)
        }
        
        // Should eventually become inactive
        // Note: May take time for envelopes to complete
        
        inputData.deallocate()
    }
    
    func testVelocitySensitivity() throws {
        // Test velocity sensitivity across the range
        let velocities: [UInt8] = [1, 32, 64, 96, 127]
        let frameCount = 128
        
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * 2)
        inputData.initialize(repeating: 0.0, count: frameCount * 2)
        
        let inputBuffer = AudioEngine.AudioBuffer(
            data: inputData,
            frameCount: frameCount,
            channelCount: 2,
            sampleRate: sampleRate
        )
        
        var outputs: [Float] = []
        
        for velocity in velocities {
            wavetoneVoice.allNotesOff()
            wavetoneVoice.noteOn(note: 60, velocity: velocity, channel: 0, timestamp: nil)
            
            let outputBuffer = wavetoneVoice.process(input: inputBuffer)
            
            // Find peak output
            var peak: Float = 0.0
            for i in 0..<frameCount {
                peak = max(peak, abs(outputBuffer.data[i]))
            }
            outputs.append(peak)
        }
        
        // Higher velocities should generally produce higher output levels
        for i in 1..<outputs.count {
            XCTAssertGreaterThanOrEqual(outputs[i], outputs[i-1] * 0.8, 
                                       "Higher velocity should produce higher output")
        }
        
        inputData.deallocate()
    }
}
