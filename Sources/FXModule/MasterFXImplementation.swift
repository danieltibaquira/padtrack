// MasterFXImplementation.swift
// DigitonePad - FXModule
//
// Enhanced master effects implementation with advanced compressor and overdrive
// Provides professional-grade master bus processing with comprehensive control

import Foundation
import Accelerate
import MachineProtocols
import AudioEngine

// MARK: - Master FX Configuration

/// Configuration for master effects system
public struct MasterFXConfig: Codable {
    /// Compressor configuration
    public var compressor: MasterCompressorConfig = MasterCompressorConfig()
    
    /// Overdrive configuration
    public var overdrive: MasterOverdriveConfig = MasterOverdriveConfig()
    
    /// Limiter configuration
    public var limiter: MasterLimiterConfig = MasterLimiterConfig()
    
    /// EQ configuration
    public var eq: MasterEQConfig = MasterEQConfig()
    
    /// Effect chain configuration
    public var chain: EffectChainConfig = EffectChainConfig()
    
    /// Master output configuration
    public var output: MasterOutputConfig = MasterOutputConfig()
    
    public init() {}
}

/// Master compressor configuration
public struct MasterCompressorConfig: Codable {
    public var enabled: Bool = true
    public var threshold: Float = -12.0      // dB (-60 to 0)
    public var ratio: Float = 4.0            // 1:1 to 20:1
    public var attack: Float = 5.0           // ms (0.1 to 100)
    public var release: Float = 100.0        // ms (10 to 1000)
    public var knee: Float = 2.0             // dB (0 to 10)
    public var makeupGain: Float = 0.0       // dB (-20 to 20)
    public var lookahead: Float = 5.0        // ms (0 to 10)
    public var sidechain: SidechainConfig = SidechainConfig()
    public var character: CompressorCharacter = .clean
    public var wetLevel: Float = 1.0         // 0.0 to 1.0
    
    public init() {}
}

/// Master overdrive configuration
public struct MasterOverdriveConfig: Codable {
    public var enabled: Bool = true
    public var drive: Float = 1.0            // 0.0 to 10.0
    public var saturation: SaturationType = .tube
    public var tone: Float = 0.5             // 0.0 to 1.0
    public var presence: Float = 0.0         // -10dB to 10dB
    public var warmth: Float = 0.0           // -10dB to 10dB
    public var asymmetry: Float = 0.0        // -1.0 to 1.0
    public var harmonics: Float = 0.0        // 0.0 to 1.0
    public var stereoWidth: Float = 1.0      // 0.0 to 2.0
    public var outputLevel: Float = 0.0      // dB (-20 to 20)
    public var wetLevel: Float = 1.0         // 0.0 to 1.0
    
    public init() {}
}

/// Master limiter configuration
public struct MasterLimiterConfig: Codable {
    public var enabled: Bool = true
    public var ceiling: Float = -0.1         // dB (-10 to 0)
    public var release: Float = 100.0        // ms (1 to 1000)
    public var lookahead: Float = 5.0        // ms (0 to 10)
    public var oversampling: Int = 4         // 1, 2, 4, 8
    public var softKnee: Float = 0.5         // 0.0 to 1.0
    public var character: LimiterCharacter = .transparent
    public var isr: Bool = true              // Inter-sample peak detection
    
    public init() {}
}

/// Master EQ configuration
public struct MasterEQConfig: Codable {
    public var enabled: Bool = false
    public var lowShelf: EQBandConfig = EQBandConfig(frequency: 100.0, gain: 0.0, q: 0.7)
    public var lowMid: EQBandConfig = EQBandConfig(frequency: 500.0, gain: 0.0, q: 1.0)
    public var highMid: EQBandConfig = EQBandConfig(frequency: 3000.0, gain: 0.0, q: 1.0)
    public var highShelf: EQBandConfig = EQBandConfig(frequency: 10000.0, gain: 0.0, q: 0.7)
    
    public init() {}
}

/// Effect chain configuration
public struct EffectChainConfig: Codable {
    public var order: [MasterEffectType] = [.eq, .compressor, .overdrive, .limiter]
    public var parallelCompression: Bool = false
    public var parallelCompressionMix: Float = 0.0  // 0.0 to 1.0
    public var midSideProcessing: Bool = false
    
    public init() {}
}

/// Master output configuration
public struct MasterOutputConfig: Codable {
    public var gain: Float = 0.0             // dB (-20 to 20)
    public var stereoWidth: Float = 1.0      // 0.0 to 2.0
    public var dcBlock: Bool = true
    public var dithering: Bool = false
    public var ditherType: MasterDitherType = .triangular
    public var outputFormat: OutputFormat = .float32
    
