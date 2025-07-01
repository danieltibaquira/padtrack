// Lowpass4FilterMachine.swift
// DigitonePad - FilterMachine
//
// 4-pole lowpass filter with 24dB/octave slope for FLTR section
// Professional implementation with resonance, drive, and keyboard tracking

import Foundation
import Accelerate
import simd
import MachineProtocols
import AudioEngine

// MARK: - 4-Pole Filter Configuration

/// Configuration for the 4-pole lowpass filter
public struct Lowpass4FilterConfig: Codable {
    /// Cutoff frequency in Hz (20Hz - 20kHz)
    public var cutoffFrequency: Float = 1000.0
    
    /// Resonance amount (0.0 - 1.0)
    public var resonance: Float = 0.0
    
    /// Drive/saturation amount (0.0 - 1.0)
    public var drive: Float = 0.0
    
    /// Keyboard tracking amount (-1.0 to 1.0)
    public var keyboardTracking: Float = 0.0
    
    /// Self-oscillation threshold (0.9 - 0.99)
    public var selfOscillationThreshold: Float = 0.95
    
    /// Drive saturation type
    public var driveType: DriveSaturationType = .analog
    
    /// Filter topology (cascaded biquads vs direct form)
    public var topology: FilterTopology = .cascadedBiquads
    
    public init() {}
    
    /// Validate and clamp parameters to safe ranges
    public mutating func validate() {
        cutoffFrequency = max(20.0, min(20000.0, cutoffFrequency))
        resonance = max(0.0, min(1.0, resonance))
        drive = max(0.0, min(1.0, drive))
        keyboardTracking = max(-1.0, min(1.0, keyboardTracking))
        selfOscillationThreshold = max(0.9, min(0.99, selfOscillationThreshold))
    }
}

/// Drive saturation types for harmonic coloration
public enum DriveSaturationType: String, CaseIterable, Codable {
    case clean = "clean"
    case analog = "analog"
    case tube = "tube"
    case transistor = "transistor"
    case digital = "digital"
    
    public var description: String {
        switch self {
        case .clean: return "Clean"
        case .analog: return "Analog"
        case .tube: return "Tube"
        case .transistor: return "Transistor"
        case .digital: return "Digital"
        }
    }
}

/// Filter implementation topology
public enum FilterTopology: String, CaseIterable, Codable {
    case cascadedBiquads = "cascaded"
    case directForm = "direct"
    case stateVariable = "statevariable"
    
    public var description: String {
        switch self {
        case .cascadedBiquads: return "Cascaded Biquads"
        case .directForm: return "Direct Form"
        case .stateVariable: return "State Variable"
        }
    }
}

// MARK: - 4-Pole Biquad Coefficients

/// Coefficients for a single biquad stage
public struct BiquadCoefficients {
    public var b0: Float = 1.0
    public var b1: Float = 0.0
    public var b2: Float = 0.0
    public var a1: Float = 0.0
    public var a2: Float = 0.0
    
    public init() {}
    
    public init(b0: Float, b1: Float, b2: Float, a1: Float, a2: Float) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.a1 = a1
        self.a2 = a2
    }
}

/// Complete coefficient set for 4-pole filter (2 cascaded biquads)
public struct Lowpass4Coefficients {
    public var stage1: BiquadCoefficients
    public var stage2: BiquadCoefficients
    
    public init() {
        self.stage1 = BiquadCoefficients()
        self.stage2 = BiquadCoefficients()
    }
    
    public init(stage1: BiquadCoefficients, stage2: BiquadCoefficients) {
        self.stage1 = stage1
        self.stage2 = stage2
    }
}

// MARK: - 4-Pole Filter State

/// State variables for a single biquad stage
public struct BiquadState {
    public var x1: Float = 0.0  // Input delay 1
    public var x2: Float = 0.0  // Input delay 2
    public var y1: Float = 0.0  // Output delay 1
    public var y2: Float = 0.0  // Output delay 2
    
