// MIDIIOModule.swift
// DigitonePad - MIDIModule
//
// Enhanced MIDI I/O module for external device integration
// Provides professional-grade MIDI processing with advanced routing and filtering

import Foundation
import CoreMIDI
import Combine
import MachineProtocols

// MARK: - MIDI I/O Configuration

/// Configuration for MIDI I/O module
public struct MIDIIOConfig: Codable {
    /// Input configuration
    public var input: MIDIInputConfig = MIDIInputConfig()
    
    /// Output configuration
    public var output: MIDIOutputConfig = MIDIOutputConfig()
    
    /// Routing configuration
    public var routing: MIDIRoutingConfig = MIDIRoutingConfig()
    
    /// Filtering configuration
    public var filtering: MIDIFilteringConfig = MIDIFilteringConfig()
    
    /// Performance configuration
    public var performance: MIDIPerformanceConfig = MIDIPerformanceConfig()
    
    public init() {}
}

/// MIDI input configuration
public struct MIDIInputConfig: Codable {
    public var enabled: Bool = true
    public var bufferSize: Int = 1024
    public var enableTimestamping: Bool = true
    public var enableChannelFiltering: Bool = false
    public var allowedChannels: Set<UInt8> = Set(0...15)
    public var enableVelocityScaling: Bool = false
    public var velocityScale: Float = 1.0
    public var enableNoteTransposition: Bool = false
    public var transposition: Int8 = 0
    
    public init() {}
}

/// MIDI output configuration
public struct MIDIOutputConfig: Codable {
    public var enabled: Bool = true
    public var bufferSize: Int = 1024
    public var enableLatencyCompensation: Bool = true
    public var latencyCompensationMs: Double = 0.0
    public var enableChannelRemapping: Bool = false
    public var channelMap: [UInt8: UInt8] = [:]
    public var enableVelocityProcessing: Bool = false
    public var velocityCurve: VelocityCurve = .linear
    
    public init() {}
}

/// MIDI routing configuration
public struct MIDIRoutingConfig: Codable {
    public var enableRouting: Bool = true
    public var maxRoutes: Int = 64
    public var enableSplitting: Bool = true
    public var enableMerging: Bool = true
    public var enableThru: Bool = false
    public var thruDelay: Double = 0.0
    
    public init() {}
}

/// MIDI filtering configuration
public struct MIDIFilteringConfig: Codable {
    public var enableFiltering: Bool = false
    public var allowedMessageTypes: Set<MIDIMessageType> = Set(MIDIMessageType.allCases)
    public var blockedMessageTypes: Set<MIDIMessageType> = []
    public var enableChannelFiltering: Bool = false
    public var allowedChannels: Set<UInt8> = Set(0...15)
    public var enableVelocityFiltering: Bool = false
    public var minVelocity: UInt8 = 1
    public var maxVelocity: UInt8 = 127
    
    public init() {}
}

/// MIDI performance configuration
public struct MIDIPerformanceConfig: Codable {
    public var enableHighPrecisionTiming: Bool = true
    public var enableJitterReduction: Bool = true
    public var enableBufferOptimization: Bool = true
    public var maxProcessingLatency: Double = 1.0  // ms
    public var enableStatistics: Bool = true
    
    public init() {}
}

/// Velocity curve types
public enum VelocityCurve: String, CaseIterable, Codable {
    case linear = "linear"
    case exponential = "exponential"
    case logarithmic = "logarithmic"
    case sCurve = "sCurve"
    case custom = "custom"
    
