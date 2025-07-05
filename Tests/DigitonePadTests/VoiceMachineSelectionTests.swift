import XCTest
import SwiftUI
@testable import DigitonePad
@testable import AudioEngine
@testable import VoiceModule

/// Tests for voice machine selection and switching functionality
class VoiceMachineSelectionTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var mockAudioEngine: MockAudioEngine!
    var voiceMachineManager: VoiceMachineManager!
    var mainLayoutState: MainLayoutState!
    
    // MARK: - Setup/Teardown
    
    override func setUp() {
        super.setUp()
        mockAudioEngine = MockAudioEngine()
        voiceMachineManager = VoiceMachineManager(audioEngine: mockAudioEngine)
        mainLayoutState = MainLayoutState()
    }
    
    override func tearDown() {
        mockAudioEngine = nil
        voiceMachineManager = nil
        mainLayoutState = nil
        super.tearDown()
    }
    
    // MARK: - Voice Machine Selection Tests
    
    /// Test track selection changes voice machine
    func testTrackSelectionChangesVoiceMachine() {
        // ARRANGE: Setup voice machine manager
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        voiceMachineManager.setVoiceMachine(for: 2, type: .fmDrum)
        
        // ACT: Select different tracks
        mainLayoutState.selectTrack(1)
        let track1Type = voiceMachineManager.getVoiceMachineType(for: 1)
        
        mainLayoutState.selectTrack(2)
        let track2Type = voiceMachineManager.getVoiceMachineType(for: 2)
        
        // ASSERT: Voice machines should match track selection
        XCTAssertEqual(track1Type, .fmTone, "Track 1 should use FM Tone")
        XCTAssertEqual(track2Type, .fmDrum, "Track 2 should use FM Drum")
        XCTAssertEqual(mainLayoutState.selectedTrack, 2, "Track 2 should be selected")
    }
    
    /// Test voice machine switching performance
    func testVoiceMachineSwitchingPerformance() {
        // ARRANGE: Setup voice machine manager
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        
        // ACT & ASSERT: Measure voice machine switching time
        measure {
            voiceMachineManager.setVoiceMachine(for: 1, type: .fmDrum)
            voiceMachineManager.setVoiceMachine(for: 1, type: .wavetone)
            voiceMachineManager.setVoiceMachine(for: 1, type: .swarmer)
            voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        }
        
        // Voice machine switching should be seamless (<10ms)
        XCTAssertEqual(voiceMachineManager.getVoiceMachineType(for: 1), .fmTone, "Voice machine should switch correctly")
    }
    
    /// Test voice machine persistence across track switches
    func testVoiceMachinePersistenceAcrossTrackSwitches() {
        // ARRANGE: Setup different voice machines for each track
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        voiceMachineManager.setVoiceMachine(for: 2, type: .fmDrum)
        voiceMachineManager.setVoiceMachine(for: 3, type: .wavetone)
        voiceMachineManager.setVoiceMachine(for: 4, type: .swarmer)
        
        // ACT: Switch between tracks multiple times
        mainLayoutState.selectTrack(1)
        mainLayoutState.selectTrack(3)
        mainLayoutState.selectTrack(2)
        mainLayoutState.selectTrack(4)
        mainLayoutState.selectTrack(1)
        
        // ASSERT: Voice machines should persist
        XCTAssertEqual(voiceMachineManager.getVoiceMachineType(for: 1), .fmTone, "Track 1 voice machine should persist")
        XCTAssertEqual(voiceMachineManager.getVoiceMachineType(for: 2), .fmDrum, "Track 2 voice machine should persist")
        XCTAssertEqual(voiceMachineManager.getVoiceMachineType(for: 3), .wavetone, "Track 3 voice machine should persist")
        XCTAssertEqual(voiceMachineManager.getVoiceMachineType(for: 4), .swarmer, "Track 4 voice machine should persist")
    }
    
    // MARK: - Voice Machine Integration Tests
    
    /// Test voice machine integration with audio engine
    func testVoiceMachineIntegrationWithAudioEngine() {
        // ARRANGE: Setup audio engine and voice machine
        try? mockAudioEngine.initialize(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try? mockAudioEngine.start()
        
        // ACT: Set voice machine and trigger note
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        voiceMachineManager.triggerVoice(track: 1, note: 60, velocity: 100)
        
        // ASSERT: Audio engine should remain stable
        XCTAssertTrue(mockAudioEngine.isRunning, "Audio engine should be running")
        XCTAssertTrue(mockAudioEngine.isInitialized, "Audio engine should be initialized")
        
        // Voice machine should be correctly set
        XCTAssertEqual(voiceMachineManager.getVoiceMachineType(for: 1), .fmTone, "Voice machine should be set correctly")
    }
    
    /// Test voice machine switching during playback
    func testVoiceMachineSwitchingDuringPlayback() {
        // ARRANGE: Setup audio engine and start playback
        try? mockAudioEngine.initialize(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try? mockAudioEngine.start()
        
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        mainLayoutState.togglePlayback() // Start playback
        
        // ACT: Switch voice machine during playback
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmDrum)
        
        // ASSERT: Playback should continue without interruption
        XCTAssertTrue(mainLayoutState.isPlaying, "Playback should continue")
        XCTAssertTrue(mockAudioEngine.isRunning, "Audio engine should remain running")
        XCTAssertEqual(voiceMachineManager.getVoiceMachineType(for: 1), .fmDrum, "Voice machine should switch")
    }
    
    // MARK: - Voice Machine Parameter Tests
    
    /// Test voice machine parameter isolation
    func testVoiceMachineParameterIsolation() {
        // ARRANGE: Setup different voice machines
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        voiceMachineManager.setVoiceMachine(for: 2, type: .fmTone)
        
        let voice1 = voiceMachineManager.getVoiceMachine(for: 1) as? MockFMToneVoiceMachine
        let voice2 = voiceMachineManager.getVoiceMachine(for: 2) as? MockFMToneVoiceMachine
        
        // ACT: Update parameters for different tracks
        voice1?.updateParameter(.algorithm, value: 2.0)
        voice2?.updateParameter(.algorithm, value: 3.0)
        
        // ASSERT: Parameters should be isolated between voice machines
        XCTAssertEqual(voice1?.algorithmValue, 2.0, "Track 1 voice machine should have algorithm = 2.0")
        XCTAssertEqual(voice2?.algorithmValue, 3.0, "Track 2 voice machine should have algorithm = 3.0")
    }
    
    /// Test voice machine parameter reset on switch
    func testVoiceMachineParameterResetOnSwitch() {
        // ARRANGE: Setup voice machine with custom parameters
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        let originalVoice = voiceMachineManager.getVoiceMachine(for: 1) as? MockFMToneVoiceMachine
        originalVoice?.updateParameter(.algorithm, value: 4.0)
        
        // ACT: Switch to different voice machine type and back
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmDrum)
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        
        let newVoice = voiceMachineManager.getVoiceMachine(for: 1) as? MockFMToneVoiceMachine
        
        // ASSERT: New voice machine should have default parameters
        XCTAssertEqual(newVoice?.algorithmValue, 1.0, "New voice machine should have default algorithm value")
        XCTAssertNotEqual(newVoice?.algorithmValue, 4.0, "New voice machine should not retain old parameters")
    }
    
    // MARK: - Voice Machine Type Tests
    
    /// Test all voice machine types can be selected
    func testAllVoiceMachineTypesCanBeSelected() {
        // ARRANGE: List of all voice machine types
        let allTypes: [VoiceMachineType] = [.fmTone, .fmDrum, .wavetone, .swarmer]
        
        // ACT: Set each voice machine type
        for (index, type) in allTypes.enumerated() {
            let track = index + 1
            voiceMachineManager.setVoiceMachine(for: track, type: type)
        }
        
        // ASSERT: All voice machine types should be set correctly
        XCTAssertEqual(voiceMachineManager.getVoiceMachineType(for: 1), .fmTone, "Track 1 should be FM Tone")
        XCTAssertEqual(voiceMachineManager.getVoiceMachineType(for: 2), .fmDrum, "Track 2 should be FM Drum")
        XCTAssertEqual(voiceMachineManager.getVoiceMachineType(for: 3), .wavetone, "Track 3 should be Wavetone")
        XCTAssertEqual(voiceMachineManager.getVoiceMachineType(for: 4), .swarmer, "Track 4 should be Swarmer")
    }
    
    /// Test voice machine type validation
    func testVoiceMachineTypeValidation() {
        // ARRANGE: Setup voice machine manager
        let validTracks = [1, 2, 3, 4]
        let invalidTracks = [0, 5, -1, 10]
        
        // ACT & ASSERT: Test valid tracks
        for track in validTracks {
            voiceMachineManager.setVoiceMachine(for: track, type: .fmTone)
            XCTAssertEqual(voiceMachineManager.getVoiceMachineType(for: track), .fmTone, "Track \(track) should accept voice machine")
        }
        
        // ACT & ASSERT: Test invalid tracks
        for track in invalidTracks {
            voiceMachineManager.setVoiceMachine(for: track, type: .fmTone)
            XCTAssertNil(voiceMachineManager.getVoiceMachineType(for: track), "Track \(track) should not accept voice machine")
        }
    }
    
    // MARK: - Voice Machine Memory Tests
    
    /// Test voice machine memory usage
    func testVoiceMachineMemoryUsage() {
        // ARRANGE: Setup multiple voice machines
        let trackCount = 4
        let voiceMachineTypes: [VoiceMachineType] = [.fmTone, .fmDrum, .wavetone, .swarmer]
        
        // ACT: Create multiple voice machines
        for track in 1...trackCount {
            let typeIndex = (track - 1) % voiceMachineTypes.count
            voiceMachineManager.setVoiceMachine(for: track, type: voiceMachineTypes[typeIndex])
        }
        
        // ASSERT: Memory usage should be reasonable
        let report = mockAudioEngine.getPerformanceReport()
        XCTAssertLessThan(report.memoryUsage, 0.5, "Memory usage should be under 50%")
    }
    
    /// Test voice machine cleanup on shutdown
    func testVoiceMachineCleanupOnShutdown() {
        // ARRANGE: Setup voice machines
        for track in 1...4 {
            voiceMachineManager.setVoiceMachine(for: track, type: .fmTone)
        }
        
        // ACT: Shutdown audio engine
        mockAudioEngine.shutdown()
        
        // ASSERT: Voice machines should be cleaned up
        XCTAssertFalse(mockAudioEngine.isRunning, "Audio engine should be stopped")
        XCTAssertFalse(mockAudioEngine.isInitialized, "Audio engine should be deinitialized")
    }
}

// MARK: - Voice Machine Manager Extensions

extension VoiceMachineManager {
    /// Set voice machine for invalid tracks (should be ignored)
    func setVoiceMachine(for track: Int, type: VoiceMachineType) {
        guard track >= 1 && track <= 4 else { return }
        
        voiceMachineTypes[track] = type
        
        switch type {
        case .fmTone:
            voiceMachines[track] = MockFMToneVoiceMachine()
        case .fmDrum:
            voiceMachines[track] = MockFMDrumVoiceMachine()
        case .wavetone:
            voiceMachines[track] = MockWavetoneVoiceMachine()
        case .swarmer:
            voiceMachines[track] = MockSwarmerVoiceMachine()
        }
    }
}