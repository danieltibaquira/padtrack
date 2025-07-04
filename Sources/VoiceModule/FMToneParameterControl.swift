import Foundation
import Combine
import MachineProtocols
import AudioEngine

// MARK: - FM TONE Parameter Definitions

/// All FM TONE synthesis parameters organized by category
public enum FMToneParameterID: String, CaseIterable, Codable, Sendable {
    // Algorithm Selection
    case algorithm = "fm_tone_algorithm"
    
    // Master Controls
    case masterVolume = "fm_tone_master_volume"
    case masterTune = "fm_tone_master_tune"
    case portamento = "fm_tone_portamento"
    case pitchBendRange = "fm_tone_pitch_bend_range"
    
    // Operator A Parameters
    case opA_frequency = "fm_tone_op_a_frequency"
    case opA_fineTune = "fm_tone_op_a_fine_tune"
    case opA_outputLevel = "fm_tone_op_a_output_level"
    case opA_modIndex = "fm_tone_op_a_mod_index"
    case opA_feedback = "fm_tone_op_a_feedback"
    case opA_keyTracking = "fm_tone_op_a_key_tracking"
    case opA_velocity = "fm_tone_op_a_velocity"
    
    // Operator B1 Parameters
    case opB1_frequency = "fm_tone_op_b1_frequency"
    case opB1_fineTune = "fm_tone_op_b1_fine_tune"
    case opB1_outputLevel = "fm_tone_op_b1_output_level"
    case opB1_modIndex = "fm_tone_op_b1_mod_index"
    case opB1_feedback = "fm_tone_op_b1_feedback"
    case opB1_keyTracking = "fm_tone_op_b1_key_tracking"
    case opB1_velocity = "fm_tone_op_b1_velocity"
    
    // Operator B2 Parameters
    case opB2_frequency = "fm_tone_op_b2_frequency"
    case opB2_fineTune = "fm_tone_op_b2_fine_tune"
    case opB2_outputLevel = "fm_tone_op_b2_output_level"
    case opB2_modIndex = "fm_tone_op_b2_mod_index"
    case opB2_feedback = "fm_tone_op_b2_feedback"
    case opB2_keyTracking = "fm_tone_op_b2_key_tracking"
    case opB2_velocity = "fm_tone_op_b2_velocity"
    
    // Operator C Parameters
    case opC_frequency = "fm_tone_op_c_frequency"
    case opC_fineTune = "fm_tone_op_c_fine_tune"
    case opC_outputLevel = "fm_tone_op_c_output_level"
    case opC_modIndex = "fm_tone_op_c_mod_index"
    case opC_feedback = "fm_tone_op_c_feedback"
    case opC_keyTracking = "fm_tone_op_c_key_tracking"
    case opC_velocity = "fm_tone_op_c_velocity"
    
    // Envelope Parameters (per operator)
    case opA_env_delay = "fm_tone_op_a_env_delay"
    case opA_env_attack = "fm_tone_op_a_env_attack"
    case opA_env_decay = "fm_tone_op_a_env_decay"
    case opA_env_sustain = "fm_tone_op_a_env_sustain"
    case opA_env_release = "fm_tone_op_a_env_release"
    case opA_env_curve = "fm_tone_op_a_env_curve"
    case opA_env_velSens = "fm_tone_op_a_env_vel_sens"
    case opA_env_keyTrack = "fm_tone_op_a_env_key_track"
    
    case opB1_env_delay = "fm_tone_op_b1_env_delay"
    case opB1_env_attack = "fm_tone_op_b1_env_attack"
    case opB1_env_decay = "fm_tone_op_b1_env_decay"
    case opB1_env_sustain = "fm_tone_op_b1_env_sustain"
    case opB1_env_release = "fm_tone_op_b1_env_release"
    case opB1_env_curve = "fm_tone_op_b1_env_curve"
    case opB1_env_velSens = "fm_tone_op_b1_env_vel_sens"
    case opB1_env_keyTrack = "fm_tone_op_b1_env_key_track"
    
