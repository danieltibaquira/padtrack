// FMDrumVoiceMachineTests.swift
// DigitonePad - Tests
//
// Unit tests for FM DRUM Voice Machine

import XCTest
@testable import VoiceModule
@testable import MachineProtocols
@testable import AudioEngine

final class FMDrumVoiceMachineTests: XCTestCase {
    
    var drumMachine: FMDrumVoiceMachine!
    
    override func setUpWithError() throws {
        drumMachine = FMDrumVoiceMachine(name: "Test FM DRUM", polyphony: 4)
    }
    
    override func tearDownWithError() throws {
        drumMachine = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() throws {
        XCTAssertEqual(drumMachine.name, "Test FM DRUM")
        XCTAssertEqual(drumMachine.polyphony, 4)
        XCTAssertTrue(drumMachine.isEnabled)
        XCTAssertEqual(drumMachine.activeVoices, 0)
    }
    
    func testParameterSetup() throws {
        let parameters = drumMachine.parameters.parameters
        
        // Check that all drum parameters are present
        XCTAssertNotNil(parameters["body_tone"])
        XCTAssertNotNil(parameters["noise_level"])
        XCTAssertNotNil(parameters["pitch_sweep_amount"])
        XCTAssertNotNil(parameters["pitch_sweep_time"])
        XCTAssertNotNil(parameters["wavefold_amount"])
        
        // Check parameter ranges
        XCTAssertEqual(parameters["body_tone"]?.minValue, 0.0)
        XCTAssertEqual(parameters["body_tone"]?.maxValue, 1.0)
        XCTAssertEqual(parameters["noise_level"]?.minValue, 0.0)
        XCTAssertEqual(parameters["noise_level"]?.maxValue, 1.0)
    }
    
    // MARK: - Note Handling Tests
    
    func testNoteOnOff() throws {
        // Test note on
        drumMachine.noteOn(note: 60, velocity: 100, channel: 0, timestamp: nil)
        XCTAssertEqual(drumMachine.activeVoices, 1)
        
        // Test note off
        drumMachine.noteOff(note: 60, velocity: 0, channel: 0, timestamp: nil)
        XCTAssertEqual(drumMachine.activeVoices, 0)
    }
    
    func testPolyphony() throws {
        // Test polyphonic behavior
        for note in 60..<64 {
            drumMachine.noteOn(note: UInt8(note), velocity: 100, channel: 0, timestamp: nil)
        }
        XCTAssertEqual(drumMachine.activeVoices, 4)
        
        // Test voice stealing (should still be 4 voices)
        drumMachine.noteOn(note: 64, velocity: 100, channel: 0, timestamp: nil)
        XCTAssertEqual(drumMachine.activeVoices, 4)
    }
    
    func testAllNotesOff() throws {
        // Trigger multiple notes
        for note in 60..<63 {
            drumMachine.noteOn(note: UInt8(note), velocity: 100, channel: 0, timestamp: nil)
        }
        XCTAssertEqual(drumMachine.activeVoices, 3)
        
        // Test all notes off
        drumMachine.allNotesOff()
        XCTAssertEqual(drumMachine.activeVoices, 0)
    }
    
    // MARK: - Audio Processing Tests
    
    func testAudioProcessing() throws {
        // Create test input buffer
        let frameCount = 512
        let channelCount = 2
        let sampleRate: Double = 44100.0
        
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount)
        inputData.initialize(repeating: 0.0, count: frameCount * channelCount)
        
        let inputBuffer = AudioEngine.AudioBuffer(
            data: inputData,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: sampleRate
        )
        
        // Trigger a note
        drumMachine.noteOn(note: 60, velocity: 100, channel: 0, timestamp: nil)
        
        // Process audio
        let outputBuffer = drumMachine.process(input: inputBuffer)
        
        // Verify output buffer properties
        XCTAssertEqual(outputBuffer.frameCount, frameCount)
        XCTAssertEqual(outputBuffer.channelCount, channelCount)
        XCTAssertEqual(outputBuffer.sampleRate, sampleRate)
        
        // Clean up
        inputData.deallocate()
    }
    
    // MARK: - Drum Type Tests
    
    func testDrumTypes() throws {
        // Test all drum types
        let drumTypes: [DrumType] = [.kick, .snare, .hihat, .tom, .cymbal]
        
        for drumType in drumTypes {
            drumMachine.setDrumType(drumType)
            
            // Verify that parameters are updated for each drum type
            // (This is a basic test - in practice you'd check specific parameter values)
            XCTAssertNotNil(drumMachine.parameters.getParameter(id: "body_tone"))
            XCTAssertNotNil(drumMachine.parameters.getParameter(id: "noise_level"))
        }
    }
    
    func testDrumTypeDisplayNames() throws {
        XCTAssertEqual(DrumType.kick.displayName, "Kick")
        XCTAssertEqual(DrumType.snare.displayName, "Snare")
        XCTAssertEqual(DrumType.hihat.displayName, "Hi-Hat")
        XCTAssertEqual(DrumType.tom.displayName, "Tom")
        XCTAssertEqual(DrumType.cymbal.displayName, "Cymbal")
    }
    
    // MARK: - Parameter Update Tests
    
    func testParameterUpdates() throws {
        // Test parameter updates through the parameter manager
        try drumMachine.parameters.updateParameter(id: "body_tone", value: 0.8)
        XCTAssertEqual(drumMachine.parameters.getParameterValue(id: "body_tone"), 0.8, accuracy: 0.001)
        
        try drumMachine.parameters.updateParameter(id: "noise_level", value: 0.6)
        XCTAssertEqual(drumMachine.parameters.getParameterValue(id: "noise_level"), 0.6, accuracy: 0.001)
        
        try drumMachine.parameters.updateParameter(id: "wavefold_amount", value: 0.4)
        XCTAssertEqual(drumMachine.parameters.getParameterValue(id: "wavefold_amount"), 0.4, accuracy: 0.001)
    }
    