    public init() {}
}

/// Supporting configuration types
public struct SidechainConfig: Codable {
    public var enabled: Bool = false
    public var source: SidechainSource = .external
    public var filterFreq: Float = 100.0     // Hz
    public var filterSlope: Float = 12.0     // dB/octave
    
    public init() {}
}

public struct EQBandConfig: Codable {
    public var frequency: Float
    public var gain: Float
    public var q: Float
    public var enabled: Bool = true
    
    public init(frequency: Float, gain: Float, q: Float) {
        self.frequency = frequency
        self.gain = gain
        self.q = q
    }
}

/// Enums for configuration
public enum CompressorCharacter: String, CaseIterable, Codable {
    case clean = "clean"
    case vintage = "vintage"
    case aggressive = "aggressive"
    case smooth = "smooth"
    
    public var description: String {
        switch self {
        case .clean: return "Clean"
        case .vintage: return "Vintage"
        case .aggressive: return "Aggressive"
        case .smooth: return "Smooth"
        }
    }
}

public enum SaturationType: String, CaseIterable, Codable {
    case tube = "tube"
    case transistor = "transistor"
    case tape = "tape"
    case digital = "digital"
    case vintage = "vintage"
    
    public var description: String {
        switch self {
        case .tube: return "Tube"
        case .transistor: return "Transistor"
        case .tape: return "Tape"
        case .digital: return "Digital"
        case .vintage: return "Vintage"
        }
    }
}

public enum LimiterCharacter: String, CaseIterable, Codable {
    case transparent = "transparent"
    case warm = "warm"
    case aggressive = "aggressive"
    
    public var description: String {
        switch self {
        case .transparent: return "Transparent"
        case .warm: return "Warm"
        case .aggressive: return "Aggressive"
        }
    }
}

public enum SidechainSource: String, CaseIterable, Codable {
    case external = "external"
    case `internal` = "internal"
    case kick = "kick"
    case snare = "snare"
    
    public var description: String {
        switch self {
        case .external: return "External"
        case .internal: return "Internal"
        case .kick: return "Kick"
        case .snare: return "Snare"
        }
    }
}



public enum OutputFormat: String, CaseIterable, Codable, Sendable {
    case float32 = "float32"
    case int24 = "int24"
    case int16 = "int16"
    
    public var description: String {
        switch self {
        case .float32: return "32-bit Float"
        case .int24: return "24-bit Integer"
        case .int16: return "16-bit Integer"
        }
    }
}

public enum MasterEffectType: String, CaseIterable, Codable, Sendable {
    case eq = "eq"
    case compressor = "compressor"
    case overdrive = "overdrive"
    case limiter = "limiter"
    
    public var description: String {
        switch self {
        case .eq: return "EQ"
        case .compressor: return "Compressor"
        case .overdrive: return "Overdrive"
        case .limiter: return "Limiter"
        }
    }
}

/// Master output chain configuration
public struct MasterChainConfig: Codable, Sendable {
    // Compressor settings
    public var compressorEnabled: Bool = false
    public var compressorThreshold: Float = -12.0  // dB
    public var compressorRatio: Float = 4.0
    public var compressorAttack: Float = 1.0       // ms
    public var compressorRelease: Float = 100.0    // ms
    public var compressorMakeupGain: Float = 0.0   // dB
    
    // Limiter settings
    public var limiterEnabled: Bool = true
    public var limiterThreshold: Float = -0.3      // dB
    public var limiterRelease: Float = 50.0        // ms
    public var limiterLookahead: Float = 5.0       // ms
    
    // EQ settings
    public var eqEnabled: Bool = false
    public var lowShelfFreq: Float = 100.0         // Hz
    public var lowShelfGain: Float = 0.0           // dB
    public var highShelfFreq: Float = 10000.0      // Hz
    public var highShelfGain: Float = 0.0          // dB
    
    // Master settings
    public var masterGain: Float = 0.0             // dB
    public var stereoWidth: Float = 1.0            // 0.0 to 2.0
    public var dcBlock: Bool = true
    public var dithering: Bool = false
    public var ditherType: MasterDitherType = .triangular
    public var outputFormat: OutputFormat = .float32
}

public enum MasterDitherType: String, CaseIterable, Codable, Sendable {
    case none = "none"
    case triangular = "triangular"
    case shaped = "shaped"
}

// MARK: - Master FX Processor

