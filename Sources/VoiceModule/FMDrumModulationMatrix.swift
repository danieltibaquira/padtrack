//
//  FMDrumModulationMatrix.swift
//  DigitonePad - VoiceModule
//
//  Modulation matrix system for FM DRUM voice machine
//

import Foundation

/// Comprehensive modulation matrix for FM DRUM synthesis
public final class FMDrumModulationMatrix: @unchecked Sendable {
    
    // MARK: - Modulation Sources
    
    private var modulationSources: [ModulationSource] = []
    private var modulationTargets: [ModulationTarget] = []
    private var modulationConnections: [ModulationConnection] = []
    
    // Modulation values (updated each sample)
    private var sourceValues: [ModulationSourceType: Double] = [:]
    private var targetValues: [ModulationTargetType: Double] = [:]
    
    // Matrix configuration
    private let maxConnections: Int = 32
    private var isEnabled: Bool = true
    
    // Performance optimization
    private var activeConnections: [ModulationConnection] = []
    private var connectionLookup: [ModulationSourceType: [ModulationConnection]] = [:]
    
    public init() {
        setupDefaultSources()
        setupDefaultTargets()
        setupDefaultConnections()
        rebuildConnectionLookup()
    }
    
    // MARK: - Modulation Processing
    
    /// Process all modulation connections for a single sample
    public func processModulation() {
        // Clear target values
        for targetType in ModulationTargetType.allCases {
            targetValues[targetType] = 0.0
        }
        
        // Process all active connections
        for connection in activeConnections {
            guard connection.isEnabled else { continue }
            
            let sourceValue = sourceValues[connection.source] ?? 0.0
            let modulatedValue = applyModulationCurve(
                value: sourceValue,
                curve: connection.curve,
                amount: connection.amount
            )
            
            // Accumulate modulation at target
            let currentValue = targetValues[connection.target] ?? 0.0
            targetValues[connection.target] = currentValue + modulatedValue
        }
        
        // Clamp target values to valid ranges
        clampTargetValues()
    }
    
    /// Update a modulation source value
    public func updateSourceValue(_ source: ModulationSourceType, value: Double) {
        sourceValues[source] = value
    }
    
    /// Get the current modulation value for a target
    public func getTargetValue(_ target: ModulationTargetType) -> Double {
        return targetValues[target] ?? 0.0
    }
    
    // MARK: - Connection Management
    
    /// Add a new modulation connection
    public func addConnection(
        source: ModulationSourceType,
        target: ModulationTargetType,
        amount: Double,
        curve: ModulationCurve = .linear
    ) -> Bool {
        guard modulationConnections.count < maxConnections else { return false }
        
        let connection = ModulationConnection(
            id: UUID(),
            source: source,
            target: target,
            amount: max(-1.0, min(1.0, amount)),
            curve: curve,
            isEnabled: true
        )
        
        modulationConnections.append(connection)
        rebuildConnectionLookup()
        return true
    }
    
    /// Remove a modulation connection
    public func removeConnection(id: UUID) -> Bool {
        guard let index = modulationConnections.firstIndex(where: { $0.id == id }) else {
            return false
        }
        
        modulationConnections.remove(at: index)
        rebuildConnectionLookup()
        return true
    }
    
    /// Update an existing connection
    public func updateConnection(
        id: UUID,
        amount: Double? = nil,
        curve: ModulationCurve? = nil,
        enabled: Bool? = nil
    ) -> Bool {
        guard let index = modulationConnections.firstIndex(where: { $0.id == id }) else {
            return false
        }
        
        var connection = modulationConnections[index]
        
        if let amount = amount {
            connection.amount = max(-1.0, min(1.0, amount))
        }
        
        if let curve = curve {
            connection.curve = curve
        }
        
        if let enabled = enabled {
            connection.isEnabled = enabled
        }
        
        modulationConnections[index] = connection
        rebuildConnectionLookup()
        return true
    }
    
    /// Get all connections for a specific source
    public func getConnectionsForSource(_ source: ModulationSourceType) -> [ModulationConnection] {
        return connectionLookup[source] ?? []
    }
    
    /// Get all current connections
    public func getAllConnections() -> [ModulationConnection] {
        return modulationConnections
    }
    
    // MARK: - Preset Management
    
    /// Save current matrix state as preset
    public func savePreset(name: String) -> ModulationMatrixPreset {
        return ModulationMatrixPreset(
            name: name,
            connections: modulationConnections,
            timestamp: Date()
        )
    }
    
