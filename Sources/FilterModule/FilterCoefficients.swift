import Foundation
import Accelerate
import simd

// MARK: - Filter Types and Configuration

/// Supported filter types for coefficient calculation
public enum FilterCoefficientType: CaseIterable, Codable {
    case lowpass, highpass, bandpass, bandstop
    case lowshelf, highshelf, peak, allpass
}

/// Filter topology types
public enum FilterTopology: CaseIterable, Codable {
    case biquad          // Standard biquad implementation
    case stateVariable   // State-variable filter
    case ladder          // Moog-style ladder filter
    case chamberlin      // Chamberlin state-variable
}

/// Configuration for filter coefficient calculation
public struct FilterCoefficientConfig {
    public var sampleRate: Float = 44100.0
    public var cutoffFrequency: Float = 1000.0
    public var resonance: Float = 0.7        // 0.0 to 1.0
    public var gain: Float = 0.0             // dB, for shelf/peak filters
    public var bandwidth: Float = 1.0        // Octaves, for bandpass/peak
    public var keyTracking: Float = 0.0      // 0.0 to 1.0
    public var morphAmount: Float = 0.0      // 0.0 to 1.0 for morphing
    
    public init() {}
}

// MARK: - Filter Coefficients

/// Biquad filter coefficients (Direct Form I)
public struct BiquadCoefficients {
    public var a0: Float = 1.0  // Input coefficients
    public var a1: Float = 0.0
    public var a2: Float = 0.0
    public var b0: Float = 1.0  // Output coefficients
    public var b1: Float = 0.0
    public var b2: Float = 0.0
    
    public init() {}
    
    public init(a0: Float, a1: Float, a2: Float, b0: Float, b1: Float, b2: Float) {
        self.a0 = a0; self.a1 = a1; self.a2 = a2
        self.b0 = b0; self.b1 = b1; self.b2 = b2
    }
    
    /// Normalize coefficients by a0
    public mutating func normalize() {
        guard a0 != 0.0 else { return }
        let norm = 1.0 / a0
        a1 *= norm; a2 *= norm
        b0 *= norm; b1 *= norm; b2 *= norm
        a0 = 1.0
    }
    
    /// Check if coefficients are stable (poles inside unit circle)
    public var isStable: Bool {
        let discriminant = b1 * b1 - 4.0 * b2
        if discriminant >= 0 {
            let root1 = (-b1 + sqrt(discriminant)) / (2.0 * b2)
            let root2 = (-b1 - sqrt(discriminant)) / (2.0 * b2)
            return abs(root1) < 1.0 && abs(root2) < 1.0
        } else {
            let magnitude = sqrt(b2)
            return magnitude < 1.0
        }
    }
}

/// State-variable filter coefficients
public struct StateVariableCoefficients {
    public var frequency: Float = 0.0    // Frequency coefficient
    public var damping: Float = 0.0      // Damping coefficient
    public var gain: Float = 1.0         // Overall gain
    
    public init() {}
    
    public init(frequency: Float, damping: Float, gain: Float = 1.0) {
        self.frequency = frequency
        self.damping = damping
        self.gain = gain
    }
}

// MARK: - Filter Coefficient Calculator

/// Comprehensive filter coefficient calculation engine
public class FilterCoefficientCalculator {
    
    // MARK: - Public Interface
    
    /// Calculate biquad coefficients for specified filter type and parameters
    public static func calculateBiquadCoefficients(
        type: FilterCoefficientType,
        config: FilterCoefficientConfig
    ) -> BiquadCoefficients {
        
        // Apply frequency warping for digital implementation
        let omega = calculateDigitalFrequency(
            frequency: config.cutoffFrequency,
            sampleRate: config.sampleRate
        )
        
        switch type {
        case .lowpass:
            return calculateLowpassBiquad(omega: omega, q: resonanceToQ(config.resonance))
        case .highpass:
            return calculateHighpassBiquad(omega: omega, q: resonanceToQ(config.resonance))
        case .bandpass:
            return calculateBandpassBiquad(omega: omega, q: resonanceToQ(config.resonance))
        case .bandstop:
            return calculateBandstopBiquad(omega: omega, q: resonanceToQ(config.resonance))
        case .lowshelf:
            return calculateLowshelfBiquad(omega: omega, gain: config.gain, q: resonanceToQ(config.resonance))
        case .highshelf:
            return calculateHighshelfBiquad(omega: omega, gain: config.gain, q: resonanceToQ(config.resonance))
        case .peak:
            return calculatePeakBiquad(omega: omega, gain: config.gain, q: resonanceToQ(config.resonance))
        case .allpass:
            return calculateAllpassBiquad(omega: omega, q: resonanceToQ(config.resonance))
        }
    }
    
