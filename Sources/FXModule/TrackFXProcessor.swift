// TrackFXProcessor.swift
// DigitonePad - FXModule
//
// Per-track effects processing chain with bit reduction, sample rate reduction, and overdrive
// Efficient AVAudioUnit-compatible processors for track signal chains

import Foundation
import AVFoundation
import Accelerate
import AudioEngine
import MachineProtocols

// MARK: - Track FX Configuration

/// Configuration for the complete track FX chain
public struct TrackFXConfig: Codable {
    /// Bit reduction settings
    public var bitReduction: BitReductionConfig
    
    /// Sample rate reduction settings
    public var sampleRateReduction: SampleRateReductionConfig
    
    /// Overdrive settings
    public var overdrive: OverdriveConfig
    
    /// Global bypass for entire FX chain
    public var globalBypass: Bool = false
    
    /// Effect processing order
    public var processingOrder: [TrackFXType] = [.bitReduction, .sampleRateReduction, .overdrive]
    
    public init() {
        self.bitReduction = BitReductionConfig()
        self.sampleRateReduction = SampleRateReductionConfig()
        self.overdrive = OverdriveConfig()
    }
}

/// Individual track effect types
public enum TrackFXType: String, CaseIterable, Codable {
    case bitReduction = "bitreduction"
    case sampleRateReduction = "sampleratereduction"
    case overdrive = "overdrive"
    
    public var displayName: String {
        switch self {
        case .bitReduction: return "Bit Reduction"
        case .sampleRateReduction: return "Sample Rate Reduction"
        case .overdrive: return "Overdrive"
        }
    }
}

// MARK: - Bit Reduction Configuration

/// Configuration for bit reduction effect
public struct BitReductionConfig: Codable {
    /// Bit depth (1-16 bits)
    public var bitDepth: Float = 16.0
    
    /// Effect bypass
    public var bypass: Bool = false
    
    /// Dry/wet mix (0.0 = dry, 1.0 = wet)
    public var mix: Float = 1.0
    
    /// Dithering enabled
    public var dithering: Bool = false
    
    /// Quantization noise shaping
    public var noiseShaping: Bool = false
    
    public init() {}
    
    /// Validate and clamp parameters
    public mutating func validate() {
        bitDepth = max(1.0, min(16.0, bitDepth))
        mix = max(0.0, min(1.0, mix))
    }
}

// MARK: - Sample Rate Reduction Configuration

/// Configuration for sample rate reduction effect
public struct SampleRateReductionConfig: Codable {
    /// Downsampling factor (1-64)
    public var downsampleFactor: Int = 1
    
    /// Effect bypass
    public var bypass: Bool = false
    
    /// Dry/wet mix (0.0 = dry, 1.0 = wet)
    public var mix: Float = 1.0
    
    /// Anti-aliasing filter enabled
    public var antiAliasing: Bool = false
    
    /// Hold mode (sample and hold vs linear interpolation)
    public var holdMode: Bool = true
    
    public init() {}
    
    /// Validate and clamp parameters
    public mutating func validate() {
        downsampleFactor = max(1, min(64, downsampleFactor))
        mix = max(0.0, min(1.0, mix))
    }
}

// MARK: - Overdrive Configuration

/// Configuration for overdrive effect
public struct OverdriveConfig: Codable {
    /// Drive amount (0.0-1.0)
    public var drive: Float = 0.0
    
    /// Tone control (-1.0 to 1.0, negative = darker, positive = brighter)
    public var tone: Float = 0.0
    
    /// Effect bypass
    public var bypass: Bool = false
    
    /// Dry/wet mix (0.0 = dry, 1.0 = wet)
    public var mix: Float = 1.0
    
    /// Overdrive type
    public var overdriveType: OverdriveType = .analog
    
    /// Output level compensation
    public var outputLevel: Float = 1.0
    
    public init() {}
    
    /// Validate and clamp parameters
    public mutating func validate() {
        drive = max(0.0, min(1.0, drive))
        tone = max(-1.0, min(1.0, tone))
        mix = max(0.0, min(1.0, mix))
        outputLevel = max(0.1, min(2.0, outputLevel))
    }
}

/// Overdrive algorithm types
public enum OverdriveType: String, CaseIterable, Codable {
    case analog = "analog"
    case tube = "tube"
    case transistor = "transistor"
    case digital = "digital"
    case fuzz = "fuzz"
    
