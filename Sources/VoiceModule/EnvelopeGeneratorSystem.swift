// EnvelopeGeneratorSystem.swift
// DigitonePad - VoiceModule
//
// Comprehensive envelope generator system for WAVETONE and other voice machines
// Provides flexible ADSR envelopes with advanced features

import Foundation
import Accelerate
import MachineProtocols
import AudioEngine

// MARK: - Envelope Configuration Types

/// Envelope curve shapes for natural-sounding envelopes
public enum EnvelopeCurveType: String, CaseIterable, Codable {
    case linear = "linear"
    case exponential = "exponential"
    case logarithmic = "logarithmic"
    case sine = "sine"
    case cosine = "cosine"
    case power = "power"
    case inverse = "inverse"
    
    public var description: String {
        switch self {
        case .linear: return "Linear"
        case .exponential: return "Exponential"
        case .logarithmic: return "Logarithmic"
        case .sine: return "Sine"
        case .cosine: return "Cosine"
        case .power: return "Power"
        case .inverse: return "Inverse"
        }
    }
}

/// Envelope stage types
public enum EnvelopeStage: String, CaseIterable, Codable {
    case idle = "idle"
    case delay = "delay"
    case attack = "attack"
    case decay = "decay"
    case sustain = "sustain"
    case release = "release"
    
    public var description: String {
        switch self {
        case .idle: return "Idle"
        case .delay: return "Delay"
        case .attack: return "Attack"
        case .decay: return "Decay"
        case .sustain: return "Sustain"
        case .release: return "Release"
        }
    }
}

/// Envelope trigger modes
public enum EnvelopeTriggerMode: String, CaseIterable, Codable {
    case retrigger = "retrigger"    // Always restart from beginning
    case legato = "legato"          // Continue from current level
    case reset = "reset"            // Reset to zero then start
    
    public var description: String {
        switch self {
        case .retrigger: return "Retrigger"
        case .legato: return "Legato"
        case .reset: return "Reset"
        }
    }
}

// MARK: - Envelope Stage Configuration

/// Configuration for individual envelope stages
public struct EnvelopeGeneratorStageConfig: Codable {
    public var time: Float          // Stage duration in seconds
    public var level: Float         // Target level (0.0 to 1.0)
    public var curve: EnvelopeCurveType  // Curve shape
    public var curvePower: Float    // Power for power curve (1.0 to 10.0)
    
    public init(time: Float = 0.1, level: Float = 1.0, curve: EnvelopeCurveType = .exponential, curvePower: Float = 2.0) {
        self.time = max(0.0, time)
        self.level = max(0.0, min(1.0, level))
        self.curve = curve
        self.curvePower = max(0.1, min(10.0, curvePower))
    }
}

// MARK: - Envelope Generator Configuration

/// Complete configuration for envelope generator
public struct EnvelopeGeneratorConfig: Codable {
    public var delay: EnvelopeGeneratorStageConfig
    public var attack: EnvelopeGeneratorStageConfig
    public var decay: EnvelopeGeneratorStageConfig
    public var sustain: EnvelopeGeneratorStageConfig
    public var release: EnvelopeGeneratorStageConfig
    
    // Advanced features
    public var velocitySensitivity: Float = 0.8    // 0.0 to 1.0
    public var velocityCurve: EnvelopeCurveType = .exponential
    public var keyTracking: Float = 0.0            // -1.0 to 1.0 (affects time scaling)
    public var triggerMode: EnvelopeTriggerMode = .retrigger
    public var loopEnabled: Bool = false
    public var loopStart: EnvelopeStage = .decay
    public var loopEnd: EnvelopeStage = .sustain
    
    public init() {
        self.delay = EnvelopeGeneratorStageConfig(time: 0.0, level: 0.0, curve: .linear)
        self.attack = EnvelopeGeneratorStageConfig(time: 0.01, level: 1.0, curve: .exponential)
        self.decay = EnvelopeGeneratorStageConfig(time: 0.1, level: 0.7, curve: .exponential)
        self.sustain = EnvelopeGeneratorStageConfig(time: 0.0, level: 0.7, curve: .linear)
        self.release = EnvelopeGeneratorStageConfig(time: 0.3, level: 0.0, curve: .exponential)
    }
    
