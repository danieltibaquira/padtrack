import Foundation
import MachineProtocols
import Accelerate

/// Bit reduction effect for lo-fi audio processing
public class BitReductionEffect: FXProcessor, ObservableObject, @unchecked Sendable {
    
    // MARK: - Effect-specific parameters
    
    /// Bit depth (1-16 bits)
    public var bitDepth: Float = 16.0 {
        didSet {
            bitDepth = max(1.0, min(16.0, bitDepth))
            updateQuantizationStep()
        }
    }
    
    /// Dithering amount (0.0 = no dither, 1.0 = full dither)
    public var ditherAmount: Float = 0.0 {
        didSet {
            ditherAmount = max(0.0, min(1.0, ditherAmount))
        }
    }
    
    /// Dithering type
    public enum DitherType: String, CaseIterable {
        case none = "none"
        case triangular = "triangular"
        case rectangular = "rectangular"
    }
    
    public var ditherType: DitherType = .none
    
    // MARK: - Private properties
    
    private var quantizationStep: Float = 1.0
    private var invQuantizationStep: Float = 1.0
    private var randomGenerator = SystemRandomNumberGenerator()
    
    // MARK: - Initialization
    
    public init() {
        super.init(name: "Bit Reduction")
        self.effectType = .bitCrusher
        setupBitReductionParameters()
        updateQuantizationStep()
    }
    
    // MARK: - Parameter Setup
    
    private func setupBitReductionParameters() {
        do {
            // Bit depth parameter
            let bitDepthParam = Parameter(
                id: "bit_depth",
                name: "Bit Depth",
                value: bitDepth,
                minValue: 1.0,
                maxValue: 16.0,
                defaultValue: 8.0,
                unit: "bits"
            )
            try parameters.addParameter(bitDepthParam)
            
            // Dither amount parameter
            let ditherParam = Parameter(
                id: "dither_amount",
                name: "Dither",
                value: ditherAmount,
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 0.0,
                unit: ""
            )
            try parameters.addParameter(ditherParam)
            
            // Dither type parameter
            let ditherTypeParam = Parameter(
                id: "dither_type",
                name: "Dither Type",
                value: 0.0, // none
                minValue: 0.0,
                maxValue: 2.0,
                defaultValue: 0.0,
                unit: ""
            )
            try parameters.addParameter(ditherTypeParam)
            
        } catch {
            print("Failed to setup bit reduction parameters: \(error)")
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

        // Apply optimized bit reduction
        OptimizedEffectProcessing.optimizedBitReduction(
            samples: &output.samples,
            bitDepth: bitDepth,
            ditherAmount: ditherAmount
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
        if let newBitDepth = parameters.getParameterValue(id: "bit_depth") {
            bitDepth = newBitDepth
        }
        
        if let newDitherAmount = parameters.getParameterValue(id: "dither_amount") {
            ditherAmount = newDitherAmount
        }
        
        if let ditherTypeValue = parameters.getParameterValue(id: "dither_type") {
            switch Int(ditherTypeValue) {
            case 0: ditherType = .none
            case 1: ditherType = .triangular
            case 2: ditherType = .rectangular
            default: ditherType = .none
            }
        }
    }
    
    private func updateQuantizationStep() {
        let levels = pow(2.0, bitDepth)
        quantizationStep = 2.0 / levels
        invQuantizationStep = 1.0 / quantizationStep
    }
    
    private func quantize(sample: Float) -> Float {
        // Quantize to the specified bit depth
        let quantized = round(sample * invQuantizationStep) * quantizationStep
        
        // Clamp to valid range
        return max(-1.0, min(1.0, quantized))
    }
    
    private func applyDithering(to sample: Float) -> Float {
        guard ditherAmount > 0.0 && ditherType != .none else {
            return sample
        }
        
        let ditherNoise: Float
        
        switch ditherType {
        case .none:
            return sample
            
        case .rectangular:
            // Rectangular (uniform) dither
            ditherNoise = Float.random(in: -1.0...1.0, using: &randomGenerator)
            
        case .triangular:
            // Triangular dither (sum of two uniform random numbers)
            let r1 = Float.random(in: -1.0...1.0, using: &randomGenerator)
            let r2 = Float.random(in: -1.0...1.0, using: &randomGenerator)
            ditherNoise = (r1 + r2) * 0.5
        }
        
        // Scale dither by amount and quantization step
        let scaledDither = ditherNoise * ditherAmount * quantizationStep * 0.5
        
        return sample + scaledDither
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
        // Reset any internal state if needed
        randomGenerator = SystemRandomNumberGenerator()
    }
    
    // MARK: - Preset Management
    
    public override func loadEffectPreset(_ preset: EffectPreset) {
        super.loadEffectPreset(preset)
        
        // Load bit reduction specific parameters
        if let bitDepthValue = preset.parameters["bit_depth"] {
            bitDepth = bitDepthValue
        }
        
        if let ditherValue = preset.parameters["dither_amount"] {
            ditherAmount = ditherValue
        }
        
        if let ditherTypeValue = preset.parameters["dither_type"] {
            switch Int(ditherTypeValue) {
            case 0: ditherType = .none
            case 1: ditherType = .triangular
            case 2: ditherType = .rectangular
            default: ditherType = .none
            }
        }
    }
    
    public override func saveEffectPreset(name: String) -> EffectPreset {
        let basePreset = super.saveEffectPreset(name: name)

        // Create new parameters dictionary with bit reduction specific parameters
        var allParameters = basePreset.parameters
        allParameters["bit_depth"] = bitDepth
        allParameters["dither_amount"] = ditherAmount
        allParameters["dither_type"] = Float(ditherType == .none ? 0 : (ditherType == .triangular ? 1 : 2))

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

extension BitReductionEffect {
    /// Create a bit reduction effect with common presets
    public static func createPreset(_ preset: BitReductionPreset) -> BitReductionEffect {
        let effect = BitReductionEffect()
        
        switch preset {
        case .subtle:
            effect.bitDepth = 12.0
            effect.ditherAmount = 0.2
            effect.ditherType = .triangular
            effect.wetLevel = 0.7
            
        case .lofi:
            effect.bitDepth = 8.0
            effect.ditherAmount = 0.0
            effect.wetLevel = 1.0
            
        case .extreme:
            effect.bitDepth = 4.0
            effect.ditherAmount = 0.0
            effect.wetLevel = 1.0
            
        case .vintage:
            effect.bitDepth = 10.0
            effect.ditherAmount = 0.3
            effect.ditherType = .rectangular
            effect.wetLevel = 0.8
        }
        
        return effect
    }
}

/// Bit reduction presets
public enum BitReductionPreset: String, CaseIterable {
    case subtle = "Subtle"
    case lofi = "Lo-Fi"
    case extreme = "Extreme"
    case vintage = "Vintage"
}
