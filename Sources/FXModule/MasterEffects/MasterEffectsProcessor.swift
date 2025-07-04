import Foundation
import MachineProtocols
import Combine
import Accelerate

/// Master effects processor that handles the final output processing chain
public class MasterEffectsProcessor: ObservableObject {
    
    // MARK: - Effects Chain
    
    @Published public private(set) var compressor: CompressorEffect
    @Published public private(set) var overdrive: MasterOverdriveEffect
    @Published public private(set) var limiter: TruePeakLimiterEffect
    
    // MARK: - Chain Configuration
    
    @Published public var effectsOrder: [MasterEffectType] = [.compressor, .overdrive, .limiter]
    @Published public var masterBypass: Bool = false
    @Published public var masterGain: Float = 0.0 // dB
    
    // MARK: - Metering
    
    @Published public var inputLevel: Float = 0.0
    @Published public var outputLevel: Float = 0.0
    @Published public var totalGainReduction: Float = 0.0
    
    // MARK: - Performance
    
    private var performanceMonitor = MasterEffectsPerformanceMonitor()
    
    // MARK: - Initialization
    
    public init() {
        self.compressor = CompressorEffect()
        self.overdrive = MasterOverdriveEffect()
        self.limiter = TruePeakLimiterEffect()
        
        setupDefaultConfiguration()
    }
    
    // MARK: - Audio Processing
    
    /// Process audio through the master effects chain
    public func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        guard !masterBypass else {
            return applyMasterGain(to: input)
        }
        
        performanceMonitor.startTiming()
        
        var output = input
        
        // Update input metering
        updateInputMetering(output)
        
        // Process through effects chain in specified order
        for effectType in effectsOrder {
            switch effectType {
            case .eq:
                // EQ processing would go here when implemented
                break
            case .compressor:
                if compressor.isEnabled {
                    output = compressor.process(input: output)
                }
            case .overdrive:
                if overdrive.isEnabled {
                    output = overdrive.process(input: output)
                }
            case .limiter:
                if limiter.isEnabled {
                    output = limiter.process(input: output)
                }
            }
        }
        
        // Apply master gain
        output = applyMasterGain(to: output)
        
        // Update output metering
        updateOutputMetering(output)
        updateGainReductionMetering()
        
        performanceMonitor.endTiming(samplesProcessed: output.samples.count)
        
