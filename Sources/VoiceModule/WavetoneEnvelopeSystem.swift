//
//  WavetoneEnvelopeSystem.swift
//  DigitonePad - VoiceModule
//
//  WAVETONE Envelope Generator System with ADSR envelopes, multiple curve types,
//  trigger modes, loop modes, velocity sensitivity, and key tracking

import Foundation
import Accelerate
import MachineProtocols
import AudioEngine
import AVFoundation
import simd

/// Comprehensive envelope generator system for WAVETONE Voice Machine
/// Provides ADSR envelopes with advanced features including customizable curves,
/// velocity sensitivity, loop modes, and key tracking
@unchecked Sendable
public final class WavetoneEnvelopeSystem {
    
    // MARK: - Envelope Phase
    public enum EnvelopePhase: CaseIterable {
        case delay
        case attack
        case decay
        case sustain
        case release
        case finished
    }
    
    // MARK: - Envelope Curve Types
    public enum EnvelopeCurve: CaseIterable {
        case linear
        case exponential
        case logarithmic
        case sine
        case power
        case snap
    }
    
    // MARK: - Trigger Modes
    public enum TriggerMode: CaseIterable {
        case retrigger    // Always restart from beginning
        case legato       // Continue if already running
        case cycle        // Cycle through phases continuously
    }
    
    // MARK: - Loop Modes
    public enum LoopMode: CaseIterable {
        case off          // No looping
        case sustainLoop  // Loop during sustain phase
        case fullLoop     // Loop entire envelope
        case pingPong     // Ping-pong loop
    }
    
    // MARK: - Envelope Configuration
    public struct EnvelopeStageConfig {
        public var rate: Float        // Time in seconds (0.001 - 10.0)
        public var targetLevel: Float // Target level (0.0 - 1.0)
        public var curve: EnvelopeCurve
        
        public init(rate: Float = 0.1, targetLevel: Float = 1.0, curve: EnvelopeCurve = .exponential) {
            self.rate = max(0.001, min(10.0, rate))
            self.targetLevel = max(0.0, min(1.0, targetLevel))
            self.curve = curve
        }
    }
    
    public struct EnvelopeConfig {
        public var delay: EnvelopeStageConfig
        public var attack: EnvelopeStageConfig
        public var decay: EnvelopeStageConfig
        public var sustain: EnvelopeStageConfig
        public var release: EnvelopeStageConfig
        
        public var triggerMode: TriggerMode
        public var loopMode: LoopMode
        public var loopStartPhase: EnvelopePhase
        public var loopEndPhase: EnvelopePhase
        
        // Velocity sensitivity
        public var velocitySensitivity: Float  // 0.0 - 1.0
        public var velocityCurve: EnvelopeCurve
        
        // Key tracking
        public var keyTracking: Float          // -1.0 to 1.0 (rate scaling)
        public var keyTrackingCenter: UInt8    // MIDI note number (default C4 = 60)
        
        public init() {
            self.delay = EnvelopeStageConfig(rate: 0.0, targetLevel: 0.0, curve: .linear)
            self.attack = EnvelopeStageConfig(rate: 0.1, targetLevel: 1.0, curve: .exponential)
            self.decay = EnvelopeStageConfig(rate: 0.2, targetLevel: 0.7, curve: .exponential)
            self.sustain = EnvelopeStageConfig(rate: 0.0, targetLevel: 0.7, curve: .linear)
            self.release = EnvelopeStageConfig(rate: 0.3, targetLevel: 0.0, curve: .exponential)
            
            self.triggerMode = .retrigger
            self.loopMode = .off
            self.loopStartPhase = .attack
            self.loopEndPhase = .decay
            
            self.velocitySensitivity = 0.5
            self.velocityCurve = .exponential
            
            self.keyTracking = 0.0
            self.keyTrackingCenter = 60  // C4
        }
    }
    
    // MARK: - Envelope State
    public struct EnvelopeState {
        public var currentPhase: EnvelopePhase = .finished
        public var currentLevel: Float = 0.0
        public var phaseProgress: Float = 0.0
        public var isActive: Bool = false
        public var velocity: Float = 1.0
        public var noteNumber: UInt8 = 60
        
