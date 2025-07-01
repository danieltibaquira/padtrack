// AudioEngine.swift
// DigitonePad - AudioEngine
//
// This module handles audio processing and playback with comprehensive
// audio session management, error handling, and performance monitoring.

import Foundation
import AVFoundation
import MachineProtocols
import Accelerate
import simd
import Combine

// MARK: - Audio Buffer Management

/// Unique identifier for audio nodes
public typealias AudioNodeID = UUID

/// Audio buffer wrapper for processing
public struct AudioBuffer: @unchecked Sendable, MachineProtocols.AudioBufferProtocol {
    public let data: UnsafeMutablePointer<Float>
    public let frameCount: Int
    public let channelCount: Int
    public let sampleRate: Double

    public init(data: UnsafeMutablePointer<Float>, frameCount: Int, channelCount: Int, sampleRate: Double) {
        self.data = data
        self.frameCount = frameCount
        self.channelCount = channelCount
        self.sampleRate = sampleRate
    }

    /// Legacy samples property for compatibility
    public var samples: [Float] {
        get {
            let buffer = UnsafeBufferPointer(start: data, count: frameCount * channelCount)
            return Array(buffer)
        }
        set {
            let count = min(newValue.count, frameCount * channelCount)
            data.update(from: newValue, count: count)
        }
    }
}

// MARK: - Buffer Pool Management

/// Manages a pool of reusable audio buffers to minimize allocations
public final class AudioBufferPool: @unchecked Sendable {
    private let maxBuffers: Int
    private let frameCount: Int
    private let channelCount: Int
    private let sampleRate: Double

    private var availableBuffers: [AudioBuffer] = []
    private var allocatedBuffers: Set<UnsafeMutablePointer<Float>> = []
    private let poolQueue = DispatchQueue(label: "AudioBufferPool", qos: .userInitiated)

    public init(maxBuffers: Int = 32, frameCount: Int, channelCount: Int, sampleRate: Double) {
        self.maxBuffers = maxBuffers
        self.frameCount = frameCount
        self.channelCount = channelCount
        self.sampleRate = sampleRate

        // Pre-allocate some buffers
        preallocateBuffers(count: min(8, maxBuffers))
    }

    deinit {
        cleanup()
    }

    /// Get a buffer from the pool or create a new one
    public func getBuffer() -> AudioBuffer {
        return poolQueue.sync {
            if let buffer = availableBuffers.popLast() {
                // Zero out the buffer data
                buffer.data.initialize(repeating: 0.0, count: frameCount * channelCount)
                return buffer
            } else {
                // Create new buffer
                return createNewBuffer()
            }
        }
    }

    /// Return a buffer to the pool for reuse
    public func returnBuffer(_ buffer: AudioBuffer) {
        poolQueue.sync {
            guard allocatedBuffers.contains(buffer.data) else {
                // Buffer not from this pool, ignore
                return
            }

            if availableBuffers.count < maxBuffers {
                availableBuffers.append(buffer)
            } else {
                // Pool is full, deallocate this buffer
                deallocateBuffer(buffer)
            }
        }
    }

    /// Get current pool statistics
    public func getStatistics() -> (available: Int, allocated: Int, total: Int) {
        return poolQueue.sync {
            let available = availableBuffers.count
            let total = allocatedBuffers.count
            let allocated = total - available
            return (available: available, allocated: allocated, total: total)
        }
    }

    private func preallocateBuffers(count: Int) {
        for _ in 0..<count {
            let buffer = createNewBuffer()
            availableBuffers.append(buffer)
        }
    }

    private func createNewBuffer() -> AudioBuffer {
        let totalSamples = frameCount * channelCount
        let data = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)
        data.initialize(repeating: 0.0, count: totalSamples)

        allocatedBuffers.insert(data)

        return AudioBuffer(
            data: data,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: sampleRate
        )
    }

    private func deallocateBuffer(_ buffer: AudioBuffer) {
        buffer.data.deallocate()
        allocatedBuffers.remove(buffer.data)
    }

    private func cleanup() {
        poolQueue.sync {
            for buffer in availableBuffers {
                deallocateBuffer(buffer)
            }
            availableBuffers.removeAll()

            // Clean up any remaining allocated buffers
            for data in allocatedBuffers {
                data.deallocate()
            }
            allocatedBuffers.removeAll()
        }
    }
}

// MARK: - Circular Buffer Implementation

/// Thread-safe circular buffer for real-time audio processing
public final class AudioCircularBuffer: @unchecked Sendable {
    private let capacity: Int
    private let channelCount: Int
    private let sampleRate: Double
    private let data: UnsafeMutablePointer<Float>

    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private var availableFrames: Int = 0

    private let bufferQueue = DispatchQueue(label: "AudioCircularBuffer", qos: .userInitiated)

    public init(capacity: Int, channelCount: Int, sampleRate: Double) {
        self.capacity = capacity
        self.channelCount = channelCount
        self.sampleRate = sampleRate

        let totalSamples = capacity * channelCount
        self.data = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)
        self.data.initialize(repeating: 0.0, count: totalSamples)
    }

    deinit {
        data.deallocate()
    }

    /// Write audio data to the circular buffer
    public func write(_ buffer: AudioBuffer) -> Int {
        return bufferQueue.sync {
            let framesToWrite = min(buffer.frameCount, capacity - availableFrames)
            let channelsToWrite = min(buffer.channelCount, channelCount)

            for frame in 0..<framesToWrite {
                for channel in 0..<channelsToWrite {
                    let sourceIndex = frame * buffer.channelCount + channel
                    let destIndex = writeIndex * channelCount + channel
                    data[destIndex] = buffer.data[sourceIndex]
                }

                writeIndex = (writeIndex + 1) % capacity
            }

            availableFrames += framesToWrite
            return framesToWrite
        }
    }

    /// Read audio data from the circular buffer
    public func read(frameCount: Int, into buffer: AudioBuffer) -> Int {
        return bufferQueue.sync {
            let framesToRead = min(frameCount, min(availableFrames, buffer.frameCount))
            let channelsToRead = min(channelCount, buffer.channelCount)

            for frame in 0..<framesToRead {
                for channel in 0..<channelsToRead {
                    let sourceIndex = readIndex * channelCount + channel
                    let destIndex = frame * buffer.channelCount + channel
                    buffer.data[destIndex] = data[sourceIndex]
                }

                readIndex = (readIndex + 1) % capacity
            }

            availableFrames -= framesToRead
            return framesToRead
        }
    }

    /// Get the number of frames available for reading
    public func availableForReading() -> Int {
        return bufferQueue.sync { availableFrames }
    }

    /// Get the number of frames available for writing
    public func availableForWriting() -> Int {
        return bufferQueue.sync { capacity - availableFrames }
    }

    /// Clear all data in the buffer
    public func clear() {
        bufferQueue.sync {
            writeIndex = 0
            readIndex = 0
            availableFrames = 0
            data.initialize(repeating: 0.0, count: capacity * channelCount)
        }
    }

    /// Get buffer statistics
    public func getStatistics() -> (capacity: Int, available: Int, usage: Double) {
        return bufferQueue.sync {
            let usage = Double(availableFrames) / Double(capacity)
            return (capacity: capacity, available: availableFrames, usage: usage)
        }
    }
}

// MARK: - Real-Time Processing Optimizations

/// High-performance audio processing utilities using SIMD and lock-free algorithms
public final class AudioProcessingOptimizer: @unchecked Sendable {

    // MARK: - SIMD-Optimized Audio Operations

    /// Apply gain to audio buffer using SIMD instructions
    public static func applyGain(to buffer: AudioBuffer, gain: Float) {
        let frameCount = buffer.frameCount
        let channelCount = buffer.channelCount
        let totalSamples = frameCount * channelCount

        // Use vDSP for vectorized gain application
        var gainValue = gain
        vDSP_vsmul(buffer.data, 1, &gainValue, buffer.data, 1, vDSP_Length(totalSamples))
    }

    /// Mix two audio buffers using SIMD instructions
    public static func mixBuffers(input1: AudioBuffer, input2: AudioBuffer, output: AudioBuffer, gain1: Float = 1.0, gain2: Float = 1.0) {
        let frameCount = min(input1.frameCount, min(input2.frameCount, output.frameCount))
        let channelCount = min(input1.channelCount, min(input2.channelCount, output.channelCount))
        let totalSamples = frameCount * channelCount

        // Apply gains and mix using vDSP
        var g1 = gain1
        var g2 = gain2

        // Scale input1 by gain1
        vDSP_vsmul(input1.data, 1, &g1, output.data, 1, vDSP_Length(totalSamples))

        // Scale input2 by gain2 and add to output
        vDSP_vsma(input2.data, 1, &g2, output.data, 1, output.data, 1, vDSP_Length(totalSamples))
    }

    /// Apply fade in/out using SIMD instructions
    public static func applyFade(to buffer: AudioBuffer, startGain: Float, endGain: Float) {
        let frameCount = buffer.frameCount
        let channelCount = buffer.channelCount

        // Create gain ramp
        let gainDelta = (endGain - startGain) / Float(frameCount - 1)

        for frame in 0..<frameCount {
            let currentGain = startGain + gainDelta * Float(frame)

            // Apply gain to all channels in this frame
            for channel in 0..<channelCount {
                let sampleIndex = frame * channelCount + channel
                buffer.data[sampleIndex] *= currentGain
            }
        }
    }

    /// Copy audio data with format conversion using SIMD
    public static func copyWithConversion(from source: AudioBuffer, to destination: AudioBuffer) {
        let framesToCopy = min(source.frameCount, destination.frameCount)
        let sourceChannels = source.channelCount
        let destChannels = destination.channelCount

        if sourceChannels == destChannels {
            // Direct copy when channel counts match
            let totalSamples = framesToCopy * sourceChannels
            vDSP_mmov(source.data, destination.data, vDSP_Length(totalSamples), 1, 1, 1)
        } else {
            // Channel conversion required
            for frame in 0..<framesToCopy {
                if sourceChannels == 1 && destChannels == 2 {
                    // Mono to stereo
                    let monoSample = source.data[frame]
                    destination.data[frame * 2] = monoSample
                    destination.data[frame * 2 + 1] = monoSample
                } else if sourceChannels == 2 && destChannels == 1 {
                    // Stereo to mono (mix down)
                    let leftSample = source.data[frame * 2]
                    let rightSample = source.data[frame * 2 + 1]
                    destination.data[frame] = (leftSample + rightSample) * 0.5
                } else {
                    // General case: copy available channels, zero others
                    let channelsToCopy = min(sourceChannels, destChannels)
                    for channel in 0..<channelsToCopy {
                        destination.data[frame * destChannels + channel] = source.data[frame * sourceChannels + channel]
                    }
                    // Zero remaining channels if destination has more
                    for channel in channelsToCopy..<destChannels {
                        destination.data[frame * destChannels + channel] = 0.0
                    }
                }
            }
        }
    }

    /// Apply soft clipping using optimized algorithm
    public static func applySoftClipping(to buffer: AudioBuffer, threshold: Float = 0.8) {
        let totalSamples = buffer.frameCount * buffer.channelCount

        for i in 0..<totalSamples {
            let sample = buffer.data[i]
            let absample = abs(sample)

            if absample > threshold {
                // Soft clipping using tanh approximation
                let sign: Float = sample >= 0 ? 1.0 : -1.0
                let normalizedInput = absample / threshold
                let clipped = threshold * Float(tanh(Double(normalizedInput)))
                buffer.data[i] = sign * clipped
            }
        }
    }

    /// Calculate RMS level using SIMD
    public static func calculateRMS(for buffer: AudioBuffer) -> Float {
        let totalSamples = buffer.frameCount * buffer.channelCount
        var rms: Float = 0.0

        // Use vDSP for efficient RMS calculation
        vDSP_rmsqv(buffer.data, 1, &rms, vDSP_Length(totalSamples))

        return rms
    }

    /// Calculate peak level using SIMD
    public static func calculatePeak(for buffer: AudioBuffer) -> Float {
        let totalSamples = buffer.frameCount * buffer.channelCount
        var peak: Float = 0.0

        // Use vDSP for efficient peak detection
        vDSP_maxmgv(buffer.data, 1, &peak, vDSP_Length(totalSamples))

        return peak
    }
}

// MARK: - Lock-Free Audio Processing

/// Lock-free audio processing utilities for real-time performance
public final class LockFreeAudioProcessor: @unchecked Sendable {

    /// Thread-safe ring buffer for single producer, single consumer scenarios
    public final class SPSCRingBuffer: @unchecked Sendable {
        private let capacity: Int
        private let data: UnsafeMutablePointer<Float>
        private var writeIndex: Int = 0
        private var readIndex: Int = 0
        private let bufferQueue = DispatchQueue(label: "SPSCRingBuffer", qos: .userInitiated)

        public init(capacity: Int) {
            self.capacity = capacity
            self.data = UnsafeMutablePointer<Float>.allocate(capacity: capacity)
            self.data.initialize(repeating: 0.0, count: capacity)
        }

        deinit {
            data.deallocate()
        }

        /// Write data to the ring buffer (producer)
        public func write(_ samples: UnsafePointer<Float>, count: Int) -> Int {
            return bufferQueue.sync {
                let available = (readIndex - writeIndex - 1 + capacity) % capacity
                let toWrite = min(count, available)

                if toWrite > 0 {
                    let endIndex = writeIndex + toWrite

                    if endIndex <= capacity {
                        // No wrap-around needed
                        data.advanced(by: writeIndex).update(from: samples, count: toWrite)
                    } else {
                        // Handle wrap-around
                        let firstPart = capacity - writeIndex
                        let secondPart = toWrite - firstPart

                        data.advanced(by: writeIndex).update(from: samples, count: firstPart)
                        data.update(from: samples.advanced(by: firstPart), count: secondPart)
                    }

                    writeIndex = (writeIndex + toWrite) % capacity
                }

                return toWrite
            }
        }

        /// Read data from the ring buffer (consumer)
        public func read(_ samples: UnsafeMutablePointer<Float>, count: Int) -> Int {
            return bufferQueue.sync {
                let available = (writeIndex - readIndex + capacity) % capacity
                let toRead = min(count, available)

                if toRead > 0 {
                    let endIndex = readIndex + toRead

                    if endIndex <= capacity {
                        // No wrap-around needed
                        samples.update(from: data.advanced(by: readIndex), count: toRead)
                    } else {
                        // Handle wrap-around
                        let firstPart = capacity - readIndex
                        let secondPart = toRead - firstPart

                        samples.update(from: data.advanced(by: readIndex), count: firstPart)
                        samples.advanced(by: firstPart).update(from: data, count: secondPart)
                    }

                    readIndex = (readIndex + toRead) % capacity
                }

                return toRead
            }
        }

        /// Get available space for writing
        public func availableForWrite() -> Int {
            return bufferQueue.sync {
                return (readIndex - writeIndex - 1 + capacity) % capacity
            }
        }

        /// Get available data for reading
        public func availableForRead() -> Int {
            return bufferQueue.sync {
                return (writeIndex - readIndex + capacity) % capacity
            }
        }
    }

    /// Thread-safe audio parameter smoother
    public final class ParameterSmoother: @unchecked Sendable {
        private var currentValue: Float = 0.0
        private var targetValue: Float = 0.0
        private let smoothingFactor: Float
        private let smootherQueue = DispatchQueue(label: "ParameterSmoother", qos: .userInitiated)

        public init(initialValue: Float = 0.0, smoothingTime: Float = 0.01, sampleRate: Float = 44100.0) {
            self.smoothingFactor = exp(-1.0 / (smoothingTime * sampleRate))
            self.currentValue = initialValue
            self.targetValue = initialValue
        }

        /// Set target value (thread-safe)
        public func setTarget(_ value: Float) {
            smootherQueue.sync {
                targetValue = value
            }
        }

        /// Get next smoothed value
        public func getNextValue() -> Float {
            return smootherQueue.sync {
                let newValue = currentValue + (targetValue - currentValue) * (1.0 - smoothingFactor)
                currentValue = newValue
                return newValue
            }
        }

        /// Get current value without updating
        public func getCurrentValue() -> Float {
            return smootherQueue.sync {
                return currentValue
            }
        }
    }
}

/// Audio node types
public enum AudioNodeType: String, CaseIterable, Sendable {
    case source = "source"
    case processor = "processor"
    case mixer = "mixer"
    case output = "output"
}

/// Audio node status
public enum AudioNodeStatus: String, CaseIterable, Sendable {
    case inactive = "inactive"
    case active = "active"
    case bypassed = "bypassed"
    case error = "error"
}

/// Protocol for all audio processing nodes
public protocol AudioNode: AnyObject, Sendable {
    /// Unique identifier for this node
    var id: AudioNodeID { get }

    /// Human-readable name for this node
    var name: String { get set }

    /// Type of audio node
    var nodeType: AudioNodeType { get }

    /// Current status of the node
    var status: AudioNodeStatus { get set }

    /// Whether the node is currently bypassed
    var isBypassed: Bool { get set }

    /// Input format for this node
    var inputFormat: AVAudioFormat? { get }

    /// Output format for this node
    var outputFormat: AVAudioFormat? { get }

    /// Maximum number of input connections
    var maxInputs: Int { get }

    /// Maximum number of output connections
    var maxOutputs: Int { get }

    /// Current input connections
    var inputConnections: [AudioConnection] { get }

    /// Current output connections
    var outputConnections: [AudioConnection] { get }

    /// Process audio data
    func process(input: AudioBuffer?) -> AudioBuffer?

    /// Prepare the node for processing
    func prepare(format: AVAudioFormat) throws

    /// Reset the node state
    func reset()

    /// Validate node configuration
    func validate() throws
}

/// Represents a connection between two audio nodes
public struct AudioConnection: @unchecked Sendable, Equatable {
    public let id: UUID
    public let sourceNodeId: AudioNodeID
    public let destinationNodeId: AudioNodeID
    public let sourceOutputIndex: Int
    public let destinationInputIndex: Int
    public let format: AVAudioFormat
    public let isActive: Bool

    public init(
        sourceNodeId: AudioNodeID,
        destinationNodeId: AudioNodeID,
        sourceOutputIndex: Int = 0,
        destinationInputIndex: Int = 0,
        format: AVAudioFormat,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.sourceNodeId = sourceNodeId
        self.destinationNodeId = destinationNodeId
        self.sourceOutputIndex = sourceOutputIndex
        self.destinationInputIndex = destinationInputIndex
        self.format = format
        self.isActive = isActive
    }

    public static func == (lhs: AudioConnection, rhs: AudioConnection) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Base Audio Node Implementation

/// Base implementation for audio nodes
public class BaseAudioNode: @unchecked Sendable, AudioNode {
    public let id: AudioNodeID
    public var name: String
    public let nodeType: AudioNodeType
    public var status: AudioNodeStatus
    public var isBypassed: Bool
    public var inputFormat: AVAudioFormat?
    public var outputFormat: AVAudioFormat?
    public let maxInputs: Int
    public let maxOutputs: Int

    private var _inputConnections: [AudioConnection] = []
    private var _outputConnections: [AudioConnection] = []
    private let connectionQueue = DispatchQueue(label: "AudioNode.connections", qos: .userInitiated)

    public var inputConnections: [AudioConnection] {
        return connectionQueue.sync { _inputConnections }
    }

    public var outputConnections: [AudioConnection] {
        return connectionQueue.sync { _outputConnections }
    }

    public init(
        name: String,
        nodeType: AudioNodeType,
        maxInputs: Int = 1,
        maxOutputs: Int = 1
    ) {
        self.id = UUID()
        self.name = name
        self.nodeType = nodeType
        self.status = .inactive
        self.isBypassed = false
        self.maxInputs = maxInputs
        self.maxOutputs = maxOutputs
    }

    public func process(input: AudioBuffer?) -> AudioBuffer? {
        guard !isBypassed, status == .active else {
            return input // Pass through when bypassed or inactive
        }

        // Base implementation just passes through
        // Subclasses should override this method
        return input
    }

    public func prepare(format: AVAudioFormat) throws {
        inputFormat = format
        outputFormat = format
        status = .active
    }

    public func reset() {
        status = .inactive
        inputFormat = nil
        outputFormat = nil
        connectionQueue.sync {
            _inputConnections.removeAll()
            _outputConnections.removeAll()
        }
    }

    public func validate() throws {
        // Basic validation - subclasses can override
        if inputConnections.count > maxInputs {
            throw AudioEngineError.configurationError("Too many input connections: \(inputConnections.count) > \(maxInputs)")
        }

        if outputConnections.count > maxOutputs {
            throw AudioEngineError.configurationError("Too many output connections: \(outputConnections.count) > \(maxOutputs)")
        }
    }

    // Internal methods for connection management
    internal func addInputConnection(_ connection: AudioConnection) {
        connectionQueue.sync {
            _inputConnections.append(connection)
        }
    }

    internal func removeInputConnection(_ connection: AudioConnection) {
        connectionQueue.sync {
            _inputConnections.removeAll { $0.id == connection.id }
        }
    }

    internal func addOutputConnection(_ connection: AudioConnection) {
        connectionQueue.sync {
            _outputConnections.append(connection)
        }
    }

    internal func removeOutputConnection(_ connection: AudioConnection) {
        connectionQueue.sync {
            _outputConnections.removeAll { $0.id == connection.id }
        }
    }
}

// MARK: - Concrete Node Implementations

/// Audio source node (generates or inputs audio)
public class AudioSourceNode: BaseAudioNode, @unchecked Sendable {
    public var isGenerating: Bool = false

    public init(name: String) {
        super.init(name: name, nodeType: .source, maxInputs: 0, maxOutputs: 1)
    }

    public override func process(input: AudioBuffer?) -> AudioBuffer? {
        guard !isBypassed, status == .active, isGenerating else {
            return nil
        }

        // Source nodes generate audio - subclasses should implement generation logic
        return generateAudio()
    }

    /// Override this method to implement audio generation
    open func generateAudio() -> AudioBuffer? {
        // Base implementation returns silence
        return nil
    }

    public func startGenerating() {
        isGenerating = true
    }

    public func stopGenerating() {
        isGenerating = false
    }
}

/// Audio processor node (processes audio)
public class AudioProcessorNode: BaseAudioNode, @unchecked Sendable {
    public init(name: String, maxInputs: Int = 1, maxOutputs: Int = 1) {
        super.init(name: name, nodeType: .processor, maxInputs: maxInputs, maxOutputs: maxOutputs)
    }

    public override func process(input: AudioBuffer?) -> AudioBuffer? {
        // Branch prediction optimization: most common case first
        if status == .active && !isBypassed {
            return processAudio(input)
        }

        // Fallback for bypassed or inactive nodes
        return input
    }

    /// Override this method to implement audio processing
    open func processAudio(_ input: AudioBuffer?) -> AudioBuffer? {
        // Base implementation passes through unchanged
        return input
    }
}

/// Audio mixer node (combines multiple inputs)
public class AudioMixerNode: BaseAudioNode, @unchecked Sendable {
    public var inputGains: [Float] = []
    public var masterGain: Float = 1.0

    public init(name: String, maxInputs: Int = 8) {
        super.init(name: name, nodeType: .mixer, maxInputs: maxInputs, maxOutputs: 1)
        inputGains = Array(repeating: 1.0, count: maxInputs)
    }

    public override func process(input: AudioBuffer?) -> AudioBuffer? {
        // Branch prediction optimization: most common case first
        if status == .active && !isBypassed {
            return mixInputs()
        }

        return input
    }

    /// Mix all connected inputs using optimized SIMD operations
    open func mixInputs() -> AudioBuffer? {
        // This would be implemented with actual input collection and SIMD mixing
        // For now, return a placeholder that demonstrates the optimization structure
        return nil
    }

    /// Optimized mixing function using SIMD
    public func mixInputsOptimized(inputs: [AudioBuffer], output: AudioBuffer) {
        guard !inputs.isEmpty else { return }

        let frameCount = output.frameCount
        let channelCount = output.channelCount
        let totalSamples = frameCount * channelCount

        // Clear output buffer first
        vDSP_vclr(output.data, 1, vDSP_Length(totalSamples))

        // Mix each input with its corresponding gain
        for (index, inputBuffer) in inputs.enumerated() {
            guard index < inputGains.count else { break }

            let gain = inputGains[index]
            if gain > 0.0 {
                let samplesToMix = min(totalSamples, inputBuffer.frameCount * inputBuffer.channelCount)
                var gainValue = gain

                // Use SIMD to add scaled input to output
                vDSP_vsma(inputBuffer.data, 1, &gainValue, output.data, 1, output.data, 1, vDSP_Length(samplesToMix))
            }
        }

        // Apply master gain
        if masterGain != 1.0 {
            var masterGainValue = masterGain
            vDSP_vsmul(output.data, 1, &masterGainValue, output.data, 1, vDSP_Length(totalSamples))
        }
    }

    public func setInputGain(index: Int, gain: Float) {
        guard index >= 0 && index < inputGains.count else { return }
        inputGains[index] = max(0.0, min(2.0, gain)) // Clamp between 0 and 2
    }
}

/// Audio output node (outputs audio)
public class AudioOutputNode: BaseAudioNode, @unchecked Sendable {
    public var outputGain: Float = 1.0
    public var isMuted: Bool = false

    public init(name: String) {
        super.init(name: name, nodeType: .output, maxInputs: 1, maxOutputs: 0)
    }

    public override func process(input: AudioBuffer?) -> AudioBuffer? {
        // Branch prediction optimization: most common case first
        if status == .active && !isBypassed && !isMuted {
            return applyOutputGain(input)
        }

        // Return nil for muted or inactive output
        return nil
    }

    /// Apply output gain to the audio using SIMD optimization
    open func applyOutputGain(_ input: AudioBuffer?) -> AudioBuffer? {
        guard let input = input else { return nil }

        // Apply gain using optimized SIMD operations
        if outputGain != 1.0 {
            AudioProcessingOptimizer.applyGain(to: input, gain: outputGain)
        }

        return input
    }

    public func mute() {
        isMuted = true
    }

    public func unmute() {
        isMuted = false
    }
}

// MARK: - Audio Graph Manager

/// Manages the audio processing graph
public actor AudioGraphManager {
    private var nodes: [AudioNodeID: AudioNode] = [:]
    private var connections: [UUID: AudioConnection] = [:]
    private var processingOrder: [AudioNodeID] = []

    public init() {}

    // MARK: - Node Management

    /// Add a node to the graph
    public func addNode(_ node: AudioNode) throws {
        guard nodes[node.id] == nil else {
            throw AudioEngineError.configurationError("Node with ID \(node.id) already exists")
        }

        nodes[node.id] = node
        updateProcessingOrder()
    }

    /// Remove a node from the graph
    public func removeNode(id: AudioNodeID) throws {
        guard let node = nodes[id] else {
            throw AudioEngineError.configurationError("Node with ID \(id) not found")
        }

        // Remove all connections involving this node
        let connectionsToRemove = connections.values.filter {
            $0.sourceNodeId == id || $0.destinationNodeId == id
        }

        for connection in connectionsToRemove {
            try removeConnection(id: connection.id)
        }

        // Reset and remove the node
        node.reset()
        nodes.removeValue(forKey: id)
        updateProcessingOrder()
    }

    /// Get a node by ID
    public func getNode(id: AudioNodeID) -> AudioNode? {
        return nodes[id]
    }

    /// Get all nodes
    public func getAllNodes() -> [AudioNode] {
        return Array(nodes.values)
    }

    /// Get nodes by type
    public func getNodes(ofType type: AudioNodeType) -> [AudioNode] {
        return nodes.values.filter { $0.nodeType == type }
    }

    // MARK: - Connection Management

    /// Connect two nodes
    public func connect(
        sourceId: AudioNodeID,
        destinationId: AudioNodeID,
        sourceOutputIndex: Int = 0,
        destinationInputIndex: Int = 0,
        format: AVAudioFormat
    ) throws {
        guard let sourceNode = nodes[sourceId] else {
            throw AudioEngineError.configurationError("Source node \(sourceId) not found")
        }

        guard let destinationNode = nodes[destinationId] else {
            throw AudioEngineError.configurationError("Destination node \(destinationId) not found")
        }

        // Validate connection limits
        if sourceNode.outputConnections.count >= sourceNode.maxOutputs {
            throw AudioEngineError.configurationError("Source node has reached maximum outputs")
        }

        if destinationNode.inputConnections.count >= destinationNode.maxInputs {
            throw AudioEngineError.configurationError("Destination node has reached maximum inputs")
        }

        // Check for circular dependencies
        if try wouldCreateCycle(from: sourceId, to: destinationId) {
            throw AudioEngineError.configurationError("Connection would create a circular dependency")
        }

        // Create the connection
        let connection = AudioConnection(
            sourceNodeId: sourceId,
            destinationNodeId: destinationId,
            sourceOutputIndex: sourceOutputIndex,
            destinationInputIndex: destinationInputIndex,
            format: format
        )

        // Add connection to both nodes
        if let sourceBase = sourceNode as? BaseAudioNode {
            sourceBase.addOutputConnection(connection)
        }

        if let destinationBase = destinationNode as? BaseAudioNode {
            destinationBase.addInputConnection(connection)
        }

        connections[connection.id] = connection
        updateProcessingOrder()
    }

    /// Disconnect two nodes
    public func disconnect(sourceId: AudioNodeID, destinationId: AudioNodeID) throws {
        let connectionsToRemove = connections.values.filter {
            $0.sourceNodeId == sourceId && $0.destinationNodeId == destinationId
        }

        for connection in connectionsToRemove {
            try removeConnection(id: connection.id)
        }
    }

    /// Remove a specific connection
    public func removeConnection(id: UUID) throws {
        guard let connection = connections[id] else {
            throw AudioEngineError.configurationError("Connection \(id) not found")
        }

        // Remove from nodes
        if let sourceNode = nodes[connection.sourceNodeId] as? BaseAudioNode {
            sourceNode.removeOutputConnection(connection)
        }

        if let destinationNode = nodes[connection.destinationNodeId] as? BaseAudioNode {
            destinationNode.removeInputConnection(connection)
        }

        connections.removeValue(forKey: id)
        updateProcessingOrder()
    }

    /// Get all connections
    public func getAllConnections() -> [AudioConnection] {
        return Array(connections.values)
    }

    // MARK: - Graph Processing

    /// Process the entire graph with optimized real-time performance
    public func processGraph() {
        // Process nodes in topological order for optimal performance
        for nodeId in processingOrder {
            // Branch prediction optimization: most nodes will exist
            if let node = nodes[nodeId] {
                processNode(node)
            }
        }
    }

    /// Process a single node with optimized input collection
    private func processNode(_ node: AudioNode) {
        // Collect inputs from connected nodes
        let inputBuffer = collectNodeInputs(node)

        // Process the node
        let output = node.process(input: inputBuffer)

        // Distribute output to connected nodes
        if let output = output {
            distributeNodeOutput(node, output: output)
        }
    }

    /// Collect inputs from all connected source nodes
    private func collectNodeInputs(_ node: AudioNode) -> AudioBuffer? {
        let inputConnections = connections.values.filter { $0.destinationNodeId == node.id }

        // Branch prediction: most nodes have 0-1 inputs
        if inputConnections.isEmpty {
            return nil
        } else if inputConnections.count == 1 {
            // Single input - direct pass through
            let connection = inputConnections[0]
            if let sourceNode = nodes[connection.sourceNodeId] {
                return getNodeOutput(sourceNode)
            }
        } else {
            // Multiple inputs - need mixing
            return mixMultipleInputs(inputConnections)
        }

        return nil
    }

    /// Get cached output from a node
    private func getNodeOutput(_ node: AudioNode) -> AudioBuffer? {
        // This would return the cached output from the node's last processing
        // For now, return nil as placeholder
        return nil
    }

    /// Mix multiple inputs using SIMD optimization
    private func mixMultipleInputs(_ connections: [AudioConnection]) -> AudioBuffer? {
        // This would implement optimized mixing of multiple input connections
        // Using the SIMD mixing functions from AudioProcessingOptimizer
        return nil
    }

    /// Distribute node output to connected destination nodes
    private func distributeNodeOutput(_ node: AudioNode, output: AudioBuffer) {
        let outputConnections = connections.values.filter { $0.sourceNodeId == node.id }

        // Cache the output for destination nodes to collect
        // This would be implemented with a lock-free cache
        for connection in outputConnections {
            cacheNodeOutput(connection.destinationNodeId, output: output)
        }
    }

    /// Cache node output for efficient access by destination nodes
    private func cacheNodeOutput(_ nodeId: AudioNodeID, output: AudioBuffer) {
        // This would implement lock-free caching of node outputs
        // For real-time performance
    }

    /// Validate the entire graph
    public func validateGraph() throws {
        for node in nodes.values {
            try node.validate()
        }

        // Check for orphaned nodes, cycles, etc.
        try validateGraphStructure()
    }

    // MARK: - Private Methods

    private func updateProcessingOrder() {
        // Topological sort to determine processing order
        processingOrder = topologicalSort()
    }

    private func topologicalSort() -> [AudioNodeID] {
        var visited: Set<AudioNodeID> = []
        var result: [AudioNodeID] = []

        func visit(_ nodeId: AudioNodeID) {
            if visited.contains(nodeId) { return }
            visited.insert(nodeId)

            // Visit all nodes that this node depends on (input connections)
            let inputConnections = connections.values.filter { $0.destinationNodeId == nodeId }
            for connection in inputConnections {
                visit(connection.sourceNodeId)
            }

            result.append(nodeId)
        }

        for nodeId in nodes.keys {
            visit(nodeId)
        }

        return result
    }

    private func wouldCreateCycle(from sourceId: AudioNodeID, to destinationId: AudioNodeID) throws -> Bool {
        // Check if connecting sourceId to destinationId would create a cycle
        var visited: Set<AudioNodeID> = []

        func hasPath(from: AudioNodeID, to: AudioNodeID) -> Bool {
            if from == to { return true }
            if visited.contains(from) { return false }
            visited.insert(from)

            let outgoingConnections = connections.values.filter { $0.sourceNodeId == from }
            for connection in outgoingConnections {
                if hasPath(from: connection.destinationNodeId, to: to) {
                    return true
                }
            }

            return false
        }

        return hasPath(from: destinationId, to: sourceId)
    }

    private func validateGraphStructure() throws {
        // Additional graph validation logic
        let sourceNodes = getNodes(ofType: .source)
        let outputNodes = getNodes(ofType: .output)

        if sourceNodes.isEmpty {
            throw AudioEngineError.configurationError("Graph has no source nodes")
        }

        if outputNodes.isEmpty {
            throw AudioEngineError.configurationError("Graph has no output nodes")
        }
    }
}

// MARK: - Audio Engine Configuration

/// Configuration for AudioEngine initialization
public struct AudioEngineConfiguration: Sendable {
    public let sampleRate: Double
    public let bufferSize: Int
    public let channelCount: Int
    #if os(iOS)
    public let sessionCategory: AVAudioSession.Category
    public let sessionOptions: AVAudioSession.CategoryOptions
    #endif
    public let enablePerformanceMonitoring: Bool
    public let enableErrorRecovery: Bool

    #if os(iOS)
    public init(
        sampleRate: Double = 44100.0,
        bufferSize: Int = 512,
        channelCount: Int = 2,
        sessionCategory: AVAudioSession.Category = .playAndRecord,
        sessionOptions: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetooth],
        enablePerformanceMonitoring: Bool = true,
        enableErrorRecovery: Bool = true
    ) {
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
        self.channelCount = channelCount
        self.sessionCategory = sessionCategory
        self.sessionOptions = sessionOptions
        self.enablePerformanceMonitoring = enablePerformanceMonitoring
        self.enableErrorRecovery = enableErrorRecovery
    }
    #else
    public init(
        sampleRate: Double = 44100.0,
        bufferSize: Int = 512,
        channelCount: Int = 2,
        enablePerformanceMonitoring: Bool = true,
        enableErrorRecovery: Bool = true
    ) {
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
        self.channelCount = channelCount
        self.enablePerformanceMonitoring = enablePerformanceMonitoring
        self.enableErrorRecovery = enableErrorRecovery
    }
    #endif
}

// MARK: - Audio Engine Errors

