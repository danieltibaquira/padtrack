import Foundation
import Accelerate
import MachineProtocols

/// High-quality algorithmic reverb effect using Schroeder reverb topology
public class ReverbEffect: BaseSendEffect {
    
    // MARK: - Parameters
    
    /// Room size (0.0 to 1.0)
    public var roomSize: Float = 0.5 {
        didSet {
            roomSize = max(0.0, min(1.0, roomSize))
            updateReverbParameters()
        }
    }
    
    /// Damping amount (0.0 to 1.0)
    public var damping: Float = 0.5 {
        didSet {
            damping = max(0.0, min(1.0, damping))
            updateDampingFilters()
        }
    }
    
    /// Pre-delay time in seconds
    public var preDelay: Float = 0.02 {
        didSet {
            preDelay = max(0.0, min(0.1, preDelay))
            updatePreDelay()
        }
    }
    
    /// High-frequency rolloff (0.0 to 1.0)
    public var highCut: Float = 0.8 {
        didSet {
            highCut = max(0.0, min(1.0, highCut))
            updateInputFilter()
        }
    }
    
    /// Stereo width (0.0 = mono, 1.0 = full stereo)
    public var stereoWidth: Float = 1.0 {
        didSet {
            stereoWidth = max(0.0, min(1.0, stereoWidth))
        }
    }
    
    // MARK: - Internal Components
    
    private var combFilters: [CombFilter] = []
    private var allpassFilters: [AllpassFilter] = []
    private var preDelayBuffer: DelayLine
    private var inputFilter: OnePoleFilter
    private var sampleRate: Double = 44100.0
    
    // Reverb topology constants
    private let combDelayTimes: [Float] = [0.0297, 0.0371, 0.0411, 0.0437, 0.005, 0.0017, 0.0013, 0.001]
    private let allpassDelayTimes: [Float] = [0.005, 0.0017, 0.0013, 0.001]
    private let combGains: [Float] = [0.773, 0.802, 0.753, 0.733, 0.753, 0.733, 0.802, 0.773]
    
    // MARK: - Initialization
    
    public init() {
        self.preDelayBuffer = DelayLine(maxDelay: 0.1, sampleRate: sampleRate)
        self.inputFilter = OnePoleFilter()
        
        super.init(name: "Reverb")
        self.returnLevel = 0.2
        
        setupReverbNetwork()
        updateReverbParameters()
        updateDampingFilters()
        updateInputFilter()
    }
    
    // MARK: - Audio Processing
    
    public override func processEffect(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        var output = input
        
        if input.channelCount == 2 {
            processStereoReverb(&output)
        } else {
            processMonoReverb(&output)
        }
        
        return output
    }
    
    private func processStereoReverb(_ buffer: inout MachineProtocols.AudioBuffer) {
        let frameCount = buffer.frameCount
        
        for frame in 0..<frameCount {
            let leftIndex = frame * 2
            let rightIndex = frame * 2 + 1
            
            guard leftIndex < buffer.samples.count && rightIndex < buffer.samples.count else { break }
            
            let leftInput = buffer.samples[leftIndex]
            let rightInput = buffer.samples[rightIndex]
            
            // Mix to mono for reverb input
            let monoInput = (leftInput + rightInput) * 0.5
            
            // Apply input filtering
            let filteredInput = inputFilter.process(monoInput)
            
            // Apply pre-delay
            let preDelayedInput = preDelayBuffer.process(filteredInput)
            
            // Process through reverb network
            let reverbOutput = processReverbNetwork(preDelayedInput)
            
            // Create stereo output with width control
            let leftOutput = reverbOutput * (1.0 + stereoWidth) * 0.5
            let rightOutput = reverbOutput * (1.0 - stereoWidth) * 0.5
            
            buffer.samples[leftIndex] = leftOutput
            buffer.samples[rightIndex] = rightOutput
        }
    }
    
    private func processMonoReverb(_ buffer: inout MachineProtocols.AudioBuffer) {
        for i in 0..<buffer.samples.count {
            let input = buffer.samples[i]
            
            // Apply input filtering
            let filteredInput = inputFilter.process(input)
            
            // Apply pre-delay
            let preDelayedInput = preDelayBuffer.process(filteredInput)
            
            // Process through reverb network
            buffer.samples[i] = processReverbNetwork(preDelayedInput)
        }
    }
    
