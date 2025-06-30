// FMDrumVoice.swift
// DigitonePad - VoiceModule
//
// Individual FM drum voice with specialized percussion synthesis

import Foundation
import Accelerate
import QuartzCore

/// A complete FM drum voice with body, noise, and modulation components
public final class FMDrumVoice: @unchecked Sendable {
    // Voice properties
    public var note: UInt8 = 60
    public var velocity: UInt8 = 100
    public var isActive: Bool = false
    public var startTime: Double = 0.0
    
    // FM Body Component (3 operators for drum body)
    private var bodyOperators: [FMOperator] = []
    // private var optimizedBodyOperators: [FMDrumDSPOptimizations.OptimizedFMOperator] = []
    private var bodyAlgorithm: DrumFMAlgorithm = .kickAlgorithm

    // Noise/Transient Component
    private var noiseGenerator: NoiseGenerator
    // private var optimizedNoiseGenerator: FMDrumDSPOptimizations.OptimizedNoiseGenerator
    private var noiseFilter: BandpassFilter
    // private var optimizedNoiseFilter: FMDrumDSPOptimizations.OptimizedBandpassFilter
    
    // Pitch Sweep Module
    private var pitchEnvelope: PitchEnvelope
    
    // Wavefolding Distortion
    private var waveFolder: WaveFolder
    
    // Specialized ADSR Envelopes
    private var amplitudeEnvelope: DrumADSR
    private var noiseEnvelope: DrumADSR
    private var filterEnvelope: DrumADSR
    
    // Parameters
    private var bodyTone: Double = 0.5
    private var noiseLevel: Double = 0.3
    private var pitchSweepAmount: Double = 0.4
    private var pitchSweepTime: Double = 0.1
    private var wavefoldAmount: Double = 0.2

    // Performance settings
    private var useOptimizedDSP: Bool = true
    private var processingMode: ProcessingMode = .realtime

    // DSP object pool for optimization (temporarily disabled)
    // private static var dspPool: FMDrumDSPOptimizations.DSPObjectPool?

    // Modulation matrix (temporarily disabled)
    // private let modulationMatrix: FMDrumModulationMatrix

    private let sampleRate: Double
    
    public init(sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate
        
        // Initialize FM body operators (3 operators for drums)
        for _ in 0..<3 {
            bodyOperators.append(FMOperator(sampleRate: sampleRate))
        }
        
        // Initialize components
        self.noiseGenerator = NoiseGenerator()
        // self.optimizedNoiseGenerator = FMDrumDSPOptimizations.OptimizedNoiseGenerator()
        self.noiseFilter = BandpassFilter(sampleRate: sampleRate)
        // self.optimizedNoiseFilter = FMDrumDSPOptimizations.OptimizedBandpassFilter(sampleRate: sampleRate)
        self.pitchEnvelope = PitchEnvelope(sampleRate: sampleRate)
        self.waveFolder = WaveFolder()
        // self.modulationMatrix = FMDrumModulationMatrix()

        // Initialize optimized operators (temporarily disabled)
        // for _ in 0..<3 {
        //     optimizedBodyOperators.append(FMDrumDSPOptimizations.OptimizedFMOperator(sampleRate: sampleRate))
        // }

        // Initialize DSP pool if needed (temporarily disabled)
        // if Self.dspPool == nil {
        //     Self.dspPool = FMDrumDSPOptimizations.DSPObjectPool(sampleRate: sampleRate)
        // }
        
        // Initialize envelopes with drum-optimized settings
        self.amplitudeEnvelope = DrumADSR(sampleRate: sampleRate, type: .amplitude)
        self.noiseEnvelope = DrumADSR(sampleRate: sampleRate, type: .noise)
        self.filterEnvelope = DrumADSR(sampleRate: sampleRate, type: .filter)
        
        setupDefaultConfiguration()
    }
    
    // MARK: - Voice Control
    
    /// Start the drum voice
    public func noteOn(note: UInt8, velocity: UInt8) {
        self.note = note
        self.velocity = velocity
        self.isActive = true
        self.startTime = CACurrentMediaTime()
        
        // Calculate base frequency from MIDI note
        let baseFrequency = midiNoteToFrequency(note)
        
        // Configure FM body operators based on drum algorithm
        configureBodyOperators(baseFrequency: baseFrequency, velocity: velocity)
        
        // Configure noise component
        configureNoiseComponent(velocity: velocity)
        
        // Configure pitch sweep
        configurePitchSweep(baseFrequency: baseFrequency)
        
        // Trigger all envelopes
        amplitudeEnvelope.noteOn(velocity: velocity)
        noiseEnvelope.noteOn(velocity: velocity)
        filterEnvelope.noteOn(velocity: velocity)
        pitchEnvelope.trigger()
        
        // Reset operator phases
        for fmOperator in bodyOperators {
            fmOperator.reset()
        }
    }
    
