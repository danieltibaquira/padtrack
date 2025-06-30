// FMToneEnvelope.swift
// DigitonePad - VoiceModule
//
// Advanced Envelope Generator System for FM TONE Voice Machine

import Foundation
import Accelerate
import MachineProtocols
import AVFoundation

// MARK: - Envelope Curve Types

/// Different curve shapes for envelope stages
public enum EnvelopeCurve: CaseIterable, Sendable {
    case linear
    case exponential
    case logarithmic
    case sine
    case power
    
    /// Calculate the curved value from 0.0 to 1.0
    public func apply(to normalizedPosition: Float, power: Float = 2.0) -> Float {
        let position = max(0.0, min(1.0, normalizedPosition))
        
        switch self {
        case .linear:
            return position
            
        case .exponential:
            return position * position
            
        case .logarithmic:
            return sqrt(position)
            
        case .sine:
            return sin(position * Float.pi * 0.5)
            
        case .power:
            return pow(position, power)
        }
    }
}

// MARK: - Envelope Stage Configuration

/// Configuration for a single envelope stage
public struct EnvelopeStageConfig: Sendable {
    public let curve: EnvelopeCurve
    public let rate: Float          // Time in seconds (0.001 to 10.0)
    public let targetLevel: Float   // Target level (0.0 to 1.0)
    public let curvePower: Float    // Power factor for power curve (0.1 to 10.0)
    
    public init(curve: EnvelopeCurve = .exponential, rate: Float = 0.1, targetLevel: Float = 1.0, curvePower: Float = 2.0) {
        self.curve = curve
        self.rate = max(0.001, min(10.0, rate))
        self.targetLevel = max(0.0, min(1.0, targetLevel))
        self.curvePower = max(0.1, min(10.0, curvePower))
    }
}

// MARK: - Envelope Phase

/// Envelope phase states
public enum EnvelopePhase: CaseIterable, Sendable {
    case idle
    case delay      // Pre-attack delay
    case attack
    case decay
    case sustain
    case release
    
    public var isActive: Bool {
        self != .idle
    }
}

// MARK: - Loop Configuration

/// Loop modes for sustained envelopes
public enum EnvelopeLoopMode: CaseIterable, Sendable {
    case off                // No looping
    case sustainLoop        // Loop during sustain phase
    case fullLoop          // Loop entire envelope
    case pingPong          // Ping-pong loop (forward/backward)
    
    /// Loop points (start and end phase)
    public var loopPoints: (start: EnvelopePhase, end: EnvelopePhase) {
        switch self {
        case .off:
            return (.idle, .idle)
        case .sustainLoop:
            return (.decay, .sustain)
        case .fullLoop:
            return (.attack, .release)
        case .pingPong:
            return (.attack, .decay)
        }
    }
}

// MARK: - FM Tone Envelope Generator

/// Advanced envelope generator optimized for FM synthesis
public final class FMToneEnvelope: @unchecked Sendable {
    
    // MARK: - Configuration
    
    public struct Configuration: Sendable {
        public var delay: EnvelopeStageConfig
        public var attack: EnvelopeStageConfig
        public var decay: EnvelopeStageConfig
        public var sustain: EnvelopeStageConfig
        public var release: EnvelopeStageConfig
        
        public var velocitySensitivity: Float       // 0.0 to 1.0
        public var velocityCurve: EnvelopeCurve     // How velocity affects level
        public var keyTracking: Float               // -1.0 to 1.0 (rate scaling)
        public var loopMode: EnvelopeLoopMode       // Looping behavior
        
        public init() {
            self.delay = EnvelopeStageConfig(curve: .linear, rate: 0.0, targetLevel: 0.0)
            self.attack = EnvelopeStageConfig(curve: .exponential, rate: 0.01, targetLevel: 1.0)
            self.decay = EnvelopeStageConfig(curve: .exponential, rate: 0.1, targetLevel: 0.7)
            self.sustain = EnvelopeStageConfig(curve: .linear, rate: 0.0, targetLevel: 0.7)
            self.release = EnvelopeStageConfig(curve: .exponential, rate: 0.2, targetLevel: 0.0)
            
            self.velocitySensitivity = 0.8
            self.velocityCurve = .exponential
            self.keyTracking = 0.0
            self.loopMode = .off
        }
        
