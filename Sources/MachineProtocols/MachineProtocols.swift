// MachineProtocols.swift
// DigitonePad - MachineProtocols Module
//
// This module defines the core protocols that prevent circular dependencies
// between other modules in the DigitonePad application.

import Foundation

// MARK: - Core Protocol Hierarchy

/// Base protocol for all audio processing machines
/// Provides fundamental functionality required by all machine types
public protocol MachineProtocol: AnyObject {
    /// Unique identifier for the machine instance
    var id: UUID { get }
    
    /// Human-readable name for the machine
    var name: String { get set }
    
    /// Whether the machine is currently active/enabled
    var isEnabled: Bool { get set }
    
    /// Whether the machine has been properly initialized
    var isInitialized: Bool { get }
    
    /// Current operational status of the machine
    var status: MachineStatus { get }
    
    /// Timestamp of last activity
    var lastActiveTimestamp: Date? { get }
    
    /// Current error state, if any
    var lastError: MachineError? { get }
    
    /// Error handling callback
    var errorHandler: ((MachineError) -> Void)? { get set }
    
    /// Performance metrics for monitoring
    var performanceMetrics: MachinePerformanceMetrics { get }
    
    /// Machine-specific parameters
    var parameters: ParameterManager { get }
    
    // MARK: - Lifecycle Methods
    
    /// Initialize the machine with given configuration
    func initialize(configuration: MachineConfiguration) throws
    
    /// Start the machine operation
    func start() throws
    
    /// Stop the machine operation
    func stop() throws
    
    /// Suspend machine operation (can be resumed)
    func suspend() throws
    
    /// Resume machine operation from suspended state
    func resume() throws
    
    /// Reset the machine to its initial state
    func reset()
    
    // MARK: - Audio Processing
    
    /// Process audio input and return processed output
    func process(input: AudioBuffer) -> AudioBuffer
    
    // MARK: - Parameter Management
    
    /// Update a specific parameter
    func updateParameter(key: String, value: Any) throws
    
    /// Validate all current parameters
    func validateParameters() throws -> Bool
    
    // MARK: - Status and Health
    
    /// Perform a health check on the machine
    func healthCheck() -> MachineHealthStatus
    
    /// Reset performance counters
    func resetPerformanceCounters()
    
    // MARK: - Serialization
    
    /// Get current machine state for serialization
    func getState() -> MachineState
    
    /// Set machine state from serialized data
    func setState(_ state: MachineState)
}

// MARK: - Supporting Types

/// Machine operational status
public enum MachineStatus: String, CaseIterable, Codable {
    case uninitialized = "uninitialized"
    case initializing = "initializing"
    case ready = "ready"
    case running = "running"
    case suspended = "suspended"
    case stopping = "stopping"
    case error = "error"
}

/// Machine health status
public enum MachineHealthStatus: String, CaseIterable, Codable {
    case healthy = "healthy"
    case warning = "warning"
    case critical = "critical"
    case unknown = "unknown"
}

/// Machine configuration for initialization
public struct MachineConfiguration: Codable {
    public let sampleRate: Double
    public let bufferSize: Int
    public let channelCount: Int
    public let parameters: [String: String]
    
    public init(sampleRate: Double, bufferSize: Int, channelCount: Int, parameters: [String: String] = [:]) {
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
        self.channelCount = channelCount
        self.parameters = parameters
    }
}

/// Performance metrics for machine monitoring
public struct MachinePerformanceMetrics: Codable {
    public var cpuUsage: Double = 0.0
    public var memoryUsage: Int = 0
    public var processedSamples: Int = 0
    public var droppedSamples: Int = 0
    public var averageProcessingTime: Double = 0.0
    public var peakProcessingTime: Double = 0.0
    public var errorCount: Int = 0
    
    public init() {}
    
    public mutating func reset() {
        cpuUsage = 0.0
        memoryUsage = 0
        processedSamples = 0
        droppedSamples = 0
        averageProcessingTime = 0.0
        peakProcessingTime = 0.0
        errorCount = 0
    }
}

/// Base protocol for machine errors
public protocol MachineError: Error {
    var code: String { get }
    var message: String { get }
    var severity: ErrorSeverity { get }
    var timestamp: Date { get }
}

/// Error severity levels
public enum ErrorSeverity: String, CaseIterable, Codable, Sendable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
}

/// Common machine error implementation
public struct CommonMachineError: MachineError {
    public let code: String
    public let message: String
    public let severity: ErrorSeverity
    public let timestamp: Date
    
    public init(code: String, message: String, severity: ErrorSeverity) {
        self.code = code
        self.message = message
        self.severity = severity
        self.timestamp = Date()
    }
}

// MARK: - Specialized Protocols

/// Voice state information
public struct VoiceState: Sendable, Codable {
    public let voiceId: Int
    public let note: UInt8
    public let velocity: UInt8
    public let startTime: UInt64
    public let isActive: Bool
    public let amplitude: Float

    public init(voiceId: Int, note: UInt8, velocity: UInt8, startTime: UInt64, isActive: Bool = true, amplitude: Float = 1.0) {
        self.voiceId = voiceId
        self.note = note
        self.velocity = velocity
        self.startTime = startTime
        self.isActive = isActive
        self.amplitude = amplitude
    }
}

/// Voice allocation information
public struct VoiceAllocation: Sendable {
    public let voiceId: Int
    public let note: UInt8
    public let velocity: UInt8
    public let timestamp: UInt64

    public init(voiceId: Int, note: UInt8, velocity: UInt8, timestamp: UInt64) {
        self.voiceId = voiceId
        self.note = note
        self.velocity = velocity
        self.timestamp = timestamp
    }
}

/// Protocol for voice/synthesis machines
/// Extends MachineProtocol with voice-specific functionality
public protocol VoiceMachineProtocol: MachineProtocol {
    // MARK: - Voice Management

    /// Trigger a note with given parameters
    func noteOn(note: UInt8, velocity: UInt8)

    /// Trigger a note with additional parameters
    func noteOn(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?)

    /// Release a note
    func noteOff(note: UInt8)

    /// Release a note with additional parameters
    func noteOff(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?)

    /// Release all currently playing notes
    func allNotesOff()

    /// Release all notes on a specific channel
    func allNotesOff(channel: UInt8)

    /// Number of simultaneous voices supported
    var polyphony: Int { get set }

    /// Current number of active voices
    var activeVoices: Int { get }

    /// Voice stealing behavior when polyphony limit is reached
    var voiceStealingMode: VoiceStealingMode { get set }

    /// Get current voice states
    var voiceStates: [VoiceState] { get }

    /// Get voice allocation information
    func getVoiceAllocation(for note: UInt8) -> VoiceAllocation?

    // MARK: - Voice-Specific Parameters

    /// Master volume (0.0 to 1.0)
    var masterVolume: Float { get set }

    /// Master tuning in cents (-100 to +100)
    var masterTuning: Float { get set }

    /// Portamento/glide time in seconds
    var portamentoTime: Float { get set }

    /// Whether portamento is enabled
    var portamentoEnabled: Bool { get set }

    /// Velocity sensitivity (0.0 to 1.0)
    var velocitySensitivity: Float { get set }

    /// Pitch bend range in semitones
    var pitchBendRange: Float { get set }

    /// Current pitch bend value (-1.0 to +1.0)
    var pitchBend: Float { get set }

    /// Modulation wheel value (0.0 to 1.0)
    var modWheel: Float { get set }

    // MARK: - Voice Synthesis Parameters

    /// Initialize voice-specific parameters
    func setupVoiceParameters()

    /// Get voice-specific parameter groups
    func getVoiceParameterGroups() -> [ParameterGroup]

    /// Apply pitch bend to all active voices
    func applyPitchBend(_ value: Float)

    /// Apply modulation to all active voices
    func applyModulation(_ value: Float)

    /// Set voice parameter value for specific voice
    func setVoiceParameter(voiceId: Int, parameterId: String, value: Float) throws

    /// Get voice parameter value for specific voice
    func getVoiceParameter(voiceId: Int, parameterId: String) -> Float?

    // MARK: - Voice Events

    /// Handle sustain pedal changes
    func setSustainPedal(_ enabled: Bool)

    /// Handle sostenuto pedal changes
    func setSostenutoPedal(_ enabled: Bool)

    /// Handle soft pedal changes
    func setSoftPedal(_ enabled: Bool)

    /// Handle aftertouch (channel pressure)
    func setAftertouch(_ pressure: Float)

    /// Handle polyphonic aftertouch (key pressure)
    func setPolyphonicAftertouch(note: UInt8, pressure: Float)
}

/// Filter response characteristics
public struct FilterResponse: Sendable, Codable {
    public let frequency: Float
    public let magnitude: Float
    public let phase: Float

    public init(frequency: Float, magnitude: Float, phase: Float) {
        self.frequency = frequency
        self.magnitude = magnitude
        self.phase = phase
    }
}

/// Filter slope options
public enum FilterSlope: String, CaseIterable, Codable, Sendable {
    case slope6dB = "6dB"      // 1-pole
    case slope12dB = "12dB"    // 2-pole
    case slope18dB = "18dB"    // 3-pole
    case slope24dB = "24dB"    // 4-pole
    case slope36dB = "36dB"    // 6-pole
    case slope48dB = "48dB"    // 8-pole
}

/// Filter quality modes
public enum FilterQuality: String, CaseIterable, Codable, Sendable {
    case low = "low"           // Fast, lower quality
    case medium = "medium"     // Balanced
    case high = "high"         // Slow, higher quality
    case ultra = "ultra"       // Highest quality, slowest
}

/// Protocol for filter machines
/// Extends MachineProtocol with filter-specific functionality
public protocol FilterMachineProtocol: MachineProtocol {
    // MARK: - Core Filter Parameters

    /// Filter cutoff frequency (in Hz)
    var cutoff: Float { get set }

    /// Filter resonance (0.0 to 1.0)
    var resonance: Float { get set }

    /// Filter type/mode
    var filterType: FilterType { get set }

    /// Filter drive/distortion amount (0.0 to 1.0)
    var drive: Float { get set }

    /// Filter slope/order
    var slope: FilterSlope { get set }

    /// Filter quality/oversampling
    var quality: FilterQuality { get set }

    // MARK: - Advanced Filter Parameters

    /// Filter gain for peak/shelf filters (in dB)
    var gain: Float { get set }

    /// Filter bandwidth for bandpass/notch filters (in octaves)
    var bandwidth: Float { get set }

    /// Filter key tracking amount (0.0 to 1.0)
    var keyTracking: Float { get set }

    /// Filter velocity sensitivity (0.0 to 1.0)
    var velocitySensitivity: Float { get set }

    /// Filter envelope amount (-1.0 to 1.0)
    var envelopeAmount: Float { get set }

    /// Filter LFO amount (-1.0 to 1.0)
    var lfoAmount: Float { get set }

    /// Filter modulation input amount (-1.0 to 1.0)
    var modulationAmount: Float { get set }

    // MARK: - Filter State and Analysis

    /// Whether the filter is currently active
    var isActive: Bool { get set }

    /// Current filter state (for debugging/visualization)
    var filterState: [String: Float] { get }

    /// Get frequency response at specific frequency
    func getFrequencyResponse(at frequency: Float) -> FilterResponse

    /// Get frequency response curve over range
    func getFrequencyResponseCurve(startFreq: Float, endFreq: Float, points: Int) -> [FilterResponse]

    // MARK: - Filter Control

    /// Reset filter state (clear delay lines, etc.)
    func resetFilterState()

    /// Set filter parameters from preset
    func loadFilterPreset(_ preset: FilterPreset)

    /// Get current filter settings as preset
    func saveFilterPreset(name: String) -> FilterPreset

    /// Initialize filter-specific parameters
    func setupFilterParameters()

    /// Get filter-specific parameter groups
    func getFilterParameterGroups() -> [ParameterGroup]

    /// Apply modulation to filter parameters
    func applyFilterModulation(envelope: Float, lfo: Float, modulation: Float)

    /// Update filter coefficients (called when parameters change)
    func updateFilterCoefficients()

    // MARK: - Real-time Control

    /// Set cutoff with key tracking applied
    func setCutoffWithKeyTracking(baseFreq: Float, note: UInt8, velocity: UInt8)

    /// Modulate filter in real-time
    func modulateFilter(cutoffMod: Float, resonanceMod: Float)
}

/// Effect processing mode
public enum EffectProcessingMode: String, CaseIterable, Codable, Sendable {
    case insert = "insert"         // Effect processes the entire signal
    case send = "send"             // Effect processes a copy of the signal
    case sidechain = "sidechain"   // Effect uses external sidechain input
}

/// Effect quality settings
public enum EffectQuality: String, CaseIterable, Codable, Sendable {
    case draft = "draft"           // Lowest quality, fastest processing
    case good = "good"             // Balanced quality and performance
    case high = "high"             // High quality, slower processing
    case ultra = "ultra"           // Highest quality, slowest processing
}

/// Effect preset for saving/loading effect configurations
public struct EffectPreset: Codable, Sendable {
    public let name: String
    public let description: String?
    public let effectType: EffectType
    public let parameters: [String: Float]
    public let processingMode: EffectProcessingMode
    public let quality: EffectQuality
    public let wetLevel: Float
    public let dryLevel: Float
    public let metadata: [String: String]
    public let createdAt: Date

