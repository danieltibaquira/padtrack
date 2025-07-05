// MIDICCMapper.swift
// DigitonePad - MIDIModule
//
// Universal MIDI CC parameter mapping system for all voice machines

import Foundation
import CoreMIDI
import MachineProtocols

/// Universal MIDI CC mapper for all voice machines and parameters
public final class MIDICCMapper: @unchecked Sendable {
    
    // MARK: - Properties
    
    weak var delegate: MIDICCMapperDelegate?
    
    private let lock = NSLock()
    private var mappings: [TrackChannelKey: [UInt8: ParameterMapping]] = [:]
    private var reverseMappings: [TrackChannelKey: [MIDIControllableParameter: UInt8]] = [:]
    private var voiceMachines: [TrackChannelKey: WeakVoiceMachineRef] = [:]
    
    // MIDI Learn state
    private var isLearningState = false
    private var learningContext: MIDILearnContext?
    
    // Performance tracking
    private var processedMessageCount = 0
    private var droppedMessageCount = 0
    
    // MARK: - Initialization
    
    public init() {
        // Initialize with empty state
    }
    
    // MARK: - Public Interface
    
    /// Check if MIDI learn mode is active
    public var isLearning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isLearningState
    }
    
    /// Get the parameter currently being learned
    public var learningParameter: MIDIControllableParameter? {
        lock.lock()
        defer { lock.unlock() }
        return learningContext?.parameter
    }
    
    /// Map a CC controller to a parameter
    public func mapCC(_ cc: UInt8, to parameter: MIDIControllableParameter, on voiceMachine: VoiceMachineProtocol?, track: Int, channel: UInt8 = 1) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = TrackChannelKey(track: track, channel: channel)
        
        // Initialize mappings if needed
        if mappings[key] == nil {
            mappings[key] = [:]
            reverseMappings[key] = [:]
        }
        
        // Remove any existing mapping for this parameter
        if let existingCC = reverseMappings[key]?[parameter] {
            mappings[key]?.removeValue(forKey: existingCC)
        }
        
        // Create new mapping
        let mapping = ParameterMapping(
            parameter: parameter,
            curveType: .linear,
            minValue: 0.0,
            maxValue: 1.0,
            smoothing: true
        )
        
        mappings[key]?[cc] = mapping
        reverseMappings[key]?[parameter] = cc
        
        // Store voice machine reference
        if let voiceMachine = voiceMachine {
            voiceMachines[key] = WeakVoiceMachineRef(voiceMachine)
        }
    }
    
    /// Remove CC mapping
    public func unmapCC(_ cc: UInt8, track: Int, channel: UInt8 = 1) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = TrackChannelKey(track: track, channel: channel)
        
        if let mapping = mappings[key]?[cc] {
            mappings[key]?.removeValue(forKey: cc)
            reverseMappings[key]?.removeValue(forKey: mapping.parameter)
        }
    }
    
    /// Get mapped parameter for a CC
    public func getMappedParameter(for cc: UInt8, track: Int, channel: UInt8 = 1) -> MIDIControllableParameter? {
        lock.lock()
        defer { lock.unlock() }
        
        let key = TrackChannelKey(track: track, channel: channel)
        return mappings[key]?[cc]?.parameter
    }
    
    /// Get mapped CC for a parameter
    public func getMappedCC(for parameter: MIDIControllableParameter, track: Int, channel: UInt8 = 1) -> UInt8? {
        lock.lock()
        defer { lock.unlock() }
        
        let key = TrackChannelKey(track: track, channel: channel)
        return reverseMappings[key]?[parameter]
    }
    
    // MARK: - MIDI Learn
    
    /// Start MIDI learn for a parameter
    public func startMIDILearn(for parameter: MIDIControllableParameter, on voiceMachine: VoiceMachineProtocol?, track: Int, channel: UInt8 = 1) {
        lock.lock()
        defer { lock.unlock() }
        
        isLearningState = true
        learningContext = MIDILearnContext(
            parameter: parameter,
            voiceMachine: voiceMachine,
            track: track,
            channel: channel
        )
    }
    
    /// Cancel MIDI learn mode
    public func cancelMIDILearn() {
        lock.lock()
        defer { lock.unlock() }
        
        isLearningState = false
        learningContext = nil
    }
    
    // MARK: - Message Processing
    
    /// Process incoming MIDI message
    public func handleIncomingMessage(_ message: MIDIMessage, for voiceMachine: VoiceMachineProtocol?) {
        // Handle MIDI learn first
        if isLearning {
            handleMIDILearnMessage(message, for: voiceMachine)
            return
        }
        
        // Process normal CC mapping
        guard message.type == .controlChange else {
            return
        }
        
        processControlChange(controller: message.data1, value: message.data2, channel: message.channel, voiceMachine: voiceMachine)
    }
    
    /// Process control change message for multiple tracks
    public func processControlChangeForAllTracks(controller: UInt8, value: UInt8, channel: UInt8) {
        lock.lock()
        defer { lock.unlock() }
        
        for (key, voiceMachineRef) in voiceMachines {
            if key.channel == channel {
                processControlChange(
                    controller: controller,
                    value: value,
                    channel: channel,
                    voiceMachine: voiceMachineRef.voiceMachine
                )
            }
        }
    }
    
    // MARK: - Advanced Mapping
    
    /// Set parameter curve type for CC mapping
    public func setParameterCurve(_ curve: ParameterCurveType, for cc: UInt8, track: Int, channel: UInt8 = 1) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = TrackChannelKey(track: track, channel: channel)
        mappings[key]?[cc]?.curveType = curve
    }
    
    /// Set parameter range for CC mapping
    public func setParameterRange(min: Float, max: Float, for cc: UInt8, track: Int, channel: UInt8 = 1) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = TrackChannelKey(track: track, channel: channel)
        mappings[key]?[cc]?.minValue = min
        mappings[key]?[cc]?.maxValue = max
    }
    
    /// Enable/disable parameter smoothing
    public func setParameterSmoothing(_ enabled: Bool, for cc: UInt8, track: Int, channel: UInt8 = 1) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = TrackChannelKey(track: track, channel: channel)
        mappings[key]?[cc]?.smoothing = enabled
    }
    
    // MARK: - Validation
    
    /// Validate and map CC (throws on invalid input)
    public func validateAndMapCC(_ cc: UInt8, to parameter: MIDIControllableParameter, track: Int, channel: UInt8 = 1) throws {
        guard cc <= 127 else {
            throw MIDICCMapperError.invalidCCNumber(cc)
        }
        
        mapCC(cc, to: parameter, on: nil, track: track, channel: channel)
    }
    
    // MARK: - Persistence
    
    /// Export all mappings for persistence
    public func exportMappings() -> MIDICCMappingData {
        lock.lock()
        defer { lock.unlock() }
        
        var exportData: [String: [UInt8: ParameterMappingData]] = [:]
        
        for (key, ccMappings) in mappings {
            let keyString = "\(key.track)-\(key.channel)"
            var mappingData: [UInt8: ParameterMappingData] = [:]
            
            for (cc, mapping) in ccMappings {
                mappingData[cc] = ParameterMappingData(
                    parameter: mapping.parameter.rawValue,
                    curveType: mapping.curveType.rawValue,
                    minValue: mapping.minValue,
                    maxValue: mapping.maxValue,
                    smoothing: mapping.smoothing
                )
            }
            
            exportData[keyString] = mappingData
        }
        
        return MIDICCMappingData(
            version: "1.0",
            mappings: exportData,
            createdAt: Date()
        )
    }
    
    /// Import mappings from persistence
    public func importMappings(_ data: MIDICCMappingData) {
        lock.lock()
        defer { lock.unlock() }
        
        // Clear existing mappings
        mappings.removeAll()
        reverseMappings.removeAll()
        
        // Import new mappings
        for (keyString, ccMappings) in data.mappings {
            let components = keyString.split(separator: "-")
            guard components.count == 2,
                  let track = Int(components[0]),
                  let channel = UInt8(components[1]) else {
                continue
            }
            
            let key = TrackChannelKey(track: track, channel: channel)
            mappings[key] = [:]
            reverseMappings[key] = [:]
            
            for (cc, mappingData) in ccMappings {
                guard let parameter = MIDIControllableParameter(rawValue: mappingData.parameter),
                      let curveType = ParameterCurveType(rawValue: mappingData.curveType) else {
                    continue
                }
                
                let mapping = ParameterMapping(
                    parameter: parameter,
                    curveType: curveType,
                    minValue: mappingData.minValue,
                    maxValue: mappingData.maxValue,
                    smoothing: mappingData.smoothing
                )
                
                mappings[key]?[cc] = mapping
                reverseMappings[key]?[parameter] = cc
            }
        }
    }
    
    /// Export mappings as JSON data
    public func exportAsJSON() -> Data {
        let mappingData = exportMappings()
        return (try? JSONEncoder().encode(mappingData)) ?? Data()
    }
    
    /// Import mappings from JSON data
    public func importFromJSON(_ data: Data) throws {
        let mappingData = try JSONDecoder().decode(MIDICCMappingData.self, from: data)
        importMappings(mappingData)
    }
    
    // MARK: - Statistics
    
    /// Get processing statistics
    public func getStatistics() -> MIDICCMapperStatistics {
        lock.lock()
        defer { lock.unlock() }
        
        let totalMappings = mappings.values.reduce(0) { $0 + $1.count }
        
        return MIDICCMapperStatistics(
            totalMappings: totalMappings,
            processedMessages: processedMessageCount,
            droppedMessages: droppedMessageCount,
            activeTracks: Set(mappings.keys.map { $0.track }).count
        )
    }
    
    // MARK: - Private Implementation
    
    private func processControlChange(controller: UInt8, value: UInt8, channel: UInt8, voiceMachine: VoiceMachineProtocol?) {
        // Find all tracks that could handle this CC on this channel
        var processed = false
        
        lock.lock()
        defer { lock.unlock() }
        
        for (key, mapping) in mappings {
            if key.channel == channel, let parameterMapping = mapping[controller] {
                let normalizedValue = Float(value) / 127.0
                let finalValue = applyParameterCurve(
                    normalizedValue,
                    curve: parameterMapping.curveType,
                    min: parameterMapping.minValue,
                    max: parameterMapping.maxValue
                )
                
                // Apply to voice machine if available
                if let voiceMachine = voiceMachine ?? voiceMachines[key]?.voiceMachine {
                    voiceMachine.setParameter(parameterMapping.parameter, value: finalValue)
                }
                
                // Notify delegate
                let processedMessage = MIDIMessage(type: .controlChange, channel: channel, data1: controller, data2: value)
                delegate?.ccMapper(self, processedMessage: processedMessage)
                
                processed = true
                processedMessageCount += 1
            }
        }
        
        if !processed {
            droppedMessageCount += 1
            let droppedMessage = MIDIMessage(type: .controlChange, channel: channel, data1: controller, data2: value)
            delegate?.ccMapper(self, droppedMessage: droppedMessage)
        }
    }
    
    private func handleMIDILearnMessage(_ message: MIDIMessage, for voiceMachine: VoiceMachineProtocol?) {
        guard message.type == .controlChange,
              let context = learningContext else {
            return
        }
        
        let channel = message.channel
        let controller = message.data1
        
        // Only learn if message is on the correct channel
        if context.channel == channel {
            mapCC(controller, to: context.parameter, on: voiceMachine, track: context.track, channel: context.channel)
            
            // Exit learn mode
            isLearningState = false
            let parameter = context.parameter
            learningContext = nil
            
            // Notify delegate
            delegate?.ccMapper(self, didLearnCC: controller, for: parameter)
        }
    }
    
    private func applyParameterCurve(_ normalizedValue: Float, curve: ParameterCurveType, min: Float, max: Float) -> Float {
        let curvedValue: Float
        
        switch curve {
        case .linear:
            curvedValue = normalizedValue
        case .exponential:
            curvedValue = pow(normalizedValue, 2.0)
        case .logarithmic:
            curvedValue = sqrt(normalizedValue)
        case .sCurve:
            // S-curve using sigmoid function
            let scaled = (normalizedValue - 0.5) * 6.0
            curvedValue = 1.0 / (1.0 + exp(-scaled))
        }
        
        return min + curvedValue * (max - min)
    }
}

