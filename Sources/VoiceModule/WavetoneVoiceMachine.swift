// WavetoneVoiceMachine.swift
// DigitonePad - VoiceModule
//
// WAVETONE Voice Machine with dual oscillators, wavetable synthesis,
// phase distortion, ring modulation, hard sync, and flexible noise design

import Foundation
import Accelerate
import MachineProtocols
import AudioEngine
import AVFoundation
import simd

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

// MARK: - WAVETONE Voice Machine Parameters

/// Complete parameter set for WAVETONE Voice Machine
public struct WavetoneVoiceMachineParameters: Sendable {
    
    // MARK: - Oscillator Parameters
    public var oscillator1Wavetable: Int = 0        // Wavetable index (0-127)
    public var oscillator1Tune: Float = 0.0         // Semitones (-24 to +24)
    public var oscillator1FineTune: Float = 0.0     // Cents (-50 to +50)
    public var oscillator1Level: Float = 0.8        // Output level (0.0 - 1.0)
    public var oscillator1PhaseDistortion: Float = 0.0  // Phase distortion amount (0.0 - 1.0)
    
    public var oscillator2Wavetable: Int = 1        // Wavetable index (0-127)
    public var oscillator2Tune: Float = 0.0         // Semitones (-24 to +24)
    public var oscillator2FineTune: Float = 0.0     // Cents (-50 to +50)
    public var oscillator2Level: Float = 0.8        // Output level (0.0 - 1.0)
    public var oscillator2PhaseDistortion: Float = 0.0  // Phase distortion amount (0.0 - 1.0)
    
    // MARK: - Modulation Parameters
    public var ringModulationDepth: Float = 0.0     // Ring modulation depth (0.0 - 1.0)
    public var hardSyncAmount: Float = 0.0          // Hard sync amount (0.0 - 1.0)
    public var modulationMode: Int = 0              // 0=Off, 1=Ring, 2=Hard Sync, 3=FM, 4=AM
    
    // MARK: - Noise Parameters
    public var noiseType: Int = 0                   // Noise type (0-9, see NoiseType enum)
    public var noiseLevel: Float = 0.0              // Noise level (0.0 - 1.0)
    public var noiseFilterCutoff: Float = 1000.0    // Noise filter frequency (20Hz - 20kHz)
    public var noiseFilterResonance: Float = 0.0    // Noise filter resonance (0.0 - 1.0)
    
    // MARK: - Envelope Parameters (3 envelopes: Amp, Filter, Aux)
    public var ampEnvelopeAttack: Float = 0.01      // Attack time (0.001 - 10.0 seconds)
    public var ampEnvelopeDecay: Float = 0.3        // Decay time (0.001 - 10.0 seconds)
    public var ampEnvelopeSustain: Float = 0.7      // Sustain level (0.0 - 1.0)
    public var ampEnvelopeRelease: Float = 0.5      // Release time (0.001 - 10.0 seconds)
    
    public var filterEnvelopeAttack: Float = 0.005  // Attack time (0.001 - 10.0 seconds)
    public var filterEnvelopeDecay: Float = 2.0     // Decay time (0.001 - 10.0 seconds)
    public var filterEnvelopeSustain: Float = 0.2   // Sustain level (0.0 - 1.0)
    public var filterEnvelopeRelease: Float = 1.5   // Release time (0.001 - 10.0 seconds)
    
    public var auxEnvelopeAttack: Float = 0.5       // Attack time (0.001 - 10.0 seconds)
    public var auxEnvelopeDecay: Float = 0.8        // Decay time (0.001 - 10.0 seconds)
    public var auxEnvelopeSustain: Float = 0.8      // Sustain level (0.0 - 1.0)
    public var auxEnvelopeRelease: Float = 1.2      // Release time (0.001 - 10.0 seconds)
    
    // MARK: - Global Parameters
    public var masterVolume: Float = 0.8            // Master volume (0.0 - 1.0)
    public var masterTune: Float = 0.0              // Master tuning (-100 to +100 cents)
    public var polyphony: Int = 8                   // Max voices (1-16)
    public var portamento: Float = 0.0              // Portamento time (0.0 - 5.0 seconds)
    public var velocitySensitivity: Float = 0.5     // Velocity sensitivity (0.0 - 1.0)
    public var keyTracking: Float = 0.0             // Key tracking (-1.0 to +1.0)
    
    public init() {
        // Default values are set in property declarations
    }
}

// MARK: - Parameter Management System

/// Parameter smoothing and automation system for WAVETONE
@unchecked Sendable
public final class WavetoneParameterManager {
    
    // MARK: - Properties
    
    private var currentParameters: WavetoneVoiceMachineParameters
    private var targetParameters: WavetoneVoiceMachineParameters
    private var parameterSmoothers: [String: ParameterSmoother] = [:]
    private let sampleRate: Float
    
    // Parameter update callbacks
    private var updateCallbacks: [(WavetoneVoiceMachineParameters) -> Void] = []
    
    // Thread safety
    private let parameterQueue = DispatchQueue(label: "wavetone.parameters", qos: .userInteractive)
    
    // MARK: - Initialization
    
    public init(sampleRate: Float) {
        self.sampleRate = sampleRate
        self.currentParameters = WavetoneVoiceMachineParameters()
        self.targetParameters = WavetoneVoiceMachineParameters()
        
        setupParameterSmoothers()
    }
    
    // MARK: - Public Interface
    
