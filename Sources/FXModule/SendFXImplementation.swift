// SendFXImplementation.swift
// DigitonePad - FXModule
//
// Comprehensive send effects implementation with delay, reverb, chorus and tempo sync
// Provides professional-grade send/return effects processing

import Foundation
import Accelerate
import MachineProtocols
import AudioEngine

// MARK: - Send FX Configuration

/// Configuration for send effects system
public struct SendFXConfig: Codable {
    /// Delay configuration
    public var delay: DelayConfig = DelayConfig()
    
    /// Reverb configuration
    public var reverb: ReverbConfig = ReverbConfig()
    
    /// Chorus configuration
    public var chorus: ChorusConfig = ChorusConfig()
    
    /// Tempo sync configuration
    public var tempoSync: TempoSyncConfig = TempoSyncConfig()
    
    /// Send routing configuration
    public var routing: SendRoutingConfig = SendRoutingConfig()
    
    public init() {}
}

/// Delay effect configuration
public struct DelayConfig: Codable {
    public var enabled: Bool = true
    public var delayTime: Float = 0.25        // Seconds or note value
    public var feedback: Float = 0.3          // 0.0-0.95
    public var damping: Float = 0.2           // High-frequency damping
    public var filterCutoff: Float = 8000.0   // Hz
    public var stereoSpread: Float = 0.0      // -1.0 to 1.0
    public var tempoSynced: Bool = false      // Sync to tempo
    public var noteValue: NoteValue = .quarter
    public var wetLevel: Float = 1.0
    
    public init() {}
}

/// Reverb effect configuration
public struct ReverbConfig: Codable {
    public var enabled: Bool = true
    public var roomSize: Float = 0.5          // 0.0-1.0
    public var damping: Float = 0.5           // 0.0-1.0
    public var preDelay: Float = 0.02         // Seconds
    public var highCut: Float = 0.8           // 0.0-1.0
    public var lowCut: Float = 0.1            // 0.0-1.0
    public var diffusion: Float = 0.7         // 0.0-1.0
    public var modulation: Float = 0.1        // 0.0-1.0
    public var earlyReflections: Float = 0.3  // 0.0-1.0
    public var wetLevel: Float = 1.0
    
    public init() {}
}

/// Chorus effect configuration
public struct ChorusConfig: Codable {
    public var enabled: Bool = true
    public var rate: Float = 0.5              // Hz
    public var depth: Float = 0.3             // 0.0-1.0
    public var feedback: Float = 0.1          // 0.0-0.9
    public var delay: Float = 0.02            // Base delay in seconds
    public var voices: Int = 2                // Number of chorus voices
    public var stereoWidth: Float = 1.0       // 0.0-1.0
    public var tempoSynced: Bool = false      // Sync rate to tempo
    public var noteValue: NoteValue = .eighth
    public var wetLevel: Float = 1.0
    
    public init() {}
}

/// Tempo sync configuration
public struct TempoSyncConfig: Codable {
    public var enabled: Bool = true
    public var bpm: Float = 120.0             // Beats per minute
    public var timeSignature: TimeSignature = .fourFour
    public var syncSource: SyncSource = .internal
    
    public init() {}
}

/// Send routing configuration
public struct SendRoutingConfig: Codable {
    public var sendCount: Int = 3             // Number of send buses
    public var returnLevels: [Float] = [0.3, 0.2, 0.3]  // Return levels for each send
    public var crossFeedback: Float = 0.0     // Cross-feedback between sends
    public var masterSendLevel: Float = 1.0   // Master send level
    
    public init() {}
}

/// Musical note values for tempo sync
public enum NoteValue: Float, CaseIterable, Codable {
    case thirtysecond = 0.125
    case sixteenth = 0.25
    case eighth = 0.5
    case quarter = 1.0
    case half = 2.0
    case whole = 4.0
    case dottedSixteenth = 0.375
    case dottedEighth = 0.75
    case dottedQuarter = 1.5
    case tripletEighth = 0.333
    case tripletQuarter = 0.667
    
    public var description: String {
        switch self {
        case .thirtysecond: return "1/32"
        case .sixteenth: return "1/16"
        case .eighth: return "1/8"
        case .quarter: return "1/4"
        case .half: return "1/2"
        case .whole: return "1/1"
        case .dottedSixteenth: return "1/16."
        case .dottedEighth: return "1/8."
        case .dottedQuarter: return "1/4."
        case .tripletEighth: return "1/8T"
        case .tripletQuarter: return "1/4T"
        }
    }
}