    /// Load a preset
    public func loadPreset(_ preset: ModulationMatrixPreset) {
        modulationConnections = preset.connections
        rebuildConnectionLookup()
    }
    
    /// Clear all connections
    public func clearAllConnections() {
        modulationConnections.removeAll()
        rebuildConnectionLookup()
    }
    
    // MARK: - Setup Methods
    
    private func setupDefaultSources() {
        modulationSources = ModulationSourceType.allCases.map { sourceType in
            ModulationSource(
                type: sourceType,
                name: sourceType.displayName,
                range: sourceType.defaultRange,
                isEnabled: true
            )
        }
    }
    
    private func setupDefaultTargets() {
        modulationTargets = ModulationTargetType.allCases.map { targetType in
            ModulationTarget(
                type: targetType,
                name: targetType.displayName,
                range: targetType.defaultRange,
                isEnabled: true
            )
        }
    }
    
    private func setupDefaultConnections() {
        // Add some useful default connections for drums
        
        // Velocity to amplitude
        _ = addConnection(
            source: .velocity,
            target: .amplitudeLevel,
            amount: 0.8,
            curve: .exponential
        )
        
        // Velocity to filter cutoff
        _ = addConnection(
            source: .velocity,
            target: .filterCutoff,
            amount: 0.3,
            curve: .linear
        )
        
        // Pitch envelope to operator frequencies
        _ = addConnection(
            source: .pitchEnvelope,
            target: .operator1Frequency,
            amount: 0.5,
            curve: .linear
        )
        
        // Amplitude envelope to noise level
        _ = addConnection(
            source: .amplitudeEnvelope,
            target: .noiseLevel,
            amount: 0.4,
            curve: .linear
        )
    }
    
    // MARK: - Helper Methods
    
    private func rebuildConnectionLookup() {
        connectionLookup.removeAll()
        activeConnections.removeAll()
        
        for connection in modulationConnections {
            if connection.isEnabled {
                activeConnections.append(connection)
            }
            
            if connectionLookup[connection.source] == nil {
                connectionLookup[connection.source] = []
            }
            connectionLookup[connection.source]?.append(connection)
        }
    }
    
    private func applyModulationCurve(
        value: Double,
        curve: ModulationCurve,
        amount: Double
    ) -> Double {
        let scaledValue = value * amount
        
        switch curve {
        case .linear:
            return scaledValue
            
        case .exponential:
            return scaledValue >= 0 ? pow(scaledValue, 2.0) : -pow(-scaledValue, 2.0)
            
        case .logarithmic:
            return scaledValue >= 0 ? sqrt(scaledValue) : -sqrt(-scaledValue)
            
        case .sine:
            return sin(scaledValue * .pi / 2.0)
            
        case .inverted:
            return -scaledValue
            
        case .bipolar:
            return scaledValue * 2.0 - 1.0
        }
    }
    
    private func clampTargetValues() {
        for targetType in ModulationTargetType.allCases {
            if let value = targetValues[targetType] {
                let range = targetType.defaultRange
                targetValues[targetType] = max(range.lowerBound, min(range.upperBound, value))
            }
        }
    }
    
    // MARK: - Configuration
    
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    public func isMatrixEnabled() -> Bool {
        return isEnabled
    }
    
    public func getActiveConnectionCount() -> Int {
        return activeConnections.count
    }
    
    public func getTotalConnectionCount() -> Int {
        return modulationConnections.count
    }
}

// MARK: - Supporting Types

public struct ModulationSource: Codable {
    public let type: ModulationSourceType
    public let name: String
    public let range: ClosedRange<Double>
    public var isEnabled: Bool
}

public struct ModulationTarget: Codable {
    public let type: ModulationTargetType
    public let name: String
    public let range: ClosedRange<Double>
    public var isEnabled: Bool
}

public struct ModulationConnection: Identifiable, Codable {
    public let id: UUID
    public let source: ModulationSourceType
    public let target: ModulationTargetType
    public var amount: Double
    public var curve: ModulationCurve
    public var isEnabled: Bool
}

public struct ModulationMatrixPreset: Codable {
    public let name: String
    public let connections: [ModulationConnection]
    public let timestamp: Date
}

// MARK: - Enums

