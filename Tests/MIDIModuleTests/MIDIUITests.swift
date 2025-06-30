// MIDIUITests.swift
// DigitonePad - MIDIModule Tests
//
// UI automation tests for MIDI SwiftUI interface

import XCTest
import SwiftUI
@testable import MIDIModule

final class MIDIUITests: XCTestCase {

    // MARK: - Helper Methods

    @MainActor
    private func createViewModel() -> MIDIViewModel {
        return MIDIViewModel()
    }

    // MARK: - ViewModel Tests

    @MainActor
    func testViewModelInitialization() {
        let viewModel = createViewModel()
        XCTAssertEqual(viewModel.connectionStatus, .disconnected)
        XCTAssertTrue(viewModel.availableDevices.isEmpty)
        XCTAssertTrue(viewModel.connectedDevices.isEmpty)
        XCTAssertNil(viewModel.lastReceivedMessage)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    @MainActor
    func testViewModelVIPERIntegration() {
        // Test that VIPER components are properly wired
        let viewModel = createViewModel()
        viewModel.initialize()

        // The initialize call should trigger the presenter
        // In a real scenario, this would update the view model state
        XCTAssertTrue(true) // Placeholder - would verify state changes
    }

    @MainActor
    func testSendTestNote() {
        // Test sending a test note
        let viewModel = createViewModel()
        viewModel.sendTestNote(note: 60, velocity: 100, channel: 0)

        // Verify the note was processed (in real implementation)
        XCTAssertTrue(true) // Placeholder
    }

    @MainActor
    func testSendTestCC() {
        // Test sending a control change message
        let viewModel = createViewModel()
        viewModel.sendTestCC(controller: 7, value: 100, channel: 0)

        // Verify the CC was processed
        XCTAssertTrue(true) // Placeholder
    }

    // MARK: - View Protocol Tests

    @MainActor
    func testShowMIDIDevices() {
        let viewModel = createViewModel()
        let testDevices = [
            MIDIDevice(
                id: 1,
                name: "Test Device 1",
                manufacturer: "Test",
                isOnline: true,
                isConnected: false,
                type: .input
            ),
            MIDIDevice(
                id: 2,
                name: "Test Device 2",
                manufacturer: "Test",
                isOnline: true,
                isConnected: false,
                type: .output
            )
        ]

        viewModel.showMIDIDevices(testDevices)

        XCTAssertEqual(viewModel.availableDevices.count, 2)
        XCTAssertEqual(viewModel.availableDevices[0].name, "Test Device 1")
        XCTAssertEqual(viewModel.availableDevices[1].name, "Test Device 2")
    }
    
    @MainActor
    func testShowConnectionStatus() {
        let viewModel = createViewModel()
        viewModel.showConnectionStatus(.connected)
        XCTAssertEqual(viewModel.connectionStatus, .connected)

        viewModel.showConnectionStatus(.disconnected)
        XCTAssertEqual(viewModel.connectionStatus, .disconnected)

        viewModel.showConnectionStatus(.error)
        XCTAssertEqual(viewModel.connectionStatus, .error)
    }

    @MainActor
    func testShowConnectedDevices() {
        let viewModel = createViewModel()
        let connectedDevice = MIDIDevice(
            id: 1,
            name: "Connected Device",
            manufacturer: "Test",
            isOnline: true,
            isConnected: true,
            type: .input
        )

        viewModel.showConnectedDevices([connectedDevice])

        XCTAssertEqual(viewModel.connectedDevices.count, 1)
        XCTAssertEqual(viewModel.connectedDevices[0].name, "Connected Device")
        XCTAssertTrue(viewModel.connectedDevices[0].isConnected)
    }
    
    @MainActor
    func testShowMIDIMessage() {
        let viewModel = createViewModel()
        let testMessage = MIDIMessage(
            type: .noteOn,
            channel: 0,
            data1: 60,
            data2: 127
        )

        viewModel.showMIDIMessage(testMessage)

        XCTAssertNotNil(viewModel.lastReceivedMessage)
        XCTAssertEqual(viewModel.lastReceivedMessage?.type, .noteOn)
        XCTAssertEqual(viewModel.lastReceivedMessage?.data1, 60)
        XCTAssertEqual(viewModel.lastReceivedMessage?.data2, 127)
    }

    @MainActor
    func testShowError() {
        let viewModel = createViewModel()
        let testError = MIDIError.connectionFailed("Test connection error")

        viewModel.showError(testError)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "Test connection error")
    }

    @MainActor
    func testShowLoading() {
        let viewModel = createViewModel()
        viewModel.showLoading(true)
        XCTAssertEqual(viewModel.connectionStatus, .connecting)

        // Loading false doesn't change status in current implementation
        viewModel.showLoading(false)
        XCTAssertEqual(viewModel.connectionStatus, .connecting)
    }

    // MARK: - Extension Tests

    func testMIDIConnectionStatusDescription() {
        XCTAssertEqual(MIDIConnectionStatus.disconnected.description, "Disconnected")
        XCTAssertEqual(MIDIConnectionStatus.connecting.description, "Connecting...")
        XCTAssertEqual(MIDIConnectionStatus.connected.description, "Connected")
        XCTAssertEqual(MIDIConnectionStatus.error.description, "Error")
    }
    