    /// Stop the drum voice (quick release)
    public func noteOff() {
        amplitudeEnvelope.noteOff()
        noiseEnvelope.noteOff()
        filterEnvelope.noteOff()
    }
    
    /// Quick release for voice stealing
    public func quickRelease() {
        amplitudeEnvelope.quickRelease()
        noiseEnvelope.quickRelease()
        filterEnvelope.quickRelease()
    }
    
    // MARK: - Audio Processing
    
    /// Process one sample
    public func processSample() -> Double {
        guard isActive else { return 0.0 }
        
        // Process envelopes
        let ampEnv = amplitudeEnvelope.processSample()
        let noiseEnv = noiseEnvelope.processSample()
        let filterEnv = filterEnvelope.processSample()
        let pitchMod = pitchEnvelope.processSample()

        // Temporarily disabled modulation processing
        /*
        updateModulationSources(
            ampEnv: ampEnv,
            noiseEnv: noiseEnv,
            filterEnv: filterEnv,
            pitchMod: pitchMod
        )

        // Process modulation matrix
        modulationMatrix.processModulation()
        */

        // Check if voice should be deactivated
        if amplitudeEnvelope.isFinished && noiseEnvelope.isFinished {
            isActive = false
            return 0.0
        }
        
        // Temporarily use unmodulated parameters
        // Apply modulation to parameters
        /*
        let modulatedPitchMod = pitchMod + modulationMatrix.getTargetValue(.pitchSweepAmount)
        let modulatedBodyTone = bodyTone + modulationMatrix.getTargetValue(.amplitudeLevel)
        let modulatedNoiseLevel = noiseLevel + modulationMatrix.getTargetValue(.noiseLevel)
        let modulatedWavefoldAmount = wavefoldAmount + modulationMatrix.getTargetValue(.wavefoldAmount)
        */

        // Process FM body with pitch modulation
        var bodyOutput = processFMBody(pitchModulation: pitchMod)

        // Process noise component
        let noiseOutput = processNoiseComponent(envelope: noiseEnv, filterEnv: filterEnv)

        // Mix body and noise
        var mixedOutput = (bodyOutput * bodyTone) + (noiseOutput * noiseLevel)
        
        // Apply wavefolding distortion
        if wavefoldAmount > 0.0 {
            mixedOutput = waveFolder.process(input: mixedOutput, amount: wavefoldAmount)
        }
        
        // Apply amplitude envelope
        mixedOutput *= ampEnv
        
        return mixedOutput
    }

    /// Process multiple samples using optimized SIMD algorithms
    public func processVector(sampleCount: Int) -> [Double] {
        guard isActive else { return Array(repeating: 0.0, count: sampleCount) }

        if useOptimizedDSP {
            return processOptimizedVector(sampleCount: sampleCount)
        } else {
            // Fallback to single sample processing
            var output = Array(repeating: 0.0, count: sampleCount)
            for i in 0..<sampleCount {
                output[i] = processSample()
            }
            return output
        }
    }

    private func processOptimizedVector(sampleCount: Int) -> [Double] {
        // Fallback to standard processing until optimized components are implemented
        var output = Array(repeating: 0.0, count: sampleCount)
        for i in 0..<sampleCount {
            output[i] = processSample()
        }
        return output
    }

    private func processFMBody(pitchModulation: Double) -> Double {
        // Apply pitch modulation to all operators
        for (index, fmOperator) in bodyOperators.enumerated() {
            let pitchMod = pitchModulation * pitchSweepAmount
            fmOperator.setPitchModulation(pitchMod)
        }
        
        // Process FM algorithm for drums
        return bodyAlgorithm.process(operators: bodyOperators)
    }
    
    private func processNoiseComponent(envelope: Double, filterEnv: Double) -> Double {
        // Generate noise
        let noise = noiseGenerator.processSample()
        
        // Apply filter with envelope modulation
        let filteredNoise = noiseFilter.process(input: noise, cutoffMod: filterEnv)
        
        return filteredNoise * envelope
    }