    public mutating func reset() {
        x1 = 0.0
        x2 = 0.0
        y1 = 0.0
        y2 = 0.0
    }
}

/// Complete state for 4-pole filter
public struct Lowpass4FilterState {
    public var stage1: BiquadState
    public var stage2: BiquadState
    public var globalFeedback: Float = 0.0  // For self-oscillation
    
    public init() {
        self.stage1 = BiquadState()
        self.stage2 = BiquadState()
    }
    
    public mutating func reset() {
        stage1.reset()
        stage2.reset()
        globalFeedback = 0.0
    }
}

// MARK: - Coefficient Calculator

/// Calculates coefficients for 4-pole lowpass filter
public final class Lowpass4CoefficientCalculator {
    
    private let sampleRate: Double
    
    public init(sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate
    }
    
    /// Calculate 4-pole lowpass coefficients using cascaded biquads
    public func calculateCoefficients(
        cutoffFrequency: Float,
        resonance: Float,
        topology: FilterTopology = .cascadedBiquads
    ) -> Lowpass4Coefficients {
        
        switch topology {
        case .cascadedBiquads:
            return calculateCascadedBiquadCoefficients(cutoffFrequency: cutoffFrequency, resonance: resonance)
        case .directForm:
            return calculateDirectFormCoefficients(cutoffFrequency: cutoffFrequency, resonance: resonance)
        case .stateVariable:
            return calculateStateVariableCoefficients(cutoffFrequency: cutoffFrequency, resonance: resonance)
        }
    }
    
    // MARK: - Cascaded Biquad Implementation
    
    private func calculateCascadedBiquadCoefficients(cutoffFrequency: Float, resonance: Float) -> Lowpass4Coefficients {
        // For 4-pole Butterworth response, we use two identical 2-pole stages
        // Each stage has a Q factor that creates the overall 4-pole response
        
        let nyquist = Float(sampleRate * 0.5)
        let normalizedFreq = min(cutoffFrequency / nyquist, 0.99)
        
        // Pre-warp frequency for bilinear transform
        let omega = tan(Float.pi * normalizedFreq)
        let omega2 = omega * omega
        
        // For 4-pole Butterworth, we need two biquads with specific Q values
        // Stage 1: Q = 0.5412 (poles at ±45°)
        // Stage 2: Q = 1.3065 (poles at ±135°)
        
        let q1 = 0.5412 + resonance * 2.0  // Modulate Q with resonance
        let q2 = 1.3065 + resonance * 2.0
        
        let stage1 = calculateBiquadLowpass(omega: omega, omega2: omega2, q: q1)
        let stage2 = calculateBiquadLowpass(omega: omega, omega2: omega2, q: q2)
        
        return Lowpass4Coefficients(stage1: stage1, stage2: stage2)
    }
    
    private func calculateBiquadLowpass(omega: Float, omega2: Float, q: Float) -> BiquadCoefficients {
        // Standard biquad lowpass design
        let k = omega / q
        let denominator = 1.0 + k + omega2
        
        let b0 = omega2 / denominator
        let b1 = 2.0 * b0
        let b2 = b0
        let a1 = (2.0 * omega2 - 2.0) / denominator
        let a2 = (1.0 - k + omega2) / denominator
        
        return BiquadCoefficients(b0: b0, b1: b1, b2: b2, a1: a1, a2: a2)
    }
    
    // MARK: - Direct Form Implementation
    