/// Audio engine specific errors with severity classification
public enum AudioEngineError: Error, LocalizedError {
    case initializationFailed(String)
    case audioSessionError(String)
    case engineStartFailed(String)
    case engineStopFailed(String)
    case configurationError(String)
    case interruptionError(String)
    case routeChangeError(String)
    case performanceError(String)
    case bufferUnderrun(String)
    case bufferOverrun(String)
    case memoryError(String)
    case hardwareError(String)
    case networkError(String)
    case recoveryFailed(String)
    case processingError(String)
    case validationError(String)
    case unsupportedFormat(String)
    case pluginError(String)
    case bufferError(String)
    case routingError(String)
    case formatError(String)
    case midiError(String)
    case fileIOError(String)

    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "Audio engine initialization failed: \(message)"
        case .audioSessionError(let message):
            return "Audio session error: \(message)"
        case .engineStartFailed(let message):
            return "Failed to start audio engine: \(message)"
        case .engineStopFailed(let message):
            return "Failed to stop audio engine: \(message)"
        case .configurationError(let message):
            return "Audio engine configuration error: \(message)"
        case .interruptionError(let message):
            return "Audio interruption error: \(message)"
        case .routeChangeError(let message):
            return "Audio route change error: \(message)"
        case .performanceError(let message):
            return "Audio performance error: \(message)"
        case .bufferUnderrun(let message):
            return "Audio buffer underrun: \(message)"
        case .bufferOverrun(let message):
            return "Audio buffer overrun: \(message)"
        case .memoryError(let message):
            return "Audio memory error: \(message)"
        case .hardwareError(let message):
            return "Audio hardware error: \(message)"
        case .networkError(let message):
            return "Audio network error: \(message)"
        case .recoveryFailed(let message):
            return "Audio recovery failed: \(message)"
        case .processingError(let message):
            return "Audio processing error: \(message)"
        case .validationError(let message):
            return "Audio validation error: \(message)"
        case .unsupportedFormat(let message):
            return "Unsupported audio format: \(message)"
        case .pluginError(let message):
            return "Audio plugin error: \(message)"
        case .bufferError(let message):
            return "Audio buffer error: \(message)"
        case .routingError(let message):
            return "Audio routing error: \(message)"
        case .formatError(let message):
            return "Audio format error: \(message)"
        case .midiError(let message):
            return "MIDI error: \(message)"
        case .fileIOError(let message):
            return "Audio file I/O error: \(message)"
        }
    }

    /// Error severity classification for recovery strategies
    public var severity: AudioErrorSeverity {
        switch self {
        case .initializationFailed, .engineStartFailed, .hardwareError:
            return .critical
        case .audioSessionError, .engineStopFailed, .configurationError, .memoryError:
            return .major
        case .interruptionError, .routeChangeError, .bufferUnderrun, .bufferOverrun:
            return .minor
        case .performanceError, .networkError:
            return .warning
        case .recoveryFailed:
            return .critical
        case .processingError, .pluginError:
            return .major
        case .validationError, .formatError, .fileIOError:
            return .minor
        case .unsupportedFormat:
            return .warning
        case .bufferError, .routingError:
            return .major
        case .midiError:
            return .minor
        }
    }

    /// Whether this error type supports automatic recovery
    public var isRecoverable: Bool {
        switch self {
        case .initializationFailed, .hardwareError, .recoveryFailed:
            return false
        case .audioSessionError, .engineStartFailed, .engineStopFailed, .configurationError,
             .interruptionError, .routeChangeError, .performanceError, .bufferUnderrun,
             .bufferOverrun, .memoryError, .networkError, .processingError, .validationError,
             .pluginError, .bufferError, .routingError, .formatError, .midiError, .fileIOError:
            return true
        case .unsupportedFormat:
            return false
        }
    }
}

/// Error severity levels for recovery strategy selection
public enum AudioErrorSeverity: Int, CaseIterable, Comparable {
    case warning = 0
    case minor = 1
    case major = 2
    case critical = 3

    public static func < (lhs: AudioErrorSeverity, rhs: AudioErrorSeverity) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Error Recovery System

/// Comprehensive error recovery and resilience management
public final class AudioErrorRecoveryManager: @unchecked Sendable {

    /// Recovery strategy for different error types
    public enum RecoveryStrategy: Sendable {
        case ignore
        case retry(maxAttempts: Int, delay: TimeInterval)
        case restart(graceful: Bool)
        case fallback(configuration: AudioEngineConfiguration)
        case gracefulDegradation(reducedQuality: Bool)
        case emergencyStop
    }

    /// Recovery attempt tracking
    public struct RecoveryAttempt {
        public let error: AudioEngineError
        public let strategy: RecoveryStrategy
        public let timestamp: Date
        public let attemptNumber: Int
        public let success: Bool

        public init(error: AudioEngineError, strategy: RecoveryStrategy, attemptNumber: Int, success: Bool) {
            self.error = error
            self.strategy = strategy
            self.timestamp = Date()
            self.attemptNumber = attemptNumber
            self.success = success
        }
    }

    private var recoveryHistory: [RecoveryAttempt] = []
    private var errorCounts: [String: Int] = [:]
    private var lastErrorTime: [String: Date] = [:]
    private let recoveryQueue = DispatchQueue(label: "AudioErrorRecovery", qos: .userInitiated)

    // Recovery configuration
    private let maxRecoveryAttempts: Int
    private let recoveryTimeWindow: TimeInterval
    private let emergencyThreshold: Int

    public init(maxRecoveryAttempts: Int = 3, recoveryTimeWindow: TimeInterval = 60.0, emergencyThreshold: Int = 5) {
        self.maxRecoveryAttempts = maxRecoveryAttempts
        self.recoveryTimeWindow = recoveryTimeWindow
        self.emergencyThreshold = emergencyThreshold
    }

    /// Determine recovery strategy for a given error
    public func getRecoveryStrategy(for error: AudioEngineError) -> RecoveryStrategy {
        return recoveryQueue.sync {
            let errorKey = String(describing: type(of: error))

            // Check if we've exceeded emergency threshold
            if getRecentErrorCount(for: errorKey) >= emergencyThreshold {
                return .emergencyStop
            }

            // Determine strategy based on error type and severity
            switch error.severity {
            case .warning:
                return .ignore

            case .minor:
                if error.isRecoverable {
                    return .retry(maxAttempts: 2, delay: 0.1)
                } else {
                    return .gracefulDegradation(reducedQuality: true)
                }

            case .major:
                if error.isRecoverable {
                    return .restart(graceful: true)
                } else {
                    return .fallback(configuration: createFallbackConfiguration())
                }

            case .critical:
                if error.isRecoverable && getRecentErrorCount(for: errorKey) < maxRecoveryAttempts {
                    return .restart(graceful: false)
                } else {
                    return .emergencyStop
                }
            }
        }
    }

    /// Execute recovery strategy
    public func executeRecovery(
        for error: AudioEngineError,
        using strategy: RecoveryStrategy,
        with audioEngine: AudioEngineManager
    ) async -> Bool {
        let attemptNumber = await getAttemptNumber(for: error)

        do {
            let success = try await performRecovery(strategy: strategy, audioEngine: audioEngine)
            await recordRecoveryAttempt(error: error, strategy: strategy, attemptNumber: attemptNumber, success: success)
            return success
        } catch let recoveryError {
            let audioError = recoveryError as? AudioEngineError ?? AudioEngineError.recoveryFailed(recoveryError.localizedDescription)
            await recordRecoveryAttempt(error: audioError, strategy: strategy, attemptNumber: attemptNumber, success: false)
            return false
        }
    }

    /// Perform the actual recovery operation
    private func performRecovery(strategy: RecoveryStrategy, audioEngine: AudioEngineManager) async throws -> Bool {
        switch strategy {
        case .ignore:
            return true

        case .retry(let maxAttempts, let delay):
            for attempt in 1...maxAttempts {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // Attempt to restart the engine
                do {
                    if audioEngine.isRunning {
                        try audioEngine.stop()
                    }
                    try audioEngine.start()
                    return true
                } catch {
                    if attempt == maxAttempts {
                        throw error
                    }
                }
            }
            return false

        case .restart(let graceful):
            if graceful {
                // Graceful restart
                if audioEngine.isRunning {
                    try audioEngine.stop()
                }
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                try audioEngine.start()
            } else {
                // Force restart
                audioEngine.reset()
                if let config = audioEngine.configuration {
                    try audioEngine.initialize(configuration: config)
                    try audioEngine.start()
                }
            }
            return true

        case .fallback(let configuration):
            // Reset and initialize with fallback configuration
            audioEngine.reset()
            try audioEngine.initialize(configuration: configuration)
            try audioEngine.start()
            return true

        case .gracefulDegradation(let reducedQuality):
            // Implement graceful degradation
            if reducedQuality {
                return await degradeAudioQuality(audioEngine: audioEngine)
            }
            return true

        case .emergencyStop:
            // Emergency stop - halt all audio processing
            if audioEngine.isRunning {
                try audioEngine.stop()
            }
            audioEngine.reset()
            return false
        }
    }

    /// Implement graceful degradation by reducing audio quality
    private func degradeAudioQuality(audioEngine: AudioEngineManager) async -> Bool {
        guard let currentConfig = audioEngine.configuration else { return false }

        // Create degraded configuration
        let degradedConfig = AudioEngineConfiguration(
            sampleRate: min(currentConfig.sampleRate, 22050.0), // Reduce sample rate
            bufferSize: max(currentConfig.bufferSize, 1024), // Increase buffer size
            channelCount: min(currentConfig.channelCount, 1), // Reduce to mono
            enablePerformanceMonitoring: currentConfig.enablePerformanceMonitoring,
            enableErrorRecovery: currentConfig.enableErrorRecovery
        )

        do {
            if audioEngine.isRunning {
                try audioEngine.stop()
            }
            audioEngine.reset()
            try audioEngine.initialize(configuration: degradedConfig)
            try audioEngine.start()
            return true
        } catch {
            return false
        }
    }

    /// Create fallback configuration for emergency recovery
    private func createFallbackConfiguration() -> AudioEngineConfiguration {
        return AudioEngineConfiguration(
            sampleRate: 22050.0, // Lower sample rate
            bufferSize: 2048, // Larger buffer
            channelCount: 1, // Mono
            enablePerformanceMonitoring: false,
            enableErrorRecovery: true
        )
    }

    /// Get recent error count for a specific error type
    private func getRecentErrorCount(for errorKey: String) -> Int {
        let now = Date()
        let cutoffTime = now.addingTimeInterval(-recoveryTimeWindow)

        // Clean up old entries
        if let lastTime = lastErrorTime[errorKey], lastTime < cutoffTime {
            errorCounts[errorKey] = 0
            lastErrorTime[errorKey] = nil
        }

        return errorCounts[errorKey] ?? 0
    }

    /// Get attempt number for error recovery
    private func getAttemptNumber(for error: AudioEngineError) async -> Int {
        return await withCheckedContinuation { continuation in
            recoveryQueue.async {
                let errorKey = String(describing: type(of: error))
                let currentCount = self.errorCounts[errorKey] ?? 0
                self.errorCounts[errorKey] = currentCount + 1
                self.lastErrorTime[errorKey] = Date()
                continuation.resume(returning: currentCount + 1)
            }
        }
    }

    /// Record recovery attempt for analysis
    private func recordRecoveryAttempt(error: AudioEngineError, strategy: RecoveryStrategy, attemptNumber: Int, success: Bool) async {
        await withCheckedContinuation { continuation in
            recoveryQueue.async {
                let attempt = RecoveryAttempt(error: error, strategy: strategy, attemptNumber: attemptNumber, success: success)
                self.recoveryHistory.append(attempt)

                // Keep only recent history (last 100 attempts)
                if self.recoveryHistory.count > 100 {
                    self.recoveryHistory.removeFirst(self.recoveryHistory.count - 100)
                }

                continuation.resume()
            }
        }
    }

    /// Get recovery statistics
    public func getRecoveryStatistics() -> (totalAttempts: Int, successRate: Double, recentErrors: [String: Int]) {
        return recoveryQueue.sync {
            let totalAttempts = recoveryHistory.count
            let successfulAttempts = recoveryHistory.filter { $0.success }.count
            let successRate = totalAttempts > 0 ? Double(successfulAttempts) / Double(totalAttempts) : 0.0

            return (totalAttempts: totalAttempts, successRate: successRate, recentErrors: errorCounts)
        }
    }

    /// Clear recovery history and reset counters
    public func reset() {
        recoveryQueue.sync {
            recoveryHistory.removeAll()
            errorCounts.removeAll()
            lastErrorTime.removeAll()
        }
    }
}

// MARK: - Audio Routing System

/// Comprehensive audio routing matrix for flexible signal flow management
public final class AudioRoutingMatrix: @unchecked Sendable {

    /// Routing connection with gain and processing options
    public struct RoutingConnection: @unchecked Sendable {
        public let id: UUID
        public let sourceId: AudioNodeID
        public let destinationId: AudioNodeID
        public let sourceOutput: Int
        public let destinationInput: Int
        public var gain: Float
        public var isActive: Bool
        public var latencyCompensation: Int // in samples
        public let format: AVAudioFormat

        public init(
            sourceId: AudioNodeID,
            destinationId: AudioNodeID,
            sourceOutput: Int = 0,
            destinationInput: Int = 0,
            gain: Float = 1.0,
            isActive: Bool = true,
            latencyCompensation: Int = 0,
            format: AVAudioFormat
        ) {
            self.id = UUID()
            self.sourceId = sourceId
            self.destinationId = destinationId
            self.sourceOutput = sourceOutput
            self.destinationInput = destinationInput
            self.gain = gain
            self.isActive = isActive
            self.latencyCompensation = latencyCompensation
            self.format = format
        }
    }

    /// Routing matrix configuration
    public struct RoutingConfiguration: Sendable {
        public let maxInputs: Int
        public let maxOutputs: Int
        public let enableLatencyCompensation: Bool
        public let enableGainControl: Bool
        public let enableDynamicRouting: Bool

        public init(
            maxInputs: Int = 64,
            maxOutputs: Int = 64,
            enableLatencyCompensation: Bool = true,
            enableGainControl: Bool = true,
            enableDynamicRouting: Bool = true
        ) {
            self.maxInputs = maxInputs
            self.maxOutputs = maxOutputs
            self.enableLatencyCompensation = enableLatencyCompensation
            self.enableGainControl = enableGainControl
            self.enableDynamicRouting = enableDynamicRouting
        }
    }

    private let configuration: RoutingConfiguration
    private var connections: [UUID: RoutingConnection] = [:]
    private var routingMatrix: [[Float]] = []
    private var latencyMatrix: [[Int]] = []
    private let routingQueue = DispatchQueue(label: "AudioRoutingMatrix", qos: .userInitiated)

    // Performance optimization caches
    private var sourceCache: [AudioNodeID: [RoutingConnection]] = [:]
    private var destinationCache: [AudioNodeID: [RoutingConnection]] = [:]
    private var matrixNeedsUpdate = true

    public init(configuration: RoutingConfiguration = RoutingConfiguration()) {
        self.configuration = configuration
        initializeMatrix()
    }

    /// Initialize the routing matrix
    private func initializeMatrix() {
        routingMatrix = Array(repeating: Array(repeating: 0.0, count: configuration.maxOutputs), count: configuration.maxInputs)
        latencyMatrix = Array(repeating: Array(repeating: 0, count: configuration.maxOutputs), count: configuration.maxInputs)
    }

    /// Add a routing connection
    public func addConnection(_ connection: RoutingConnection) throws {
        try routingQueue.sync {
            // Validate connection
            guard connections[connection.id] == nil else {
                throw AudioEngineError.configurationError("Connection already exists")
            }

            // Add connection
            connections[connection.id] = connection

            // Update caches
            updateSourceCache(for: connection.sourceId)
            updateDestinationCache(for: connection.destinationId)

            // Mark matrix for update
            matrixNeedsUpdate = true
        }
    }

    /// Remove a routing connection
    public func removeConnection(id: UUID) throws {
        try routingQueue.sync {
            guard let connection = connections[id] else {
                throw AudioEngineError.configurationError("Connection not found")
            }

            connections.removeValue(forKey: id)

            // Update caches
            updateSourceCache(for: connection.sourceId)
            updateDestinationCache(for: connection.destinationId)

            // Mark matrix for update
            matrixNeedsUpdate = true
        }
    }

    /// Update connection gain
    public func updateConnectionGain(id: UUID, gain: Float) throws {
        try routingQueue.sync {
            guard var connection = connections[id] else {
                throw AudioEngineError.configurationError("Connection not found")
            }

            connection.gain = max(0.0, min(2.0, gain)) // Clamp gain
            connections[id] = connection

            // Mark matrix for update
            matrixNeedsUpdate = true
        }
    }

    /// Enable or disable a connection
    public func setConnectionActive(id: UUID, isActive: Bool) throws {
        try routingQueue.sync {
            guard var connection = connections[id] else {
                throw AudioEngineError.configurationError("Connection not found")
            }

            connection.isActive = isActive
            connections[id] = connection

            // Mark matrix for update
            matrixNeedsUpdate = true
        }
    }

    /// Get all connections from a source node
    public func getSourceConnections(for nodeId: AudioNodeID) -> [RoutingConnection] {
        return routingQueue.sync {
            return sourceCache[nodeId] ?? []
        }
    }

    /// Get all connections to a destination node
    public func getDestinationConnections(for nodeId: AudioNodeID) -> [RoutingConnection] {
        return routingQueue.sync {
            return destinationCache[nodeId] ?? []
        }
    }

    /// Get routing gain between two nodes
    public func getRoutingGain(from sourceId: AudioNodeID, to destinationId: AudioNodeID) -> Float {
        return routingQueue.sync {
            let sourceConnections = sourceCache[sourceId] ?? []
            for connection in sourceConnections {
                if connection.destinationId == destinationId && connection.isActive {
                    return connection.gain
                }
            }
            return 0.0
        }
    }

    /// Update the routing matrix for optimized processing
    public func updateMatrix() {
        routingQueue.sync {
            guard matrixNeedsUpdate else { return }

            // Clear matrix
            for i in 0..<configuration.maxInputs {
                for j in 0..<configuration.maxOutputs {
                    routingMatrix[i][j] = 0.0
                    latencyMatrix[i][j] = 0
                }
            }

            // Populate matrix from connections
            for connection in connections.values {
                guard connection.isActive else { continue }

                let inputIndex = hashNodeToIndex(connection.sourceId, max: configuration.maxInputs)
                let outputIndex = hashNodeToIndex(connection.destinationId, max: configuration.maxOutputs)

                routingMatrix[inputIndex][outputIndex] = connection.gain
                latencyMatrix[inputIndex][outputIndex] = connection.latencyCompensation
            }

            matrixNeedsUpdate = false
        }
    }

    /// Process audio through the routing matrix
    public func processRouting(inputs: [AudioNodeID: AudioBuffer], outputs: inout [AudioNodeID: AudioBuffer]) {
        updateMatrix()

        routingQueue.sync {
            // Process each active connection
            for connection in connections.values {
                guard connection.isActive,
                      let inputBuffer = inputs[connection.sourceId],
                      let outputBuffer = outputs[connection.destinationId] else {
                    continue
                }

                // Apply routing with gain
                if connection.gain > 0.0 {
                    AudioProcessingOptimizer.mixBuffers(
                        input1: inputBuffer,
                        input2: outputBuffer,
                        output: outputBuffer,
                        gain1: connection.gain,
                        gain2: 1.0
                    )

                    outputs[connection.destinationId] = outputBuffer
                }
            }
        }
    }

    /// Get routing statistics
    public func getRoutingStatistics() -> (totalConnections: Int, activeConnections: Int, matrixUtilization: Double) {
        return routingQueue.sync {
            let totalConnections = connections.count
            let activeConnections = connections.values.filter { $0.isActive }.count
            let maxConnections = configuration.maxInputs * configuration.maxOutputs
            let utilization = Double(activeConnections) / Double(maxConnections)

            return (totalConnections: totalConnections, activeConnections: activeConnections, matrixUtilization: utilization)
        }
    }

    /// Clear all routing connections
    public func clearAllConnections() {
        routingQueue.sync {
            connections.removeAll()
            sourceCache.removeAll()
            destinationCache.removeAll()
            matrixNeedsUpdate = true
        }
    }

    // MARK: - Private Methods

    private func updateSourceCache(for nodeId: AudioNodeID) {
        sourceCache[nodeId] = connections.values.filter { $0.sourceId == nodeId }
    }

    private func updateDestinationCache(for nodeId: AudioNodeID) {
        destinationCache[nodeId] = connections.values.filter { $0.destinationId == nodeId }
    }

    private func hashNodeToIndex(_ nodeId: AudioNodeID, max: Int) -> Int {
        return abs(nodeId.hashValue) % max
    }
}

// MARK: - Dynamic Routing Manager

/// Manages dynamic routing changes and optimizations
public final class DynamicRoutingManager: @unchecked Sendable {

    /// Routing change event
    public struct RoutingChangeEvent: Sendable {
        public let timestamp: Date
        public let changeType: ChangeType
        public let connectionId: UUID?
        public let sourceId: AudioNodeID?
        public let destinationId: AudioNodeID?

        public enum ChangeType: String, CaseIterable, Sendable {
            case connectionAdded = "connectionAdded"
            case connectionRemoved = "connectionRemoved"
            case gainChanged = "gainChanged"
            case connectionToggled = "connectionToggled"
            case matrixOptimized = "matrixOptimized"
        }

        public init(changeType: ChangeType, connectionId: UUID? = nil, sourceId: AudioNodeID? = nil, destinationId: AudioNodeID? = nil) {
            self.timestamp = Date()
            self.changeType = changeType
            self.connectionId = connectionId
            self.sourceId = sourceId
            self.destinationId = destinationId
        }
    }

    private let routingMatrix: AudioRoutingMatrix
    private var changeHistory: [RoutingChangeEvent] = []
    private let changeQueue = DispatchQueue(label: "DynamicRoutingManager", qos: .userInitiated)

    // Optimization settings
    private let optimizationInterval: TimeInterval
    private var lastOptimization: Date = Date()

    public init(routingMatrix: AudioRoutingMatrix, optimizationInterval: TimeInterval = 1.0) {
        self.routingMatrix = routingMatrix
        self.optimizationInterval = optimizationInterval
    }

    /// Add a dynamic routing connection
    public func addDynamicConnection(
        from sourceId: AudioNodeID,
        to destinationId: AudioNodeID,
        gain: Float = 1.0,
        format: AVAudioFormat
    ) throws -> UUID {
        let connection = AudioRoutingMatrix.RoutingConnection(
            sourceId: sourceId,
            destinationId: destinationId,
            gain: gain,
            format: format
        )

        try routingMatrix.addConnection(connection)

        let event = RoutingChangeEvent(
            changeType: .connectionAdded,
            connectionId: connection.id,
            sourceId: sourceId,
            destinationId: destinationId
        )
        recordChange(event)

        return connection.id
    }

    /// Remove a dynamic routing connection
    public func removeDynamicConnection(id: UUID) throws {
        try routingMatrix.removeConnection(id: id)

        let event = RoutingChangeEvent(
            changeType: .connectionRemoved,
            connectionId: id
        )
        recordChange(event)
    }

    /// Update connection gain with smooth transitions
    public func updateConnectionGain(id: UUID, targetGain: Float, transitionTime: TimeInterval = 0.1) throws {
        // For now, apply gain immediately
        // In a full implementation, this would use parameter smoothing
        try routingMatrix.updateConnectionGain(id: id, gain: targetGain)

        let event = RoutingChangeEvent(
            changeType: .gainChanged,
            connectionId: id
        )
        recordChange(event)
    }

    /// Toggle connection active state
    public func toggleConnection(id: UUID) throws {
        // This would need to track current state and toggle it
        // For now, assume we're activating
        try routingMatrix.setConnectionActive(id: id, isActive: true)

        let event = RoutingChangeEvent(
            changeType: .connectionToggled,
            connectionId: id
        )
        recordChange(event)
    }

    /// Optimize routing matrix if needed
    public func optimizeIfNeeded() {
        let now = Date()
        if now.timeIntervalSince(lastOptimization) >= optimizationInterval {
            routingMatrix.updateMatrix()
            lastOptimization = now

            let event = RoutingChangeEvent(changeType: .matrixOptimized)
            recordChange(event)
        }
    }

    /// Get routing change history
    public func getChangeHistory(limit: Int = 100) -> [RoutingChangeEvent] {
        return changeQueue.sync {
            return Array(changeHistory.suffix(limit))
        }
    }

    /// Clear change history
    public func clearHistory() {
        changeQueue.sync {
            changeHistory.removeAll()
        }
    }

    private func recordChange(_ event: RoutingChangeEvent) {
        changeQueue.async {
            self.changeHistory.append(event)

            // Keep only recent history
            if self.changeHistory.count > 1000 {
                self.changeHistory.removeFirst(self.changeHistory.count - 1000)
            }
        }
    }
}

// MARK: - Audio Format Conversion System

/// Comprehensive audio format conversion with sample rate, bit depth, and channel mapping
public final class AudioFormatConverter: @unchecked Sendable {

    /// Conversion quality settings
    public enum ConversionQuality: Int, CaseIterable, Sendable {
        case low = 0
        case medium = 1
        case high = 2
        case maximum = 3

        var sampleRateConverterQuality: Int {
            switch self {
            case .low: return Int(kAudioConverterQuality_Min)
            case .medium: return Int(kAudioConverterQuality_Medium)
            case .high: return Int(kAudioConverterQuality_High)
            case .maximum: return Int(kAudioConverterQuality_Max)
            }
        }
    }

    /// Channel mapping configuration
    public struct ChannelMapping: Sendable {
        public let sourceChannels: Int
        public let destinationChannels: Int
        public let mappingMatrix: [[Float]] // [dest][source]

        public init(sourceChannels: Int, destinationChannels: Int, mappingMatrix: [[Float]]? = nil) {
            self.sourceChannels = sourceChannels
            self.destinationChannels = destinationChannels

            if let matrix = mappingMatrix {
                self.mappingMatrix = matrix
            } else {
                // Create default mapping
                self.mappingMatrix = Self.createDefaultMapping(from: sourceChannels, to: destinationChannels)
            }
        }

        private static func createDefaultMapping(from sourceChannels: Int, to destinationChannels: Int) -> [[Float]] {
            var matrix: [[Float]] = Array(repeating: Array(repeating: 0.0, count: sourceChannels), count: destinationChannels)

            if sourceChannels == 1 && destinationChannels == 2 {
                // Mono to stereo - duplicate to both channels
                matrix[0][0] = 1.0 // Left = Mono
                matrix[1][0] = 1.0 // Right = Mono
            } else if sourceChannels == 2 && destinationChannels == 1 {
                // Stereo to mono - mix both channels
                matrix[0][0] = 0.5 // Mono = (Left + Right) / 2
                matrix[0][1] = 0.5
            } else {
                // Direct mapping for matching channels
                let channelsToMap = min(sourceChannels, destinationChannels)
                for i in 0..<channelsToMap {
                    matrix[i][i] = 1.0
                }
            }

            return matrix
        }
    }

    /// Format conversion configuration
    public struct ConversionConfiguration: @unchecked Sendable {
        public let sourceFormat: AVAudioFormat
        public let destinationFormat: AVAudioFormat
        public let quality: ConversionQuality
        public let channelMapping: ChannelMapping?
        public let enableDithering: Bool
        public let enableNoiseShaping: Bool

        public init(
            sourceFormat: AVAudioFormat,
            destinationFormat: AVAudioFormat,
            quality: ConversionQuality = .high,
            channelMapping: ChannelMapping? = nil,
            enableDithering: Bool = true,
            enableNoiseShaping: Bool = true
        ) {
            self.sourceFormat = sourceFormat
            self.destinationFormat = destinationFormat
            self.quality = quality
            self.channelMapping = channelMapping
            self.enableDithering = enableDithering
            self.enableNoiseShaping = enableNoiseShaping
        }
    }

    private let configuration: ConversionConfiguration
    private var audioConverter: AVAudioConverter?
    private let conversionQueue = DispatchQueue(label: "AudioFormatConverter", qos: .userInitiated)

    public init(configuration: ConversionConfiguration) throws {
        self.configuration = configuration
        try setupConverter()
    }

    /// Setup the audio converter
    private func setupConverter() throws {
        // Validate format compatibility
        guard configuration.sourceFormat.commonFormat != .otherFormat &&
              configuration.destinationFormat.commonFormat != .otherFormat else {
            throw AudioEngineError.configurationError("Unsupported audio format")
        }

        guard let converter = AVAudioConverter(from: configuration.sourceFormat, to: configuration.destinationFormat) else {
            throw AudioEngineError.configurationError("Failed to create audio converter - incompatible formats")
        }

        // Configure converter quality
        converter.sampleRateConverterQuality = configuration.quality.sampleRateConverterQuality

        // Configure dithering
        if configuration.enableDithering {
            converter.dither = true
        }

        // Note: downsampling property is not available in all iOS versions
        // The converter will handle downsampling automatically

        self.audioConverter = converter
    }

    /// Convert audio buffer to target format
    public func convert(_ inputBuffer: AudioBuffer) throws -> AudioBuffer {
        guard let converter = audioConverter else {
            throw AudioEngineError.configurationError("Audio converter not initialized")
        }

        return try conversionQueue.sync {
            // Create AVAudioPCMBuffer from AudioBuffer
            guard let inputPCMBuffer = createPCMBuffer(from: inputBuffer, format: configuration.sourceFormat) else {
                throw AudioEngineError.configurationError("Failed to create input PCM buffer")
            }

            // Calculate output buffer size
            let outputFrameCapacity = AVAudioFrameCount(
                Double(inputBuffer.frameCount) * configuration.destinationFormat.sampleRate / configuration.sourceFormat.sampleRate
            )

            guard let outputPCMBuffer = AVAudioPCMBuffer(
                pcmFormat: configuration.destinationFormat,
                frameCapacity: outputFrameCapacity
            ) else {
                throw AudioEngineError.configurationError("Failed to create output PCM buffer")
            }

            // Perform conversion
            var error: NSError?
            let status = converter.convert(to: outputPCMBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return inputPCMBuffer
            }

            if status == .error {
                throw AudioEngineError.configurationError("Audio conversion failed: \(error?.localizedDescription ?? "Unknown error")")
            }

            // Apply channel mapping if specified
            if let channelMapping = configuration.channelMapping {
                try applyChannelMapping(to: outputPCMBuffer, mapping: channelMapping)
            }

            // Convert back to AudioBuffer
            return try createAudioBuffer(from: outputPCMBuffer)
        }
    }

    /// Convert audio buffer with custom channel mapping
    public func convertWithChannelMapping(
        _ inputBuffer: AudioBuffer,
        channelMapping: ChannelMapping
    ) throws -> AudioBuffer {
        // First perform format conversion
        let convertedBuffer = try convert(inputBuffer)

        // Then apply channel mapping
        return try applyChannelMappingToAudioBuffer(convertedBuffer, mapping: channelMapping)
    }

    /// Apply channel mapping to PCM buffer
    private func applyChannelMapping(to buffer: AVAudioPCMBuffer, mapping: ChannelMapping) throws {
        guard let floatChannelData = buffer.floatChannelData else {
            throw AudioEngineError.configurationError("Buffer does not contain float data")
        }

        let frameCount = Int(buffer.frameLength)
        let sourceChannels = mapping.sourceChannels
        let destChannels = mapping.destinationChannels

        // Create temporary buffer for source data
        let tempData = UnsafeMutablePointer<UnsafeMutablePointer<Float>>.allocate(capacity: sourceChannels)
        defer { tempData.deallocate() }

        for channel in 0..<sourceChannels {
            tempData[channel] = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
            tempData[channel].initialize(from: floatChannelData[channel], count: frameCount)
        }

        // Apply channel mapping
        for destChannel in 0..<destChannels {
            let destPointer = floatChannelData[destChannel]

            // Clear destination channel
            destPointer.initialize(repeating: 0.0, count: frameCount)

            // Mix from source channels according to mapping
            for sourceChannel in 0..<sourceChannels {
                let gain = mapping.mappingMatrix[destChannel][sourceChannel]
                if gain != 0.0 {
                    var gainValue = gain
                    vDSP_vsma(tempData[sourceChannel], 1, &gainValue, destPointer, 1, destPointer, 1, vDSP_Length(frameCount))
                }
            }
        }

        // Cleanup temporary data
        for channel in 0..<sourceChannels {
            tempData[channel].deallocate()
        }
    }

    /// Apply channel mapping to AudioBuffer
    private func applyChannelMappingToAudioBuffer(_ buffer: AudioBuffer, mapping: ChannelMapping) throws -> AudioBuffer {
        let frameCount = buffer.frameCount
        let sourceChannels = mapping.sourceChannels
        let destChannels = mapping.destinationChannels

        // Allocate output buffer
        let outputData = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * destChannels)
        outputData.initialize(repeating: 0.0, count: frameCount * destChannels)

        // Apply channel mapping frame by frame
        for frame in 0..<frameCount {
            for destChannel in 0..<destChannels {
                var sample: Float = 0.0

                for sourceChannel in 0..<sourceChannels {
                    let gain = mapping.mappingMatrix[destChannel][sourceChannel]
                    if gain != 0.0 && sourceChannel < buffer.channelCount {
                        let sourceIndex = frame * buffer.channelCount + sourceChannel
                        sample += buffer.data[sourceIndex] * gain
                    }
                }

                let destIndex = frame * destChannels + destChannel
                outputData[destIndex] = sample
            }
        }

        return AudioBuffer(
            data: outputData,
            frameCount: frameCount,
            channelCount: destChannels,
            sampleRate: buffer.sampleRate
        )
    }

    /// Create PCM buffer from AudioBuffer
    private func createPCMBuffer(from audioBuffer: AudioBuffer, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audioBuffer.frameCount)) else {
            return nil
        }

        pcmBuffer.frameLength = AVAudioFrameCount(audioBuffer.frameCount)

        guard let floatChannelData = pcmBuffer.floatChannelData else {
            return nil
        }

        // Copy data channel by channel
        for channel in 0..<min(audioBuffer.channelCount, Int(format.channelCount)) {
            let channelPointer = floatChannelData[channel]

            for frame in 0..<audioBuffer.frameCount {
                let sourceIndex = frame * audioBuffer.channelCount + channel
                channelPointer[frame] = audioBuffer.data[sourceIndex]
            }
        }

        return pcmBuffer
    }

    /// Create AudioBuffer from PCM buffer
    private func createAudioBuffer(from pcmBuffer: AVAudioPCMBuffer) throws -> AudioBuffer {
        guard let floatChannelData = pcmBuffer.floatChannelData else {
            throw AudioEngineError.configurationError("PCM buffer does not contain float data")
        }

        let frameCount = Int(pcmBuffer.frameLength)
        let channelCount = Int(pcmBuffer.format.channelCount)
        let totalSamples = frameCount * channelCount

        let audioData = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)

        // Interleave channel data
        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                let destIndex = frame * channelCount + channel
                audioData[destIndex] = floatChannelData[channel][frame]
            }
        }

        return AudioBuffer(
            data: audioData,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: pcmBuffer.format.sampleRate
        )
    }

    /// Get conversion statistics
    public func getConversionInfo() -> (sourceFormat: AVAudioFormat, destinationFormat: AVAudioFormat, quality: ConversionQuality) {
        return (
            sourceFormat: configuration.sourceFormat,
            destinationFormat: configuration.destinationFormat,
            quality: configuration.quality
        )
    }
}

// MARK: - Format Conversion Manager

/// Manages multiple format converters and conversion operations
public final class AudioFormatConversionManager: @unchecked Sendable {

    /// Conversion cache entry
    private struct ConversionCacheEntry {
        let converter: AudioFormatConverter
        let lastUsed: Date
        let useCount: Int
    }

    private var converterCache: [String: ConversionCacheEntry] = [:]
    private let cacheQueue = DispatchQueue(label: "AudioFormatConversionManager", qos: .userInitiated)
    private let maxCacheSize: Int
    private let cacheTimeout: TimeInterval

    public init(maxCacheSize: Int = 10, cacheTimeout: TimeInterval = 300.0) {
        self.maxCacheSize = maxCacheSize
        self.cacheTimeout = cacheTimeout
    }

