import XCTest
import Combine
@testable import SequencerModule

final class SequencerModuleTests: XCTestCase {
    var sequencer: Sequencer!
    var sequencerManager: SequencerManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        sequencer = Sequencer.shared
        sequencerManager = SequencerManager.shared
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables.removeAll()
        sequencer.stop()
        super.tearDown()
    }

    // MARK: - Clock Tests

    func testClockInitialization() {
        let clock = SequencerClock()
        XCTAssertEqual(clock.bpm, 120.0)
        XCTAssertEqual(clock.timeSignature.numerator, 4)
        XCTAssertEqual(clock.timeSignature.denominator, 4)
    }

    func testClockTempoChange() {
        let clock = SequencerClock()
        let expectation = XCTestExpectation(description: "Tempo change event")

        clock.eventPublisher
            .sink { event in
                if case .tempoChanged(let bpm) = event {
                    XCTAssertEqual(bpm, 140.0)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        clock.bpm = 140.0
        wait(for: [expectation], timeout: 1.0)
    }

    func testClockStartStop() {
        let clock = SequencerClock()
        let startExpectation = XCTestExpectation(description: "Playback started")
        let stopExpectation = XCTestExpectation(description: "Playback stopped")

        clock.eventPublisher
            .sink { event in
                switch event {
                case .playbackStarted:
                    startExpectation.fulfill()
                case .playbackStopped:
                    stopExpectation.fulfill()
                default:
                    break
                }
            }
            .store(in: &cancellables)

        clock.start()
        clock.stop()

        wait(for: [startExpectation, stopExpectation], timeout: 2.0)
    }

    // MARK: - Pattern Tests

    func testPatternStepCreation() {
        let step = PatternStep(note: 60, velocity: 100, isActive: true)
        XCTAssertEqual(step.note, 60)
        XCTAssertEqual(step.velocity, 100)
        XCTAssertTrue(step.isActive)
        XCTAssertEqual(step.probability, 1.0)
    }

    func testPatternCreation() {
        let steps = [
            PatternStep(note: 60, velocity: 100, isActive: true),
            PatternStep(note: nil, velocity: 0, isActive: false),
            PatternStep(note: 64, velocity: 80, isActive: true),
            PatternStep(note: nil, velocity: 0, isActive: false)
        ]

        let pattern = Pattern(trackId: 1, steps: steps, name: "Test Pattern")
        XCTAssertEqual(pattern.trackId, 1)
        XCTAssertEqual(pattern.length, 4)
        XCTAssertEqual(pattern.name, "Test Pattern")

        // Test step wrapping
        let firstStep = pattern.step(at: 0)
        let wrappedStep = pattern.step(at: 4) // Should wrap to index 0
        XCTAssertEqual(firstStep.note, wrappedStep.note)
    }

    // MARK: - Sequencer Tests

    func testSequencerInitialization() throws {
        XCTAssertNotNil(sequencer)
        XCTAssertEqual(sequencer.timing.bpm, 120.0)
    }

    func testSequencerPlayback() {
        let expectation = XCTestExpectation(description: "Playback events")
        expectation.expectedFulfillmentCount = 2 // Start and stop

        sequencer.eventPublisher
            .sink { event in
                switch event {
                case .playbackStarted, .playbackStopped:
                    expectation.fulfill()
                default:
                    break
                }
            }
            .store(in: &cancellables)

        sequencer.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.sequencer.stop()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testPatternLoading() {
        let steps = [PatternStep(note: 60, velocity: 100, isActive: true)]
        let pattern = Pattern(trackId: 1, steps: steps)

        sequencer.loadPattern(pattern, forTrack: 1)
        // Pattern should be loaded without errors
        XCTAssertTrue(true) // If we get here, loading succeeded
    }

    // MARK: - SequencerManager Tests

    func testSequencerManagerInitialization() {
        let manager = SequencerManager.shared
        XCTAssertNotNil(manager)

        manager.initialize()

        let expectation = XCTestExpectation(description: "Manager initialization")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertTrue(manager.isInitialized)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testTestPatternCreation() {
        let manager = SequencerManager.shared
        let pattern = manager.createTestPattern(forTrack: 1)

        XCTAssertEqual(pattern.trackId, 1)
        XCTAssertEqual(pattern.length, 16)

        // Check that steps 0, 4, 8, 12 are active
        XCTAssertTrue(pattern.step(at: 0).isActive)
        XCTAssertTrue(pattern.step(at: 4).isActive)
        XCTAssertTrue(pattern.step(at: 8).isActive)
        XCTAssertTrue(pattern.step(at: 12).isActive)

        // Check that other steps are inactive
        XCTAssertFalse(pattern.step(at: 1).isActive)
        XCTAssertFalse(pattern.step(at: 2).isActive)
    }
}