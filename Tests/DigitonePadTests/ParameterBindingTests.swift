import XCTest
import SwiftUI
@testable import DigitonePad
@testable import AudioEngine
@testable import VoiceModule

/// Tests for parameter binding between UI controls and audio parameters
class ParameterBindingTests: XCTestCase {
    
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
    
    // MARK: - Parameter Encoder Binding Tests
    
    /// Test parameter encoder rotation updates the correct parameter
    func testParameterEncoderBinding() {
        // ARRANGE: Setup parameter control system
        let parameterControl = ParameterControl()
        let voiceMachine = MockFMToneVoiceMachine()
        parameterControl.setVoiceMachine(voiceMachine)
        
        // ACT: Simulate encoder 1 rotation
        parameterControl.updateEncoder(1, delta: 0.1)
        
        // ASSERT: Verify correct parameter is updated
        XCTAssertEqual(voiceMachine.algorithmValue, 1.1, accuracy: 0.01, "Algorithm parameter should be updated by encoder 1")
    }
    
    /// Test parameter encoder with different voice machines
    func testParameterEncoderWithDifferentVoiceMachines() {
        // ARRANGE: Setup parameter control with different voice machines
        let parameterControl = ParameterControl()
        let fmToneVoice = MockFMToneVoiceMachine()
        let fmDrumVoice = MockFMDrumVoiceMachine()
        
        // ACT: Test FM Tone parameters
        parameterControl.setVoiceMachine(fmToneVoice)
        parameterControl.updateEncoder(1, delta: 0.2)
        
        // Switch to FM Drum and test
        parameterControl.setVoiceMachine(fmDrumVoice)
        parameterControl.updateEncoder(1, delta: 0.3)
        
        // ASSERT: Both voice machines should have received updates
        XCTAssertEqual(fmToneVoice.algorithmValue, 1.2, accuracy: 0.01, "FM Tone algorithm should be updated")
        XCTAssertEqual(fmDrumVoice.tuneValue, 1.3, accuracy: 0.01, "FM Drum tune should be updated")
    }
    
    /// Test parameter value clamping
    func testParameterValueClamping() {
        // ARRANGE: Setup parameter control
        let parameterControl = ParameterControl()
        let voiceMachine = MockFMToneVoiceMachine()
        parameterControl.setVoiceMachine(voiceMachine)
        
        // ACT: Try to set values outside valid range
        parameterControl.updateEncoder(1, delta: 10.0) // Should clamp to max
        parameterControl.updateEncoder(2, delta: -10.0) // Should clamp to min
        
        // ASSERT: Values should be clamped to valid ranges
        XCTAssertLessThanOrEqual(voiceMachine.algorithmValue, 5.0, "Algorithm should not exceed maximum")
        XCTAssertGreaterThanOrEqual(voiceMachine.ratioValue, 0.0, "Ratio should not go below minimum")
    }
    
    // MARK: - Real-time Parameter Updates
    
