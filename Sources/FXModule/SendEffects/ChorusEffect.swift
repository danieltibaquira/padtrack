import Foundation
import Accelerate
import MachineProtocols

/// High-quality chorus effect with multiple LFO-modulated delay lines
public class ChorusEffect: BaseSendEffect {
    
    // MARK: - Parameters
    
    /// LFO rate in Hz (0.1 to 10.0)
    public var rate: Float = 0.5 {
        didSet {
            rate = max(0.1, min(10.0, rate))
            updateLFORate()
        }
    }
    
    /// Modulation depth (0.0 to 1.0)
    public var depth: Float = 0.5 {
        didSet {
            depth = max(0.0, min(1.0, depth))
        }
    }
    
    /// Feedback amount (0.0 to 0.9)
    public var feedback: Float = 0.2 {
        didSet {
            feedback = max(0.0, min(0.9, feedback))
        }
    }
    
    /// Mix between dry and wet signal (0.0 = dry, 1.0 = wet)
    public var mix: Float = 0.5 {
        didSet {
            mix = max(0.0, min(1.0, mix))
        }
    }
    
    /// Number of chorus voices (1 to 4)
    public var voiceCount: Int = 2 {
        didSet {
            voiceCount = max(1, min(4, voiceCount))
            setupChorusVoices()
        }
    }
    
    /// Stereo spread (0.0 = mono, 1.0 = full stereo)
    public var stereoSpread: Float = 0.8 {
        didSet {
            stereoSpread = max(0.0, min(1.0, stereoSpread))
        }
    }
    
    // MARK: - Internal State
    
    private var chorusVoices: [ChorusVoice] = []
    private var sampleRate: Double = 44100.0
    private var lfoPhaseIncrement: Float = 0.0
    
    // Base delay time for chorus effect
    private let baseDelayTime: Float = 0.005 // 5ms
    private let maxModulationDepth: Float = 0.003 // 3ms max modulation
    
    // MARK: - Initialization
    
    public init() {
        super.init(name: "Chorus")
        self.returnLevel = 0.3
        
        setupChorusVoices()
        updateLFORate()
    }
    
    // MARK: - Audio Processing
    
    public override func processEffect(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        var output = input
        
        if input.channelCount == 2 {
            processStereoChorus(&output)
        } else {
            processMonoChorus(&output)
        }
        
        return output
    }
    
    private func processStereoChorus(_ buffer: inout MachineProtocols.AudioBuffer) {
        let frameCount = buffer.frameCount
        
        for frame in 0..<frameCount {
            let leftIndex = frame * 2
            let rightIndex = frame * 2 + 1
            
            guard leftIndex < buffer.samples.count && rightIndex < buffer.samples.count else { break }
            
            let leftInput = buffer.samples[leftIndex]
            let rightInput = buffer.samples[rightIndex]
            
            var leftOutput: Float = 0.0
            var rightOutput: Float = 0.0
            
            // Process through each chorus voice
            for (voiceIndex, voice) in chorusVoices.enumerated() {
                guard voiceIndex < voiceCount else { break }
                
                // Calculate stereo positioning for this voice
                let voicePan = calculateVoicePan(voiceIndex: voiceIndex)
                
                // Process left and right channels
                let voiceOutputLeft = voice.process(leftInput, channel: 0)
                let voiceOutputRight = voice.process(rightInput, channel: 1)
                
                // Apply stereo positioning
                leftOutput += voiceOutputLeft * (1.0 - voicePan)
                rightOutput += voiceOutputRight * voicePan
            }
            
            // Normalize by voice count
            if voiceCount > 0 {
                leftOutput /= Float(voiceCount)
                rightOutput /= Float(voiceCount)
            }
            
            // Apply mix
            buffer.samples[leftIndex] = leftInput * (1.0 - mix) + leftOutput * mix
            buffer.samples[rightIndex] = rightInput * (1.0 - mix) + rightOutput * mix
        }
    }
    
