import Foundation
import Accelerate
import MachineProtocols

/// High-quality dynamic range compressor for master bus processing
public class CompressorEffect: FXProcessor, ObservableObject, @unchecked Sendable {
    
    // MARK: - Parameters
    
    /// Threshold in dB (-60 to 0)
    public var threshold: Float = -12.0 {
        didSet {
            threshold = max(-60.0, min(0.0, threshold))
            updateCompressorParameters()
        }
    }
    
    /// Compression ratio (1:1 to 20:1)
    public var ratio: Float = 4.0 {
        didSet {
            ratio = max(1.0, min(20.0, ratio))
            updateCompressorParameters()
        }
    }
    
    /// Attack time in milliseconds (0.1 to 100)
    public var attackTime: Float = 5.0 {
        didSet {
            attackTime = max(0.1, min(100.0, attackTime))
            updateEnvelopeCoefficients()
        }
    }
    
    /// Release time in milliseconds (10 to 5000)
    public var releaseTime: Float = 100.0 {
        didSet {
            releaseTime = max(10.0, min(5000.0, releaseTime))
            updateEnvelopeCoefficients()
        }
    }
    
    /// Knee width in dB (0 to 20)
    public var kneeWidth: Float = 2.0 {
        didSet {
            kneeWidth = max(0.0, min(20.0, kneeWidth))
            updateCompressorParameters()
        }
    }
    
    /// Makeup gain in dB (-20 to 20)
    public var makeupGain: Float = 0.0 {
        didSet {
            makeupGain = max(-20.0, min(20.0, makeupGain))
        }
    }
    
    /// Auto makeup gain
    public var autoMakeupGain: Bool = true {
        didSet {
            if autoMakeupGain {
                calculateAutoMakeupGain()
            }
        }
    }
    
    /// Lookahead time in milliseconds (0 to 10)
    public var lookaheadTime: Float = 2.0 {
        didSet {
            lookaheadTime = max(0.0, min(10.0, lookaheadTime))
            updateLookaheadBuffer()
        }
    }
    
    // MARK: - Internal State
    
    private var sampleRate: Double = 44100.0
    private var envelopeFollower: EnvelopeFollower
    private var lookaheadBuffer: DelayBuffer
    private var gainReductionHistory: [Float] = []
    
    // Compressor curve parameters
    private var thresholdLinear: Float = 0.0
    private var slope: Float = 0.0
    private var kneeStart: Float = 0.0
    private var kneeEnd: Float = 0.0
    
    // Envelope coefficients
    private var attackCoeff: Float = 0.0
    private var releaseCoeff: Float = 0.0
    
    // Gain reduction metering
    @Published public var gainReduction: Float = 0.0
    @Published public var inputLevel: Float = 0.0
    @Published public var outputLevel: Float = 0.0
    
    // MARK: - Initialization
    
    public init() {
        self.envelopeFollower = EnvelopeFollower()
        self.lookaheadBuffer = DelayBuffer(maxDelay: 0.01, sampleRate: sampleRate)

        super.init(name: "Master Compressor")

        self.effectType = .compressor
        
        setupCompressor()
        updateCompressorParameters()
        updateEnvelopeCoefficients()
        updateLookaheadBuffer()
    }
    
    // MARK: - Audio Processing
    
    public override func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        guard !isBypassed && isEnabled else {
            return input
        }
        
        var output = input
        
        if input.channelCount == 2 {
            processStereoCompression(&output)
        } else {
            processMonoCompression(&output)
        }
        
        // Update meters
        updateMeters(input: input, output: output)
        
