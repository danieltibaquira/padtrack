// TrackFXImplementation.swift
// DigitonePad - FXModule
//
// Comprehensive track effects implementation with bit reduction, sample rate reduction, and overdrive
// Provides per-track effects processing with presets and real-time control

import Foundation
import Accelerate
import MachineProtocols
import AudioEngine

// MARK: - Track FX Configuration

/// Configuration for track effects
public struct TrackFXConfig: Codable {
    /// Bit reduction settings
    public var bitReduction: BitReductionConfig = BitReductionConfig()
    
    /// Sample rate reduction settings
    public var sampleRateReduction: SampleRateReductionConfig = SampleRateReductionConfig()
    
    /// Overdrive settings
    public var overdrive: OverdriveConfig = OverdriveConfig()
    
    /// Effect order
    public var effectOrder: [TrackFXType] = [.bitReduction, .sampleRateReduction, .overdrive]
    
    /// Global track settings
    public var inputGain: Float = 0.0      // dB
    public var outputGain: Float = 0.0     // dB
    public var wetLevel: Float = 1.0       // 0.0 to 1.0
    public var dryLevel: Float = 0.0       // 0.0 to 1.0
    
    public init() {}
}

/// Individual effect configurations
public struct BitReductionConfig: Codable {
    public var enabled: Bool = false
    public var bitDepth: Float = 16.0      // 1-16 bits
    public var ditherAmount: Float = 0.0   // 0.0-1.0
    public var ditherType: DitherType = .none
    public var wetLevel: Float = 1.0
    
    public init() {}
}

public struct SampleRateReductionConfig: Codable {
    public var enabled: Bool = false
    public var targetSampleRate: Float = 44100.0  // 100-48000 Hz
    public var antiAliasing: Bool = true
    public var filterCutoff: Float = 0.45          // 0.1-0.5
    public var wetLevel: Float = 1.0
    
    public init() {}
}

public struct OverdriveConfig: Codable {
    public var enabled: Bool = false
    public var driveAmount: Float = 1.0     // 0.0-10.0
    public var clippingCurve: ClippingCurve = .soft
    public var tone: Float = 0.5            // 0.0-1.0
    public var asymmetry: Float = 0.0       // -1.0 to 1.0
    public var wetLevel: Float = 1.0
    
    public init() {}
}

/// Track effect types
public enum TrackFXType: String, CaseIterable, Codable {
    case bitReduction = "bit_reduction"
    case sampleRateReduction = "sample_rate_reduction"
    case overdrive = "overdrive"
    
    public var description: String {
        switch self {
        case .bitReduction: return "Bit Reduction"
        case .sampleRateReduction: return "Sample Rate Reduction"
        case .overdrive: return "Overdrive"
        }
    }
}

/// Dither types for bit reduction
public enum DitherType: String, CaseIterable, Codable {
    case none = "none"
    case triangular = "triangular"
    case rectangular = "rectangular"
    
    public var description: String {
        switch self {
        case .none: return "None"
        case .triangular: return "Triangular"
        case .rectangular: return "Rectangular"
        }
    }
}

/// Clipping curves for overdrive
public enum ClippingCurve: String, CaseIterable, Codable {
    case soft = "soft"
    case hard = "hard"
    case tube = "tube"
    case asymmetric = "asymmetric"
    
    public var description: String {
        switch self {
        case .soft: return "Soft"
        case .hard: return "Hard"
        case .tube: return "Tube"
        case .asymmetric: return "Asymmetric"
        }
    }
}

// MARK: - Track FX Processor

/// Comprehensive track effects processor
public final class TrackFXProcessor: @unchecked Sendable {
    
    // MARK: - Configuration
    
    public var config: TrackFXConfig {
        didSet {
            updateEffectChain()
        }
    }
    
    /// Track identifier
    public let trackId: Int
    
    /// Whether the entire track FX is bypassed
    public var isBypassed: Bool = false
    
    /// Whether the track is muted
    public var isMuted: Bool = false
    
    // MARK: - Internal Components
    
    private var bitReductionProcessor: BitReductionProcessor
    private var sampleRateReductionProcessor: SampleRateReductionProcessor
    private var overdriveProcessor: OverdriveProcessor
    
