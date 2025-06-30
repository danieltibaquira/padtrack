import Foundation
import Accelerate
import simd

// MARK: - Parameter Smoothing Configuration

/// Configuration for different smoothing behaviors
public struct ParameterSmoothingConfig {
    public var sampleRate: Float = 44100.0
    public var defaultSmoothingTime: Float = 0.01        // 10ms default
    public var fastSmoothingTime: Float = 0.005         // 5ms for subtle changes
    public var slowSmoothingTime: Float = 0.05          // 50ms for dramatic changes
    public var enableAdaptiveSmoothing: Bool = true     // Adapt based on parameter change magnitude
    public var minimumChangeThreshold: Float = 0.001    // Minimum change to trigger smoothing
    
    public init() {}
}

/// Parameter smoothing quality presets
public enum SmoothingQuality: CaseIterable, Codable {
    case disabled       // No smoothing (immediate parameter changes)
    case fast          // Minimal smoothing for low-latency applications
    case balanced      // Default smoothing for most use cases
    case smooth        // Maximum smoothing for the smoothest transitions
    case adaptive      // Automatically adjusts based on parameter change rate
}

// MARK: - Parameter Smoother Class

/// High-performance exponential parameter smoother
public class ParameterSmoother {
    
    // MARK: - Properties
    
    private var currentValue: Float = 0.0
    private var targetValue: Float = 0.0
    private var smoothingCoefficient: Float = 0.0
    private var isFirstUpdate: Bool = true
    
    public var smoothingTime: Float {
        didSet {
            updateSmoothingCoefficient()
        }
    }
    
    public var sampleRate: Float {
        didSet {
            updateSmoothingCoefficient()
        }
    }
    
    // MARK: - Initialization
    
    public init(sampleRate: Float = 44100.0, smoothingTime: Float = 0.01) {
        self.sampleRate = sampleRate
        self.smoothingTime = smoothingTime
        updateSmoothingCoefficient()
    }
    
    // MARK: - Public Interface
    
    /// Set the target value for smoothing
    public func setTarget(_ newTarget: Float) {
        if isFirstUpdate {
            currentValue = newTarget
            targetValue = newTarget
            isFirstUpdate = false
        } else {
            targetValue = newTarget
        }
    }
    
    /// Get the next smoothed sample
    public func getNextValue() -> Float {
        if abs(currentValue - targetValue) < 1e-6 {
            return targetValue
        }
        
        currentValue += (targetValue - currentValue) * smoothingCoefficient
        return currentValue
    }
    
    /// Process a block of samples with the same target
    public func processBlock(output: UnsafeMutablePointer<Float>, frameCount: Int) {
        if abs(currentValue - targetValue) < 1e-6 {
            // Target reached, fill with constant value
            vDSP_vfill(&targetValue, output, 1, vDSP_Length(frameCount))
            currentValue = targetValue
            return
        }
        
        // Generate exponential smoothing curve
        for i in 0..<frameCount {
            currentValue += (targetValue - currentValue) * smoothingCoefficient
            output[i] = currentValue
        }
    }
    
    /// Jump immediately to target (no smoothing)
    public func jumpToTarget() {
        currentValue = targetValue
    }
    
    /// Get current smoothed value without advancing
    public var currentSmoothedValue: Float {
        return currentValue
    }
    
    /// Check if smoothing is complete
    public var isSmoothing: Bool {
        return abs(currentValue - targetValue) > 1e-6
    }
    
    // MARK: - Private Methods
    
    private func updateSmoothingCoefficient() {
        // Calculate exponential smoothing coefficient
        // coeff = 1 - exp(-1 / (sampleRate * smoothingTime))
        let timeConstant = sampleRate * smoothingTime
        smoothingCoefficient = 1.0 - exp(-1.0 / timeConstant)
        smoothingCoefficient = max(0.0, min(1.0, smoothingCoefficient))
    }
}

// MARK: - Multi-Parameter Smoother

/// Manager for multiple parameter smoothers with optimized processing
public class MultiParameterSmoother {
    
    // MARK: - Properties
    
    private var smoothers: [String: ParameterSmoother] = [:]
    private var config: ParameterSmoothingConfig
    private var quality: SmoothingQuality = .balanced
    