    public var displayName: String {
        switch self {
        case .analog: return "Analog"
        case .tube: return "Tube"
        case .transistor: return "Transistor"
        case .digital: return "Digital"
        case .fuzz: return "Fuzz"
        }
    }
}

// MARK: - Bit Reduction Processor

/// High-quality bit reduction processor with dithering and noise shaping
public final class BitReductionProcessor: @unchecked Sendable {
    
    public var config: BitReductionConfig {
        didSet {
            config.validate()
            updateInternalState()
        }
    }
    
    // MARK: - State
    
    private let sampleRate: Double
    private var ditherState: Float = 0.0
    private var noiseShapingBuffer: [Float] = []
    private let noiseShapingOrder = 3
    
    // MARK: - Initialization
    
    public init(config: BitReductionConfig = BitReductionConfig(), sampleRate: Double = 44100.0) {
        self.config = config
        self.sampleRate = sampleRate
        self.noiseShapingBuffer = Array(repeating: 0.0, count: noiseShapingOrder)
        updateInternalState()
    }
    
    // MARK: - Processing
    
    /// Process a single sample
    public func processSample(_ input: Float) -> Float {
        guard !config.bypass else { return input }
        
        let processed = applyBitReduction(input)
        return mix(dry: input, wet: processed, amount: config.mix)
    }
    
    /// Process a buffer of samples
    public func processBuffer(input: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard !config.bypass else {
            cblas_scopy(Int32(frameCount), input, 1, output, 1)
            return
        }
        
        for i in 0..<frameCount {
            let processed = applyBitReduction(input[i])
            output[i] = mix(dry: input[i], wet: processed, amount: config.mix)
        }
    }
    
    // MARK: - Private Implementation
    
    private func updateInternalState() {
        // Reset noise shaping buffer when parameters change
        noiseShapingBuffer = Array(repeating: 0.0, count: noiseShapingOrder)
    }
    
    private func applyBitReduction(_ input: Float) -> Float {
        let levels = pow(2.0, config.bitDepth)
        let scale = levels - 1.0
        
        var signal = input
        
        // Apply dithering if enabled
        if config.dithering {
            let ditherAmount = 1.0 / levels
            let dither = Float.random(in: -ditherAmount...ditherAmount)
            signal += dither
        }
        
        // Quantize
        var quantized = round(signal * scale) / scale
        
        // Apply noise shaping if enabled
        if config.noiseShaping {
            let quantizationError = signal - quantized
            
            // Simple 3rd order noise shaping filter
            var shapedError = quantizationError
            for i in 0..<noiseShapingOrder {
                shapedError += noiseShapingBuffer[i] * getNoiseShapingCoefficient(i)
            }
            
            // Update noise shaping buffer
            for i in (1..<noiseShapingOrder).reversed() {
                noiseShapingBuffer[i] = noiseShapingBuffer[i-1]
            }
            noiseShapingBuffer[0] = quantizationError
            
            // Apply shaped error
            quantized = signal - shapedError
            quantized = round(quantized * scale) / scale
        }
        
        return max(-1.0, min(1.0, quantized))
    }
    
    private func getNoiseShapingCoefficient(_ index: Int) -> Float {
        // Coefficients for 3rd order noise shaping
        switch index {
        case 0: return 2.033
        case 1: return -0.859
        case 2: return 0.083
        default: return 0.0
        }
    }
    
    private func mix(dry: Float, wet: Float, amount: Float) -> Float {
        return dry * (1.0 - amount) + wet * amount
    }
}

// MARK: - Sample Rate Reduction Processor

/// Sample rate reduction processor with anti-aliasing and hold modes
public final class SampleRateReductionProcessor: @unchecked Sendable {
    
    public var config: SampleRateReductionConfig {
        didSet {
            config.validate()
            updateInternalState()
        }
    }
    
    // MARK: - State
    
    private let sampleRate: Double
    private var sampleCounter: Int = 0
    private var holdValue: Float = 0.0
    private var previousValue: Float = 0.0
    private var antiAliasingFilter: SimpleFilter?
    
    // MARK: - Initialization
    
    public init(config: SampleRateReductionConfig = SampleRateReductionConfig(), sampleRate: Double = 44100.0) {
        self.config = config
        self.sampleRate = sampleRate
        updateInternalState()
    }
    
    // MARK: - Processing
    
    /// Process a single sample
    public func processSample(_ input: Float) -> Float {
        guard !config.bypass else { return input }
        
        let processed = applySampleRateReduction(input)
        return mix(dry: input, wet: processed, amount: config.mix)
    }
    
