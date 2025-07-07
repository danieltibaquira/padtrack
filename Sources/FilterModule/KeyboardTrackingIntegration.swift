// KeyboardTrackingIntegration.swift
// DigitonePad - FilterModule
//
// Enhanced keyboard tracking integration for voice machines and filters
// Provides seamless integration between MIDI input and filter cutoff control

import Foundation
import MachineProtocols
import AudioEngine
import VoiceModule

// MARK: - Keyboard Tracking Types

/// Configuration for keyboard tracking behavior
public struct KeyboardTrackingConfig: Sendable {
    public var trackingAmount: Float = 0.0      // -100% to +100% (negative = inverse tracking)
    public var referenceNote: UInt8 = 60        // C4 (MIDI note 60) as reference
    public var referenceFrequency: Float = 261.63  // C4 frequency in Hz
    public var trackingCurve: TrackingCurve = .linear
    public var velocitySensitivity: Float = 0.0 // 0.0 to 1.0
    public var trackingRange: ClosedRange<Float> = 20.0...20000.0  // Frequency limits
    public var smoothingTime: Float = 0.001     // Smoothing time in seconds
    
    // Legacy compatibility aliases
    public var amount: Float {
        get { trackingAmount / 100.0 }  // Convert percentage to 0-1 range
        set { trackingAmount = newValue * 100.0 }
    }
    public var keyCenter: UInt8 {
        get { referenceNote }
        set { referenceNote = newValue }
    }
    public var trackingMode: TrackingMode {
        get {
            switch trackingCurve {
            case .linear: return .linear
            case .exponential: return .exponential
            default: return .custom
            }
        }
        set {
            switch newValue {
            case .linear: trackingCurve = .linear
            case .exponential: trackingCurve = .exponential
            case .custom: trackingCurve = .sCurve
            }
        }
    }
    
    public init() {}
    
    public init(trackingAmount: Float = 0.0, referenceNote: UInt8 = 60, referenceFrequency: Float = 261.63, trackingCurve: TrackingCurve = .linear, velocitySensitivity: Float = 0.0, trackingRange: ClosedRange<Float> = 20.0...20000.0) {
        self.trackingAmount = trackingAmount
        self.referenceNote = referenceNote
        self.referenceFrequency = referenceFrequency
        self.trackingCurve = trackingCurve
        self.velocitySensitivity = velocitySensitivity
        self.trackingRange = trackingRange
    }
}

/// Tracking curve types for different musical behaviors
public enum TrackingCurve: CaseIterable, Codable, Sendable {
    case linear      // Direct 1:1 tracking
    case exponential // Exponential curve for more dramatic high-end tracking
    case logarithmic // Logarithmic curve for subtle high-end tracking
    case sCurve      // S-curve for smooth transitions
}

/// Legacy tracking modes for backward compatibility
public enum TrackingMode: CaseIterable, Codable {
    case linear      // Linear tracking
    case exponential // Exponential tracking
    case custom      // Custom curve
}

/// Delegate protocol for keyboard tracking events
public protocol KeyboardTrackingDelegate: AnyObject {
    func trackingEngineRegistered(id: String)
    func trackingEngineUnregistered(id: String)
    func trackingValueChanged(engineId: String, note: UInt8, value: Float)
}

/// Real-time parameters for keyboard tracking modulation
public struct KeyboardTrackingParameters {
    public var currentNote: UInt8 = 60          // Currently played MIDI note
    public var velocity: UInt8 = 100            // MIDI velocity (0-127)
    public var pitchBend: Float = 0.0           // Pitch bend amount (-1.0 to +1.0)
    public var isNoteActive: Bool = false       // Whether a note is currently pressed
    public var portamentoTime: Float = 0.0      // Glide time between notes
    
    public init() {}
}

/// Individual keyboard tracking engine
public class KeyboardTrackingEngine {
    public var config = KeyboardTrackingConfig()
    public var parameters = KeyboardTrackingParameters()
    
    private var lastNote: UInt8 = 60
    private var lastVelocity: UInt8 = 127
    private var currentValue: Float = 0.0
    private var currentTrackingFrequency: Float = 261.63
    private var smoothedFrequency: Float = 261.63
    private var previousNote: UInt8 = 60
    private var portamentoPhase: Float = 1.0
    
    public init() {}
    