    case opB2_env_delay = "fm_tone_op_b2_env_delay"
    case opB2_env_attack = "fm_tone_op_b2_env_attack"
    case opB2_env_decay = "fm_tone_op_b2_env_decay"
    case opB2_env_sustain = "fm_tone_op_b2_env_sustain"
    case opB2_env_release = "fm_tone_op_b2_env_release"
    case opB2_env_curve = "fm_tone_op_b2_env_curve"
    case opB2_env_velSens = "fm_tone_op_b2_env_vel_sens"
    case opB2_env_keyTrack = "fm_tone_op_b2_env_key_track"
    
    case opC_env_delay = "fm_tone_op_c_env_delay"
    case opC_env_attack = "fm_tone_op_c_env_attack"
    case opC_env_decay = "fm_tone_op_c_env_decay"
    case opC_env_sustain = "fm_tone_op_c_env_sustain"
    case opC_env_release = "fm_tone_op_c_env_release"
    case opC_env_curve = "fm_tone_op_c_env_curve"
    case opC_env_velSens = "fm_tone_op_c_env_vel_sens"
    case opC_env_keyTrack = "fm_tone_op_c_env_key_track"
    
    // LFO Parameters
    case lfo_rate = "fm_tone_lfo_rate"
    case lfo_depth = "fm_tone_lfo_depth"
    case lfo_shape = "fm_tone_lfo_shape"
    case lfo_sync = "fm_tone_lfo_sync"
    case lfo_target = "fm_tone_lfo_target"
    
    public var displayName: String {
        switch self {
        case .algorithm: return "Algorithm"
        case .masterVolume: return "Master Volume"
        case .masterTune: return "Master Tune"
        case .portamento: return "Portamento"
        case .pitchBendRange: return "Pitch Bend Range"
        case .opA_frequency: return "Op A Frequency"
        case .opA_fineTune: return "Op A Fine Tune"
        case .opA_outputLevel: return "Op A Output Level"
        case .opA_modIndex: return "Op A Mod Index"
        case .opA_feedback: return "Op A Feedback"
        case .opA_keyTracking: return "Op A Key Tracking"
        case .opA_velocity: return "Op A Velocity"
        case .opB1_frequency: return "Op B1 Frequency"
        case .opB1_fineTune: return "Op B1 Fine Tune"
        case .opB1_outputLevel: return "Op B1 Output Level"
        case .opB1_modIndex: return "Op B1 Mod Index"
        case .opB1_feedback: return "Op B1 Feedback"
        case .opB1_keyTracking: return "Op B1 Key Tracking"
        case .opB1_velocity: return "Op B1 Velocity"
        case .opB2_frequency: return "Op B2 Frequency"
        case .opB2_fineTune: return "Op B2 Fine Tune"
        case .opB2_outputLevel: return "Op B2 Output Level"
        case .opB2_modIndex: return "Op B2 Mod Index"
        case .opB2_feedback: return "Op B2 Feedback"
        case .opB2_keyTracking: return "Op B2 Key Tracking"
        case .opB2_velocity: return "Op B2 Velocity"
        case .opC_frequency: return "Op C Frequency"
        case .opC_fineTune: return "Op C Fine Tune"
        case .opC_outputLevel: return "Op C Output Level"
        case .opC_modIndex: return "Op C Mod Index"
        case .opC_feedback: return "Op C Feedback"
        case .opC_keyTracking: return "Op C Key Tracking"
        case .opC_velocity: return "Op C Velocity"
        case .opA_env_delay: return "Op A Env Delay"
        case .opA_env_attack: return "Op A Env Attack"
        case .opA_env_decay: return "Op A Env Decay"
        case .opA_env_sustain: return "Op A Env Sustain"
        case .opA_env_release: return "Op A Env Release"
        case .opA_env_curve: return "Op A Env Curve"
        case .opA_env_velSens: return "Op A Env Vel Sens"
        case .opA_env_keyTrack: return "Op A Env Key Track"
        case .opB1_env_delay: return "Op B1 Env Delay"
        case .opB1_env_attack: return "Op B1 Env Attack"
        case .opB1_env_decay: return "Op B1 Env Decay"
        case .opB1_env_sustain: return "Op B1 Env Sustain"
        case .opB1_env_release: return "Op B1 Env Release"
        case .opB1_env_curve: return "Op B1 Env Curve"
        case .opB1_env_velSens: return "Op B1 Env Vel Sens"
        case .opB1_env_keyTrack: return "Op B1 Env Key Track"
        case .opB2_env_delay: return "Op B2 Env Delay"
        case .opB2_env_attack: return "Op B2 Env Attack"
        case .opB2_env_decay: return "Op B2 Env Decay"
        case .opB2_env_sustain: return "Op B2 Env Sustain"
        case .opB2_env_release: return "Op B2 Env Release"
        case .opB2_env_curve: return "Op B2 Env Curve"
        case .opB2_env_velSens: return "Op B2 Env Vel Sens"
        case .opB2_env_keyTrack: return "Op B2 Env Key Track"
        case .opC_env_delay: return "Op C Env Delay"
        case .opC_env_attack: return "Op C Env Attack"
        case .opC_env_decay: return "Op C Env Decay"
        case .opC_env_sustain: return "Op C Env Sustain"
        case .opC_env_release: return "Op C Env Release"
        case .opC_env_curve: return "Op C Env Curve"
        case .opC_env_velSens: return "Op C Env Vel Sens"
        case .opC_env_keyTrack: return "Op C Env Key Track"
        case .lfo_rate: return "LFO Rate"
        case .lfo_depth: return "LFO Depth"
        case .lfo_shape: return "LFO Shape"
        case .lfo_sync: return "LFO Sync"
        case .lfo_target: return "LFO Target"
        }
    }
}

