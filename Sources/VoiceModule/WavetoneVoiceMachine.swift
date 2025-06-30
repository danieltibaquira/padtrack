// WavetoneVoiceMachine.swift
// DigitonePad - VoiceModule
//
// WAVETONE Voice Machine with dual oscillators, wavetable synthesis,
// phase distortion, ring modulation, hard sync, and flexible noise design

import Foundation
import Accelerate
import MachineProtocols
import AudioEngine

// MARK: - Oscillator Modulation Types

/// Types of oscillator modulation available in WAVETONE
public enum OscillatorModulationType: String, CaseIterable, Codable {
    case none = "none"
    case ringModulation = "ring_mod"
    case hardSync = "hard_sync"
    case phaseModulation = "phase_mod"
    case amplitudeModulation = "amp_mod"
    
    public var description: String {
        switch self {
        case .none: return "None"
        case .ringModulation: return "Ring Modulation"
        case .hardSync: return "Hard Sync"
        case .phaseModulation: return "Phase Modulation"
        case .amplitudeModulation: return "Amplitude Modulation"
        }
    }
}

// MARK: - WAVETONE Oscillator

/// Individual oscillator for WAVETONE with wavetable synthesis and modulation capabilities
public final class WavetoneOscillator: @unchecked Sendable {
    
    // MARK: - Core Properties
    
    public var frequency: Double = 440.0
    public var phase: Double = 0.0
    public var amplitude: Float = 1.0
    public var tuning: Float = 0.0  // In semitones
    public var phaseDistortionAmount: Float = 0.0
    
    // Wavetable properties
    public var currentWavetable: WavetableData?
    public var wavetablePosition: Float = 0.0  // 0.0 to 1.0
    public var wavetableInterpolation: WavetableInterpolation = .hermite
    
    // Modulation properties
    public var modulationType: OscillatorModulationType = .none
    public var modulationAmount: Float = 0.0
    public var syncSource: WavetoneOscillator?
    
    // Internal state
    private let sampleRate: Double
    private var phaseIncrement: Double = 0.0
    private var lastSyncPhase: Double = 0.0
    private let interpolator: WavetableInterpolator
    
    // MARK: - Initialization
    
    public init(sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate
        self.interpolator = WavetableInterpolator(
            antiAliasingConfig: .standard,
            performanceConfig: .balanced,
            splineType: .catmullRom
        )
        updatePhaseIncrement()
    }
    
    // MARK: - Parameter Updates
    
    public func setFrequency(_ frequency: Double) {
        self.frequency = frequency
        updatePhaseIncrement()
    }
    
    public func setTuning(_ tuning: Float) {
        self.tuning = tuning
        updatePhaseIncrement()
    }
    
    public func setWavetable(_ wavetable: WavetableData?) {
        self.currentWavetable = wavetable
    }
    
    public func setModulation(type: OscillatorModulationType, amount: Float) {
        self.modulationType = type
        self.modulationAmount = amount
    }
    
    // MARK: - Audio Processing
    
    /// Process a single sample with optional modulation input
    public func processSample(modulationInput: Float = 0.0) -> Float {
        guard let wavetable = currentWavetable else {
            // Fallback to sine wave if no wavetable
            let sample = sin(phase * 2.0 * Double.pi)
            advancePhase()
            let outputSample = Float(sample) * amplitude
            return applyAmplitudeModulation(outputSample, modulationInput: modulationInput)
        }

        // Calculate current phase with modulation
        var currentPhase = phase

        // Apply phase distortion
        if phaseDistortionAmount > 0.0 {
            currentPhase = applyPhaseDistortion(currentPhase)
        }

        // Apply modulation based on type
        let modulatedPhase = applyModulation(currentPhase, modulationInput: modulationInput)

        // Get wavetable sample
        let framePosition = wavetablePosition * Float(wavetable.frameCount - 1)
        let samplePosition = Float(modulatedPhase / (2.0 * Double.pi)) * Float(wavetable.frameSize)

        let sample = interpolator.interpolateSample(
            wavetable: wavetable,
            framePosition: framePosition,
            samplePosition: samplePosition,
            interpolation: wavetableInterpolation,
            fundamental: Float(frequency),
            sampleRate: Float(sampleRate)
        )

        // Advance phase
        advancePhase()

        // Apply amplitude and amplitude-based modulation
        let outputSample = sample * amplitude
        return applyAmplitudeModulation(outputSample, modulationInput: modulationInput)
    }
    
    /// Process a block of samples for efficiency
    public func processBlock(output: inout [Float], modulationInput: [Float]? = nil, blockSize: Int) {
        guard blockSize <= output.count else { return }
        
        for i in 0..<blockSize {
            let modInput = modulationInput?[i] ?? 0.0
            output[i] = processSample(modulationInput: modInput)
        }
    }
    
    // MARK: - Private Methods
    
    private func updatePhaseIncrement() {
        let tunedFrequency = frequency * pow(2.0, Double(tuning) / 12.0)
        phaseIncrement = tunedFrequency / sampleRate
    }
    
    private func advancePhase() {
        let oldPhase = phase
        phase += phaseIncrement * 2.0 * Double.pi

        // Handle hard sync with improved detection
        if modulationType == .hardSync, let syncSource = syncSource {
            let syncPhase = syncSource.currentPhase

            // Detect zero crossing in sync source (more robust detection)
            if lastSyncPhase > Double.pi && syncPhase <= Double.pi {
                // Sync source crossed zero, reset our phase
                phase = 0.0
            }
            lastSyncPhase = syncPhase
        }

        // Wrap phase efficiently
        if phase >= 2.0 * Double.pi {
            phase = phase.truncatingRemainder(dividingBy: 2.0 * Double.pi)
        }
    }
    
    private func applyPhaseDistortion(_ inputPhase: Double) -> Double {
        let normalizedPhase = inputPhase / (2.0 * Double.pi)
        let distortionAmount = Double(phaseDistortionAmount)
        
        // Apply phase distortion using a sigmoid-like curve
        let distorted = normalizedPhase + distortionAmount * sin(normalizedPhase * 2.0 * Double.pi)
        
        return distorted * 2.0 * Double.pi
    }
    
