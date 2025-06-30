import Foundation
import Accelerate
import simd

// MARK: - Phase Distortion Types

/// Available phase distortion algorithms
public enum PhaseDistortionType: CaseIterable, Codable {
    case none, sine, exponential, logarithmic, polynomial
    case window, fold, wrap, compress
}

// MARK: - Phase Distortion Parameters

/// Parameters for controlling phase distortion
public struct PhaseDistortionParameters {
    /// Primary distortion amount (0.0 to 1.0)
    public var amount: Float = 0.0
    
    /// Secondary distortion parameter (usage varies by type)
    public var curve: Float = 0.5
    
    /// Distortion asymmetry (-1.0 to 1.0)
    public var asymmetry: Float = 0.0
    
    /// Phase offset (0.0 to 1.0)
    public var offset: Float = 0.0
    
    /// Frequency-dependent distortion scaling
    public var frequencyTracking: Float = 0.0
    
    /// Parameter smoothing time constant
    public var smoothingTime: Float = 0.001
    
    public init() {}
}

// MARK: - Phase Distortion Engine

/// High-performance phase distortion processor for wavetable synthesis
public class PhaseDistortionEngine {
    
    // MARK: - Properties
    
    /// Current distortion type
    public var distortionType: PhaseDistortionType = .none {
        didSet {
            if distortionType != oldValue {
                updateLookupTable()
            }
        }
    }
    
    /// Distortion parameters
    public var parameters = PhaseDistortionParameters() {
        didSet {
            smoothingNeeded = true
        }
    }
    
    /// Sample rate for parameter smoothing
    public var sampleRate: Float = 44100.0 {
        didSet {
            updateSmoothingCoefficients()
        }
    }
    
    // MARK: - Private Properties
    
    private var currentParams = PhaseDistortionParameters()
    private var targetParams = PhaseDistortionParameters()
    private var smoothingNeeded = false
    
    // Lookup table for phase distortion curve (for performance)
    private var lookupTable: [Float] = []
    private let lookupTableSize = 1024
    
    // Parameter smoothing coefficients
    private var amountSmooth: Float = 0.0
    private var curveSmooth: Float = 0.0
    private var asymmetrySmooth: Float = 0.0
    private var offsetSmooth: Float = 0.0
    
    // Smoothing low-pass filter coefficients
    private var smoothingCoeff: Float = 0.99
    
    // MARK: - Initialization
    
    public init(sampleRate: Float = 44100.0) {
        self.sampleRate = sampleRate
        updateSmoothingCoefficients()
        updateLookupTable()
    }
    
    // MARK: - Public Methods
    
    /// Apply phase distortion to a phase value
    /// - Parameters:
    ///   - phase: Input phase (0.0 to 1.0)
    ///   - frequency: Fundamental frequency for tracking
    /// - Returns: Distorted phase (0.0 to 1.0)
    public func distortPhase(_ phase: Float, frequency: Float = 440.0) -> Float {
        updateParameterSmoothing()
        
        let trackingScale = 1.0 + currentParams.frequencyTracking * log2(frequency / 440.0)
        let scaledAmount = currentParams.amount * trackingScale
        
        return applyDistortion(phase, amount: scaledAmount)
    }
    
    /// Apply phase distortion to an array of phase values (vectorized)
    /// - Parameters:
    ///   - phases: Input phase array (0.0 to 1.0)
    ///   - frequency: Fundamental frequency for tracking
    ///   - output: Output array (must be same size as input)
    public func distortPhases(_ phases: [Float], frequency: Float = 440.0, output: inout [Float]) {
        precondition(phases.count == output.count, "Input and output arrays must be same size")
        
        updateParameterSmoothing()
        
        let trackingScale = 1.0 + currentParams.frequencyTracking * log2(frequency / 440.0)
        let scaledAmount = currentParams.amount * trackingScale
        
        for i in 0..<phases.count {
            output[i] = applyDistortion(phases[i], amount: scaledAmount)
        }
    }
    