        return output
    }
    
    // MARK: - Master Gain
    
    private func applyMasterGain(to buffer: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        guard masterGain != 0.0 else { return buffer }
        
        var output = buffer
        var gainLinear = pow(10.0, masterGain / 20.0)

        // Use vectorized operations for performance
        vDSP_vsmul(output.samples, 1, &gainLinear, &output.samples, 1, vDSP_Length(output.samples.count))
        
        return output
    }
    
    // MARK: - Effects Chain Management
    
    /// Reorder effects in the processing chain
    public func setEffectsOrder(_ order: [MasterEffectType]) {
        guard order.count == 3 && Set(order) == Set(MasterEffectType.allCases) else {
            print("Invalid effects order - must contain all three effects exactly once")
            return
        }
        effectsOrder = order
    }
    
    /// Get effect by type
    public func getEffect(_ type: MasterEffectType) -> FXProcessor {
        switch type {
        case .eq: return compressor // Placeholder until EQ is implemented
        case .compressor: return compressor
        case .overdrive: return overdrive
        case .limiter: return limiter
        }
    }
    
    // MARK: - Preset Management
    
    /// Save current master effects configuration
    public func savePreset(name: String) -> MasterEffectsPreset {
        return MasterEffectsPreset(
            name: name,
            effectsOrder: effectsOrder,
            masterGain: masterGain,
            compressorSettings: CompressorSettings(from: compressor),
            overdriveSettings: OverdriveSettings(from: overdrive),
            limiterSettings: LimiterSettings(from: limiter)
        )
    }
    
    /// Load master effects preset
    public func loadPreset(_ preset: MasterEffectsPreset) {
        effectsOrder = preset.effectsOrder
        masterGain = preset.masterGain
        
        preset.compressorSettings.apply(to: compressor)
        preset.overdriveSettings.apply(to: overdrive)
        preset.limiterSettings.apply(to: limiter)
    }
    
    // MARK: - Quick Presets
    
    public enum QuickPreset {
        case transparent
        case warm
        case punchy
        case loud
        case broadcast
        case mastering
        
        var preset: MasterEffectsPreset {
            switch self {
            case .transparent:
                return MasterEffectsPreset.transparent
            case .warm:
                return MasterEffectsPreset.warm
            case .punchy:
                return MasterEffectsPreset.punchy
            case .loud:
                return MasterEffectsPreset.loud
            case .broadcast:
                return MasterEffectsPreset.broadcast
            case .mastering:
                return MasterEffectsPreset.mastering
            }
        }
    }
    
    /// Apply a quick preset
    public func applyQuickPreset(_ preset: QuickPreset) {
        loadPreset(preset.preset)
    }
    
    // MARK: - Metering
    
    private func updateInputMetering(_ buffer: MachineProtocols.AudioBuffer) {
        var peak: Float = 0.0
        for sample in buffer.samples {
            peak = max(peak, abs(sample))
        }
        inputLevel = peak
    }
    
    private func updateOutputMetering(_ buffer: MachineProtocols.AudioBuffer) {
        var peak: Float = 0.0
        for sample in buffer.samples {
            peak = max(peak, abs(sample))
        }
        outputLevel = peak
    }
    
    private func updateGainReductionMetering() {
        totalGainReduction = compressor.gainReduction + limiter.gainReduction
    }
    
    // MARK: - Performance Monitoring
    
    public func getPerformanceMetrics() -> MasterEffectsPerformanceMetrics {
        return performanceMonitor.getMetrics()
    }
    
    public func resetPerformanceMetrics() {
        performanceMonitor.reset()
    }
    
    // MARK: - State Management
    
    /// Reset all effects to default state
    public func resetAllEffects() {
        compressor.resetEffectState()
        overdrive.resetEffectState()
        limiter.resetEffectState()
        
        masterGain = 0.0
        masterBypass = false
    }
    
    /// Set sample rate for all effects
    public func setSampleRate(_ sampleRate: Double) {
        compressor.setSampleRate(sampleRate)
        overdrive.setSampleRate(sampleRate)
        limiter.setSampleRate(sampleRate)
    }
    
    // MARK: - Private Setup
    
    private func setupDefaultConfiguration() {
        // Apply conservative default settings
        compressor.applyPreset(.master)
        overdrive.applyPreset(.clean)
        limiter.applyPreset(.mastering)
        
        // Set reasonable defaults
        masterGain = 0.0
        masterBypass = false
    }
}

// MARK: - Supporting Types



// MARK: - Preset System

public struct MasterEffectsPreset: Codable, Sendable {
    public let name: String
    public let effectsOrder: [MasterEffectType]
    public let masterGain: Float
    public let compressorSettings: CompressorSettings
    public let overdriveSettings: OverdriveSettings
    public let limiterSettings: LimiterSettings
    
    // Quick presets
    static let transparent = MasterEffectsPreset(
        name: "Transparent",
        effectsOrder: [.compressor, .overdrive, .limiter],
        masterGain: 0.0,
        compressorSettings: CompressorSettings(threshold: -18, ratio: 2, attack: 10, release: 100, knee: 4, makeup: 0, enabled: false),
        overdriveSettings: OverdriveSettings(drive: 1, saturation: .tube, highEmph: 0.1, lowRoll: 0.1, output: 0, stereoWidth: 1, harmonics: 0, enabled: false),
        limiterSettings: LimiterSettings(ceiling: -0.1, release: 100, lookahead: 5, oversampling: 4, softKnee: 0.7, enabled: true)
    )
    
    static let warm = MasterEffectsPreset(
        name: "Warm",
        effectsOrder: [.compressor, .overdrive, .limiter],
        masterGain: 0.0,
        compressorSettings: CompressorSettings(threshold: -12, ratio: 3, attack: 5, release: 150, knee: 3, makeup: 2, enabled: true),
        overdriveSettings: OverdriveSettings(drive: 1.5, saturation: .tube, highEmph: 0.2, lowRoll: 0.15, output: -1, stereoWidth: 1.05, harmonics: 0.1, enabled: true),
        limiterSettings: LimiterSettings(ceiling: -0.1, release: 100, lookahead: 5, oversampling: 4, softKnee: 0.7, enabled: true)
    )
    
