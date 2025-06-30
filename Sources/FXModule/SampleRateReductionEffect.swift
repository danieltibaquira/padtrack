import Foundation
import MachineProtocols
import Accelerate

/// Sample rate reduction effect with anti-aliasing
public class SampleRateReductionEffect: FXProcessor, ObservableObject, @unchecked Sendable {
    
    // MARK: - Effect-specific parameters
    
    /// Target sample rate (100 Hz - 48000 Hz)
    public var targetSampleRate: Float = 44100.0 {
        didSet {
            targetSampleRate = max(100.0, min(48000.0, targetSampleRate))
            updateDownsamplingRatio()
        }
    }
    
    /// Anti-aliasing filter enabled
    public var antiAliasingEnabled: Bool = true
    
    /// Filter cutoff frequency (as ratio of target sample rate)
    public var filterCutoffRatio: Float = 0.45 {
        didSet {
            filterCutoffRatio = max(0.1, min(0.5, filterCutoffRatio))
            updateFilterCoefficients()
        }
    }
    
    // MARK: - Private properties
    
    private var downsamplingRatio: Float = 1.0
    private var accumulator: Float = 0.0
    private var lastSample: Float = 0.0
    
    // Simple low-pass filter state
    private var filterState: Float = 0.0
    private var filterCoeff: Float = 1.0
    
    // Buffer for holding samples during downsampling
    private var sampleBuffer: [Float] = []
    private var bufferIndex: Int = 0
    
    // MARK: - Initialization
    
    public init() {
        super.init(name: "Sample Rate Reduction")
        self.effectType = .sampleRateReduction
        setupSampleRateReductionParameters()
        updateDownsamplingRatio()
        updateFilterCoefficients()
    }
    
    // MARK: - Parameter Setup
    
    private func setupSampleRateReductionParameters() {
        do {
            // Target sample rate parameter
            let sampleRateParam = Parameter(
                id: "target_sample_rate",
                name: "Sample Rate",
                value: targetSampleRate,
                minValue: 100.0,
                maxValue: 48000.0,
                defaultValue: 22050.0,
                unit: "Hz"
            )
            try parameters.addParameter(sampleRateParam)
            
            // Anti-aliasing enabled parameter
            let antiAliasingParam = Parameter(
                id: "anti_aliasing",
                name: "Anti-Aliasing",
                value: antiAliasingEnabled ? 1.0 : 0.0,
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 1.0,
                unit: ""
            )
            try parameters.addParameter(antiAliasingParam)
            
            // Filter cutoff ratio parameter
            let cutoffParam = Parameter(
                id: "filter_cutoff_ratio",
                name: "Filter Cutoff",
                value: filterCutoffRatio,
                minValue: 0.1,
                maxValue: 0.5,
                defaultValue: 0.3,
                unit: ""
            )
            try parameters.addParameter(cutoffParam)
            
        } catch {
            print("Failed to setup sample rate reduction parameters: \(error)")
        }
    }
    
    // MARK: - Audio Processing
    
    public override func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        guard !isBypassed && isEnabled else {
            return input
        }

        // Update parameters from parameter system
        updateParametersFromSystem()

        // Create output buffer
        var output = input

        // Store original samples for wet/dry mixing
        let originalSamples = output.samples

        // Apply input gain using vectorized operations
        if inputGain != 0.0 {
            var inputGainLinear = pow(10.0, inputGain / 20.0)
            vDSP_vsmul(output.samples, 1, &inputGainLinear, &output.samples, 1, vDSP_Length(output.samples.count))
        }

        // Apply optimized sample rate reduction
        OptimizedEffectProcessing.optimizedSampleRateReduction(
            samples: &output.samples,
            targetSampleRate: targetSampleRate,
            inputSampleRate: 44100.0, // This should come from audio engine
            antiAliasing: antiAliasingEnabled,
            filterState: &filterState
        )

        // Apply wet/dry mix using vectorized operations
        if wetLevel != 1.0 || dryLevel != 0.0 {
            var wetSamples = output.samples
            var drySamples = originalSamples

            // Scale wet and dry signals
            vDSP_vsmul(wetSamples, 1, &wetLevel, &wetSamples, 1, vDSP_Length(wetSamples.count))
            vDSP_vsmul(drySamples, 1, &dryLevel, &drySamples, 1, vDSP_Length(drySamples.count))

            // Mix wet and dry
            vDSP_vadd(wetSamples, 1, drySamples, 1, &output.samples, 1, vDSP_Length(output.samples.count))
        }

        // Apply output gain using vectorized operations
        if outputGain != 0.0 {
            var outputGainLinear = pow(10.0, outputGain / 20.0)
            vDSP_vsmul(output.samples, 1, &outputGainLinear, &output.samples, 1, vDSP_Length(output.samples.count))
        }

        // Update peak meters
        updatePeakMeters(input: input, output: output)