// MARK: - Supporting Types

/// Key for tracking mappings per track and channel
private struct TrackChannelKey: Hashable {
    let track: Int
    let channel: UInt8
}

/// Weak reference wrapper for voice machines
private struct WeakVoiceMachineRef {
    weak var voiceMachine: VoiceMachineProtocol?
    
    init(_ voiceMachine: VoiceMachineProtocol) {
        self.voiceMachine = voiceMachine
    }
}

/// MIDI Learn context
private struct MIDILearnContext {
    let parameter: MIDIControllableParameter
    let voiceMachine: VoiceMachineProtocol?
    let track: Int
    let channel: UInt8
}

/// Parameter mapping configuration
private struct ParameterMapping {
    let parameter: MIDIControllableParameter
    var curveType: ParameterCurveType
    var minValue: Float
    var maxValue: Float
    var smoothing: Bool
}

// MARK: - Public Enums and Types

/// MIDI controllable parameters
public enum MIDIControllableParameter: String, CaseIterable, Codable {
    // Filter parameters
    case filterCutoff = "filter_cutoff"
    case filterResonance = "filter_resonance"
    case filterEnvAmount = "filter_env_amount"
    
    // LFO parameters
    case lfoRate = "lfo_rate"
    case lfoDepth = "lfo_depth"
    case lfoShape = "lfo_shape"
    