    static let punchy = MasterEffectsPreset(
        name: "Punchy",
        effectsOrder: [.compressor, .overdrive, .limiter],
        masterGain: 0.0,
        compressorSettings: CompressorSettings(threshold: -8, ratio: 4, attack: 2, release: 80, knee: 2, makeup: 3, enabled: true),
        overdriveSettings: OverdriveSettings(drive: 2, saturation: .transistor, highEmph: 0.4, lowRoll: 0.1, output: -2, stereoWidth: 1.1, harmonics: 0.15, enabled: true),
        limiterSettings: LimiterSettings(ceiling: -0.1, release: 50, lookahead: 3, oversampling: 4, softKnee: 0.5, enabled: true)
    )
    
    static let loud = MasterEffectsPreset(
        name: "Loud",
        effectsOrder: [.compressor, .overdrive, .limiter],
        masterGain: 0.0,
        compressorSettings: CompressorSettings(threshold: -6, ratio: 6, attack: 1, release: 50, knee: 1, makeup: 4, enabled: true),
        overdriveSettings: OverdriveSettings(drive: 2.5, saturation: .digital, highEmph: 0.5, lowRoll: 0.2, output: -3, stereoWidth: 1.2, harmonics: 0.2, enabled: true),
        limiterSettings: LimiterSettings(ceiling: -0.3, release: 30, lookahead: 2, oversampling: 2, softKnee: 0.3, enabled: true)
    )
    
    static let broadcast = MasterEffectsPreset(
        name: "Broadcast",
        effectsOrder: [.compressor, .overdrive, .limiter],
        masterGain: 0.0,
        compressorSettings: CompressorSettings(threshold: -10, ratio: 3, attack: 3, release: 100, knee: 3, makeup: 2, enabled: true),
        overdriveSettings: OverdriveSettings(drive: 1.2, saturation: .tube, highEmph: 0.3, lowRoll: 0.25, output: -1, stereoWidth: 1, harmonics: 0.05, enabled: true),
        limiterSettings: LimiterSettings(ceiling: -1, release: 75, lookahead: 8, oversampling: 4, softKnee: 0.6, enabled: true)
    )
    
    static let mastering = MasterEffectsPreset(
        name: "Mastering",
        effectsOrder: [.compressor, .overdrive, .limiter],
        masterGain: 0.0,
        compressorSettings: CompressorSettings(threshold: -15, ratio: 2.5, attack: 8, release: 200, knee: 4, makeup: 1, enabled: true),
        overdriveSettings: OverdriveSettings(drive: 1.3, saturation: .vintage, highEmph: 0.25, lowRoll: 0.1, output: -0.5, stereoWidth: 1.02, harmonics: 0.08, enabled: true),
        limiterSettings: LimiterSettings(ceiling: -0.1, release: 200, lookahead: 10, oversampling: 8, softKnee: 0.8, enabled: true)
    )
}

// Settings structures for each effect
public struct CompressorSettings: Codable, Sendable {
    let threshold: Float
    let ratio: Float
    let attack: Float
    let release: Float
    let knee: Float
    let makeup: Float
    let enabled: Bool
    
    init(from compressor: CompressorEffect) {
        threshold = compressor.threshold
        ratio = compressor.ratio
        attack = compressor.attackTime
        release = compressor.releaseTime
        knee = compressor.kneeWidth
        makeup = compressor.makeupGain
        enabled = compressor.isEnabled
    }
    
    init(threshold: Float, ratio: Float, attack: Float, release: Float, knee: Float, makeup: Float, enabled: Bool) {
        self.threshold = threshold
        self.ratio = ratio
        self.attack = attack
        self.release = release
        self.knee = knee
        self.makeup = makeup
        self.enabled = enabled
    }
    
    func apply(to compressor: CompressorEffect) {
        compressor.threshold = threshold
        compressor.ratio = ratio
        compressor.attackTime = attack
        compressor.releaseTime = release
        compressor.kneeWidth = knee
        compressor.makeupGain = makeup
        compressor.isEnabled = enabled
    }
}