        public init(
            delay: EnvelopeStageConfig,
            attack: EnvelopeStageConfig,
            decay: EnvelopeStageConfig,
            sustain: EnvelopeStageConfig,
            release: EnvelopeStageConfig,
            velocitySensitivity: Float,
            velocityCurve: EnvelopeCurve,
            keyTracking: Float,
            loopMode: EnvelopeLoopMode
        ) {
            self.delay = delay
            self.attack = attack
            self.decay = decay
            self.sustain = sustain
            self.release = release
            self.velocitySensitivity = velocitySensitivity
            self.velocityCurve = velocityCurve
            self.keyTracking = keyTracking
            self.loopMode = loopMode
        }
    }
    
    // MARK: - State
    
    private let sampleRate: Double
    private var configuration: Configuration
    
    // Current envelope state
    private var currentPhase: EnvelopePhase = .idle
    private var currentLevel: Float = 0.0
    private var stagePosition: Float = 0.0          // 0.0 to 1.0 within current stage
    private var stageIncrement: Float = 0.0         // Per-sample increment
    private var stageStartLevel: Float = 0.0        // Level at start of current stage
    
    // Voice parameters
    private var velocity: Float = 1.0               // Normalized velocity (0.0 to 1.0)
    private var keyNumber: Float = 60.0             // MIDI key number for tracking
    private var noteOnTime: Double = 0.0            // For timing calculations
    
    // Loop state
    private var loopDirection: Float = 1.0          // 1.0 or -1.0 for ping-pong
    private var loopCount: Int = 0                  // Number of loops completed
    
    // Performance optimization
    private var lastCalculatedLevel: Float = 0.0
    private var levelInterpolationBuffer: [Float] = []
    private var bufferPosition: Int = 0
    private var blockSize: Int = 64                 // Process in blocks for efficiency
    
    // MARK: - Initialization
    
    public init(sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate
        self.configuration = Configuration()
        self.levelInterpolationBuffer = Array(repeating: 0.0, count: blockSize)
        setupInitialState()
    }
    
    private func setupInitialState() {
        currentPhase = .idle
        currentLevel = 0.0
        stagePosition = 0.0
        stageIncrement = 0.0
        loopDirection = 1.0
        loopCount = 0
    }
    
    // MARK: - Envelope Control
    
    /// Trigger envelope with note on
    public func noteOn(velocity: UInt8, keyNumber: UInt8 = 60) {
        self.velocity = Float(velocity) / 127.0
        self.keyNumber = Float(keyNumber)
        self.noteOnTime = CFAbsoluteTimeGetCurrent()
        
        // Apply velocity sensitivity
        let velocityAmount = applyVelocityCurve(self.velocity)
        
        // Start with delay or attack phase
        if configuration.delay.rate > 0.001 {
            enterPhase(.delay)
        } else {
            enterPhase(.attack)
        }
        
        // Reset loop state
        loopDirection = 1.0
        loopCount = 0
    }
    
    /// Trigger release phase
    public func noteOff() {
        if currentPhase.isActive && currentPhase != .release {
            enterPhase(.release)
        }
    }
    
    /// Quick release for voice stealing
    public func quickRelease() {
        if currentPhase.isActive {
            // Override release with very short time
            let quickConfig = EnvelopeStageConfig(
                curve: .exponential,
                rate: 0.01,  // 10ms quick release
                targetLevel: 0.0
            )
            enterPhaseWithConfig(.release, config: quickConfig)
        }
    }
    
    /// Force envelope to idle state
    public func reset() {
        currentPhase = .idle
        currentLevel = 0.0
        stagePosition = 0.0
        stageIncrement = 0.0
        bufferPosition = 0
        
        // Clear interpolation buffer
        for i in 0..<blockSize {
            levelInterpolationBuffer[i] = 0.0
        }
    }
    