// MARK: - Parameter Categories

public enum FMToneParameterCategory: String, CaseIterable {
    case master = "master"
    case algorithm = "algorithm"
    case operatorA = "operator_a"
    case operatorB1 = "operator_b1"
    case operatorB2 = "operator_b2"
    case operatorC = "operator_c"
    case envelopeA = "envelope_a"
    case envelopeB1 = "envelope_b1"
    case envelopeB2 = "envelope_b2"
    case envelopeC = "envelope_c"
    case lfo = "lfo"
    
    public var displayName: String {
        switch self {
        case .master: return "Master"
        case .algorithm: return "Algorithm"
        case .operatorA: return "Operator A"
        case .operatorB1: return "Operator B1"
        case .operatorB2: return "Operator B2"
        case .operatorC: return "Operator C"
        case .envelopeA: return "Envelope A"
        case .envelopeB1: return "Envelope B1"
        case .envelopeB2: return "Envelope B2"
        case .envelopeC: return "Envelope C"
        case .lfo: return "LFO"
        }
    }
}

// MARK: - MIDI CC Mapping

/// MIDI mapping curve types
public enum MappingCurve: String, CaseIterable, Codable, Sendable {
    case linear = "linear"
    case exponential = "exponential"
    case logarithmic = "logarithmic"
    case sCurve = "s_curve"

    /// Apply the curve to a normalized value (0.0-1.0)
    public func apply(_ value: Float) -> Float {
        switch self {
        case .linear:
            return value
        case .exponential:
            return value * value
        case .logarithmic:
            return sqrt(value)
        case .sCurve:
            return 0.5 * (1.0 + sin(Float.pi * (value - 0.5)))
        }
    }
}

/// FM TONE MIDI CC mapping configuration
public struct FMToneMIDIMapping: Codable, Sendable {
    public let id: String
    public let parameterID: FMToneParameterID
    public let midiCC: Int
    public let minValue: Float
    public let maxValue: Float
    public let curve: MappingCurve
    public let isActive: Bool
    
    public init(
        id: String = UUID().uuidString,
        parameterID: FMToneParameterID,
        midiCC: Int,
        minValue: Float,
        maxValue: Float,
        curve: MappingCurve = .linear,
        isActive: Bool = true
    ) {
        self.id = id
        self.parameterID = parameterID
        self.midiCC = midiCC
        self.minValue = minValue
        self.maxValue = maxValue
        self.curve = curve
        self.isActive = isActive
    }
}

