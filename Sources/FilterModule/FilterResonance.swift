import Foundation
import Accelerate
import simd

// MARK: - Helper Functions

private func mix(_ a: Float, _ b: Float, t: Float) -> Float {
    return a * (1.0 - t) + b * t
}

// MARK: - Resonance Configuration

/// Configuration for filter resonance behavior
public struct FilterResonanceConfig {
    public var resonance: Float = 0.7          // 0.0 to 1.0 (sometimes >1.0 for self-osc)
    public var selfOscillationThreshold: Float = 0.99   // Threshold for self-oscillation
    public var saturationAmount: Float = 0.1    // Soft saturation amount
    public var stabilityControl: Bool = true    // Enable automatic stability control
    public var feedbackGain: Float = 1.0       // Additional feedback gain
    public var dampingFactor: Float = 0.98     // Damping to prevent runaway oscillation
    
    public init() {}
}

/// Parameters for resonance modulation and control
public struct ResonanceParameters {
    public var amount: Float = 0.7             // Base resonance amount
    public var modulation: Float = 0.0         // Modulation input (-1.0 to 1.0)
    public var keyTracking: Float = 0.0        // Keyboard tracking amount
    public var velocity: Float = 1.0           // Velocity scaling
    public var frequencyCompensation: Float = 0.0  // Frequency-dependent resonance
    
    public init() {}
}

// MARK: - Self-Oscillation Engine

/// Advanced self-oscillation engine for filter resonance
public class FilterResonanceEngine {
    
    // MARK: - Properties
    
    public var config = FilterResonanceConfig()
    public var parameters = ResonanceParameters()
    
    // Internal state for feedback processing
    private var feedbackBuffer: [Float] = Array(repeating: 0.0, count: 4)
    private var oscillationState: Float = 0.0
    private var lastOutput: Float = 0.0
    private var stabilityCounter: Int = 0
    
    // Saturation and limiting
    private var saturationCurve: SaturationCurve = .tanh
    private var limiterThreshold: Float = 0.95
    
    // Self-oscillation detection and control
    private var oscillationDetected: Bool = false
    private var oscillationFrequency: Float = 440.0
    private var oscillationAmplitude: Float = 0.0
    
    // MARK: - Initialization
    
    public init() {
        resetState()
    }
    
    // MARK: - Public Interface
    
    /// Process a single sample through the resonance system
    public func processSample(
        input: Float,
        cutoffFrequency: Float,
        sampleRate: Float = 44100.0
    ) -> Float {
        
        // Calculate effective resonance with modulation
        let effectiveResonance = calculateEffectiveResonance(
            baseResonance: parameters.amount,
            modulation: parameters.modulation,
            frequency: cutoffFrequency,
            velocity: parameters.velocity
        )
        
        // Check for self-oscillation threshold
        let isInSelfOscillation = effectiveResonance >= config.selfOscillationThreshold
        
        var output: Float
        
        if isInSelfOscillation {
            // Self-oscillation mode
            output = processSelfOscillation(
                input: input,
                frequency: cutoffFrequency,
                resonance: effectiveResonance,
                sampleRate: sampleRate
            )
        } else {
            // Normal resonance mode
            output = processNormalResonance(
                input: input,
                resonance: effectiveResonance
            )
        }
        
        // Apply saturation and limiting
        output = applySaturation(output)
        output = applyLimiting(output)
        
        // Update state
        updateState(output: output)
        
        return output
    }
    
    /// Process a buffer of samples
    public func processBuffer(
        input: [Float],
        cutoffFrequency: Float,
        sampleRate: Float = 44100.0
    ) -> [Float] {
        
        return input.map { sample in
            processSample(
                input: sample,
                cutoffFrequency: cutoffFrequency,
                sampleRate: sampleRate
            )
        }
    }
    
    /// Reset internal state
    public func resetState() {
        feedbackBuffer = Array(repeating: 0.0, count: 4)
        oscillationState = 0.0
        lastOutput = 0.0
        stabilityCounter = 0
        oscillationDetected = false
        oscillationAmplitude = 0.0
    }
    
