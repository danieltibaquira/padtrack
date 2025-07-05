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
public struct KeyboardTrackingConfig {
    public var amount: Float = 0.0               // Tracking amount (0.0 to 1.0)
    public var keyCenter: UInt8 = 60            // Center note (C4)
    public var trackingMode: TrackingMode = .linear
    public var velocitySensitivity: Float = 0.0 // Velocity influence (0.0 to 1.0)
    public var smoothingTime: Float = 0.001     // Smoothing time in seconds
    
    public init() {}
}

/// Keyboard tracking modes
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

/// Individual keyboard tracking engine
public class KeyboardTrackingEngine {
    public var config = KeyboardTrackingConfig()
    private var lastNote: UInt8 = 60
    private var lastVelocity: UInt8 = 127
    private var currentValue: Float = 0.0
    
    public init() {}
    
    /// Calculate tracking value for a given note
    public func calculateTrackingValue(note: UInt8, velocity: UInt8 = 127) -> Float {
        lastNote = note
        lastVelocity = velocity
        
        guard config.amount > 0.0 else { return 0.0 }
        
        let noteOffset = Float(note) - Float(config.keyCenter)
        let velocityFactor = 1.0 + (Float(velocity) / 127.0 - 1.0) * config.velocitySensitivity
        
        var trackingValue: Float
        
        switch config.trackingMode {
        case .linear:
            trackingValue = noteOffset / 12.0 // Octave-based tracking
        case .exponential:
            trackingValue = pow(2.0, noteOffset / 12.0) - 1.0
        case .custom:
            // Simple S-curve for custom mode
            let normalized = noteOffset / 24.0 // ±2 octaves
            trackingValue = tanh(normalized * 2.0)
        }
        
        currentValue = trackingValue * config.amount * velocityFactor
        return currentValue
    }
    
    /// Get the current tracking value
    public func getCurrentValue() -> Float {
        return currentValue
    }
    
    /// Reset the tracking state
    public func reset() {
        currentValue = 0.0
        lastNote = config.keyCenter
        lastVelocity = 127
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
