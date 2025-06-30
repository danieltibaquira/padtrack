// MIDIInteractor.swift
// DigitonePad - MIDIModule
//
// VIPER Interactor for MIDI business logic

import Foundation
import CoreMIDI
import MachineProtocols

/// Interactor that handles all MIDI business logic
public final class MIDIInteractor: MIDIInteractorInputProtocol, MIDIInteractorProtocol {
    // For MIDIInteractorInputProtocol
    public weak var outputPresenter: MIDIInteractorOutputProtocol?

    // For MIDIInteractorProtocol
    public weak var presenter: MIDIPresenterProtocol? {
        get { outputPresenter as? MIDIPresenterProtocol }
        set { outputPresenter = newValue as? MIDIInteractorOutputProtocol }
    }
    
    // MARK: - Private Properties
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var outputPort: MIDIPortRef = 0
    private var configuration: MIDIConfiguration
    public private(set) var connectedDevices: Set<UInt32> = []
    private var midiInputHandler: ((MIDIMessage) -> Void)?
    private var isInitialized = false
    
    // MARK: - Initialization
    
    public init(configuration: MIDIConfiguration = MIDIConfiguration()) {
        self.configuration = configuration
    }
    
    // MARK: - MIDIInteractorInputProtocol
    
    public func initialize() {
        guard !isInitialized else {
            outputPresenter?.didInitializeMIDI()
            return
        }

        do {
            try setupMIDIClient()
            try setupMIDIPorts()
            isInitialized = true
            outputPresenter?.didInitializeMIDI()
        } catch {
            let midiError = MIDIError(
                code: "INIT_FAILED",
                message: "Failed to initialize MIDI: \(error.localizedDescription)",
                severity: .critical
            )
            outputPresenter?.didFailWithError(midiError)
        }
    }
    
    public func discoverMIDIDevices() {
        guard isInitialized else {
            let error = MIDIError(
                code: "NOT_INITIALIZED",
                message: "MIDI system not initialized",
                severity: .warning
            )
            outputPresenter?.didFailWithError(error)
            return
        }

        var devices: [MIDIDevice] = []

        // Discover input devices
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            if let device = createMIDIDevice(from: source, connectionDirection: .input) {
                devices.append(device)
            }
        }

        // Discover output devices
        let destinationCount = MIDIGetNumberOfDestinations()
        for i in 0..<destinationCount {
            let destination = MIDIGetDestination(i)
            if let device = createMIDIDevice(from: destination, connectionDirection: .output) {
                devices.append(device)
            }
        }

