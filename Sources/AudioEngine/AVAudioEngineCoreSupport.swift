// AVAudioEngineCoreSupport.swift
// DigitonePad - AudioEngine
//
// Supporting classes for AVAudioEngine Core Architecture

import Foundation
import AVFoundation
import Accelerate
import MachineProtocols

// MARK: - Enhanced Audio Graph Manager

/// Enhanced audio graph manager with advanced capabilities
internal final class EnhancedAudioGraphManager: @unchecked Sendable {
    
    private var config: GraphManagementConfig
    private var nodes: [AudioNodeID: EnhancedAudioNode] = [:]
    private var connections: [UUID: AudioConnection] = [:]
    private var processingOrder: [AudioNodeID] = []
    private var connectionCache: [AudioNodeID: [AudioConnection]] = [:]
    
    private let graphQueue = DispatchQueue(label: "EnhancedAudioGraph", qos: .userInteractive)
    
    init(config: GraphManagementConfig) {
        self.config = config
    }
    
    func initialize() throws {
        graphQueue.sync {
            nodes.removeAll()
            connections.removeAll()
            processingOrder.removeAll()
            connectionCache.removeAll()
        }
    }
    
    func addNode(_ node: EnhancedAudioNode) throws {
        try graphQueue.sync {
            guard nodes.count < config.maxNodes else {
                throw AudioEngineError.configurationError("Maximum nodes exceeded")
            }
            
            nodes[node.id] = node
            updateProcessingOrder()
            
            if config.enableConnectionCaching {
                connectionCache[node.id] = []
            }
        }
    }
    
    func removeNode(id: AudioNodeID) throws {
        try graphQueue.sync {
            guard nodes[id] != nil else {
                throw AudioEngineError.configurationError("Node not found")
            }
            
            // Remove all connections involving this node
            let connectionsToRemove = connections.values.filter { 
                $0.sourceNodeId == id || $0.destinationNodeId == id 
            }
            
            for connection in connectionsToRemove {
                connections.removeValue(forKey: connection.id)
            }
            
            nodes.removeValue(forKey: id)
            connectionCache.removeValue(forKey: id)
            updateProcessingOrder()
        }
    }
    
    func addConnection(_ connection: AudioConnection) throws {
        try graphQueue.sync {
            guard connections.count < config.maxConnections else {
                throw AudioEngineError.configurationError("Maximum connections exceeded")
            }
            
            connections[connection.id] = connection
            
            if config.enableConnectionCaching {
                updateConnectionCache(for: connection)
            }
            
            updateProcessingOrder()
        }
    }
    
    func removeConnection(sourceId: AudioNodeID, destinationId: AudioNodeID) throws {
        try graphQueue.sync {
            let connectionToRemove = connections.values.first { 
                $0.sourceNodeId == sourceId && $0.destinationNodeId == destinationId 
            }
            
            guard let connection = connectionToRemove else {
                throw AudioEngineError.configurationError("Connection not found")
            }
            
            connections.removeValue(forKey: connection.id)
            
            if config.enableConnectionCaching {
                updateConnectionCache(for: connection, removing: true)
            }
            
            updateProcessingOrder()
        }
    }
    
    func reset() {
        graphQueue.sync {
            nodes.removeAll()
            connections.removeAll()
            processingOrder.removeAll()
            connectionCache.removeAll()
        }
    }
    
    func updateConfig(_ newConfig: GraphManagementConfig) {
        graphQueue.sync {
            config = newConfig
            
            if !config.enableConnectionCaching {
                connectionCache.removeAll()
            }
        }
    }
    
    func handleConfigurationChange(sampleRate: Double, bufferSize: Int) {
        graphQueue.sync {
            // Update all nodes with new configuration
            for node in nodes.values {
                let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
                try? node.prepare(format: format)
            }
        }
    }
    
    private func updateProcessingOrder() {
        // Topological sort for optimal processing order
        var visited: Set<AudioNodeID> = []
        var tempVisited: Set<AudioNodeID> = []
        var order: [AudioNodeID] = []
        
        func visit(_ nodeId: AudioNodeID) {
            if tempVisited.contains(nodeId) {
                // Cycle detected - handle gracefully
                return
            }
            
            if visited.contains(nodeId) {
                return
            }
            
            tempVisited.insert(nodeId)
            
            // Visit all nodes that this node outputs to
            let outputConnections = connections.values.filter { $0.sourceNodeId == nodeId }
            for connection in outputConnections {
                visit(connection.destinationNodeId)
            }
            
            tempVisited.remove(nodeId)
            visited.insert(nodeId)
            order.insert(nodeId, at: 0)
        }
        
        for nodeId in nodes.keys {
            if !visited.contains(nodeId) {
                visit(nodeId)
            }
        }
        
        processingOrder = order
    }
    