    private func applyModulation(_ inputPhase: Double, modulationInput: Float) -> Double {
        let modAmount = Double(modulationAmount)
        let modInput = Double(modulationInput)

        switch modulationType {
        case .none:
            return inputPhase

        case .ringModulation:
            // Ring modulation affects amplitude, not phase - handled in processSample
            return inputPhase

        case .hardSync:
            // Hard sync is handled in advancePhase()
            return inputPhase

        case .phaseModulation:
            return inputPhase + modAmount * modInput * 2.0 * Double.pi

        case .amplitudeModulation:
            // AM affects amplitude, not phase - handled in processSample
            return inputPhase
        }
    }

    /// Apply amplitude-based modulation (Ring Mod, AM) to the output sample
    private func applyAmplitudeModulation(_ sample: Float, modulationInput: Float) -> Float {
        let modAmount = modulationAmount
        let modInput = modulationInput

        switch modulationType {
        case .none, .hardSync, .phaseModulation:
            return sample

        case .ringModulation:
            // Classic ring modulation: multiply signals and blend with dry
            let ringModulated = sample * modInput
            return sample * (1.0 - modAmount) + ringModulated * modAmount

        case .amplitudeModulation:
            // Amplitude modulation: modulate the amplitude
            let modulator = 1.0 + modInput * modAmount
            return sample * modulator
        }
    }
    
    /// Get the current phase for sync purposes
    public var currentPhase: Double {
        return phase
    }
    
    /// Reset phase (for sync)
    public func resetPhase() {
        phase = 0.0
    }
}

// MARK: - WAVETONE Noise Generator

/// Enhanced noise generator for WAVETONE with multiple algorithms and SIMD optimization
public final class WavetoneNoiseGenerator: @unchecked Sendable {

    public enum NoiseType: String, CaseIterable, Codable {
        case white = "white"
        case pink = "pink"
        case brown = "brown"
        case blue = "blue"
        case violet = "violet"
        case filtered = "filtered"
        case granular = "granular"
        case crackle = "crackle"

        public var description: String {
            switch self {
            case .white: return "White Noise"
            case .pink: return "Pink Noise (1/f)"
            case .brown: return "Brown Noise (1/f²)"
            case .blue: return "Blue Noise (f)"
            case .violet: return "Violet Noise (f²)"
            case .filtered: return "Filtered Noise"
            case .granular: return "Granular Noise"
            case .crackle: return "Crackle Noise"
            }
        }
    }

    // MARK: - Properties

    public var noiseType: NoiseType = .white
    public var level: Float = 0.0
    public var baseFrequency: Float = 1000.0  // Center frequency for filtered noise
    public var width: Float = 1000.0          // Bandwidth for filtered noise
    public var grain: Float = 1.0             // Grain density (0.0-1.0)
    public var resonance: Float = 0.0         // Filter resonance (0.0-1.0)
    public var character: Float = 0.5         // Character control (0.0-1.0)

    // Internal state
    private let sampleRate: Double
    private var pinkNoiseState: [Float] = [Float](repeating: 0.0, count: 7)
    private var brownNoiseState: Float = 0.0
    private var blueNoiseState: Float = 0.0
    private var violetNoiseState: Float = 0.0
    private var filterState: (Float, Float, Float, Float) = (0.0, 0.0, 0.0, 0.0)  // 4-pole filter
    private var granularPhase: Float = 0.0
    private var crackleState: Float = 0.0
    private var lastSample: Float = 0.0
    
    public init(sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate
    }
    
    public func processSample() -> Float {
        guard level > 0.0 else { return 0.0 }

        let rawNoise: Float

        switch noiseType {
        case .white:
            rawNoise = generateWhiteNoise()
        case .pink:
            rawNoise = generatePinkNoise()
        case .brown:
            rawNoise = generateBrownNoise()
        case .blue:
            rawNoise = generateBlueNoise()
        case .violet:
            rawNoise = generateVioletNoise()
        case .filtered:
            rawNoise = generateFilteredNoise()
        case .granular:
            rawNoise = generateGranularNoise()
        case .crackle:
            rawNoise = generateCrackleNoise()
        }

        return rawNoise * level
    }

    /// Process multiple samples efficiently using SIMD when possible
    public func processBlock(output: inout [Float], blockSize: Int) {
        guard level > 0.0 && blockSize > 0 else {
            // Fill with silence
            for i in 0..<min(blockSize, output.count) {
                output[i] = 0.0
            }
            return
        }

        for i in 0..<min(blockSize, output.count) {
            output[i] = processSample()
        }
    }
    
    // MARK: - Noise Generation Methods

    private func generateWhiteNoise() -> Float {
        // High-quality white noise with uniform distribution
        return Float.random(in: -1.0...1.0)
    }

    private func generatePinkNoise() -> Float {
        let white = generateWhiteNoise()

        // Enhanced pink noise using Paul Kellett's method with character control
        let characterMod = 1.0 + (character - 0.5) * 0.2

        pinkNoiseState[0] = 0.99886 * pinkNoiseState[0] + white * 0.0555179 * characterMod
        pinkNoiseState[1] = 0.99332 * pinkNoiseState[1] + white * 0.0750759 * characterMod
        pinkNoiseState[2] = 0.96900 * pinkNoiseState[2] + white * 0.1538520 * characterMod
        pinkNoiseState[3] = 0.86650 * pinkNoiseState[3] + white * 0.3104856 * characterMod
        pinkNoiseState[4] = 0.55000 * pinkNoiseState[4] + white * 0.5329522 * characterMod
        pinkNoiseState[5] = -0.7616 * pinkNoiseState[5] - white * 0.0168980 * characterMod

        let pink = pinkNoiseState[0] + pinkNoiseState[1] + pinkNoiseState[2] +
                  pinkNoiseState[3] + pinkNoiseState[4] + pinkNoiseState[5] +
                  pinkNoiseState[6] + white * 0.5362

        pinkNoiseState[6] = white * 0.115926

        return pink * 0.11
    }
    
    private func generateBrownNoise() -> Float {
        let white = generateWhiteNoise()
        let integrationAmount = 0.02 * (1.0 + character * 0.5)  // Character affects integration
        brownNoiseState = (brownNoiseState + white * integrationAmount) * 0.99
        brownNoiseState = max(-1.0, min(1.0, brownNoiseState))
        return brownNoiseState * 3.5
    }

