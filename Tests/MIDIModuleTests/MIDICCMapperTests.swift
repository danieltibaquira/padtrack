import XCTest
@testable import MIDIModule
@testable import VoiceModule
@testable import MachineProtocols

class MIDICCMapperTests: XCTestCase {
    var mapper: MIDICCMapper!
    var mockDelegate: MockCCMapperDelegate!
    
    override func setUp() {
        super.setUp()
        mapper = MIDICCMapper()
        mockDelegate = MockCCMapperDelegate()
        mapper.delegate = mockDelegate
    }
    
    override func tearDown() {
        mapper = nil
        mockDelegate = nil
        super.tearDown()
    }
    
    // MARK: - Basic CC Mapping Tests
    
    func testCCParameterMapping() {
        // Test CC messages correctly map to synthesis parameters
        let mockVoiceMachine = MockFMToneVoiceMachine()
        
        // Map CC 74 to filter cutoff
        mapper.mapCC(74, to: .filterCutoff, on: mockVoiceMachine, track: 1)
        
        // Send CC message
        let ccMessage = MIDIMessage.controlChange(channel: 1, controller: 74, value: 64)
        mapper.handleIncomingMessage(ccMessage, for: mockVoiceMachine)
        
        // Verify parameter was updated
        XCTAssertEqual(mockVoiceMachine.filterCutoff, 0.5, accuracy: 0.01)
    }
    
    func testMultipleCCMappings() {
        // Test multiple CC mappings on same voice machine
        let mockVoiceMachine = MockFMToneVoiceMachine()
        
        mapper.mapCC(74, to: .filterCutoff, on: mockVoiceMachine, track: 1)
        mapper.mapCC(71, to: .filterResonance, on: mockVoiceMachine, track: 1)
        mapper.mapCC(1, to: .lfoDepth, on: mockVoiceMachine, track: 1)
        
        // Send multiple CC messages
        mapper.handleIncomingMessage(MIDIMessage.controlChange(channel: 1, controller: 74, value: 100), for: mockVoiceMachine)
        mapper.handleIncomingMessage(MIDIMessage.controlChange(channel: 1, controller: 71, value: 80), for: mockVoiceMachine)
        mapper.handleIncomingMessage(MIDIMessage.controlChange(channel: 1, controller: 1, value: 32), for: mockVoiceMachine)
        
        XCTAssertEqual(mockVoiceMachine.filterCutoff, 0.787, accuracy: 0.01)
        XCTAssertEqual(mockVoiceMachine.filterResonance, 0.629, accuracy: 0.01)
        XCTAssertEqual(mockVoiceMachine.lfoDepth, 0.252, accuracy: 0.01)
    }
    
    func testCCRangeMapping() {
        // Test CC value range mapping to parameter ranges
        let mockVoiceMachine = MockFMToneVoiceMachine()
        
        mapper.mapCC(74, to: .filterCutoff, on: mockVoiceMachine, track: 1)
        
        // Test extreme values
        mapper.handleIncomingMessage(MIDIMessage.controlChange(channel: 1, controller: 74, value: 0), for: mockVoiceMachine)
        XCTAssertEqual(mockVoiceMachine.filterCutoff, 0.0, accuracy: 0.01)
        
        mapper.handleIncomingMessage(MIDIMessage.controlChange(channel: 1, controller: 74, value: 127), for: mockVoiceMachine)
        XCTAssertEqual(mockVoiceMachine.filterCutoff, 1.0, accuracy: 0.01)
    }
    
    // MARK: - MIDI Learn Tests
    
    func testMIDILearnFunctionality() {
        // Test MIDI Learn captures and maps controller input
        let mockVoiceMachine = MockFMToneVoiceMachine()
        
        // Start MIDI learn for algorithm parameter
        mapper.startMIDILearn(for: .algorithm, on: mockVoiceMachine, track: 1)
        XCTAssertTrue(mapper.isLearning)
        XCTAssertEqual(mapper.learningParameter, .algorithm)
        
        // Send CC message while learning
        let ccMessage = MIDIMessage.controlChange(channel: 1, controller: 16, value: 127)
        mapper.handleIncomingMessage(ccMessage, for: mockVoiceMachine)
        
        // Verify mapping was created
        XCTAssertFalse(mapper.isLearning)
        XCTAssertEqual(mapper.getMappedCC(for: .algorithm, track: 1), 16)
        
        // Verify delegate was notified
        XCTAssertTrue(mockDelegate.didLearnCCCalled)
        XCTAssertEqual(mockDelegate.learnedCC, 16)
        XCTAssertEqual(mockDelegate.learnedParameter, .algorithm)
    }
    
    func testMIDILearnCancellation() {
        // Test cancelling MIDI learn mode
        let mockVoiceMachine = MockFMToneVoiceMachine()
        
        mapper.startMIDILearn(for: .filterCutoff, on: mockVoiceMachine, track: 1)
        XCTAssertTrue(mapper.isLearning)
        
        mapper.cancelMIDILearn()
        XCTAssertFalse(mapper.isLearning)
        XCTAssertNil(mapper.learningParameter)
    }
    