/// Time signatures
public enum TimeSignature: String, CaseIterable, Codable {
    case fourFour = "4/4"
    case threeFour = "3/4"
    case twoFour = "2/4"
    case sixEight = "6/8"
    case twelveEight = "12/8"
    
    public var beatsPerBar: Float {
        switch self {
        case .fourFour: return 4.0
        case .threeFour: return 3.0
        case .twoFour: return 2.0
        case .sixEight: return 6.0
        case .twelveEight: return 12.0
        }
    }
}

/// Sync sources
public enum SyncSource: String, CaseIterable, Codable {
    case `internal` = "internal"
    case external = "external"
    case host = "host"
    
    public var description: String {
        switch self {
        case .internal: return "Internal"
        case .external: return "External"
        case .host: return "Host"
        }
    }
}

// MARK: - Send FX Processor

/// Comprehensive send effects processor
public final class SendFXProcessor: @unchecked Sendable {
    
    // MARK: - Configuration
    
    public var config: SendFXConfig {
        didSet {
            updateEffectChain()
        }
    }
    
    /// Sample rate
    private let sampleRate: Double
    
    /// Whether the entire send FX is bypassed
    public var isBypassed: Bool = false
    
    // MARK: - Internal Components
    
    private var delayProcessor: AdvancedDelayProcessor
    private var reverbProcessor: AdvancedReverbProcessor
    private var chorusProcessor: AdvancedChorusProcessor
    private var tempoSyncEngine: TempoSyncEngine
    private var sendRouter: SendRouter
    
    // MARK: - Audio Processing State
    
    private var processBuffer: [Float] = []
    private var tempBuffer: [Float] = []
    private var sendBuffers: [[Float]] = []
    
    // MARK: - Performance Optimization
    
    private var inputPeak: Float = 0.0
    private var outputPeak: Float = 0.0
    
    // MARK: - Initialization
    
    public init(config: SendFXConfig = SendFXConfig(), sampleRate: Double = 44100.0) {
        self.config = config
        self.sampleRate = sampleRate
        
        // Initialize processors
        self.delayProcessor = AdvancedDelayProcessor(sampleRate: sampleRate)
        self.reverbProcessor = AdvancedReverbProcessor(sampleRate: sampleRate)
        self.chorusProcessor = AdvancedChorusProcessor(sampleRate: sampleRate)
        self.tempoSyncEngine = TempoSyncEngine(sampleRate: sampleRate)
        self.sendRouter = SendRouter(sendCount: config.routing.sendCount)
        
        // Initialize buffers
        let maxBufferSize = Int(sampleRate * 0.1) // 100ms buffer
        processBuffer = [Float](repeating: 0.0, count: maxBufferSize)
        tempBuffer = [Float](repeating: 0.0, count: maxBufferSize)
        sendBuffers = Array(repeating: [Float](repeating: 0.0, count: maxBufferSize), count: config.routing.sendCount)
        
        updateEffectChain()
    }
    
    // MARK: - Audio Processing
    
    /// Process audio through send effects
    public func process(trackInputs: [MachineProtocols.AudioBuffer], sendLevels: [[Float]]) -> [MachineProtocols.AudioBuffer] {
        guard !isBypassed else { return trackInputs }
        
        let frameCount = trackInputs.first?.frameCount ?? 0
        let channelCount = trackInputs.first?.channelCount ?? 2
        
        // Update tempo sync
        tempoSyncEngine.updateTempo(config.tempoSync.bpm)
        
        // Route tracks to send buses
        let sendBusOutputs = sendRouter.routeToSends(
            trackInputs: trackInputs,
            sendLevels: sendLevels,
            frameCount: frameCount,
            channelCount: channelCount
        )
        
        // Process each send bus through its effect
        var processedSends: [MachineProtocols.AudioBuffer] = []
        
        for (sendIndex, sendBus) in sendBusOutputs.enumerated() {
            var processedSend = sendBus
            
            switch sendIndex {
            case 0: // Delay send
                if config.delay.enabled {
                    processedSend = processDelay(processedSend)
                }
                
            case 1: // Reverb send
                if config.reverb.enabled {
                    processedSend = processReverb(processedSend)
                }
                
            case 2: // Chorus send
                if config.chorus.enabled {
                    processedSend = processChorus(processedSend)
                }
                
            default:
                break
            }
            
            processedSends.append(processedSend)
        }
        
        // Mix processed sends back to track outputs
        return sendRouter.mixSendsToOutputs(
            trackInputs: trackInputs,
            processedSends: processedSends,
            returnLevels: config.routing.returnLevels
        )
    }
    