    private func updateConnectionCache(for connection: AudioConnection, removing: Bool = false) {
        if removing {
            connectionCache[connection.sourceNodeId]?.removeAll { $0.id == connection.id }
            connectionCache[connection.destinationNodeId]?.removeAll { $0.id == connection.id }
        } else {
            connectionCache[connection.sourceNodeId, default: []].append(connection)
            connectionCache[connection.destinationNodeId, default: []].append(connection)
        }
    }
}

// MARK: - Audio Performance Monitor

/// Performance monitoring for audio processing
internal final class AudioPerformanceMonitor: @unchecked Sendable {
    
    private var config: PerformanceConfig
    private var metrics: AudioPerformanceMetrics
    private var isMonitoring: Bool = false
    private var cycleStartTime: UInt64 = 0
    
    private let monitorQueue = DispatchQueue(label: "AudioPerformanceMonitor", qos: .utility)
    
    init(config: PerformanceConfig) {
        self.config = config
        self.metrics = AudioPerformanceMetrics()
    }
    
    func initialize() throws {
        monitorQueue.sync {
            metrics.reset()
        }
    }
    
    func start() {
        monitorQueue.sync {
            isMonitoring = true
        }
    }
    
    func stop() {
        monitorQueue.sync {
            isMonitoring = false
        }
    }
    
    func reset() {
        monitorQueue.sync {
            metrics.reset()
        }
    }
    
    func updateConfig(_ newConfig: PerformanceConfig) {
        monitorQueue.sync {
            config = newConfig
        }
    }
    
    func startProcessingCycle() {
        guard isMonitoring else { return }
        cycleStartTime = mach_absolute_time()
    }
    
    func endProcessingCycle() {
        guard isMonitoring else { return }
        
        let endTime = mach_absolute_time()
        let processingTime = endTime - cycleStartTime
        
        monitorQueue.async { [weak self] in
            self?.metrics.recordProcessingTime(processingTime)
        }
    }
    
    func getCurrentMetrics() -> AudioPerformanceMetrics {
        return monitorQueue.sync {
            return metrics
        }
    }
}

// MARK: - Real-Time Safety Manager

/// Real-time safety monitoring and enforcement
internal final class RealTimeSafetyManager: @unchecked Sendable {
    
    private var config: RealTimeSafetyConfig
    private var status: RealTimeSafetyStatus
    private var isMonitoring: Bool = false
    
    private let safetyQueue = DispatchQueue(label: "RealTimeSafetyManager", qos: .userInteractive)
    
    init(config: RealTimeSafetyConfig) {
        self.config = config
        self.status = RealTimeSafetyStatus()
    }
    
    func initialize() throws {
        safetyQueue.sync {
            status.reset()
        }
    }
    
    func start() {
        safetyQueue.sync {
            isMonitoring = true
        }
    }
    
    func stop() {
        safetyQueue.sync {
            isMonitoring = false
        }
    }
    
    func updateConfig(_ newConfig: RealTimeSafetyConfig) {
        safetyQueue.sync {
            config = newConfig
        }
    }
    
    func checkDeadline(_ deadline: UInt64) {
        guard isMonitoring && config.enableDeadlineMonitoring else { return }
        
        let currentTime = mach_absolute_time()
        if currentTime > deadline {
            safetyQueue.async { [weak self] in
                self?.status.recordDeadlineMiss()
            }
        }
    }
    
    func getCurrentStatus() -> RealTimeSafetyStatus {
        return safetyQueue.sync {
            return status
        }
    }
}

// MARK: - Supporting Data Structures

/// Audio performance metrics
public struct AudioPerformanceMetrics: Sendable {
    public private(set) var averageProcessingTime: Double = 0.0
    public private(set) var maxProcessingTime: Double = 0.0
    public private(set) var minProcessingTime: Double = Double.greatestFiniteMagnitude
    public private(set) var totalProcessingCycles: UInt64 = 0
    public private(set) var cpuUsage: Float = 0.0
    public private(set) var memoryUsage: Int = 0
    
