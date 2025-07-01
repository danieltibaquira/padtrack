// Lowpass4FilterMachine.swift
// DigitonePad - FilterModule
//
// 4-pole lowpass filter with 24dB/octave slope, self-oscillating resonance,
// drive saturation, and keyboard tracking

import Foundation
import Accelerate
import MachineProtocols
import AudioEngine

// MARK: - 4-Pole Lowpass Filter Core

/// High-quality 4-pole lowpass filter with cascaded biquad topology
public final class FourPoleLowpassFilter: @unchecked Sendable {
    
    // MARK: - Filter State
    
    /// Biquad filter state for each of the 4 poles
    private struct BiquadState {
        var x1: Float = 0.0  // Input delay 1
        var x2: Float = 0.0  // Input delay 2
        var y1: Float = 0.0  // Output delay 1
        var y2: Float = 0.0  // Output delay 2
    }
    
    /// Coefficients for biquad filter
    private struct BiquadCoefficients {
        var b0: Float = 1.0
        var b1: Float = 0.0
        var b2: Float = 0.0
        var a1: Float = 0.0
        var a2: Float = 0.0
    }
    
    // Filter state for 4 cascaded biquads (2 poles each)
    private var biquad1: BiquadState = BiquadState()
    private var biquad2: BiquadState = BiquadState()
    
    // Filter coefficients
    private var coeffs1: BiquadCoefficients = BiquadCoefficients()
    private var coeffs2: BiquadCoefficients = BiquadCoefficients()
    
    // MARK: - Parameters
    
    public var cutoffFrequency: Float = 1000.0 {
        didSet { updateCoefficients() }
    }
    
    public var resonance: Float = 0.0 {
        didSet { updateCoefficients() }
    }
    
    public var drive: Float = 0.0 {
        didSet { updateSaturation() }
    }
    
    // MARK: - Configuration
    
    private let sampleRate: Float
    private var driveGain: Float = 1.0
    private var postGain: Float = 1.0
    
    // Self-oscillation state
    private var isOscillating: Bool = false
    private var oscillationPhase: Float = 0.0
    private var oscillationAmplitude: Float = 0.0
    
    // MARK: - Initialization
    
    public init(sampleRate: Float = 44100.0) {
        self.sampleRate = sampleRate
        updateCoefficients()
        updateSaturation()
    }
    
    // MARK: - Audio Processing
    
    /// Process a single sample through the 4-pole filter
    public func processSample(_ input: Float) -> Float {
        // Apply input drive
        var sample = input * driveGain
        
        // Apply soft saturation if drive is enabled
        if drive > 0.0 {
            sample = applySaturation(sample)
        }
        
        // Check for self-oscillation
        if resonance > 0.95 {
            sample = processWithOscillation(sample)
        } else {
            sample = processNormal(sample)
        }
        
        // Apply post-gain compensation
        return sample * postGain
    }
    
    /// Process a block of samples for efficiency
    public func processBlock(_ input: [Float], output: inout [Float], blockSize: Int) {
        let count = min(blockSize, min(input.count, output.count))
        
        for i in 0..<count {
            output[i] = processSample(input[i])
        }
    }
    
    // MARK: - Private Processing Methods
    
    private func processNormal(_ input: Float) -> Float {
        // First biquad (poles 1-2)
        let stage1Output = processBiquad(input, state: &biquad1, coeffs: coeffs1)
        
        // Second biquad (poles 3-4) 
        let stage2Output = processBiquad(stage1Output, state: &biquad2, coeffs: coeffs2)
        
        return stage2Output
    }
    
