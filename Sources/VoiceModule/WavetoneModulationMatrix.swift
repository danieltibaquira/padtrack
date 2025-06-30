// WavetoneModulationMatrix.swift
// DigitonePad - VoiceModule
//
// Modulation matrix for WAVETONE Voice Machine
// Handles complex modulation routing between oscillators, envelopes, and LFOs

import Foundation
import MachineProtocols

// MARK: - Modulation Sources and Destinations

/// Available modulation sources in WAVETONE
public enum WavetoneModulationSource: String, CaseIterable, Codable {
    case oscillator1 = "osc1"
    case oscillator2 = "osc2"
    case envelope1 = "env1"
    case envelope2 = "env2"
    case lfo1 = "lfo1"
    case lfo2 = "lfo2"
    case velocity = "velocity"
    case modWheel = "mod_wheel"
    case aftertouch = "aftertouch"
    case pitchBend = "pitch_bend"
    
    public var description: String {
        switch self {
        case .oscillator1: return "Oscillator 1"
        case .oscillator2: return "Oscillator 2"
        case .envelope1: return "Envelope 1"
        case .envelope2: return "Envelope 2"
        case .lfo1: return "LFO 1"
        case .lfo2: return "LFO 2"
        case .velocity: return "Velocity"
        case .modWheel: return "Mod Wheel"
        case .aftertouch: return "Aftertouch"
        case .pitchBend: return "Pitch Bend"
        }
    }
}

/// Available modulation destinations in WAVETONE
public enum WavetoneModulationDestination: String, CaseIterable, Codable {
    case oscillator1 = "osc1"
    case oscillator2 = "osc2"
    case noise = "noise"
    case osc1Frequency = "osc1_freq"
    case osc2Frequency = "osc2_freq"
    case osc1WavetablePos = "osc1_wav_pos"
    case osc2WavetablePos = "osc2_wav_pos"
    case osc1PhaseDistortion = "osc1_pd"
    case osc2PhaseDistortion = "osc2_pd"
    case ringModAmount = "ring_mod"
    case noiseLevel = "noise_level"
    case noiseFilter = "noise_filter"
    
    public var description: String {
        switch self {
        case .oscillator1: return "Oscillator 1"
        case .oscillator2: return "Oscillator 2"
        case .noise: return "Noise"
        case .osc1Frequency: return "OSC1 Frequency"
        case .osc2Frequency: return "OSC2 Frequency"
        case .osc1WavetablePos: return "OSC1 Wavetable Position"
        case .osc2WavetablePos: return "OSC2 Wavetable Position"
        case .osc1PhaseDistortion: return "OSC1 Phase Distortion"
        case .osc2PhaseDistortion: return "OSC2 Phase Distortion"
        case .ringModAmount: return "Ring Mod Amount"
        case .noiseLevel: return "Noise Level"
        case .noiseFilter: return "Noise Filter"
        }
    }
}

// MARK: - Modulation Connection

/// Represents a single modulation connection
public struct WavetoneModulationConnection: Codable {
    public let source: WavetoneModulationSource
    public let destination: WavetoneModulationDestination
    public var amount: Float
    public var isEnabled: Bool
    
    public init(source: WavetoneModulationSource, 
                destination: WavetoneModulationDestination, 
                amount: Float = 0.0, 
                isEnabled: Bool = true) {
        self.source = source
        self.destination = destination
        self.amount = amount
        self.isEnabled = isEnabled
    }
}

// MARK: - Simple Envelope Generator

/// Basic ADSR envelope for modulation
public final class WavetoneEnvelope: @unchecked Sendable {
    
    public enum Stage {
        case idle, attack, decay, sustain, release
    }
    
    // MARK: - Parameters
    
    public var attack: Float = 0.01   // seconds
    public var decay: Float = 0.1     // seconds
    public var sustain: Float = 0.7   // level (0.0-1.0)
    public var release: Float = 0.3   // seconds
    
    // MARK: - State
    
    private var currentStage: Stage = .idle
    private var currentLevel: Float = 0.0
    private var stageProgress: Float = 0.0
    private let sampleRate: Double
    private var velocity: Float = 1.0
    
    public init(sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate
    }
    
    public func noteOn(velocity: Float) {
        self.velocity = velocity
        currentStage = .attack
        stageProgress = 0.0
    }
    
    public func noteOff() {
        currentStage = .release
        stageProgress = 0.0
    }
    