    /// Create preset configurations
    public static func organPreset() -> EnvelopeGeneratorConfig {
        var config = EnvelopeGeneratorConfig()
        config.attack = EnvelopeGeneratorStageConfig(time: 0.02, level: 1.0, curve: .sine)
        config.decay = EnvelopeGeneratorStageConfig(time: 0.1, level: 0.9, curve: .exponential)
        config.sustain = EnvelopeGeneratorStageConfig(time: 0.0, level: 0.9, curve: .linear)
        config.release = EnvelopeGeneratorStageConfig(time: 0.8, level: 0.0, curve: .exponential)
        config.velocitySensitivity = 0.6
        return config
    }
    
    public static func pluckedPreset() -> EnvelopeGeneratorConfig {
        var config = EnvelopeGeneratorConfig()
        config.attack = EnvelopeGeneratorStageConfig(time: 0.001, level: 1.0, curve: .exponential)
        config.decay = EnvelopeGeneratorStageConfig(time: 0.5, level: 0.0, curve: .exponential)
        config.sustain = EnvelopeGeneratorStageConfig(time: 0.0, level: 0.0, curve: .linear)
        config.release = EnvelopeGeneratorStageConfig(time: 0.1, level: 0.0, curve: .exponential)
        config.velocitySensitivity = 0.9
        return config
    }
    
    public static func padPreset() -> EnvelopeGeneratorConfig {
        var config = EnvelopeGeneratorConfig()
        config.attack = EnvelopeGeneratorStageConfig(time: 0.5, level: 1.0, curve: .sine)
        config.decay = EnvelopeGeneratorStageConfig(time: 1.0, level: 0.8, curve: .logarithmic)
        config.sustain = EnvelopeGeneratorStageConfig(time: 0.0, level: 0.8, curve: .linear)
        config.release = EnvelopeGeneratorStageConfig(time: 2.0, level: 0.0, curve: .exponential)
        config.velocitySensitivity = 0.5
        return config
    }
}

// MARK: - Advanced Envelope Generator

/// High-performance envelope generator with advanced features
public final class EnvelopeGenerator: @unchecked Sendable {
    
    // MARK: - Configuration
    
    public var config: EnvelopeGeneratorConfig {
        didSet {
            updateInternalState()
        }
    }
    
    // MARK: - State
    
    private var currentStage: EnvelopeStage = .idle
    private var currentLevel: Float = 0.0
    
    /// Public accessor for current stage
    public var currentPhase: EnvelopeStage {
        return currentStage
    }
    
    /// Public accessor for current level (read-only)
    public var level: Float {
        return currentLevel
    }
    private var targetLevel: Float = 0.0
    private var stageProgress: Float = 0.0
    private var stageRate: Float = 0.0
    
    // Note state
    private var velocity: Float = 1.0
    private var noteNumber: Int = 60
    private var isNoteOn: Bool = false
    
    // Loop state
    private var loopCount: Int = 0
    private var maxLoops: Int = -1  // -1 = infinite
    
    // Performance optimization
    private let sampleRate: Double
    private var sampleTime: Float
    
    // MARK: - Initialization
    
    public init(config: EnvelopeGeneratorConfig = EnvelopeGeneratorConfig(), sampleRate: Double = 44100.0) {
        self.config = config
        self.sampleRate = sampleRate
        self.sampleTime = Float(1.0 / sampleRate)
        updateInternalState()
    }
    
    // MARK: - Public Interface
    
    /// Trigger envelope with note on
    public func noteOn(velocity: Float, noteNumber: Int = 60) {
        self.velocity = max(0.0, min(1.0, velocity))
        self.noteNumber = noteNumber
        self.isNoteOn = true
        self.loopCount = 0
        
        // Apply trigger mode
        switch config.triggerMode {
        case .retrigger:
            currentLevel = 0.0
            currentStage = config.delay.time > 0.0 ? .delay : .attack
            
        case .legato:
            // Continue from current level, but restart stage
            currentStage = config.delay.time > 0.0 ? .delay : .attack
            
        case .reset:
            currentLevel = 0.0
            currentStage = .idle
            // Will transition to delay/attack on next sample
        }
        
        stageProgress = 0.0
        updateStageParameters()
    }
    