/// Enhanced master effects processor
public final class MasterFXProcessor: @unchecked Sendable {
    
    // MARK: - Configuration
    
    public var config: MasterFXConfig {
        didSet {
            updateEffectChain()
        }
    }
    
    /// Sample rate
    private let sampleRate: Double
    
    /// Whether the entire master FX is bypassed
    public var isBypassed: Bool = false
    
    // MARK: - Internal Components
    
    private var compressorProcessor: AdvancedCompressorProcessor
    private var overdriveProcessor: AdvancedOverdriveProcessor
    private var limiterProcessor: AdvancedLimiterProcessor
    private var eqProcessor: MasterEQProcessor
    private var outputProcessor: MasterOutputProcessor
    
    // MARK: - Audio Processing State
    
    private var processBuffer: [Float] = []
    private var parallelBuffer: [Float] = []
    private var midSideBuffer: [Float] = []
    
    // MARK: - Metering
    
    private var inputPeak: Float = 0.0
    private var outputPeak: Float = 0.0
    private var gainReduction: Float = 0.0
    
    // MARK: - Performance Optimization
    
    private var performanceMonitor: PerformanceMonitor
    
    // MARK: - Initialization
    
    public init(config: MasterFXConfig = MasterFXConfig(), sampleRate: Double = 44100.0) {
        self.config = config
        self.sampleRate = sampleRate
        
        // Initialize processors
        self.compressorProcessor = AdvancedCompressorProcessor(sampleRate: sampleRate)
        self.overdriveProcessor = AdvancedOverdriveProcessor(sampleRate: sampleRate)
        self.limiterProcessor = AdvancedLimiterProcessor(sampleRate: sampleRate)
        self.eqProcessor = MasterEQProcessor(sampleRate: sampleRate)
        self.outputProcessor = MasterOutputProcessor(sampleRate: sampleRate)
        self.performanceMonitor = PerformanceMonitor()
        
        // Initialize buffers
        let maxBufferSize = Int(sampleRate * 0.1) // 100ms buffer
        processBuffer = [Float](repeating: 0.0, count: maxBufferSize)
        parallelBuffer = [Float](repeating: 0.0, count: maxBufferSize)
        midSideBuffer = [Float](repeating: 0.0, count: maxBufferSize)
        
        updateEffectChain()
    }
    
    // MARK: - Audio Processing
    
    /// Process audio through master effects
    public func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        guard !isBypassed else { return input }
        
        performanceMonitor.startTiming()
        
        let frameCount = input.frameCount
        let channelCount = input.channelCount
        let totalSamples = frameCount * channelCount
        
        // Ensure buffers are large enough
        if processBuffer.count < totalSamples {
            processBuffer = [Float](repeating: 0.0, count: totalSamples)
            parallelBuffer = [Float](repeating: 0.0, count: totalSamples)
            midSideBuffer = [Float](repeating: 0.0, count: totalSamples)
        }
        
        // Copy input to process buffer
        for i in 0..<totalSamples {
            processBuffer[i] = input.data[i]
        }
        
        // Update input metering
        updateInputMetering(processBuffer, count: totalSamples)
        
        // Convert to mid-side if enabled
        if config.chain.midSideProcessing && channelCount == 2 {
            convertToMidSide(processBuffer, frameCount: frameCount)
        }
        
        // Setup parallel compression if enabled
        if config.chain.parallelCompression {
            for i in 0..<totalSamples {
                parallelBuffer[i] = processBuffer[i]
            }
        }
        
        // Process through effects chain
        for effectType in config.chain.order {
            switch effectType {
            case .eq:
                if config.eq.enabled {
                    processEQ(&processBuffer, frameCount: frameCount, channelCount: channelCount)
                }
                
            case .compressor:
                if config.compressor.enabled {
                    processCompressor(&processBuffer, frameCount: frameCount, channelCount: channelCount)
                }
                
            case .overdrive:
                if config.overdrive.enabled {
                    processOverdrive(&processBuffer, frameCount: frameCount, channelCount: channelCount)
                }
                
            case .limiter:
                if config.limiter.enabled {
                    processLimiter(&processBuffer, frameCount: frameCount, channelCount: channelCount)
                }
            }
        }
        
        // Mix parallel compression if enabled
        if config.chain.parallelCompression {
            mixParallelCompression(&processBuffer, totalSamples: totalSamples)
        }
        
        // Convert back from mid-side if enabled
        if config.chain.midSideProcessing && channelCount == 2 {
            convertFromMidSide(processBuffer, frameCount: frameCount)
        }
        