    // MARK: - Audio Processing State
    
    private let sampleRate: Double
    private var inputPeak: Float = 0.0
    private var outputPeak: Float = 0.0
    
    // MARK: - Performance Optimization
    
    private var processBuffer: [Float] = []
    private var tempBuffer: [Float] = []
    
    // MARK: - Initialization
    
    public init(trackId: Int, config: TrackFXConfig = TrackFXConfig(), sampleRate: Double = 44100.0) {
        self.trackId = trackId
        self.config = config
        self.sampleRate = sampleRate
        
        // Initialize effect processors
        self.bitReductionProcessor = BitReductionProcessor(sampleRate: sampleRate)
        self.sampleRateReductionProcessor = SampleRateReductionProcessor(sampleRate: sampleRate)
        self.overdriveProcessor = OverdriveProcessor(sampleRate: sampleRate)
        
        updateEffectChain()
    }
    
    // MARK: - Audio Processing
    
    /// Process audio through track effects
    public func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        guard !isBypassed else { return input }
        
        if isMuted {
            // Return silence
            let silentData = UnsafeMutablePointer<Float>.allocate(capacity: input.frameCount * input.channelCount)
            silentData.initialize(repeating: 0.0, count: input.frameCount * input.channelCount)
            
            return MachineProtocols.AudioBuffer(
                data: silentData,
                frameCount: input.frameCount,
                channelCount: input.channelCount,
                sampleRate: input.sampleRate
            )
        }
        
        // Ensure buffers are large enough
        let totalSamples = input.frameCount * input.channelCount
        if processBuffer.count < totalSamples {
            processBuffer = [Float](repeating: 0.0, count: totalSamples)
            tempBuffer = [Float](repeating: 0.0, count: totalSamples)
        }
        
        // Copy input to process buffer
        for i in 0..<totalSamples {
            processBuffer[i] = input.data[i]
        }
        
        // Store original for wet/dry mixing
        for i in 0..<totalSamples {
            tempBuffer[i] = processBuffer[i]
        }
        
        // Apply input gain
        if config.inputGain != 0.0 {
            let inputGainLinear = pow(10.0, config.inputGain / 20.0)
            vDSP_vsmul(processBuffer, 1, [inputGainLinear], processBuffer, 1, vDSP_Length(totalSamples))
        }
        
        // Update input peak
        var peak: Float = 0.0
        vDSP_maxmgv(processBuffer, 1, &peak, vDSP_Length(totalSamples))
        inputPeak = peak
        
        // Process through effects in configured order
        for effectType in config.effectOrder {
            switch effectType {
            case .bitReduction:
                if config.bitReduction.enabled {
                    processBitReduction(&processBuffer, frameCount: input.frameCount, channelCount: input.channelCount)
                }
                
            case .sampleRateReduction:
                if config.sampleRateReduction.enabled {
                    processSampleRateReduction(&processBuffer, frameCount: input.frameCount, channelCount: input.channelCount)
                }
                
            case .overdrive:
                if config.overdrive.enabled {
                    processOverdrive(&processBuffer, frameCount: input.frameCount, channelCount: input.channelCount)
                }
            }
        }
        
        // Apply wet/dry mix
        if config.wetLevel != 1.0 || config.dryLevel != 0.0 {
            // Scale wet signal
            vDSP_vsmul(processBuffer, 1, [config.wetLevel], processBuffer, 1, vDSP_Length(totalSamples))
            
            // Scale and add dry signal
            vDSP_vsmul(tempBuffer, 1, [config.dryLevel], tempBuffer, 1, vDSP_Length(totalSamples))
            vDSP_vadd(processBuffer, 1, tempBuffer, 1, processBuffer, 1, vDSP_Length(totalSamples))
        }
        
        // Apply output gain
        if config.outputGain != 0.0 {
            let outputGainLinear = pow(10.0, config.outputGain / 20.0)
            vDSP_vsmul(processBuffer, 1, [outputGainLinear], processBuffer, 1, vDSP_Length(totalSamples))
        }
        
        // Update output peak
        vDSP_maxmgv(processBuffer, 1, &peak, vDSP_Length(totalSamples))
        outputPeak = peak
        