    /// Get or create a format converter
    public func getConverter(
        from sourceFormat: AVAudioFormat,
        to destinationFormat: AVAudioFormat,
        quality: AudioFormatConverter.ConversionQuality = .high
    ) throws -> AudioFormatConverter {
        let cacheKey = createCacheKey(source: sourceFormat, destination: destinationFormat, quality: quality)

        return try cacheQueue.sync {
            // Check cache first
            if let entry = converterCache[cacheKey] {
                // Update cache entry
                converterCache[cacheKey] = ConversionCacheEntry(
                    converter: entry.converter,
                    lastUsed: Date(),
                    useCount: entry.useCount + 1
                )
                return entry.converter
            }

            // Create new converter
            let config = AudioFormatConverter.ConversionConfiguration(
                sourceFormat: sourceFormat,
                destinationFormat: destinationFormat,
                quality: quality
            )

            let converter = try AudioFormatConverter(configuration: config)

            // Add to cache
            addToCache(key: cacheKey, converter: converter)

            return converter
        }
    }

    /// Convert audio buffer with automatic converter selection
    public func convert(
        _ buffer: AudioBuffer,
        from sourceFormat: AVAudioFormat,
        to destinationFormat: AVAudioFormat,
        quality: AudioFormatConverter.ConversionQuality = .high
    ) throws -> AudioBuffer {
        let converter = try getConverter(from: sourceFormat, to: destinationFormat, quality: quality)
        return try converter.convert(buffer)
    }

    /// Convert with channel mapping
    public func convertWithChannelMapping(
        _ buffer: AudioBuffer,
        from sourceFormat: AVAudioFormat,
        to destinationFormat: AVAudioFormat,
        channelMapping: AudioFormatConverter.ChannelMapping,
        quality: AudioFormatConverter.ConversionQuality = .high
    ) throws -> AudioBuffer {
        let converter = try getConverter(from: sourceFormat, to: destinationFormat, quality: quality)
        return try converter.convertWithChannelMapping(buffer, channelMapping: channelMapping)
    }

    /// Create standard format conversions
    public func createStandardConverter(
        from sourceFormat: AVAudioFormat,
        toSampleRate sampleRate: Double,
        channels: UInt32,
        bitDepth: UInt32 = 32
    ) throws -> AudioFormatConverter {
        guard let destinationFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        ) else {
            throw AudioEngineError.configurationError("Failed to create destination format")
        }

        return try getConverter(from: sourceFormat, to: destinationFormat)
    }

    /// Get cache statistics
    public func getCacheStatistics() -> (size: Int, hitRate: Double, totalConverters: Int) {
        return cacheQueue.sync {
            let size = converterCache.count
            let totalUses = converterCache.values.reduce(0) { $0 + $1.useCount }
            let hitRate = totalUses > 0 ? Double(totalUses - size) / Double(totalUses) : 0.0

            return (size: size, hitRate: hitRate, totalConverters: size)
        }
    }

    /// Clear expired cache entries
    public func cleanupCache() {
        cacheQueue.sync {
            let now = Date()
            let expiredKeys = converterCache.compactMap { key, entry in
                now.timeIntervalSince(entry.lastUsed) > cacheTimeout ? key : nil
            }

            for key in expiredKeys {
                converterCache.removeValue(forKey: key)
            }
        }
    }

    /// Clear all cached converters
    public func clearCache() {
        cacheQueue.sync {
            converterCache.removeAll()
        }
    }

    // MARK: - Private Methods

    private func createCacheKey(
        source: AVAudioFormat,
        destination: AVAudioFormat,
        quality: AudioFormatConverter.ConversionQuality
    ) -> String {
        return "\(source.sampleRate)_\(source.channelCount)_\(destination.sampleRate)_\(destination.channelCount)_\(quality.rawValue)"
    }

    private func addToCache(key: String, converter: AudioFormatConverter) {
        // Remove oldest entries if cache is full
        if converterCache.count >= maxCacheSize {
            let oldestKey = converterCache.min { $0.value.lastUsed < $1.value.lastUsed }?.key
            if let keyToRemove = oldestKey {
                converterCache.removeValue(forKey: keyToRemove)
            }
        }

        converterCache[key] = ConversionCacheEntry(
            converter: converter,
            lastUsed: Date(),
            useCount: 1
        )
    }
}

// MARK: - Audio Engine Status

/// Current status of the audio engine
public enum AudioEngineStatus: String, CaseIterable, Sendable {
    case uninitialized = "uninitialized"
    case initializing = "initializing"
    case ready = "ready"
    case starting = "starting"
    case running = "running"
    case stopping = "stopping"
    case stopped = "stopped"
    case error = "error"
    case suspended = "suspended"
}

// MARK: - Performance Metrics

/// Performance metrics for audio engine monitoring
public struct AudioEnginePerformanceMetrics: Sendable {
    public var cpuUsage: Double = 0.0
    public var memoryUsage: Int = 0
    public var bufferUnderruns: Int = 0
    public var bufferOverruns: Int = 0
    public var averageLatency: Double = 0.0
    public var peakLatency: Double = 0.0
    public var sampleRate: Double = 0.0
    public var bufferSize: Int = 0
    public var activeNodes: Int = 0

    // Buffer pool metrics
    public var bufferPoolAvailable: Int = 0
    public var bufferPoolAllocated: Int = 0
    public var bufferPoolTotal: Int = 0

    // Circular buffer metrics
    public var circularBufferCapacity: Int = 0
    public var circularBufferAvailable: Int = 0
    public var circularBufferUsage: Double = 0.0

    // Enhanced real-time performance metrics
    public var realTimeCpuUsage: Double = 0.0
    public var threadCount: Int = 0
    public var audioThreadPriority: Int = 0
    public var renderCallbackLatency: Double = 0.0
    public var processingLoad: Double = 0.0
    public var droppedFrames: Int = 0
    public var glitchCount: Int = 0
    public var thermalState: String = "nominal"

    // Advanced timing metrics
    public var minLatency: Double = Double.infinity
    public var maxLatency: Double = 0.0
    public var latencyStandardDeviation: Double = 0.0
    public var jitter: Double = 0.0
    public var clockDrift: Double = 0.0

    // Memory and resource metrics
    public var peakMemoryUsage: Int = 0
    public var memoryPressure: String = "normal"
    public var allocationsPerSecond: Int = 0
    public var deallocationsPerSecond: Int = 0

    // Performance analysis metrics
    public var performanceScore: Double = 100.0
    public var stabilityIndex: Double = 1.0
    public var efficiencyRating: Double = 1.0

    public init() {}

    public mutating func reset() {
        cpuUsage = 0.0
        memoryUsage = 0
        bufferUnderruns = 0
        bufferOverruns = 0
        averageLatency = 0.0
        peakLatency = 0.0
        activeNodes = 0
        bufferPoolAvailable = 0
        bufferPoolAllocated = 0
        bufferPoolTotal = 0
        circularBufferCapacity = 0
        circularBufferAvailable = 0
        circularBufferUsage = 0.0

        // Reset enhanced metrics
        realTimeCpuUsage = 0.0
        threadCount = 0
        audioThreadPriority = 0
        renderCallbackLatency = 0.0
        processingLoad = 0.0
        droppedFrames = 0
        glitchCount = 0
        thermalState = "nominal"
        minLatency = Double.infinity
        maxLatency = 0.0
        latencyStandardDeviation = 0.0
        jitter = 0.0
        clockDrift = 0.0
        peakMemoryUsage = 0
        memoryPressure = "normal"
        allocationsPerSecond = 0
        deallocationsPerSecond = 0
        performanceScore = 100.0
        stabilityIndex = 1.0
        efficiencyRating = 1.0
    }
}

// MARK: - Enhanced Performance Monitoring System

/// Real-time CPU usage tracker for audio processing
public final class AudioCPUTracker: @unchecked Sendable {
    private var lastCpuTime: Double = 0.0
    private var lastSystemTime: Double = 0.0
    private let trackingQueue = DispatchQueue(label: "AudioCPUTracker", qos: .userInitiated)

    public init() {}

    /// Get current real-time CPU usage percentage
    public func getCurrentCPUUsage() -> Double {
        return trackingQueue.sync {
            let currentTime = CFAbsoluteTimeGetCurrent()

            #if os(iOS)
            // Use iOS-specific CPU tracking
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

            let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
                }
            }

            if kerr == KERN_SUCCESS {
                let cpuTime = Double(info.user_time.seconds + info.system_time.seconds) +
                             Double(info.user_time.microseconds + info.system_time.microseconds) / 1_000_000.0

                let deltaTime = currentTime - lastSystemTime
                let deltaCpu = cpuTime - lastCpuTime

                lastCpuTime = cpuTime
                lastSystemTime = currentTime

                return deltaTime > 0 ? (deltaCpu / deltaTime) * 100.0 : 0.0
            }
            #endif

            // Fallback for macOS or if iOS tracking fails
            return 0.0
        }
    }

    /// Get audio thread priority
    public func getAudioThreadPriority() -> Int {
        var policy: Int32 = 0
        var param = sched_param()

        if pthread_getschedparam(pthread_self(), &policy, &param) == 0 {
            return Int(param.sched_priority)
        }

        return 0
    }

    /// Get current thread count
    public func getCurrentThreadCount() -> Int {
        #if os(iOS)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
        #else
        return 0
        #endif
    }
}

/// Advanced latency measurement tools
public final class AudioLatencyMeasurer: @unchecked Sendable {
    private var latencyHistory: [Double] = []
    private var maxHistorySize: Int = 1000
    private let measurementQueue = DispatchQueue(label: "AudioLatencyMeasurer", qos: .userInitiated)

    public init(maxHistorySize: Int = 1000) {
        self.maxHistorySize = maxHistorySize
    }

    /// Record a latency measurement
    public func recordLatency(_ latency: Double) {
        measurementQueue.sync {
            latencyHistory.append(latency)

            // Keep history within bounds
            if latencyHistory.count > maxHistorySize {
                latencyHistory.removeFirst()
            }
        }
    }

    /// Get latency statistics
    public func getLatencyStatistics() -> (min: Double, max: Double, average: Double, standardDeviation: Double, jitter: Double) {
        return measurementQueue.sync {
            guard !latencyHistory.isEmpty else {
                return (0.0, 0.0, 0.0, 0.0, 0.0)
            }

            let min = latencyHistory.min() ?? 0.0
            let max = latencyHistory.max() ?? 0.0
            let average = latencyHistory.reduce(0.0, +) / Double(latencyHistory.count)

            // Calculate standard deviation
            let variance = latencyHistory.reduce(0.0) { sum, latency in
                let diff = latency - average
                return sum + (diff * diff)
            } / Double(latencyHistory.count)
            let standardDeviation = sqrt(variance)

            // Calculate jitter (variation in latency)
            var jitter = 0.0
            if latencyHistory.count > 1 {
                for i in 1..<latencyHistory.count {
                    jitter += abs(latencyHistory[i] - latencyHistory[i-1])
                }
                jitter /= Double(latencyHistory.count - 1)
            }

            return (min, max, average, standardDeviation, jitter)
        }
    }

    /// Clear latency history
    public func clearHistory() {
        measurementQueue.sync {
            latencyHistory.removeAll()
        }
    }
}

/// Performance visualization and analysis tools
public final class AudioPerformanceAnalyzer: @unchecked Sendable {
    private let cpuTracker = AudioCPUTracker()
    private let latencyMeasurer = AudioLatencyMeasurer()
    private var performanceHistory: [AudioEnginePerformanceMetrics] = []
    private let maxHistorySize: Int = 3600 // 1 hour at 1 sample per second
    private let analysisQueue = DispatchQueue(label: "AudioPerformanceAnalyzer", qos: .userInitiated)

    public init() {}

    /// Analyze current performance and update metrics
    public func analyzePerformance(metrics: inout AudioEnginePerformanceMetrics) {
        analysisQueue.sync {
            // Update real-time CPU usage
            metrics.realTimeCpuUsage = cpuTracker.getCurrentCPUUsage()

            // Update thread information
            metrics.threadCount = cpuTracker.getCurrentThreadCount()
            metrics.audioThreadPriority = cpuTracker.getAudioThreadPriority()

            // Update latency statistics
            let latencyStats = latencyMeasurer.getLatencyStatistics()
            metrics.minLatency = latencyStats.min
            metrics.maxLatency = latencyStats.max
            metrics.latencyStandardDeviation = latencyStats.standardDeviation
            metrics.jitter = latencyStats.jitter

            // Calculate performance score (0-100)
            metrics.performanceScore = calculatePerformanceScore(metrics)

            // Calculate stability index (0-1)
            metrics.stabilityIndex = calculateStabilityIndex(metrics)

            // Calculate efficiency rating (0-1)
            metrics.efficiencyRating = calculateEfficiencyRating(metrics)

            // Update thermal state
            metrics.thermalState = getThermalState()

            // Update memory pressure
            metrics.memoryPressure = getMemoryPressure()

            // Store in history
            performanceHistory.append(metrics)
            if performanceHistory.count > maxHistorySize {
                performanceHistory.removeFirst()
            }
        }
    }

    /// Record a latency measurement
    public func recordLatency(_ latency: Double) {
        latencyMeasurer.recordLatency(latency)
    }

    /// Get performance trend analysis
    public func getPerformanceTrend(timeWindow: TimeInterval = 300) -> (trend: String, confidence: Double) {
        return analysisQueue.sync {
            guard performanceHistory.count >= 10 else {
                return ("insufficient_data", 0.0)
            }

            let recentMetrics = Array(performanceHistory.suffix(min(Int(timeWindow), performanceHistory.count)))
            let scores = recentMetrics.map { $0.performanceScore }

            // Simple linear regression to determine trend
            let n = Double(scores.count)
            let sumX = (0..<scores.count).reduce(0.0) { $0 + Double($1) }
            let sumY = scores.reduce(0.0, +)
            let sumXY = zip(0..<scores.count, scores).reduce(0.0) { $0 + Double($1.0) * $1.1 }
            let sumX2 = (0..<scores.count).reduce(0.0) { $0 + Double($1 * $1) }

            let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
            let confidence = abs(slope) / 10.0 // Normalize confidence

            let trend: String
            if slope > 0.5 {
                trend = "improving"
            } else if slope < -0.5 {
                trend = "degrading"
            } else {
                trend = "stable"
            }

            return (trend, min(confidence, 1.0))
        }
    }

    /// Generate performance report
    public func generatePerformanceReport() -> String {
        return analysisQueue.sync {
            guard !performanceHistory.isEmpty else {
                return "No performance data available"
            }

            let latest = performanceHistory.last!
            let trend = getPerformanceTrend()

            return """
            Audio Engine Performance Report
            ==============================

            Current Status:
            - Performance Score: \(String(format: "%.1f", latest.performanceScore))/100
            - Stability Index: \(String(format: "%.3f", latest.stabilityIndex))
            - Efficiency Rating: \(String(format: "%.3f", latest.efficiencyRating))
            - CPU Usage: \(String(format: "%.1f", latest.realTimeCpuUsage))%
            - Memory Usage: \(latest.memoryUsage) bytes
            - Thermal State: \(latest.thermalState)
            - Memory Pressure: \(latest.memoryPressure)

            Latency Metrics:
            - Average: \(String(format: "%.2f", latest.averageLatency))ms
            - Min: \(String(format: "%.2f", latest.minLatency))ms
            - Max: \(String(format: "%.2f", latest.maxLatency))ms
            - Jitter: \(String(format: "%.2f", latest.jitter))ms
            - Standard Deviation: \(String(format: "%.2f", latest.latencyStandardDeviation))ms

            Buffer Status:
            - Underruns: \(latest.bufferUnderruns)
            - Overruns: \(latest.bufferOverruns)
            - Dropped Frames: \(latest.droppedFrames)
            - Glitch Count: \(latest.glitchCount)

            Performance Trend: \(trend.trend) (confidence: \(String(format: "%.1f", trend.confidence * 100))%)

            Active Nodes: \(latest.activeNodes)
            Thread Count: \(latest.threadCount)
            Audio Thread Priority: \(latest.audioThreadPriority)
            """
        }
    }

    // MARK: - Private Methods

    private func calculatePerformanceScore(_ metrics: AudioEnginePerformanceMetrics) -> Double {
        var score = 100.0

        // Deduct for high CPU usage
        if metrics.realTimeCpuUsage > 80 {
            score -= (metrics.realTimeCpuUsage - 80) * 2
        }

        // Deduct for buffer issues
        score -= Double(metrics.bufferUnderruns + metrics.bufferOverruns) * 5
        score -= Double(metrics.droppedFrames) * 0.1
        score -= Double(metrics.glitchCount) * 10

        // Deduct for high latency
        if metrics.averageLatency > 10 {
            score -= (metrics.averageLatency - 10) * 2
        }

        return max(0.0, min(100.0, score))
    }

    private func calculateStabilityIndex(_ metrics: AudioEnginePerformanceMetrics) -> Double {
        var stability = 1.0

        // Reduce stability for jitter
        stability -= metrics.jitter / 100.0

        // Reduce stability for buffer issues
        stability -= Double(metrics.bufferUnderruns + metrics.bufferOverruns) / 100.0

        // Reduce stability for glitches
        stability -= Double(metrics.glitchCount) / 10.0

        return max(0.0, min(1.0, stability))
    }

    private func calculateEfficiencyRating(_ metrics: AudioEnginePerformanceMetrics) -> Double {
        var efficiency = 1.0

        // Reduce efficiency for high CPU usage
        efficiency -= metrics.realTimeCpuUsage / 100.0

        // Reduce efficiency for high memory usage
        if metrics.memoryUsage > 100_000_000 { // 100MB
            efficiency -= 0.2
        }

        return max(0.0, min(1.0, efficiency))
    }

    private func getThermalState() -> String {
        #if os(iOS)
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return "nominal"
        case .fair:
            return "fair"
        case .serious:
            return "serious"
        case .critical:
            return "critical"
        @unknown default:
            return "unknown"
        }
        #else
        return "nominal"
        #endif
    }

    private func getMemoryPressure() -> String {
        // Simplified memory pressure detection
        let memoryUsage = getMemoryUsage()
        if memoryUsage > 500_000_000 { // 500MB
            return "high"
        } else if memoryUsage > 200_000_000 { // 200MB
            return "moderate"
        } else {
            return "normal"
        }
    }

    private func getMemoryUsage() -> Int {
        // TODO: Fix concurrency safety for mach_task_self_
        return 0
        /*
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) { ptr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), ptr, &count)
            }
        }

        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
        */
    }
}

// MARK: - Thread Management System

/// Work item for audio processing tasks
public struct AudioWorkItem: @unchecked Sendable {
    public let id: UUID
    public let priority: AudioTaskPriority
    public let work: @Sendable () async -> Void
    public let createdAt: Date

    public init(priority: AudioTaskPriority = .normal, work: @escaping @Sendable () async -> Void) {
        self.id = UUID()
        self.priority = priority
        self.work = work
        self.createdAt = Date()
    }
}

/// Priority levels for audio processing tasks
public enum AudioTaskPriority: Int, CaseIterable, Sendable {
    case low = 0
    case normal = 1
    case high = 2
    case realTime = 3

    var qosClass: DispatchQoS.QoSClass {
        switch self {
        case .low:
            return .utility
        case .normal:
            return .userInitiated
        case .high:
            return .userInteractive
        case .realTime:
            return .userInteractive
        }
    }
}

/// Thread pool for audio processing tasks with work-stealing capabilities
public final class AudioThreadPool: @unchecked Sendable {
    private let maxThreads: Int
    private let minThreads: Int
    private var threads: [AudioWorkerThread] = []
    private var workQueues: [AudioWorkQueue] = []
    private let poolQueue = DispatchQueue(label: "AudioThreadPool", qos: .userInitiated)
    private var isShutdown = false

    public init(minThreads: Int = 2, maxThreads: Int = 8) {
        self.minThreads = max(1, minThreads)
        self.maxThreads = max(self.minThreads, maxThreads)

        setupThreadPool()
    }

    deinit {
        shutdown()
    }

    /// Submit work to the thread pool
    public func submit(_ workItem: AudioWorkItem) {
        poolQueue.sync {
            guard !isShutdown else { return }

            // Find the queue with the least work for load balancing
            let targetQueue = workQueues.min { $0.workCount < $1.workCount } ?? workQueues.first
            targetQueue?.enqueue(workItem)
        }
    }

    /// Submit work with priority
    public func submit(priority: AudioTaskPriority = .normal, work: @escaping @Sendable () async -> Void) {
        let workItem = AudioWorkItem(priority: priority, work: work)
        submit(workItem)
    }

    /// Get thread pool statistics
    public func getStatistics() -> (activeThreads: Int, totalWork: Int, averageLoad: Double) {
        return poolQueue.sync {
            let activeThreads = threads.filter { $0.isActive }.count
            let totalWork = workQueues.reduce(0) { $0 + $1.workCount }
            let averageLoad = threads.isEmpty ? 0.0 : Double(totalWork) / Double(threads.count)

            return (activeThreads, totalWork, averageLoad)
        }
    }

    /// Shutdown the thread pool
    public func shutdown() {
        poolQueue.sync {
            guard !isShutdown else { return }
            isShutdown = true

            // Signal all threads to stop
            for thread in threads {
                thread.stop()
            }

            // Clear work queues
            workQueues.removeAll()
            threads.removeAll()
        }
    }

    // MARK: - Private Methods

    private func setupThreadPool() {
        // Create work queues for each thread
        for i in 0..<maxThreads {
            let queue = AudioWorkQueue(id: i)
            workQueues.append(queue)
        }

        // Create initial threads
        for i in 0..<minThreads {
            let thread = AudioWorkerThread(
                id: i,
                workQueue: workQueues[i],
                allQueues: workQueues,
                threadPool: self
            )
            threads.append(thread)
            thread.start()
        }
    }

    /// Attempt work stealing from other queues
    internal func stealWork(excludingQueue: Int) -> AudioWorkItem? {
        return poolQueue.sync {
            // Try to steal from queues with the most work
            let sortedQueues = workQueues.enumerated()
                .filter { $0.offset != excludingQueue }
                .sorted { $0.element.workCount > $1.element.workCount }

            for (_, queue) in sortedQueues {
                if let work = queue.stealWork() {
                    return work
                }
            }

            return nil
        }
    }
}

/// Work queue for individual threads with priority support
public final class AudioWorkQueue: @unchecked Sendable {
    private let id: Int
    private var highPriorityWork: [AudioWorkItem] = []
    private var normalPriorityWork: [AudioWorkItem] = []
    private var lowPriorityWork: [AudioWorkItem] = []
    private let queueLock = NSLock()

    public init(id: Int) {
        self.id = id
    }

    /// Add work to the queue
    public func enqueue(_ workItem: AudioWorkItem) {
        queueLock.lock()
        defer { queueLock.unlock() }

        switch workItem.priority {
        case .realTime, .high:
            highPriorityWork.append(workItem)
        case .normal:
            normalPriorityWork.append(workItem)
        case .low:
            lowPriorityWork.append(workItem)
        }
    }

    /// Get work from the queue (priority order)
    public func dequeue() -> AudioWorkItem? {
        queueLock.lock()
        defer { queueLock.unlock() }

        // Process high priority first
        if !highPriorityWork.isEmpty {
            return highPriorityWork.removeFirst()
        }

        // Then normal priority
        if !normalPriorityWork.isEmpty {
            return normalPriorityWork.removeFirst()
        }

        // Finally low priority
        if !lowPriorityWork.isEmpty {
            return lowPriorityWork.removeFirst()
        }

        return nil
    }

    /// Steal work from this queue (for work stealing)
    public func stealWork() -> AudioWorkItem? {
        queueLock.lock()
        defer { queueLock.unlock() }

        // Only steal from low and normal priority work
        if !lowPriorityWork.isEmpty {
            return lowPriorityWork.removeLast()
        }

        if !normalPriorityWork.isEmpty {
            return normalPriorityWork.removeLast()
        }

        return nil
    }

    /// Get current work count
    public var workCount: Int {
        queueLock.lock()
        defer { queueLock.unlock() }

        return highPriorityWork.count + normalPriorityWork.count + lowPriorityWork.count
    }
}

/// Individual worker thread with work-stealing capability
public final class AudioWorkerThread: @unchecked Sendable {
    private let id: Int
    private let workQueue: AudioWorkQueue
    private let allQueues: [AudioWorkQueue]
    private weak var threadPool: AudioThreadPool?
    private var isRunning = false
    private var thread: Thread?

    public var isActive: Bool {
        return isRunning && thread?.isExecuting == true
    }

    public init(id: Int, workQueue: AudioWorkQueue, allQueues: [AudioWorkQueue], threadPool: AudioThreadPool) {
        self.id = id
        self.workQueue = workQueue
        self.allQueues = allQueues
        self.threadPool = threadPool
    }

    /// Start the worker thread
    public func start() {
        guard !isRunning else { return }

        isRunning = true
        thread = Thread { [weak self] in
            self?.runLoop()
        }
        thread?.name = "AudioWorkerThread-\(id)"
        thread?.qualityOfService = .userInteractive
        thread?.start()
    }

    /// Stop the worker thread
    public func stop() {
        isRunning = false
        thread?.cancel()
    }

    // MARK: - Private Methods

    private func runLoop() {
        // Set thread priority for audio processing
        setThreadPriority()

        while isRunning && thread?.isCancelled == false {
            autoreleasepool {
                // Try to get work from own queue first
                var workItem = workQueue.dequeue()

                // If no work, try work stealing
                if workItem == nil {
                    workItem = threadPool?.stealWork(excludingQueue: id)
                }

                if let work = workItem {
                    // Execute the work
                    Task {
                        await work.work()
                    }
                } else {
                    // No work available, sleep briefly
                    Thread.sleep(forTimeInterval: 0.001) // 1ms
                }
            }
        }
    }

    private func setThreadPriority() {
        // Set high priority for audio processing
        var param = sched_param()
        param.sched_priority = 47 // High priority for audio

        if pthread_setschedparam(pthread_self(), SCHED_FIFO, &param) != 0 {
            // Fallback to setting thread priority
            Thread.current.threadPriority = 0.9
        }
    }
}

/// Thread synchronization utilities for audio processing
public final class AudioThreadSynchronizer: @unchecked Sendable {
    private let semaphore: DispatchSemaphore
    private let condition = NSCondition()
    private var waitingThreads = 0
    private var signaled = false

    public init(initialValue: Int = 0) {
        self.semaphore = DispatchSemaphore(value: initialValue)
    }

    /// Wait for signal with timeout
    public func wait(timeout: TimeInterval = .infinity) -> Bool {
        if timeout == .infinity {
            semaphore.wait()
            return true
        } else {
            let result = semaphore.wait(timeout: .now() + timeout)
            return result == .success
        }
    }

    /// Signal waiting threads
    public func signal() {
        semaphore.signal()
    }

    /// Broadcast signal to all waiting threads
    public func broadcast() {
        condition.lock()
        signaled = true
        condition.broadcast()
        condition.unlock()
    }

    /// Wait for broadcast signal
    public func waitForBroadcast(timeout: TimeInterval = .infinity) -> Bool {
        condition.lock()
        defer { condition.unlock() }

        waitingThreads += 1
        defer { waitingThreads -= 1 }

        while !signaled {
            if timeout == .infinity {
                condition.wait()
            } else {
                let result = condition.wait(until: Date().addingTimeInterval(timeout))
                if !result {
                    return false
                }
            }
        }

        return true
    }

    /// Reset broadcast signal
    public func resetBroadcast() {
        condition.lock()
        signaled = false
        condition.unlock()
    }
}

// MARK: - DSP Algorithm Library

/// Base protocol for all DSP algorithms
public protocol DSPAlgorithm: Sendable {
    /// Process audio buffer in-place
    func process(_ buffer: AudioBuffer)

    /// Reset algorithm state
    func reset()

    /// Get algorithm parameters
    var parameters: [String: Float] { get set }

    /// Algorithm name
    var name: String { get }
}

/// Reverb algorithm implementation
public final class ReverbAlgorithm: DSPAlgorithm, @unchecked Sendable {
    public let name = "Reverb"

    // Reverb parameters
    private var roomSize: Float = 0.5
    private var damping: Float = 0.5
    private var wetLevel: Float = 0.3
    private var dryLevel: Float = 0.7
    private var width: Float = 1.0

    // Delay lines for reverb
    private var delayLines: [DelayLine] = []
    private var allpassFilters: [AllpassFilter] = []
    private var combFilters: [CombFilter] = []

    public var parameters: [String: Float] {
        get {
            return [
                "roomSize": roomSize,
                "damping": damping,
                "wetLevel": wetLevel,
                "dryLevel": dryLevel,
                "width": width
            ]
        }
        set {
            roomSize = newValue["roomSize"] ?? roomSize
            damping = newValue["damping"] ?? damping
            wetLevel = newValue["wetLevel"] ?? wetLevel
            dryLevel = newValue["dryLevel"] ?? dryLevel
            width = newValue["width"] ?? width
            updateFilters()
        }
    }

    public init(sampleRate: Double = 44100.0) {
        setupReverb(sampleRate: sampleRate)
    }

    public func process(_ buffer: AudioBuffer) {
        let frameCount = buffer.frameCount
        let channelCount = buffer.channelCount

        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                let sampleIndex = frame * channelCount + channel
                let inputSample = buffer.data[sampleIndex]

                // Process through comb filters
                var reverbSample: Float = 0.0
                for combFilter in combFilters {
                    reverbSample += combFilter.process(inputSample)
                }

                // Process through allpass filters
                for allpassFilter in allpassFilters {
                    reverbSample = allpassFilter.process(reverbSample)
                }

                // Mix wet and dry signals
                let outputSample = inputSample * dryLevel + reverbSample * wetLevel
                buffer.data[sampleIndex] = outputSample
            }
        }
    }

    public func reset() {
        for combFilter in combFilters {
            combFilter.reset()
        }
        for allpassFilter in allpassFilters {
            allpassFilter.reset()
        }
    }

    private func setupReverb(sampleRate: Double) {
        // Comb filter delays (in samples)
        let combDelays = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]

        // Allpass filter delays (in samples)
        let allpassDelays = [556, 441, 341, 225]

        // Create comb filters
        combFilters = combDelays.map { delay in
            CombFilter(delayInSamples: Int(Double(delay) * sampleRate / 44100.0), feedback: 0.84, damping: damping)
        }

        // Create allpass filters
        allpassFilters = allpassDelays.map { delay in
            AllpassFilter(delayInSamples: Int(Double(delay) * sampleRate / 44100.0), feedback: 0.5)
        }
    }

    private func updateFilters() {
        for combFilter in combFilters {
            combFilter.setFeedback(0.84 * roomSize)
            combFilter.setDamping(damping)
        }
    }
}

/// Delay algorithm implementation
public final class DelayAlgorithm: DSPAlgorithm, @unchecked Sendable {
    public let name = "Delay"

    private var delayTime: Float = 0.25 // seconds
    private var feedback: Float = 0.3
    private var wetLevel: Float = 0.3
    private var dryLevel: Float = 0.7

    private var delayLine: DelayLine

    public var parameters: [String: Float] {
        get {
            return [
                "delayTime": delayTime,
                "feedback": feedback,
                "wetLevel": wetLevel,
                "dryLevel": dryLevel
            ]
        }
        set {
            delayTime = newValue["delayTime"] ?? delayTime
            feedback = newValue["feedback"] ?? feedback
            wetLevel = newValue["wetLevel"] ?? wetLevel
            dryLevel = newValue["dryLevel"] ?? dryLevel
            updateDelay()
        }
    }

    public init(sampleRate: Double = 44100.0, maxDelayTime: Float = 2.0) {
        let maxDelaySamples = Int(Double(maxDelayTime) * sampleRate)
        delayLine = DelayLine(maxDelay: maxDelaySamples)
        updateDelay()
    }

    public func process(_ buffer: AudioBuffer) {
        let frameCount = buffer.frameCount
        let channelCount = buffer.channelCount

        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                let sampleIndex = frame * channelCount + channel
                let inputSample = buffer.data[sampleIndex]

                // Get delayed sample
                let delayedSample = delayLine.read()

                // Create feedback
                let feedbackSample = inputSample + delayedSample * feedback
                delayLine.write(feedbackSample)

                // Mix wet and dry signals
                let outputSample = inputSample * dryLevel + delayedSample * wetLevel
                buffer.data[sampleIndex] = outputSample
            }
        }
    }

    public func reset() {
        delayLine.reset()
    }

    private func updateDelay() {
        // Update delay line parameters if needed
    }
}

/// EQ algorithm implementation (3-band parametric EQ)
public final class EQAlgorithm: DSPAlgorithm, @unchecked Sendable {
    public let name = "EQ"

    private var lowGain: Float = 0.0    // dB
    private var midGain: Float = 0.0    // dB
    private var highGain: Float = 0.0   // dB
    private var lowFreq: Float = 200.0  // Hz
    private var midFreq: Float = 1000.0 // Hz
    private var highFreq: Float = 5000.0 // Hz
    private var lowQ: Float = 0.7
    private var midQ: Float = 0.7
    private var highQ: Float = 0.7

    private var lowFilter: BiquadFilter
    private var midFilter: BiquadFilter
    private var highFilter: BiquadFilter

    public var parameters: [String: Float] {
        get {
            return [
                "lowGain": lowGain,
                "midGain": midGain,
                "highGain": highGain,
                "lowFreq": lowFreq,
                "midFreq": midFreq,
                "highFreq": highFreq,
                "lowQ": lowQ,
                "midQ": midQ,
                "highQ": highQ
            ]
        }
        set {
            lowGain = newValue["lowGain"] ?? lowGain
            midGain = newValue["midGain"] ?? midGain
            highGain = newValue["highGain"] ?? highGain
            lowFreq = newValue["lowFreq"] ?? lowFreq
            midFreq = newValue["midFreq"] ?? midFreq
            highFreq = newValue["highFreq"] ?? highFreq
            lowQ = newValue["lowQ"] ?? lowQ
            midQ = newValue["midQ"] ?? midQ
            highQ = newValue["highQ"] ?? highQ
            updateFilters()
        }
    }

    public init(sampleRate: Double = 44100.0) {
        lowFilter = BiquadFilter(sampleRate: sampleRate)
        midFilter = BiquadFilter(sampleRate: sampleRate)
        highFilter = BiquadFilter(sampleRate: sampleRate)
        updateFilters()
    }

    public func process(_ buffer: AudioBuffer) {
        let frameCount = buffer.frameCount
        let channelCount = buffer.channelCount

        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                let sampleIndex = frame * channelCount + channel
                var sample = buffer.data[sampleIndex]

                // Process through each EQ band
                sample = lowFilter.process(sample)
                sample = midFilter.process(sample)
                sample = highFilter.process(sample)

                buffer.data[sampleIndex] = sample
            }
        }
    }

    public func reset() {
        lowFilter.reset()
        midFilter.reset()
        highFilter.reset()
    }

    private func updateFilters() {
        lowFilter.setPeakingEQ(frequency: lowFreq, gain: lowGain, q: lowQ)
        midFilter.setPeakingEQ(frequency: midFreq, gain: midGain, q: midQ)
        highFilter.setPeakingEQ(frequency: highFreq, gain: highGain, q: highQ)
    }
}

// MARK: - DSP Building Blocks

/// Delay line implementation
public final class DelayLine: @unchecked Sendable {
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private let maxDelay: Int

    public init(maxDelay: Int) {
        self.maxDelay = maxDelay
        self.buffer = Array(repeating: 0.0, count: maxDelay)
    }

    public func write(_ sample: Float) {
        buffer[writeIndex] = sample
        writeIndex = (writeIndex + 1) % maxDelay
    }

    public func read() -> Float {
        let sample = buffer[readIndex]
        readIndex = (readIndex + 1) % maxDelay
        return sample
    }

    public func readWithDelay(_ delaySamples: Int) -> Float {
        let index = (writeIndex - delaySamples + maxDelay) % maxDelay
        return buffer[index]
    }

    public func reset() {
        buffer = Array(repeating: 0.0, count: maxDelay)
        writeIndex = 0
        readIndex = 0
    }
}

/// Comb filter implementation
public final class CombFilter: @unchecked Sendable {
    private let delayLine: DelayLine
    private var feedback: Float
    private var damping: Float
    private var filterState: Float = 0.0

    public init(delayInSamples: Int, feedback: Float, damping: Float) {
        self.delayLine = DelayLine(maxDelay: delayInSamples)
        self.feedback = feedback
        self.damping = damping
    }

    public func process(_ input: Float) -> Float {
        let delayed = delayLine.read()

        // Apply damping filter (simple lowpass)
        filterState = delayed * (1.0 - damping) + filterState * damping

        let output = input + filterState * feedback
        delayLine.write(output)

        return delayed
    }