    // Envelope parameters
    case ampAttack = "amp_attack"
    case ampDecay = "amp_decay"
    case ampSustain = "amp_sustain"
    case ampRelease = "amp_release"
    
    // FM parameters
    case algorithm = "algorithm"
    case feedback = "feedback"
    case pitchBend = "pitch_bend"
    
    // Operator parameters
    case operatorLevel1 = "op1_level"
    case operatorLevel2 = "op2_level"
    case operatorLevel3 = "op3_level"
    case operatorLevel4 = "op4_level"
    
    case operatorRatio1 = "op1_ratio"
    case operatorRatio2 = "op2_ratio"
    case operatorRatio3 = "op3_ratio"
    case operatorRatio4 = "op4_ratio"
    
    case operatorDetune1 = "op1_detune"
    case operatorDetune2 = "op2_detune"
    case operatorDetune3 = "op3_detune"
    case operatorDetune4 = "op4_detune"
    
    // Convenience constructors
    static func operatorLevel(_ index: Int) -> MIDIControllableParameter {
        switch index {
        case 1: return .operatorLevel1
        case 2: return .operatorLevel2
        case 3: return .operatorLevel3
        case 4: return .operatorLevel4
        default: return .operatorLevel1
        }
    }
    
    static func operatorRatio(_ index: Int) -> MIDIControllableParameter {
        switch index {
        case 1: return .operatorRatio1
        case 2: return .operatorRatio2
        case 3: return .operatorRatio3
        case 4: return .operatorRatio4
        default: return .operatorRatio1
        }
    }
    
