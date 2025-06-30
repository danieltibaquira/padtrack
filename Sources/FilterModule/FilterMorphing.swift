import Foundation
import Accelerate
import simd

// MARK: - Filter Morphing Types

/// Morphing modes for different filter combinations
public enum FilterMorphMode: CaseIterable, Codable {
    case lpBpHp        // Lowpass → Bandpass → Highpass
    case lpHp          // Lowpass → Highpass (direct)
    case bpNotch       // Bandpass → Notch
    case shelfPeak     // Low Shelf → Peak → High Shelf
    case allpassBypass // Allpass → Bypass
}

/// Configuration for filter morphing behavior
public struct FilterMorphConfig {
    public var mode: FilterMorphMode = .lpBpHp
    public var morphParameter: Float = 0.0    // 0.0 to 1.0
    public var stabilityChecking: Bool = true
    public var smoothingTime: Float = 0.001   // Seconds
    public var crossfadeSlope: Float = 0.5    // 0.0 = linear, 1.0 = exponential
    
    public init() {}
}

/// Advanced morphing parameters for fine control
public struct FilterMorphParameters {
    public var primaryMorph: Float = 0.0      // Main morphing parameter (0-1)
    public var secondaryMorph: Float = 0.0    // Secondary morphing for 3+ filter types
    public var morphShape: Float = 0.5        // Controls interpolation curve shape
    public var stabilityFactor: Float = 1.0   // Stability preservation strength
    public var bypassAmount: Float = 0.0      // Direct bypass mixing (0-1)
    
    public init() {}
}

// MARK: - Filter Morphing Engine

/// Advanced filter morphing processor with smooth transitions and stability preservation
public class FilterMorphingEngine {
    
    // MARK: - Properties
    
    public var config = FilterMorphConfig()
    public var parameters = FilterMorphParameters()
    
    private var currentCoefficients = BiquadCoefficients()
    private var targetCoefficients = BiquadCoefficients()
    private var smoothingBuffers = Array(repeating: Float(0), count: 6) // For coefficient smoothing
    
    private let sampleRate: Float
    private var smoothingFactors = Array(repeating: Float(0), count: 6)
    
    // MARK: - Initialization
    
    public init(sampleRate: Float = 44100.0) {
        self.sampleRate = sampleRate
        updateSmoothingFactors()
    }
    
    // MARK: - Public Interface
    
    /// Calculate morphed filter coefficients based on current parameters
    public func calculateMorphedCoefficients(
        baseConfig: FilterCoefficientConfig
    ) -> BiquadCoefficients {
        
        let morphedCoeffs = generateMorphedCoefficients(baseConfig: baseConfig)
        
        // Apply smoothing if enabled
        if config.smoothingTime > 0 {
            return applyCoefficientSmoothing(target: morphedCoeffs)
        } else {
            currentCoefficients = morphedCoeffs
            return morphedCoeffs
        }
    }
    
    /// Update morphing parameters with validation
    public func updateMorphParameters(_ newParams: FilterMorphParameters) {
        // Validate and clamp parameters
        parameters.primaryMorph = max(0.0, min(1.0, newParams.primaryMorph))
        parameters.secondaryMorph = max(0.0, min(1.0, newParams.secondaryMorph))
        parameters.morphShape = max(0.0, min(1.0, newParams.morphShape))
        parameters.stabilityFactor = max(0.0, min(2.0, newParams.stabilityFactor))
        parameters.bypassAmount = max(0.0, min(1.0, newParams.bypassAmount))
    }
    
    /// Set morphing mode and update configuration
    public func setMorphMode(_ mode: FilterMorphMode) {
        config.mode = mode
        // Reset smoothing buffers when changing mode
        smoothingBuffers = Array(repeating: Float(0), count: 6)
    }
    
    /// Update smoothing time and recalculate smoothing factors
    public func setSmoothingTime(_ time: Float) {
        config.smoothingTime = max(0.0, min(1.0, time))
        updateSmoothingFactors()
    }
    
    // MARK: - Morphing Algorithm Implementation
    
    private func generateMorphedCoefficients(baseConfig: FilterCoefficientConfig) -> BiquadCoefficients {
        
        switch config.mode {
        case .lpBpHp:
            return morphLowpassBandpassHighpass(baseConfig: baseConfig)
        case .lpHp:
            return morphLowpassHighpass(baseConfig: baseConfig)
        case .bpNotch:
            return morphBandpassNotch(baseConfig: baseConfig)
        case .shelfPeak:
            return morphShelfPeak(baseConfig: baseConfig)
        case .allpassBypass:
            return morphAllpassBypass(baseConfig: baseConfig)
        }
    }
    