        // Process master output
        processOutput(&processBuffer, frameCount: frameCount, channelCount: channelCount)
        
        // Update output metering
        updateOutputMetering(processBuffer, count: totalSamples)
        
        // Create output buffer
        let outputData = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)
        for i in 0..<totalSamples {
            outputData[i] = processBuffer[i]
        }
        
        performanceMonitor.endTiming(samplesProcessed: totalSamples)
        
        return AudioEngine.AudioBuffer(
            data: outputData,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: input.sampleRate
        )
    }

    // MARK: - Individual Effect Processing

    private func processEQ(_ buffer: inout [Float], frameCount: Int, channelCount: Int) {
        eqProcessor.process(buffer: &buffer, frameCount: frameCount, channelCount: channelCount, config: config.eq)
    }

    private func processCompressor(_ buffer: inout [Float], frameCount: Int, channelCount: Int) {
        let reduction = compressorProcessor.process(buffer: &buffer, frameCount: frameCount, channelCount: channelCount, config: config.compressor)
        gainReduction = max(gainReduction, reduction)
    }

    private func processOverdrive(_ buffer: inout [Float], frameCount: Int, channelCount: Int) {
        overdriveProcessor.process(buffer: &buffer, frameCount: frameCount, channelCount: channelCount, config: config.overdrive)
    }

    private func processLimiter(_ buffer: inout [Float], frameCount: Int, channelCount: Int) {
        limiterProcessor.process(buffer: &buffer, frameCount: frameCount, channelCount: channelCount, config: config.limiter)
    }

    private func processOutput(_ buffer: inout [Float], frameCount: Int, channelCount: Int) {
        outputProcessor.process(buffer: &buffer, frameCount: frameCount, channelCount: channelCount, config: config.output)
    }

    // MARK: - Mid-Side Processing

    private func convertToMidSide(_ buffer: [Float], frameCount: Int) {
        for frame in 0..<frameCount {
            let leftIndex = frame * 2
            let rightIndex = frame * 2 + 1

            let left = buffer[leftIndex]
            let right = buffer[rightIndex]

            let mid = (left + right) * 0.5
            let side = (left - right) * 0.5

            processBuffer[leftIndex] = mid
            processBuffer[rightIndex] = side
        }
    }

    private func convertFromMidSide(_ buffer: [Float], frameCount: Int) {
        for frame in 0..<frameCount {
            let midIndex = frame * 2
            let sideIndex = frame * 2 + 1

            let mid = buffer[midIndex]
            let side = buffer[sideIndex]

            let left = mid + side
            let right = mid - side

            processBuffer[midIndex] = left
            processBuffer[sideIndex] = right
        }
    }

    // MARK: - Parallel Compression

    private func mixParallelCompression(_ buffer: inout [Float], totalSamples: Int) {
        let mix = config.chain.parallelCompressionMix

        for i in 0..<totalSamples {
            buffer[i] = buffer[i] * (1.0 - mix) + parallelBuffer[i] * mix
        }
    }

    // MARK: - Metering

    private func updateInputMetering(_ buffer: [Float], count: Int) {
        var peak: Float = 0.0
        vDSP_maxmgv(buffer, 1, &peak, vDSP_Length(count))
        inputPeak = peak
    }

    private func updateOutputMetering(_ buffer: [Float], count: Int) {
        var peak: Float = 0.0
        vDSP_maxmgv(buffer, 1, &peak, vDSP_Length(count))
        outputPeak = peak
    }

    // MARK: - Control Methods

    /// Reset all effect states
    public func reset() {
        compressorProcessor.reset()
        overdriveProcessor.reset()
        limiterProcessor.reset()
        eqProcessor.reset()
        outputProcessor.reset()

        inputPeak = 0.0
        outputPeak = 0.0
        gainReduction = 0.0
    }

    /// Get current peak levels
    public func getPeakLevels() -> (input: Float, output: Float, gainReduction: Float) {
        return (inputPeak, outputPeak, gainReduction)
    }

    /// Enable/disable specific master effect
    public func setEffectEnabled(_ effectType: MasterEffectType, enabled: Bool) {
        switch effectType {
        case .eq:
            config.eq.enabled = enabled
        case .compressor:
            config.compressor.enabled = enabled
        case .overdrive:
            config.overdrive.enabled = enabled
        case .limiter:
            config.limiter.enabled = enabled
        }
    }

    /// Check if specific effect is enabled
    public func isEffectEnabled(_ effectType: MasterEffectType) -> Bool {
        switch effectType {
        case .eq:
            return config.eq.enabled
        case .compressor:
            return config.compressor.enabled
        case .overdrive:
            return config.overdrive.enabled
        case .limiter:
            return config.limiter.enabled
        }
    }

    // MARK: - Private Methods

    private func updateEffectChain() {
        // Update individual processors with new configuration
        compressorProcessor.updateConfig(config.compressor)
        overdriveProcessor.updateConfig(config.overdrive)
        limiterProcessor.updateConfig(config.limiter)
        eqProcessor.updateConfig(config.eq)
        outputProcessor.updateConfig(config.output)
    }
}