    public var description: String {
        switch self {
        case .linear: return "Linear"
        case .exponential: return "Exponential"
        case .logarithmic: return "Logarithmic"
        case .sCurve: return "S-Curve"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Enhanced MIDI Device Types

/// Enhanced MIDI device with advanced capabilities
public struct EnhancedMIDIDevice: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let manufacturer: String
    public let model: String
    public let uniqueID: Int32
    public let deviceType: MIDIDeviceType
    public let connectionType: MIDIConnectionType
    public var isOnline: Bool
    public var isConnected: Bool
    public var capabilities: MIDIDeviceCapabilities
    public var configuration: MIDIDeviceConfiguration
    public var statistics: MIDIDeviceStatistics
    
    public init(id: UUID = UUID(), name: String, manufacturer: String, model: String,
                uniqueID: Int32, deviceType: MIDIDeviceType, connectionType: MIDIConnectionType,
                isOnline: Bool = false, isConnected: Bool = false) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.model = model
        self.uniqueID = uniqueID
        self.deviceType = deviceType
        self.connectionType = connectionType
        self.isOnline = isOnline
        self.isConnected = isConnected
        self.capabilities = MIDIDeviceCapabilities()
        self.configuration = MIDIDeviceConfiguration()
        self.statistics = MIDIDeviceStatistics()
    }
}

/// MIDI device types
public enum MIDIDeviceType: String, CaseIterable, Codable, Sendable {
    case keyboard = "keyboard"
    case controller = "controller"
    case synthesizer = "synthesizer"
    case drumMachine = "drumMachine"
    case sequencer = "sequencer"
    case interface = "interface"
    case computer = "computer"
    case virtual = "virtual"
    case unknown = "unknown"
    
    public var description: String {
        switch self {
        case .keyboard: return "Keyboard"
        case .controller: return "Controller"
        case .synthesizer: return "Synthesizer"
        case .drumMachine: return "Drum Machine"
        case .sequencer: return "Sequencer"
        case .interface: return "MIDI Interface"
        case .computer: return "Computer"
        case .virtual: return "Virtual Device"
        case .unknown: return "Unknown"
        }
    }
}

/// MIDI connection types
public enum MIDIConnectionType: String, CaseIterable, Codable, Sendable {
    case usb = "usb"
    case bluetooth = "bluetooth"
    case network = "network"
    case virtual = "virtual"
    case din = "din"
    case unknown = "unknown"
    
    public var description: String {
        switch self {
        case .usb: return "USB"
        case .bluetooth: return "Bluetooth"
        case .network: return "Network"
        case .virtual: return "Virtual"
        case .din: return "DIN"
        case .unknown: return "Unknown"
        }
    }
}

/// MIDI device capabilities
public struct MIDIDeviceCapabilities: Codable, Sendable {
    public var supportsInput: Bool = false
    public var supportsOutput: Bool = false
    public var supportsMTC: Bool = false
    public var supportsMClock: Bool = false
    public var supportsMMC: Bool = false
    public var supportsSysEx: Bool = false
    public var supportsRPN: Bool = false
    public var supportsNRPN: Bool = false
    public var channelCount: Int = 16
    public var maxSysExSize: Int = 65536
    
    public init() {}
}

/// MIDI device configuration
public struct MIDIDeviceConfiguration: Codable, Sendable {
    public var inputChannel: UInt8? = nil  // nil = omni
    public var outputChannel: UInt8 = 0
    public var enableSysEx: Bool = true
    public var enableMTC: Bool = false
    public var enableMClock: Bool = false
    public var velocityMap: [UInt8: UInt8] = [:]
    public var ccMap: [UInt8: UInt8] = [:]
    
    public init() {}
}

/// MIDI device statistics
public struct MIDIDeviceStatistics: Codable, Sendable {
    public var messagesReceived: UInt64 = 0
    public var messagesSent: UInt64 = 0
    public var bytesReceived: UInt64 = 0
    public var bytesSent: UInt64 = 0
    public var errors: UInt64 = 0
    public var lastActivity: Date? = nil
    public var averageLatency: Double = 0.0
    
    public init() {}
}

// MARK: - MIDI Route Definition

/// MIDI routing definition
public struct MIDIRoute: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let sourceDeviceId: UUID?
    public let destinationDeviceId: UUID?
    public let sourceChannel: UInt8?  // nil = all channels
    public let destinationChannel: UInt8?  // nil = preserve
    public let messageTypeFilter: Set<MIDIMessageType>?  // nil = all types
    public let enabled: Bool
    public let priority: Int
    public let transform: MIDITransform?
    
