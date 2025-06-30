// FMToneAlgorithms.swift
// DigitonePad - VoiceModule
//
// 8 FM Algorithms for TONE Voice Machine (inspired by Digitone/DX7)

import Foundation
import MachineProtocols

// MARK: - FM TONE Algorithm Definitions

/// Complete set of 8 FM algorithms for the TONE Voice Machine
/// Operators are numbered: C (Carrier), A, B1, B2 (Modulators)
/// Index mapping: C=0, A=1, B1=2, B2=3
public struct FMToneAlgorithms {
    
    // MARK: - Algorithm 1: Simple FM
    /// Operator chain: B2 -> A -> C (output)
    /// Classic 2-operator FM sound with one modulator chain
    public static let algorithm1 = FMAlgorithm(
        id: 1,
        name: "Simple FM",
        connections: [
            FMConnection(source: 3, destination: 1, amount: 1.0), // B2 -> A
            FMConnection(source: 1, destination: 0, amount: 1.0)  // A -> C
        ]
    )
    
    // MARK: - Algorithm 2: Parallel Modulators
    /// Both A and B1 modulate C independently
    /// Great for rich harmonic content
    public static let algorithm2 = FMAlgorithm(
        id: 2,
        name: "Parallel Mod",
        connections: [
            FMConnection(source: 1, destination: 0, amount: 1.0), // A -> C
            FMConnection(source: 2, destination: 0, amount: 1.0)  // B1 -> C
        ]
    )
    
    // MARK: - Algorithm 3: Series Chain
    /// Full series chain: B2 -> B1 -> A -> C
    /// Maximum FM complexity with cascading modulation
    public static let algorithm3 = FMAlgorithm(
        id: 3,
        name: "Series Chain",
        connections: [
            FMConnection(source: 3, destination: 2, amount: 1.0), // B2 -> B1
            FMConnection(source: 2, destination: 1, amount: 1.0), // B1 -> A
            FMConnection(source: 1, destination: 0, amount: 1.0)  // A -> C
        ]
    )
    
    // MARK: - Algorithm 4: Dual Carriers
    /// C and A are both carriers, B1 and B2 are modulators
    /// Creates richer, more complex textures
    public static let algorithm4 = FMAlgorithm(
        id: 4,
        name: "Dual Carriers",
        connections: [
            FMConnection(source: 2, destination: 0, amount: 1.0), // B1 -> C
            FMConnection(source: 3, destination: 1, amount: 1.0)  // B2 -> A
        ]
    )
    
    // MARK: - Algorithm 5: Feedback Stack
    /// Two parallel chains: B2->A and B1->C, with A also going to C
    /// Complex modulation matrix for evolving timbres
    public static let algorithm5 = FMAlgorithm(
        id: 5,
        name: "Feedback Stack",
        connections: [
            FMConnection(source: 3, destination: 1, amount: 1.0), // B2 -> A
            FMConnection(source: 2, destination: 0, amount: 1.0), // B1 -> C
            FMConnection(source: 1, destination: 0, amount: 0.7)  // A -> C (mixed level)
        ]
    )
    
    // MARK: - Algorithm 6: Ring Modulation Style
    /// All modulators contribute to carrier
    /// Similar to algorithm 2 but with B2 also contributing
    public static let algorithm6 = FMAlgorithm(
        id: 6,
        name: "Ring Mod Style",
        connections: [
            FMConnection(source: 1, destination: 0, amount: 1.0), // A -> C
            FMConnection(source: 2, destination: 0, amount: 1.0), // B1 -> C
            FMConnection(source: 3, destination: 0, amount: 1.0)  // B2 -> C
        ]
    )
    
    // MARK: - Algorithm 7: Branched Modulation
    /// B2 modulates both A and B1, which then modulate C
    /// Creates harmonic relationships between modulators
    public static let algorithm7 = FMAlgorithm(
        id: 7,
        name: "Branched Mod",
        connections: [
            FMConnection(source: 3, destination: 1, amount: 1.0), // B2 -> A
            FMConnection(source: 3, destination: 2, amount: 1.0), // B2 -> B1
            FMConnection(source: 1, destination: 0, amount: 1.0), // A -> C
            FMConnection(source: 2, destination: 0, amount: 1.0)  // B1 -> C
        ]
    )
    
    // MARK: - Algorithm 8: Complex Matrix
    /// Most complex algorithm with multiple interconnections
    /// B2->B1->C, B2->A->C, and direct A->B1 cross-modulation
    public static let algorithm8 = FMAlgorithm(
        id: 8,
        name: "Complex Matrix",
        connections: [
            FMConnection(source: 3, destination: 2, amount: 1.0), // B2 -> B1
            FMConnection(source: 3, destination: 1, amount: 0.8), // B2 -> A (reduced)
            FMConnection(source: 2, destination: 0, amount: 1.0), // B1 -> C
            FMConnection(source: 1, destination: 0, amount: 1.0), // A -> C
            FMConnection(source: 1, destination: 2, amount: 0.5)  // A -> B1 (cross-mod)
        ]
    )
    
    // MARK: - Algorithm Collection
    
    /// All 8 algorithms in order
    public static let allAlgorithms: [FMAlgorithm] = [
        algorithm1, algorithm2, algorithm3, algorithm4,
        algorithm5, algorithm6, algorithm7, algorithm8
    ]
    