    // MARK: - Performance Tests

    func testPerformance() throws {
        // Performance test for audio processing
        let frameCount = 512
        let channelCount = 2
        let sampleRate: Double = 44100.0

        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount)
        inputData.initialize(repeating: 0.0, count: frameCount * channelCount)

        let inputBuffer = AudioEngine.AudioBuffer(
            data: inputData,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: sampleRate
        )

        // Trigger multiple notes for stress test
        for note in 60..<64 {
            drumMachine.noteOn(note: UInt8(note), velocity: 100, channel: 0, timestamp: nil)
        }

        // Measure processing time
        measure {
            for _ in 0..<100 {
                _ = drumMachine.process(input: inputBuffer)
            }
        }

        // Clean up
        inputData.deallocate()
    }

    func testCPUUsageUnderLoad() throws {
        // Test CPU usage with maximum polyphony
        let frameCount = 512
        let channelCount = 2
        let sampleRate: Double = 44100.0

        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount)
        inputData.initialize(repeating: 0.0, count: frameCount * channelCount)

        let inputBuffer = AudioEngine.AudioBuffer(
            data: inputData,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: sampleRate
        )

        // Trigger maximum polyphony
        for note in 60..<68 {
            drumMachine.noteOn(note: UInt8(note), velocity: 100, channel: 0, timestamp: nil)
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let iterations = 1000

        for _ in 0..<iterations {
            _ = drumMachine.process(input: inputBuffer)
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        let averageTime = totalTime / Double(iterations)

        // Should process buffer in reasonable time (less than buffer duration)
        let bufferDuration = Double(frameCount) / sampleRate
        XCTAssertLessThan(averageTime, bufferDuration * 0.5, "Processing should be efficient")

        inputData.deallocate()
    }

    // MARK: - Edge Case Tests

    func testExtremeParameterValues() throws {
        // Test with extreme parameter values
        try drumMachine.parameters.updateParameter(id: "body_tone", value: 0.0)
        try drumMachine.parameters.updateParameter(id: "noise_level", value: 1.0)
        try drumMachine.parameters.updateParameter(id: "wavefold_amount", value: 1.0)
        try drumMachine.parameters.updateParameter(id: "pitch_sweep_amount", value: 1.0)
        try drumMachine.parameters.updateParameter(id: "pitch_sweep_time", value: 0.01)

        drumMachine.noteOn(note: 60, velocity: 127, channel: 0, timestamp: nil)

        let frameCount = 256
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * 2)
        inputData.initialize(repeating: 0.0, count: frameCount * 2)

        let inputBuffer = AudioEngine.AudioBuffer(
            data: inputData,
            frameCount: frameCount,
            channelCount: 2,
            sampleRate: 44100.0
        )

        let outputBuffer = drumMachine.process(input: inputBuffer)

        // Should not crash or produce invalid output
        for i in 0..<frameCount {
            XCTAssertFalse(outputBuffer.data[i].isNaN, "Output should not be NaN")
            XCTAssertFalse(outputBuffer.data[i].isInfinite, "Output should not be infinite")
        }

        inputData.deallocate()
    }

    func testRapidNoteTriggering() throws {
        // Test rapid note triggering (typical for drum patterns)
        let frameCount = 64
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * 2)
        inputData.initialize(repeating: 0.0, count: frameCount * 2)

        let inputBuffer = AudioEngine.AudioBuffer(
            data: inputData,
            frameCount: frameCount,
            channelCount: 2,
            sampleRate: 44100.0
        )

        for i in 0..<50 {
            drumMachine.noteOn(note: 60, velocity: 100, channel: 0, timestamp: nil)
            _ = drumMachine.process(input: inputBuffer)

            if i % 8 == 0 {
                drumMachine.allNotesOff()
            }
        }

        // Should handle rapid triggering without issues
        XCTAssertTrue(true, "Should complete without crashing")

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
            sampleRate: 44100.0
        )

        var outputs: [Float] = []

        for velocity in velocities {
            drumMachine.allNotesOff()
            drumMachine.noteOn(note: 60, velocity: velocity, channel: 0, timestamp: nil)

            let outputBuffer = drumMachine.process(input: inputBuffer)

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

    // MARK: - Audio Quality Tests

    func testOutputLevels() throws {
        // Test that output levels are within reasonable bounds
        let frameCount = 512
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * 2)
        inputData.initialize(repeating: 0.0, count: frameCount * 2)

        let inputBuffer = AudioEngine.AudioBuffer(
            data: inputData,
            frameCount: frameCount,
            channelCount: 2,
            sampleRate: 44100.0
        )

        drumMachine.noteOn(note: 60, velocity: 127, channel: 0, timestamp: nil)

        let outputBuffer = drumMachine.process(input: inputBuffer)

        // Check output levels are reasonable (not clipping, not silent)
        var maxLevel: Float = 0.0
        var hasOutput = false

        for i in 0..<frameCount {
            let sample = abs(outputBuffer.data[i])
            maxLevel = max(maxLevel, sample)
            if sample > 0.001 {
                hasOutput = true
            }
        }

        XCTAssertTrue(hasOutput, "Should produce audible output")
        XCTAssertLessThan(maxLevel, 2.0, "Output should not exceed reasonable levels")

        inputData.deallocate()
    }
}