    public init(id: UUID = UUID(), name: String, sourceDeviceId: UUID? = nil,
                destinationDeviceId: UUID? = nil, sourceChannel: UInt8? = nil,
                destinationChannel: UInt8? = nil, messageTypeFilter: Set<MIDIMessageType>? = nil,
                enabled: Bool = true, priority: Int = 0, transform: MIDITransform? = nil) {
        self.id = id
        self.name = name
        self.sourceDeviceId = sourceDeviceId
        self.destinationDeviceId = destinationDeviceId
        self.sourceChannel = sourceChannel
        self.destinationChannel = destinationChannel
        self.messageTypeFilter = messageTypeFilter
        self.enabled = enabled
        self.priority = priority
        self.transform = transform
    }
}

/// MIDI message transformation
public struct MIDITransform: Codable {
    public var channelOffset: Int8 = 0
    public var noteOffset: Int8 = 0
    public var velocityScale: Float = 1.0
    public var velocityOffset: Int8 = 0
    public var ccMap: [UInt8: UInt8] = [:]
    public var enableVelocityCurve: Bool = false
    public var velocityCurve: VelocityCurve = .linear
    
    public init() {}
}

// MARK: - MIDI I/O Module

/// Enhanced MIDI I/O module with professional capabilities
public final class MIDIIOModule: ObservableObject, @unchecked Sendable {
    
    // MARK: - Configuration
    
    @Published public var config: MIDIIOConfig {
        didSet {
            updateConfiguration()
        }
    }
    
    // MARK: - Core MIDI Components
    
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var outputPort: MIDIPortRef = 0
    
    // MARK: - Device Management
    
    @Published public private(set) var availableDevices: [EnhancedMIDIDevice] = []
    @Published public private(set) var connectedInputDevices: [EnhancedMIDIDevice] = []
    @Published public private(set) var connectedOutputDevices: [EnhancedMIDIDevice] = []
    
    // MARK: - Routing System
    
    @Published public var routes: [MIDIRoute] = []
    private var routingEngine: MIDIRoutingEngine
    
    // MARK: - Message Processing
    
    private var messageProcessor: MIDIMessageProcessor
    private var messageFilter: MIDIMessageFilter
    private var messageBuffer: MIDIMessageBuffer
    
    // MARK: - Performance Monitoring
    
    private var performanceMonitor: MIDIPerformanceMonitor
    @Published public private(set) var statistics: MIDIIOStatistics = MIDIIOStatistics()
    
    // MARK: - Event Handling
    
    public var messageReceivedHandler: ((MIDIMessage, EnhancedMIDIDevice?) -> Void)?
    public var deviceConnectedHandler: ((EnhancedMIDIDevice) -> Void)?
    public var deviceDisconnectedHandler: ((EnhancedMIDIDevice) -> Void)?
    public var errorHandler: ((MIDIIOError) -> Void)?
    
    // MARK: - Thread Safety
    
    private let ioQueue = DispatchQueue(label: "MIDIIOModule", qos: .userInteractive)
    private let deviceQueue = DispatchQueue(label: "MIDIIOModule.Devices", qos: .userInitiated)
    
    // MARK: - State Management
    
    private var isInitialized: Bool = false
    private var isRunning: Bool = false
    
    // MARK: - Initialization
    
    public init(config: MIDIIOConfig = MIDIIOConfig()) {
        self.config = config
        self.routingEngine = MIDIRoutingEngine()
        self.messageProcessor = MIDIMessageProcessor(config: config.performance)
        self.messageFilter = MIDIMessageFilter(config: config.filtering)
        self.messageBuffer = MIDIMessageBuffer(size: config.input.bufferSize)
        self.performanceMonitor = MIDIPerformanceMonitor()
        
        setupMIDINotifications()
    }

    // MARK: - Lifecycle Management