    private func calculateDirectFormCoefficients(cutoffFrequency: Float, resonance: Float) -> Lowpass4Coefficients {
        // Direct form 4-pole filter design
        // This provides tighter control over the overall response
        
        let nyquist = Float(sampleRate * 0.5)
        let normalizedFreq = min(cutoffFrequency / nyquist, 0.99)
        
        // Calculate poles for 4-pole Butterworth filter
        let omega = 2.0 * Float.pi * normalizedFreq
        
        // Pole angles for 4-pole Butterworth: ±45°, ±135°
        let angles: [Float] = [Float.pi * 0.25, Float.pi * 0.75, Float.pi * 1.25, Float.pi * 1.75]
        
        // Convert to complex poles and apply resonance
        var poles: [simd_float2] = []
        for angle in angles {
            let real = cos(angle) * (1.0 - resonance * 0.1)  // Move poles closer to unit circle
            let imag = sin(angle) * (1.0 - resonance * 0.1)
            poles.append(simd_float2(real, imag))
        }
        
        // Convert complex poles to cascaded biquad form
        let stage1 = polesToBiquad(pole1: poles[0], pole2: poles[1], omega: omega)
        let stage2 = polesToBiquad(pole1: poles[2], pole2: poles[3], omega: omega)
        
        return Lowpass4Coefficients(stage1: stage1, stage2: stage2)
    }
    
    private func polesToBiquad(pole1: simd_float2, pole2: simd_float2, omega: Float) -> BiquadCoefficients {
        // Convert complex conjugate pole pair to biquad coefficients
        let real = pole1.x
        let imag = abs(pole1.y)
        
        let r = sqrt(real * real + imag * imag)
        let theta = atan2(imag, real)
        
        // Bilinear transform
        let k = tan(omega * 0.5)
        let k2 = k * k
        
        let a1 = -2.0 * r * cos(theta)
        let a2 = r * r
        
        let denominator = 1.0 + a1 * k + a2 * k2
        
        let b0 = k2 / denominator
        let b1 = 2.0 * b0
        let b2 = b0
        let a1_final = (2.0 * k2 - 2.0) / denominator
        let a2_final = (1.0 - a1 * k + a2 * k2) / denominator
        
        return BiquadCoefficients(b0: b0, b1: b1, b2: b2, a1: a1_final, a2: a2_final)
    }
    
    // MARK: - State Variable Implementation
    
    private func calculateStateVariableCoefficients(cutoffFrequency: Float, resonance: Float) -> Lowpass4Coefficients {
        // State variable filter approach for 4-pole design
        // This provides excellent control over resonance and self-oscillation
        
        let nyquist = Float(sampleRate * 0.5)
        let normalizedFreq = min(cutoffFrequency / nyquist, 0.99)
        
        // Calculate frequency and damping parameters
        let f = normalizedFreq
        let q = 0.5 + resonance * 10.0  // Resonance range
        
        // Two-integrator loop parameters
        let g = tan(Float.pi * f)
        let k = 1.0 / q
        let a1 = 1.0 / (1.0 + g * (g + k))
        let a2 = g * a1
        let a3 = g * a2
        
        // Convert to biquad form for compatibility
        let stage1 = BiquadCoefficients(
            b0: a3,
            b1: 2.0 * a3,
            b2: a3,
            a1: 2.0 * (a3 - a1),
            a2: a1 - a2 + a3
        )
        
        // Second stage with modified parameters for 4-pole response
        let g2 = g * 0.7071  // Adjust for proper 4-pole rolloff
        let a1_2 = 1.0 / (1.0 + g2 * (g2 + k))
        let a2_2 = g2 * a1_2
        let a3_2 = g2 * a2_2
        
        let stage2 = BiquadCoefficients(
            b0: a3_2,
            b1: 2.0 * a3_2,
            b2: a3_2,
            a1: 2.0 * (a3_2 - a1_2),
            a2: a1_2 - a2_2 + a3_2
        )
        
        return Lowpass4Coefficients(stage1: stage1, stage2: stage2)
    }
}

// MARK: - Drive/Saturation Processor

/// Applies drive and saturation effects
public final class DriveSaturationProcessor {
    
    public var driveType: DriveSaturationType = .analog
    public var driveAmount: Float = 0.0
    
    public init() {}
    
    /// Process a single sample through the drive/saturation algorithm
    public func processSample(_ input: Float) -> Float {
        guard driveAmount > 0.001 else { return input }
        
        let driven = input * (1.0 + driveAmount * 9.0)  // Drive gain
        
        switch driveType {
        case .clean:
            return driven
            
        case .analog:
            return analogSaturation(driven)
            
        case .tube:
            return tubeSaturation(driven)
            
        case .transistor:
            return transistorSaturation(driven)
            
        case .digital:
            return digitalSaturation(driven)
        }
    }
    