    /// Process a buffer of samples
    public func processBuffer(input: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard !config.bypass else {
            cblas_scopy(Int32(frameCount), input, 1, output, 1)
            return
        }
        
        for i in 0..<frameCount {
            let processed = applySampleRateReduction(input[i])
            output[i] = mix(dry: input[i], wet: processed, amount: config.mix)
        }
    }
    
    // MARK: - Private Implementation
    
    private func updateInternalState() {
        sampleCounter = 0
        
        // Setup anti-aliasing filter if enabled
        if config.antiAliasing {
            let cutoffFrequency = Float(sampleRate) / Float(config.downsampleFactor * 2)
            antiAliasingFilter = SimpleFilter(cutoff: cutoffFrequency, sampleRate: Float(sampleRate))
        } else {
            antiAliasingFilter = nil
        }
    }
    
    private func applySampleRateReduction(_ input: Float) -> Float {
        var signal = input
        
        // Apply anti-aliasing filter if enabled
        if let filter = antiAliasingFilter {
            signal = filter.process(signal)
        }
        
        // Sample rate reduction
        if sampleCounter % config.downsampleFactor == 0 {
            holdValue = signal
        }
        
        sampleCounter += 1
        
        // Return held value or interpolated value
        if config.holdMode {
            return holdValue
        } else {
            // Linear interpolation between samples
            let progress = Float(sampleCounter % config.downsampleFactor) / Float(config.downsampleFactor)
            return previousValue + (holdValue - previousValue) * progress
        }
    }
    
    private func mix(dry: Float, wet: Float, amount: Float) -> Float {
        return dry * (1.0 - amount) + wet * amount
    }
}

// MARK: - Simple Filter for Anti-Aliasing

/// Simple one-pole lowpass filter for anti-aliasing
private final class SimpleFilter {
    private var state: Float = 0.0
    private let coefficient: Float
    
    init(cutoff: Float, sampleRate: Float) {
        let omega = 2.0 * Float.pi * cutoff / sampleRate
        self.coefficient = 1.0 - exp(-omega)
    }
    
    func process(_ input: Float) -> Float {
        state += coefficient * (input - state)
        return state
    }
}

// MARK: - Overdrive Processor

/// Multi-algorithm overdrive processor with tone control
public final class OverdriveProcessor: @unchecked Sendable {
    
    public var config: OverdriveConfig {
        didSet {
            config.validate()
            updateToneFilter()
        }
    }
    
    // MARK: - State
    
    private let sampleRate: Double
    private var toneFilter: ToneControlFilter
    
    // MARK: - Initialization
    
    public init(config: OverdriveConfig = OverdriveConfig(), sampleRate: Double = 44100.0) {
        self.config = config
        self.sampleRate = sampleRate
        self.toneFilter = ToneControlFilter(sampleRate: sampleRate)
        updateToneFilter()
    }
    
    // MARK: - Processing
    
    /// Process a single sample
    public func processSample(_ input: Float) -> Float {
        guard !config.bypass else { return input }
        
        let processed = applyOverdrive(input)
        return mix(dry: input, wet: processed, amount: config.mix)
    }
    
    /// Process a buffer of samples
    public func processBuffer(input: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard !config.bypass else {
            cblas_scopy(Int32(frameCount), input, 1, output, 1)
            return
        }
        
        for i in 0..<frameCount {
            let processed = applyOverdrive(input[i])
            output[i] = mix(dry: input[i], wet: processed, amount: config.mix)
        }
    }
    
    // MARK: - Private Implementation
    
    private func updateToneFilter() {
        toneFilter.setTone(config.tone)
    }
    
    private func applyOverdrive(_ input: Float) -> Float {
        // Apply drive gain
        let driven = input * (1.0 + config.drive * 9.0)  // Up to 10x gain
        
        // Apply overdrive algorithm
        var overdriven: Float
        switch config.overdriveType {
        case .analog:
            overdriven = analogOverdrive(driven)
        case .tube:
            overdriven = tubeOverdrive(driven)
        case .transistor:
            overdriven = transistorOverdrive(driven)
        case .digital:
            overdriven = digitalOverdrive(driven)
        case .fuzz:
            overdriven = fuzzOverdrive(driven)
        }
        
        // Apply tone control
        overdriven = toneFilter.process(overdriven)
        
        // Apply output level compensation
        overdriven *= config.outputLevel
        
        return max(-1.0, min(1.0, overdriven))
    }
    
    // MARK: - Overdrive Algorithms
    
