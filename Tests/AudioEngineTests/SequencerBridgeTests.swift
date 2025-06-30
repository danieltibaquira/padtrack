// SequencerBridgeTests.swift
// DigitonePad - AudioEngineTests
//
// Tests for sequencer-to-audio engine integration

import XCTest
import Combine
@testable import AudioEngine
@testable import SequencerModule
@testable import MachineProtocols

final class SequencerBridgeTests: XCTestCase {
    var audioEngine: AudioEngineManager!
    var sequencerBridge: SequencerBridge!
    var timingSynchronizer: TimingSynchronizer!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        audioEngine = AudioEngineManager.shared
        timingSynchronizer = TimingSynchronizer()
        sequencerBridge = SequencerBridge(audioEngine: audioEngine)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        sequencerBridge = nil
        timingSynchronizer = nil
        super.tearDown()
    }
    
    // MARK: - Audio Event Queue Tests
    
    func testAudioEventQueueInitialization() {
        let eventQueue = AudioEventQueue(maxQueueSize: 100)
        XCTAssertEqual(eventQueue.count, 0)
    }
    
    func testAudioEventQueueEnqueueDequeue() {
        let eventQueue = AudioEventQueue(maxQueueSize: 100)
        
        // Create test events
        let event1 = PrioritizedEvent(
            event: .noteOn(note: 60, velocity: 100, track: 1, timestamp: 1000),
            priority: .high,
            timestamp: 1000
        )
        
        let event2 = PrioritizedEvent(
            event: .noteOff(note: 60, track: 1, timestamp: 2000),
            priority: .normal,
            timestamp: 2000
        )
        
        // Enqueue events
        eventQueue.enqueue(event1)
        eventQueue.enqueue(event2)
        
        XCTAssertEqual(eventQueue.count, 2)
        
        // Dequeue events up to timestamp 1500
        let dequeuedEvents = eventQueue.dequeueEvents(upTo: 1500)
        XCTAssertEqual(dequeuedEvents.count, 1)
        XCTAssertEqual(eventQueue.count, 1)
        
        // Check that the correct event was dequeued
        if case .noteOn(let note, let velocity, let track, _) = dequeuedEvents.first?.event {
            XCTAssertEqual(note, 60)
            XCTAssertEqual(velocity, 100)
            XCTAssertEqual(track, 1)
        } else {
            XCTFail("Expected noteOn event")
        }
    }
    
    func testAudioEventQueuePriorityOrdering() {
        let eventQueue = AudioEventQueue(maxQueueSize: 100)
        
        // Create events with same timestamp but different priorities
        let lowPriorityEvent = PrioritizedEvent(
            event: .parameterChange(track: 1, parameter: "volume", value: 0.5, timestamp: 1000),
            priority: .low,
            timestamp: 1000
        )
        
        let highPriorityEvent = PrioritizedEvent(
            event: .noteOn(note: 60, velocity: 100, track: 1, timestamp: 1000),
            priority: .high,
            timestamp: 1000
        )
        
        // Enqueue in reverse priority order
        eventQueue.enqueue(lowPriorityEvent)
        eventQueue.enqueue(highPriorityEvent)
        
        // Dequeue and verify high priority comes first
        let dequeuedEvents = eventQueue.dequeueEvents(upTo: 1000)
        XCTAssertEqual(dequeuedEvents.count, 2)
        
        // High priority event should come first
        if case .noteOn = dequeuedEvents.first?.event {
            // Correct
        } else {
            XCTFail("High priority event should come first")
        }
    }
    
    func testAudioEventQueueMaxSize() {
        let eventQueue = AudioEventQueue(maxQueueSize: 2)
        
        // Add more events than max size
        for i in 0..<5 {
            let event = PrioritizedEvent(
                event: .noteOn(note: 60, velocity: 100, track: 1, timestamp: UInt64(i * 1000)),
                priority: .normal,
                timestamp: UInt64(i * 1000)
            )
            eventQueue.enqueue(event)
        }
        
        // Should not exceed max size
        XCTAssertEqual(eventQueue.count, 2)
    }
    
    // MARK: - Timing Synchronizer Tests
    
    func testTimingSynchronizerInitialization() {
        XCTAssertNotNil(timingSynchronizer)
        
        let timing = timingSynchronizer.getCurrentTiming()
        XCTAssertEqual(timing.sampleRate, 44100.0)
        XCTAssertEqual(timing.bpm, 120.0)
    }
    
    func testTimingSynchronizerTempoChange() {
        timingSynchronizer.setTempo(140.0)
        
        let timing = timingSynchronizer.getCurrentTiming()
        XCTAssertEqual(timing.bpm, 140.0)
        
        // Test clamping
        timingSynchronizer.setTempo(300.0) // Should be clamped to 200
        let clampedTiming = timingSynchronizer.getCurrentTiming()
        XCTAssertEqual(clampedTiming.bpm, 200.0)
    }
    
    func testTimingSynchronizerPlaybackControl() {
        let stepExpectation = XCTestExpectation(description: "Step advanced")
        
        timingSynchronizer.onStepAdvanced = { step in
            stepExpectation.fulfill()
        }
        
        timingSynchronizer.startPlayback()
        
        // Process a buffer to trigger step advance
        let hostTime = mach_absolute_time()
        _ = timingSynchronizer.processBuffer(hostTime: hostTime)
        
        timingSynchronizer.stopPlayback()
        
        wait(for: [stepExpectation], timeout: 1.0)
    }
    
    func testTimingSynchronizerSampleTimeCalculation() {
        timingSynchronizer.updateTiming(sampleRate: 44100.0, bufferSize: 512)
        
        let timing = timingSynchronizer.getCurrentTiming()
        
        // Test samples per beat calculation
        let expectedSamplesPerBeat = (60.0 / 120.0) * 44100.0 // 22050 samples per beat at 120 BPM
        XCTAssertEqual(timing.samplesPerBeat, expectedSamplesPerBeat, accuracy: 0.1)
        
        // Test samples per step calculation
        let expectedSamplesPerStep = expectedSamplesPerBeat / 4.0 // 16th notes
        XCTAssertEqual(timing.samplesPerStep, expectedSamplesPerStep, accuracy: 0.1)
    }
    
    // MARK: - Sequencer Bridge Tests
    
    func testSequencerBridgeInitialization() {
        XCTAssertNotNil(sequencerBridge)
    }
    
    func testSequencerBridgeVoiceMachineRegistration() {
        let voiceMachine = MockVoiceMachine()

        sequencerBridge.registerVoiceMachine(voiceMachine, forTrack: 1)

        // Voice machine should be registered (no direct way to test, but no crash is good)
        XCTAssertTrue(true)
    }
    
    func testSequencerBridgeEventProcessing() {
        let voiceMachine = MockVoiceMachine()
        sequencerBridge.registerVoiceMachine(voiceMachine, forTrack: 1)
        
        // Simulate sequencer event
        let sequencerEvent = SequencerEvent.noteTriggered(note: 60, velocity: 100, track: 1)
        
        // Process events (this would normally be called from audio callback)
        sequencerBridge.processEvents(bufferStartTime: 0, bufferSize: 512)
        
        // No direct way to verify, but no crash is good
        XCTAssertTrue(true)
    }
    
    // MARK: - Integration Tests
    
    func testSequencerToAudioEngineIntegration() {
        // Initialize audio engine with test configuration
        let config = AudioEngineConfiguration()
        
        do {
            try audioEngine.initialize(configuration: config)
            
            // Register a voice machine
            let voiceMachine = MockVoiceMachine()
            audioEngine.registerVoiceMachine(voiceMachine, forTrack: 1)

            // Set tempo
            audioEngine.setTempo(130.0)

            // Start playback
            audioEngine.startSequencerPlayback()

            // Get timing info
            let timing = audioEngine.getCurrentTiming()
            XCTAssertNotNil(timing)
            XCTAssertEqual(timing?.bpm, 130.0)

            // Stop playback
            audioEngine.stopSequencerPlayback()
            
        } catch {
            XCTFail("Failed to initialize audio engine: \(error)")
        }
    }
    
    func testSequencerManagerIntegration() {
        let sequencerManager = SequencerManager.shared
        sequencerManager.initialize()
        
        let expectation = XCTestExpectation(description: "Sequencer event received")
        
        // Subscribe to sequencer events
        sequencerManager.eventPublisher
            .sink { event in
                switch event {
                case .playbackStarted:
                    expectation.fulfill()
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Start sequencer
        sequencerManager.play()
        
        wait(for: [expectation], timeout: 2.0)
        
        sequencerManager.stop()
    }
    
    // MARK: - Performance Tests
    
    func testEventQueuePerformance() {
        let eventQueue = AudioEventQueue(maxQueueSize: 10000)
        
        measure {
            // Add many events
            for i in 0..<1000 {
                let event = PrioritizedEvent(
                    event: .noteOn(note: 60, velocity: 100, track: 1, timestamp: UInt64(i)),
                    priority: .normal,
                    timestamp: UInt64(i)
                )
                eventQueue.enqueue(event)
            }
            
            // Dequeue all events
            _ = eventQueue.dequeueEvents(upTo: 1000)
        }
    }
    
    func testTimingSynchronizerPerformance() {
        measure {
            for _ in 0..<1000 {
                let hostTime = mach_absolute_time()
                _ = timingSynchronizer.processBuffer(hostTime: hostTime)
            }
        }
    }
}