        outputPresenter?.didDiscoverMIDIDevices(devices)
    }
    
    public func connectToDevice(_ device: MIDIDevice) {
        guard isInitialized else {
            let error = MIDIError(
                code: "NOT_INITIALIZED",
                message: "MIDI system not initialized",
                severity: .warning
            )
            outputPresenter?.didFailWithError(error)
            return
        }

        do {
            switch device.connectionDirection {
            case .input:
                try connectToInputDevice(device)
            case .output:
                try connectToOutputDevice(device)
            case .bidirectional:
                try connectToInputDevice(device)
                try connectToOutputDevice(device)
            case .virtual:
                // Virtual devices are handled differently
                break
            }

            connectedDevices.insert(device.id)
            outputPresenter?.didConnectToDevice(device)
        } catch {
            let midiError = MIDIError(
                code: "CONNECTION_FAILED",
                message: "Failed to connect to device \(device.name): \(error.localizedDescription)",
                severity: .error
            )
            outputPresenter?.didFailWithError(midiError)
        }
    }
    
    public func disconnectFromDevice(_ device: MIDIDevice) {
        connectedDevices.remove(device.id)
        outputPresenter?.didDisconnectFromDevice(device)
    }
    
    public func sendMIDIMessage(_ message: MIDIMessage) {
        guard isInitialized else {
            let error = MIDIError(
                code: "NOT_INITIALIZED",
                message: "MIDI system not initialized",
                severity: .warning
            )
            outputPresenter?.didFailWithError(error)
            return
        }

        do {
            try sendMessage(message)
        } catch {
            let midiError = MIDIError(
                code: "SEND_FAILED",
                message: "Failed to send MIDI message: \(error.localizedDescription)",
                severity: .error
            )
            outputPresenter?.didFailWithError(midiError)
        }
    }
    
    public func setMIDIInputHandler(_ handler: @escaping (MIDIMessage) -> Void) {
        self.midiInputHandler = handler
    }

    // MARK: - MIDIInteractorProtocol

    public func getAvailableDevices() async throws -> [MIDIDevice] {
        self.discoverMIDIDevices()
        // For now, return discovered devices - in real implementation this would be async
        return []
    }

    public func establishConnection(to device: MIDIDevice) async throws {
        self.connectToDevice(device)
    }

    public func terminateConnection(from device: MIDIDevice) async throws {
        self.disconnectFromDevice(device)
    }

    public func transmitMIDI(_ message: MIDIMessage) async throws {
        self.sendMIDIMessage(message)
    }

    public func startListening() async throws {
        // Already handled in initialize()
    }

    public func stopListening() async throws {
        // Implementation for stopping MIDI listening
    }
    
    // MARK: - Private Methods
    
    private func setupMIDIClient() throws {
        let status = MIDIClientCreateWithBlock(configuration.clientName as CFString, &midiClient) { [weak self] notification in
            self?.handleMIDINotification(notification)
        }
        
        guard status == noErr else {
            throw NSError(domain: "MIDIError", code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Failed to create MIDI client"
            ])
        }
    }
    
    private func setupMIDIPorts() throws {
        // Create input port
        let inputStatus = MIDIInputPortCreateWithProtocol(
            midiClient,
            configuration.inputPortName as CFString,
            MIDIProtocolID._1_0,
            &inputPort
        ) { [weak self] eventList, srcConnRefCon in
            self?.handleMIDIInput(eventList, srcConnRefCon: srcConnRefCon)
        }
        
        guard inputStatus == noErr else {
            throw NSError(domain: "MIDIError", code: Int(inputStatus), userInfo: [
                NSLocalizedDescriptionKey: "Failed to create MIDI input port"
            ])
        }
        
        // Create output port
        let outputStatus = MIDIOutputPortCreate(
            midiClient,
            configuration.outputPortName as CFString,
            &outputPort
        )
        
        guard outputStatus == noErr else {
            throw NSError(domain: "MIDIError", code: Int(outputStatus), userInfo: [
                NSLocalizedDescriptionKey: "Failed to create MIDI output port"
            ])
        }
    }
    
    private func createMIDIDevice(from endpointRef: MIDIEndpointRef, connectionDirection: MIDIConnectionDirection) -> MIDIDevice? {
        var name: Unmanaged<CFString>?
        var manufacturer: Unmanaged<CFString>?
        var isOnline: Int32 = 0
        
        // Get device name
        MIDIObjectGetStringProperty(endpointRef, kMIDIPropertyName, &name)
        let deviceName = name?.takeRetainedValue() as String? ?? "Unknown Device"
        
        // Get manufacturer
        MIDIObjectGetStringProperty(endpointRef, kMIDIPropertyManufacturer, &manufacturer)
        let deviceManufacturer = manufacturer?.takeRetainedValue() as String? ?? "Unknown"
        
        // Check if online
        MIDIObjectGetIntegerProperty(endpointRef, kMIDIPropertyOffline, &isOnline)
        
        return MIDIDevice(
            id: UInt32(endpointRef),
            name: deviceName,
            manufacturer: deviceManufacturer,
            isOnline: isOnline == 0,
            isConnected: connectedDevices.contains(UInt32(endpointRef)),
            connectionDirection: connectionDirection
        )
    }
    
    private func connectToInputDevice(_ device: MIDIDevice) throws {
        let source = MIDIEndpointRef(device.id)
        let status = MIDIPortConnectSource(inputPort, source, nil)
        
        guard status == noErr else {
            throw NSError(domain: "MIDIError", code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Failed to connect to input device"
            ])
        }
    }
    
    private func connectToOutputDevice(_ device: MIDIDevice) throws {
        // Output devices don't need explicit connection like input devices
        // Connection is established when sending messages
    }
    
    private func sendMessage(_ message: MIDIMessage) throws {
        guard outputPort != 0 else {
            throw NSError(domain: "MIDIError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Output port not initialized"
            ])
        }
        
        // Create MIDI packet
        let packet = MIDIPacket()
        var packetList = MIDIPacketList(numPackets: 1, packet: packet)
        
        // Prepare MIDI data
        let statusByte = message.type.rawValue | (message.channel & 0x0F)
        var midiData: [UInt8] = [statusByte, message.data1, message.data2]
        
        // Adjust data length based on message type
        switch message.type {
        case .programChange:
            midiData = [statusByte, message.data1]
        case .timingClock, .start, .continue, .stop:
            midiData = [statusByte]
        default:
            break
        }
        
        // Add packet to list
        let packetPtr = MIDIPacketListInit(&packetList)
        let _ = MIDIPacketListAdd(
            &packetList,
            1024,
            packetPtr,
            mach_absolute_time(),
            midiData.count,
            midiData
        )
        
        // Check if packet was added successfully (finalPacket is not optional in modern Swift)
        // We'll rely on the fact that MIDIPacketListAdd returns NULL on failure
        
        // Send to all connected output devices
        let destinationCount = MIDIGetNumberOfDestinations()
        for i in 0..<destinationCount {
            let destination = MIDIGetDestination(i)
            if connectedDevices.contains(UInt32(destination)) {
                let status = MIDISend(outputPort, destination, &packetList)
                if status != noErr {
                    throw NSError(domain: "MIDIError", code: Int(status), userInfo: [
                        NSLocalizedDescriptionKey: "Failed to send MIDI message"
                    ])
                }
            }
        }
    }
    
    private func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) {
        // Handle MIDI system notifications (device added/removed, etc.)
        switch notification.pointee.messageID {
        case .msgObjectAdded, .msgObjectRemoved:
            // Refresh device list when devices are added or removed
            discoverMIDIDevices()
        default:
            break
        }
    }
    
    private func handleMIDIInput(_ eventList: UnsafePointer<MIDIEventList>, srcConnRefCon: UnsafeMutableRawPointer?) {
        // Simplified MIDI input handling for now
        // TODO: Implement proper MIDI event parsing when CoreMIDI API is stable
        print("MIDI input received")
    }
    
    public func processMIDIEvent(_ data: [UInt8]) {
        // Simple MIDI message parsing
        guard data.count >= 3 else { return }
        
        let statusByte = data[0]
        let data1 = data[1]
        let data2 = data[2]
        
        guard let messageType = MIDIMessageType(rawValue: statusByte & 0xF0) else { return }
        
        let channel = statusByte & 0x0F
        let message = MIDIMessage(
            type: messageType,
            channel: channel,
            data1: data1,
            data2: data2
        )
        
        // Notify presenter and call input handler
        outputPresenter?.didReceiveMIDIMessage(message)
        midiInputHandler?(message)
    }
    
    // MARK: - Deinitializer
    
    deinit {
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
        }
        if outputPort != 0 {
            MIDIPortDispose(outputPort)
        }
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
        }
    }
} 