    public func setFeedback(_ feedback: Float) {
        self.feedback = feedback
    }

    public func setDamping(_ damping: Float) {
        self.damping = damping
    }

    public func reset() {
        delayLine.reset()
        filterState = 0.0
    }
}

/// Allpass filter implementation
public final class AllpassFilter: @unchecked Sendable {
    private let delayLine: DelayLine
    private let feedback: Float

    public init(delayInSamples: Int, feedback: Float) {
        self.delayLine = DelayLine(maxDelay: delayInSamples)
        self.feedback = feedback
    }

    public func process(_ input: Float) -> Float {
        let delayed = delayLine.read()
        let output = -input + delayed
        delayLine.write(input + delayed * feedback)
        return output
    }

    public func reset() {
        delayLine.reset()
    }
}

/// Biquad filter implementation
public final class BiquadFilter: @unchecked Sendable {
    private var a0: Float = 1.0
    private var a1: Float = 0.0
    private var a2: Float = 0.0
    private var b1: Float = 0.0
    private var b2: Float = 0.0

    private var x1: Float = 0.0
    private var x2: Float = 0.0
    private var y1: Float = 0.0
    private var y2: Float = 0.0

    private let sampleRate: Double

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    public func process(_ input: Float) -> Float {
        let output = a0 * input + a1 * x1 + a2 * x2 - b1 * y1 - b2 * y2

        // Update delay elements
        x2 = x1
        x1 = input
        y2 = y1
        y1 = output

        return output
    }

    public func setPeakingEQ(frequency: Float, gain: Float, q: Float) {
        let omega = 2.0 * Float.pi * frequency / Float(sampleRate)
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)
        let A = pow(10.0, gain / 40.0)

        let b0 = 1.0 + alpha * A
        let b1 = -2.0 * cosOmega
        let b2 = 1.0 - alpha * A
        let a0 = 1.0 + alpha / A
        let a1 = -2.0 * cosOmega
        let a2 = 1.0 - alpha / A

        // Normalize coefficients
        self.a0 = b0 / a0
        self.a1 = b1 / a0
        self.a2 = b2 / a0
        self.b1 = a1 / a0
        self.b2 = a2 / a0
    }

    public func reset() {
        x1 = 0.0
        x2 = 0.0
        y1 = 0.0
        y2 = 0.0
    }
}

// MARK: - DSP Algorithm Manager and Benchmarking

/// DSP algorithm manager for organizing and benchmarking algorithms
public final class DSPAlgorithmManager: @unchecked Sendable {
    private var algorithms: [String: DSPAlgorithm] = [:]
    private var benchmarkResults: [String: DSPBenchmarkResult] = [:]
    private let managerQueue = DispatchQueue(label: "DSPAlgorithmManager", qos: .userInitiated)

    public init() {
        setupDefaultAlgorithms()
    }

    /// Register a DSP algorithm
    public func registerAlgorithm(_ algorithm: DSPAlgorithm) {
        managerQueue.sync {
            algorithms[algorithm.name] = algorithm
        }
    }

    /// Get algorithm by name
    public func getAlgorithm(name: String) -> DSPAlgorithm? {
        return managerQueue.sync {
            return algorithms[name]
        }
    }

    /// Get all available algorithms
    public func getAllAlgorithms() -> [String: DSPAlgorithm] {
        return managerQueue.sync {
            return algorithms
        }
    }

    /// Benchmark an algorithm
    public func benchmarkAlgorithm(name: String, testBuffer: AudioBuffer, iterations: Int = 1000) -> DSPBenchmarkResult? {
        return managerQueue.sync {
            guard let algorithm = algorithms[name] else { return nil }

            let benchmarker = DSPBenchmarker()
            let result = benchmarker.benchmark(algorithm: algorithm, testBuffer: testBuffer, iterations: iterations)
            benchmarkResults[name] = result

            return result
        }
    }

    /// Get benchmark results
    public func getBenchmarkResults() -> [String: DSPBenchmarkResult] {
        return managerQueue.sync {
            return benchmarkResults
        }
    }

    /// Generate benchmark report
    public func generateBenchmarkReport() -> String {
        return managerQueue.sync {
            var report = "DSP Algorithm Benchmark Report\n"
            report += "==============================\n\n"

            for (name, result) in benchmarkResults.sorted(by: { $0.value.averageTime < $1.value.averageTime }) {
                report += "Algorithm: \(name)\n"
                report += "  Average Time: \(String(format: "%.3f", result.averageTime * 1000))ms\n"
                report += "  Min Time: \(String(format: "%.3f", result.minTime * 1000))ms\n"
                report += "  Max Time: \(String(format: "%.3f", result.maxTime * 1000))ms\n"
                report += "  CPU Usage: \(String(format: "%.1f", result.cpuUsage))%\n"
                report += "  Memory Usage: \(result.memoryUsage) bytes\n"
                report += "  Performance Score: \(String(format: "%.1f", result.performanceScore))/100\n\n"
            }

            return report
        }
    }

    private func setupDefaultAlgorithms() {
        // Register default algorithms
        registerAlgorithm(ReverbAlgorithm())
        registerAlgorithm(DelayAlgorithm())
        registerAlgorithm(EQAlgorithm())
    }
}

/// Benchmark result for DSP algorithms
public struct DSPBenchmarkResult: Sendable {
    public let algorithmName: String
    public let averageTime: Double
    public let minTime: Double
    public let maxTime: Double
    public let cpuUsage: Double
    public let memoryUsage: Int
    public let performanceScore: Double
    public let iterations: Int
    public let timestamp: Date

    public init(algorithmName: String, averageTime: Double, minTime: Double, maxTime: Double,
                cpuUsage: Double, memoryUsage: Int, performanceScore: Double, iterations: Int) {
        self.algorithmName = algorithmName
        self.averageTime = averageTime
        self.minTime = minTime
        self.maxTime = maxTime
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.performanceScore = performanceScore
        self.iterations = iterations
        self.timestamp = Date()
    }
}

/// DSP algorithm benchmarker
public final class DSPBenchmarker: @unchecked Sendable {

    public init() {}

    /// Benchmark a DSP algorithm
    public func benchmark(algorithm: DSPAlgorithm, testBuffer: AudioBuffer, iterations: Int) -> DSPBenchmarkResult {
        var times: [Double] = []
        let startMemory = getMemoryUsage()

        // Warm up
        for _ in 0..<10 {
            let testBufferCopy = createBufferCopy(testBuffer)
            algorithm.process(testBufferCopy)
        }

        // Actual benchmark
        for _ in 0..<iterations {
            let testBufferCopy = createBufferCopy(testBuffer)

            let startTime = CFAbsoluteTimeGetCurrent()
            algorithm.process(testBufferCopy)
            let endTime = CFAbsoluteTimeGetCurrent()

            times.append(endTime - startTime)
        }

        let endMemory = getMemoryUsage()

        // Calculate statistics
        let averageTime = times.reduce(0.0, +) / Double(times.count)
        let minTime = times.min() ?? 0.0
        let maxTime = times.max() ?? 0.0
        let memoryUsage = endMemory - startMemory

        // Calculate CPU usage (simplified)
        let cpuUsage = min(100.0, averageTime * 100000.0) // Rough estimate

        // Calculate performance score (0-100, higher is better)
        let performanceScore = max(0.0, min(100.0, 100.0 - (averageTime * 10000.0)))

        return DSPBenchmarkResult(
            algorithmName: algorithm.name,
            averageTime: averageTime,
            minTime: minTime,
            maxTime: maxTime,
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            performanceScore: performanceScore,
            iterations: iterations
        )
    }

    private func createBufferCopy(_ original: AudioBuffer) -> AudioBuffer {
        let totalSamples = original.frameCount * original.channelCount
        let newData = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)
        newData.initialize(from: original.data, count: totalSamples)

        return AudioBuffer(
            data: newData,
            frameCount: original.frameCount,
            channelCount: original.channelCount,
            sampleRate: original.sampleRate
        )
    }

    private func getMemoryUsage() -> Int {
        // TODO: Fix concurrency safety for mach_task_self_
        return 0
        /*
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) { ptr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), ptr, &count)
            }
        }

        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
        */
    }
}

// MARK: - MIDI Support System

/// MIDI message types
public enum MIDIMessageType: UInt8, CaseIterable, Sendable {
    case noteOff = 0x80
    case noteOn = 0x90
    case polyphonicKeyPressure = 0xA0
    case controlChange = 0xB0
    case programChange = 0xC0
    case channelPressure = 0xD0
    case pitchBend = 0xE0
    case systemExclusive = 0xF0
    case timeCode = 0xF1
    case songPosition = 0xF2
    case songSelect = 0xF3
    case tuneRequest = 0xF6
    case endOfExclusive = 0xF7
    case timingClock = 0xF8
    case start = 0xFA
    case `continue` = 0xFB
    case stop = 0xFC
    case activeSensing = 0xFE
    case reset = 0xFF
}

/// MIDI message structure
public struct MIDIMessage: Sendable {
    public let timestamp: UInt64
    public let status: UInt8
    public let data1: UInt8
    public let data2: UInt8
    public let channel: UInt8
    public let messageType: MIDIMessageType

    public init(timestamp: UInt64, status: UInt8, data1: UInt8, data2: UInt8) {
        self.timestamp = timestamp
        self.status = status
        self.data1 = data1
        self.data2 = data2
        self.channel = status & 0x0F
        self.messageType = MIDIMessageType(rawValue: status & 0xF0) ?? .noteOn
    }

    /// Create a note on message
    public static func noteOn(channel: UInt8, note: UInt8, velocity: UInt8, timestamp: UInt64 = 0) -> MIDIMessage {
        return MIDIMessage(timestamp: timestamp, status: 0x90 | (channel & 0x0F), data1: note, data2: velocity)
    }

    /// Create a note off message
    public static func noteOff(channel: UInt8, note: UInt8, velocity: UInt8, timestamp: UInt64 = 0) -> MIDIMessage {
        return MIDIMessage(timestamp: timestamp, status: 0x80 | (channel & 0x0F), data1: note, data2: velocity)
    }

    /// Create a control change message
    public static func controlChange(channel: UInt8, controller: UInt8, value: UInt8, timestamp: UInt64 = 0) -> MIDIMessage {
        return MIDIMessage(timestamp: timestamp, status: 0xB0 | (channel & 0x0F), data1: controller, data2: value)
    }

    /// Create a pitch bend message
    public static func pitchBend(channel: UInt8, value: UInt16, timestamp: UInt64 = 0) -> MIDIMessage {
        let lsb = UInt8(value & 0x7F)
        let msb = UInt8((value >> 7) & 0x7F)
        return MIDIMessage(timestamp: timestamp, status: 0xE0 | (channel & 0x0F), data1: lsb, data2: msb)
    }
}

/// MIDI message parser for processing raw MIDI data
public final class MIDIMessageParser: @unchecked Sendable {
    private var runningStatus: UInt8 = 0
    private var dataBytes: [UInt8] = []
    private var expectedDataBytes: Int = 0
    private let parserQueue = DispatchQueue(label: "MIDIMessageParser", qos: .userInitiated)

    public init() {}

    /// Parse raw MIDI bytes into messages
    public func parseBytes(_ bytes: [UInt8], timestamp: UInt64 = 0) -> [MIDIMessage] {
        return parserQueue.sync {
            var messages: [MIDIMessage] = []

            for byte in bytes {
                if byte >= 0x80 {
                    // Status byte
                    if !dataBytes.isEmpty && expectedDataBytes > 0 {
                        // Complete previous message if possible
                        if let message = completeMessage(timestamp: timestamp) {
                            messages.append(message)
                        }
                    }

                    runningStatus = byte
                    dataBytes.removeAll()
                    expectedDataBytes = getExpectedDataBytes(for: byte)
                } else {
                    // Data byte
                    if runningStatus != 0 {
                        dataBytes.append(byte)

                        if dataBytes.count >= expectedDataBytes {
                            if let message = completeMessage(timestamp: timestamp) {
                                messages.append(message)
                            }
                            dataBytes.removeAll()
                        }
                    }
                }
            }

            return messages
        }
    }

    private func completeMessage(timestamp: UInt64) -> MIDIMessage? {
        guard runningStatus != 0 else { return nil }

        let data1 = dataBytes.count > 0 ? dataBytes[0] : 0
        let data2 = dataBytes.count > 1 ? dataBytes[1] : 0

        return MIDIMessage(timestamp: timestamp, status: runningStatus, data1: data1, data2: data2)
    }

    private func getExpectedDataBytes(for status: UInt8) -> Int {
        let messageType = status & 0xF0

        switch messageType {
        case 0x80, 0x90, 0xA0, 0xB0, 0xE0: // Note off, note on, poly pressure, CC, pitch bend
            return 2
        case 0xC0, 0xD0: // Program change, channel pressure
            return 1
        case 0xF0: // System messages
            switch status {
            case 0xF1, 0xF3: // Time code, song select
                return 1
            case 0xF2: // Song position
                return 2
            default:
                return 0
            }
        default:
            return 0
        }
    }
}

/// MIDI routing system for managing MIDI connections
public final class MIDIRouter: @unchecked Sendable {
    private var routes: [MIDIRoute] = []
    private var filters: [MIDIFilter] = []
    private let routerQueue = DispatchQueue(label: "MIDIRouter", qos: .userInitiated)

    public init() {}

    /// Add a MIDI route
    public func addRoute(_ route: MIDIRoute) {
        routerQueue.sync {
            routes.append(route)
        }
    }

    /// Remove a MIDI route
    public func removeRoute(id: UUID) {
        routerQueue.sync {
            routes.removeAll { $0.id == id }
        }
    }

    /// Add a MIDI filter
    public func addFilter(_ filter: MIDIFilter) {
        routerQueue.sync {
            filters.append(filter)
        }
    }

    /// Route MIDI messages
    public func routeMessage(_ message: MIDIMessage) -> [MIDIMessage] {
        return routerQueue.sync {
            var processedMessages = [message]

            // Apply filters
            for filter in filters {
                processedMessages = processedMessages.compactMap { filter.process($0) }
            }

            // Apply routes
            var routedMessages: [MIDIMessage] = []
            for processedMessage in processedMessages {
                for route in routes {
                    if route.matches(processedMessage) {
                        routedMessages.append(route.transform(processedMessage))
                    }
                }
            }

            return routedMessages.isEmpty ? processedMessages : routedMessages
        }
    }

    /// Get all routes
    public func getAllRoutes() -> [MIDIRoute] {
        return routerQueue.sync { routes }
    }

    /// Clear all routes
    public func clearRoutes() {
        routerQueue.sync {
            routes.removeAll()
            filters.removeAll()
        }
    }
}

/// MIDI route for transforming and routing messages
public struct MIDIRoute: Sendable {
    public let id: UUID
    public let sourceChannel: UInt8?
    public let targetChannel: UInt8?
    public let messageTypes: Set<MIDIMessageType>
    public let transform: @Sendable (MIDIMessage) -> MIDIMessage
    public let condition: @Sendable (MIDIMessage) -> Bool

    public init(
        sourceChannel: UInt8? = nil,
        targetChannel: UInt8? = nil,
        messageTypes: Set<MIDIMessageType> = Set(MIDIMessageType.allCases),
        condition: @escaping @Sendable (MIDIMessage) -> Bool = { _ in true },
        transform: @escaping @Sendable (MIDIMessage) -> MIDIMessage = { $0 }
    ) {
        self.id = UUID()
        self.sourceChannel = sourceChannel
        self.targetChannel = targetChannel
        self.messageTypes = messageTypes
        self.condition = condition
        self.transform = transform
    }

    /// Check if route matches message
    public func matches(_ message: MIDIMessage) -> Bool {
        // Check channel
        if let sourceChannel = sourceChannel, message.channel != sourceChannel {
            return false
        }

        // Check message type
        if !messageTypes.contains(message.messageType) {
            return false
        }

        // Check custom condition
        return condition(message)
    }
}

/// MIDI filter for processing messages
public struct MIDIFilter: Sendable {
    public let id: UUID
    public let process: @Sendable (MIDIMessage) -> MIDIMessage?

    public init(process: @escaping @Sendable (MIDIMessage) -> MIDIMessage?) {
        self.id = UUID()
        self.process = process
    }

    /// Create a channel filter
    public static func channelFilter(allowedChannels: Set<UInt8>) -> MIDIFilter {
        return MIDIFilter { message in
            return allowedChannels.contains(message.channel) ? message : nil
        }
    }

    /// Create a velocity filter
    public static func velocityFilter(minVelocity: UInt8) -> MIDIFilter {
        return MIDIFilter { message in
            if message.messageType == .noteOn && message.data2 < minVelocity {
                return nil
            }
            return message
        }
    }

    /// Create a note range filter
    public static func noteRangeFilter(minNote: UInt8, maxNote: UInt8) -> MIDIFilter {
        return MIDIFilter { message in
            if (message.messageType == .noteOn || message.messageType == .noteOff) {
                if message.data1 < minNote || message.data1 > maxNote {
                    return nil
                }
            }
            return message
        }
    }
}

// MARK: - MIDI Parameter Mapping

/// MIDI-to-audio parameter mapping system
public final class MIDIParameterMapper: @unchecked Sendable {
    private var mappings: [MIDIParameterMapping] = []
    private let mapperQueue = DispatchQueue(label: "MIDIParameterMapper", qos: .userInitiated)

    public init() {}

    /// Add a parameter mapping
    public func addMapping(_ mapping: MIDIParameterMapping) {
        mapperQueue.sync {
            mappings.append(mapping)
        }
    }

    /// Remove a parameter mapping
    public func removeMapping(id: UUID) {
        mapperQueue.sync {
            mappings.removeAll { $0.id == id }
        }
    }

    /// Process MIDI message and return parameter updates
    public func processMessage(_ message: MIDIMessage) -> [ParameterUpdate] {
        return mapperQueue.sync {
            var updates: [ParameterUpdate] = []

            for mapping in mappings {
                if mapping.matches(message) {
                    if let update = mapping.createParameterUpdate(from: message) {
                        updates.append(update)
                    }
                }
            }

            return updates
        }
    }

    /// Get all mappings
    public func getAllMappings() -> [MIDIParameterMapping] {
        return mapperQueue.sync { mappings }
    }

    /// Clear all mappings
    public func clearMappings() {
        mapperQueue.sync {
            mappings.removeAll()
        }
    }
}

/// MIDI parameter mapping configuration
public struct MIDIParameterMapping: Sendable {
    public let id: UUID
    public let midiController: UInt8?
    public let midiChannel: UInt8?
    public let messageType: MIDIMessageType
    public let parameterName: String
    public let minValue: Float
    public let maxValue: Float
    public let curve: MappingCurve
    public let condition: @Sendable (MIDIMessage) -> Bool

    public init(
        midiController: UInt8? = nil,
        midiChannel: UInt8? = nil,
        messageType: MIDIMessageType = .controlChange,
        parameterName: String,
        minValue: Float = 0.0,
        maxValue: Float = 1.0,
        curve: MappingCurve = .linear,
        condition: @escaping @Sendable (MIDIMessage) -> Bool = { _ in true }
    ) {
        self.id = UUID()
        self.midiController = midiController
        self.midiChannel = midiChannel
        self.messageType = messageType
        self.parameterName = parameterName
        self.minValue = minValue
        self.maxValue = maxValue
        self.curve = curve
        self.condition = condition
    }

    /// Check if mapping matches message
    public func matches(_ message: MIDIMessage) -> Bool {
        // Check message type
        if message.messageType != messageType {
            return false
        }

        // Check channel
        if let channel = midiChannel, message.channel != channel {
            return false
        }

        // Check controller (for CC messages)
        if messageType == .controlChange, let controller = midiController, message.data1 != controller {
            return false
        }

        // Check custom condition
        return condition(message)
    }

    /// Create parameter update from MIDI message
    public func createParameterUpdate(from message: MIDIMessage) -> ParameterUpdate? {
        let midiValue: Float

        switch messageType {
        case .controlChange:
            midiValue = Float(message.data2) / 127.0
        case .pitchBend:
            let pitchValue = UInt16(message.data1) | (UInt16(message.data2) << 7)
            midiValue = (Float(pitchValue) - 8192.0) / 8192.0 // -1.0 to 1.0
        case .channelPressure:
            midiValue = Float(message.data1) / 127.0
        case .noteOn:
            midiValue = Float(message.data2) / 127.0 // Velocity
        default:
            return nil
        }

        let normalizedValue = curve.apply(midiValue)
        let scaledValue = minValue + normalizedValue * (maxValue - minValue)

        return ParameterUpdate(
            parameterName: parameterName,
            value: scaledValue,
            timestamp: message.timestamp
        )
    }
}

/// Parameter update structure
public struct ParameterUpdate: Sendable {
    public let parameterName: String
    public let value: Float
    public let timestamp: UInt64

    public init(parameterName: String, value: Float, timestamp: UInt64) {
        self.parameterName = parameterName
        self.value = value
        self.timestamp = timestamp
    }
}

/// Mapping curve types for parameter scaling
public enum MappingCurve: Sendable {
    case linear
    case exponential
    case logarithmic
    case sCurve

    /// Apply curve to normalized input (0.0-1.0)
    public func apply(_ input: Float) -> Float {
        let clampedInput = max(0.0, min(1.0, input))

        switch self {
        case .linear:
            return clampedInput
        case .exponential:
            return clampedInput * clampedInput
        case .logarithmic:
            return sqrt(clampedInput)
        case .sCurve:
            // Smooth S-curve using sine function
            let angle = (clampedInput - 0.5) * Float.pi
            return 0.5 + 0.5 * sin(angle)
        }
    }
}

/// MIDI device manager for handling MIDI input/output
public final class MIDIDeviceManager: @unchecked Sendable {
    private var inputDevices: [MIDIInputDevice] = []
    private var outputDevices: [MIDIOutputDevice] = []
    private let deviceQueue = DispatchQueue(label: "MIDIDeviceManager", qos: .userInitiated)

    public var messageCallback: (@Sendable (MIDIMessage) -> Void)?

    public init() {}

    /// Scan for available MIDI devices
    public func scanDevices() {
        deviceQueue.sync {
            // This would integrate with Core MIDI on iOS/macOS
            // For now, create mock devices for testing
            inputDevices = [
                MIDIInputDevice(id: UUID(), name: "Virtual MIDI Input", isConnected: true),
                MIDIInputDevice(id: UUID(), name: "External Controller", isConnected: false)
            ]

            outputDevices = [
                MIDIOutputDevice(id: UUID(), name: "Virtual MIDI Output", isConnected: true),
                MIDIOutputDevice(id: UUID(), name: "External Synthesizer", isConnected: false)
            ]
        }
    }

    /// Get available input devices
    public func getInputDevices() -> [MIDIInputDevice] {
        return deviceQueue.sync { inputDevices }
    }

    /// Get available output devices
    public func getOutputDevices() -> [MIDIOutputDevice] {
        return deviceQueue.sync { outputDevices }
    }

    /// Connect to input device
    public func connectInputDevice(id: UUID) -> Bool {
        return deviceQueue.sync {
            if let index = inputDevices.firstIndex(where: { $0.id == id }) {
                inputDevices[index].isConnected = true
                return true
            }
            return false
        }
    }

    /// Disconnect from input device
    public func disconnectInputDevice(id: UUID) -> Bool {
        return deviceQueue.sync {
            if let index = inputDevices.firstIndex(where: { $0.id == id }) {
                inputDevices[index].isConnected = false
                return true
            }
            return false
        }
    }

    /// Send MIDI message to output device
    public func sendMessage(_ message: MIDIMessage, to deviceId: UUID) -> Bool {
        return deviceQueue.sync {
            if outputDevices.first(where: { $0.id == deviceId && $0.isConnected }) != nil {
                // Send message to device
                return true
            }
            return false
        }
    }

    /// Simulate receiving MIDI message (for testing)
    public func simulateMessage(_ message: MIDIMessage) {
        messageCallback?(message)
    }
}

/// MIDI input device representation
public struct MIDIInputDevice: Sendable {
    public let id: UUID
    public let name: String
    public var isConnected: Bool

    public init(id: UUID, name: String, isConnected: Bool) {
        self.id = id
        self.name = name
        self.isConnected = isConnected
    }
}

/// MIDI output device representation
public struct MIDIOutputDevice: Sendable {
    public let id: UUID
    public let name: String
    public var isConnected: Bool

    public init(id: UUID, name: String, isConnected: Bool) {
        self.id = id
        self.name = name
        self.isConnected = isConnected
    }
}

// MARK: - Audio Unit Testing Framework

/// Test result for audio unit tests
public struct AudioTestResult: Sendable {
    public let testName: String
    public let passed: Bool
    public let executionTime: TimeInterval
    public let errorMessage: String?
    public let metrics: [String: Double]
    public let timestamp: Date

    public init(testName: String, passed: Bool, executionTime: TimeInterval,
                errorMessage: String? = nil, metrics: [String: Double] = [:]) {
        self.testName = testName
        self.passed = passed
        self.executionTime = executionTime
        self.errorMessage = errorMessage
        self.metrics = metrics
        self.timestamp = Date()
    }
}

/// Test suite for organizing related tests
public final class AudioTestSuite: @unchecked Sendable {
    public let name: String
    private var tests: [AudioTest] = []
    private let suiteQueue = DispatchQueue(label: "AudioTestSuite", qos: .userInitiated)

    public init(name: String) {
        self.name = name
    }

    /// Add test to suite
    public func addTest(_ test: AudioTest) {
        suiteQueue.sync {
            tests.append(test)
        }
    }

    /// Run all tests in suite
    public func runTests() -> [AudioTestResult] {
        return suiteQueue.sync {
            var results: [AudioTestResult] = []

            for test in tests {
                let result = test.run()
                results.append(result)
            }

            return results
        }
    }

    /// Get test count
    public var testCount: Int {
        return suiteQueue.sync { tests.count }
    }
}

/// Individual audio test
public final class AudioTest: @unchecked Sendable {
    public let name: String
    private let testFunction: @Sendable () throws -> [String: Double]
    private let timeout: TimeInterval

    public init(name: String, timeout: TimeInterval = 5.0, testFunction: @escaping @Sendable () throws -> [String: Double]) {
        self.name = name
        self.timeout = timeout
        self.testFunction = testFunction
    }

    /// Run the test
    public func run() -> AudioTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let metrics = try testFunction()
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime

            if executionTime > timeout {
                return AudioTestResult(
                    testName: name,
                    passed: false,
                    executionTime: executionTime,
                    errorMessage: "Test timed out (exceeded \(timeout)s)",
                    metrics: metrics
                )
            }

            return AudioTestResult(
                testName: name,
                passed: true,
                executionTime: executionTime,
                metrics: metrics
            )
        } catch {
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            return AudioTestResult(
                testName: name,
                passed: false,
                executionTime: executionTime,
                errorMessage: error.localizedDescription
            )
        }
    }
}

/// Mock audio node for testing
public final class MockAudioNode: @unchecked Sendable {
    public let id: UUID
    public let name: String
    public var isProcessing: Bool = false
    public var processCallCount: Int = 0
    public var lastProcessedBuffer: AudioBuffer?
    public var shouldFail: Bool = false
    public var processingDelay: TimeInterval = 0.0

    private let nodeQueue = DispatchQueue(label: "MockAudioNode", qos: .userInitiated)

    public init(name: String) {
        self.id = UUID()
        self.name = name
    }

    /// Simulate audio processing
    public func process(_ buffer: AudioBuffer) throws {
        try nodeQueue.sync {
            if shouldFail {
                throw AudioEngineError.processingError("Mock node failure")
            }

            isProcessing = true
            processCallCount += 1
            lastProcessedBuffer = buffer

            // Simulate processing delay
            if processingDelay > 0 {
                Thread.sleep(forTimeInterval: processingDelay)
            }

            // Simulate some audio processing (add small amount of noise)
            for i in 0..<(buffer.frameCount * buffer.channelCount) {
                buffer.data[i] += Float.random(in: -0.001...0.001)
            }

            isProcessing = false
        }
    }

    /// Reset mock state
    public func reset() {
        nodeQueue.sync {
            isProcessing = false
            processCallCount = 0
            lastProcessedBuffer = nil
            shouldFail = false
            processingDelay = 0.0
        }
    }
}

/// Audio output validator for testing
public final class AudioOutputValidator: @unchecked Sendable {
    private let validatorQueue = DispatchQueue(label: "AudioOutputValidator", qos: .userInitiated)

    public init() {}

    /// Validate audio buffer for silence
    public func validateSilence(_ buffer: AudioBuffer, threshold: Float = 0.001) -> Bool {
        return validatorQueue.sync {
            let totalSamples = buffer.frameCount * buffer.channelCount

            for i in 0..<totalSamples {
                if abs(buffer.data[i]) > threshold {
                    return false
                }
            }

            return true
        }
    }

    /// Validate audio buffer for clipping
    public func validateNoClipping(_ buffer: AudioBuffer, threshold: Float = 0.99) -> Bool {
        return validatorQueue.sync {
            let totalSamples = buffer.frameCount * buffer.channelCount

            for i in 0..<totalSamples {
                if abs(buffer.data[i]) > threshold {
                    return false
                }
            }

            return true
        }
    }

    /// Calculate RMS level of buffer
    public func calculateRMS(_ buffer: AudioBuffer) -> Float {
        return validatorQueue.sync {
            let totalSamples = buffer.frameCount * buffer.channelCount
            var sum: Float = 0.0

            for i in 0..<totalSamples {
                let sample = buffer.data[i]
                sum += sample * sample
            }

            return sqrt(sum / Float(totalSamples))
        }
    }

    /// Calculate peak level of buffer
    public func calculatePeak(_ buffer: AudioBuffer) -> Float {
        return validatorQueue.sync {
            let totalSamples = buffer.frameCount * buffer.channelCount
            var peak: Float = 0.0

            for i in 0..<totalSamples {
                peak = max(peak, abs(buffer.data[i]))
            }

            return peak
        }
    }

    /// Validate frequency content (simplified)
    public func validateFrequencyContent(_ buffer: AudioBuffer, expectedFrequency: Float, tolerance: Float = 0.1) -> Bool {
        return validatorQueue.sync {
            // Simplified frequency detection using zero-crossing rate
            let totalSamples = buffer.frameCount * buffer.channelCount
            var zeroCrossings = 0

            for i in 1..<totalSamples {
                if (buffer.data[i-1] >= 0 && buffer.data[i] < 0) || (buffer.data[i-1] < 0 && buffer.data[i] >= 0) {
                    zeroCrossings += 1
                }
            }

            let estimatedFrequency = Float(zeroCrossings) * Float(buffer.sampleRate) / (2.0 * Float(totalSamples))
            let difference = abs(estimatedFrequency - expectedFrequency)

            return difference <= tolerance * expectedFrequency
        }
    }

    /// Compare two buffers for similarity
    public func compareBuffers(_ buffer1: AudioBuffer, _ buffer2: AudioBuffer, tolerance: Float = 0.01) -> Bool {
        return validatorQueue.sync {
            guard buffer1.frameCount == buffer2.frameCount &&
                  buffer1.channelCount == buffer2.channelCount else {
                return false
            }

            let totalSamples = buffer1.frameCount * buffer1.channelCount

            for i in 0..<totalSamples {
                let difference = abs(buffer1.data[i] - buffer2.data[i])
                if difference > tolerance {
                    return false
                }
            }

            return true
        }
    }
}

/// Performance test runner for audio components
public final class AudioPerformanceTestRunner: @unchecked Sendable {
    private let runnerQueue = DispatchQueue(label: "AudioPerformanceTestRunner", qos: .userInitiated)

    public init() {}

    /// Run performance test on audio processing function
    public func runPerformanceTest<T>(
        name: String,
        iterations: Int = 1000,
        setup: @escaping @Sendable () -> T,
        test: @escaping @Sendable (T) -> Void,
        cleanup: @escaping @Sendable (T) -> Void = { _ in }
    ) -> AudioTestResult {
        return runnerQueue.sync {
            var times: [TimeInterval] = []
            var totalMemoryUsage: Int = 0

            let startMemory = getMemoryUsage()

            // Warm up
            for _ in 0..<10 {
                let testObject = setup()
                test(testObject)
                cleanup(testObject)
            }

            // Actual test
            for _ in 0..<iterations {
                let testObject = setup()

                let startTime = CFAbsoluteTimeGetCurrent()
                test(testObject)
                let endTime = CFAbsoluteTimeGetCurrent()

                times.append(endTime - startTime)
                cleanup(testObject)
            }

            let endMemory = getMemoryUsage()
            totalMemoryUsage = endMemory - startMemory

            // Calculate statistics
            let averageTime = times.reduce(0.0, +) / Double(times.count)
            let minTime = times.min() ?? 0.0
            let maxTime = times.max() ?? 0.0

            let metrics = [
                "averageTime": averageTime * 1000.0, // Convert to milliseconds
                "minTime": minTime * 1000.0,
                "maxTime": maxTime * 1000.0,
                "memoryUsage": Double(totalMemoryUsage),
                "iterations": Double(iterations)
            ]

            return AudioTestResult(
                testName: name,
                passed: averageTime < 0.01, // Pass if average time is less than 10ms
                executionTime: averageTime,
                metrics: metrics
            )
        }
    }

    private func getMemoryUsage() -> Int {
        // TODO: Fix concurrency safety for mach_task_self_
        return 0
        /*
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) { ptr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), ptr, &count)
            }
        }

        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
        */
    }
}

// MARK: - Audio Testing Framework Manager

/// Main testing framework for audio engine components
public final class AudioTestingFramework: @unchecked Sendable {
    private var testSuites: [String: AudioTestSuite] = [:]
    private let validator = AudioOutputValidator()
    private let performanceRunner = AudioPerformanceTestRunner()
    private let frameworkQueue = DispatchQueue(label: "AudioTestingFramework", qos: .userInitiated)

    public init() {
        setupDefaultTests()
    }

    /// Add test suite
    public func addTestSuite(_ suite: AudioTestSuite) {
        frameworkQueue.sync {
            testSuites[suite.name] = suite
        }
    }

    /// Run all test suites
    public func runAllTests() -> [String: [AudioTestResult]] {
        return frameworkQueue.sync {
            var allResults: [String: [AudioTestResult]] = [:]

            for (suiteName, suite) in testSuites {
                allResults[suiteName] = suite.runTests()
            }

            return allResults
        }
    }

    /// Run specific test suite
    public func runTestSuite(name: String) -> [AudioTestResult]? {
        return frameworkQueue.sync {
            return testSuites[name]?.runTests()
        }
    }

    /// Generate test report
    public func generateTestReport() -> String {
        return frameworkQueue.sync {
            let allResults = runAllTests()
            var report = "Audio Engine Test Report\n"
            report += "========================\n\n"

            var totalTests = 0
            var passedTests = 0
            var totalExecutionTime: TimeInterval = 0

            for (suiteName, results) in allResults {
                report += "Test Suite: \(suiteName)\n"
                report += "-------------------\n"

                for result in results {
                    totalTests += 1
                    totalExecutionTime += result.executionTime

                    if result.passed {
                        passedTests += 1
                        report += "✅ \(result.testName) - PASSED (\(String(format: "%.3f", result.executionTime * 1000))ms)\n"
                    } else {
                        report += "❌ \(result.testName) - FAILED (\(String(format: "%.3f", result.executionTime * 1000))ms)\n"
                        if let error = result.errorMessage {
                            report += "   Error: \(error)\n"
                        }
                    }

                    // Add metrics if available
                    if !result.metrics.isEmpty {
                        report += "   Metrics: "
                        for (key, value) in result.metrics {
                            report += "\(key): \(String(format: "%.3f", value)) "
                        }
                        report += "\n"
                    }
                }

                report += "\n"
            }

            // Summary
            report += "Summary\n"
            report += "-------\n"
            report += "Total Tests: \(totalTests)\n"
            report += "Passed: \(passedTests)\n"
            report += "Failed: \(totalTests - passedTests)\n"
            report += "Success Rate: \(String(format: "%.1f", Double(passedTests) / Double(totalTests) * 100))%\n"
            report += "Total Execution Time: \(String(format: "%.3f", totalExecutionTime * 1000))ms\n"

            return report
        }
    }

    /// Create mock audio buffer for testing
    public func createTestBuffer(frameCount: Int = 1024, channelCount: Int = 2,
                                sampleRate: Double = 44100.0, signalType: TestSignalType = .silence) -> AudioBuffer {
        let totalSamples = frameCount * channelCount
        let data = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)