    private func processMonoChorus(_ buffer: inout MachineProtocols.AudioBuffer) {
        for i in 0..<buffer.samples.count {
            let input = buffer.samples[i]
            var output: Float = 0.0
            
            // Process through each chorus voice
            for (voiceIndex, voice) in chorusVoices.enumerated() {
                guard voiceIndex < voiceCount else { break }
                output += voice.process(input, channel: 0)
            }
            
            // Normalize by voice count
            if voiceCount > 0 {
                output /= Float(voiceCount)
            }
            
            // Apply mix
            buffer.samples[i] = input * (1.0 - mix) + output * mix
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupChorusVoices() {
        chorusVoices = []
        
        for i in 0..<4 { // Always create 4 voices, but only use voiceCount
            let voice = ChorusVoice(
                baseDelay: baseDelayTime + Float(i) * 0.002, // Spread base delays
                maxModulation: maxModulationDepth,
                phaseOffset: Float(i) * Float.pi * 0.5, // 90° phase offset between voices
                sampleRate: sampleRate
            )
            chorusVoices.append(voice)
        }
    }
    
    private func updateLFORate() {
        lfoPhaseIncrement = 2.0 * Float.pi * rate / Float(sampleRate)
        
        for voice in chorusVoices {
            voice.setLFORate(rate, sampleRate: sampleRate)
        }
    }
    
    private func calculateVoicePan(voiceIndex: Int) -> Float {
        guard voiceCount > 1 else { return 0.5 }
        
        let panPosition = Float(voiceIndex) / Float(voiceCount - 1) // 0.0 to 1.0
        return 0.5 + (panPosition - 0.5) * stereoSpread
    }
    
    // MARK: - State Management
    
    public override func resetState() {
        super.resetState()
        
        for voice in chorusVoices {
            voice.reset()
        }
    }
    
    // MARK: - Preset Management
    
    public enum ChorusPreset {
        case subtle
        case classic
        case wide
        case deep
        case shimmer
        case vintage
        
        var parameters: (rate: Float, depth: Float, feedback: Float, mix: Float, voiceCount: Int) {
            switch self {
            case .subtle:
                return (0.3, 0.3, 0.1, 0.3, 2)
            case .classic:
                return (0.5, 0.5, 0.2, 0.5, 2)
            case .wide:
                return (0.4, 0.6, 0.15, 0.6, 3)
            case .deep:
                return (0.2, 0.8, 0.3, 0.7, 3)
            case .shimmer:
                return (1.5, 0.4, 0.1, 0.4, 4)
            case .vintage:
                return (0.6, 0.7, 0.4, 0.6, 2)
            }
        }
    }
    
    /// Apply a chorus preset
    public func applyPreset(_ preset: ChorusPreset) {
        let params = preset.parameters
        rate = params.rate
        depth = params.depth
        feedback = params.feedback
        mix = params.mix
        voiceCount = params.voiceCount
    }
    
    // MARK: - Utility Methods
    
    /// Set sample rate (call when audio engine sample rate changes)
    public func setSampleRate(_ sampleRate: Double) {
        self.sampleRate = sampleRate
        
        for voice in chorusVoices {
            voice.setSampleRate(sampleRate)
        }
        
        updateLFORate()
    }
}

// MARK: - Chorus Voice

/// Individual chorus voice with LFO-modulated delay
private class ChorusVoice {
    private var delayBuffer: [Float] = []
    private var bufferSize: Int = 0
    private var writeIndex: Int = 0
    
    private var lfoPhase: Float = 0.0
    private var lfoPhaseIncrement: Float = 0.0
    private let phaseOffset: Float
    
    private let baseDelay: Float
    private let maxModulation: Float
    private var feedback: Float = 0.0
    private var sampleRate: Double
    
    init(baseDelay: Float, maxModulation: Float, phaseOffset: Float, sampleRate: Double) {
        self.baseDelay = baseDelay
        self.maxModulation = maxModulation
        self.phaseOffset = phaseOffset
        self.sampleRate = sampleRate
        self.lfoPhase = phaseOffset
        
        setupDelayBuffer()
    }
    
    func process(_ input: Float, channel: Int) -> Float {
        // Calculate current delay time with LFO modulation
        let lfoValue = sin(lfoPhase + phaseOffset)
        let modulationAmount = lfoValue * maxModulation
        let currentDelay = baseDelay + modulationAmount
        
        // Convert delay time to samples
        let delaySamples = currentDelay * Float(sampleRate)
        
        // Read delayed sample with interpolation
        let delayedSample = readDelayedSample(delaySamples)
        
        // Apply feedback
        let feedbackSample = input + delayedSample * feedback
        
        // Write to delay buffer
        delayBuffer[writeIndex] = feedbackSample
        
        // Advance indices
        writeIndex = (writeIndex + 1) % bufferSize
        lfoPhase += lfoPhaseIncrement
        
        // Keep LFO phase in range
        if lfoPhase > 2.0 * Float.pi {
            lfoPhase -= 2.0 * Float.pi
        }
        
        return delayedSample
    }
    
    private func setupDelayBuffer() {
        // Buffer size for maximum delay + modulation
        let maxDelay = baseDelay + maxModulation
        bufferSize = Int((maxDelay + 0.01) * Float(sampleRate)) // Add some headroom
        delayBuffer = Array(repeating: 0.0, count: bufferSize)
        writeIndex = 0
    }
    
    private func readDelayedSample(_ delaySamples: Float) -> Float {
        let readPos = Float(writeIndex) - delaySamples
        let adjustedReadPos = readPos < 0 ? readPos + Float(bufferSize) : readPos
        
        // Linear interpolation
        let intPos = Int(adjustedReadPos)
        let fracPos = adjustedReadPos - Float(intPos)
        
        let index1 = intPos % bufferSize
        let index2 = (intPos + 1) % bufferSize
        
        let sample1 = delayBuffer[index1]
        let sample2 = delayBuffer[index2]
        
        return sample1 + (sample2 - sample1) * fracPos
    }
    
    func setLFORate(_ rate: Float, sampleRate: Double) {
        lfoPhaseIncrement = 2.0 * Float.pi * rate / Float(sampleRate)
    }
    
    func setFeedback(_ feedback: Float) {
        self.feedback = feedback
    }
    
    func setSampleRate(_ sampleRate: Double) {
        self.sampleRate = sampleRate
        setupDelayBuffer()
    }
    
    func reset() {
        for i in 0..<delayBuffer.count {
            delayBuffer[i] = 0.0
        }
        writeIndex = 0
        lfoPhase = phaseOffset
    }
}

// MARK: - Factory Method

extension ChorusEffect {
    /// Create a chorus effect configured for send processing
    public static func createSendChorus() -> ChorusEffect {
        let chorus = ChorusEffect()
        chorus.applyPreset(.classic)
        chorus.returnLevel = 0.3
        return chorus
    }
}
