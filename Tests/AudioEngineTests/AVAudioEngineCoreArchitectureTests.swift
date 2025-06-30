// AVAudioEngineCoreArchitectureTests.swift
// DigitonePad - AudioEngineTests
//
// Comprehensive test suite for AVAudioEngine Core Architecture

import XCTest
import AVFoundation
@testable import AudioEngine

final class AVAudioEngineCoreArchitectureTests: XCTestCase {
    
    var coreArchitecture: AVAudioEngineCoreArchitecture!
    var config: AVAudioEngineCoreConfig!
    
    override func setUp() {
        super.setUp()
        config = AVAudioEngineCoreConfig()
        coreArchitecture = AVAudioEngineCoreArchitecture(config: config)
    }
    
    override func tearDown() {
        coreArchitecture = nil
        config = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialization() {
        XCTAssertNotNil(coreArchitecture)
        XCTAssertEqual(coreArchitecture.config.audioSession.sampleRate, 44100.0)
        XCTAssertEqual(coreArchitecture.config.audioSession.bufferDuration, 0.005)
        XCTAssertTrue(coreArchitecture.config.performance.enableSIMDOptimization)
    }
    
    func testConfigurationUpdate() {
        var newConfig = AVAudioEngineCoreConfig()
        newConfig.audioSession.sampleRate = 48000.0
        newConfig.performance.enableMultithreading = false
        
        coreArchitecture.config = newConfig
        
        XCTAssertEqual(coreArchitecture.config.audioSession.sampleRate, 48000.0)
        XCTAssertFalse(coreArchitecture.config.performance.enableMultithreading)
    }
    
    func testLifecycleManagement() {
        // Test initialization
        XCTAssertNoThrow(try coreArchitecture.initialize())
        
        // Test start
        XCTAssertNoThrow(try coreArchitecture.start())
        
        // Test stop
        coreArchitecture.stop()
        
        // Test reset
        XCTAssertNoThrow(try coreArchitecture.reset())
    }
    
    // MARK: - Configuration Tests
    
    func testAudioSessionConfiguration() {
        var sessionConfig = AudioSessionConfig()
        sessionConfig.category = "playback"
        sessionConfig.sampleRate = 48000.0
        sessionConfig.bufferDuration = 0.010
        sessionConfig.inputChannels = 1
        sessionConfig.outputChannels = 2
        
        config.audioSession = sessionConfig
        coreArchitecture.config = config
        
        XCTAssertEqual(coreArchitecture.config.audioSession.category, "playback")
        XCTAssertEqual(coreArchitecture.config.audioSession.sampleRate, 48000.0)
        XCTAssertEqual(coreArchitecture.config.audioSession.bufferDuration, 0.010)
        XCTAssertEqual(coreArchitecture.config.audioSession.inputChannels, 1)
        XCTAssertEqual(coreArchitecture.config.audioSession.outputChannels, 2)
    }
    
    func testEngineConfiguration() {
        var engineConfig = EngineConfig()
        engineConfig.enableManualRenderingMode = true
        engineConfig.enableOfflineRendering = true
        engineConfig.maxFramesToRender = 8192
        
        config.engine = engineConfig
        coreArchitecture.config = config
        
        XCTAssertTrue(coreArchitecture.config.engine.enableManualRenderingMode)
        XCTAssertTrue(coreArchitecture.config.engine.enableOfflineRendering)
        XCTAssertEqual(coreArchitecture.config.engine.maxFramesToRender, 8192)
    }
    
    func testGraphManagementConfiguration() {
        var graphConfig = GraphManagementConfig()
        graphConfig.maxNodes = 128
        graphConfig.maxConnections = 256
        graphConfig.enableDynamicReconnection = false
        graphConfig.enableNodePooling = false
        
        config.graphManagement = graphConfig
        coreArchitecture.config = config
        
        XCTAssertEqual(coreArchitecture.config.graphManagement.maxNodes, 128)
        XCTAssertEqual(coreArchitecture.config.graphManagement.maxConnections, 256)
        XCTAssertFalse(coreArchitecture.config.graphManagement.enableDynamicReconnection)
        XCTAssertFalse(coreArchitecture.config.graphManagement.enableNodePooling)
    }
    
    func testPerformanceConfiguration() {
        var perfConfig = PerformanceConfig()
        perfConfig.enableSIMDOptimization = false
        perfConfig.enableMultithreading = false
        perfConfig.threadPoolSize = 2
        perfConfig.bufferPoolSize = 32
        
        config.performance = perfConfig
        coreArchitecture.config = config
        
        XCTAssertFalse(coreArchitecture.config.performance.enableSIMDOptimization)
        XCTAssertFalse(coreArchitecture.config.performance.enableMultithreading)
        XCTAssertEqual(coreArchitecture.config.performance.threadPoolSize, 2)
        XCTAssertEqual(coreArchitecture.config.performance.bufferPoolSize, 32)
    }
    
    func testRealTimeSafetyConfiguration() {
        var safetyConfig = RealTimeSafetyConfig()
        safetyConfig.enableLockFreeOperations = false
        safetyConfig.enableWaitFreeAlgorithms = false
        safetyConfig.maxProcessingTimeMs = 5.0
        
        config.realTimeSafety = safetyConfig
        coreArchitecture.config = config
        
        XCTAssertFalse(coreArchitecture.config.realTimeSafety.enableLockFreeOperations)
        XCTAssertFalse(coreArchitecture.config.realTimeSafety.enableWaitFreeAlgorithms)
        XCTAssertEqual(coreArchitecture.config.realTimeSafety.maxProcessingTimeMs, 5.0)
    }
    
    // MARK: - Node Management Tests
    
    func testNodeManagement() {
        let mockNode = MockEnhancedAudioNode()
        
        XCTAssertNoThrow(try coreArchitecture.initialize())
        
        // Test adding node
        XCTAssertNoThrow(try coreArchitecture.addNode(mockNode))
        
        // Test removing node
        XCTAssertNoThrow(try coreArchitecture.removeNode(id: mockNode.id))
    }
    
    func testNodeConnection() {
        let sourceNode = MockEnhancedAudioNode()
        let destinationNode = MockEnhancedAudioNode()
        
        XCTAssertNoThrow(try coreArchitecture.initialize())
        XCTAssertNoThrow(try coreArchitecture.addNode(sourceNode))
        XCTAssertNoThrow(try coreArchitecture.addNode(destinationNode))
        
        // Test connecting nodes
        XCTAssertNoThrow(try coreArchitecture.connectNodes(
            sourceId: sourceNode.id,
            destinationId: destinationNode.id
        ))
        
        // Test disconnecting nodes
        XCTAssertNoThrow(try coreArchitecture.disconnectNodes(
            sourceId: sourceNode.id,
            destinationId: destinationNode.id
        ))
    }
    
    func testRealTimeSafetyValidation() {
        var safetyConfig = RealTimeSafetyConfig()
        safetyConfig.enableLockFreeOperations = true
        config.realTimeSafety = safetyConfig
        coreArchitecture.config = config
        
        let nonRealTimeSafeNode = MockEnhancedAudioNode()
        nonRealTimeSafeNode.isRealTimeSafe = false
        
        XCTAssertNoThrow(try coreArchitecture.initialize())
        
        // Should throw error for non-real-time-safe node
        XCTAssertThrowsError(try coreArchitecture.addNode(nonRealTimeSafeNode))
    }
    
    // MARK: - Audio Processing Tests
    
    func testAudioProcessing() {
        XCTAssertNoThrow(try coreArchitecture.initialize())
        XCTAssertNoThrow(try coreArchitecture.start())
        
        // Create test audio buffer
        let bufferSize = 512
        let channelCount = 2
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize * channelCount)
        
        // Fill with test signal
        for i in 0..<(bufferSize * channelCount) {
            inputData[i] = sin(Float(i) * 0.1)
        }
        
        let inputBuffer = AudioBuffer(
            data: inputData,
            frameCount: bufferSize,
            channelCount: channelCount,
            sampleRate: 44100.0
        )
        
        // Create processing context
        let context = AudioProcessingContext(
            sampleTime: 0,
            hostTime: mach_absolute_time(),
            deadline: mach_absolute_time() + 1000000, // 1ms deadline
            bufferSize: bufferSize,
            sampleRate: 44100.0,
            threadPriority: 47,
            isRealTime: true
        )
        
        // Process audio
        let outputBuffer = coreArchitecture.processAudio(inputBuffer: inputBuffer, context: context)
        
        // Should return a buffer
        XCTAssertNotNil(outputBuffer)
        
        inputData.deallocate()
        coreArchitecture.stop()
    }
    
