// FMToneAlgorithmRouter.swift
// DigitonePad - VoiceModule
//
// Dynamic Algorithm Routing System for FM TONE Voice Machine

import Foundation
import Accelerate
import MachineProtocols

// MARK: - Algorithm Processing Order

/// Manages the processing order for operators to ensure proper signal flow
public struct AlgorithmProcessingOrder {
    public let operatorOrder: [Int]
    public let hasFeedback: Bool
    public let feedbackConnections: [FMConnection]
    
    public init(algorithm: FMAlgorithm) {
        (self.operatorOrder, self.hasFeedback, self.feedbackConnections) = Self.calculateProcessingOrder(for: algorithm)
    }
    
    /// Calculate optimal processing order using topological sort
    private static func calculateProcessingOrder(for algorithm: FMAlgorithm) -> ([Int], Bool, [FMConnection]) {
        let operatorCount = 4
        var inDegree = Array(repeating: 0, count: operatorCount)
        var adjList = Array(repeating: [Int](), count: operatorCount)
        var feedbackConnections: [FMConnection] = []
        
        // Build adjacency list and detect feedback
        for connection in algorithm.connections {
            if connection.source >= connection.destination {
                // This is feedback - process separately
                feedbackConnections.append(connection)
            } else {
                adjList[connection.source].append(connection.destination)
                inDegree[connection.destination] += 1
            }
        }
        
        // Topological sort for non-feedback connections
        var queue: [Int] = []
        var result: [Int] = []
        
        // Find operators with no incoming edges (start points)
        for i in 0..<operatorCount {
            if inDegree[i] == 0 {
                queue.append(i)
            }
        }
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            result.append(current)
            
            for neighbor in adjList[current] {
                inDegree[neighbor] -= 1
                if inDegree[neighbor] == 0 {
                    queue.append(neighbor)
                }
            }
        }
        
        // Add any remaining operators (shouldn't happen in well-formed algorithms)
        for i in 0..<operatorCount {
            if !result.contains(i) {
                result.append(i)
            }
        }
        
        return (result, !feedbackConnections.isEmpty, feedbackConnections)
    }
}

// MARK: - Algorithm Transition Manager

/// Manages smooth transitions between algorithms to avoid audio artifacts
public final class AlgorithmTransitionManager: @unchecked Sendable {
    private var isTransitioning: Bool = false
    private var transitionProgress: Float = 0.0
    private var transitionSamples: Int = 0
    private var targetTransitionSamples: Int = 0
    
    // Cross-fade buffers for smooth transitions
    private var oldAlgorithmBuffer: [Float] = []
    private var newAlgorithmBuffer: [Float] = []
    
    public init() {
        // Default transition time: 10ms at 44.1kHz
        self.targetTransitionSamples = Int(0.01 * 44100)
    }
    
    public func startTransition(transitionTimeMs: Double = 10.0, sampleRate: Double = 44100.0) {
        isTransitioning = true
        transitionProgress = 0.0
        transitionSamples = 0
        targetTransitionSamples = Int(transitionTimeMs * 0.001 * sampleRate)
        
        // Pre-allocate buffers
        let bufferSize = targetTransitionSamples
        oldAlgorithmBuffer = Array(repeating: 0.0, count: bufferSize)
        newAlgorithmBuffer = Array(repeating: 0.0, count: bufferSize)
    }
    
    public func processTransition(oldOutput: Float, newOutput: Float) -> Float {
        guard isTransitioning else { return newOutput }
        
        // Calculate cross-fade amount
        let fadeAmount = Float(transitionSamples) / Float(targetTransitionSamples)
        let smoothFade = 0.5 * (1.0 + sin(Float.pi * (fadeAmount - 0.5)))
        
        // Cross-fade between old and new
        let result = oldOutput * (1.0 - smoothFade) + newOutput * smoothFade
        
        transitionSamples += 1
        if transitionSamples >= targetTransitionSamples {
            isTransitioning = false
        }
        
        return result
    }
    
    public var isActive: Bool { isTransitioning }
}

// MARK: - Algorithm Visualization Data

/// Provides data structures for UI visualization of algorithms
public struct AlgorithmVisualizationData {
    public let nodes: [OperatorNode]
    public let connections: [ConnectionEdge]
    public let layout: AlgorithmLayout
    
    public init(algorithm: FMAlgorithm) {
        self.nodes = Self.createNodes(for: algorithm)
        self.connections = Self.createConnections(for: algorithm)
        self.layout = Self.calculateLayout(for: algorithm)
    }
    