    func testMIDILearnOverwrite() {
        // Test overwriting existing CC mapping with MIDI learn
        let mockVoiceMachine = MockFMToneVoiceMachine()
        
        // Create initial mapping
        mapper.mapCC(74, to: .filterCutoff, on: mockVoiceMachine, track: 1)
        
        // Start MIDI learn for same parameter
        mapper.startMIDILearn(for: .filterCutoff, on: mockVoiceMachine, track: 1)
        
        // Learn new CC
        mapper.handleIncomingMessage(MIDIMessage.controlChange(channel: 1, controller: 75, value: 64), for: mockVoiceMachine)
        
        // Verify old mapping was replaced
        XCTAssertNil(mapper.getMappedParameter(for: 74, track: 1))
        XCTAssertEqual(mapper.getMappedCC(for: .filterCutoff, track: 1), 75)
    }
    
    // MARK: - Persistence Tests
    
    func testCCMappingPersistence() {
        // Test CC mappings save/load correctly
        let mockVoiceMachine = MockFMToneVoiceMachine()
        
        // Create mappings
        mapper.mapCC(1, to: .lfoDepth, on: mockVoiceMachine, track: 1)
        mapper.mapCC(74, to: .filterCutoff, on: mockVoiceMachine, track: 1)
        mapper.mapCC(71, to: .filterResonance, on: mockVoiceMachine, track: 2)
        
        // Export mappings
        let savedMappings = mapper.exportMappings()
        
        // Create new mapper and import
        let newMapper = MIDICCMapper()
        newMapper.importMappings(savedMappings)
        
        // Verify mappings were restored
        XCTAssertEqual(newMapper.getMappedCC(for: .lfoDepth, track: 1), 1)
        XCTAssertEqual(newMapper.getMappedCC(for: .filterCutoff, track: 1), 74)
        XCTAssertEqual(newMapper.getMappedCC(for: .filterResonance, track: 2), 71)
    }
    
    func testMappingJSONExport() {
        // Test exporting mappings as JSON
        mapper.mapCC(74, to: .filterCutoff, on: nil, track: 1)
        mapper.mapCC(1, to: .lfoDepth, on: nil, track: 1)
        
        let jsonData = mapper.exportAsJSON()
        XCTAssertNotNil(jsonData)
        
        // Verify JSON structure
        if let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
            XCTAssertNotNil(json["mappings"])
            XCTAssertNotNil(json["version"])
        } else {
            XCTFail("Failed to parse exported JSON")
        }
    }
    
    // MARK: - Channel and Track Management Tests
    
    func testChannelSpecificMappings() {
        // Test CC mappings are channel-specific
        let mockVoiceMachine = MockFMToneVoiceMachine()
        
        mapper.mapCC(74, to: .filterCutoff, on: mockVoiceMachine, track: 1, channel: 1)
        mapper.mapCC(74, to: .filterResonance, on: mockVoiceMachine, track: 1, channel: 2)
        
        // Send CC on channel 1
        mapper.handleIncomingMessage(MIDIMessage.controlChange(channel: 1, controller: 74, value: 64), for: mockVoiceMachine)
        XCTAssertEqual(mockVoiceMachine.filterCutoff, 0.5, accuracy: 0.01)
        XCTAssertEqual(mockVoiceMachine.filterResonance, 0.0, accuracy: 0.01) // Should not change
        
        // Send CC on channel 2
        mockVoiceMachine.filterCutoff = 0.0 // Reset
        mapper.handleIncomingMessage(MIDIMessage.controlChange(channel: 2, controller: 74, value: 100), for: mockVoiceMachine)
        XCTAssertEqual(mockVoiceMachine.filterCutoff, 0.0, accuracy: 0.01) // Should not change
        XCTAssertEqual(mockVoiceMachine.filterResonance, 0.787, accuracy: 0.01)
    }
    
    func testTrackSpecificMappings() {
        // Test different tracks can have different mappings
        mapper.mapCC(74, to: .filterCutoff, on: nil, track: 1)
        mapper.mapCC(74, to: .filterResonance, on: nil, track: 2)
        mapper.mapCC(74, to: .lfoDepth, on: nil, track: 3)
        
        XCTAssertEqual(mapper.getMappedParameter(for: 74, track: 1), .filterCutoff)
        XCTAssertEqual(mapper.getMappedParameter(for: 74, track: 2), .filterResonance)
        XCTAssertEqual(mapper.getMappedParameter(for: 74, track: 3), .lfoDepth)
    }
    
    // MARK: - Parameter Validation Tests
    
    func testAllParametersMappable() {
        // Test every synthesizer parameter can be CC mapped
        let allParameters: [MIDIControllableParameter] = [
            .filterCutoff, .filterResonance, .filterEnvAmount,
            .lfoRate, .lfoDepth, .lfoShape,
            .ampAttack, .ampDecay, .ampSustain, .ampRelease,
            .algorithm, .feedback, .pitchBend,
            .operatorLevel(1), .operatorLevel(2), .operatorLevel(3), .operatorLevel(4),
            .operatorRatio(1), .operatorRatio(2), .operatorRatio(3), .operatorRatio(4),
            .operatorDetune(1), .operatorDetune(2), .operatorDetune(3), .operatorDetune(4)
        ]
        
        for (index, parameter) in allParameters.enumerated() {
            XCTAssertNoThrow(try mapper.validateAndMapCC(UInt8(index + 1), to: parameter, track: 1))
        }
    }
    
    func testInvalidCCRejection() {
        // Test mapper rejects invalid CC numbers
        XCTAssertThrows(try mapper.validateAndMapCC(128, to: .filterCutoff, track: 1)) // CC > 127
        XCTAssertThrows(try mapper.validateAndMapCC(255, to: .filterCutoff, track: 1))
    }
    
    // MARK: - Performance Tests
    
    func testHighThroughputCCProcessing() {
        // Test handling rapid CC input without issues
        let mockVoiceMachine = MockFMToneVoiceMachine()
        mapper.mapCC(74, to: .filterCutoff, on: mockVoiceMachine, track: 1)
        
        measure {
            for i in 0..<1000 {
                let value = UInt8(i % 128)
                mapper.handleIncomingMessage(MIDIMessage.controlChange(channel: 1, controller: 74, value: value), for: mockVoiceMachine)
            }
        }
        
        // Verify no messages were dropped
        XCTAssertEqual(mockDelegate.processedMessageCount, 1000)
        XCTAssertEqual(mockDelegate.droppedMessageCount, 0)
    }
    
    func testConcurrentCCAccess() {
        // Test thread safety of CC mapper
        let expectation = self.expectation(description: "Concurrent access")
        let mockVoiceMachine = MockFMToneVoiceMachine()
        
        mapper.mapCC(74, to: .filterCutoff, on: mockVoiceMachine, track: 1)
        
        DispatchQueue.concurrentPerform(iterations: 100) { i in
            mapper.handleIncomingMessage(MIDIMessage.controlChange(channel: 1, controller: 74, value: UInt8(i % 128)), for: mockVoiceMachine)
        }
        
        expectation.fulfill()
        
        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error)
        }
    }
}