// MARK: - FM TONE Parameter Control System

/// Comprehensive parameter control system for FM TONE synthesis
public final class FMToneParameterControl: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let parameterManager: ParameterManager
    private var smoothers: [String: ParameterSmoother] = [:]
    private var midiMappings: [Int: FMToneMIDIMapping] = [:]
    private let controlQueue = DispatchQueue(label: "FMToneParameterControl", qos: .userInitiated)
    
    // Callbacks
    public var parameterChangeCallback: ((FMToneParameterID, Float) -> Void)?
    public var midiLearnCallback: ((FMToneParameterID, Int) -> Void)?
    
    // MIDI Learn state
    private var midiLearnMode = false
    private var midiLearnParameter: FMToneParameterID?
    
    // Performance monitoring
    private var updateCount: Int = 0
    private var lastUpdateTime: CFTimeInterval = 0
    
    // MARK: - Initialization
    
    public init(sampleRate: Float = 44100.0) {
        self.parameterManager = ParameterManager()
        
        // Initialize all FM TONE parameters
        setupParameters()
        
        // Initialize parameter smoothers
        setupParameterSmoothers(sampleRate: sampleRate)
        
        // Setup default MIDI mappings
        setupDefaultMIDIMappings()
        
        // Setup parameter change callbacks
        setupParameterCallbacks()
    }
    
    // MARK: - Parameter Setup
    
    private func setupParameters() {
        // Algorithm parameter
        let algorithmParam = Parameter(
            id: FMToneParameterID.algorithm.rawValue,
            name: FMToneParameterID.algorithm.displayName,
            value: 1.0,
            minValue: 1.0,
            maxValue: 8.0,
            defaultValue: 1.0,
            category: .synthesis,
            dataType: .integer,
            scaling: .discrete,
            stepSize: 1.0,
            enumerationValues: ["Algorithm 1", "Algorithm 2", "Algorithm 3", "Algorithm 4", 
                              "Algorithm 5", "Algorithm 6", "Algorithm 7", "Algorithm 8"]
        )
        parameterManager.addParameter(algorithmParam)
        
        // Master parameters
        setupMasterParameters()
        
        // Operator parameters
        setupOperatorParameters()
        
        // Envelope parameters
        setupEnvelopeParameters()
        
        // LFO parameters
        setupLFOParameters()
    }
    
    private func setupMasterParameters() {
        let masterParams: [(FMToneParameterID, Float, Float, Float, String?)] = [
            (.masterVolume, 0.8, 0.0, 1.0, nil),
            (.masterTune, 0.0, -24.0, 24.0, "semitones"),
            (.portamento, 0.0, 0.0, 1.0, "seconds"),
            (.pitchBendRange, 2.0, 0.0, 24.0, "semitones")
        ]
        
        for (paramID, defaultValue, minValue, maxValue, unit) in masterParams {
            let param = Parameter(
                id: paramID.rawValue,
                name: paramID.displayName,
                value: defaultValue,
                minValue: minValue,
                maxValue: maxValue,
                defaultValue: defaultValue,
                unit: unit,
                category: .synthesis
            )
            parameterManager.addParameter(param)
        }
    }
    
    private func setupOperatorParameters() {
        let operators: [String] = ["A", "B1", "B2", "C"]
        let operatorParamSpecs: [(String, Float, Float, Float, String?)] = [
            ("frequency", 1.0, 0.1, 32.0, "ratio"),
            ("fine_tune", 0.0, -100.0, 100.0, "cents"),
            ("output_level", 0.8, 0.0, 1.0, nil),
            ("mod_index", 0.0, 0.0, 10.0, nil),
            ("feedback", 0.0, 0.0, 1.0, nil),
            ("key_tracking", 1.0, 0.0, 2.0, nil),
            ("velocity", 0.5, 0.0, 1.0, nil)
        ]
        
        for op in operators {
            for (paramName, defaultValue, minValue, maxValue, unit) in operatorParamSpecs {
                let paramID = "fm_tone_op_\(op.lowercased())_\(paramName)"
                let displayName = "Op \(op) \(paramName.capitalized.replacingOccurrences(of: "_", with: " "))"
                
                let param = Parameter(
                    id: paramID,
                    name: displayName,
                    value: defaultValue,
                    minValue: minValue,
                    maxValue: maxValue,
                    defaultValue: defaultValue,
                    unit: unit,
                    category: .synthesis
                )
                parameterManager.addParameter(param)
            }
        }
    }
    
    private func setupEnvelopeParameters() {
        let operators = ["A", "B1", "B2", "C"]
        let envelopeParamSpecs: [(String, Float, Float, Float, String?)] = [
            ("delay", 0.0, 0.0, 5.0, "seconds"),
            ("attack", 0.01, 0.001, 10.0, "seconds"),
            ("decay", 0.3, 0.001, 10.0, "seconds"),
            ("sustain", 0.7, 0.0, 1.0, nil),
            ("release", 0.5, 0.001, 10.0, "seconds"),
            ("curve", 1.0, 0.0, 4.0, nil), // Linear, Exp, Log, Sine, Power
            ("vel_sens", 0.5, 0.0, 1.0, nil),
            ("key_track", 0.0, -1.0, 1.0, nil)
        ]
        
        for op in operators {
            for (paramName, defaultValue, minValue, maxValue, unit) in envelopeParamSpecs {
                let paramID = "fm_tone_op_\(op.lowercased())_env_\(paramName)"
                let displayName = "Op \(op) Env \(paramName.capitalized.replacingOccurrences(of: "_", with: " "))"
                
                var param = Parameter(
                    id: paramID,
                    name: displayName,
                    value: defaultValue,
                    minValue: minValue,
                    maxValue: maxValue,
                    defaultValue: defaultValue,
                    unit: unit,
                    category: .envelope
                )
                
                // Special handling for curve parameter
                if paramName == "curve" {
                    param = Parameter(
                        id: paramID,
                        name: displayName,
                        value: defaultValue,
                        minValue: minValue,
                        maxValue: maxValue,
                        defaultValue: defaultValue,
                        unit: unit,
                        category: .envelope,
                        dataType: .enumeration,
                        scaling: .discrete,
                        stepSize: 1.0,
                        enumerationValues: ["Linear", "Exponential", "Logarithmic", "Sine", "Power"]
                    )
                }
                
                parameterManager.addParameter(param)
            }
        }
    }
    
    private func setupLFOParameters() {
        let lfoParams: [(FMToneParameterID, Float, Float, Float, String?, ParameterDataType, [String]?)] = [
            (.lfo_rate, 2.0, 0.1, 20.0, "Hz", .float, nil),
            (.lfo_depth, 0.0, 0.0, 1.0, nil, .float, nil),
            (.lfo_shape, 0.0, 0.0, 3.0, nil, .enumeration, ["Sine", "Triangle", "Square", "Sawtooth"]),
            (.lfo_sync, 0.0, 0.0, 1.0, nil, .boolean, nil),
            (.lfo_target, 0.0, 0.0, 10.0, nil, .enumeration, 
             ["Off", "Op A Freq", "Op B1 Freq", "Op B2 Freq", "Op C Freq", 
              "Op A Level", "Op B1 Level", "Op B2 Level", "Op C Level", 
              "Filter Cutoff", "Master Volume"])
        ]
        
        for (paramID, defaultValue, minValue, maxValue, unit, dataType, enumValues) in lfoParams {
            let param = Parameter(
                id: paramID.rawValue,
                name: paramID.displayName,
                value: defaultValue,
                minValue: minValue,
                maxValue: maxValue,
                defaultValue: defaultValue,
                unit: unit,
                category: .modulation,
                dataType: dataType,
                scaling: dataType == .enumeration ? .discrete : .linear,
                stepSize: dataType == .enumeration ? 1.0 : nil,
                enumerationValues: enumValues
            )
            parameterManager.addParameter(param)
        }
    }
    
    // MARK: - Parameter Smoothing Setup
    
    private func setupParameterSmoothers(sampleRate: Float) {
        controlQueue.sync {
            for paramID in FMToneParameterID.allCases {
                let smoothingTime: Float
                
                // Different smoothing times for different parameter types
                switch paramID {
                case .algorithm:
                    smoothingTime = 0.001 // Very fast for discrete changes
                case .masterVolume, .opA_outputLevel, .opB1_outputLevel, .opB2_outputLevel, .opC_outputLevel:
                    smoothingTime = 0.005 // Fast for levels
                case .opA_frequency, .opB1_frequency, .opB2_frequency, .opC_frequency,
                     .opA_fineTune, .opB1_fineTune, .opB2_fineTune, .opC_fineTune:
                    smoothingTime = 0.01 // Medium for frequencies
                default:
                    smoothingTime = 0.02 // Standard smoothing
                }
                
                let currentValue = parameterManager.getParameterValue(id: paramID.rawValue) ?? 0.0
                let smoother = ParameterSmoother(sampleRate: sampleRate, smoothingTime: smoothingTime)
                smoother.reset(currentValue)
                smoothers[paramID.rawValue] = smoother
            }
        }
    }
    
    // MARK: - Default MIDI Mappings
    
    private func setupDefaultMIDIMappings() {
        let defaultMappings: [(Int, FMToneParameterID)] = [
            // Standard MIDI CCs
            (1, .lfo_depth),        // Modulation Wheel
            (7, .masterVolume),     // Volume
            (10, .lfo_rate),        // Pan (repurposed)
            (11, .opA_outputLevel), // Expression
            (12, .opB1_outputLevel),
            (13, .opB2_outputLevel),
            (14, .opC_outputLevel),
            (15, .algorithm),
            
            // Assignable CCs for operator controls
            (16, .opA_frequency),
            (17, .opB1_frequency),
            (18, .opB2_frequency),
            (19, .opC_frequency),
            (20, .opA_modIndex),
            (21, .opB1_modIndex),
            (22, .opB2_modIndex),
            (23, .opC_modIndex),
            
            // Envelope controls
            (24, .opA_env_attack),
            (25, .opA_env_decay),
            (26, .opA_env_sustain),
            (27, .opA_env_release),
            (28, .opB1_env_attack),
            (29, .opB1_env_decay),
            (30, .opB1_env_sustain),
            (31, .opB1_env_release)
        ]
        
        controlQueue.sync {
            for (cc, paramID) in defaultMappings {
                if let param = parameterManager.getParameter(id: paramID.rawValue) {
                    let mapping = FMToneMIDIMapping(
                        parameterID: paramID,
                        midiCC: cc,
                        minValue: param.minValue,
                        maxValue: param.maxValue
                    )
                    midiMappings[cc] = mapping
                }
            }
        }
    }
    
    // MARK: - Parameter Callbacks
    
    private func setupParameterCallbacks() {
        parameterManager.globalChangeCallback = { [weak self] parameterID, oldValue, newValue in
            guard let self = self,
                  let paramID = FMToneParameterID(rawValue: parameterID) else { return }
            
            // Update smoother target
            self.controlQueue.async {
                self.smoothers[parameterID]?.setTarget(newValue)
            }
            
            // Notify callback
            self.parameterChangeCallback?(paramID, newValue)
        }
    }
}

