import Foundation
import Accelerate
import MachineProtocols

/// High-quality digital delay effect for send processing
public class DelayEffect: BaseSendEffect {
    
    // MARK: - Parameters
    
    /// Delay time in seconds
    public var delayTime: Float = 0.25 {
        didSet {
            delayTime = max(0.001, min(2.0, delayTime))
            updateDelayParameters()
        }
    }
    
    /// Feedback amount (0.0 to 0.95)
    public var feedback: Float = 0.3 {
        didSet {
            feedback = max(0.0, min(0.95, feedback))
        }
    }
    
    /// High-frequency damping (0.0 to 1.0)
    public var damping: Float = 0.2 {
        didSet {
            damping = max(0.0, min(1.0, damping))
        }
    }
    
    /// Low-pass filter cutoff frequency
    public var filterCutoff: Float = 8000.0 {
        didSet {
            filterCutoff = max(100.0, min(20000.0, filterCutoff))
            updateFilterCoefficients()
        }
    }
    
    /// Stereo spread (0.0 = mono, 1.0 = full stereo)
    public var stereoSpread: Float = 0.5 {
        didSet {
            stereoSpread = max(0.0, min(1.0, stereoSpread))
        }
    }
    
    // MARK: - Internal State
    
    private var delayBuffer: [Float] = []
    private var bufferSize: Int = 0
    private var writeIndex: Int = 0
    private var readIndex: Float = 0.0
    private var sampleRate: Double = 44100.0
    
    // Filter state for damping
    private var filterState: [Float] = [0.0, 0.0] // Left, Right
    private var filterCoeff: Float = 0.0
    
    // Stereo delay offsets
    private var leftDelayOffset: Float = 0.0
    private var rightDelayOffset: Float = 0.0
    
    // MARK: - Initialization
    
    public init() {
        super.init(name: "Delay")
        self.returnLevel = 0.25
        setupDelayBuffer()
        updateFilterCoefficients()
        updateDelayParameters()
    }
    
    // MARK: - Audio Processing
    
    public override func processEffect(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        var output = input
        
        // Process stereo delay
        if input.channelCount == 2 {
            processStereoDelay(&output)
        } else {
            processMonoDelay(&output)
        }
        
        return output
    }
    
    private func processStereoDelay(_ buffer: inout MachineProtocols.AudioBuffer) {
        let frameCount = buffer.frameCount
        
        for frame in 0..<frameCount {
            let leftIndex = frame * 2
            let rightIndex = frame * 2 + 1
            
            guard leftIndex < buffer.samples.count && rightIndex < buffer.samples.count else { break }
            
            let leftInput = buffer.samples[leftIndex]
            let rightInput = buffer.samples[rightIndex]
            
            // Calculate delay tap positions
            let leftReadPos = calculateReadPosition(offset: leftDelayOffset)
            let rightReadPos = calculateReadPosition(offset: rightDelayOffset)
            
            // Read delayed samples with interpolation
            let leftDelayed = readDelayedSample(at: leftReadPos)
            let rightDelayed = readDelayedSample(at: rightReadPos)
            
            // Apply damping filter
            let leftFiltered = applyDampingFilter(leftDelayed, channel: 0)
            let rightFiltered = applyDampingFilter(rightDelayed, channel: 1)
            
            // Calculate feedback
            let leftFeedback = leftInput + (leftFiltered * feedback)
            let rightFeedback = rightInput + (rightFiltered * feedback)
            
            // Write to delay buffer
            writeToDelayBuffer(leftFeedback + rightFeedback * 0.5) // Mix to mono for buffer
            
            // Output delayed signals
            buffer.samples[leftIndex] = leftDelayed
            buffer.samples[rightIndex] = rightDelayed
            
            // Advance write index
            writeIndex = (writeIndex + 1) % bufferSize
        }
    }
    
    private func processMonoDelay(_ buffer: inout MachineProtocols.AudioBuffer) {
        for i in 0..<buffer.samples.count {
            let input = buffer.samples[i]
            
            // Read delayed sample
            let delayed = readDelayedSample(at: readIndex)
            
            // Apply damping filter
            let filtered = applyDampingFilter(delayed, channel: 0)
            
            // Calculate feedback
            let feedbackSample = input + (filtered * feedback)
            
            // Write to delay buffer
            writeToDelayBuffer(feedbackSample)
            
            // Output delayed signal
            buffer.samples[i] = delayed
            
            // Advance write index
            writeIndex = (writeIndex + 1) % bufferSize
        }
    }
    
    // MARK: - Delay Buffer Operations
    
    private func setupDelayBuffer() {
        // Maximum delay time of 2 seconds at 48kHz
        bufferSize = Int(sampleRate * 2.0)
        delayBuffer = Array(repeating: 0.0, count: bufferSize)
        writeIndex = 0
    }
    
