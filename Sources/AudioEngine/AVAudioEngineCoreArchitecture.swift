// AVAudioEngineCoreArchitecture.swift
// DigitonePad - AudioEngine
//
// Enhanced AVAudioEngine core architecture with advanced graph management
// Provides professional-grade audio processing with optimized performance

import Foundation
import AVFoundation
import Accelerate
import MachineProtocols

// MARK: - Core Architecture Configuration

/// Configuration for AVAudioEngine core architecture
public struct AVAudioEngineCoreConfig: Codable {
    /// Audio session configuration
    public var audioSession: AudioSessionConfig = AudioSessionConfig()
    
    /// Engine configuration
    public var engine: EngineConfig = EngineConfig()
    
    /// Graph management configuration
    public var graphManagement: GraphManagementConfig = GraphManagementConfig()
    
    /// Performance optimization configuration
    public var performance: PerformanceConfig = PerformanceConfig()
    
    /// Real-time safety configuration
    public var realTimeSafety: RealTimeSafetyConfig = RealTimeSafetyConfig()
    
    public init() {}
}

/// Audio session configuration
public struct AudioSessionConfig: Codable {
    public var category: String = "playAndRecord"
    public var mode: String = "default"
    public var options: [String] = ["defaultToSpeaker", "allowBluetooth"]
    public var sampleRate: Double = 44100.0
    public var bufferDuration: Double = 0.005  // 5ms
    public var inputChannels: Int = 2
    public var outputChannels: Int = 2
    public var enableHardwareOptimization: Bool = true
    
    public init() {}
}

/// Engine configuration
public struct EngineConfig: Codable {
    public var enableManualRenderingMode: Bool = false
    public var enableOfflineRendering: Bool = false
    public var maxFramesToRender: UInt32 = 4096
    public var enableAutomaticConfigurationChange: Bool = true
    public var enableInterruption: Bool = true
    public var enableRouteChange: Bool = true
    
    public init() {}
}

/// Graph management configuration
public struct GraphManagementConfig: Codable {
    public var maxNodes: Int = 256
    public var maxConnections: Int = 512
    public var enableDynamicReconnection: Bool = true
    public var enableNodePooling: Bool = true
    public var enableConnectionCaching: Bool = true
    public var graphUpdateBatchSize: Int = 16
    
    public init() {}
}

/// Performance configuration
public struct PerformanceConfig: Codable {
    public var enableSIMDOptimization: Bool = true
    public var enableMultithreading: Bool = true
    public var threadPoolSize: Int = 4
    public var enableBufferPooling: Bool = true
    public var bufferPoolSize: Int = 64
    public var enableMemoryPrefetching: Bool = true
    
    public init() {}
}

/// Real-time safety configuration
public struct RealTimeSafetyConfig: Codable {
    public var enableLockFreeOperations: Bool = true
    public var enableWaitFreeAlgorithms: Bool = true
    public var maxAllocationSize: Int = 0  // No allocations in RT thread
    public var enableDeadlineMonitoring: Bool = true
    public var maxProcessingTimeMs: Double = 2.0
    
    public init() {}
}

// MARK: - Enhanced Audio Node Types

/// Enhanced audio node with advanced capabilities
public protocol EnhancedAudioNode: AudioNode {
    /// Node processing latency in samples
    var processingLatency: Int { get }
    
    /// Node CPU usage percentage (0.0-1.0)
    var cpuUsage: Float { get }
    
    /// Node memory usage in bytes
    var memoryUsage: Int { get }
    
    /// Real-time safety compliance
    var isRealTimeSafe: Bool { get }
    
    /// Process audio with enhanced context
    func processEnhanced(input: AudioBuffer?, context: AudioProcessingContext) -> AudioBuffer?
    
    /// Prepare for real-time processing
    func prepareForRealTime(maxFrames: Int) throws
    
    /// Reset internal state
    func resetState()
    