// MARK: - Mock Objects

class MockCCMapperDelegate: MIDICCMapperDelegate {
    var didLearnCCCalled = false
    var learnedCC: UInt8?
    var learnedParameter: MIDIControllableParameter?
    var processedMessageCount = 0
    var droppedMessageCount = 0
    
    func ccMapper(_ mapper: MIDICCMapper, didLearnCC cc: UInt8, for parameter: MIDIControllableParameter) {
        didLearnCCCalled = true
        learnedCC = cc
        learnedParameter = parameter
    }
    
    func ccMapper(_ mapper: MIDICCMapper, processedMessage: MIDIMessage) {
        processedMessageCount += 1
    }
    
    func ccMapper(_ mapper: MIDICCMapper, droppedMessage: MIDIMessage) {
        droppedMessageCount += 1
    }
}

class MockFMToneVoiceMachine: VoiceMachineProtocol {
    var name: String = "Mock FM Tone"
    var voiceCount: Int = 1
    var activeVoices: Int = 0
    var polyphonyMode: PolyphonyMode = .monophonic
    
    // Parameters
    var filterCutoff: Float = 0.0
    var filterResonance: Float = 0.0
    var lfoDepth: Float = 0.0
    
    func renderAudio(into buffer: AudioBuffer, voiceIndex: Int, sampleCount: Int) {
        // Mock implementation
    }
    
    func noteOn(_ pitch: UInt8, velocity: UInt8, voiceIndex: Int, timestamp: TimeInterval) {
        // Mock implementation
    }
    
    func noteOff(_ pitch: UInt8, voiceIndex: Int, timestamp: TimeInterval) {
        // Mock implementation
    }
    
    func allNotesOff() {
        // Mock implementation
    }
    
    func setParameter(_ parameter: MIDIControllableParameter, value: Float) {
        switch parameter {
        case .filterCutoff:
            filterCutoff = value
        case .filterResonance:
            filterResonance = value
        case .lfoDepth:
            lfoDepth = value
        default:
            break
        }
    }
}

// MARK: - Test Helpers

extension MIDICCMapperTests {
    func XCTAssertThrows<T>(_ expression: @autoclosure () throws -> T, _ message: String = "") {
        do {
            _ = try expression()
            XCTFail(message.isEmpty ? "Expected error to be thrown" : message)
        } catch {
            // Success - error was thrown
        }
    }
}