    private func generateBlueNoise() -> Float {
        let white = generateWhiteNoise()
        let differentiated = white - blueNoiseState
        blueNoiseState = white
        return differentiated * (0.5 + character * 0.5)
    }

    private func generateVioletNoise() -> Float {
        let blue = generateBlueNoise()
        let differentiated = blue - violetNoiseState
        violetNoiseState = blue
        return differentiated * (0.3 + character * 0.4)
    }
    
    private func generateFilteredNoise() -> Float {
        let white = generateWhiteNoise()

        // Enhanced 4-pole state variable filter with resonance
        let cutoff = min(0.49, baseFrequency / Float(sampleRate))
        let q = 0.5 + resonance * 4.5  // Resonance range 0.5 to 5.0
        let f = 2.0 * sin(Float.pi * cutoff)

        // State variable filter implementation
        filterState.0 += f * filterState.1
        let highpass = white - filterState.0 - q * filterState.1
        filterState.1 += f * highpass
        let bandpass = filterState.1
        let lowpass = filterState.0

        // Mix filter outputs based on character parameter
        let lowMix = (1.0 - character) * lowpass
        let bandMix = character * (1.0 - character) * 4.0 * bandpass
        let highMix = character * highpass

        return lowMix + bandMix + highMix
    }
    
    private func generateGranularNoise() -> Float {
        let white = generateWhiteNoise()

        // Enhanced granular noise with smooth grain envelopes
        let grainRate = grain * 100.0 + 1.0  // 1-101 Hz grain rate
        let grainPhaseIncrement = grainRate / Float(sampleRate)

        granularPhase += grainPhaseIncrement
        if granularPhase >= 1.0 {
            granularPhase -= 1.0
        }

        // Create grain envelope using character parameter
        let envelope: Float
        if character < 0.5 {
            // Square-like grains
            envelope = granularPhase < (character * 2.0) ? 1.0 : 0.0
        } else {
            // Smooth grains using sine envelope
            let smoothness = (character - 0.5) * 2.0
            envelope = sin(granularPhase * Float.pi) * smoothness + (1.0 - smoothness) * (granularPhase < 0.5 ? 1.0 : 0.0)
        }

        return white * envelope
    }

    private func generateCrackleNoise() -> Float {
        let white = generateWhiteNoise()

        // Crackle noise: sparse impulses with random timing
        let crackleRate = grain * 0.01 + 0.001  // Very sparse
        let trigger = Float.random(in: 0.0...1.0) < crackleRate

        if trigger {
            // Generate impulse with random amplitude and character-controlled decay
            crackleState = white * (0.5 + Float.random(in: 0.0...0.5))
        } else {
            // Decay existing crackle
            let decayRate = 0.95 + character * 0.04  // Character affects decay time
            crackleState *= decayRate
        }

        return crackleState
    }

    // MARK: - Utility Methods

    public func reset() {
        pinkNoiseState = [Float](repeating: 0.0, count: 7)
        brownNoiseState = 0.0
        blueNoiseState = 0.0
        violetNoiseState = 0.0
        filterState = (0.0, 0.0, 0.0, 0.0)
        granularPhase = 0.0
        crackleState = 0.0
        lastSample = 0.0
    }

    public func setParameters(type: NoiseType, level: Float, baseFreq: Float, width: Float, grain: Float, resonance: Float, character: Float) {
        self.noiseType = type
        self.level = max(0.0, min(1.0, level))
        self.baseFrequency = max(20.0, min(20000.0, baseFreq))
        self.width = max(10.0, min(10000.0, width))
        self.grain = max(0.0, min(1.0, grain))
        self.resonance = max(0.0, min(1.0, resonance))
        self.character = max(0.0, min(1.0, character))
    }
}

// MARK: - WAVETONE Voice Machine

/// Complete WAVETONE Voice Machine with dual oscillators, modulation, and noise
public final class WavetoneVoiceMachine: VoiceMachine, @unchecked Sendable {

    // MARK: - Core Components

    /// Dual oscillator system
    private var oscillator1: WavetoneOscillator
    private var oscillator2: WavetoneOscillator

    /// Noise generator
    private var noiseGenerator: WavetoneNoiseGenerator

    /// Wavetable manager for accessing wavetables
    private let wavetableManager: WavetableManager

    /// Modulation matrix for complex routing
    private var modulationMatrix: WavetoneModulationMatrix

    /// Envelope system for amplitude and modulation control
    private var envelopeSystem: WavetoneEnvelopeSystem

    // MARK: - Polyphony Management

    /// Individual voice instance for polyphonic operation
    private struct WavetoneVoice {
        let id: UUID
        var note: UInt8
        var velocity: UInt8
        var channel: UInt8
        var isActive: Bool
        var startTime: UInt64
        var oscillator1: WavetoneOscillator
        var oscillator2: WavetoneOscillator
        var noiseGenerator: WavetoneNoiseGenerator
        var envelopeSystem: WavetoneEnvelopeSystem
        var modulationMatrix: WavetoneModulationMatrix

        init(sampleRate: Double, note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64) {
            self.id = UUID()
            self.note = note
            self.velocity = velocity
            self.channel = channel
            self.isActive = true
            self.startTime = timestamp

            // Initialize voice-specific components
            self.oscillator1 = WavetoneOscillator(sampleRate: sampleRate)
            self.oscillator2 = WavetoneOscillator(sampleRate: sampleRate)
            self.noiseGenerator = WavetoneNoiseGenerator(sampleRate: sampleRate)
            self.envelopeSystem = WavetoneEnvelopeSystem(sampleRate: sampleRate)
            self.modulationMatrix = WavetoneModulationMatrix()

            // Set note frequency
            let frequency = 440.0 * pow(2.0, (Double(note) - 69.0) / 12.0)
            self.oscillator1.frequency = frequency
            self.oscillator2.frequency = frequency

            // Trigger envelopes
            let velocityScale = Float(velocity) / 127.0
            self.envelopeSystem.noteOn(velocity: velocityScale, noteNumber: Int(note))
            self.modulationMatrix.noteOn(velocity: velocityScale)
        }