        return output
    }
    
    private func processStereoCompression(_ buffer: inout MachineProtocols.AudioBuffer) {
        let frameCount = buffer.frameCount
        
        for frame in 0..<frameCount {
            let leftIndex = frame * 2
            let rightIndex = frame * 2 + 1
            
            guard leftIndex < buffer.samples.count && rightIndex < buffer.samples.count else { break }
            
            let leftInput = buffer.samples[leftIndex]
            let rightInput = buffer.samples[rightIndex]
            
            // Calculate stereo peak level
            let peakLevel = max(abs(leftInput), abs(rightInput))
            
            // Apply lookahead delay to input
            let delayedLeft = lookaheadBuffer.process(leftInput, channel: 0)
            let delayedRight = lookaheadBuffer.process(rightInput, channel: 1)
            
            // Calculate gain reduction
            let gainReductionAmount = calculateGainReduction(peakLevel)
            
            // Apply envelope following
            let smoothedGainReduction = envelopeFollower.process(gainReductionAmount)
            
            // Apply compression
            let compressionGain = linearToDb(smoothedGainReduction)
            let makeupGainLinear = dbToLinear(makeupGain)
            
            buffer.samples[leftIndex] = delayedLeft * smoothedGainReduction * makeupGainLinear
            buffer.samples[rightIndex] = delayedRight * smoothedGainReduction * makeupGainLinear
            
            // Update gain reduction meter
            gainReduction = max(gainReduction * 0.99, -compressionGain)
        }
    }
    
    private func processMonoCompression(_ buffer: inout MachineProtocols.AudioBuffer) {
        for i in 0..<buffer.samples.count {
            let input = buffer.samples[i]
            let inputLevel = abs(input)
            
            // Apply lookahead delay
            let delayedInput = lookaheadBuffer.process(input, channel: 0)
            
            // Calculate gain reduction
            let gainReductionAmount = calculateGainReduction(inputLevel)
            
            // Apply envelope following
            let smoothedGainReduction = envelopeFollower.process(gainReductionAmount)
            
            // Apply compression and makeup gain
            let makeupGainLinear = dbToLinear(makeupGain)
            buffer.samples[i] = delayedInput * smoothedGainReduction * makeupGainLinear
            
            // Update gain reduction meter
            let compressionGain = linearToDb(smoothedGainReduction)
            gainReduction = max(gainReduction * 0.99, -compressionGain)
        }
    }
    
    // MARK: - Compression Calculation
    
    private func calculateGainReduction(_ inputLevel: Float) -> Float {
        let inputDb = linearToDb(inputLevel)
        
        guard inputDb > threshold else {
            return 1.0 // No compression needed
        }
        
        let overThreshold = inputDb - threshold
        var gainReductionDb: Float
        
        if kneeWidth > 0 && inputDb >= kneeStart && inputDb <= kneeEnd {
            // Soft knee compression
            let kneeRatio = (inputDb - kneeStart) / kneeWidth
            let softRatio = 1.0 + (ratio - 1.0) * kneeRatio * kneeRatio
            gainReductionDb = overThreshold * (1.0 - 1.0 / softRatio)
        } else if inputDb > kneeEnd {
            // Above knee - full ratio
            gainReductionDb = overThreshold * (1.0 - 1.0 / ratio)
        } else {
            // Below knee - no compression
            gainReductionDb = 0.0
        }
        
        return dbToLinear(-gainReductionDb)
    }
    
    // MARK: - Parameter Updates
    
    private func updateCompressorParameters() {
        thresholdLinear = dbToLinear(threshold)
        slope = 1.0 - 1.0 / ratio
        
        kneeStart = threshold - kneeWidth / 2.0
        kneeEnd = threshold + kneeWidth / 2.0
        
        if autoMakeupGain {
            calculateAutoMakeupGain()
        }
    }
    
    private func updateEnvelopeCoefficients() {
        attackCoeff = exp(-1.0 / (attackTime * 0.001 * Float(sampleRate)))
        releaseCoeff = exp(-1.0 / (releaseTime * 0.001 * Float(sampleRate)))
        
        envelopeFollower.setCoefficients(attack: attackCoeff, release: releaseCoeff)
    }
    
    private func updateLookaheadBuffer() {
        let lookaheadSamples = lookaheadTime * 0.001 * Float(sampleRate)
        lookaheadBuffer.setDelay(lookaheadSamples)
    }
    
    private func calculateAutoMakeupGain() {
        // Estimate makeup gain based on threshold and ratio
        let estimatedGainReduction = (threshold - (-20.0)) * (1.0 - 1.0 / ratio)
        makeupGain = estimatedGainReduction * 0.7 // Conservative estimate
    }
    
    // MARK: - Setup and Utility
    
    private func setupCompressor() {
        gainReductionHistory = Array(repeating: 0.0, count: 100)
    }
    
    private func updateMeters(input: MachineProtocols.AudioBuffer, output: MachineProtocols.AudioBuffer) {
        // Calculate input level
        var inputPeak: Float = 0.0
        for sample in input.samples {
            inputPeak = max(inputPeak, abs(sample))
        }
        self.inputLevel = inputPeak
        
        // Calculate output level
        var outputPeak: Float = 0.0
        for sample in output.samples {
            outputPeak = max(outputPeak, abs(sample))
        }
        self.outputLevel = outputPeak
    }
    
    // MARK: - Utility Functions
    
    private func dbToLinear(_ db: Float) -> Float {
        return pow(10.0, db / 20.0)
    }
    
    private func linearToDb(_ linear: Float) -> Float {
        return 20.0 * log10(max(linear, 1e-6))
    }
    
    // MARK: - State Management
    
    public override func resetEffectState() {
        super.resetEffectState()
        envelopeFollower.reset()
        lookaheadBuffer.reset()
        gainReduction = 0.0
        inputLevel = 0.0
        outputLevel = 0.0
    }
    
    // MARK: - Sample Rate
    
    public func setSampleRate(_ sampleRate: Double) {
        self.sampleRate = sampleRate
        lookaheadBuffer.setSampleRate(sampleRate)
        updateEnvelopeCoefficients()
        updateLookaheadBuffer()
    }
    
    // MARK: - Presets
    
    public enum CompressorPreset {
        case gentle
        case standard
        case aggressive
        case limiter
        case vocal
        case drum
        case master
        
        var parameters: (threshold: Float, ratio: Float, attack: Float, release: Float, knee: Float) {
            switch self {
            case .gentle:
                return (-18.0, 2.0, 10.0, 100.0, 4.0)
            case .standard:
                return (-12.0, 4.0, 5.0, 100.0, 2.0)
            case .aggressive:
                return (-8.0, 8.0, 2.0, 50.0, 1.0)
            case .limiter:
                return (-1.0, 20.0, 0.1, 10.0, 0.5)
            case .vocal:
                return (-15.0, 3.0, 8.0, 150.0, 3.0)
            case .drum:
                return (-10.0, 6.0, 1.0, 80.0, 2.0)
            case .master:
                return (-6.0, 3.0, 3.0, 200.0, 2.0)
            }
        }
    }
    
    /// Apply a compressor preset
    public func applyPreset(_ preset: CompressorPreset) {
        let params = preset.parameters
        threshold = params.threshold
        ratio = params.ratio
        attackTime = params.attack
        releaseTime = params.release
        kneeWidth = params.knee
    }
}