    /// Get processing statistics
    func getProcessingStats() -> NodeProcessingStats
}

/// Audio processing context with enhanced information
public struct AudioProcessingContext: Sendable {
    /// Current sample time
    public let sampleTime: AVAudioFramePosition
    
    /// Host time in nanoseconds
    public let hostTime: UInt64
    
    /// Processing deadline
    public let deadline: UInt64
    
    /// Buffer size for this processing cycle
    public let bufferSize: Int
    
    /// Sample rate
    public let sampleRate: Double
    
    /// Processing thread priority
    public let threadPriority: Int
    
    /// Real-time processing flag
    public let isRealTime: Bool
    
    public init(sampleTime: AVAudioFramePosition, hostTime: UInt64, deadline: UInt64,
                bufferSize: Int, sampleRate: Double, threadPriority: Int, isRealTime: Bool) {
        self.sampleTime = sampleTime
        self.hostTime = hostTime
        self.deadline = deadline
        self.bufferSize = bufferSize
        self.sampleRate = sampleRate
        self.threadPriority = threadPriority
        self.isRealTime = isRealTime
    }
}

/// Node processing statistics
public struct NodeProcessingStats: Sendable {
    /// Average processing time in microseconds
    public let averageProcessingTime: Double
    
    /// Maximum processing time in microseconds
    public let maxProcessingTime: Double
    
    /// Number of processing cycles
    public let processingCycles: UInt64
    
    /// Number of deadline misses
    public let deadlineMisses: UInt64
    
    /// CPU usage percentage
    public let cpuUsage: Float
    
    /// Memory usage in bytes
    public let memoryUsage: Int
    
    public init(averageProcessingTime: Double, maxProcessingTime: Double,
                processingCycles: UInt64, deadlineMisses: UInt64,
                cpuUsage: Float, memoryUsage: Int) {
        self.averageProcessingTime = averageProcessingTime
        self.maxProcessingTime = maxProcessingTime
        self.processingCycles = processingCycles
        self.deadlineMisses = deadlineMisses
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
    }
}

// MARK: - AVAudioEngine Core Architecture

/// Enhanced AVAudioEngine core architecture with advanced capabilities
public final class AVAudioEngineCoreArchitecture: @unchecked Sendable {
    
    // MARK: - Configuration
    
    public var config: AVAudioEngineCoreConfig {
        didSet {
            updateConfiguration()
        }
    }
    
    // MARK: - Core Components
    
    private let engine: AVAudioEngine
#if os(iOS)
    private let audioSession: AVAudioSession
#endif
    private let graphManager: EnhancedAudioGraphManager
    private let performanceMonitor: AudioPerformanceMonitor
    private let realTimeSafetyManager: RealTimeSafetyManager
    
    // MARK: - Node Management
    
    private var nodeRegistry: [AudioNodeID: EnhancedAudioNode] = [:]
    private var nodePool: AudioNodePool
    private var connectionManager: AudioConnectionManager
    
    // MARK: - Processing Pipeline
    
    private var processingPipeline: AudioProcessingPipeline
    private var bufferManager: AudioBufferManager
    private var formatManager: AudioFormatManager
    
    // MARK: - Thread Management
    
    private let processingQueue: DispatchQueue
    private let configurationQueue: DispatchQueue
    private var threadPool: AudioThreadPool
    
    // MARK: - State Management
    
    private var isInitialized: Bool = false
    private var isRunning: Bool = false
    private var currentSampleRate: Double = 44100.0
    private var currentBufferSize: Int = 512
    
    // MARK: - Performance Tracking
    
    private var performanceMetrics: AudioPerformanceMetrics
    private var processingStats: ProcessingStatistics
    
    // MARK: - Initialization
    
