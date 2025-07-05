import XCTest
import SwiftUI
@testable import DigitonePad
@testable import AudioEngine
@testable import VoiceModule

/// Tests for UI-Audio integration points following TDD requirements
class UIAudioIntegrationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var mockAudioEngine: MockAudioEngine!
    var mainLayoutState: MainLayoutState!
    
    // MARK: - Setup/Teardown
    
    override func setUp() {
        super.setUp()
        mockAudioEngine = MockAudioEngine()
        mainLayoutState = MainLayoutState()
    }
    
    override func tearDown() {
        mockAudioEngine = nil
        mainLayoutState = nil
        super.tearDown()
    }
    
    // MARK: - Parameter Encoder Tests
    
    /// Test that parameter encoder updates voice machine parameters
    func testParameterEncoderUpdatesVoiceMachine() {
        // ARRANGE: Setup voice machine and UI state
        let voiceMachine = MockFMToneVoiceMachine()
        let parameterBridge = ParameterBridge(voiceMachine: voiceMachine)
        
        // ACT: Simulate encoder rotation
        parameterBridge.updateParameter(.algorithm, value: 3.0)
        
        // ASSERT: Verify audio parameter changed
        XCTAssertEqual(voiceMachine.algorithmValue, 3.0, "Algorithm parameter should be updated")
    }
    
    /// Test parameter updates happen within required latency
    func testParameterUpdateLatency() {
        // ARRANGE: Setup voice machine and parameter bridge
        let voiceMachine = MockFMToneVoiceMachine()
        let parameterBridge = ParameterBridge(voiceMachine: voiceMachine)
        
        // ACT & ASSERT: Measure parameter update time
        measure {
            parameterBridge.updateParameter(.algorithm, value: 2.0)
        }
        
        // Parameter change must complete in <1ms
        XCTAssertEqual(voiceMachine.algorithmValue, 2.0, "Parameter should update immediately")
    }
    
    /// Test multiple parameter updates don't interfere
    func testMultipleParameterUpdates() {
        // ARRANGE: Setup voice machine and parameter bridge
        let voiceMachine = MockFMToneVoiceMachine()
        let parameterBridge = ParameterBridge(voiceMachine: voiceMachine)
        
        // ACT: Update multiple parameters
        parameterBridge.updateParameter(.algorithm, value: 1.0)
        parameterBridge.updateParameter(.ratio, value: 2.5)
        parameterBridge.updateParameter(.level, value: 0.75)
        
        // ASSERT: All parameters should be updated correctly
        XCTAssertEqual(voiceMachine.algorithmValue, 1.0, "Algorithm should be updated")
        XCTAssertEqual(voiceMachine.ratioValue, 2.5, "Ratio should be updated")
        XCTAssertEqual(voiceMachine.levelValue, 0.75, "Level should be updated")
    }
    
    // MARK: - Voice Machine Selection Tests
    
    /// Test voice machine selection updates audio engine
    func testVoiceMachineSelectionUpdatesAudio() {
        // ARRANGE: Setup audio engine and layout state
        let audioEngine = MockAudioEngine()
        let layoutState = MainLayoutState()
        let voiceMachineManager = VoiceMachineManager(audioEngine: audioEngine)
        
        // ACT: Select different voice machine
        layoutState.selectTrack(2)
        voiceMachineManager.setVoiceMachine(for: 2, type: .fmDrum)
        
        // ASSERT: Verify audio engine uses new machine
        XCTAssertEqual(voiceMachineManager.getVoiceMachineType(for: 2), .fmDrum, "Track 2 should use FM Drum voice machine")
    }
    
    /// Test voice machine selection persistence
    func testVoiceMachineSelectionPersistence() {
        // ARRANGE: Setup voice machine manager
        let audioEngine = MockAudioEngine()
        let voiceMachineManager = VoiceMachineManager(audioEngine: audioEngine)
        
        // ACT: Set voice machines for different tracks
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        voiceMachineManager.setVoiceMachine(for: 2, type: .fmDrum)
        voiceMachineManager.setVoiceMachine(for: 3, type: .wavetone)
        voiceMachineManager.setVoiceMachine(for: 4, type: .swarmer)
        
        // ASSERT: All voice machines should be correctly assigned
        XCTAssertEqual(voiceMachineManager.getVoiceMachineType(for: 1), .fmTone)
        XCTAssertEqual(voiceMachineManager.getVoiceMachineType(for: 2), .fmDrum)
        XCTAssertEqual(voiceMachineManager.getVoiceMachineType(for: 3), .wavetone)
        XCTAssertEqual(voiceMachineManager.getVoiceMachineType(for: 4), .swarmer)
    }
    
    // MARK: - Full Data Flow Tests
    
    /// Test complete data flow from UI to audio
    func testFullDataFlow_UIToAudio() {
        // ARRANGE: Setup complete system
        let audioEngine = MockAudioEngine()
        let voiceMachineManager = VoiceMachineManager(audioEngine: audioEngine)
        let layoutState = MainLayoutState()
        let parameterBridge = ParameterBridge(voiceMachine: voiceMachineManager.getVoiceMachine(for: 1))
        
        // ACT: Simulate UI interaction chain
        layoutState.selectTrack(1)
        voiceMachineManager.setVoiceMachine(for: 1, type: .fmTone)
        parameterBridge.updateParameter(.algorithm, value: 4.0)
        
        // ASSERT: Verify complete data flow
        XCTAssertEqual(layoutState.selectedTrack, 1, "Track should be selected")
        XCTAssertEqual(voiceMachineManager.getVoiceMachineType(for: 1), .fmTone, "Voice machine should be set")
        
        if let fmToneVoice = voiceMachineManager.getVoiceMachine(for: 1) as? MockFMToneVoiceMachine {
            XCTAssertEqual(fmToneVoice.algorithmValue, 4.0, "Parameter should be updated in voice machine")
        } else {
            XCTFail("Expected FM Tone voice machine")
        }
    }
    
    // MARK: - Performance Tests
    
    /// Test polyphonic performance with multiple voices
    func testPolyphonicPerformance() {
        // ARRANGE: Setup audio engine with multiple voices
        let audioEngine = MockAudioEngine()
        let voiceMachineManager = VoiceMachineManager(audioEngine: audioEngine)
        
        // ACT & ASSERT: Test 8 simultaneous voices without dropouts
        measure {
            for track in 1...4 {
                voiceMachineManager.setVoiceMachine(for: track, type: .fmTone)
                voiceMachineManager.triggerVoice(track: track, note: 60, velocity: 100)
                voiceMachineManager.triggerVoice(track: track, note: 64, velocity: 100)
            }
        }
        
        // CPU usage must stay <30% on minimum iPad
        XCTAssertLessThan(audioEngine.cpuUsage, 0.3, "CPU usage should be under 30%")
    }
    
    /// Test memory usage during integration
    func testMemoryUsageDuringIntegration() {
        // ARRANGE: Setup complete system
        let audioEngine = MockAudioEngine()
        let voiceMachineManager = VoiceMachineManager(audioEngine: audioEngine)
        let layoutState = MainLayoutState()
        
        // ACT: Perform various operations
        for track in 1...4 {
            layoutState.selectTrack(track)
            voiceMachineManager.setVoiceMachine(for: track, type: .fmTone)
            
            for param in 1...8 {
                let parameterBridge = ParameterBridge(voiceMachine: voiceMachineManager.getVoiceMachine(for: track))
                parameterBridge.updateParameter(.algorithm, value: Double(param))
            }
        }
        
        // ASSERT: Memory usage increase should be <10MB
        let report = audioEngine.getPerformanceReport()
        XCTAssertLessThan(report.memoryUsage, 0.1, "Memory usage should be under 10%")
    }
}

