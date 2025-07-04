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
    
    // Note: level property already defined above
    
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
// Note: WavetoneEnvelopeSystem is defined in WavetoneEnvelopeSystem.swift