    // MARK: - Audio Processing
    
    /// Process one sample and return envelope level
    public func processSample() -> Float {
        guard currentPhase.isActive else { return 0.0 }
        
        // Use block processing for efficiency
        if bufferPosition >= blockSize {
            processBlock()
            bufferPosition = 0
        }
        
        let level = levelInterpolationBuffer[bufferPosition]
        bufferPosition += 1
        
        return level
    }
    
    /// Process multiple samples at once (more efficient)
    public func processBlock(samples: inout [Float], startIndex: Int = 0) {
        let endIndex = min(startIndex + samples.count, samples.count)
        
        for i in startIndex..<endIndex {
            samples[i] = processSample()
        }
    }
    
    private func processBlock() {
        for i in 0..<blockSize {
            levelInterpolationBuffer[i] = calculateNextSample()
        }
    }
    
    private func calculateNextSample() -> Float {
        guard currentPhase.isActive else { return 0.0 }
        
        let config = getConfigForPhase(currentPhase)
        
        // Calculate position within stage
        if stageIncrement > 0.0 {
            stagePosition += stageIncrement * loopDirection
        }
        
        // Check for stage completion or looping
        if shouldAdvancePhase() {
            handlePhaseAdvancement()
            return currentLevel
        }
        
        // Calculate curved interpolation
        let curvedPosition = config.curve.apply(to: stagePosition, power: config.curvePower)
        
        // Interpolate level
        if currentPhase == .sustain {
            currentLevel = config.targetLevel * velocity
        } else {
            let levelDelta = (config.targetLevel * velocity) - stageStartLevel
            currentLevel = stageStartLevel + (levelDelta * curvedPosition)
        }
        
        // Apply denormal protection
        if abs(currentLevel) < 1e-10 {
            currentLevel = 0.0
        }
        
        return currentLevel
    }
    
    // MARK: - Phase Management
    
    private func enterPhase(_ phase: EnvelopePhase) {
        let config = getConfigForPhase(phase)
        enterPhaseWithConfig(phase, config: config)
    }
    
    private func enterPhaseWithConfig(_ phase: EnvelopePhase, config: EnvelopeStageConfig) {
        currentPhase = phase
        stageStartLevel = currentLevel
        stagePosition = 0.0
        
        // Calculate stage increment with key tracking
        let keyTrackingFactor = 1.0 + (configuration.keyTracking * (keyNumber - 60.0) / 64.0)
        let adjustedRate = config.rate / keyTrackingFactor
        
        if adjustedRate > 0.001 {
            stageIncrement = 1.0 / (Float(sampleRate) * adjustedRate)
        } else {
            stageIncrement = 1.0  // Instant transition
        }
        
        // Handle sustain phase (doesn't advance automatically)
        if phase == .sustain {
            stageIncrement = 0.0
            currentLevel = config.targetLevel * velocity
        }
    }
    
    private func shouldAdvancePhase() -> Bool {
        // Sustain phase doesn't auto-advance
        if currentPhase == .sustain {
            return false
        }
        
        // Check for loop conditions
        if configuration.loopMode != .off && shouldLoop() {
            return false  // Handle looping instead
        }
        
        // Normal phase advancement
        return stagePosition >= 1.0 || (loopDirection < 0 && stagePosition <= 0.0)
    }
    
    private func shouldLoop() -> Bool {
        let (loopStart, loopEnd) = configuration.loopMode.loopPoints
        return currentPhase == loopEnd && configuration.loopMode != .off
    }
    
    private func handlePhaseAdvancement() {
        // Handle looping first
        if shouldLoop() {
            handleLooping()
            return
        }
        
        // Regular phase advancement
        switch currentPhase {
        case .idle:
            break
            
        case .delay:
            enterPhase(.attack)
            
        case .attack:
            enterPhase(.decay)
            
        case .decay:
            enterPhase(.sustain)
            
        case .sustain:
            // Sustain doesn't auto-advance
            break
            
        case .release:
            // Release completes to idle
            if stagePosition >= 1.0 || currentLevel <= 0.001 {
                currentPhase = .idle
                currentLevel = 0.0
            }
        }
    }
    