    private func processOptimizedFMBodyVector(pitchModulation: [Double]) -> [Double] {
        // Fallback to standard processing until optimized components are implemented
        var output = Array(repeating: 0.0, count: pitchModulation.count)
        for i in 0..<pitchModulation.count {
            // Apply pitch modulation to all operators
            for fmOperator in bodyOperators {
                let pitchMod = pitchModulation[i] * pitchSweepAmount
                fmOperator.setPitchModulation(pitchMod)
            }
            // Process FM algorithm for drums
            output[i] = bodyAlgorithm.process(operators: bodyOperators)
        }
        return output
    }

    /// Enable or disable optimized DSP processing
    public func setOptimizedDSP(_ enabled: Bool) {
        useOptimizedDSP = enabled
    }

    /// Set processing mode for performance tuning
    public func setProcessingMode(_ mode: ProcessingMode) {
        processingMode = mode
    }

    // MARK: - Modulation (temporarily disabled)

    /*
    private func updateModulationSources(
        ampEnv: Double,
        noiseEnv: Double,
        filterEnv: Double,
        pitchMod: Double
    ) {
        // Update envelope sources
        modulationMatrix.updateSourceValue(.amplitudeEnvelope, value: ampEnv)
        modulationMatrix.updateSourceValue(.noiseEnvelope, value: noiseEnv)
        modulationMatrix.updateSourceValue(.filterEnvelope, value: filterEnv)
        modulationMatrix.updateSourceValue(.pitchEnvelope, value: pitchMod)

        // Update velocity (normalized)
        let velocityNormalized = Double(velocity) / 127.0
        modulationMatrix.updateSourceValue(.velocity, value: velocityNormalized)

        // Update key tracking (based on MIDI note)
        let keyTrackingValue = (Double(note) - 60.0) / 64.0 // -1 to 1 range
        modulationMatrix.updateSourceValue(.keyTracking, value: keyTrackingValue)

        // Update random source (new random value each sample)
        let randomValue = Double.random(in: -1.0...1.0)
        modulationMatrix.updateSourceValue(.randomSource, value: randomValue)
    }

    /// Get the modulation matrix for external access
    public func getModulationMatrix() -> FMDrumModulationMatrix {
        return modulationMatrix
    }

    /// Update MIDI-based modulation sources
    public func updateMIDIModulation(
        pitchBend: Double = 0.0,
        modWheel: Double = 0.0,
        aftertouch: Double = 0.0
    ) {
        modulationMatrix.updateSourceValue(.pitchBend, value: pitchBend)
        modulationMatrix.updateSourceValue(.modWheel, value: modWheel)
        modulationMatrix.updateSourceValue(.aftertouch, value: aftertouch)
    }
    */

    // MARK: - Configuration
    
    public func configureDrumVoice(
        drumType: DrumType,
        bodyTone: Double,
        noiseLevel: Double,
        pitchSweepAmount: Double,
        pitchSweepTime: Double,
        wavefoldAmount: Double
    ) {
        self.bodyTone = bodyTone
        self.noiseLevel = noiseLevel
        self.pitchSweepAmount = pitchSweepAmount
        self.pitchSweepTime = pitchSweepTime
        self.wavefoldAmount = wavefoldAmount
        
        // Configure components based on drum type
        configureDrumType(drumType)
    }
    
    public func updateParameters(
        bodyTone: Double,
        noiseLevel: Double,
        pitchSweepAmount: Double,
        pitchSweepTime: Double,
        wavefoldAmount: Double
    ) {
        self.bodyTone = bodyTone
        self.noiseLevel = noiseLevel
        self.pitchSweepAmount = pitchSweepAmount
        self.pitchSweepTime = pitchSweepTime
        self.wavefoldAmount = wavefoldAmount
        
        // Update pitch envelope time
        pitchEnvelope.setDecayTime(pitchSweepTime)
    }
    