    private func processWithOscillation(_ input: Float) -> Float {
        // Self-oscillation mode - generate sine wave at cutoff frequency
        let oscillationFreq = cutoffFrequency
        let phaseIncrement = oscillationFreq / sampleRate * 2.0 * Float.pi
        
        oscillationPhase += phaseIncrement
        if oscillationPhase >= 2.0 * Float.pi {
            oscillationPhase -= 2.0 * Float.pi
        }
        
        // Calculate oscillation amplitude based on resonance overshoot
        oscillationAmplitude = (resonance - 0.95) * 10.0  // Scale overshoot
        
        // Generate oscillation signal
        let oscillationSignal = sin(oscillationPhase) * oscillationAmplitude
        
        // Mix input with oscillation (reduce input influence during oscillation)
        let inputMix = min(0.2, 1.0 - oscillationAmplitude)
        let mixedInput = input * inputMix + oscillationSignal
        
        // Process through filter with reduced feedback to prevent runaway
        return processNormal(mixedInput) * 0.8
    }
    
    private func processBiquad(_ input: Float, state: inout BiquadState, coeffs: BiquadCoefficients) -> Float {
        // Direct Form II biquad implementation
        let output = coeffs.b0 * input + coeffs.b1 * state.x1 + coeffs.b2 * state.x2 - coeffs.a1 * state.y1 - coeffs.a2 * state.y2
        
        // Update state
        state.x2 = state.x1
        state.x1 = input
        state.y2 = state.y1
        state.y1 = output
        
        return output
    }
    
    private func applySaturation(_ input: Float) -> Float {
        // Soft clipping with adjustable curve
        let driveAmount = drive * 5.0  // Scale drive for more dramatic effect
        let driven = input * (1.0 + driveAmount)
        
        // Hyperbolic tangent saturation
        return tanh(driven) / (1.0 + driveAmount * 0.3)  // Compensate gain
    }
    
    // MARK: - Coefficient Calculation
    
    private func updateCoefficients() {
        // Clamp parameters to safe ranges
        let freq = max(20.0, min(cutoffFrequency, sampleRate * 0.45))
        let q = 0.5 + resonance * 9.5  // Q range: 0.5 to 10.0
        
        // Calculate normalized frequency
        let omega = 2.0 * Float.pi * freq / sampleRate
        let cosOmega = cos(omega)
        let sinOmega = sin(omega)
        let alpha = sinOmega / (2.0 * q)
        
        // Lowpass biquad coefficients
        let norm = 1.0 + alpha
        
        coeffs1.b0 = (1.0 - cosOmega) / (2.0 * norm)
        coeffs1.b1 = (1.0 - cosOmega) / norm
        coeffs1.b2 = (1.0 - cosOmega) / (2.0 * norm)
        coeffs1.a1 = -2.0 * cosOmega / norm
        coeffs1.a2 = (1.0 - alpha) / norm
        
        // Second stage uses same coefficients for 4-pole response
        coeffs2 = coeffs1
        
        // Update oscillation detection
        isOscillating = resonance > 0.95
    }
    
    private func updateSaturation() {
        // Calculate drive gain and compensation
        driveGain = 1.0 + drive * 3.0
        postGain = 1.0 / (1.0 + drive * 0.5)  // Compensate for drive gain
    }
    
    // MARK: - Utility Methods
    
    public func reset() {
        biquad1 = BiquadState()
        biquad2 = BiquadState()
        oscillationPhase = 0.0
        oscillationAmplitude = 0.0
    }
    
    /// Get the current filter response at a given frequency
    public func getResponseAt(frequency: Float) -> Float {
        let omega = 2.0 * Float.pi * frequency / sampleRate
        
        // Calculate magnitude response for 4-pole lowpass
        let ratio = frequency / cutoffFrequency
        let magnitude = 1.0 / sqrt(1.0 + pow(ratio, 8.0))  // 4th order = 8th power
        
        return magnitude
    }
}

// MARK: - Keyboard Tracking

/// Keyboard tracking system for filter cutoff frequency
public final class FilterKeyboardTracking: @unchecked Sendable {
    
    // MARK: - Configuration
    
    public struct TrackingConfig {
        public var amount: Float = 0.0        // -1.0 to 1.0
        public var referenceNote: Int = 60    // C4
        public var curve: TrackingCurve = .linear
        
