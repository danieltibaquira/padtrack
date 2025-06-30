import XCTest
@testable import SequencerModule
@testable import MachineProtocols

// Import test utilities and mocks
import TestUtilities
import MockObjects

/// Tests for Sequencer business logic (Interactor layer)
final class SequencerInteractorTests: DigitonePadTestCase {
    
    var sequencerInteractor: SequencerInteractor!
    var mockSequencer: MockSequencer!
    var mockPresenter: MockSequencerPresenter!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        mockSequencer = MockSequencer()
        mockPresenter = MockSequencerPresenter()
        sequencerInteractor = SequencerInteractor(
            sequencer: mockSequencer,
            presenter: mockPresenter
        )
        
        try mockSequencer.initialize()
    }
    
    override func tearDownWithError() throws {
        sequencerInteractor = nil
        mockSequencer = nil
        mockPresenter = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Sequencer Lifecycle Tests
    
    func testStartSequencerSuccess() throws {
        // GIVEN: Initialized sequencer
        
        // WHEN: Starting sequencer
        try sequencerInteractor.startSequencer()
        
        // THEN: Sequencer should be running
        XCTAssertTrue(mockSequencer.isRunning)
        XCTAssertTrue(mockPresenter.wasSequencerStartedCalled)
    }
    
    func testStartSequencerNotInitialized() throws {
        // GIVEN: Uninitialized sequencer
        mockSequencer.shutdown()
        
        // WHEN & THEN: Starting should fail
        XCTAssertThrowsError(try sequencerInteractor.startSequencer())
        XCTAssertTrue(mockPresenter.wasErrorPresentedCalled)
    }
    
    func testStopSequencer() throws {
        // GIVEN: Running sequencer
        try mockSequencer.start()
        
        // WHEN: Stopping sequencer
        try sequencerInteractor.stopSequencer()
        
        // THEN: Sequencer should be stopped
        XCTAssertFalse(mockSequencer.isRunning)
        XCTAssertEqual(mockSequencer.currentStep, 0)
        XCTAssertTrue(mockPresenter.wasSequencerStoppedCalled)
    }
    
    func testPauseResumeSequencer() throws {
        // GIVEN: Running sequencer
        try mockSequencer.start()
        
        // WHEN: Pausing sequencer
        try sequencerInteractor.pauseSequencer()
        
        // THEN: Sequencer should be paused
        XCTAssertFalse(mockSequencer.isRunning)
        XCTAssertTrue(mockPresenter.wasSequencerPausedCalled)
        
        // WHEN: Resuming sequencer
        try sequencerInteractor.resumeSequencer()
        
        // THEN: Sequencer should be running again
        XCTAssertTrue(mockSequencer.isRunning)
        XCTAssertTrue(mockPresenter.wasSequencerResumedCalled)
    }
    
    // MARK: - BPM Management Tests
    
    func testSetBPMValid() throws {
        // GIVEN: Valid BPM values
        let validBPMs: [Float] = [60.0, 120.0, 140.0, 180.0, 200.0]
        
        for bpm in validBPMs {
            // WHEN: Setting BPM
            try sequencerInteractor.setBPM(bpm)
            
            // THEN: BPM should be set
            XCTAssertEqual(mockSequencer.bpm, bpm)
            XCTAssertTrue(mockPresenter.wasBPMChangedCalled)
        }
    }
    
    func testSetBPMInvalid() throws {
        // GIVEN: Invalid BPM values
        let invalidBPMs: [Float] = [30.0, 300.0, 0.0, -10.0]
        
        for bpm in invalidBPMs {
            // WHEN & THEN: Setting invalid BPM should fail
            XCTAssertThrowsError(try sequencerInteractor.setBPM(bpm)) { error in
                XCTAssertTrue(error is SequencerInteractorError)
            }
        }
    }
    
    // MARK: - Pattern Management Tests
    
    func testCreatePatternSuccess() throws {
        // GIVEN: Valid pattern parameters
        let patternName = "Test Pattern"
        let patternLength = 16
        
        // WHEN: Creating pattern
        let pattern = try sequencerInteractor.createPattern(name: patternName, length: patternLength)
        
        // THEN: Pattern should be created
        XCTAssertEqual(pattern.name, patternName)
        XCTAssertEqual(pattern.length, patternLength)
        XCTAssertTrue(mockPresenter.wasPatternCreatedCalled)
    }
    
    func testCreatePatternInvalidName() throws {
        // GIVEN: Invalid pattern name
        let invalidName = ""
        
        // WHEN & THEN: Creating pattern should fail
        XCTAssertThrowsError(try sequencerInteractor.createPattern(name: invalidName, length: 16)) { error in
            XCTAssertTrue(error is SequencerInteractorError)
        }
    }
    
    func testCreatePatternInvalidLength() throws {
        // GIVEN: Invalid pattern length
        let invalidLengths = [0, -1, 129] // 0, negative, too long
        
        for length in invalidLengths {
            // WHEN & THEN: Creating pattern should fail
            XCTAssertThrowsError(try sequencerInteractor.createPattern(name: "Test", length: length)) { error in
                XCTAssertTrue(error is SequencerInteractorError)
            }
        }
    }
    
    func testLoadPatternSuccess() throws {
        // GIVEN: Existing pattern
        let pattern = mockSequencer.createPattern(name: "Test Pattern", length: 16)
        
        // WHEN: Loading pattern
        try sequencerInteractor.loadPattern(pattern)
        
        // THEN: Pattern should be loaded
        XCTAssertEqual(mockSequencer.currentPattern?.id, pattern.id)
        XCTAssertTrue(mockPresenter.wasPatternLoadedCalled)
    }
    
    func testDeletePatternSuccess() throws {
        // GIVEN: Existing pattern
        let pattern = mockSequencer.createPattern(name: "To Delete", length: 16)
        
        // WHEN: Deleting pattern
        try sequencerInteractor.deletePattern(pattern)
        
        // THEN: Pattern should be deleted
        XCTAssertFalse(mockSequencer.patterns.contains { $0.id == pattern.id })
        XCTAssertTrue(mockPresenter.wasPatternDeletedCalled)
    }
    
    // MARK: - Step Management Tests
    
    func testSetStepEnabled() throws {
        // GIVEN: Pattern loaded
        let pattern = mockSequencer.createPattern(name: "Test Pattern", length: 16)
        try mockSequencer.loadPattern(pattern)
        
        // WHEN: Enabling step
        try sequencerInteractor.setStep(index: 0, enabled: true)
        
        // THEN: Step should be enabled
        let step = try mockSequencer.getStep(0)
        XCTAssertTrue(step.isEnabled)
        XCTAssertTrue(mockPresenter.wasStepChangedCalled)
    }
    
    func testSetStepDisabled() throws {
        // GIVEN: Pattern with enabled step
        let pattern = mockSequencer.createPattern(name: "Test Pattern", length: 16)
        try mockSequencer.loadPattern(pattern)
        try mockSequencer.setStep(0, enabled: true)
        
        // WHEN: Disabling step
        try sequencerInteractor.setStep(index: 0, enabled: false)
        
        // THEN: Step should be disabled
        let step = try mockSequencer.getStep(0)
        XCTAssertFalse(step.isEnabled)
    }
    
    func testSetStepInvalidIndex() throws {
        // GIVEN: Pattern loaded
        let pattern = mockSequencer.createPattern(name: "Test Pattern", length: 16)
        try mockSequencer.loadPattern(pattern)
        
        // WHEN & THEN: Setting invalid step index should fail
        XCTAssertThrowsError(try sequencerInteractor.setStep(index: 16, enabled: true)) // Out of bounds
        XCTAssertThrowsError(try sequencerInteractor.setStep(index: -1, enabled: true)) // Negative
    }
    
    func testSetStepNoPatternLoaded() throws {
        // GIVEN: No pattern loaded
        
        // WHEN & THEN: Setting step should fail
        XCTAssertThrowsError(try sequencerInteractor.setStep(index: 0, enabled: true)) { error in
            XCTAssertTrue(error is SequencerError)
        }
    }
    
    // MARK: - Recording Tests
    
    func testStartRecordingStep() throws {
        // GIVEN: Pattern loaded
        let pattern = mockSequencer.createPattern(name: "Test Pattern", length: 16)
        try mockSequencer.loadPattern(pattern)
        
        // WHEN: Starting step recording
        try sequencerInteractor.startRecording(mode: .step)
        
        // THEN: Recording should be active
        XCTAssertTrue(mockSequencer.isRecording)
        XCTAssertEqual(mockSequencer.recordingMode, .step)
        XCTAssertTrue(mockPresenter.wasRecordingStartedCalled)
    }
    
    func testStartRecordingLive() throws {
        // GIVEN: Pattern loaded
        let pattern = mockSequencer.createPattern(name: "Test Pattern", length: 16)
        try mockSequencer.loadPattern(pattern)
        
        // WHEN: Starting live recording
        try sequencerInteractor.startRecording(mode: .live)
        
        // THEN: Recording should be active
        XCTAssertTrue(mockSequencer.isRecording)
        XCTAssertEqual(mockSequencer.recordingMode, .live)
    }
    
    func testStopRecording() throws {
        // GIVEN: Active recording
        let pattern = mockSequencer.createPattern(name: "Test Pattern", length: 16)
        try mockSequencer.loadPattern(pattern)
        try mockSequencer.startRecording(mode: .step)
        
        // WHEN: Stopping recording
        try sequencerInteractor.stopRecording()
        
        // THEN: Recording should be stopped
        XCTAssertFalse(mockSequencer.isRecording)
        XCTAssertTrue(mockPresenter.wasRecordingStoppedCalled)
    }
    
    // MARK: - Validation Tests
    
    func testValidateBPM() throws {
        // Test valid BPM values
        XCTAssertNoThrow(try sequencerInteractor.validateBPM(60.0))
        XCTAssertNoThrow(try sequencerInteractor.validateBPM(120.0))
        XCTAssertNoThrow(try sequencerInteractor.validateBPM(200.0))
        
        // Test invalid BPM values
        XCTAssertThrowsError(try sequencerInteractor.validateBPM(30.0)) // Too low
        XCTAssertThrowsError(try sequencerInteractor.validateBPM(300.0)) // Too high
        XCTAssertThrowsError(try sequencerInteractor.validateBPM(0.0))
        XCTAssertThrowsError(try sequencerInteractor.validateBPM(-10.0))
    }
    
    func testValidatePatternName() throws {
        // Test valid names
        XCTAssertNoThrow(try sequencerInteractor.validatePatternName("Valid Pattern"))
        XCTAssertNoThrow(try sequencerInteractor.validatePatternName("Pattern 123"))
        
        // Test invalid names
        XCTAssertThrowsError(try sequencerInteractor.validatePatternName(""))
        XCTAssertThrowsError(try sequencerInteractor.validatePatternName("   "))
        XCTAssertThrowsError(try sequencerInteractor.validatePatternName(String(repeating: "a", count: 256)))
    }
    
    func testValidatePatternLength() throws {
        // Test valid lengths
        XCTAssertNoThrow(try sequencerInteractor.validatePatternLength(16))
        XCTAssertNoThrow(try sequencerInteractor.validatePatternLength(32))
        XCTAssertNoThrow(try sequencerInteractor.validatePatternLength(64))
        
        // Test invalid lengths
        XCTAssertThrowsError(try sequencerInteractor.validatePatternLength(0))
        XCTAssertThrowsError(try sequencerInteractor.validatePatternLength(-1))
        XCTAssertThrowsError(try sequencerInteractor.validatePatternLength(129)) // Too long
    }
    
    // MARK: - Error Handling Tests
    
    func testSequencerFailureHandling() throws {
        // GIVEN: Sequencer configured to fail
        mockSequencer.setShouldFailOperations(true)
        
        // WHEN & THEN: Operations should handle failures gracefully
        XCTAssertThrowsError(try sequencerInteractor.startSequencer())
        XCTAssertTrue(mockPresenter.wasErrorPresentedCalled)
        
        XCTAssertThrowsError(try sequencerInteractor.stopSequencer())
        XCTAssertThrowsError(try sequencerInteractor.pauseSequencer())
    }
    
    // MARK: - Performance Tests
    
    func testStepManipulationPerformance() throws {
        // GIVEN: Pattern loaded
        let pattern = mockSequencer.createPattern(name: "Performance Test", length: 64)
        try mockSequencer.loadPattern(pattern)
        
        // WHEN & THEN: Step manipulation should be performant
        measure {
            for i in 0..<64 {
                do {
                    try sequencerInteractor.setStep(index: i, enabled: i % 2 == 0)
                } catch {
                    XCTFail("Step manipulation failed: \(error)")
                }
            }
        }
    }
    
    func testPatternCreationPerformance() throws {
        measure {
            for i in 0..<100 {
                do {
                    _ = try sequencerInteractor.createPattern(name: "Pattern \(i)", length: 16)
                } catch {
                    XCTFail("Pattern creation failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Mock Sequencer Presenter

class MockSequencerPresenter {
    var wasSequencerStartedCalled = false
    var wasSequencerStoppedCalled = false
    var wasSequencerPausedCalled = false
    var wasSequencerResumedCalled = false
    var wasBPMChangedCalled = false
    var wasPatternCreatedCalled = false
    var wasPatternLoadedCalled = false
    var wasPatternDeletedCalled = false
    var wasStepChangedCalled = false
    var wasRecordingStartedCalled = false
    var wasRecordingStoppedCalled = false
    var wasErrorPresentedCalled = false
    
    var lastError: Error?
    var lastBPM: Float?
    var lastPattern: MockPattern?
    
    func presentSequencerStarted() {
        wasSequencerStartedCalled = true
    }
    
    func presentSequencerStopped() {
        wasSequencerStoppedCalled = true
    }
    
    func presentSequencerPaused() {
        wasSequencerPausedCalled = true
    }
    
    func presentSequencerResumed() {
        wasSequencerResumedCalled = true
    }
    
    func presentBPMChanged(_ bpm: Float) {
        wasBPMChangedCalled = true
        lastBPM = bpm
    }
    
    func presentPatternCreated(_ pattern: MockPattern) {
        wasPatternCreatedCalled = true
        lastPattern = pattern
    }
    
    func presentPatternLoaded(_ pattern: MockPattern) {
        wasPatternLoadedCalled = true
        lastPattern = pattern
    }
    
    func presentPatternDeleted(_ pattern: MockPattern) {
        wasPatternDeletedCalled = true
        lastPattern = pattern
    }
    
    func presentStepChanged(_ index: Int, _ enabled: Bool) {
        wasStepChangedCalled = true
    }
    
    func presentRecordingStarted(_ mode: RecordingMode) {
        wasRecordingStartedCalled = true
    }
    
    func presentRecordingStopped() {
        wasRecordingStoppedCalled = true
    }
    
    func presentError(_ error: Error) {
        wasErrorPresentedCalled = true
        lastError = error
    }
}

// MARK: - Sequencer Interactor Implementation

class SequencerInteractor {
    private let sequencer: MockSequencer
    private let presenter: MockSequencerPresenter
    
    init(sequencer: MockSequencer, presenter: MockSequencerPresenter) {
        self.sequencer = sequencer
        self.presenter = presenter
    }
    
    func startSequencer() throws {
        do {
            try sequencer.start()
            presenter.presentSequencerStarted()
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func stopSequencer() throws {
        do {
            try sequencer.stop()
            presenter.presentSequencerStopped()
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func pauseSequencer() throws {
        do {
            try sequencer.pause()
            presenter.presentSequencerPaused()
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func resumeSequencer() throws {
        do {
            try sequencer.resume()
            presenter.presentSequencerResumed()
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func setBPM(_ bpm: Float) throws {
        do {
            try validateBPM(bpm)
            sequencer.bpm = bpm
            presenter.presentBPMChanged(bpm)
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func createPattern(name: String, length: Int) throws -> MockPattern {
        do {
            try validatePatternName(name)
            try validatePatternLength(length)
            
            let pattern = sequencer.createPattern(name: name, length: length)
            presenter.presentPatternCreated(pattern)
            return pattern
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func loadPattern(_ pattern: MockPattern) throws {
        do {
            try sequencer.loadPattern(pattern)
            presenter.presentPatternLoaded(pattern)
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func deletePattern(_ pattern: MockPattern) throws {
        do {
            try sequencer.deletePattern(pattern)
            presenter.presentPatternDeleted(pattern)
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func setStep(index: Int, enabled: Bool) throws {
        do {
            try sequencer.setStep(index, enabled: enabled)
            presenter.presentStepChanged(index, enabled)
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func startRecording(mode: RecordingMode) throws {
        do {
            try sequencer.startRecording(mode: mode)
            presenter.presentRecordingStarted(mode)
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func stopRecording() throws {
        do {
            try sequencer.stopRecording()
            presenter.presentRecordingStopped()
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    // MARK: - Validation Methods
    
    func validateBPM(_ bpm: Float) throws {
        if bpm < 40.0 || bpm > 250.0 {
            throw SequencerInteractorError.invalidBPM("BPM must be between 40 and 250")
        }
    }
    
    func validatePatternName(_ name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            throw SequencerInteractorError.invalidPatternName("Pattern name cannot be empty")
        }
        
        if trimmedName.count > 255 {
            throw SequencerInteractorError.invalidPatternName("Pattern name too long")
        }
    }
    
    func validatePatternLength(_ length: Int) throws {
        if length <= 0 || length > 128 {
            throw SequencerInteractorError.invalidPatternLength("Pattern length must be between 1 and 128")
        }
    }
}

// MARK: - Sequencer Interactor Errors

enum SequencerInteractorError: Error, LocalizedError {
    case invalidBPM(String)
    case invalidPatternName(String)
    case invalidPatternLength(String)
    case sequencerNotReady(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidBPM(let message):
            return "Invalid BPM: \(message)"
        case .invalidPatternName(let message):
            return "Invalid pattern name: \(message)"
        case .invalidPatternLength(let message):
            return "Invalid pattern length: \(message)"
        case .sequencerNotReady(let message):
            return "Sequencer not ready: \(message)"
        }
    }
}