    public init(config: AVAudioEngineCoreConfig = AVAudioEngineCoreConfig()) {
        self.config = config
        self.engine = AVAudioEngine()
#if os(iOS)
        self.audioSession = AVAudioSession.sharedInstance()
#endif
        
        // Initialize managers
        self.graphManager = EnhancedAudioGraphManager(config: config.graphManagement)
        self.performanceMonitor = AudioPerformanceMonitor(config: config.performance)
        self.realTimeSafetyManager = RealTimeSafetyManager(config: config.realTimeSafety)
        
        // Initialize node management
        self.nodePool = AudioNodePool(maxNodes: config.graphManagement.maxNodes)
        self.connectionManager = AudioConnectionManager(maxConnections: config.graphManagement.maxConnections)
        
        // Initialize processing pipeline
        self.processingPipeline = AudioProcessingPipeline(config: config.performance)
        self.bufferManager = AudioBufferManager(config: config.performance)
        self.formatManager = AudioFormatManager()
        
        // Initialize thread management
        self.processingQueue = DispatchQueue(label: "AVAudioEngineCore.Processing", qos: .userInteractive)
        self.configurationQueue = DispatchQueue(label: "AVAudioEngineCore.Configuration", qos: .userInitiated)
        self.threadPool = AudioThreadPool(minThreads: 2, maxThreads: config.performance.threadPoolSize)
        
        // Initialize performance tracking
        self.performanceMetrics = AudioPerformanceMetrics()
        self.processingStats = ProcessingStatistics()
        
        setupEngineCallbacks()
        updateConfiguration()
    }
    
    // MARK: - Lifecycle Management
    
    /// Initialize the audio engine core
    public func initialize() throws {
        try configurationQueue.sync {
            guard !isInitialized else { return }
            
            // Configure audio session
            try configureAudioSession()
            
            // Configure engine
            try configureEngine()
            
            // Initialize graph manager
            try graphManager.initialize()
            
            // Initialize performance monitoring
            try performanceMonitor.initialize()
            
            // Initialize real-time safety
            try realTimeSafetyManager.initialize()
            
            // Initialize processing pipeline
            try processingPipeline.initialize()
            
            // Initialize buffer management
            try bufferManager.initialize()
            
            isInitialized = true
        }
    }
    
    /// Start the audio engine
    public func start() throws {
        try processingQueue.sync {
            guard isInitialized && !isRunning else {
                throw AudioEngineError.engineStartFailed("Engine not ready to start")
            }
            
            // Start performance monitoring
            performanceMonitor.start()
            
            // Start real-time safety monitoring
            realTimeSafetyManager.start()
            
            // Start the engine
            try engine.start()
            
            // Start processing pipeline
            try processingPipeline.start()
            
            isRunning = true
        }
    }
    
    /// Stop the audio engine
    public func stop() {
        processingQueue.sync {
            guard isRunning else { return }
            
            // Stop processing pipeline
            processingPipeline.stop()
            
            // Stop the engine
            engine.stop()
            
            // Stop monitoring
            realTimeSafetyManager.stop()
            performanceMonitor.stop()
            
            isRunning = false
        }
    }
    
    /// Reset the audio engine
    public func reset() throws {
        stop()
        
        try configurationQueue.sync {
            // Reset all components
            graphManager.reset()
            performanceMonitor.reset()
            processingPipeline.reset()
            bufferManager.reset()
            
            // Clear node registry
            nodeRegistry.removeAll()
            
            // Reset performance metrics
            performanceMetrics.reset()
            processingStats.reset()
            
            isInitialized = false
        }
    }

    // MARK: - Node Management

    /// Add an enhanced audio node to the graph
    public func addNode(_ node: EnhancedAudioNode) throws {
        try configurationQueue.sync {
            guard nodeRegistry[node.id] == nil else {
                throw AudioEngineError.configurationError("Node already exists")
            }

            // Validate real-time safety
            if config.realTimeSafety.enableLockFreeOperations && !node.isRealTimeSafe {
                throw AudioEngineError.configurationError("Node is not real-time safe")
            }

            // Prepare node for real-time processing
            try node.prepareForRealTime(maxFrames: currentBufferSize)

            // Add to registry and graph
            nodeRegistry[node.id] = node
            try graphManager.addNode(node)

            // Update processing pipeline
            try processingPipeline.addNode(node)
        }
    }