    public init(
        name: String,
        description: String? = nil,
        effectType: EffectType,
        parameters: [String: Float],
        processingMode: EffectProcessingMode = .insert,
        quality: EffectQuality = .good,
        wetLevel: Float = 1.0,
        dryLevel: Float = 1.0,
        metadata: [String: String] = [:]
    ) {
        self.name = name
        self.description = description
        self.effectType = effectType
        self.parameters = parameters
        self.processingMode = processingMode
        self.quality = quality
        self.wetLevel = wetLevel
        self.dryLevel = dryLevel
        self.metadata = metadata
        self.createdAt = Date()
    }
}

/// Protocol for effect machines
/// Extends MachineProtocol with effect-specific functionality
public protocol FXProcessorProtocol: MachineProtocol {
    // MARK: - Core Effect Parameters

    /// Wet/dry mix control (0.0 = dry, 1.0 = wet)
    var wetLevel: Float { get set }

    /// Dry signal level (0.0 to 1.0)
    var dryLevel: Float { get set }

    /// Bypass the effect processing
    var isBypassed: Bool { get set }

    /// Effect type identifier
    var effectType: EffectType { get }

    /// Effect processing mode
    var processingMode: EffectProcessingMode { get set }

    /// Effect quality setting
    var quality: EffectQuality { get set }

    // MARK: - Advanced Effect Parameters

    /// Input gain (in dB)
    var inputGain: Float { get set }

    /// Output gain (in dB)
    var outputGain: Float { get set }

    /// Effect intensity/depth (0.0 to 1.0)
    var intensity: Float { get set }

    /// Effect rate/speed parameter
    var rate: Float { get set }

    /// Effect feedback amount (0.0 to 1.0)
    var feedback: Float { get set }

    /// Effect modulation depth (0.0 to 1.0)
    var modDepth: Float { get set }

    /// Effect stereo width (-1.0 to 1.0)
    var stereoWidth: Float { get set }

    // MARK: - Effect State and Analysis

    /// Current effect processing latency in samples
    var latency: Int { get }

    /// Whether the effect is currently processing audio
    var isProcessing: Bool { get }

    /// Current effect state for visualization
    var effectState: [String: Float] { get }

    /// Peak input level for metering
    var inputPeak: Float { get }

    /// Peak output level for metering
    var outputPeak: Float { get }

    // MARK: - Effect Control

    /// Reset effect state (clear delay lines, reverb tails, etc.)
    func resetEffectState()

    /// Flush effect buffers (for tempo sync, etc.)
    func flushBuffers()

    /// Set effect parameters from preset
    func loadEffectPreset(_ preset: EffectPreset)

    /// Get current effect settings as preset
    func saveEffectPreset(name: String) -> EffectPreset

    /// Initialize effect-specific parameters
    func setupEffectParameters()

    /// Get effect-specific parameter groups
    func getEffectParameterGroups() -> [ParameterGroup]

    /// Process audio with sidechain input (if supported)
    func processSidechain(input: AudioBuffer, sidechain: AudioBuffer?) -> AudioBuffer

    /// Get effect tail time in seconds (for reverbs, delays, etc.)
    func getTailTime() -> Double

    /// Set tempo sync information
    func setTempoSync(bpm: Double, timeSignature: TimeSignature)

    // MARK: - Real-time Control

    /// Modulate effect parameters in real-time
    func modulateEffect(intensity: Float, rate: Float, feedback: Float)

    /// Set effect parameter with automation
    func setEffectParameter(id: String, value: Float, smoothTime: Float)

    /// Trigger effect-specific actions (tap tempo, freeze, etc.)
    func triggerAction(_ action: String, value: Float)
}

// MARK: - Shared Data Structures

/// Basic audio buffer structure for audio processing
public struct AudioBuffer {
    public let sampleRate: Double
    public let channelCount: Int
    public let frameCount: Int
    public var samples: [Float]

    public init(sampleRate: Double, channelCount: Int, frameCount: Int, samples: [Float]) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.frameCount = frameCount
        self.samples = samples
    }

    /// Legacy data property for compatibility
    public var data: [Float] {
        get { samples }
        set { samples = newValue }
    }

    /// Create an empty buffer with specified properties
    public static func empty(sampleRate: Double, channelCount: Int, frameCount: Int) -> AudioBuffer {
        return AudioBuffer(
            sampleRate: sampleRate,
            channelCount: channelCount,
            frameCount: frameCount,
            samples: Array(repeating: 0.0, count: frameCount * channelCount)
        )
    }

    /// Convenience initializer
    public init(sampleRate: Double, channelCount: Int, frameCount: Int) {
        self.init(
            sampleRate: sampleRate,
            channelCount: channelCount,
            frameCount: frameCount,
            samples: Array(repeating: 0.0, count: frameCount * channelCount)
        )
    }
}

/// Machine state for serialization/deserialization
public struct MachineState: Codable {
    public let machineType: String
    public let parameters: [String: Float]
    public let metadata: [String: String]

    public init(machineType: String, parameters: [String: Float], metadata: [String: String] = [:]) {
        self.machineType = machineType
        self.parameters = parameters
        self.metadata = metadata
    }
}

/// Serialization format version for compatibility
public struct SerializationVersion: Codable, Sendable, Equatable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public static let current = SerializationVersion(major: 1, minor: 0, patch: 0)

    public var versionString: String {
        return "\(major).\(minor).\(patch)"
    }

    public func isCompatible(with other: SerializationVersion) -> Bool {
        // Same major version is compatible
        return self.major == other.major
    }
}

/// Comprehensive machine serialization data
public struct MachineSerializationData: Codable, Sendable {
    public let version: SerializationVersion
    public let machineId: String
    public let machineType: String
    public let name: String
    public let isEnabled: Bool
    public let parameters: [String: Float]
    public let parameterGroups: [String: [String]]
    public let presets: [String: ParameterPreset]
    public let metadata: [String: String]
    public let createdAt: Date
    public let lastModified: Date

    public init(
        version: SerializationVersion = .current,
        machineId: String,
        machineType: String,
        name: String,
        isEnabled: Bool,
        parameters: [String: Float],
        parameterGroups: [String: [String]] = [:],
        presets: [String: ParameterPreset] = [:],
        metadata: [String: String] = [:]
    ) {
        self.version = version
        self.machineId = machineId
        self.machineType = machineType
        self.name = name
        self.isEnabled = isEnabled
        self.parameters = parameters
        self.parameterGroups = parameterGroups
        self.presets = presets
        self.metadata = metadata
        self.createdAt = Date()
        self.lastModified = Date()
    }
}

/// Voice machine specific serialization data
public struct VoiceMachineSerializationData: Codable, Sendable {
    public let baseData: MachineSerializationData
    public let polyphony: Int
    public let voiceStealingMode: VoiceStealingMode
    public let masterVolume: Float
    public let masterTuning: Float
    public let portamentoTime: Float
    public let portamentoEnabled: Bool
    public let velocitySensitivity: Float
    public let pitchBendRange: Float

    public init(
        baseData: MachineSerializationData,
        polyphony: Int,
        voiceStealingMode: VoiceStealingMode,
        masterVolume: Float,
        masterTuning: Float,
        portamentoTime: Float,
        portamentoEnabled: Bool,
        velocitySensitivity: Float,
        pitchBendRange: Float
    ) {
        self.baseData = baseData
        self.polyphony = polyphony
        self.voiceStealingMode = voiceStealingMode
        self.masterVolume = masterVolume
        self.masterTuning = masterTuning
        self.portamentoTime = portamentoTime
        self.portamentoEnabled = portamentoEnabled
        self.velocitySensitivity = velocitySensitivity
        self.pitchBendRange = pitchBendRange
    }
}

/// Filter machine specific serialization data
public struct FilterMachineSerializationData: Codable, Sendable {
    public let baseData: MachineSerializationData
    public let filterType: FilterType
    public let cutoff: Float
    public let resonance: Float
    public let drive: Float
    public let slope: FilterSlope
    public let quality: FilterQuality
    public let gain: Float
    public let bandwidth: Float
    public let keyTracking: Float
    public let velocitySensitivity: Float
    public let envelopeAmount: Float
    public let lfoAmount: Float
    public let modulationAmount: Float
    public let isActive: Bool

    public init(
        baseData: MachineSerializationData,
        filterType: FilterType,
        cutoff: Float,
        resonance: Float,
        drive: Float,
        slope: FilterSlope,
        quality: FilterQuality,
        gain: Float,
        bandwidth: Float,
        keyTracking: Float,
        velocitySensitivity: Float,
        envelopeAmount: Float,
        lfoAmount: Float,
        modulationAmount: Float,
        isActive: Bool
    ) {
        self.baseData = baseData
        self.filterType = filterType
        self.cutoff = cutoff
        self.resonance = resonance
        self.drive = drive
        self.slope = slope
        self.quality = quality
        self.gain = gain
        self.bandwidth = bandwidth
        self.keyTracking = keyTracking
        self.velocitySensitivity = velocitySensitivity
        self.envelopeAmount = envelopeAmount
        self.lfoAmount = lfoAmount
        self.modulationAmount = modulationAmount
        self.isActive = isActive
    }
}

/// Effect machine specific serialization data
public struct FXProcessorSerializationData: Codable, Sendable {
    public let baseData: MachineSerializationData
    public let effectType: EffectType
    public let wetLevel: Float
    public let dryLevel: Float
    public let isBypassed: Bool
    public let processingMode: EffectProcessingMode
    public let quality: EffectQuality
    public let inputGain: Float
    public let outputGain: Float
    public let intensity: Float
    public let rate: Float
    public let feedback: Float
    public let modDepth: Float
    public let stereoWidth: Float

    public init(
        baseData: MachineSerializationData,
        effectType: EffectType,
        wetLevel: Float,
        dryLevel: Float,
        isBypassed: Bool,
        processingMode: EffectProcessingMode,
        quality: EffectQuality,
        inputGain: Float,
        outputGain: Float,
        intensity: Float,
        rate: Float,
        feedback: Float,
        modDepth: Float,
        stereoWidth: Float
    ) {
        self.baseData = baseData
        self.effectType = effectType
        self.wetLevel = wetLevel
        self.dryLevel = dryLevel
        self.isBypassed = isBypassed
        self.processingMode = processingMode
        self.quality = quality
        self.inputGain = inputGain
        self.outputGain = outputGain
        self.intensity = intensity
        self.rate = rate
        self.feedback = feedback
        self.modDepth = modDepth
        self.stereoWidth = stereoWidth
    }
}

/// Protocol for serializable machines
public protocol SerializableMachine {
    /// Get comprehensive serialization data
    func getSerializationData() -> MachineSerializationData

    /// Restore from serialization data
    func restoreFromSerializationData(_ data: MachineSerializationData) throws

    /// Validate serialization data compatibility
    func validateSerializationData(_ data: MachineSerializationData) -> Bool

    /// Get serialization format version
    func getSupportedSerializationVersion() -> SerializationVersion
}

/// Serialization manager for handling machine persistence
public class MachineSerializationManager: @unchecked Sendable {
    private let queue = DispatchQueue(label: "MachineSerializationManager", qos: .utility)

    public init() {}

    /// Serialize a machine to JSON data
    public func serialize<T: SerializableMachine>(_ machine: T) throws -> Data {
        return try queue.sync {
            let serializationData = machine.getSerializationData()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(serializationData)
        }
    }

    /// Deserialize a machine from JSON data
    public func deserialize<T: SerializableMachine>(_ machine: T, from data: Data) throws {
        try queue.sync {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let serializationData = try decoder.decode(MachineSerializationData.self, from: data)

            // Validate compatibility
            guard machine.validateSerializationData(serializationData) else {
                throw CommonMachineError(
                    code: "SERIALIZATION_INCOMPATIBLE",
                    message: "Serialization data is incompatible with machine type",
                    severity: .error
                )
            }

            // Restore machine state
            try machine.restoreFromSerializationData(serializationData)
        }
    }

    /// Serialize machine to file
    public func saveToFile<T: SerializableMachine>(_ machine: T, url: URL) throws {
        let data = try serialize(machine)
        try data.write(to: url)
    }

    /// Deserialize machine from file
    public func loadFromFile<T: SerializableMachine>(_ machine: T, url: URL) throws {
        let data = try Data(contentsOf: url)
        try deserialize(machine, from: data)
    }

    /// Serialize multiple machines to a bundle
    public func serializeBundle<T: SerializableMachine>(_ machines: [T]) throws -> Data {
        return try queue.sync {
            let serializationDataArray = machines.map { $0.getSerializationData() }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(serializationDataArray)
        }
    }

    /// Deserialize multiple machines from a bundle
    public func deserializeBundle<T: SerializableMachine>(_ machines: [T], from data: Data) throws {
        try queue.sync {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let serializationDataArray = try decoder.decode([MachineSerializationData].self, from: data)

            guard machines.count == serializationDataArray.count else {
                throw CommonMachineError(
                    code: "SERIALIZATION_COUNT_MISMATCH",
                    message: "Number of machines doesn't match serialization data count",
                    severity: .error
                )
            }

            for (machine, data) in zip(machines, serializationDataArray) {
                guard machine.validateSerializationData(data) else {
                    throw CommonMachineError(
                        code: "SERIALIZATION_INCOMPATIBLE",
                        message: "Serialization data is incompatible with machine type",
                        severity: .error
                    )
                }

                try machine.restoreFromSerializationData(data)
            }
        }
    }

    /// Create a backup of machine state
    public func createBackup<T: SerializableMachine>(_ machine: T) throws -> Data {
        return try serialize(machine)
    }

    /// Restore machine from backup
    public func restoreFromBackup<T: SerializableMachine>(_ machine: T, backup: Data) throws {
        try deserialize(machine, from: backup)
    }

