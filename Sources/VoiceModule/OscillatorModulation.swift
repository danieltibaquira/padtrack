// OscillatorModulation.swift
// DigitonePad - VoiceModule
//
// Comprehensive Oscillator Modulation System for WAVETONE Voice Machine
// Implements Ring Modulation and Hard Sync with advanced anti-aliasing

import Foundation
import Accelerate
import simd
import MachineProtocols
import AudioEngine

// MARK: - Oscillator Modulation Types

/// Available oscillator modulation types
public enum OscillatorModulationType: String, CaseIterable, Codable {
    case none = "none"                  // No modulation
    case ringModulation = "ring"        // Ring modulation (amplitude multiplication)
    case hardSync = "sync"              // Hard sync (phase reset)
    case phaseModulation = "phase"      // Phase modulation
    case frequencyModulation = "freq"   // Frequency modulation
    case pulseWidthModulation = "pwm"   // Pulse width modulation
    case amplitudeModulation = "am"     // Amplitude modulation
    
    public var displayName: String {
        switch self {
        case .none: return "None"
        case .ringModulation: return "Ring Mod"
        case .hardSync: return "Hard Sync"
        case .phaseModulation: return "Phase Mod"
        case .frequencyModulation: return "Freq Mod"
        case .pulseWidthModulation: return "PWM"
        case .amplitudeModulation: return "AM"
        }
    }
}

// MARK: - Oscillator Roles

/// Defines the role of oscillators in modulation relationship
public enum OscillatorRole {
    case carrier    // Main oscillator (modulated)
    case modulator  // Modulating oscillator
}

// MARK: - Modulation Parameters

/// Comprehensive parameters for oscillator modulation
public struct OscillatorModulationParameters {
    /// Primary modulation type
    public var type: OscillatorModulationType = .none
    
    /// Modulation depth (0.0 to 1.0)
    public var depth: Float = 0.0
    
    /// Modulation frequency ratio (modulator/carrier frequency ratio)
    public var ratio: Float = 1.0
    
    /// Fine tuning offset for modulator (-100 to +100 cents)
    public var fineTune: Float = 0.0
    
    /// Phase offset between oscillators (0.0 to 1.0)
    public var phaseOffset: Float = 0.0
    
    /// Sync threshold for hard sync (0.0 to 1.0)
    public var syncThreshold: Float = 0.0
    
    /// Modulation asymmetry (-1.0 to 1.0)
    public var asymmetry: Float = 0.0
    
    /// Enable anti-aliasing for harsh modulation types
    public var antiAliasing: Bool = true
    
    /// Ring modulation DC offset compensation
    public var dcBlocker: Bool = true
    
    /// Parameter smoothing time (seconds)
    public var smoothingTime: Float = 0.001
    
    public init() {}
}

// MARK: - Modulation State

/// Internal state tracking for oscillator modulation
struct ModulationState {
    var carrierPhase: Float = 0.0
    var modulatorPhase: Float = 0.0
    var lastSyncPoint: Float = 0.0
    var phaseIncrement: Float = 0.0
    var modulatorIncrement: Float = 0.0
    var dcBlockerState: Float = 0.0
    var dcBlockerPrevious: Float = 0.0
    
    // Anti-aliasing state
    var oversampleBuffer: [Float] = []
    var antiAliasFilter: [Float] = []
    var filterDelay: [Float] = []
}

// MARK: - Ring Modulation Engine