public enum ModulationSourceType: String, CaseIterable, Codable {
    case velocity = "velocity"
    case aftertouch = "aftertouch"
    case pitchBend = "pitchBend"
    case modWheel = "modWheel"
    case amplitudeEnvelope = "amplitudeEnvelope"
    case pitchEnvelope = "pitchEnvelope"
    case filterEnvelope = "filterEnvelope"
    case noiseEnvelope = "noiseEnvelope"
    case lfo1 = "lfo1"
    case lfo2 = "lfo2"
    case randomSource = "randomSource"
    case keyTracking = "keyTracking"
    
    public var displayName: String {
        switch self {
        case .velocity: return "Velocity"
        case .aftertouch: return "Aftertouch"
        case .pitchBend: return "Pitch Bend"
        case .modWheel: return "Mod Wheel"
        case .amplitudeEnvelope: return "Amp Env"
        case .pitchEnvelope: return "Pitch Env"
        case .filterEnvelope: return "Filter Env"
        case .noiseEnvelope: return "Noise Env"
        case .lfo1: return "LFO 1"
        case .lfo2: return "LFO 2"
        case .randomSource: return "Random"
        case .keyTracking: return "Key Track"
        }
    }
    
    public var defaultRange: ClosedRange<Double> {
        switch self {
        case .velocity, .aftertouch: return 0.0...1.0
        case .pitchBend: return -1.0...1.0
        case .modWheel: return 0.0...1.0
        case .amplitudeEnvelope, .pitchEnvelope, .filterEnvelope, .noiseEnvelope: return 0.0...1.0
        case .lfo1, .lfo2: return -1.0...1.0
        case .randomSource: return -1.0...1.0
        case .keyTracking: return -1.0...1.0
        }
    }
}

public enum ModulationTargetType: String, CaseIterable, Codable {
    case amplitudeLevel = "amplitudeLevel"
    case operator1Frequency = "operator1Frequency"
    case operator2Frequency = "operator2Frequency"
    case operator3Frequency = "operator3Frequency"
    case operator1Level = "operator1Level"
    case operator2Level = "operator2Level"
    case operator3Level = "operator3Level"
    case noiseLevel = "noiseLevel"
    case filterCutoff = "filterCutoff"
    case filterResonance = "filterResonance"
    case pitchSweepAmount = "pitchSweepAmount"
    case pitchSweepTime = "pitchSweepTime"
    case wavefoldAmount = "wavefoldAmount"
    case panPosition = "panPosition"
    case reverbSend = "reverbSend"
    case distortionAmount = "distortionAmount"
    
    public var displayName: String {
        switch self {
        case .amplitudeLevel: return "Amp Level"
        case .operator1Frequency: return "Op1 Freq"
        case .operator2Frequency: return "Op2 Freq"
        case .operator3Frequency: return "Op3 Freq"
        case .operator1Level: return "Op1 Level"
        case .operator2Level: return "Op2 Level"
        case .operator3Level: return "Op3 Level"
        case .noiseLevel: return "Noise Level"
        case .filterCutoff: return "Filter Cutoff"
        case .filterResonance: return "Filter Res"
        case .pitchSweepAmount: return "Pitch Sweep"
        case .pitchSweepTime: return "Sweep Time"
        case .wavefoldAmount: return "Wavefold"
        case .panPosition: return "Pan"
        case .reverbSend: return "Reverb"
        case .distortionAmount: return "Distortion"
        }
    }
    
    public var defaultRange: ClosedRange<Double> {
        switch self {
        case .amplitudeLevel, .operator1Level, .operator2Level, .operator3Level: return 0.0...1.0
        case .operator1Frequency, .operator2Frequency, .operator3Frequency: return -2.0...2.0
        case .noiseLevel: return 0.0...1.0
        case .filterCutoff: return -1.0...1.0
        case .filterResonance: return 0.0...1.0
        case .pitchSweepAmount: return -1.0...1.0
        case .pitchSweepTime: return 0.0...1.0
        case .wavefoldAmount: return 0.0...1.0
        case .panPosition: return -1.0...1.0
        case .reverbSend, .distortionAmount: return 0.0...1.0
        }
    }
}

public enum ModulationCurve: String, CaseIterable, Codable {
    case linear = "linear"
    case exponential = "exponential"
    case logarithmic = "logarithmic"
    case sine = "sine"
    case inverted = "inverted"
    case bipolar = "bipolar"
    
    public var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .exponential: return "Exponential"
        case .logarithmic: return "Logarithmic"
        case .sine: return "Sine"
        case .inverted: return "Inverted"
        case .bipolar: return "Bipolar"
        }
    }
}