        // Create output buffer
        let outputData = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)
        for i in 0..<totalSamples {
            outputData[i] = processBuffer[i]
        }
        
        return MachineProtocols.AudioBuffer(
            data: outputData,
            frameCount: input.frameCount,
            channelCount: input.channelCount,
            sampleRate: input.sampleRate
        )
    }
    
    // MARK: - Individual Effect Processing
    
    private func processBitReduction(_ buffer: inout [Float], frameCount: Int, channelCount: Int) {
        bitReductionProcessor.process(
            buffer: &buffer,
            frameCount: frameCount,
            channelCount: channelCount,
            config: config.bitReduction
        )
    }
    
    private func processSampleRateReduction(_ buffer: inout [Float], frameCount: Int, channelCount: Int) {
        sampleRateReductionProcessor.process(
            buffer: &buffer,
            frameCount: frameCount,
            channelCount: channelCount,
            config: config.sampleRateReduction
        )
    }
    
    private func processOverdrive(_ buffer: inout [Float], frameCount: Int, channelCount: Int) {
        overdriveProcessor.process(
            buffer: &buffer,
            frameCount: frameCount,
            channelCount: channelCount,
            config: config.overdrive
        )
    }
    
    // MARK: - Control Methods
    
    /// Reset all effect states
    public func reset() {
        bitReductionProcessor.reset()
        sampleRateReductionProcessor.reset()
        overdriveProcessor.reset()
        inputPeak = 0.0
        outputPeak = 0.0
    }
    
    /// Get current peak levels
    public func getPeakLevels() -> (input: Float, output: Float) {
        return (inputPeak, outputPeak)
    }
    
    /// Enable/disable specific effect
    public func setEffectEnabled(_ effectType: TrackFXType, enabled: Bool) {
        switch effectType {
        case .bitReduction:
            config.bitReduction.enabled = enabled
        case .sampleRateReduction:
            config.sampleRateReduction.enabled = enabled
        case .overdrive:
            config.overdrive.enabled = enabled
        }
    }
    
    /// Check if specific effect is enabled
    public func isEffectEnabled(_ effectType: TrackFXType) -> Bool {
        switch effectType {
        case .bitReduction:
            return config.bitReduction.enabled
        case .sampleRateReduction:
            return config.sampleRateReduction.enabled
        case .overdrive:
            return config.overdrive.enabled
        }
    }
    
    // MARK: - Private Methods
    
    private func updateEffectChain() {
        // Update individual processors with new configuration
        bitReductionProcessor.updateConfig(config.bitReduction)
        sampleRateReductionProcessor.updateConfig(config.sampleRateReduction)
        overdriveProcessor.updateConfig(config.overdrive)
    }
}

// MARK: - Bit Reduction Processor

/// Optimized bit reduction processor
private final class BitReductionProcessor: @unchecked Sendable {

    private let sampleRate: Double
    private var quantizationStep: Float = 1.0
    private var ditherState: Float = 0.0

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func updateConfig(_ config: BitReductionConfig) {
        // Calculate quantization step
        let maxValue = pow(2.0, config.bitDepth - 1.0)
        quantizationStep = 2.0 / maxValue
    }

    func process(buffer: inout [Float], frameCount: Int, channelCount: Int, config: BitReductionConfig) {
        guard config.enabled else { return }

        let totalSamples = frameCount * channelCount

        for i in 0..<totalSamples {
            var sample = buffer[i]

            // Apply dithering if enabled
            if config.ditherAmount > 0.0 {
                let dither = generateDither(type: config.ditherType) * config.ditherAmount
                sample += dither * quantizationStep * 0.5
            }

            // Quantize
            sample = round(sample / quantizationStep) * quantizationStep

            // Clamp to prevent overflow
            sample = max(-1.0, min(1.0, sample))

            // Apply wet level
            buffer[i] = sample * config.wetLevel + buffer[i] * (1.0 - config.wetLevel)
        }
    }

    func reset() {
        ditherState = 0.0
    }

    private func generateDither(type: DitherType) -> Float {
        switch type {
        case .none:
            return 0.0

        case .triangular:
            // Triangular dither (two uniform random numbers)
            let r1 = Float.random(in: -1.0...1.0)
            let r2 = Float.random(in: -1.0...1.0)
            return r1 + r2

        case .rectangular:
            // Rectangular (uniform) dither
            return Float.random(in: -1.0...1.0)
        }
    }
}

