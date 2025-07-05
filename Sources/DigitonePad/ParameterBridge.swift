// ParameterBridge.swift
// DigitonePad - Parameter Bridge
//
// Bridge between UI parameter controls and audio engine parameters

import Foundation
import Combine
import VoiceModule
import AudioEngine

/// Bridge class that connects UI parameter changes to audio engine parameters
@MainActor
public class ParameterBridge: ObservableObject {
    
    // MARK: - Properties
    
    private var audioEngine: AudioEngineProtocol?
    private var voiceMachineManager: VoiceMachineManager?
    private var cancellables = Set<AnyCancellable>()
    
    // Current parameter values for each track
    private var trackParameters: [Int: [String: Double]] = [:]
    
    // Parameter update queue for thread safety
    private let parameterQueue = DispatchQueue(label: "parameter.bridge.queue", qos: .userInteractive)
    
    // MARK: - Initialization
    
    public init() {
        setupDefaultParameters()
    }
    
    public func setAudioEngine(_ audioEngine: AudioEngineProtocol) {
        self.audioEngine = audioEngine
    }
    
    public func setVoiceMachineManager(_ manager: VoiceMachineManager) {
        self.voiceMachineManager = manager
    }
    
    // MARK: - Parameter Updates
    
    /// Update a parameter for the currently selected track
    public func updateParameter(track: Int, parameterId: String, value: Double) {
        // Ensure value is in valid range
        let clampedValue = max(0.0, min(1.0, value))
        
        // Store parameter value
        if trackParameters[track] == nil {
            trackParameters[track] = [:]
        }
        trackParameters[track]?[parameterId] = clampedValue
        
        // Update audio engine parameter asynchronously
        parameterQueue.async { [weak self] in
            self?.updateAudioParameter(track: track, parameterId: parameterId, value: clampedValue)
        }
    }
    
    /// Update multiple parameters at once for better performance
    public func updateParameters(track: Int, parameters: [String: Double]) {
        for (parameterId, value) in parameters {
            updateParameter(track: track, parameterId: parameterId, value: value)
        }
    }
    
    /// Get current parameter value
    public func getParameterValue(track: Int, parameterId: String) -> Double {
        return trackParameters[track]?[parameterId] ?? 0.0
    }
    
    /// Update encoder value (0-7) with delta change
    public func updateEncoder(track: Int, encoder: Int, delta: Double) {
        guard encoder >= 0 && encoder < 8 else { return }
        
        // Map encoder to parameter based on current page/mode
        let parameterId = getParameterIdForEncoder(track: track, encoder: encoder)
        let currentValue = getParameterValue(track: track, parameterId: parameterId)
        let newValue = currentValue + delta
        
        updateParameter(track: track, parameterId: parameterId, value: newValue)
    }
    
    // MARK: - Voice Machine Integration
    
    /// Set voice machine type for a track
    public func setVoiceMachine(track: Int, type: VoiceMachineType) {
        voiceMachineManager?.setVoiceMachine(for: track, type: type)
        
        // Reset parameters to defaults for new voice machine
        resetParametersForTrack(track, voiceMachineType: type)
    }
    
