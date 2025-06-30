import Foundation
import MachineProtocols
import Combine
import Accelerate

/// Send routing system for global effects processing
public class SendRoutingSystem: ObservableObject {
    
    // MARK: - Properties
    
    /// Available send effects
    @Published public private(set) var sendEffects: [SendEffect] = []
    
    /// Send buses for routing audio
    private var sendBuses: [SendBus] = []
    
    /// Maximum number of send effects
    public let maxSendEffects: Int = 4
    
    /// Master send level
    @Published public var masterSendLevel: Float = 1.0
    
    /// Send system bypass
    @Published public var isBypassed: Bool = false
    
    // MARK: - Initialization
    
    public init() {
        setupDefaultSendEffects()
        setupSendBuses()
    }
    
    // MARK: - Send Effect Management
    
    /// Add a send effect to the system
    public func addSendEffect(_ effect: SendEffect) -> Bool {
        guard sendEffects.count < maxSendEffects else {
            print("Cannot add send effect: maximum number reached (\(maxSendEffects))")
            return false
        }
        
        sendEffects.append(effect)
        setupSendBus(for: effect)
        return true
    }
    
    /// Remove a send effect
    public func removeSendEffect(at index: Int) -> SendEffect? {
        guard index >= 0 && index < sendEffects.count else {
            return nil
        }
        
        let removedEffect = sendEffects.remove(at: index)
        removeSendBus(at: index)
        return removedEffect
    }
    
    /// Get send effect by index
    public func getSendEffect(at index: Int) -> SendEffect? {
        guard index >= 0 && index < sendEffects.count else {
            return nil
        }
        return sendEffects[index]
    }
    
    // MARK: - Audio Processing
    
    /// Process audio through the send system
    public func processSends(trackOutputs: [MachineProtocols.AudioBuffer], sendLevels: [[Float]]) -> [MachineProtocols.AudioBuffer] {
        guard !isBypassed else {
            return trackOutputs
        }
        
        var processedOutputs = trackOutputs
        
        // Process each send effect
        for (sendIndex, sendEffect) in sendEffects.enumerated() {
            guard sendIndex < sendBuses.count else { continue }
            
            let sendBus = sendBuses[sendIndex]
            
            // Mix track sends into the send bus
            sendBus.clearBuffer()
            
            for (trackIndex, trackOutput) in trackOutputs.enumerated() {
                guard trackIndex < sendLevels.count && sendIndex < sendLevels[trackIndex].count else {
                    continue
                }
                
                let sendLevel = sendLevels[trackIndex][sendIndex]
                sendBus.addTrackSend(trackOutput, level: sendLevel)
            }
            
            // Process the send bus through the effect
            let processedSend = sendEffect.process(input: sendBus.getBuffer())
            
            // Mix the processed send back into track outputs
            for i in 0..<processedOutputs.count {
                processedOutputs[i] = mixBuffers(
                    dry: processedOutputs[i],
                    wet: processedSend,
                    wetLevel: sendEffect.returnLevel
                )
            }
        }
        
        return processedOutputs
    }
    
    // MARK: - Send Bus Management
    
    private func setupSendBuses() {
        sendBuses = Array(0..<maxSendEffects).map { _ in SendBus() }
    }
    
    private func setupSendBus(for effect: SendEffect) {
        // Send bus is already created in setupSendBuses
        // This method can be used for additional configuration if needed
    }
    
    private func removeSendBus(at index: Int) {
        guard index >= 0 && index < sendBuses.count else { return }
        sendBuses[index].clearBuffer()
    }
    
    // MARK: - Utility Methods
    
    private func setupDefaultSendEffects() {
        // Create default send effects
        let delay = DelaySendEffect()
        let reverb = ReverbSendEffect()
        let chorus = ChorusSendEffect()
        
        _ = addSendEffect(delay)
        _ = addSendEffect(reverb)
        _ = addSendEffect(chorus)
    }
    
    private func mixBuffers(dry: MachineProtocols.AudioBuffer, wet: MachineProtocols.AudioBuffer, wetLevel: Float) -> MachineProtocols.AudioBuffer {
        var output = dry

        let wetGain = wetLevel * masterSendLevel
        let sampleCount = min(output.samples.count, wet.samples.count)

        // Use vectorized operations for better performance
        if sampleCount > 0 {
            var wetGainVector = wetGain
            var wetSamples = Array(wet.samples.prefix(sampleCount))

            // Scale wet samples
            vDSP_vsmul(wetSamples, 1, &wetGainVector, &wetSamples, 1, vDSP_Length(sampleCount))

            // Add to dry samples
            vDSP_vadd(output.samples, 1, wetSamples, 1, &output.samples, 1, vDSP_Length(sampleCount))
        }

        return output
    }
    
    // MARK: - Send Levels Management
    
    /// Set send level for a specific track and send
    public func setSendLevel(trackIndex: Int, sendIndex: Int, level: Float, in sendLevels: inout [[Float]]) {
        guard trackIndex >= 0 && trackIndex < sendLevels.count else { return }
        guard sendIndex >= 0 && sendIndex < sendLevels[trackIndex].count else { return }
        
        sendLevels[trackIndex][sendIndex] = max(0.0, min(1.0, level))
    }
    
    /// Get send level for a specific track and send
    public func getSendLevel(trackIndex: Int, sendIndex: Int, from sendLevels: [[Float]]) -> Float {
        guard trackIndex >= 0 && trackIndex < sendLevels.count else { return 0.0 }
        guard sendIndex >= 0 && sendIndex < sendLevels[trackIndex].count else { return 0.0 }
        
        return sendLevels[trackIndex][sendIndex]
    }
    