    /// Validate serialization data without restoring
    public func validateSerializationData(_ data: Data) throws -> MachineSerializationData {
        return try queue.sync {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(MachineSerializationData.self, from: data)
        }
    }

    /// Get serialization metadata without full deserialization
    public func getSerializationMetadata(_ data: Data) throws -> (machineType: String, version: SerializationVersion, name: String) {
        let serializationData = try validateSerializationData(data)
        return (serializationData.machineType, serializationData.version, serializationData.name)
    }
}

// MARK: - Enumerations

/// Filter types enumeration
public enum FilterType: String, CaseIterable, Codable, Sendable {
    case lowpass = "lowpass"
    case highpass = "highpass" 
    case bandpass = "bandpass"
    case notch = "notch"
    case allpass = "allpass"
    case lowshelf = "lowshelf"
    case highshelf = "highshelf"
    case peak = "peak"
}

/// Effect types enumeration
public enum EffectType: String, CaseIterable, Codable, Sendable {
    case delay = "delay"
    case reverb = "reverb"
    case chorus = "chorus"
    case flanger = "flanger"
    case phaser = "phaser"
    case distortion = "distortion"
    case compressor = "compressor"
    case limiter = "limiter"
    case equalizer = "equalizer"
    case overdrive = "overdrive"
    case bitCrusher = "bitCrusher"
    case sampleRateReduction = "sampleRateReduction"
}

/// Voice stealing modes for polyphonic synthesis
public enum VoiceStealingMode: String, CaseIterable, Codable, Sendable {
    case oldest = "oldest"          // Steal the oldest playing note
    case quietest = "quietest"      // Steal the quietest playing note
    case newest = "newest"          // Steal the newest playing note
    case none = "none"              // Don't steal voices, ignore new notes
}

// MARK: - Parameter System

/// Parameter change notification callback
public typealias ParameterChangeCallback = @Sendable (String, Float, Float) -> Void

/// Parameter categories for organization
public enum ParameterCategory: String, CaseIterable, Codable, Sendable {
    case synthesis = "synthesis"
    case filter = "filter"
    case envelope = "envelope"
    case lfo = "lfo"
    case effects = "effects"
    case modulation = "modulation"
    case sequencer = "sequencer"
    case mixer = "mixer"
    case global = "global"
}

/// Parameter data types
public enum ParameterDataType: String, CaseIterable, Codable, Sendable {
    case float = "float"
    case integer = "integer"
    case boolean = "boolean"
    case enumeration = "enumeration"
}

/// Parameter scaling types for UI representation
public enum ParameterScaling: String, CaseIterable, Codable, Sendable {
    case linear = "linear"
    case logarithmic = "logarithmic"
    case exponential = "exponential"
    case discrete = "discrete"
}

/// Enhanced parameter protocol with comprehensive functionality
public protocol ParameterProtocol: Sendable {
    /// Unique identifier for the parameter
    var id: String { get }

    /// Current parameter value
    var value: Float { get }

    /// Minimum allowed value
    var minValue: Float { get }

    /// Maximum allowed value
    var maxValue: Float { get }

    /// Default value for reset operations
    var defaultValue: Float { get }

    /// Human-readable parameter name
    var name: String { get }

    /// Parameter description for help/documentation
    var description: String? { get }

    /// Unit of measurement (Hz, dB, %, etc.)
    var unit: String? { get }

    /// Parameter category for organization
    var category: ParameterCategory { get }

    /// Data type of the parameter
    var dataType: ParameterDataType { get }

    /// Scaling type for UI representation
    var scaling: ParameterScaling { get }

    /// Whether the parameter can be automated
    var isAutomatable: Bool { get }

    /// Whether the parameter is currently being automated
    var isAutomated: Bool { get set }

    /// Step size for discrete parameters
    var stepSize: Float? { get }

    /// Valid enumeration values (for enum parameters)
    var enumerationValues: [String]? { get }

    /// Parameter change callback
    var changeCallback: ParameterChangeCallback? { get set }

    /// Normalize value to 0.0-1.0 range
    func normalizedValue() -> Float

    /// Set value from normalized 0.0-1.0 range
    mutating func setNormalizedValue(_ normalizedValue: Float)

    /// Validate if a value is within acceptable range
    func isValidValue(_ testValue: Float) -> Bool

    /// Clamp value to valid range
    func clampValue(_ testValue: Float) -> Float

    /// Reset parameter to default value
    mutating func resetToDefault()

    /// Get formatted string representation of current value
    func formattedValue() -> String

    /// Set value with validation and notification
    mutating func setValue(_ newValue: Float, notifyChange: Bool)
}

/// Enhanced parameter implementation with comprehensive functionality
public struct Parameter: ParameterProtocol, Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let unit: String?
    public let category: ParameterCategory
    public let dataType: ParameterDataType
    public let scaling: ParameterScaling
    public let minValue: Float
    public let maxValue: Float
    public let defaultValue: Float
    public let isAutomatable: Bool
    public let stepSize: Float?
    public let enumerationValues: [String]?

    internal var _value: Float

    public var value: Float {
        get { _value }
    }

    public var isAutomated: Bool = false
    public var changeCallback: ParameterChangeCallback?

    /// Initialize a parameter with comprehensive configuration
    public init(
        id: String,
        name: String,
        description: String? = nil,
        value: Float,
        minValue: Float,
        maxValue: Float,
        defaultValue: Float,
        unit: String? = nil,
        category: ParameterCategory = .global,
        dataType: ParameterDataType = .float,
        scaling: ParameterScaling = .linear,
        isAutomatable: Bool = true,
        stepSize: Float? = nil,
        enumerationValues: [String]? = nil,
        changeCallback: ParameterChangeCallback? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.minValue = minValue
        self.maxValue = maxValue
        self.defaultValue = defaultValue
        self.unit = unit
        self.category = category
        self.dataType = dataType
        self.scaling = scaling
        self.isAutomatable = isAutomatable
        self.stepSize = stepSize
        self.enumerationValues = enumerationValues
        self.changeCallback = changeCallback
        self._value = max(minValue, min(maxValue, value))
    }

    /// Convenience initializer for simple float parameters
    public init(
        id: String,
        name: String,
        value: Float,
        minValue: Float,
        maxValue: Float,
        defaultValue: Float,
        unit: String? = nil,
        category: ParameterCategory = .global
    ) {
        self.id = id
        self.name = name
        self.description = nil
        self.minValue = minValue
        self.maxValue = maxValue
        self.defaultValue = defaultValue
        self.unit = unit
        self.category = category
        self.dataType = .float
        self.scaling = .linear
        self.isAutomatable = true
        self.stepSize = nil
        self.enumerationValues = nil
        self.changeCallback = nil
        self._value = max(minValue, min(maxValue, value))
    }

    public func normalizedValue() -> Float {
        guard maxValue != minValue else { return 0.0 }

        switch scaling {
        case .linear:
            return (value - minValue) / (maxValue - minValue)
        case .logarithmic:
            let logMin = log10(max(minValue, 0.001))
            let logMax = log10(max(maxValue, 0.001))
            let logValue = log10(max(value, 0.001))
            return (logValue - logMin) / (logMax - logMin)
        case .exponential:
            let normalLinear = (value - minValue) / (maxValue - minValue)
            return normalLinear * normalLinear
        case .discrete:
            return (value - minValue) / (maxValue - minValue)
        }
    }

    public mutating func setNormalizedValue(_ normalizedValue: Float) {
        let clampedNormalized = max(0.0, min(1.0, normalizedValue))
        var newValue: Float

        switch scaling {
        case .linear, .discrete:
            newValue = minValue + clampedNormalized * (maxValue - minValue)
        case .logarithmic:
            let logMin = log10(max(minValue, 0.001))
            let logMax = log10(max(maxValue, 0.001))
            let logValue = logMin + clampedNormalized * (logMax - logMin)
            newValue = pow(10.0, logValue)
        case .exponential:
            let linearValue = sqrt(clampedNormalized)
            newValue = minValue + linearValue * (maxValue - minValue)
        }

        if let step = stepSize {
            newValue = round(newValue / step) * step
        }

        setValue(newValue, notifyChange: true)
    }

    public func isValidValue(_ testValue: Float) -> Bool {
        return testValue >= minValue && testValue <= maxValue
    }

    public func clampValue(_ testValue: Float) -> Float {
        var clampedValue = max(minValue, min(maxValue, testValue))

        if let step = stepSize {
            clampedValue = round(clampedValue / step) * step
        }

        return clampedValue
    }

    public mutating func resetToDefault() {
        let previousValue = _value
        let clampedValue = clampValue(defaultValue)
        _value = clampedValue
        if clampedValue != previousValue {
            changeCallback?(id, previousValue, clampedValue)
        }
    }

    public func formattedValue() -> String {
        switch dataType {
        case .float:
            if let unit = unit {
                return String(format: "%.2f %@", value, unit)
            } else {
                return String(format: "%.2f", value)
            }
        case .integer:
            if let unit = unit {
                return String(format: "%.0f %@", value, unit)
            } else {
                return String(format: "%.0f", value)
            }
        case .boolean:
            return value > 0.5 ? "On" : "Off"
        case .enumeration:
            if let enumValues = enumerationValues {
                let index = Int(value)
                if index >= 0 && index < enumValues.count {
                    return enumValues[index]
                }
            }
            return String(format: "%.0f", value)
        }
    }

    public mutating func setValue(_ newValue: Float, notifyChange: Bool = true) {
        let clampedValue = clampValue(newValue)

        if clampedValue != _value {
            let previousValue = _value
            _value = clampedValue
            if notifyChange {
                changeCallback?(id, previousValue, clampedValue)
            }
        }
    }

    // MARK: - Codable Support

    private enum CodingKeys: String, CodingKey {
        case id, name, description, unit, minValue, maxValue, defaultValue
        case category, dataType, scaling, isAutomatable, stepSize, enumerationValues
        case _value = "value", isAutomated
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        minValue = try container.decode(Float.self, forKey: .minValue)
        maxValue = try container.decode(Float.self, forKey: .maxValue)
        defaultValue = try container.decode(Float.self, forKey: .defaultValue)
        category = try container.decode(ParameterCategory.self, forKey: .category)
        dataType = try container.decode(ParameterDataType.self, forKey: .dataType)
        scaling = try container.decode(ParameterScaling.self, forKey: .scaling)
        isAutomatable = try container.decode(Bool.self, forKey: .isAutomatable)
        stepSize = try container.decodeIfPresent(Float.self, forKey: .stepSize)
        enumerationValues = try container.decodeIfPresent([String].self, forKey: .enumerationValues)
        _value = try container.decode(Float.self, forKey: ._value)
        isAutomated = try container.decodeIfPresent(Bool.self, forKey: .isAutomated) ?? false
        changeCallback = nil // Callbacks are not serialized
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(unit, forKey: .unit)
        try container.encode(minValue, forKey: .minValue)
        try container.encode(maxValue, forKey: .maxValue)
        try container.encode(defaultValue, forKey: .defaultValue)
        try container.encode(category, forKey: .category)
        try container.encode(dataType, forKey: .dataType)
        try container.encode(scaling, forKey: .scaling)
        try container.encode(isAutomatable, forKey: .isAutomatable)
        try container.encodeIfPresent(stepSize, forKey: .stepSize)
        try container.encodeIfPresent(enumerationValues, forKey: .enumerationValues)
        try container.encode(_value, forKey: ._value)
        try container.encode(isAutomated, forKey: .isAutomated)
    }
}

/// Parameter preset for saving/loading parameter configurations
public struct ParameterPreset: Codable, Sendable {
    public let name: String
    public let description: String?
    public let parameters: [String: Float]
    public let metadata: [String: String]
    public let createdAt: Date

    public init(name: String, description: String? = nil, parameters: [String: Float], metadata: [String: String] = [:]) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.metadata = metadata
        self.createdAt = Date()
    }
}

/// Filter preset for saving/loading filter configurations
public struct FilterPreset: Codable, Sendable {
    public let name: String
    public let description: String?
    public let filterType: FilterType
    public let cutoff: Float
    public let resonance: Float
    public let drive: Float
    public let slope: FilterSlope
    public let quality: FilterQuality
    public let gain: Float
    public let bandwidth: Float
    public let keyTracking: Float
    public let velocitySensitivity: Float
    public let envelopeAmount: Float
    public let lfoAmount: Float
    public let modulationAmount: Float
    public let metadata: [String: String]
    public let createdAt: Date

    public init(
        name: String,
        description: String? = nil,
        filterType: FilterType,
        cutoff: Float,
        resonance: Float,
        drive: Float,
        slope: FilterSlope = .slope24dB,
        quality: FilterQuality = .medium,
        gain: Float = 0.0,
        bandwidth: Float = 1.0,
        keyTracking: Float = 0.0,
        velocitySensitivity: Float = 0.0,
        envelopeAmount: Float = 0.0,
        lfoAmount: Float = 0.0,
        modulationAmount: Float = 0.0,
        metadata: [String: String] = [:]
    ) {
        self.name = name
        self.description = description
        self.filterType = filterType
        self.cutoff = cutoff
        self.resonance = resonance
        self.drive = drive
        self.slope = slope
        self.quality = quality
        self.gain = gain
        self.bandwidth = bandwidth
        self.keyTracking = keyTracking
        self.velocitySensitivity = velocitySensitivity
        self.envelopeAmount = envelopeAmount
        self.lfoAmount = lfoAmount
        self.modulationAmount = modulationAmount
        self.metadata = metadata
        self.createdAt = Date()
    }
}