    public func processSample() -> Float {
        let sampleTime = 1.0 / Float(sampleRate)
        
        switch currentStage {
        case .idle:
            currentLevel = 0.0
            
        case .attack:
            if attack > 0.0 {
                stageProgress += sampleTime / attack
                currentLevel = stageProgress * velocity
                if stageProgress >= 1.0 {
                    currentStage = .decay
                    stageProgress = 0.0
                }
            } else {
                currentLevel = velocity
                currentStage = .decay
            }
            
        case .decay:
            if decay > 0.0 {
                stageProgress += sampleTime / decay
                currentLevel = velocity * (sustain + (1.0 - sustain) * (1.0 - stageProgress))
                if stageProgress >= 1.0 {
                    currentStage = .sustain
                    currentLevel = velocity * sustain
                }
            } else {
                currentLevel = velocity * sustain
                currentStage = .sustain
            }
            
        case .sustain:
            currentLevel = velocity * sustain
            
        case .release:
            if release > 0.0 {
                stageProgress += sampleTime / release
                let releaseStartLevel = velocity * sustain
                currentLevel = releaseStartLevel * (1.0 - stageProgress)
                if stageProgress >= 1.0 {
                    currentStage = .idle
                    currentLevel = 0.0
                }
            } else {
                currentStage = .idle
                currentLevel = 0.0
            }
        }
        
        return max(0.0, min(1.0, currentLevel))
    }
    
    public var isActive: Bool {
        return currentStage != .idle
    }
}

// MARK: - Simple LFO

/// Basic LFO for modulation
public final class WavetoneLFO: @unchecked Sendable {
    
    public enum Waveform: String, CaseIterable, Codable {
        case sine = "sine"
        case triangle = "triangle"
        case sawtooth = "sawtooth"
        case square = "square"
        case random = "random"
    }
    
    // MARK: - Parameters
    
    public var frequency: Float = 1.0  // Hz
    public var waveform: Waveform = .sine
    public var amplitude: Float = 1.0
    public var phase: Float = 0.0
    
    // MARK: - State
    
    private var currentPhase: Float = 0.0
    private let sampleRate: Double
    private var randomValue: Float = 0.0
    private var randomCounter: Int = 0
    
    public init(sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate
    }
    
    public func processSample() -> Float {
        let phaseIncrement = frequency / Float(sampleRate)
        currentPhase += phaseIncrement
        
        // Wrap phase
        while currentPhase >= 1.0 {
            currentPhase -= 1.0
        }
        
        let adjustedPhase = currentPhase + phase
        let normalizedPhase = adjustedPhase - floor(adjustedPhase)
        
        let output: Float
        
        switch waveform {
        case .sine:
            output = sin(normalizedPhase * 2.0 * Float.pi)
            
        case .triangle:
            if normalizedPhase < 0.5 {
                output = (normalizedPhase * 4.0) - 1.0
            } else {
                output = 3.0 - (normalizedPhase * 4.0)
            }
            
        case .sawtooth:
            output = (normalizedPhase * 2.0) - 1.0
            
        case .square:
            output = normalizedPhase < 0.5 ? -1.0 : 1.0
            
        case .random:
            // Sample and hold random values
            randomCounter += 1
            if randomCounter >= Int(Double(sampleRate) / Double(frequency) / 10.0) {
                randomValue = Float.random(in: -1.0...1.0)
                randomCounter = 0
            }
            output = randomValue
        }
        
        return output * amplitude
    }
    
    public func reset() {
        currentPhase = 0.0
        randomCounter = 0
    }
}

// MARK: - Modulation Matrix

/// Complete modulation matrix for WAVETONE
public final class WavetoneModulationMatrix: @unchecked Sendable {
    
    // MARK: - Modulation Sources
    
    private var envelope1: WavetoneEnvelope
    private var envelope2: WavetoneEnvelope
    private var lfo1: WavetoneLFO
    private var lfo2: WavetoneLFO
    
    // MARK: - Modulation State
    
    private var connections: [WavetoneModulationConnection] = []
    private var sourceValues: [WavetoneModulationSource: Float] = [:]
    private var destinationValues: [WavetoneModulationDestination: Float] = [:]
    
    // MARK: - External Control Values
    
    private var velocityValue: Float = 0.0
    private var modWheelValue: Float = 0.0
    private var aftertouchValue: Float = 0.0
    private var pitchBendValue: Float = 0.0
    
    public init(sampleRate: Double = 44100.0) {
        self.envelope1 = WavetoneEnvelope(sampleRate: sampleRate)
        self.envelope2 = WavetoneEnvelope(sampleRate: sampleRate)
        self.lfo1 = WavetoneLFO(sampleRate: sampleRate)
        self.lfo2 = WavetoneLFO(sampleRate: sampleRate)
        
        initializeSourceValues()
        initializeDestinationValues()
    }
    
    // MARK: - Public Interface
    
    public func noteOn(velocity: Float) {
        velocityValue = velocity
        envelope1.noteOn(velocity: velocity)
        envelope2.noteOn(velocity: velocity)
    }
    