// MARK: - Public Interface

extension FMToneParameterControl {
    
    /// Get current parameter value
    public func getParameterValue(_ parameterID: FMToneParameterID) -> Float? {
        return parameterManager.getParameterValue(id: parameterID.rawValue)
    }
    
    /// Set parameter value with optional smoothing
    public func setParameterValue(_ parameterID: FMToneParameterID, value: Float, smooth: Bool = true) {
        do {
            try parameterManager.updateParameter(id: parameterID.rawValue, value: value, notifyChange: smooth)
            
            if !smooth {
                // Immediately update smoother for non-smoothed changes
                controlQueue.async {
                    self.smoothers[parameterID.rawValue]?.setTarget(value)
                }
            }
        } catch {
            print("Failed to set parameter \(parameterID.rawValue): \(error)")
        }
    }
    
    /// Get smoothed parameter value (call from audio thread)
    public func getSmoothedValue(_ parameterID: FMToneParameterID) -> Float {
        return controlQueue.sync {
            smoothers[parameterID.rawValue]?.process() ?? 0.0
        }
    }
    
    /// Process MIDI CC message
    public func processMIDICC(_ cc: Int, value: Int) {
        controlQueue.async {
            // Handle MIDI learn mode
            if self.midiLearnMode, let learnParam = self.midiLearnParameter {
                self.assignMIDICC(cc, to: learnParam)
                self.midiLearnMode = false
                self.midiLearnParameter = nil
                self.midiLearnCallback?(learnParam, cc)
                return
            }
            
            // Process existing mapping
            guard let mapping = self.midiMappings[cc], mapping.isActive else { return }
            
            let normalizedValue = Float(value) / 127.0
            let curvedValue = mapping.curve.apply(normalizedValue)
            let scaledValue = mapping.minValue + curvedValue * (mapping.maxValue - mapping.minValue)
            
            self.setParameterValue(mapping.parameterID, value: scaledValue)
        }
    }
    