    /// Release envelope with note off
    public func noteOff() {
        self.isNoteOn = false
        
        // Transition to release stage
        if currentStage != .release {
            currentStage = .release
            stageProgress = 0.0
            updateStageParameters()
        }
    }
    
    /// Process a single sample and return envelope value
    public func processSample() -> Float {
        // Handle idle state
        if currentStage == .idle {
            if config.triggerMode == .reset && isNoteOn {
                currentStage = config.delay.time > 0.0 ? .delay : .attack
                updateStageParameters()
            } else {
                return 0.0
            }
        }
        
        // Update envelope level
        updateEnvelopeLevel()
        
        // Check for stage completion
        if stageProgress >= 1.0 {
            advanceToNextStage()
        }
        
        return currentLevel
    }
    
    /// Process a block of samples for efficiency
    public func processBlock(output: inout [Float], blockSize: Int) {
        for i in 0..<min(blockSize, output.count) {
            output[i] = processSample()
        }
    }
    
    /// Check if envelope is active
    public var isActive: Bool {
        return currentStage != .idle || currentLevel > 0.001
    }
    
    /// Get current envelope stage
    public var stage: EnvelopeStage {
        return currentStage
    }
    
    /// Get current envelope level
    public var level: Float {
        return currentLevel
    }
    
    /// Reset envelope to idle state
    public func reset() {
        currentStage = .idle
        currentLevel = 0.0
        stageProgress = 0.0
        isNoteOn = false
        loopCount = 0
    }
    
    // MARK: - Private Implementation
    
    private func updateInternalState() {
        sampleTime = Float(1.0 / sampleRate)
        if currentStage != .idle {
            updateStageParameters()
        }
    }
    
    private func updateStageParameters() {
        let stageConfig = getStageConfig(currentStage)
        targetLevel = stageConfig.level
        
        // Apply velocity sensitivity
        if currentStage == .attack || currentStage == .decay {
            let velocityScale = applyCurve(velocity, curve: config.velocityCurve)
            let sensitivity = config.velocitySensitivity
            let velocityFactor = 1.0 - sensitivity + (sensitivity * velocityScale)
            targetLevel *= velocityFactor
        }
        
        // Calculate stage rate with key tracking
        var stageTime = stageConfig.time
        if config.keyTracking != 0.0 {
            let keyFactor = pow(2.0, Float(noteNumber - 60) / 12.0 * config.keyTracking)
            stageTime /= keyFactor
        }
        
        stageRate = stageTime > 0.0 ? (sampleTime / stageTime) : 1.0
    }
    
    private func updateEnvelopeLevel() {
        if currentStage == .sustain {
            // Sustain stage - hold level
            currentLevel = targetLevel
            return
        }
        
        // Calculate progress through current stage
        stageProgress += stageRate
        stageProgress = min(stageProgress, 1.0)
        
        // Apply curve to progress
        let stageConfig = getStageConfig(currentStage)
        let curvedProgress = applyCurve(stageProgress, curve: stageConfig.curve, power: stageConfig.curvePower)
        
        // Interpolate between start and target levels
        let startLevel = getStageStartLevel()
        currentLevel = startLevel + (targetLevel - startLevel) * curvedProgress
    }
    
    private func advanceToNextStage() {
        stageProgress = 0.0
        
        switch currentStage {
        case .idle:
            currentStage = config.delay.time > 0.0 ? .delay : .attack
            
        case .delay:
            currentStage = .attack
            
        case .attack:
            currentStage = .decay
            
        case .decay:
            currentStage = .sustain
            
        case .sustain:
            // Handle looping
            if config.loopEnabled && isNoteOn {
                if maxLoops < 0 || loopCount < maxLoops {
                    currentStage = config.loopStart
                    loopCount += 1
                }
            }
            // Stay in sustain until note off
            
        case .release:
            currentStage = .idle
            currentLevel = 0.0
        }
        
        updateStageParameters()
    }
    
