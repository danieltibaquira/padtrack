// MIDIModuleProtocols.swift
// DigitonePad - MIDIModule
//
// VIPER architecture protocols for MIDI functionality

import Foundation
import CoreMIDI
import MachineProtocols

// MARK: - VIPER Protocols

/// View protocol for MIDI UI components
public protocol MIDIViewProtocol: AnyObject {
    var presenter: MIDIPresenterProtocol? { get set }
    
    @MainActor func showMIDIDevices(_ devices: [MIDIDevice])
    @MainActor func showMIDIConnection(status: MIDIConnectionStatus)
    @MainActor func showMIDIActivity(message: MIDIMessage)
    @MainActor func showError(_ error: MIDIError)
}

/// Presenter protocol for MIDI presentation logic
public protocol MIDIPresenterProtocol: AnyObject {
    var view: MIDIViewProtocol? { get set }
    var interactor: MIDIInteractorProtocol? { get set }
    var router: MIDIRouterProtocol? { get set }
    
    func viewDidLoad()
    func refreshMIDIDevices()
    func connectToDevice(_ device: MIDIDevice)
    func disconnectFromDevice(_ device: MIDIDevice)
    func sendMIDIMessage(_ message: MIDIMessage)
    func handleMIDIReceived(_ message: MIDIMessage)
    func handleConnectionStatusChanged(_ status: MIDIConnectionStatus)
    func handleError(_ error: MIDIError)
}

/// Interactor input protocol for MIDI business logic
public protocol MIDIInteractorInputProtocol: AnyObject {
    var outputPresenter: MIDIInteractorOutputProtocol? { get set }
    
    func initialize()
    func discoverMIDIDevices()
    func connectToDevice(_ device: MIDIDevice)
    func disconnectFromDevice(_ device: MIDIDevice)
    func sendMIDIMessage(_ message: MIDIMessage)
    func setMIDIInputHandler(_ handler: @escaping (MIDIMessage) -> Void)
}

/// Interactor output protocol for communicating back to presenter
public protocol MIDIInteractorOutputProtocol: AnyObject {
    func didInitializeMIDI()
    func didDiscoverMIDIDevices(_ devices: [MIDIDevice])
    func didConnectToDevice(_ device: MIDIDevice)
    func didDisconnectFromDevice(_ device: MIDIDevice)
    func didReceiveMIDIMessage(_ message: MIDIMessage)
    func didFailWithError(_ error: MIDIError)
}

/// Interactor protocol for MIDI data operations
public protocol MIDIInteractorProtocol: AnyObject {
    var presenter: MIDIPresenterProtocol? { get set }
    
    func getAvailableDevices() async throws -> [MIDIDevice]
    func establishConnection(to device: MIDIDevice) async throws
    func terminateConnection(from device: MIDIDevice) async throws
    func transmitMIDI(_ message: MIDIMessage) async throws
    func startListening() async throws
    func stopListening() async throws
}

/// Router protocol for navigation
public protocol MIDIRouterProtocol: AnyObject {
    @MainActor static func createMIDIModule() -> Any
    func navigateToMIDISettings()
    func navigateToMIDIDeviceList()
    func presentDeviceSelection(from view: MIDIViewProtocol)
    func presentSettings(from view: MIDIViewProtocol)
}

// MARK: - Entity Types

/// MIDI device representation
public struct MIDIDevice: Codable, Equatable, Sendable {
    public let id: UInt32
    public let name: String
    public let manufacturer: String
    public let isOnline: Bool
    public let isConnected: Bool
    public let connectionDirection: MIDIConnectionDirection
    
    public init(id: UInt32, name: String, manufacturer: String, isOnline: Bool, isConnected: Bool, connectionDirection: MIDIConnectionDirection) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.isOnline = isOnline
        self.isConnected = isConnected
        self.connectionDirection = connectionDirection
    }
}

/// MIDI connection direction types
public enum MIDIConnectionDirection: String, Codable, CaseIterable, Sendable {
    case input = "input"
    case output = "output"
    case bidirectional = "bidirectional"
    case virtual = "virtual"
}

/// MIDI message representation
public struct MIDIMessage: Codable, Equatable, Sendable {
    public let type: MIDIMessageType
    public let channel: UInt8
    public let data1: UInt8
    public let data2: UInt8
    public let timestamp: UInt64
    
    public init(type: MIDIMessageType, channel: UInt8, data1: UInt8, data2: UInt8, timestamp: UInt64 = 0) {
        self.type = type
        self.channel = channel
        self.data1 = data1
        self.data2 = data2
        self.timestamp = timestamp
    }
}

/// MIDI message types
public enum MIDIMessageType: UInt8, Codable, CaseIterable, Sendable {
    case noteOff = 0x80
    case noteOn = 0x90
    case controlChange = 0xB0
    case programChange = 0xC0
    case pitchBend = 0xE0
    case systemExclusive = 0xF0
    case timingClock = 0xF8
    case start = 0xFA
    case `continue` = 0xFB
    case stop = 0xFC
}

/// MIDI connection status
public enum MIDIConnectionStatus: String, Codable, CaseIterable, Sendable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case error = "error"
}

/// MIDI specific errors
public struct MIDIError: MachineError, Codable, Sendable {
    public let code: String
    public let message: String
    public let severity: ErrorSeverity
    public let timestamp: Date

    public init(code: String, message: String, severity: ErrorSeverity = .error) {
        self.code = code
        self.message = message
        self.severity = severity
        self.timestamp = Date()
    }

    // MARK: - Static Factory Methods

    public static func initializationFailed(_ message: String) -> MIDIError {
        return MIDIError(code: "INIT_FAILED", message: message, severity: .critical)
    }

    public static func connectionFailed(_ message: String) -> MIDIError {
        return MIDIError(code: "CONNECTION_FAILED", message: message, severity: .error)
    }

    public static func sendFailed(_ message: String) -> MIDIError {
        return MIDIError(code: "SEND_FAILED", message: message, severity: .error)
    }
}

// MARK: - MIDI Configuration

/// MIDI module configuration
public struct MIDIConfiguration: Codable, Sendable {
    public let clientName: String
    public let enableVirtualPorts: Bool
    public let enableNetworkSession: Bool
    public let inputPortName: String
    public let outputPortName: String
    public let preferredDevices: [String]

    public init(
        clientName: String = "DigitonePad",
        enableVirtualPorts: Bool = true,
        enableNetworkSession: Bool = true,
        inputPortName: String = "DigitonePad Input",
        outputPortName: String = "DigitonePad Output",
        preferredDevices: [String] = []
    ) {
        self.clientName = clientName
        self.enableVirtualPorts = enableVirtualPorts
        self.enableNetworkSession = enableNetworkSession
        self.inputPortName = inputPortName
        self.outputPortName = outputPortName
        self.preferredDevices = preferredDevices
    }
}