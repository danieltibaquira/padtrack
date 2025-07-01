import Foundation
import AVFoundation
@testable import AudioEngine
@testable import MachineProtocols

/// Mock implementation of AudioEngine for testing
public class MockAudioEngine: AudioEngineProtocol {
    
    // MARK: - Properties
    
    public var isRunning: Bool = false
    public var isInitialized: Bool = false
    public var sampleRate: Double = 44100.0
    public var bufferSize: Int = 512
    public var channelCount: Int = 2
    public var cpuUsage: Float = 0.0
    public var latency: TimeInterval = 0.0
    
    private var shouldFailOperations: Bool = false
    private var simulatedLatency: TimeInterval = 0.005 // 5ms default
    private var simulatedCPUUsage: Float = 0.1 // 10% default
    private var connectedNodes: [MockAudioNode] = []
    
    // MARK: - Mock Configuration
    
    public init() {}
    
    /// Configure the mock to simulate operation failures
    public func setShouldFailOperations(_ shouldFail: Bool) {
        self.shouldFailOperations = shouldFail
    }
    
    /// Configure simulated latency
    public func setSimulatedLatency(_ latency: TimeInterval) {
        self.simulatedLatency = latency
        self.latency = latency
    }
    
    /// Configure simulated CPU usage
    public func setSimulatedCPUUsage(_ usage: Float) {
        self.simulatedCPUUsage = usage
        self.cpuUsage = usage
    }
    
    // MARK: - AudioEngineProtocol Implementation
    
    public func initialize(sampleRate: Double, bufferSize: Int, channelCount: Int) throws {
        if shouldFailOperations {
            throw AudioEngineError.initializationFailed("Mock initialization failure")
        }
        
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
        self.channelCount = channelCount
        self.isInitialized = true
        self.latency = simulatedLatency
        self.cpuUsage = simulatedCPUUsage
    }
    
    public func start() throws {
        if shouldFailOperations {
            throw AudioEngineError.startFailed("Mock start failure")
        }
        
        guard isInitialized else {
            throw AudioEngineError.notInitialized("Engine not initialized")
        }
        
        isRunning = true
    }
    
    public func stop() throws {
        if shouldFailOperations {
            throw AudioEngineError.stopFailed("Mock stop failure")
        }
        
        isRunning = false
    }
    
    public func suspend() throws {
        if shouldFailOperations {
            throw AudioEngineError.suspendFailed("Mock suspend failure")
        }
        
        isRunning = false
    }
    
    public func resume() throws {
        if shouldFailOperations {
            throw AudioEngineError.resumeFailed("Mock resume failure")
        }
        
        guard isInitialized else {
            throw AudioEngineError.notInitialized("Engine not initialized")
        }
        
        isRunning = true
    }
    
    public func shutdown() {
        isRunning = false
        isInitialized = false
        connectedNodes.removeAll()
    }
    
    // MARK: - Audio Graph Management
    
    public func connectNode(_ node: MockAudioNode, to destination: MockAudioNode) throws {
        if shouldFailOperations {
            throw AudioEngineError.connectionFailed("Mock connection failure")
        }
        
        if !connectedNodes.contains(where: { $0.id == node.id }) {
            connectedNodes.append(node)
        }
        
        if !connectedNodes.contains(where: { $0.id == destination.id }) {
            connectedNodes.append(destination)
        }
        
        node.connectTo(destination)
    }
    
    public func disconnectNode(_ node: MockAudioNode) throws {
        if shouldFailOperations {
            throw AudioEngineError.disconnectionFailed("Mock disconnection failure")
        }
        
        connectedNodes.removeAll { $0.id == node.id }
        node.disconnect()
    }
    
    public func getConnectedNodes() -> [MockAudioNode] {
        return connectedNodes
    }
    
    // MARK: - Audio Processing
    
    public func processAudio(inputBuffer: AudioEngine.AudioBuffer) -> AudioEngine.AudioBuffer {
        // Simulate audio processing by copying input to output with slight modification
        let outputData = UnsafeMutablePointer<Float>.allocate(capacity: inputBuffer.frameCount * inputBuffer.channelCount)
        
        for i in 0..<(inputBuffer.frameCount * inputBuffer.channelCount) {
            // Apply a simple gain reduction to simulate processing
            outputData[i] = inputBuffer.data[i] * 0.95
        }
        
        return AudioEngine.AudioBuffer(
            data: outputData,
            frameCount: inputBuffer.frameCount,
            channelCount: inputBuffer.channelCount,
            sampleRate: inputBuffer.sampleRate
        )
    }
    
    // MARK: - Performance Monitoring
    