/// High-performance ring modulation processor
public final class RingModulationEngine: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Modulation parameters
    public var parameters = OscillatorModulationParameters()
    
    /// Sample rate for processing
    public var sampleRate: Float = 44100.0 {
        didSet { updateInternalState() }
    }
    
    // MARK: - Private Properties
    
    private var smoothedParams = OscillatorModulationParameters()
    private var smoothingCoefficients: [Float] = []
    private var state = ModulationState()
    
    // Anti-aliasing filter coefficients
    private let antiAliasFilterOrder = 8
    private var antiAliasCoefficients: [Float] = []
    
    // MARK: - Initialization
    
    public init(sampleRate: Float = 44100.0) {
        self.sampleRate = sampleRate
        updateInternalState()
        setupAntiAliasing()
    }
    
    // MARK: - Ring Modulation Processing
    
    /// Apply ring modulation to carrier signal
    /// - Parameters:
    ///   - carrierSample: Carrier oscillator sample
    ///   - modulatorSample: Modulator oscillator sample
    ///   - depth: Modulation depth (0.0 to 1.0)
    /// - Returns: Ring modulated sample
    public func processRingModulation(carrierSample: Float, modulatorSample: Float, depth: Float) -> Float {
        updateParameterSmoothing()
        
        let effectiveDepth = smoothedParams.depth * depth
        
        if effectiveDepth <= 0.001 {
            return carrierSample
        }
        
        // Basic ring modulation: carrier * modulator
        var modulated = carrierSample * modulatorSample * effectiveDepth
        
        // Apply asymmetry
        if smoothedParams.asymmetry != 0.0 {
            modulated = applyAsymmetry(modulated, asymmetry: smoothedParams.asymmetry)
        }
        
        // Mix with dry signal
        let wet = modulated
        let dry = carrierSample * (1.0 - effectiveDepth)
        var output = wet + dry
        
        // Apply DC blocking if enabled
        if smoothedParams.dcBlocker {
            output = applyDCBlocker(output)
        }
        
        return output
    }
    
    /// Process ring modulation with anti-aliasing
    /// - Parameters:
    ///   - carrierSample: Carrier sample
    ///   - modulatorSample: Modulator sample
    ///   - depth: Modulation depth
    ///   - fundamental: Fundamental frequency for anti-aliasing
    /// - Returns: Anti-aliased ring modulated sample
    public func processRingModulationAntiAliased(carrierSample: Float, modulatorSample: Float, depth: Float, fundamental: Float) -> Float {
        if !smoothedParams.antiAliasing || shouldApplyAntiAliasing(fundamental: fundamental) {
            return processRingModulation(carrierSample: carrierSample, modulatorSample: modulatorSample, depth: depth)
        }
        
        // Oversample and filter
        let oversampleFactor = 4
        var oversampledOutput: Float = 0.0
        
        for i in 0..<oversampleFactor {
            let phase = Float(i) / Float(oversampleFactor)
            let interpolatedCarrier = carrierSample // In practice, would interpolate
            let interpolatedModulator = modulatorSample // In practice, would interpolate
            
            let sample = processRingModulation(carrierSample: interpolatedCarrier, modulatorSample: interpolatedModulator, depth: depth)
            oversampledOutput += applyAntiAliasFilter(sample)
        }
        
        return oversampledOutput / Float(oversampleFactor)
    }
    
    // MARK: - Advanced Ring Modulation Modes
    
    /// Bipolar ring modulation (classic RM)
    public func processBipolarRingMod(carrierSample: Float, modulatorSample: Float, depth: Float) -> Float {
        let modulated = carrierSample * modulatorSample
        return carrierSample + depth * modulated
    }
    
    /// Unipolar ring modulation (like tremolo)
    public func processUnipolarRingMod(carrierSample: Float, modulatorSample: Float, depth: Float) -> Float {
        let unipolarMod = (modulatorSample + 1.0) * 0.5 // Convert to 0-1 range
        return carrierSample * (1.0 - depth + depth * unipolarMod)
    }
    
    /// Quadrature ring modulation (90-degree phase offset)
    public func processQuadratureRingMod(carrierSample: Float, modulatorSample: Float, quadratureMod: Float, depth: Float) -> Float {
        let primaryMod = carrierSample * modulatorSample
        let quadMod = carrierSample * quadratureMod
        let complexMod = sqrt(primaryMod * primaryMod + quadMod * quadMod)
        return carrierSample + depth * complexMod
    }
    
    // MARK: - Private Methods
    
    private func updateParameterSmoothing() {
        if smoothingCoefficients.isEmpty {
            setupParameterSmoothing()
        }
        
        smoothedParams.depth = smooth(current: smoothedParams.depth, target: parameters.depth, coefficient: smoothingCoefficients[0])
        smoothedParams.ratio = smooth(current: smoothedParams.ratio, target: parameters.ratio, coefficient: smoothingCoefficients[1])
        smoothedParams.asymmetry = smooth(current: smoothedParams.asymmetry, target: parameters.asymmetry, coefficient: smoothingCoefficients[2])
    }
    
    private func smooth(current: Float, target: Float, coefficient: Float) -> Float {
        return current * coefficient + target * (1.0 - coefficient)
    }
    
    private func setupParameterSmoothing() {
        let cutoffFreq = 1.0 / parameters.smoothingTime
        let omega = 2.0 * Float.pi * cutoffFreq / sampleRate
        let coeff = exp(-omega)
        
        smoothingCoefficients = [coeff, coeff, coeff, coeff] // One for each parameter
    }
    
    private func applyAsymmetry(_ sample: Float, asymmetry: Float) -> Float {
        if asymmetry == 0.0 { return sample }
        
        if sample >= 0.0 {
            return sample * (1.0 + asymmetry)
        } else {
            return sample * (1.0 - asymmetry)
        }
    }
    
    private func applyDCBlocker(_ sample: Float) -> Float {
        // Simple DC blocking filter: y[n] = x[n] - x[n-1] + 0.995 * y[n-1]
        let output = sample - state.dcBlockerPrevious + 0.995 * state.dcBlockerState
        state.dcBlockerPrevious = sample
        state.dcBlockerState = output
        return output
    }
    
    private func shouldApplyAntiAliasing(fundamental: Float) -> Bool {
        let nyquist = sampleRate * 0.5
        return fundamental > nyquist * 0.25 // Apply AA above 25% of Nyquist
    }
    
    private func applyAntiAliasFilter(_ sample: Float) -> Float {
        // Simple FIR lowpass filter for anti-aliasing
        state.filterDelay.insert(sample, at: 0)
        if state.filterDelay.count > antiAliasFilterOrder {
            state.filterDelay.removeLast()
        }
        
        var output: Float = 0.0
        for i in 0..<min(state.filterDelay.count, antiAliasCoefficients.count) {
            output += state.filterDelay[i] * antiAliasCoefficients[i]
        }
        
        return output
    }
    
    private func updateInternalState() {
        setupParameterSmoothing()
    }
    
    private func setupAntiAliasing() {
        // Design a simple lowpass FIR filter for anti-aliasing
        antiAliasCoefficients = []
        let cutoff = 0.4 // Cutoff at 40% of sample rate
        
        for i in 0..<antiAliasFilterOrder {
            let n = Float(i) - Float(antiAliasFilterOrder - 1) * 0.5
            var coeff: Float
            
            if abs(n) < 0.001 {
                coeff = 2.0 * cutoff
            } else {
                coeff = sin(2.0 * Float.pi * cutoff * n) / (Float.pi * n)
            }
            
            // Apply Hamming window
            let window = 0.54 - 0.46 * cos(2.0 * Float.pi * Float(i) / Float(antiAliasFilterOrder - 1))
            coeff *= window
            
            antiAliasCoefficients.append(coeff)
        }
        
        // Normalize coefficients
        let sum = antiAliasCoefficients.reduce(0.0, +)
        if sum > 0.0 {
            antiAliasCoefficients = antiAliasCoefficients.map { $0 / sum }
        }
        
        state.filterDelay = [Float](repeating: 0.0, count: antiAliasFilterOrder)
    }
}