        mutating func noteOff() {
            envelopeSystem.noteOff()
            modulationMatrix.noteOff()
        }

        mutating func updateFromGlobalParameters(_ globalParams: [String: Float]) {
            // Update oscillator parameters
            if let tuning1 = globalParams["osc1_tuning"] {
                oscillator1.setTuning(tuning1)
            }
            if let pos1 = globalParams["osc1_wavetable_pos"] {
                oscillator1.wavetablePosition = pos1
            }
            if let distortion1 = globalParams["osc1_phase_distortion"] {
                oscillator1.phaseDistortionAmount = distortion1
            }
            if let level1 = globalParams["osc1_level"] {
                oscillator1.amplitude = level1
            }

            // Similar for oscillator 2
            if let tuning2 = globalParams["osc2_tuning"] {
                oscillator2.setTuning(tuning2)
            }
            if let pos2 = globalParams["osc2_wavetable_pos"] {
                oscillator2.wavetablePosition = pos2
            }
            if let distortion2 = globalParams["osc2_phase_distortion"] {
                oscillator2.phaseDistortionAmount = distortion2
            }
            if let level2 = globalParams["osc2_level"] {
                oscillator2.amplitude = level2
            }

            // Update noise parameters
            if let noiseLevel = globalParams["noise_level"] {
                noiseGenerator.level = noiseLevel
            }
            if let noiseType = globalParams["noise_type"] {
                let noiseTypes: [WavetoneNoiseGenerator.NoiseType] = [.white, .pink, .brown, .blue, .violet, .filtered, .granular, .crackle]
                let index = Int(noiseType.rounded())
                if index >= 0 && index < noiseTypes.count {
                    noiseGenerator.noiseType = noiseTypes[index]
                }
            }

            // Update envelope parameters
            if let attack = globalParams["amp_attack"] {
                envelopeSystem.amplitudeEnvelope.config.attack.time = attack
            }
            if let decay = globalParams["amp_decay"] {
                envelopeSystem.amplitudeEnvelope.config.decay.time = decay
            }
            if let sustain = globalParams["amp_sustain"] {
                envelopeSystem.amplitudeEnvelope.config.sustain.level = sustain
            }
            if let release = globalParams["amp_release"] {
                envelopeSystem.amplitudeEnvelope.config.release.time = release
            }
        }
    }

    /// Active voices for polyphonic operation
    private var voices: [WavetoneVoice] = []

    /// Voice allocation tracking
    private var voiceAllocationQueue: [UUID] = []

    /// Global parameter cache for efficient voice updates
    private var globalParameterCache: [String: Float] = [:]

    // MARK: - Legacy Voice State (for backward compatibility)

    private var currentNote: UInt8 = 60
    private var currentVelocity: UInt8 = 100
    private var isNoteActive: Bool = false

    // MARK: - Audio Processing

    private let sampleRate: Double
    private var outputBuffer: [Float] = []
    private var tempBuffer: [Float] = []

    // MARK: - Initialization

    public override init(name: String = "WAVETONE", polyphony: Int = 16) {
        self.sampleRate = 44100.0

        // Initialize oscillators
        self.oscillator1 = WavetoneOscillator(sampleRate: sampleRate)
        self.oscillator2 = WavetoneOscillator(sampleRate: sampleRate)

        // Initialize noise generator
        self.noiseGenerator = WavetoneNoiseGenerator(sampleRate: sampleRate)

        // Initialize wavetable manager
        self.wavetableManager = WavetableManager()

        // Initialize modulation matrix
        self.modulationMatrix = WavetoneModulationMatrix()

        // Initialize envelope system
        self.envelopeSystem = WavetoneEnvelopeSystem(sampleRate: sampleRate)

        super.init(name: name, polyphony: polyphony)

        setupWavetoneParameters()
        setupDefaultWavetables()
        setupModulationRouting()

        // Initialize buffers
        outputBuffer = [Float](repeating: 0.0, count: 1024)
        tempBuffer = [Float](repeating: 0.0, count: 1024)
    }

    // MARK: - VoiceMachine Protocol Implementation

    public override func noteOn(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?) {
        let noteTimestamp = timestamp ?? UInt64(Date().timeIntervalSince1970 * 1000000)

        // Check if we have available voices
        if voices.count >= polyphony {
            // Voice stealing - find oldest voice or voice in release phase
            if let voiceToSteal = findVoiceToSteal() {
                removeVoice(voiceToSteal)
            } else {
                // No voice available and can't steal - ignore note
                return
            }
        }

        // Create new voice
        var newVoice = WavetoneVoice(
            sampleRate: sampleRate,
            note: note,
            velocity: velocity,
            channel: channel,
            timestamp: noteTimestamp
        )

        // Apply current global parameters to the new voice
        newVoice.updateFromGlobalParameters(globalParameterCache)

        // Set wavetables from global oscillators
        newVoice.oscillator1.currentWavetable = oscillator1.currentWavetable
        newVoice.oscillator2.currentWavetable = oscillator2.currentWavetable

        // Add voice to active voices
        voices.append(newVoice)
        voiceAllocationQueue.append(newVoice.id)

        // Update legacy state for backward compatibility
        currentNote = note
        currentVelocity = velocity
        isNoteActive = true

        super.noteOn(note: note, velocity: velocity, channel: channel, timestamp: timestamp)
    }

    public override func noteOff(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?) {
        // Find and release matching voices
        for i in 0..<voices.count {
            if voices[i].note == note && voices[i].channel == channel && voices[i].isActive {
                voices[i].noteOff()
                // Note: Don't remove voice immediately - let envelope finish release phase
            }
        }

        // Legacy compatibility
        if note == currentNote {
            isNoteActive = false
            modulationMatrix.noteOff()
            envelopeSystem.noteOff()
        }

        super.noteOff(note: note, velocity: velocity, channel: channel, timestamp: timestamp)
    }

    public override func allNotesOff() {
        // Release all active voices
        for i in 0..<voices.count {
            voices[i].noteOff()
        }

        // Legacy compatibility
        isNoteActive = false
        oscillator1.resetPhase()
        oscillator2.resetPhase()
        modulationMatrix.allNotesOff()
        envelopeSystem.allNotesOff()

        super.allNotesOff()
    }