    // MARK: - Individual Effect Processing
    
    private func processDelay(_ input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        // Update delay time based on tempo sync
        if config.delay.tempoSynced {
            let syncedTime = tempoSyncEngine.calculateNoteTime(config.delay.noteValue)
            delayProcessor.setDelayTime(syncedTime)
        } else {
            delayProcessor.setDelayTime(config.delay.delayTime)
        }
        
        // Update other delay parameters
        delayProcessor.setFeedback(config.delay.feedback)
        delayProcessor.setDamping(config.delay.damping)
        delayProcessor.setFilterCutoff(config.delay.filterCutoff)
        delayProcessor.setStereoSpread(config.delay.stereoSpread)
        
        return delayProcessor.process(input)
    }
    
    private func processReverb(_ input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        // Update reverb parameters
        reverbProcessor.setRoomSize(config.reverb.roomSize)
        reverbProcessor.setDamping(config.reverb.damping)
        reverbProcessor.setPreDelay(config.reverb.preDelay)
        reverbProcessor.setHighCut(config.reverb.highCut)
        reverbProcessor.setLowCut(config.reverb.lowCut)
        reverbProcessor.setDiffusion(config.reverb.diffusion)
        reverbProcessor.setModulation(config.reverb.modulation)
        reverbProcessor.setEarlyReflections(config.reverb.earlyReflections)
        
        return reverbProcessor.process(input)
    }
    
    private func processChorus(_ input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        // Update chorus rate based on tempo sync
        if config.chorus.tempoSynced {
            let syncedRate = tempoSyncEngine.calculateNoteRate(config.chorus.noteValue)
            chorusProcessor.setRate(syncedRate)
        } else {
            chorusProcessor.setRate(config.chorus.rate)
        }
        
        // Update other chorus parameters
        chorusProcessor.setDepth(config.chorus.depth)
        chorusProcessor.setFeedback(config.chorus.feedback)
        chorusProcessor.setDelay(config.chorus.delay)
        chorusProcessor.setVoices(config.chorus.voices)
        chorusProcessor.setStereoWidth(config.chorus.stereoWidth)
        
        return chorusProcessor.process(input)
    }
    
    // MARK: - Control Methods
    
    /// Reset all effect states
    public func reset() {
        delayProcessor.reset()
        reverbProcessor.reset()
        chorusProcessor.reset()
        tempoSyncEngine.reset()
        sendRouter.reset()
        inputPeak = 0.0
        outputPeak = 0.0
    }
    
    /// Get current peak levels
    public func getPeakLevels() -> (input: Float, output: Float) {
        return (inputPeak, outputPeak)
    }
    
    /// Enable/disable specific send effect
    public func setEffectEnabled(_ effectType: SendEffectType, enabled: Bool) {
        switch effectType {
        case .delay:
            config.delay.enabled = enabled
        case .reverb:
            config.reverb.enabled = enabled
        case .chorus:
            config.chorus.enabled = enabled
        }
    }
    
    /// Check if specific effect is enabled
    public func isEffectEnabled(_ effectType: SendEffectType) -> Bool {
        switch effectType {
        case .delay:
            return config.delay.enabled
        case .reverb:
            return config.reverb.enabled
        case .chorus:
            return config.chorus.enabled
        }
    }
    
    /// Set tempo for tempo-synced effects
    public func setTempo(_ bpm: Float) {
        config.tempoSync.bpm = max(60.0, min(200.0, bpm))
        tempoSyncEngine.updateTempo(config.tempoSync.bpm)
    }
    
    /// Get current tempo
    public func getTempo() -> Float {
        return config.tempoSync.bpm
    }
    
    // MARK: - Private Methods
    
    private func updateEffectChain() {
        // Update individual processors with new configuration
        delayProcessor.updateConfig(config.delay)
        reverbProcessor.updateConfig(config.reverb)
        chorusProcessor.updateConfig(config.chorus)
        tempoSyncEngine.updateConfig(config.tempoSync)
        sendRouter.updateConfig(config.routing)
    }
}

/// Send effect types
public enum SendEffectType: String, CaseIterable, Codable {
    case delay = "delay"
    case reverb = "reverb"
    case chorus = "chorus"
    
    public var description: String {
        switch self {
        case .delay: return "Delay"
        case .reverb: return "Reverb"
        case .chorus: return "Chorus"
        }
    }
}

// MARK: - Advanced Delay Processor

/// High-quality delay processor with tempo sync
private final class AdvancedDelayProcessor: @unchecked Sendable {