    private func processReverbNetwork(_ input: Float) -> Float {
        // Process through parallel comb filters
        var combSum: Float = 0.0
        for combFilter in combFilters {
            combSum += combFilter.process(input)
        }
        
        // Process through series allpass filters
        var allpassOutput = combSum
        for allpassFilter in allpassFilters {
            allpassOutput = allpassFilter.process(allpassOutput)
        }
        
        return allpassOutput
    }
    
    // MARK: - Setup Methods
    
    private func setupReverbNetwork() {
        // Create comb filters
        combFilters = []
        for i in 0..<combDelayTimes.count {
            let combFilter = CombFilter(
                delayTime: combDelayTimes[i],
                gain: combGains[i],
                sampleRate: sampleRate
            )
            combFilters.append(combFilter)
        }
        
        // Create allpass filters
        allpassFilters = []
        for delayTime in allpassDelayTimes {
            let allpassFilter = AllpassFilter(
                delayTime: delayTime,
                gain: 0.7,
                sampleRate: sampleRate
            )
            allpassFilters.append(allpassFilter)
        }
    }
    
    private func updateReverbParameters() {
        // Scale delay times based on room size
        let roomScale = 0.5 + roomSize * 0.5 // Scale from 0.5 to 1.0
        
        for (i, combFilter) in combFilters.enumerated() {
            let scaledDelayTime = combDelayTimes[i] * roomScale
            combFilter.setDelayTime(scaledDelayTime)
            
            // Adjust feedback based on room size
            let scaledGain = combGains[i] * (0.7 + roomSize * 0.25)
            combFilter.setGain(scaledGain)
        }
    }
    
    private func updateDampingFilters() {
        // Update damping in comb filters
        for combFilter in combFilters {
            combFilter.setDamping(damping)
        }
    }
    
    private func updatePreDelay() {
        preDelayBuffer.setDelayTime(preDelay)
    }
    
    private func updateInputFilter() {
        // Calculate cutoff frequency based on highCut parameter
        let cutoffFreq = 1000.0 + highCut * 15000.0 // 1kHz to 16kHz
        inputFilter.setCutoff(Float(cutoffFreq), sampleRate: Float(sampleRate))
    }
    
    // MARK: - State Management
    
    public override func resetState() {
        super.resetState()
        
        preDelayBuffer.reset()
        inputFilter.reset()
        
        for combFilter in combFilters {
            combFilter.reset()
        }
        
        for allpassFilter in allpassFilters {
            allpassFilter.reset()
        }
    }
    
    // MARK: - Preset Management
    
    public enum ReverbPreset {
        case room
        case hall
        case chamber
        case plate
        case spring
        case ambient
        
        var parameters: (roomSize: Float, damping: Float, preDelay: Float, highCut: Float) {
            switch self {
            case .room:
                return (0.3, 0.4, 0.01, 0.8)
            case .hall:
                return (0.8, 0.6, 0.03, 0.7)
            case .chamber:
                return (0.5, 0.3, 0.015, 0.9)
            case .plate:
                return (0.4, 0.2, 0.005, 0.95)
            case .spring:
                return (0.6, 0.8, 0.02, 0.6)
            case .ambient:
                return (0.9, 0.7, 0.05, 0.5)
            }
        }
    }
    
    /// Apply a reverb preset
    public func applyPreset(_ preset: ReverbPreset) {
        let params = preset.parameters
        roomSize = params.roomSize
        damping = params.damping
        preDelay = params.preDelay
        highCut = params.highCut
    }
    
    // MARK: - Utility Methods
    
    /// Set sample rate (call when audio engine sample rate changes)
    public func setSampleRate(_ sampleRate: Double) {
        self.sampleRate = sampleRate
        
        preDelayBuffer.setSampleRate(sampleRate)
        
        for combFilter in combFilters {
            combFilter.setSampleRate(sampleRate)
        }
        
        for allpassFilter in allpassFilters {
            allpassFilter.setSampleRate(sampleRate)
        }
        
        updateInputFilter()
    }
}