    /// Initialize the MIDI I/O module
    public func initialize() throws {
        try ioQueue.sync {
            guard !isInitialized else { return }

            // Create MIDI client
            let clientStatus = MIDIClientCreateWithBlock("DigitonePadMIDIIO" as CFString, &midiClient) { [weak self] notification in
                self?.handleMIDINotification(notification)
            }

            guard clientStatus == noErr else {
                throw MIDIIOError.initializationFailed("Failed to create MIDI client: \(clientStatus)")
            }

            // Create input port
            let inputStatus = MIDIInputPortCreateWithProtocol(
                midiClient,
                "DigitonePadInput" as CFString,
                MIDIProtocolID._1_0,
                &inputPort
            ) { [weak self] eventList, srcConnRefCon in
                self?.handleMIDIInput(eventList, srcConnRefCon: srcConnRefCon)
            }

            guard inputStatus == noErr else {
                throw MIDIIOError.initializationFailed("Failed to create input port: \(inputStatus)")
            }

            // Create output port
            let outputStatus = MIDIOutputPortCreate(
                midiClient,
                "DigitonePadOutput" as CFString,
                &outputPort
            )

            guard outputStatus == noErr else {
                throw MIDIIOError.initializationFailed("Failed to create output port: \(outputStatus)")
            }

            // Initialize components
            try routingEngine.initialize()
            try messageProcessor.initialize()
            try performanceMonitor.initialize()

            isInitialized = true
        }
    }

    /// Start the MIDI I/O module
    public func start() throws {
        try ioQueue.sync {
            guard isInitialized && !isRunning else {
                throw MIDIIOError.invalidState("Module not ready to start")
            }

            // Start performance monitoring
            performanceMonitor.start()

            // Discover and connect to devices
            try discoverDevices()

            isRunning = true
        }
    }

    /// Stop the MIDI I/O module
    public func stop() {
        ioQueue.sync {
            guard isRunning else { return }

            // Disconnect all devices
            disconnectAllDevices()

            // Stop performance monitoring
            performanceMonitor.stop()

            isRunning = false
        }
    }

    /// Reset the MIDI I/O module
    public func reset() throws {
        stop()

        try ioQueue.sync {
            // Reset all components
            routingEngine.reset()
            messageProcessor.reset()
            messageFilter.reset()
            messageBuffer.reset()
            performanceMonitor.reset()

            // Clear device lists
            availableDevices.removeAll()
            connectedInputDevices.removeAll()
            connectedOutputDevices.removeAll()

            // Reset statistics
            statistics.reset()

            isInitialized = false
        }
    }

    // MARK: - Device Management

    /// Discover available MIDI devices
    public func discoverDevices() throws {
        try deviceQueue.sync {
            var discoveredDevices: [EnhancedMIDIDevice] = []

            // Discover input devices
            let sourceCount = MIDIGetNumberOfSources()
            for i in 0..<sourceCount {
                let source = MIDIGetSource(i)
                if let device = createDeviceFromEndpoint(source, isInput: true) {
                    discoveredDevices.append(device)
                }
            }

            // Discover output devices
            let destinationCount = MIDIGetNumberOfDestinations()
            for i in 0..<destinationCount {
                let destination = MIDIGetDestination(i)
                if let device = createDeviceFromEndpoint(destination, isInput: false) {
                    discoveredDevices.append(device)
                }
            }

            DispatchQueue.main.async {
                self.availableDevices = discoveredDevices
            }
        }
    }

    /// Connect to an input device
    public func connectInputDevice(_ device: EnhancedMIDIDevice) throws {
        try deviceQueue.sync {
            guard device.capabilities.supportsInput else {
                throw MIDIIOError.deviceError("Device does not support input")
            }

            let source = MIDIGetSource(Int(device.uniqueID))
            let status = MIDIPortConnectSource(inputPort, source, nil)

            guard status == noErr else {
                throw MIDIIOError.connectionFailed("Failed to connect input device: \(status)")
            }

            var connectedDevice = device
            connectedDevice.isConnected = true

            DispatchQueue.main.async {
                if !self.connectedInputDevices.contains(where: { $0.id == device.id }) {
                    self.connectedInputDevices.append(connectedDevice)
                }
                self.deviceConnectedHandler?(connectedDevice)
            }
        }
    }