    private func handleLooping() {
        loopCount += 1
        
        switch configuration.loopMode {
        case .off:
            return
            
        case .sustainLoop:
            stagePosition = 0.0
            enterPhase(.decay)
            
        case .fullLoop:
            stagePosition = 0.0
            enterPhase(.attack)
            
        case .pingPong:
            loopDirection *= -1.0
            if loopDirection > 0.0 {
                stagePosition = 0.0
            } else {
                stagePosition = 1.0
            }
        }
    }
    
    // MARK: - Configuration Access
    
    public func updateConfiguration(_ config: Configuration) {
        self.configuration = config
    }
    
    public func updateStage(_ phase: EnvelopePhase, config: EnvelopeStageConfig) {
        switch phase {
        case .delay:
            configuration.delay = config
        case .attack:
            configuration.attack = config
        case .decay:
            configuration.decay = config
        case .sustain:
            configuration.sustain = config
        case .release:
            configuration.release = config
        case .idle:
            break
        }
    }
    
    private func getConfigForPhase(_ phase: EnvelopePhase) -> EnvelopeStageConfig {
        switch phase {
        case .idle:
            return EnvelopeStageConfig(curve: .linear, rate: 0.0, targetLevel: 0.0)
        case .delay:
            return configuration.delay
        case .attack:
            return configuration.attack
        case .decay:
            return configuration.decay
        case .sustain:
            return configuration.sustain
        case .release:
            return configuration.release
        }
    }
    
    private func applyVelocityCurve(_ velocity: Float) -> Float {
        let scaledVelocity = 1.0 - configuration.velocitySensitivity + (configuration.velocitySensitivity * velocity)
        return configuration.velocityCurve.apply(to: scaledVelocity)
    }
    
    // MARK: - State Access
    
    public var isActive: Bool {
        currentPhase.isActive
    }
    
    public var currentOutput: Float {
        currentLevel
    }
    
    public var phase: EnvelopePhase {
        currentPhase
    }
    
    public var stageProgress: Float {
        stagePosition
    }
    
    // MARK: - Performance Monitoring
    
    public struct EnvelopeState: Sendable {
        public let phase: EnvelopePhase
        public let level: Float
        public let progress: Float
        public let loopCount: Int
        public let velocity: Float
        public let keyNumber: Float
    }
    
    public var currentState: EnvelopeState {
        EnvelopeState(
            phase: currentPhase,
            level: currentLevel,
            progress: stagePosition,
            loopCount: loopCount,
            velocity: velocity,
            keyNumber: keyNumber
        )
    }
}

// MARK: - Envelope Presets

/// Common envelope presets for FM synthesis
public struct FMEnvelopePresets {
    
    public static let organStyle = FMToneEnvelope.Configuration(
        delay: EnvelopeStageConfig(curve: .linear, rate: 0.0, targetLevel: 0.0),
        attack: EnvelopeStageConfig(curve: .sine, rate: 0.02, targetLevel: 1.0),
        decay: EnvelopeStageConfig(curve: .exponential, rate: 0.1, targetLevel: 0.9),
        sustain: EnvelopeStageConfig(curve: .linear, rate: 0.0, targetLevel: 0.9),
        release: EnvelopeStageConfig(curve: .exponential, rate: 0.8, targetLevel: 0.0),
        velocitySensitivity: 0.6,
        velocityCurve: .logarithmic,
        keyTracking: 0.0,
        loopMode: .off
    )
    