    static func operatorDetune(_ index: Int) -> MIDIControllableParameter {
        switch index {
        case 1: return .operatorDetune1
        case 2: return .operatorDetune2
        case 3: return .operatorDetune3
        case 4: return .operatorDetune4
        default: return .operatorDetune1
        }
    }
}

/// Parameter curve types for different response characteristics
public enum ParameterCurveType: String, CaseIterable, Codable {
    case linear = "linear"
    case exponential = "exponential"
    case logarithmic = "logarithmic"
    case sCurve = "s_curve"
}

/// CC mapper delegate protocol
public protocol MIDICCMapperDelegate: AnyObject {
    func ccMapper(_ mapper: MIDICCMapper, didLearnCC cc: UInt8, for parameter: MIDIControllableParameter)
    func ccMapper(_ mapper: MIDICCMapper, processedMessage: MIDIMessage)
    func ccMapper(_ mapper: MIDICCMapper, droppedMessage: MIDIMessage)
}

/// CC mapper errors
public enum MIDICCMapperError: Error {
    case invalidCCNumber(UInt8)
    case mappingNotFound
    case voiceMachineNotSet
}

/// CC mapper statistics
public struct MIDICCMapperStatistics {
    public let totalMappings: Int
    public let processedMessages: Int
    public let droppedMessages: Int
    public let activeTracks: Int
}

// MARK: - Persistence Types

/// Serializable mapping data for persistence
public struct MIDICCMappingData: Codable {
    let version: String
    let mappings: [String: [UInt8: ParameterMappingData]]
    let createdAt: Date
}

/// Serializable parameter mapping data
public struct ParameterMappingData: Codable {
    let parameter: String
    let curveType: String
    let minValue: Float
    let maxValue: Float
    let smoothing: Bool
}

// MARK: - MIDIMessage Extensions

/// Convenient message creation for CC mapper
public extension MIDIMessage {
    static func controlChange(channel: UInt8, controller: UInt8, value: UInt8) -> MIDIMessage {
        return MIDIMessage(
            type: .controlChange,
            channel: channel,
            data1: controller,
            data2: value,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000)
        )
    }
    
    static func noteOn(channel: UInt8, note: UInt8, velocity: UInt8) -> MIDIMessage {
        return MIDIMessage(
            type: .noteOn,
            channel: channel,
            data1: note,
            data2: velocity,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000)
        )
    }
    
    static func noteOff(channel: UInt8, note: UInt8, velocity: UInt8) -> MIDIMessage {
        return MIDIMessage(
            type: .noteOff,
            channel: channel,
            data1: note,
            data2: velocity,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000)
        )
    }
}

// MARK: - VoiceMachineProtocol Extension

/// Extension to support MIDI parameter control
public extension VoiceMachineProtocol {
    func setParameter(_ parameter: MIDIControllableParameter, value: Float) {
        // Default implementation - subclasses should override
        // This method should map MIDI parameters to voice machine specific parameters
        
        // For example, if this is an FMToneVoiceMachine, map parameters appropriately
        // This is a placeholder that voice machines can override
    }
}