// MARK: - Hard Sync Engine

/// High-performance hard sync processor
public final class HardSyncEngine: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Modulation parameters
    public var parameters = OscillatorModulationParameters()
    
    /// Sample rate for processing
    public var sampleRate: Float = 44100.0 {
        didSet { updateInternalState() }
    }
    
    // MARK: - Private Properties
    
    private var smoothedParams = OscillatorModulationParameters()
    private var smoothingCoefficients: [Float] = []
    private var state = ModulationState()
    
    // Band-limited impulse tables for anti-aliasing
    private var blitTables: [[Float]] = []
    private let maxHarmonics = 64
    
    // MARK: - Initialization
    
    public init(sampleRate: Float = 44100.0) {
        self.sampleRate = sampleRate
        updateInternalState()
        setupBLITTables()
    }
    
    // MARK: - Hard Sync Processing
    
    /// Process hard sync between oscillators
    /// - Parameters:
    ///   - carrierPhase: Current carrier phase (0.0 to 1.0)
    ///   - masterPhase: Master oscillator phase (0.0 to 1.0)
    ///   - frequency: Carrier frequency
    ///   - masterFrequency: Master frequency
    /// - Returns: Tuple of (synced phase, sync triggered)
    public func processHardSync(carrierPhase: Float, masterPhase: Float, frequency: Float, masterFrequency: Float) -> (syncedPhase: Float, syncTriggered: Bool) {
        updateParameterSmoothing()
        
        let ratio = frequency / masterFrequency
        let syncThreshold = smoothedParams.syncThreshold
        
        // Detect sync point (master oscillator zero crossing)
        let syncTriggered = detectSyncPoint(masterPhase: masterPhase, threshold: syncThreshold)
        
        if syncTriggered {
            // Reset carrier phase with optional offset
            let resetPhase = smoothedParams.phaseOffset
            state.lastSyncPoint = carrierPhase
            return (resetPhase, true)
        } else {
            // Normal phase increment
            return (carrierPhase, false)
        }
    }
    
    /// Process hard sync with anti-aliasing
    /// - Parameters:
    ///   - carrierPhase: Carrier phase
    ///   - masterPhase: Master phase
    ///   - frequency: Carrier frequency
    ///   - masterFrequency: Master frequency
    ///   - wavetable: Source wavetable for carrier
    /// - Returns: Anti-aliased sync sample
    public func processHardSyncAntiAliased(carrierPhase: Float, masterPhase: Float, frequency: Float, masterFrequency: Float, wavetable: WavetableData) -> Float {
        let (syncedPhase, syncTriggered) = processHardSync(carrierPhase: carrierPhase, masterPhase: masterPhase, frequency: frequency, masterFrequency: masterFrequency)
        
        if !syncTriggered || !smoothedParams.antiAliasing {
            return wavetable.getSample(frameIndex: 0, position: syncedPhase * Float(wavetable.frameSize))
        }
        
        // Apply band-limited sync using BLIT
        return synthesizeWithBLIT(phase: syncedPhase, frequency: frequency, wavetable: wavetable)
    }
    
    /// Advanced sync with multiple sync modes
    public func processAdvancedSync(carrierPhase: Float, masterPhase: Float, frequency: Float, masterFrequency: Float, mode: SyncMode) -> (syncedPhase: Float, syncTriggered: Bool) {
        switch mode {
        case .hard:
            return processHardSync(carrierPhase: carrierPhase, masterPhase: masterPhase, frequency: frequency, masterFrequency: masterFrequency)
        case .soft:
            return processSoftSync(carrierPhase: carrierPhase, masterPhase: masterPhase, frequency: frequency, masterFrequency: masterFrequency)
        case .reversible:
            return processReversibleSync(carrierPhase: carrierPhase, masterPhase: masterPhase, frequency: frequency, masterFrequency: masterFrequency)
        }
    }
    
    // MARK: - Sync Modes
    
    public enum SyncMode {
        case hard       // Traditional hard sync
        case soft       // Softer sync with smooth transitions
        case reversible // Reversible sync (can sync in both directions)
    }
    
    // MARK: - Private Methods
    
    private func detectSyncPoint(masterPhase: Float, threshold: Float) -> Bool {
        let previousPhase = state.lastSyncPoint
        
        // Check for phase wraparound (indicates sync point)
        if previousPhase > masterPhase {
            // Phase wrapped from ~1.0 to ~0.0
            return true
        }
        
        // Check for threshold crossing
        if threshold > 0.0 && previousPhase < threshold && masterPhase >= threshold {
            return true
        }
        
        state.lastSyncPoint = masterPhase
        return false
    }
    
    private func processSoftSync(carrierPhase: Float, masterPhase: Float, frequency: Float, masterFrequency: Float) -> (syncedPhase: Float, syncTriggered: Bool) {
        let syncStrength = smoothedParams.depth
        let syncTriggered = detectSyncPoint(masterPhase: masterPhase, threshold: smoothedParams.syncThreshold)
        
        if syncTriggered && syncStrength > 0.0 {
            // Soft sync: blend between current phase and reset phase
            let resetPhase = smoothedParams.phaseOffset
            let blendedPhase = carrierPhase * (1.0 - syncStrength) + resetPhase * syncStrength
            return (blendedPhase, true)
        }
        
        return (carrierPhase, false)
    }
    
    private func processReversibleSync(carrierPhase: Float, masterPhase: Float, frequency: Float, masterFrequency: Float) -> (syncedPhase: Float, syncTriggered: Bool) {
        // Reversible sync can trigger on both positive and negative zero crossings
        let syncTriggered = detectReversibleSyncPoint(masterPhase: masterPhase)
        
        if syncTriggered {
            let resetPhase = smoothedParams.phaseOffset
            return (resetPhase, true)
        }
        
        return (carrierPhase, false)
    }
    
    private func detectReversibleSyncPoint(masterPhase: Float) -> Bool {
        let previousPhase = state.lastSyncPoint
        
        // Check for any significant phase change (both directions)
        let phaseDiff = abs(masterPhase - previousPhase)
        
        if phaseDiff > 0.5 {
            state.lastSyncPoint = masterPhase
            return true
        }
        
        state.lastSyncPoint = masterPhase
        return false
    }
    
    private func synthesizeWithBLIT(phase: Float, frequency: Float, wavetable: WavetableData) -> Float {
        let nyquist = sampleRate * 0.5
        let maxHarmonics = min(self.maxHarmonics, Int(nyquist / frequency))
        
        if maxHarmonics < 1 {
            return 0.0
        }
        
        let tableIndex = min(maxHarmonics - 1, blitTables.count - 1)
        let table = blitTables[tableIndex]
        
        let tablePos = phase * Float(table.count)
        let intPos = Int(tablePos)
        let fracPos = tablePos - Float(intPos)
        
        let sample1 = table[intPos % table.count]
        let sample2 = table[(intPos + 1) % table.count]
        
        return sample1 + fracPos * (sample2 - sample1)
    }
    
    private func setupBLITTables() {
        blitTables = []
        
        for harmonics in 1...maxHarmonics {
            var table: [Float] = []
            let tableSize = 1024
            
            for i in 0..<tableSize {
                let phase = Float(i) / Float(tableSize) * 2.0 * Float.pi
                var sample: Float = 0.0
                
                // Generate band-limited impulse train
                for h in 1...harmonics {
                    sample += sin(Float(h) * phase) / Float(h)
                }
                
                table.append(sample)
            }
            
            // Normalize
            let maxValue = table.max() ?? 1.0
            if maxValue > 0.0 {
                table = table.map { $0 / maxValue }
            }
            
            blitTables.append(table)
        }
    }
    
    private func updateInternalState() {
        setupParameterSmoothing()
    }
    
    private func updateParameterSmoothing() {
        if smoothingCoefficients.isEmpty {
            setupParameterSmoothing()
        }
        
        smoothedParams.depth = smooth(current: smoothedParams.depth, target: parameters.depth, coefficient: smoothingCoefficients[0])
        smoothedParams.syncThreshold = smooth(current: smoothedParams.syncThreshold, target: parameters.syncThreshold, coefficient: smoothingCoefficients[1])
        smoothedParams.phaseOffset = smooth(current: smoothedParams.phaseOffset, target: parameters.phaseOffset, coefficient: smoothingCoefficients[2])
    }
    
    private func smooth(current: Float, target: Float, coefficient: Float) -> Float {
        return current * coefficient + target * (1.0 - coefficient)
    }
    
    private func setupParameterSmoothing() {
        let cutoffFreq = 1.0 / parameters.smoothingTime
        let omega = 2.0 * Float.pi * cutoffFreq / sampleRate
        let coeff = exp(-omega)
        
        smoothingCoefficients = [coeff, coeff, coeff, coeff]
    }
}