    private func analogOverdrive(_ input: Float) -> Float {
        // Smooth analog-style overdrive using tanh
        return tanh(input * 0.7) * 1.2
    }
    
    private func tubeOverdrive(_ input: Float) -> Float {
        // Tube-style asymmetric overdrive
        let x = input * 0.6
        if x >= 0.0 {
            return x / (1.0 + x * 0.8)  // Soft compression for positive
        } else {
            return x / (1.0 - x * 0.6)  // Harder compression for negative
        }
    }
    
    private func transistorOverdrive(_ input: Float) -> Float {
        // Transistor-style hard clipping with soft knee
        let threshold = 0.7
        let x = input * 0.8
        
        if abs(x) < threshold {
            return x
        } else {
            let sign = x >= 0.0 ? 1.0 : -1.0
            let excess = abs(x) - threshold
            let compressed = threshold + excess / (1.0 + excess * 3.0)
            return sign * compressed
        }
    }
    
    private func digitalOverdrive(_ input: Float) -> Float {
        // Digital-style hard clipping
        let gain = 1.0 + config.drive * 2.0
        let clipped = max(-0.8, min(0.8, input * gain))
        return clipped
    }
    
    private func fuzzOverdrive(_ input: Float) -> Float {
        // Fuzz-style square wave clipping
        let gain = 1.0 + config.drive * 4.0
        let driven = input * gain
        
        if driven > 0.3 {
            return 0.8
        } else if driven < -0.3 {
            return -0.8
        } else {
            return driven * 2.0
        }
    }
    
    private func mix(dry: Float, wet: Float, amount: Float) -> Float {
        return dry * (1.0 - amount) + wet * amount
    }
}

// MARK: - Tone Control Filter

/// Tone control filter for overdrive effect
private final class ToneControlFilter {
    private var lowShelf: BiquadFilter
    private var highShelf: BiquadFilter
    
    init(sampleRate: Double) {
        self.lowShelf = BiquadFilter(sampleRate: sampleRate)
        self.highShelf = BiquadFilter(sampleRate: sampleRate)
        setTone(0.0)  // Neutral tone
    }
    
    func setTone(_ tone: Float) {
        // Tone control: negative = darker (boost low, cut high), positive = brighter (cut low, boost high)
        let lowGain = tone < 0 ? abs(tone) * 6.0 : -tone * 3.0  // dB
        let highGain = tone > 0 ? tone * 6.0 : -abs(tone) * 3.0  // dB
        
        lowShelf.setLowShelf(frequency: 200.0, gain: lowGain, q: 0.7)
        highShelf.setHighShelf(frequency: 3000.0, gain: highGain, q: 0.7)
    }
    
    func process(_ input: Float) -> Float {
        let lowFiltered = lowShelf.process(input)
        return highShelf.process(lowFiltered)
    }
}

// MARK: - Simple Biquad Filter

/// Simple biquad filter for tone control
private final class BiquadFilter {
    private var x1: Float = 0.0
    private var x2: Float = 0.0
    private var y1: Float = 0.0
    private var y2: Float = 0.0
    
    private var b0: Float = 1.0
    private var b1: Float = 0.0
    private var b2: Float = 0.0
    private var a1: Float = 0.0
    private var a2: Float = 0.0
    
    private let sampleRate: Double
    
    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }
    
    func setLowShelf(frequency: Float, gain: Float, q: Float) {
        let omega = 2.0 * Float.pi * frequency / Float(sampleRate)
        let A = pow(10.0, gain / 40.0)
        let S = 1.0
        let beta = sqrt(A) / q
        
        let cosOmega = cos(omega)
        let sinOmega = sin(omega)
        
        let b0_temp = A * ((A + 1) - (A - 1) * cosOmega + beta * sinOmega)
        let b1_temp = 2 * A * ((A - 1) - (A + 1) * cosOmega)
        let b2_temp = A * ((A + 1) - (A - 1) * cosOmega - beta * sinOmega)
        let a0_temp = (A + 1) + (A - 1) * cosOmega + beta * sinOmega
        let a1_temp = -2 * ((A - 1) + (A + 1) * cosOmega)
        let a2_temp = (A + 1) + (A - 1) * cosOmega - beta * sinOmega
        
        b0 = b0_temp / a0_temp
        b1 = b1_temp / a0_temp
        b2 = b2_temp / a0_temp
        a1 = a1_temp / a0_temp
        a2 = a2_temp / a0_temp
    }
    
    func setHighShelf(frequency: Float, gain: Float, q: Float) {
        let omega = 2.0 * Float.pi * frequency / Float(sampleRate)
        let A = pow(10.0, gain / 40.0)
        let S = 1.0
        let beta = sqrt(A) / q
        
        let cosOmega = cos(omega)
        let sinOmega = sin(omega)
        
        let b0_temp = A * ((A + 1) + (A - 1) * cosOmega + beta * sinOmega)
        let b1_temp = -2 * A * ((A - 1) + (A + 1) * cosOmega)
        let b2_temp = A * ((A + 1) + (A - 1) * cosOmega - beta * sinOmega)
        let a0_temp = (A + 1) - (A - 1) * cosOmega + beta * sinOmega
        let a1_temp = 2 * ((A - 1) - (A + 1) * cosOmega)
        let a2_temp = (A + 1) - (A - 1) * cosOmega - beta * sinOmega
        
        b0 = b0_temp / a0_temp
        b1 = b1_temp / a0_temp
        b2 = b2_temp / a0_temp
        a1 = a1_temp / a0_temp
        a2 = a2_temp / a0_temp
    }
    
    func process(_ input: Float) -> Float {
        let output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        
        x2 = x1
        x1 = input
        y2 = y1
        y1 = output
        
        return output
    }
}

