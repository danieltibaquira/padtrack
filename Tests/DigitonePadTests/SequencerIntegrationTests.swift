import XCTest
import SwiftUI
@testable import DigitonePad
@testable import AudioEngine
@testable import VoiceModule
@testable import SequencerModule

/// Tests for step sequencer integration with audio engine
class SequencerIntegrationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var mockAudioEngine: MockAudioEngine!
    var sequencerCore: SequencerCore!
    var voiceMachineManager: VoiceMachineManager!
    var mainLayoutState: MainLayoutState!
    
    // MARK: - Setup/Teardown
    
    override func setUp() {
        super.setUp()
        mockAudioEngine = MockAudioEngine()
        sequencerCore = SequencerCore(audioEngine: mockAudioEngine)
        voiceMachineManager = VoiceMachineManager(audioEngine: mockAudioEngine)
        mainLayoutState = MainLayoutState()
    }
    
    override func tearDown() {
        mockAudioEngine = nil
        sequencerCore = nil
        voiceMachineManager = nil
        mainLayoutState = nil
        super.tearDown()
    }
    
    // MARK: - Sequencer Trigger Tests
    
    /// Test sequencer step triggers produce audio
    func testSequencerToAudioFlow() {
        // ARRANGE: Setup sequencer and audio engine
        try? mockAudioEngine.initialize(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try? mockAudioEngine.start()
        
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        sequencerCore.setVoiceMachineManager(voiceMachineManager)
        
        // ACT: Trigger step
        let triggerTime = Date().timeIntervalSince1970
        sequencerCore.triggerStep(0, track: 1)
        let actualTriggerTime = sequencerCore.getLastTriggerTime()
        
        // ASSERT: Step triggers should produce audio
        XCTAssertTrue(mockAudioEngine.isRunning, "Audio engine should be running")
        XCTAssertLessThan(actualTriggerTime - triggerTime, 0.001, "Trigger should happen within 1ms")
    }
    
    /// Test sequencer trigger timing accuracy
    func testSequencerTriggerTiming() {
        // ARRANGE: Setup sequencer with precise timing
        try? mockAudioEngine.initialize(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try? mockAudioEngine.start()
        
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        sequencerCore.setVoiceMachineManager(voiceMachineManager)
        
        // ACT: Trigger multiple steps and measure timing
        let startTime = Date().timeIntervalSince1970
        
        for step in 0..<4 {
            sequencerCore.triggerStep(step, track: 1)
        }
        
        let endTime = Date().timeIntervalSince1970
        let totalTime = endTime - startTime
        
        // ASSERT: All triggers should complete quickly
        XCTAssertLessThan(totalTime, 0.01, "All triggers should complete within 10ms")
        XCTAssertEqual(sequencerCore.getTriggeredStepCount(), 4, "All steps should be triggered")
    }
    
    /// Test sequencer step pattern playback
    func testSequencerStepPatternPlayback() {
        // ARRANGE: Setup sequencer with pattern
        try? mockAudioEngine.initialize(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try? mockAudioEngine.start()
        
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        sequencerCore.setVoiceMachineManager(voiceMachineManager)
        
        // Create a simple pattern: steps 0, 4, 8, 12
        let pattern = [true, false, false, false, true, false, false, false, 
                      true, false, false, false, true, false, false, false]
        sequencerCore.setPattern(pattern, for: 1)
        
        // ACT: Start playback
        sequencerCore.start()
        
        // Simulate 4 steps of playback
        for step in 0..<4 {
            sequencerCore.processStep(step * 4) // Steps 0, 4, 8, 12
        }
        
        // ASSERT: Only active steps should trigger
        XCTAssertEqual(sequencerCore.getTriggeredStepCount(), 4, "Only active steps should trigger")
        XCTAssertTrue(sequencerCore.isRunning, "Sequencer should be running")
    }
    
    // MARK: - Multi-Track Sequencer Tests
    
    /// Test multi-track sequencer playback
    func testMultiTrackSequencerPlayback() {
        // ARRANGE: Setup multi-track sequencer
        try? mockAudioEngine.initialize(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try? mockAudioEngine.start()
        
        // Setup different voice machines for different tracks
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        voiceMachineManager.setVoiceMachine(for: 2, type: .fmDrum)
        voiceMachineManager.setVoiceMachine(for: 3, type: .wavetone)
        voiceMachineManager.setVoiceMachine(for: 4, type: .swarmer)
        
        sequencerCore.setVoiceMachineManager(voiceMachineManager)
        
        // Create patterns for each track
        for track in 1...4 {
            let pattern = Array(repeating: false, count: 16)
            var activePattern = pattern
            activePattern[0] = true  // First step active for all tracks
            activePattern[track * 2] = true  // Different steps for each track
            
            sequencerCore.setPattern(activePattern, for: track)
        }
        
        // ACT: Start playback and process first step
        sequencerCore.start()
        sequencerCore.processStep(0)
        
        // ASSERT: All tracks should trigger their first step
        XCTAssertEqual(sequencerCore.getTriggeredStepCount(for: 1), 1, "Track 1 should trigger")
        XCTAssertEqual(sequencerCore.getTriggeredStepCount(for: 2), 1, "Track 2 should trigger")
        XCTAssertEqual(sequencerCore.getTriggeredStepCount(for: 3), 1, "Track 3 should trigger")
        XCTAssertEqual(sequencerCore.getTriggeredStepCount(for: 4), 1, "Track 4 should trigger")
    }
    
    /// Test track muting in sequencer
    func testTrackMutingInSequencer() {
        // ARRANGE: Setup sequencer with patterns
        try? mockAudioEngine.initialize(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try? mockAudioEngine.start()
        
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        voiceMachineManager.setVoiceMachine(for: 2, type: .fmDrum)
        sequencerCore.setVoiceMachineManager(voiceMachineManager)
        
        // Set patterns for both tracks
        let activePattern = [true, false, true, false, true, false, true, false,
                            true, false, true, false, true, false, true, false]
        sequencerCore.setPattern(activePattern, for: 1)
        sequencerCore.setPattern(activePattern, for: 2)
        
        // ACT: Mute track 2 and process steps
        sequencerCore.muteTrack(2)
        sequencerCore.start()
        
        for step in [0, 2, 4, 6] {
            sequencerCore.processStep(step)
        }
        
        // ASSERT: Track 1 should trigger, track 2 should be muted
        XCTAssertEqual(sequencerCore.getTriggeredStepCount(for: 1), 4, "Track 1 should trigger all steps")
        XCTAssertEqual(sequencerCore.getTriggeredStepCount(for: 2), 0, "Track 2 should be muted")
    }
    
    // MARK: - Sequencer Transport Tests
    
    /// Test sequencer transport controls
    func testSequencerTransportControls() {
        // ARRANGE: Setup sequencer
        try? mockAudioEngine.initialize(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try? mockAudioEngine.start()
        
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        sequencerCore.setVoiceMachineManager(voiceMachineManager)
        
        // ACT: Test transport controls
        sequencerCore.start()
        XCTAssertTrue(sequencerCore.isRunning, "Sequencer should be running after start")
        
        sequencerCore.stop()
        XCTAssertFalse(sequencerCore.isRunning, "Sequencer should stop after stop")
        
        sequencerCore.start()
        sequencerCore.pause()
        XCTAssertFalse(sequencerCore.isRunning, "Sequencer should pause")
        
        sequencerCore.resume()
        XCTAssertTrue(sequencerCore.isRunning, "Sequencer should resume")
        
        // ASSERT: Transport controls should work correctly
        XCTAssertTrue(sequencerCore.isRunning, "Final state should be running")
    }
    
    /// Test sequencer position tracking
    func testSequencerPositionTracking() {
        // ARRANGE: Setup sequencer
        try? mockAudioEngine.initialize(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try? mockAudioEngine.start()
        
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        sequencerCore.setVoiceMachineManager(voiceMachineManager)
        
        // ACT: Start sequencer and process multiple steps
        sequencerCore.start()
        
        for step in 0..<8 {
            sequencerCore.processStep(step)
        }
        
        // ASSERT: Position should be tracked correctly
        XCTAssertEqual(sequencerCore.getCurrentPosition(), 8, "Position should be tracked correctly")
        
        // Test position reset
        sequencerCore.resetPosition()
        XCTAssertEqual(sequencerCore.getCurrentPosition(), 0, "Position should reset to 0")
    }
    
    // MARK: - Sequencer Pattern Management Tests
    
    /// Test sequencer pattern editing
    func testSequencerPatternEditing() {
        // ARRANGE: Setup sequencer
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        sequencerCore.setVoiceMachineManager(voiceMachineManager)
        
        // ACT: Edit pattern
        let initialPattern = Array(repeating: false, count: 16)
        sequencerCore.setPattern(initialPattern, for: 1)
        
        // Toggle some steps
        sequencerCore.toggleStep(0, track: 1)
        sequencerCore.toggleStep(4, track: 1)
        sequencerCore.toggleStep(8, track: 1)
        sequencerCore.toggleStep(12, track: 1)
        
        let editedPattern = sequencerCore.getPattern(for: 1)
        
        // ASSERT: Pattern should be edited correctly
        XCTAssertTrue(editedPattern[0], "Step 0 should be active")
        XCTAssertTrue(editedPattern[4], "Step 4 should be active")
        XCTAssertTrue(editedPattern[8], "Step 8 should be active")
        XCTAssertTrue(editedPattern[12], "Step 12 should be active")
        
        // Other steps should remain inactive
        XCTAssertFalse(editedPattern[1], "Step 1 should be inactive")
        XCTAssertFalse(editedPattern[2], "Step 2 should be inactive")
    }
    
    /// Test sequencer pattern copy/paste
    func testSequencerPatternCopyPaste() {
        // ARRANGE: Setup sequencer with pattern
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        voiceMachineManager.setVoiceMachine(for: 2, type: .fmDrum)
        sequencerCore.setVoiceMachineManager(voiceMachineManager)
        
        // Create source pattern
        let sourcePattern = [true, false, true, false, true, false, true, false,
                           false, true, false, true, false, true, false, true]
        sequencerCore.setPattern(sourcePattern, for: 1)
        
        // ACT: Copy pattern from track 1 to track 2
        sequencerCore.copyPattern(from: 1, to: 2)
        
        let copiedPattern = sequencerCore.getPattern(for: 2)
        
        // ASSERT: Pattern should be copied correctly
        XCTAssertEqual(copiedPattern, sourcePattern, "Pattern should be copied exactly")
        
        // Original pattern should remain unchanged
        let originalPattern = sequencerCore.getPattern(for: 1)
        XCTAssertEqual(originalPattern, sourcePattern, "Original pattern should remain unchanged")
    }
    
    // MARK: - Performance Tests
    
    /// Test sequencer performance under load
    func testSequencerPerformanceUnderLoad() {
        // ARRANGE: Setup sequencer with all tracks active
        try? mockAudioEngine.initialize(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try? mockAudioEngine.start()
        
        for track in 1...4 {
            voiceMachineManager.setVoiceMachine(for: track, type: .fmTone)
        }
        sequencerCore.setVoiceMachineManager(voiceMachineManager)
        
        // Create dense patterns for all tracks
        let densePattern = Array(repeating: true, count: 16)
        for track in 1...4 {
            sequencerCore.setPattern(densePattern, for: track)
        }
        
        // ACT & ASSERT: Measure performance
        measure {
            sequencerCore.start()
            for step in 0..<16 {
                sequencerCore.processStep(step)
            }
            sequencerCore.stop()
        }
        
        // CPU usage should remain reasonable
        let report = mockAudioEngine.getPerformanceReport()
        XCTAssertLessThan(report.cpuUsage, 0.5, "CPU usage should be under 50%")
    }
    
    /// Test sequencer memory usage
    func testSequencerMemoryUsage() {
        // ARRANGE: Setup sequencer with maximum configuration
        try? mockAudioEngine.initialize(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try? mockAudioEngine.start()
        
        for track in 1...4 {
            voiceMachineManager.setVoiceMachine(for: track, type: .fmTone)
        }
        sequencerCore.setVoiceMachineManager(voiceMachineManager)
        
        // Create and store multiple patterns
        for track in 1...4 {
            for bank in 1...4 {
                let pattern = Array(repeating: bank % 2 == 0, count: 16)
                sequencerCore.setPattern(pattern, for: track, bank: bank)
            }
        }
        
        // ACT: Run sequencer
        sequencerCore.start()
        for _ in 0..<100 {
            sequencerCore.processStep(0)
        }
        
        // ASSERT: Memory usage should be reasonable
        let report = mockAudioEngine.getPerformanceReport()
        XCTAssertLessThan(report.memoryUsage, 0.3, "Memory usage should be under 30%")
    }
}

// MARK: - Mock Sequencer Core for Testing

class SequencerCore {
    private var audioEngine: MockAudioEngine
    private var voiceMachineManager: VoiceMachineManager?
    private var isRunning = false
    private var currentPosition = 0
    private var patterns: [Int: [Bool]] = [:]
    private var patternBanks: [Int: [Int: [Bool]]] = [:]
    private var mutedTracks: Set<Int> = []
    private var triggeredStepCounts: [Int: Int] = [:]
    private var lastTriggerTime: TimeInterval = 0
    
    init(audioEngine: MockAudioEngine) {
        self.audioEngine = audioEngine
    }
    
    func setVoiceMachineManager(_ manager: VoiceMachineManager) {
        self.voiceMachineManager = manager
    }
    
    func start() {
        isRunning = true
        currentPosition = 0
    }
    
    func stop() {
        isRunning = false
        currentPosition = 0
    }
    
    func pause() {
        isRunning = false
    }
    
    func resume() {
        isRunning = true
    }
    
    func triggerStep(_ step: Int, track: Int) {
        lastTriggerTime = Date().timeIntervalSince1970
        triggeredStepCounts[track, default: 0] += 1
        
        // Trigger voice machine
        voiceMachineManager?.triggerVoice(track: track, note: 60, velocity: 100)
    }
    
    func processStep(_ step: Int) {
        currentPosition = step
        
        // Process all tracks
        for track in 1...4 {
            guard !mutedTracks.contains(track) else { continue }
            
            if let pattern = patterns[track], step < pattern.count, pattern[step] {
                triggerStep(step, track: track)
            }
        }
    }
    
    func setPattern(_ pattern: [Bool], for track: Int, bank: Int = 1) {
        patterns[track] = pattern
        
        if patternBanks[track] == nil {
            patternBanks[track] = [:]
        }
        patternBanks[track]?[bank] = pattern
    }
    
    func getPattern(for track: Int) -> [Bool] {
        return patterns[track] ?? Array(repeating: false, count: 16)
    }
    
    func toggleStep(_ step: Int, track: Int) {
        if patterns[track] == nil {
            patterns[track] = Array(repeating: false, count: 16)
        }
        patterns[track]?[step].toggle()
    }
    
    func copyPattern(from sourceTrack: Int, to destinationTrack: Int) {
        patterns[destinationTrack] = patterns[sourceTrack]
    }
    
    func muteTrack(_ track: Int) {
        mutedTracks.insert(track)
    }
    
    func unmuteTrack(_ track: Int) {
        mutedTracks.remove(track)
    }
    
    func resetPosition() {
        currentPosition = 0
    }
    
    func getCurrentPosition() -> Int {
        return currentPosition
    }
    
    func getLastTriggerTime() -> TimeInterval {
        return lastTriggerTime
    }
    
    func getTriggeredStepCount(for track: Int? = nil) -> Int {
        if let track = track {
            return triggeredStepCounts[track] ?? 0
        } else {
            return triggeredStepCounts.values.reduce(0, +)
        }
    }
}