    private func configureDrumType(_ drumType: DrumType) {
        switch drumType {
        case .kick:
            bodyAlgorithm = .kickAlgorithm
            noiseFilter.setCutoff(frequency: 80.0, resonance: 0.5)
            amplitudeEnvelope.setTimes(attack: 0.001, decay: 0.3, sustain: 0.0, release: 0.1)
            noiseEnvelope.setTimes(attack: 0.001, decay: 0.05, sustain: 0.0, release: 0.02)
            
        case .snare:
            bodyAlgorithm = .snareAlgorithm
            noiseFilter.setCutoff(frequency: 200.0, resonance: 0.7)
            amplitudeEnvelope.setTimes(attack: 0.001, decay: 0.15, sustain: 0.0, release: 0.05)
            noiseEnvelope.setTimes(attack: 0.001, decay: 0.1, sustain: 0.0, release: 0.03)
            
        case .hihat:
            bodyAlgorithm = .hihatAlgorithm
            noiseFilter.setCutoff(frequency: 8000.0, resonance: 0.3)
            amplitudeEnvelope.setTimes(attack: 0.001, decay: 0.05, sustain: 0.0, release: 0.02)
            noiseEnvelope.setTimes(attack: 0.001, decay: 0.04, sustain: 0.0, release: 0.01)
            
        case .tom:
            bodyAlgorithm = .tomAlgorithm
            noiseFilter.setCutoff(frequency: 150.0, resonance: 0.4)
            amplitudeEnvelope.setTimes(attack: 0.001, decay: 0.4, sustain: 0.0, release: 0.1)
            noiseEnvelope.setTimes(attack: 0.001, decay: 0.08, sustain: 0.0, release: 0.03)
            
        case .cymbal:
            bodyAlgorithm = .cymbalAlgorithm
            noiseFilter.setCutoff(frequency: 5000.0, resonance: 0.2)
            amplitudeEnvelope.setTimes(attack: 0.001, decay: 0.8, sustain: 0.0, release: 0.3)
            noiseEnvelope.setTimes(attack: 0.001, decay: 0.6, sustain: 0.0, release: 0.2)
        }
    }
    
    private func configureBodyOperators(baseFrequency: Double, velocity: UInt8) {
        let velocityScale = Double(velocity) / 127.0
        
        // Configure operators based on current algorithm
        bodyAlgorithm.configureOperators(
            operators: bodyOperators,
            baseFrequency: baseFrequency,
            velocity: velocityScale
        )
    }
    
    private func configureNoiseComponent(velocity: UInt8) {
        let velocityScale = Double(velocity) / 127.0
        noiseGenerator.setLevel(velocityScale)
    }
    
    private func configurePitchSweep(baseFrequency: Double) {
        pitchEnvelope.configure(
            startPitch: 1.0,
            endPitch: 0.0,
            decayTime: pitchSweepTime
        )
    }
    
    private func setupDefaultConfiguration() {
        // Set default drum configuration (kick drum)
        configureDrumType(.kick)
    }
}

// MARK: - Utility Functions

/// Convert MIDI note to frequency
private func midiNoteToFrequency(_ note: UInt8) -> Double {
    return 440.0 * pow(2.0, (Double(note) - 69.0) / 12.0)
}

// MARK: - Drum FM Algorithms

/// Specialized FM algorithms for drum sounds
public enum DrumFMAlgorithm {
    case kickAlgorithm
    case snareAlgorithm
    case hihatAlgorithm
    case tomAlgorithm
    case cymbalAlgorithm

    /// Process the FM algorithm with the given operators
    func process(operators: [FMOperator]) -> Double {
        guard operators.count >= 3 else { return 0.0 }

        switch self {
        case .kickAlgorithm:
            // Op2 -> Op1 -> Op0 (series chain for punchy kick)
            let op2 = operators[2].processSample()
            let op1 = operators[1].processSample(modulationInput: op2)
            return operators[0].processSample(modulationInput: op1)

        case .snareAlgorithm:
            // Op2 -> Op0, Op1 -> Op0 (parallel for snare body + rattle)
            let op2 = operators[2].processSample()
            let op1 = operators[1].processSample()
            return operators[0].processSample(modulationInput: op2 + op1 * 0.5)

        case .hihatAlgorithm:
            // All operators in parallel for metallic sound
            let op0 = operators[0].processSample()
            let op1 = operators[1].processSample()
            let op2 = operators[2].processSample()
            return (op0 + op1 * 0.7 + op2 * 0.5) / 2.2

        case .tomAlgorithm:
            // Op2 -> Op1 -> Op0 with feedback for tom resonance
            let op2 = operators[2].processSample()
            let op1 = operators[1].processSample(modulationInput: op2)
            return operators[0].processSample(modulationInput: op1)

        case .cymbalAlgorithm:
            // Complex routing for cymbal harmonics
            let op2 = operators[2].processSample()
            let op1 = operators[1].processSample(modulationInput: op2 * 0.3)
            let op0 = operators[0].processSample(modulationInput: op1 * 0.8)
            return op0 + op1 * 0.4 + op2 * 0.2
        }
    }