    /// Get voice machine type for a track
    public func getVoiceMachineType(track: Int) -> VoiceMachineType? {
        return voiceMachineManager?.getVoiceMachineType(for: track)
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultParameters() {
        // Initialize default parameters for all tracks
        for track in 1...4 {
            trackParameters[track] = [
                "algorithm": 0.25,      // Algorithm 1 (0-1 maps to 1-4)
                "ratio": 0.25,          // Ratio 2.0 (0-1 maps to 0.5-32)
                "level": 1.0,           // Level 100%
                "attack": 0.1,          // Attack time
                "decay": 0.3,           // Decay time
                "sustain": 0.7,         // Sustain level
                "release": 0.5,         // Release time
                "cutoff": 0.8,          // Filter cutoff
                "resonance": 0.1,       // Filter resonance
                "pan": 0.5,             // Pan center
                "feedback": 0.0,        // No feedback
                "modulation": 0.5,      // Moderate modulation
                "harmony": 0.0,         // No harmony
                "detune": 0.5,          // Center detune
                "mix": 0.5,             // 50% mix
                "delay": 0.0            // No delay
            ]
        }
    }
    
    private func updateAudioParameter(track: Int, parameterId: String, value: Double) {
        guard let voiceMachine = voiceMachineManager?.getVoiceMachine(for: track) else {
            return
        }
        
        // Convert UI parameter to audio engine parameter based on voice machine type
        let audioValue = convertUIValueToAudioValue(parameterId: parameterId, uiValue: value, track: track)
        
        // Update voice machine parameter
        switch voiceMachine {
        case let fmToneVoice as FMToneVoiceMachine:
            updateFMToneParameter(fmToneVoice, parameterId: parameterId, value: audioValue)
        case let fmDrumVoice as FMDrumVoiceMachine:
            updateFMDrumParameter(fmDrumVoice, parameterId: parameterId, value: audioValue)
        case let wavetoneVoice as WavetoneVoiceMachine:
            updateWavetoneParameter(wavetoneVoice, parameterId: parameterId, value: audioValue)
        case let swarmerVoice as SwarmerVoiceMachine:
            updateSwarmerParameter(swarmerVoice, parameterId: parameterId, value: audioValue)
        default:
            break
        }
    }
    
    private func convertUIValueToAudioValue(parameterId: String, uiValue: Double, track: Int) -> Double {
        switch parameterId {
        case "algorithm":
            // Convert 0-1 to 1-4 for algorithm
            return 1.0 + (uiValue * 3.0)
        case "ratio":
            // Convert 0-1 to 0.5-32 for ratio (exponential)
            return 0.5 * pow(64.0, uiValue)
        case "cutoff":
            // Convert 0-1 to 20-20000 Hz (exponential)
            return 20.0 * pow(1000.0, uiValue)
        case "resonance":
            // Convert 0-1 to 0-0.99 for resonance
            return uiValue * 0.99
        case "attack", "decay", "release":
            // Convert 0-1 to 0.001-10 seconds (exponential)
            return 0.001 * pow(10000.0, uiValue)
        case "sustain", "level", "mix":
            // Linear 0-1 mapping
            return uiValue
        case "pan":
            // Convert 0-1 to -1 to 1 for pan
            return (uiValue * 2.0) - 1.0
        case "feedback":
            // Convert 0-1 to 0-0.95 for feedback
            return uiValue * 0.95
        case "detune":
            // Convert 0-1 to -50 to 50 cents
            return (uiValue * 100.0) - 50.0
        default:
            // Default linear mapping
            return uiValue
        }
    }
    
    private func updateFMToneParameter(_ voiceMachine: FMToneVoiceMachine, parameterId: String, value: Double) {
        // Update FM Tone voice machine parameters
        // This would call specific methods on the FM Tone voice machine
        print("Updating FM Tone parameter \(parameterId) to \(value)")
    }
    
    private func updateFMDrumParameter(_ voiceMachine: FMDrumVoiceMachine, parameterId: String, value: Double) {
        // Update FM Drum voice machine parameters
        print("Updating FM Drum parameter \(parameterId) to \(value)")
    }
    
    private func updateWavetoneParameter(_ voiceMachine: WavetoneVoiceMachine, parameterId: String, value: Double) {
        // Update Wavetone voice machine parameters
        print("Updating Wavetone parameter \(parameterId) to \(value)")
    }
    
    private func updateSwarmerParameter(_ voiceMachine: SwarmerVoiceMachine, parameterId: String, value: Double) {
        // Update Swarmer voice machine parameters
        print("Updating Swarmer parameter \(parameterId) to \(value)")
    }
    
    private func getParameterIdForEncoder(track: Int, encoder: Int) -> String {
        // Map encoder index to parameter ID based on voice machine type and current page
        let voiceMachineType = getVoiceMachineType(track: track) ?? .fmTone
        
        switch voiceMachineType {
        case .fmTone:
            return getFMToneParameterForEncoder(encoder)
        case .fmDrum:
            return getFMDrumParameterForEncoder(encoder)
        case .wavetone:
            return getWavetoneParameterForEncoder(encoder)
        case .swarmer:
            return getSwarmerParameterForEncoder(encoder)
        }
    }
    
    private func getFMToneParameterForEncoder(_ encoder: Int) -> String {
        let fmToneParameters = [
            "algorithm", "ratio", "level", "attack",
            "decay", "sustain", "release", "cutoff"
        ]
        return encoder < fmToneParameters.count ? fmToneParameters[encoder] : "level"
    }
    
    private func getFMDrumParameterForEncoder(_ encoder: Int) -> String {
        let fmDrumParameters = [
            "tune", "tone", "decay", "snap",
            "level", "pan", "send1", "send2"
        ]
        return encoder < fmDrumParameters.count ? fmDrumParameters[encoder] : "level"
    }
    
    private func getWavetoneParameterForEncoder(_ encoder: Int) -> String {
        let wavetoneParameters = [
            "wavetable", "position", "formant", "peak",
            "attack", "decay", "sustain", "release"
        ]
        return encoder < wavetoneParameters.count ? wavetoneParameters[encoder] : "level"
    }
    
    private func getSwarmerParameterForEncoder(_ encoder: Int) -> String {
        let swarmerParameters = [
            "voices", "spread", "drift", "chaos",
            "attack", "decay", "sustain", "release"
        ]
        return encoder < swarmerParameters.count ? swarmerParameters[encoder] : "level"
    }
    
    private func resetParametersForTrack(_ track: Int, voiceMachineType: VoiceMachineType) {
        // Reset parameters to defaults for the new voice machine type
        switch voiceMachineType {
        case .fmTone:
            trackParameters[track] = [
                "algorithm": 0.25, "ratio": 0.25, "level": 1.0, "attack": 0.1,
                "decay": 0.3, "sustain": 0.7, "release": 0.5, "cutoff": 0.8
            ]
        case .fmDrum:
            trackParameters[track] = [
                "tune": 0.5, "tone": 0.5, "decay": 0.5, "snap": 0.0,
                "level": 1.0, "pan": 0.5, "send1": 0.0, "send2": 0.0
            ]
        case .wavetone:
            trackParameters[track] = [
                "wavetable": 0.0, "position": 0.0, "formant": 0.5, "peak": 0.5,
                "attack": 0.1, "decay": 0.3, "sustain": 0.7, "release": 0.5
            ]
        case .swarmer:
            trackParameters[track] = [
                "voices": 0.5, "spread": 0.3, "drift": 0.2, "chaos": 0.1,
                "attack": 0.1, "decay": 0.3, "sustain": 0.7, "release": 0.5
            ]
        }
    }
}

// MARK: - Voice Machine Manager

/// Manages voice machines for each track
public class VoiceMachineManager: ObservableObject {
    
