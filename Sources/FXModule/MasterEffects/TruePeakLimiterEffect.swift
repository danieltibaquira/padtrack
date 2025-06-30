import Foundation
import Accelerate
import MachineProtocols

/// True peak limiter with look-ahead and oversampling for master bus processing
public class TruePeakLimiterEffect: FXProcessor, ObservableObject, @unchecked Sendable {
    
    // MARK: - Parameters
    
    /// Ceiling level in dB (-20 to 0)
    public var ceiling: Float = -0.1 {
        didSet {
            ceiling = max(-20.0, min(0.0, ceiling))
            updateLimiterParameters()
        }
    }
    
    /// Release time in milliseconds (1 to 1000)
    public var releaseTime: Float = 50.0 {
        didSet {
            releaseTime = max(1.0, min(1000.0, releaseTime))
            updateReleaseCoefficient()
        }
    }
    
    /// Look-ahead time in milliseconds (1 to 20)
    public var lookaheadTime: Float = 5.0 {
        didSet {
            lookaheadTime = max(1.0, min(20.0, lookaheadTime))
            updateLookaheadBuffer()
        }
    }
    
    /// Oversampling factor (1, 2, 4, or 8)
    public var oversamplingFactor: Int = 4 {
        didSet {
            oversamplingFactor = [1, 2, 4, 8].contains(oversamplingFactor) ? oversamplingFactor : 4
            setupOversampling()
        }
    }
    
    /// ISR (Inter-Sample Peak) detection
    public var isrDetection: Bool = true {
        didSet {
            setupOversampling()
        }
    }
    
    /// Soft knee amount (0.0 to 1.0)
    public var softKnee: Float = 0.5 {
        didSet {
            softKnee = max(0.0, min(1.0, softKnee))
        }
    }
    
    // MARK: - Internal State
    
    private var sampleRate: Double = 44100.0
    private var lookaheadBuffer: LookaheadBuffer
    private var gainReductionEnvelope: Float = 1.0
    private var releaseCoeff: Float = 0.0
    
    // Oversampling components
    private var upsampleFilter: OversamplingFilter
    private var downsampleFilter: OversamplingFilter
    private var oversampledBuffer: [Float] = []
    
    // True peak detection
    private var peakDetector: TruePeakDetector
    
    // Limiter parameters
    private var ceilingLinear: Float = 0.0
    private var kneeThreshold: Float = 0.0
    
    // Metering
    @Published public var gainReduction: Float = 0.0
    @Published public var truePeakLevel: Float = 0.0
    @Published public var outputLevel: Float = 0.0
    
    // MARK: - Initialization
    
    public init() {
        self.lookaheadBuffer = LookaheadBuffer(maxLookahead: 0.02, sampleRate: sampleRate)
        self.upsampleFilter = OversamplingFilter()
        self.downsampleFilter = OversamplingFilter()
        self.peakDetector = TruePeakDetector()

        super.init(name: "True Peak Limiter")

        self.effectType = .limiter
        
        setupLimiter()
        updateLimiterParameters()
        updateReleaseCoefficient()
        setupOversampling()
    }
    
    // MARK: - Audio Processing
    
    public override func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        guard !isBypassed && isEnabled else {
            return input
        }
        
        var output = input
        
        if isrDetection && oversamplingFactor > 1 {
            processWithOversampling(&output)
        } else {
            processDirectly(&output)
        }
        
        // Update meters
        updateMeters(input: input, output: output)
        