    private let sampleRate: Double
    private var delayBuffer: [Float] = []
    private var writeIndex: Int = 0
    private var delayTime: Float = 0.25
    private var feedback: Float = 0.3
    private var damping: Float = 0.2
    private var filterCutoff: Float = 8000.0
    private var stereoSpread: Float = 0.0

    // Filter state
    private var dampingFilterState: [Float] = [0.0, 0.0]
    private var dampingCoeff: Float = 0.5

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        let maxDelay = Int(sampleRate * 2.0) // 2 second max delay
        delayBuffer = [Float](repeating: 0.0, count: maxDelay)
        updateDampingFilter()
    }

    func setDelayTime(_ time: Float) {
        delayTime = max(0.001, min(2.0, time))
    }

    func setFeedback(_ feedback: Float) {
        self.feedback = max(0.0, min(0.95, feedback))
    }

    func setDamping(_ damping: Float) {
        self.damping = max(0.0, min(1.0, damping))
        updateDampingFilter()
    }

    func setFilterCutoff(_ cutoff: Float) {
        filterCutoff = max(100.0, min(20000.0, cutoff))
        updateDampingFilter()
    }

    func setStereoSpread(_ spread: Float) {
        stereoSpread = max(-1.0, min(1.0, spread))
    }

    func updateConfig(_ config: DelayConfig) {
        setFeedback(config.feedback)
        setDamping(config.damping)
        setFilterCutoff(config.filterCutoff)
        setStereoSpread(config.stereoSpread)
    }

    func process(_ input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        let frameCount = input.frameCount
        let channelCount = input.channelCount

        let outputData = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount)
        outputData.initialize(repeating: 0.0, count: frameCount * channelCount)

        let delaySamples = Int(delayTime * Float(sampleRate))

        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                let inputIndex = frame * channelCount + channel
                let inputSample = input.data[inputIndex]

                // Calculate read index with stereo spread
                let spreadOffset = channel == 1 ? Int(stereoSpread * Float(delaySamples) * 0.1) : 0
                let readIndex = (writeIndex - delaySamples + spreadOffset + delayBuffer.count) % delayBuffer.count

                // Read delayed sample
                let delayedSample = delayBuffer[readIndex]

                // Apply damping filter
                let filteredSample = applyDampingFilter(delayedSample, channel: channel)

                // Calculate feedback
                let feedbackSample = inputSample + filteredSample * feedback

                // Write to delay buffer
                delayBuffer[writeIndex] = feedbackSample

                // Output delayed signal
                outputData[inputIndex] = filteredSample
            }

            writeIndex = (writeIndex + 1) % delayBuffer.count
        }

        return AudioEngine.AudioBuffer(
            data: outputData,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: input.sampleRate
        )
    }

    func reset() {
        delayBuffer.fill(with: 0.0)
        writeIndex = 0
        dampingFilterState = [0.0, 0.0]
    }

    private func updateDampingFilter() {
        let omega = 2.0 * Float.pi * filterCutoff / Float(sampleRate)
        dampingCoeff = tan(omega * 0.5)
    }

    private func applyDampingFilter(_ input: Float, channel: Int) -> Float {
        let channelIndex = min(channel, 1)
        let k = dampingCoeff * damping
        let a = 1.0 / (1.0 + k)

        let output = a * (input + k * dampingFilterState[channelIndex])
        dampingFilterState[channelIndex] = output

        return output
    }
}

// MARK: - Advanced Reverb Processor

/// High-quality reverb processor with modulation
private final class AdvancedReverbProcessor: @unchecked Sendable {

    private let sampleRate: Double
    private var roomSize: Float = 0.5
    private var damping: Float = 0.5
    private var preDelay: Float = 0.02
    private var highCut: Float = 0.8
    private var lowCut: Float = 0.1
    private var diffusion: Float = 0.7
    private var modulation: Float = 0.1
    private var earlyReflections: Float = 0.3

    // Reverb network components
    private var preDelayBuffer: [Float] = []
    private var preDelayIndex: Int = 0
    private var combFilters: [CombFilter] = []
    private var allpassFilters: [AllpassFilter] = []