    mutating func recordProcessingTime(_ time: UInt64) {
        let timeInMicroseconds = Double(time) / 1000.0
        
        totalProcessingCycles += 1
        maxProcessingTime = max(maxProcessingTime, timeInMicroseconds)
        minProcessingTime = min(minProcessingTime, timeInMicroseconds)
        
        // Update running average
        averageProcessingTime = (averageProcessingTime * Double(totalProcessingCycles - 1) + timeInMicroseconds) / Double(totalProcessingCycles)
        
        // Estimate CPU usage (simplified)
        cpuUsage = Float(averageProcessingTime / 1000.0) // Convert to percentage
    }
    
    mutating func reset() {
        averageProcessingTime = 0.0
        maxProcessingTime = 0.0
        minProcessingTime = Double.greatestFiniteMagnitude
        totalProcessingCycles = 0
        cpuUsage = 0.0
        memoryUsage = 0
    }
}

/// Real-time safety status
public struct RealTimeSafetyStatus: Sendable {
    public private(set) var deadlineMisses: UInt64 = 0
    public private(set) var totalDeadlines: UInt64 = 0
    public private(set) var safetyPercentage: Float = 100.0
    public private(set) var isRealTimeSafe: Bool = true
    
    mutating func recordDeadlineMiss() {
        deadlineMisses += 1
        totalDeadlines += 1
        updateSafetyPercentage()
    }
    
    mutating func recordDeadlineMet() {
        totalDeadlines += 1
        updateSafetyPercentage()
    }
    
    private mutating func updateSafetyPercentage() {
        if totalDeadlines > 0 {
            safetyPercentage = Float(totalDeadlines - deadlineMisses) / Float(totalDeadlines) * 100.0
            isRealTimeSafe = safetyPercentage > 95.0 // 95% threshold
        }
    }
    
    mutating func reset() {
        deadlineMisses = 0
        totalDeadlines = 0
        safetyPercentage = 100.0
        isRealTimeSafe = true
    }
}

/// Processing statistics
public struct ProcessingStatistics: Sendable {
    public private(set) var totalCycles: UInt64 = 0
    public private(set) var successfulCycles: UInt64 = 0
    public private(set) var failedCycles: UInt64 = 0
    public private(set) var averageCycleTime: Double = 0.0
    
    mutating func recordCycle(successful: Bool = true, cycleTime: Double = 0.0) {
        totalCycles += 1
        
        if successful {
            successfulCycles += 1
        } else {
            failedCycles += 1
        }
        
        if cycleTime > 0.0 {
            averageCycleTime = (averageCycleTime * Double(totalCycles - 1) + cycleTime) / Double(totalCycles)
        }
    }
    
    mutating func reset() {
        totalCycles = 0
        successfulCycles = 0
        failedCycles = 0
        averageCycleTime = 0.0
    }
}

// MARK: - Stub Classes (To be implemented)

internal final class AudioNodePool: @unchecked Sendable {
    init(maxNodes: Int) {}
    func returnNode(_ node: EnhancedAudioNode) {}
}

internal final class AudioConnectionManager: @unchecked Sendable {
    init(maxConnections: Int) {}
    func createConnection(sourceId: AudioNodeID, destinationId: AudioNodeID, sourceOutput: Int, destinationInput: Int) throws -> AudioConnection {
        // Create a default format for mock connections
        guard let defaultFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2) else {
            throw AudioEngineError.configurationError("Failed to create default audio format")
        }
        return AudioConnection(
            sourceNodeId: sourceId, 
            destinationNodeId: destinationId, 
            sourceOutputIndex: sourceOutput, 
            destinationInputIndex: destinationInput,
            format: defaultFormat
        )
    }
    func removeConnection(sourceId: AudioNodeID, destinationId: AudioNodeID) throws {}
}

internal final class AudioProcessingPipeline: @unchecked Sendable {
    init(config: PerformanceConfig) {}
    func initialize() throws {}
    func start() throws {}
    func stop() {}
    func reset() {}
    func addNode(_ node: EnhancedAudioNode) throws {}
    func removeNode(_ node: EnhancedAudioNode) throws {}
    func updateConnections() throws {}
    func updateConfig(_ config: PerformanceConfig) {}
    func handleConfigurationChange(sampleRate: Double, bufferSize: Int) {}
    func process(input: AudioBuffer?, context: AudioProcessingContext) -> AudioBuffer? { return input }
}

internal final class AudioBufferManager: @unchecked Sendable {
    init(config: PerformanceConfig) {}
    func initialize() throws {}
    func reset() {}
    func updateConfig(_ config: PerformanceConfig) {}
}

internal final class AudioFormatManager: @unchecked Sendable {
    func areCompatible(_ format1: AVAudioFormat, _ format2: AVAudioFormat) -> Bool { return true }
}

// AudioThreadPool moved to AudioEngine.swift to avoid duplication
