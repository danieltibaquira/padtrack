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
    
    // MARK: - Private Properties
    
    private var playbackTimer: Timer?
    private var currentBPM: Double = 120.0
    private var stepDuration: TimeInterval {
        return 60.0 / (currentBPM * 4) // 16th note duration
    }
    
    // MARK: - Initialization
    
    public init() {
        setupDefaultState()
        initializeFMToneParameters()
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
            updateDisplayText("PLAYING")
        } else {
            stopPlayback()
            updateDisplayText("PAUSED")
        }
    }
    
    public func stop() {
        isPlaying = false
        isRecording = false
        currentStep = -1
        stopPlayback()
        updateDisplayText("STOPPED")
    }
    
    public func rewind() {
        currentStep = -1
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
        updateDisplayText("STEP \(step + 1) \(activeSteps.contains(step) ? "ON" : "OFF")")
    }
    
    public func clearAllSteps() {
        activeSteps.removeAll()
        updateDisplayText("ALL STEPS CLEARED")
    }
    
    public func setAllSteps() {
        activeSteps = Set(0..<16)
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
            parameterLabels = ["ALGO", "RATIO C", "RATIO A", "RATIO B", "HARM", "DTUN", "FDBK", "MIX"]
            updateFMToneParameterValues(page: 1)
            
        case 2:
            // Page 2 - Modulator Levels & Envelopes: ATK, DEC, END, LEV for operators A and B
            parameterLabels = ["ATK A", "DEC A", "END A", "LEV A", "ATK B", "DEC B", "END B", "LEV B"]
            updateFMToneParameterValues(page: 2)
            
        case 3:
            // Page 3 - Envelope Behavior: delay, trig mode, phase reset controls
            parameterLabels = ["DELAY", "TRIG", "PHASE", "RES A", "RES B", "DTUN", "HARM", "KEY TRK"]
            updateFMToneParameterValues(page: 3)
            
        case 4:
            // Page 4 - Offsets & Key Tracking: fine-tuning for operator ratios and keyboard tracking
            parameterLabels = ["OFS A", "OFS B", "KEY TRK", "VEL SEN", "SCALE", "ROOT", "TUNE", "FINE"]
            updateFMToneParameterValues(page: 4)
            
        default:
            // Default to standard parameter labels for pages 5-8
            updateParameterLabelsForPage(page)
        }
    }
    
    private func updateFMToneParameterValues(page: Int) {
        switch page {
        case 1:
            parameterValues = [
                fmToneParameterValues["algorithm"]! / 4.0, // Scale 1-4 to 0-1
                fmToneParameterValues["operator4_ratio"]! / 32.0, // Carrier ratio
                fmToneParameterValues["operator1_ratio"]! / 32.0, // Operator A ratio
                fmToneParameterValues["operator2_ratio"]! / 32.0, // Operator B ratio
                fmToneParameterValues["harmony"]!,
                fmToneParameterValues["detune"]!,
                fmToneParameterValues["feedback"]!,
                fmToneParameterValues["mix"]!
            ]
            
        case 2:
            parameterValues = [
                fmToneParameterValues["attack"]!,
                fmToneParameterValues["decay"]!,
                fmToneParameterValues["end"]!,
                fmToneParameterValues["operator1_envelope_level"]!,
                fmToneParameterValues["attack"]!, // Operator B uses same envelope for now
                fmToneParameterValues["decay"]!,
                fmToneParameterValues["end"]!,
                fmToneParameterValues["operator2_envelope_level"]!
            ]
            
        case 3:
            parameterValues = [
                fmToneParameterValues["delay"]!,
                fmToneParameterValues["trig_mode"]!,
                fmToneParameterValues["phase_reset"]!,
                0.0, // Reserved for future use
                0.0, // Reserved for future use
                fmToneParameterValues["detune"]!,
                fmToneParameterValues["harmony"]!,
                fmToneParameterValues["key_tracking"]!
            ]
            
        case 4:
            parameterValues = [
                fmToneParameterValues["operator1_offset"]!,
                fmToneParameterValues["operator2_offset"]!,
                fmToneParameterValues["key_tracking"]!,
                0.5, // Velocity sensitivity placeholder
                0.0, // Scale placeholder
                0.0, // Root placeholder
                0.5, // Tune placeholder
                0.0  // Fine placeholder
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