public struct OverdriveSettings: Codable, Sendable {
    let drive: Float
    let saturation: MasterOverdriveEffect.SaturationType
    let highEmph: Float
    let lowRoll: Float
    let output: Float
    let stereoWidth: Float
    let harmonics: Float
    let enabled: Bool
    
    init(from overdrive: MasterOverdriveEffect) {
        drive = overdrive.driveAmount
        saturation = overdrive.saturationType
        highEmph = overdrive.highFreqEmphasis
        lowRoll = overdrive.lowFreqRolloff
        output = overdrive.outputLevel
        stereoWidth = overdrive.stereoWidth
        harmonics = overdrive.harmonicEnhancement
        enabled = overdrive.isEnabled
    }
    
    init(drive: Float, saturation: MasterOverdriveEffect.SaturationType, highEmph: Float, lowRoll: Float, output: Float, stereoWidth: Float, harmonics: Float, enabled: Bool) {
        self.drive = drive
        self.saturation = saturation
        self.highEmph = highEmph
        self.lowRoll = lowRoll
        self.output = output
        self.stereoWidth = stereoWidth
        self.harmonics = harmonics
        self.enabled = enabled
    }
    
    func apply(to overdrive: MasterOverdriveEffect) {
        overdrive.driveAmount = drive
        overdrive.saturationType = saturation
        overdrive.highFreqEmphasis = highEmph
        overdrive.lowFreqRolloff = lowRoll
        overdrive.outputLevel = output
        overdrive.stereoWidth = stereoWidth
        overdrive.harmonicEnhancement = harmonics
        overdrive.isEnabled = enabled
    }
}

public struct LimiterSettings: Codable, Sendable {
    let ceiling: Float
    let release: Float
    let lookahead: Float
    let oversampling: Int
    let softKnee: Float
    let enabled: Bool
    
    init(from limiter: TruePeakLimiterEffect) {
        ceiling = limiter.ceiling
        release = limiter.releaseTime
        lookahead = limiter.lookaheadTime
        oversampling = limiter.oversamplingFactor
        softKnee = limiter.softKnee
        enabled = limiter.isEnabled
    }
    
    init(ceiling: Float, release: Float, lookahead: Float, oversampling: Int, softKnee: Float, enabled: Bool) {
        self.ceiling = ceiling
        self.release = release
        self.lookahead = lookahead
        self.oversampling = oversampling
        self.softKnee = softKnee
        self.enabled = enabled
    }
    
    func apply(to limiter: TruePeakLimiterEffect) {
        limiter.ceiling = ceiling
        limiter.releaseTime = release
        limiter.lookaheadTime = lookahead
        limiter.oversamplingFactor = oversampling
        limiter.softKnee = softKnee
        limiter.isEnabled = enabled
    }
}

// MARK: - Performance Monitoring

private class MasterEffectsPerformanceMonitor {
    private var metrics = MasterEffectsPerformanceMetrics()
    private var startTime: CFAbsoluteTime = 0.0
    
    func startTiming() {
        startTime = CFAbsoluteTimeGetCurrent()
    }
    
    func endTiming(samplesProcessed: Int) {
        let endTime = CFAbsoluteTimeGetCurrent()
        let processingTime = endTime - startTime
        
        metrics.totalProcessingTime += processingTime
        metrics.totalSamplesProcessed += samplesProcessed
        metrics.processCallCount += 1
        
        if processingTime > metrics.peakProcessingTime {
            metrics.peakProcessingTime = processingTime
        }
    }
    
    func getMetrics() -> MasterEffectsPerformanceMetrics {
        return metrics
    }
    
    func reset() {
        metrics = MasterEffectsPerformanceMetrics()
    }
}

public struct MasterEffectsPerformanceMetrics {
    public var totalProcessingTime: TimeInterval = 0.0
    public var totalSamplesProcessed: Int = 0
    public var processCallCount: Int = 0
    public var peakProcessingTime: TimeInterval = 0.0
    
    public var averageProcessingTime: TimeInterval {
        guard processCallCount > 0 else { return 0.0 }
        return totalProcessingTime / Double(processCallCount)
    }
    
    public var cpuUsageEstimate: Float {
        let realTimeForSamples = Double(totalSamplesProcessed) / 44100.0
        guard realTimeForSamples > 0 else { return 0.0 }
        return Float(totalProcessingTime / realTimeForSamples)
    }
}