    private static func createNodes(for algorithm: FMAlgorithm) -> [OperatorNode] {
        let carriers = algorithm.carrierOperators
        let modulators = algorithm.modulatorOperators
        
        return (0..<4).map { index in
            let type: OperatorNodeType
            if carriers.contains(index) {
                type = .carrier
            } else if modulators.contains(index) {
                type = .modulator
            } else {
                type = .inactive
            }
            
            return OperatorNode(
                id: index,
                name: ["C", "A", "B1", "B2"][index],
                type: type,
                position: CGPoint(x: 0, y: 0) // Will be calculated by layout
            )
        }
    }
    
    private static func createConnections(for algorithm: FMAlgorithm) -> [ConnectionEdge] {
        return algorithm.connections.map { connection in
            ConnectionEdge(
                source: connection.source,
                destination: connection.destination,
                strength: Float(connection.amount),
                isFeedback: connection.source >= connection.destination
            )
        }
    }
    
    private static func calculateLayout(for algorithm: FMAlgorithm) -> AlgorithmLayout {
        // Simple grid layout - could be enhanced with force-directed layout
        let positions: [CGPoint] = [
            CGPoint(x: 150, y: 200), // C (Carrier - center right)
            CGPoint(x: 100, y: 150), // A (top left)
            CGPoint(x: 100, y: 250), // B1 (bottom left)  
            CGPoint(x: 50, y: 200)   // B2 (far left)
        ]
        
        return AlgorithmLayout(
            operatorPositions: positions,
            canvasSize: CGSize(width: 200, height: 300),
            scale: 1.0
        )
    }
}

public struct OperatorNode {
    public let id: Int
    public let name: String
    public let type: OperatorNodeType
    public let position: CGPoint
}

public enum OperatorNodeType {
    case carrier
    case modulator
    case inactive
}

public struct ConnectionEdge {
    public let source: Int
    public let destination: Int
    public let strength: Float
    public let isFeedback: Bool
}

public struct AlgorithmLayout {
    public let operatorPositions: [CGPoint]
    public let canvasSize: CGSize
    public let scale: Double
}

// MARK: - Algorithm Router

/// Main routing system that manages signal flow and algorithm switching
public final class FMToneAlgorithmRouter: @unchecked Sendable {
    
    // Current algorithm state
    private var currentAlgorithm: FMAlgorithm
    private var processingOrder: AlgorithmProcessingOrder
    private var transitionManager: AlgorithmTransitionManager
    
    // Performance optimization
    private var cachedModulationLookup: [[Double]] = []
    private var operatorOutputBuffer: [Double] = []
    
    // Statistics and monitoring
    private var processingTime: TimeInterval = 0.0
    private var algorithmSwitches: Int = 0
    
    public init(initialAlgorithm: FMAlgorithm = FMToneAlgorithms.algorithm1) {
        self.currentAlgorithm = initialAlgorithm
        self.processingOrder = AlgorithmProcessingOrder(algorithm: initialAlgorithm)
        self.transitionManager = AlgorithmTransitionManager()
        
        setupOptimizations()
    }
    
    private func setupOptimizations() {
        // Pre-allocate buffers
        operatorOutputBuffer = Array(repeating: 0.0, count: 4)
        
        // Pre-compute modulation lookup table
        rebuildModulationLookup()
    }
    
    private func rebuildModulationLookup() {
        // Create 4x4 lookup table for modulation amounts
        cachedModulationLookup = Array(repeating: Array(repeating: 0.0, count: 4), count: 4)
        
        for connection in currentAlgorithm.connections {
            cachedModulationLookup[connection.source][connection.destination] = connection.amount
        }
    }
    
    // MARK: - Algorithm Management
    
    /// Switch to a new algorithm with smooth transition
    public func switchAlgorithm(to newAlgorithm: FMAlgorithm, transitionTimeMs: Double = 10.0, sampleRate: Double = 44100.0) {
        guard newAlgorithm.id != currentAlgorithm.id else { return }
        
        // Start transition
        transitionManager.startTransition(transitionTimeMs: transitionTimeMs, sampleRate: sampleRate)
        
        // Update internal state
        currentAlgorithm = newAlgorithm
        processingOrder = AlgorithmProcessingOrder(algorithm: newAlgorithm)
        rebuildModulationLookup()
        
        algorithmSwitches += 1
    }
    
    /// Switch to algorithm by ID (1-8)
    public func switchAlgorithm(toId algorithmId: Int, transitionTimeMs: Double = 10.0, sampleRate: Double = 44100.0) {
        guard let algorithm = FMToneAlgorithms.algorithm(id: algorithmId) else { return }
        switchAlgorithm(to: algorithm, transitionTimeMs: transitionTimeMs, sampleRate: sampleRate)
    }
    
    // MARK: - Signal Processing
    