    /// Start MIDI learn mode for a parameter
    public func startMIDILearn(for parameterID: FMToneParameterID) {
        controlQueue.sync {
            midiLearnMode = true
            midiLearnParameter = parameterID
        }
    }
    
    /// Cancel MIDI learn mode
    public func cancelMIDILearn() {
        controlQueue.sync {
            midiLearnMode = false
            midiLearnParameter = nil
        }
    }
    
    /// Assign MIDI CC to parameter
    public func assignMIDICC(_ cc: Int, to parameterID: FMToneParameterID) {
        controlQueue.sync {
            guard let param = parameterManager.getParameter(id: parameterID.rawValue) else { return }
            
            let mapping = FMToneMIDIMapping(
                parameterID: parameterID,
                midiCC: cc,
                minValue: param.minValue,
                maxValue: param.maxValue
            )
            midiMappings[cc] = mapping
        }
    }
    
    /// Remove MIDI CC mapping
    public func removeMIDICC(_ cc: Int) {
        controlQueue.sync {
            midiMappings.removeValue(forKey: cc)
        }
    }
    
    /// Get all MIDI mappings
    public func getMIDIMappings() -> [FMToneMIDIMapping] {
        return controlQueue.sync {
            Array(midiMappings.values)
        }
    }
    
    /// Reset all parameters to defaults
    public func resetToDefaults() {
        parameterManager.resetAllToDefaults()
    }
    
