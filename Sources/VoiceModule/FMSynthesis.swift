// FMSynthesis.swift
// DigitonePad - VoiceModule
//
// FM Synthesis Engine Implementation

import Foundation
import Accelerate
import MachineProtocols
import AudioEngine

// MARK: - FM Operator

/// A single FM operator with phase accumulation and modulation
public final class FMOperator: @unchecked Sendable {
    // Core properties
    public var frequency: Double = 440.0
    public var amplitude: Double = 1.0
    public var phase: Double = 0.0
    public var phaseIncrement: Double = 0.0
    
    // Modulation properties
    public var modulationIndex: Double = 0.0
    public var feedbackAmount: Double = 0.0

    // Pitch modulation
    private var pitchModulation: Double = 0.0
    private var baseFrequency: Double = 440.0

    // State
    private var sampleRate: Double = 44100.0
    private var previousOutput: Double = 0.0
    
    // Sine lookup table for performance
    private static let sineTableSize = 4096
    private static let sineTable: [Double] = {
        var table = [Double](repeating: 0.0, count: sineTableSize)
        for i in 0..<sineTableSize {
            let phase = Double(i) * 2.0 * Double.pi / Double(sineTableSize)
            table[i] = sin(phase)
        }
        return table
    }()
    
    public init(sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate
        self.baseFrequency = frequency
        updatePhaseIncrement()
    }

    /// Update the phase increment based on current frequency and pitch modulation
    public func updatePhaseIncrement() {
        let modulatedFrequency = baseFrequency * (1.0 + pitchModulation)
        phaseIncrement = modulatedFrequency * 2.0 * Double.pi / sampleRate
    }
    
    /// Process one sample with optional modulation input
    public func processSample(modulationInput: Double = 0.0) -> Double {
        // Apply modulation to phase
        let modulatedPhase = phase + (modulationInput * modulationIndex) + (previousOutput * feedbackAmount)
        
        // Lookup sine value using table interpolation
        let output = lookupSine(phase: modulatedPhase) * amplitude
        
        // Advance phase
        phase += phaseIncrement
        
        // Wrap phase to avoid overflow
        if phase >= 2.0 * Double.pi {
            phase -= 2.0 * Double.pi
        }
        
        // Store for feedback
        previousOutput = output
        
        return output
    }
    
    /// Fast sine lookup with linear interpolation
    private func lookupSine(phase: Double) -> Double {
        // Normalize phase to table range
        let normalizedPhase = phase.truncatingRemainder(dividingBy: 2.0 * Double.pi)
        let tablePhase = normalizedPhase * Double(Self.sineTableSize) / (2.0 * Double.pi)
        
        let index = Int(tablePhase)
        let fraction = tablePhase - Double(index)
        
        let index1 = index % Self.sineTableSize
        let index2 = (index + 1) % Self.sineTableSize
        
        // Linear interpolation
        return Self.sineTable[index1] * (1.0 - fraction) + Self.sineTable[index2] * fraction
    }
    
    /// Reset operator state
    public func reset() {
        phase = 0.0
        previousOutput = 0.0
    }
    
    /// Set frequency and update phase increment
    public func setFrequency(_ freq: Double) {
        frequency = freq
        baseFrequency = freq
        updatePhaseIncrement()
    }

    /// Set pitch modulation amount (0.0 = no modulation, 1.0 = double frequency, -1.0 = half frequency)
    public func setPitchModulation(_ modulation: Double) {
        pitchModulation = modulation
        updatePhaseIncrement()
    }
}

// MARK: - FM Algorithm

/// Defines how operators are connected in an FM algorithm
public struct FMAlgorithm: Sendable {
    public let id: Int
    public let name: String
    public let connections: [FMConnection]
    
    public init(id: Int, name: String, connections: [FMConnection]) {
        self.id = id
        self.name = name
        self.connections = connections
    }
}

/// Represents a connection between operators
public struct FMConnection: Sendable, Codable {
    public let source: Int      // Source operator index
    public let destination: Int // Destination operator index
    public let amount: Double   // Connection strength
    
    public init(source: Int, destination: Int, amount: Double = 1.0) {
        self.source = source
        self.destination = destination
        self.amount = amount
    }
}

