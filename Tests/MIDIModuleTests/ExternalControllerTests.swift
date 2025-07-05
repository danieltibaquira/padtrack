import XCTest
@testable import MIDIModule
@testable import VoiceModule
@testable import MachineProtocols

class ExternalControllerTests: XCTestCase {
    var manager: ExternalControllerManager!
    var mockDelegate: MockControllerManagerDelegate!
    
    override func setUp() {
        super.setUp()
        manager = ExternalControllerManager()
        mockDelegate = MockControllerManagerDelegate()
        manager.delegate = mockDelegate
    }
    
    override func tearDown() {
        manager = nil
        mockDelegate = nil
        super.tearDown()
    }
    
    // MARK: - Controller Detection Tests
    
    func testControllerDetection() {
        // Test automatic detection of MIDI controllers
        let mockDevice = MockMIDIDevice(name: "LaunchPad Pro", manufacturer: "Novation")
        
        manager.addMIDIDevice(mockDevice)
        
        XCTAssertTrue(manager.detectedControllers.contains { $0.name == "LaunchPad Pro" })
        XCTAssertNotNil(manager.getPresetMapping(for: mockDevice))
        
        // Verify delegate was notified
        XCTAssertTrue(mockDelegate.didDetectControllerCalled)
        XCTAssertEqual(mockDelegate.detectedController?.name, "LaunchPad Pro")
    }
    
    func testMultipleControllerDetection() {
        // Test detecting multiple controllers
        let launchPad = MockMIDIDevice(name: "LaunchPad Pro", manufacturer: "Novation")
        let push = MockMIDIDevice(name: "Push 2", manufacturer: "Ableton")
        let keyLab = MockMIDIDevice(name: "KeyLab 61", manufacturer: "Arturia")
        
        manager.addMIDIDevice(launchPad)
        manager.addMIDIDevice(push)
        manager.addMIDIDevice(keyLab)
        
        XCTAssertEqual(manager.detectedControllers.count, 3)
        XCTAssertTrue(manager.detectedControllers.contains { $0.name == "LaunchPad Pro" })
        XCTAssertTrue(manager.detectedControllers.contains { $0.name == "Push 2" })
        XCTAssertTrue(manager.detectedControllers.contains { $0.name == "KeyLab 61" })
    }
    
    func testControllerRemoval() {
        // Test controller disconnection handling
        let mockDevice = MockMIDIDevice(name: "LaunchPad Pro", manufacturer: "Novation")
        
        manager.addMIDIDevice(mockDevice)
        XCTAssertEqual(manager.detectedControllers.count, 1)
        
        manager.removeMIDIDevice(mockDevice)
        XCTAssertEqual(manager.detectedControllers.count, 0)
        
        // Verify delegate was notified
        XCTAssertTrue(mockDelegate.didRemoveControllerCalled)
        XCTAssertEqual(mockDelegate.removedController?.name, "LaunchPad Pro")
    }
    
    // MARK: - Multi-Controller Support Tests
    
    func testMultiControllerSupport() {
        // Test handling multiple MIDI controllers simultaneously
        let device1 = MockMIDIDevice(name: "Controller 1", manufacturer: "Generic")
        let device2 = MockMIDIDevice(name: "Controller 2", manufacturer: "Generic")
        
        manager.addMIDIDevice(device1)
        manager.addMIDIDevice(device2)
        
        // Send CC from both devices simultaneously
        device1.sendCC(74, value: 64, channel: 1)
        device2.sendCC(75, value: 32, channel: 2)
        
        // Verify both messages processed correctly
        XCTAssertEqual(manager.getLastCCValue(74, channel: 1), 64)
        XCTAssertEqual(manager.getLastCCValue(75, channel: 2), 32)
    }
    