    // MARK: - Saturation Algorithms
    
    private func analogSaturation(_ input: Float) -> Float {
        // Smooth analog-style saturation using tanh
        let scaled = input * 0.7
        return tanh(scaled) * (1.0 / tanh(0.7))
    }
    
    private func tubeSaturation(_ input: Float) -> Float {
        // Tube-style asymmetric saturation
        let x = input * 0.5
        if x >= 0.0 {
            return x / (1.0 + x)  // Soft compression for positive
        } else {
            return x / (1.0 - x * 0.7)  // Harder compression for negative
        }
    }
    
    private func transistorSaturation(_ input: Float) -> Float {
        // Transistor-style hard clipping with soft knee
        let threshold = 0.8
        let x = input * 0.6
        
        if abs(x) < threshold {
            return x
        } else {
            let sign = x >= 0.0 ? 1.0 : -1.0
            let excess = abs(x) - threshold
            let compressed = threshold + excess / (1.0 + excess * 2.0)
            return sign * compressed
        }
    }
    
    private func digitalSaturation(_ input: Float) -> Float {
        // Digital-style bit reduction and quantization
        let bits = 8.0 - driveAmount * 4.0  // 8 to 4 bits
        let levels = pow(2.0, bits)
        let quantized = round(input * levels) / levels
        return max(-1.0, min(1.0, quantized))
    }
}

// MARK: - Main 4-Pole Filter Engine

/// High-performance 4-pole lowpass filter with resonance, drive, and keyboard tracking
public final class Lowpass4FilterMachine: @unchecked Sendable {
    
    // MARK: - Configuration
    
    public var config: Lowpass4FilterConfig {
        didSet {
            config.validate()
            updateCoefficients()
        }
    }
    
    // MARK: - Processing Components
    
    private let coefficientCalculator: Lowpass4CoefficientCalculator
    private let driveProcessor: DriveSaturationProcessor
    private var filterState: Lowpass4FilterState
    private var currentCoefficients: Lowpass4Coefficients
    
    // MARK: - Performance State
    
    private let sampleRate: Double
    private var isEnabled: Bool = true
    private var currentNote: Int = 60  // C4
    private var currentVelocity: Float = 1.0
    
    // MARK: - Self-Oscillation State
    
    private var oscillatorPhase: Float = 0.0
    private var isOscillating: Bool = false
    private var oscillationFrequency: Float = 440.0
    
    // MARK: - Initialization
    
    public init(config: Lowpass4FilterConfig = Lowpass4FilterConfig(), sampleRate: Double = 44100.0) {
        self.config = config
        self.sampleRate = sampleRate
        self.coefficientCalculator = Lowpass4CoefficientCalculator(sampleRate: sampleRate)
        self.driveProcessor = DriveSaturationProcessor()
        self.filterState = Lowpass4FilterState()
        self.currentCoefficients = Lowpass4Coefficients()
        
        // Initialize components
        self.driveProcessor.driveType = config.driveType
        self.driveProcessor.driveAmount = config.drive
        
        updateCoefficients()
    }
    
    // MARK: - Public Interface
    
    /// Process a single sample
    public func processSample(_ input: Float) -> Float {
        guard isEnabled else { return input }
        
        // Apply drive/saturation to input
        let drivenInput = driveProcessor.processSample(input)
        
        // Check for self-oscillation
        if config.resonance >= config.selfOscillationThreshold {
            return processSampleWithOscillation(drivenInput)
        } else {
            return processSampleNormal(drivenInput)
        }
    }
    
    /// Process a buffer of samples for efficiency
    public func processBuffer(input: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard isEnabled else {
            // Bypass - copy input to output
            cblas_scopy(Int32(frameCount), input, 1, output, 1)
            return
        }
        
        for i in 0..<frameCount {
            output[i] = processSample(input[i])
        }
    }
    