// MARK: - Sample Rate Reduction Processor

/// Optimized sample rate reduction processor
private final class SampleRateReductionProcessor: @unchecked Sendable {

    private let sampleRate: Double
    private var downsampleCounter: Float = 0.0
    private var downsampleRatio: Float = 1.0
    private var lastSample: Float = 0.0

    // Anti-aliasing filter state
    private var filterState1: Float = 0.0
    private var filterState2: Float = 0.0
    private var filterCoeff: Float = 0.5

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func updateConfig(_ config: SampleRateReductionConfig) {
        downsampleRatio = Float(sampleRate) / config.targetSampleRate

        // Update anti-aliasing filter coefficient
        let cutoffFreq = config.targetSampleRate * config.filterCutoff
        let omega = 2.0 * Float.pi * cutoffFreq / Float(sampleRate)
        filterCoeff = tan(omega * 0.5)
    }

    func process(buffer: inout [Float], frameCount: Int, channelCount: Int, config: SampleRateReductionConfig) {
        guard config.enabled else { return }

        let totalSamples = frameCount * channelCount

        for i in 0..<totalSamples {
            var sample = buffer[i]

            // Apply anti-aliasing filter if enabled
            if config.antiAliasing {
                sample = applyAntiAliasingFilter(sample)
            }

            // Sample and hold downsampling
            downsampleCounter += 1.0
            if downsampleCounter >= downsampleRatio {
                downsampleCounter = 0.0
                lastSample = sample
            }

            // Apply wet level
            buffer[i] = lastSample * config.wetLevel + buffer[i] * (1.0 - config.wetLevel)
        }
    }

    func reset() {
        downsampleCounter = 0.0
        lastSample = 0.0
        filterState1 = 0.0
        filterState2 = 0.0
    }

    private func applyAntiAliasingFilter(_ input: Float) -> Float {
        // Simple 2-pole Butterworth lowpass filter
        let k = filterCoeff
        let a = 1.0 / (1.0 + k * (k + 1.414))

        let output = a * (input + 2.0 * filterState1 + filterState2)
        filterState2 = filterState1
        filterState1 = input

        return output
    }
}

// MARK: - Overdrive Processor

/// Optimized overdrive processor
private final class OverdriveProcessor: @unchecked Sendable {

    private let sampleRate: Double

    // Tone filter state
    private var toneFilterState: Float = 0.0
    private var toneFilterCoeff: Float = 0.5

    // DC blocker state
    private var dcBlockerX1: Float = 0.0
    private var dcBlockerY1: Float = 0.0

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func updateConfig(_ config: OverdriveConfig) {
        // Update tone filter coefficient
        toneFilterCoeff = 0.1 + config.tone * 0.8
    }

    func process(buffer: inout [Float], frameCount: Int, channelCount: Int, config: OverdriveConfig) {
        guard config.enabled else { return }

        let totalSamples = frameCount * channelCount

        for i in 0..<totalSamples {
            var sample = buffer[i]

            // Apply drive
            sample *= config.driveAmount

            // Apply clipping curve
            sample = applyClippingCurve(sample, curve: config.clippingCurve, asymmetry: config.asymmetry)

            // Apply tone filter
            sample = applyToneFilter(sample)

            // Apply DC blocker
            sample = applyDCBlocker(sample)

            // Apply wet level
            buffer[i] = sample * config.wetLevel + buffer[i] * (1.0 - config.wetLevel)
        }
    }

    func reset() {
        toneFilterState = 0.0
        dcBlockerX1 = 0.0
        dcBlockerY1 = 0.0
    }

    private func applyClippingCurve(_ sample: Float, curve: ClippingCurve, asymmetry: Float) -> Float {
        // Apply asymmetry
        let asymmetricSample = sample + asymmetry * 0.1

        switch curve {
        case .soft:
            return tanh(asymmetricSample)

        case .hard:
            return max(-1.0, min(1.0, asymmetricSample))

        case .tube:
            if asymmetricSample >= 0.0 {
                return tanh(asymmetricSample * 0.7)
            } else {
                return tanh(asymmetricSample * 1.2)
            }

        case .asymmetric:
            if asymmetricSample >= 0.0 {
                return asymmetricSample / (1.0 + asymmetricSample)
            } else {
                return asymmetricSample / (1.0 - asymmetricSample * 0.5)
            }
        }
    }