    // MARK: - Resonance Calculation
    
    private func calculateEffectiveResonance(
        baseResonance: Float,
        modulation: Float,
        frequency: Float,
        velocity: Float
    ) -> Float {
        
        // Start with base resonance
        var resonance = baseResonance
        
        // Apply modulation
        resonance += modulation * 0.5  // Scale modulation influence
        
        // Apply velocity scaling
        resonance *= velocity
        
        // Apply frequency compensation
        if parameters.frequencyCompensation != 0.0 {
            let freqFactor = log2(frequency / 440.0) // Relative to A4
            resonance += freqFactor * parameters.frequencyCompensation * 0.1
        }
        
        // Clamp to valid range (allow slight overshoot for self-oscillation)
        return max(0.0, min(1.2, resonance))
    }
    
    // MARK: - Normal Resonance Processing
    
    private func processNormalResonance(
        input: Float,
        resonance: Float
    ) -> Float {
        
        // Calculate feedback amount
        let feedbackAmount = resonance * config.feedbackGain
        
        // Calculate feedback signal
        let feedback = calculateFeedback()
        
        // Mix input with feedback
        let mixedSignal = input + feedback * feedbackAmount
        
        // Update feedback buffer
        updateFeedbackBuffer(mixedSignal)
        
        return mixedSignal
    }
    
    // MARK: - Self-Oscillation Processing
    
    private func processSelfOscillation(
        input: Float,
        frequency: Float,
        resonance: Float,
        sampleRate: Float
    ) -> Float {
        
        oscillationDetected = true
        oscillationFrequency = frequency
        
        // Calculate oscillation phase increment
        let phaseIncrement = 2.0 * Float.pi * frequency / sampleRate
        
        // Update oscillation state
        oscillationState += phaseIncrement
        if oscillationState > 2.0 * Float.pi {
            oscillationState -= 2.0 * Float.pi
        }
        
        // Generate self-oscillation signal
        let oscillationAmplitude = (resonance - config.selfOscillationThreshold) * 2.0
        let oscillationSignal = sin(oscillationState) * oscillationAmplitude
        
        // Mix with input (reduced influence in self-oscillation mode)
        let inputMix = input * (1.0 - oscillationAmplitude * 0.8)
        
        // Apply damping to prevent runaway oscillation
        let dampedSignal = (oscillationSignal + inputMix) * config.dampingFactor
        
        // Store amplitude for analysis
        self.oscillationAmplitude = abs(dampedSignal)
        
        return dampedSignal
    }
    
    // MARK: - Feedback Processing
    
    private func calculateFeedback() -> Float {
        // Multi-tap feedback calculation for richer resonance
        let tap1 = feedbackBuffer[0] * 0.6
        let tap2 = feedbackBuffer[1] * 0.3
        let tap3 = feedbackBuffer[2] * 0.1
        
        return tap1 + tap2 + tap3
    }
    
    private func updateFeedbackBuffer(_ input: Float) {
        // Shift buffer and add new sample
        for i in stride(from: feedbackBuffer.count - 1, to: 0, by: -1) {
            feedbackBuffer[i] = feedbackBuffer[i - 1]
        }
        feedbackBuffer[0] = input
    }
    
    // MARK: - Saturation and Limiting
    