    /// Primary morphing: Lowpass → Bandpass → Highpass
    private func morphLowpassBandpassHighpass(baseConfig: FilterCoefficientConfig) -> BiquadCoefficients {
        let morph = parameters.primaryMorph
        let shape = parameters.morphShape
        
        // Apply morphing curve shape
        let shapedMorph = applyMorphingCurve(morph, shape: shape)
        
        if shapedMorph <= 0.5 {
            // First half: Lowpass → Bandpass
            let localMorph = shapedMorph * 2.0
            let lpCoeffs = FilterCoefficientCalculator.calculateBiquadCoefficients(
                type: .lowpass, config: baseConfig
            )
            let bpCoeffs = FilterCoefficientCalculator.calculateBiquadCoefficients(
                type: .bandpass, config: baseConfig
            )
            
            return interpolateCoefficientsWithStability(
                from: lpCoeffs, to: bpCoeffs, amount: localMorph
            )
        } else {
            // Second half: Bandpass → Highpass
            let localMorph = (shapedMorph - 0.5) * 2.0
            let bpCoeffs = FilterCoefficientCalculator.calculateBiquadCoefficients(
                type: .bandpass, config: baseConfig
            )
            let hpCoeffs = FilterCoefficientCalculator.calculateBiquadCoefficients(
                type: .highpass, config: baseConfig
            )
            
            return interpolateCoefficientsWithStability(
                from: bpCoeffs, to: hpCoeffs, amount: localMorph
            )
        }
    }
    
    /// Direct morphing: Lowpass → Highpass
    private func morphLowpassHighpass(baseConfig: FilterCoefficientConfig) -> BiquadCoefficients {
        let morph = applyMorphingCurve(parameters.primaryMorph, shape: parameters.morphShape)
        
        let lpCoeffs = FilterCoefficientCalculator.calculateBiquadCoefficients(
            type: .lowpass, config: baseConfig
        )
        let hpCoeffs = FilterCoefficientCalculator.calculateBiquadCoefficients(
            type: .highpass, config: baseConfig
        )
        
        return interpolateCoefficientsWithStability(
            from: lpCoeffs, to: hpCoeffs, amount: morph
        )
    }
    
    /// Bandpass ↔ Notch morphing
    private func morphBandpassNotch(baseConfig: FilterCoefficientConfig) -> BiquadCoefficients {
        let morph = applyMorphingCurve(parameters.primaryMorph, shape: parameters.morphShape)
        
        let bpCoeffs = FilterCoefficientCalculator.calculateBiquadCoefficients(
            type: .bandpass, config: baseConfig
        )
        let notchCoeffs = FilterCoefficientCalculator.calculateBiquadCoefficients(
            type: .bandstop, config: baseConfig
        )
        
        return interpolateCoefficientsWithStability(
            from: bpCoeffs, to: notchCoeffs, amount: morph
        )
    }
    
    /// EQ-style morphing: Low Shelf → Peak → High Shelf
    private func morphShelfPeak(baseConfig: FilterCoefficientConfig) -> BiquadCoefficients {
        let morph = parameters.primaryMorph
        let shape = parameters.morphShape
        let shapedMorph = applyMorphingCurve(morph, shape: shape)
        
        if shapedMorph <= 0.5 {
            // Low Shelf → Peak
            let localMorph = shapedMorph * 2.0
            let lsCoeffs = FilterCoefficientCalculator.calculateBiquadCoefficients(
                type: .lowshelf, config: baseConfig
            )
            let pkCoeffs = FilterCoefficientCalculator.calculateBiquadCoefficients(
                type: .peak, config: baseConfig
            )
            
            return interpolateCoefficientsWithStability(
                from: lsCoeffs, to: pkCoeffs, amount: localMorph
            )
        } else {
            // Peak → High Shelf
            let localMorph = (shapedMorph - 0.5) * 2.0
            let pkCoeffs = FilterCoefficientCalculator.calculateBiquadCoefficients(
                type: .peak, config: baseConfig
            )
            let hsCoeffs = FilterCoefficientCalculator.calculateBiquadCoefficients(
                type: .highshelf, config: baseConfig
            )
            
            return interpolateCoefficientsWithStability(
                from: pkCoeffs, to: hsCoeffs, amount: localMorph
            )
        }
    }
    
    /// Allpass → Bypass morphing for special effects
    private func morphAllpassBypass(baseConfig: FilterCoefficientConfig) -> BiquadCoefficients {
        let morph = applyMorphingCurve(parameters.primaryMorph, shape: parameters.morphShape)
        
        let apCoeffs = FilterCoefficientCalculator.calculateBiquadCoefficients(
            type: .allpass, config: baseConfig
        )
        
        // Bypass coefficients (pass-through)
        let bypassCoeffs = BiquadCoefficients(
            a0: 1.0, a1: 0.0, a2: 0.0,
            b0: 1.0, b1: 0.0, b2: 0.0
        )
        
        return interpolateCoefficientsWithStability(
            from: apCoeffs, to: bypassCoeffs, amount: morph
        )
    }
    
    // MARK: - Advanced Interpolation
    