    /// Apply phase distortion using SIMD for optimal performance
    /// - Parameters:
    ///   - phases: Input phase array
    ///   - frequency: Fundamental frequency
    ///   - output: Output array
    public func distortPhasesSIMD(_ phases: UnsafePointer<Float>, count: Int, frequency: Float, output: UnsafeMutablePointer<Float>) {
        updateParameterSmoothing()
        
        let trackingScale = 1.0 + currentParams.frequencyTracking * log2(frequency / 440.0)
        let scaledAmount = currentParams.amount * trackingScale
        
        // Process in SIMD chunks of 4
        let simdCount = count & ~3  // Round down to multiple of 4
        
        for i in stride(from: 0, to: simdCount, by: 4) {
            let inputVec = simd_float4(phases[i], phases[i+1], phases[i+2], phases[i+3])
            let outputVec = applySIMDDistortion(inputVec, amount: scaledAmount)
            
            output[i] = outputVec.x
            output[i+1] = outputVec.y
            output[i+2] = outputVec.z
            output[i+3] = outputVec.w
        }
        
        // Process remaining elements
        for i in simdCount..<count {
            output[i] = applyDistortion(phases[i], amount: scaledAmount)
        }
    }
    
    // MARK: - Private Methods
    
    private func updateParameterSmoothing() {
        if smoothingNeeded {
            targetParams = parameters
            smoothingNeeded = false
        }
        
        // Smooth parameters to avoid clicks
        currentParams.amount = currentParams.amount * smoothingCoeff + targetParams.amount * (1.0 - smoothingCoeff)
        currentParams.curve = currentParams.curve * smoothingCoeff + targetParams.curve * (1.0 - smoothingCoeff)
        currentParams.asymmetry = currentParams.asymmetry * smoothingCoeff + targetParams.asymmetry * (1.0 - smoothingCoeff)
        currentParams.offset = currentParams.offset * smoothingCoeff + targetParams.offset * (1.0 - smoothingCoeff)
    }
    
    private func updateSmoothingCoefficients() {
        let cutoffFreq: Float = 1.0 / parameters.smoothingTime
        let omega = 2.0 * Float.pi * cutoffFreq / sampleRate
        smoothingCoeff = exp(-omega)
    }
    
    private func updateLookupTable() {
        lookupTable.removeAll()
        lookupTable.reserveCapacity(lookupTableSize)
        
        for i in 0..<lookupTableSize {
            let phase = Float(i) / Float(lookupTableSize - 1)
            let distortedPhase = computeDistortion(phase, type: distortionType, amount: 1.0, curve: 0.5, asymmetry: 0.0)
            lookupTable.append(distortedPhase)
        }
    }
    
    private func applyDistortion(_ phase: Float, amount: Float) -> Float {
        if amount <= 0.001 {
            return phase + currentParams.offset
        }
        
        let basePhase = fmod(phase + currentParams.offset + 1.0, 1.0)
        let distortedPhase = computeDistortion(basePhase, type: distortionType, 
                                             amount: amount, 
                                             curve: currentParams.curve, 
                                             asymmetry: currentParams.asymmetry)
        
        return fmod(distortedPhase + 1.0, 1.0)
    }
    
    private func applySIMDDistortion(_ phases: simd_float4, amount: Float) -> simd_float4 {
        if amount <= 0.001 {
            return phases + simd_float4(repeating: currentParams.offset)
        }
        
        let basePhases = fmod(phases + simd_float4(repeating: currentParams.offset + 1.0), simd_float4(repeating: 1.0))
        
        // Apply distortion to each component
        let result = simd_float4(
            computeDistortion(basePhases.x, type: distortionType, amount: amount, curve: currentParams.curve, asymmetry: currentParams.asymmetry),
            computeDistortion(basePhases.y, type: distortionType, amount: amount, curve: currentParams.curve, asymmetry: currentParams.asymmetry),
            computeDistortion(basePhases.z, type: distortionType, amount: amount, curve: currentParams.curve, asymmetry: currentParams.asymmetry),
            computeDistortion(basePhases.w, type: distortionType, amount: amount, curve: currentParams.curve, asymmetry: currentParams.asymmetry)
        )
        
        return fmod(result + simd_float4(repeating: 1.0), simd_float4(repeating: 1.0))
    }
    