        // Loop state
        public var loopCount: Int = 0
        public var loopDirection: Int = 1  // 1 for forward, -1 for reverse (ping-pong)
        
        // Internal state
        fileprivate var phaseStartLevel: Float = 0.0
        fileprivate var phaseTargetLevel: Float = 0.0
        fileprivate var phaseRate: Float = 0.0
        fileprivate var sampleRate: Float = 44100.0
    }
    
    // MARK: - Properties
    private var config: EnvelopeConfig
    private var state: EnvelopeState
    private let blockSize: Int = 64
    private var interpolationBuffer: [Float]
    
    // MARK: - Initialization
    public init(config: EnvelopeConfig = EnvelopeConfig()) {
        self.config = config
        self.state = EnvelopeState()
        self.interpolationBuffer = Array(repeating: 0.0, count: blockSize)
    }
    
    // MARK: - Configuration
    public func updateConfig(_ newConfig: EnvelopeConfig) {
        config = newConfig
    }
    
    public func setSampleRate(_ sampleRate: Float) {
        state.sampleRate = sampleRate
    }
    
    // MARK: - Envelope Control
    public func trigger(velocity: Float = 1.0, noteNumber: UInt8 = 60) {
        let clampedVelocity = max(0.0, min(1.0, velocity))
        
        switch config.triggerMode {
        case .retrigger:
            startEnvelope(velocity: clampedVelocity, noteNumber: noteNumber)
        case .legato:
            if !state.isActive {
                startEnvelope(velocity: clampedVelocity, noteNumber: noteNumber)
            }
        case .cycle:
            if state.isActive {
                advanceToNextPhase()
            } else {
                startEnvelope(velocity: clampedVelocity, noteNumber: noteNumber)
            }
        }
    }
    
    public func release() {
        if state.isActive && state.currentPhase != .release {
            transitionToPhase(.release)
        }
    }
    
    public func quickRelease() {
        // Emergency quick release for voice stealing (10ms)
        if state.isActive {
            state.currentPhase = .release
            state.phaseStartLevel = state.currentLevel
            state.phaseTargetLevel = 0.0
            state.phaseRate = calculatePhaseRate(time: 0.01, curve: .exponential)
            state.phaseProgress = 0.0
        }
    }
    
    public func reset() {
        state.currentPhase = .finished
        state.currentLevel = 0.0
        state.phaseProgress = 0.0
        state.isActive = false
        state.loopCount = 0
        state.loopDirection = 1
    }
    
    // MARK: - Processing
    public func processSample() -> Float {
        guard state.isActive else { return 0.0 }
        
        // Update phase progress
        state.phaseProgress += state.phaseRate
        
        // Calculate envelope level based on curve
        let rawLevel = calculateCurveValue(progress: state.phaseProgress, curve: getCurrentCurve())
        state.currentLevel = interpolateLevel(start: state.phaseStartLevel, 
                                            target: state.phaseTargetLevel, 
                                            progress: rawLevel)
        
        // Apply velocity sensitivity
        let velocityScaledLevel = applyVelocitySensitivity(level: state.currentLevel, velocity: state.velocity)
        
        // Check for phase completion
        if state.phaseProgress >= 1.0 {
            handlePhaseCompletion()
        }
        
        // Apply denormal protection
        return velocityScaledLevel < 1e-10 ? 0.0 : velocityScaledLevel
    }
    
    public func processBlock(_ buffer: inout [Float]) {
        let count = min(buffer.count, blockSize)
        
        guard state.isActive else {
            for i in 0..<count {
                buffer[i] = 0.0
            }
            return
        }
        
        for i in 0..<count {
            buffer[i] = processSample()
        }
    }
    
    // MARK: - State Access
    public func getCurrentState() -> EnvelopeState {
        return state
    }
    
    public func isFinished() -> Bool {
        return state.currentPhase == .finished
    }
    
    public func getCurrentLevel() -> Float {
        return state.currentLevel
    }
    
    public func getCurrentPhase() -> EnvelopePhase {
        return state.currentPhase
    }
    
    // MARK: - Private Methods
    private func startEnvelope(velocity: Float, noteNumber: UInt8) {
        state.velocity = velocity
        state.noteNumber = noteNumber
        state.isActive = true
        state.loopCount = 0
        state.loopDirection = 1
        
        // Start with delay phase if configured, otherwise attack
        if config.delay.rate > 0.0 {
            transitionToPhase(.delay)
        } else {
            transitionToPhase(.attack)
        }
    }
    