// MARK: - FM Voice

/// A complete FM voice with 4 operators
public final class FMVoice: @unchecked Sendable {
    // Operators
    internal var operators: [FMOperator] = []
    
    // Voice properties
    public var note: UInt8 = 60
    public var velocity: UInt8 = 100
    public var isActive: Bool = false
    
    // Algorithm
    public var algorithm: FMAlgorithm = FMAlgorithms.algorithm1
    
    // Frequency ratios for operators
    public var operatorRatios: [Double] = [1.0, 1.0, 1.0, 1.0]
    
    // Output levels for operators
    public var operatorLevels: [Double] = [1.0, 1.0, 1.0, 1.0]
    
    private let sampleRate: Double
    
    public init(sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate
        
        // Initialize 4 operators
        for _ in 0..<4 {
            operators.append(FMOperator(sampleRate: sampleRate))
        }
    }
    
    /// Start the voice with a note
    public func noteOn(note: UInt8, velocity: UInt8) {
        self.note = note
        self.velocity = velocity
        self.isActive = true
        
        // Calculate base frequency from MIDI note
        let baseFrequency = midiNoteToFrequency(note)
        
        // Set operator frequencies based on ratios
        for (index, fmOperator) in operators.enumerated() {
            fmOperator.setFrequency(baseFrequency * operatorRatios[index])
            fmOperator.amplitude = operatorLevels[index] * Double(velocity) / 127.0
        }
        
        // Reset operator phases
        for fmOperator in operators {
            fmOperator.reset()
        }
    }
    
    /// Stop the voice
    public func noteOff() {
        isActive = false
        // TODO: Implement envelope release
    }
    
    /// Process one sample
    public func processSample() -> Double {
        guard isActive else { return 0.0 }
        
        // Process operators according to algorithm
        var operatorOutputs = [Double](repeating: 0.0, count: 4)
        
        // Process each operator with modulation from connections
        for i in 0..<4 {
            var modulationInput: Double = 0.0
            
            // Calculate modulation input from other operators
            for connection in algorithm.connections {
                if connection.destination == i {
                    modulationInput += operatorOutputs[connection.source] * connection.amount
                }
            }
            
            operatorOutputs[i] = operators[i].processSample(modulationInput: modulationInput)
        }
        
        // Mix output operators (typically operator 0 is the carrier)
        return operatorOutputs[0]
    }
    
    /// Convert MIDI note to frequency
    private func midiNoteToFrequency(_ note: UInt8) -> Double {
        return 440.0 * pow(2.0, (Double(note) - 69.0) / 12.0)
    }
    
    /// Reset voice state
    public func reset() {
        isActive = false
        for fmOperator in operators {
            fmOperator.reset()
        }
    }
}

// MARK: - FM Algorithms

/// Predefined FM algorithms
public struct FMAlgorithms {
    /// Algorithm 1: Simple 2-operator FM (Op1 -> Op0)
    public static let algorithm1 = FMAlgorithm(
        id: 1,
        name: "Simple FM",
        connections: [
            FMConnection(source: 1, destination: 0)
        ]
    )
    
    /// Algorithm 2: Parallel operators (Op1 -> Op0, Op2 -> Op0)
    public static let algorithm2 = FMAlgorithm(
        id: 2,
        name: "Parallel FM",
        connections: [
            FMConnection(source: 1, destination: 0),
            FMConnection(source: 2, destination: 0)
        ]
    )
    
    /// Algorithm 3: Series chain (Op3 -> Op2 -> Op1 -> Op0)
    public static let algorithm3 = FMAlgorithm(
        id: 3,
        name: "Series Chain",
        connections: [
            FMConnection(source: 3, destination: 2),
            FMConnection(source: 2, destination: 1),
            FMConnection(source: 1, destination: 0)
        ]
    )
    
    /// Algorithm 4: Complex routing with feedback
    public static let algorithm4 = FMAlgorithm(
        id: 4,
        name: "Complex FB",
        connections: [
            FMConnection(source: 1, destination: 0),
            FMConnection(source: 2, destination: 1),
            FMConnection(source: 3, destination: 0)
        ]
    )
    
    public static let allAlgorithms = [algorithm1, algorithm2, algorithm3, algorithm4]
}