        return output
    }
    
    private func processWithOversampling(_ buffer: inout MachineProtocols.AudioBuffer) {
        let frameCount = buffer.frameCount
        let channelCount = buffer.channelCount
        
        // Prepare oversampled buffer
        let oversampledFrameCount = frameCount * oversamplingFactor
        oversampledBuffer = Array(repeating: 0.0, count: oversampledFrameCount * channelCount)
        
        // Upsample
        upsampleAudio(input: buffer.samples, output: &oversampledBuffer, factor: oversamplingFactor)
        
        // Process at higher sample rate
        processOversampledAudio(&oversampledBuffer, frameCount: oversampledFrameCount, channelCount: channelCount)
        
        // Downsample back to original rate
        downsampleAudio(input: oversampledBuffer, output: &buffer.samples, factor: oversamplingFactor)
    }
    
    private func processDirectly(_ buffer: inout MachineProtocols.AudioBuffer) {
        if buffer.channelCount == 2 {
            processStereoLimiting(&buffer)
        } else {
            processMonoLimiting(&buffer)
        }
    }
    
    private func processStereoLimiting(_ buffer: inout MachineProtocols.AudioBuffer) {
        let frameCount = buffer.frameCount
        
        for frame in 0..<frameCount {
            let leftIndex = frame * 2
            let rightIndex = frame * 2 + 1
            
            guard leftIndex < buffer.samples.count && rightIndex < buffer.samples.count else { break }
            
            let leftInput = buffer.samples[leftIndex]
            let rightInput = buffer.samples[rightIndex]
            
            // Apply lookahead delay
            let delayedLeft = lookaheadBuffer.process(leftInput, channel: 0)
            let delayedRight = lookaheadBuffer.process(rightInput, channel: 1)
            
            // Detect peak level (stereo peak)
            let peakLevel = max(abs(leftInput), abs(rightInput))
            let truePeak = peakDetector.detectTruePeak(peakLevel)
            
            // Calculate required gain reduction
            let requiredGainReduction = calculateGainReduction(truePeak)
            
            // Apply envelope following
            updateGainReductionEnvelope(requiredGainReduction)
            
            // Apply limiting
            buffer.samples[leftIndex] = delayedLeft * gainReductionEnvelope
            buffer.samples[rightIndex] = delayedRight * gainReductionEnvelope
            
            // Update gain reduction meter
            gainReduction = max(gainReduction * 0.99, 1.0 - gainReductionEnvelope)
        }
    }
    
    private func processMonoLimiting(_ buffer: inout MachineProtocols.AudioBuffer) {
        for i in 0..<buffer.samples.count {
            let input = buffer.samples[i]
            
            // Apply lookahead delay
            let delayedInput = lookaheadBuffer.process(input, channel: 0)
            
            // Detect peak level
            let truePeak = peakDetector.detectTruePeak(abs(input))
            
            // Calculate required gain reduction
            let requiredGainReduction = calculateGainReduction(truePeak)
            
            // Apply envelope following
            updateGainReductionEnvelope(requiredGainReduction)
            
            // Apply limiting
            buffer.samples[i] = delayedInput * gainReductionEnvelope
            
            // Update gain reduction meter
            gainReduction = max(gainReduction * 0.99, 1.0 - gainReductionEnvelope)
        }
    }
    
    private func processOversampledAudio(_ buffer: inout [Float], frameCount: Int, channelCount: Int) {
        // Process oversampled audio with higher precision
        let oversampledSampleRate = sampleRate * Double(oversamplingFactor)
        
        for frame in 0..<frameCount {
            if channelCount == 2 {
                let leftIndex = frame * 2
                let rightIndex = frame * 2 + 1
                
                guard leftIndex < buffer.count && rightIndex < buffer.count else { break }
                
                let leftSample = buffer[leftIndex]
                let rightSample = buffer[rightIndex]
                
                let peakLevel = max(abs(leftSample), abs(rightSample))
                let requiredGainReduction = calculateGainReduction(peakLevel)
                
                updateGainReductionEnvelope(requiredGainReduction)
                
                buffer[leftIndex] = leftSample * gainReductionEnvelope
                buffer[rightIndex] = rightSample * gainReductionEnvelope
            } else {
                let sample = buffer[frame]
                let requiredGainReduction = calculateGainReduction(abs(sample))
                
                updateGainReductionEnvelope(requiredGainReduction)
                
                buffer[frame] = sample * gainReductionEnvelope
            }
        }
    }
    
    // MARK: - Limiting Calculations
    
    private func calculateGainReduction(_ peakLevel: Float) -> Float {
        guard peakLevel > ceilingLinear else {
            return 1.0 // No limiting needed
        }
        
        let overThreshold = peakLevel - ceilingLinear
        
        if softKnee > 0.0 && peakLevel >= kneeThreshold {
            // Soft knee limiting
            let kneeRatio = min(1.0, (peakLevel - kneeThreshold) / (ceilingLinear - kneeThreshold))
            let softRatio = kneeRatio * kneeRatio * (3.0 - 2.0 * kneeRatio) // Smooth curve
            let gainReduction = ceilingLinear / (kneeThreshold + softRatio * (peakLevel - kneeThreshold))
            return gainReduction
        } else {
            // Hard limiting
            return ceilingLinear / peakLevel
        }
    }
    
    private func updateGainReductionEnvelope(_ targetGainReduction: Float) {
        if targetGainReduction < gainReductionEnvelope {
            // Instant attack for limiting
            gainReductionEnvelope = targetGainReduction
        } else {
            // Smooth release
            gainReductionEnvelope = targetGainReduction + (gainReductionEnvelope - targetGainReduction) * releaseCoeff
        }
    }
    
    // MARK: - Parameter Updates
    
    private func updateLimiterParameters() {
        ceilingLinear = pow(10.0, ceiling / 20.0)
        kneeThreshold = ceilingLinear * (1.0 - softKnee * 0.1) // 10% knee range max
    }
    
    private func updateReleaseCoefficient() {
        let releaseTimeSeconds = releaseTime * 0.001
        releaseCoeff = exp(-1.0 / (releaseTimeSeconds * Float(sampleRate)))
    }
    
    private func updateLookaheadBuffer() {
        let lookaheadSamples = lookaheadTime * 0.001 * Float(sampleRate)
        lookaheadBuffer.setLookahead(lookaheadSamples)
    }
    
    // MARK: - Oversampling
    
    private func setupOversampling() {
        let nyquist = Float(sampleRate) * 0.5
        let cutoff = nyquist * 0.45 // Anti-aliasing cutoff
        
        upsampleFilter.setupAntiAliasingFilter(cutoff: cutoff, sampleRate: Float(sampleRate))
        downsampleFilter.setupAntiAliasingFilter(cutoff: cutoff, sampleRate: Float(sampleRate * Double(oversamplingFactor)))
    }
    
    private func upsampleAudio(input: [Float], output: inout [Float], factor: Int) {
        // Simple zero-stuffing upsampling with filtering
        for i in 0..<input.count {
            let outputIndex = i * factor
            if outputIndex < output.count {
                output[outputIndex] = input[i]
                
                // Zero-stuff
                for j in 1..<factor {
                    if outputIndex + j < output.count {
                        output[outputIndex + j] = 0.0
                    }
                }
            }
        }
        
        // Apply anti-aliasing filter
        upsampleFilter.process(&output)
    }
    
    private func downsampleAudio(input: [Float], output: inout [Float], factor: Int) {
        // Apply anti-aliasing filter first
        var filteredInput = input
        downsampleFilter.process(&filteredInput)
        
        // Decimate
        for i in 0..<output.count {
            let inputIndex = i * factor
            if inputIndex < filteredInput.count {
                output[i] = filteredInput[inputIndex]
            }
        }
    }
    
    // MARK: - Setup and Utility
    
    private func setupLimiter() {
        updateLookaheadBuffer()
    }
    
    private func updateMeters(input: MachineProtocols.AudioBuffer, output: MachineProtocols.AudioBuffer) {
        // Calculate true peak level
        var inputPeak: Float = 0.0
        for sample in input.samples {
            inputPeak = max(inputPeak, abs(sample))
        }
        self.truePeakLevel = peakDetector.detectTruePeak(inputPeak)
        
        // Calculate output level
        var outputPeak: Float = 0.0
        for sample in output.samples {
            outputPeak = max(outputPeak, abs(sample))
        }
        self.outputLevel = outputPeak
    }
    
    // MARK: - State Management
    
    public override func resetEffectState() {
        super.resetEffectState()
        lookaheadBuffer.reset()
        peakDetector.reset()
        upsampleFilter.reset()
        downsampleFilter.reset()
        gainReductionEnvelope = 1.0
        gainReduction = 0.0
        truePeakLevel = 0.0
        outputLevel = 0.0
    }
    
    // MARK: - Sample Rate
    
    public func setSampleRate(_ sampleRate: Double) {
        self.sampleRate = sampleRate
        lookaheadBuffer.setSampleRate(sampleRate)
        updateReleaseCoefficient()
        updateLookaheadBuffer()
        setupOversampling()
    }
    
    // MARK: - Presets
    
    public enum LimiterPreset {
        case transparent
        case aggressive
        case broadcast
        case mastering
        case streaming
        
        var parameters: (ceiling: Float, release: Float, lookahead: Float, oversampling: Int, softKnee: Float) {
            switch self {
            case .transparent:
                return (-0.1, 100.0, 5.0, 4, 0.7)
            case .aggressive:
                return (-0.3, 30.0, 3.0, 2, 0.3)
            case .broadcast:
                return (-1.0, 50.0, 8.0, 4, 0.5)
            case .mastering:
                return (-0.1, 200.0, 10.0, 8, 0.8)
            case .streaming:
                return (-1.0, 75.0, 6.0, 4, 0.6)
            }
        }
    }
    
    /// Apply a limiter preset
    public func applyPreset(_ preset: LimiterPreset) {
        let params = preset.parameters
        ceiling = params.ceiling
        releaseTime = params.release
        lookaheadTime = params.lookahead
        oversamplingFactor = params.oversampling
        softKnee = params.softKnee
    }
}

