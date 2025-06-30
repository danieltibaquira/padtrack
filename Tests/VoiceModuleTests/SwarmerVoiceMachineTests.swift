// SwarmerVoiceMachineTests.swift
// DigitonePad - VoiceModuleTests
//
// Comprehensive test suite for SWARMER Voice Machine

import XCTest
import AudioEngine
import MachineProtocols
@testable import VoiceModule

final class SwarmerVoiceMachineTests: XCTestCase {
    
    var swarmerVoice: SwarmerVoiceMachine!
    let sampleRate: Double = 44100.0
    let bufferSize = 512
    
    override func setUp() {
        super.setUp()
        swarmerVoice = SwarmerVoiceMachine(name: "Test SWARMER", polyphony: 8)
    }
    
    override func tearDown() {
        swarmerVoice = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialization() {
        XCTAssertNotNil(swarmerVoice)
        XCTAssertEqual(swarmerVoice.name, "Test SWARMER")
        XCTAssertEqual(swarmerVoice.polyphony, 8)
        XCTAssertFalse(swarmerVoice.isActive)
    }
    
    func testNoteOnOff() {
        // Test note on
        swarmerVoice.noteOn(note: 60, velocity: 100, channel: 0, timestamp: nil)
        XCTAssertTrue(swarmerVoice.isActive)
        
        // Test note off
        swarmerVoice.noteOff(note: 60, velocity: 64, channel: 0, timestamp: nil)
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
        swarmerVoice.noteOn(note: 60, velocity: 100, channel: 0, timestamp: nil)
        
        // Process audio
        let outputBuffer = swarmerVoice.process(input: inputBuffer)
        
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
    
    func testMainOscillatorWaveforms() {
        let waveforms: [SwarmerWaveform] = [.sine, .triangle, .sawtooth, .square, .pulse, .noise]
        
        for (index, waveform) in waveforms.enumerated() {
            try? swarmerVoice.parameters.updateParameter(id: "main_waveform", value: Float(index))
            
            let waveformValue = swarmerVoice.parameters.getParameterValue(id: "main_waveform")
            XCTAssertEqual(waveformValue, Float(index), accuracy: 0.01, "Should set main waveform to \(waveform)")
        }
    }
    
    func testSwarmOscillatorWaveforms() {
        let waveforms: [SwarmerWaveform] = [.sine, .triangle, .sawtooth, .square, .pulse, .noise]
        
        for (index, waveform) in waveforms.enumerated() {
            try? swarmerVoice.parameters.updateParameter(id: "swarm_waveform", value: Float(index))
            
            let waveformValue = swarmerVoice.parameters.getParameterValue(id: "swarm_waveform")
            XCTAssertEqual(waveformValue, Float(index), accuracy: 0.01, "Should set swarm waveform to \(waveform)")
        }
    }
    
    func testTuning() {
        // Test tuning parameter
        try? swarmerVoice.parameters.updateParameter(id: "tune", value: 12.0) // +1 octave
        
        let tuningValue = swarmerVoice.parameters.getParameterValue(id: "tune")
        XCTAssertEqual(tuningValue, 12.0, accuracy: 0.01)
        
        // Test negative tuning
        try? swarmerVoice.parameters.updateParameter(id: "tune", value: -12.0) // -1 octave
        
        let negativeTuningValue = swarmerVoice.parameters.getParameterValue(id: "tune")
        XCTAssertEqual(negativeTuningValue, -12.0, accuracy: 0.01)
    }
    
    func testMainOctave() {
        // Test main octave parameter
        try? swarmerVoice.parameters.updateParameter(id: "main_octave", value: 1.0)
        
        let octaveValue = swarmerVoice.parameters.getParameterValue(id: "main_octave")
        XCTAssertEqual(octaveValue, 1.0, accuracy: 0.01)
        
        // Test bounds
        try? swarmerVoice.parameters.updateParameter(id: "main_octave", value: 3.0)
        let clampedValue = swarmerVoice.parameters.getParameterValue(id: "main_octave")
        XCTAssertLessThanOrEqual(clampedValue, 2.0)
    }
    
    // MARK: - Swarm Tests
    
    func testDetuneAmount() {
        // Test detune parameter
        try? swarmerVoice.parameters.updateParameter(id: "detune_amount", value: 50.0)
        
        let detuneValue = swarmerVoice.parameters.getParameterValue(id: "detune_amount")
        XCTAssertEqual(detuneValue, 50.0, accuracy: 0.01)
        
        // Test audio output with detune
        swarmerVoice.noteOn(note: 60, velocity: 100, channel: 0, timestamp: nil)
        
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: 256)
        inputData.initialize(repeating: 0.0, count: 256)
        
        let inputBuffer = AudioEngine.AudioBuffer(
            data: inputData,
            frameCount: 128,
            channelCount: 2,
            sampleRate: sampleRate
        )
        
        let outputBuffer = swarmerVoice.process(input: inputBuffer)
        
        // Should produce output with detune characteristics
        var hasOutput = false
        for i in 0..<128 {
            if outputBuffer.data[i] != 0.0 {
                hasOutput = true
                break
            }
        }
        XCTAssertTrue(hasOutput, "Should produce output with detune")
        
        inputData.deallocate()
    }
    
    func testSwarmMix() {
        // Test swarm mix parameter
        try? swarmerVoice.parameters.updateParameter(id: "swarm_mix", value: 0.8)
        
        let mixValue = swarmerVoice.parameters.getParameterValue(id: "swarm_mix")
        XCTAssertEqual(mixValue, 0.8, accuracy: 0.01)
        
        // Test extreme values
        try? swarmerVoice.parameters.updateParameter(id: "swarm_mix", value: 0.0)
        let minMixValue = swarmerVoice.parameters.getParameterValue(id: "swarm_mix")
        XCTAssertEqual(minMixValue, 0.0, accuracy: 0.01)
        
        try? swarmerVoice.parameters.updateParameter(id: "swarm_mix", value: 1.0)
        let maxMixValue = swarmerVoice.parameters.getParameterValue(id: "swarm_mix")
        XCTAssertEqual(maxMixValue, 1.0, accuracy: 0.01)
    }
    
    func testAnimation() {
        // Test animation amount
        try? swarmerVoice.parameters.updateParameter(id: "animation_amount", value: 0.7)
        
        let animationAmount = swarmerVoice.parameters.getParameterValue(id: "animation_amount")
        XCTAssertEqual(animationAmount, 0.7, accuracy: 0.01)
        
        // Test animation rate
        try? swarmerVoice.parameters.updateParameter(id: "animation_rate", value: 5.0)
        
        let animationRate = swarmerVoice.parameters.getParameterValue(id: "animation_rate")
        XCTAssertEqual(animationRate, 5.0, accuracy: 0.01)
        
        // Test audio output with animation
        swarmerVoice.noteOn(note: 60, velocity: 100, channel: 0, timestamp: nil)
        
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: 1024)
        inputData.initialize(repeating: 0.0, count: 1024)
        
        let inputBuffer = AudioEngine.AudioBuffer(
            data: inputData,
            frameCount: 512,
            channelCount: 2,
            sampleRate: sampleRate
        )
        
        let outputBuffer = swarmerVoice.process(input: inputBuffer)
        
        // Should produce output with animation
        var hasOutput = false
        for i in 0..<512 {
            if outputBuffer.data[i] != 0.0 {
                hasOutput = true
                break
            }
        }
        XCTAssertTrue(hasOutput, "Should produce output with animation")
        
        inputData.deallocate()
    }
    