    /// Calculate tracking value for a given note
    public func calculateTrackingValue(note: UInt8, velocity: UInt8 = 127) -> Float {
        lastNote = note
        lastVelocity = velocity
        parameters.currentNote = note
        parameters.velocity = velocity
        parameters.isNoteActive = true
        
        guard config.trackingAmount != 0.0 else { return 0.0 }
        
        let noteOffset = Float(note) - Float(config.referenceNote)
        let velocityFactor = 1.0 + (Float(velocity) / 127.0 - 1.0) * config.velocitySensitivity
        
        var trackingValue: Float
        
        switch config.trackingCurve {
        case .linear:
            trackingValue = noteOffset / 12.0 // Octave-based tracking
        case .exponential:
            trackingValue = pow(2.0, noteOffset / 12.0) - 1.0
        case .logarithmic:
            trackingValue = log2(1.0 + abs(noteOffset) / 12.0) * sign(noteOffset)
        case .sCurve:
            // S-curve for smooth transitions
            let normalized = noteOffset / 24.0 // ±2 octaves
            trackingValue = tanh(normalized * 2.0)
        }
        
        currentValue = trackingValue * (config.trackingAmount / 100.0) * velocityFactor
        return currentValue
    }
    
    /// Get the current tracking value
    public func getCurrentValue() -> Float {
        return currentValue
    }
    
    /// Calculate the tracked cutoff frequency based on current MIDI input
    public func calculateTrackedFrequency(baseCutoff: Float) -> Float {
        guard parameters.isNoteActive else {
            return baseCutoff
        }
        
        let noteOffset = Float(parameters.currentNote) - Float(config.referenceNote)
        let adjustedNoteOffset = noteOffset + (parameters.pitchBend * 2.0)
        let frequencyRatio = pow(2.0, adjustedNoteOffset / 12.0)
        let trackingMultiplier = 1.0 + (config.trackingAmount * 0.01 * (frequencyRatio - 1.0))
        
        var trackedFrequency = baseCutoff * trackingMultiplier
        
        if config.velocitySensitivity > 0.0 {
            let velocityFactor = Float(parameters.velocity) / 127.0
            let velocityModulation = 1.0 + (config.velocitySensitivity * (velocityFactor - 0.5) * 2.0)
            trackedFrequency *= velocityModulation
        }
        
        trackedFrequency = max(config.trackingRange.lowerBound,
                              min(config.trackingRange.upperBound, trackedFrequency))
        
        currentTrackingFrequency = trackedFrequency
        return trackedFrequency
    }
    
    /// Handle MIDI note on event
    public func noteOn(note: UInt8, velocity: UInt8) {
        previousNote = parameters.currentNote
        parameters.currentNote = note
        parameters.velocity = velocity
        parameters.isNoteActive = true
        portamentoPhase = 0.0
        _ = calculateTrackingValue(note: note, velocity: velocity)
    }
    
    /// Handle MIDI note off event
    public func noteOff(note: UInt8) {
        if note == parameters.currentNote {
            parameters.isNoteActive = false
        }
    }
    
    /// Handle pitch bend event
    public func pitchBend(amount: Float) {
        parameters.pitchBend = max(-1.0, min(1.0, amount))
    }
    
    /// Get current tracking state for debugging/display
    public func getTrackingInfo() -> TrackingInfo {
        return TrackingInfo(
            isActive: parameters.isNoteActive,
            currentNote: parameters.currentNote,
            referenceNote: config.referenceNote,
            noteOffset: Float(parameters.currentNote) - Float(config.referenceNote),
            trackingAmount: config.trackingAmount,
            currentFrequency: currentTrackingFrequency,
            smoothedFrequency: smoothedFrequency,
            velocityFactor: Float(parameters.velocity) / 127.0,
            pitchBendAmount: parameters.pitchBend,
            portamentoPhase: portamentoPhase
        )
    }
    
    /// Reset the tracking state
    public func reset() {
        currentValue = 0.0
        lastNote = config.referenceNote
        lastVelocity = 127
        parameters = KeyboardTrackingParameters()
        parameters.currentNote = config.referenceNote
        currentTrackingFrequency = config.referenceFrequency
        smoothedFrequency = config.referenceFrequency
        portamentoPhase = 1.0
    }
}

// MARK: - Tracking Info

/// Current state of keyboard tracking for debugging/display
public struct TrackingInfo {
    public let isActive: Bool
    public let currentNote: UInt8
    public let referenceNote: UInt8
    public let noteOffset: Float      // Semitones from reference
    public let trackingAmount: Float  // Percentage (-100 to +100)
    public let currentFrequency: Float
    public let smoothedFrequency: Float
    public let velocityFactor: Float  // 0.0 to 1.0
    public let pitchBendAmount: Float // -1.0 to +1.0
    public let portamentoPhase: Float // 0.0 to 1.0
    