    // Modulation
    private var modulationPhase: Float = 0.0
    private let modulationRate: Float = 0.1

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        setupReverbNetwork()
    }

    func setRoomSize(_ size: Float) {
        roomSize = max(0.0, min(1.0, size))
        updateCombFilters()
    }

    func setDamping(_ damping: Float) {
        self.damping = max(0.0, min(1.0, damping))
        updateCombFilters()
    }

    func setPreDelay(_ delay: Float) {
        preDelay = max(0.0, min(0.1, delay))
        updatePreDelay()
    }

    func setHighCut(_ cut: Float) {
        highCut = max(0.0, min(1.0, cut))
    }

    func setLowCut(_ cut: Float) {
        lowCut = max(0.0, min(1.0, cut))
    }

    func setDiffusion(_ diffusion: Float) {
        self.diffusion = max(0.0, min(1.0, diffusion))
        updateAllpassFilters()
    }

    func setModulation(_ modulation: Float) {
        self.modulation = max(0.0, min(1.0, modulation))
    }

    func setEarlyReflections(_ reflections: Float) {
        earlyReflections = max(0.0, min(1.0, reflections))
    }

    func updateConfig(_ config: ReverbConfig) {
        setRoomSize(config.roomSize)
        setDamping(config.damping)
        setPreDelay(config.preDelay)
        setHighCut(config.highCut)
        setLowCut(config.lowCut)
        setDiffusion(config.diffusion)
        setModulation(config.modulation)
        setEarlyReflections(config.earlyReflections)
    }

    func process(_ input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        let frameCount = input.frameCount
        let channelCount = input.channelCount

        let outputData = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount)
        outputData.initialize(repeating: 0.0, count: frameCount * channelCount)

        for frame in 0..<frameCount {
            // Update modulation
            modulationPhase += modulationRate / Float(sampleRate)
            if modulationPhase > 2.0 * Float.pi {
                modulationPhase -= 2.0 * Float.pi
            }

            for channel in 0..<channelCount {
                let inputIndex = frame * channelCount + channel
                let inputSample = input.data[inputIndex]

                // Apply pre-delay
                let preDelayedSample = applyPreDelay(inputSample)

                // Process through reverb network
                var reverbOutput: Float = 0.0

                // Comb filters (parallel)
                for combFilter in combFilters {
                    reverbOutput += combFilter.process(preDelayedSample)
                }
                reverbOutput /= Float(combFilters.count)

                // Allpass filters (series)
                for allpassFilter in allpassFilters {
                    reverbOutput = allpassFilter.process(reverbOutput)
                }

                // Apply modulation
                let modulationAmount = sin(modulationPhase) * modulation * 0.1
                reverbOutput *= (1.0 + modulationAmount)

                outputData[inputIndex] = reverbOutput
            }
        }

        return AudioEngine.AudioBuffer(
            data: outputData,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: input.sampleRate
        )
    }

    func reset() {
        preDelayBuffer.fill(with: 0.0)
        preDelayIndex = 0
        modulationPhase = 0.0

        for combFilter in combFilters {
            combFilter.reset()
        }

        for allpassFilter in allpassFilters {
            allpassFilter.reset()
        }
    }

    private func setupReverbNetwork() {
        // Setup pre-delay buffer
        let maxPreDelay = Int(sampleRate * 0.1) // 100ms max
        preDelayBuffer = [Float](repeating: 0.0, count: maxPreDelay)

        // Setup comb filters (Schroeder reverb topology)
        let combDelays: [Float] = [0.0297, 0.0371, 0.0411, 0.0437, 0.005, 0.0017]
        combFilters = combDelays.map { delay in
            CombFilter(delay: delay, sampleRate: sampleRate)
        }

        // Setup allpass filters
        let allpassDelays: [Float] = [0.005, 0.0017, 0.0028]
        allpassFilters = allpassDelays.map { delay in
            AllpassFilter(delay: delay, sampleRate: sampleRate)
        }

        updateCombFilters()
        updateAllpassFilters()
        updatePreDelay()
    }

    private func updatePreDelay() {
        // Pre-delay buffer is already allocated
    }

    private func updateCombFilters() {
        for combFilter in combFilters {
            combFilter.setFeedback(roomSize * 0.84)
            combFilter.setDamping(damping)
        }
    }

    private func updateAllpassFilters() {
        for allpassFilter in allpassFilters {
            allpassFilter.setFeedback(diffusion * 0.7)
        }
    }

    private func applyPreDelay(_ input: Float) -> Float {
        let delaySamples = Int(preDelay * Float(sampleRate))
        let readIndex = (preDelayIndex - delaySamples + preDelayBuffer.count) % preDelayBuffer.count

        let output = preDelayBuffer[readIndex]
        preDelayBuffer[preDelayIndex] = input

        preDelayIndex = (preDelayIndex + 1) % preDelayBuffer.count

        return output
    }
}

// MARK: - Advanced Chorus Processor