    /// Calculate state-variable coefficients
    public static func calculateStateVariableCoefficients(
        config: FilterCoefficientConfig
    ) -> StateVariableCoefficients {
        
        let sampleRate = config.sampleRate
        let frequency = config.cutoffFrequency
        
        // Clamp frequency to valid range
        let clampedFreq = max(1.0, min(frequency, sampleRate * 0.49))
        
        // Calculate frequency coefficient using bilinear transform
        let omega = 2.0 * Float.pi * clampedFreq / sampleRate
        let freqCoeff = 2.0 * sin(omega * 0.5)
        
        // Calculate damping coefficient from resonance
        let q = resonanceToQ(config.resonance)
        let dampingCoeff = 1.0 / q
        
        return StateVariableCoefficients(
            frequency: freqCoeff,
            damping: dampingCoeff,
            gain: 1.0
        )
    }
    
    /// Calculate morphed coefficients between two filter types
    public static func calculateMorphedCoefficients(
        typeA: FilterCoefficientType,
        typeB: FilterCoefficientType,
        morphAmount: Float,
        config: FilterCoefficientConfig
    ) -> BiquadCoefficients {
        
        let coeffsA = calculateBiquadCoefficients(type: typeA, config: config)
        let coeffsB = calculateBiquadCoefficients(type: typeB, config: config)
        
        return interpolateBiquadCoefficients(
            from: coeffsA,
            to: coeffsB,
            amount: morphAmount
        )
    }
    
    // MARK: - Frequency Warping
    
    /// Apply bilinear transform frequency warping for digital implementation
    private static func calculateDigitalFrequency(frequency: Float, sampleRate: Float) -> Float {
        let nyquist = sampleRate * 0.5
        let clampedFreq = max(1.0, min(frequency, nyquist * 0.99))
        
        // Bilinear transform: ω = 2 * tan(π * f / fs)
        return 2.0 * tan(Float.pi * clampedFreq / sampleRate)
    }
    
    /// Convert resonance (0-1) to Q factor with musical scaling
    private static func resonanceToQ(_ resonance: Float) -> Float {
        let clampedRes = max(0.0, min(1.0, resonance))
        
        // Musical scaling: 0.5 to 40 with exponential curve
        let minQ: Float = 0.5
        let maxQ: Float = 40.0
        
        return minQ * pow(maxQ / minQ, clampedRes * clampedRes)
    }
    
    // MARK: - Biquad Coefficient Calculations
    
    private static func calculateLowpassBiquad(omega: Float, q: Float) -> BiquadCoefficients {
        let cosOmega = cos(omega)
        let sinOmega = sin(omega)
        let alpha = sinOmega / (2.0 * q)
        
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cosOmega
        let a2 = 1.0 - alpha
        let b0 = (1.0 - cosOmega) / 2.0
        let b1 = 1.0 - cosOmega
        let b2 = (1.0 - cosOmega) / 2.0
        
        var coeffs = BiquadCoefficients(a0: a0, a1: a1, a2: a2, b0: b0, b1: b1, b2: b2)
        coeffs.normalize()
        return coeffs
    }
    
    private static func calculateHighpassBiquad(omega: Float, q: Float) -> BiquadCoefficients {
        let cosOmega = cos(omega)
        let sinOmega = sin(omega)
        let alpha = sinOmega / (2.0 * q)
        
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cosOmega
        let a2 = 1.0 - alpha
        let b0 = (1.0 + cosOmega) / 2.0
        let b1 = -(1.0 + cosOmega)
        let b2 = (1.0 + cosOmega) / 2.0
        
        var coeffs = BiquadCoefficients(a0: a0, a1: a1, a2: a2, b0: b0, b1: b1, b2: b2)
        coeffs.normalize()
        return coeffs
    }
    
    private static func calculateBandpassBiquad(omega: Float, q: Float) -> BiquadCoefficients {
        let cosOmega = cos(omega)
        let sinOmega = sin(omega)
        let alpha = sinOmega / (2.0 * q)
        
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cosOmega
        let a2 = 1.0 - alpha
        let b0 = alpha
        let b1: Float = 0.0
        let b2 = -alpha
        
        var coeffs = BiquadCoefficients(a0: a0, a1: a1, a2: a2, b0: b0, b1: b1, b2: b2)
        coeffs.normalize()
        return coeffs
    }
    