    func testControllerIsolation() {
        // Test that controllers don't interfere with each other
        let device1 = MockMIDIDevice(name: "Controller 1", manufacturer: "Generic")
        let device2 = MockMIDIDevice(name: "Controller 2", manufacturer: "Generic")
        
        manager.addMIDIDevice(device1)
        manager.addMIDIDevice(device2)
        
        // Configure different mappings for each controller
        manager.setControllerMapping(device1, mapping: .custom(channel: 1))
        manager.setControllerMapping(device2, mapping: .custom(channel: 2))
        
        // Send same CC from both devices
        device1.sendCC(74, value: 100, channel: 1)
        device2.sendCC(74, value: 50, channel: 2)
        
        // Verify isolation
        let device1Messages = manager.getMessagesFromDevice(device1)
        let device2Messages = manager.getMessagesFromDevice(device2)
        
        XCTAssertEqual(device1Messages.count, 1)
        XCTAssertEqual(device2Messages.count, 1)
        XCTAssertNotEqual(device1Messages.first?.value, device2Messages.first?.value)
    }
    
    // MARK: - Preset Mapping Tests
    
    func testLaunchPadProPresetMapping() {
        // Test LaunchPad Pro preset mapping
        let launchPad = MockMIDIDevice(name: "LaunchPad Pro", manufacturer: "Novation")
        manager.addMIDIDevice(launchPad)
        
        let mapping = manager.getPresetMapping(for: launchPad)
        XCTAssertNotNil(mapping)
        
        // Verify LaunchPad specific mappings
        if let launchPadMapping = mapping as? LaunchPadProMapping {
            // Test pad mappings
            XCTAssertEqual(launchPadMapping.padToNote(row: 0, column: 0), 60) // C4
            XCTAssertEqual(launchPadMapping.padToNote(row: 0, column: 1), 61) // C#4
            
            // Test side button mappings
            XCTAssertEqual(launchPadMapping.sideButtonCC(index: 0), 89)
            XCTAssertEqual(launchPadMapping.sideButtonCC(index: 7), 96)
        } else {
            XCTFail("Expected LaunchPadProMapping")
        }
    }
    
    func testPush2PresetMapping() {
        // Test Push 2 preset mapping
        let push = MockMIDIDevice(name: "Push 2", manufacturer: "Ableton")
        manager.addMIDIDevice(push)
        
        let mapping = manager.getPresetMapping(for: push)
        XCTAssertNotNil(mapping)
        
        if let pushMapping = mapping as? Push2Mapping {
            // Test encoder mappings
            XCTAssertEqual(pushMapping.encoderCC(index: 0), 71)
            XCTAssertEqual(pushMapping.encoderCC(index: 7), 78)
            
            // Test pad velocity curves
            XCTAssertEqual(pushMapping.velocityCurve, .linear)
        } else {
            XCTFail("Expected Push2Mapping")
        }
    }
    
    func testCustomControllerMapping() {
        // Test creating custom controller mappings
        let customDevice = MockMIDIDevice(name: "Custom Controller", manufacturer: "DIY")
        manager.addMIDIDevice(customDevice)
        
        // Create custom mapping
        let customMapping = CustomControllerMapping()
        customMapping.addPadMapping(note: 36, row: 0, column: 0)
        customMapping.addEncoderMapping(cc: 16, index: 0)
        customMapping.addSliderMapping(cc: 7, index: 0)
        
        manager.setControllerMapping(customDevice, mapping: customMapping)
        
        // Verify custom mapping is used
        let retrievedMapping = manager.getMapping(for: customDevice)
        XCTAssertTrue(retrievedMapping is CustomControllerMapping)
    }
    
    // MARK: - Message Routing Tests
    
    func testControllerMessageRouting() {
        // Test routing messages from controller to appropriate destination
        let controller = MockMIDIDevice(name: "Test Controller", manufacturer: "Test")
        manager.addMIDIDevice(controller)
        
        // Setup routing
        manager.routeController(controller, to: .track(1))
        
        // Send messages
        controller.sendNoteOn(60, velocity: 100, channel: 1)
        controller.sendCC(74, value: 64, channel: 1)
        
        // Verify routing
        let routedMessages = mockDelegate.routedMessages
        XCTAssertEqual(routedMessages.count, 2)
        XCTAssertEqual(routedMessages[0].destination, .track(1))
        XCTAssertEqual(routedMessages[1].destination, .track(1))
    }
    
