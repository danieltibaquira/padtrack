// MIDIViewModel.swift
// DigitonePad - MIDIModule
//
// SwiftUI ViewModel for MIDI interface

import SwiftUI
import Combine
import MachineProtocols

/// SwiftUI ViewModel that bridges to the VIPER architecture
@MainActor
public class MIDIViewModel: ObservableObject, MIDIViewProtocol {
    
    // MARK: - Published Properties
    
    @Published public var availableDevices: [MIDIDevice] = []
    @Published public var connectedDevices: [MIDIDevice] = []
    @Published public var connectionStatus: MIDIConnectionStatus = .disconnected
    @Published public var lastMIDIMessage: MIDIMessage?
    @Published public var errorMessage: String?
    @Published public var isShowingError: Bool = false
    @Published public var lastReceivedMessage: MIDIMessage?
    
    // MARK: - VIPER Properties
    
    private var _presenter: MIDIPresenter?
    
    public var presenter: MIDIPresenterProtocol? {
        get { return _presenter }
        set { _presenter = newValue as? MIDIPresenter }
    }
    
    // MARK: - Initialization
    
    public init() {
        setupVIPER()
    }
    
    private func setupVIPER() {
        let presenter = MIDIPresenter()
        let interactor = MockMIDIInteractor()
        let router = MIDIRouter()
        
        presenter.view = self
        presenter.interactor = interactor
        presenter.router = router
        
        interactor.presenter = presenter
        
        self._presenter = presenter
    }
    
    // MARK: - Public Methods
    
    public func initialize() {
        presenter?.viewDidLoad()
    }
    
    public func discoverDevices() {
        presenter?.refreshMIDIDevices()
    }
    
    public func connect(to device: MIDIDevice) {
        presenter?.connectToDevice(device)
    }
    
    public func disconnect(from device: MIDIDevice) {
        presenter?.disconnectFromDevice(device)
    }
    
    public func sendMessage(_ message: MIDIMessage) {
        presenter?.sendMIDIMessage(message)
    }
    
    public func clearError() {
        errorMessage = nil
        isShowingError = false
    }
    
    // MARK: - Test Methods
    
    public func sendTestNote(note: UInt8, velocity: UInt8 = 100, channel: UInt8 = 0) {
        let message = MIDIMessage(
            type: .noteOn,
            channel: channel,
            data1: note,
            data2: velocity,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000)
        )
        sendMessage(message)
    }
    
    public func sendTestCC(controller: UInt8, value: UInt8, channel: UInt8 = 0) {
        let message = MIDIMessage(
            type: .controlChange,
            channel: channel,
            data1: controller,
            data2: value,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000)
        )
        sendMessage(message)
    }
    
    // MARK: - MIDIViewProtocol Implementation
    
    public func showMIDIDevices(_ devices: [MIDIDevice]) {
        availableDevices = devices
    }
    
    public func showMIDIConnection(status: MIDIConnectionStatus) {
        connectionStatus = status
        
        // Update connected devices based on status
        if status == .connected {
            // This would typically come from the actual connection event
            // For now, we'll keep the connected devices as is
        } else if status == .disconnected {
            connectedDevices.removeAll()
        }
    }
    
    public func showMIDIActivity(message: MIDIMessage) {
        lastMIDIMessage = message
        lastReceivedMessage = message
    }
    
    public func showError(_ error: MIDIError) {
        errorMessage = error.message
        isShowingError = true
    }

    // MARK: - Additional Methods for Tests

    public func showConnectionStatus(_ status: MIDIConnectionStatus) {
        connectionStatus = status
    }

    public func showConnectedDevices(_ devices: [MIDIDevice]) {
        connectedDevices = devices
    }

    public func showMIDIMessage(_ message: MIDIMessage) {
        lastReceivedMessage = message
        lastMIDIMessage = message
    }

    public func showLoading(_ isLoading: Bool) {
        if isLoading {
            connectionStatus = .connecting
        }
    }

    public func connectToDevice(_ device: MIDIDevice) {
        presenter?.connectToDevice(device)
    }
}

// MARK: - Mock Interactor for Preview/Testing

public class MockMIDIInteractor: MIDIInteractorProtocol {
    public weak var presenter: MIDIPresenterProtocol?
    
    public func getAvailableDevices() async throws -> [MIDIDevice] {
        // Mock implementation
        return [
            MIDIDevice(id: 1, name: "Virtual MIDI Device", manufacturer: "Apple", isOnline: true, isConnected: false, connectionDirection: .virtual),
            MIDIDevice(id: 2, name: "USB MIDI Device", manufacturer: "Generic", isOnline: true, isConnected: false, connectionDirection: .bidirectional)
        ]
    }
    
    public func establishConnection(to device: MIDIDevice) async throws {
        // Mock implementation
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    public func terminateConnection(from device: MIDIDevice) async throws {
        // Mock implementation
    }
    
    public func transmitMIDI(_ message: MIDIMessage) async throws {
        // Mock implementation
    }
    
    public func startListening() async throws {
        // Mock implementation
    }
    
    public func stopListening() async throws {
        // Mock implementation
    }
}

// MARK: - Preview Support

extension MIDIViewModel {
    public static func createPreview() -> MIDIViewModel {
        let viewModel = MIDIViewModel()

        // Mock some data for preview
        viewModel.availableDevices = [
            MIDIDevice(id: 1, name: "Virtual MIDI Device", manufacturer: "Apple", isOnline: true, isConnected: false, connectionDirection: .virtual),
            MIDIDevice(id: 2, name: "USB MIDI Device", manufacturer: "Generic", isOnline: true, isConnected: false, connectionDirection: .bidirectional),
            MIDIDevice(id: 3, name: "Digitone", manufacturer: "Elektron", isOnline: true, isConnected: true, connectionDirection: .bidirectional)
        ]

        viewModel.connectionStatus = .connected

        return viewModel
    }

    public static var preview: MIDIViewModel {
        let viewModel = MIDIViewModel()

        // Mock data for tests
        viewModel.availableDevices = [
            MIDIDevice(id: 1, name: "Virtual MIDI Device", manufacturer: "Apple", isOnline: true, isConnected: false, connectionDirection: .virtual),
            MIDIDevice(id: 2, name: "USB MIDI Controller", manufacturer: "Generic", isOnline: true, isConnected: true, connectionDirection: .bidirectional)
        ]

        viewModel.connectedDevices = [
            MIDIDevice(id: 2, name: "USB MIDI Controller", manufacturer: "Generic", isOnline: true, isConnected: true, connectionDirection: .bidirectional)
        ]

        viewModel.connectionStatus = .connected

        return viewModel
    }
}