    /// Interpolate coefficients with stability preservation
    private func interpolateCoefficientsWithStability(
        from: BiquadCoefficients,
        to: BiquadCoefficients,
        amount: Float
    ) -> BiquadCoefficients {
        
        let t = max(0.0, min(1.0, amount))
        let invT = 1.0 - t
        
        // Standard linear interpolation
        var result = BiquadCoefficients(
            a0: from.a0 * invT + to.a0 * t,
            a1: from.a1 * invT + to.a1 * t,
            a2: from.a2 * invT + to.a2 * t,
            b0: from.b0 * invT + to.b0 * t,
            b1: from.b1 * invT + to.b1 * t,
            b2: from.b2 * invT + to.b2 * t
        )
        
        // Apply stability checking if enabled
        if config.stabilityChecking {
            result = ensureStability(result, stabilityFactor: parameters.stabilityFactor)
        }
        
        // Apply bypass mixing if configured
        if parameters.bypassAmount > 0.0 {
            result = mixWithBypass(result, bypassAmount: parameters.bypassAmount)
        }
        
        return result
    }
    
    /// Apply morphing curve shaping for non-linear transitions
    private func applyMorphingCurve(_ input: Float, shape: Float) -> Float {
        let x = max(0.0, min(1.0, input))
        let s = max(0.0, min(1.0, shape))
        
        if s < 0.5 {
            // More linear (s=0) to exponential (s=0.5)
            let factor = s * 2.0
            return x * (1.0 - factor) + pow(x, 0.5 + factor) * factor
        } else {
            // Exponential (s=0.5) to S-curve (s=1.0)
            let factor = (s - 0.5) * 2.0
            let exponential = pow(x, 2.0)
            let sCurve = 3.0 * x * x - 2.0 * x * x * x
            return exponential * (1.0 - factor) + sCurve * factor
        }
    }
    
    /// Ensure filter stability through pole adjustment
    private func ensureStability(_ coeffs: BiquadCoefficients, stabilityFactor: Float) -> BiquadCoefficients {
        var result = coeffs
        
        if !result.isStable {
            // Adjust coefficients to ensure stability
            let maxPoleRadius = 0.98 * stabilityFactor
            
            // Calculate current pole radius
            let discriminant = result.b1 * result.b1 - 4.0 * result.b2
            if discriminant >= 0 {
                let root1 = (-result.b1 + sqrt(discriminant)) / (2.0 * result.b2)
                let root2 = (-result.b1 - sqrt(discriminant)) / (2.0 * result.b2)
                let maxRadius = max(abs(root1), abs(root2))
                
                if maxRadius > maxPoleRadius {
                    let scaleFactor = maxPoleRadius / maxRadius
                    result.b2 *= scaleFactor * scaleFactor
                }
            } else {
                let magnitude = sqrt(abs(result.b2))
                if magnitude > maxPoleRadius {
                    let scaleFactor = maxPoleRadius / magnitude
                    result.b2 *= scaleFactor * scaleFactor
                }
            }
        }
        
        return result
    }
    
    /// Mix filtered signal with bypass for smooth transitions
    private func mixWithBypass(_ coeffs: BiquadCoefficients, bypassAmount: Float) -> BiquadCoefficients {
        let mix = max(0.0, min(1.0, bypassAmount))
        let filterMix = 1.0 - mix
        
        let bypassCoeffs = BiquadCoefficients(
            a0: 1.0, a1: 0.0, a2: 0.0,
            b0: 1.0, b1: 0.0, b2: 0.0
        )
        
        return BiquadCoefficients(
            a0: coeffs.a0 * filterMix + bypassCoeffs.a0 * mix,
            a1: coeffs.a1 * filterMix + bypassCoeffs.a1 * mix,
            a2: coeffs.a2 * filterMix + bypassCoeffs.a2 * mix,
            b0: coeffs.b0 * filterMix + bypassCoeffs.b0 * mix,
            b1: coeffs.b1 * filterMix + bypassCoeffs.b1 * mix,
            b2: coeffs.b2 * filterMix + bypassCoeffs.b2 * mix
        )
    }
    
    // MARK: - Parameter Smoothing
    
    /// Apply real-time coefficient smoothing
    private func applyCoefficientSmoothing(target: BiquadCoefficients) -> BiquadCoefficients {
        let targetArray = [target.a0, target.a1, target.a2, target.b0, target.b1, target.b2]
        
        for i in 0..<6 {
            smoothingBuffers[i] += (targetArray[i] - smoothingBuffers[i]) * smoothingFactors[i]
        }
        
        let result = BiquadCoefficients(
            a0: smoothingBuffers[0], a1: smoothingBuffers[1], a2: smoothingBuffers[2],
            b0: smoothingBuffers[3], b1: smoothingBuffers[4], b2: smoothingBuffers[5]
        )
        
        currentCoefficients = result
        return result
    }
    
    /// Calculate smoothing factors based on time constant
    private func updateSmoothingFactors() {
        let timeConstant = config.smoothingTime
        let samplesPerUpdate = sampleRate / 1000.0 // Assuming 1kHz update rate
        let smoothing = 1.0 - exp(-1.0 / (timeConstant * samplesPerUpdate))
        
        smoothingFactors = Array(repeating: smoothing, count: 6)
    }
} 