    func testMultiDestinationRouting() {
        // Test routing single controller to multiple destinations
        let controller = MockMIDIDevice(name: "Test Controller", manufacturer: "Test")
        manager.addMIDIDevice(controller)
        
        // Setup multi-destination routing
        manager.routeController(controller, to: .track(1), for: .notes)
        manager.routeController(controller, to: .global, for: .cc)
        
        // Send different message types
        controller.sendNoteOn(60, velocity: 100, channel: 1)
        controller.sendCC(74, value: 64, channel: 1)
        
        // Verify routing
        let noteMessages = mockDelegate.routedMessages.filter { $0.type == .note }
        let ccMessages = mockDelegate.routedMessages.filter { $0.type == .cc }
        
        XCTAssertEqual(noteMessages.first?.destination, .track(1))
        XCTAssertEqual(ccMessages.first?.destination, .global)
    }
    
    // MARK: - Performance Tests
    
    func testHighThroughputControllerInput() {
        // Test handling rapid controller input
        let controller = MockMIDIDevice(name: "Performance Test Controller", manufacturer: "Test")
        manager.addMIDIDevice(controller)
        
        measure {
            for i in 0..<1000 {
                controller.sendCC(74, value: UInt8(i % 128), channel: 1)
            }
        }
        
        // Verify all messages were processed
        XCTAssertEqual(mockDelegate.processedMessageCount, 1000)
        XCTAssertEqual(mockDelegate.droppedMessageCount, 0)
    }
    
    func testControllerLatency() {
        // Test input latency from controller
        let controller = MockMIDIDevice(name: "Latency Test Controller", manufacturer: "Test")
        manager.addMIDIDevice(controller)
        
        let startTime = CACurrentMediaTime()
        controller.sendNoteOn(60, velocity: 127, channel: 1)
        
        // Wait for processing
        let expectation = self.expectation(description: "Message processed")
        mockDelegate.messageProcessedHandler = {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 0.1) { error in
            let endTime = CACurrentMediaTime()
            let latency = endTime - startTime
            
            // Verify latency is under 5ms
            XCTAssertLessThan(latency, 0.005, "Controller latency exceeds 5ms requirement")
        }
    }
    
    // MARK: - LED Feedback Tests
    
    func testControllerLEDFeedback() {
        // Test sending LED feedback to controllers
        let launchPad = MockMIDIDevice(name: "LaunchPad Pro", manufacturer: "Novation")
        manager.addMIDIDevice(launchPad)
        
        // Set pad LED color
        manager.setPadLED(row: 0, column: 0, color: .red, on: launchPad)
        
        // Verify MIDI message was sent
        let sentMessages = launchPad.sentMessages
        XCTAssertEqual(sentMessages.count, 1)
        
        if case .sysex(let data) = sentMessages.first {
            // Verify LaunchPad Pro sysex format
            XCTAssertEqual(data[0], 0xF0) // Sysex start
            XCTAssertEqual(data[1], 0x00) // Novation manufacturer ID
            XCTAssertEqual(data[2], 0x20)
            XCTAssertEqual(data[3], 0x29)
            XCTAssertEqual(data.last, 0xF7) // Sysex end
        } else {
            XCTFail("Expected sysex message for LED feedback")
        }
    }
    
    func testControllerButtonLEDSync() {
        // Test LED state synchronization with button presses
        let controller = MockMIDIDevice(name: "LED Controller", manufacturer: "Test")
        manager.addMIDIDevice(controller)
        
        // Enable auto LED sync
        manager.enableAutoLEDSync(for: controller)
        
        // Press button
        controller.sendNoteOn(36, velocity: 127, channel: 1)
        
        // Verify LED was turned on
        let ledMessages = controller.sentMessages.filter { message in
            if case .noteOn = message { return true }
            return false
        }
        XCTAssertEqual(ledMessages.count, 1)
    }
}