    private func getStageConfig(_ stage: EnvelopeStage) -> EnvelopeGeneratorStageConfig {
        switch stage {
        case .idle: return EnvelopeGeneratorStageConfig(time: 0.0, level: 0.0, curve: .linear)
        case .delay: return config.delay
        case .attack: return config.attack
        case .decay: return config.decay
        case .sustain: return config.sustain
        case .release: return config.release
        }
    }
    
    private func getStageStartLevel() -> Float {
        switch currentStage {
        case .idle: return 0.0
        case .delay: return currentLevel
        case .attack: return currentLevel
        case .decay: return currentLevel
        case .sustain: return currentLevel
        case .release: return currentLevel
        }
    }
    
    private func applyCurve(_ input: Float, curve: EnvelopeCurveType, power: Float = 2.0) -> Float {
        let x = max(0.0, min(1.0, input))
        
        switch curve {
        case .linear:
            return x
            
        case .exponential:
            return x * x
            
        case .logarithmic:
            return sqrt(x)
            
        case .sine:
            return sin(x * Float.pi * 0.5)
            
        case .cosine:
            return 1.0 - cos(x * Float.pi * 0.5)
            
        case .power:
            return pow(x, power)
            
        case .inverse:
            return 1.0 - pow(1.0 - x, power)
        }
    }
}

// MARK: - WAVETONE Envelope System

/// Specialized envelope system for WAVETONE with multiple envelope generators
public final class WavetoneEnvelopeSystem: @unchecked Sendable {

    // MARK: - Envelope Generators

    /// Amplitude envelope for overall volume control
    public let amplitudeEnvelope: EnvelopeGenerator

    /// Filter envelope for filter cutoff modulation
    public let filterEnvelope: EnvelopeGenerator

    /// Pitch envelope for frequency modulation
    public let pitchEnvelope: EnvelopeGenerator

    /// Auxiliary envelope for custom modulation
    public let auxEnvelope: EnvelopeGenerator

    // MARK: - Configuration

    public struct Configuration: Codable {
        public var amplitudeConfig: EnvelopeGeneratorConfig
        public var filterConfig: EnvelopeGeneratorConfig
        public var pitchConfig: EnvelopeGeneratorConfig
        public var auxConfig: EnvelopeGeneratorConfig

        public init() {
            // Default amplitude envelope (standard ADSR)
            self.amplitudeConfig = EnvelopeGeneratorConfig()

            // Default filter envelope (more aggressive)
            self.filterConfig = EnvelopeGeneratorConfig()
            filterConfig.attack.time = 0.02
            filterConfig.decay.time = 0.3
            filterConfig.sustain.level = 0.5
            filterConfig.release.time = 0.5

            // Default pitch envelope (quick sweep)
            self.pitchConfig = EnvelopeGeneratorConfig()
            pitchConfig.attack.time = 0.001
            pitchConfig.decay.time = 0.05
            pitchConfig.sustain.level = 0.0
            pitchConfig.release.time = 0.01

            // Default aux envelope (slow modulation)
            self.auxConfig = EnvelopeGeneratorConfig()
            auxConfig.attack.time = 0.1
            auxConfig.decay.time = 0.8
            auxConfig.sustain.level = 0.7
            auxConfig.release.time = 1.0
        }
    }

    private var configuration: Configuration

    // MARK: - Initialization

    public init(configuration: Configuration = Configuration(), sampleRate: Double = 44100.0) {
        self.configuration = configuration

        self.amplitudeEnvelope = EnvelopeGenerator(config: configuration.amplitudeConfig, sampleRate: sampleRate)
        self.filterEnvelope = EnvelopeGenerator(config: configuration.filterConfig, sampleRate: sampleRate)
        self.pitchEnvelope = EnvelopeGenerator(config: configuration.pitchConfig, sampleRate: sampleRate)
        self.auxEnvelope = EnvelopeGenerator(config: configuration.auxConfig, sampleRate: sampleRate)
    }

    // MARK: - Public Interface