    /// Format tracking info for display
    public var displayString: String {
        let noteName = noteNumberToName(currentNote)
        let refNoteName = noteNumberToName(referenceNote)
        let direction = trackingAmount >= 0 ? "Normal" : "Inverse"
        
        return """
        Keyboard Tracking:
        Current: \(noteName) (\(currentNote))
        Reference: \(refNoteName) (\(referenceNote))
        Offset: \(noteOffset > 0 ? "+" : "")\(String(format: "%.1f", noteOffset)) semitones
        Tracking: \(String(format: "%.1f", abs(trackingAmount)))% (\(direction))
        Frequency: \(String(format: "%.2f", currentFrequency)) Hz
        Active: \(isActive ? "Yes" : "No")
        Portamento: \(String(format: "%.1f", portamentoPhase * 100))% complete
        """
    }
    
    /// Convert MIDI note number to note name
    private func noteNumberToName(_ note: UInt8) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(note) / 12 - 1
        let noteIndex = Int(note) % 12
        return "\(noteNames[noteIndex])\(octave)"
    }
}

// MARK: - Keyboard Tracking Integration Manager

/// Comprehensive integration manager for keyboard tracking across the system
public final class KeyboardTrackingIntegrationManager: @unchecked Sendable {
    
    // MARK: - Core Components
    
    /// Individual tracking engines for different filter instances
    private var trackingEngines: [String: KeyboardTrackingEngine] = [:]
    
    /// Active voice tracking (maps voice ID to tracking engine ID)
    private var voiceTrackingMap: [String: String] = [:]
    
    /// Global tracking configuration
    public var globalConfig: KeyboardTrackingConfig {
        didSet {
            updateAllEngines()
        }
    }
    
    // MARK: - Delegate Protocol
    
    public weak var delegate: KeyboardTrackingDelegate?
    
    // MARK: - Initialization
    
    public init(globalConfig: KeyboardTrackingConfig = KeyboardTrackingConfig()) {
        self.globalConfig = globalConfig
    }
    
    // MARK: - Engine Management
    
    /// Register a new tracking engine for a specific filter or voice machine
    public func registerTrackingEngine(id: String, config: KeyboardTrackingConfig? = nil) {
        let engineConfig = config ?? globalConfig
        let engine = KeyboardTrackingEngine()
        engine.config = engineConfig
        trackingEngines[id] = engine
        
        delegate?.trackingEngineRegistered(id: id)
    }
    
    /// Unregister a tracking engine
    public func unregisterTrackingEngine(id: String) {
        trackingEngines.removeValue(forKey: id)
        
        // Clean up voice mappings
        voiceTrackingMap = voiceTrackingMap.filter { $0.value != id }
        
        delegate?.trackingEngineUnregistered(id: id)
    }
    
    /// Get a tracking engine by ID
    public func getTrackingEngine(id: String) -> KeyboardTrackingEngine? {
        return trackingEngines[id]
    }
    
    /// Get all registered engine IDs
    public var registeredEngineIDs: [String] {
        return Array(trackingEngines.keys)
    }
    
    // MARK: - Voice Integration
    
    /// Associate a voice with a tracking engine
    public func associateVoice(voiceID: String, withTrackingEngine engineID: String) {
        guard trackingEngines[engineID] != nil else {
            print("Warning: Tracking engine \(engineID) not found")
            return
        }
        
        voiceTrackingMap[voiceID] = engineID
        delegate?.voiceAssociated(voiceID: voiceID, engineID: engineID)
    }
    
    /// Disassociate a voice from tracking
    public func disassociateVoice(voiceID: String) {
        if let engineID = voiceTrackingMap.removeValue(forKey: voiceID) {
            delegate?.voiceDisassociated(voiceID: voiceID, engineID: engineID)
        }
    }
    
    /// Get the tracking engine ID for a voice
    public func getTrackingEngineID(forVoice voiceID: String) -> String? {
        return voiceTrackingMap[voiceID]
    }
    
    // MARK: - MIDI Event Processing
    
    /// Process MIDI note on event for all relevant engines
    public func processMIDINoteOn(note: UInt8, velocity: UInt8, channel: UInt8, voiceID: String? = nil) {
        if let voiceID = voiceID, let engineID = voiceTrackingMap[voiceID] {
            // Process for specific voice
            trackingEngines[engineID]?.noteOn(note: note, velocity: velocity)
            delegate?.trackingUpdated(engineID: engineID, note: note, velocity: velocity)
        } else {
            // Process for all engines (global mode)
            for (engineID, engine) in trackingEngines {
                engine.noteOn(note: note, velocity: velocity)
                delegate?.trackingUpdated(engineID: engineID, note: note, velocity: velocity)
            }
        }
    }
    