    private func applyToneFilter(_ input: Float) -> Float {
        // Simple one-pole lowpass filter for tone control
        toneFilterState += toneFilterCoeff * (input - toneFilterState)
        return toneFilterState
    }

    private func applyDCBlocker(_ input: Float) -> Float {
        // High-pass filter to remove DC offset
        let output = input - dcBlockerX1 + 0.995 * dcBlockerY1
        dcBlockerX1 = input
        dcBlockerY1 = output
        return output
    }
}

// MARK: - Track FX Presets

/// Preset types for track effects
public enum TrackFXPresetType: String, CaseIterable, Codable {
    case clean = "clean"
    case lofi = "lofi"
    case vintage = "vintage"
    case aggressive = "aggressive"
    case telephone = "telephone"
    case radio = "radio"
    case crushed = "crushed"
    case warm = "warm"
    case digital = "digital"

    public var description: String {
        switch self {
        case .clean: return "Clean"
        case .lofi: return "Lo-Fi"
        case .vintage: return "Vintage"
        case .aggressive: return "Aggressive"
        case .telephone: return "Telephone"
        case .radio: return "Radio"
        case .crushed: return "Crushed"
        case .warm: return "Warm"
        case .digital: return "Digital"
        }
    }
}

// MARK: - Track FX Factory

/// Factory for creating track FX configurations
public extension TrackFXProcessor {

    /// Create a track FX processor with a preset configuration
    static func createWithPreset(_ preset: TrackFXPresetType, trackId: Int, sampleRate: Double = 44100.0) -> TrackFXProcessor {
        let config = createPresetConfig(preset)
        return TrackFXProcessor(trackId: trackId, config: config, sampleRate: sampleRate)
    }