    /// Trigger all envelopes with note on
    public func noteOn(velocity: Float, noteNumber: Int = 60) {
        amplitudeEnvelope.noteOn(velocity: velocity, noteNumber: noteNumber)
        filterEnvelope.noteOn(velocity: velocity, noteNumber: noteNumber)
        pitchEnvelope.noteOn(velocity: velocity, noteNumber: noteNumber)
        auxEnvelope.noteOn(velocity: velocity, noteNumber: noteNumber)
    }

    /// Release all envelopes with note off
    public func noteOff() {
        amplitudeEnvelope.noteOff()
        filterEnvelope.noteOff()
        pitchEnvelope.noteOff()
        auxEnvelope.noteOff()
    }

    /// Process all envelopes and return their values
    public func processEnvelopes() -> (amplitude: Float, filter: Float, pitch: Float, aux: Float) {
        return (
            amplitude: amplitudeEnvelope.processSample(),
            filter: filterEnvelope.processSample(),
            pitch: pitchEnvelope.processSample(),
            aux: auxEnvelope.processSample()
        )
    }

    /// Check if any envelope is active
    public var isActive: Bool {
        return amplitudeEnvelope.isActive || filterEnvelope.isActive ||
               pitchEnvelope.isActive || auxEnvelope.isActive
    }

    /// Reset all envelopes
    public func reset() {
        amplitudeEnvelope.reset()
        filterEnvelope.reset()
        pitchEnvelope.reset()
        auxEnvelope.reset()
    }
    
    /// All notes off - releases all envelopes
    public func allNotesOff() {
        noteOff()
    }

    /// Update configuration
    public func updateConfiguration(_ newConfig: Configuration) {
        self.configuration = newConfig
        amplitudeEnvelope.config = newConfig.amplitudeConfig
        filterEnvelope.config = newConfig.filterConfig
        pitchEnvelope.config = newConfig.pitchConfig
        auxEnvelope.config = newConfig.auxConfig
    }

    // MARK: - Preset Management

    /// Create preset configurations for different sound types
    public static func createPresetConfiguration(type: WavetonePresetType) -> Configuration {
        var config = Configuration()

        switch type {
        case .lead:
            // Lead sound: punchy amplitude, bright filter, subtle pitch
            config.amplitudeConfig = EnvelopeGeneratorConfig()
            config.amplitudeConfig.attack.time = 0.01
            config.amplitudeConfig.decay.time = 0.2
            config.amplitudeConfig.sustain.level = 0.8
            config.amplitudeConfig.release.time = 0.3

            config.filterConfig.attack.time = 0.005
            config.filterConfig.decay.time = 0.15
            config.filterConfig.sustain.level = 0.6

        case .pad:
            // Pad sound: slow amplitude, evolving filter, no pitch
            config.amplitudeConfig = EnvelopeGeneratorConfig.padPreset()

            config.filterConfig.attack.time = 0.8
            config.filterConfig.decay.time = 2.0
            config.filterConfig.sustain.level = 0.7
            config.filterConfig.release.time = 3.0

            config.pitchConfig.attack.time = 0.0
            config.pitchConfig.decay.time = 0.0
            config.pitchConfig.sustain.level = 0.0

        case .pluck:
            // Plucked sound: fast amplitude, quick filter, pitch sweep
            config.amplitudeConfig = EnvelopeGeneratorConfig.pluckedPreset()

            config.filterConfig.attack.time = 0.001
            config.filterConfig.decay.time = 0.1
            config.filterConfig.sustain.level = 0.2

            config.pitchConfig.attack.time = 0.001
            config.pitchConfig.decay.time = 0.02
            config.pitchConfig.sustain.level = 0.0

        case .bass:
            // Bass sound: punchy amplitude, controlled filter, minimal pitch
            config.amplitudeConfig.attack.time = 0.005
            config.amplitudeConfig.decay.time = 0.3
            config.amplitudeConfig.sustain.level = 0.9
            config.amplitudeConfig.release.time = 0.2

            config.filterConfig.attack.time = 0.01
            config.filterConfig.decay.time = 0.2
            config.filterConfig.sustain.level = 0.4

        case .organ:
            // Organ sound: smooth amplitude, steady filter, no pitch
            config.amplitudeConfig = EnvelopeGeneratorConfig.organPreset()

            config.filterConfig.attack.time = 0.05
            config.filterConfig.decay.time = 0.1
            config.filterConfig.sustain.level = 0.8
            config.filterConfig.release.time = 0.8
        }

        return config
    }
}