    /// Process MIDI note off event
    public func processMIDINoteOff(note: UInt8, velocity: UInt8, channel: UInt8, voiceID: String? = nil) {
        if let voiceID = voiceID, let engineID = voiceTrackingMap[voiceID] {
            // Process for specific voice
            trackingEngines[engineID]?.noteOff(note: note)
            delegate?.trackingUpdated(engineID: engineID, note: note, velocity: 0)
        } else {
            // Process for all engines (global mode)
            for (engineID, engine) in trackingEngines {
                engine.noteOff(note: note)
                delegate?.trackingUpdated(engineID: engineID, note: note, velocity: 0)
            }
        }
    }
    
    /// Process pitch bend event
    public func processPitchBend(amount: Float, channel: UInt8, voiceID: String? = nil) {
        if let voiceID = voiceID, let engineID = voiceTrackingMap[voiceID] {
            // Process for specific voice
            trackingEngines[engineID]?.pitchBend(amount: amount)
            delegate?.pitchBendUpdated(engineID: engineID, amount: amount)
        } else {
            // Process for all engines (global mode)
            for (engineID, engine) in trackingEngines {
                engine.pitchBend(amount: amount)
                delegate?.pitchBendUpdated(engineID: engineID, amount: amount)
            }
        }
    }
    
    // MARK: - Filter Integration
    
    /// Calculate tracked cutoff frequency for a specific engine
    public func calculateTrackedCutoff(engineID: String, baseCutoff: Float) -> Float {
        guard let engine = trackingEngines[engineID] else {
            return baseCutoff
        }
        
        return engine.calculateTrackedFrequency(baseCutoff: baseCutoff)
    }
    
    /// Calculate tracked cutoff for a voice
    public func calculateTrackedCutoff(voiceID: String, baseCutoff: Float) -> Float {
        guard let engineID = voiceTrackingMap[voiceID],
              let engine = trackingEngines[engineID] else {
            return baseCutoff
        }
        
        return engine.calculateTrackedFrequency(baseCutoff: baseCutoff)
    }
    
    /// Get tracking information for debugging/display
    public func getTrackingInfo(engineID: String) -> TrackingInfo? {
        return trackingEngines[engineID]?.getTrackingInfo()
    }
    
    // MARK: - Configuration Management
    
    /// Update configuration for a specific engine
    public func updateEngineConfig(engineID: String, config: KeyboardTrackingConfig) {
        trackingEngines[engineID]?.config = config
        delegate?.configurationUpdated(engineID: engineID)
    }
    
    /// Update global configuration and apply to all engines
    public func updateGlobalConfig(_ config: KeyboardTrackingConfig) {
        self.globalConfig = config
        updateAllEngines()
    }
    
    /// Apply a preset to a specific engine
    public func applyPreset(engineID: String, presetName: String) {
        trackingEngines[engineID]?.config.loadPreset(presetName)
        delegate?.presetApplied(engineID: engineID, presetName: presetName)
    }
    
    /// Apply a preset to all engines
    public func applyGlobalPreset(_ presetName: String) {
        globalConfig.loadPreset(presetName)
        updateAllEngines()
    }
    
    // MARK: - Utility Methods
    
    /// Reset all tracking engines
    public func resetAllEngines() {
        for (engineID, engine) in trackingEngines {
            engine.reset()
            delegate?.trackingReset(engineID: engineID)
        }
    }
    
    /// Reset a specific engine
    public func resetEngine(engineID: String) {
        trackingEngines[engineID]?.reset()
        delegate?.trackingReset(engineID: engineID)
    }
    
    /// Get all active tracking information
    public func getAllTrackingInfo() -> [String: TrackingInfo] {
        var info: [String: TrackingInfo] = [:]
        for (engineID, engine) in trackingEngines {
            info[engineID] = engine.getTrackingInfo()
        }
        return info
    }
    
    // MARK: - Private Methods
    
    private func updateAllEngines() {
        for (engineID, engine) in trackingEngines {
            engine.config = globalConfig
            delegate?.configurationUpdated(engineID: engineID)
        }
    }
}

// MARK: - Preset Configurations

extension KeyboardTrackingConfig {
    