// MARK: - Main Track FX Processor

/// Complete track FX processor with configurable effect chain
public final class TrackFXProcessor: @unchecked Sendable {
    
    // MARK: - Configuration
    
    public var config: TrackFXConfig {
        didSet {
            updateProcessors()
        }
    }
    
    // MARK: - Processors
    
    private let bitReductionProcessor: BitReductionProcessor
    private let sampleRateReductionProcessor: SampleRateReductionProcessor
    private let overdriveProcessor: OverdriveProcessor
    
    // MARK: - State
    
    private let sampleRate: Double
    private var isEnabled: Bool = true
    
    // MARK: - Initialization
    
    public init(config: TrackFXConfig = TrackFXConfig(), sampleRate: Double = 44100.0) {
        self.config = config
        self.sampleRate = sampleRate
        
        self.bitReductionProcessor = BitReductionProcessor(config: config.bitReduction, sampleRate: sampleRate)
        self.sampleRateReductionProcessor = SampleRateReductionProcessor(config: config.sampleRateReduction, sampleRate: sampleRate)
        self.overdriveProcessor = OverdriveProcessor(config: config.overdrive, sampleRate: sampleRate)
        
        updateProcessors()
    }
    
    // MARK: - Public Interface
    
    /// Process a single sample through the complete FX chain
    public func processSample(_ input: Float) -> Float {
        guard isEnabled && !config.globalBypass else { return input }
        
        var signal = input
        
        // Process through effects in configured order
        for effectType in config.processingOrder {
            switch effectType {
            case .bitReduction:
                signal = bitReductionProcessor.processSample(signal)
            case .sampleRateReduction:
                signal = sampleRateReductionProcessor.processSample(signal)
            case .overdrive:
                signal = overdriveProcessor.processSample(signal)
            }
        }
        
        return signal
    }
    
    /// Process a buffer of samples through the complete FX chain
    public func processBuffer(input: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard isEnabled && !config.globalBypass else {
            cblas_scopy(Int32(frameCount), input, 1, output, 1)
            return
        }
        
        // Use temporary buffers for multi-stage processing
        var tempBuffer1 = [Float](repeating: 0.0, count: frameCount)
        var tempBuffer2 = [Float](repeating: 0.0, count: frameCount)
        
        var currentInput = input
        var currentOutput = UnsafeMutablePointer<Float>(mutating: tempBuffer1)
        
        // Process through effects in configured order
        for (index, effectType) in config.processingOrder.enumerated() {
            let isLastEffect = index == config.processingOrder.count - 1
            let finalOutput = isLastEffect ? output : (index % 2 == 0 ? UnsafeMutablePointer<Float>(mutating: tempBuffer2) : UnsafeMutablePointer<Float>(mutating: tempBuffer1))
            
            switch effectType {
            case .bitReduction:
                bitReductionProcessor.processBuffer(input: currentInput, output: finalOutput, frameCount: frameCount)
            case .sampleRateReduction:
                sampleRateReductionProcessor.processBuffer(input: currentInput, output: finalOutput, frameCount: frameCount)
            case .overdrive:
                overdriveProcessor.processBuffer(input: currentInput, output: finalOutput, frameCount: frameCount)
            }
            
            // Setup for next iteration
            if !isLastEffect {
                currentInput = UnsafePointer<Float>(finalOutput)
                currentOutput = index % 2 == 0 ? UnsafeMutablePointer<Float>(mutating: tempBuffer1) : UnsafeMutablePointer<Float>(mutating: tempBuffer2)
            }
        }
    }
    