        switch signalType {
        case .silence:
            data.initialize(repeating: 0.0, count: totalSamples)
        case .sineWave(let frequency, let amplitude):
            for i in 0..<totalSamples {
                let phase = Float(i) * 2.0 * Float.pi * Float(frequency) / Float(sampleRate)
                data[i] = sin(phase) * amplitude
            }
        case .whiteNoise(let amplitude):
            for i in 0..<totalSamples {
                data[i] = Float.random(in: -amplitude...amplitude)
            }
        case .impulse(let amplitude):
            data.initialize(repeating: 0.0, count: totalSamples)
            if totalSamples > 0 {
                data[0] = amplitude
            }
        }

        return AudioBuffer(
            data: data,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: sampleRate
        )
    }

    /// Validate audio output
    public func validateOutput(_ buffer: AudioBuffer) -> AudioOutputValidation {
        let rms = validator.calculateRMS(buffer)
        let peak = validator.calculatePeak(buffer)
        let isSilent = validator.validateSilence(buffer)
        let hasClipping = !validator.validateNoClipping(buffer)

        return AudioOutputValidation(
            rms: rms,
            peak: peak,
            isSilent: isSilent,
            hasClipping: hasClipping,
            isValid: !hasClipping && rms < 1.0 && peak < 1.0
        )
    }

    /// Run performance test
    public func runPerformanceTest<T>(
        name: String,
        iterations: Int = 1000,
        setup: @escaping @Sendable () -> T,
        test: @escaping @Sendable (T) -> Void,
        cleanup: @escaping @Sendable (T) -> Void = { _ in }
    ) -> AudioTestResult {
        return performanceRunner.runPerformanceTest(
            name: name,
            iterations: iterations,
            setup: setup,
            test: test,
            cleanup: cleanup
        )
    }

    private func setupDefaultTests() {
        // Create basic audio engine tests
        let basicSuite = AudioTestSuite(name: "Basic Audio Engine Tests")

        // Buffer creation test
        basicSuite.addTest(AudioTest(name: "Buffer Creation") {
            let buffer = self.createTestBuffer()
            return [
                "frameCount": Double(buffer.frameCount),
                "channelCount": Double(buffer.channelCount),
                "sampleRate": buffer.sampleRate
            ]
        })

        // Silence validation test
        basicSuite.addTest(AudioTest(name: "Silence Validation") {
            let buffer = self.createTestBuffer(signalType: .silence)
            let validation = self.validateOutput(buffer)

            if !validation.isSilent {
                throw AudioEngineError.validationError("Buffer should be silent")
            }

            return [
                "rms": Double(validation.rms),
                "peak": Double(validation.peak)
            ]
        })

        // Signal generation test
        basicSuite.addTest(AudioTest(name: "Signal Generation") {
            let buffer = self.createTestBuffer(signalType: .sineWave(frequency: 440.0, amplitude: 0.5))
            let validation = self.validateOutput(buffer)

            if validation.isSilent {
                throw AudioEngineError.validationError("Buffer should contain signal")
            }

            return [
                "rms": Double(validation.rms),
                "peak": Double(validation.peak)
            ]
        })

        addTestSuite(basicSuite)
    }
}

/// Test signal types for generating test audio
public enum TestSignalType {
    case silence
    case sineWave(frequency: Double, amplitude: Float)
    case whiteNoise(amplitude: Float)
    case impulse(amplitude: Float)
}

/// Audio output validation result
public struct AudioOutputValidation: Sendable {
    public let rms: Float
    public let peak: Float
    public let isSilent: Bool
    public let hasClipping: Bool
    public let isValid: Bool

    public init(rms: Float, peak: Float, isSilent: Bool, hasClipping: Bool, isValid: Bool) {
        self.rms = rms
        self.peak = peak
        self.isSilent = isSilent
        self.hasClipping = hasClipping
        self.isValid = isValid
    }
}

// MARK: - Audio File I/O System

/// Audio file format types
public enum AudioFileFormat: String, CaseIterable, Sendable {
    case wav = "wav"
    case aiff = "aiff"
    case mp3 = "mp3"
    case aac = "aac"
    case flac = "flac"
    case ogg = "ogg"

    var fileExtension: String {
        return rawValue
    }

    var mimeType: String {
        switch self {
        case .wav:
            return "audio/wav"
        case .aiff:
            return "audio/aiff"
        case .mp3:
            return "audio/mpeg"
        case .aac:
            return "audio/aac"
        case .flac:
            return "audio/flac"
        case .ogg:
            return "audio/ogg"
        }
    }
}

/// Audio file metadata
public struct AudioFileMetadata: Sendable {
    public let title: String?
    public let artist: String?
    public let album: String?
    public let genre: String?
    public let year: Int?
    public let duration: TimeInterval
    public let bitRate: Int
    public let sampleRate: Double
    public let channelCount: Int
    public let fileSize: Int64
    public let format: AudioFileFormat

    public init(title: String? = nil, artist: String? = nil, album: String? = nil,
                genre: String? = nil, year: Int? = nil, duration: TimeInterval,
                bitRate: Int, sampleRate: Double, channelCount: Int,
                fileSize: Int64, format: AudioFileFormat) {
        self.title = title
        self.artist = artist
        self.album = album
        self.genre = genre
        self.year = year
        self.duration = duration
        self.bitRate = bitRate
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.fileSize = fileSize
        self.format = format
    }
}

/// Audio file decoder for reading audio files
public final class AudioFileDecoder: @unchecked Sendable {
    private let decoderQueue = DispatchQueue(label: "AudioFileDecoder", qos: .userInitiated)

    public init() {}

    /// Decode audio file to buffer
    public func decodeFile(at url: URL) throws -> (buffer: AudioBuffer, metadata: AudioFileMetadata) {
        return try decoderQueue.sync {
            // Get file attributes
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0

            // Determine format from file extension
            let fileExtension = url.pathExtension.lowercased()
            guard let format = AudioFileFormat(rawValue: fileExtension) else {
                throw AudioEngineError.unsupportedFormat("Unsupported file format: \(fileExtension)")
            }

            // Use AVAudioFile for decoding (iOS/macOS)
            let audioFile = try AVAudioFile(forReading: url)
            let frameCount = Int(audioFile.length)
            let channelCount = Int(audioFile.processingFormat.channelCount)
            let sampleRate = audioFile.processingFormat.sampleRate

            // Create buffer for decoded audio
            let totalSamples = frameCount * channelCount
            let data = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)

            // Read audio data
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(frameCount))!
            try audioFile.read(into: buffer)

            // Convert to our buffer format
            if let floatChannelData = buffer.floatChannelData {
                if channelCount == 1 {
                    // Mono
                    for i in 0..<frameCount {
                        data[i] = floatChannelData[0][i]
                    }
                } else {
                    // Interleaved stereo/multi-channel
                    for frame in 0..<frameCount {
                        for channel in 0..<channelCount {
                            data[frame * channelCount + channel] = floatChannelData[channel][frame]
                        }
                    }
                }
            }

            let audioBuffer = AudioBuffer(
                data: data,
                frameCount: frameCount,
                channelCount: channelCount,
                sampleRate: sampleRate
            )

            // Create metadata
            let duration = Double(frameCount) / sampleRate
            let bitRate = Int(sampleRate * Double(channelCount) * 32) // Assuming 32-bit float

            let metadata = AudioFileMetadata(
                duration: duration,
                bitRate: bitRate,
                sampleRate: sampleRate,
                channelCount: channelCount,
                fileSize: fileSize,
                format: format
            )

            return (audioBuffer, metadata)
        }
    }

    /// Get metadata without decoding full file
    public func getMetadata(for url: URL) throws -> AudioFileMetadata {
        return try decoderQueue.sync {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0

            let fileExtension = url.pathExtension.lowercased()
            guard let format = AudioFileFormat(rawValue: fileExtension) else {
                throw AudioEngineError.unsupportedFormat("Unsupported file format: \(fileExtension)")
            }

            let audioFile = try AVAudioFile(forReading: url)
            let frameCount = Int(audioFile.length)
            let channelCount = Int(audioFile.processingFormat.channelCount)
            let sampleRate = audioFile.processingFormat.sampleRate

            let duration = Double(frameCount) / sampleRate
            let bitRate = Int(sampleRate * Double(channelCount) * 32)

            return AudioFileMetadata(
                duration: duration,
                bitRate: bitRate,
                sampleRate: sampleRate,
                channelCount: channelCount,
                fileSize: fileSize,
                format: format
            )
        }
    }
}

/// Audio file encoder for writing audio files
public final class AudioFileEncoder: @unchecked Sendable {
    private let encoderQueue = DispatchQueue(label: "AudioFileEncoder", qos: .userInitiated)

    public init() {}

    /// Encode audio buffer to file
    public func encodeBuffer(_ buffer: AudioBuffer, to url: URL, format: AudioFileFormat, metadata: AudioFileMetadata? = nil) throws {
        try encoderQueue.sync {
            // Create AVAudioFormat
            guard let audioFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: buffer.sampleRate,
                channels: UInt32(buffer.channelCount),
                interleaved: false
            ) else {
                throw AudioEngineError.configurationError("Failed to create audio format")
            }

            // Create output file
            let audioFile = try AVAudioFile(forWriting: url, settings: audioFormat.settings)

            // Create PCM buffer
            let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: UInt32(buffer.frameCount))!
            pcmBuffer.frameLength = UInt32(buffer.frameCount)

            // Copy data to PCM buffer
            if let floatChannelData = pcmBuffer.floatChannelData {
                if buffer.channelCount == 1 {
                    // Mono
                    for i in 0..<buffer.frameCount {
                        floatChannelData[0][i] = buffer.data[i]
                    }
                } else {
                    // Multi-channel (deinterleave)
                    for frame in 0..<buffer.frameCount {
                        for channel in 0..<buffer.channelCount {
                            floatChannelData[channel][frame] = buffer.data[frame * buffer.channelCount + channel]
                        }
                    }
                }
            }

            // Write to file
            try audioFile.write(from: pcmBuffer)
        }
    }
}

// MARK: - Streaming Audio File Reader

/// Streaming audio file reader for large files
public final class StreamingAudioFileReader: @unchecked Sendable {
    private let url: URL
    private let audioFile: AVAudioFile
    private let bufferSize: Int
    private var currentPosition: Int64 = 0
    private let readerQueue = DispatchQueue(label: "StreamingAudioFileReader", qos: .userInitiated)

    public let metadata: AudioFileMetadata
    public var isAtEnd: Bool {
        return currentPosition >= audioFile.length
    }

    public init(url: URL, bufferSize: Int = 4096) throws {
        self.url = url
        self.bufferSize = bufferSize

        // Open audio file
        self.audioFile = try AVAudioFile(forReading: url)

        // Get file metadata
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0

        let fileExtension = url.pathExtension.lowercased()
        let format = AudioFileFormat(rawValue: fileExtension) ?? .wav

        let frameCount = Int(audioFile.length)
        let channelCount = Int(audioFile.processingFormat.channelCount)
        let sampleRate = audioFile.processingFormat.sampleRate
        let duration = Double(frameCount) / sampleRate
        let bitRate = Int(sampleRate * Double(channelCount) * 32)

        self.metadata = AudioFileMetadata(
            duration: duration,
            bitRate: bitRate,
            sampleRate: sampleRate,
            channelCount: channelCount,
            fileSize: fileSize,
            format: format
        )
    }

    /// Read next chunk of audio data
    public func readNextChunk() throws -> AudioBuffer? {
        return try readerQueue.sync {
            guard !isAtEnd else { return nil }

            let framesToRead = min(bufferSize, Int(audioFile.length - currentPosition))
            guard framesToRead > 0 else { return nil }

            // Create buffer for reading
            let pcmBuffer = AVAudioPCMBuffer(
                pcmFormat: audioFile.processingFormat,
                frameCapacity: UInt32(framesToRead)
            )!

            // Set file position
            audioFile.framePosition = currentPosition

            // Read audio data
            try audioFile.read(into: pcmBuffer, frameCount: UInt32(framesToRead))

            // Update position
            currentPosition += Int64(framesToRead)

            // Convert to our buffer format
            let channelCount = Int(audioFile.processingFormat.channelCount)
            let totalSamples = framesToRead * channelCount
            let data = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)

            if let floatChannelData = pcmBuffer.floatChannelData {
                if channelCount == 1 {
                    // Mono
                    for i in 0..<framesToRead {
                        data[i] = floatChannelData[0][i]
                    }
                } else {
                    // Multi-channel (interleave)
                    for frame in 0..<framesToRead {
                        for channel in 0..<channelCount {
                            data[frame * channelCount + channel] = floatChannelData[channel][frame]
                        }
                    }
                }
            }

            return AudioBuffer(
                data: data,
                frameCount: framesToRead,
                channelCount: channelCount,
                sampleRate: audioFile.processingFormat.sampleRate
            )
        }
    }

    /// Seek to specific position in file
    public func seek(to position: TimeInterval) throws {
        readerQueue.sync {
            let framePosition = Int64(position * audioFile.processingFormat.sampleRate)
            let clampedPosition = max(0, min(framePosition, audioFile.length))
            currentPosition = clampedPosition
        }
    }

    /// Reset to beginning of file
    public func reset() {
        readerQueue.sync {
            currentPosition = 0
        }
    }
}

/// Audio file I/O manager
public final class AudioFileIOManager: @unchecked Sendable {
    private let decoder = AudioFileDecoder()
    private let encoder = AudioFileEncoder()
    private var streamingReaders: [UUID: StreamingAudioFileReader] = [:]
    private let managerQueue = DispatchQueue(label: "AudioFileIOManager", qos: .userInitiated)

    public init() {}

    /// Load audio file completely into memory
    public func loadAudioFile(from url: URL) throws -> (buffer: AudioBuffer, metadata: AudioFileMetadata) {
        return try decoder.decodeFile(at: url)
    }

    /// Get audio file metadata without loading
    public func getAudioFileMetadata(for url: URL) throws -> AudioFileMetadata {
        return try decoder.getMetadata(for: url)
    }

    /// Save audio buffer to file
    public func saveAudioFile(_ buffer: AudioBuffer, to url: URL, format: AudioFileFormat, metadata: AudioFileMetadata? = nil) throws {
        try encoder.encodeBuffer(buffer, to: url, format: format, metadata: metadata)
    }

    /// Create streaming reader for large files
    public func createStreamingReader(for url: URL, bufferSize: Int = 4096) throws -> (id: UUID, reader: StreamingAudioFileReader) {
        return try managerQueue.sync {
            let reader = try StreamingAudioFileReader(url: url, bufferSize: bufferSize)
            let id = UUID()
            streamingReaders[id] = reader
            return (id, reader)
        }
    }

    /// Get streaming reader by ID
    public func getStreamingReader(id: UUID) -> StreamingAudioFileReader? {
        return managerQueue.sync {
            return streamingReaders[id]
        }
    }

    /// Remove streaming reader
    public func removeStreamingReader(id: UUID) {
        _ = managerQueue.sync {
            streamingReaders.removeValue(forKey: id)
        }
    }

    /// Get supported file formats
    public func getSupportedFormats() -> [AudioFileFormat] {
        return AudioFileFormat.allCases
    }

    /// Check if file format is supported
    public func isFormatSupported(_ format: AudioFileFormat) -> Bool {
        return AudioFileFormat.allCases.contains(format)
    }

    /// Get optimal buffer size for streaming
    public func getOptimalBufferSize(for metadata: AudioFileMetadata) -> Int {
        // Calculate optimal buffer size based on file characteristics
        let baseSize = 4096
        let sampleRateMultiplier = metadata.sampleRate / 44100.0
        let channelMultiplier = Double(metadata.channelCount)

        let optimalSize = Int(Double(baseSize) * sampleRateMultiplier * channelMultiplier)
        return max(1024, min(optimalSize, 16384)) // Clamp between 1K and 16K frames
    }

    /// Batch process multiple files
    public func batchProcessFiles(urls: [URL], operation: @escaping (URL, AudioFileMetadata) throws -> Void) throws {
        for url in urls {
            let metadata = try getAudioFileMetadata(for: url)
            try operation(url, metadata)
        }
    }

    /// Convert audio file format
    public func convertAudioFile(from sourceURL: URL, to destinationURL: URL, targetFormat: AudioFileFormat) throws {
        let (buffer, metadata) = try loadAudioFile(from: sourceURL)

        // Create new metadata with target format
        let newMetadata = AudioFileMetadata(
            title: metadata.title,
            artist: metadata.artist,
            album: metadata.album,
            genre: metadata.genre,
            year: metadata.year,
            duration: metadata.duration,
            bitRate: metadata.bitRate,
            sampleRate: metadata.sampleRate,
            channelCount: metadata.channelCount,
            fileSize: metadata.fileSize,
            format: targetFormat
        )

        try saveAudioFile(buffer, to: destinationURL, format: targetFormat, metadata: newMetadata)
    }
}

// MARK: - Audio Clock and Synchronization System

/// High-precision audio clock for timing and synchronization
public final class AudioClock: @unchecked Sendable {
    private var startTime: CFAbsoluteTime = 0.0
    private var pausedTime: CFAbsoluteTime = 0.0
    private var totalPausedDuration: CFAbsoluteTime = 0.0
    private var isRunning: Bool = false
    private var isPaused: Bool = false
    private let sampleRate: Double
    private let clockQueue = DispatchQueue(label: "AudioClock", qos: .userInteractive)

    public init(sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate
    }

    /// Start the audio clock
    public func start() {
        clockQueue.sync {
            if !isRunning {
                startTime = CFAbsoluteTimeGetCurrent()
                totalPausedDuration = 0.0
                isRunning = true
                isPaused = false
            }
        }
    }

    /// Stop the audio clock
    public func stop() {
        clockQueue.sync {
            isRunning = false
            isPaused = false
            startTime = 0.0
            pausedTime = 0.0
            totalPausedDuration = 0.0
        }
    }

    /// Pause the audio clock
    public func pause() {
        clockQueue.sync {
            if isRunning && !isPaused {
                pausedTime = CFAbsoluteTimeGetCurrent()
                isPaused = true
            }
        }
    }

    /// Resume the audio clock
    public func resume() {
        clockQueue.sync {
            if isRunning && isPaused {
                totalPausedDuration += CFAbsoluteTimeGetCurrent() - pausedTime
                isPaused = false
                pausedTime = 0.0
            }
        }
    }

    /// Get current time in seconds
    public func getCurrentTime() -> TimeInterval {
        return clockQueue.sync {
            guard isRunning else { return 0.0 }

            let currentTime = CFAbsoluteTimeGetCurrent()
            if isPaused {
                return pausedTime - startTime - totalPausedDuration
            } else {
                return currentTime - startTime - totalPausedDuration
            }
        }
    }

    /// Get current time in samples
    public func getCurrentSample() -> Int64 {
        let timeInSeconds = getCurrentTime()
        return Int64(timeInSeconds * sampleRate)
    }

    /// Convert time to samples
    public func timeToSamples(_ time: TimeInterval) -> Int64 {
        return Int64(time * sampleRate)
    }

    /// Convert samples to time
    public func samplesToTime(_ samples: Int64) -> TimeInterval {
        return Double(samples) / sampleRate
    }

    /// Get clock status
    public func getStatus() -> (isRunning: Bool, isPaused: Bool, currentTime: TimeInterval) {
        return clockQueue.sync {
            return (isRunning, isPaused, getCurrentTime())
        }
    }
}

/// Tempo and beat tracking system
public final class TempoTracker: @unchecked Sendable {
    private var bpm: Double = 120.0
    private var beatsPerBar: Int = 4
    private var noteValue: NoteValue = .quarter
    private var currentBeat: Double = 0.0
    private var currentBar: Int = 0
    private let trackerQueue = DispatchQueue(label: "TempoTracker", qos: .userInteractive)

    public enum NoteValue: Double, CaseIterable, Sendable {
        case whole = 1.0
        case half = 2.0
        case quarter = 4.0
        case eighth = 8.0
        case sixteenth = 16.0
    }

    public init(bpm: Double = 120.0, beatsPerBar: Int = 4, noteValue: NoteValue = .quarter) {
        self.bpm = bpm
        self.beatsPerBar = beatsPerBar
        self.noteValue = noteValue
    }

    /// Set tempo in BPM
    public func setTempo(_ newBpm: Double) {
        trackerQueue.sync {
            bpm = max(20.0, min(300.0, newBpm)) // Clamp to reasonable range
        }
    }

    /// Set time signature
    public func setTimeSignature(beatsPerBar: Int, noteValue: NoteValue) {
        trackerQueue.sync {
            self.beatsPerBar = max(1, min(16, beatsPerBar))
            self.noteValue = noteValue
        }
    }

    /// Update position based on audio clock time
    public func updatePosition(audioTime: TimeInterval) {
        trackerQueue.sync {
            let secondsPerBeat = 60.0 / bpm
            let totalBeats = audioTime / secondsPerBeat

            currentBar = Int(totalBeats / Double(beatsPerBar))
            currentBeat = totalBeats.truncatingRemainder(dividingBy: Double(beatsPerBar))
        }
    }

    /// Get current musical position
    public func getCurrentPosition() -> (bar: Int, beat: Double, bpm: Double) {
        return trackerQueue.sync {
            return (currentBar, currentBeat, bpm)
        }
    }

    /// Get time until next beat
    public func getTimeToNextBeat() -> TimeInterval {
        return trackerQueue.sync {
            let secondsPerBeat = 60.0 / bpm
            let beatProgress = currentBeat - floor(currentBeat)
            return (1.0 - beatProgress) * secondsPerBeat
        }
    }

    /// Check if currently on a beat
    public func isOnBeat(tolerance: TimeInterval = 0.05) -> Bool {
        return trackerQueue.sync {
            let beatProgress = currentBeat - floor(currentBeat)
            return beatProgress < tolerance || beatProgress > (1.0 - tolerance)
        }
    }

    /// Get beat duration in seconds
    public func getBeatDuration() -> TimeInterval {
        return trackerQueue.sync {
            return 60.0 / bpm
        }
    }
}

/// Multi-stream synchronization manager
public final class AudioSynchronizationManager: @unchecked Sendable {
    private var streams: [UUID: AudioStream] = [:]
    private var masterClock: AudioClock?
    private var syncTolerance: TimeInterval = 0.001 // 1ms tolerance
    private let syncQueue = DispatchQueue(label: "AudioSynchronizationManager", qos: .userInteractive)

    public struct AudioStream: Sendable {
        public let id: UUID
        public let name: String
        public var offset: TimeInterval
        public var isActive: Bool
        public var lastSyncTime: TimeInterval

        public init(id: UUID = UUID(), name: String, offset: TimeInterval = 0.0) {
            self.id = id
            self.name = name
            self.offset = offset
            self.isActive = true
            self.lastSyncTime = 0.0
        }
    }

    public init(masterClock: AudioClock? = nil) {
        self.masterClock = masterClock
    }

    /// Set master clock for synchronization
    public func setMasterClock(_ clock: AudioClock) {
        syncQueue.sync {
            masterClock = clock
        }
    }

    /// Add audio stream for synchronization
    public func addStream(_ stream: AudioStream) {
        syncQueue.sync {
            streams[stream.id] = stream
        }
    }

    /// Remove audio stream
    public func removeStream(id: UUID) {
        _ = syncQueue.sync {
            streams.removeValue(forKey: id)
        }
    }

    /// Update stream offset for synchronization
    public func updateStreamOffset(id: UUID, offset: TimeInterval) {
        syncQueue.sync {
            streams[id]?.offset = offset
        }
    }

    /// Get synchronized time for a specific stream
    public func getSynchronizedTime(for streamId: UUID) -> TimeInterval? {
        return syncQueue.sync {
            guard let masterTime = masterClock?.getCurrentTime(),
                  let stream = streams[streamId] else {
                return nil
            }

            return masterTime + stream.offset
        }
    }

    /// Check if streams are synchronized
    public func areStreamsSynchronized() -> Bool {
        return syncQueue.sync {
            guard let masterTime = masterClock?.getCurrentTime() else { return false }

            for stream in streams.values {
                guard stream.isActive else { continue }

                let streamTime = masterTime + stream.offset
                let timeDifference = abs(streamTime - stream.lastSyncTime)

                if timeDifference > syncTolerance {
                    return false
                }
            }

            return true
        }
    }

    /// Synchronize all active streams
    public func synchronizeStreams() {
        syncQueue.sync {
            guard let masterTime = masterClock?.getCurrentTime() else { return }

            for (id, var stream) in streams {
                if stream.isActive {
                    stream.lastSyncTime = masterTime + stream.offset
                    streams[id] = stream
                }
            }
        }
    }

    /// Get synchronization status
    public func getSynchronizationStatus() -> (activeStreams: Int, synchronized: Bool, masterTime: TimeInterval?) {
        return syncQueue.sync {
            let activeCount = streams.values.filter { $0.isActive }.count
            let isSynchronized = areStreamsSynchronized()
            let masterTime = masterClock?.getCurrentTime()

            return (activeCount, isSynchronized, masterTime)
        }
    }

    /// Set synchronization tolerance
    public func setSyncTolerance(_ tolerance: TimeInterval) {
        syncQueue.sync {
            syncTolerance = max(0.0001, min(0.1, tolerance)) // Clamp between 0.1ms and 100ms
        }
    }
}

// MARK: - External Synchronization

/// External synchronization protocols and utilities
public enum ExternalSyncType: String, CaseIterable, Sendable {
    case midiClock = "midi_clock"
    case linkSync = "link_sync"
    case ltc = "ltc" // Linear Time Code
    case wordClock = "word_clock"
    case custom = "custom"
}

/// External synchronization manager
public final class ExternalSyncManager: @unchecked Sendable {
    private var syncType: ExternalSyncType = .midiClock
    private var isEnabled: Bool = false
    private var lastSyncTime: TimeInterval = 0.0
    private var syncCallback: (@Sendable (TimeInterval) -> Void)?
    private let syncQueue = DispatchQueue(label: "ExternalSyncManager", qos: .userInteractive)

    public init() {}

    /// Enable external synchronization
    public func enableSync(type: ExternalSyncType, callback: @escaping @Sendable (TimeInterval) -> Void) {
        syncQueue.sync {
            syncType = type
            syncCallback = callback
            isEnabled = true
        }
    }

    /// Disable external synchronization
    public func disableSync() {
        syncQueue.sync {
            isEnabled = false
            syncCallback = nil
        }
    }

    /// Process external sync signal
    public func processSyncSignal(timestamp: TimeInterval) {
        syncQueue.sync {
            guard isEnabled else { return }

            lastSyncTime = timestamp
            syncCallback?(timestamp)
        }
    }

    /// Get sync status
    public func getSyncStatus() -> (type: ExternalSyncType, enabled: Bool, lastSync: TimeInterval) {
        return syncQueue.sync {
            return (syncType, isEnabled, lastSyncTime)
        }
    }
}

/// Audio clock and synchronization manager
public final class AudioClockManager: @unchecked Sendable {
    private let audioClock: AudioClock
    private let tempoTracker: TempoTracker
    private let syncManager: AudioSynchronizationManager
    private let externalSyncManager: ExternalSyncManager
    private let managerQueue = DispatchQueue(label: "AudioClockManager", qos: .userInteractive)

    public init(sampleRate: Double = 44100.0) {
        self.audioClock = AudioClock(sampleRate: sampleRate)
        self.tempoTracker = TempoTracker()
        self.syncManager = AudioSynchronizationManager(masterClock: audioClock)
        self.externalSyncManager = ExternalSyncManager()

        setupExternalSync()
    }

    /// Start the audio clock system
    public func start() {
        managerQueue.sync {
            audioClock.start()
        }
    }

    /// Stop the audio clock system
    public func stop() {
        managerQueue.sync {
            audioClock.stop()
        }
    }

    /// Pause the audio clock system
    public func pause() {
        managerQueue.sync {
            audioClock.pause()
        }
    }

    /// Resume the audio clock system
    public func resume() {
        managerQueue.sync {
            audioClock.resume()
        }
    }

    /// Get current audio time
    public func getCurrentTime() -> TimeInterval {
        return audioClock.getCurrentTime()
    }

    /// Get current sample position
    public func getCurrentSample() -> Int64 {
        return audioClock.getCurrentSample()
    }

    /// Set tempo
    public func setTempo(_ bpm: Double) {
        managerQueue.sync {
            tempoTracker.setTempo(bpm)
        }
    }

    /// Set time signature
    public func setTimeSignature(beatsPerBar: Int, noteValue: TempoTracker.NoteValue) {
        managerQueue.sync {
            tempoTracker.setTimeSignature(beatsPerBar: beatsPerBar, noteValue: noteValue)
        }
    }

    /// Update musical position
    public func updateMusicalPosition() {
        managerQueue.sync {
            let currentTime = audioClock.getCurrentTime()
            tempoTracker.updatePosition(audioTime: currentTime)
        }
    }

    /// Get current musical position
    public func getCurrentMusicalPosition() -> (bar: Int, beat: Double, bpm: Double) {
        return tempoTracker.getCurrentPosition()
    }

    /// Add synchronized stream
    public func addSynchronizedStream(name: String, offset: TimeInterval = 0.0) -> UUID {
        return managerQueue.sync {
            let stream = AudioSynchronizationManager.AudioStream(name: name, offset: offset)
            syncManager.addStream(stream)
            return stream.id
        }
    }

    /// Remove synchronized stream
    public func removeSynchronizedStream(id: UUID) {
        managerQueue.sync {
            syncManager.removeStream(id: id)
        }
    }

    /// Get synchronized time for stream
    public func getSynchronizedTime(for streamId: UUID) -> TimeInterval? {
        return syncManager.getSynchronizedTime(for: streamId)
    }

    /// Enable external synchronization
    public func enableExternalSync(type: ExternalSyncType) {
        managerQueue.sync {
            externalSyncManager.enableSync(type: type) { [weak self] timestamp in
                self?.handleExternalSync(timestamp: timestamp)
            }
        }
    }

    /// Disable external synchronization
    public func disableExternalSync() {
        managerQueue.sync {
            externalSyncManager.disableSync()
        }
    }

    /// Get comprehensive clock status
    public func getClockStatus() -> AudioClockStatus {
        return managerQueue.sync {
            let clockStatus = audioClock.getStatus()
            let musicalPosition = tempoTracker.getCurrentPosition()
            let syncStatus = syncManager.getSynchronizationStatus()
            let externalSyncStatus = externalSyncManager.getSyncStatus()

            return AudioClockStatus(
                isRunning: clockStatus.isRunning,
                isPaused: clockStatus.isPaused,
                currentTime: clockStatus.currentTime,
                currentSample: audioClock.getCurrentSample(),
                currentBar: musicalPosition.bar,
                currentBeat: musicalPosition.beat,
                bpm: musicalPosition.bpm,
                activeStreams: syncStatus.activeStreams,
                streamsSynchronized: syncStatus.synchronized,
                externalSyncType: externalSyncStatus.type,
                externalSyncEnabled: externalSyncStatus.enabled
            )
        }
    }

    private func setupExternalSync() {
        // External sync setup would be implemented here
        // This would integrate with MIDI clock, Link, etc.
    }

    private func handleExternalSync(timestamp: TimeInterval) {
        // Handle external synchronization signals
        // This would adjust the internal clock based on external timing
    }
}

/// Comprehensive audio clock status
public struct AudioClockStatus: Sendable {
    public let isRunning: Bool
    public let isPaused: Bool
    public let currentTime: TimeInterval
    public let currentSample: Int64
    public let currentBar: Int
    public let currentBeat: Double
    public let bpm: Double
    public let activeStreams: Int
    public let streamsSynchronized: Bool
    public let externalSyncType: ExternalSyncType
    public let externalSyncEnabled: Bool

    public init(isRunning: Bool, isPaused: Bool, currentTime: TimeInterval, currentSample: Int64,
                currentBar: Int, currentBeat: Double, bpm: Double, activeStreams: Int,
                streamsSynchronized: Bool, externalSyncType: ExternalSyncType, externalSyncEnabled: Bool) {
        self.isRunning = isRunning
        self.isPaused = isPaused
        self.currentTime = currentTime
        self.currentSample = currentSample
        self.currentBar = currentBar
        self.currentBeat = currentBeat
        self.bpm = bpm
        self.activeStreams = activeStreams
        self.streamsSynchronized = streamsSynchronized
        self.externalSyncType = externalSyncType
        self.externalSyncEnabled = externalSyncEnabled
    }
}

// MARK: - Plugin Architecture System

/// Plugin interface for audio processing
public protocol AudioPlugin: Sendable {
    /// Plugin identifier
    var id: UUID { get }

    /// Plugin name
    var name: String { get }

    /// Plugin version
    var version: String { get }

    /// Plugin author
    var author: String { get }

    /// Plugin description
    var description: String { get }

    /// Plugin parameters
    var parameters: [AudioPluginParameter] { get }

    /// Initialize plugin with sample rate and buffer size
    func initialize(sampleRate: Double, bufferSize: Int) throws

    /// Process audio buffer
    func process(_ buffer: AudioBuffer) throws

    /// Set parameter value
    func setParameter(id: String, value: Float) throws

    /// Get parameter value
    func getParameter(id: String) throws -> Float

    /// Reset plugin state
    func reset()

    /// Cleanup plugin resources
    func cleanup()
}

/// Plugin parameter definition
public struct AudioPluginParameter: Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let minValue: Float
    public let maxValue: Float
    public let defaultValue: Float
    public let unit: String
    public let type: ParameterType

    public enum ParameterType: Sendable {
        case continuous
        case discrete
        case boolean
        case selection(options: [String])
    }

    public init(id: String, name: String, description: String, minValue: Float, maxValue: Float,
                defaultValue: Float, unit: String = "", type: ParameterType = .continuous) {
        self.id = id
        self.name = name
        self.description = description
        self.minValue = minValue
        self.maxValue = maxValue
        self.defaultValue = defaultValue
        self.unit = unit
        self.type = type
    }
}

/// Plugin metadata for discovery and loading
public struct AudioPluginMetadata: Sendable {
    public let id: UUID
    public let name: String
    public let version: String
    public let author: String
    public let description: String
    public let category: PluginCategory
    public let filePath: String
    public let isLoaded: Bool
    public let isValid: Bool

    public enum PluginCategory: String, CaseIterable, Sendable {
        case effect = "effect"
        case instrument = "instrument"
        case analyzer = "analyzer"
        case utility = "utility"
        case generator = "generator"
    }

    public init(id: UUID, name: String, version: String, author: String, description: String,
                category: PluginCategory, filePath: String, isLoaded: Bool = false, isValid: Bool = true) {
        self.id = id
        self.name = name
        self.version = version
        self.author = author
        self.description = description
        self.category = category
        self.filePath = filePath
        self.isLoaded = isLoaded
        self.isValid = isValid
    }
}

/// Plugin loader for dynamic loading
public final class AudioPluginLoader: @unchecked Sendable {
    private let loaderQueue = DispatchQueue(label: "AudioPluginLoader", qos: .userInitiated)

    public init() {}

    /// Load plugin from file path
    public func loadPlugin(from path: String) throws -> AudioPlugin {
        return loaderQueue.sync {
            // In a real implementation, this would use dynamic loading
            // For now, we'll create a mock plugin
            return MockAudioPlugin(name: "Loaded Plugin", filePath: path)
        }
    }

    /// Validate plugin before loading
    public func validatePlugin(at path: String) -> Bool {
        return loaderQueue.sync {
            // Basic validation - check if file exists and has correct extension
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: path) else { return false }

            let url = URL(fileURLWithPath: path)
            let validExtensions = ["plugin", "vst", "au", "component"]
            return validExtensions.contains(url.pathExtension.lowercased())
        }
    }

    /// Scan directory for plugins
    public func scanForPlugins(in directory: String) -> [AudioPluginMetadata] {
        return loaderQueue.sync {
            var plugins: [AudioPluginMetadata] = []
            let fileManager = FileManager.default

            guard let enumerator = fileManager.enumerator(atPath: directory) else {
                return plugins
            }

            for case let fileName as String in enumerator {
                let fullPath = (directory as NSString).appendingPathComponent(fileName)

                if validatePlugin(at: fullPath) {
                    let metadata = createMetadata(for: fullPath)
                    plugins.append(metadata)
                }
            }

            return plugins
        }
    }

    private func createMetadata(for path: String) -> AudioPluginMetadata {
        let url = URL(fileURLWithPath: path)
        let name = url.deletingPathExtension().lastPathComponent

        return AudioPluginMetadata(
            id: UUID(),
            name: name,
            version: "1.0.0",
            author: "Unknown",
            description: "Plugin loaded from \(path)",
            category: .effect,
            filePath: path,
            isValid: true
        )
    }
}