    // Parameter-specific smoothing times
    private let parameterSmoothingTimes: [String: Float] = [
        "cutoff": 0.005,        // Fast for filter cutoff
        "resonance": 0.01,      // Medium for resonance
        "morphAmount": 0.02,    // Slower for morphing
        "gain": 0.003,          // Fast for gain changes
        "bandwidth": 0.015,     // Medium for bandwidth
        "keyTracking": 0.05     // Slow for tracking amount
    ]
    
    // MARK: - Initialization
    
    public init(config: ParameterSmoothingConfig = ParameterSmoothingConfig()) {
        self.config = config
    }
    
    // MARK: - Public Interface
    
    /// Register a parameter for smoothing
    public func registerParameter(_ name: String, initialValue: Float = 0.0) {
        let smoothingTime = parameterSmoothingTimes[name] ?? config.defaultSmoothingTime
        let smoother = ParameterSmoother(sampleRate: config.sampleRate, smoothingTime: smoothingTime)
        smoother.setTarget(initialValue)
        smoother.jumpToTarget()
        smoothers[name] = smoother
    }
    
    /// Set parameter target value
    public func setParameterTarget(_ name: String, value: Float) {
        guard let smoother = smoothers[name] else {
            // Auto-register unknown parameters
            registerParameter(name, initialValue: value)
            return
        }
        
        // Adaptive smoothing based on change magnitude
        if config.enableAdaptiveSmoothing {
            let changeAmount = abs(value - smoother.currentSmoothedValue)
            if changeAmount > 0.5 {
                // Large change - use slower smoothing
                smoother.smoothingTime = config.slowSmoothingTime
            } else if changeAmount < config.minimumChangeThreshold {
                // Tiny change - use fast smoothing
                smoother.smoothingTime = config.fastSmoothingTime
            } else {
                // Normal change - use default
                let specificTime = parameterSmoothingTimes[name] ?? config.defaultSmoothingTime
                smoother.smoothingTime = specificTime
            }
        }
        
        smoother.setTarget(value)
    }
    
    /// Get smoothed parameter value
    public func getSmoothedValue(_ name: String) -> Float {
        guard let smoother = smoothers[name] else { return 0.0 }
        return smoother.getNextValue()
    }
    
    /// Get current value without advancing smoother
    public func getCurrentValue(_ name: String) -> Float {
        guard let smoother = smoothers[name] else { return 0.0 }
        return smoother.currentSmoothedValue
    }
    
    /// Process all parameters for one sample
    public func processNextSample() -> [String: Float] {
        var results: [String: Float] = [:]
        for (name, smoother) in smoothers {
            results[name] = smoother.getNextValue()
        }
        return results
    }
    
    /// Process a block of samples for specific parameter
    public func processParameterBlock(_ name: String, output: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard let smoother = smoothers[name] else {
            // Fill with zeros if parameter not registered
            vDSP_vclr(output, 1, vDSP_Length(frameCount))
            return
        }
        smoother.processBlock(output: output, frameCount: frameCount)
    }
    
    /// Check if any parameters are currently smoothing
    public var hasActiveSmoothing: Bool {
        return smoothers.values.contains { $0.isSmoothing }
    }
    
    /// Update sample rate for all smoothers
    public func updateSampleRate(_ newSampleRate: Float) {
        config.sampleRate = newSampleRate
        for smoother in smoothers.values {
            smoother.sampleRate = newSampleRate
        }
    }
    
    /// Set quality preset
    public func setQuality(_ newQuality: SmoothingQuality) {
        quality = newQuality
        
        switch newQuality {
        case .disabled:
            config.defaultSmoothingTime = 0.0
        case .fast:
            config.defaultSmoothingTime = 0.002
        case .balanced:
            config.defaultSmoothingTime = 0.01
        case .smooth:
            config.defaultSmoothingTime = 0.05
        case .adaptive:
            config.enableAdaptiveSmoothing = true
            config.defaultSmoothingTime = 0.01
        }
        
        // Update existing smoothers
        for (name, smoother) in smoothers {
            let specificTime = parameterSmoothingTimes[name] ?? config.defaultSmoothingTime
            smoother.smoothingTime = specificTime
        }
    }
}

// MARK: - Filter-Specific Parameter Smoother

/// Specialized parameter smoother for filter operations
public class FilterParameterSmoother: MultiParameterSmoother {
    
    // MARK: - Filter-Specific Parameters
    