    func testSpread() {
        // Test spread parameter
        try? swarmerVoice.parameters.updateParameter(id: "spread", value: 0.8)
        
        let spreadValue = swarmerVoice.parameters.getParameterValue(id: "spread")
        XCTAssertEqual(spreadValue, 0.8, accuracy: 0.01)
    }
    
    // MARK: - Preset Tests
    
    func testPresetCreation() {
        let presetTypes: [SwarmerPresetType] = [.lush, .wide, .subtle, .aggressive, .organic]
        
        for presetType in presetTypes {
            let preset = SwarmerVoiceMachine.createPreset(type: presetType)
            
            // Verify preset contains expected parameters
            XCTAssertNotNil(preset["detune_amount"], "Preset \(presetType) should have detune_amount")
            XCTAssertNotNil(preset["swarm_mix"], "Preset \(presetType) should have swarm_mix")
            XCTAssertNotNil(preset["animation_amount"], "Preset \(presetType) should have animation_amount")
            XCTAssertNotNil(preset["animation_rate"], "Preset \(presetType) should have animation_rate")
            
            // Verify parameter values are within valid ranges
            if let detuneAmount = preset["detune_amount"] {
                XCTAssertGreaterThanOrEqual(detuneAmount, 0.0, "Detune amount should be non-negative")
                XCTAssertLessThanOrEqual(detuneAmount, 100.0, "Detune amount should not exceed maximum")
            }
            
            if let swarmMix = preset["swarm_mix"] {
                XCTAssertGreaterThanOrEqual(swarmMix, 0.0, "Swarm mix should be non-negative")
                XCTAssertLessThanOrEqual(swarmMix, 1.0, "Swarm mix should not exceed 1.0")
            }
        }
    }
    