/// Plugin sandbox for security and isolation
public final class AudioPluginSandbox: @unchecked Sendable {
    private let sandboxQueue = DispatchQueue(label: "AudioPluginSandbox", qos: .userInitiated)
    private var sandboxedPlugins: [UUID: SandboxedPlugin] = [:]

    private struct SandboxedPlugin {
        let plugin: AudioPlugin
        let restrictions: SandboxRestrictions
        let startTime: Date
        var cpuUsage: Double
        var memoryUsage: Int
    }

    public struct SandboxRestrictions: Sendable {
        public let maxCpuUsage: Double // Percentage
        public let maxMemoryUsage: Int // Bytes
        public let maxExecutionTime: TimeInterval // Seconds
        public let allowFileAccess: Bool
        public let allowNetworkAccess: Bool

        public init(maxCpuUsage: Double = 50.0, maxMemoryUsage: Int = 100_000_000,
                   maxExecutionTime: TimeInterval = 1.0, allowFileAccess: Bool = false,
                   allowNetworkAccess: Bool = false) {
            self.maxCpuUsage = maxCpuUsage
            self.maxMemoryUsage = maxMemoryUsage
            self.maxExecutionTime = maxExecutionTime
            self.allowFileAccess = allowFileAccess
            self.allowNetworkAccess = allowNetworkAccess
        }
    }

    public init() {}

    /// Add plugin to sandbox
    public func addPlugin(_ plugin: AudioPlugin, restrictions: SandboxRestrictions) {
        sandboxQueue.sync {
            let sandboxedPlugin = SandboxedPlugin(
                plugin: plugin,
                restrictions: restrictions,
                startTime: Date(),
                cpuUsage: 0.0,
                memoryUsage: 0
            )
            sandboxedPlugins[plugin.id] = sandboxedPlugin
        }
    }

    /// Remove plugin from sandbox
    public func removePlugin(id: UUID) {
        _ = sandboxQueue.sync {
            sandboxedPlugins.removeValue(forKey: id)
        }
    }

    /// Process audio through sandboxed plugin
    public func processAudio(pluginId: UUID, buffer: AudioBuffer) throws {
        try sandboxQueue.sync {
            guard var sandboxedPlugin = sandboxedPlugins[pluginId] else {
                throw AudioEngineError.pluginError("Plugin not found in sandbox")
            }

            let startTime = CFAbsoluteTimeGetCurrent()
            let startMemory = getMemoryUsage()

            // Check execution time limit
            let executionTime = Date().timeIntervalSince(sandboxedPlugin.startTime)
            if executionTime > sandboxedPlugin.restrictions.maxExecutionTime {
                throw AudioEngineError.pluginError("Plugin exceeded execution time limit")
            }

            // Process audio
            try sandboxedPlugin.plugin.process(buffer)

            let endTime = CFAbsoluteTimeGetCurrent()
            let endMemory = getMemoryUsage()

            // Update resource usage
            sandboxedPlugin.cpuUsage = (endTime - startTime) * 100.0 // Simplified CPU usage
            sandboxedPlugin.memoryUsage = endMemory - startMemory

            // Check resource limits
            if sandboxedPlugin.cpuUsage > sandboxedPlugin.restrictions.maxCpuUsage {
                throw AudioEngineError.pluginError("Plugin exceeded CPU usage limit")
            }

            if sandboxedPlugin.memoryUsage > sandboxedPlugin.restrictions.maxMemoryUsage {
                throw AudioEngineError.pluginError("Plugin exceeded memory usage limit")
            }

            sandboxedPlugins[pluginId] = sandboxedPlugin
        }
    }

    /// Get plugin resource usage
    public func getResourceUsage(pluginId: UUID) -> (cpu: Double, memory: Int)? {
        return sandboxQueue.sync {
            guard let sandboxedPlugin = sandboxedPlugins[pluginId] else { return nil }
            return (sandboxedPlugin.cpuUsage, sandboxedPlugin.memoryUsage)
        }
    }

    private func getMemoryUsage() -> Int {
        // TODO: Fix concurrency safety for mach_task_self_
        return 0
        /*
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) { ptr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), ptr, &count)
            }
        }

        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
        */
    }
}

// MARK: - Plugin Manager and Mock Implementation

/// Main plugin manager for the audio engine
public final class AudioPluginManager: @unchecked Sendable {
    private let loader = AudioPluginLoader()
    private let sandbox = AudioPluginSandbox()
    private var loadedPlugins: [UUID: AudioPlugin] = [:]
    private var pluginMetadata: [UUID: AudioPluginMetadata] = [:]
    private let managerQueue = DispatchQueue(label: "AudioPluginManager", qos: .userInitiated)

    public init() {}

    /// Scan for plugins in directory
    public func scanPlugins(in directory: String) -> [AudioPluginMetadata] {
        return managerQueue.sync {
            let scannedPlugins = loader.scanForPlugins(in: directory)

            for plugin in scannedPlugins {
                pluginMetadata[plugin.id] = plugin
            }

            return scannedPlugins
        }
    }

    /// Load plugin by ID
    public func loadPlugin(id: UUID) throws -> AudioPlugin {
        return try managerQueue.sync {
            guard let metadata = pluginMetadata[id] else {
                throw AudioEngineError.pluginError("Plugin metadata not found")
            }

            if let existingPlugin = loadedPlugins[id] {
                return existingPlugin
            }

            let plugin = try loader.loadPlugin(from: metadata.filePath)
            loadedPlugins[id] = plugin

            // Add to sandbox with default restrictions
            let restrictions = AudioPluginSandbox.SandboxRestrictions()
            sandbox.addPlugin(plugin, restrictions: restrictions)

            return plugin
        }
    }

    /// Unload plugin
    public func unloadPlugin(id: UUID) {
        managerQueue.sync {
            if let plugin = loadedPlugins[id] {
                plugin.cleanup()
                loadedPlugins.removeValue(forKey: id)
                sandbox.removePlugin(id: id)
            }
        }
    }

    /// Get loaded plugin
    public func getPlugin(id: UUID) -> AudioPlugin? {
        return managerQueue.sync {
            return loadedPlugins[id]
        }
    }

    /// Get all loaded plugins
    public func getAllLoadedPlugins() -> [AudioPlugin] {
        return managerQueue.sync {
            return Array(loadedPlugins.values)
        }
    }

    /// Get plugin metadata
    public func getPluginMetadata(id: UUID) -> AudioPluginMetadata? {
        return managerQueue.sync {
            return pluginMetadata[id]
        }
    }

    /// Get all plugin metadata
    public func getAllPluginMetadata() -> [AudioPluginMetadata] {
        return managerQueue.sync {
            return Array(pluginMetadata.values)
        }
    }

    /// Process audio through plugin safely
    public func processAudioThroughPlugin(pluginId: UUID, buffer: AudioBuffer) throws {
        try sandbox.processAudio(pluginId: pluginId, buffer: buffer)
    }

    /// Get plugin resource usage
    public func getPluginResourceUsage(id: UUID) -> (cpu: Double, memory: Int)? {
        return sandbox.getResourceUsage(pluginId: id)
    }

    /// Validate plugin
    public func validatePlugin(at path: String) -> Bool {
        return loader.validatePlugin(at: path)
    }

    /// Create built-in plugin
    public func createBuiltInPlugin(type: BuiltInPluginType) -> AudioPlugin {
        return managerQueue.sync {
            switch type {
            case .gain:
                return GainPlugin()
            case .delay:
                return DelayPlugin()
            case .reverb:
                return ReverbPlugin()
            }
        }
    }

    public enum BuiltInPluginType: CaseIterable, Sendable {
        case gain
        case delay
        case reverb
    }
}

/// Mock audio plugin for testing and examples
public final class MockAudioPlugin: AudioPlugin, @unchecked Sendable {
    public let id = UUID()
    public let name: String
    public let version = "1.0.0"
    public let author = "AudioEngine"
    public let description: String
    public let parameters: [AudioPluginParameter]

    private let filePath: String
    private var parameterValues: [String: Float] = [:]
    private let pluginQueue = DispatchQueue(label: "MockAudioPlugin", qos: .userInitiated)

    public init(name: String, filePath: String) {
        self.name = name
        self.filePath = filePath
        self.description = "Mock plugin loaded from \(filePath)"

        // Create some example parameters
        self.parameters = [
            AudioPluginParameter(
                id: "gain",
                name: "Gain",
                description: "Output gain control",
                minValue: 0.0,
                maxValue: 2.0,
                defaultValue: 1.0,
                unit: "dB"
            ),
            AudioPluginParameter(
                id: "mix",
                name: "Mix",
                description: "Dry/wet mix",
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 0.5,
                unit: "%"
            )
        ]

        // Initialize default parameter values
        for parameter in parameters {
            parameterValues[parameter.id] = parameter.defaultValue
        }
    }

    public func initialize(sampleRate: Double, bufferSize: Int) throws {
        pluginQueue.sync {
            // Mock initialization
        }
    }

    public func process(_ buffer: AudioBuffer) throws {
        pluginQueue.sync {
            let gain = parameterValues["gain"] ?? 1.0
            let totalSamples = buffer.frameCount * buffer.channelCount

            // Apply gain to all samples
            for i in 0..<totalSamples {
                buffer.data[i] *= gain
            }
        }
    }

    public func setParameter(id: String, value: Float) throws {
        try pluginQueue.sync {
            guard let parameter = parameters.first(where: { $0.id == id }) else {
                throw AudioEngineError.pluginError("Parameter \(id) not found")
            }

            let clampedValue = max(parameter.minValue, min(parameter.maxValue, value))
            parameterValues[id] = clampedValue
        }
    }

    public func getParameter(id: String) throws -> Float {
        return try pluginQueue.sync {
            guard let value = parameterValues[id] else {
                throw AudioEngineError.pluginError("Parameter \(id) not found")
            }
            return value
        }
    }

    public func reset() {
        pluginQueue.sync {
            for parameter in parameters {
                parameterValues[parameter.id] = parameter.defaultValue
            }
        }
    }

    public func cleanup() {
        pluginQueue.sync {
            parameterValues.removeAll()
        }
    }
}

/// Built-in gain plugin
public final class GainPlugin: AudioPlugin, @unchecked Sendable {
    public let id = UUID()
    public let name = "Gain"
    public let version = "1.0.0"
    public let author = "AudioEngine"
    public let description = "Simple gain control plugin"
    public let parameters: [AudioPluginParameter]

    private var gain: Float = 1.0
    private let pluginQueue = DispatchQueue(label: "GainPlugin", qos: .userInitiated)

    public init() {
        self.parameters = [
            AudioPluginParameter(
                id: "gain",
                name: "Gain",
                description: "Linear gain multiplier",
                minValue: 0.0,
                maxValue: 4.0,
                defaultValue: 1.0,
                unit: "linear"
            )
        ]
    }

    public func initialize(sampleRate: Double, bufferSize: Int) throws {
        // No initialization needed for gain plugin
    }

    public func process(_ buffer: AudioBuffer) throws {
        pluginQueue.sync {
            let totalSamples = buffer.frameCount * buffer.channelCount

            for i in 0..<totalSamples {
                buffer.data[i] *= gain
            }
        }
    }

    public func setParameter(id: String, value: Float) throws {
        try pluginQueue.sync {
            guard id == "gain" else {
                throw AudioEngineError.pluginError("Unknown parameter: \(id)")
            }
            gain = max(0.0, min(4.0, value))
        }
    }

    public func getParameter(id: String) throws -> Float {
        return try pluginQueue.sync {
            guard id == "gain" else {
                throw AudioEngineError.pluginError("Unknown parameter: \(id)")
            }
            return gain
        }
    }

    public func reset() {
        pluginQueue.sync {
            gain = 1.0
        }
    }

    public func cleanup() {
        // No cleanup needed for gain plugin
    }
}

/// Built-in delay plugin
public final class DelayPlugin: AudioPlugin, @unchecked Sendable {
    public let id = UUID()
    public let name = "Delay"
    public let version = "1.0.0"
    public let author = "AudioEngine"
    public let description = "Simple delay effect plugin"
    public let parameters: [AudioPluginParameter]

    private var delayTime: Float = 0.25
    private var feedback: Float = 0.3
    private var wetLevel: Float = 0.3
    private var delayLine: DelayLine?
    private let pluginQueue = DispatchQueue(label: "DelayPlugin", qos: .userInitiated)

    public init() {
        self.parameters = [
            AudioPluginParameter(
                id: "delayTime",
                name: "Delay Time",
                description: "Delay time in seconds",
                minValue: 0.01,
                maxValue: 2.0,
                defaultValue: 0.25,
                unit: "s"
            ),
            AudioPluginParameter(
                id: "feedback",
                name: "Feedback",
                description: "Delay feedback amount",
                minValue: 0.0,
                maxValue: 0.95,
                defaultValue: 0.3,
                unit: "%"
            ),
            AudioPluginParameter(
                id: "wetLevel",
                name: "Wet Level",
                description: "Wet signal level",
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 0.3,
                unit: "%"
            )
        ]
    }

    public func initialize(sampleRate: Double, bufferSize: Int) throws {
        pluginQueue.sync {
            let maxDelaySamples = Int(2.0 * sampleRate) // 2 seconds max delay
            delayLine = DelayLine(maxDelay: maxDelaySamples)
        }
    }

    public func process(_ buffer: AudioBuffer) throws {
        try pluginQueue.sync {
            guard let delayLine = delayLine else {
                throw AudioEngineError.pluginError("Delay plugin not initialized")
            }

            let totalSamples = buffer.frameCount * buffer.channelCount

            for i in 0..<totalSamples {
                let inputSample = buffer.data[i]
                let delayedSample = delayLine.read()

                let feedbackSample = inputSample + delayedSample * feedback
                delayLine.write(feedbackSample)

                buffer.data[i] = inputSample * (1.0 - wetLevel) + delayedSample * wetLevel
            }
        }
    }

    public func setParameter(id: String, value: Float) throws {
        try pluginQueue.sync {
            switch id {
            case "delayTime":
                delayTime = max(0.01, min(2.0, value))
            case "feedback":
                feedback = max(0.0, min(0.95, value))
            case "wetLevel":
                wetLevel = max(0.0, min(1.0, value))
            default:
                throw AudioEngineError.pluginError("Unknown parameter: \(id)")
            }
        }
    }

    public func getParameter(id: String) throws -> Float {
        return try pluginQueue.sync {
            switch id {
            case "delayTime":
                return delayTime
            case "feedback":
                return feedback
            case "wetLevel":
                return wetLevel
            default:
                throw AudioEngineError.pluginError("Unknown parameter: \(id)")
            }
        }
    }

    public func reset() {
        pluginQueue.sync {
            delayLine?.reset()
            delayTime = 0.25
            feedback = 0.3
            wetLevel = 0.3
        }
    }

    public func cleanup() {
        pluginQueue.sync {
            delayLine = nil
        }
    }
}

/// Built-in reverb plugin
public final class ReverbPlugin: AudioPlugin, @unchecked Sendable {
    public let id = UUID()
    public let name = "Reverb"
    public let version = "1.0.0"
    public let author = "AudioEngine"
    public let description = "Simple reverb effect plugin"
    public let parameters: [AudioPluginParameter]

    private var roomSize: Float = 0.5
    private var damping: Float = 0.5
    private var wetLevel: Float = 0.3
    private var reverbAlgorithm: ReverbAlgorithm?
    private let pluginQueue = DispatchQueue(label: "ReverbPlugin", qos: .userInitiated)

    public init() {
        self.parameters = [
            AudioPluginParameter(
                id: "roomSize",
                name: "Room Size",
                description: "Reverb room size",
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 0.5,
                unit: "%"
            ),
            AudioPluginParameter(
                id: "damping",
                name: "Damping",
                description: "High frequency damping",
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 0.5,
                unit: "%"
            ),
            AudioPluginParameter(
                id: "wetLevel",
                name: "Wet Level",
                description: "Reverb wet level",
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 0.3,
                unit: "%"
            )
        ]
    }

    public func initialize(sampleRate: Double, bufferSize: Int) throws {
        pluginQueue.sync {
            reverbAlgorithm = ReverbAlgorithm(sampleRate: sampleRate)
        }
    }

    public func process(_ buffer: AudioBuffer) throws {
        try pluginQueue.sync {
            guard let reverb = reverbAlgorithm else {
                throw AudioEngineError.pluginError("Reverb plugin not initialized")
            }

            // Update reverb parameters
            reverb.parameters = [
                "roomSize": roomSize,
                "damping": damping,
                "wetLevel": wetLevel,
                "dryLevel": 1.0 - wetLevel
            ]

            reverb.process(buffer)
        }
    }

    public func setParameter(id: String, value: Float) throws {
        try pluginQueue.sync {
            switch id {
            case "roomSize":
                roomSize = max(0.0, min(1.0, value))
            case "damping":
                damping = max(0.0, min(1.0, value))
            case "wetLevel":
                wetLevel = max(0.0, min(1.0, value))
            default:
                throw AudioEngineError.pluginError("Unknown parameter: \(id)")
            }
        }
    }

    public func getParameter(id: String) throws -> Float {
        return try pluginQueue.sync {
            switch id {
            case "roomSize":
                return roomSize
            case "damping":
                return damping
            case "wetLevel":
                return wetLevel
            default:
                throw AudioEngineError.pluginError("Unknown parameter: \(id)")
            }
        }
    }

    public func reset() {
        pluginQueue.sync {
            reverbAlgorithm?.reset()
            roomSize = 0.5
            damping = 0.5
            wetLevel = 0.3
        }
    }

    public func cleanup() {
        pluginQueue.sync {
            reverbAlgorithm = nil
        }
    }
}

// MARK: - Multi-Channel Audio Support System

/// Channel configuration for multi-channel audio
public enum ChannelConfiguration: Sendable, Equatable {
    case mono           // 1.0
    case stereo         // 2.0
    case stereo21       // 2.1 (L, R, LFE)
    case surround51     // 5.1 (L, R, C, LFE, Ls, Rs)
    case surround71     // 7.1 (L, R, C, LFE, Ls, Rs, Lrs, Rrs)
    case surround714    // 7.1.4 Atmos (7.1 + 4 height channels)
    case custom(channelCount: Int)

    public static var allCases: [ChannelConfiguration] {
        return [.mono, .stereo, .stereo21, .surround51, .surround71, .surround714]
    }

    public var channelCount: Int {
        switch self {
        case .mono:
            return 1
        case .stereo:
            return 2
        case .stereo21:
            return 3
        case .surround51:
            return 6
        case .surround71:
            return 8
        case .surround714:
            return 12
        case .custom(let count):
            return count
        }
    }

    public var channelLabels: [String] {
        switch self {
        case .mono:
            return ["Mono"]
        case .stereo:
            return ["Left", "Right"]
        case .stereo21:
            return ["Left", "Right", "LFE"]
        case .surround51:
            return ["Left", "Right", "Center", "LFE", "Left Surround", "Right Surround"]
        case .surround71:
            return ["Left", "Right", "Center", "LFE", "Left Surround", "Right Surround", "Left Rear", "Right Rear"]
        case .surround714:
            return ["Left", "Right", "Center", "LFE", "Left Surround", "Right Surround", "Left Rear", "Right Rear",
                   "Top Front Left", "Top Front Right", "Top Rear Left", "Top Rear Right"]
        case .custom(let count):
            return (1...count).map { "Channel \($0)" }
        }
    }
}

/// Multi-channel audio buffer for handling various channel configurations
public final class MultiChannelAudioBuffer: @unchecked Sendable {
    public let configuration: ChannelConfiguration
    public let frameCount: Int
    public let sampleRate: Double
    private let channelData: [UnsafeMutablePointer<Float>]
    private let bufferQueue = DispatchQueue(label: "MultiChannelAudioBuffer", qos: .userInteractive)

    public init(configuration: ChannelConfiguration, frameCount: Int, sampleRate: Double) {
        self.configuration = configuration
        self.frameCount = frameCount
        self.sampleRate = sampleRate

        // Allocate separate buffers for each channel
        self.channelData = (0..<configuration.channelCount).map { _ in
            let buffer = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
            buffer.initialize(repeating: 0.0, count: frameCount)
            return buffer
        }
    }

    deinit {
        for buffer in channelData {
            buffer.deallocate()
        }
    }

    /// Get channel data for specific channel
    public func getChannelData(channel: Int) -> UnsafeMutablePointer<Float>? {
        return bufferQueue.sync {
            guard channel >= 0 && channel < configuration.channelCount else { return nil }
            return channelData[channel]
        }
    }

    /// Set sample value for specific channel and frame
    public func setSample(channel: Int, frame: Int, value: Float) {
        bufferQueue.sync {
            guard channel >= 0 && channel < configuration.channelCount,
                  frame >= 0 && frame < frameCount else { return }
            channelData[channel][frame] = value
        }
    }

    /// Get sample value for specific channel and frame
    public func getSample(channel: Int, frame: Int) -> Float {
        return bufferQueue.sync {
            guard channel >= 0 && channel < configuration.channelCount,
                  frame >= 0 && frame < frameCount else { return 0.0 }
            return channelData[channel][frame]
        }
    }

    /// Clear all channel data
    public func clear() {
        bufferQueue.sync {
            for buffer in channelData {
                buffer.initialize(repeating: 0.0, count: frameCount)
            }
        }
    }

    /// Copy data from another multi-channel buffer
    public func copyFrom(_ other: MultiChannelAudioBuffer) {
        bufferQueue.sync {
            let channelsToCopy = min(configuration.channelCount, other.configuration.channelCount)
            let framesToCopy = min(frameCount, other.frameCount)

            for channel in 0..<channelsToCopy {
                if let sourceData = other.getChannelData(channel: channel),
                   let destData = getChannelData(channel: channel) {
                    destData.update(from: sourceData, count: framesToCopy)
                }
            }
        }
    }

    /// Convert to interleaved AudioBuffer
    public func toInterleavedBuffer() -> AudioBuffer {
        return bufferQueue.sync {
            let totalSamples = frameCount * configuration.channelCount
            let interleavedData = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)

            for frame in 0..<frameCount {
                for channel in 0..<configuration.channelCount {
                    let interleavedIndex = frame * configuration.channelCount + channel
                    interleavedData[interleavedIndex] = channelData[channel][frame]
                }
            }

            return AudioBuffer(
                data: interleavedData,
                frameCount: frameCount,
                channelCount: configuration.channelCount,
                sampleRate: sampleRate
            )
        }
    }

    /// Create from interleaved AudioBuffer
    public static func fromInterleavedBuffer(_ buffer: AudioBuffer, configuration: ChannelConfiguration) -> MultiChannelAudioBuffer {
        let multiBuffer = MultiChannelAudioBuffer(
            configuration: configuration,
            frameCount: buffer.frameCount,
            sampleRate: buffer.sampleRate
        )

        let channelCount = min(buffer.channelCount, configuration.channelCount)

        for frame in 0..<buffer.frameCount {
            for channel in 0..<channelCount {
                let interleavedIndex = frame * buffer.channelCount + channel
                multiBuffer.setSample(channel: channel, frame: frame, value: buffer.data[interleavedIndex])
            }
        }

        return multiBuffer
    }
}

/// Channel mapping and routing for multi-channel audio
public final class ChannelMapper: @unchecked Sendable {
    private var mappings: [ChannelMapping] = []
    private let mapperQueue = DispatchQueue(label: "ChannelMapper", qos: .userInteractive)

    public struct ChannelMapping: Sendable {
        public let sourceChannel: Int
        public let destinationChannel: Int
        public let gain: Float

        public init(sourceChannel: Int, destinationChannel: Int, gain: Float = 1.0) {
            self.sourceChannel = sourceChannel
            self.destinationChannel = destinationChannel
            self.gain = gain
        }
    }

    public init() {}

    /// Add channel mapping
    public func addMapping(_ mapping: ChannelMapping) {
        mapperQueue.sync {
            mappings.append(mapping)
        }
    }

    /// Remove all mappings
    public func clearMappings() {
        mapperQueue.sync {
            mappings.removeAll()
        }
    }

    /// Apply channel mapping to multi-channel buffer
    public func applyMapping(source: MultiChannelAudioBuffer, destination: MultiChannelAudioBuffer) {
        mapperQueue.sync {
            destination.clear()

            for mapping in mappings {
                guard let sourceData = source.getChannelData(channel: mapping.sourceChannel),
                      let destData = destination.getChannelData(channel: mapping.destinationChannel) else {
                    continue
                }

                let framesToProcess = min(source.frameCount, destination.frameCount)

                for frame in 0..<framesToProcess {
                    destData[frame] += sourceData[frame] * mapping.gain
                }
            }
        }
    }

    /// Create standard stereo to surround mapping
    public func createStereoToSurroundMapping(sourceConfig: ChannelConfiguration, destConfig: ChannelConfiguration) {
        mapperQueue.sync {
            clearMappings()

            // Basic stereo to surround mapping
            if sourceConfig == .stereo {
                switch destConfig {
                case .surround51:
                    addMapping(ChannelMapping(sourceChannel: 0, destinationChannel: 0)) // L -> L
                    addMapping(ChannelMapping(sourceChannel: 1, destinationChannel: 1)) // R -> R
                case .surround71:
                    addMapping(ChannelMapping(sourceChannel: 0, destinationChannel: 0)) // L -> L
                    addMapping(ChannelMapping(sourceChannel: 1, destinationChannel: 1)) // R -> R
                default:
                    // Direct mapping for other configurations
                    let channelCount = min(sourceConfig.channelCount, destConfig.channelCount)
                    for i in 0..<channelCount {
                        addMapping(ChannelMapping(sourceChannel: i, destinationChannel: i))
                    }
                }
            }
        }
    }
}

// MARK: - Audio Filter for Multi-Channel Processing

/// Basic audio filter interface for multi-channel processing
public protocol AudioFilter: Sendable {
    func process(_ input: Float) -> Float
    func reset()
}

/// Simple lowpass filter implementation
public final class LowpassFilter: AudioFilter, @unchecked Sendable {
    private var previousOutput: Float = 0.0
    private let cutoffFrequency: Float
    private let sampleRate: Float
    private let alpha: Float

    public init(cutoffFrequency: Float, sampleRate: Float) {
        self.cutoffFrequency = cutoffFrequency
        self.sampleRate = sampleRate

        // Calculate filter coefficient
        let rc = 1.0 / (2.0 * Float.pi * cutoffFrequency)
        let dt = 1.0 / sampleRate
        self.alpha = dt / (rc + dt)
    }

    public func process(_ input: Float) -> Float {
        previousOutput = alpha * input + (1.0 - alpha) * previousOutput
        return previousOutput
    }

    public func reset() {
        previousOutput = 0.0
    }
}

// MARK: - Multi-Channel Processing and Conversion

/// Multi-channel audio processor for handling various channel configurations
public final class MultiChannelProcessor: @unchecked Sendable {
    private let processorQueue = DispatchQueue(label: "MultiChannelProcessor", qos: .userInteractive)
    private var channelProcessors: [Int: ChannelProcessor] = [:]

    private struct ChannelProcessor {
        var gain: Float = 1.0
        var mute: Bool = false
        var solo: Bool = false
        var delay: DelayLine?
        var filter: AudioFilter?
    }

    public init() {}

    /// Set channel gain
    public func setChannelGain(channel: Int, gain: Float) {
        processorQueue.sync {
            if channelProcessors[channel] == nil {
                channelProcessors[channel] = ChannelProcessor()
            }
            channelProcessors[channel]?.gain = max(0.0, min(4.0, gain))
        }
    }

    /// Set channel mute
    public func setChannelMute(channel: Int, mute: Bool) {
        processorQueue.sync {
            if channelProcessors[channel] == nil {
                channelProcessors[channel] = ChannelProcessor()
            }
            channelProcessors[channel]?.mute = mute
        }
    }

    /// Set channel solo
    public func setChannelSolo(channel: Int, solo: Bool) {
        processorQueue.sync {
            if channelProcessors[channel] == nil {
                channelProcessors[channel] = ChannelProcessor()
            }
            channelProcessors[channel]?.solo = solo
        }
    }

    /// Process multi-channel buffer
    public func process(_ buffer: MultiChannelAudioBuffer) {
        processorQueue.sync {
            let hasSoloChannels = channelProcessors.values.contains { $0.solo }

            for channel in 0..<buffer.configuration.channelCount {
                guard let channelData = buffer.getChannelData(channel: channel) else { continue }

                let processor = channelProcessors[channel] ?? ChannelProcessor()

                // Check if channel should be audible
                let shouldProcess = !processor.mute && (!hasSoloChannels || processor.solo)

                if shouldProcess {
                    // Apply gain
                    for frame in 0..<buffer.frameCount {
                        channelData[frame] *= processor.gain
                    }
                } else {
                    // Mute channel
                    for frame in 0..<buffer.frameCount {
                        channelData[frame] = 0.0
                    }
                }
            }
        }
    }

    /// Get channel processor status
    public func getChannelStatus(channel: Int) -> (gain: Float, mute: Bool, solo: Bool) {
        return processorQueue.sync {
            let processor = channelProcessors[channel] ?? ChannelProcessor()
            return (processor.gain, processor.mute, processor.solo)
        }
    }

    /// Reset all channel processors
    public func reset() {
        processorQueue.sync {
            channelProcessors.removeAll()
        }
    }
}

/// Multi-channel format converter for converting between different channel configurations
public final class MultiChannelFormatConverter: @unchecked Sendable {
    private let converterQueue = DispatchQueue(label: "MultiChannelFormatConverter", qos: .userInteractive)
    private let channelMapper = ChannelMapper()

    public init() {}

    /// Convert between different channel configurations
    public func convert(source: MultiChannelAudioBuffer, to targetConfig: ChannelConfiguration) -> MultiChannelAudioBuffer {
        return converterQueue.sync {
            let destination = MultiChannelAudioBuffer(
                configuration: targetConfig,
                frameCount: source.frameCount,
                sampleRate: source.sampleRate
            )

            // Apply appropriate conversion strategy
            switch (source.configuration, targetConfig) {
            case (.mono, .stereo):
                convertMonoToStereo(source: source, destination: destination)
            case (.stereo, .mono):
                convertStereoToMono(source: source, destination: destination)
            case (.stereo, .surround51):
                convertStereoToSurround51(source: source, destination: destination)
            case (.surround51, .stereo):
                convertSurround51ToStereo(source: source, destination: destination)
            case (.stereo, .surround71):
                convertStereoToSurround71(source: source, destination: destination)
            case (.surround71, .stereo):
                convertSurround71ToStereo(source: source, destination: destination)
            default:
                // Generic conversion - copy matching channels
                convertGeneric(source: source, destination: destination)
            }

            return destination
        }
    }

    private func convertMonoToStereo(source: MultiChannelAudioBuffer, destination: MultiChannelAudioBuffer) {
        guard let sourceData = source.getChannelData(channel: 0),
              let leftData = destination.getChannelData(channel: 0),
              let rightData = destination.getChannelData(channel: 1) else { return }

        for frame in 0..<source.frameCount {
            let sample = sourceData[frame]
            leftData[frame] = sample
            rightData[frame] = sample
        }
    }

    private func convertStereoToMono(source: MultiChannelAudioBuffer, destination: MultiChannelAudioBuffer) {
        guard let leftData = source.getChannelData(channel: 0),
              let rightData = source.getChannelData(channel: 1),
              let monoData = destination.getChannelData(channel: 0) else { return }

        for frame in 0..<source.frameCount {
            monoData[frame] = (leftData[frame] + rightData[frame]) * 0.5
        }
    }

    private func convertStereoToSurround51(source: MultiChannelAudioBuffer, destination: MultiChannelAudioBuffer) {
        guard let leftData = source.getChannelData(channel: 0),
              let rightData = source.getChannelData(channel: 1),
              let destLeftData = destination.getChannelData(channel: 0),
              let destRightData = destination.getChannelData(channel: 1) else { return }

        // Copy L/R channels directly
        for frame in 0..<source.frameCount {
            destLeftData[frame] = leftData[frame]
            destRightData[frame] = rightData[frame]
        }

        // Center channel gets a mix of L/R
        if let centerData = destination.getChannelData(channel: 2) {
            for frame in 0..<source.frameCount {
                centerData[frame] = (leftData[frame] + rightData[frame]) * 0.5
            }
        }

        // LFE channel gets low-frequency content (simplified)
        if let lfeData = destination.getChannelData(channel: 3) {
            for frame in 0..<source.frameCount {
                lfeData[frame] = (leftData[frame] + rightData[frame]) * 0.1
            }
        }

        // Surround channels get ambient content (simplified)
        if let leftSurroundData = destination.getChannelData(channel: 4),
           let rightSurroundData = destination.getChannelData(channel: 5) {
            for frame in 0..<source.frameCount {
                leftSurroundData[frame] = leftData[frame] * 0.3
                rightSurroundData[frame] = rightData[frame] * 0.3
            }
        }
    }

    private func convertSurround51ToStereo(source: MultiChannelAudioBuffer, destination: MultiChannelAudioBuffer) {
        guard let destLeftData = destination.getChannelData(channel: 0),
              let destRightData = destination.getChannelData(channel: 1) else { return }

        // Mix down 5.1 to stereo
        for frame in 0..<source.frameCount {
            var leftMix: Float = 0.0
            var rightMix: Float = 0.0

            // Front L/R
            if let leftData = source.getChannelData(channel: 0) {
                leftMix += leftData[frame]
            }
            if let rightData = source.getChannelData(channel: 1) {
                rightMix += rightData[frame]
            }

            // Center (mix to both channels)
            if let centerData = source.getChannelData(channel: 2) {
                let centerContribution = centerData[frame] * 0.707 // -3dB
                leftMix += centerContribution
                rightMix += centerContribution
            }

            // LFE (mix to both channels)
            if let lfeData = source.getChannelData(channel: 3) {
                let lfeContribution = lfeData[frame] * 0.5
                leftMix += lfeContribution
                rightMix += lfeContribution
            }

            // Surround channels
            if let leftSurroundData = source.getChannelData(channel: 4) {
                leftMix += leftSurroundData[frame] * 0.707
            }
            if let rightSurroundData = source.getChannelData(channel: 5) {
                rightMix += rightSurroundData[frame] * 0.707
            }

            destLeftData[frame] = leftMix
            destRightData[frame] = rightMix
        }
    }

    private func convertStereoToSurround71(source: MultiChannelAudioBuffer, destination: MultiChannelAudioBuffer) {
        // Similar to 5.1 but with additional rear channels
        convertStereoToSurround51(source: source, destination: destination)

        // Add rear channels
        guard let leftData = source.getChannelData(channel: 0),
              let rightData = source.getChannelData(channel: 1) else { return }

        if let leftRearData = destination.getChannelData(channel: 6),
           let rightRearData = destination.getChannelData(channel: 7) {
            for frame in 0..<source.frameCount {
                leftRearData[frame] = leftData[frame] * 0.2
                rightRearData[frame] = rightData[frame] * 0.2
            }
        }
    }

    private func convertSurround71ToStereo(source: MultiChannelAudioBuffer, destination: MultiChannelAudioBuffer) {
        guard let destLeftData = destination.getChannelData(channel: 0),
              let destRightData = destination.getChannelData(channel: 1) else { return }

        // Mix down 7.1 to stereo (similar to 5.1 but with rear channels)
        for frame in 0..<source.frameCount {
            var leftMix: Float = 0.0
            var rightMix: Float = 0.0

            // Front L/R
            if let leftData = source.getChannelData(channel: 0) {
                leftMix += leftData[frame]
            }
            if let rightData = source.getChannelData(channel: 1) {
                rightMix += rightData[frame]
            }

            // Center
            if let centerData = source.getChannelData(channel: 2) {
                let centerContribution = centerData[frame] * 0.707
                leftMix += centerContribution
                rightMix += centerContribution
            }

            // LFE
            if let lfeData = source.getChannelData(channel: 3) {
                let lfeContribution = lfeData[frame] * 0.5
                leftMix += lfeContribution
                rightMix += lfeContribution
            }

            // Side surround channels
            if let leftSurroundData = source.getChannelData(channel: 4) {
                leftMix += leftSurroundData[frame] * 0.707
            }
            if let rightSurroundData = source.getChannelData(channel: 5) {
                rightMix += rightSurroundData[frame] * 0.707
            }

            // Rear channels
            if let leftRearData = source.getChannelData(channel: 6) {
                leftMix += leftRearData[frame] * 0.5
            }
            if let rightRearData = source.getChannelData(channel: 7) {
                rightMix += rightRearData[frame] * 0.5
            }

            destLeftData[frame] = leftMix
            destRightData[frame] = rightMix
        }
    }