    /// Remove a node from the graph
    public func removeNode(id: AudioNodeID) throws {
        try configurationQueue.sync {
            guard let node = nodeRegistry[id] else {
                throw AudioEngineError.configurationError("Node not found")
            }

            // Remove from processing pipeline
            try processingPipeline.removeNode(node)

            // Remove from graph
            try graphManager.removeNode(id: id)

            // Remove from registry
            nodeRegistry.removeValue(forKey: id)

            // Return node to pool if applicable
            nodePool.returnNode(node)
        }
    }

    /// Connect two nodes with enhanced validation
    public func connectNodes(sourceId: AudioNodeID, destinationId: AudioNodeID,
                           sourceOutput: Int = 0, destinationInput: Int = 0) throws {
        try configurationQueue.sync {
            guard let sourceNode = nodeRegistry[sourceId],
                  let destinationNode = nodeRegistry[destinationId] else {
                throw AudioEngineError.configurationError("Node not found")
            }

            // Validate connection compatibility
            try validateConnection(source: sourceNode, destination: destinationNode,
                                 sourceOutput: sourceOutput, destinationInput: destinationInput)

            // Create connection
            let connection = try connectionManager.createConnection(
                sourceId: sourceId, destinationId: destinationId,
                sourceOutput: sourceOutput, destinationInput: destinationInput
            )

            // Add to graph
            try graphManager.addConnection(connection)

            // Update processing pipeline
            try processingPipeline.updateConnections()
        }
    }

    /// Disconnect two nodes
    public func disconnectNodes(sourceId: AudioNodeID, destinationId: AudioNodeID) throws {
        try configurationQueue.sync {
            // Remove from graph
            try graphManager.removeConnection(sourceId: sourceId, destinationId: destinationId)

            // Remove from connection manager
            try connectionManager.removeConnection(sourceId: sourceId, destinationId: destinationId)

            // Update processing pipeline
            try processingPipeline.updateConnections()
        }
    }

    // MARK: - Audio Processing

    /// Process audio through the enhanced graph
    public func processAudio(inputBuffer: AudioBuffer?, context: AudioProcessingContext) -> AudioBuffer? {
        guard isRunning else { return inputBuffer }

        performanceMonitor.startProcessingCycle()
        realTimeSafetyManager.checkDeadline(context.deadline)

        // Process through pipeline
        let outputBuffer = processingPipeline.process(input: inputBuffer, context: context)

        // Update performance metrics
        performanceMonitor.endProcessingCycle()
        processingStats.recordCycle()

        return outputBuffer
    }

    /// Get current performance metrics
    public func getPerformanceMetrics() -> AudioPerformanceMetrics {
        return performanceMonitor.getCurrentMetrics()
    }

    /// Get processing statistics
    public func getProcessingStatistics() -> ProcessingStatistics {
        return processingStats
    }

    /// Get real-time safety status
    public func getRealTimeSafetyStatus() -> RealTimeSafetyStatus {
        return realTimeSafetyManager.getCurrentStatus()
    }

    // MARK: - Configuration Management

    private func updateConfiguration() {
        // Update all components with new configuration
        graphManager.updateConfig(config.graphManagement)
        performanceMonitor.updateConfig(config.performance)
        realTimeSafetyManager.updateConfig(config.realTimeSafety)
        processingPipeline.updateConfig(config.performance)
        bufferManager.updateConfig(config.performance)
    }