    func testPresetApplication() {
        let lushPreset = SwarmerVoiceMachine.createPreset(type: .lush)
        
        // Apply preset
        swarmerVoice.applyPreset(lushPreset)
        
        // Verify parameters were set
        if let expectedDetune = lushPreset["detune_amount"] {
            let actualDetune = swarmerVoice.parameters.getParameterValue(id: "detune_amount")
            XCTAssertEqual(actualDetune, expectedDetune, accuracy: 0.01, "Should apply detune amount from preset")
        }
        
        if let expectedMix = lushPreset["swarm_mix"] {
            let actualMix = swarmerVoice.parameters.getParameterValue(id: "swarm_mix")
            XCTAssertEqual(actualMix, expectedMix, accuracy: 0.01, "Should apply swarm mix from preset")
        }
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
        swarmerVoice.noteOn(note: 60, velocity: 100, channel: 0, timestamp: nil)
        
        // Measure processing time
        measure {
            for _ in 0..<100 {
                _ = swarmerVoice.process(input: inputBuffer)
            }
        }
        
        inputData.deallocate()
    }
    
    // MARK: - Edge Case Tests
    
    func testExtremeParameterValues() throws {
        // Test with extreme parameter values
        try swarmerVoice.parameters.updateParameter(id: "tune", value: 24.0)
        try swarmerVoice.parameters.updateParameter(id: "detune_amount", value: 100.0)
        try swarmerVoice.parameters.updateParameter(id: "animation_amount", value: 1.0)
        try swarmerVoice.parameters.updateParameter(id: "animation_rate", value: 20.0)
        try swarmerVoice.parameters.updateParameter(id: "swarm_mix", value: 1.0)
        
        swarmerVoice.noteOn(note: 60, velocity: 127, channel: 0, timestamp: nil)
        
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: 256)
        inputData.initialize(repeating: 0.0, count: 256)
        
        let inputBuffer = AudioEngine.AudioBuffer(
            data: inputData,
            frameCount: 128,
            channelCount: 2,
            sampleRate: sampleRate
        )
        
        let outputBuffer = swarmerVoice.process(input: inputBuffer)
        
        // Should not crash or produce invalid output
        for i in 0..<128 {
            XCTAssertFalse(outputBuffer.data[i].isNaN, "Output should not be NaN")
            XCTAssertFalse(outputBuffer.data[i].isInfinite, "Output should not be infinite")
        }
        
        inputData.deallocate()
    }
    
    func testAllNotesOff() {
        // Trigger multiple notes
        swarmerVoice.noteOn(note: 60, velocity: 100, channel: 0, timestamp: nil)
        swarmerVoice.noteOn(note: 64, velocity: 100, channel: 0, timestamp: nil)
        
        // Stop all notes
        swarmerVoice.allNotesOff()
        
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
            _ = swarmerVoice.process(input: inputBuffer)
        }
        
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
            swarmerVoice.allNotesOff()
            swarmerVoice.noteOn(note: 60, velocity: velocity, channel: 0, timestamp: nil)
            
            let outputBuffer = swarmerVoice.process(input: inputBuffer)
            
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
