// MIDIIOSupport.swift
// DigitonePad - MIDIModule
//
// Supporting classes for MIDI I/O Module

import Foundation
import CoreMIDI
import MachineProtocols

// MARK: - MIDI I/O Statistics

/// Statistics for MIDI I/O operations
public struct MIDIIOStatistics: Codable {
    public private(set) var messagesReceived: UInt64 = 0
    public private(set) var messagesSent: UInt64 = 0
    public private(set) var bytesReceived: UInt64 = 0
    public private(set) var bytesSent: UInt64 = 0
    public private(set) var errors: UInt64 = 0
    public private(set) var droppedMessages: UInt64 = 0
    public private(set) var averageLatency: Double = 0.0
    public private(set) var maxLatency: Double = 0.0
    public private(set) var uptime: TimeInterval = 0.0
    public private(set) var startTime: Date = Date()
    
    mutating func reset() {
        messagesReceived = 0
        messagesSent = 0
        bytesReceived = 0
        bytesSent = 0
        errors = 0
        droppedMessages = 0
        averageLatency = 0.0
        maxLatency = 0.0
        uptime = 0.0
        startTime = Date()
    }
    
    mutating func recordMessageReceived(bytes: Int = 3) {
        messagesReceived += 1
        bytesReceived += UInt64(bytes)
    }
    
    mutating func recordMessageSent(bytes: Int = 3) {
        messagesSent += 1
        bytesSent += UInt64(bytes)
    }
    
    mutating func recordError() {
        errors += 1
    }
    
    mutating func recordDroppedMessage() {
        droppedMessages += 1
    }
    
    mutating func recordLatency(_ latency: Double) {
        maxLatency = max(maxLatency, latency)
        averageLatency = (averageLatency * Double(messagesReceived - 1) + latency) / Double(messagesReceived)
    }
}

// MARK: - MIDI I/O Errors

/// Errors that can occur in MIDI I/O operations
public enum MIDIIOError: Error, LocalizedError {
    case initializationFailed(String)
    case deviceError(String)
    case connectionFailed(String)
    case transmissionFailed(String)
    case invalidState(String)
    case configurationError(String)
    case bufferOverflow
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "MIDI initialization failed: \(message)"
        case .deviceError(let message):
            return "MIDI device error: \(message)"
        case .connectionFailed(let message):
            return "MIDI connection failed: \(message)"
        case .transmissionFailed(let message):
            return "MIDI transmission failed: \(message)"
        case .invalidState(let message):
            return "Invalid MIDI state: \(message)"
        case .configurationError(let message):
            return "MIDI configuration error: \(message)"
        case .bufferOverflow:
            return "MIDI buffer overflow"
        case .timeout:
            return "MIDI operation timeout"
        }
    }
}

// MARK: - MIDI Routing Engine

/// Engine for routing MIDI messages between devices
internal final class MIDIRoutingEngine: @unchecked Sendable {
    
    private var isInitialized: Bool = false
    private var config: MIDIRoutingConfig = MIDIRoutingConfig()
    
    func initialize() throws {
        isInitialized = true
    }
    
    func reset() {
        isInitialized = false
    }
    
    func updateConfig(_ newConfig: MIDIRoutingConfig) {
        config = newConfig
    }
    
    func route(_ message: MIDIMessage, from sourceDevice: EnhancedMIDIDevice?, routes: [MIDIRoute]) -> [(MIDIMessage, EnhancedMIDIDevice?)] {
        guard config.enableRouting else {
            return [(message, nil)] // Pass through
        }
        
        var routedMessages: [(MIDIMessage, EnhancedMIDIDevice?)] = []
        
        for route in routes where route.enabled {
            if shouldRouteMessage(message, from: sourceDevice, via: route) {
                let transformedMessage = applyTransform(message, transform: route.transform)
                routedMessages.append((transformedMessage, nil)) // Device lookup would be implemented
            }
        }
        
        // If no routes matched and thru is enabled, pass through
        if routedMessages.isEmpty && config.enableThru {
            routedMessages.append((message, nil))
        }
        
        return routedMessages
    }
    