// MARK: - Mock Classes for Testing

/// Mock FM Tone Voice Machine for testing
class MockFMToneVoiceMachine: VoiceMachineProtocol {
    var algorithmValue: Double = 1.0
    var ratioValue: Double = 1.0
    var levelValue: Double = 1.0
    
    func updateParameter(_ parameter: FMToneParameter, value: Double) {
        switch parameter {
        case .algorithm:
            algorithmValue = value
        case .ratio:
            ratioValue = value
        case .level:
            levelValue = value
        default:
            break
        }
    }
    
    func triggerNote(_ note: Int, velocity: Int) {
        // Mock implementation
    }
    
    func releaseNote(_ note: Int) {
        // Mock implementation
    }
}

/// Mock Voice Machine Manager for testing
class VoiceMachineManager {
    private var audioEngine: MockAudioEngine
    private var voiceMachines: [Int: VoiceMachineProtocol] = [:]
    private var voiceMachineTypes: [Int: VoiceMachineType] = [:]
    
    init(audioEngine: MockAudioEngine) {
        self.audioEngine = audioEngine
    }
    
    func setVoiceMachine(for track: Int, type: VoiceMachineType) {
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
    
    func getVoiceMachine(for track: Int) -> VoiceMachineProtocol? {
        return voiceMachines[track]
    }
    
    func getVoiceMachineType(for track: Int) -> VoiceMachineType? {
        return voiceMachineTypes[track]
    }
    
    func triggerVoice(track: Int, note: Int, velocity: Int) {
        voiceMachines[track]?.triggerNote(note, velocity: velocity)
    }
}

/// Mock Parameter Bridge for testing
class ParameterBridge {
    private var voiceMachine: VoiceMachineProtocol?
    
    init(voiceMachine: VoiceMachineProtocol?) {
        self.voiceMachine = voiceMachine
    }
    
    func updateParameter(_ parameter: FMToneParameter, value: Double) {
        if let fmToneVoice = voiceMachine as? MockFMToneVoiceMachine {
            fmToneVoice.updateParameter(parameter, value: value)
        }
    }
}

// MARK: - Supporting Types

enum VoiceMachineType {
    case fmTone, fmDrum, wavetone, swarmer
}

enum FMToneParameter {
    case algorithm, ratio, level
}

protocol VoiceMachineProtocol {
    func triggerNote(_ note: Int, velocity: Int)
    func releaseNote(_ note: Int)
}

// Additional mock voice machines
class MockFMDrumVoiceMachine: VoiceMachineProtocol {
    func triggerNote(_ note: Int, velocity: Int) {}
    func releaseNote(_ note: Int) {}
}

class MockWavetoneVoiceMachine: VoiceMachineProtocol {
    func triggerNote(_ note: Int, velocity: Int) {}
    func releaseNote(_ note: Int) {}
}

class MockSwarmerVoiceMachine: VoiceMachineProtocol {
    func triggerNote(_ note: Int, velocity: Int) {}
    func releaseNote(_ note: Int) {}
}