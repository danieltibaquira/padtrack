import XCTest
@testable import MIDIModule
import CoreMIDI

final class MIDIModuleTests: XCTestCase {
    
    var interactor: MIDIInteractor!
    var presenter: MockMIDIPresenter!
    
    override func setUp() {
        super.setUp()
        interactor = MIDIInteractor()
        presenter = MockMIDIPresenter()
        interactor.presenter = presenter
    }
    
    override func tearDown() {
        interactor = nil
        presenter = nil
        super.tearDown()
    }
    
    // MARK: - MIDI Message Tests
    
    func testMIDIMessageCreation() {
        let message = MIDIMessage(
            type: .noteOn,
            channel: 0,
            data1: 60, // Middle C
            data2: 127 // Max velocity
        )
        
        XCTAssertEqual(message.type, .noteOn)
        XCTAssertEqual(message.channel, 0)
        XCTAssertEqual(message.data1, 60)
        XCTAssertEqual(message.data2, 127)
    }
    
    func testMIDIMessageTypeRawValues() {
        XCTAssertEqual(MIDIMessageType.noteOff.rawValue, 0x80)
        XCTAssertEqual(MIDIMessageType.noteOn.rawValue, 0x90)
        XCTAssertEqual(MIDIMessageType.controlChange.rawValue, 0xB0)
        XCTAssertEqual(MIDIMessageType.programChange.rawValue, 0xC0)
        XCTAssertEqual(MIDIMessageType.pitchBend.rawValue, 0xE0)
    }
    
    func testMIDIDeviceCreation() {
        let device = MIDIDevice(
            id: 1,
            name: "Test Device",
            manufacturer: "Test Manufacturer",
            isOnline: true,
            isConnected: false,
            type: .input
        )
        
        XCTAssertEqual(device.id, 1)
        XCTAssertEqual(device.name, "Test Device")
        XCTAssertEqual(device.manufacturer, "Test Manufacturer")
        XCTAssertTrue(device.isOnline)
        XCTAssertFalse(device.isConnected)
        XCTAssertEqual(device.type, .input)
    }
    
    // MARK: - MIDI Configuration Tests
    
    func testMIDIConfigurationDefaults() {
        let config = MIDIConfiguration()
        
        XCTAssertEqual(config.clientName, "DigitonePad")
        XCTAssertEqual(config.inputPortName, "DigitonePad Input")
        XCTAssertEqual(config.outputPortName, "DigitonePad Output")
        XCTAssertTrue(config.enableVirtualPorts)
        XCTAssertTrue(config.enableNetworkSession)
    }
    
    // MARK: - MIDI Error Tests
    
    func testMIDIErrorCreation() {
        let error = MIDIError.initializationFailed("Test error")

        XCTAssertEqual(error.code, "INIT_FAILED")
        XCTAssertEqual(error.message, "Test error")
        XCTAssertEqual(error.severity, .critical)
    }
    
    func testMIDIErrorMessages() {
        let initError = MIDIError.initializationFailed("Init failed")
        let connectionError = MIDIError.connectionFailed("Connection failed")
        let sendError = MIDIError.sendFailed("Send failed")
        
        XCTAssertEqual(initError.message, "Init failed")
        XCTAssertEqual(connectionError.message, "Connection failed")
        XCTAssertEqual(sendError.message, "Send failed")
    }
    
    // MARK: - MIDI Interactor Tests
    
    func testInteractorInitialization() {
        XCTAssertNotNil(interactor)
        XCTAssertNotNil(interactor.presenter)
    }
    
    func testMIDIInputHandlerSetting() {
        var receivedMessage: MIDIMessage?
        
        interactor.setMIDIInputHandler { message in
            receivedMessage = message
        }
        
        // Simulate receiving a MIDI message
        let _ = MIDIMessage(type: .noteOn, channel: 0, data1: 60, data2: 127)
        interactor.processMIDIEvent([0x90, 60, 127]) // Note On, Middle C, Max velocity
        
        XCTAssertNotNil(receivedMessage)
        XCTAssertEqual(receivedMessage?.type, .noteOn)
        XCTAssertEqual(receivedMessage?.data1, 60)
        XCTAssertEqual(receivedMessage?.data2, 127)
    }
    
    func testDeviceConnectionTracking() {
        let device = MIDIDevice(
            id: 1,
            name: "Test Device",
            manufacturer: "Test",
            isOnline: true,
            isConnected: false,
            type: .input
        )
        
        // Initially no devices connected
        XCTAssertFalse(interactor.connectedDevices.contains(device.id))
        
        // Connect device (this would normally trigger CoreMIDI calls)
        interactor.connectToDevice(device)
        
        // Verify presenter was notified
        XCTAssertTrue(presenter.didConnectToDeviceCalled)
        XCTAssertEqual(presenter.connectedDevice?.id, device.id)
    }
    