    private var audioEngine: AudioEngineProtocol?
    private var voiceMachines: [Int: VoiceMachineProtocol] = [:]
    private var voiceMachineTypes: [Int: VoiceMachineType] = [:]
    
    public init() {
        setupDefaultVoiceMachines()
    }
    
    public func setAudioEngine(_ audioEngine: AudioEngineProtocol) {
        self.audioEngine = audioEngine
    }
    
    public func setVoiceMachine(for track: Int, type: VoiceMachineType) {
        guard track >= 1 && track <= 4 else { return }
        
        voiceMachineTypes[track] = type
        
        // Create new voice machine instance
        switch type {
        case .fmTone:
            voiceMachines[track] = createFMToneVoiceMachine()
        case .fmDrum:
            voiceMachines[track] = createFMDrumVoiceMachine()
        case .wavetone:
            voiceMachines[track] = createWavetoneVoiceMachine()
        case .swarmer:
            voiceMachines[track] = createSwarmerVoiceMachine()
        }
    }
    
    public func getVoiceMachine(for track: Int) -> VoiceMachineProtocol? {
        return voiceMachines[track]
    }
    
    public func getVoiceMachineType(for track: Int) -> VoiceMachineType? {
        return voiceMachineTypes[track]
    }
    
    public func triggerVoice(track: Int, note: Int, velocity: Int) {
        voiceMachines[track]?.triggerNote(note, velocity: velocity)
    }
    
    public func releaseVoice(track: Int, note: Int) {
        voiceMachines[track]?.releaseNote(note)
    }
    
    private func setupDefaultVoiceMachines() {
        // Setup default voice machines for each track
        setVoiceMachine(for: 1, type: .fmTone)
        setVoiceMachine(for: 2, type: .fmDrum)
        setVoiceMachine(for: 3, type: .wavetone)
        setVoiceMachine(for: 4, type: .swarmer)
    }
    
    private func createFMToneVoiceMachine() -> VoiceMachineProtocol {
        // Create and configure FM Tone voice machine
        return MockVoiceMachine(type: .fmTone)
    }
    
    private func createFMDrumVoiceMachine() -> VoiceMachineProtocol {
        // Create and configure FM Drum voice machine
        return MockVoiceMachine(type: .fmDrum)
    }
    
    private func createWavetoneVoiceMachine() -> VoiceMachineProtocol {
        // Create and configure Wavetone voice machine
        return MockVoiceMachine(type: .wavetone)
    }
    
    private func createSwarmerVoiceMachine() -> VoiceMachineProtocol {
        // Create and configure Swarmer voice machine
        return MockVoiceMachine(type: .swarmer)
    }
}

// MARK: - Supporting Types

public enum VoiceMachineType: String, CaseIterable {
    case fmTone = "FM TONE"
    case fmDrum = "FM DRUM"
    case wavetone = "WAVETONE"
    case swarmer = "SWARMER"
}

public protocol VoiceMachineProtocol {
    func triggerNote(_ note: Int, velocity: Int)
    func releaseNote(_ note: Int)
}

public protocol AudioEngineProtocol {
    var isRunning: Bool { get }
    var isInitialized: Bool { get }
    func initialize() throws
    func start() throws
    func stop() throws
}

// MARK: - Mock Implementation for Testing

private class MockVoiceMachine: VoiceMachineProtocol {
    let type: VoiceMachineType
    
    init(type: VoiceMachineType) {
        self.type = type
    }
    
    func triggerNote(_ note: Int, velocity: Int) {
        print("Mock \(type.rawValue) triggered note \(note) with velocity \(velocity)")
    }
    
    func releaseNote(_ note: Int) {
        print("Mock \(type.rawValue) released note \(note)")
    }
}