/// Parameter group for organizing related parameters
public struct ParameterGroup: Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let category: ParameterCategory
    public let parameterIds: [String]

    public init(id: String, name: String, description: String? = nil, category: ParameterCategory, parameterIds: [String]) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.parameterIds = parameterIds
    }
}

/// Parameter manager for organizing and managing machine parameters
public class ParameterManager: @unchecked Sendable {
    private var _parameters: [String: Parameter] = [:]
    private var _groups: [String: ParameterGroup] = [:]
    private let queue = DispatchQueue(label: "ParameterManager", qos: .userInitiated)

    /// All parameters managed by this instance
    public var parameters: [String: Parameter] {
        return queue.sync { _parameters }
    }

    /// All parameter groups
    public var groups: [String: ParameterGroup] {
        return queue.sync { _groups }
    }

    /// Parameter change notification callback
    public var globalChangeCallback: ParameterChangeCallback?

    public init() {}

    /// Add a parameter to the manager
    public func addParameter(_ parameter: Parameter) {
        queue.sync {
            var mutableParameter = parameter
            // Set up global change callback forwarding
            let originalCallback = mutableParameter.changeCallback
            mutableParameter.changeCallback = { [weak self] id, oldValue, newValue in
                originalCallback?(id, oldValue, newValue)
                self?.globalChangeCallback?(id, oldValue, newValue)
            }
            _parameters[parameter.id] = mutableParameter
        }
    }

    /// Remove a parameter from the manager
    public func removeParameter(id: String) {
        queue.sync {
            _ = _parameters.removeValue(forKey: id)
        }
    }

    /// Get a parameter by ID
    public func getParameter(id: String) -> Parameter? {
        return queue.sync { _parameters[id] }
    }

    /// Update a parameter value
    public func updateParameter(id: String, value: Float, notifyChange: Bool = true) throws {
        try queue.sync {
            guard var parameter = _parameters[id] else {
                throw CommonMachineError(
                    code: "PARAMETER_NOT_FOUND",
                    message: "Parameter with ID '\(id)' not found",
                    severity: .error
                )
            }

            parameter.setValue(value, notifyChange: notifyChange)
            _parameters[id] = parameter
        }
    }

    /// Get parameter value by ID
    public func getParameterValue(id: String) -> Float? {
        return queue.sync { _parameters[id]?._value }
    }

    /// Get parameters by category
    public func getParametersByCategory(_ category: ParameterCategory) -> [Parameter] {
        return queue.sync {
            _parameters.values.filter { $0.category == category }
        }
    }

    /// Add a parameter group
    public func addGroup(_ group: ParameterGroup) {
        queue.sync {
            _groups[group.id] = group
        }
    }

    /// Get parameters in a group
    public func getParametersInGroup(groupId: String) -> [Parameter] {
        return queue.sync {
            guard let group = _groups[groupId] else { return [] }
            return group.parameterIds.compactMap { _parameters[$0] }
        }
    }

    /// Reset all parameters to default values
    public func resetAllToDefaults() {
        queue.sync {
            for (id, var parameter) in _parameters {
                parameter.resetToDefault()
                _parameters[id] = parameter
            }
        }
    }

    /// Create a preset from current parameter values
    public func createPreset(name: String, description: String? = nil) -> ParameterPreset {
        return queue.sync {
            let parameterValues = _parameters.mapValues { $0._value }
            return ParameterPreset(
                name: name,
                description: description,
                parameters: parameterValues
            )
        }
    }

    /// Load a preset
    public func loadPreset(_ preset: ParameterPreset, notifyChanges: Bool = true) throws {
        try queue.sync {
            for (parameterId, value) in preset.parameters {
                guard _parameters[parameterId] != nil else {
                    throw CommonMachineError(
                        code: "PRESET_PARAMETER_NOT_FOUND",
                        message: "Parameter '\(parameterId)' from preset not found in current parameters",
                        severity: .warning
                    )
                }

                try updateParameter(id: parameterId, value: value, notifyChange: notifyChanges)
            }
        }
    }

    /// Get all parameter values as a dictionary
    public func getAllValues() -> [String: Float] {
        return queue.sync {
            _parameters.mapValues { $0._value }
        }
    }

    /// Set multiple parameter values at once
    public func setValues(_ values: [String: Float], notifyChanges: Bool = true) throws {
        try queue.sync {
            for (id, value) in values {
                try updateParameter(id: id, value: value, notifyChange: notifyChanges)
            }
        }
    }

    /// Validate all parameters
    public func validateAllParameters() -> [String] {
        return queue.sync {
            var errors: [String] = []
            for (id, parameter) in _parameters {
                if !parameter.isValidValue(parameter._value) {
                    errors.append("Parameter '\(id)' has invalid value: \(parameter._value)")
                }
            }
            return errors
        }
    }
}

// MARK: - Common Machine Types

/// Common machine type identifiers
public enum MachineType: String, CaseIterable, Codable {
    // Voice machines
    case fmTone = "FM_TONE"
    case fmDrum = "FM_DRUM"
    case wavetone = "WAVETONE"
    case swarmer = "SWARMER"
    
    // Filter machines
    case multiMode = "MULTI_MODE"
    case lowpass4 = "LOWPASS_4"
    
    // Effect machines
    case trackDelay = "TRACK_DELAY"
    case trackReverb = "TRACK_REVERB"
    case trackChorus = "TRACK_CHORUS"
    case masterCompressor = "MASTER_COMPRESSOR"
    case masterOverdrive = "MASTER_OVERDRIVE"
}

// MARK: - Utility Extensions

extension MachineProtocol {
    /// Default implementation for getting machine state
    public func getState() -> MachineState {
        return MachineState(
            machineType: String(describing: type(of: self)),
            parameters: parameters.getAllValues(),
            metadata: [
                "name": name,
                "enabled": String(isEnabled),
                "status": status.rawValue,
                "isInitialized": String(isInitialized)
            ]
        )
    }
    
    /// Default implementation for setting machine state
    public func setState(_ state: MachineState) {
        // Set metadata
        if let enabledString = state.metadata["enabled"] {
            isEnabled = enabledString == "true"
        }

        // Set parameters
        do {
            try parameters.setValues(state.parameters, notifyChanges: false)
        } catch {
            // Log error but don't throw - allow partial state restoration
            if let errorHandler = errorHandler {
                errorHandler(CommonMachineError(
                    code: "STATE_RESTORATION_PARTIAL_FAILURE",
                    message: "Failed to restore some parameters: \(error.localizedDescription)",
                    severity: .warning
                ))
            }
        }
    }
    
    /// Default implementation for parameter validation
    public func validateParameters() throws -> Bool {
        let errors = parameters.validateAllParameters()
        if !errors.isEmpty {
            throw CommonMachineError(
                code: "PARAMETER_VALIDATION_FAILED",
                message: "Parameter validation failed: \(errors.joined(separator: ", "))",
                severity: .error
            )
        }
        return true
    }
    
    /// Default implementation for health check
    public func healthCheck() -> MachineHealthStatus {
        // Basic health check based on status and errors
        if let error = lastError {
            switch error.severity {
            case .critical:
                return .critical
            case .error:
                return .warning
            case .warning, .info:
                return .warning
            }
        }
        
        switch status {
        case .error:
            return .critical
        case .running, .ready:
            return .healthy
        case .suspended, .stopping:
            return .warning
        default:
            return .unknown
        }
    }
    
    /// Default implementation for parameter updates
    public func updateParameter(key: String, value: Any) throws {
        // Try to convert value to Float and update parameter
        guard let floatValue = value as? Float else {
            throw CommonMachineError(
                code: "INVALID_PARAMETER_TYPE",
                message: "Parameter value must be a Float, got: \(type(of: value))",
                severity: .error
            )
        }

        try parameters.updateParameter(id: key, value: floatValue)
    }
    
    /// Default implementation for performance counter reset
    public func resetPerformanceCounters() {
        // Override in concrete implementations that have mutable performance metrics
    }
    
    /// Default lifecycle method implementations
    public func initialize(configuration: MachineConfiguration) throws {
        // Override in concrete implementations
    }
    
    public func start() throws {
        // Override in concrete implementations
    }
    
    public func stop() throws {
        // Override in concrete implementations
    }
    
    public func suspend() throws {
        // Override in concrete implementations
    }
    
    public func resume() throws {
        // Override in concrete implementations
    }
}

// MARK: - SerializableMachine Extensions

extension MachineProtocol where Self: SerializableMachine {
    /// Default implementation for getting serialization data
    public func getSerializationData() -> MachineSerializationData {
        let parameterGroups = parameters.groups.mapValues { group in
            group.parameterIds
        }

        return MachineSerializationData(
            machineId: id.uuidString,
            machineType: String(describing: type(of: self)),
            name: name,
            isEnabled: isEnabled,
            parameters: parameters.getAllValues(),
            parameterGroups: parameterGroups,
            metadata: [
                "status": status.rawValue,
                "isInitialized": String(isInitialized),
                "lastActiveTimestamp": lastActiveTimestamp?.timeIntervalSince1970.description ?? "",
                "lastError": lastError?.message ?? ""
            ]
        )
    }

    /// Default implementation for restoring from serialization data
    public func restoreFromSerializationData(_ data: MachineSerializationData) throws {
        // Validate version compatibility
        guard data.version.isCompatible(with: getSupportedSerializationVersion()) else {
            throw CommonMachineError(
                code: "SERIALIZATION_VERSION_INCOMPATIBLE",
                message: "Serialization version \(data.version.versionString) is incompatible",
                severity: .error
            )
        }

        // Restore basic properties
        name = data.name
        isEnabled = data.isEnabled

        // Restore parameters
        try parameters.setValues(data.parameters, notifyChanges: false)

        // Restore metadata if available
        if let statusString = data.metadata["status"],
           let restoredStatus = MachineStatus(rawValue: statusString) {
            // Note: In a real implementation, you'd need a way to set the status
            // For now, we'll just validate it's a known status
            _ = restoredStatus
        }
    }

    /// Default implementation for validating serialization data
    public func validateSerializationData(_ data: MachineSerializationData) -> Bool {
        // Check if machine type matches
        let currentType = String(describing: type(of: self))
        guard data.machineType == currentType else {
            return false
        }

        // Check version compatibility
        guard data.version.isCompatible(with: getSupportedSerializationVersion()) else {
            return false
        }

        // Validate that all required parameters exist
        let currentParameters = Set(parameters.parameters.keys)
        let serializedParameters = Set(data.parameters.keys)

        // Allow for additional parameters in serialized data (forward compatibility)
        // but ensure all current parameters have values
        return currentParameters.isSubset(of: serializedParameters)
    }

    /// Default implementation for supported serialization version
    public func getSupportedSerializationVersion() -> SerializationVersion {
        return .current
    }
}

// MARK: - VoiceMachineProtocol Extensions

extension VoiceMachineProtocol {
    /// Default implementation for noteOn with additional parameters
    public func noteOn(note: UInt8, velocity: UInt8, channel: UInt8 = 0, timestamp: UInt64? = nil) {
        // Default to simple noteOn implementation
        noteOn(note: note, velocity: velocity)
    }

    /// Default implementation for noteOff with additional parameters
    public func noteOff(note: UInt8, velocity: UInt8 = 64, channel: UInt8 = 0, timestamp: UInt64? = nil) {
        // Default to simple noteOff implementation
        noteOff(note: note)
    }

    /// Default implementation for channel-specific allNotesOff
    public func allNotesOff(channel: UInt8) {
        // Default to global allNotesOff
        allNotesOff()
    }

    /// Default implementation for voice allocation lookup
    public func getVoiceAllocation(for note: UInt8) -> VoiceAllocation? {
        // Override in concrete implementations
        return nil
    }

    /// Default implementation for voice parameter setup
    public func setupVoiceParameters() {
        // Add common voice parameters
        let masterVolumeParam = Parameter(
            id: "master_volume",
            name: "Master Volume",
            description: "Overall output volume",
            value: 0.8,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.8,
            unit: "%",
            category: .synthesis,
            scaling: .linear
        )

        let masterTuningParam = Parameter(
            id: "master_tuning",
            name: "Master Tuning",
            description: "Global pitch adjustment in cents",
            value: 0.0,
            minValue: -100.0,
            maxValue: 100.0,
            defaultValue: 0.0,
            unit: "cents",
            category: .synthesis,
            scaling: .linear
        )

        let portamentoTimeParam = Parameter(
            id: "portamento_time",
            name: "Portamento Time",
            description: "Glide time between notes",
            value: 0.0,
            minValue: 0.0,
            maxValue: 5.0,
            defaultValue: 0.0,
            unit: "s",
            category: .synthesis,
            scaling: .exponential
        )

        let portamentoEnabledParam = Parameter(
            id: "portamento_enabled",
            name: "Portamento",
            description: "Enable/disable portamento",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            category: .synthesis,
            dataType: .boolean
        )

        let velocitySensitivityParam = Parameter(
            id: "velocity_sensitivity",
            name: "Velocity Sensitivity",
            description: "How much velocity affects the sound",
            value: 1.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 1.0,
            unit: "%",
            category: .synthesis
        )

        let pitchBendRangeParam = Parameter(
            id: "pitch_bend_range",
            name: "Pitch Bend Range",
            description: "Pitch bend wheel range in semitones",
            value: 2.0,
            minValue: 0.0,
            maxValue: 24.0,
            defaultValue: 2.0,
            unit: "semitones",
            category: .synthesis,
            dataType: .integer
        )

        // Add parameters to the parameter manager
        parameters.addParameter(masterVolumeParam)
        parameters.addParameter(masterTuningParam)
        parameters.addParameter(portamentoTimeParam)
        parameters.addParameter(portamentoEnabledParam)
        parameters.addParameter(velocitySensitivityParam)
        parameters.addParameter(pitchBendRangeParam)
    }