    private func transitionToPhase(_ phase: EnvelopePhase) {
        state.currentPhase = phase
        state.phaseStartLevel = state.currentLevel
        state.phaseProgress = 0.0
        
        let stageConfig = getStageConfig(for: phase)
        state.phaseTargetLevel = stageConfig.targetLevel
        
        // Apply key tracking to rate
        let keyTrackingMultiplier = calculateKeyTrackingMultiplier()
        let adjustedRate = stageConfig.rate * keyTrackingMultiplier
        
        state.phaseRate = calculatePhaseRate(time: adjustedRate, curve: stageConfig.curve)
    }
    
    private func advanceToNextPhase() {
        switch state.currentPhase {
        case .delay:
            transitionToPhase(.attack)
        case .attack:
            transitionToPhase(.decay)
        case .decay:
            transitionToPhase(.sustain)
        case .sustain:
            handleSustainPhase()
        case .release:
            state.currentPhase = .finished
            state.isActive = false
        case .finished:
            break
        }
    }
    
    private func handlePhaseCompletion() {
        // Handle looping
        if shouldLoop() {
            handleLooping()
            return
        }
        
        // Normal phase advancement
        advanceToNextPhase()
    }
    
    private func handleSustainPhase() {
        // Sustain phase behavior depends on loop mode
        switch config.loopMode {
        case .off:
            // Stay in sustain until release
            break
        case .sustainLoop:
            if config.loopStartPhase == .sustain {
                state.phaseProgress = 0.0
            }
        case .fullLoop, .pingPong:
            handleLooping()
        }
    }
    
    private func shouldLoop() -> Bool {
        switch config.loopMode {
        case .off:
            return false
        case .sustainLoop:
            return state.currentPhase == .sustain
        case .fullLoop, .pingPong:
            return state.currentPhase == config.loopEndPhase
        }
    }
    
    private func handleLooping() {
        state.loopCount += 1
        
        switch config.loopMode {
        case .off:
            break
        case .sustainLoop:
            state.phaseProgress = 0.0
        case .fullLoop:
            transitionToPhase(config.loopStartPhase)
        case .pingPong:
            state.loopDirection *= -1
            if state.loopDirection == 1 {
                transitionToPhase(config.loopStartPhase)
            } else {
                transitionToPhase(config.loopEndPhase)
            }
        }
    }
    
    private func getStageConfig(for phase: EnvelopePhase) -> EnvelopeStageConfig {
        switch phase {
        case .delay: return config.delay
        case .attack: return config.attack
        case .decay: return config.decay
        case .sustain: return config.sustain
        case .release: return config.release
        case .finished: return config.release
        }
    }
    
    private func getCurrentCurve() -> EnvelopeCurve {
        return getStageConfig(for: state.currentPhase).curve
    }
    
    private func calculatePhaseRate(time: Float, curve: EnvelopeCurve) -> Float {
        guard time > 0.0 else { return 1.0 }
        
        // Base rate calculation (samples per second / time in seconds)
        let baseRate = 1.0 / (time * state.sampleRate)
        
        // Adjust rate based on curve type for consistent timing
        switch curve {
        case .linear, .sine:
            return baseRate
        case .exponential, .logarithmic:
            return baseRate * 0.9  // Slightly slower for exponential curves
        case .power:
            return baseRate * 0.95
        case .snap:
            return baseRate * 10.0  // Very fast for snap
        }
    }
    
    private func calculateCurveValue(progress: Float, curve: EnvelopeCurve) -> Float {
        let clampedProgress = max(0.0, min(1.0, progress))
        
        switch curve {
        case .linear:
            return clampedProgress
        case .exponential:
            return 1.0 - exp(-5.0 * clampedProgress)
        case .logarithmic:
            return log(1.0 + 9.0 * clampedProgress) / log(10.0)
        case .sine:
            return sin(clampedProgress * .pi / 2.0)
        case .power:
            return pow(clampedProgress, 2.0)
        case .snap:
            return clampedProgress < 0.1 ? 0.0 : 1.0
        }
    }
    
