// MainLayoutState.swift
// DigitonePad - Main Application Layout State
//
// State management for the main application layout

import SwiftUI
import Combine

/// Main layout state management
@MainActor
public class MainLayoutState: ObservableObject {
    // MARK: - Published Properties
    
    @Published public var isPlaying: Bool = false
    @Published public var isRecording: Bool = false
    @Published public var selectedTrack: Int = 1
    @Published public var currentStep: Int = -1
    @Published public var activeSteps: Set<Int> = []
    @Published public var currentMode: SequencerMode = .pattern
    @Published public var selectedFunction: FunctionButton = .grid
    @Published public var currentPage: Int = 1
    @Published public var displayText: String = "DIGITONE PAD"
    @Published public var isLandscape: Bool = false
    
    // Parameter values for the 8 encoders
    @Published public var parameterValues: [Double] = Array(repeating: 0.5, count: 8)
    @Published public var parameterLabels: [String] = [
        "CUTOFF", "RESO", "ATTACK", "DECAY",
        "SUSTAIN", "RELEASE", "LEVEL", "PAN"
    ]
    
    // FM TONE specific parameters
    @Published public var isFMToneMode: Bool = false
    @Published public var fmToneParameterValues: [String: Double] = [:]
    
    // FM Parameter Bridge for real-time audio integration
    public private(set) var fmParameterBridge: FMParameterBridge?
    
    // MARK: - Private Properties
    
    private var playbackTimer: Timer?
    private var currentBPM: Double = 120.0
    private var stepDuration: TimeInterval {
        return 60.0 / (currentBPM * 4) // 16th note duration
    }
    
    // Parameter bridge for audio integration
    public private(set) var parameterBridge = ParameterBridge()
    public private(set) var voiceMachineManager = VoiceMachineManager()
    public private(set) var sequencerBridge = SequencerBridge()
    
    // MARK: - Initialization
    
    public init() {
        setupDefaultState()
        initializeFMToneParameters()
        setupFMParameterBridge()
        
        // Connect parameter bridge and voice machine manager
        parameterBridge.setVoiceMachineManager(voiceMachineManager)
        sequencerBridge.setVoiceMachineManager(voiceMachineManager)
    }
    
    // MARK: - FM TONE Mode Management
    
    public func setFMToneMode(_ enabled: Bool) {
        isFMToneMode = enabled
        if enabled {
            updateFMToneParameterLabelsForPage(currentPage)
            updateDisplayText("FM TONE MODE")
        } else {
            updateParameterLabelsForFunction(selectedFunction)
            updateDisplayText("STANDARD MODE")
        }
    }
    
    public func updateFMToneParameter(key: String, value: Double) {
        fmToneParameterValues[key] = value
        
        // Update parameter bridge for real-time audio integration
        if let parameterID = mapStringToParameterID(key) {
            fmParameterBridge?.updateParameter(parameterID, value: value)
        }
        
        // Trigger UI update
        objectWillChange.send()
    }
    
    public func getFMToneParameterValue(key: String) -> Double {
        return fmToneParameterValues[key] ?? 0.0
    }
    
    // MARK: - Transport Controls
    
    public func togglePlayback() {
        isPlaying.toggle()
        
        if isPlaying {
            startPlayback()
            sequencerBridge.start()
            updateDisplayText("PLAYING")
        } else {
            stopPlayback()
            sequencerBridge.pause()
            updateDisplayText("PAUSED")
        }
    }
    
    public func stop() {
        isPlaying = false
        isRecording = false
        currentStep = -1
        stopPlayback()
        sequencerBridge.stop()
        updateDisplayText("STOPPED")
    }
    
    public func rewind() {
        currentStep = -1
        sequencerBridge.stop()
        updateDisplayText("REWOUND")
    }
    
    public func toggleRecording() {
        isRecording.toggle()
        updateDisplayText(isRecording ? "RECORDING" : "READY")
    }
    
    // MARK: - Step Management
    