        public init() {}
    }
    
    public enum TrackingCurve: String, CaseIterable {
        case linear = "linear"
        case exponential = "exponential"
        case logarithmic = "logarithmic"
        
        public var description: String {
            switch self {
            case .linear: return "Linear"
            case .exponential: return "Exponential"
            case .logarithmic: return "Logarithmic"
            }
        }
    }
    
    // MARK: - Properties
    
    public var config: TrackingConfig = TrackingConfig()
    
    // MARK: - Tracking Calculation
    
    /// Calculate frequency offset based on MIDI note
    public func calculateFrequencyMultiplier(for note: Int) -> Float {
        guard config.amount != 0.0 else { return 1.0 }
        
        let noteOffset = Float(note - config.referenceNote)
        let semitoneRatio = pow(2.0, noteOffset / 12.0)  // Standard musical ratio
        
        // Apply tracking curve
        let curvedRatio: Float
        switch config.curve {
        case .linear:
            curvedRatio = 1.0 + (semitoneRatio - 1.0) * config.amount
        case .exponential:
            curvedRatio = pow(semitoneRatio, config.amount)
        case .logarithmic:
            let logRatio = log2(semitoneRatio)
            curvedRatio = pow(2.0, logRatio * config.amount)
        }
        
        return max(0.1, min(curvedRatio, 10.0))  // Clamp to reasonable range
    }
    
    /// Get tracking amount for display
    public func getTrackingAmount() -> Float {
        return config.amount
    }
    
    /// Set tracking amount (-1.0 to 1.0)
    public func setTrackingAmount(_ amount: Float) {
        config.amount = max(-1.0, min(1.0, amount))
    }
}

// MARK: - Lowpass 4 Filter Machine

/// Complete 4-pole lowpass filter machine with all features
public final class Lowpass4FilterMachine: FilterMachine, @unchecked Sendable {
    
    // MARK: - Core Components
    
    /// 4-pole lowpass filter engine
    private let filter: FourPoleLowpassFilter
    
    /// Keyboard tracking system
    private let keyboardTracking: FilterKeyboardTracking
    
    // MARK: - State
    
    private var currentNote: Int = 60
    private var baseCutoffFrequency: Float = 1000.0
    
    // Audio processing
    private let sampleRate: Float
    private var outputBuffer: [Float] = []
    private var tempBuffer: [Float] = []
    
    // MARK: - Initialization
    
    public override init(name: String = "Lowpass 4", sampleRate: Float = 44100.0) {
        self.sampleRate = sampleRate
        self.filter = FourPoleLowpassFilter(sampleRate: sampleRate)
        self.keyboardTracking = FilterKeyboardTracking()
        
        super.init(name: name)
        
        setupFilterParameters()
        
        // Initialize buffers
        outputBuffer = [Float](repeating: 0.0, count: 1024)
        tempBuffer = [Float](repeating: 0.0, count: 1024)
    }
    
    // MARK: - FilterMachine Protocol Implementation
    
    public override func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        let frameCount = input.frameCount
        let channelCount = input.channelCount
        
        // Ensure output buffer is large enough
        if outputBuffer.count < frameCount * channelCount {
            outputBuffer = [Float](repeating: 0.0, count: frameCount * channelCount)
            tempBuffer = [Float](repeating: 0.0, count: frameCount)
        }
        
        // Update filter parameters
        updateFilterParameters()
        
        // Process each channel
        for channel in 0..<channelCount {
            // Extract channel data
            for frame in 0..<frameCount {
                let inputIndex = frame * channelCount + channel
                tempBuffer[frame] = inputIndex < input.data.count ? input.data[inputIndex] : 0.0
            }
            
            // Process through filter
            filter.processBlock(tempBuffer, output: &tempBuffer, blockSize: frameCount)
            
            // Store back to output buffer
            for frame in 0..<frameCount {
                let outputIndex = frame * channelCount + channel
                if outputIndex < outputBuffer.count {
                    outputBuffer[outputIndex] = tempBuffer[frame]
                }
            }
        }
        