    /// Get algorithm by ID (1-8)
    public static func algorithm(id: Int) -> FMAlgorithm? {
        guard id >= 1 && id <= 8 else { return nil }
        return allAlgorithms[id - 1]
    }
    
    /// Get algorithm by index (0-7)
    public static func algorithm(index: Int) -> FMAlgorithm? {
        guard index >= 0 && index < 8 else { return nil }
        return allAlgorithms[index]
    }
}

// MARK: - Algorithm Analysis Utilities

extension FMAlgorithm {
    
    /// Get the carrier operators (operators that output to audio)
    public var carrierOperators: [Int] {
        let destinations = Set(connections.map { $0.destination })
        let sources = Set(connections.map { $0.source })
        
        // Carriers are operators that are destinations but not sources,
        // or operator 0 if it has no outgoing connections
        var carriers: [Int] = []
        
        for i in 0..<4 {
            if !sources.contains(i) || (!destinations.contains(i) && i == 0) {
                carriers.append(i)
            }
        }
        
        // If no clear carriers found, default to operator 0
        return carriers.isEmpty ? [0] : carriers
    }
    
    /// Get modulator operators (operators that modulate others)
    public var modulatorOperators: [Int] {
        let sources = Set(connections.map { $0.source })
        return Array(sources).sorted()
    }
    
    /// Check if an operator modulates another
    public func operatorModulates(_ source: Int, target: Int) -> Bool {
        return connections.contains { $0.source == source && $0.destination == target }
    }
    
    /// Get modulation amount between two operators
    public func modulationAmount(from source: Int, to destination: Int) -> Double {
        return connections.first { $0.source == source && $0.destination == destination }?.amount ?? 0.0
    }
    
    /// Get all operators that modulate the given operator
    public func modulatorsFor(operator: Int) -> [(source: Int, amount: Double)] {
        return connections
            .filter { $0.destination == `operator` }
            .map { (source: $0.source, amount: $0.amount) }
    }
    
    /// Complexity score (0-10) based on number and type of connections
    public var complexityScore: Int {
        let connectionCount = connections.count
        let crossModulations = connections.filter { connection in
            // Cross-modulation is when a later operator modulates an earlier one
            return connection.source < connection.destination
        }.count
        
        // Base score from connection count
        var score = min(connectionCount * 2, 8)
        
        // Add points for cross-modulations (more complex)
        score += crossModulations * 2
        
        return min(score, 10)
    }
    
    /// Human-readable description of the algorithm routing
    public var routingDescription: String {
        let sortedConnections = connections.sorted { 
            if $0.source == $1.source {
                return $0.destination < $1.destination
            }
            return $0.source < $1.source
        }
        
        let operatorNames = ["C", "A", "B1", "B2"]
        
        return sortedConnections.map { connection in
            let sourceName = operatorNames[connection.source]
            let destName = operatorNames[connection.destination]
            let amountStr = connection.amount == 1.0 ? "" : " (\(String(format: "%.1f", connection.amount)))"
            return "\(sourceName)→\(destName)\(amountStr)"
        }.joined(separator: ", ")
    }
}

// MARK: - Preset Algorithm Configurations

/// Preset configurations for common FM sounds using the 8 algorithms
public struct FMTonePresets {
    
    /// Classic electric piano sound (Algorithm 1)
    public static let electricPiano = FMTonePresetConfiguration(
        algorithm: FMToneAlgorithms.algorithm1,
        operatorRatios: [1.0, 14.0, 1.0, 1.0],
        operatorLevels: [1.0, 0.6, 0.0, 0.0],
        modulationIndices: [0.0, 2.8, 0.0, 0.0],
        name: "Electric Piano"
    )
    
    /// Warm bass sound (Algorithm 2)
    public static let warmBass = FMTonePresetConfiguration(
        algorithm: FMToneAlgorithms.algorithm2,
        operatorRatios: [1.0, 2.0, 3.0, 1.0],
        operatorLevels: [1.0, 0.4, 0.3, 0.0],
        modulationIndices: [0.0, 1.5, 1.2, 0.0],
        name: "Warm Bass"
    )
    
    /// Bell sound (Algorithm 3)
    public static let bell = FMTonePresetConfiguration(
        algorithm: FMToneAlgorithms.algorithm3,
        operatorRatios: [1.0, 3.5, 7.0, 11.0],
        operatorLevels: [1.0, 0.8, 0.6, 0.4],
        modulationIndices: [0.0, 2.0, 1.8, 1.5],
        name: "Bell"
    )
    
    /// Brass ensemble (Algorithm 5)
    public static let brass = FMTonePresetConfiguration(
        algorithm: FMToneAlgorithms.algorithm5,
        operatorRatios: [1.0, 2.0, 1.0, 3.0],
        operatorLevels: [1.0, 0.7, 0.5, 0.6],
        modulationIndices: [0.0, 1.8, 0.8, 2.2],
        name: "Brass"
    )
}

/// Configuration structure for FM TONE presets
public struct FMTonePresetConfiguration: Sendable {
    public let algorithm: FMAlgorithm
    public let operatorRatios: [Float]
    public let operatorLevels: [Float]
    public let modulationIndices: [Float]
    public let name: String
    
    public init(algorithm: FMAlgorithm, 
                operatorRatios: [Float], 
                operatorLevels: [Float], 
                modulationIndices: [Float], 
                name: String) {
        self.algorithm = algorithm
        self.operatorRatios = operatorRatios
        self.operatorLevels = operatorLevels
        self.modulationIndices = modulationIndices
        self.name = name
    }
} 