    /// Default implementation for getting voice parameter groups
    public func getVoiceParameterGroups() -> [ParameterGroup] {
        let synthGroup = ParameterGroup(
            id: "synthesis",
            name: "Synthesis",
            description: "Core synthesis parameters",
            category: .synthesis,
            parameterIds: [
                "master_volume",
                "master_tuning",
                "velocity_sensitivity"
            ]
        )

        let expressionGroup = ParameterGroup(
            id: "expression",
            name: "Expression",
            description: "Performance expression parameters",
            category: .synthesis,
            parameterIds: [
                "portamento_time",
                "portamento_enabled",
                "pitch_bend_range"
            ]
        )

        return [synthGroup, expressionGroup]
    }

    /// Default implementation for pitch bend
    public func applyPitchBend(_ value: Float) {
        // Store the pitch bend value
        do {
            try parameters.updateParameter(id: "pitch_bend", value: value)
        } catch {
            // Parameter might not exist yet - this is okay for default implementation
        }
    }

    /// Default implementation for modulation
    public func applyModulation(_ value: Float) {
        // Store the modulation value
        do {
            try parameters.updateParameter(id: "mod_wheel", value: value)
        } catch {
            // Parameter might not exist yet - this is okay for default implementation
        }
    }

    /// Default implementation for voice-specific parameter setting
    public func setVoiceParameter(voiceId: Int, parameterId: String, value: Float) throws {
        // Default implementation just sets the global parameter
        try parameters.updateParameter(id: parameterId, value: value)
    }

    /// Default implementation for voice-specific parameter getting
    public func getVoiceParameter(voiceId: Int, parameterId: String) -> Float? {
        // Default implementation returns the global parameter value
        return parameters.getParameterValue(id: parameterId)
    }

    /// Default implementation for sustain pedal
    public func setSustainPedal(_ enabled: Bool) {
        // Override in concrete implementations
    }

    /// Default implementation for sostenuto pedal
    public func setSostenutoPedal(_ enabled: Bool) {
        // Override in concrete implementations
    }

    /// Default implementation for soft pedal
    public func setSoftPedal(_ enabled: Bool) {
        // Override in concrete implementations
    }

    /// Default implementation for aftertouch
    public func setAftertouch(_ pressure: Float) {
        // Override in concrete implementations
    }

    /// Default implementation for polyphonic aftertouch
    public func setPolyphonicAftertouch(note: UInt8, pressure: Float) {
        // Override in concrete implementations
    }

    /// Convenience property implementations using parameter manager
    public var masterVolume: Float {
        get { parameters.getParameterValue(id: "master_volume") ?? 0.8 }
        set { try? parameters.updateParameter(id: "master_volume", value: newValue) }
    }

    public var masterTuning: Float {
        get { parameters.getParameterValue(id: "master_tuning") ?? 0.0 }
        set { try? parameters.updateParameter(id: "master_tuning", value: newValue) }
    }

    public var portamentoTime: Float {
        get { parameters.getParameterValue(id: "portamento_time") ?? 0.0 }
        set { try? parameters.updateParameter(id: "portamento_time", value: newValue) }
    }

    public var portamentoEnabled: Bool {
        get { (parameters.getParameterValue(id: "portamento_enabled") ?? 0.0) > 0.5 }
        set { try? parameters.updateParameter(id: "portamento_enabled", value: newValue ? 1.0 : 0.0) }
    }

    public var velocitySensitivity: Float {
        get { parameters.getParameterValue(id: "velocity_sensitivity") ?? 1.0 }
        set { try? parameters.updateParameter(id: "velocity_sensitivity", value: newValue) }
    }

    public var pitchBendRange: Float {
        get { parameters.getParameterValue(id: "pitch_bend_range") ?? 2.0 }
        set { try? parameters.updateParameter(id: "pitch_bend_range", value: newValue) }
    }

    public var pitchBend: Float {
        get { parameters.getParameterValue(id: "pitch_bend") ?? 0.0 }
        set { try? parameters.updateParameter(id: "pitch_bend", value: newValue) }
    }

    public var modWheel: Float {
        get { parameters.getParameterValue(id: "mod_wheel") ?? 0.0 }
        set { try? parameters.updateParameter(id: "mod_wheel", value: newValue) }
    }
}

// MARK: - FilterMachineProtocol Extensions

extension FilterMachineProtocol {
    /// Default implementation for filter parameter setup
    public func setupFilterParameters() {
        let cutoffParam = Parameter(
            id: "filter_cutoff",
            name: "Cutoff",
            description: "Filter cutoff frequency",
            value: 1000.0,
            minValue: 20.0,
            maxValue: 20000.0,
            defaultValue: 1000.0,
            unit: "Hz",
            category: .filter,
            scaling: .logarithmic
        )

        let resonanceParam = Parameter(
            id: "filter_resonance",
            name: "Resonance",
            description: "Filter resonance/Q factor",
            value: 0.1,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.1,
            unit: "%",
            category: .filter
        )

        let driveParam = Parameter(
            id: "filter_drive",
            name: "Drive",
            description: "Filter drive/distortion amount",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "%",
            category: .filter
        )

        let gainParam = Parameter(
            id: "filter_gain",
            name: "Gain",
            description: "Filter gain for peak/shelf filters",
            value: 0.0,
            minValue: -24.0,
            maxValue: 24.0,
            defaultValue: 0.0,
            unit: "dB",
            category: .filter
        )

        let bandwidthParam = Parameter(
            id: "filter_bandwidth",
            name: "Bandwidth",
            description: "Filter bandwidth for bandpass/notch filters",
            value: 1.0,
            minValue: 0.1,
            maxValue: 4.0,
            defaultValue: 1.0,
            unit: "octaves",
            category: .filter
        )

        let keyTrackingParam = Parameter(
            id: "filter_key_tracking",
            name: "Key Tracking",
            description: "Filter cutoff key tracking amount",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "%",
            category: .filter
        )

        let velocitySensParam = Parameter(
            id: "filter_velocity_sensitivity",
            name: "Velocity Sensitivity",
            description: "Filter velocity sensitivity",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "%",
            category: .filter
        )

        let envelopeAmountParam = Parameter(
            id: "filter_envelope_amount",
            name: "Envelope Amount",
            description: "Filter envelope modulation amount",
            value: 0.0,
            minValue: -1.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "%",
            category: .filter
        )

        let lfoAmountParam = Parameter(
            id: "filter_lfo_amount",
            name: "LFO Amount",
            description: "Filter LFO modulation amount",
            value: 0.0,
            minValue: -1.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "%",
            category: .filter
        )

        let modulationAmountParam = Parameter(
            id: "filter_modulation_amount",
            name: "Modulation Amount",
            description: "Filter modulation input amount",
            value: 0.0,
            minValue: -1.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "%",
            category: .filter
        )

        // Add parameters to the parameter manager
        parameters.addParameter(cutoffParam)
        parameters.addParameter(resonanceParam)
        parameters.addParameter(driveParam)
        parameters.addParameter(gainParam)
        parameters.addParameter(bandwidthParam)
        parameters.addParameter(keyTrackingParam)
        parameters.addParameter(velocitySensParam)
        parameters.addParameter(envelopeAmountParam)
        parameters.addParameter(lfoAmountParam)
        parameters.addParameter(modulationAmountParam)
    }

    /// Default implementation for getting filter parameter groups
    public func getFilterParameterGroups() -> [ParameterGroup] {
        let coreGroup = ParameterGroup(
            id: "filter_core",
            name: "Core Filter",
            description: "Basic filter parameters",
            category: .filter,
            parameterIds: [
                "filter_cutoff",
                "filter_resonance",
                "filter_drive",
                "filter_gain",
                "filter_bandwidth"
            ]
        )

        let modulationGroup = ParameterGroup(
            id: "filter_modulation",
            name: "Filter Modulation",
            description: "Filter modulation parameters",
            category: .filter,
            parameterIds: [
                "filter_key_tracking",
                "filter_velocity_sensitivity",
                "filter_envelope_amount",
                "filter_lfo_amount",
                "filter_modulation_amount"
            ]
        )

        return [coreGroup, modulationGroup]
    }

    /// Default implementation for frequency response
    public func getFrequencyResponse(at frequency: Float) -> FilterResponse {
        // Basic implementation - override in concrete implementations
        return FilterResponse(frequency: frequency, magnitude: 1.0, phase: 0.0)
    }

    /// Default implementation for frequency response curve
    public func getFrequencyResponseCurve(startFreq: Float, endFreq: Float, points: Int) -> [FilterResponse] {
        var responses: [FilterResponse] = []
        let logStart = log10(startFreq)
        let logEnd = log10(endFreq)
        let logStep = (logEnd - logStart) / Float(points - 1)

        for i in 0..<points {
            let logFreq = logStart + Float(i) * logStep
            let freq = pow(10.0, logFreq)
            responses.append(getFrequencyResponse(at: freq))
        }

        return responses
    }

    /// Default implementation for filter state reset
    public func resetFilterState() {
        // Override in concrete implementations
    }

    /// Default implementation for loading filter preset
    public func loadFilterPreset(_ preset: FilterPreset) {
        filterType = preset.filterType
        cutoff = preset.cutoff
        resonance = preset.resonance
        drive = preset.drive
        slope = preset.slope
        quality = preset.quality
        gain = preset.gain
        bandwidth = preset.bandwidth
        keyTracking = preset.keyTracking
        velocitySensitivity = preset.velocitySensitivity
        envelopeAmount = preset.envelopeAmount
        lfoAmount = preset.lfoAmount
        modulationAmount = preset.modulationAmount

        updateFilterCoefficients()
    }

    /// Default implementation for saving filter preset
    public func saveFilterPreset(name: String) -> FilterPreset {
        return FilterPreset(
            name: name,
            filterType: filterType,
            cutoff: cutoff,
            resonance: resonance,
            drive: drive,
            slope: slope,
            quality: quality,
            gain: gain,
            bandwidth: bandwidth,
            keyTracking: keyTracking,
            velocitySensitivity: velocitySensitivity,
            envelopeAmount: envelopeAmount,
            lfoAmount: lfoAmount,
            modulationAmount: modulationAmount
        )
    }

    /// Default implementation for filter modulation
    public func applyFilterModulation(envelope: Float, lfo: Float, modulation: Float) {
        let cutoffMod = envelope * envelopeAmount + lfo * lfoAmount + modulation * modulationAmount
        let newCutoff = cutoff * (1.0 + cutoffMod)

        // Apply modulation without triggering parameter callbacks
        try? parameters.updateParameter(id: "filter_cutoff", value: max(20.0, min(20000.0, newCutoff)), notifyChange: false)
    }

    /// Default implementation for coefficient updates
    public func updateFilterCoefficients() {
        // Override in concrete implementations
    }

    /// Default implementation for cutoff with key tracking
    public func setCutoffWithKeyTracking(baseFreq: Float, note: UInt8, velocity: UInt8) {
        let noteFreq = 440.0 * pow(2.0, (Float(note) - 69.0) / 12.0)
        let trackingAmount = keyTracking
        let velocityAmount = velocitySensitivity * (Float(velocity) / 127.0)

        let trackedCutoff = baseFreq * (1.0 + trackingAmount * (noteFreq / 440.0 - 1.0))
        let finalCutoff = trackedCutoff * (1.0 + velocityAmount)

        cutoff = max(20.0, min(20000.0, finalCutoff))
    }

    /// Default implementation for real-time modulation
    public func modulateFilter(cutoffMod: Float, resonanceMod: Float) {
        let newCutoff = cutoff * (1.0 + cutoffMod)
        let newResonance = resonance + resonanceMod

        cutoff = max(20.0, min(20000.0, newCutoff))
        resonance = max(0.0, min(1.0, newResonance))
    }

    /// Convenience property implementations using parameter manager
    public var cutoff: Float {
        get { parameters.getParameterValue(id: "filter_cutoff") ?? 1000.0 }
        set { try? parameters.updateParameter(id: "filter_cutoff", value: newValue) }
    }

    public var resonance: Float {
        get { parameters.getParameterValue(id: "filter_resonance") ?? 0.1 }
        set { try? parameters.updateParameter(id: "filter_resonance", value: newValue) }
    }

    public var drive: Float {
        get { parameters.getParameterValue(id: "filter_drive") ?? 0.0 }
        set { try? parameters.updateParameter(id: "filter_drive", value: newValue) }
    }

    public var gain: Float {
        get { parameters.getParameterValue(id: "filter_gain") ?? 0.0 }
        set { try? parameters.updateParameter(id: "filter_gain", value: newValue) }
    }

    public var bandwidth: Float {
        get { parameters.getParameterValue(id: "filter_bandwidth") ?? 1.0 }
        set { try? parameters.updateParameter(id: "filter_bandwidth", value: newValue) }
    }

    public var keyTracking: Float {
        get { parameters.getParameterValue(id: "filter_key_tracking") ?? 0.0 }
        set { try? parameters.updateParameter(id: "filter_key_tracking", value: newValue) }
    }

    public var velocitySensitivity: Float {
        get { parameters.getParameterValue(id: "filter_velocity_sensitivity") ?? 0.0 }
        set { try? parameters.updateParameter(id: "filter_velocity_sensitivity", value: newValue) }
    }