        return MachineProtocols.AudioBuffer(
            data: outputBuffer,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: input.sampleRate
        )
    }
    
    // MARK: - MIDI Integration
    
    public override func noteOn(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?) {
        currentNote = Int(note)
        updateFilterParameters()
        super.noteOn(note: note, velocity: velocity, channel: channel, timestamp: timestamp)
    }
    
    // MARK: - Parameter Management
    
    private func setupFilterParameters() {
        // Cutoff frequency parameter
        parameters.addParameter(Parameter(
            id: "cutoff",
            name: "Cutoff",
            description: "Filter cutoff frequency",
            value: 1000.0,
            minValue: 20.0,
            maxValue: 20000.0,
            defaultValue: 1000.0,
            unit: "Hz",
            category: .filter,
            dataType: .float,
            scaling: .logarithmic,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: { [weak self] _, _, newValue in
                self?.baseCutoffFrequency = newValue
                self?.updateFilterParameters()
            }
        ))
        
        // Resonance parameter
        parameters.addParameter(Parameter(
            id: "resonance",
            name: "Resonance",
            description: "Filter resonance amount",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .filter,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: { [weak self] _, _, newValue in
                self?.filter.resonance = newValue
            }
        ))
        
        // Drive parameter
        parameters.addParameter(Parameter(
            id: "drive",
            name: "Drive",
            description: "Input drive/saturation amount",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .filter,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: { [weak self] _, _, newValue in
                self?.filter.drive = newValue
            }
        ))
        
        // Keyboard tracking parameter
        parameters.addParameter(Parameter(
            id: "tracking",
            name: "Key Track",
            description: "Keyboard tracking amount",
            value: 0.0,
            minValue: -1.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .filter,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: { [weak self] _, _, newValue in
                self?.keyboardTracking.setTrackingAmount(newValue)
                self?.updateFilterParameters()
            }
        ))
        
        // Tracking curve parameter
        parameters.addParameter(Parameter(
            id: "tracking_curve",
            name: "Track Curve",
            description: "Keyboard tracking curve type",
            value: 0.0,
            minValue: 0.0,
            maxValue: 2.0,
            defaultValue: 0.0,
            unit: "",
            category: .filter,
            dataType: .enumeration,
            scaling: .linear,
            isAutomatable: false,
            stepSize: nil,
            enumerationValues: FilterKeyboardTracking.TrackingCurve.allCases.map { $0.description },
            changeCallback: { [weak self] _, _, newValue in
                let curves = FilterKeyboardTracking.TrackingCurve.allCases
                let index = Int(newValue.rounded())
                if index >= 0 && index < curves.count {
                    self?.keyboardTracking.config.curve = curves[index]
                    self?.updateFilterParameters()
                }
            }
        ))
    }
    
    private func updateFilterParameters() {
        // Apply keyboard tracking to cutoff frequency
        let trackingMultiplier = keyboardTracking.calculateFrequencyMultiplier(for: currentNote)
        let finalCutoff = baseCutoffFrequency * trackingMultiplier
        
        // Clamp to valid range
        filter.cutoffFrequency = max(20.0, min(finalCutoff, sampleRate * 0.45))
    }
    
    // MARK: - Utility Methods
    
    public func reset() {
        filter.reset()
    }
    
    /// Get the current filter response for visualization
    public func getFrequencyResponse(frequencies: [Float]) -> [Float] {
        return frequencies.map { filter.getResponseAt(frequency: $0) }
    }
    
    /// Check if filter is currently self-oscillating
    public var isOscillating: Bool {
        return filter.resonance > 0.95
    }
    
    /// Get current effective cutoff frequency (with tracking applied)
    public var effectiveCutoffFrequency: Float {
        let trackingMultiplier = keyboardTracking.calculateFrequencyMultiplier(for: currentNote)
        return baseCutoffFrequency * trackingMultiplier
    }
}