    /// Update a parameter with smoothing
    public func setParameter<T: Numeric>(_ keyPath: WritableKeyPath<WavetoneVoiceMachineParameters, T>, value: T) {
        parameterQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.targetParameters[keyPath: keyPath] = value
            
            // Trigger smoothing for this parameter
            let parameterName = String(describing: keyPath)
            if let smoother = self.parameterSmoothers[parameterName] {
                if let floatValue = value as? Float {
                    smoother.setTarget(floatValue)
                }
            }
        }
    }
    
    /// Get current parameter value
    public func getParameter<T>(_ keyPath: KeyPath<WavetoneVoiceMachineParameters, T>) -> T {
        return parameterQueue.sync {
            return currentParameters[keyPath: keyPath]
        }
    }
    
    /// Process parameter smoothing (call from audio thread)
    public func processParameterSmoothing() -> WavetoneVoiceMachineParameters {
        // Update smoothed parameters
        for (parameterName, smoother) in parameterSmoothers {
            let smoothedValue = smoother.getSmoothedValue()
            updateParameterByName(parameterName, value: smoothedValue)
        }
        
        return currentParameters
    }
    
    /// Add parameter update callback
    public func addUpdateCallback(_ callback: @escaping (WavetoneVoiceMachineParameters) -> Void) {
        parameterQueue.async { [weak self] in
            self?.updateCallbacks.append(callback)
        }
    }
    
    /// Load preset parameters
    public func loadPreset(_ parameters: WavetoneVoiceMachineParameters) {
        parameterQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.targetParameters = parameters
            self.currentParameters = parameters
            
            // Update all smoothers to new values
            self.updateAllSmoothers()
            
            // Notify callbacks
            for callback in self.updateCallbacks {
                callback(parameters)
            }
        }
    }
    
    /// Get current parameters (thread-safe)
    public func getCurrentParameters() -> WavetoneVoiceMachineParameters {
        return parameterQueue.sync {
            return currentParameters
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupParameterSmoothers() {
        // Oscillator parameters (fast smoothing for audio-rate changes)
        parameterSmoothers["oscillator1Level"] = ParameterSmoother(sampleRate: sampleRate, smoothingTime: 0.005)
        parameterSmoothers["oscillator2Level"] = ParameterSmoother(sampleRate: sampleRate, smoothingTime: 0.005)
        parameterSmoothers["oscillator1PhaseDistortion"] = ParameterSmoother(sampleRate: sampleRate, smoothingTime: 0.01)
        parameterSmoothers["oscillator2PhaseDistortion"] = ParameterSmoother(sampleRate: sampleRate, smoothingTime: 0.01)
        
        // Modulation parameters
        parameterSmoothers["ringModulationDepth"] = ParameterSmoother(sampleRate: sampleRate, smoothingTime: 0.01)
        parameterSmoothers["hardSyncAmount"] = ParameterSmoother(sampleRate: sampleRate, smoothingTime: 0.01)
        
        // Noise parameters
        parameterSmoothers["noiseLevel"] = ParameterSmoother(sampleRate: sampleRate, smoothingTime: 0.005)
        parameterSmoothers["noiseFilterCutoff"] = ParameterSmoother(sampleRate: sampleRate, smoothingTime: 0.02)
        parameterSmoothers["noiseFilterResonance"] = ParameterSmoother(sampleRate: sampleRate, smoothingTime: 0.01)
        
        // Envelope parameters (slower smoothing to avoid artifacts)
        parameterSmoothers["ampEnvelopeAttack"] = ParameterSmoother(sampleRate: sampleRate, smoothingTime: 0.05)
        parameterSmoothers["ampEnvelopeDecay"] = ParameterSmoother(sampleRate: sampleRate, smoothingTime: 0.05)
        parameterSmoothers["ampEnvelopeSustain"] = ParameterSmoother(sampleRate: sampleRate, smoothingTime: 0.05)
        parameterSmoothers["ampEnvelopeRelease"] = ParameterSmoother(sampleRate: sampleRate, smoothingTime: 0.05)
        
        // Global parameters
        parameterSmoothers["masterVolume"] = ParameterSmoother(sampleRate: sampleRate, smoothingTime: 0.01)
        parameterSmoothers["masterTune"] = ParameterSmoother(sampleRate: sampleRate, smoothingTime: 0.1)
        parameterSmoothers["portamento"] = ParameterSmoother(sampleRate: sampleRate, smoothingTime: 0.02)
    }
    
    private func updateParameterByName(_ name: String, value: Float) {
        switch name {
        case "oscillator1Level": currentParameters.oscillator1Level = value
        case "oscillator2Level": currentParameters.oscillator2Level = value
        case "oscillator1PhaseDistortion": currentParameters.oscillator1PhaseDistortion = value
        case "oscillator2PhaseDistortion": currentParameters.oscillator2PhaseDistortion = value
        case "ringModulationDepth": currentParameters.ringModulationDepth = value
        case "hardSyncAmount": currentParameters.hardSyncAmount = value
        case "noiseLevel": currentParameters.noiseLevel = value
        case "noiseFilterCutoff": currentParameters.noiseFilterCutoff = value
        case "noiseFilterResonance": currentParameters.noiseFilterResonance = value
        case "ampEnvelopeAttack": currentParameters.ampEnvelopeAttack = value
        case "ampEnvelopeDecay": currentParameters.ampEnvelopeDecay = value
        case "ampEnvelopeSustain": currentParameters.ampEnvelopeSustain = value
        case "ampEnvelopeRelease": currentParameters.ampEnvelopeRelease = value
        case "masterVolume": currentParameters.masterVolume = value
        case "masterTune": currentParameters.masterTune = value
        case "portamento": currentParameters.portamento = value
        default: break
        }
    }
    
    private func updateAllSmoothers() {
        parameterSmoothers["oscillator1Level"]?.setTarget(currentParameters.oscillator1Level)
        parameterSmoothers["oscillator2Level"]?.setTarget(currentParameters.oscillator2Level)
        parameterSmoothers["oscillator1PhaseDistortion"]?.setTarget(currentParameters.oscillator1PhaseDistortion)
        parameterSmoothers["oscillator2PhaseDistortion"]?.setTarget(currentParameters.oscillator2PhaseDistortion)
        parameterSmoothers["ringModulationDepth"]?.setTarget(currentParameters.ringModulationDepth)
        parameterSmoothers["hardSyncAmount"]?.setTarget(currentParameters.hardSyncAmount)
        parameterSmoothers["noiseLevel"]?.setTarget(currentParameters.noiseLevel)
        parameterSmoothers["noiseFilterCutoff"]?.setTarget(currentParameters.noiseFilterCutoff)
        parameterSmoothers["noiseFilterResonance"]?.setTarget(currentParameters.noiseFilterResonance)
        parameterSmoothers["ampEnvelopeAttack"]?.setTarget(currentParameters.ampEnvelopeAttack)
        parameterSmoothers["ampEnvelopeDecay"]?.setTarget(currentParameters.ampEnvelopeDecay)
        parameterSmoothers["ampEnvelopeSustain"]?.setTarget(currentParameters.ampEnvelopeSustain)
        parameterSmoothers["ampEnvelopeRelease"]?.setTarget(currentParameters.ampEnvelopeRelease)
        parameterSmoothers["masterVolume"]?.setTarget(currentParameters.masterVolume)
        parameterSmoothers["masterTune"]?.setTarget(currentParameters.masterTune)
        parameterSmoothers["portamento"]?.setTarget(currentParameters.portamento)
    }
}

// MARK: - WAVETONE Voice

/// Individual voice for WAVETONE synthesis
@unchecked Sendable
public final class WavetoneVoice {
    
    // MARK: - Properties
    
    private let sampleRate: Float
    private var isActive: Bool = false
    private var noteNumber: Int = 60
    private var velocity: Float = 1.0
    private var frequency: Float = 440.0
    
    // Synthesis components (using existing implementations)
    private var wavetableData1: WavetableData
    private var wavetableData2: WavetableData
    private var oscillatorModulation: OscillatorModulationSystem
    private var noiseGenerator: NoiseGenerator
    private var envelopeSystem: WavetoneEnvelopeSystem
    
    // Audio processing buffers
    private var oscillator1Buffer: [Float]
    private var oscillator2Buffer: [Float]
    private var noiseBuffer: [Float]
    private var mixBuffer: [Float]
    
    private let bufferSize: Int = 64
    
    // MARK: - Initialization
    
    public init(sampleRate: Float) {
        self.sampleRate = sampleRate
        
        // Initialize synthesis components
        self.wavetableData1 = WavetableData.createSineProgression(frameCount: 64)
        self.wavetableData2 = WavetableData.createSawtoothProgression(frameCount: 32)
        self.oscillatorModulation = OscillatorModulationSystem(sampleRate: sampleRate)
        self.noiseGenerator = NoiseGenerator(sampleRate: sampleRate)
        self.envelopeSystem = WavetoneEnvelopeSystem(sampleRate: sampleRate)
        
        // Initialize audio buffers
        self.oscillator1Buffer = Array(repeating: 0.0, count: bufferSize)
        self.oscillator2Buffer = Array(repeating: 0.0, count: bufferSize)
        self.noiseBuffer = Array(repeating: 0.0, count: bufferSize)
        self.mixBuffer = Array(repeating: 0.0, count: bufferSize)
    }
    
    // MARK: - Public Interface
    
    /// Start voice with note on
    public func noteOn(noteNumber: Int, velocity: Float) {
        self.noteNumber = noteNumber
        self.velocity = velocity
        self.frequency = midiNoteToFrequency(noteNumber)
        self.isActive = true
        
        // Trigger envelopes
        envelopeSystem.noteOn(velocity: velocity, noteNumber: noteNumber)
    }
    
    /// Stop voice with note off
    public func noteOff() {
        envelopeSystem.noteOff()
    }
    
    /// Process audio for this voice
    public func processAudio(parameters: WavetoneVoiceMachineParameters, outputBuffer: inout [Float], blockSize: Int) {
        guard isActive else {
            // Clear output buffer
            for i in 0..<min(blockSize, outputBuffer.count) {
                outputBuffer[i] = 0.0
            }
            return
        }
        
        let actualBlockSize = min(blockSize, bufferSize)
        
        // Process envelopes
        let envelopeValues = envelopeSystem.processEnvelopes()
        let ampEnvelope = envelopeValues[.amplitude] ?? 0.0
        
        // Check if voice should be deactivated
        if !envelopeSystem.isActive {
            isActive = false
            for i in 0..<actualBlockSize {
                outputBuffer[i] = 0.0
            }
            return
        }
        
        // Generate oscillator 1
        generateOscillator1(parameters: parameters, blockSize: actualBlockSize)
        
        // Generate oscillator 2
        generateOscillator2(parameters: parameters, blockSize: actualBlockSize)
        
        // Apply oscillator modulation (ring mod, hard sync, etc.)
        applyOscillatorModulation(parameters: parameters, blockSize: actualBlockSize)
        
        // Generate noise
        generateNoise(parameters: parameters, blockSize: actualBlockSize)
        
        // Mix all sources
        mixSources(parameters: parameters, blockSize: actualBlockSize)
        
        // Apply amplitude envelope and master volume
        for i in 0..<actualBlockSize {
            outputBuffer[i] = mixBuffer[i] * ampEnvelope * parameters.masterVolume * velocity
        }
    }
    
    /// Check if voice is active
    public var active: Bool {
        return isActive
    }
    
    /// Get voice note number
    public var currentNoteNumber: Int {
        return noteNumber
    }
    
    // MARK: - Private Implementation
    
    private func generateOscillator1(parameters: WavetoneVoiceMachineParameters, blockSize: Int) {
        let tuning = parameters.oscillator1Tune + (parameters.oscillator1FineTune / 100.0)
        let tunedFrequency = frequency * pow(2.0, tuning / 12.0)
        
        // Generate wavetable audio with phase distortion
        for i in 0..<blockSize {
            let phase = Float(i) / Float(blockSize) // Simplified phase calculation
            let distortedPhase = applyPhaseDistortion(phase: phase, amount: parameters.oscillator1PhaseDistortion)
            oscillator1Buffer[i] = wavetableData1.synthesize(phase: distortedPhase, frequency: tunedFrequency)
        }
    }
    
    private func generateOscillator2(parameters: WavetoneVoiceMachineParameters, blockSize: Int) {
        let tuning = parameters.oscillator2Tune + (parameters.oscillator2FineTune / 100.0)
        let tunedFrequency = frequency * pow(2.0, tuning / 12.0)
        
        // Generate wavetable audio with phase distortion
        for i in 0..<blockSize {
            let phase = Float(i) / Float(blockSize) // Simplified phase calculation
            let distortedPhase = applyPhaseDistortion(phase: phase, amount: parameters.oscillator2PhaseDistortion)
            oscillator2Buffer[i] = wavetableData2.synthesize(phase: distortedPhase, frequency: tunedFrequency)
        }
    }
    
    private func applyOscillatorModulation(parameters: WavetoneVoiceMachineParameters, blockSize: Int) {
        switch parameters.modulationMode {
        case 1: // Ring Modulation
            for i in 0..<blockSize {
                let modulated = oscillatorModulation.processRingModulation(
                    carrier: oscillator1Buffer[i],
                    modulator: oscillator2Buffer[i],
                    depth: parameters.ringModulationDepth
                )
                oscillator1Buffer[i] = modulated
            }
            
        case 2: // Hard Sync
            for i in 0..<blockSize {
                let synced = oscillatorModulation.processHardSync(
                    slave: oscillator1Buffer[i],
                    master: oscillator2Buffer[i],
                    amount: parameters.hardSyncAmount
                )
                oscillator1Buffer[i] = synced
            }
            
        default: // No modulation
            break
        }
    }
    
    private func generateNoise(parameters: WavetoneVoiceMachineParameters, blockSize: Int) {
        if parameters.noiseLevel > 0.001 {
            noiseGenerator.processBlock(outputBuffer: &noiseBuffer, blockSize: blockSize)
            
            // Apply noise level
            for i in 0..<blockSize {
                noiseBuffer[i] *= parameters.noiseLevel
            }
        } else {
            // Clear noise buffer
            for i in 0..<blockSize {
                noiseBuffer[i] = 0.0
            }
        }
    }
    
    private func mixSources(parameters: WavetoneVoiceMachineParameters, blockSize: Int) {
        // Mix oscillators and noise
        for i in 0..<blockSize {
            mixBuffer[i] = (oscillator1Buffer[i] * parameters.oscillator1Level) +
                          (oscillator2Buffer[i] * parameters.oscillator2Level) +
                          noiseBuffer[i]
            
            // Apply soft clipping to prevent harsh distortion
            mixBuffer[i] = tanh(mixBuffer[i])
        }
    }
    
    private func applyPhaseDistortion(phase: Float, amount: Float) -> Float {
        if amount <= 0.001 {
            return phase
        }
        
        // Simple sine-based phase distortion
        let distorted = phase + (amount * sin(phase * 2.0 * .pi))
        return fmod(distorted, 1.0)
    }
    
    private func midiNoteToFrequency(_ noteNumber: Int) -> Float {
        return 440.0 * pow(2.0, Float(noteNumber - 69) / 12.0)
    }
}

// MARK: - WAVETONE Voice Machine

/// Complete WAVETONE Voice Machine implementation
/// Combines wavetable synthesis, phase distortion, oscillator modulation, noise generation, and envelopes
@unchecked Sendable
public final class WavetoneVoiceMachine: VoiceMachine {
    
    // MARK: - Parameter Management System
    public struct WavetoneParameters {
        // Master Controls
        public var masterVolume: Float = 0.8
        public var masterTune: Float = 0.0        // -12 to +12 semitones
        public var portamento: Float = 0.0        // 0.0 to 5.0 seconds
        public var pitchBend: Float = 0.0         // -2.0 to +2.0 semitones
        
        // Oscillator 1 (Wavetable)
        public var osc1Level: Float = 0.8
        public var osc1Tune: Float = 0.0          // -24 to +24 semitones
        public var osc1FineTune: Float = 0.0      // -50 to +50 cents
        public var osc1WavetableIndex: Int = 0
        public var osc1WavePosition: Float = 0.0  // 0.0 to 1.0
        public var osc1PhaseDistortion: Float = 0.0  // 0.0 to 1.0
        
        // Oscillator 2 (Wavetable)
        public var osc2Level: Float = 0.8
        public var osc2Tune: Float = 0.0          // -24 to +24 semitones
        public var osc2FineTune: Float = 0.0      // -50 to +50 cents
        public var osc2WavetableIndex: Int = 1
        public var osc2WavePosition: Float = 0.0  // 0.0 to 1.0
        public var osc2PhaseDistortion: Float = 0.0  // 0.0 to 1.0
        
        // Modulation
        public var ringModulation: Float = 0.0    // 0.0 to 1.0
        public var hardSync: Float = 0.0          // 0.0 to 1.0
        public var syncDirection: Int = 1         // 1 = osc1->osc2, 2 = osc2->osc1
        
        // Noise Generator
        public var noiseType: Int = 0             // NoiseType index
        public var noiseLevel: Float = 0.0        // 0.0 to 1.0
        public var noiseFilter: Float = 0.5       // 0.0 to 1.0 (filter frequency)
        public var noiseResonance: Float = 0.0    // 0.0 to 1.0
        
        // Envelope Parameters (Amplitude)
        public var ampEnvAttack: Float = 0.1
        public var ampEnvDecay: Float = 0.2
        public var ampEnvSustain: Float = 0.7
        public var ampEnvRelease: Float = 0.3
        public var ampEnvVelocity: Float = 0.5
        
        // Envelope Parameters (Filter)
        public var filterEnvAttack: Float = 0.05
        public var filterEnvDecay: Float = 0.8
        public var filterEnvSustain: Float = 0.3
        public var filterEnvRelease: Float = 2.0
        public var filterEnvAmount: Float = 0.0   // -1.0 to 1.0
        
        // LFO
        public var lfoRate: Float = 1.0           // 0.1 to 20.0 Hz
        public var lfoDepth: Float = 0.0          // 0.0 to 1.0
        public var lfoShape: Int = 0              // 0=sine, 1=triangle, 2=square, 3=saw
        public var lfoSync: Bool = false
        public var lfoTarget: Int = 0             // 0=pitch, 1=filter, 2=amplitude, 3=wavetable
        
        public init() {}
    }
    
    // MARK: - Voice State
    private struct VoiceState {
        var isActive: Bool = false
        var noteNumber: Int = 60
        var velocity: Float = 1.0
        var frequency: Float = 440.0
        var phase1: Float = 0.0
        var phase2: Float = 0.0
        var envelopeState: WavetoneEnvelopeState = WavetoneEnvelopeState()
    }
    
    private struct WavetoneEnvelopeState {
        var ampEnvelope: Float = 0.0
        var filterEnvelope: Float = 0.0
        var ampPhase: EnvelopePhase = .idle
        var filterPhase: EnvelopePhase = .idle
        var ampTime: Float = 0.0
        var filterTime: Float = 0.0
        var isReleasing: Bool = false
    }
    
    // MARK: - Properties
    private let maxVoices = 16
    private var voices: [VoiceState]
    private var parameters: WavetoneParameters
    private var parameterSmoothers: [String: ParameterSmoother]
    private let sampleRate: Float
    
    // Audio components
    private var wavetables: [WavetableData]
    private var noiseGenerator: WavetoneNoiseGenerator
    private var envelopeSystem: WavetoneMultiEnvelopeSystem
    
    // Audio buffers
    private var voiceBuffer: [Float]
    private var mixBuffer: [Float]
    private var tempBuffer: [Float]
    private let blockSize = 128
    
    // Performance monitoring
    private var cpuUsage: Float = 0.0
    private var processingTime: CFTimeInterval = 0.0
    private var activeVoiceCount: Int = 0
    
    // Thread safety
    private let voiceQueue = DispatchQueue(label: "wavetone.voices", qos: .userInteractive)
    private let parameterQueue = DispatchQueue(label: "wavetone.parameters", qos: .userInteractive)
    
    // MARK: - Initialization
    
    public override init(sampleRate: Float = 44100.0) {
        self.sampleRate = sampleRate
        self.voices = Array(repeating: VoiceState(), count: maxVoices)
        self.parameters = WavetoneParameters()
        self.parameterSmoothers = [:]
        
        // Initialize audio buffers
        self.voiceBuffer = Array(repeating: 0.0, count: blockSize)
        self.mixBuffer = Array(repeating: 0.0, count: blockSize)
        self.tempBuffer = Array(repeating: 0.0, count: blockSize)
        
        // Initialize wavetables
        self.wavetables = [
            WavetableData.createSineProgression(frameCount: 64),
            WavetableData.createSawtoothProgression(frameCount: 32),
            WavetableData.createSquareProgression(frameCount: 16),
            WavetableData.createTriangleProgression(frameCount: 24)
        ]
        
        // Initialize audio components
        self.noiseGenerator = WavetoneNoiseGenerator(sampleRate: Double(sampleRate))
        self.envelopeSystem = WavetoneMultiEnvelopeSystem(sampleRate: Double(sampleRate), blockSize: blockSize)
        
        super.init(sampleRate: sampleRate)
        
        setupParameterSmoothers()
    }
    
    // MARK: - VoiceMachine Protocol Implementation
    
    public override func noteOn(noteNumber: Int, velocity: Float) {
        voiceQueue.async { [weak self] in
            guard let self = self else { return }
            
            let clampedVelocity = max(0.0, min(1.0, velocity))
            let clampedNote = max(0, min(127, noteNumber))
            
            // Find available voice or steal oldest
            let voiceIndex = self.findAvailableVoice() ?? self.findOldestVoice()
            
            // Initialize voice
            var voice = self.voices[voiceIndex]
            voice.isActive = true
            voice.noteNumber = clampedNote
            voice.velocity = clampedVelocity
            voice.frequency = self.midiNoteToFrequency(clampedNote)
            voice.phase1 = 0.0
            voice.phase2 = 0.0
            voice.envelopeState = WavetoneEnvelopeState()
            voice.envelopeState.ampPhase = .attack
            voice.envelopeState.filterPhase = .attack
            
            self.voices[voiceIndex] = voice
            self.updateActiveVoiceCount()
            
            // Trigger envelopes
            self.envelopeSystem.triggerAll(velocity: clampedVelocity, midiNote: Float(clampedNote))
        }
    }
    
    public override func noteOff(noteNumber: Int) {
        voiceQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Find active voices with this note number
            for i in 0..<self.voices.count {
                if self.voices[i].isActive && self.voices[i].noteNumber == noteNumber {
                    self.voices[i].envelopeState.isReleasing = true
                    self.voices[i].envelopeState.ampPhase = .release
                    self.voices[i].envelopeState.filterPhase = .release
                }
            }
            
            // Release envelopes
            self.envelopeSystem.releaseAll()
        }
    }
    
    public override func allNotesOff() {
        voiceQueue.async { [weak self] in
            guard let self = self else { return }
            
            for i in 0..<self.voices.count {
                if self.voices[i].isActive {
                    self.voices[i].envelopeState.isReleasing = true
                    self.voices[i].envelopeState.ampPhase = .release
                    self.voices[i].envelopeState.filterPhase = .release
                }
            }
            
            self.envelopeSystem.releaseAll()
        }
    }
    
    public override func setPitchBend(_ value: Float) {
        parameterQueue.async { [weak self] in
            guard let self = self else { return }
            
            let clampedValue = max(-2.0, min(2.0, value))
            self.parameters.pitchBend = clampedValue
            self.parameterSmoothers["pitchBend"]?.setTarget(clampedValue)
        }
    }
    
    public override func setModWheel(_ value: Float) {
        parameterQueue.async { [weak self] in
            guard let self = self else { return }
            
            let clampedValue = max(0.0, min(1.0, value))
            self.parameters.lfoDepth = clampedValue * 0.5  // Scale mod wheel to LFO depth
            self.parameterSmoothers["lfoDepth"]?.setTarget(self.parameters.lfoDepth)
        }
    }
    
    public override func processAudio(outputBuffer: AudioBuffer, frameCount: Int) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Process parameter smoothing
        processParameterSmoothing()
        
        // Clear mix buffer
        vDSP_vclr(&mixBuffer, 1, vDSP_Length(min(frameCount, blockSize)))
        
        // Process each active voice
        voiceQueue.sync {
            for i in 0..<voices.count {
                if voices[i].isActive {
                    processVoice(voiceIndex: i, frameCount: min(frameCount, blockSize))
                    
                    // Add to mix buffer
                    vDSP_vadd(mixBuffer, 1, voiceBuffer, 1, &mixBuffer, 1, vDSP_Length(min(frameCount, blockSize)))
                }
            }
        }
        
        // Apply master volume and copy to output
        let masterVol = parameters.masterVolume
        vDSP_vsmul(mixBuffer, 1, &masterVol, &tempBuffer, 1, vDSP_Length(min(frameCount, blockSize)))
        
        // Copy to output buffer (assuming mono for now)
        if let outputPointer = outputBuffer.floatChannelData?[0] {
            cblas_scopy(Int32(min(frameCount, blockSize)), tempBuffer, 1, outputPointer, 1)
        }
        
        // Update performance metrics
        processingTime = CFAbsoluteTimeGetCurrent() - startTime
        cpuUsage = Float(processingTime * Double(sampleRate) / Double(frameCount))
        
        // Clean up inactive voices
        cleanupInactiveVoices()
    }
    
    // MARK: - Parameter Management
    
    public func setParameter(_ parameter: String, value: Float) {
        parameterQueue.async { [weak self] in
            guard let self = self else { return }
            
            let clampedValue = self.clampParameterValue(parameter, value: value)
            self.updateParameter(parameter, value: clampedValue)
            self.parameterSmoothers[parameter]?.setTarget(clampedValue)
        }
    }
    
    public func getParameter(_ parameter: String) -> Float {
        return getParameterInternal(parameter)
    }
    
    public func loadPreset(_ presetData: [String: Any]) {
        parameterQueue.async { [weak self] in
            guard let self = self else { return }
            
            for (key, value) in presetData {
                if let floatValue = value as? Float {
                    self.updateParameter(key, value: floatValue)
                    self.parameterSmoothers[key]?.setTarget(floatValue)
                } else if let intValue = value as? Int {
                    self.updateParameter(key, value: Float(intValue))
                }
            }
        }
    }
    
    // MARK: - Preset Management
    
    public func savePreset() -> [String: Any] {
        return parameterQueue.sync {
            return [
                "masterVolume": parameters.masterVolume,
                "masterTune": parameters.masterTune,
                "portamento": parameters.portamento,
                "osc1Level": parameters.osc1Level,
                "osc1Tune": parameters.osc1Tune,
                "osc1FineTune": parameters.osc1FineTune,
                "osc1WavetableIndex": parameters.osc1WavetableIndex,
                "osc1WavePosition": parameters.osc1WavePosition,
                "osc1PhaseDistortion": parameters.osc1PhaseDistortion,
                "osc2Level": parameters.osc2Level,
                "osc2Tune": parameters.osc2Tune,
                "osc2FineTune": parameters.osc2FineTune,
                "osc2WavetableIndex": parameters.osc2WavetableIndex,
                "osc2WavePosition": parameters.osc2WavePosition,
                "osc2PhaseDistortion": parameters.osc2PhaseDistortion,
                "ringModulation": parameters.ringModulation,
                "hardSync": parameters.hardSync,
                "noiseType": parameters.noiseType,
                "noiseLevel": parameters.noiseLevel,
                "ampEnvAttack": parameters.ampEnvAttack,
                "ampEnvDecay": parameters.ampEnvDecay,
                "ampEnvSustain": parameters.ampEnvSustain,
                "ampEnvRelease": parameters.ampEnvRelease,
                "filterEnvAttack": parameters.filterEnvAttack,
                "filterEnvDecay": parameters.filterEnvDecay,
                "filterEnvSustain": parameters.filterEnvSustain,
                "filterEnvRelease": parameters.filterEnvRelease,
                "lfoRate": parameters.lfoRate,
                "lfoDepth": parameters.lfoDepth
            ]
        }
    }
    
    // MARK: - Performance Monitoring
    
    public var performanceMetrics: [String: Any] {
        return [
            "cpuUsage": cpuUsage,
            "processingTime": processingTime,
            "activeVoices": activeVoiceCount,
            "maxVoices": maxVoices,
            "sampleRate": sampleRate,
            "blockSize": blockSize
        ]
    }
    
    // MARK: - Private Implementation
    
    private func setupParameterSmoothers() {
        let smoothingTimes: [String: Float] = [
            "masterVolume": 0.01,
            "masterTune": 0.1,
            "portamento": 0.02,
            "pitchBend": 0.005,
            "osc1Level": 0.005,
            "osc2Level": 0.005,
            "osc1PhaseDistortion": 0.01,
            "osc2PhaseDistortion": 0.01,
            "ringModulation": 0.01,
            "hardSync": 0.01,
            "noiseLevel": 0.005,
            "lfoDepth": 0.02,
            "lfoRate": 0.05
        ]
        
        for (parameter, time) in smoothingTimes {
            parameterSmoothers[parameter] = ParameterSmoother(sampleRate: sampleRate, smoothingTime: time)
        }
    }
    
    private func processParameterSmoothing() {
        for (parameter, smoother) in parameterSmoothers {
            let smoothedValue = smoother.getSmoothedValue()
            updateParameter(parameter, value: smoothedValue)
        }
    }
    
    private func processVoice(voiceIndex: Int, frameCount: Int) {
        var voice = voices[voiceIndex]
        
        // Clear voice buffer
        vDSP_vclr(&voiceBuffer, 1, vDSP_Length(frameCount))
        
        // Process envelopes
        processVoiceEnvelopes(&voice, frameCount: frameCount)
        
        // Check if voice should be deactivated
        if voice.envelopeState.ampEnvelope <= 0.001 && voice.envelopeState.isReleasing {
            voice.isActive = false
            voices[voiceIndex] = voice
            return
        }
        
        // Generate oscillator audio
        processOscillators(&voice, frameCount: frameCount)
        
        // Generate noise
        processNoise(&voice, frameCount: frameCount)
        
        // Apply amplitude envelope
        let ampEnv = voice.envelopeState.ampEnvelope * voice.velocity
        vDSP_vsmul(voiceBuffer, 1, &ampEnv, &voiceBuffer, 1, vDSP_Length(frameCount))
        
        voices[voiceIndex] = voice
    }
    
    private func processVoiceEnvelopes(_ voice: inout VoiceState, frameCount: Int) {
        // Simplified envelope processing - in real implementation would use WavetoneEnvelopeSystem
        let ampParams = [parameters.ampEnvAttack, parameters.ampEnvDecay, parameters.ampEnvSustain, parameters.ampEnvRelease]
        
        switch voice.envelopeState.ampPhase {
        case .attack:
            voice.envelopeState.ampTime += Float(frameCount) / sampleRate
            let attackProgress = voice.envelopeState.ampTime / ampParams[0]
            voice.envelopeState.ampEnvelope = min(1.0, attackProgress)
            
            if attackProgress >= 1.0 {
                voice.envelopeState.ampPhase = .decay
                voice.envelopeState.ampTime = 0.0
            }
            
        case .decay:
            voice.envelopeState.ampTime += Float(frameCount) / sampleRate
            let decayProgress = voice.envelopeState.ampTime / ampParams[1]
            voice.envelopeState.ampEnvelope = 1.0 - (decayProgress * (1.0 - ampParams[2]))
            
            if decayProgress >= 1.0 {
                voice.envelopeState.ampPhase = .sustain
                voice.envelopeState.ampEnvelope = ampParams[2]
            }
            
        case .sustain:
            voice.envelopeState.ampEnvelope = ampParams[2]
            
        case .release:
            voice.envelopeState.ampTime += Float(frameCount) / sampleRate
            let releaseProgress = voice.envelopeState.ampTime / ampParams[3]
            voice.envelopeState.ampEnvelope = ampParams[2] * (1.0 - releaseProgress)
            
            if releaseProgress >= 1.0 {
                voice.envelopeState.ampEnvelope = 0.0
                voice.envelopeState.ampPhase = .idle
            }
            
        default:
            voice.envelopeState.ampEnvelope = 0.0
        }
    }
    
    private func processOscillators(_ voice: inout VoiceState, frameCount: Int) {
        let baseFreq = voice.frequency
        let pitchBendMult = pow(2.0, parameters.pitchBend / 12.0)
        let masterTuneMult = pow(2.0, parameters.masterTune / 12.0)
        
        // Oscillator 1
        let osc1Freq = baseFreq * pow(2.0, parameters.osc1Tune / 12.0) * pitchBendMult * masterTuneMult
        let osc1PhaseInc = osc1Freq / sampleRate
        
        // Oscillator 2  
        let osc2Freq = baseFreq * pow(2.0, parameters.osc2Tune / 12.0) * pitchBendMult * masterTuneMult
        let osc2PhaseInc = osc2Freq / sampleRate
        
        for i in 0..<frameCount {
            // Generate oscillator 1
            let osc1Sample = generateWavetableSample(
                wavetableIndex: parameters.osc1WavetableIndex,
                phase: voice.phase1,
                wavePosition: parameters.osc1WavePosition,
                phaseDistortion: parameters.osc1PhaseDistortion
            )
            
            // Generate oscillator 2
            let osc2Sample = generateWavetableSample(
                wavetableIndex: parameters.osc2WavetableIndex,
                phase: voice.phase2,
                wavePosition: parameters.osc2WavePosition,
                phaseDistortion: parameters.osc2PhaseDistortion
            )
            
            // Apply modulation
            var mixedSample = osc1Sample * parameters.osc1Level + osc2Sample * parameters.osc2Level
            
            // Ring modulation
            if parameters.ringModulation > 0.001 {
                let ringMod = osc1Sample * osc2Sample
                mixedSample = mixedSample * (1.0 - parameters.ringModulation) + ringMod * parameters.ringModulation
            }
            
            // Hard sync (simplified)
            if parameters.hardSync > 0.001 && voice.phase2 < osc2PhaseInc {
                voice.phase1 = 0.0  // Reset osc1 phase when osc2 resets
            }
            
            voiceBuffer[i] += mixedSample
            
            // Advance phases
            voice.phase1 += osc1PhaseInc
            voice.phase2 += osc2PhaseInc
            
            if voice.phase1 >= 1.0 { voice.phase1 -= 1.0 }
            if voice.phase2 >= 1.0 { voice.phase2 -= 1.0 }
        }
    }
    
    private func processNoise(_ voice: inout VoiceState, frameCount: Int) {
        if parameters.noiseLevel > 0.001 {
            // Configure noise generator
            noiseGenerator.setParameters(
                type: WavetoneNoiseGenerator.NoiseType.allCases[min(parameters.noiseType, WavetoneNoiseGenerator.NoiseType.allCases.count - 1)],
                level: parameters.noiseLevel,
                baseFreq: parameters.noiseFilter * 10000.0 + 100.0,
                width: 1000.0,
                grain: 0.5,
                resonance: parameters.noiseResonance,
                character: 0.5
            )
            
            // Generate noise and add to voice buffer
            for i in 0..<frameCount {
                let noiseSample = noiseGenerator.processSample()
                voiceBuffer[i] += noiseSample
            }
        }
    }
    
    private func generateWavetableSample(wavetableIndex: Int, phase: Float, wavePosition: Float, phaseDistortion: Float) -> Float {
        guard wavetableIndex < wavetables.count else { return 0.0 }
        
        let wavetable = wavetables[wavetableIndex]
        var adjustedPhase = phase
        
        // Apply phase distortion
        if phaseDistortion > 0.001 {
            adjustedPhase = phase + phaseDistortion * sin(phase * 2.0 * .pi)
            if adjustedPhase > 1.0 { adjustedPhase -= 1.0 }
            if adjustedPhase < 0.0 { adjustedPhase += 1.0 }
        }
        
        // Calculate frame and sample positions
        let framePos = wavePosition * Float(wavetable.frameCount - 1)
        let samplePos = adjustedPhase * Float(wavetable.frameSize)
        
        // Use linear interpolation for now (could use more sophisticated interpolation)
        return wavetable.interpolateSample(framePosition: framePos, samplePosition: samplePos, interpolation: .linear)
    }
    
    private func findAvailableVoice() -> Int? {
        for i in 0..<voices.count {
            if !voices[i].isActive {
                return i
            }
        }
        return nil
    }
    
    private func findOldestVoice() -> Int {
        // Simplified voice stealing - steal the first active voice
        for i in 0..<voices.count {
            if voices[i].isActive {
                return i
            }
        }
        return 0
    }
    
    private func cleanupInactiveVoices() {
        for i in 0..<voices.count {
            if voices[i].isActive && voices[i].envelopeState.ampEnvelope <= 0.001 && voices[i].envelopeState.isReleasing {
                voices[i].isActive = false
            }
        }
        updateActiveVoiceCount()
    }
    
    private func updateActiveVoiceCount() {
        activeVoiceCount = voices.filter { $0.isActive }.count
    }
    
    private func midiNoteToFrequency(_ noteNumber: Int) -> Float {
        return 440.0 * pow(2.0, Float(noteNumber - 69) / 12.0)
    }
    
    private func clampParameterValue(_ parameter: String, value: Float) -> Float {
        switch parameter {
        case "masterVolume", "osc1Level", "osc2Level", "noiseLevel", "ringModulation", "hardSync":
            return max(0.0, min(1.0, value))
        case "masterTune", "osc1Tune", "osc2Tune":
            return max(-24.0, min(24.0, value))
        case "pitchBend":
            return max(-2.0, min(2.0, value))
        case "ampEnvAttack", "ampEnvDecay", "ampEnvRelease", "filterEnvAttack", "filterEnvDecay", "filterEnvRelease":
            return max(0.001, min(10.0, value))
        case "ampEnvSustain", "filterEnvSustain":
            return max(0.0, min(1.0, value))
        case "lfoRate":
            return max(0.1, min(20.0, value))
        default:
            return value
        }
    }
    
    private func updateParameter(_ parameter: String, value: Float) {
        switch parameter {
        case "masterVolume": parameters.masterVolume = value
        case "masterTune": parameters.masterTune = value
        case "portamento": parameters.portamento = value
        case "pitchBend": parameters.pitchBend = value
        case "osc1Level": parameters.osc1Level = value
        case "osc1Tune": parameters.osc1Tune = value
        case "osc1FineTune": parameters.osc1FineTune = value
        case "osc1WavePosition": parameters.osc1WavePosition = value
        case "osc1PhaseDistortion": parameters.osc1PhaseDistortion = value
        case "osc2Level": parameters.osc2Level = value
        case "osc2Tune": parameters.osc2Tune = value
        case "osc2FineTune": parameters.osc2FineTune = value
        case "osc2WavePosition": parameters.osc2WavePosition = value
        case "osc2PhaseDistortion": parameters.osc2PhaseDistortion = value
        case "ringModulation": parameters.ringModulation = value
        case "hardSync": parameters.hardSync = value
        case "noiseLevel": parameters.noiseLevel = value
        case "noiseFilter": parameters.noiseFilter = value
        case "noiseResonance": parameters.noiseResonance = value
        case "ampEnvAttack": parameters.ampEnvAttack = value
        case "ampEnvDecay": parameters.ampEnvDecay = value
        case "ampEnvSustain": parameters.ampEnvSustain = value
        case "ampEnvRelease": parameters.ampEnvRelease = value
        case "filterEnvAttack": parameters.filterEnvAttack = value
        case "filterEnvDecay": parameters.filterEnvDecay = value
        case "filterEnvSustain": parameters.filterEnvSustain = value
        case "filterEnvRelease": parameters.filterEnvRelease = value
        case "lfoRate": parameters.lfoRate = value
        case "lfoDepth": parameters.lfoDepth = value
        default: break
        }
    }
    
    private func getParameterValue(_ parameter: String) -> Float {
        switch parameter {
        case "masterVolume": return parameters.masterVolume
        case "masterTune": return parameters.masterTune
        case "portamento": return parameters.portamento
        case "pitchBend": return parameters.pitchBend
        case "osc1Level": return parameters.osc1Level
        case "osc1Tune": return parameters.osc1Tune
        case "osc1FineTune": return parameters.osc1FineTune
        case "osc1WavePosition": return parameters.osc1WavePosition
        case "osc1PhaseDistortion": return parameters.osc1PhaseDistortion
        case "osc2Level": return parameters.osc2Level
        case "osc2Tune": return parameters.osc2Tune
        case "osc2FineTune": return parameters.osc2FineTune
        case "osc2WavePosition": return parameters.osc2WavePosition
        case "osc2PhaseDistortion": return parameters.osc2PhaseDistortion
        case "ringModulation": return parameters.ringModulation
        case "hardSync": return parameters.hardSync
        case "noiseLevel": return parameters.noiseLevel
        case "noiseFilter": return parameters.noiseFilter
        case "noiseResonance": return parameters.noiseResonance
        case "ampEnvAttack": return parameters.ampEnvAttack
        case "ampEnvDecay": return parameters.ampEnvDecay
        case "ampEnvSustain": return parameters.ampEnvSustain
        case "ampEnvRelease": return parameters.ampEnvRelease
        case "filterEnvAttack": return parameters.filterEnvAttack
        case "filterEnvDecay": return parameters.filterEnvDecay
        case "filterEnvSustain": return parameters.filterEnvSustain
        case "filterEnvRelease": return parameters.filterEnvRelease
        case "lfoRate": return parameters.lfoRate
        case "lfoDepth": return parameters.lfoDepth
        default: return 0.0
        }
    }
}

