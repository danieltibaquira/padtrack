import Foundation
import MachineProtocols
import Combine

/// Effect chain for processing audio through multiple effects in sequence
public class EffectChain: FXProcessor, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Array of effects in the chain
    private var effects: [FXProcessor] = []
    
    /// Maximum number of effects in chain
    public let maxEffects: Int = 8
    
    /// Chain bypass (bypasses entire chain)
    public var chainBypassed: Bool = false
    
    /// Chain wet/dry mix (applies to entire chain output)
    public var chainWetLevel: Float = 1.0
    public var chainDryLevel: Float = 0.0
    
    // MARK: - Initialization
    
    public init() {
        super.init(name: "Effect Chain")
        self.effectType = .delay // Using delay as a placeholder
        setupChainParameters()
    }
    
    // MARK: - Parameter Setup
    
    private func setupChainParameters() {
        do {
            // Chain bypass parameter
            let chainBypassParam = Parameter(
                id: "chain_bypass",
                name: "Chain Bypass",
                value: chainBypassed ? 1.0 : 0.0,
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 0.0,
                unit: ""
            )
            try parameters.addParameter(chainBypassParam)
            
            // Chain wet level parameter
            let chainWetParam = Parameter(
                id: "chain_wet_level",
                name: "Chain Wet",
                value: chainWetLevel,
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 1.0,
                unit: ""
            )
            try parameters.addParameter(chainWetParam)
            
            // Chain dry level parameter
            let chainDryParam = Parameter(
                id: "chain_dry_level",
                name: "Chain Dry",
                value: chainDryLevel,
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 0.0,
                unit: ""
            )
            try parameters.addParameter(chainDryParam)
            
        } catch {
            print("Failed to setup effect chain parameters: \(error)")
        }
    }
    
    // MARK: - Effect Management
    
    /// Add an effect to the end of the chain
    public func addEffect(_ effect: FXProcessor) -> Bool {
        guard effects.count < maxEffects else {
            print("Cannot add effect: chain is full (max \(maxEffects) effects)")
            return false
        }
        
        effects.append(effect)
        updateChainParameters()
        return true
    }
    
    /// Insert an effect at a specific position
    public func insertEffect(_ effect: FXProcessor, at index: Int) -> Bool {
        guard effects.count < maxEffects else {
            print("Cannot insert effect: chain is full (max \(maxEffects) effects)")
            return false
        }
        
        guard index >= 0 && index <= effects.count else {
            print("Cannot insert effect: invalid index \(index)")
            return false
        }
        
        effects.insert(effect, at: index)
        updateChainParameters()
        return true
    }
    
    /// Remove an effect at a specific position
    public func removeEffect(at index: Int) -> FXProcessor? {
        guard index >= 0 && index < effects.count else {
            print("Cannot remove effect: invalid index \(index)")
            return nil
        }
        
        let removedEffect = effects.remove(at: index)
        updateChainParameters()
        return removedEffect
    }
    
    /// Remove a specific effect
    public func removeEffect(_ effect: FXProcessor) -> Bool {
        if let index = effects.firstIndex(where: { $0 === effect }) {
            effects.remove(at: index)
            updateChainParameters()
            return true
        }
        return false
    }
    
    /// Move an effect from one position to another
    public func moveEffect(from sourceIndex: Int, to destinationIndex: Int) -> Bool {
        guard sourceIndex >= 0 && sourceIndex < effects.count else {
            print("Cannot move effect: invalid source index \(sourceIndex)")
            return false
        }
        
        guard destinationIndex >= 0 && destinationIndex < effects.count else {
            print("Cannot move effect: invalid destination index \(destinationIndex)")
            return false
        }
        
        let effect = effects.remove(at: sourceIndex)
        effects.insert(effect, at: destinationIndex)
        updateChainParameters()
        return true
    }
    
    /// Clear all effects from the chain
    public func clearEffects() {
        effects.removeAll()
        updateChainParameters()
    }
    
    /// Get all effects in the chain
    public func getEffects() -> [FXProcessor] {
        return effects
    }
    
    /// Get effect at specific index
    public func getEffect(at index: Int) -> FXProcessor? {
        guard index >= 0 && index < effects.count else {
            return nil
        }
        return effects[index]
    }
    
    /// Get number of effects in chain
    public var effectCount: Int {
        return effects.count
    }
    
    // MARK: - Audio Processing
    
    public override func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        guard !isBypassed && !chainBypassed && isEnabled else {
            return input
        }
        
        // Update parameters from parameter system
        updateParametersFromSystem()
        
        // Store original input for wet/dry mixing
        let originalInput = input
        
        // Process through each effect in sequence
        var currentBuffer = input
        
        for effect in effects {
            if effect.isEnabled && !effect.isBypassed {
                currentBuffer = effect.process(input: currentBuffer)
            }
        }
        
        // Apply chain-level wet/dry mix
        var output = currentBuffer
        
        for i in 0..<output.samples.count {
            let wetSample = currentBuffer.samples[i] * chainWetLevel
            let drySample = originalInput.samples[i] * chainDryLevel
            output.samples[i] = wetSample + drySample
        }
        
        // Apply input/output gain
        for i in 0..<output.samples.count {
            let sample = output.samples[i]
            let gainedSample = sample * pow(10.0, inputGain / 20.0)
            output.samples[i] = gainedSample * pow(10.0, outputGain / 20.0)
        }
        
        // Update peak meters
        updatePeakMeters(input: originalInput, output: output)
        
        return output
    }
    
    // MARK: - Private Methods
    
    private func updateParametersFromSystem() {
        if let chainBypassValue = parameters.getParameterValue(id: "chain_bypass") {
            chainBypassed = chainBypassValue > 0.5
        }
        
        if let chainWetValue = parameters.getParameterValue(id: "chain_wet_level") {
            chainWetLevel = chainWetValue
        }
        
        if let chainDryValue = parameters.getParameterValue(id: "chain_dry_level") {
            chainDryLevel = chainDryValue
        }
    }
    
    private func updateChainParameters() {
        // Update parameter system with current chain state
        do {
            try parameters.updateParameter(id: "chain_bypass", value: chainBypassed ? 1.0 : 0.0)
            try parameters.updateParameter(id: "chain_wet_level", value: chainWetLevel)
            try parameters.updateParameter(id: "chain_dry_level", value: chainDryLevel)
        } catch {
            // Ignore parameter update errors
        }
    }
    
    private func updatePeakMeters(input: MachineProtocols.AudioBuffer, output: MachineProtocols.AudioBuffer) {
        // Calculate input peak
        var inputPeakValue: Float = 0.0
        for sample in input.samples {
            inputPeakValue = max(inputPeakValue, abs(sample))
        }
        self.inputPeak = inputPeakValue
        
        // Calculate output peak
        var outputPeakValue: Float = 0.0
        for sample in output.samples {
            outputPeakValue = max(outputPeakValue, abs(sample))
        }
        self.outputPeak = outputPeakValue
    }
    
    // MARK: - Effect State Management
    
    public override func resetEffectState() {
        super.resetEffectState()
        
        // Reset all effects in the chain
        for effect in effects {
            effect.resetEffectState()
        }
    }
    
    public override func flushBuffers() {
        super.flushBuffers()
        
        // Flush all effects in the chain
        for effect in effects {
            effect.flushBuffers()
        }
    }
    
    // MARK: - Preset Management
    
    public override func loadEffectPreset(_ preset: EffectPreset) {
        super.loadEffectPreset(preset)
        
        // Load chain-specific parameters
        if let chainBypassValue = preset.parameters["chain_bypass"] {
            chainBypassed = chainBypassValue > 0.5
        }
        
        if let chainWetValue = preset.parameters["chain_wet_level"] {
            chainWetLevel = chainWetValue
        }
        
        if let chainDryValue = preset.parameters["chain_dry_level"] {
            chainDryLevel = chainDryValue
        }
        
        // Note: Individual effect presets would need to be handled separately
        // This could be extended to save/load entire chain configurations
    }
    
    public override func saveEffectPreset(name: String) -> EffectPreset {
        let basePreset = super.saveEffectPreset(name: name)

        // Create new parameters dictionary with chain-specific parameters
        var allParameters = basePreset.parameters
        allParameters["chain_bypass"] = chainBypassed ? 1.0 : 0.0
        allParameters["chain_wet_level"] = chainWetLevel
        allParameters["chain_dry_level"] = chainDryLevel
        allParameters["effect_count"] = Float(effects.count)

        // Note: Individual effect presets would need to be handled separately
        // This could be extended to save/load entire chain configurations

        return EffectPreset(
            name: name,
            description: nil,
            effectType: .delay,
            parameters: allParameters,
            metadata: basePreset.metadata
        )
    }
    
    // MARK: - Utility Methods
    
    /// Get chain processing latency (sum of all effect latencies)
    public override var latency: Int {
        return effects.reduce(0) { $0 + $1.latency }
    }
    
    /// Check if any effect in the chain is processing
    public override var isProcessing: Bool {
        return !chainBypassed && effects.contains { $0.isProcessing }
    }
    
    /// Get combined effect state from all effects
    public override var effectState: [String: Float] {
        var combinedState = super.effectState
        
        for (index, effect) in effects.enumerated() {
            let effectState = effect.effectState
            for (key, value) in effectState {
                combinedState["effect_\(index)_\(key)"] = value
            }
        }
        
        return combinedState
    }
}

// MARK: - Chain Builder

extension EffectChain {
    /// Builder pattern for creating effect chains
    public class Builder {
        private let chain = EffectChain()
        
        public init() {}
        
        public func addBitReduction(preset: BitReductionPreset = .subtle) -> Builder {
            let effect = BitReductionEffect.createPreset(preset)
            _ = chain.addEffect(effect)
            return self
        }
        
        public func addSampleRateReduction(preset: SampleRateReductionPreset = .subtle) -> Builder {
            let effect = SampleRateReductionEffect.createPreset(preset)
            _ = chain.addEffect(effect)
            return self
        }
        
        public func addOverdrive(preset: OverdrivePreset = .clean) -> Builder {
            let effect = OverdriveEffect.createPreset(preset)
            _ = chain.addEffect(effect)
            return self
        }
        
        public func setChainMix(wet: Float, dry: Float) -> Builder {
            chain.chainWetLevel = wet
            chain.chainDryLevel = dry
            return self
        }
        
        public func build() -> EffectChain {
            return chain
        }
    }
    
    /// Create a new chain builder
    public static func builder() -> Builder {
        return Builder()
    }
}