    // MARK: - Voice Management Helper Methods

    /// Find a voice to steal when polyphony limit is reached
    private func findVoiceToSteal() -> UUID? {
        // First, try to find a voice in release phase
        for voice in voices {
            if !voice.isActive || voice.envelopeSystem.amplitudeEnvelope.currentPhase == .release {
                return voice.id
            }
        }

        // If no voice in release, steal the oldest voice
        return voiceAllocationQueue.first
    }

    /// Remove a voice from the active voices
    private func removeVoice(_ voiceId: UUID) {
        voices.removeAll { $0.id == voiceId }
        voiceAllocationQueue.removeAll { $0 == voiceId }
    }

    /// Clean up finished voices (voices that have completed their release phase)
    private func cleanupFinishedVoices() {
        let initialCount = voices.count

        voices.removeAll { (voice: WavetoneVoice) -> Bool in
            let envelope = voice.envelopeSystem.amplitudeEnvelope
            return envelope.currentPhase == .idle && envelope.level < 0.001
        }

        // Update allocation queue
        let activeVoiceIds = Set(voices.map { $0.id })
        voiceAllocationQueue.removeAll { !activeVoiceIds.contains($0) }

        // Update active voice count for base class
        activeVoices = voices.count
    }

    /// Update global parameter cache and propagate to all voices
    private func updateGlobalParameters() {
        // Collect current parameter values
        globalParameterCache.removeAll()
        for parameter in parameters.getAllParameters() {
            globalParameterCache[parameter.id] = parameters.getValue(parameter.id)
        }

        // Update all active voices with new parameters
        for i in 0..<voices.count {
            voices[i].updateFromGlobalParameters(globalParameterCache)
        }
    }

    /// Get current polyphony usage information
    public func getPolyphonyInfo() -> (active: Int, total: Int, usage: Float) {
        cleanupFinishedVoices()
        let activeCount = voices.count
        let usage = Float(activeCount) / Float(polyphony)
        return (active: activeCount, total: polyphony, usage: usage)
    }

    public override func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        let frameCount = input.frameCount
        let channelCount = input.channelCount

        // Ensure output buffer is large enough
        if outputBuffer.count < frameCount * channelCount {
            outputBuffer = [Float](repeating: 0.0, count: frameCount * channelCount)
            tempBuffer = [Float](repeating: 0.0, count: frameCount)
        }

        // Clear output buffer
        for i in 0..<frameCount * channelCount {
            outputBuffer[i] = 0.0
        }

        // Clear temp buffer
        for i in 0..<frameCount {
            tempBuffer[i] = 0.0
        }

        // Clean up finished voices
        cleanupFinishedVoices()

        // Update global parameters if needed
        updateGlobalParameters()

        // Process all active voices
        processPolyphonicAudio(frameCount: frameCount)

        // Interleave for stereo output
        for frame in 0..<frameCount {
            let sample = tempBuffer[frame]
            for channel in 0..<channelCount {
                outputBuffer[frame * channelCount + channel] = sample
            }
        }

