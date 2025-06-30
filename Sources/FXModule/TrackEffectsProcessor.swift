import Foundation
import MachineProtocols
import Combine

/// Track-level effects processor that manages effects for individual tracks
public class TrackEffectsProcessor: ObservableObject {
    
    // MARK: - Properties
    
    /// Track identifier
    public let trackId: Int
    
    /// Effect chain for this track
    @Published public private(set) var effectChain: EffectChain
    
    /// Track-level bypass
    @Published public var isBypassed: Bool = false
    
    /// Track input gain
    @Published public var inputGain: Float = 0.0 // dB
    
    /// Track output gain
    @Published public var outputGain: Float = 0.0 // dB
    
    /// Track pan (-1.0 = left, 0.0 = center, 1.0 = right)
    @Published public var pan: Float = 0.0
    
    /// Track mute
    @Published public var isMuted: Bool = false
    
    /// Track solo
    @Published public var isSoloed: Bool = false

    /// Send levels for global send effects
    @Published public var sendLevels: [Float] = [0.0, 0.0, 0.0, 0.0] // 4 send effects max
    
    // MARK: - Available Effects
    
    public enum AvailableEffect: String, CaseIterable {
        case bitReduction = "Bit Reduction"
        case sampleRateReduction = "Sample Rate Reduction"
        case overdrive = "Overdrive"
        
        var effectType: EffectType {
            switch self {
            case .bitReduction: return .bitCrusher
            case .sampleRateReduction: return .sampleRateReduction
            case .overdrive: return .overdrive
            }
        }
    }
    
    // MARK: - Initialization
    
    public init(trackId: Int) {
        self.trackId = trackId
        self.effectChain = EffectChain()
        setupDefaultEffects()
    }
    
    // MARK: - Effect Management
    
    /// Add an effect to the track
    public func addEffect(_ effectType: AvailableEffect) -> Bool {
        let effect: FXProcessor
        
        switch effectType {
        case .bitReduction:
            effect = BitReductionEffect()
        case .sampleRateReduction:
            effect = SampleRateReductionEffect()
        case .overdrive:
            effect = OverdriveEffect()
        }
        
        return effectChain.addEffect(effect)
    }
    
    /// Add a preconfigured effect
    public func addEffect(_ effect: FXProcessor) -> Bool {
        return effectChain.addEffect(effect)
    }
    
    /// Remove effect at index
    public func removeEffect(at index: Int) -> FXProcessor? {
        return effectChain.removeEffect(at: index)
    }
    
    /// Move effect from one position to another
    public func moveEffect(from sourceIndex: Int, to destinationIndex: Int) -> Bool {
        return effectChain.moveEffect(from: sourceIndex, to: destinationIndex)
    }
    
    /// Get effect at index
    public func getEffect(at index: Int) -> FXProcessor? {
        return effectChain.getEffect(at: index)
    }
    
    /// Get all effects
    public func getEffects() -> [FXProcessor] {
        return effectChain.getEffects()
    }
    
    /// Clear all effects
    public func clearEffects() {
        effectChain.clearEffects()
    }
    
    /// Get number of effects
    public var effectCount: Int {
        return effectChain.effectCount
    }
    
    // MARK: - Audio Processing
    
    /// Process audio through the track effects
    public func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        guard !isBypassed && !isMuted else {
            // Return silence if muted, original if bypassed
            if isMuted {
                var silentBuffer = input
                for i in 0..<silentBuffer.samples.count {
                    silentBuffer.samples[i] = 0.0
                }
                return silentBuffer
            }
            return input
        }
        
        // Apply input gain
        var processedBuffer = input
        let inputGainLinear = pow(10.0, inputGain / 20.0)
        
        for i in 0..<processedBuffer.samples.count {
            processedBuffer.samples[i] *= inputGainLinear
        }
        
        // Process through effect chain
        processedBuffer = effectChain.process(input: processedBuffer)
        
        // Apply output gain
        let outputGainLinear = pow(10.0, outputGain / 20.0)
        
        for i in 0..<processedBuffer.samples.count {
            processedBuffer.samples[i] *= outputGainLinear
        }
        
        // Apply panning (for stereo processing)
        if processedBuffer.channelCount == 2 {
            applyPanning(to: &processedBuffer)
        }
        