/// High-quality chorus processor with multiple voices
private final class AdvancedChorusProcessor: @unchecked Sendable {

    private let sampleRate: Double
    private var rate: Float = 0.5
    private var depth: Float = 0.3
    private var feedback: Float = 0.1
    private var delay: Float = 0.02
    private var voices: Int = 2
    private var stereoWidth: Float = 1.0

    // Chorus voices
    private var chorusVoices: [ChorusVoice] = []

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        setupChorusVoices()
    }

    func setRate(_ rate: Float) {
        self.rate = max(0.1, min(10.0, rate))
        updateChorusVoices()
    }

    func setDepth(_ depth: Float) {
        self.depth = max(0.0, min(1.0, depth))
        updateChorusVoices()
    }

    func setFeedback(_ feedback: Float) {
        self.feedback = max(0.0, min(0.9, feedback))
        updateChorusVoices()
    }

    func setDelay(_ delay: Float) {
        self.delay = max(0.001, min(0.1, delay))
        updateChorusVoices()
    }

    func setVoices(_ voices: Int) {
        self.voices = max(1, min(8, voices))
        setupChorusVoices()
    }

    func setStereoWidth(_ width: Float) {
        stereoWidth = max(0.0, min(1.0, width))
        updateChorusVoices()
    }

    func updateConfig(_ config: ChorusConfig) {
        setDepth(config.depth)
        setFeedback(config.feedback)
        setDelay(config.delay)
        setVoices(config.voices)
        setStereoWidth(config.stereoWidth)
    }

    func process(_ input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        let frameCount = input.frameCount
        let channelCount = input.channelCount

        let outputData = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount)
        outputData.initialize(repeating: 0.0, count: frameCount * channelCount)

        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                let inputIndex = frame * channelCount + channel
                let inputSample = input.data[inputIndex]

                var chorusOutput: Float = 0.0

                // Process through each chorus voice
                for (voiceIndex, voice) in chorusVoices.enumerated() {
                    let voiceOutput = voice.process(inputSample)

                    // Apply stereo positioning
                    let pan = calculateVoicePan(voiceIndex: voiceIndex, channel: channel)
                    chorusOutput += voiceOutput * pan
                }

                // Normalize by voice count
                if voices > 0 {
                    chorusOutput /= Float(voices)
                }

                outputData[inputIndex] = chorusOutput
            }
        }

        return AudioEngine.AudioBuffer(
            data: outputData,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: input.sampleRate
        )
    }

    func reset() {
        for voice in chorusVoices {
            voice.reset()
        }
    }

    private func setupChorusVoices() {
        chorusVoices.removeAll()

        for i in 0..<voices {
            let voice = ChorusVoice(
                baseDelay: delay,
                rate: rate,
                depth: depth,
                feedback: feedback,
                phaseOffset: Float(i) * 2.0 * Float.pi / Float(voices),
                sampleRate: sampleRate
            )
            chorusVoices.append(voice)
        }
    }

    private func updateChorusVoices() {
        for (i, voice) in chorusVoices.enumerated() {
            voice.setRate(rate)
            voice.setDepth(depth)
            voice.setFeedback(feedback)
            voice.setBaseDelay(delay)
            voice.setPhaseOffset(Float(i) * 2.0 * Float.pi / Float(voices))
        }
    }

    private func calculateVoicePan(voiceIndex: Int, channel: Int) -> Float {
        if voices == 1 { return 1.0 }

        let voicePosition = Float(voiceIndex) / Float(voices - 1) // 0.0 to 1.0
        let panPosition = (voicePosition - 0.5) * stereoWidth // -stereoWidth/2 to +stereoWidth/2

        if channel == 0 { // Left channel
            return 1.0 - max(0.0, panPosition)
        } else { // Right channel
            return 1.0 + min(0.0, panPosition)
        }
    }
}

// MARK: - Tempo Sync Engine

/// Engine for tempo synchronization
private final class TempoSyncEngine: @unchecked Sendable {

    private let sampleRate: Double
    private var bpm: Float = 120.0
    private var timeSignature: TimeSignature = .fourFour
    private var syncSource: SyncSource = .internal

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func updateTempo(_ bpm: Float) {
        self.bpm = max(60.0, min(200.0, bpm))
    }

    func updateConfig(_ config: TempoSyncConfig) {
        updateTempo(config.bpm)
        timeSignature = config.timeSignature
        syncSource = config.syncSource
    }

    func calculateNoteTime(_ noteValue: NoteValue) -> Float {
        let beatDuration = 60.0 / bpm // Duration of one quarter note in seconds
        return beatDuration * noteValue.rawValue
    }