// MARK: - Preset System
public struct WavetonePreset {
    public let name: String
    public let parameters: WavetoneVoiceMachine.WavetoneParameters
    public let amplitudeEnvelope: WavetoneEnvelopeSystem.EnvelopeConfig
    public let filterEnvelope: WavetoneEnvelopeSystem.EnvelopeConfig
    
    public init(name: String, 
                parameters: WavetoneVoiceMachine.WavetoneParameters,
                amplitudeEnvelope: WavetoneEnvelopeSystem.EnvelopeConfig,
                filterEnvelope: WavetoneEnvelopeSystem.EnvelopeConfig) {
        self.name = name
        self.parameters = parameters
        self.amplitudeEnvelope = amplitudeEnvelope
        self.filterEnvelope = filterEnvelope
    }
}

// MARK: - Built-in Presets
public extension WavetonePreset {
    
    static let analog: WavetonePreset = {
        var params = WavetoneVoiceMachine.WavetoneParameters()
        params.osc1Level = 0.8
        params.osc2Level = 0.6
        params.osc2Tune = -12.0  // One octave down
        params.ringModulation = 0.1
        params.noiseLevel = 0.05
        
        return WavetonePreset(
            name: "Analog",
            parameters: params,
            amplitudeEnvelope: .plucked,
            filterEnvelope: .bell
        )
    }()
    