    private func computeDistortion(_ phase: Float, type: PhaseDistortionType, amount: Float, curve: Float, asymmetry: Float) -> Float {
        var normalizedPhase = max(0.0, min(1.0, phase))
        
        // Apply asymmetry
        if asymmetry != 0.0 {
            if normalizedPhase < 0.5 {
                normalizedPhase = normalizedPhase * (1.0 + asymmetry)
            } else {
                normalizedPhase = 0.5 + (normalizedPhase - 0.5) * (1.0 - asymmetry)
            }
            normalizedPhase = max(0.0, min(1.0, normalizedPhase))
        }
        
        let baseDistortion: Float
        
        switch type {
        case .none:
            baseDistortion = normalizedPhase
            
        case .sine:
            // Sine wave shaping: creates smooth harmonic distortion
            let sinePhase = sin(Float.pi * normalizedPhase)
            baseDistortion = normalizedPhase + amount * (sinePhase - normalizedPhase) * curve
            
        case .exponential:
            // Exponential curve: creates sharp attack characteristics
            let expCurve = curve * 4.0 + 0.1
            let expPhase = (pow(normalizedPhase, expCurve) - normalizedPhase) * amount + normalizedPhase
            baseDistortion = expPhase
            
        case .logarithmic:
            // Logarithmic curve: opposite of exponential
            let logCurve = curve * 0.9 + 0.1
            let logPhase = normalizedPhase + amount * (log(normalizedPhase * logCurve + (1.0 - logCurve)) / log(logCurve + (1.0 - logCurve)) - normalizedPhase)
            baseDistortion = logPhase
            
        case .polynomial:
            // Polynomial distortion with adjustable order
            let order = curve * 6.0 + 1.0
            let polyPhase = pow(normalizedPhase, order)
            baseDistortion = normalizedPhase + amount * (polyPhase - normalizedPhase)
            
        case .window:
            // Window function distortion (Hamming-like)
            let windowPhase = 0.54 - 0.46 * cos(2.0 * Float.pi * normalizedPhase)
            baseDistortion = normalizedPhase + amount * curve * (windowPhase - normalizedPhase)
            
        case .fold:
            // Phase folding: reflects phase back when it exceeds threshold
            let threshold = curve
            if normalizedPhase > threshold {
                let foldedPhase = threshold - (normalizedPhase - threshold)
                baseDistortion = normalizedPhase + amount * (foldedPhase - normalizedPhase)
            } else {
                baseDistortion = normalizedPhase
            }
            
        case .wrap:
            // Phase wrapping: wraps phase around multiple times
            let wrapFactor = curve * 4.0 + 1.0
            let wrappedPhase = fmod(normalizedPhase * wrapFactor, 1.0)
            baseDistortion = normalizedPhase + amount * (wrappedPhase - normalizedPhase)
            
        case .compress:
            // Phase compression/expansion
            let center = 0.5
            let compression = curve * 2.0
            let distance = normalizedPhase - center
            let compressedDistance = distance * compression
            let compressedPhase = center + compressedDistance
            baseDistortion = normalizedPhase + amount * (compressedPhase - normalizedPhase)
        }
        
        return max(0.0, min(1.0, baseDistortion))
    }
}

// MARK: - Phase Distortion Processor

/// High-level processor that combines phase distortion with wavetable synthesis
public class PhaseDistortionProcessor {
    
    // MARK: - Properties
    
    public let engine: PhaseDistortionEngine
    