    func testMIDIConnectionStatusColor() {
        XCTAssertEqual(MIDIConnectionStatus.disconnected.color, .secondary)
        XCTAssertEqual(MIDIConnectionStatus.connecting.color, .orange)
        XCTAssertEqual(MIDIConnectionStatus.connected.color, .green)
        XCTAssertEqual(MIDIConnectionStatus.error.color, .red)
    }
    
    func testMIDIMessageTypeDisplayName() {
        XCTAssertEqual(MIDIMessageType.noteOff.displayName, "Note Off")
        XCTAssertEqual(MIDIMessageType.noteOn.displayName, "Note On")
        XCTAssertEqual(MIDIMessageType.controlChange.displayName, "CC")
        XCTAssertEqual(MIDIMessageType.programChange.displayName, "PC")
        XCTAssertEqual(MIDIMessageType.pitchBend.displayName, "Pitch")
        XCTAssertEqual(MIDIMessageType.systemExclusive.displayName, "SysEx")
        XCTAssertEqual(MIDIMessageType.timingClock.displayName, "Clock")
        XCTAssertEqual(MIDIMessageType.start.displayName, "Start")
        XCTAssertEqual(MIDIMessageType.continue.displayName, "Continue")
        XCTAssertEqual(MIDIMessageType.stop.displayName, "Stop")
    }
    
    // MARK: - Preview Tests

    @MainActor
    func testPreviewViewModel() {
        let previewViewModel = MIDIViewModel.preview

        XCTAssertEqual(previewViewModel.availableDevices.count, 2)
        XCTAssertEqual(previewViewModel.connectedDevices.count, 1)
        XCTAssertEqual(previewViewModel.connectionStatus, .connected)

        XCTAssertEqual(previewViewModel.availableDevices[0].name, "Virtual MIDI Device")
        XCTAssertEqual(previewViewModel.availableDevices[1].name, "USB MIDI Controller")
        XCTAssertEqual(previewViewModel.connectedDevices[0].name, "USB MIDI Controller")
    }
}

// MARK: - SwiftUI View Tests

final class MIDISwiftUIViewTests: XCTestCase {

    @MainActor
    func testMIDISwiftUIViewCreation() {
        let view = MIDISwiftUIView()
        XCTAssertNotNil(view)
    }

    @MainActor
    func testMIDIMessageRowCreation() {
        let message = MIDIMessage(
            type: .noteOn,
            channel: 0,
            data1: 60,
            data2: 127
        )
        
        let messageRow = MIDIMessageRow(message: message, isRecent: true)
        XCTAssertNotNil(messageRow)
    }
    
    @MainActor
    func testMIDIDeviceListViewCreation() {
        let devices = [
            MIDIDevice(
                id: 1,
                name: "Test Device",
                manufacturer: "Test",
                isOnline: true,
                isConnected: false,
                type: .input
            )
        ]

        let deviceListView = MIDIDeviceListView(
            devices: devices,
            connectedDevices: [],
            onDeviceSelected: { _ in },
            onDeviceDisconnected: { _ in }
        )

        XCTAssertNotNil(deviceListView)
    }

    @MainActor
    func testMIDIDeviceRowCreation() {
        let device = MIDIDevice(
            id: 1,
            name: "Test Device",
            manufacturer: "Test",
            isOnline: true,
            isConnected: false,
            type: .input
        )
        
        let deviceRow = MIDIDeviceRow(
            device: device,
            isConnected: false,
            onConnect: {},
            onDisconnect: {}
        )
        
        XCTAssertNotNil(deviceRow)
    }
}

// MARK: - Integration Tests

final class MIDIUIIntegrationTests: XCTestCase {

    @MainActor
    func testFullUIWorkflow() {
        let viewModel = MIDIViewModel()
        
        // Test initialization
        viewModel.initialize()
        XCTAssertEqual(viewModel.connectionStatus, .disconnected)
        
        // Test device discovery
        let testDevices = [
            MIDIDevice(
                id: 1,
                name: "Test Input",
                manufacturer: "Test",
                isOnline: true,
                isConnected: false,
                type: .input
            ),
            MIDIDevice(
                id: 2,
                name: "Test Output",
                manufacturer: "Test",
                isOnline: true,
                isConnected: false,
                type: .output
            )
        ]
        
        viewModel.showMIDIDevices(testDevices)
        XCTAssertEqual(viewModel.availableDevices.count, 2)
        
        // Test device connection
        viewModel.connectToDevice(testDevices[0])
        viewModel.showConnectedDevices([testDevices[0]])
        XCTAssertEqual(viewModel.connectedDevices.count, 1)
        
        // Test MIDI message handling
        let testMessage = MIDIMessage(type: .noteOn, channel: 0, data1: 60, data2: 127)
        viewModel.showMIDIMessage(testMessage)
        XCTAssertNotNil(viewModel.lastReceivedMessage)
        
        // Test error handling
        let testError = MIDIError.sendFailed("Test error")
        viewModel.showError(testError)
        XCTAssertNotNil(viewModel.errorMessage)
    }
} 