    public var envelopeAmount: Float {
        get { parameters.getParameterValue(id: "filter_envelope_amount") ?? 0.0 }
        set { try? parameters.updateParameter(id: "filter_envelope_amount", value: newValue) }
    }

    public var lfoAmount: Float {
        get { parameters.getParameterValue(id: "filter_lfo_amount") ?? 0.0 }
        set { try? parameters.updateParameter(id: "filter_lfo_amount", value: newValue) }
    }

    public var modulationAmount: Float {
        get { parameters.getParameterValue(id: "filter_modulation_amount") ?? 0.0 }
        set { try? parameters.updateParameter(id: "filter_modulation_amount", value: newValue) }
    }
}

// MARK: - FXProcessorProtocol Extensions

extension FXProcessorProtocol {
    /// Default implementation for effect parameter setup
    public func setupEffectParameters() {
        let wetLevelParam = Parameter(
            id: "fx_wet_level",
            name: "Wet Level",
            description: "Effect wet signal level",
            value: 1.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 1.0,
            unit: "%",
            category: .effects
        )

        let dryLevelParam = Parameter(
            id: "fx_dry_level",
            name: "Dry Level",
            description: "Effect dry signal level",
            value: 1.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 1.0,
            unit: "%",
            category: .effects
        )

        let inputGainParam = Parameter(
            id: "fx_input_gain",
            name: "Input Gain",
            description: "Effect input gain",
            value: 0.0,
            minValue: -24.0,
            maxValue: 24.0,
            defaultValue: 0.0,
            unit: "dB",
            category: .effects
        )

        let outputGainParam = Parameter(
            id: "fx_output_gain",
            name: "Output Gain",
            description: "Effect output gain",
            value: 0.0,
            minValue: -24.0,
            maxValue: 24.0,
            defaultValue: 0.0,
            unit: "dB",
            category: .effects
        )

        let intensityParam = Parameter(
            id: "fx_intensity",
            name: "Intensity",
            description: "Effect intensity/depth",
            value: 0.5,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.5,
            unit: "%",
            category: .effects
        )

        let rateParam = Parameter(
            id: "fx_rate",
            name: "Rate",
            description: "Effect rate/speed",
            value: 1.0,
            minValue: 0.1,
            maxValue: 10.0,
            defaultValue: 1.0,
            unit: "Hz",
            category: .effects,
            scaling: .logarithmic
        )

        let feedbackParam = Parameter(
            id: "fx_feedback",
            name: "Feedback",
            description: "Effect feedback amount",
            value: 0.0,
            minValue: 0.0,
            maxValue: 0.95,
            defaultValue: 0.0,
            unit: "%",
            category: .effects
        )

        let modDepthParam = Parameter(
            id: "fx_mod_depth",
            name: "Mod Depth",
            description: "Effect modulation depth",
            value: 0.5,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.5,
            unit: "%",
            category: .effects
        )

        let stereoWidthParam = Parameter(
            id: "fx_stereo_width",
            name: "Stereo Width",
            description: "Effect stereo width",
            value: 0.0,
            minValue: -1.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "%",
            category: .effects
        )

        // Add parameters to the parameter manager
        parameters.addParameter(wetLevelParam)
        parameters.addParameter(dryLevelParam)
        parameters.addParameter(inputGainParam)
        parameters.addParameter(outputGainParam)
        parameters.addParameter(intensityParam)
        parameters.addParameter(rateParam)
        parameters.addParameter(feedbackParam)
        parameters.addParameter(modDepthParam)
        parameters.addParameter(stereoWidthParam)
    }

    /// Default implementation for getting effect parameter groups
    public func getEffectParameterGroups() -> [ParameterGroup] {
        let mixGroup = ParameterGroup(
            id: "fx_mix",
            name: "Mix & Levels",
            description: "Effect mixing and level parameters",
            category: .effects,
            parameterIds: [
                "fx_wet_level",
                "fx_dry_level",
                "fx_input_gain",
                "fx_output_gain"
            ]
        )

        let processingGroup = ParameterGroup(
            id: "fx_processing",
            name: "Processing",
            description: "Effect processing parameters",
            category: .effects,
            parameterIds: [
                "fx_intensity",
                "fx_rate",
                "fx_feedback",
                "fx_mod_depth",
                "fx_stereo_width"
            ]
        )

        return [mixGroup, processingGroup]
    }

    /// Default implementation for effect state reset
    public func resetEffectState() {
        // Override in concrete implementations
    }

    /// Default implementation for buffer flushing
    public func flushBuffers() {
        // Override in concrete implementations
    }

    /// Default implementation for loading effect preset
    public func loadEffectPreset(_ preset: EffectPreset) {
        processingMode = preset.processingMode
        quality = preset.quality
        wetLevel = preset.wetLevel
        dryLevel = preset.dryLevel

        // Load effect-specific parameters
        for (parameterId, value) in preset.parameters {
            try? parameters.updateParameter(id: parameterId, value: value)
        }
    }

    /// Default implementation for saving effect preset
    public func saveEffectPreset(name: String) -> EffectPreset {
        return EffectPreset(
            name: name,
            effectType: effectType,
            parameters: parameters.getAllValues(),
            processingMode: processingMode,
            quality: quality,
            wetLevel: wetLevel,
            dryLevel: dryLevel
        )
    }

    /// Default implementation for sidechain processing
    public func processSidechain(input: AudioBuffer, sidechain: AudioBuffer?) -> AudioBuffer {
        // Default to regular processing without sidechain
        return process(input: input)
    }

    /// Default implementation for tail time
    public func getTailTime() -> Double {
        // Override in concrete implementations that have tails
        return 0.0
    }

    /// Default implementation for tempo sync
    public func setTempoSync(bpm: Double, timeSignature: TimeSignature) {
        // Override in concrete implementations that support tempo sync
    }

    /// Default implementation for effect modulation
    public func modulateEffect(intensity: Float, rate: Float, feedback: Float) {
        try? parameters.updateParameter(id: "fx_intensity", value: intensity, notifyChange: false)
        try? parameters.updateParameter(id: "fx_rate", value: rate, notifyChange: false)
        try? parameters.updateParameter(id: "fx_feedback", value: feedback, notifyChange: false)
    }

    /// Default implementation for parameter setting with smoothing
    public func setEffectParameter(id: String, value: Float, smoothTime: Float = 0.0) {
        // For now, just set the parameter directly
        // In a real implementation, you'd implement parameter smoothing
        try? parameters.updateParameter(id: id, value: value)
    }

    /// Default implementation for action triggering
    public func triggerAction(_ action: String, value: Float = 1.0) {
        // Override in concrete implementations for specific actions
    }

    /// Convenience property implementations using parameter manager
    public var wetLevel: Float {
        get { parameters.getParameterValue(id: "fx_wet_level") ?? 1.0 }
        set { try? parameters.updateParameter(id: "fx_wet_level", value: newValue) }
    }

    public var dryLevel: Float {
        get { parameters.getParameterValue(id: "fx_dry_level") ?? 1.0 }
        set { try? parameters.updateParameter(id: "fx_dry_level", value: newValue) }
    }

    public var inputGain: Float {
        get { parameters.getParameterValue(id: "fx_input_gain") ?? 0.0 }
        set { try? parameters.updateParameter(id: "fx_input_gain", value: newValue) }
    }

    public var outputGain: Float {
        get { parameters.getParameterValue(id: "fx_output_gain") ?? 0.0 }
        set { try? parameters.updateParameter(id: "fx_output_gain", value: newValue) }
    }

    public var intensity: Float {
        get { parameters.getParameterValue(id: "fx_intensity") ?? 0.5 }
        set { try? parameters.updateParameter(id: "fx_intensity", value: newValue) }
    }

    public var rate: Float {
        get { parameters.getParameterValue(id: "fx_rate") ?? 1.0 }
        set { try? parameters.updateParameter(id: "fx_rate", value: newValue) }
    }

    public var feedback: Float {
        get { parameters.getParameterValue(id: "fx_feedback") ?? 0.0 }
        set { try? parameters.updateParameter(id: "fx_feedback", value: newValue) }
    }

    public var modDepth: Float {
        get { parameters.getParameterValue(id: "fx_mod_depth") ?? 0.5 }
        set { try? parameters.updateParameter(id: "fx_mod_depth", value: newValue) }
    }

    public var stereoWidth: Float {
        get { parameters.getParameterValue(id: "fx_stereo_width") ?? 0.0 }
        set { try? parameters.updateParameter(id: "fx_stereo_width", value: newValue) }
    }
}

// MARK: - Mock Implementations for Testing

/// Mock voice machine implementation for testing
public class MockVoiceMachine: VoiceMachineProtocol, SerializableMachine, @unchecked Sendable {
    public let id = UUID()
    public var name: String = "Mock Voice Machine"
    public var isEnabled: Bool = true
    public var isInitialized: Bool = false
    public var status: MachineStatus = .uninitialized
    public var lastActiveTimestamp: Date?
    public var lastError: MachineError?
    public var errorHandler: ((MachineError) -> Void)?
    public var performanceMetrics: MachinePerformanceMetrics = MachinePerformanceMetrics()
    public var parameters: ParameterManager = ParameterManager()

    // Voice-specific properties
    public var polyphony: Int = 8
    public var voiceStealingMode: VoiceStealingMode = .oldest
    private var _activeVoices: Int = 0
    private var _voiceStates: [VoiceState] = []

    public var activeVoices: Int { _activeVoices }
    public var voiceStates: [VoiceState] { _voiceStates }

    public init() {
        setupVoiceParameters()
    }

    // MARK: - MachineProtocol Implementation

    public func initialize(configuration: MachineConfiguration) throws {
        isInitialized = true
        status = .ready
    }

    public func start() throws {
        guard isInitialized else {
            throw CommonMachineError(code: "NOT_INITIALIZED", message: "Machine not initialized", severity: .error)
        }
        status = .running
    }

    public func stop() throws {
        status = .ready
        allNotesOff()
    }

    public func suspend() throws {
        status = .suspended
    }

    public func resume() throws {
        status = .running
    }

    public func reset() {
        allNotesOff()
        _voiceStates.removeAll()
        _activeVoices = 0
        parameters.resetAllToDefaults()
    }

    public func process(input: AudioBuffer) -> AudioBuffer {
        // Mock processing - just return the input
        lastActiveTimestamp = Date()
        return input
    }

    public func healthCheck() -> MachineHealthStatus {
        return .healthy
    }

    public func resetPerformanceCounters() {
        performanceMetrics.reset()
    }

    // MARK: - VoiceMachineProtocol Implementation

    public func noteOn(note: UInt8, velocity: UInt8) {
        noteOn(note: note, velocity: velocity, channel: 0, timestamp: nil)
    }

    public func noteOn(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?) {
        if _activeVoices >= polyphony {
            // Voice stealing
            if voiceStealingMode != .none {
                let voiceToSteal = findVoiceToSteal()
                if let voiceId = voiceToSteal {
                    releaseVoice(voiceId: voiceId)
                }
            } else {
                return // Ignore new note
            }
        }

        let voiceId = allocateVoice()
        let voiceState = VoiceState(
            voiceId: voiceId,
            note: note,
            velocity: velocity,
            startTime: timestamp ?? UInt64(Date().timeIntervalSince1970 * 1000)
        )

        _voiceStates.append(voiceState)
        _activeVoices += 1
        lastActiveTimestamp = Date()
    }

    public func noteOff(note: UInt8) {
        noteOff(note: note, velocity: 64, channel: 0, timestamp: nil)
    }

    public func noteOff(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?) {
        if let index = _voiceStates.firstIndex(where: { $0.note == note && $0.isActive }) {
            _voiceStates[index] = VoiceState(
                voiceId: _voiceStates[index].voiceId,
                note: _voiceStates[index].note,
                velocity: _voiceStates[index].velocity,
                startTime: _voiceStates[index].startTime,
                isActive: false
            )
            _activeVoices = max(0, _activeVoices - 1)
        }
    }

    public func allNotesOff() {
        _voiceStates.removeAll()
        _activeVoices = 0
    }

    public func allNotesOff(channel: UInt8) {
        // For mock implementation, just call allNotesOff
        allNotesOff()
    }

    public func getVoiceAllocation(for note: UInt8) -> VoiceAllocation? {
        guard let voiceState = _voiceStates.first(where: { $0.note == note && $0.isActive }) else {
            return nil
        }

        return VoiceAllocation(
            voiceId: voiceState.voiceId,
            note: note,
            velocity: voiceState.velocity,
            timestamp: voiceState.startTime
        )
    }

    // MARK: - Helper Methods

    private func allocateVoice() -> Int {
        return Int.random(in: 0..<polyphony)
    }

    private func findVoiceToSteal() -> Int? {
        guard !_voiceStates.isEmpty else { return nil }

        switch voiceStealingMode {
        case .oldest:
            return _voiceStates.min(by: { $0.startTime < $1.startTime })?.voiceId
        case .quietest:
            return _voiceStates.min(by: { $0.amplitude < $1.amplitude })?.voiceId
        case .newest:
            return _voiceStates.max(by: { $0.startTime < $1.startTime })?.voiceId
        case .none:
            return nil
        }
    }

    private func releaseVoice(voiceId: Int) {
        if let index = _voiceStates.firstIndex(where: { $0.voiceId == voiceId }) {
            _voiceStates.remove(at: index)
            _activeVoices = max(0, _activeVoices - 1)
        }
    }
}