    private func writeToDelayBuffer(_ sample: Float) {
        delayBuffer[writeIndex] = sample
    }
    
    private func readDelayedSample(at position: Float) -> Float {
        let intPos = Int(position)
        let fracPos = position - Float(intPos)
        
        let index1 = intPos % bufferSize
        let index2 = (intPos + 1) % bufferSize
        
        // Linear interpolation
        let sample1 = delayBuffer[index1]
        let sample2 = delayBuffer[index2]
        
        return sample1 + (sample2 - sample1) * fracPos
    }
    
    private func calculateReadPosition(offset: Float = 0.0) -> Float {
        let delaySamples = (delayTime + offset) * Float(sampleRate)
        let readPos = Float(writeIndex) - delaySamples
        
        return readPos < 0 ? readPos + Float(bufferSize) : readPos
    }
    
    // MARK: - Filtering
    
    private func applyDampingFilter(_ input: Float, channel: Int) -> Float {
        guard channel < filterState.count else { return input }
        
        // Simple one-pole low-pass filter
        filterState[channel] = filterState[channel] * filterCoeff + input * (1.0 - filterCoeff)
        return filterState[channel]
    }
    
    private func updateFilterCoefficients() {
        // Calculate filter coefficient for low-pass filter
        let omega = 2.0 * Float.pi * filterCutoff / Float(sampleRate)
        filterCoeff = exp(-omega)
    }
    
    private func updateDelayParameters() {
        // Update stereo spread offsets
        let spreadAmount = stereoSpread * 0.01 // Max 10ms spread
        leftDelayOffset = -spreadAmount * 0.5
        rightDelayOffset = spreadAmount * 0.5
        
        // Update read index
        readIndex = calculateReadPosition()
    }
    
    // MARK: - State Management
    
    public override func resetState() {
        super.resetState()
        
        // Clear delay buffer
        for i in 0..<delayBuffer.count {
            delayBuffer[i] = 0.0
        }
        
        // Reset indices
        writeIndex = 0
        readIndex = 0.0
        
        // Reset filter state
        for i in 0..<filterState.count {
            filterState[i] = 0.0
        }
    }
    
    // MARK: - Parameter Presets
    
    public enum DelayPreset {
        case short
        case medium
        case long
        case slapback
        case echo
        case ambient
        
        var parameters: (delayTime: Float, feedback: Float, damping: Float, filterCutoff: Float) {
            switch self {
            case .short:
                return (0.125, 0.2, 0.3, 12000.0)
            case .medium:
                return (0.25, 0.35, 0.4, 8000.0)
            case .long:
                return (0.5, 0.45, 0.5, 6000.0)
            case .slapback:
                return (0.08, 0.15, 0.2, 15000.0)
            case .echo:
                return (0.375, 0.6, 0.6, 5000.0)
            case .ambient:
                return (0.75, 0.7, 0.8, 4000.0)
            }
        }
    }
    
    /// Apply a delay preset
    public func applyPreset(_ preset: DelayPreset) {
        let params = preset.parameters
        delayTime = params.delayTime
        feedback = params.feedback
        damping = params.damping
        filterCutoff = params.filterCutoff
    }
    
    // MARK: - Utility Methods
    
    /// Set sample rate (call when audio engine sample rate changes)
    public func setSampleRate(_ sampleRate: Double) {
        self.sampleRate = sampleRate
        setupDelayBuffer()
        updateFilterCoefficients()
        updateDelayParameters()
    }
    
    /// Get current delay time in milliseconds
    public var delayTimeMs: Float {
        return delayTime * 1000.0
    }
    
    /// Set delay time in milliseconds
    public func setDelayTimeMs(_ timeMs: Float) {
        delayTime = timeMs / 1000.0
    }
    
    /// Get current delay time in BPM-synced note values
    public func setDelayTimeBPM(_ bpm: Float, noteValue: NoteValue) {
        let beatDuration = 60.0 / bpm
        delayTime = beatDuration * noteValue.multiplier
    }
    
    public enum NoteValue: Float {
        case sixteenth = 0.25
        case eighth = 0.5
        case quarter = 1.0
        case half = 2.0
        case whole = 4.0
        case dottedEighth = 0.75
        case dottedQuarter = 1.5
        
        var multiplier: Float {
            return rawValue
        }
    }
}

// MARK: - Update Send Effect Implementation

extension DelayEffect {
    /// Create a delay effect configured for send processing
    public static func createSendDelay() -> DelayEffect {
        let delay = DelayEffect()
        delay.applyPreset(.medium)
        delay.returnLevel = 0.25
        return delay
    }
}