        return AudioEngine.AudioBuffer(
            data: outputBuffer,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: input.sampleRate
        )
    }

    // MARK: - Audio Processing Implementation

    /// Process audio for all active voices (polyphonic)
    private func processPolyphonicAudio(frameCount: Int) {
        guard !voices.isEmpty else { return }

        // Process each voice and mix to output
        for voiceIndex in 0..<voices.count {
            processVoiceAudio(voiceIndex: voiceIndex, frameCount: frameCount)
        }

        // Apply master volume scaling to prevent clipping
        let voiceCount = Float(voices.count)
        let scalingFactor = 1.0 / max(1.0, sqrt(voiceCount))  // Gentle scaling to prevent clipping

        for i in 0..<frameCount {
            tempBuffer[i] *= scalingFactor
        }
    }

    /// Process audio for a single voice
    private func processVoiceAudio(voiceIndex: Int, frameCount: Int) {
        guard voiceIndex < voices.count else { return }

        let voice = voices[voiceIndex]

        // Process each sample for this voice
        for i in 0..<frameCount {
            var sample: Float = 0.0

            // Update voice modulation matrix
            voice.modulationMatrix.updateModulation()

            // Process voice envelope system
            let envelopeValues = voice.envelopeSystem.processEnvelopes()

            // Get modulation values for this voice
            let osc1ModInput = voice.modulationMatrix.getModulationValue(destination: .oscillator1)
            let osc2ModInput = voice.modulationMatrix.getModulationValue(destination: .oscillator2)
            let noiseModInput = voice.modulationMatrix.getModulationValue(destination: .noise)

            // Process oscillators
            let osc1Sample = voice.oscillator1.processSample(modulationInput: osc1ModInput)
            let osc2Sample = voice.oscillator2.processSample(modulationInput: osc2ModInput)

            // Mix oscillators with proper ring modulation handling
            var mixedSample: Float = 0.0

            if voice.oscillator1.modulationType == .ringModulation {
                // OSC1 ring modulates with OSC2
                let ringModulated = osc1Sample * osc2Sample
                let dryMix = osc1Sample * (1.0 - voice.oscillator1.modulationAmount)
                let wetMix = ringModulated * voice.oscillator1.modulationAmount
                mixedSample += dryMix + wetMix + osc2Sample
            } else if voice.oscillator2.modulationType == .ringModulation {
                // OSC2 ring modulates with OSC1
                let ringModulated = osc2Sample * osc1Sample
                let dryMix = osc2Sample * (1.0 - voice.oscillator2.modulationAmount)
                let wetMix = ringModulated * voice.oscillator2.modulationAmount
                mixedSample += dryMix + wetMix + osc1Sample
            } else {
                // No ring modulation, simple mix
                mixedSample += osc1Sample + osc2Sample
            }

            sample += mixedSample

            // Add noise with envelope modulation
            let noiseSample = voice.noiseGenerator.processSample()
            let envelopedNoise = noiseSample * envelopeValues.aux  // Use aux envelope for noise
            sample += envelopedNoise

            // Apply amplitude envelope
            sample *= envelopeValues.amplitude

            // Mix into main output buffer
            tempBuffer[i] += sample
        }
    }

    private func processAudioBlock(frameCount: Int) {
        // Update modulation matrix
        modulationMatrix.updateModulation()

        // Process envelope system
        let envelopeValues = envelopeSystem.processEnvelopes()

        // Get modulation values
        let osc1ModInput = modulationMatrix.getModulationValue(destination: .oscillator1)
        let osc2ModInput = modulationMatrix.getModulationValue(destination: .oscillator2)
        let noiseModInput = modulationMatrix.getModulationValue(destination: .noise)

        // Process each sample
        for i in 0..<frameCount {
            var sample: Float = 0.0

            // Process oscillator 1
            let osc1Sample = oscillator1.processSample(modulationInput: osc1ModInput)

            // Process oscillator 2 with potential modulation from oscillator 1
            var osc2ModulationInput = osc2ModInput

            // Apply ring modulation if enabled
            if oscillator2.modulationType == .ringModulation {
                osc2ModulationInput = osc1Sample * oscillator2.modulationAmount
            }

            let osc2Sample = oscillator2.processSample(modulationInput: osc2ModulationInput)

            // Mix oscillators with proper ring modulation handling
            var mixedSample: Float = 0.0

            // Check if either oscillator has ring modulation enabled
            if oscillator1.modulationType == .ringModulation {
                // OSC1 ring modulates with OSC2
                let ringModulated = osc1Sample * osc2Sample
                let dryMix = osc1Sample * (1.0 - oscillator1.modulationAmount)
                let wetMix = ringModulated * oscillator1.modulationAmount
                mixedSample += dryMix + wetMix + osc2Sample
            } else if oscillator2.modulationType == .ringModulation {
                // OSC2 ring modulates with OSC1
                let ringModulated = osc2Sample * osc1Sample
                let dryMix = osc2Sample * (1.0 - oscillator2.modulationAmount)
                let wetMix = ringModulated * oscillator2.modulationAmount
                mixedSample += dryMix + wetMix + osc1Sample
            } else {
                // No ring modulation, simple mix
                mixedSample += osc1Sample + osc2Sample
            }

            sample += mixedSample

            // Add noise with envelope modulation
            let noiseSample = noiseGenerator.processSample()
            let envelopedNoise = noiseSample * envelopeValues.aux  // Use aux envelope for noise
            sample += envelopedNoise

            // Apply amplitude envelope and master amplitude
            sample *= envelopeValues.amplitude
            tempBuffer[i] = sample * 0.5  // Scale down to prevent clipping
        }
    }

    // MARK: - Parameter Management

    private func setupWavetoneParameters() {
        // Oscillator 1 parameters
        parameters.addParameter(Parameter(
            id: "osc1_tuning",
            name: "OSC1 Tuning",
            description: "Oscillator 1 tuning in semitones",
            value: 0.0,
            minValue: -24.0,
            maxValue: 24.0,
            defaultValue: 0.0,
            unit: "semitones",
            category: .synthesis,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true
        ,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "osc1_wavetable_pos",
            name: "OSC1 Wavetable Position",
            description: "Position within the wavetable",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .synthesis,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "osc1_phase_distortion",
            name: "OSC1 Phase Distortion",
            description: "Amount of phase distortion",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .synthesis,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "osc1_level",
            name: "OSC1 Level",
            description: "Oscillator 1 output level",
            value: 0.8,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.8,
            unit: "",
            category: .synthesis,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        // Oscillator 2 parameters
        parameters.addParameter(Parameter(
            id: "osc2_tuning",
            name: "OSC2 Tuning",
            description: "Oscillator 2 tuning in semitones",
            value: 0.0,
            minValue: -24.0,
            maxValue: 24.0,
            defaultValue: 0.0,
            unit: "semitones",
            category: .synthesis,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "osc2_wavetable_pos",
            name: "OSC2 Wavetable Position",
            description: "Position within the wavetable",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .synthesis,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true
        ,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "osc2_phase_distortion",
            name: "OSC2 Phase Distortion",
            description: "Amount of phase distortion",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .synthesis,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true
        ,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "osc2_level",
            name: "OSC2 Level",
            description: "Oscillator 2 output level",
            value: 0.8,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.8,
            unit: "",
            category: .synthesis,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true
        ,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        // Modulation parameters
        parameters.addParameter(Parameter(
            id: "ring_mod_amount",
            name: "Ring Mod Amount",
            description: "Ring modulation amount",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .modulation,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true
        ,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "hard_sync_enable",
            name: "Hard Sync Enable",
            description: "Enable hard sync between oscillators",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .modulation,
            dataType: .boolean,
            scaling: .linear,
            isAutomatable: true
        ,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        // Noise parameters
        parameters.addParameter(Parameter(
            id: "noise_level",
            name: "Noise Level",
            description: "Noise generator level",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .synthesis,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true
        ,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "noise_type",
            name: "Noise Type",
            description: "Type of noise generation algorithm",
            value: 0.0,
            minValue: 0.0,
            maxValue: 7.0,
            defaultValue: 0.0,
            unit: "",
            category: .synthesis,
            dataType: .enumeration,
            scaling: .linear,
            isAutomatable: true
        ,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "noise_base_freq",
            name: "Noise Base Frequency",
            description: "Base frequency for filtered noise",
            value: 1000.0,
            minValue: 20.0,
            maxValue: 20000.0,
            defaultValue: 1000.0,
            unit: "Hz",
            category: .synthesis,
            dataType: .float,
            scaling: .exponential,
            isAutomatable: true
        ,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "noise_width",
            name: "Noise Width",
            description: "Bandwidth for filtered noise",
            value: 1000.0,
            minValue: 10.0,
            maxValue: 10000.0,
            defaultValue: 1000.0,
            unit: "Hz",
            category: .synthesis,
            dataType: .float,
            scaling: .exponential,
            isAutomatable: true
        ,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "noise_grain",
            name: "Noise Grain",
            description: "Grain density for granular/crackle noise",
            value: 0.5,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.5,
            unit: "",
            category: .synthesis,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true
        ,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "noise_resonance",
            name: "Noise Resonance",
            description: "Filter resonance for filtered noise",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .synthesis,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true
        ,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "noise_character",
            name: "Noise Character",
            description: "Character control for noise algorithms",
            value: 0.5,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.5,
            unit: "",
            category: .synthesis,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true
        ,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        // Amplitude envelope parameters
        parameters.addParameter(Parameter(
            id: "amp_attack",
            name: "Amp Attack",
            description: "Amplitude envelope attack time",
            value: 0.01,
            minValue: 0.001,
            maxValue: 10.0,
            defaultValue: 0.01,
            unit: "s",
            category: .envelope,
            dataType: .float,
            scaling: .exponential,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "amp_decay",
            name: "Amp Decay",
            description: "Amplitude envelope decay time",
            value: 0.3,
            minValue: 0.001,
            maxValue: 10.0,
            defaultValue: 0.3,
            unit: "s",
            category: .envelope,
            dataType: .float,
            scaling: .exponential,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "amp_sustain",
            name: "Amp Sustain",
            description: "Amplitude envelope sustain level",
            value: 0.7,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.7,
            unit: "",
            category: .envelope,
            dataType: .float,
            scaling: .exponential,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "amp_release",
            name: "Amp Release",
            description: "Amplitude envelope release time",
            value: 1.0,
            minValue: 0.001,
            maxValue: 10.0,
            defaultValue: 1.0,
            unit: "s",
            category: .envelope,
            dataType: .float,
            scaling: .exponential,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        // Modulation matrix parameters
        parameters.addParameter(Parameter(
            id: "mod_wheel",
            name: "Mod Wheel",
            description: "Modulation wheel input",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .modulation,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "aftertouch",
            name: "Aftertouch",
            description: "Channel aftertouch input",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .modulation,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "velocity",
            name: "Velocity",
            description: "Note velocity input",
            value: 1.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 1.0,
            unit: "",
            category: .modulation,
            dataType: .float,
            scaling: .linear,
            isAutomatable: false,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "lfo1_rate",
            name: "LFO1 Rate",
            description: "LFO 1 rate in Hz",
            value: 1.0,
            minValue: 0.01,
            maxValue: 100.0,
            defaultValue: 1.0,
            unit: "Hz",
            category: .modulation,
            dataType: .float,
            scaling: .exponential,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "lfo1_depth",
            name: "LFO1 Depth",
            description: "LFO 1 modulation depth",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .modulation,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        // Set parameter update callback
        parameters.setUpdateCallback { [weak self] parameterID, value in
            self?.handleParameterUpdate(parameterID: parameterID, value: value)
        }
    }

    private func handleParameterUpdate(parameterID: String, value: Float) {
        // Update global parameter cache
        globalParameterCache[parameterID] = value

        switch parameterID {
        case "osc1_tuning":
            oscillator1.setTuning(value)
            // Update all active voices
            for i in 0..<voices.count {
                voices[i].oscillator1.setTuning(value)
            }
        case "osc1_wavetable_pos":
            oscillator1.wavetablePosition = value
            for i in 0..<voices.count {
                voices[i].oscillator1.wavetablePosition = value
            }
        case "osc1_phase_distortion":
            oscillator1.phaseDistortionAmount = value
            for i in 0..<voices.count {
                voices[i].oscillator1.phaseDistortionAmount = value
            }
        case "osc1_level":
            oscillator1.amplitude = value
            for i in 0..<voices.count {
                voices[i].oscillator1.amplitude = value
            }
        case "osc2_tuning":
            oscillator2.setTuning(value)
            for i in 0..<voices.count {
                voices[i].oscillator2.setTuning(value)
            }
        case "osc2_wavetable_pos":
            oscillator2.wavetablePosition = value
            for i in 0..<voices.count {
                voices[i].oscillator2.wavetablePosition = value
            }
        case "osc2_phase_distortion":
            oscillator2.phaseDistortionAmount = value
            for i in 0..<voices.count {
                voices[i].oscillator2.phaseDistortionAmount = value
            }
        case "osc2_level":
            oscillator2.amplitude = value
            for i in 0..<voices.count {
                voices[i].oscillator2.amplitude = value
            }

        // Modulation parameters
        case "ring_mod_amount":
            oscillator1.setModulation(type: .ringModulation, amount: value)
        case "hard_sync_enable":
            if value > 0.5 {
                oscillator2.setModulation(type: .hardSync, amount: 1.0)
                oscillator2.syncSource = oscillator1
            } else {
                oscillator2.setModulation(type: .none, amount: 0.0)
                oscillator2.syncSource = nil
            }

        // Noise parameters
        case "noise_level":
            noiseGenerator.level = value
        case "noise_type":
            let noiseTypes: [WavetoneNoiseGenerator.NoiseType] = [.white, .pink, .brown, .blue, .violet, .filtered, .granular, .crackle]
            let index = Int(value.rounded())
            if index >= 0 && index < noiseTypes.count {
                noiseGenerator.noiseType = noiseTypes[index]
            }
        case "noise_base_freq":
            noiseGenerator.baseFrequency = value
        case "noise_width":
            noiseGenerator.width = value
        case "noise_grain":
            noiseGenerator.grain = value
        case "noise_resonance":
            noiseGenerator.resonance = value
        case "noise_character":
            noiseGenerator.character = value
        case "amp_attack":
            envelopeSystem.amplitudeEnvelope.config.attack.time = value
        case "amp_decay":
            envelopeSystem.amplitudeEnvelope.config.decay.time = value
        case "amp_sustain":
            envelopeSystem.amplitudeEnvelope.config.sustain.level = value
        case "amp_release":
            envelopeSystem.amplitudeEnvelope.config.release.time = value

        // Modulation matrix parameters
        case "mod_wheel":
            modulationMatrix.setModulationSource(.modWheel, value: value)
        case "aftertouch":
            modulationMatrix.setModulationSource(.aftertouch, value: value)
        case "velocity":
            modulationMatrix.setModulationSource(.velocity, value: value)
        case "lfo1_rate":
            modulationMatrix.setLFORate(1, rate: value)
        case "lfo1_depth":
            modulationMatrix.setLFODepth(1, depth: value)

        default:
            break
        }
    }

    private func setupDefaultWavetables() {
        // Set default wavetables for oscillators
        let wavetables = wavetableManager.getAllWavetables()
        if !wavetables.isEmpty {
            oscillator1.setWavetable(wavetables[0])
            if wavetables.count > 1 {
                oscillator2.setWavetable(wavetables[1])
            } else {
                oscillator2.setWavetable(wavetables[0])
            }
        }
    }

    private func setupModulationRouting() {
        // Configure default modulation routing
        modulationMatrix.setupDefaultRouting()
    }

    // MARK: - Preset Management

    /// Preset data structure for WAVETONE Voice Machine
    public struct WavetonePreset: Codable {
        public let name: String
        public let description: String
        public let category: String
        public let parameters: [String: Float]
        public let wavetable1Name: String?
        public let wavetable2Name: String?
        public let version: String
        public let createdDate: Date

        public init(name: String, description: String = "", category: String = "User",
                   parameters: [String: Float], wavetable1Name: String? = nil,
                   wavetable2Name: String? = nil) {
            self.name = name
            self.description = description
            self.category = category
            self.parameters = parameters
            self.wavetable1Name = wavetable1Name
            self.wavetable2Name = wavetable2Name
            self.version = "1.0"
            self.createdDate = Date()
        }
    }

    /// Save current state as a preset
    public func savePreset(name: String, description: String = "", category: String = "User") -> WavetonePreset {
        var parameterValues: [String: Float] = [:]

        // Collect all current parameter values
        for parameter in parameters.getAllParameters() {
            parameterValues[parameter.id] = parameters.getValue(parameter.id)
        }

        // Get current wavetable names
        let wavetable1Name = oscillator1.currentWavetable?.metadata.name
        let wavetable2Name = oscillator2.currentWavetable?.metadata.name

        return WavetonePreset(
            name: name,
            description: description,
            category: category,
            parameters: parameterValues,
            wavetable1Name: wavetable1Name,
            wavetable2Name: wavetable2Name
        )
    }

    /// Load a preset
    public func loadPreset(_ preset: WavetonePreset) {
        // Load parameter values
        for (parameterID, value) in preset.parameters {
            parameters.setValue(parameterID, value: value)
        }

        // Load wavetables if specified
        if let wavetable1Name = preset.wavetable1Name {
            if let wavetable = wavetableManager.getWavetable(named: wavetable1Name) {
                oscillator1.currentWavetable = wavetable
            }
        }

        if let wavetable2Name = preset.wavetable2Name {
            if let wavetable = wavetableManager.getWavetable(named: wavetable2Name) {
                oscillator2.currentWavetable = wavetable
            }
        }
    }

    /// Get factory presets
    public static func getFactoryPresets() -> [WavetonePreset] {
        return [
            // Lead preset
            WavetonePreset(
                name: "Classic Lead",
                description: "Bright lead sound with filter sweep",
                category: "Lead",
                parameters: [
                    "osc1_level": 0.8,
                    "osc2_level": 0.6,
                    "osc2_tuning": 7.0,  // Perfect fifth
                    "amp_attack": 0.01,
                    "amp_decay": 0.3,
                    "amp_sustain": 0.7,
                    "amp_release": 0.5,
                    "lfo1_rate": 5.0,
                    "lfo1_depth": 0.3
                ]
            ),

            // Pad preset
            WavetonePreset(
                name: "Warm Pad",
                description: "Evolving pad with slow attack",
                category: "Pad",
                parameters: [
                    "osc1_level": 0.7,
                    "osc2_level": 0.7,
                    "osc2_tuning": -12.0,  // One octave down
                    "amp_attack": 2.0,
                    "amp_decay": 1.0,
                    "amp_sustain": 0.8,
                    "amp_release": 3.0,
                    "lfo1_rate": 0.5,
                    "lfo1_depth": 0.2
                ]
            ),

            // Bass preset
            WavetonePreset(
                name: "Deep Bass",
                description: "Rich bass sound with sub oscillator",
                category: "Bass",
                parameters: [
                    "osc1_level": 0.9,
                    "osc2_level": 0.5,
                    "osc2_tuning": -24.0,  // Two octaves down
                    "amp_attack": 0.001,
                    "amp_decay": 0.2,
                    "amp_sustain": 0.9,
                    "amp_release": 0.3,
                    "lfo1_rate": 2.0,
                    "lfo1_depth": 0.1
                ]
            ),

            // Pluck preset
            WavetonePreset(
                name: "Bright Pluck",
                description: "Percussive pluck with fast decay",
                category: "Pluck",
                parameters: [
                    "osc1_level": 0.8,
                    "osc2_level": 0.4,
                    "osc2_tuning": 12.0,  // One octave up
                    "amp_attack": 0.001,
                    "amp_decay": 0.1,
                    "amp_sustain": 0.0,
                    "amp_release": 0.2,
                    "lfo1_rate": 0.0,
                    "lfo1_depth": 0.0
                ]
            ),

            // Noise preset
            WavetonePreset(
                name: "Wind Texture",
                description: "Filtered noise for ambient textures",
                category: "Texture",
                parameters: [
                    "osc1_level": 0.3,
                    "osc2_level": 0.0,
                    "noise_level": 0.8,
                    "noise_type": 5.0,  // Filtered noise
                    "noise_base_freq": 2000.0,
                    "noise_width": 1000.0,
                    "noise_resonance": 0.3,
                    "noise_character": 0.7,
                    "amp_attack": 1.0,
                    "amp_decay": 2.0,
                    "amp_sustain": 0.6,
                    "amp_release": 2.0
                ]
            )
        ]
    }

    /// Initialize with default preset
    public func loadDefaultPreset() {
        let defaultPreset = WavetonePreset(
            name: "Default",
            description: "Default WAVETONE settings",
            category: "Init",
            parameters: [
                "osc1_level": 0.8,
                "osc2_level": 0.0,
                "osc1_tuning": 0.0,
                "osc2_tuning": 0.0,
                "amp_attack": 0.01,
                "amp_decay": 0.3,
                "amp_sustain": 0.7,
                "amp_release": 1.0,
                "noise_level": 0.0
            ]
        )
        loadPreset(defaultPreset)
    }
}