    public func updatePerformanceMetrics() {
        // Simulate varying CPU usage
        cpuUsage = simulatedCPUUsage + Float.random(in: -0.02...0.02)
        cpuUsage = max(0.0, min(1.0, cpuUsage))
        
        // Simulate varying latency
        latency = simulatedLatency + Double.random(in: -0.001...0.001)
        latency = max(0.0, latency)
    }
    
    public func getPerformanceReport() -> AudioPerformanceReport {
        updatePerformanceMetrics()
        
        return AudioPerformanceReport(
            cpuUsage: cpuUsage,
            memoryUsage: Float.random(in: 0.1...0.3), // Simulate 10-30% memory usage
            latency: latency,
            bufferUnderruns: Int.random(in: 0...2),
            droppedFrames: Int.random(in: 0...5)
        )
    }
}

// MARK: - Mock Audio Node

public class MockAudioNode: Identifiable {
    public let id = UUID()
    public var name: String
    public var isEnabled: Bool = true
    public var inputConnections: [MockAudioNode] = []
    public var outputConnections: [MockAudioNode] = []
    
    public init(name: String) {
        self.name = name
    }
    
    public func connectTo(_ destination: MockAudioNode) {
        if !outputConnections.contains(where: { $0.id == destination.id }) {
            outputConnections.append(destination)
        }
        
        if !destination.inputConnections.contains(where: { $0.id == self.id }) {
            destination.inputConnections.append(self)
        }
    }
    
    public func disconnect() {
        // Remove this node from all output connections' input lists
        for output in outputConnections {
            output.inputConnections.removeAll { $0.id == self.id }
        }
        
        // Remove this node from all input connections' output lists
        for input in inputConnections {
            input.outputConnections.removeAll { $0.id == self.id }
        }
        
        inputConnections.removeAll()
        outputConnections.removeAll()
    }
    
    public func processAudio(_ buffer: AudioEngine.AudioBuffer) -> AudioEngine.AudioBuffer {
        // Mock audio processing - just pass through with slight modification
        let outputData = UnsafeMutablePointer<Float>.allocate(capacity: buffer.frameCount * buffer.channelCount)
        
        for i in 0..<(buffer.frameCount * buffer.channelCount) {
            outputData[i] = buffer.data[i] * (isEnabled ? 1.0 : 0.0)
        }
        
        return AudioEngine.AudioBuffer(
            data: outputData,
            frameCount: buffer.frameCount,
            channelCount: buffer.channelCount,
            sampleRate: buffer.sampleRate
        )
    }
}

// MARK: - Supporting Types

public struct AudioPerformanceReport {
    public let cpuUsage: Float
    public let memoryUsage: Float
    public let latency: TimeInterval
    public let bufferUnderruns: Int
    public let droppedFrames: Int
    
    public init(cpuUsage: Float, memoryUsage: Float, latency: TimeInterval, bufferUnderruns: Int, droppedFrames: Int) {
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.latency = latency
        self.bufferUnderruns = bufferUnderruns
        self.droppedFrames = droppedFrames
    }
}

// MARK: - Protocol Definitions

public protocol AudioEngineProtocol {
    var isRunning: Bool { get }
    var isInitialized: Bool { get }
    var sampleRate: Double { get }
    var bufferSize: Int { get }
    var channelCount: Int { get }
    var cpuUsage: Float { get }
    var latency: TimeInterval { get }
    
    func initialize(sampleRate: Double, bufferSize: Int, channelCount: Int) throws
    func start() throws
    func stop() throws
    func suspend() throws
    func resume() throws
    func shutdown()
    func processAudio(inputBuffer: AudioEngine.AudioBuffer) -> AudioEngine.AudioBuffer
    func getPerformanceReport() -> AudioPerformanceReport
}

// MARK: - Error Types

public enum AudioEngineError: Error, LocalizedError {
    case initializationFailed(String)
    case startFailed(String)
    case stopFailed(String)
    case suspendFailed(String)
    case resumeFailed(String)
    case connectionFailed(String)
    case disconnectionFailed(String)
    case notInitialized(String)
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "Audio engine initialization failed: \(message)"
        case .startFailed(let message):
            return "Audio engine start failed: \(message)"
        case .stopFailed(let message):
            return "Audio engine stop failed: \(message)"
        case .suspendFailed(let message):
            return "Audio engine suspend failed: \(message)"
        case .resumeFailed(let message):
            return "Audio engine resume failed: \(message)"
        case .connectionFailed(let message):
            return "Audio node connection failed: \(message)"
        case .disconnectionFailed(let message):
            return "Audio node disconnection failed: \(message)"
        case .notInitialized(let message):
            return "Audio engine not initialized: \(message)"
        }
    }
}