/// Mock filter machine implementation for testing
public class MockFilterMachine: FilterMachineProtocol, SerializableMachine, @unchecked Sendable {
    public let id = UUID()
    public var name: String = "Mock Filter Machine"
    public var isEnabled: Bool = true
    public var isInitialized: Bool = false
    public var status: MachineStatus = .uninitialized
    public var lastActiveTimestamp: Date?
    public var lastError: MachineError?
    public var errorHandler: ((MachineError) -> Void)?
    public var performanceMetrics: MachinePerformanceMetrics = MachinePerformanceMetrics()
    public var parameters: ParameterManager = ParameterManager()

    // Filter-specific properties
    public var filterType: FilterType = .lowpass
    public var slope: FilterSlope = .slope24dB
    public var quality: FilterQuality = .medium
    public var isActive: Bool = true

    public var filterState: [String: Float] {
        return [
            "cutoff": cutoff,
            "resonance": resonance,
            "drive": drive,
            "gain": gain,
            "bandwidth": bandwidth
        ]
    }

    public init() {
        setupFilterParameters()
    }

    // MARK: - MachineProtocol Implementation

    public func initialize(configuration: MachineConfiguration) throws {
        isInitialized = true
        status = .ready
    }

    public func start() throws {
        guard isInitialized else {
            throw CommonMachineError(code: "NOT_INITIALIZED", message: "Machine not initialized", severity: .error)
        }
        status = .running
    }

    public func stop() throws {
        status = .ready
    }

    public func suspend() throws {
        status = .suspended
    }

    public func resume() throws {
        status = .running
    }

    public func reset() {
        resetFilterState()
        parameters.resetAllToDefaults()
    }

    public func process(input: AudioBuffer) -> AudioBuffer {
        // Mock processing - apply simple gain based on filter settings
        lastActiveTimestamp = Date()

        // Simulate filter processing by applying a simple gain
        let gainFactor = isActive ? (1.0 - resonance * 0.5) : 1.0
        var output = input

        // Apply mock filtering effect
        for i in 0..<output.samples.count {
            output.samples[i] *= gainFactor
        }

        return output
    }

    public func healthCheck() -> MachineHealthStatus {
        return .healthy
    }

    public func resetPerformanceCounters() {
        performanceMetrics.reset()
    }

    // MARK: - FilterMachineProtocol Implementation

    public func getFrequencyResponse(at frequency: Float) -> FilterResponse {
        // Mock frequency response calculation
        let normalizedFreq = frequency / 20000.0
        let cutoffNorm = cutoff / 20000.0

        var magnitude: Float = 1.0
        var phase: Float = 0.0

        switch filterType {
        case .lowpass:
            if normalizedFreq > cutoffNorm {
                let slopeValue = Float(slope.rawValue.dropLast(2)) ?? 24.0
                let rolloff = pow(normalizedFreq / cutoffNorm, -slopeValue / 6.0)
                magnitude = rolloff * (1.0 + resonance * 2.0)
            }
            phase = -normalizedFreq * Float.pi / 2.0

        case .highpass:
            if normalizedFreq < cutoffNorm {
                let slopeValue = Float(slope.rawValue.dropLast(2)) ?? 24.0
                let rolloff = pow(normalizedFreq / cutoffNorm, slopeValue / 6.0)
                magnitude = rolloff * (1.0 + resonance * 2.0)
            }
            phase = normalizedFreq * Float.pi / 2.0

        case .bandpass:
            let distance = abs(normalizedFreq - cutoffNorm)
            magnitude = 1.0 / (1.0 + distance * 10.0 / bandwidth)
            magnitude *= (1.0 + resonance * 3.0)

        case .notch:
            let distance = abs(normalizedFreq - cutoffNorm)
            magnitude = distance * 10.0 / bandwidth
            magnitude = min(1.0, magnitude)

        case .peak:
            let distance = abs(normalizedFreq - cutoffNorm)
            if distance < bandwidth / 10.0 {
                magnitude = 1.0 + gain / 24.0
            }

        case .lowshelf:
            if normalizedFreq < cutoffNorm {
                magnitude = 1.0 + gain / 24.0
            }

        case .highshelf:
            if normalizedFreq > cutoffNorm {
                magnitude = 1.0 + gain / 24.0
            }

        case .allpass:
            // All-pass filter has unity magnitude
            magnitude = 1.0
        }

        // Apply drive
        magnitude *= (1.0 + drive * 0.5)

        return FilterResponse(frequency: frequency, magnitude: magnitude, phase: phase)
    }

    public func resetFilterState() {
        // Mock filter state reset
        isActive = true
    }

    public func updateFilterCoefficients() {
        // Mock coefficient update - in a real implementation this would recalculate filter coefficients
        lastActiveTimestamp = Date()
    }

    public func setCutoffWithKeyTracking(baseFreq: Float, note: UInt8, velocity: UInt8) {
        let noteFreq = 440.0 * pow(2.0, (Float(note) - 69.0) / 12.0)
        let trackingAmount = keyTracking
        let velocityAmount = velocitySensitivity * (Float(velocity) / 127.0)

        let trackedCutoff = baseFreq * (1.0 + trackingAmount * (noteFreq / 440.0 - 1.0))
        let finalCutoff = trackedCutoff * (1.0 + velocityAmount)

        cutoff = max(20.0, min(20000.0, finalCutoff))
        updateFilterCoefficients()
    }

    public func modulateFilter(cutoffMod: Float, resonanceMod: Float) {
        let newCutoff = cutoff * (1.0 + cutoffMod)
        let newResonance = resonance + resonanceMod

        cutoff = max(20.0, min(20000.0, newCutoff))
        resonance = max(0.0, min(1.0, newResonance))
        updateFilterCoefficients()
    }
}

/// Mock FX processor implementation for testing
public class MockFXProcessor: FXProcessorProtocol, SerializableMachine, @unchecked Sendable {
    public let id = UUID()
    public var name: String = "Mock FX Processor"
    public var isEnabled: Bool = true
    public var isInitialized: Bool = false
    public var status: MachineStatus = .uninitialized
    public var lastActiveTimestamp: Date?
    public var lastError: MachineError?
    public var errorHandler: ((MachineError) -> Void)?
    public var performanceMetrics: MachinePerformanceMetrics = MachinePerformanceMetrics()
    public var parameters: ParameterManager = ParameterManager()

    // FX-specific properties
    public let effectType: EffectType = .reverb
    public var isBypassed: Bool = false
    public var processingMode: EffectProcessingMode = .insert
    public var quality: EffectQuality = .good

    // State properties
    public var latency: Int = 0
    public var isProcessing: Bool = false
    private var _inputPeak: Float = 0.0
    private var _outputPeak: Float = 0.0

    public var inputPeak: Float { _inputPeak }
    public var outputPeak: Float { _outputPeak }

    public var effectState: [String: Float] {
        return [
            "wetLevel": wetLevel,
            "dryLevel": dryLevel,
            "inputGain": inputGain,
            "outputGain": outputGain,
            "intensity": intensity,
            "rate": rate,
            "feedback": feedback,
            "modDepth": modDepth,
            "stereoWidth": stereoWidth
        ]
    }

    public init() {
        setupEffectParameters()
    }

    // MARK: - MachineProtocol Implementation

    public func initialize(configuration: MachineConfiguration) throws {
        isInitialized = true
        status = .ready
        latency = 64 // Mock latency
    }

    public func start() throws {
        guard isInitialized else {
            throw CommonMachineError(code: "NOT_INITIALIZED", message: "Machine not initialized", severity: .error)
        }
        status = .running
        isProcessing = true
    }

    public func stop() throws {
        status = .ready
        isProcessing = false
    }

    public func suspend() throws {
        status = .suspended
        isProcessing = false
    }

    public func resume() throws {
        status = .running
        isProcessing = true
    }

    public func reset() {
        resetEffectState()
        parameters.resetAllToDefaults()
        _inputPeak = 0.0
        _outputPeak = 0.0
    }

    public func process(input: AudioBuffer) -> AudioBuffer {
        guard !isBypassed && isProcessing else {
            return input
        }

        lastActiveTimestamp = Date()

        // Calculate input peak
        _inputPeak = input.samples.map { abs($0) }.max() ?? 0.0

        // Mock effect processing
        var output = input

        // Apply input gain
        let inputGainLinear = pow(10.0, inputGain / 20.0)
        for i in 0..<output.samples.count {
            output.samples[i] *= inputGainLinear
        }

        // Apply effect processing based on type
        switch effectType {
        case .reverb:
            applyMockReverb(&output)
        case .delay:
            applyMockDelay(&output)
        case .chorus:
            applyMockChorus(&output)
        case .flanger:
            applyMockFlanger(&output)
        case .phaser:
            applyMockPhaser(&output)
        case .distortion:
            applyMockDistortion(&output)
        case .compressor:
            applyMockCompressor(&output)
        case .limiter:
            applyMockLimiter(&output)
        case .equalizer:
            applyMockEqualizer(&output)
        case .overdrive:
            applyMockDistortion(&output) // Use distortion for overdrive
        case .bitCrusher:
            applyMockDistortion(&output) // Use distortion for bit crusher
        case .sampleRateReduction:
            applyMockDistortion(&output) // Use distortion for sample rate reduction
        }

        // Apply output gain
        let outputGainLinear = pow(10.0, outputGain / 20.0)
        for i in 0..<output.samples.count {
            output.samples[i] *= outputGainLinear
        }

        // Mix wet and dry signals
        let wetOutput = output
        for i in 0..<output.samples.count {
            output.samples[i] = input.samples[i] * dryLevel + wetOutput.samples[i] * wetLevel
        }

        // Calculate output peak
        _outputPeak = output.samples.map { abs($0) }.max() ?? 0.0

        return output
    }

    public func healthCheck() -> MachineHealthStatus {
        return .healthy
    }

    public func resetPerformanceCounters() {
        performanceMetrics.reset()
    }

    // MARK: - FXProcessorProtocol Implementation

    public func resetEffectState() {
        // Mock effect state reset
        _inputPeak = 0.0
        _outputPeak = 0.0
    }

    public func flushBuffers() {
        // Mock buffer flushing
        resetEffectState()
    }

    public func processSidechain(input: AudioBuffer, sidechain: AudioBuffer?) -> AudioBuffer {
        // For mock implementation, just process normally
        return process(input: input)
    }

    public func getTailTime() -> Double {
        switch effectType {
        case .reverb:
            return 3.0 // 3 second reverb tail
        case .delay:
            return 2.0 // 2 second delay tail
        default:
            return 0.0
        }
    }

    public func setTempoSync(bpm: Double, timeSignature: TimeSignature) {
        // Mock tempo sync - adjust rate based on BPM
        if effectType == .delay || effectType == .chorus || effectType == .flanger {
            let syncedRate = Float(bpm / 120.0) // Normalize to 120 BPM
            try? parameters.updateParameter(id: "fx_rate", value: syncedRate, notifyChange: false)
        }
    }

    public func triggerAction(_ action: String, value: Float = 1.0) {
        switch action {
        case "tap_tempo":
            // Mock tap tempo
            let newRate = value
            try? parameters.updateParameter(id: "fx_rate", value: newRate)
        case "freeze":
            // Mock freeze effect
            isBypassed = value < 0.5
        case "reset":
            reset()
        default:
            break
        }
    }

    // MARK: - Mock Effect Processing Methods

    private func applyMockReverb(_ buffer: inout AudioBuffer) {
        let reverbAmount = intensity * 0.3
        for i in 0..<buffer.samples.count {
            buffer.samples[i] *= (1.0 + reverbAmount)
        }
    }

    private func applyMockDelay(_ buffer: inout AudioBuffer) {
        let delayAmount = intensity * 0.5
        for i in 0..<buffer.samples.count {
            buffer.samples[i] *= (1.0 + delayAmount * feedback)
        }
    }

    private func applyMockChorus(_ buffer: inout AudioBuffer) {
        let chorusAmount = intensity * modDepth
        for i in 0..<buffer.samples.count {
            let modulation = sin(Float(i) * rate * 0.01) * chorusAmount
            buffer.samples[i] *= (1.0 + modulation)
        }
    }

    private func applyMockFlanger(_ buffer: inout AudioBuffer) {
        let flangerAmount = intensity * modDepth * 0.5
        for i in 0..<buffer.samples.count {
            let modulation = sin(Float(i) * rate * 0.02) * flangerAmount
            buffer.samples[i] *= (1.0 + modulation)
        }
    }

    private func applyMockPhaser(_ buffer: inout AudioBuffer) {
        let phaserAmount = intensity * modDepth * 0.3
        for i in 0..<buffer.samples.count {
            let modulation = sin(Float(i) * rate * 0.005) * phaserAmount
            buffer.samples[i] *= (1.0 + modulation)
        }
    }

    private func applyMockDistortion(_ buffer: inout AudioBuffer) {
        let distortionAmount = intensity * 2.0
        for i in 0..<buffer.samples.count {
            buffer.samples[i] = tanh(buffer.samples[i] * distortionAmount)
        }
    }

    private func applyMockCompressor(_ buffer: inout AudioBuffer) {
        let compressionRatio = 1.0 + intensity * 3.0
        for i in 0..<buffer.samples.count {
            let amplitude = abs(buffer.samples[i])
            if amplitude > 0.5 {
                let compressed = 0.5 + (amplitude - 0.5) / compressionRatio
                buffer.samples[i] = buffer.samples[i] > 0 ? compressed : -compressed
            }
        }
    }