    /// Connect to an output device
    public func connectOutputDevice(_ device: EnhancedMIDIDevice) throws {
        try deviceQueue.sync {
            guard device.capabilities.supportsOutput else {
                throw MIDIIOError.deviceError("Device does not support output")
            }

            var connectedDevice = device
            connectedDevice.isConnected = true

            DispatchQueue.main.async {
                if !self.connectedOutputDevices.contains(where: { $0.id == device.id }) {
                    self.connectedOutputDevices.append(connectedDevice)
                }
                self.deviceConnectedHandler?(connectedDevice)
            }
        }
    }

    /// Disconnect an input device
    public func disconnectInputDevice(_ device: EnhancedMIDIDevice) throws {
        try deviceQueue.sync {
            let source = MIDIGetSource(Int(device.uniqueID))
            let status = MIDIPortDisconnectSource(inputPort, source)

            guard status == noErr else {
                throw MIDIIOError.connectionFailed("Failed to disconnect input device: \(status)")
            }

            DispatchQueue.main.async {
                self.connectedInputDevices.removeAll { $0.id == device.id }
                self.deviceDisconnectedHandler?(device)
            }
        }
    }

    /// Disconnect an output device
    public func disconnectOutputDevice(_ device: EnhancedMIDIDevice) throws {
        try deviceQueue.sync {
            DispatchQueue.main.async {
                self.connectedOutputDevices.removeAll { $0.id == device.id }
                self.deviceDisconnectedHandler?(device)
            }
        }
    }

    /// Disconnect all devices
    public func disconnectAllDevices() {
        deviceQueue.sync {
            // Disconnect all input devices
            for device in connectedInputDevices {
                try? disconnectInputDevice(device)
            }

            // Disconnect all output devices
            for device in connectedOutputDevices {
                try? disconnectOutputDevice(device)
            }
        }
    }

    // MARK: - Message Processing

    /// Send MIDI message to specific device
    public func sendMessage(_ message: MIDIMessage, to device: EnhancedMIDIDevice) throws {
        try ioQueue.sync {
            guard isRunning else {
                throw MIDIIOError.invalidState("Module not running")
            }

            guard device.capabilities.supportsOutput && device.isConnected else {
                throw MIDIIOError.deviceError("Device not available for output")
            }

            // Process message through filter and processor
            guard let processedMessage = messageFilter.filter(message) else {
                return // Message filtered out
            }

            let finalMessage = messageProcessor.process(processedMessage, for: device)

            // Send to device
            try sendRawMessage(finalMessage, to: device)

            // Update statistics
            statistics.recordMessageSent()
            performanceMonitor.recordMessageSent()
        }
    }

    /// Send MIDI message to all connected output devices
    public func broadcastMessage(_ message: MIDIMessage) throws {
        for device in connectedOutputDevices {
            try? sendMessage(message, to: device)
        }
    }

    /// Send MIDI message through routing system
    public func routeMessage(_ message: MIDIMessage, from sourceDevice: EnhancedMIDIDevice? = nil) {
        ioQueue.async {
            let routedMessages = self.routingEngine.route(message, from: sourceDevice, routes: self.routes)

            for (routedMessage, targetDevice) in routedMessages {
                if let device = targetDevice {
                    try? self.sendMessage(routedMessage, to: device)
                } else {
                    // Broadcast to all devices
                    try? self.broadcastMessage(routedMessage)
                }
            }
        }
    }

    // MARK: - Routing Management

    /// Add a MIDI route
    public func addRoute(_ route: MIDIRoute) {
        ioQueue.sync {
            if !routes.contains(where: { $0.id == route.id }) {
                routes.append(route)
                routes.sort { $0.priority > $1.priority }
            }
        }
    }

    /// Remove a MIDI route
    public func removeRoute(id: UUID) {
        ioQueue.sync {
            routes.removeAll { $0.id == id }
        }
    }

    /// Update a MIDI route
    public func updateRoute(_ route: MIDIRoute) {
        ioQueue.sync {
            if let index = routes.firstIndex(where: { $0.id == route.id }) {
                routes[index] = route
                routes.sort { $0.priority > $1.priority }
            }
        }
    }