    func calculateNoteRate(_ noteValue: NoteValue) -> Float {
        let noteTime = calculateNoteTime(noteValue)
        return 1.0 / noteTime // Rate in Hz
    }

    func reset() {
        // Reset any internal timing state if needed
    }
}

// MARK: - Send Router

/// Routes audio to send buses and mixes returns
private final class SendRouter: @unchecked Sendable {

    private let sendCount: Int
    private var sendBuffers: [[Float]] = []

    init(sendCount: Int) {
        self.sendCount = sendCount
        setupSendBuffers()
    }

    func routeToSends(trackInputs: [MachineProtocols.AudioBuffer], sendLevels: [[Float]], frameCount: Int, channelCount: Int) -> [MachineProtocols.AudioBuffer] {
        // Clear send buffers
        for i in 0..<sendCount {
            sendBuffers[i].fill(with: 0.0)
        }

        // Route tracks to sends
        for (trackIndex, trackInput) in trackInputs.enumerated() {
            guard trackIndex < sendLevels.count else { continue }

            for sendIndex in 0..<min(sendCount, sendLevels[trackIndex].count) {
                let sendLevel = sendLevels[trackIndex][sendIndex]
                if sendLevel > 0.001 {
                    addToSendBus(trackInput, sendIndex: sendIndex, level: sendLevel)
                }
            }
        }

        // Convert send buffers to AudioBuffers
        return sendBuffers.enumerated().map { index, buffer in
            let data = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount)
            let copyCount = min(buffer.count, frameCount * channelCount)
            data.initialize(from: buffer, count: copyCount)

            return AudioEngine.AudioBuffer(
                data: data,
                frameCount: frameCount,
                channelCount: channelCount,
                sampleRate: trackInputs.first?.sampleRate ?? 44100.0
            )
        }
    }

    func mixSendsToOutputs(trackInputs: [MachineProtocols.AudioBuffer], processedSends: [MachineProtocols.AudioBuffer], returnLevels: [Float]) -> [MachineProtocols.AudioBuffer] {
        var outputs = trackInputs

        // Mix processed sends back to track outputs
        for (sendIndex, processedSend) in processedSends.enumerated() {
            guard sendIndex < returnLevels.count else { continue }

            let returnLevel = returnLevels[sendIndex]
            if returnLevel > 0.001 {
                // Mix to all track outputs (or implement more sophisticated routing)
                for trackIndex in 0..<outputs.count {
                    outputs[trackIndex] = mixBuffers(outputs[trackIndex], processedSend, level: returnLevel)
                }
            }
        }

        return outputs
    }

    func updateConfig(_ config: SendRoutingConfig) {
        // Update routing configuration if needed
    }

    func reset() {
        for i in 0..<sendCount {
            sendBuffers[i].fill(with: 0.0)
        }
    }

    private func setupSendBuffers() {
        let maxBufferSize = 4096 // Reasonable buffer size
        sendBuffers = Array(repeating: [Float](repeating: 0.0, count: maxBufferSize), count: sendCount)
    }

    private func addToSendBus(_ trackBuffer: MachineProtocols.AudioBuffer, sendIndex: Int, level: Float) {
        guard sendIndex < sendBuffers.count else { return }

        let sampleCount = min(sendBuffers[sendIndex].count, trackBuffer.frameCount * trackBuffer.channelCount)

        for i in 0..<sampleCount {
            sendBuffers[sendIndex][i] += trackBuffer.data[i] * level
        }
    }

    private func mixBuffers(_ buffer1: MachineProtocols.AudioBuffer, _ buffer2: MachineProtocols.AudioBuffer, level: Float) -> MachineProtocols.AudioBuffer {
        let frameCount = min(buffer1.frameCount, buffer2.frameCount)
        let channelCount = min(buffer1.channelCount, buffer2.channelCount)

        let outputData = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount)

        for i in 0..<frameCount * channelCount {
            outputData[i] = buffer1.data[i] + buffer2.data[i] * level
        }

        return AudioEngine.AudioBuffer(
            data: outputData,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: buffer1.sampleRate
        )
    }
}

// MARK: - Supporting Filter Classes

/// Comb filter for reverb
private final class CombFilter: @unchecked Sendable {

    private var buffer: [Float]
    private var index: Int = 0
    private var feedback: Float = 0.5
    private var damping: Float = 0.5
    private var filterState: Float = 0.0