    /// Primary distortion type
    public var primaryType: PhaseDistortionType = .sine {
        didSet { engine.distortionType = primaryType }
    }
    
    /// Distortion parameters
    public var parameters: PhaseDistortionParameters {
        get { engine.parameters }
        set { engine.parameters = newValue }
    }
    
    // MARK: - Initialization
    
    public init(sampleRate: Float = 44100.0) {
        self.engine = PhaseDistortionEngine(sampleRate: sampleRate)
    }
    
    // MARK: - Convenience Methods
    
    /// Set basic distortion parameters
    /// - Parameters:
    ///   - amount: Distortion intensity (0.0 to 1.0)
    ///   - curve: Curve shaping (0.0 to 1.0)
    ///   - asymmetry: Asymmetry (-1.0 to 1.0)
    public func setDistortion(amount: Float, curve: Float = 0.5, asymmetry: Float = 0.0) {
        var params = parameters
        params.amount = max(0.0, min(1.0, amount))
        params.curve = max(0.0, min(1.0, curve))
        params.asymmetry = max(-1.0, min(1.0, asymmetry))
        parameters = params
    }
    
    /// Apply phase distortion for wavetable synthesis
    /// - Parameters:
    ///   - wavetable: Source wavetable data
    ///   - phase: Current oscillator phase (0.0 to 1.0)
    ///   - frequency: Fundamental frequency
    /// - Returns: Synthesized sample
    public func synthesize(wavetable: WavetableData, phase: Float, frequency: Float) -> Float {
        let distortedPhase = engine.distortPhase(phase, frequency: frequency)
        return wavetable.interpolateSample(at: distortedPhase, frame: 0)
    }
    
    /// Batch synthesis for multiple samples
    /// - Parameters:
    ///   - wavetable: Source wavetable data
    ///   - phases: Array of phase values
    ///   - frequency: Fundamental frequency
    ///   - output: Output sample array
    public func synthesizeBatch(wavetable: WavetableData, phases: [Float], frequency: Float, output: inout [Float]) {
        precondition(phases.count == output.count, "Phase and output arrays must be same size")
        
        var distortedPhases = Array<Float>(repeating: 0.0, count: phases.count)
        engine.distortPhases(phases, frequency: frequency, output: &distortedPhases)
        
        for i in 0..<phases.count {
            output[i] = wavetable.interpolateSample(at: distortedPhases[i], frame: 0)
        }
    }
}

// MARK: - WavetableData Extensions for Phase Distortion

extension WavetableData {
    
    /// Apply phase distortion during wavetable synthesis
    /// - Parameters:
    ///   - phase: Input phase (0.0 to 1.0)
    ///   - frame: Wavetable frame index
    ///   - distortion: Phase distortion engine
    ///   - frequency: Fundamental frequency
    /// - Returns: Synthesized sample with phase distortion
    public func synthesizeWithPhaseDistortion(phase: Float, frame: Int, distortion: PhaseDistortionEngine, frequency: Float) -> Float {
        let distortedPhase = distortion.distortPhase(phase, frequency: frequency)
        return interpolateSample(at: distortedPhase, frame: frame)
    }
    
    /// Batch synthesis with phase distortion
    /// - Parameters:
    ///   - phases: Input phase array
    ///   - frame: Wavetable frame index
    ///   - distortion: Phase distortion engine
    ///   - frequency: Fundamental frequency
    ///   - output: Output sample array
    public func synthesizeBatchWithPhaseDistortion(phases: [Float], frame: Int, distortion: PhaseDistortionEngine, frequency: Float, output: inout [Float]) {
        var distortedPhases = Array<Float>(repeating: 0.0, count: phases.count)
        distortion.distortPhases(phases, frequency: frequency, output: &distortedPhases)
        
        for i in 0..<phases.count {
            output[i] = interpolateSample(at: distortedPhases[i], frame: frame)
        }
    }
} 