    private func interpolateLevel(start: Float, target: Float, progress: Float) -> Float {
        return start + (target - start) * progress
    }
    
    private func applyVelocitySensitivity(level: Float, velocity: Float) -> Float {
        let sensitivityAmount = config.velocitySensitivity
        guard sensitivityAmount > 0.0 else { return level }
        
        let velocityMultiplier = calculateCurveValue(progress: velocity, curve: config.velocityCurve)
        let scaledVelocity = 1.0 - sensitivityAmount + (sensitivityAmount * velocityMultiplier)
        
        return level * scaledVelocity
    }
    
    private func calculateKeyTrackingMultiplier() -> Float {
        guard config.keyTracking != 0.0 else { return 1.0 }
        
        let noteOffset = Float(Int(state.noteNumber) - Int(config.keyTrackingCenter))
        let octaveOffset = noteOffset / 12.0
        
        // Key tracking affects rate: positive = faster at higher notes, negative = slower
        return pow(2.0, config.keyTracking * octaveOffset)
    }
}

// MARK: - Multi-Envelope System
@unchecked Sendable
public final class WavetoneMultiEnvelopeSystem {
    
    public enum EnvelopeDestination: CaseIterable {
        case amplitude
        case filter
        case auxiliary1
        case auxiliary2
        case auxiliary3
        case auxiliary4
        case auxiliary5
    }
    
    private var envelopes: [EnvelopeDestination: WavetoneEnvelopeSystem] = [:]
    private var routingMatrix: [EnvelopeDestination: Float] = [:]
    
    public init() {
        // Initialize envelopes for each destination
        for destination in EnvelopeDestination.allCases {
            envelopes[destination] = WavetoneEnvelopeSystem()
            routingMatrix[destination] = destination == .amplitude ? 1.0 : 0.0
        }
    }
    
    public func getEnvelope(for destination: EnvelopeDestination) -> WavetoneEnvelopeSystem? {
        return envelopes[destination]
    }
    
    public func setRouting(destination: EnvelopeDestination, amount: Float) {
        routingMatrix[destination] = max(0.0, min(1.0, amount))
    }
    
    public func getRouting(for destination: EnvelopeDestination) -> Float {
        return routingMatrix[destination] ?? 0.0
    }
    
    public func triggerAll(velocity: Float = 1.0, noteNumber: UInt8 = 60) {
        for envelope in envelopes.values {
            envelope.trigger(velocity: velocity, noteNumber: noteNumber)
        }
    }
    
    public func releaseAll() {
        for envelope in envelopes.values {
            envelope.release()
        }
    }
    
    public func resetAll() {
        for envelope in envelopes.values {
            envelope.reset()
        }
    }
    
    public func setSampleRateAll(_ sampleRate: Float) {
        for envelope in envelopes.values {
            envelope.setSampleRate(sampleRate)
        }
    }
    
    public func processAll() -> [EnvelopeDestination: Float] {
        var results: [EnvelopeDestination: Float] = [:]
        
        for (destination, envelope) in envelopes {
            let envelopeLevel = envelope.processSample()
            let routingAmount = routingMatrix[destination] ?? 0.0
            results[destination] = envelopeLevel * routingAmount
        }
        
        return results
    }
}

// MARK: - Preset Configurations
public extension WavetoneEnvelopeSystem.EnvelopeConfig {
    