// MARK: - Supporting Classes

/// Envelope follower for smooth gain reduction
private class EnvelopeFollower {
    private var envelope: Float = 1.0
    private var attackCoeff: Float = 0.0
    private var releaseCoeff: Float = 0.0
    
    func process(_ input: Float) -> Float {
        let targetGain = input
        
        if targetGain < envelope {
            // Attack (gain reduction increasing)
            envelope = targetGain + (envelope - targetGain) * attackCoeff
        } else {
            // Release (gain reduction decreasing)
            envelope = targetGain + (envelope - targetGain) * releaseCoeff
        }
        
        return envelope
    }
    
    func setCoefficients(attack: Float, release: Float) {
        attackCoeff = attack
        releaseCoeff = release
    }
    
    func reset() {
        envelope = 1.0
    }
}

/// Delay buffer for lookahead processing
private class DelayBuffer {
    private var buffers: [[Float]] = []
    private var writeIndex: Int = 0
    private var delayInSamples: Int = 0
    private var sampleRate: Double
    
    init(maxDelay: Float, sampleRate: Double) {
        self.sampleRate = sampleRate
        let maxSamples = Int(maxDelay * Float(sampleRate))
        
        // Initialize buffers for stereo
        buffers = [
            Array(repeating: 0.0, count: maxSamples),
            Array(repeating: 0.0, count: maxSamples)
        ]
    }
    
    func process(_ input: Float, channel: Int) -> Float {
        guard channel < buffers.count else { return input }
        
        buffers[channel][writeIndex] = input
        
        let readIndex = (writeIndex - delayInSamples + buffers[channel].count) % buffers[channel].count
        let output = buffers[channel][readIndex]
        
        if channel == buffers.count - 1 {
            writeIndex = (writeIndex + 1) % buffers[0].count
        }
        
        return output
    }
    
    func setDelay(_ delaySamples: Float) {
        delayInSamples = Int(delaySamples)
        delayInSamples = max(0, min(delayInSamples, buffers[0].count - 1))
    }
    
    func setSampleRate(_ sampleRate: Double) {
        self.sampleRate = sampleRate
    }
    
    func reset() {
        for i in 0..<buffers.count {
            for j in 0..<buffers[i].count {
                buffers[i][j] = 0.0
            }
        }
        writeIndex = 0
    }
}