    /// Create preset from current parameters
    public func createPreset(name: String, description: String? = nil) -> ParameterPreset {
        return parameterManager.createPreset(name: name, description: description)
    }
    
    /// Load preset
    public func loadPreset(_ preset: ParameterPreset) throws {
        try parameterManager.loadPreset(preset)
    }
    
    /// Get parameters by category
    public func getParametersByCategory(_ category: FMToneParameterCategory) -> [Parameter] {
        let categoryParams = FMToneParameterID.allCases.filter { paramID in
            switch category {
            case .master:
                return [.masterVolume, .masterTune, .portamento, .pitchBendRange].contains(paramID)
            case .algorithm:
                return paramID == .algorithm
            case .operatorA:
                return paramID.rawValue.contains("op_a_") && !paramID.rawValue.contains("env")
            case .operatorB1:
                return paramID.rawValue.contains("op_b1_") && !paramID.rawValue.contains("env")
            case .operatorB2:
                return paramID.rawValue.contains("op_b2_") && !paramID.rawValue.contains("env")
            case .operatorC:
                return paramID.rawValue.contains("op_c_") && !paramID.rawValue.contains("env")
            case .envelopeA:
                return paramID.rawValue.contains("op_a_env")
            case .envelopeB1:
                return paramID.rawValue.contains("op_b1_env")
            case .envelopeB2:
                return paramID.rawValue.contains("op_b2_env")
            case .envelopeC:
                return paramID.rawValue.contains("op_c_env")
            case .lfo:
                return paramID.rawValue.contains("lfo")
            }
        }
        
        return categoryParams.compactMap { parameterManager.getParameter(id: $0.rawValue) }
    }
} 