// MARK: - Advanced Compressor Processor

/// High-quality compressor processor for master bus
private final class AdvancedCompressorProcessor: @unchecked Sendable {

    private let sampleRate: Double
    private var envelopeFollower: EnvelopeFollower
    private var lookaheadBuffer: LookaheadBuffer
    private var sidechainFilter: SidechainFilter
    private var characterProcessor: CompressorCharacterProcessor

    // State variables
    private var gainReduction: Float = 0.0

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        self.envelopeFollower = EnvelopeFollower(sampleRate: sampleRate)
        self.lookaheadBuffer = LookaheadBuffer(maxDelay: 0.01, sampleRate: sampleRate)
        self.sidechainFilter = SidechainFilter(sampleRate: sampleRate)
        self.characterProcessor = CompressorCharacterProcessor(sampleRate: sampleRate)
    }

    func updateConfig(_ config: MasterCompressorConfig) {
        envelopeFollower.setAttack(config.attack)
        envelopeFollower.setRelease(config.release)
        lookaheadBuffer.setDelay(config.lookahead)
        sidechainFilter.updateConfig(config.sidechain)
        characterProcessor.setCharacter(config.character)
    }

    func process(buffer: inout [Float], frameCount: Int, channelCount: Int, config: MasterCompressorConfig) -> Float {
        var maxGainReduction: Float = 0.0

        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                let index = frame * channelCount + channel
                let input = buffer[index]

                // Apply lookahead delay
                let delayed = lookaheadBuffer.process(input, channel: channel)

                // Calculate detection signal
                let detectionSignal = sidechainFilter.process(input, channel: channel)
                let level = abs(detectionSignal)

                // Calculate gain reduction
                let reduction = calculateGainReduction(level, config: config)
                let smoothedReduction = envelopeFollower.process(reduction, channel: channel)

                // Apply character processing
                let characterGain = characterProcessor.process(smoothedReduction, config: config)

                // Apply compression
                buffer[index] = delayed * characterGain

                maxGainReduction = max(maxGainReduction, 1.0 - characterGain)
            }
        }

        // Apply makeup gain
        if config.makeupGain != 0.0 {
            let makeupLinear = pow(10.0, config.makeupGain / 20.0)
            vDSP_vsmul(buffer, 1, [makeupLinear], &buffer, 1, vDSP_Length(frameCount * channelCount))
        }

        gainReduction = maxGainReduction
        return maxGainReduction
    }

    func reset() {
        envelopeFollower.reset()
        lookaheadBuffer.reset()
        sidechainFilter.reset()
        characterProcessor.reset()
        gainReduction = 0.0
    }

    private func calculateGainReduction(_ level: Float, config: MasterCompressorConfig) -> Float {
        let levelDb = 20.0 * log10(max(level, 1e-10))

        guard levelDb > config.threshold else {
            return 1.0 // No compression
        }

        let overThreshold = levelDb - config.threshold
        var gainReductionDb: Float

        // Apply knee
        if config.knee > 0.0 {
            let kneeStart = config.threshold - config.knee * 0.5
            let kneeEnd = config.threshold + config.knee * 0.5

            if levelDb >= kneeStart && levelDb <= kneeEnd {
                // Soft knee
                let kneeRatio = (levelDb - kneeStart) / config.knee
                let softRatio = 1.0 + (config.ratio - 1.0) * kneeRatio * kneeRatio
                gainReductionDb = overThreshold * (1.0 - 1.0 / softRatio)
            } else if levelDb > kneeEnd {
                // Above knee
                gainReductionDb = overThreshold * (1.0 - 1.0 / config.ratio)
            } else {
                // Below knee
                gainReductionDb = 0.0
            }
        } else {
            // Hard knee
            gainReductionDb = overThreshold * (1.0 - 1.0 / config.ratio)
        }

        return pow(10.0, -gainReductionDb / 20.0)
    }
}