    private func applyMockLimiter(_ buffer: inout AudioBuffer) {
        let threshold = 1.0 - intensity * 0.5
        for i in 0..<buffer.samples.count {
            buffer.samples[i] = max(-threshold, min(threshold, buffer.samples[i]))
        }
    }

    private func applyMockEqualizer(_ buffer: inout AudioBuffer) {
        let eqGain = 1.0 + (intensity - 0.5) * 0.5
        for i in 0..<buffer.samples.count {
            buffer.samples[i] *= eqGain
        }
    }
}

// MARK: - Enhanced Shared Data Structures

/// Enhanced audio buffer structure for professional audio processing
public struct EnhancedAudioBuffer {
    /// Sample data storage
    public let samples: UnsafeMutablePointer<Float>
    
    /// Number of audio frames (samples per channel)
    public let frameCount: Int
    
    /// Number of audio channels
    public let channelCount: Int
    
    /// Sample rate in Hz
    public let sampleRate: Double
    
    /// Whether the buffer uses interleaved format
    public let isInterleaved: Bool
    
    /// Buffer capacity in frames
    public let capacity: Int
    
    /// Initialize an enhanced audio buffer
    public init(frameCount: Int, channelCount: Int, sampleRate: Double, isInterleaved: Bool = true) {
        self.frameCount = frameCount
        self.channelCount = channelCount
        self.sampleRate = sampleRate
        self.isInterleaved = isInterleaved
        self.capacity = frameCount
        
        let totalSamples = frameCount * channelCount
        self.samples = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)
        self.samples.initialize(repeating: 0.0, count: totalSamples)
    }
    
    /// Get sample at specific frame and channel
    public func getSample(frame: Int, channel: Int) -> Float {
        guard frame < frameCount && channel < channelCount else { return 0.0 }
        
        if isInterleaved {
            return samples[frame * channelCount + channel]
        } else {
            return samples[channel * frameCount + frame]
        }
    }
    
    /// Set sample at specific frame and channel
    public func setSample(frame: Int, channel: Int, value: Float) {
        guard frame < frameCount && channel < channelCount else { return }
        
        if isInterleaved {
            samples[frame * channelCount + channel] = value
        } else {
            samples[channel * frameCount + frame] = value
        }
    }
    
    /// Clear all samples to zero
    public func clear() {
        let totalSamples = frameCount * channelCount
        samples.initialize(repeating: 0.0, count: totalSamples)
    }
    
    /// Copy samples from another buffer
    public func copy(from source: EnhancedAudioBuffer, sourceFrame: Int = 0, destFrame: Int = 0, frameCount: Int? = nil) {
        let framesToCopy = frameCount ?? min(self.frameCount - destFrame, source.frameCount - sourceFrame)
        let channelsToCopy = min(self.channelCount, source.channelCount)
        
        for frame in 0..<framesToCopy {
            for channel in 0..<channelsToCopy {
                let sourceValue = source.getSample(frame: sourceFrame + frame, channel: channel)
                setSample(frame: destFrame + frame, channel: channel, value: sourceValue)
            }
        }
    }
    
    /// Deallocate buffer memory
    public func deallocate() {
        samples.deallocate()
    }
}

/// MIDI message types
public enum MIDIMessageType: UInt8, CaseIterable, Codable, Sendable {
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
public struct MIDIMessage: Sendable, Codable {
    /// Message type
    public let type: MIDIMessageType
    
    /// MIDI channel (0-15)
    public let channel: UInt8
    
    /// First data byte
    public let data1: UInt8
    
    /// Second data byte
    public let data2: UInt8
    
    /// Initialize a MIDI message
    public init(type: MIDIMessageType, channel: UInt8, data1: UInt8, data2: UInt8 = 0) {
        self.type = type
        self.channel = min(channel, 15)
        self.data1 = data1
        self.data2 = data2
    }
    
    /// Create a Note On message
    public static func noteOn(channel: UInt8, note: UInt8, velocity: UInt8) -> MIDIMessage {
        return MIDIMessage(type: .noteOn, channel: channel, data1: note, data2: velocity)
    }
    
    /// Create a Note Off message
    public static func noteOff(channel: UInt8, note: UInt8, velocity: UInt8 = 64) -> MIDIMessage {
        return MIDIMessage(type: .noteOff, channel: channel, data1: note, data2: velocity)
    }
    
    /// Create a Control Change message
    public static func controlChange(channel: UInt8, controller: UInt8, value: UInt8) -> MIDIMessage {
        return MIDIMessage(type: .controlChange, channel: channel, data1: controller, data2: value)
    }
    
    /// Create a Program Change message
    public static func programChange(channel: UInt8, program: UInt8) -> MIDIMessage {
        return MIDIMessage(type: .programChange, channel: channel, data1: program)
    }
    
    /// Create a Pitch Bend message
    public static func pitchBend(channel: UInt8, value: UInt16) -> MIDIMessage {
        let lsb = UInt8(value & 0x7F)
        let msb = UInt8((value >> 7) & 0x7F)
        return MIDIMessage(type: .pitchBend, channel: channel, data1: lsb, data2: msb)
    }
    
    /// Get the raw MIDI bytes
    public var rawBytes: [UInt8] {
        let statusByte = type.rawValue | (channel & 0x0F)
        
        switch type {
        case .programChange, .channelPressure:
            return [statusByte, data1]
        default:
            return [statusByte, data1, data2]
        }
    }
}

/// MIDI event with timestamp
public struct MIDIEvent: Sendable, Codable {
    /// Timestamp in samples
    public let timestamp: UInt64
    
    /// MIDI message
    public let message: MIDIMessage
    
    /// Initialize a MIDI event
    public init(timestamp: UInt64, message: MIDIMessage) {
        self.timestamp = timestamp
        self.message = message
    }
}

/// Time signature structure
public struct TimeSignature: Sendable, Codable, Equatable {
    /// Numerator (beats per bar)
    public let numerator: Int
    
    /// Denominator (note value)
    public let denominator: Int
    
    /// Initialize time signature
    public init(numerator: Int, denominator: Int) {
        self.numerator = max(1, numerator)
        self.denominator = max(1, denominator)
    }
    
    /// Common time signatures
    public static let fourFour = TimeSignature(numerator: 4, denominator: 4)
    public static let threeFour = TimeSignature(numerator: 3, denominator: 4)
    public static let twoFour = TimeSignature(numerator: 2, denominator: 4)
    public static let sixEight = TimeSignature(numerator: 6, denominator: 8)
}

/// Musical time position
public struct MusicalTime: Sendable, Codable, Equatable {
    /// Bar number (0-based)
    public let bar: Int
    
    /// Beat within bar (0-based)
    public let beat: Int
    
    /// Tick within beat (0-based, typically 0-95 for 96 PPQN)
    public let tick: Int
    
    /// Initialize musical time
    public init(bar: Int, beat: Int, tick: Int) {
        self.bar = max(0, bar)
        self.beat = max(0, beat)
        self.tick = max(0, tick)
    }
    
    /// Convert to total ticks
    public func totalTicks(timeSignature: TimeSignature, ppqn: Int = 96) -> Int {
        let ticksPerBeat = ppqn
        let beatsPerBar = timeSignature.numerator
        let ticksPerBar = beatsPerBar * ticksPerBeat
        
        return (bar * ticksPerBar) + (beat * ticksPerBeat) + tick
    }
    
    /// Create from total ticks
    public static func from(totalTicks: Int, timeSignature: TimeSignature, ppqn: Int = 96) -> MusicalTime {
        let ticksPerBeat = ppqn
        let beatsPerBar = timeSignature.numerator
        let ticksPerBar = beatsPerBar * ticksPerBeat
        
        let bar = totalTicks / ticksPerBar
        let remainingTicks = totalTicks % ticksPerBar
        let beat = remainingTicks / ticksPerBeat
        let tick = remainingTicks % ticksPerBeat
        
        return MusicalTime(bar: bar, beat: beat, tick: tick)
    }
}

/// Time information structure
public struct TimeInfo: Sendable, Codable {
    /// Current sample position
    public let samplePosition: UInt64
    
    /// Sample rate in Hz
    public let sampleRate: Double
    
    /// Tempo in BPM
    public let tempo: Double
    
    /// Time signature
    public let timeSignature: TimeSignature
    
    /// Musical time position
    public let musicalTime: MusicalTime
    
    /// Whether transport is playing
    public let isPlaying: Bool
    
    /// Whether transport is recording
    public let isRecording: Bool
    
    /// Pulses per quarter note
    public let ppqn: Int
    
    /// Initialize time info
    public init(samplePosition: UInt64, sampleRate: Double, tempo: Double, timeSignature: TimeSignature, musicalTime: MusicalTime, isPlaying: Bool = false, isRecording: Bool = false, ppqn: Int = 96) {
        self.samplePosition = samplePosition
        self.sampleRate = max(1.0, sampleRate)
        self.tempo = max(1.0, tempo)
        self.timeSignature = timeSignature
        self.musicalTime = musicalTime
        self.isPlaying = isPlaying
        self.isRecording = isRecording
        self.ppqn = max(1, ppqn)
    }
    
    /// Get time in seconds
    public var timeInSeconds: Double {
        return Double(samplePosition) / sampleRate
    }
    
    /// Get samples per beat
    public var samplesPerBeat: Double {
        return (60.0 / tempo) * sampleRate
    }
    
    /// Get samples per tick
    public var samplesPerTick: Double {
        return samplesPerBeat / Double(ppqn)
    }
}

/// Audio format specification
public struct AudioFormat: Sendable, Codable, Equatable {
    /// Sample rate in Hz
    public let sampleRate: Double
    
    /// Number of channels
    public let channelCount: Int
    
    /// Bit depth
    public let bitDepth: Int
    
    /// Whether format is interleaved
    public let isInterleaved: Bool
    
    /// Whether format is floating point
    public let isFloatingPoint: Bool
    
    /// Initialize audio format
    public init(sampleRate: Double, channelCount: Int, bitDepth: Int, isInterleaved: Bool = true, isFloatingPoint: Bool = true) {
        self.sampleRate = max(1.0, sampleRate)
        self.channelCount = max(1, channelCount)
        self.bitDepth = max(8, bitDepth)
        self.isInterleaved = isInterleaved
        self.isFloatingPoint = isFloatingPoint
    }
    
    /// Common audio formats
    public static let cd = AudioFormat(sampleRate: 44100, channelCount: 2, bitDepth: 16, isFloatingPoint: false)
    public static let dvd = AudioFormat(sampleRate: 48000, channelCount: 2, bitDepth: 24, isFloatingPoint: false)
    public static let studio = AudioFormat(sampleRate: 48000, channelCount: 2, bitDepth: 32, isFloatingPoint: true)
    public static let highRes = AudioFormat(sampleRate: 96000, channelCount: 2, bitDepth: 32, isFloatingPoint: true)
    
    /// Get bytes per sample
    public var bytesPerSample: Int {
        return bitDepth / 8
    }
    
    /// Get bytes per frame
    public var bytesPerFrame: Int {
        return bytesPerSample * channelCount
    }
}

/// Parameter automation point
public struct AutomationPoint: Sendable, Codable, Equatable {
    /// Time position in samples
    public let time: UInt64
    
    /// Parameter value
    public let value: Float
    
    /// Curve type for interpolation
    public let curve: AutomationCurve
    
    /// Initialize automation point
    public init(time: UInt64, value: Float, curve: AutomationCurve = .linear) {
        self.time = time
        self.value = value
        self.curve = curve
    }
}

/// Automation curve types
public enum AutomationCurve: String, CaseIterable, Codable, Sendable {
    case linear = "linear"
    case exponential = "exponential"
    case logarithmic = "logarithmic"
    case smooth = "smooth"
    case step = "step"
}

/// Parameter automation data
public struct ParameterAutomation: Sendable, Codable {
    /// Parameter identifier
    public let parameterId: String
    
    /// Automation points
    public let points: [AutomationPoint]
    
    /// Whether automation is enabled
    public let isEnabled: Bool
    
    /// Initialize parameter automation
    public init(parameterId: String, points: [AutomationPoint], isEnabled: Bool = true) {
        self.parameterId = parameterId
        self.points = points.sorted { $0.time < $1.time }
        self.isEnabled = isEnabled
    }
    
    /// Get interpolated value at specific time
    public func valueAt(time: UInt64) -> Float? {
        guard isEnabled && !points.isEmpty else { return nil }
        
        // Find surrounding points
        var beforePoint: AutomationPoint?
        var afterPoint: AutomationPoint?
        
        for point in points {
            if point.time <= time {
                beforePoint = point
            } else {
                afterPoint = point
                break
            }
        }
        
        // Handle edge cases
        if beforePoint == nil {
            return points.first?.value
        }
        
        if afterPoint == nil {
            return beforePoint?.value
        }
        
        guard let before = beforePoint, let after = afterPoint else {
            return nil
        }
        
        // Calculate interpolation factor
        let timeDiff = after.time - before.time
        guard timeDiff > 0 else { return before.value }
        
        let factor = Float(time - before.time) / Float(timeDiff)
        
        // Interpolate based on curve type
        switch before.curve {
        case .linear:
            return before.value + (after.value - before.value) * factor
        case .exponential:
            let expFactor = factor * factor
            return before.value + (after.value - before.value) * expFactor
        case .logarithmic:
            let logFactor = sqrt(factor)
            return before.value + (after.value - before.value) * logFactor
        case .smooth:
            let smoothFactor = factor * factor * (3.0 - 2.0 * factor)
            return before.value + (after.value - before.value) * smoothFactor
        case .step:
            return before.value
        }
    }
}