    /// Create a preset configuration
    static func createPresetConfig(_ preset: TrackFXPresetType) -> TrackFXConfig {
        var config = TrackFXConfig()

        switch preset {
        case .clean:
            // No effects enabled - clean signal
            config.bitReduction.enabled = false
            config.sampleRateReduction.enabled = false
            config.overdrive.enabled = false

        case .lofi:
            // Classic lo-fi sound
            config.bitReduction.enabled = true
            config.bitReduction.bitDepth = 8.0
            config.bitReduction.ditherAmount = 0.0
            config.bitReduction.wetLevel = 1.0

            config.sampleRateReduction.enabled = true
            config.sampleRateReduction.targetSampleRate = 11025.0
            config.sampleRateReduction.antiAliasing = false
            config.sampleRateReduction.wetLevel = 1.0

            config.overdrive.enabled = true
            config.overdrive.driveAmount = 1.5
            config.overdrive.clippingCurve = .soft
            config.overdrive.tone = 0.3
            config.overdrive.wetLevel = 0.7

        case .vintage:
            // Warm vintage character
            config.bitReduction.enabled = true
            config.bitReduction.bitDepth = 12.0
            config.bitReduction.ditherAmount = 0.3
            config.bitReduction.ditherType = .triangular
            config.bitReduction.wetLevel = 0.8

            config.overdrive.enabled = true
            config.overdrive.driveAmount = 2.0
            config.overdrive.clippingCurve = .tube
            config.overdrive.tone = 0.6
            config.overdrive.asymmetry = 0.1
            config.overdrive.wetLevel = 0.8

        case .aggressive:
            // Aggressive digital distortion
            config.bitReduction.enabled = true
            config.bitReduction.bitDepth = 6.0
            config.bitReduction.ditherAmount = 0.0
            config.bitReduction.wetLevel = 1.0

            config.overdrive.enabled = true
            config.overdrive.driveAmount = 5.0
            config.overdrive.clippingCurve = .hard
            config.overdrive.tone = 0.8
            config.overdrive.wetLevel = 1.0

        case .telephone:
            // Telephone/AM radio sound
            config.sampleRateReduction.enabled = true
            config.sampleRateReduction.targetSampleRate = 8000.0
            config.sampleRateReduction.antiAliasing = true
            config.sampleRateReduction.filterCutoff = 0.4
            config.sampleRateReduction.wetLevel = 1.0

            config.bitReduction.enabled = true
            config.bitReduction.bitDepth = 8.0
            config.bitReduction.ditherAmount = 0.1
            config.bitReduction.wetLevel = 1.0

            config.overdrive.enabled = true
            config.overdrive.driveAmount = 1.2
            config.overdrive.clippingCurve = .soft
            config.overdrive.tone = 0.2
            config.overdrive.wetLevel = 0.6

        case .radio:
            // FM radio quality
            config.sampleRateReduction.enabled = true
            config.sampleRateReduction.targetSampleRate = 22050.0
            config.sampleRateReduction.antiAliasing = true
            config.sampleRateReduction.filterCutoff = 0.45
            config.sampleRateReduction.wetLevel = 0.8

            config.bitReduction.enabled = true
            config.bitReduction.bitDepth = 10.0
            config.bitReduction.ditherAmount = 0.2
            config.bitReduction.wetLevel = 0.7

        case .crushed:
            // Heavily crushed/destroyed sound
            config.bitReduction.enabled = true
            config.bitReduction.bitDepth = 3.0
            config.bitReduction.ditherAmount = 0.0
            config.bitReduction.wetLevel = 1.0

            config.sampleRateReduction.enabled = true
            config.sampleRateReduction.targetSampleRate = 4000.0
            config.sampleRateReduction.antiAliasing = false
            config.sampleRateReduction.wetLevel = 1.0

            config.overdrive.enabled = true
            config.overdrive.driveAmount = 8.0
            config.overdrive.clippingCurve = .hard
            config.overdrive.tone = 0.9
            config.overdrive.wetLevel = 1.0

        case .warm:
            // Warm analog-style processing
            config.overdrive.enabled = true
            config.overdrive.driveAmount = 1.8
            config.overdrive.clippingCurve = .tube
            config.overdrive.tone = 0.5
            config.overdrive.asymmetry = 0.15
            config.overdrive.wetLevel = 0.6

            config.bitReduction.enabled = true
            config.bitReduction.bitDepth = 14.0
            config.bitReduction.ditherAmount = 0.4
            config.bitReduction.ditherType = .triangular
            config.bitReduction.wetLevel = 0.5

        case .digital:
            // Clean digital processing
            config.bitReduction.enabled = true
            config.bitReduction.bitDepth = 4.0
            config.bitReduction.ditherAmount = 0.0
            config.bitReduction.wetLevel = 1.0

            config.overdrive.enabled = true
            config.overdrive.driveAmount = 3.0
            config.overdrive.clippingCurve = .hard
            config.overdrive.tone = 1.0
            config.overdrive.wetLevel = 0.8
        }

        return config
    }

    /// Apply a preset to an existing processor
    func applyPreset(_ preset: TrackFXPresetType) {
        self.config = Self.createPresetConfig(preset)
    }

    /// Get available preset names
    static var availablePresets: [String] {
        return TrackFXPresetType.allCases.map { $0.description }
    }
}

// MARK: - Parameter Management

/// Parameter manager for track FX
public extension TrackFXProcessor {

    /// Create parameters for track FX
    func createParameters() -> [Parameter] {
        var parameters: [Parameter] = []

        // Global parameters
        parameters.append(Parameter(
            id: "track_fx_input_gain",
            name: "Input Gain",
            description: "Track input gain",
            unit: "dB",
            category: .gain,
            dataType: .float,
            scaling: .linear,
            minValue: -24.0,
            maxValue: 24.0,
            defaultValue: 0.0,
            isAutomatable: true
        ))

        parameters.append(Parameter(
            id: "track_fx_output_gain",
            name: "Output Gain",
            description: "Track output gain",
            unit: "dB",
            category: .gain,
            dataType: .float,
            scaling: .linear,
            minValue: -24.0,
            maxValue: 24.0,
            defaultValue: 0.0,
            isAutomatable: true
        ))

        parameters.append(Parameter(
            id: "track_fx_wet_level",
            name: "Wet Level",
            description: "Effects wet level",
            unit: "",
            category: .mix,
            dataType: .float,
            scaling: .linear,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 1.0,
            isAutomatable: true
        ))

        parameters.append(Parameter(
            id: "track_fx_dry_level",
            name: "Dry Level",
            description: "Effects dry level",
            unit: "",
            category: .mix,
            dataType: .float,
            scaling: .linear,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            isAutomatable: true
        ))

        // Bit reduction parameters
        parameters.append(contentsOf: createBitReductionParameters())

        // Sample rate reduction parameters
        parameters.append(contentsOf: createSampleRateReductionParameters())

        // Overdrive parameters
        parameters.append(contentsOf: createOverdriveParameters())

        return parameters
    }