    /// Enable/disable the entire FX processor
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    /// Get current enabled state
    public var enabled: Bool {
        return isEnabled
    }
    
    // MARK: - Individual Effect Control
    
    /// Update bit reduction settings
    public func setBitReduction(_ config: BitReductionConfig) {
        self.config.bitReduction = config
        bitReductionProcessor.config = config
    }
    
    /// Update sample rate reduction settings
    public func setSampleRateReduction(_ config: SampleRateReductionConfig) {
        self.config.sampleRateReduction = config
        sampleRateReductionProcessor.config = config
    }
    
    /// Update overdrive settings
    public func setOverdrive(_ config: OverdriveConfig) {
        self.config.overdrive = config
        overdriveProcessor.config = config
    }
    
    /// Set processing order for effects
    public func setProcessingOrder(_ order: [TrackFXType]) {
        config.processingOrder = order
    }
    
    // MARK: - Private Implementation
    
    private func updateProcessors() {
        bitReductionProcessor.config = config.bitReduction
        sampleRateReductionProcessor.config = config.sampleRateReduction
        overdriveProcessor.config = config.overdrive
    }
}

// MARK: - FXMachine Protocol Conformance

extension TrackFXProcessor: FXMachine {
    
    public var machineType: String {
        return "TrackFX"
    }
    
    public var parameterCount: Int {
        return 8  // Bit depth, SR factor, Overdrive drive, tone, and bypass controls
    }
    
    public func getParameterName(index: Int) -> String {
        switch index {
        case 0: return "BIT_DEPTH"
        case 1: return "BIT_BYPASS"
        case 2: return "SR_FACTOR"
        case 3: return "SR_BYPASS"
        case 4: return "OD_DRIVE"
        case 5: return "OD_TONE"
        case 6: return "OD_BYPASS"
        case 7: return "GLOBAL_BYPASS"
        default: return "UNKNOWN"
        }
    }
    
    public func getParameterValue(index: Int) -> Float {
        switch index {
        case 0: return config.bitReduction.bitDepth
        case 1: return config.bitReduction.bypass ? 1.0 : 0.0
        case 2: return Float(config.sampleRateReduction.downsampleFactor)
        case 3: return config.sampleRateReduction.bypass ? 1.0 : 0.0
        case 4: return config.overdrive.drive
        case 5: return config.overdrive.tone
        case 6: return config.overdrive.bypass ? 1.0 : 0.0
        case 7: return config.globalBypass ? 1.0 : 0.0
        default: return 0.0
        }
    }
    
    public func setParameterValue(index: Int, value: Float) {
        switch index {
        case 0:
            config.bitReduction.bitDepth = value
            bitReductionProcessor.config = config.bitReduction
        case 1:
            config.bitReduction.bypass = value > 0.5
            bitReductionProcessor.config = config.bitReduction
        case 2:
            config.sampleRateReduction.downsampleFactor = Int(value)
            sampleRateReductionProcessor.config = config.sampleRateReduction
        case 3:
            config.sampleRateReduction.bypass = value > 0.5
            sampleRateReductionProcessor.config = config.sampleRateReduction
        case 4:
            config.overdrive.drive = value
            overdriveProcessor.config = config.overdrive
        case 5:
            config.overdrive.tone = value
            overdriveProcessor.config = config.overdrive
        case 6:
            config.overdrive.bypass = value > 0.5
            overdriveProcessor.config = config.overdrive
        case 7:
            config.globalBypass = value > 0.5
        default:
            break
        }
    }
    
    public func getParameterDisplayValue(index: Int) -> String {
        switch index {
        case 0: return String(format: "%.0f bits", config.bitReduction.bitDepth)
        case 1: return config.bitReduction.bypass ? "BYPASS" : "ON"
        case 2: return String(format: "1/%d", config.sampleRateReduction.downsampleFactor)
        case 3: return config.sampleRateReduction.bypass ? "BYPASS" : "ON"
        case 4: return String(format: "%.1f%%", config.overdrive.drive * 100.0)
        case 5: return String(format: "%.1f", config.overdrive.tone)
        case 6: return config.overdrive.bypass ? "BYPASS" : "ON"
        case 7: return config.globalBypass ? "BYPASS" : "ON"
        default: return ""
        }
    }
}