    public static let bellStyle = FMToneEnvelope.Configuration(
        delay: EnvelopeStageConfig(curve: .linear, rate: 0.0, targetLevel: 0.0),
        attack: EnvelopeStageConfig(curve: .logarithmic, rate: 0.005, targetLevel: 1.0),
        decay: EnvelopeStageConfig(curve: .exponential, rate: 2.0, targetLevel: 0.0),
        sustain: EnvelopeStageConfig(curve: .linear, rate: 0.0, targetLevel: 0.0),
        release: EnvelopeStageConfig(curve: .exponential, rate: 1.0, targetLevel: 0.0),
        velocitySensitivity: 0.9,
        velocityCurve: .exponential,
        keyTracking: 0.3,  // Higher notes decay faster
        loopMode: .off
    )
    
    public static let pluckedStyle = FMToneEnvelope.Configuration(
        delay: EnvelopeStageConfig(curve: .linear, rate: 0.0, targetLevel: 0.0),
        attack: EnvelopeStageConfig(curve: .linear, rate: 0.001, targetLevel: 1.0),
        decay: EnvelopeStageConfig(curve: .exponential, rate: 0.8, targetLevel: 0.1),
        sustain: EnvelopeStageConfig(curve: .linear, rate: 0.0, targetLevel: 0.1),
        release: EnvelopeStageConfig(curve: .exponential, rate: 0.5, targetLevel: 0.0),
        velocitySensitivity: 0.8,
        velocityCurve: .exponential,
        keyTracking: 0.5,  // Strong key tracking for plucked sounds
        loopMode: .off
    )
    
    public static let padStyle = FMToneEnvelope.Configuration(
        delay: EnvelopeStageConfig(curve: .linear, rate: 0.0, targetLevel: 0.0),
        attack: EnvelopeStageConfig(curve: .sine, rate: 0.5, targetLevel: 1.0),
        decay: EnvelopeStageConfig(curve: .logarithmic, rate: 1.0, targetLevel: 0.8),
        sustain: EnvelopeStageConfig(curve: .linear, rate: 0.0, targetLevel: 0.8),
        release: EnvelopeStageConfig(curve: .exponential, rate: 2.0, targetLevel: 0.0),
        velocitySensitivity: 0.5,
        velocityCurve: .sine,
        keyTracking: -0.2,  // Slower attack for higher notes
        loopMode: .off
    )
    
    public static let percussiveStyle = FMToneEnvelope.Configuration(
        delay: EnvelopeStageConfig(curve: .linear, rate: 0.0, targetLevel: 0.0),
        attack: EnvelopeStageConfig(curve: .linear, rate: 0.001, targetLevel: 1.0),
        decay: EnvelopeStageConfig(curve: .exponential, rate: 0.1, targetLevel: 0.0),
        sustain: EnvelopeStageConfig(curve: .linear, rate: 0.0, targetLevel: 0.0),
        release: EnvelopeStageConfig(curve: .exponential, rate: 0.05, targetLevel: 0.0),
        velocitySensitivity: 1.0,
        velocityCurve: .exponential,
        keyTracking: 0.4,
        loopMode: .off
    )
    
    public static let lfoStyle = FMToneEnvelope.Configuration(
        delay: EnvelopeStageConfig(curve: .linear, rate: 0.0, targetLevel: 0.0),
        attack: EnvelopeStageConfig(curve: .sine, rate: 1.0, targetLevel: 1.0),
        decay: EnvelopeStageConfig(curve: .sine, rate: 1.0, targetLevel: 0.0),
        sustain: EnvelopeStageConfig(curve: .linear, rate: 0.0, targetLevel: 0.0),
        release: EnvelopeStageConfig(curve: .linear, rate: 0.01, targetLevel: 0.0),
        velocitySensitivity: 0.0,  // No velocity sensitivity for LFO
        velocityCurve: .linear,
        keyTracking: 0.0,
        loopMode: .fullLoop  // Continuous looping
    )
    
    /// Get all available presets
    public static var allPresets: [String: FMToneEnvelope.Configuration] {
        [
            "Organ": organStyle,
            "Bell": bellStyle,
            "Plucked": pluckedStyle,
            "Pad": padStyle,
            "Percussive": percussiveStyle,
            "LFO": lfoStyle
        ]
    }
} 