    // MARK: - Performance Monitoring Tests
    
    func testPerformanceMetrics() {
        XCTAssertNoThrow(try coreArchitecture.initialize())
        XCTAssertNoThrow(try coreArchitecture.start())
        
        // Get initial metrics
        let metrics = coreArchitecture.getPerformanceMetrics()
        XCTAssertGreaterThanOrEqual(metrics.averageProcessingTime, 0.0)
        XCTAssertGreaterThanOrEqual(metrics.cpuUsage, 0.0)
        XCTAssertLessThanOrEqual(metrics.cpuUsage, 1.0)
        
        coreArchitecture.stop()
    }
    
    func testProcessingStatistics() {
        XCTAssertNoThrow(try coreArchitecture.initialize())
        
        let stats = coreArchitecture.getProcessingStatistics()
        XCTAssertGreaterThanOrEqual(stats.totalCycles, 0)
        XCTAssertGreaterThanOrEqual(stats.successfulCycles, 0)
        XCTAssertGreaterThanOrEqual(stats.averageCycleTime, 0.0)
    }
    
    func testRealTimeSafetyStatus() {
        XCTAssertNoThrow(try coreArchitecture.initialize())
        
        let status = coreArchitecture.getRealTimeSafetyStatus()
        XCTAssertGreaterThanOrEqual(status.safetyPercentage, 0.0)
        XCTAssertLessThanOrEqual(status.safetyPercentage, 100.0)
        XCTAssertGreaterThanOrEqual(status.deadlineMisses, 0)
        XCTAssertGreaterThanOrEqual(status.totalDeadlines, 0)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() {
        // Test starting without initialization
        XCTAssertThrowsError(try coreArchitecture.start())
        
        // Test adding node without initialization
        let mockNode = MockEnhancedAudioNode()
        XCTAssertThrowsError(try coreArchitecture.addNode(mockNode))
    }
    
    // MARK: - Performance Tests
    
    func testInitializationPerformance() {
        measure {
            let testCore = AVAudioEngineCoreArchitecture(config: config)
            try? testCore.initialize()
        }
    }
    
    func testNodeManagementPerformance() {
        XCTAssertNoThrow(try coreArchitecture.initialize())
        
        measure {
            for i in 0..<100 {
                let node = MockEnhancedAudioNode()
                node.name = "TestNode\(i)"
                try? coreArchitecture.addNode(node)
            }
        }
    }
    
    func testAudioProcessingPerformance() {
        XCTAssertNoThrow(try coreArchitecture.initialize())
        XCTAssertNoThrow(try coreArchitecture.start())
        
        let bufferSize = 512
        let channelCount = 2
        let inputData = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize * channelCount)
        
        for i in 0..<(bufferSize * channelCount) {
            inputData[i] = sin(Float(i) * 0.1)
        }
        
        let inputBuffer = AudioBuffer(
            data: inputData,
            frameCount: bufferSize,
            channelCount: channelCount,
            sampleRate: 44100.0
        )
        
        let context = AudioProcessingContext(
            sampleTime: 0,
            hostTime: mach_absolute_time(),
            deadline: mach_absolute_time() + 1000000,
            bufferSize: bufferSize,
            sampleRate: 44100.0,
            threadPriority: 47,
            isRealTime: true
        )
        
        measure {
            for _ in 0..<1000 {
                _ = coreArchitecture.processAudio(inputBuffer: inputBuffer, context: context)
            }
        }
        
        inputData.deallocate()
        coreArchitecture.stop()
    }
}