// MARK: - Unified Oscillator Modulation System

/// Comprehensive oscillator modulation system combining all modulation types
public final class OscillatorModulationSystem: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Current modulation type
    public var modulationType: OscillatorModulationType = .none {
        didSet { updateProcessingMode() }
    }
    
    /// Modulation parameters
    public var parameters = OscillatorModulationParameters() {
        didSet { updateEngineParameters() }
    }
    
    /// Sample rate
    public var sampleRate: Float = 44100.0 {
        didSet { updateSampleRate() }
    }
    
    // MARK: - Private Properties
    
    private let ringModEngine: RingModulationEngine
    private let hardSyncEngine: HardSyncEngine
    private var phaseAccumulator: Float = 0.0
    private var modulatorAccumulator: Float = 0.0
    
    // MARK: - Initialization
    
    public init(sampleRate: Float = 44100.0) {
        self.sampleRate = sampleRate
        self.ringModEngine = RingModulationEngine(sampleRate: sampleRate)
        self.hardSyncEngine = HardSyncEngine(sampleRate: sampleRate)
        updateEngineParameters()
    }
    
    // MARK: - Main Processing Interface
    
    /// Process oscillator modulation
    /// - Parameters:
    ///   - carrierWavetable: Carrier oscillator wavetable
    ///   - modulatorWavetable: Modulator oscillator wavetable
    ///   - carrierFrequency: Carrier frequency
    ///   - modulatorFrequency: Modulator frequency
    ///   - framePosition: Current frame position in wavetables
    /// - Returns: Modulated sample
    public func processSample(carrierWavetable: WavetableData, 
                             modulatorWavetable: WavetableData,
                             carrierFrequency: Float,
                             modulatorFrequency: Float,
                             framePosition: Float = 0.0) -> Float {
        
        // Update phase accumulators
        let carrierIncrement = carrierFrequency / sampleRate
        let modulatorIncrement = modulatorFrequency / sampleRate
        
        phaseAccumulator += carrierIncrement
        modulatorAccumulator += modulatorIncrement
        
        // Wrap phases
        phaseAccumulator = fmod(phaseAccumulator, 1.0)
        modulatorAccumulator = fmod(modulatorAccumulator, 1.0)
        
        return processSample(carrierWavetable: carrierWavetable,
                           modulatorWavetable: modulatorWavetable,
                           carrierPhase: phaseAccumulator,
                           modulatorPhase: modulatorAccumulator,
                           carrierFrequency: carrierFrequency,
                           modulatorFrequency: modulatorFrequency,
                           framePosition: framePosition)
    }
    
    /// Process with explicit phase values
    /// - Parameters:
    ///   - carrierWavetable: Carrier wavetable
    ///   - modulatorWavetable: Modulator wavetable
    ///   - carrierPhase: Carrier phase (0.0 to 1.0)
    ///   - modulatorPhase: Modulator phase (0.0 to 1.0)
    ///   - carrierFrequency: Carrier frequency
    ///   - modulatorFrequency: Modulator frequency
    ///   - framePosition: Frame position
    /// - Returns: Modulated sample
    public func processSample(carrierWavetable: WavetableData,
                             modulatorWavetable: WavetableData,
                             carrierPhase: Float,
                             modulatorPhase: Float,
                             carrierFrequency: Float,
                             modulatorFrequency: Float,
                             framePosition: Float = 0.0) -> Float {
        
        switch modulationType {
        case .none:
            return synthesizeCarrier(wavetable: carrierWavetable, phase: carrierPhase, framePosition: framePosition)
            
        case .ringModulation:
            return processRingModulation(carrierWavetable: carrierWavetable,
                                       modulatorWavetable: modulatorWavetable,
                                       carrierPhase: carrierPhase,
                                       modulatorPhase: modulatorPhase,
                                       carrierFrequency: carrierFrequency,
                                       framePosition: framePosition)
            
        case .hardSync:
            return processHardSync(carrierWavetable: carrierWavetable,
                                 modulatorWavetable: modulatorWavetable,
                                 carrierPhase: carrierPhase,
                                 modulatorPhase: modulatorPhase,
                                 carrierFrequency: carrierFrequency,
                                 modulatorFrequency: modulatorFrequency,
                                 framePosition: framePosition)
            
        case .phaseModulation:
            return processPhaseModulation(carrierWavetable: carrierWavetable,
                                        modulatorWavetable: modulatorWavetable,
                                        carrierPhase: carrierPhase,
                                        modulatorPhase: modulatorPhase,
                                        framePosition: framePosition)
            
        case .frequencyModulation:
            return processFrequencyModulation(carrierWavetable: carrierWavetable,
                                            modulatorWavetable: modulatorWavetable,
                                            carrierPhase: carrierPhase,
                                            modulatorPhase: modulatorPhase,
                                            carrierFrequency: carrierFrequency,
                                            framePosition: framePosition)
            
        case .amplitudeModulation:
            return processAmplitudeModulation(carrierWavetable: carrierWavetable,
                                            modulatorWavetable: modulatorWavetable,
                                            carrierPhase: carrierPhase,
                                            modulatorPhase: modulatorPhase,
                                            framePosition: framePosition)
            
        case .pulseWidthModulation:
            return processPulseWidthModulation(carrierWavetable: carrierWavetable,
                                             modulatorWavetable: modulatorWavetable,
                                             carrierPhase: carrierPhase,
                                             modulatorPhase: modulatorPhase,
                                             framePosition: framePosition)
        }
    }
    
    // MARK: - Specific Modulation Implementations
    
    private func processRingModulation(carrierWavetable: WavetableData,
                                     modulatorWavetable: WavetableData,
                                     carrierPhase: Float,
                                     modulatorPhase: Float,
                                     carrierFrequency: Float,
                                     framePosition: Float) -> Float {
        
        let carrierSample = synthesizeCarrier(wavetable: carrierWavetable, phase: carrierPhase, framePosition: framePosition)
        let modulatorSample = synthesizeModulator(wavetable: modulatorWavetable, phase: modulatorPhase, framePosition: framePosition)
        
        if parameters.antiAliasing {
            return ringModEngine.processRingModulationAntiAliased(carrierSample: carrierSample, 
                                                                 modulatorSample: modulatorSample,
                                                                 depth: parameters.depth,
                                                                 fundamental: carrierFrequency)
        } else {
            return ringModEngine.processRingModulation(carrierSample: carrierSample,
                                                     modulatorSample: modulatorSample,
                                                     depth: parameters.depth)
        }
    }
    
    private func processHardSync(carrierWavetable: WavetableData,
                               modulatorWavetable: WavetableData,
                               carrierPhase: Float,
                               modulatorPhase: Float,
                               carrierFrequency: Float,
                               modulatorFrequency: Float,
                               framePosition: Float) -> Float {
        
        if parameters.antiAliasing {
            return hardSyncEngine.processHardSyncAntiAliased(carrierPhase: carrierPhase,
                                                           masterPhase: modulatorPhase,
                                                           frequency: carrierFrequency,
                                                           masterFrequency: modulatorFrequency,
                                                           wavetable: carrierWavetable)
        } else {
            let (syncedPhase, _) = hardSyncEngine.processHardSync(carrierPhase: carrierPhase,
                                                                masterPhase: modulatorPhase,
                                                                frequency: carrierFrequency,
                                                                masterFrequency: modulatorFrequency)
            return synthesizeCarrier(wavetable: carrierWavetable, phase: syncedPhase, framePosition: framePosition)
        }
    }
    
    private func processPhaseModulation(carrierWavetable: WavetableData,
                                      modulatorWavetable: WavetableData,
                                      carrierPhase: Float,
                                      modulatorPhase: Float,
                                      framePosition: Float) -> Float {
        
        let modulatorSample = synthesizeModulator(wavetable: modulatorWavetable, phase: modulatorPhase, framePosition: framePosition)
        let phaseModAmount = modulatorSample * parameters.depth
        let modulatedPhase = fmod(carrierPhase + phaseModAmount + 1.0, 1.0)
        
        return synthesizeCarrier(wavetable: carrierWavetable, phase: modulatedPhase, framePosition: framePosition)
    }
    
    private func processFrequencyModulation(carrierWavetable: WavetableData,
                                          modulatorWavetable: WavetableData,
                                          carrierPhase: Float,
                                          modulatorPhase: Float,
                                          carrierFrequency: Float,
                                          framePosition: Float) -> Float {
        
        let modulatorSample = synthesizeModulator(wavetable: modulatorWavetable, phase: modulatorPhase, framePosition: framePosition)
        let freqModAmount = modulatorSample * parameters.depth * carrierFrequency
        let modulatedFreq = carrierFrequency + freqModAmount
        
        // This would require integration for proper FM - simplified here
        let phaseModAmount = (freqModAmount / sampleRate) * 2.0 * Float.pi
        let modulatedPhase = fmod(carrierPhase + phaseModAmount + 1.0, 1.0)
        
        return synthesizeCarrier(wavetable: carrierWavetable, phase: modulatedPhase, framePosition: framePosition)
    }
    
    private func processAmplitudeModulation(carrierWavetable: WavetableData,
                                          modulatorWavetable: WavetableData,
                                          carrierPhase: Float,
                                          modulatorPhase: Float,
                                          framePosition: Float) -> Float {
        
        let carrierSample = synthesizeCarrier(wavetable: carrierWavetable, phase: carrierPhase, framePosition: framePosition)
        let modulatorSample = synthesizeModulator(wavetable: modulatorWavetable, phase: modulatorPhase, framePosition: framePosition)
        
        // AM: carrier * (1 + depth * modulator)
        let modulationAmount = 1.0 + parameters.depth * modulatorSample
        return carrierSample * modulationAmount
    }
    
    private func processPulseWidthModulation(carrierWavetable: WavetableData,
                                           modulatorWavetable: WavetableData,
                                           carrierPhase: Float,
                                           modulatorPhase: Float,
                                           framePosition: Float) -> Float {
        
        let modulatorSample = synthesizeModulator(wavetable: modulatorWavetable, phase: modulatorPhase, framePosition: framePosition)
        let pulseWidth = 0.5 + parameters.depth * modulatorSample * 0.4 // Keep width between 0.1 and 0.9
        
        // Simple pulse wave with modulated width
        return carrierPhase < pulseWidth ? 1.0 : -1.0
    }
    
    // MARK: - Helper Methods
    
    private func synthesizeCarrier(wavetable: WavetableData, phase: Float, framePosition: Float) -> Float {
        let frameIndex = Int(framePosition) % wavetable.frameCount
        let samplePosition = phase * Float(wavetable.frameSize)
        return wavetable.getSample(frameIndex: frameIndex, position: samplePosition, interpolation: .linear)
    }
    
    private func synthesizeModulator(wavetable: WavetableData, phase: Float, framePosition: Float) -> Float {
        let frameIndex = Int(framePosition) % wavetable.frameCount
        let samplePosition = phase * Float(wavetable.frameSize)
        return wavetable.getSample(frameIndex: frameIndex, position: samplePosition, interpolation: .linear)
    }
    
    private func updateProcessingMode() {
        // Configure engines based on modulation type
        ringModEngine.parameters = parameters
        hardSyncEngine.parameters = parameters
    }
    
    private func updateEngineParameters() {
        ringModEngine.parameters = parameters
        hardSyncEngine.parameters = parameters
    }
    
    private func updateSampleRate() {
        ringModEngine.sampleRate = sampleRate
        hardSyncEngine.sampleRate = sampleRate
    }
    
    // MARK: - Advanced Features
    
    /// Reset all internal state
    public func reset() {
        phaseAccumulator = 0.0
        modulatorAccumulator = 0.0
        // Reset engine states would go here
    }
    
    /// Set phase manually
    public func setPhase(carrier: Float, modulator: Float) {
        phaseAccumulator = fmod(carrier + 1.0, 1.0)
        modulatorAccumulator = fmod(modulator + 1.0, 1.0)
    }
    
    /// Get current modulation state for debugging
    public func getModulationState() -> (carrierPhase: Float, modulatorPhase: Float, modulationType: OscillatorModulationType) {
        return (phaseAccumulator, modulatorAccumulator, modulationType)
    }
}

// MARK: - Extensions for Integration

extension WavetableData {
    
    /// Convenience method for oscillator modulation synthesis
    public func synthesizeWithModulation(
        modulatorWavetable: WavetableData,
        carrierPhase: Float,
        modulatorPhase: Float,
        modulationSystem: OscillatorModulationSystem,
        carrierFrequency: Float,
        modulatorFrequency: Float,
        framePosition: Float = 0.0
    ) -> Float {
        return modulationSystem.processSample(
            carrierWavetable: self,
            modulatorWavetable: modulatorWavetable,
            carrierPhase: carrierPhase,
            modulatorPhase: modulatorPhase,
            carrierFrequency: carrierFrequency,
            modulatorFrequency: modulatorFrequency,
            framePosition: framePosition
        )
    }
}