    /// Handle MIDI note events for keyboard tracking
    public func noteOn(noteNumber: Int, velocity: Float) {
        currentNote = noteNumber
        currentVelocity = velocity
        updateCutoffWithKeyTracking()
    }
    
    /// Handle note off events
    public func noteOff() {
        // Optional: implement note-off behavior
    }
    
    /// Reset filter state
    public func reset() {
        filterState.reset()
        oscillatorPhase = 0.0
        isOscillating = false
    }
    
    /// Enable/disable filter processing
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            reset()
        }
    }
    
    // MARK: - Parameter Updates
    
    /// Update cutoff frequency
    public func setCutoffFrequency(_ frequency: Float) {
        config.cutoffFrequency = max(20.0, min(20000.0, frequency))
        updateCoefficients()
    }
    
    /// Update resonance amount
    public func setResonance(_ resonance: Float) {
        config.resonance = max(0.0, min(1.0, resonance))
        updateCoefficients()
    }
    
    /// Update drive amount
    public func setDrive(_ drive: Float) {
        config.drive = max(0.0, min(1.0, drive))
        driveProcessor.driveAmount = config.drive
    }
    
    /// Update keyboard tracking amount
    public func setKeyboardTracking(_ tracking: Float) {
        config.keyboardTracking = max(-1.0, min(1.0, tracking))
        updateCutoffWithKeyTracking()
    }
    
    // MARK: - Private Implementation
    
    private func updateCoefficients() {
        currentCoefficients = coefficientCalculator.calculateCoefficients(
            cutoffFrequency: config.cutoffFrequency,
            resonance: config.resonance,
            topology: config.topology
        )
    }
    
    private func updateCutoffWithKeyTracking() {
        guard config.keyboardTracking != 0.0 else { return }
        
        // Calculate frequency offset based on note difference from C4 (60)
        let noteOffset = Float(currentNote - 60)
        let semitoneRatio = pow(2.0, noteOffset / 12.0)
        let trackingAmount = config.keyboardTracking
        
        // Apply keyboard tracking to cutoff frequency
        let trackedFrequency = config.cutoffFrequency * pow(semitoneRatio, trackingAmount)
        let clampedFrequency = max(20.0, min(20000.0, trackedFrequency))
        
        currentCoefficients = coefficientCalculator.calculateCoefficients(
            cutoffFrequency: clampedFrequency,
            resonance: config.resonance,
            topology: config.topology
        )
    }
    
    private func processSampleNormal(_ input: Float) -> Float {
        // Process through cascaded biquad stages
        let stage1Output = processBiquadStage(
            input: input,
            coefficients: currentCoefficients.stage1,
            state: &filterState.stage1
        )
        
        let stage2Output = processBiquadStage(
            input: stage1Output,
            coefficients: currentCoefficients.stage2,
            state: &filterState.stage2
        )
        
        return stage2Output
    }
    
    private func processSampleWithOscillation(_ input: Float) -> Float {
        // Self-oscillation mode
        isOscillating = true
        
        // Generate oscillation at cutoff frequency
        oscillationFrequency = config.cutoffFrequency
        let phaseIncrement = 2.0 * Float.pi * oscillationFrequency / Float(sampleRate)
        
        oscillatorPhase += phaseIncrement
        if oscillatorPhase >= 2.0 * Float.pi {
            oscillatorPhase -= 2.0 * Float.pi
        }
        
        let oscillation = sin(oscillatorPhase)
        let oscillationGain = (config.resonance - config.selfOscillationThreshold) * 10.0
        
        // Mix input with oscillation
        let mixedInput = input * 0.1 + oscillation * oscillationGain
        
        // Process through filter with reduced resonance to prevent runaway
        let tempResonance = config.resonance
        config.resonance = config.selfOscillationThreshold * 0.9
        updateCoefficients()
        
        let output = processSampleNormal(mixedInput)
        
        // Restore original resonance
        config.resonance = tempResonance
        updateCoefficients()
        
        return output
    }
    
    private func processBiquadStage(
        input: Float,
        coefficients: BiquadCoefficients,
        state: inout BiquadState
    ) -> Float {
        // Direct Form II biquad implementation
        let w = input - coefficients.a1 * state.y1 - coefficients.a2 * state.y2
        let output = coefficients.b0 * w + coefficients.b1 * state.x1 + coefficients.b2 * state.x2
        
        // Update state
        state.x2 = state.x1
        state.x1 = w
        state.y2 = state.y1
        state.y1 = output
        
        return output
    }
}