    private let filterParameters = [
        "cutoffFrequency", "resonance", "morphAmount", "gain", 
        "bandwidth", "keyTracking", "velocitySensitivity", "pitchBend"
    ]
    
    // MARK: - Initialization
    
    public override init(config: ParameterSmoothingConfig = ParameterSmoothingConfig()) {
        super.init(config: config)
        
        // Register all filter parameters
        for param in filterParameters {
            registerParameter(param)
        }
    }
    
    // MARK: - Filter-Specific Interface
    
    /// Update all filter parameters at once
    public func updateFilterParameters(
        cutoff: Float? = nil,
        resonance: Float? = nil,
        morph: Float? = nil,
        gain: Float? = nil,
        bandwidth: Float? = nil,
        keyTracking: Float? = nil,
        velocitySensitivity: Float? = nil,
        pitchBend: Float? = nil
    ) {
        if let cutoff = cutoff { setParameterTarget("cutoffFrequency", value: cutoff) }
        if let resonance = resonance { setParameterTarget("resonance", value: resonance) }
        if let morph = morph { setParameterTarget("morphAmount", value: morph) }
        if let gain = gain { setParameterTarget("gain", value: gain) }
        if let bandwidth = bandwidth { setParameterTarget("bandwidth", value: bandwidth) }
        if let keyTracking = keyTracking { setParameterTarget("keyTracking", value: keyTracking) }
        if let velocitySensitivity = velocitySensitivity { setParameterTarget("velocitySensitivity", value: velocitySensitivity) }
        if let pitchBend = pitchBend { setParameterTarget("pitchBend", value: pitchBend) }
    }
    
    /// Get all smoothed filter parameters
    public func getSmoothedFilterParameters() -> (
        cutoff: Float, resonance: Float, morph: Float, gain: Float,
        bandwidth: Float, keyTracking: Float, velocitySensitivity: Float, pitchBend: Float
    ) {
        return (
            cutoff: getSmoothedValue("cutoffFrequency"),
            resonance: getSmoothedValue("resonance"),
            morph: getSmoothedValue("morphAmount"),
            gain: getSmoothedValue("gain"),
            bandwidth: getSmoothedValue("bandwidth"),
            keyTracking: getSmoothedValue("keyTracking"),
            velocitySensitivity: getSmoothedValue("velocitySensitivity"),
            pitchBend: getSmoothedValue("pitchBend")
        )
    }
}

// MARK: - Smoothing Utilities

/// Utility functions for parameter smoothing
public struct SmoothingUtilities {
    
    /// Calculate optimal smoothing time based on parameter type and change magnitude
    public static func calculateOptimalSmoothingTime(
        parameterType: String,
        changeAmount: Float,
        baseTime: Float = 0.01
    ) -> Float {
        
        let scaleFactor: Float
        
        switch parameterType.lowercased() {
        case "cutoff", "frequency":
            // Frequency changes need faster smoothing
            scaleFactor = 0.5
        case "resonance", "q":
            // Resonance changes can be slightly slower
            scaleFactor = 1.0
        case "gain", "volume":
            // Gain changes need very fast smoothing
            scaleFactor = 0.3
        case "morph", "blend":
            // Morphing can be slower for musicality
            scaleFactor = 2.0
        default:
            scaleFactor = 1.0
        }
        
        // Adjust based on change magnitude
        let magnitudeScale = 1.0 + (changeAmount * 0.5)
        
        return baseTime * scaleFactor * magnitudeScale
    }
    
    /// Create a smoothing curve with custom shape
    public static func createCustomSmoothingCurve(
        length: Int,
        curveType: SmoothingCurveType = .exponential
    ) -> [Float] {
        
        var curve = [Float](repeating: 0.0, count: length)
        let lengthFloat = Float(length - 1)
        
        for i in 0..<length {
            let t = Float(i) / lengthFloat
            
            switch curveType {
            case .linear:
                curve[i] = t
            case .exponential:
                curve[i] = 1.0 - exp(-5.0 * t)
            case .logarithmic:
                curve[i] = log(1.0 + 9.0 * t) / log(10.0)
            case .sCurve:
                curve[i] = t * t * (3.0 - 2.0 * t)
            }
        }
        
        return curve
    }
}

/// Types of smoothing curves available
public enum SmoothingCurveType: CaseIterable, Codable {
    case linear
    case exponential
    case logarithmic
    case sCurve
} 