    private func applySaturation(_ input: Float) -> Float {
        guard config.saturationAmount > 0.0 else { return input }
        
        let amount = config.saturationAmount
        
        switch saturationCurve {
        case .tanh:
            return tanh(input * (1.0 + amount * 4.0)) / (1.0 + amount * 0.5)
        case .softClip:
            let threshold = 1.0 - amount
            if abs(input) <= threshold {
                return input
            } else {
                let excess = abs(input) - threshold
                let sign: Float = input < 0 ? -1.0 : 1.0
                return Float(sign * (threshold + excess * amount))
            }
        case .polynomial:
            let x = max(-1.0, min(1.0, input))
            return x - (amount * pow(x, 3) / 3.0)
        case .atan:
            return atan(input * (1.0 + amount * 2.0)) / (Float.pi * 0.5) * (1.0 + amount * 0.2)
        case .cubic:
            let x = max(-1.0, min(1.0, input))
            let y = x - pow(x, 3) / 3.0
            return mix(input, y, t: amount)
        case .asymmetric:
            let sign: Float = input < 0 ? -1.0 : 1.0
            let absInput = abs(input)
            let positive = tanh(absInput * (1.0 + amount * 2.0))
            let negative = atan(absInput * (1.0 + amount * 3.0)) / (Float.pi * 0.5)
            return sign * (input >= 0 ? positive : negative)
        case .tube:
            let drive = 1.0 + amount * 4.0
            let x = input * drive
            let y = tanh(x * 0.7) + atan(x * 0.3) * 0.5
            return y / drive * (1.0 + amount * 0.3)
        }
    }
    
    private func applyLimiting(_ input: Float) -> Float {
        guard abs(input) > limiterThreshold else { return input }
        
        let sign: Float = input < 0 ? -1.0 : 1.0
        let limitedMagnitude = limiterThreshold + (abs(input) - limiterThreshold) * 0.1
        
        return Float(sign * limitedMagnitude)
    }
    
    // MARK: - State Management
    
    private func updateState(output: Float) {
        lastOutput = output
        
        // Stability monitoring
        if config.stabilityControl {
            if abs(output) > 2.0 {
                stabilityCounter += 1
                if stabilityCounter > 10 {
                    // Emergency stability reset
                    resetState()
                    stabilityCounter = 0
                }
            } else {
                stabilityCounter = max(0, stabilityCounter - 1)
            }
        }
    }
    
    // MARK: - Analysis and Diagnostics
    
    /// Get current resonance analysis information
    public func getResonanceAnalysis() -> ResonanceAnalysis {
        return ResonanceAnalysis(
            isOscillating: oscillationDetected,
            oscillationFrequency: oscillationFrequency,
            oscillationAmplitude: oscillationAmplitude,
            feedbackLevel: calculateFeedback(),
            stabilityStatus: stabilityCounter == 0 ? .stable : .unstable
        )
    }
}

// MARK: - Supporting Types

// Removed duplicate SaturationCurve enum - using the one from FourPoleLadderFilter.swift

/// Resonance analysis data
public struct ResonanceAnalysis {
    public let isOscillating: Bool
    public let oscillationFrequency: Float
    public let oscillationAmplitude: Float
    public let feedbackLevel: Float
    public let stabilityStatus: StabilityStatus
}

/// Stability status enumeration
public enum StabilityStatus {
    case stable, unstable, critical
}

// MARK: - Utility Extensions

extension FilterResonanceEngine {
    
    /// Configure for specific musical styles
    public func configureForStyle(_ style: ResonanceStyle) {
        switch style {
        case .classic:
            config.selfOscillationThreshold = 0.95
            config.saturationAmount = 0.15
            config.dampingFactor = 0.98
            saturationCurve = .tanh
            
        case .aggressive:
            config.selfOscillationThreshold = 0.85
            config.saturationAmount = 0.3
            config.dampingFactor = 0.95
            saturationCurve = .softClip
            
        case .clean:
            config.selfOscillationThreshold = 0.99
            config.saturationAmount = 0.05
            config.dampingFactor = 0.99
            saturationCurve = .polynomial
            
        case .experimental:
            config.selfOscillationThreshold = 0.75
            config.saturationAmount = 0.4
            config.dampingFactor = 0.92
            saturationCurve = .tanh
        }
    }
    
    /// Set resonance with musical scaling
    public func setMusicalResonance(_ value: Float) {
        // Convert linear 0-1 to musical exponential curve
        let exponential = pow(value, 0.3)  // Gentler curve at low values
        parameters.amount = exponential
    }
}

/// Musical resonance styles
public enum ResonanceStyle: CaseIterable {
    case classic, aggressive, clean, experimental
} 