    private func createBitReductionParameters() -> [Parameter] {
        return [
            Parameter(
                id: "bit_reduction_enabled",
                name: "Bit Reduction Enable",
                description: "Enable bit reduction effect",
                value: 0.0,
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 0.0,
                unit: "",
                category: .effects,
                dataType: .boolean,
                scaling: .linear,
                isAutomatable: true
            ),
            Parameter(
                id: "bit_reduction_depth",
                name: "Bit Depth",
                description: "Bit reduction depth",
                value: 16.0,
                minValue: 1.0,
                maxValue: 16.0,
                defaultValue: 16.0,
                unit: "bits",
                category: .effects,
                dataType: .float,
                scaling: .linear,
                isAutomatable: true
            ),
            Parameter(
                id: "bit_reduction_dither",
                name: "Dither Amount",
                description: "Dithering amount",
                value: 0.0,
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 0.0,
                unit: "",
                category: .effects,
                dataType: .float,
                scaling: .linear,
                isAutomatable: true
            )
        ]
    }

    private func createSampleRateReductionParameters() -> [Parameter] {
        return [
            Parameter(
                id: "sample_rate_reduction_enabled",
                name: "Sample Rate Reduction Enable",
                description: "Enable sample rate reduction effect",
                value: 0.0,
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 0.0,
                unit: "",
                category: .effects,
                dataType: .boolean,
                scaling: .linear,
                isAutomatable: true
            ),
            Parameter(
                id: "sample_rate_reduction_rate",
                name: "Target Sample Rate",
                description: "Target sample rate",
                value: 44100.0,
                minValue: 100.0,
                maxValue: 48000.0,
                defaultValue: 44100.0,
                unit: "Hz",
                category: .effects,
                dataType: .float,
                scaling: .logarithmic,
                isAutomatable: true
            ),
            Parameter(
                id: "sample_rate_reduction_antialiasing",
                name: "Anti-Aliasing",
                description: "Enable anti-aliasing filter",
                value: 1.0,
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 1.0,
                unit: "",
                category: .effects,
                dataType: .boolean,
                scaling: .linear,
                isAutomatable: true
            )
        ]
    }

    private func createOverdriveParameters() -> [Parameter] {
        return [
            Parameter(
                id: "overdrive_enabled",
                name: "Overdrive Enable",
                description: "Enable overdrive effect",
                value: 0.0,
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 0.0,
                unit: "",
                category: .effects,
                dataType: .boolean,
                scaling: .linear,
                isAutomatable: true
            ),
            Parameter(
                id: "overdrive_drive",
                name: "Drive Amount",
                description: "Overdrive drive amount",
                value: 1.0,
                minValue: 0.0,
                maxValue: 10.0,
                defaultValue: 1.0,
                unit: "",
                category: .effects,
                dataType: .float,
                scaling: .linear,
                isAutomatable: true
            ),
            Parameter(
                id: "overdrive_tone",
                name: "Tone",
                description: "Overdrive tone control",
                value: 0.5,
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 0.5,
                unit: "",
                category: .effects,
                dataType: .float,
                scaling: .linear,
                isAutomatable: true
            ),
            Parameter(
                id: "overdrive_asymmetry",
                name: "Asymmetry",
                description: "Overdrive asymmetry",
                value: 0.0,
                minValue: -1.0,
                maxValue: 1.0,
                defaultValue: 0.0,
                unit: "",
                category: .effects,
                dataType: .float,
                scaling: .linear,
                isAutomatable: true
            )
        ]
    }
}