// MARK: - Supporting Classes

/// Lookahead buffer for delay compensation
private class LookaheadBuffer {
    private var buffers: [[Float]] = []
    private var writeIndex: Int = 0
    private var lookaheadSamples: Int = 0
    private var sampleRate: Double
    
    init(maxLookahead: Float, sampleRate: Double) {
        self.sampleRate = sampleRate
        let maxSamples = Int(maxLookahead * Float(sampleRate))
        
        buffers = [
            Array(repeating: 0.0, count: maxSamples),
            Array(repeating: 0.0, count: maxSamples)
        ]
    }
    
    func process(_ input: Float, channel: Int) -> Float {
        guard channel < buffers.count else { return input }
        
        buffers[channel][writeIndex] = input
        
        let readIndex = (writeIndex - lookaheadSamples + buffers[channel].count) % buffers[channel].count
        let output = buffers[channel][readIndex]
        
        if channel == buffers.count - 1 {
            writeIndex = (writeIndex + 1) % buffers[0].count
        }
        
        return output
    }
    
    func setLookahead(_ samples: Float) {
        lookaheadSamples = Int(samples)
        lookaheadSamples = max(0, min(lookaheadSamples, buffers[0].count - 1))
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

/// True peak detector using oversampling
private class TruePeakDetector {
    private var oversampleBuffer: [Float] = []
    private let oversampleFactor = 4
    
    func detectTruePeak(_ input: Float) -> Float {
        // Simple true peak estimation
        // In a full implementation, this would use proper oversampling
        return input * 1.05 // Conservative estimate of potential inter-sample peaks
    }
    
    func reset() {
        oversampleBuffer.removeAll()
    }
}

/// Simple oversampling filter
private class OversamplingFilter {
    private var delayLine: [Float] = Array(repeating: 0.0, count: 64)
    private var writeIndex: Int = 0
    
    func setupAntiAliasingFilter(cutoff: Float, sampleRate: Float) {
        // Setup would configure filter coefficients
        // Simplified for this implementation
    }
    
    func process(_ buffer: inout [Float]) {
        // Simple low-pass filtering
        // In a full implementation, this would be a proper anti-aliasing filter
        for i in 1..<buffer.count {
            buffer[i] = buffer[i] * 0.8 + buffer[i-1] * 0.2
        }
    }
    
    func reset() {
        delayLine = Array(repeating: 0.0, count: delayLine.count)
        writeIndex = 0
    }
}