// MARK: - FilterMachine Protocol Conformance

extension Lowpass4FilterMachine: FilterMachine {
    
    public var machineType: String {
        return "Lowpass4Filter"
    }
    
    public var parameterCount: Int {
        return 4  // Cutoff, Resonance, Drive, Keyboard Tracking
    }
    
    public func getParameterName(index: Int) -> String {
        switch index {
        case 0: return "CUTOFF"
        case 1: return "RESO"
        case 2: return "DRIVE"
        case 3: return "TRACK"
        default: return "UNKNOWN"
        }
    }
    
    public func getParameterValue(index: Int) -> Float {
        switch index {
        case 0: return config.cutoffFrequency
        case 1: return config.resonance
        case 2: return config.drive
        case 3: return config.keyboardTracking
        default: return 0.0
        }
    }
    
    public func setParameterValue(index: Int, value: Float) {
        switch index {
        case 0: setCutoffFrequency(value)
        case 1: setResonance(value)
        case 2: setDrive(value)
        case 3: setKeyboardTracking(value)
        default: break
        }
    }
    
    public func getParameterDisplayValue(index: Int) -> String {
        switch index {
        case 0: return String(format: "%.1f Hz", config.cutoffFrequency)
        case 1: return String(format: "%.2f", config.resonance)
        case 2: return String(format: "%.2f", config.drive)
        case 3: return String(format: "%.1f%%", config.keyboardTracking * 100.0)
        default: return ""
        }
    }
}

// MARK: - Analysis and Diagnostics

extension Lowpass4FilterMachine {
    
    /// Get current filter status for debugging
    public var filterStatus: FilterStatus {
        return FilterStatus(
            isEnabled: isEnabled,
            cutoffFrequency: config.cutoffFrequency,
            resonance: config.resonance,
            isOscillating: isOscillating,
            currentNote: currentNote,
            topology: config.topology.rawValue
        )
    }
    
    /// Calculate frequency response at given frequency
    public func getFrequencyResponse(at frequency: Float) -> Float {
        // Simplified frequency response calculation for visualization
        let nyquist = Float(sampleRate * 0.5)
        let normalizedFreq = frequency / nyquist
        
        if normalizedFreq > 1.0 { return 0.0 }
        
        // 4-pole lowpass response: -24dB/octave above cutoff
        let cutoffNormalized = config.cutoffFrequency / nyquist
        let ratio = normalizedFreq / cutoffNormalized
        
        if ratio <= 1.0 {
            return 1.0  // Passband
        } else {
            // -24dB/octave rolloff
            let octaves = log2(ratio)
            let attenuation = pow(10.0, -24.0 * octaves / 20.0)
            return attenuation
        }
    }
}

/// Filter status information for debugging and display
public struct FilterStatus {
    public let isEnabled: Bool
    public let cutoffFrequency: Float
    public let resonance: Float
    public let isOscillating: Bool
    public let currentNote: Int
    public let topology: String
    
    public init(isEnabled: Bool, cutoffFrequency: Float, resonance: Float, isOscillating: Bool, currentNote: Int, topology: String) {
        self.isEnabled = isEnabled
        self.cutoffFrequency = cutoffFrequency
        self.resonance = resonance
        self.isOscillating = isOscillating
        self.currentNote = currentNote
        self.topology = topology
    }
}