    private static func calculateBandstopBiquad(omega: Float, q: Float) -> BiquadCoefficients {
        let cosOmega = cos(omega)
        let sinOmega = sin(omega)
        let alpha = sinOmega / (2.0 * q)
        
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cosOmega
        let a2 = 1.0 - alpha
        let b0: Float = 1.0
        let b1 = -2.0 * cosOmega
        let b2: Float = 1.0
        
        var coeffs = BiquadCoefficients(a0: a0, a1: a1, a2: a2, b0: b0, b1: b1, b2: b2)
        coeffs.normalize()
        return coeffs
    }
    
    private static func calculateLowshelfBiquad(omega: Float, gain: Float, q: Float) -> BiquadCoefficients {
        let A = pow(10.0, gain / 40.0)  // Convert dB to linear
        let cosOmega = cos(omega)
        let sinOmega = sin(omega)
        let beta = sqrt(A) / q
        
        let a0 = (A + 1.0) + (A - 1.0) * cosOmega + beta * sinOmega
        let a1 = -2.0 * ((A - 1.0) + (A + 1.0) * cosOmega)
        let a2 = (A + 1.0) + (A - 1.0) * cosOmega - beta * sinOmega
        let b0 = A * ((A + 1.0) - (A - 1.0) * cosOmega + beta * sinOmega)
        let b1 = 2.0 * A * ((A - 1.0) - (A + 1.0) * cosOmega)
        let b2 = A * ((A + 1.0) - (A - 1.0) * cosOmega - beta * sinOmega)
        
        var coeffs = BiquadCoefficients(a0: a0, a1: a1, a2: a2, b0: b0, b1: b1, b2: b2)
        coeffs.normalize()
        return coeffs
    }
    
    private static func calculateHighshelfBiquad(omega: Float, gain: Float, q: Float) -> BiquadCoefficients {
        let A = pow(10.0, gain / 40.0)  // Convert dB to linear
        let cosOmega = cos(omega)
        let sinOmega = sin(omega)
        let beta = sqrt(A) / q
        
        let a0 = (A + 1.0) - (A - 1.0) * cosOmega + beta * sinOmega
        let a1 = 2.0 * ((A - 1.0) - (A + 1.0) * cosOmega)
        let a2 = (A + 1.0) - (A - 1.0) * cosOmega - beta * sinOmega
        let b0 = A * ((A + 1.0) + (A - 1.0) * cosOmega + beta * sinOmega)
        let b1 = -2.0 * A * ((A - 1.0) + (A + 1.0) * cosOmega)
        let b2 = A * ((A + 1.0) + (A - 1.0) * cosOmega - beta * sinOmega)
        
        var coeffs = BiquadCoefficients(a0: a0, a1: a1, a2: a2, b0: b0, b1: b1, b2: b2)
        coeffs.normalize()
        return coeffs
    }
    
    private static func calculatePeakBiquad(omega: Float, gain: Float, q: Float) -> BiquadCoefficients {
        let A = pow(10.0, gain / 40.0)  // Convert dB to linear
        let cosOmega = cos(omega)
        let sinOmega = sin(omega)
        let alpha = sinOmega / (2.0 * q)
        
        let a0 = 1.0 + alpha / A
        let a1 = -2.0 * cosOmega
        let a2 = 1.0 - alpha / A
        let b0 = 1.0 + alpha * A
        let b1 = -2.0 * cosOmega
        let b2 = 1.0 - alpha * A
        
        var coeffs = BiquadCoefficients(a0: a0, a1: a1, a2: a2, b0: b0, b1: b1, b2: b2)
        coeffs.normalize()
        return coeffs
    }
    
    private static func calculateAllpassBiquad(omega: Float, q: Float) -> BiquadCoefficients {
        let cosOmega = cos(omega)
        let sinOmega = sin(omega)
        let alpha = sinOmega / (2.0 * q)
        
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cosOmega
        let a2 = 1.0 - alpha
        let b0 = 1.0 - alpha
        let b1 = -2.0 * cosOmega
        let b2 = 1.0 + alpha
        
        var coeffs = BiquadCoefficients(a0: a0, a1: a1, a2: a2, b0: b0, b1: b1, b2: b2)
        coeffs.normalize()
        return coeffs
    }
    
    // MARK: - Coefficient Interpolation
    