// MARK: - Mock Enhanced Audio Node

class MockEnhancedAudioNode: EnhancedAudioNode {
    let id = UUID()
    var name: String = "MockNode"
    let nodeType: AudioNodeType = .generator
    var status: AudioNodeStatus = .inactive
    var isBypassed: Bool = false
    let maxInputs: Int = 1
    let maxOutputs: Int = 1
    var inputFormat: AVAudioFormat?
    var outputFormat: AVAudioFormat?
    var inputConnections: [AudioConnection] = []
    var outputConnections: [AudioConnection] = []
    
    var processingLatency: Int = 0
    var cpuUsage: Float = 0.1
    var memoryUsage: Int = 1024
    var isRealTimeSafe: Bool = true
    
    func process(input: AudioBuffer?) -> AudioBuffer? {
        return input
    }
    
    func processEnhanced(input: AudioBuffer?, context: AudioProcessingContext) -> AudioBuffer? {
        return input
    }
    
    func prepare(format: AVAudioFormat) throws {
        inputFormat = format
        outputFormat = format
        status = .active
    }
    
    func prepareForRealTime(maxFrames: Int) throws {
        // Mock preparation
    }
    
    func resetState() {
        // Mock reset
    }
    
    func getProcessingStats() -> NodeProcessingStats {
        return NodeProcessingStats(
            averageProcessingTime: 10.0,
            maxProcessingTime: 50.0,
            processingCycles: 1000,
            deadlineMisses: 0,
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage
        )
    }
}