// MARK: - Supporting Classes

/// Comb filter with damping
private class CombFilter {
    private var delayLine: DelayLine
    private var dampingFilter: OnePoleFilter
    private var gain: Float
    
    init(delayTime: Float, gain: Float, sampleRate: Double) {
        self.delayLine = DelayLine(maxDelay: 0.1, sampleRate: sampleRate)
        self.dampingFilter = OnePoleFilter()
        self.gain = gain
        
        delayLine.setDelayTime(delayTime)
    }
    
    func process(_ input: Float) -> Float {
        let delayed = delayLine.process(input + dampingFilter.process(delayLine.tap()) * gain)
        return delayed
    }
    
    func setDelayTime(_ delayTime: Float) {
        delayLine.setDelayTime(delayTime)
    }
    
    func setGain(_ gain: Float) {
        self.gain = gain
    }
    
    func setDamping(_ damping: Float) {
        let cutoff = 1000.0 + (1.0 - damping) * 10000.0
        dampingFilter.setCutoff(Float(cutoff), sampleRate: Float(delayLine.sampleRate))
    }
    
    func setSampleRate(_ sampleRate: Double) {
        delayLine.setSampleRate(sampleRate)
    }
    
    func reset() {
        delayLine.reset()
        dampingFilter.reset()
    }
}

/// Allpass filter
private class AllpassFilter {
    private var delayLine: DelayLine
    private var gain: Float
    
    init(delayTime: Float, gain: Float, sampleRate: Double) {
        self.delayLine = DelayLine(maxDelay: 0.01, sampleRate: sampleRate)
        self.gain = gain
        
        delayLine.setDelayTime(delayTime)
    }
    
    func process(_ input: Float) -> Float {
        let delayed = delayLine.tap()
        let output = -gain * input + delayed
        delayLine.process(input + gain * delayed)
        return output
    }
    
    func setSampleRate(_ sampleRate: Double) {
        delayLine.setSampleRate(sampleRate)
    }
    
    func reset() {
        delayLine.reset()
    }
}

/// Simple delay line
private class DelayLine {
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private var delayInSamples: Int = 0
    var sampleRate: Double
    
    init(maxDelay: Float, sampleRate: Double) {
        self.sampleRate = sampleRate
        let maxSamples = Int(maxDelay * Float(sampleRate))
        self.buffer = Array(repeating: 0.0, count: maxSamples)
    }
    
    func process(_ input: Float) -> Float {
        buffer[writeIndex] = input
        
        let readIndex = (writeIndex - delayInSamples + buffer.count) % buffer.count
        let output = buffer[readIndex]
        
        writeIndex = (writeIndex + 1) % buffer.count
        
        return output
    }
    
    func tap() -> Float {
        let readIndex = (writeIndex - delayInSamples + buffer.count) % buffer.count
        return buffer[readIndex]
    }
    
    func setDelayTime(_ delayTime: Float) {
        delayInSamples = Int(delayTime * Float(sampleRate))
        delayInSamples = max(1, min(delayInSamples, buffer.count - 1))
    }
    
    func setSampleRate(_ sampleRate: Double) {
        self.sampleRate = sampleRate
    }
    
    func reset() {
        for i in 0..<buffer.count {
            buffer[i] = 0.0
        }
        writeIndex = 0
    }
}

/// One-pole filter
private class OnePoleFilter {
    private var state: Float = 0.0
    private var coeff: Float = 0.0
    
    func process(_ input: Float) -> Float {
        state = state * coeff + input * (1.0 - coeff)
        return state
    }
    
    func setCutoff(_ cutoff: Float, sampleRate: Float) {
        let omega = 2.0 * Float.pi * cutoff / sampleRate
        coeff = exp(-omega)
    }
    
    func reset() {
        state = 0.0
    }
}

// MARK: - Factory Method

extension ReverbEffect {
    /// Create a reverb effect configured for send processing
    public static func createSendReverb() -> ReverbEffect {
        let reverb = ReverbEffect()
        reverb.applyPreset(.hall)
        reverb.returnLevel = 0.2
        return reverb
    }
}