        return processedBuffer
    }
    
    // MARK: - Track Control
    
    /// Reset all effects on the track
    public func resetEffects() {
        effectChain.resetEffectState()
    }
    
    /// Flush all effect buffers
    public func flushEffects() {
        effectChain.flushBuffers()
    }
    
    /// Set track bypass state
    public func setBypass(_ bypassed: Bool) {
        isBypassed = bypassed
    }
    
    /// Set track mute state
    public func setMute(_ muted: Bool) {
        isMuted = muted
    }
    
    /// Set track solo state
    public func setSolo(_ soloed: Bool) {
        isSoloed = soloed
    }
    
    /// Set track input gain
    public func setInputGain(_ gain: Float) {
        inputGain = max(-60.0, min(20.0, gain))
    }
    
    /// Set track output gain
    public func setOutputGain(_ gain: Float) {
        outputGain = max(-60.0, min(20.0, gain))
    }
    
    /// Set track pan
    public func setPan(_ panValue: Float) {
        pan = max(-1.0, min(1.0, panValue))
    }

    // MARK: - Send Controls

    /// Set send level for a specific send effect
    public func setSendLevel(_ level: Float, for sendIndex: Int) {
        guard sendIndex >= 0 && sendIndex < sendLevels.count else { return }
        sendLevels[sendIndex] = max(0.0, min(1.0, level))
    }

    /// Get send level for a specific send effect
    public func getSendLevel(for sendIndex: Int) -> Float {
        guard sendIndex >= 0 && sendIndex < sendLevels.count else { return 0.0 }
        return sendLevels[sendIndex]
    }

    /// Set all send levels at once
    public func setSendLevels(_ levels: [Float]) {
        for (index, level) in levels.enumerated() {
            setSendLevel(level, for: index)
        }
    }

    /// Reset all send levels to zero
    public func resetSendLevels() {
        for i in 0..<sendLevels.count {
            sendLevels[i] = 0.0
        }
    }
    
    // MARK: - Preset Management
    
    /// Save track effects as preset
    public func savePreset(name: String) -> TrackEffectsPreset {
        let effectPresets = effectChain.getEffects().map { effect in
            effect.saveEffectPreset(name: "\(name)_\(effect.name)")
        }
        
        return TrackEffectsPreset(
            name: name,
            trackId: trackId,
            inputGain: inputGain,
            outputGain: outputGain,
            pan: pan,
            isBypassed: isBypassed,
            effectPresets: effectPresets,
            sendLevels: sendLevels
        )
    }
    
    /// Load track effects from preset
    public func loadPreset(_ preset: TrackEffectsPreset) {
        // Clear existing effects
        clearEffects()
        
        // Load track settings
        inputGain = preset.inputGain
        outputGain = preset.outputGain
        pan = preset.pan
        isBypassed = preset.isBypassed
        sendLevels = preset.sendLevels
        
        // Load effects
        for effectPreset in preset.effectPresets {
            // Create appropriate effect based on type
            let effect: FXProcessor
            
            switch effectPreset.effectType {
            case .bitCrusher:
                effect = BitReductionEffect()
            case .sampleRateReduction:
                effect = SampleRateReductionEffect()
            case .overdrive:
                effect = OverdriveEffect()
            default:
                continue // Skip unsupported effects
            }
            
            // Load the preset into the effect
            effect.loadEffectPreset(effectPreset)
            
            // Add to chain
            _ = addEffect(effect)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultEffects() {
        // Track starts with no effects by default
        // Effects can be added as needed
    }
    
    private func applyPanning(to buffer: inout MachineProtocols.AudioBuffer) {
        guard buffer.channelCount == 2 else { return }
        
        // Calculate left and right gains based on pan
        let leftGain = cos((pan + 1.0) * Float.pi / 4.0)
        let rightGain = sin((pan + 1.0) * Float.pi / 4.0)
        
        // Apply panning (assuming interleaved stereo)
        for i in stride(from: 0, to: buffer.samples.count, by: 2) {
            if i + 1 < buffer.samples.count {
                let leftSample = buffer.samples[i]
                let rightSample = buffer.samples[i + 1]
                
                // Apply pan law
                buffer.samples[i] = leftSample * leftGain
                buffer.samples[i + 1] = rightSample * rightGain
            }
        }
    }
}

// MARK: - Track Effects Preset

public struct TrackEffectsPreset: Codable {
    public let name: String
    public let trackId: Int
    public let inputGain: Float
    public let outputGain: Float
    public let pan: Float
    public let isBypassed: Bool
    public let effectPresets: [EffectPreset]
    public let sendLevels: [Float]

    public init(name: String, trackId: Int, inputGain: Float, outputGain: Float, pan: Float, isBypassed: Bool, effectPresets: [EffectPreset], sendLevels: [Float] = [0.0, 0.0, 0.0, 0.0]) {
        self.name = name
        self.trackId = trackId
        self.inputGain = inputGain
        self.outputGain = outputGain
        self.pan = pan
        self.isBypassed = isBypassed
        self.effectPresets = effectPresets
        self.sendLevels = sendLevels
    }
}

// MARK: - Factory Methods

extension TrackEffectsProcessor {
    /// Create a track processor with common effect combinations
    public static func createWithPreset(_ preset: TrackEffectsPresetType, trackId: Int) -> TrackEffectsProcessor {
        let processor = TrackEffectsProcessor(trackId: trackId)
        
        switch preset {
        case .clean:
            // No effects, just clean signal
            break
            
        case .lofi:
            _ = processor.addEffect(BitReductionEffect.createPreset(.lofi))
            _ = processor.addEffect(SampleRateReductionEffect.createPreset(.lofi))
            
        case .warm:
            _ = processor.addEffect(OverdriveEffect.createPreset(.warm))
            
        case .crunch:
            _ = processor.addEffect(OverdriveEffect.createPreset(.crunch))
            _ = processor.addEffect(BitReductionEffect.createPreset(.subtle))
            
        case .extreme:
            _ = processor.addEffect(OverdriveEffect.createPreset(.fuzz))
            _ = processor.addEffect(BitReductionEffect.createPreset(.extreme))
            _ = processor.addEffect(SampleRateReductionEffect.createPreset(.extreme))
        }
        
        return processor
    }
}

/// Common track effects preset types
public enum TrackEffectsPresetType: String, CaseIterable {
    case clean = "Clean"
    case lofi = "Lo-Fi"
    case warm = "Warm"
    case crunch = "Crunch"
    case extreme = "Extreme"
}