    /// Common tracking presets for different musical styles
    public static let trackingPresets: [String: KeyboardTrackingConfig] = [
        "Off": KeyboardTrackingConfig(trackingAmount: 0.0),
        
        "Subtle": KeyboardTrackingConfig(
            trackingAmount: 25.0,
            trackingCurve: .linear,
            velocitySensitivity: 0.1
        ),
        
        "Standard": KeyboardTrackingConfig(
            trackingAmount: 50.0,
            trackingCurve: .linear,
            velocitySensitivity: 0.2
        ),
        
        "Full": KeyboardTrackingConfig(
            trackingAmount: 100.0,
            trackingCurve: .linear,
            velocitySensitivity: 0.3
        ),
        
        "Inverse": KeyboardTrackingConfig(
            trackingAmount: -50.0,
            trackingCurve: .linear,
            velocitySensitivity: 0.1
        ),
        
        "Exponential": KeyboardTrackingConfig(
            trackingAmount: 75.0,
            trackingCurve: .exponential,
            velocitySensitivity: 0.4
        ),
        
        "Smooth": KeyboardTrackingConfig(
            trackingAmount: 60.0,
            trackingCurve: .sCurve,
            velocitySensitivity: 0.25
        )
    ]
    
    /// Load a preset configuration
    public mutating func loadPreset(_ presetName: String) {
        if let preset = Self.trackingPresets[presetName] {
            self = preset
        }
    }
}

// MARK: - Keyboard Tracking Delegate

/// Delegate protocol for keyboard tracking events
public protocol KeyboardTrackingDelegate: AnyObject {
    
    /// Called when a tracking engine is registered
    func trackingEngineRegistered(id: String)
    
    /// Called when a tracking engine is unregistered
    func trackingEngineUnregistered(id: String)
    
    /// Called when a voice is associated with a tracking engine
    func voiceAssociated(voiceID: String, engineID: String)
    
    /// Called when a voice is disassociated from tracking
    func voiceDisassociated(voiceID: String, engineID: String)
    
    /// Called when tracking is updated due to MIDI input
    func trackingUpdated(engineID: String, note: UInt8, velocity: UInt8)
    
    /// Called when pitch bend is updated
    func pitchBendUpdated(engineID: String, amount: Float)
    
    /// Called when configuration is updated
    func configurationUpdated(engineID: String)
    
    /// Called when a preset is applied
    func presetApplied(engineID: String, presetName: String)
    
    /// Called when tracking is reset
    func trackingReset(engineID: String)
}

// MARK: - Voice Machine Integration Extension

/// Extension to integrate keyboard tracking with voice machines
public extension VoiceMachine {
    
    /// Keyboard tracking integration manager (should be set by the audio engine)
    @MainActor private static var trackingManager: KeyboardTrackingIntegrationManager?
    
    /// Set the global tracking manager
    @MainActor static func setTrackingManager(_ manager: KeyboardTrackingIntegrationManager) {
        trackingManager = manager
    }
    
    /// Get the global tracking manager
    @MainActor static func getTrackingManager() -> KeyboardTrackingIntegrationManager? {
        return trackingManager
    }
    
    /// Register this voice machine for keyboard tracking
    @MainActor func registerForKeyboardTracking(config: KeyboardTrackingConfig? = nil) {
        let engineID = "\(name)_\(id.uuidString)"
        Self.trackingManager?.registerTrackingEngine(id: engineID, config: config)
    }
    
    /// Unregister from keyboard tracking
    @MainActor func unregisterFromKeyboardTracking() {
        let engineID = "\(name)_\(id.uuidString)"
        Self.trackingManager?.unregisterTrackingEngine(id: engineID)
    }
    
    /// Get tracked cutoff frequency for this voice machine
    @MainActor func getTrackedCutoff(baseCutoff: Float) -> Float {
        let engineID = "\(name)_\(id.uuidString)"
        return Self.trackingManager?.calculateTrackedCutoff(engineID: engineID, baseCutoff: baseCutoff) ?? baseCutoff
    }
    
    /// Override noteOn to integrate with keyboard tracking
    @MainActor func noteOnWithTracking(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?) {
        // Call original noteOn
        noteOn(note: note, velocity: velocity, channel: channel, timestamp: timestamp)
        
        // Update keyboard tracking
        let voiceID = id.uuidString
        Self.trackingManager?.processMIDINoteOn(note: note, velocity: velocity, channel: channel, voiceID: voiceID)
    }
    
    /// Override noteOff to integrate with keyboard tracking
    @MainActor func noteOffWithTracking(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?) {
        // Call original noteOff
        noteOff(note: note, velocity: velocity, channel: channel, timestamp: timestamp)
        
        // Update keyboard tracking
        let voiceID = id.uuidString
        Self.trackingManager?.processMIDINoteOff(note: note, velocity: velocity, channel: channel, voiceID: voiceID)
    }
}