    static let organ = WavetoneEnvelopeSystem.EnvelopeConfig(
        delay: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.0, targetLevel: 0.0, curve: .linear),
        attack: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.01, targetLevel: 1.0, curve: .snap),
        decay: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.05, targetLevel: 0.9, curve: .exponential),
        sustain: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.0, targetLevel: 0.9, curve: .linear),
        release: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.1, targetLevel: 0.0, curve: .exponential),
        triggerMode: .retrigger,
        loopMode: .off,
        velocitySensitivity: 0.3,
        velocityCurve: .exponential,
        keyTracking: 0.2
    )
    
    static let bell = WavetoneEnvelopeSystem.EnvelopeConfig(
        delay: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.0, targetLevel: 0.0, curve: .linear),
        attack: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.05, targetLevel: 1.0, curve: .exponential),
        decay: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.8, targetLevel: 0.3, curve: .logarithmic),
        sustain: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.0, targetLevel: 0.3, curve: .linear),
        release: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 2.0, targetLevel: 0.0, curve: .logarithmic),
        triggerMode: .retrigger,
        loopMode: .off,
        velocitySensitivity: 0.8,
        velocityCurve: .exponential,
        keyTracking: 0.5
    )
    
    static let plucked = WavetoneEnvelopeSystem.EnvelopeConfig(
        delay: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.0, targetLevel: 0.0, curve: .linear),
        attack: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.002, targetLevel: 1.0, curve: .snap),
        decay: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.3, targetLevel: 0.0, curve: .exponential),
        sustain: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.0, targetLevel: 0.0, curve: .linear),
        release: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.1, targetLevel: 0.0, curve: .exponential),
        triggerMode: .retrigger,
        loopMode: .off,
        velocitySensitivity: 0.9,
        velocityCurve: .exponential,
        keyTracking: 0.8
    )
    
    static let pad = WavetoneEnvelopeSystem.EnvelopeConfig(
        delay: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.1, targetLevel: 0.0, curve: .linear),
        attack: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.5, targetLevel: 1.0, curve: .sine),
        decay: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.8, targetLevel: 0.8, curve: .logarithmic),
        sustain: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.0, targetLevel: 0.8, curve: .linear),
        release: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 1.5, targetLevel: 0.0, curve: .logarithmic),
        triggerMode: .legato,
        loopMode: .off,
        velocitySensitivity: 0.4,
        velocityCurve: .sine,
        keyTracking: 0.0
    )
    
    static let percussive = WavetoneEnvelopeSystem.EnvelopeConfig(
        delay: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.0, targetLevel: 0.0, curve: .linear),
        attack: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.001, targetLevel: 1.0, curve: .snap),
        decay: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.15, targetLevel: 0.1, curve: .exponential),
        sustain: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.0, targetLevel: 0.1, curve: .linear),
        release: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.2, targetLevel: 0.0, curve: .exponential),
        triggerMode: .retrigger,
        loopMode: .off,
        velocitySensitivity: 1.0,
        velocityCurve: .exponential,
        keyTracking: 1.0
    )
    
    static let lfo = WavetoneEnvelopeSystem.EnvelopeConfig(
        delay: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.0, targetLevel: 0.0, curve: .linear),
        attack: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.5, targetLevel: 1.0, curve: .sine),
        decay: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.5, targetLevel: 0.0, curve: .sine),
        sustain: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.0, targetLevel: 0.0, curve: .linear),
        release: WavetoneEnvelopeSystem.EnvelopeStageConfig(rate: 0.1, targetLevel: 0.0, curve: .linear),
        triggerMode: .cycle,
        loopMode: .fullLoop,
        loopStartPhase: .attack,
        loopEndPhase: .decay,
        velocitySensitivity: 0.0,
        velocityCurve: .linear,
        keyTracking: 0.0
    )
    
    private init(delay: WavetoneEnvelopeSystem.EnvelopeStageConfig,
                attack: WavetoneEnvelopeSystem.EnvelopeStageConfig,
                decay: WavetoneEnvelopeSystem.EnvelopeStageConfig,
                sustain: WavetoneEnvelopeSystem.EnvelopeStageConfig,
                release: WavetoneEnvelopeSystem.EnvelopeStageConfig,
                triggerMode: WavetoneEnvelopeSystem.TriggerMode,
                loopMode: WavetoneEnvelopeSystem.LoopMode,
                loopStartPhase: WavetoneEnvelopeSystem.EnvelopePhase = .attack,
                loopEndPhase: WavetoneEnvelopeSystem.EnvelopePhase = .decay,
                velocitySensitivity: Float,
                velocityCurve: WavetoneEnvelopeSystem.EnvelopeCurve,
                keyTracking: Float) {
        self.delay = delay
        self.attack = attack
        self.decay = decay
        self.sustain = sustain
        self.release = release
        self.triggerMode = triggerMode
        self.loopMode = loopMode
        self.loopStartPhase = loopStartPhase
        self.loopEndPhase = loopEndPhase
        self.velocitySensitivity = velocitySensitivity
        self.velocityCurve = velocityCurve
        self.keyTracking = keyTracking
        self.keyTrackingCenter = 60
    }
}