    private func configureAudioSession() throws {
#if os(iOS)
        let sessionConfig = config.audioSession

        try audioSession.setCategory(
            AVAudioSession.Category(rawValue: sessionConfig.category),
            mode: AVAudioSession.Mode(rawValue: sessionConfig.mode),
            options: AVAudioSession.CategoryOptions(sessionConfig.options.map { AVAudioSession.CategoryOptions(rawValue: $0) })
        )

        try audioSession.setPreferredSampleRate(sessionConfig.sampleRate)
        try audioSession.setPreferredIOBufferDuration(sessionConfig.bufferDuration)
        try audioSession.setPreferredInputNumberOfChannels(sessionConfig.inputChannels)
        try audioSession.setPreferredOutputNumberOfChannels(sessionConfig.outputChannels)

        if sessionConfig.enableHardwareOptimization {
            try audioSession.setActive(true)
        }

        currentSampleRate = audioSession.sampleRate
        currentBufferSize = Int(audioSession.sampleRate * audioSession.ioBufferDuration)
#else
        // macOS: Use default sample rate and buffer size
        currentSampleRate = 44100.0
        currentBufferSize = 512
#endif
    }

    private func configureEngine() throws {
        let engineConfig = config.engine

        if engineConfig.enableManualRenderingMode {
            // Configure for manual rendering
            let format = AVAudioFormat(standardFormatWithSampleRate: currentSampleRate, channels: 2)!
            try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: engineConfig.maxFramesToRender)
        }

        // Setup engine callbacks
        setupEngineCallbacks()
    }

    private func setupEngineCallbacks() {
#if os(iOS)
        // Configuration change callback
        engine.configurationChangeBlock = { [weak self] in
            self?.handleConfigurationChange()
        }

        // Add interruption handling if needed
        if config.engine.enableInterruption {
            NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleAudioInterruption(notification)
            }
        }

        // Add route change handling if needed
        if config.engine.enableRouteChange {
            NotificationCenter.default.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleRouteChange(notification)
            }
        }
#endif
    }

    private func validateConnection(source: EnhancedAudioNode, destination: EnhancedAudioNode,
                                  sourceOutput: Int, destinationInput: Int) throws {
        // Validate output index
        guard sourceOutput < source.maxOutputs else {
            throw AudioEngineError.configurationError("Invalid source output index")
        }

        // Validate input index
        guard destinationInput < destination.maxInputs else {
            throw AudioEngineError.configurationError("Invalid destination input index")
        }

        // Validate format compatibility
        if let sourceFormat = source.outputFormat,
           let destinationFormat = destination.inputFormat {
            guard formatManager.areCompatible(sourceFormat, destinationFormat) else {
                throw AudioEngineError.configurationError("Incompatible audio formats")
            }
        }

        // Validate real-time safety
        if config.realTimeSafety.enableLockFreeOperations {
            guard source.isRealTimeSafe && destination.isRealTimeSafe else {
                throw AudioEngineError.configurationError("Connection involves non-real-time-safe nodes")
            }
        }
    }

    // MARK: - Event Handlers

    private func handleConfigurationChange() {
        configurationQueue.async { [weak self] in
            guard let self = self else { return }

#if os(iOS)
            // Update current audio parameters
            self.currentSampleRate = self.audioSession.sampleRate
            self.currentBufferSize = Int(self.audioSession.sampleRate * self.audioSession.ioBufferDuration)
#endif

            // Notify components of configuration change
            self.graphManager.handleConfigurationChange(sampleRate: self.currentSampleRate, bufferSize: self.currentBufferSize)
            self.processingPipeline.handleConfigurationChange(sampleRate: self.currentSampleRate, bufferSize: self.currentBufferSize)
        }
    }

    private func handleAudioInterruption(_ notification: Notification) {
#if os(iOS)
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            stop()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    try? start()
                }
            }
        @unknown default:
            break
        }
#endif
    }

    private func handleRouteChange(_ notification: Notification) {
#if os(iOS)
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            // Handle device changes
            configurationQueue.async { [weak self] in
                self?.handleConfigurationChange()
            }
        default:
            break
        }
#endif
    }
}