    public func noteOff() {
        envelope1.noteOff()
        envelope2.noteOff()
    }
    
    public func allNotesOff() {
        velocityValue = 0.0
        envelope1.noteOff()
        envelope2.noteOff()
        lfo1.reset()
        lfo2.reset()
    }
    
    public func updateModulation() {
        // Update source values
        sourceValues[.envelope1] = envelope1.processSample()
        sourceValues[.envelope2] = envelope2.processSample()
        sourceValues[.lfo1] = lfo1.processSample()
        sourceValues[.lfo2] = lfo2.processSample()
        sourceValues[.velocity] = velocityValue
        sourceValues[.modWheel] = modWheelValue
        sourceValues[.aftertouch] = aftertouchValue
        sourceValues[.pitchBend] = pitchBendValue
        
        // Reset destination values
        for destination in WavetoneModulationDestination.allCases {
            destinationValues[destination] = 0.0
        }
        
        // Apply modulation connections
        for connection in connections where connection.isEnabled {
            let sourceValue = sourceValues[connection.source] ?? 0.0
            let modulationAmount = sourceValue * connection.amount
            destinationValues[connection.destination] = (destinationValues[connection.destination] ?? 0.0) + modulationAmount
        }
    }
    
    public func getModulationValue(destination: WavetoneModulationDestination) -> Float {
        return destinationValues[destination] ?? 0.0
    }
    
    // MARK: - Connection Management
    
    public func addConnection(_ connection: WavetoneModulationConnection) {
        connections.append(connection)
    }
    
    public func removeConnection(source: WavetoneModulationSource, destination: WavetoneModulationDestination) {
        connections.removeAll { $0.source == source && $0.destination == destination }
    }
    
    public func setConnectionAmount(source: WavetoneModulationSource, destination: WavetoneModulationDestination, amount: Float) {
        for i in 0..<connections.count {
            if connections[i].source == source && connections[i].destination == destination {
                connections[i].amount = amount
                return
            }
        }
        // If connection doesn't exist, create it
        addConnection(WavetoneModulationConnection(source: source, destination: destination, amount: amount))
    }
    
    // MARK: - Control Value Setters
    
    public func setModWheel(_ value: Float) {
        modWheelValue = max(0.0, min(1.0, value))
    }
    
    public func setAftertouch(_ value: Float) {
        aftertouchValue = max(0.0, min(1.0, value))
    }
    
    public func setPitchBend(_ value: Float) {
        pitchBendValue = max(-1.0, min(1.0, value))
    }
    
    // MARK: - Component Access
    
    public func getEnvelope1() -> WavetoneEnvelope { return envelope1 }
    public func getEnvelope2() -> WavetoneEnvelope { return envelope2 }
    public func getLFO1() -> WavetoneLFO { return lfo1 }
    public func getLFO2() -> WavetoneLFO { return lfo2 }
    
    // MARK: - Convenience Methods for Parameter Updates
    
    public func setModulationSource(_ source: WavetoneModulationSource, value: Float) {
        switch source {
        case .modWheel:
            setModWheel(value)
        case .aftertouch:
            setAftertouch(value)
        case .velocity:
            velocityValue = max(0.0, min(1.0, value))
        case .pitchBend:
            setPitchBend(value)
        default:
            break // Other sources are controlled internally
        }
    }
    
    public func setLFORate(_ lfoNumber: Int, rate: Float) {
        switch lfoNumber {
        case 1:
            lfo1.frequency = rate
        case 2:
            lfo2.frequency = rate
        default:
            break
        }
    }
    
    public func setLFODepth(_ lfoNumber: Int, depth: Float) {
        switch lfoNumber {
        case 1:
            lfo1.amplitude = depth
        case 2:
            lfo2.amplitude = depth
        default:
            break
        }
    }
    
    // MARK: - Setup Methods
    
    public func setupDefaultRouting() {
        // Default modulation routing for WAVETONE
        addConnection(WavetoneModulationConnection(source: .envelope1, destination: .osc1WavetablePos, amount: 0.3))
        addConnection(WavetoneModulationConnection(source: .lfo1, destination: .osc2Frequency, amount: 0.1))
        addConnection(WavetoneModulationConnection(source: .velocity, destination: .noiseLevel, amount: 0.5))
        addConnection(WavetoneModulationConnection(source: .modWheel, destination: .ringModAmount, amount: 0.8))
    }
    
    // MARK: - Private Methods
    
    private func initializeSourceValues() {
        for source in WavetoneModulationSource.allCases {
            sourceValues[source] = 0.0
        }
    }
    
    private func initializeDestinationValues() {
        for destination in WavetoneModulationDestination.allCases {
            destinationValues[destination] = 0.0
        }
    }
}