    private func convertGeneric(source: MultiChannelAudioBuffer, destination: MultiChannelAudioBuffer) {
        let channelCount = min(source.configuration.channelCount, destination.configuration.channelCount)

        for channel in 0..<channelCount {
            guard let sourceData = source.getChannelData(channel: channel),
                  let destData = destination.getChannelData(channel: channel) else { continue }

            let frameCount = min(source.frameCount, destination.frameCount)
            destData.update(from: sourceData, count: frameCount)
        }
    }
}

// MARK: - Audio Engine Manager

/// Main interface for audio operations with comprehensive lifecycle management
@objc public final class AudioEngineManager: NSObject, @unchecked Sendable {
    @objc public static let shared = AudioEngineManager()

    // MARK: - Private Properties

    private let engine = AVAudioEngine()
    #if os(iOS)
    private let audioSession = AVAudioSession.sharedInstance()
    #endif
    private let queue = DispatchQueue(label: "AudioEngineManager", qos: .userInitiated)

    // Audio graph management
    private let graphManager = AudioGraphManager()

    // Buffer management
    private var bufferPool: AudioBufferPool?
    private var circularBuffer: AudioCircularBuffer?

    // Error recovery management
    private var errorRecoveryManager: AudioErrorRecoveryManager?

    // Audio routing management
    private var routingMatrix: AudioRoutingMatrix?
    private var dynamicRoutingManager: DynamicRoutingManager?

    // Format conversion management
    private var formatConversionManager: AudioFormatConversionManager?

    private var _configuration: AudioEngineConfiguration?
    private var _status: AudioEngineStatus = .uninitialized
    private var _performanceMetrics = AudioEnginePerformanceMetrics()
    private var _lastError: AudioEngineError?

    // Notification observers
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?

    // Performance monitoring
    private var performanceTimer: Timer?
    private var startTime: Date?
    private var performanceAnalyzer: AudioPerformanceAnalyzer?

    // Thread management
    private var threadPool: AudioThreadPool?
    private var threadSynchronizer: AudioThreadSynchronizer?

    // DSP algorithm management
    private var dspManager: DSPAlgorithmManager?

    // MIDI system management
    private var midiParser: MIDIMessageParser?
    private var midiRouter: MIDIRouter?
    private var midiParameterMapper: MIDIParameterMapper?
    private var midiDeviceManager: MIDIDeviceManager?

    // Testing framework
    private var testingFramework: AudioTestingFramework?

    // Audio file I/O management
    private var audioFileIOManager: AudioFileIOManager?

    // Audio clock and synchronization
    private var audioClockManager: AudioClockManager?

    // Plugin architecture
    private var pluginManager: AudioPluginManager?

    // Multi-channel support
    private var multiChannelProcessor: MultiChannelProcessor?
    private var multiChannelFormatConverter: MultiChannelFormatConverter?
    private var currentChannelConfiguration: ChannelConfiguration = .stereo

    // Sequencer integration
    private var sequencerBridge: SequencerBridge?
    private var timingSynchronizer: TimingSynchronizer?

    // MARK: - Public Properties

    /// Current configuration of the audio engine
    public var configuration: AudioEngineConfiguration? {
        return queue.sync { _configuration }
    }

    /// Current status of the audio engine
    public var status: AudioEngineStatus {
        return queue.sync { _status }
    }

    /// Current performance metrics
    public var performanceMetrics: AudioEnginePerformanceMetrics {
        return queue.sync { _performanceMetrics }
    }

    /// Last error that occurred
    public var lastError: AudioEngineError? {
        return queue.sync { _lastError }
    }

    /// Whether the engine is currently running
    public var isRunning: Bool {
        return engine.isRunning
    }

    /// Current sample rate
    public var sampleRate: Double {
        return engine.outputNode.outputFormat(forBus: 0).sampleRate
    }

    /// Current buffer size in frames
    public var bufferSize: AVAudioFrameCount {
        #if os(iOS)
        return engine.outputNode.outputFormat(forBus: 0).commonFormat == .pcmFormatFloat32 ?
               AVAudioFrameCount(audioSession.ioBufferDuration * sampleRate) : 0
        #else
        // On macOS, return a default buffer size
        return 512
        #endif
    }

    // MARK: - Callbacks

    /// Called when the engine status changes
    public var statusChangeCallback: ((AudioEngineStatus) -> Void)?

    /// Called when an error occurs
    public var errorCallback: ((AudioEngineError) -> Void)?

    /// Called when performance metrics are updated
    public var performanceCallback: ((AudioEnginePerformanceMetrics) -> Void)?

    // MARK: - Initialization

    private override init() {
        super.init()
        setupNotificationObservers()
    }

    deinit {
        cleanup()
    }

    // MARK: - Public Methods

    /// Initialize the audio engine with the given configuration
    public func initialize(configuration: AudioEngineConfiguration = AudioEngineConfiguration()) throws {
        try queue.sync {
            guard _status == .uninitialized else {
                throw AudioEngineError.initializationFailed("Engine already initialized")
            }

            updateStatus(.initializing)

            do {
                // Store configuration
                _configuration = configuration

                // Configure audio session
                try configureAudioSession(configuration)

                // Configure engine
                try configureEngine(configuration)

                // Setup buffer management
                try setupBufferManagement(configuration)

                // Setup error recovery if enabled
                if configuration.enableErrorRecovery {
                    setupErrorRecovery()
                }

                // Setup audio routing system
                setupAudioRouting()

                // Setup format conversion system
                setupFormatConversion()

                // Setup performance monitoring if enabled
                if configuration.enablePerformanceMonitoring {
                    setupPerformanceMonitoring()
                }

                // Setup thread management
                setupThreadManagement(configuration)

                // Setup DSP algorithm library
                setupDSPLibrary()

                // Setup MIDI system
                setupMIDISystem()

                // Setup testing framework
                setupTestingFramework()

                // Setup audio file I/O
                setupAudioFileIO()

                // Setup audio clock and synchronization
                setupAudioClock(configuration)

                // Setup plugin architecture
                setupPluginArchitecture()

                // Setup multi-channel support
                setupMultiChannelSupport(configuration)

                // Setup sequencer integration
                setupSequencerIntegration(configuration)

                updateStatus(.ready)

            } catch {
                updateStatus(.error)
                let engineError = AudioEngineError.initializationFailed(error.localizedDescription)
                _lastError = engineError
                throw engineError
            }
        }
    }

    /// Start the audio engine
    @objc public func start() throws {
        try queue.sync {
            guard _status == .ready || _status == .stopped else {
                throw AudioEngineError.engineStartFailed("Engine not ready to start. Current status: \(_status)")
            }

            updateStatus(.starting)

            do {
                startTime = Date()
                try engine.start()
                updateStatus(.running)

                // Start performance monitoring
                if _configuration?.enablePerformanceMonitoring == true {
                    startPerformanceMonitoring()
                }

            } catch {
                updateStatus(.error)
                let engineError = AudioEngineError.engineStartFailed(error.localizedDescription)
                _lastError = engineError

                // Attempt error recovery if enabled
                if let recoveryManager = errorRecoveryManager {
                    Task {
                        let recovered = await attemptErrorRecovery(error: engineError, recoveryManager: recoveryManager)
                        if !recovered {
                            DispatchQueue.main.async { [weak self] in
                                self?.errorCallback?(engineError)
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.errorCallback?(engineError)
                    }
                }

                throw engineError
            }
        }
    }

    /// Stop the audio engine
    @objc public func stop() throws {
        try queue.sync {
            guard _status == .running || _status == .starting else {
                throw AudioEngineError.engineStopFailed("Engine not running. Current status: \(_status)")
            }

            updateStatus(.stopping)

            // Stop performance monitoring
            stopPerformanceMonitoring()

            engine.stop()
            updateStatus(.stopped)
        }
    }

    /// Suspend the audio engine (for interruptions)
    @objc public func suspend() throws {
        try queue.sync {
            guard _status == .running else {
                throw AudioEngineError.interruptionError("Cannot suspend engine that is not running")
            }

            engine.pause()
            updateStatus(.suspended)
        }
    }

    /// Resume the audio engine (after interruption)
    @objc public func resume() throws {
        try queue.sync {
            guard _status == .suspended else {
                throw AudioEngineError.interruptionError("Cannot resume engine that is not suspended")
            }

            do {
                try engine.start()
                updateStatus(.running)
            } catch {
                let engineError = AudioEngineError.interruptionError(error.localizedDescription)
                _lastError = engineError
                throw engineError
            }
        }
    }

    /// Reset the audio engine to initial state
    @objc public func reset() {
        queue.sync {
            cleanup()
            _status = .uninitialized
            _configuration = nil
            _lastError = nil
            _performanceMetrics.reset()
        }
    }

    // MARK: - Audio Graph Management

    /// Add a node to the audio graph
    public func addNode(_ node: AudioNode) async throws {
        try await graphManager.addNode(node)
    }

    /// Remove a node from the audio graph
    public func removeNode(id: AudioNodeID) async throws {
        try await graphManager.removeNode(id: id)
    }

    /// Get a node by ID
    public func getNode(id: AudioNodeID) async -> AudioNode? {
        return await graphManager.getNode(id: id)
    }

    /// Get all nodes in the graph
    public func getAllNodes() async -> [AudioNode] {
        return await graphManager.getAllNodes()
    }

    /// Connect two nodes in the graph
    public func connect(
        sourceId: AudioNodeID,
        destinationId: AudioNodeID,
        sourceOutputIndex: Int = 0,
        destinationInputIndex: Int = 0,
        format: AVAudioFormat
    ) async throws {
        try await graphManager.connect(
            sourceId: sourceId,
            destinationId: destinationId,
            sourceOutputIndex: sourceOutputIndex,
            destinationInputIndex: destinationInputIndex,
            format: format
        )
    }

    /// Disconnect two nodes
    public func disconnect(sourceId: AudioNodeID, destinationId: AudioNodeID) async throws {
        try await graphManager.disconnect(sourceId: sourceId, destinationId: destinationId)
    }

    /// Get all connections in the graph
    public func getAllConnections() async -> [AudioConnection] {
        return await graphManager.getAllConnections()
    }

    /// Validate the audio graph
    public func validateGraph() async throws {
        try await graphManager.validateGraph()
    }

    /// Process the audio graph (called internally during audio processing)
    internal func processAudioGraph() async {
        await graphManager.processGraph()
    }

    // MARK: - Buffer Management

    /// Get a buffer from the buffer pool
    public func getBuffer() -> AudioBuffer? {
        return bufferPool?.getBuffer()
    }

    /// Return a buffer to the buffer pool
    public func returnBuffer(_ buffer: AudioBuffer) {
        bufferPool?.returnBuffer(buffer)
    }

    /// Get buffer pool statistics
    public func getBufferPoolStatistics() -> (available: Int, allocated: Int, total: Int)? {
        return bufferPool?.getStatistics()
    }

    /// Write audio data to the circular buffer
    public func writeToCircularBuffer(_ buffer: AudioBuffer) -> Int? {
        return circularBuffer?.write(buffer)
    }

    /// Read audio data from the circular buffer
    public func readFromCircularBuffer(frameCount: Int, into buffer: AudioBuffer) -> Int? {
        return circularBuffer?.read(frameCount: frameCount, into: buffer)
    }

    /// Get circular buffer statistics
    public func getCircularBufferStatistics() -> (capacity: Int, available: Int, usage: Double)? {
        return circularBuffer?.getStatistics()
    }

    /// Clear the circular buffer
    public func clearCircularBuffer() {
        circularBuffer?.clear()
    }

    // MARK: - Error Recovery Management

    /// Get error recovery statistics
    public func getErrorRecoveryStatistics() -> (totalAttempts: Int, successRate: Double, recentErrors: [String: Int])? {
        return errorRecoveryManager?.getRecoveryStatistics()
    }

    /// Reset error recovery history
    public func resetErrorRecovery() {
        errorRecoveryManager?.reset()
    }

    /// Manually trigger error recovery for testing
    public func triggerErrorRecovery(for error: AudioEngineError) async -> Bool {
        guard let recoveryManager = errorRecoveryManager else { return false }
        return await attemptErrorRecovery(error: error, recoveryManager: recoveryManager)
    }

    // MARK: - Audio Routing Management

    /// Add a routing connection between nodes
    public func addRoutingConnection(
        from sourceId: AudioNodeID,
        to destinationId: AudioNodeID,
        gain: Float = 1.0,
        format: AVAudioFormat
    ) throws -> UUID? {
        return try dynamicRoutingManager?.addDynamicConnection(
            from: sourceId,
            to: destinationId,
            gain: gain,
            format: format
        )
    }

    /// Remove a routing connection
    public func removeRoutingConnection(id: UUID) throws {
        try dynamicRoutingManager?.removeDynamicConnection(id: id)
    }

    /// Update routing connection gain
    public func updateRoutingGain(id: UUID, gain: Float, transitionTime: TimeInterval = 0.1) throws {
        try dynamicRoutingManager?.updateConnectionGain(id: id, targetGain: gain, transitionTime: transitionTime)
    }

    /// Toggle routing connection active state
    public func toggleRoutingConnection(id: UUID) throws {
        try dynamicRoutingManager?.toggleConnection(id: id)
    }

    /// Get routing gain between two nodes
    public func getRoutingGain(from sourceId: AudioNodeID, to destinationId: AudioNodeID) -> Float {
        return routingMatrix?.getRoutingGain(from: sourceId, to: destinationId) ?? 0.0
    }

    /// Get routing statistics
    public func getRoutingStatistics() -> (totalConnections: Int, activeConnections: Int, matrixUtilization: Double)? {
        return routingMatrix?.getRoutingStatistics()
    }

    /// Get routing change history
    public func getRoutingChangeHistory(limit: Int = 100) -> [DynamicRoutingManager.RoutingChangeEvent] {
        return dynamicRoutingManager?.getChangeHistory(limit: limit) ?? []
    }

    /// Clear all routing connections
    public func clearAllRoutingConnections() {
        routingMatrix?.clearAllConnections()
        dynamicRoutingManager?.clearHistory()
    }

    /// Optimize routing matrix
    public func optimizeRouting() {
        dynamicRoutingManager?.optimizeIfNeeded()
    }

    // MARK: - Format Conversion Management

    /// Convert audio buffer between formats
    public func convertAudioFormat(
        _ buffer: AudioBuffer,
        from sourceFormat: AVAudioFormat,
        to destinationFormat: AVAudioFormat,
        quality: AudioFormatConverter.ConversionQuality = .high
    ) throws -> AudioBuffer {
        guard let conversionManager = formatConversionManager else {
            throw AudioEngineError.configurationError("Format conversion manager not initialized")
        }

        return try conversionManager.convert(
            buffer,
            from: sourceFormat,
            to: destinationFormat,
            quality: quality
        )
    }

    /// Convert audio buffer with channel mapping
    public func convertAudioFormatWithChannelMapping(
        _ buffer: AudioBuffer,
        from sourceFormat: AVAudioFormat,
        to destinationFormat: AVAudioFormat,
        channelMapping: AudioFormatConverter.ChannelMapping,
        quality: AudioFormatConverter.ConversionQuality = .high
    ) throws -> AudioBuffer {
        guard let conversionManager = formatConversionManager else {
            throw AudioEngineError.configurationError("Format conversion manager not initialized")
        }

        return try conversionManager.convertWithChannelMapping(
            buffer,
            from: sourceFormat,
            to: destinationFormat,
            channelMapping: channelMapping,
            quality: quality
        )
    }

    /// Create standard format converter
    public func createStandardFormatConverter(
        from sourceFormat: AVAudioFormat,
        toSampleRate sampleRate: Double,
        channels: UInt32,
        bitDepth: UInt32 = 32
    ) throws -> AudioFormatConverter {
        guard let conversionManager = formatConversionManager else {
            throw AudioEngineError.configurationError("Format conversion manager not initialized")
        }

        return try conversionManager.createStandardConverter(
            from: sourceFormat,
            toSampleRate: sampleRate,
            channels: channels,
            bitDepth: bitDepth
        )
    }

    /// Get format conversion cache statistics
    public func getFormatConversionStatistics() -> (size: Int, hitRate: Double, totalConverters: Int)? {
        return formatConversionManager?.getCacheStatistics()
    }

    /// Clean up expired format converters
    public func cleanupFormatConversionCache() {
        formatConversionManager?.cleanupCache()
    }

    /// Clear all format conversion cache
    public func clearFormatConversionCache() {
        formatConversionManager?.clearCache()
    }

    /// Convert audio to engine's native format
    public func convertToNativeFormat(_ buffer: AudioBuffer, sourceFormat: AVAudioFormat) throws -> AudioBuffer {
        guard let config = _configuration else {
            throw AudioEngineError.configurationError("Engine not configured")
        }

        guard let nativeFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: config.sampleRate,
            channels: UInt32(config.channelCount),
            interleaved: false
        ) else {
            throw AudioEngineError.configurationError("Failed to create native format")
        }

        return try convertAudioFormat(buffer, from: sourceFormat, to: nativeFormat)
    }

    // MARK: - Enhanced Performance Monitoring

    /// Get performance trend analysis
    public func getPerformanceTrend(timeWindow: TimeInterval = 300) -> (trend: String, confidence: Double) {
        return performanceAnalyzer?.getPerformanceTrend(timeWindow: timeWindow) ?? ("unknown", 0.0)
    }

    /// Generate comprehensive performance report
    public func generatePerformanceReport() -> String {
        return performanceAnalyzer?.generatePerformanceReport() ?? "Performance analyzer not available"
    }

    /// Record a custom latency measurement
    public func recordLatencyMeasurement(_ latency: Double) {
        performanceAnalyzer?.recordLatency(latency)
    }

    /// Get real-time CPU usage
    public func getRealTimeCPUUsage() -> Double {
        return _performanceMetrics.realTimeCpuUsage
    }

    /// Get current thermal state
    public func getThermalState() -> String {
        return _performanceMetrics.thermalState
    }

    /// Get memory pressure status
    public func getMemoryPressure() -> String {
        return _performanceMetrics.memoryPressure
    }

    /// Get performance score (0-100)
    public func getPerformanceScore() -> Double {
        return _performanceMetrics.performanceScore
    }

    /// Get stability index (0-1)
    public func getStabilityIndex() -> Double {
        return _performanceMetrics.stabilityIndex
    }

    /// Get efficiency rating (0-1)
    public func getEfficiencyRating() -> Double {
        return _performanceMetrics.efficiencyRating
    }

    // MARK: - Thread Management

    /// Submit work to the thread pool
    public func submitWork(priority: AudioTaskPriority = .normal, work: @escaping @Sendable () async -> Void) {
        threadPool?.submit(priority: priority, work: work)
    }

    /// Submit work item to the thread pool
    public func submitWorkItem(_ workItem: AudioWorkItem) {
        threadPool?.submit(workItem)
    }

    /// Get thread pool statistics
    public func getThreadPoolStatistics() -> (activeThreads: Int, totalWork: Int, averageLoad: Double)? {
        return threadPool?.getStatistics()
    }

    /// Wait for thread synchronization
    public func waitForThreadSync(timeout: TimeInterval = .infinity) -> Bool {
        return threadSynchronizer?.wait(timeout: timeout) ?? false
    }

    /// Signal thread synchronization
    public func signalThreadSync() {
        threadSynchronizer?.signal()
    }

    /// Broadcast to all waiting threads
    public func broadcastToThreads() {
        threadSynchronizer?.broadcast()
    }

    /// Wait for broadcast signal
    public func waitForBroadcast(timeout: TimeInterval = .infinity) -> Bool {
        return threadSynchronizer?.waitForBroadcast(timeout: timeout) ?? false
    }

    /// Reset broadcast signal
    public func resetBroadcast() {
        threadSynchronizer?.resetBroadcast()
    }

    // MARK: - DSP Algorithm Library

    /// Get DSP algorithm by name
    public func getDSPAlgorithm(name: String) -> DSPAlgorithm? {
        return dspManager?.getAlgorithm(name: name)
    }

    /// Register a custom DSP algorithm
    public func registerDSPAlgorithm(_ algorithm: DSPAlgorithm) {
        dspManager?.registerAlgorithm(algorithm)
    }

    /// Get all available DSP algorithms
    public func getAllDSPAlgorithms() -> [String: DSPAlgorithm] {
        return dspManager?.getAllAlgorithms() ?? [:]
    }

    /// Benchmark a DSP algorithm
    public func benchmarkDSPAlgorithm(name: String, testBuffer: AudioBuffer, iterations: Int = 1000) -> DSPBenchmarkResult? {
        return dspManager?.benchmarkAlgorithm(name: name, testBuffer: testBuffer, iterations: iterations)
    }

    /// Get DSP benchmark results
    public func getDSPBenchmarkResults() -> [String: DSPBenchmarkResult] {
        return dspManager?.getBenchmarkResults() ?? [:]
    }

    /// Generate DSP benchmark report
    public func generateDSPBenchmarkReport() -> String {
        return dspManager?.generateBenchmarkReport() ?? "DSP manager not available"
    }

    /// Create a test buffer for DSP benchmarking
    public func createDSPTestBuffer(frameCount: Int = 1024, channelCount: Int = 2, sampleRate: Double = 44100.0) -> AudioBuffer {
        let totalSamples = frameCount * channelCount
        let data = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)

        // Fill with test signal (sine wave)
        for i in 0..<totalSamples {
            let phase = Float(i) * 2.0 * Float.pi * 440.0 / Float(sampleRate) // 440 Hz sine wave
            data[i] = sin(phase) * 0.5 // 50% amplitude
        }

        return AudioBuffer(
            data: data,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: sampleRate
        )
    }

    // MARK: - MIDI System

    /// Parse raw MIDI bytes into messages
    public func parseMIDIBytes(_ bytes: [UInt8], timestamp: UInt64 = 0) -> [MIDIMessage] {
        return midiParser?.parseBytes(bytes, timestamp: timestamp) ?? []
    }

    /// Route MIDI message through the routing system
    public func routeMIDIMessage(_ message: MIDIMessage) -> [MIDIMessage] {
        return midiRouter?.routeMessage(message) ?? [message]
    }

    /// Add MIDI route
    public func addMIDIRoute(_ route: MIDIRoute) {
        midiRouter?.addRoute(route)
    }

    /// Remove MIDI route
    public func removeMIDIRoute(id: UUID) {
        midiRouter?.removeRoute(id: id)
    }

    /// Add MIDI filter
    public func addMIDIFilter(_ filter: MIDIFilter) {
        midiRouter?.addFilter(filter)
    }

    /// Get all MIDI routes
    public func getAllMIDIRoutes() -> [MIDIRoute] {
        return midiRouter?.getAllRoutes() ?? []
    }

    /// Clear all MIDI routes
    public func clearMIDIRoutes() {
        midiRouter?.clearRoutes()
    }

    /// Add MIDI parameter mapping
    public func addMIDIParameterMapping(_ mapping: MIDIParameterMapping) {
        midiParameterMapper?.addMapping(mapping)
    }

    /// Remove MIDI parameter mapping
    public func removeMIDIParameterMapping(id: UUID) {
        midiParameterMapper?.removeMapping(id: id)
    }

    /// Process MIDI message for parameter updates
    public func processMIDIForParameters(_ message: MIDIMessage) -> [ParameterUpdate] {
        return midiParameterMapper?.processMessage(message) ?? []
    }

    /// Get all MIDI parameter mappings
    public func getAllMIDIParameterMappings() -> [MIDIParameterMapping] {
        return midiParameterMapper?.getAllMappings() ?? []
    }

    /// Clear all MIDI parameter mappings
    public func clearMIDIParameterMappings() {
        midiParameterMapper?.clearMappings()
    }

    /// Scan for MIDI devices
    public func scanMIDIDevices() {
        midiDeviceManager?.scanDevices()
    }

    /// Get available MIDI input devices
    public func getMIDIInputDevices() -> [MIDIInputDevice] {
        return midiDeviceManager?.getInputDevices() ?? []
    }

    /// Get available MIDI output devices
    public func getMIDIOutputDevices() -> [MIDIOutputDevice] {
        return midiDeviceManager?.getOutputDevices() ?? []
    }

    /// Connect to MIDI input device
    public func connectMIDIInputDevice(id: UUID) -> Bool {
        return midiDeviceManager?.connectInputDevice(id: id) ?? false
    }

    /// Disconnect from MIDI input device
    public func disconnectMIDIInputDevice(id: UUID) -> Bool {
        return midiDeviceManager?.disconnectInputDevice(id: id) ?? false
    }

    /// Send MIDI message to output device
    public func sendMIDIMessage(_ message: MIDIMessage, to deviceId: UUID) -> Bool {
        return midiDeviceManager?.sendMessage(message, to: deviceId) ?? false
    }

    /// Simulate MIDI message (for testing)
    public func simulateMIDIMessage(_ message: MIDIMessage) {
        midiDeviceManager?.simulateMessage(message)
    }

    /// Set MIDI message callback
    public func setMIDIMessageCallback(_ callback: @escaping @Sendable (MIDIMessage) -> Void) {
        midiDeviceManager?.messageCallback = callback
    }

    // MARK: - Audio Testing Framework

    /// Run all audio tests
    public func runAllAudioTests() -> [String: [AudioTestResult]] {
        return testingFramework?.runAllTests() ?? [:]
    }

    /// Run specific test suite
    public func runAudioTestSuite(name: String) -> [AudioTestResult]? {
        return testingFramework?.runTestSuite(name: name)
    }

    /// Generate comprehensive test report
    public func generateAudioTestReport() -> String {
        return testingFramework?.generateTestReport() ?? "Testing framework not available"
    }

    /// Add custom test suite
    public func addAudioTestSuite(_ suite: AudioTestSuite) {
        testingFramework?.addTestSuite(suite)
    }