    /// Interpolate between two sets of biquad coefficients
    private static func interpolateBiquadCoefficients(
        from: BiquadCoefficients,
        to: BiquadCoefficients,
        amount: Float
    ) -> BiquadCoefficients {
        
        let t = max(0.0, min(1.0, amount))
        let invT = 1.0 - t
        
        return BiquadCoefficients(
            a0: from.a0 * invT + to.a0 * t,
            a1: from.a1 * invT + to.a1 * t,
            a2: from.a2 * invT + to.a2 * t,
            b0: from.b0 * invT + to.b0 * t,
            b1: from.b1 * invT + to.b1 * t,
            b2: from.b2 * invT + to.b2 * t
        )
    }
}

// MARK: - Filter Response Analysis

/// Tools for analyzing filter frequency response
public struct FilterResponseAnalyzer {
    
    /// Calculate magnitude response at specific frequency
    public static func calculateMagnitudeResponse(
        coefficients: BiquadCoefficients,
        frequency: Float,
        sampleRate: Float
    ) -> Float {
        
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let cosOmega = cos(omega)
        let cos2Omega = cos(2.0 * omega)
        
        // Calculate numerator and denominator magnitudes
        let numMag = sqrt(
            coefficients.b0 * coefficients.b0 +
            coefficients.b1 * coefficients.b1 +
            coefficients.b2 * coefficients.b2 +
            2.0 * coefficients.b0 * coefficients.b1 * cosOmega +
            2.0 * coefficients.b1 * coefficients.b2 * cosOmega +
            2.0 * coefficients.b0 * coefficients.b2 * cos2Omega
        )
        
        let denMag = sqrt(
            coefficients.a0 * coefficients.a0 +
            coefficients.a1 * coefficients.a1 +
            coefficients.a2 * coefficients.a2 +
            2.0 * coefficients.a0 * coefficients.a1 * cosOmega +
            2.0 * coefficients.a1 * coefficients.a2 * cosOmega +
            2.0 * coefficients.a0 * coefficients.a2 * cos2Omega
        )
        
        return denMag > 0.0 ? numMag / denMag : 0.0
    }
    
    /// Calculate phase response at specific frequency
    public static func calculatePhaseResponse(
        coefficients: BiquadCoefficients,
        frequency: Float,
        sampleRate: Float
    ) -> Float {
        
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let sin2Omega = sin(2.0 * omega)
        let cos2Omega = cos(2.0 * omega)
        
        // Calculate numerator phase
        let numReal = coefficients.b0 + coefficients.b1 * cosOmega + coefficients.b2 * cos2Omega
        let numImag = coefficients.b1 * sinOmega + coefficients.b2 * sin2Omega
        let numPhase = atan2(numImag, numReal)
        
        // Calculate denominator phase
        let denReal = coefficients.a0 + coefficients.a1 * cosOmega + coefficients.a2 * cos2Omega
        let denImag = coefficients.a1 * sinOmega + coefficients.a2 * sin2Omega
        let denPhase = atan2(denImag, denReal)
        
        return numPhase - denPhase
    }
}

// MARK: - Coefficient Validation

/// Validation utilities for filter coefficients
public struct FilterCoefficientValidator {
    
    /// Validate that biquad coefficients produce a stable filter
    public static func validateStability(_ coefficients: BiquadCoefficients) -> Bool {
        return coefficients.isStable
    }
    
    /// Clamp coefficients to safe ranges to prevent numerical issues
    public static func clampCoefficients(_ coefficients: inout BiquadCoefficients) {
        let maxMagnitude: Float = 100.0
        
        coefficients.a0 = max(-maxMagnitude, min(maxMagnitude, coefficients.a0))
        coefficients.a1 = max(-maxMagnitude, min(maxMagnitude, coefficients.a1))
        coefficients.a2 = max(-maxMagnitude, min(maxMagnitude, coefficients.a2))
        coefficients.b0 = max(-maxMagnitude, min(maxMagnitude, coefficients.b0))
        coefficients.b1 = max(-maxMagnitude, min(maxMagnitude, coefficients.b1))
        coefficients.b2 = max(-maxMagnitude, min(maxMagnitude, coefficients.b2))
    }
    
    /// Check if coefficients represent a pass-through filter
    public static func isPassthrough(_ coefficients: BiquadCoefficients) -> Bool {
        return abs(coefficients.a0 - 1.0) < 1e-6 &&
               abs(coefficients.a1) < 1e-6 &&
               abs(coefficients.a2) < 1e-6 &&
               abs(coefficients.b0 - 1.0) < 1e-6 &&
               abs(coefficients.b1) < 1e-6 &&
               abs(coefficients.b2) < 1e-6
    }
} 