    /// Process the FM algorithm with optimized operators for multiple samples (temporarily disabled)
    /*
    func processVector(operators: [FMDrumDSPOptimizations.OptimizedFMOperator], sampleCount: Int) -> [Double] {
        guard operators.count >= 3 else { return Array(repeating: 0.0, count: sampleCount) }

        switch self {
        case .kickAlgorithm:
            // Op2 -> Op1 -> Op0 (series chain for punchy kick)
            let op2Output = operators[2].processVector()
            let op1Output = operators[1].processVector(modulationInput: op2Output)
            return operators[0].processVector(modulationInput: op1Output)

        case .snareAlgorithm:
            // Op2 -> Op0, Op1 -> Op0 (parallel for snare body + rattle)
            let op2Output = operators[2].processVector()
            let op1Output = operators[1].processVector()
            let combinedMod = zip(op2Output, op1Output).map { $0 + $1 * 0.5 }
            return operators[0].processVector(modulationInput: combinedMod)

        case .hihatAlgorithm:
            // All operators in parallel for metallic sound
            let op0Output = operators[0].processVector()
            let op1Output = operators[1].processVector()
            let op2Output = operators[2].processVector()
            return zip(zip(op0Output, op1Output), op2Output).map {
                ($0.0 + $0.1 * 0.7 + $1 * 0.5) / 2.2
            }

        case .tomAlgorithm:
            // Op2 -> Op1 -> Op0 with feedback for tom resonance
            let op2Output = operators[2].processVector()
            let op1Output = operators[1].processVector(modulationInput: op2Output)
            return operators[0].processVector(modulationInput: op1Output)

        case .cymbalAlgorithm:
            // Complex routing for cymbal harmonics
            let op2Output = operators[2].processVector()
            let op1ModInput = op2Output.map { $0 * 0.3 }
            let op1Output = operators[1].processVector(modulationInput: op1ModInput)
            let op0ModInput = op1Output.map { $0 * 0.8 }
            let op0Output = operators[0].processVector(modulationInput: op0ModInput)

            return zip(zip(op0Output, op1Output), op2Output).map {
                $0.0 + $0.1 * 0.4 + $1 * 0.2
            }
        }
    }
    */

    /// Configure operators for this algorithm
    func configureOperators(operators: [FMOperator], baseFrequency: Double, velocity: Double) {
        guard operators.count >= 3 else { return }

        switch self {
        case .kickAlgorithm:
            operators[0].setFrequency(baseFrequency * 1.0)
            operators[1].setFrequency(baseFrequency * 2.0)
            operators[2].setFrequency(baseFrequency * 0.5)
            operators[0].amplitude = velocity * 1.0
            operators[1].amplitude = velocity * 0.8
            operators[2].amplitude = velocity * 0.6
            operators[1].modulationIndex = 2.0
            operators[2].modulationIndex = 1.5

        case .snareAlgorithm:
            operators[0].setFrequency(baseFrequency * 1.0)
            operators[1].setFrequency(baseFrequency * 3.7)  // Inharmonic for snare buzz
            operators[2].setFrequency(baseFrequency * 1.3)
            operators[0].amplitude = velocity * 1.0
            operators[1].amplitude = velocity * 0.6
            operators[2].amplitude = velocity * 0.7
            operators[1].modulationIndex = 1.2
            operators[2].modulationIndex = 1.8

        case .hihatAlgorithm:
            operators[0].setFrequency(baseFrequency * 4.0)
            operators[1].setFrequency(baseFrequency * 6.7)  // Inharmonic ratios
            operators[2].setFrequency(baseFrequency * 9.3)
            operators[0].amplitude = velocity * 0.8
            operators[1].amplitude = velocity * 0.6
            operators[2].amplitude = velocity * 0.4
            operators[0].modulationIndex = 0.5
            operators[1].modulationIndex = 0.3
            operators[2].modulationIndex = 0.2

        case .tomAlgorithm:
            operators[0].setFrequency(baseFrequency * 1.0)
            operators[1].setFrequency(baseFrequency * 1.8)
            operators[2].setFrequency(baseFrequency * 0.7)
            operators[0].amplitude = velocity * 1.0
            operators[1].amplitude = velocity * 0.7
            operators[2].amplitude = velocity * 0.5
            operators[1].modulationIndex = 1.5
            operators[2].modulationIndex = 1.0

        case .cymbalAlgorithm:
            operators[0].setFrequency(baseFrequency * 2.3)
            operators[1].setFrequency(baseFrequency * 5.1)
            operators[2].setFrequency(baseFrequency * 8.7)
            operators[0].amplitude = velocity * 0.9
            operators[1].amplitude = velocity * 0.6
            operators[2].amplitude = velocity * 0.4
            operators[0].modulationIndex = 0.8
            operators[1].modulationIndex = 0.6
            operators[2].modulationIndex = 0.4
        }
    }
}

// MARK: - Processing Mode

public enum ProcessingMode {
    case realtime      // Optimized for low latency
    case quality       // Optimized for audio quality
    case balanced      // Balance between latency and quality
}