    /// Process operators according to current algorithm routing
    /// Returns the final audio output
    public func processOperators(_ operators: [FMOperator]) -> Double {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Clear output buffer
        for i in 0..<4 {
            operatorOutputBuffer[i] = 0.0
        }
        
        // Process operators in dependency order
        for operatorIndex in processingOrder.operatorOrder {
            guard operatorIndex < operators.count else { continue }
            
            // Calculate modulation input for this operator
            var modulationInput: Double = 0.0
            
            // Use cached lookup for performance
            for sourceIndex in 0..<4 {
                let amount = cachedModulationLookup[sourceIndex][operatorIndex]
                if amount > 0.0 {
                    modulationInput += operatorOutputBuffer[sourceIndex] * amount
                }
            }
            
            // Process the operator
            operatorOutputBuffer[operatorIndex] = operators[operatorIndex].processSample(modulationInput: modulationInput)
        }
        
        // Handle feedback connections (processed after main signal flow)
        if processingOrder.hasFeedback {
            processFeeback(operators)
        }
        
        // Mix carrier outputs
        let output = mixCarrierOutputs()
        
        // Update performance stats
        processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        return output
    }
    
    private func processFeeback(_ operators: [FMOperator]) {
        // Process feedback connections separately to avoid dependency cycles
        // This is a simplified implementation - could be enhanced with delay lines
        for connection in processingOrder.feedbackConnections {
            let feedbackAmount = connection.amount * 0.1 // Reduced to prevent instability
            operators[connection.destination].feedbackAmount = feedbackAmount
        }
    }
    
    private func mixCarrierOutputs() -> Double {
        let carriers = currentAlgorithm.carrierOperators
        
        if carriers.count == 1 {
            return operatorOutputBuffer[carriers[0]]
        } else {
            // Mix multiple carriers
            var output: Double = 0.0
            let scale = 1.0 / Double(carriers.count)
            
            for carrierIndex in carriers {
                output += operatorOutputBuffer[carrierIndex] * scale
            }
            
            return output
        }
    }
    
    // MARK: - Algorithm Information
    
    public var algorithm: FMAlgorithm { currentAlgorithm }
    
    public var visualizationData: AlgorithmVisualizationData {
        AlgorithmVisualizationData(algorithm: currentAlgorithm)
    }
    
    public var isTransitioning: Bool { transitionManager.isActive }
    
    // MARK: - Performance Monitoring
    
    public struct PerformanceStats {
        public let processingTime: TimeInterval
        public let algorithmSwitches: Int
        public let currentAlgorithmId: Int
        public let hasFeeback: Bool
    }
    
    public var performanceStats: PerformanceStats {
        PerformanceStats(
            processingTime: processingTime,
            algorithmSwitches: algorithmSwitches,
            currentAlgorithmId: currentAlgorithm.id,
            hasFeeback: processingOrder.hasFeedback
        )
    }
    
    // MARK: - Preset Support
    
    /// Create a preset configuration for the current algorithm
    public func createPreset(name: String) -> FMAlgorithmPreset {
        FMAlgorithmPreset(
            name: name,
            algorithmId: currentAlgorithm.id,
            customConnections: currentAlgorithm.connections.isEmpty ? nil : currentAlgorithm.connections
        )
    }
    
    /// Apply a preset configuration
    public func applyPreset(_ preset: FMAlgorithmPreset, transitionTimeMs: Double = 10.0, sampleRate: Double = 44100.0) {
        if let customConnections = preset.customConnections {
            // Apply custom algorithm
            let customAlgorithm = FMAlgorithm(
                id: preset.algorithmId,
                name: preset.name,
                connections: customConnections
            )
            switchAlgorithm(to: customAlgorithm, transitionTimeMs: transitionTimeMs, sampleRate: sampleRate)
        } else {
            // Use standard algorithm
            switchAlgorithm(toId: preset.algorithmId, transitionTimeMs: transitionTimeMs, sampleRate: sampleRate)
        }
    }
}

// MARK: - Algorithm Preset

/// Stores algorithm configuration for presets
public struct FMAlgorithmPreset: Codable {
    public let name: String
    public let algorithmId: Int
    public let customConnections: [FMConnection]?
    
    public init(name: String, algorithmId: Int, customConnections: [FMConnection]? = nil) {
        self.name = name
        self.algorithmId = algorithmId
        self.customConnections = customConnections
    }
}

// MARK: - Extensions for Visualization Support

extension CGPoint {
    public init(x: Double, y: Double) {
        self.init(x: CGFloat(x), y: CGFloat(y))
    }
}

extension CGSize {
    public init(width: Double, height: Double) {
        self.init(width: CGFloat(width), height: CGFloat(height))
    }
} 