// MARK: - Mock Objects

class MockControllerManagerDelegate: ExternalControllerManagerDelegate {
    var didDetectControllerCalled = false
    var detectedController: ExternalController?
    var didRemoveControllerCalled = false
    var removedController: ExternalController?
    var routedMessages: [(message: MIDIMessage, destination: RoutingDestination, type: MessageType)] = []
    var processedMessageCount = 0
    var droppedMessageCount = 0
    var messageProcessedHandler: (() -> Void)?
    
    enum MessageType {
        case note, cc, other
    }
    
    enum RoutingDestination: Equatable {
        case track(Int)
        case global
    }
    
    func controllerManager(_ manager: ExternalControllerManager, didDetectController controller: ExternalController) {
        didDetectControllerCalled = true
        detectedController = controller
    }
    
    func controllerManager(_ manager: ExternalControllerManager, didRemoveController controller: ExternalController) {
        didRemoveControllerCalled = true
        removedController = controller
    }
    
    func controllerManager(_ manager: ExternalControllerManager, routedMessage message: MIDIMessage, to destination: RoutingDestination) {
        let type: MessageType
        switch message {
        case .noteOn, .noteOff:
            type = .note
        case .controlChange:
            type = .cc
        default:
            type = .other
        }
        
        routedMessages.append((message: message, destination: destination, type: type))
        processedMessageCount += 1
        messageProcessedHandler?()
    }
    
    func controllerManager(_ manager: ExternalControllerManager, droppedMessage: MIDIMessage) {
        droppedMessageCount += 1
    }
}

class MockMIDIDevice: MIDIDeviceProtocol {
    let name: String
    let manufacturer: String
    var isConnected: Bool = true
    var sentMessages: [MIDIMessage] = []
    weak var delegate: MIDIDeviceDelegate?
    
    init(name: String, manufacturer: String) {
        self.name = name
        self.manufacturer = manufacturer
    }
    
    func sendCC(_ cc: UInt8, value: UInt8, channel: UInt8) {
        let message = MIDIMessage.controlChange(channel: channel, controller: cc, value: value)
        delegate?.midiDevice(self, receivedMessage: message)
    }
    
    func sendNoteOn(_ note: UInt8, velocity: UInt8, channel: UInt8) {
        let message = MIDIMessage.noteOn(channel: channel, note: note, velocity: velocity)
        delegate?.midiDevice(self, receivedMessage: message)
    }
    
    func sendNoteOff(_ note: UInt8, channel: UInt8) {
        let message = MIDIMessage.noteOff(channel: channel, note: note, velocity: 0)
        delegate?.midiDevice(self, receivedMessage: message)
    }
    
    func send(_ message: MIDIMessage) {
        sentMessages.append(message)
    }
}

// MARK: - Mock Controller Mappings

class LaunchPadProMapping: ControllerMapping {
    func padToNote(row: Int, column: Int) -> UInt8 {
        // LaunchPad Pro note layout
        return UInt8(60 + (row * 8) + column)
    }
    
    func sideButtonCC(index: Int) -> UInt8 {
        // Side button CCs
        return UInt8(89 + index)
    }
}

class Push2Mapping: ControllerMapping {
    let velocityCurve: VelocityCurve = .linear
    
    func encoderCC(index: Int) -> UInt8 {
        return UInt8(71 + index)
    }
}

class CustomControllerMapping: ControllerMapping {
    private var padMappings: [String: UInt8] = [:]
    private var encoderMappings: [Int: UInt8] = [:]
    private var sliderMappings: [Int: UInt8] = [:]
    
    func addPadMapping(note: UInt8, row: Int, column: Int) {
        padMappings["\(row)-\(column)"] = note
    }
    
    func addEncoderMapping(cc: UInt8, index: Int) {
        encoderMappings[index] = cc
    }
    
    func addSliderMapping(cc: UInt8, index: Int) {
        sliderMappings[index] = cc
    }
}

// MARK: - Test Enums

enum VelocityCurve {
    case linear
    case exponential
    case logarithmic
}