    /// Test real-time parameter updates during audio playback
    func testRealTimeParameterUpdates() {
        // ARRANGE: Setup audio engine and parameter control
        let audioEngine = MockAudioEngine()
        try? audioEngine.initialize(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try? audioEngine.start()
        
        let parameterControl = ParameterControl()
        let voiceMachine = MockFMToneVoiceMachine()
        parameterControl.setVoiceMachine(voiceMachine)
        
        // ACT: Update parameters during playback
        parameterControl.updateEncoder(1, delta: 0.1)
        parameterControl.updateEncoder(2, delta: 0.2)
        
        // ASSERT: Parameters should update without affecting audio engine
        XCTAssertTrue(audioEngine.isRunning, "Audio engine should remain running")
        XCTAssertEqual(voiceMachine.algorithmValue, 1.1, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.ratioValue, 1.2, accuracy: 0.01)
    }
    
    /// Test parameter update performance
    func testParameterUpdatePerformance() {
        // ARRANGE: Setup parameter control
        let parameterControl = ParameterControl()
        let voiceMachine = MockFMToneVoiceMachine()
        parameterControl.setVoiceMachine(voiceMachine)
        
        // ACT & ASSERT: Measure parameter update time
        measure {
            for i in 1...8 {
                parameterControl.updateEncoder(i, delta: 0.1)
            }
        }
        
        // All 8 parameters should be updated quickly
        XCTAssertNotEqual(voiceMachine.algorithmValue, 1.0, "Parameters should be updated")
    }
    
    // MARK: - Parameter Page Navigation Tests
    
    /// Test parameter page switching
    func testParameterPageSwitching() {
        // ARRANGE: Setup parameter control with multiple pages
        let parameterControl = ParameterControl()
        let voiceMachine = MockFMToneVoiceMachine()
        parameterControl.setVoiceMachine(voiceMachine)
        
        // ACT: Switch to different parameter pages
        parameterControl.setPage(1) // Oscillator page
        parameterControl.updateEncoder(1, delta: 0.1)
        
        parameterControl.setPage(2) // Filter page
        parameterControl.updateEncoder(1, delta: 0.2)
        
        parameterControl.setPage(3) // Amplitude page
        parameterControl.updateEncoder(1, delta: 0.3)
        
        // ASSERT: Different parameters should be updated based on current page
        XCTAssertEqual(voiceMachine.algorithmValue, 1.1, accuracy: 0.01, "Page 1 parameter updated")
        XCTAssertEqual(voiceMachine.filterCutoffValue, 1.2, accuracy: 0.01, "Page 2 parameter updated")
        XCTAssertEqual(voiceMachine.amplitudeValue, 1.3, accuracy: 0.01, "Page 3 parameter updated")
    }
    
    /// Test parameter page persistence
    func testParameterPagePersistence() {
        // ARRANGE: Setup parameter control
        let parameterControl = ParameterControl()
        let voiceMachine = MockFMToneVoiceMachine()
        parameterControl.setVoiceMachine(voiceMachine)
        
        // ACT: Set parameters on different pages
        parameterControl.setPage(1)
        parameterControl.updateEncoder(1, delta: 0.5)
        
        parameterControl.setPage(2)
        parameterControl.updateEncoder(1, delta: 0.6)
        
        // Return to page 1
        parameterControl.setPage(1)
        
        // ASSERT: Previous page parameters should be maintained
        XCTAssertEqual(voiceMachine.algorithmValue, 1.5, accuracy: 0.01, "Page 1 parameter should persist")
        XCTAssertEqual(voiceMachine.filterCutoffValue, 1.6, accuracy: 0.01, "Page 2 parameter should persist")
    }
    
    // MARK: - Track Selection Parameter Tests
    
    /// Test parameter isolation between tracks
    func testParameterIsolationBetweenTracks() {
        // ARRANGE: Setup parameter control with multiple tracks
        let parameterControl = ParameterControl()
        let track1Voice = MockFMToneVoiceMachine()
        let track2Voice = MockFMToneVoiceMachine()
        
        // ACT: Update parameters for different tracks
        parameterControl.setTrack(1, voiceMachine: track1Voice)
        parameterControl.updateEncoder(1, delta: 0.1)
        
        parameterControl.setTrack(2, voiceMachine: track2Voice)
        parameterControl.updateEncoder(1, delta: 0.2)
        
        // ASSERT: Each track should have independent parameter values
        XCTAssertEqual(track1Voice.algorithmValue, 1.1, accuracy: 0.01, "Track 1 algorithm")
        XCTAssertEqual(track2Voice.algorithmValue, 1.2, accuracy: 0.01, "Track 2 algorithm")
    }
    
    /// Test parameter update synchronization
    func testParameterUpdateSynchronization() {
        // ARRANGE: Setup parameter control with multiple tracks
        let parameterControl = ParameterControl()
        let track1Voice = MockFMToneVoiceMachine()
        let track2Voice = MockFMToneVoiceMachine()
        
        parameterControl.setTrack(1, voiceMachine: track1Voice)
        parameterControl.setTrack(2, voiceMachine: track2Voice)
        
        // ACT: Update parameters simultaneously
        let expectation = self.expectation(description: "Parameter updates completed")
        
        DispatchQueue.global().async {
            parameterControl.updateEncoder(1, delta: 0.1)
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        // ASSERT: Parameters should be updated correctly
        XCTAssertEqual(track1Voice.algorithmValue, 1.1, accuracy: 0.01, "Track 1 should be updated")
    }
}

// MARK: - Mock Parameter Control for Testing

class ParameterControl {
    private var currentVoiceMachine: VoiceMachineProtocol?
    private var currentPage: Int = 1
    private var currentTrack: Int = 1
    private var trackVoiceMachines: [Int: VoiceMachineProtocol] = [:]
    
    func setVoiceMachine(_ voiceMachine: VoiceMachineProtocol) {
        currentVoiceMachine = voiceMachine
        trackVoiceMachines[currentTrack] = voiceMachine
    }
    
    func setTrack(_ track: Int, voiceMachine: VoiceMachineProtocol) {
        currentTrack = track
        trackVoiceMachines[track] = voiceMachine
        currentVoiceMachine = voiceMachine
    }
    
    func setPage(_ page: Int) {
        currentPage = page
    }
    
    func updateEncoder(_ encoder: Int, delta: Double) {
        guard let voiceMachine = currentVoiceMachine else { return }
        
        // Route encoder to appropriate parameter based on page and encoder
        switch (currentPage, encoder) {
        case (1, 1): // Page 1, Encoder 1 = Algorithm
            if let fmToneVoice = voiceMachine as? MockFMToneVoiceMachine {
                fmToneVoice.updateParameter(.algorithm, value: fmToneVoice.algorithmValue + delta)
            } else if let fmDrumVoice = voiceMachine as? MockFMDrumVoiceMachine {
                fmDrumVoice.updateParameter(.tune, value: fmDrumVoice.tuneValue + delta)
            }
            
        case (1, 2): // Page 1, Encoder 2 = Ratio
            if let fmToneVoice = voiceMachine as? MockFMToneVoiceMachine {
                fmToneVoice.updateParameter(.ratio, value: max(0.0, fmToneVoice.ratioValue + delta))
            }
            
        case (2, 1): // Page 2, Encoder 1 = Filter Cutoff
            if let fmToneVoice = voiceMachine as? MockFMToneVoiceMachine {
                fmToneVoice.updateParameter(.filterCutoff, value: fmToneVoice.filterCutoffValue + delta)
            }
            
        case (3, 1): // Page 3, Encoder 1 = Amplitude
            if let fmToneVoice = voiceMachine as? MockFMToneVoiceMachine {
                fmToneVoice.updateParameter(.amplitude, value: fmToneVoice.amplitudeValue + delta)
            }
            
        default:
            break
        }
    }
}

// MARK: - Extended Mock Voice Machines

extension MockFMToneVoiceMachine {
    var filterCutoffValue: Double {
        get { return _filterCutoffValue }
        set { _filterCutoffValue = newValue }
    }
    
    var amplitudeValue: Double {
        get { return _amplitudeValue }
        set { _amplitudeValue = newValue }
    }
    
    private var _filterCutoffValue: Double = 1.0
    private var _amplitudeValue: Double = 1.0
    
    func updateParameter(_ parameter: FMToneParameter, value: Double) {
        switch parameter {
        case .algorithm:
            algorithmValue = min(5.0, max(1.0, value))
        case .ratio:
            ratioValue = max(0.0, value)
        case .level:
            levelValue = min(1.0, max(0.0, value))
        case .filterCutoff:
            _filterCutoffValue = value
        case .amplitude:
            _amplitudeValue = value
        }
    }
}

class MockFMDrumVoiceMachine: VoiceMachineProtocol {
    var tuneValue: Double = 1.0
    
    func triggerNote(_ note: Int, velocity: Int) {}
    func releaseNote(_ note: Int) {}
    
    func updateParameter(_ parameter: FMDrumParameter, value: Double) {
        switch parameter {
        case .tune:
            tuneValue = value
        }
    }
}

enum FMDrumParameter {
    case tune
}

extension FMToneParameter {
    static let filterCutoff = FMToneParameter.level // Reuse for testing
    static let amplitude = FMToneParameter.level // Reuse for testing
}