    public func toggleStep(_ step: Int) {
        if activeSteps.contains(step) {
            activeSteps.remove(step)
        } else {
            activeSteps.insert(step)
        }
        
        // Update sequencer bridge
        sequencerBridge.toggleStep(step, track: selectedTrack)
        
        updateDisplayText("STEP \(step + 1) \(activeSteps.contains(step) ? "ON" : "OFF")")
    }
    
    public func clearAllSteps() {
        activeSteps.removeAll()
        sequencerBridge.clearPattern(for: selectedTrack)
        updateDisplayText("ALL STEPS CLEARED")
    }
    
    public func setAllSteps() {
        activeSteps = Set(0..<16)
        sequencerBridge.fillPattern(for: selectedTrack)
        updateDisplayText("ALL STEPS SET")
    }
    
    // MARK: - Track Management
    
    public func selectTrack(_ track: Int) {
        guard track >= 1 && track <= 4 else { return }
        selectedTrack = track
        updateDisplayText("TRACK \(track)")
        
        if isFMToneMode {
            updateFMToneParameterLabelsForPage(currentPage)
        } else {
            updateParameterLabelsForTrack(track)
        }
    }
    
    // MARK: - Mode Management
    
    public func setMode(_ mode: SequencerMode) {
        currentMode = mode
        updateDisplayText(mode.displayName)
        updateParameterLabelsForMode(mode)
    }
    
    // MARK: - Function Management
    
    public func selectFunction(_ function: FunctionButton) {
        selectedFunction = function
        updateDisplayText(function.displayName)
        
        if isFMToneMode {
            updateFMToneParameterLabelsForPage(currentPage)
        } else {
            updateParameterLabelsForFunction(function)
        }
    }
    
    // MARK: - Page Management
    
    public func nextPage() {
        currentPage = min(currentPage + 1, 8)
        updateDisplayText("PAGE \(currentPage)")
        
        if isFMToneMode {
            updateFMToneParameterLabelsForPage(currentPage)
        } else {
            updateParameterLabelsForPage(currentPage)
        }
    }
    
    public func previousPage() {
        currentPage = max(currentPage - 1, 1)
        updateDisplayText("PAGE \(currentPage)")
        
        if isFMToneMode {
            updateFMToneParameterLabelsForPage(currentPage)
        } else {
            updateParameterLabelsForPage(currentPage)
        }
    }

    public func setPage(_ page: Int) {
        guard page >= 1 && page <= 8 else { return }
        currentPage = page
        updateDisplayText("PAGE \(currentPage)")
        
        if isFMToneMode {
            updateFMToneParameterLabelsForPage(currentPage)
        } else {
            updateParameterLabelsForPage(currentPage)
        }
    }
    
    // MARK: - Orientation Management
    
    public func updateOrientation(isLandscape: Bool) {
        self.isLandscape = isLandscape
    }
    
    // MARK: - Parameter Control Integration
    
    /// Update parameter encoder value
    public func updateEncoder(_ encoder: Int, delta: Double) {
        guard encoder >= 0 && encoder < 8 else { return }
        
        // Update local parameter value
        parameterValues[encoder] = max(0.0, min(1.0, parameterValues[encoder] + delta))
        
        // Update audio parameter through bridge
        parameterBridge.updateEncoder(track: selectedTrack, encoder: encoder, delta: delta)
        
        // Update display
        let parameterName = parameterLabels[encoder]
        let parameterValue = Int(parameterValues[encoder] * 100)
        updateDisplayText("\(parameterName): \(parameterValue)%")
    }
    
    /// Set voice machine type for current track
    public func setVoiceMachineType(_ type: VoiceMachineType) {
        voiceMachineManager.setVoiceMachine(for: selectedTrack, type: type)
        updateDisplayText("TRACK \(selectedTrack): \(type.rawValue)")
    }
    
    /// Get current voice machine type for selected track
    public func getCurrentVoiceMachineType() -> VoiceMachineType? {
        return voiceMachineManager.getVoiceMachineType(for: selectedTrack)
    }
    