// MARK: - WAVETONE Preset Types

/// Preset types for WAVETONE envelope configurations
public enum WavetonePresetType: String, CaseIterable, Codable {
    case lead = "lead"
    case pad = "pad"
    case pluck = "pluck"
    case bass = "bass"
    case organ = "organ"

    public var description: String {
        switch self {
        case .lead: return "Lead"
        case .pad: return "Pad"
        case .pluck: return "Pluck"
        case .bass: return "Bass"
        case .organ: return "Organ"
        }
    }
}

// MARK: - Envelope Parameter Manager

/// Parameter manager for envelope system integration
public final class EnvelopeParameterManager: @unchecked Sendable {

    private let envelopeSystem: WavetoneEnvelopeSystem

    public init(envelopeSystem: WavetoneEnvelopeSystem) {
        self.envelopeSystem = envelopeSystem
    }

    /// Create parameters for envelope system
    public func createParameters() -> [Parameter] {
        var parameters: [Parameter] = []

        // Amplitude envelope parameters
        parameters.append(contentsOf: createEnvelopeParameters(prefix: "amp", name: "Amplitude"))

        // Filter envelope parameters
        parameters.append(contentsOf: createEnvelopeParameters(prefix: "filter", name: "Filter"))

        // Pitch envelope parameters
        parameters.append(contentsOf: createEnvelopeParameters(prefix: "pitch", name: "Pitch"))

        // Aux envelope parameters
        parameters.append(contentsOf: createEnvelopeParameters(prefix: "aux", name: "Aux"))

        return parameters
    }

    private func createEnvelopeParameters(prefix: String, name: String) -> [Parameter] {
        return [
            Parameter(
                id: "\(prefix)_attack",
                name: "\(name) Attack",
                description: "\(name) envelope attack time",
                unit: "s",
                category: .envelope,
                dataType: .float,
                scaling: .logarithmic,
                minValue: 0.001,
                maxValue: 10.0,
                defaultValue: 0.01,
                isAutomatable: true
            ),
            Parameter(
                id: "\(prefix)_decay",
                name: "\(name) Decay",
                description: "\(name) envelope decay time",
                unit: "s",
                category: .envelope,
                dataType: .float,
                scaling: .logarithmic,
                minValue: 0.001,
                maxValue: 10.0,
                defaultValue: 0.1,
                isAutomatable: true
            ),
            Parameter(
                id: "\(prefix)_sustain",
                name: "\(name) Sustain",
                description: "\(name) envelope sustain level",
                unit: "",
                category: .envelope,
                dataType: .float,
                scaling: .linear,
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 0.7,
                isAutomatable: true
            ),
            Parameter(
                id: "\(prefix)_release",
                name: "\(name) Release",
                description: "\(name) envelope release time",
                unit: "s",
                category: .envelope,
                dataType: .float,
                scaling: .logarithmic,
                minValue: 0.001,
                maxValue: 10.0,
                defaultValue: 0.3,
                isAutomatable: true
            )
        ]
    }

    /// Handle parameter updates
    public func handleParameterUpdate(parameterID: String, value: Float) {
        let components = parameterID.split(separator: "_")
        guard components.count == 2 else { return }

        let envelopeType = String(components[0])
        let parameter = String(components[1])

        // Get the appropriate envelope
        let envelope: EnvelopeGenerator
        switch envelopeType {
        case "amp": envelope = envelopeSystem.amplitudeEnvelope
        case "filter": envelope = envelopeSystem.filterEnvelope
        case "pitch": envelope = envelopeSystem.pitchEnvelope
        case "aux": envelope = envelopeSystem.auxEnvelope
        default: return
        }

        // Update the parameter
        var config = envelope.config
        switch parameter {
        case "attack":
            config.attack.time = value
        case "decay":
            config.decay.time = value
        case "sustain":
            config.sustain.level = value
        case "release":
            config.release.time = value
        default:
            return
        }

        envelope.config = config
    }
}