        return output
    }
    
    // MARK: - Private Methods
    
    private func updateParametersFromSystem() {
        if let newSampleRate = parameters.getParameterValue(id: "target_sample_rate") {
            targetSampleRate = newSampleRate
        }
        
        if let antiAliasingValue = parameters.getParameterValue(id: "anti_aliasing") {
            antiAliasingEnabled = antiAliasingValue > 0.5
        }
        
        if let cutoffValue = parameters.getParameterValue(id: "filter_cutoff_ratio") {
            filterCutoffRatio = cutoffValue
        }
    }
    
    private func updateDownsamplingRatio() {
        // Assume input sample rate is 44100 Hz (this should come from audio engine)
        let inputSampleRate: Float = 44100.0
        downsamplingRatio = inputSampleRate / targetSampleRate
    }
    
    private func updateFilterCoefficients() {
        // Simple one-pole low-pass filter coefficient
        // Cutoff frequency = filterCutoffRatio * targetSampleRate
        let cutoffFreq = filterCutoffRatio * targetSampleRate
        let inputSampleRate: Float = 44100.0
        let normalizedCutoff = cutoffFreq / inputSampleRate
        
        // Calculate filter coefficient (simple RC filter approximation)
        filterCoeff = exp(-2.0 * Float.pi * normalizedCutoff)
    }
    
    private func applyAntiAliasingFilter(_ sample: Float) -> Float {
        // Simple one-pole low-pass filter
        filterState = filterState * filterCoeff + sample * (1.0 - filterCoeff)
        return filterState
    }
    
    private func applySampleRateReduction(_ sample: Float) -> Float {
        // Accumulate samples for downsampling
        accumulator += 1.0
        
        if accumulator >= downsamplingRatio {
            // Time to output a new sample
            accumulator -= downsamplingRatio
            lastSample = sample
            return sample
        } else {
            // Hold the last sample (zero-order hold)
            return lastSample
        }
    }
    
    private func updatePeakMeters(input: MachineProtocols.AudioBuffer, output: MachineProtocols.AudioBuffer) {
        // Calculate input peak
        var inputPeakValue: Float = 0.0
        vDSP_maxmgv(input.samples, 1, &inputPeakValue, vDSP_Length(input.samples.count))
        self.inputPeak = inputPeakValue
        
        // Calculate output peak
        var outputPeakValue: Float = 0.0
        vDSP_maxmgv(output.samples, 1, &outputPeakValue, vDSP_Length(output.samples.count))
        self.outputPeak = outputPeakValue
    }
    
    // MARK: - Effect State Management
    
    public override func resetEffectState() {
        super.resetEffectState()
        accumulator = 0.0
        lastSample = 0.0
        filterState = 0.0
        sampleBuffer.removeAll()
        bufferIndex = 0
    }
    
    // MARK: - Preset Management
    
    public override func loadEffectPreset(_ preset: EffectPreset) {
        super.loadEffectPreset(preset)
        
        // Load sample rate reduction specific parameters
        if let sampleRateValue = preset.parameters["target_sample_rate"] {
            targetSampleRate = sampleRateValue
        }
        
        if let antiAliasingValue = preset.parameters["anti_aliasing"] {
            antiAliasingEnabled = antiAliasingValue > 0.5
        }
        
        if let cutoffValue = preset.parameters["filter_cutoff_ratio"] {
            filterCutoffRatio = cutoffValue
        }
    }
    
    public override func saveEffectPreset(name: String) -> EffectPreset {
        let basePreset = super.saveEffectPreset(name: name)

        // Create new parameters dictionary with sample rate reduction specific parameters
        var allParameters = basePreset.parameters
        allParameters["target_sample_rate"] = targetSampleRate
        allParameters["anti_aliasing"] = antiAliasingEnabled ? 1.0 : 0.0
        allParameters["filter_cutoff_ratio"] = filterCutoffRatio

        return EffectPreset(
            name: name,
            description: nil,
            effectType: .bitCrusher,
            parameters: allParameters,
            metadata: basePreset.metadata
        )
    }
}

// MARK: - Factory Method

extension SampleRateReductionEffect {
    /// Create a sample rate reduction effect with common presets
    public static func createPreset(_ preset: SampleRateReductionPreset) -> SampleRateReductionEffect {
        let effect = SampleRateReductionEffect()
        
        switch preset {
        case .telephone:
            effect.targetSampleRate = 8000.0
            effect.antiAliasingEnabled = true
            effect.filterCutoffRatio = 0.4
            effect.wetLevel = 1.0
            
        case .radio:
            effect.targetSampleRate = 22050.0
            effect.antiAliasingEnabled = true
            effect.filterCutoffRatio = 0.45
            effect.wetLevel = 0.8
            
        case .lofi:
            effect.targetSampleRate = 11025.0
            effect.antiAliasingEnabled = false
            effect.filterCutoffRatio = 0.3
            effect.wetLevel = 1.0
            
        case .extreme:
            effect.targetSampleRate = 2000.0
            effect.antiAliasingEnabled = false
            effect.filterCutoffRatio = 0.2
            effect.wetLevel = 1.0
            
        case .subtle:
            effect.targetSampleRate = 32000.0
            effect.antiAliasingEnabled = true
            effect.filterCutoffRatio = 0.45
            effect.wetLevel = 0.6
        }
        
        return effect
    }
}

/// Sample rate reduction presets
public enum SampleRateReductionPreset: String, CaseIterable {
    case telephone = "Telephone"
    case radio = "Radio"
    case lofi = "Lo-Fi"
    case extreme = "Extreme"
    case subtle = "Subtle"
}