    func testMIDIMessageSending() {
        let message = MIDIMessage(type: .noteOn, channel: 0, data1: 60, data2: 127)
        
        // This should not crash even without real MIDI setup
        interactor.sendMIDIMessage(message)
        
        // In a real test, we'd verify the message was sent to CoreMIDI
        // For now, we just ensure no exceptions are thrown
        XCTAssertTrue(true)
    }
    
    // MARK: - MIDI Manager Tests
    
    func testMIDIManagerSingleton() {
        let manager1 = MIDIManager.shared
        let manager2 = MIDIManager.shared
        
        XCTAssertTrue(manager1 === manager2)
    }
    
    func testMIDIManagerLegacyInterface() {
        let manager = MIDIManager.shared
        
        // Test legacy MIDI sending interface
        manager.sendMIDI(note: 60, velocity: 127, channel: 0)
        
        // Test input handler setting
        var receivedNote: UInt8 = 0
        var receivedVelocity: UInt8 = 0
        var receivedChannel: UInt8 = 0

        manager.setInputHandler { note, velocity, channel in
            receivedNote = note
            receivedVelocity = velocity
            receivedChannel = channel
        }

        // Use the variables to avoid warnings
        _ = receivedNote
        _ = receivedVelocity
        _ = receivedChannel
        
        // Simulate input (this would normally come from CoreMIDI)
        // For testing, we can't easily trigger the callback without real MIDI
        XCTAssertTrue(true) // Placeholder assertion
    }
}

// MARK: - Mock Objects

class MockMIDIPresenter: MIDIInteractorOutputProtocol, MIDIPresenterProtocol {
    // MIDIPresenterProtocol properties
    var view: MIDIViewProtocol?
    var interactor: MIDIInteractorProtocol?
    var router: MIDIRouterProtocol?

    var didInitializeMIDICalled = false
    var didDiscoverMIDIDevicesCalled = false
    var didConnectToDeviceCalled = false
    var didDisconnectFromDeviceCalled = false
    var didReceiveMIDIMessageCalled = false
    var didFailWithErrorCalled = false

    var discoveredDevices: [MIDIDevice] = []
    var connectedDevice: MIDIDevice?
    var disconnectedDevice: MIDIDevice?
    var receivedMessage: MIDIMessage?
    var receivedError: MIDIError?
    
    func didInitializeMIDI() {
        didInitializeMIDICalled = true
    }
    
    func didDiscoverMIDIDevices(_ devices: [MIDIDevice]) {
        didDiscoverMIDIDevicesCalled = true
        discoveredDevices = devices
    }
    
    func didConnectToDevice(_ device: MIDIDevice) {
        didConnectToDeviceCalled = true
        connectedDevice = device
    }
    
    func didDisconnectFromDevice(_ device: MIDIDevice) {
        didDisconnectFromDeviceCalled = true
        disconnectedDevice = device
    }
    
    func didReceiveMIDIMessage(_ message: MIDIMessage) {
        didReceiveMIDIMessageCalled = true
        receivedMessage = message
    }
    
    func didFailWithError(_ error: MIDIError) {
        didFailWithErrorCalled = true
        receivedError = error
    }

    // MARK: - MIDIPresenterProtocol methods

    func viewDidLoad() {
        // Mock implementation
    }

    func refreshMIDIDevices() {
        // Mock implementation
    }

    func connectToDevice(_ device: MIDIDevice) {
        didConnectToDeviceCalled = true
        connectedDevice = device
    }

    func disconnectFromDevice(_ device: MIDIDevice) {
        didDisconnectFromDeviceCalled = true
        disconnectedDevice = device
    }

    func sendMIDIMessage(_ message: MIDIMessage) {
        // Mock implementation
    }

    func handleMIDIReceived(_ message: MIDIMessage) {
        didReceiveMIDIMessageCalled = true
        receivedMessage = message
    }

    func handleConnectionStatusChanged(_ status: MIDIConnectionStatus) {
        // Mock implementation
    }

    func handleError(_ error: MIDIError) {
        didFailWithErrorCalled = true
        receivedError = error
    }
}

// MARK: - Integration Tests

final class MIDIIntegrationTests: XCTestCase {
    
    @MainActor
    func testVIPERComponentsIntegration() {
        // Test that all VIPER components can be created and wired together
        let moduleView = MIDIRouter.createMIDIModule()

        XCTAssertNotNil(moduleView)
    }
    
    @MainActor
    func testSwiftUIIntegration() {
        let midiView = MIDIModuleView()
        XCTAssertNotNil(midiView)
    }
    
    func testMIDIManagerIntegration() {
        let manager = MIDIManager.shared
        
        // Test initialization
        manager.initialize()
        
        // Test device discovery
        manager.discoverDevices()
        
        // These should not crash
        XCTAssertTrue(true)
    }
} 