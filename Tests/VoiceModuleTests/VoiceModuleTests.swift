import XCTest
@testable import VoiceModule
@testable import MachineProtocols

final class VoiceModuleTests: XCTestCase {

    // MARK: - FM Operator Tests

    func testFMOperatorInitialization() {
        let fmOperator = FMOperator(sampleRate: 44100.0)

        XCTAssertEqual(fmOperator.frequency, 440.0)
        XCTAssertEqual(fmOperator.amplitude, 1.0)
        XCTAssertEqual(fmOperator.phase, 0.0)
        XCTAssertEqual(fmOperator.modulationIndex, 0.0)
        XCTAssertEqual(fmOperator.feedbackAmount, 0.0)
    }

    func testFMOperatorFrequencyUpdate() {
        let fmOperator = FMOperator(sampleRate: 44100.0)

        fmOperator.setFrequency(880.0)
        XCTAssertEqual(fmOperator.frequency, 880.0)

        // Phase increment should be updated
        let expectedPhaseIncrement = 880.0 * 2.0 * Double.pi / 44100.0
        XCTAssertEqual(fmOperator.phaseIncrement, expectedPhaseIncrement, accuracy: 0.0001)
    }

    func testFMOperatorSampleProcessing() {
        let fmOperator = FMOperator(sampleRate: 44100.0)
        fmOperator.setFrequency(440.0)

        // Process a few samples
        let sample1 = fmOperator.processSample()
        let sample2 = fmOperator.processSample()

        // Samples should be different (sine wave progression)
        XCTAssertNotEqual(sample1, sample2)

        // Output should be within expected range
        XCTAssertTrue(abs(sample1) <= 1.0)
        XCTAssertTrue(abs(sample2) <= 1.0)
    }

    func testFMOperatorReset() {
        let fmOperator = FMOperator(sampleRate: 44100.0)

        // Process some samples to change state
        _ = fmOperator.processSample()
        _ = fmOperator.processSample()

        // Reset should restore initial state
        fmOperator.reset()
        XCTAssertEqual(fmOperator.phase, 0.0)
    }

    // MARK: - FM Voice Tests

    func testFMVoiceInitialization() {
        let voice = FMVoice(sampleRate: 44100.0)

        XCTAssertEqual(voice.note, 60)
        XCTAssertEqual(voice.velocity, 100)
        XCTAssertFalse(voice.isActive)
        XCTAssertEqual(voice.operatorRatios.count, 4)
        XCTAssertEqual(voice.operatorLevels.count, 4)
    }

    func testFMVoiceNoteOnOff() {
        let voice = FMVoice(sampleRate: 44100.0)

        // Test note on
        voice.noteOn(note: 69, velocity: 127) // A4
        XCTAssertEqual(voice.note, 69)
        XCTAssertEqual(voice.velocity, 127)
        XCTAssertTrue(voice.isActive)

        // Test note off
        voice.noteOff()
        XCTAssertFalse(voice.isActive)
    }

    func testFMVoiceSampleProcessing() {
        let voice = FMVoice(sampleRate: 44100.0)

        // Inactive voice should output silence
        let silentSample = voice.processSample()
        XCTAssertEqual(silentSample, 0.0)

        // Active voice should produce audio
        voice.noteOn(note: 69, velocity: 127)
        let activeSample = voice.processSample()
        XCTAssertNotEqual(activeSample, 0.0)
    }

    // MARK: - FM Synthesis Engine Tests

    func testFMSynthesisEngineInitialization() {
        let engine = FMSynthesisEngine(sampleRate: 44100.0, maxPolyphony: 8)

        XCTAssertEqual(engine.polyphonyUsage, 0)
        XCTAssertFalse(engine.isActive)
        XCTAssertEqual(engine.masterVolume, 1.0)
    }

    func testFMSynthesisEngineNoteHandling() {
        let engine = FMSynthesisEngine(sampleRate: 44100.0, maxPolyphony: 8)

        // Test note on
        let success = engine.noteOn(note: 60, velocity: 100)
        XCTAssertTrue(success)
        XCTAssertEqual(engine.polyphonyUsage, 1)
        XCTAssertTrue(engine.isActive)

        // Test note off
        engine.noteOff(note: 60)
        XCTAssertEqual(engine.polyphonyUsage, 0)
        XCTAssertFalse(engine.isActive)
    }

    func testFMSynthesisEnginePolyphony() {
        let engine = FMSynthesisEngine(sampleRate: 44100.0, maxPolyphony: 4)

        // Fill up polyphony
        for note in 60..<64 {
            let success = engine.noteOn(note: UInt8(note), velocity: 100)
            XCTAssertTrue(success)
        }

        XCTAssertEqual(engine.polyphonyUsage, 4)

        // Try to exceed polyphony (should trigger voice stealing)
        let success = engine.noteOn(note: 64, velocity: 100)
        XCTAssertTrue(success) // Should succeed due to voice stealing
        XCTAssertEqual(engine.polyphonyUsage, 4) // Should still be at max
    }

    func testFMSynthesisEngineBufferProcessing() {
        let engine = FMSynthesisEngine(sampleRate: 44100.0, maxPolyphony: 8)

        // Start a note
        _ = engine.noteOn(note: 60, velocity: 100)

        // Process a buffer
        let frameCount = 256
        let output = engine.processBuffer(frameCount: frameCount)

        XCTAssertEqual(output.count, frameCount)

        // Should have non-zero output
        let hasNonZeroSamples = output.contains { abs($0) > 0.001 }
        XCTAssertTrue(hasNonZeroSamples)
    }

    // MARK: - Algorithm Tests

    func testFMAlgorithms() {
        // Test that all algorithms are properly defined
        XCTAssertEqual(FMAlgorithms.algorithm1.id, 1)
        XCTAssertEqual(FMAlgorithms.algorithm2.id, 2)
        XCTAssertEqual(FMAlgorithms.algorithm3.id, 3)
        XCTAssertEqual(FMAlgorithms.algorithm4.id, 4)

        XCTAssertEqual(FMAlgorithms.allAlgorithms.count, 4)

        // Test algorithm connections
        XCTAssertEqual(FMAlgorithms.algorithm1.connections.count, 1)
        XCTAssertEqual(FMAlgorithms.algorithm2.connections.count, 2)
        XCTAssertEqual(FMAlgorithms.algorithm3.connections.count, 3)
        XCTAssertEqual(FMAlgorithms.algorithm4.connections.count, 3)
    }
}