    /// Clear all routes
    public func clearRoutes() {
        ioQueue.sync {
            routes.removeAll()
        }
    }

    // MARK: - Configuration Management

    private func updateConfiguration() {
        ioQueue.async {
            self.messageProcessor.updateConfig(self.config.performance)
            self.messageFilter.updateConfig(self.config.filtering)
            self.routingEngine.updateConfig(self.config.routing)
        }
    }

    // MARK: - Private Implementation

    private func setupMIDINotifications() {
        // Setup system MIDI notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: "kMIDIObjectAdded"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            try? self?.discoverDevices()
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: "kMIDIObjectRemoved"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            try? self?.discoverDevices()
        }
    }

    private func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) {
        let notificationPtr = notification.pointee

        switch notificationPtr.messageID {
        case .msgObjectAdded, .msgObjectRemoved:
            DispatchQueue.main.async {
                try? self.discoverDevices()
            }
        case .msgPropertyChanged:
            // Handle property changes
            break
        default:
            break
        }
    }

    private func handleMIDIInput(_ eventList: UnsafePointer<MIDIEventList>, srcConnRefCon: UnsafeMutableRawPointer?) {
        performanceMonitor.startProcessingCycle()

        // Parse MIDI events
        let events = parseMIDIEventList(eventList)

        for event in events {
            // Find source device
            let sourceDevice = findSourceDevice(from: srcConnRefCon)

            // Process through filter
            guard let filteredMessage = messageFilter.filter(event) else {
                continue
            }

            // Process through message processor
            let processedMessage = messageProcessor.process(filteredMessage, for: sourceDevice)

            // Update statistics
            statistics.recordMessageReceived()

            // Route message
            routeMessage(processedMessage, from: sourceDevice)

            // Notify handler
            DispatchQueue.main.async {
                self.messageReceivedHandler?(processedMessage, sourceDevice)
            }
        }

        performanceMonitor.endProcessingCycle()
    }

    private func createDeviceFromEndpoint(_ endpoint: MIDIEndpointRef, isInput: Bool) -> EnhancedMIDIDevice? {
        var name: Unmanaged<CFString>?
        var manufacturer: Unmanaged<CFString>?
        var model: Unmanaged<CFString>?
        var uniqueID: Int32 = 0
        var isOnline: Int32 = 0

        // Get device properties
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name)
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyManufacturer, &manufacturer)
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyModel, &model)
        MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)
        MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyOffline, &isOnline)

        let deviceName = name?.takeRetainedValue() as String? ?? "Unknown Device"
        let deviceManufacturer = manufacturer?.takeRetainedValue() as String? ?? "Unknown"
        let deviceModel = model?.takeRetainedValue() as String? ?? "Unknown"

        var device = EnhancedMIDIDevice(
            name: deviceName,
            manufacturer: deviceManufacturer,
            model: deviceModel,
            uniqueID: uniqueID,
            deviceType: .unknown,
            connectionType: .usb,
            isOnline: isOnline == 0
        )

        // Set capabilities
        device.capabilities.supportsInput = isInput
        device.capabilities.supportsOutput = !isInput

        return device
    }

    private func sendRawMessage(_ message: MIDIMessage, to device: EnhancedMIDIDevice) throws {
        let destination = MIDIGetDestination(Int(device.uniqueID))

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

        // Send packet
        let status = MIDISend(outputPort, destination, &packetList)

        guard status == noErr else {
            throw MIDIIOError.transmissionFailed("Failed to send MIDI message: \(status)")
        }
    }

    private func parseMIDIEventList(_ eventList: UnsafePointer<MIDIEventList>) -> [MIDIMessage] {
        let messages: [MIDIMessage] = []

        // Parse MIDI event list (simplified implementation)
        // In a real implementation, this would properly parse the event list structure

        return messages
    }

    private func findSourceDevice(from refCon: UnsafeMutableRawPointer?) -> EnhancedMIDIDevice? {
        // Find the source device based on the reference connection
        // This would map the refCon to the actual device
        return connectedInputDevices.first
    }

    // MARK: - Deinitializer

    deinit {
        stop()

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