    /// Trigger note for current track
    public func triggerNote(_ note: Int, velocity: Int = 100) {
        voiceMachineManager.triggerVoice(track: selectedTrack, note: note, velocity: velocity)
    }
    
    /// Release note for current track
    public func releaseNote(_ note: Int) {
        voiceMachineManager.releaseVoice(track: selectedTrack, note: note)
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultState() {
        selectedTrack = 1
        currentMode = .pattern
        selectedFunction = .grid
        currentPage = 1
        updateDisplayText("DIGITONE PAD READY")
        
        // Set some default active steps for demo
        activeSteps = [0, 4, 8, 12]
    }
    
    private func initializeFMToneParameters() {
        // Initialize FM TONE parameter values
        fmToneParameterValues = [
            "algorithm": 1.0,
            "operator1_ratio": 1.0,
            "operator2_ratio": 2.0,
            "operator3_ratio": 3.0,
            "operator4_ratio": 4.0,
            "operator1_level": 1.0,
            "operator2_level": 0.8,
            "operator3_level": 0.6,
            "operator4_level": 0.4,
            "modulation_index": 2.0,
            "feedback": 0.0,
            "harmony": 0.0,
            "detune": 0.0,
            "mix": 0.5,
            "attack": 0.1,
            "decay": 0.3,
            "end": 0.5,
            "operator1_envelope_level": 1.0,
            "operator2_envelope_level": 0.8,
            "delay": 0.0,
            "trig_mode": 0.0,
            "phase_reset": 0.0,
            "operator1_offset": 0.0,
            "operator2_offset": 0.0,
            "key_tracking": 0.5
        ]
    }
    
    private func updateFMToneParameterLabelsForPage(_ page: Int) {
        switch page {
        case 1:
            // Page 1 - Core FM: ALGO, RATIO C/A/B, HARM, DTUN, FDBK, MIX
            // Matches Elektron Digitone hardware specification exactly
            parameterLabels = ["ALGO", "RATIO C", "RATIO A", "RATIO B", "HARM", "DTUN", "FDBK", "MIX"]
            updateFMToneParameterValues(page: 1)
            
        case 2:
            // Page 2 - Modulator Levels & Envelopes: ATK, DEC, END, LEV for operators A and B
            // Provides envelope control for both modulator operators
            parameterLabels = ["ATK A", "DEC A", "END A", "LEV A", "ATK B", "DEC B", "END B", "LEV B"]
            updateFMToneParameterValues(page: 2)
            
        case 3:
            // Page 3 - Envelope Behavior: delay, trig mode, phase reset controls
            // Advanced envelope and trigger controls following Digitone specification
            parameterLabels = ["DELAY", "TRIG", "PHASE", "RES A", "RES B", "DTUN", "HARM", "KEY TRK"]
            updateFMToneParameterValues(page: 3)
            
        case 4:
            // Page 4 - Offsets & Key Tracking: fine-tuning for operator ratios and keyboard tracking
            // Precise control over tuning, scaling, and keyboard response
            parameterLabels = ["OFS A", "OFS B", "KEY TRK", "VEL SEN", "SCALE", "ROOT", "TUNE", "FINE"]
            updateFMToneParameterValues(page: 4)
            
        default:
            // Default to standard parameter labels for pages 5-8 (future expansion)
            updateParameterLabelsForPage(page)
        }
    }
    
    private func updateFMToneParameterValues(page: Int) {
        switch page {
        case 1:
            // Page 1 - Core FM Parameters (normalized to 0.0-1.0 for UI)
            parameterValues = [
                (fmToneParameterValues["algorithm"] ?? 1.0) / 8.0,           // ALGO: 1-8 -> 0.0-1.0
                (fmToneParameterValues["operator4_ratio"] ?? 1.0) / 32.0,    // RATIO C: 0.5-32.0 -> 0.0-1.0
                (fmToneParameterValues["operator1_ratio"] ?? 1.0) / 32.0,    // RATIO A: 0.5-32.0 -> 0.0-1.0
                (fmToneParameterValues["operator2_ratio"] ?? 1.0) / 32.0,    // RATIO B: 0.5-32.0 -> 0.0-1.0
                fmToneParameterValues["harmony"] ?? 0.0,                     // HARM: 0.0-1.0
                (fmToneParameterValues["detune"] ?? 0.0 + 64.0) / 128.0,     // DTUN: -64 to +63 -> 0.0-1.0
                fmToneParameterValues["feedback"] ?? 0.0,                    // FDBK: 0.0-1.0
                fmToneParameterValues["mix"] ?? 0.5                          // MIX: 0.0-1.0
            ]
            
        case 2:
            // Page 2 - Modulator Levels & Envelopes (normalized)
            parameterValues = [
                fmToneParameterValues["attack"] ?? 0.1,                      // ATK A: 0.0-1.0
                fmToneParameterValues["decay"] ?? 0.3,                       // DEC A: 0.0-1.0
                fmToneParameterValues["end"] ?? 0.5,                         // END A: 0.0-1.0
                fmToneParameterValues["operator1_envelope_level"] ?? 1.0,    // LEV A: 0.0-1.0
                fmToneParameterValues["attack"] ?? 0.1,                      // ATK B: 0.0-1.0 (can be independent)
                fmToneParameterValues["decay"] ?? 0.3,                       // DEC B: 0.0-1.0 (can be independent)
                fmToneParameterValues["end"] ?? 0.5,                         // END B: 0.0-1.0 (can be independent)
                fmToneParameterValues["operator2_envelope_level"] ?? 0.8     // LEV B: 0.0-1.0
            ]
            
        case 3:
            // Page 3 - Envelope Behavior Controls (normalized)
            parameterValues = [
                fmToneParameterValues["delay"] ?? 0.0,                       // DELAY: 0.0-1.0
                fmToneParameterValues["trig_mode"] ?? 0.0,                    // TRIG: 0.0-1.0 (discrete)
                fmToneParameterValues["phase_reset"] ?? 0.0,                 // PHASE: 0.0-1.0 (discrete)
                0.0,                                                         // RES A: reserved for future
                0.0,                                                         // RES B: reserved for future
                (fmToneParameterValues["detune"] ?? 0.0 + 64.0) / 128.0,     // DTUN: -64 to +63 -> 0.0-1.0
                fmToneParameterValues["harmony"] ?? 0.0,                     // HARM: 0.0-1.0
                fmToneParameterValues["key_tracking"] ?? 0.5                 // KEY TRK: 0.0-1.0
            ]
            
        case 4:
            // Page 4 - Offsets & Key Tracking (normalized)
            parameterValues = [
                (fmToneParameterValues["operator1_offset"] ?? 0.0 + 100.0) / 200.0,  // OFS A: -100 to +100 -> 0.0-1.0
                (fmToneParameterValues["operator2_offset"] ?? 0.0 + 100.0) / 200.0,  // OFS B: -100 to +100 -> 0.0-1.0
                fmToneParameterValues["key_tracking"] ?? 0.5,                        // KEY TRK: 0.0-1.0
                fmToneParameterValues["velocity_sensitivity"] ?? 0.5,                // VEL SEN: 0.0-1.0
                (fmToneParameterValues["scale"] ?? 0.0) / 11.0,                      // SCALE: 0-11 -> 0.0-1.0
                (fmToneParameterValues["root"] ?? 0.0) / 11.0,                       // ROOT: 0-11 -> 0.0-1.0
                (fmToneParameterValues["tune"] ?? 0.0 + 24.0) / 48.0,                // TUNE: -24 to +24 -> 0.0-1.0
                (fmToneParameterValues["fine"] ?? 0.0 + 100.0) / 200.0               // FINE: -100 to +100 -> 0.0-1.0
            ]
            
        default:
            break
        }
    }
    
    private func startPlayback() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceStep()
            }
        }
    }
    
    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func advanceStep() {
        currentStep = (currentStep + 1) % 16
        
        // Update display with current step info
        if activeSteps.contains(currentStep) {
            updateDisplayText("STEP \(currentStep + 1) ACTIVE")
        }
    }
    
    private func updateDisplayText(_ text: String) {
        displayText = text
        
        // Reset to default after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if self?.displayText == text {
                self?.displayText = "DIGITONE PAD"
            }
        }
    }
    
    private func updateParameterLabelsForTrack(_ track: Int) {
        switch track {
        case 1:
            parameterLabels = ["CUTOFF", "RESO", "ATTACK", "DECAY", "SUSTAIN", "RELEASE", "LEVEL", "PAN"]
        case 2:
            parameterLabels = ["RATIO", "LEVEL", "ATTACK", "DECAY", "SUSTAIN", "RELEASE", "DETUNE", "FEEDBACK"]
        case 3:
            parameterLabels = ["DELAY", "FEEDBACK", "HPF", "LPF", "REVERB", "SIZE", "DAMP", "MIX"]
        case 4:
            parameterLabels = ["COMP", "THRESH", "RATIO", "ATTACK", "RELEASE", "GAIN", "DRIVE", "OUTPUT"]
        default:
            break
        }
    }
    
    private func updateParameterLabelsForMode(_ mode: SequencerMode) {
        switch mode {
        case .pattern:
            parameterLabels = ["LENGTH", "SCALE", "ROOT", "SWING", "GATE", "VELOCITY", "CHANCE", "OFFSET"]
        case .song:
            parameterLabels = ["TEMPO", "CHAIN", "MUTE", "SOLO", "COPY", "PASTE", "CLEAR", "FILL"]
        case .live:
            parameterLabels = ["SCENE", "MORPH", "CROSSFADE", "FILTER", "DELAY", "REVERB", "COMP", "MASTER"]
        }
    }
    
    private func updateParameterLabelsForFunction(_ function: FunctionButton) {
        switch function {
        case .grid:
            parameterLabels = ["STEP", "VELOCITY", "GATE", "MICRO", "SWING", "CHANCE", "CONDITION", "RETRIG"]
        case .parameter:
            parameterLabels = ["VALUE", "MIN", "MAX", "CURVE", "SMOOTH", "QUANTIZE", "SCALE", "OFFSET"]
        case .mixer:
            parameterLabels = ["LEVEL", "PAN", "SEND A", "SEND B", "HPF", "LPF", "COMP", "EQ"]
        }
    }
    
    private func updateParameterLabelsForPage(_ page: Int) {
        // Update parameter labels based on current page
        // This would typically load different parameter sets
        updateDisplayText("PAGE \(page) LOADED")
    }
    
    // MARK: - FM Parameter Bridge Setup
    
    private func setupFMParameterBridge() {
        // Initialize the FM parameter bridge for real-time audio integration
        fmParameterBridge = FMParameterBridge()
        
        // Setup performance monitoring callback
        fmParameterBridge?.performanceCallback = { [weak self] updateTime in
            if updateTime > 0.001 {
                print("Warning: Parameter update took \(updateTime * 1000)ms")
            }
        }
    }
    
    // MARK: - Parameter ID Mapping
    
    private func mapStringToParameterID(_ key: String) -> FMParameterID? {
        switch key {
        case "algorithm": return .algorithm
        case "operator4_ratio": return .ratioC
        case "operator1_ratio": return .ratioA
        case "operator2_ratio": return .ratioB
        case "harmony": return .harmony
        case "detune": return .detune
        case "feedback": return .feedback
        case "mix": return .mix
        case "attack": return .attackA
        case "decay": return .decayA
        case "end": return .endA
        case "operator1_envelope_level": return .levelA
        case "operator2_envelope_level": return .levelB
        case "delay": return .delay
        case "trig_mode": return .trigMode
        case "phase_reset": return .phaseReset
        case "key_tracking": return .keyTracking
        case "operator1_offset": return .offsetA
        case "operator2_offset": return .offsetB
        case "velocity_sensitivity": return .velocitySensitivity
        case "scale": return .scale
        case "root": return .root
        case "tune": return .tune
        case "fine": return .fine
        default: return nil
        }
    }
    
    // MARK: - Enhanced Parameter Methods
    
    /// Update a specific encoder value on the current FM page
    public func updateEncoderValue(_ encoderIndex: Int, value: Double) {
        guard isFMToneMode && encoderIndex < 8 else { return }
        
        // Update the parameter value in the UI
        parameterValues[encoderIndex] = value
        
        // Map encoder index to parameter based on current page
        if let parameterID = mapEncoderToParameterID(page: currentPage, encoder: encoderIndex) {
            fmParameterBridge?.updateParameter(parameterID, value: value)
            
            // Also update the internal parameter storage
            if let parameterKey = mapParameterIDToString(parameterID) {
                updateFMToneParameter(key: parameterKey, value: value)
            }
        }
    }
    
    private func mapEncoderToParameterID(page: Int, encoder: Int) -> FMParameterID? {
        switch (page, encoder) {
        // Page 1 - Core FM
        case (1, 0): return .algorithm
        case (1, 1): return .ratioC
        case (1, 2): return .ratioA
        case (1, 3): return .ratioB
        case (1, 4): return .harmony
        case (1, 5): return .detune
        case (1, 6): return .feedback
        case (1, 7): return .mix
        
        // Page 2 - Envelopes
        case (2, 0): return .attackA
        case (2, 1): return .decayA
        case (2, 2): return .endA
        case (2, 3): return .levelA
        case (2, 4): return .attackB
        case (2, 5): return .decayB
        case (2, 6): return .endB
        case (2, 7): return .levelB
        
        // Page 3 - Envelope Behavior
        case (3, 0): return .delay
        case (3, 1): return .trigMode
        case (3, 2): return .phaseReset
        case (3, 3): return .reserved1
        case (3, 4): return .reserved2
        case (3, 5): return .detune
        case (3, 6): return .harmony
        case (3, 7): return .keyTracking
        
        // Page 4 - Offsets & Key Tracking
        case (4, 0): return .offsetA
        case (4, 1): return .offsetB
        case (4, 2): return .keyTracking
        case (4, 3): return .velocitySensitivity
        case (4, 4): return .scale
        case (4, 5): return .root
        case (4, 6): return .tune
        case (4, 7): return .fine
        
        default: return nil
        }
    }
    
    private func mapParameterIDToString(_ parameterID: FMParameterID) -> String? {
        switch parameterID {
        case .algorithm: return "algorithm"
        case .ratioC: return "operator4_ratio"
        case .ratioA: return "operator1_ratio"
        case .ratioB: return "operator2_ratio"
        case .harmony: return "harmony"
        case .detune: return "detune"
        case .feedback: return "feedback"
        case .mix: return "mix"
        case .attackA: return "attack"
        case .decayA: return "decay"
        case .endA: return "end"
        case .levelA: return "operator1_envelope_level"
        case .levelB: return "operator2_envelope_level"
        case .delay: return "delay"
        case .trigMode: return "trig_mode"
        case .phaseReset: return "phase_reset"
        case .keyTracking: return "key_tracking"
        case .offsetA: return "operator1_offset"
        case .offsetB: return "operator2_offset"
        case .velocitySensitivity: return "velocity_sensitivity"
        case .scale: return "scale"
        case .root: return "root"
        case .tune: return "tune"
        case .fine: return "fine"
        default: return nil
        }
    }
}

// MARK: - Supporting Enums

/// Sequencer mode enumeration
public enum SequencerMode: String, CaseIterable {
    case pattern = "PATTERN"
    case song = "SONG"
    case live = "LIVE"
    
    public var displayName: String {
        return rawValue
    }
}

/// Function button enumeration
public enum FunctionButton: String, CaseIterable {
    case grid = "GRID"
    case parameter = "PARAM"
    case mixer = "MIXER"
    
    public var title: String {
        return rawValue
    }
    
    public var displayName: String {
        switch self {
        case .grid:
            return "GRID MODE"
        case .parameter:
            return "PARAMETER MODE"
        case .mixer:
            return "MIXER MODE"
        }
    }
}