    /// Initialize send levels matrix for given number of tracks
    public func createSendLevelsMatrix(trackCount: Int) -> [[Float]] {
        return Array(0..<trackCount).map { _ in
            Array(repeating: 0.0, count: maxSendEffects)
        }
    }
}

// MARK: - Send Bus

/// Individual send bus for routing audio to effects
public class SendBus {
    private var buffer: MachineProtocols.AudioBuffer
    private let bufferSize: Int = 1024
    
    init() {
        // Create a default buffer - in real implementation this would be properly sized
        self.buffer = MockAudioBuffer(frameCount: bufferSize, channelCount: 2, sampleRate: 44100.0)
    }
    
    /// Clear the send bus buffer
    func clearBuffer() {
        for i in 0..<buffer.samples.count {
            buffer.samples[i] = 0.0
        }
    }
    
    /// Add a track's send to the bus
    func addTrackSend(_ trackBuffer: MachineProtocols.AudioBuffer, level: Float) {
        let sampleCount = min(buffer.samples.count, trackBuffer.samples.count)

        // Use vectorized operations for better performance
        if sampleCount > 0 && level > 0.001 { // Skip processing if level is negligible
            var levelVector = level
            var scaledSamples = Array(trackBuffer.samples.prefix(sampleCount))

            // Scale track samples by send level
            vDSP_vsmul(scaledSamples, 1, &levelVector, &scaledSamples, 1, vDSP_Length(sampleCount))

            // Add to send bus buffer
            vDSP_vadd(buffer.samples, 1, scaledSamples, 1, &buffer.samples, 1, vDSP_Length(sampleCount))
        }
    }
    
    /// Get the current buffer
    func getBuffer() -> MachineProtocols.AudioBuffer {
        return buffer
    }
}

// MARK: - Send Effect Protocol

/// Protocol for send effects
public protocol SendEffect: AnyObject {
    var name: String { get }
    var returnLevel: Float { get set }
    var isBypassed: Bool { get set }
    var isEnabled: Bool { get set }
    
    func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer
    func resetState()
}

// MARK: - Base Send Effect

/// Base class for send effects
public class BaseSendEffect: SendEffect {
    public let name: String
    public var returnLevel: Float = 0.3
    public var isBypassed: Bool = false
    public var isEnabled: Bool = true
    
    public init(name: String) {
        self.name = name
    }
    
    public func process(input: AudioBuffer) -> AudioBuffer {
        guard !isBypassed && isEnabled else {
            return input
        }
        
        return processEffect(input: input)
    }
    
    /// Override this method in subclasses
    public func processEffect(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        return input
    }
    
    public func resetState() {
        // Override in subclasses if needed
    }
}

// MARK: - Placeholder Send Effects

/// Delay send effect using DelayEffect
public class DelaySendEffect: BaseSendEffect {
    private let delayEffect: DelayEffect

    public init() {
        self.delayEffect = DelayEffect.createSendDelay()
        super.init(name: "Delay")
        self.returnLevel = 0.25
    }

    public override func processEffect(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        return delayEffect.processEffect(input: input)
    }

    public override func resetState() {
        super.resetState()
        delayEffect.resetState()
    }

    // Expose delay parameters
    public var delayTime: Float {
        get { delayEffect.delayTime }
        set { delayEffect.delayTime = newValue }
    }

    public var feedback: Float {
        get { delayEffect.feedback }
        set { delayEffect.feedback = newValue }
    }

    public var damping: Float {
        get { delayEffect.damping }
        set { delayEffect.damping = newValue }
    }
}

/// Reverb send effect using ReverbEffect
public class ReverbSendEffect: BaseSendEffect {
    private let reverbEffect: ReverbEffect

    public init() {
        self.reverbEffect = ReverbEffect.createSendReverb()
        super.init(name: "Reverb")
        self.returnLevel = 0.2
    }

    public override func processEffect(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        return reverbEffect.processEffect(input: input)
    }

    public override func resetState() {
        super.resetState()
        reverbEffect.resetState()
    }

    // Expose reverb parameters
    public var roomSize: Float {
        get { reverbEffect.roomSize }
        set { reverbEffect.roomSize = newValue }
    }

    public var damping: Float {
        get { reverbEffect.damping }
        set { reverbEffect.damping = newValue }
    }

    public var preDelay: Float {
        get { reverbEffect.preDelay }
        set { reverbEffect.preDelay = newValue }
    }
}

/// Chorus send effect using ChorusEffect
public class ChorusSendEffect: BaseSendEffect {
    private let chorusEffect: ChorusEffect

    public init() {
        self.chorusEffect = ChorusEffect.createSendChorus()
        super.init(name: "Chorus")
        self.returnLevel = 0.3
    }

    public override func processEffect(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        return chorusEffect.processEffect(input: input)
    }

    public override func resetState() {
        super.resetState()
        chorusEffect.resetState()
    }

    // Expose chorus parameters
    public var rate: Float {
        get { chorusEffect.rate }
        set { chorusEffect.rate = newValue }
    }

    public var depth: Float {
        get { chorusEffect.depth }
        set { chorusEffect.depth = newValue }
    }

    public var feedback: Float {
        get { chorusEffect.feedback }
        set { chorusEffect.feedback = newValue }
    }
}

// MARK: - Mock Audio Buffer (temporary)

private struct MockAudioBuffer: AudioBufferProtocol, @unchecked Sendable {
    let data: UnsafeMutablePointer<Float>
    let frameCount: Int
    let channelCount: Int
    let sampleRate: Double
    var samples: [Float]
    
    init(frameCount: Int, channelCount: Int, sampleRate: Double) {
        self.frameCount = frameCount
        self.channelCount = channelCount
        self.sampleRate = sampleRate
        self.samples = Array(repeating: 0.0, count: frameCount * channelCount)
        self.data = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount)
    }
}