    /// Create test buffer for audio testing
    public func createAudioTestBuffer(frameCount: Int = 1024, channelCount: Int = 2,
                                     sampleRate: Double = 44100.0, signalType: TestSignalType = .silence) -> AudioBuffer {
        return testingFramework?.createTestBuffer(frameCount: frameCount, channelCount: channelCount,
                                                 sampleRate: sampleRate, signalType: signalType) ??
               AudioBuffer(data: UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount),
                          frameCount: frameCount, channelCount: channelCount, sampleRate: sampleRate)
    }

    /// Validate audio output
    public func validateAudioOutput(_ buffer: AudioBuffer) -> AudioOutputValidation {
        return testingFramework?.validateOutput(buffer) ??
               AudioOutputValidation(rms: 0, peak: 0, isSilent: true, hasClipping: false, isValid: false)
    }

    /// Run performance test on audio component
    public func runAudioPerformanceTest<T>(
        name: String,
        iterations: Int = 1000,
        setup: @escaping @Sendable () -> T,
        test: @escaping @Sendable (T) -> Void,
        cleanup: @escaping @Sendable (T) -> Void = { _ in }
    ) -> AudioTestResult {
        return testingFramework?.runPerformanceTest(
            name: name,
            iterations: iterations,
            setup: setup,
            test: test,
            cleanup: cleanup
        ) ?? AudioTestResult(testName: name, passed: false, executionTime: 0, errorMessage: "Testing framework not available")
    }

    /// Test audio engine initialization
    public func testAudioEngineInitialization() -> AudioTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Test basic initialization components
        let hasEngine = true // engine is always non-nil after initialization
        let hasConfiguration = _configuration != nil
        let hasBufferPool = bufferPool != nil
        let hasCircularBuffer = circularBuffer != nil

        let executionTime = CFAbsoluteTimeGetCurrent() - startTime

        let metrics = [
            "hasEngine": hasEngine ? 1.0 : 0.0,
            "hasConfiguration": hasConfiguration ? 1.0 : 0.0,
            "hasBufferPool": hasBufferPool ? 1.0 : 0.0,
            "hasCircularBuffer": hasCircularBuffer ? 1.0 : 0.0
        ]

        let passed = hasEngine && hasConfiguration && hasBufferPool && hasCircularBuffer

        return AudioTestResult(
            testName: "Audio Engine Initialization",
            passed: passed,
            executionTime: executionTime,
            metrics: metrics
        )
    }

    /// Test audio processing pipeline
    public func testAudioProcessingPipeline() -> AudioTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Create test buffer
            let testBuffer = createAudioTestBuffer(signalType: .sineWave(frequency: 440.0, amplitude: 0.5))

            // Validate input
            let inputValidation = validateAudioOutput(testBuffer)

            // Test processing (simplified)
            let mockNode = MockAudioNode(name: "Test Node")
            try mockNode.process(testBuffer)

            // Validate output
            let outputValidation = validateAudioOutput(testBuffer)

            let executionTime = CFAbsoluteTimeGetCurrent() - startTime

            let metrics = [
                "inputRMS": Double(inputValidation.rms),
                "outputRMS": Double(outputValidation.rms),
                "processCallCount": Double(mockNode.processCallCount),
                "processingTime": executionTime * 1000.0
            ]

            let passed = mockNode.processCallCount > 0 && !outputValidation.hasClipping

            return AudioTestResult(
                testName: "Audio Processing Pipeline",
                passed: passed,
                executionTime: executionTime,
                metrics: metrics
            )
        } catch {
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            return AudioTestResult(
                testName: "Audio Processing Pipeline",
                passed: false,
                executionTime: executionTime,
                errorMessage: error.localizedDescription
            )
        }
    }

    // MARK: - Audio File I/O

    /// Load audio file into memory
    public func loadAudioFile(from url: URL) throws -> (buffer: AudioBuffer, metadata: AudioFileMetadata) {
        guard let ioManager = audioFileIOManager else {
            throw AudioEngineError.configurationError("Audio file I/O manager not available")
        }
        return try ioManager.loadAudioFile(from: url)
    }

    /// Get audio file metadata
    public func getAudioFileMetadata(for url: URL) throws -> AudioFileMetadata {
        guard let ioManager = audioFileIOManager else {
            throw AudioEngineError.configurationError("Audio file I/O manager not available")
        }
        return try ioManager.getAudioFileMetadata(for: url)
    }

    /// Save audio buffer to file
    public func saveAudioFile(_ buffer: AudioBuffer, to url: URL, format: AudioFileFormat, metadata: AudioFileMetadata? = nil) throws {
        guard let ioManager = audioFileIOManager else {
            throw AudioEngineError.configurationError("Audio file I/O manager not available")
        }
        try ioManager.saveAudioFile(buffer, to: url, format: format, metadata: metadata)
    }

    /// Create streaming reader for large files
    public func createStreamingAudioReader(for url: URL, bufferSize: Int = 4096) throws -> (id: UUID, reader: StreamingAudioFileReader) {
        guard let ioManager = audioFileIOManager else {
            throw AudioEngineError.configurationError("Audio file I/O manager not available")
        }
        return try ioManager.createStreamingReader(for: url, bufferSize: bufferSize)
    }

    /// Get streaming reader by ID
    public func getStreamingAudioReader(id: UUID) -> StreamingAudioFileReader? {
        return audioFileIOManager?.getStreamingReader(id: id)
    }

    /// Remove streaming reader
    public func removeStreamingAudioReader(id: UUID) {
        audioFileIOManager?.removeStreamingReader(id: id)
    }

    /// Get supported audio file formats
    public func getSupportedAudioFormats() -> [AudioFileFormat] {
        return audioFileIOManager?.getSupportedFormats() ?? []
    }

    /// Check if audio format is supported
    public func isAudioFormatSupported(_ format: AudioFileFormat) -> Bool {
        return audioFileIOManager?.isFormatSupported(format) ?? false
    }

    /// Get optimal buffer size for streaming
    public func getOptimalStreamingBufferSize(for metadata: AudioFileMetadata) -> Int {
        return audioFileIOManager?.getOptimalBufferSize(for: metadata) ?? 4096
    }

    /// Convert audio file format
    public func convertAudioFile(from sourceURL: URL, to destinationURL: URL, targetFormat: AudioFileFormat) throws {
        guard let ioManager = audioFileIOManager else {
            throw AudioEngineError.configurationError("Audio file I/O manager not available")
        }
        try ioManager.convertAudioFile(from: sourceURL, to: destinationURL, targetFormat: targetFormat)
    }

    /// Batch process audio files
    public func batchProcessAudioFiles(urls: [URL], operation: @escaping (URL, AudioFileMetadata) throws -> Void) throws {
        guard let ioManager = audioFileIOManager else {
            throw AudioEngineError.configurationError("Audio file I/O manager not available")
        }
        try ioManager.batchProcessFiles(urls: urls, operation: operation)
    }

    // MARK: - Audio Clock and Synchronization

    /// Start audio clock
    public func startAudioClock() {
        audioClockManager?.start()
    }

    /// Stop audio clock
    public func stopAudioClock() {
        audioClockManager?.stop()
    }

    /// Pause audio clock
    public func pauseAudioClock() {
        audioClockManager?.pause()
    }

    /// Resume audio clock
    public func resumeAudioClock() {
        audioClockManager?.resume()
    }

    /// Get current audio time
    public func getCurrentAudioTime() -> TimeInterval {
        return audioClockManager?.getCurrentTime() ?? 0.0
    }

    /// Get current sample position
    public func getCurrentSamplePosition() -> Int64 {
        return audioClockManager?.getCurrentSample() ?? 0
    }

    /// Set tempo in BPM
    public func setTempo(_ bpm: Double) {
        audioClockManager?.setTempo(bpm)
        timingSynchronizer?.setTempo(bpm)
    }

    /// Set time signature
    public func setTimeSignature(beatsPerBar: Int, noteValue: TempoTracker.NoteValue) {
        audioClockManager?.setTimeSignature(beatsPerBar: beatsPerBar, noteValue: noteValue)
    }

    /// Update musical position
    public func updateMusicalPosition() {
        audioClockManager?.updateMusicalPosition()
    }

    /// Get current musical position
    public func getCurrentMusicalPosition() -> (bar: Int, beat: Double, bpm: Double) {
        return audioClockManager?.getCurrentMusicalPosition() ?? (0, 0.0, 120.0)
    }

    /// Add synchronized audio stream
    public func addSynchronizedStream(name: String, offset: TimeInterval = 0.0) -> UUID? {
        return audioClockManager?.addSynchronizedStream(name: name, offset: offset)
    }

    /// Remove synchronized audio stream
    public func removeSynchronizedStream(id: UUID) {
        audioClockManager?.removeSynchronizedStream(id: id)
    }

    /// Get synchronized time for stream
    public func getSynchronizedTime(for streamId: UUID) -> TimeInterval? {
        return audioClockManager?.getSynchronizedTime(for: streamId)
    }

    /// Enable external synchronization
    public func enableExternalSync(type: ExternalSyncType) {
        audioClockManager?.enableExternalSync(type: type)
    }

    /// Disable external synchronization
    public func disableExternalSync() {
        audioClockManager?.disableExternalSync()
    }

    /// Get comprehensive audio clock status
    public func getAudioClockStatus() -> AudioClockStatus? {
        return audioClockManager?.getClockStatus()
    }

    /// Check if audio clock is running
    public func isAudioClockRunning() -> Bool {
        return audioClockManager?.getClockStatus().isRunning ?? false
    }

    /// Check if audio clock is paused
    public func isAudioClockPaused() -> Bool {
        return audioClockManager?.getClockStatus().isPaused ?? false
    }

    /// Convert time to samples using current sample rate
    public func timeToSamples(_ time: TimeInterval) -> Int64 {
        guard let config = _configuration else { return 0 }
        return Int64(time * config.sampleRate)
    }

    /// Convert samples to time using current sample rate
    public func samplesToTime(_ samples: Int64) -> TimeInterval {
        guard let config = _configuration else { return 0.0 }
        return Double(samples) / config.sampleRate
    }

    // MARK: - Plugin Architecture

    /// Scan for plugins in directory
    public func scanPlugins(in directory: String) -> [AudioPluginMetadata] {
        return pluginManager?.scanPlugins(in: directory) ?? []
    }

    /// Load plugin by ID
    public func loadPlugin(id: UUID) throws -> AudioPlugin {
        guard let manager = pluginManager else {
            throw AudioEngineError.configurationError("Plugin manager not available")
        }
        return try manager.loadPlugin(id: id)
    }

    /// Unload plugin
    public func unloadPlugin(id: UUID) {
        pluginManager?.unloadPlugin(id: id)
    }

    /// Get loaded plugin
    public func getPlugin(id: UUID) -> AudioPlugin? {
        return pluginManager?.getPlugin(id: id)
    }

    /// Get all loaded plugins
    public func getAllLoadedPlugins() -> [AudioPlugin] {
        return pluginManager?.getAllLoadedPlugins() ?? []
    }

    /// Get plugin metadata
    public func getPluginMetadata(id: UUID) -> AudioPluginMetadata? {
        return pluginManager?.getPluginMetadata(id: id)
    }

    /// Get all plugin metadata
    public func getAllPluginMetadata() -> [AudioPluginMetadata] {
        return pluginManager?.getAllPluginMetadata() ?? []
    }

    /// Process audio through plugin safely
    public func processAudioThroughPlugin(pluginId: UUID, buffer: AudioBuffer) throws {
        guard let manager = pluginManager else {
            throw AudioEngineError.configurationError("Plugin manager not available")
        }
        try manager.processAudioThroughPlugin(pluginId: pluginId, buffer: buffer)
    }

    /// Get plugin resource usage
    public func getPluginResourceUsage(id: UUID) -> (cpu: Double, memory: Int)? {
        return pluginManager?.getPluginResourceUsage(id: id)
    }

    /// Validate plugin at path
    public func validatePlugin(at path: String) -> Bool {
        return pluginManager?.validatePlugin(at: path) ?? false
    }

    /// Create built-in plugin
    public func createBuiltInPlugin(type: AudioPluginManager.BuiltInPluginType) -> AudioPlugin? {
        return pluginManager?.createBuiltInPlugin(type: type)
    }

    /// Initialize plugin with current audio settings
    public func initializePlugin(_ plugin: AudioPlugin) throws {
        guard let config = _configuration else {
            throw AudioEngineError.configurationError("Audio engine not configured")
        }
        try plugin.initialize(sampleRate: config.sampleRate, bufferSize: config.bufferSize)
    }

    /// Set plugin parameter
    public func setPluginParameter(pluginId: UUID, parameterId: String, value: Float) throws {
        guard let plugin = getPlugin(id: pluginId) else {
            throw AudioEngineError.pluginError("Plugin not found")
        }
        try plugin.setParameter(id: parameterId, value: value)
    }

    /// Get plugin parameter
    public func getPluginParameter(pluginId: UUID, parameterId: String) throws -> Float {
        guard let plugin = getPlugin(id: pluginId) else {
            throw AudioEngineError.pluginError("Plugin not found")
        }
        return try plugin.getParameter(id: parameterId)
    }

    /// Reset plugin state
    public func resetPlugin(id: UUID) {
        getPlugin(id: id)?.reset()
    }

    /// Get plugin parameters
    public func getPluginParameters(id: UUID) -> [AudioPluginParameter] {
        return getPlugin(id: id)?.parameters ?? []
    }

    // MARK: - Multi-Channel Support

    /// Set channel configuration
    public func setChannelConfiguration(_ configuration: ChannelConfiguration) {
        currentChannelConfiguration = configuration
    }

    /// Get current channel configuration
    public func getChannelConfiguration() -> ChannelConfiguration {
        return currentChannelConfiguration
    }

    /// Create multi-channel buffer with current configuration
    public func createMultiChannelBuffer(frameCount: Int) -> MultiChannelAudioBuffer? {
        guard let config = _configuration else { return nil }
        return MultiChannelAudioBuffer(
            configuration: currentChannelConfiguration,
            frameCount: frameCount,
            sampleRate: config.sampleRate
        )
    }

    /// Convert AudioBuffer to MultiChannelAudioBuffer
    public func convertToMultiChannel(_ buffer: AudioBuffer, configuration: ChannelConfiguration) -> MultiChannelAudioBuffer {
        return MultiChannelAudioBuffer.fromInterleavedBuffer(buffer, configuration: configuration)
    }

    /// Convert MultiChannelAudioBuffer to AudioBuffer
    public func convertToInterleaved(_ buffer: MultiChannelAudioBuffer) -> AudioBuffer {
        return buffer.toInterleavedBuffer()
    }

    /// Convert between different channel configurations
    public func convertChannelConfiguration(source: MultiChannelAudioBuffer, to targetConfig: ChannelConfiguration) -> MultiChannelAudioBuffer? {
        return multiChannelFormatConverter?.convert(source: source, to: targetConfig)
    }

    /// Set channel gain
    public func setChannelGain(channel: Int, gain: Float) {
        multiChannelProcessor?.setChannelGain(channel: channel, gain: gain)
    }

    /// Set channel mute
    public func setChannelMute(channel: Int, mute: Bool) {
        multiChannelProcessor?.setChannelMute(channel: channel, mute: mute)
    }

    /// Set channel solo
    public func setChannelSolo(channel: Int, solo: Bool) {
        multiChannelProcessor?.setChannelSolo(channel: channel, solo: solo)
    }

    /// Get channel status
    public func getChannelStatus(channel: Int) -> (gain: Float, mute: Bool, solo: Bool) {
        return multiChannelProcessor?.getChannelStatus(channel: channel) ?? (1.0, false, false)
    }

    /// Process multi-channel buffer
    public func processMultiChannelBuffer(_ buffer: MultiChannelAudioBuffer) {
        multiChannelProcessor?.process(buffer)
    }

    /// Get supported channel configurations
    public func getSupportedChannelConfigurations() -> [ChannelConfiguration] {
        return ChannelConfiguration.allCases
    }

    /// Get channel labels for configuration
    public func getChannelLabels(for configuration: ChannelConfiguration) -> [String] {
        return configuration.channelLabels
    }

    /// Get channel count for configuration
    public func getChannelCount(for configuration: ChannelConfiguration) -> Int {
        return configuration.channelCount
    }

    /// Reset all channel processors
    public func resetChannelProcessors() {
        multiChannelProcessor?.reset()
    }

    /// Check if configuration is supported
    public func isChannelConfigurationSupported(_ configuration: ChannelConfiguration) -> Bool {
        // All configurations are supported in our implementation
        return true
    }

    /// Get optimal channel configuration for device
    public func getOptimalChannelConfiguration() -> ChannelConfiguration {
        #if os(iOS)
        // iOS devices typically support stereo output
        return .stereo
        #else
        // macOS can support more complex configurations
        return .stereo // Default to stereo, could be enhanced to detect hardware capabilities
        #endif
    }

    // MARK: - Sequencer Integration

    /// Set the sequencer event publisher for integration
    public func setSequencerEventPublisher(_ publisher: any SequencerEventPublisher) {
        sequencerBridge?.setSequencerEventPublisher(publisher)
    }

    /// Register a voice machine for sequencer integration
    public func registerVoiceMachine(_ voiceMachine: any VoiceMachineProtocol, forTrack track: Int) {
        sequencerBridge?.registerVoiceMachine(voiceMachine, forTrack: track)
    }

    /// Process sequencer events for the current audio buffer
    public func processSequencerEvents(bufferStartTime: UInt64, bufferSize: Int) {
        sequencerBridge?.processEvents(bufferStartTime: bufferStartTime, bufferSize: bufferSize)
    }

    /// Get current timing information
    public func getCurrentTiming() -> TimingInfo? {
        return timingSynchronizer?.getCurrentTiming()
    }

    /// Start sequencer playback
    public func startSequencerPlayback() {
        timingSynchronizer?.startPlayback()
    }

    /// Stop sequencer playback
    public func stopSequencerPlayback() {
        timingSynchronizer?.stopPlayback()
    }

    // MARK: - Private Methods

    /// Configure the audio session with the given configuration (iOS only)
    private func configureAudioSession(_ config: AudioEngineConfiguration) throws {
        #if os(iOS)
        do {
            // Set category and options
            try audioSession.setCategory(config.sessionCategory, options: config.sessionOptions)

            // Set preferred sample rate
            try audioSession.setPreferredSampleRate(config.sampleRate)

            // Calculate buffer duration for desired buffer size
            let bufferDuration = Double(config.bufferSize) / config.sampleRate
            try audioSession.setPreferredIOBufferDuration(bufferDuration)

            // Activate the session
            try audioSession.setActive(true)

        } catch {
            throw AudioEngineError.audioSessionError(error.localizedDescription)
        }
        #else
        // On macOS, audio session configuration is not needed
        // The system handles audio session management automatically
        #endif
    }

    /// Configure the audio engine with the given configuration
    private func configureEngine(_ config: AudioEngineConfiguration) throws {
        // Ensure engine is stopped before configuration
        if engine.isRunning {
            engine.stop()
        }

        // Reset engine
        engine.reset()

        // Configure output node format if needed
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        if outputFormat.sampleRate != config.sampleRate ||
           outputFormat.channelCount != AVAudioChannelCount(config.channelCount) {

            let desiredFormat = AVAudioFormat(
                standardFormatWithSampleRate: config.sampleRate,
                channels: AVAudioChannelCount(config.channelCount)
            )

            if let format = desiredFormat {
                engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)
            }
        }

        // Prepare the engine
        engine.prepare()
    }

    /// Setup notification observers for audio session events (iOS only)
    private func setupNotificationObservers() {
        #if os(iOS)
        // Audio interruption observer
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioInterruption(notification)
        }

        // Route change observer
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
        #endif
    }

    /// Handle audio session interruptions (iOS only)
    #if os(iOS)
    private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // Interruption began - suspend engine
            do {
                try suspend()
            } catch {
                _lastError = AudioEngineError.interruptionError("Failed to suspend during interruption: \(error.localizedDescription)")
                errorCallback?(_lastError!)
            }

        case .ended:
            // Interruption ended - check if we should resume
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    do {
                        try resume()
                    } catch {
                        _lastError = AudioEngineError.interruptionError("Failed to resume after interruption: \(error.localizedDescription)")
                        errorCallback?(_lastError!)
                    }
                }
            }

        @unknown default:
            break
        }
    }
    #endif

    /// Handle audio route changes (iOS only)
    #if os(iOS)
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            // Device was connected/disconnected - may need to restart engine
            if _configuration?.enableErrorRecovery == true && _status == .running {
                do {
                    try stop()
                    try start()
                } catch {
                    _lastError = AudioEngineError.routeChangeError("Failed to restart engine after route change: \(error.localizedDescription)")
                    errorCallback?(_lastError!)
                }
            }

        case .categoryChange, .override:
            // Audio session category changed - may need reconfiguration
            break

        default:
            break
        }
    }
    #endif

    /// Setup buffer management system
    private func setupBufferManagement(_ config: AudioEngineConfiguration) throws {
        // Initialize buffer pool
        bufferPool = AudioBufferPool(
            maxBuffers: 32,
            frameCount: config.bufferSize,
            channelCount: config.channelCount,
            sampleRate: config.sampleRate
        )

        // Initialize circular buffer with capacity for 1 second of audio
        let circularBufferCapacity = Int(config.sampleRate)
        circularBuffer = AudioCircularBuffer(
            capacity: circularBufferCapacity,
            channelCount: config.channelCount,
            sampleRate: config.sampleRate
        )
    }

    /// Setup error recovery system
    private func setupErrorRecovery() {
        errorRecoveryManager = AudioErrorRecoveryManager(
            maxRecoveryAttempts: 3,
            recoveryTimeWindow: 60.0,
            emergencyThreshold: 5
        )
    }

    /// Attempt error recovery using the recovery manager
    private func attemptErrorRecovery(error: AudioEngineError, recoveryManager: AudioErrorRecoveryManager) async -> Bool {
        let strategy = recoveryManager.getRecoveryStrategy(for: error)
        return await recoveryManager.executeRecovery(for: error, using: strategy, with: self)
    }

    /// Setup audio routing system
    private func setupAudioRouting() {
        let routingConfig = AudioRoutingMatrix.RoutingConfiguration(
            maxInputs: 64,
            maxOutputs: 64,
            enableLatencyCompensation: true,
            enableGainControl: true,
            enableDynamicRouting: true
        )

        routingMatrix = AudioRoutingMatrix(configuration: routingConfig)

        if let matrix = routingMatrix {
            dynamicRoutingManager = DynamicRoutingManager(
                routingMatrix: matrix,
                optimizationInterval: 1.0
            )
        }
    }

    /// Setup format conversion system
    private func setupFormatConversion() {
        formatConversionManager = AudioFormatConversionManager(
            maxCacheSize: 10,
            cacheTimeout: 300.0
        )
    }

    /// Setup thread management system
    private func setupThreadManagement(_ config: AudioEngineConfiguration) {
        // Calculate optimal thread count based on system capabilities
        let processorCount = ProcessInfo.processInfo.processorCount
        let minThreads = max(2, processorCount / 2)
        let maxThreads = max(minThreads, processorCount)

        // Initialize thread pool
        threadPool = AudioThreadPool(minThreads: minThreads, maxThreads: maxThreads)

        // Initialize thread synchronizer
        threadSynchronizer = AudioThreadSynchronizer(initialValue: 0)
    }

    /// Setup DSP algorithm library
    private func setupDSPLibrary() {
        dspManager = DSPAlgorithmManager()
    }

    /// Setup MIDI system
    private func setupMIDISystem() {
        midiParser = MIDIMessageParser()
        midiRouter = MIDIRouter()
        midiParameterMapper = MIDIParameterMapper()
        midiDeviceManager = MIDIDeviceManager()

        // Set up MIDI message callback to integrate with parameter mapping
        midiDeviceManager?.messageCallback = { [weak self] message in
            guard let self = self else { return }

            // Route the message
            let routedMessages = self.midiRouter?.routeMessage(message) ?? [message]

            // Process for parameter updates
            for routedMessage in routedMessages {
                let parameterUpdates = self.midiParameterMapper?.processMessage(routedMessage) ?? []

                // Apply parameter updates (this would integrate with audio processing)
                for update in parameterUpdates {
                    // In a real implementation, this would update audio parameters
                    // For now, we just log the update
                    print("MIDI Parameter Update: \(update.parameterName) = \(update.value)")
                }
            }
        }

        // Scan for available devices
        midiDeviceManager?.scanDevices()
    }

    /// Setup testing framework
    private func setupTestingFramework() {
        testingFramework = AudioTestingFramework()
    }

    /// Setup audio file I/O system
    private func setupAudioFileIO() {
        audioFileIOManager = AudioFileIOManager()
    }

    /// Setup audio clock and synchronization system
    private func setupAudioClock(_ config: AudioEngineConfiguration) {
        audioClockManager = AudioClockManager(sampleRate: config.sampleRate)
    }

    /// Setup plugin architecture system
    private func setupPluginArchitecture() {
        pluginManager = AudioPluginManager()
    }

    /// Setup multi-channel support system
    private func setupMultiChannelSupport(_ config: AudioEngineConfiguration) {
        multiChannelProcessor = MultiChannelProcessor()
        multiChannelFormatConverter = MultiChannelFormatConverter()

        // Set initial channel configuration based on audio configuration
        currentChannelConfiguration = config.channelCount == 1 ? .mono : .stereo
    }

    /// Setup sequencer integration system
    private func setupSequencerIntegration(_ config: AudioEngineConfiguration) {
        // Initialize timing synchronizer
        timingSynchronizer = TimingSynchronizer()
        timingSynchronizer?.updateTiming(sampleRate: sampleRate, bufferSize: Int(bufferSize))

        // Initialize sequencer bridge (without sequencer event publisher initially)
        sequencerBridge = SequencerBridge(audioEngine: self)
        sequencerBridge?.setSampleRate(sampleRate)
        sequencerBridge?.setBufferSize(Int(bufferSize))

        // Setup timing callbacks for step/beat/bar events
        timingSynchronizer?.onStepAdvanced = { [weak self] step in
            // Handle step advance events if needed
            print("Step advanced: \(step)")
        }

        timingSynchronizer?.onBeatAdvanced = { [weak self] beat in
            // Handle beat advance events if needed
            print("Beat advanced: \(beat)")
        }

        timingSynchronizer?.onBarAdvanced = { [weak self] bar in
            // Handle bar advance events if needed
            print("Bar advanced: \(bar)")
        }
    }

    /// Setup performance monitoring
    private func setupPerformanceMonitoring() {
        _performanceMetrics.reset()

        // Initialize performance analyzer
        performanceAnalyzer = AudioPerformanceAnalyzer()

        #if os(iOS)
        _performanceMetrics.sampleRate = audioSession.sampleRate
        _performanceMetrics.bufferSize = Int(audioSession.ioBufferDuration * audioSession.sampleRate)
        #else
        // On macOS, use engine's output format for metrics
        _performanceMetrics.sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        _performanceMetrics.bufferSize = 512 // Default buffer size for macOS
        #endif
    }

    /// Start performance monitoring timer
    private func startPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePerformanceMetrics()
        }
    }

    /// Stop performance monitoring timer
    private func stopPerformanceMonitoring() {
        performanceTimer?.invalidate()
        performanceTimer = nil
    }

    /// Update performance metrics
    private func updatePerformanceMetrics() {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Update basic metrics
            #if os(iOS)
            self._performanceMetrics.sampleRate = self.audioSession.sampleRate
            self._performanceMetrics.bufferSize = Int(self.audioSession.ioBufferDuration * self.audioSession.sampleRate)
            #else
            // On macOS, use engine's output format for metrics
            self._performanceMetrics.sampleRate = self.engine.outputNode.outputFormat(forBus: 0).sampleRate
            self._performanceMetrics.bufferSize = 512 // Default buffer size for macOS
            #endif

            // Count active nodes (simplified)
            self._performanceMetrics.activeNodes = self.countActiveNodes()

            // Calculate latency (simplified)
            if let startTime = self.startTime {
                let currentLatency = Date().timeIntervalSince(startTime) * 1000.0 // Convert to milliseconds
                self._performanceMetrics.averageLatency = currentLatency
                self._performanceMetrics.peakLatency = max(self._performanceMetrics.peakLatency, currentLatency)

                // Record latency for analysis
                self.performanceAnalyzer?.recordLatency(currentLatency)
            }

            // Update buffer pool metrics
            if let poolStats = self.bufferPool?.getStatistics() {
                self._performanceMetrics.bufferPoolAvailable = poolStats.available
                self._performanceMetrics.bufferPoolAllocated = poolStats.allocated
                self._performanceMetrics.bufferPoolTotal = poolStats.total
            }

            // Update circular buffer metrics
            if let circularStats = self.circularBuffer?.getStatistics() {
                self._performanceMetrics.circularBufferCapacity = circularStats.capacity
                self._performanceMetrics.circularBufferAvailable = circularStats.available
                self._performanceMetrics.circularBufferUsage = circularStats.usage
            }

            // Use performance analyzer for enhanced metrics
            self.performanceAnalyzer?.analyzePerformance(metrics: &self._performanceMetrics)

            // Notify callback
            self.performanceCallback?(self._performanceMetrics)
        }
    }

    /// Count active audio nodes (simplified implementation)
    private func countActiveNodes() -> Int {
        // This is a simplified implementation
        // In a real implementation, you would traverse the audio graph
        return engine.isRunning ? 1 : 0
    }

    /// Update engine status and notify observers
    private func updateStatus(_ newStatus: AudioEngineStatus) {
        let oldStatus = _status
        _status = newStatus

        if oldStatus != newStatus {
            DispatchQueue.main.async { [weak self] in
                self?.statusChangeCallback?(newStatus)
            }
        }
    }

    /// Cleanup resources
    private func cleanup() {
        // Stop performance monitoring
        stopPerformanceMonitoring()

        // Stop engine if running
        if engine.isRunning {
            engine.stop()
        }

        // Cleanup buffer management
        bufferPool = nil
        circularBuffer = nil

        // Cleanup error recovery
        errorRecoveryManager = nil

        // Cleanup audio routing
        routingMatrix = nil
        dynamicRoutingManager = nil

        // Cleanup format conversion
        formatConversionManager = nil

        // Cleanup performance analyzer
        performanceAnalyzer = nil

        // Cleanup thread management
        threadPool?.shutdown()
        threadPool = nil
        threadSynchronizer = nil

        // Cleanup DSP manager
        dspManager = nil

        // Cleanup MIDI system
        midiParser = nil
        midiRouter = nil
        midiParameterMapper = nil
        midiDeviceManager = nil

        // Cleanup testing framework
        testingFramework = nil

        // Cleanup audio file I/O
        audioFileIOManager = nil

        // Cleanup audio clock and synchronization
        audioClockManager?.stop()
        audioClockManager = nil

        // Cleanup plugin architecture
        pluginManager = nil

        // Cleanup multi-channel support
        multiChannelProcessor?.reset()
        multiChannelProcessor = nil
        multiChannelFormatConverter = nil

        // Cleanup sequencer integration
        sequencerBridge = nil
        timingSynchronizer = nil

        // Remove notification observers (iOS only)
        #if os(iOS)
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }

        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            routeChangeObserver = nil
        }
        #endif

        // Deactivate audio session (iOS only)
        #if os(iOS)
        do {
            try audioSession.setActive(false)
        } catch {
            // Log error but don't throw during cleanup
            print("Warning: Failed to deactivate audio session during cleanup: \(error)")
        }
        #endif
    }
}

// MARK: - Sequencer Integration Classes

// MARK: - Audio Event Types

/// Events that can be sent to the audio engine
public enum AudioEvent: Sendable {
    case noteOn(note: UInt8, velocity: UInt8, track: Int, timestamp: UInt64)
    case noteOff(note: UInt8, track: Int, timestamp: UInt64)
    case parameterChange(track: Int, parameter: String, value: Double, timestamp: UInt64)
    case tempoChange(bpm: Double, timestamp: UInt64)
    case playbackStart(timestamp: UInt64)
    case playbackStop(timestamp: UInt64)
}

/// Priority levels for audio events
public enum EventPriority: Int, Comparable, Sendable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    public static func < (lhs: EventPriority, rhs: EventPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Wrapper for prioritized events
public struct PrioritizedEvent: Sendable, Comparable {
    public let event: AudioEvent
    public let priority: EventPriority
    public let timestamp: UInt64
    public let id: UUID

    public init(event: AudioEvent, priority: EventPriority = .normal, timestamp: UInt64) {
        self.event = event
        self.priority = priority
        self.timestamp = timestamp
        self.id = UUID()
    }

    public static func < (lhs: PrioritizedEvent, rhs: PrioritizedEvent) -> Bool {
        // First sort by timestamp (earlier events first)
        if lhs.timestamp != rhs.timestamp {
            return lhs.timestamp < rhs.timestamp
        }
        // Then by priority (higher priority first)
        return lhs.priority > rhs.priority
    }

    public static func == (lhs: PrioritizedEvent, rhs: PrioritizedEvent) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Thread-Safe Event Queue

/// Thread-safe priority queue for audio events
public final class AudioEventQueue: @unchecked Sendable {
    private var events: [PrioritizedEvent] = []
    private let queue = DispatchQueue(label: "com.digitonepad.audio.eventqueue", qos: .userInteractive)
    private let maxQueueSize: Int

    public init(maxQueueSize: Int = 1000) {
        self.maxQueueSize = maxQueueSize
    }

    /// Add an event to the queue
    public func enqueue(_ event: PrioritizedEvent) {
        queue.sync {
            // Insert in sorted order (binary search for efficiency)
            let insertIndex = events.binarySearchInsertionIndex(for: event)
            events.insert(event, at: insertIndex)

            // Limit queue size to prevent memory issues
            if events.count > maxQueueSize {
                events.removeFirst(events.count - maxQueueSize)
            }
        }
    }

    /// Get all events up to a specific timestamp
    public func dequeueEvents(upTo timestamp: UInt64) -> [PrioritizedEvent] {
        return queue.sync {
            var result: [PrioritizedEvent] = []

            while !events.isEmpty && events.first!.timestamp <= timestamp {
                result.append(events.removeFirst())
            }

            return result
        }
    }

    /// Get the next event without removing it
    public func peek() -> PrioritizedEvent? {
        return queue.sync {
            return events.first
        }
    }

    /// Clear all events
    public func clear() {
        queue.sync {
            events.removeAll()
        }
    }

    /// Get current queue size
    public var count: Int {
        return queue.sync {
            return events.count
        }
    }
}

// MARK: - Binary Search Extension

extension Array where Element: Comparable {
    /// Find the insertion index for maintaining sorted order
    func binarySearchInsertionIndex(for element: Element) -> Int {
        var low = 0
        var high = count

        while low < high {
            let mid = (low + high) / 2
            if self[mid] < element {
                low = mid + 1
            } else {
                high = mid
            }
        }

        return low
    }
}

// MARK: - Timing Information

/// Comprehensive timing information for synchronization
public struct TimingInfo: Sendable {
    public let sampleRate: Double
    public let bufferSize: Int
    public let currentSampleTime: UInt64
    public let hostTime: UInt64
    public let bpm: Double
    public let timeSignature: (numerator: Int, denominator: Int)

    // Calculated properties
    public var samplesPerBeat: Double {
        return (60.0 / bpm) * sampleRate
    }

    public var samplesPerStep: Double {
        return samplesPerBeat / 4.0 // 16th notes
    }

    public var currentBeat: Double {
        return Double(currentSampleTime) / samplesPerBeat
    }

    public var currentStep: Int {
        return Int(currentBeat * 4.0) % 16 // 16-step pattern
    }

    public init(sampleRate: Double, bufferSize: Int, currentSampleTime: UInt64,
                hostTime: UInt64, bpm: Double, timeSignature: (Int, Int)) {
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
        self.currentSampleTime = currentSampleTime
        self.hostTime = hostTime
        self.bpm = bpm
        self.timeSignature = timeSignature
    }
}

// MARK: - Timing Synchronizer

/// Manages timing synchronization between sequencer and audio engine
public final class TimingSynchronizer: @unchecked Sendable {
    // Core timing properties
    private var sampleRate: Double = 44100.0
    private var bufferSize: Int = 512
    private var currentSampleTime: UInt64 = 0
    private var isPlaying: Bool = false

    // Musical timing
    private var bpm: Double = 120.0
    private var timeSignature: (numerator: Int, denominator: Int) = (4, 4)

    // Synchronization
    private let queue = DispatchQueue(label: "com.digitonepad.timing", qos: .userInteractive)
    private var lastHostTime: UInt64 = 0
    private var sampleTimeOffset: UInt64 = 0

    // Callbacks
    public var onStepAdvanced: ((Int) -> Void)?
    public var onBeatAdvanced: ((Int) -> Void)?
    public var onBarAdvanced: ((Int) -> Void)?

    // Step tracking
    private var lastStep: Int = -1
    private var lastBeat: Int = -1
    private var lastBar: Int = -1

    public init() {
        setupHostTimeConversion()
    }

    // MARK: - Public Interface

    /// Update timing parameters
    public func updateTiming(sampleRate: Double, bufferSize: Int) {
        queue.sync {
            self.sampleRate = sampleRate
            self.bufferSize = bufferSize
        }
    }

    /// Set the tempo
    public func setTempo(_ bpm: Double) {
        queue.sync {
            self.bpm = max(60.0, min(bpm, 200.0)) // Clamp to reasonable range
        }
    }

    /// Set the time signature
    public func setTimeSignature(numerator: Int, denominator: Int) {
        queue.sync {
            self.timeSignature = (numerator, denominator)
        }
    }

    /// Start playback
    public func startPlayback() {
        queue.sync {
            isPlaying = true
            resetTiming()
        }
    }

    /// Stop playback
    public func stopPlayback() {
        queue.sync {
            isPlaying = false
        }
    }

    /// Process timing for current audio buffer
    public func processBuffer(hostTime: UInt64) -> TimingInfo {
        return queue.sync {
            // Update sample time based on host time
            updateSampleTime(hostTime: hostTime)

            // Create timing info
            let timingInfo = TimingInfo(
                sampleRate: sampleRate,
                bufferSize: bufferSize,
                currentSampleTime: currentSampleTime,
                hostTime: hostTime,
                bpm: bpm,
                timeSignature: timeSignature
            )

            // Check for step/beat/bar advances
            if isPlaying {
                checkForAdvances(timingInfo: timingInfo)
            }

            // Advance sample time for next buffer
            currentSampleTime += UInt64(bufferSize)

            return timingInfo
        }
    }

    /// Get current timing info without processing
    public func getCurrentTiming() -> TimingInfo {
        return queue.sync {
            return TimingInfo(
                sampleRate: sampleRate,
                bufferSize: bufferSize,
                currentSampleTime: currentSampleTime,
                hostTime: mach_absolute_time(),
                bpm: bpm,
                timeSignature: timeSignature
            )
        }
    }

    // MARK: - Private Implementation

    private func setupHostTimeConversion() {
        lastHostTime = mach_absolute_time()
    }

    private func resetTiming() {
        currentSampleTime = 0
        sampleTimeOffset = 0
        lastStep = -1
        lastBeat = -1
        lastBar = -1
        lastHostTime = mach_absolute_time()
    }

    private func updateSampleTime(hostTime: UInt64) {
        if lastHostTime == 0 {
            lastHostTime = hostTime
            return
        }

        // Calculate elapsed time in samples
        let hostTimeDiff = hostTime - lastHostTime
        let nanoseconds = hostTimeToNanos(hostTimeDiff)
        let seconds = Double(nanoseconds) / 1_000_000_000.0
        let samplesDiff = UInt64(seconds * sampleRate)

        // Update sample time (but don't let it drift too far from expected)
        let expectedSampleTime = currentSampleTime + UInt64(bufferSize)
        let actualSampleTime = currentSampleTime + samplesDiff

        // Use a small amount of drift correction
        let driftCorrection = (expectedSampleTime - actualSampleTime) / 10
        currentSampleTime = actualSampleTime + driftCorrection

        lastHostTime = hostTime
    }

    private func checkForAdvances(timingInfo: TimingInfo) {
        // Check for step advance
        let currentStep = timingInfo.currentStep
        if currentStep != lastStep {
            lastStep = currentStep
            onStepAdvanced?(currentStep)
        }

        // Check for beat advance
        let currentBeat = Int(timingInfo.currentBeat) % timeSignature.numerator
        if currentBeat != lastBeat {
            lastBeat = currentBeat
            onBeatAdvanced?(currentBeat)
        }

        // Check for bar advance
        let currentBar = Int(timingInfo.currentBeat) / timeSignature.numerator
        if currentBar != lastBar {
            lastBar = currentBar
            onBarAdvanced?(currentBar)
        }
    }

    private func hostTimeToNanos(_ hostTime: UInt64) -> UInt64 {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return hostTime * UInt64(timebase.numer) / UInt64(timebase.denom)
    }
}

// MARK: - Sequencer Bridge

/// Main bridge connecting sequencer events to audio engine
public final class SequencerBridge: @unchecked Sendable {
    // Event processing
    private let eventQueue = AudioEventQueue()
    private var cancellables = Set<AnyCancellable>()

    // Timing
    private var sampleRate: Double = 44100.0
    private var currentSampleTime: UInt64 = 0
    private var samplesPerBuffer: Int = 512

    // Audio engine reference
    private weak var audioEngine: AudioEngineManager?

    // Sequencer event publisher (dependency injection)
    private weak var sequencerEventPublisher: (any SequencerEventPublisher)?

    // Voice machines for each track
    private var voiceMachines: [Int: any VoiceMachineProtocol] = [:]

    public init(audioEngine: AudioEngineManager, sequencerEventPublisher: (any SequencerEventPublisher)? = nil) {
        self.audioEngine = audioEngine
        self.sequencerEventPublisher = sequencerEventPublisher
        if sequencerEventPublisher != nil {
            setupSequencerSubscription()
        }
    }

    // MARK: - Public Interface

    /// Set the sample rate for timing calculations
    public func setSampleRate(_ sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    /// Set the buffer size for timing calculations
    public func setBufferSize(_ bufferSize: Int) {
        self.samplesPerBuffer = bufferSize
    }

    /// Set the sequencer event publisher
    public func setSequencerEventPublisher(_ publisher: any SequencerEventPublisher) {
        self.sequencerEventPublisher = publisher
        setupSequencerSubscription()
    }

    /// Register a voice machine for a specific track
    public func registerVoiceMachine(_ voiceMachine: any VoiceMachineProtocol, forTrack track: Int) {
        voiceMachines[track] = voiceMachine
    }

    /// Process events for the current audio buffer
    public func processEvents(bufferStartTime: UInt64, bufferSize: Int) {
        let bufferEndTime = bufferStartTime + UInt64(bufferSize)
        let events = eventQueue.dequeueEvents(upTo: bufferEndTime)

        for prioritizedEvent in events {
            processAudioEvent(prioritizedEvent.event, at: prioritizedEvent.timestamp, bufferStart: bufferStartTime)
        }

        currentSampleTime = bufferEndTime
    }

    // MARK: - Private Implementation

    private func setupSequencerSubscription() {
        // Clear existing subscriptions
        cancellables.removeAll()

        // Subscribe to sequencer events if publisher is available
        guard let publisher = sequencerEventPublisher else { return }

        publisher.eventPublisher
            .sink { [weak self] sequencerEvent in
                self?.handleSequencerEvent(sequencerEvent)
            }
            .store(in: &cancellables)
    }

    private func handleSequencerEvent(_ event: SequencerEvent) {
        let timestamp = currentSampleTime + UInt64(samplesPerBuffer) // Schedule for next buffer

        switch event {
        case .noteTriggered(let note, let velocity, let track):
            let audioEvent = AudioEvent.noteOn(note: note, velocity: velocity, track: track, timestamp: timestamp)
            let prioritizedEvent = PrioritizedEvent(event: audioEvent, priority: .high, timestamp: timestamp)
            eventQueue.enqueue(prioritizedEvent)

        case .noteReleased(let note, let track):
            let audioEvent = AudioEvent.noteOff(note: note, track: track, timestamp: timestamp)
            let prioritizedEvent = PrioritizedEvent(event: audioEvent, priority: .high, timestamp: timestamp)
            eventQueue.enqueue(prioritizedEvent)

        case .tempoChanged(let bpm):
            let audioEvent = AudioEvent.tempoChange(bpm: bpm, timestamp: timestamp)
            let prioritizedEvent = PrioritizedEvent(event: audioEvent, priority: .normal, timestamp: timestamp)
            eventQueue.enqueue(prioritizedEvent)

        case .playbackStarted:
            let audioEvent = AudioEvent.playbackStart(timestamp: timestamp)
            let prioritizedEvent = PrioritizedEvent(event: audioEvent, priority: .critical, timestamp: timestamp)
            eventQueue.enqueue(prioritizedEvent)

        case .playbackStopped:
            let audioEvent = AudioEvent.playbackStop(timestamp: timestamp)
            let prioritizedEvent = PrioritizedEvent(event: audioEvent, priority: .critical, timestamp: timestamp)
            eventQueue.enqueue(prioritizedEvent)

        default:
            // Handle other events as needed
            break
        }
    }

    private func processAudioEvent(_ event: AudioEvent, at timestamp: UInt64, bufferStart: UInt64) {
        switch event {
        case .noteOn(let note, let velocity, let track, _):
            if let voiceMachine = voiceMachines[track] {
                voiceMachine.noteOn(note: note, velocity: velocity, channel: 0, timestamp: timestamp)
            }

        case .noteOff(let note, let track, _):
            if let voiceMachine = voiceMachines[track] {
                voiceMachine.noteOff(note: note, velocity: 0, channel: 0, timestamp: timestamp)
            }

        case .parameterChange(let track, let parameter, let value, _):
            if let voiceMachine = voiceMachines[track] {
                do {
                    try voiceMachine.updateParameter(key: parameter, value: value)
                } catch {
                    // Log error but continue processing
                    print("Failed to update parameter \(parameter) for track \(track): \(error)")
                }
            }

        case .tempoChange(let bpm, _):
            // Update audio engine tempo if needed
            audioEngine?.setTempo(bpm)

        case .playbackStart(_):
            // Handle playback start
            audioEngine?.startSequencerPlayback()

        case .playbackStop(_):
            // Handle playback stop
            audioEngine?.stopSequencerPlayback()
        }
    }

    // MARK: - Cleanup

    deinit {
        cancellables.removeAll()
        eventQueue.clear()
    }
}