    private func shouldRouteMessage(_ message: MIDIMessage, from sourceDevice: EnhancedMIDIDevice?, via route: MIDIRoute) -> Bool {
        // Check source device
        if let routeSourceId = route.sourceDeviceId,
           let sourceId = sourceDevice?.id,
           routeSourceId != sourceId {
            return false
        }
        
        // Check source channel
        if let routeSourceChannel = route.sourceChannel,
           routeSourceChannel != message.channel {
            return false
        }
        
        // Check message type filter
        if let messageTypeFilter = route.messageTypeFilter,
           !messageTypeFilter.contains(message.type) {
            return false
        }
        
        return true
    }
    
    private func applyTransform(_ message: MIDIMessage, transform: MIDITransform?) -> MIDIMessage {
        guard let transform = transform else { return message }
        
        var transformedMessage = message
        
        // Apply channel offset
        if transform.channelOffset != 0 {
            let newChannel = Int(message.channel) + Int(transform.channelOffset)
            transformedMessage = MIDIMessage(
                type: message.type,
                channel: UInt8(max(0, min(15, newChannel))),
                data1: message.data1,
                data2: message.data2,
                timestamp: message.timestamp
            )
        }
        
        // Apply note offset for note messages
        if (message.type == .noteOn || message.type == .noteOff) && transform.noteOffset != 0 {
            let newNote = Int(message.data1) + Int(transform.noteOffset)
            transformedMessage = MIDIMessage(
                type: transformedMessage.type,
                channel: transformedMessage.channel,
                data1: UInt8(max(0, min(127, newNote))),
                data2: transformedMessage.data2,
                timestamp: transformedMessage.timestamp
            )
        }
        
        // Apply velocity scaling for note messages
        if (message.type == .noteOn || message.type == .noteOff) && transform.velocityScale != 1.0 {
            let newVelocity = Float(message.data2) * transform.velocityScale + Float(transform.velocityOffset)
            transformedMessage = MIDIMessage(
                type: transformedMessage.type,
                channel: transformedMessage.channel,
                data1: transformedMessage.data1,
                data2: UInt8(max(0, min(127, Int(newVelocity)))),
                timestamp: transformedMessage.timestamp
            )
        }
        
        // Apply CC mapping
        if message.type == .controlChange,
           let mappedCC = transform.ccMap[message.data1] {
            transformedMessage = MIDIMessage(
                type: transformedMessage.type,
                channel: transformedMessage.channel,
                data1: mappedCC,
                data2: transformedMessage.data2,
                timestamp: transformedMessage.timestamp
            )
        }
        
        return transformedMessage
    }
}

// MARK: - MIDI Message Processor

/// Processor for MIDI messages with performance optimizations
internal final class MIDIMessageProcessor: @unchecked Sendable {
    
    private var config: MIDIPerformanceConfig
    private var isInitialized: Bool = false
    
    init(config: MIDIPerformanceConfig) {
        self.config = config
    }
    
    func initialize() throws {
        isInitialized = true
    }
    
    func reset() {
        isInitialized = false
    }
    
    func updateConfig(_ newConfig: MIDIPerformanceConfig) {
        config = newConfig
    }
    
    func process(_ message: MIDIMessage, for device: EnhancedMIDIDevice?) -> MIDIMessage {
        guard isInitialized else { return message }
        
        var processedMessage = message
        
        // Apply high-precision timing if enabled
        if config.enableHighPrecisionTiming {
            processedMessage = applyHighPrecisionTiming(processedMessage)
        }
        
        // Apply jitter reduction if enabled
        if config.enableJitterReduction {
            processedMessage = applyJitterReduction(processedMessage)
        }
        
        // Apply device-specific processing
        if let device = device {
            processedMessage = applyDeviceProcessing(processedMessage, for: device)
        }
        
        return processedMessage
    }
    
    private func applyHighPrecisionTiming(_ message: MIDIMessage) -> MIDIMessage {
        // Apply high-precision timestamp
        let preciseTimestamp = UInt64(mach_absolute_time())
        
        return MIDIMessage(
            type: message.type,
            channel: message.channel,
            data1: message.data1,
            data2: message.data2,
            timestamp: preciseTimestamp
        )
    }
    
    private func applyJitterReduction(_ message: MIDIMessage) -> MIDIMessage {
        // Implement jitter reduction algorithm
        // This would typically involve buffering and smoothing timestamps
        return message
    }
    