    init(delay: Float, sampleRate: Double) {
        let bufferSize = Int(delay * Float(sampleRate))
        buffer = [Float](repeating: 0.0, count: max(1, bufferSize))
    }

    func setFeedback(_ feedback: Float) {
        self.feedback = max(0.0, min(0.99, feedback))
    }

    func setDamping(_ damping: Float) {
        self.damping = max(0.0, min(1.0, damping))
    }

    func process(_ input: Float) -> Float {
        let output = buffer[index]

        // Apply damping filter
        filterState += damping * (output - filterState)

        // Write input + feedback to buffer
        buffer[index] = input + filterState * feedback

        // Advance index
        index = (index + 1) % buffer.count

        return output
    }

    func reset() {
        buffer.fill(with: 0.0)
        index = 0
        filterState = 0.0
    }
}

/// Allpass filter for reverb
private final class AllpassFilter: @unchecked Sendable {

    private var buffer: [Float]
    private var index: Int = 0
    private var feedback: Float = 0.5

    init(delay: Float, sampleRate: Double) {
        let bufferSize = Int(delay * Float(sampleRate))
        buffer = [Float](repeating: 0.0, count: max(1, bufferSize))
    }

    func setFeedback(_ feedback: Float) {
        self.feedback = max(0.0, min(0.99, feedback))
    }

    func process(_ input: Float) -> Float {
        let delayed = buffer[index]
        let output = -input + delayed

        buffer[index] = input + delayed * feedback

        index = (index + 1) % buffer.count

        return output
    }

    func reset() {
        buffer.fill(with: 0.0)
        index = 0
    }
}

/// Individual chorus voice
private final class ChorusVoice: @unchecked Sendable {

    private var delayBuffer: [Float]
    private var writeIndex: Int = 0
    private var baseDelay: Float
    private var rate: Float
    private var depth: Float
    private var feedback: Float
    private var phaseOffset: Float
    private var lfoPhase: Float = 0.0
    private let sampleRate: Double

    init(baseDelay: Float, rate: Float, depth: Float, feedback: Float, phaseOffset: Float, sampleRate: Double) {
        self.baseDelay = baseDelay
        self.rate = rate
        self.depth = depth
        self.feedback = feedback
        self.phaseOffset = phaseOffset
        self.sampleRate = sampleRate

        let maxDelay = Int(sampleRate * 0.1) // 100ms max
        delayBuffer = [Float](repeating: 0.0, count: maxDelay)
    }

    func setRate(_ rate: Float) {
        self.rate = rate
    }

    func setDepth(_ depth: Float) {
        self.depth = depth
    }

    func setFeedback(_ feedback: Float) {
        self.feedback = feedback
    }

    func setBaseDelay(_ delay: Float) {
        baseDelay = delay
    }

    func setPhaseOffset(_ offset: Float) {
        phaseOffset = offset
    }

    func process(_ input: Float) -> Float {
        // Update LFO
        lfoPhase += rate * 2.0 * Float.pi / Float(sampleRate)
        if lfoPhase > 2.0 * Float.pi {
            lfoPhase -= 2.0 * Float.pi
        }

        // Calculate modulated delay
        let lfoValue = sin(lfoPhase + phaseOffset)
        let modulatedDelay = baseDelay + lfoValue * depth * baseDelay
        let delaySamples = modulatedDelay * Float(sampleRate)

        // Read delayed sample with interpolation
        let delayedSample = readDelayedSample(delaySamples)

        // Apply feedback
        let feedbackSample = input + delayedSample * feedback

        // Write to delay buffer
        delayBuffer[writeIndex] = feedbackSample
        writeIndex = (writeIndex + 1) % delayBuffer.count

        return delayedSample
    }

    func reset() {
        delayBuffer.fill(with: 0.0)
        writeIndex = 0
        lfoPhase = 0.0
    }

    private func readDelayedSample(_ delaySamples: Float) -> Float {
        let intDelay = Int(delaySamples)
        let fracDelay = delaySamples - Float(intDelay)

        let readIndex1 = (writeIndex - intDelay + delayBuffer.count) % delayBuffer.count
        let readIndex2 = (readIndex1 - 1 + delayBuffer.count) % delayBuffer.count

        let sample1 = delayBuffer[readIndex1]
        let sample2 = delayBuffer[readIndex2]

        // Linear interpolation
        return sample1 * (1.0 - fracDelay) + sample2 * fracDelay
    }
}

// MARK: - Array Extensions

private extension Array where Element == Float {
    mutating func fill(with value: Float) {
        for i in 0..<count {
            self[i] = value
        }
    }
}