    static let bell: WavetonePreset = {
        var params = WavetoneVoiceMachine.WavetoneParameters()
        params.osc1Level = 0.9
        params.osc2Level = 0.7
        params.osc2Tune = 7.0    // Perfect fifth
        params.osc1PhaseDistortion = 0.3
        params.ringModulation = 0.2
        
        return WavetonePreset(
            name: "Bell",
            parameters: params,
            amplitudeEnvelope: .bell,
            filterEnvelope: .bell
        )
    }()
    
    static let pad: WavetonePreset = {
        var params = WavetoneVoiceMachine.WavetoneParameters()
        params.osc1Level = 0.7
        params.osc2Level = 0.7
        params.osc2FineTune = 5.0  // Slight detune
        params.portamento = 0.2
        params.noiseLevel = 0.1
        
        return WavetonePreset(
            name: "Pad",
            parameters: params,
            amplitudeEnvelope: .pad,
            filterEnvelope: .pad
        )
    }()
    
    static let percussive: WavetonePreset = {
        var params = WavetoneVoiceMachine.WavetoneParameters()
        params.osc1Level = 0.9
        params.osc2Level = 0.4
        params.osc1PhaseDistortion = 0.6
        params.noiseLevel = 0.3
        params.hardSync = 0.4
        
        return WavetonePreset(
            name: "Percussive",
            parameters: params,
            amplitudeEnvelope: .percussive,
            filterEnvelope: .percussive
        )
    }()
}