    private func applyDeviceProcessing(_ message: MIDIMessage, for device: EnhancedMIDIDevice) -> MIDIMessage {
        var processedMessage = message
        
        // Apply device-specific channel mapping
        if let mappedChannel = device.configuration.ccMap[message.channel] {
            processedMessage = MIDIMessage(
                type: message.type,
                channel: mappedChannel,
                data1: message.data1,
                data2: message.data2,
                timestamp: message.timestamp
            )
        }
        
        // Apply device-specific velocity mapping
        if (message.type == .noteOn || message.type == .noteOff),
           let mappedVelocity = device.configuration.velocityMap[message.data2] {
            processedMessage = MIDIMessage(
                type: message.type,
                channel: processedMessage.channel,
                data1: message.data1,
                data2: mappedVelocity,
                timestamp: message.timestamp
            )
        }
        
        return processedMessage
    }
}

// MARK: - MIDI Message Filter

/// Filter for MIDI messages based on configuration
internal final class MIDIMessageFilter: @unchecked Sendable {
    
    private var config: MIDIFilteringConfig
    
    init(config: MIDIFilteringConfig) {
        self.config = config
    }
    
    func reset() {
        // Reset filter state if needed
    }
    
    func updateConfig(_ newConfig: MIDIFilteringConfig) {
        config = newConfig
    }
    
    func filter(_ message: MIDIMessage) -> MIDIMessage? {
        guard config.enableFiltering else { return message }
        
        // Check message type filter
        if !config.allowedMessageTypes.contains(message.type) ||
           config.blockedMessageTypes.contains(message.type) {
            return nil
        }
        
        // Check channel filter
        if config.enableChannelFiltering &&
           !config.allowedChannels.contains(message.channel) {
            return nil
        }
        
        // Check velocity filter for note messages
        if config.enableVelocityFiltering &&
           (message.type == .noteOn || message.type == .noteOff) {
            if message.data2 < config.minVelocity || message.data2 > config.maxVelocity {
                return nil
            }
        }
        
        return message
    }
}

// MARK: - MIDI Message Buffer

/// Buffer for MIDI messages with overflow protection
internal final class MIDIMessageBuffer: @unchecked Sendable {
    
    private var buffer: [MIDIMessage] = []
    private let maxSize: Int
    private let bufferQueue = DispatchQueue(label: "MIDIMessageBuffer", qos: .userInteractive)
    
    init(size: Int) {
        self.maxSize = size
        self.buffer.reserveCapacity(size)
    }
    
    func reset() {
        bufferQueue.sync {
            buffer.removeAll()
        }
    }
    
    func add(_ message: MIDIMessage) -> Bool {
        return bufferQueue.sync {
            guard buffer.count < maxSize else {
                return false // Buffer overflow
            }
            
            buffer.append(message)
            return true
        }
    }
    
    func getNext() -> MIDIMessage? {
        return bufferQueue.sync {
            guard !buffer.isEmpty else { return nil }
            return buffer.removeFirst()
        }
    }
    
    func getAll() -> [MIDIMessage] {
        return bufferQueue.sync {
            let messages = buffer
            buffer.removeAll()
            return messages
        }
    }
    
    var count: Int {
        return bufferQueue.sync {
            return buffer.count
        }
    }
    
    var isFull: Bool {
        return bufferQueue.sync {
            return buffer.count >= maxSize
        }
    }
}

// MARK: - MIDI Performance Monitor

/// Performance monitoring for MIDI operations
internal final class MIDIPerformanceMonitor: @unchecked Sendable {
    
    private var isMonitoring: Bool = false
    private var cycleStartTime: UInt64 = 0
    private var messagesSent: UInt64 = 0
    private var messagesReceived: UInt64 = 0
    
    func initialize() throws {
        // Initialize performance monitoring
    }
    
    func start() {
        isMonitoring = true
    }
    
    func stop() {
        isMonitoring = false
    }
    
    func startProcessingCycle() {
        guard isMonitoring else { return }
        cycleStartTime = mach_absolute_time()
    }
    
    func endProcessingCycle() {
        guard isMonitoring else { return }
        // Record processing time
    }
    
    func recordMessageSent() {
        guard isMonitoring else { return }
        messagesSent += 1
    }
    
    func recordMessageReceived() {
        guard isMonitoring else { return }
        messagesReceived += 1
    }
    
    func reset() {
        cycleStartTime = 0
        messagesSent = 0
        messagesReceived = 0
    }
}
