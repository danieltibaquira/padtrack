import Foundation
import MachineProtocols
import Accelerate

/// Overdrive effect with soft clipping algorithms
public class OverdriveEffect: FXProcessor, ObservableObject, @unchecked Sendable {
    
    // MARK: - Effect-specific parameters
    
    /// Drive amount (0.0 - 10.0)
    public var driveAmount: Float = 1.0 {
        didSet {
            driveAmount = max(0.0, min(10.0, driveAmount))
        }
    }
    
    /// Output level compensation (-20.0 to 20.0 dB)
    public var outputLevel: Float = 0.0 {
        didSet {
            outputLevel = max(-20.0, min(20.0, outputLevel))
        }
    }
    
    /// Clipping curve type
    public enum ClippingCurve: String, CaseIterable {
        case soft = "soft"           // Smooth tanh saturation
        case hard = "hard"           // Hard clipping
        case tube = "tube"           // Tube-style asymmetric
        case diode = "diode"         // Diode-style clipping
        case foldback = "foldback"   // Foldback distortion
    }
    
    public var clippingCurve: ClippingCurve = .soft
    
    /// Asymmetry amount (-1.0 to 1.0)
    public var asymmetry: Float = 0.0 {
        didSet {
            asymmetry = max(-1.0, min(1.0, asymmetry))
        }
    }
    
    /// Tone control (high frequency rolloff)
    public var tone: Float = 0.5 {
        didSet {
            tone = max(0.0, min(1.0, tone))
            updateToneFilter()
        }
    }
    
    // MARK: - Private properties
    
    // Tone filter state (simple one-pole low-pass)
    private var toneFilterState: Float = 0.0
    private var toneFilterCoeff: Float = 0.5
    
    // DC blocking filter state
    private var dcBlockerX1: Float = 0.0
    private var dcBlockerY1: Float = 0.0
    
    // MARK: - Initialization
    
    public init() {
        super.init(name: "Overdrive")
        self.effectType = .overdrive
        setupOverdriveParameters()
        updateToneFilter()
    }
    
    // MARK: - Parameter Setup
    
    private func setupOverdriveParameters() {
        do {
            // Drive amount parameter
            let driveParam = Parameter(
                id: "drive_amount",
                name: "Drive",
                value: driveAmount,
                minValue: 0.0,
                maxValue: 10.0,
                defaultValue: 1.0,
                unit: ""
            )
            try parameters.addParameter(driveParam)
            
            // Output level parameter
            let outputParam = Parameter(
                id: "output_level",
                name: "Output",
                value: outputLevel,
                minValue: -20.0,
                maxValue: 20.0,
                defaultValue: 0.0,
                unit: "dB"
            )
            try parameters.addParameter(outputParam)
            
            // Clipping curve parameter
            let curveParam = Parameter(
                id: "clipping_curve",
                name: "Curve",
                value: 0.0, // soft
                minValue: 0.0,
                maxValue: 4.0,
                defaultValue: 0.0,
                unit: ""
            )
            try parameters.addParameter(curveParam)
            
            // Asymmetry parameter
            let asymmetryParam = Parameter(
                id: "asymmetry",
                name: "Asymmetry",
                value: asymmetry,
                minValue: -1.0,
                maxValue: 1.0,
                defaultValue: 0.0,
                unit: ""
            )
            try parameters.addParameter(asymmetryParam)
            
            // Tone parameter
            let toneParam = Parameter(
                id: "tone",
                name: "Tone",
                value: tone,
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 0.5,
                unit: ""
            )
            try parameters.addParameter(toneParam)
            
        } catch {
            print("Failed to setup overdrive parameters: \(error)")
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

        // Convert clipping curve to optimized type
        let optimizedClippingType: OverdriveClippingType
        switch clippingCurve {
        case .soft: optimizedClippingType = .soft
        case .hard: optimizedClippingType = .hard
        case .tube: optimizedClippingType = .tube
        default: optimizedClippingType = .soft
        }

        // Apply optimized overdrive processing
        OptimizedEffectProcessing.optimizedOverdrive(
            samples: &output.samples,
            driveAmount: driveAmount,
            clippingType: optimizedClippingType
        )

        // Apply DC blocking and tone filtering (non-vectorized for now)
        for i in 0..<output.samples.count {
            output.samples[i] = applyDCBlocker(output.samples[i])
            output.samples[i] = applyToneFilter(output.samples[i])
        }

        // Apply output level compensation
        if outputLevel != 0.0 {
            var outputLevelLinear = pow(10.0, outputLevel / 20.0)
            vDSP_vsmul(output.samples, 1, &outputLevelLinear, &output.samples, 1, vDSP_Length(output.samples.count))
        }

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

        // Apply final output gain
        if outputGain != 0.0 {
            var finalGainLinear = pow(10.0, outputGain / 20.0)
            vDSP_vsmul(output.samples, 1, &finalGainLinear, &output.samples, 1, vDSP_Length(output.samples.count))
        }

        // Update peak meters
        updatePeakMeters(input: input, output: output)

        return output
    }
    
    // MARK: - Private Methods
    
    private func updateParametersFromSystem() {
        if let newDrive = parameters.getParameterValue(id: "drive_amount") {
            driveAmount = newDrive
        }
        
        if let newOutput = parameters.getParameterValue(id: "output_level") {
            outputLevel = newOutput
        }
        
        if let curveValue = parameters.getParameterValue(id: "clipping_curve") {
            switch Int(curveValue) {
            case 0: clippingCurve = .soft
            case 1: clippingCurve = .hard
            case 2: clippingCurve = .tube
            case 3: clippingCurve = .diode
            case 4: clippingCurve = .foldback
            default: clippingCurve = .soft
            }
        }
        
        if let newAsymmetry = parameters.getParameterValue(id: "asymmetry") {
            asymmetry = newAsymmetry
        }
        
        if let newTone = parameters.getParameterValue(id: "tone") {
            tone = newTone
        }
    }
    
    private func updateToneFilter() {
        // Map tone control to filter coefficient
        // 0.0 = very dark, 1.0 = bright
        toneFilterCoeff = 0.1 + tone * 0.8
    }
    
    private func applyClippingCurve(_ sample: Float) -> Float {
        // Apply asymmetry
        let asymmetricSample = sample + asymmetry * 0.1
        
        switch clippingCurve {
        case .soft:
            // Smooth tanh saturation
            return tanh(asymmetricSample)
            
        case .hard:
            // Hard clipping
            return max(-1.0, min(1.0, asymmetricSample))
            
        case .tube:
            // Tube-style asymmetric clipping
            if asymmetricSample >= 0.0 {
                return tanh(asymmetricSample * 0.7)
            } else {
                return tanh(asymmetricSample * 1.2)
            }
            
        case .diode:
            // Diode-style clipping (exponential)
            let sign = asymmetricSample >= 0.0 ? 1.0 : -1.0
            let abs_sample = abs(asymmetricSample)
            if abs_sample < 0.1 {
                return asymmetricSample
            } else {
                let clipped = sign * (0.1 + 0.9 * (1.0 - exp(-Double(abs_sample - 0.1) * 3.0)))
                return Float(max(-1.0, min(1.0, clipped)))
            }
            
        case .foldback:
            // Foldback distortion
            var folded = asymmetricSample
            while abs(folded) > 1.0 {
                if folded > 1.0 {
                    folded = 2.0 - folded
                } else if folded < -1.0 {
                    folded = -2.0 - folded
                }
            }
            return folded
        }
    }
    
    private func applyDCBlocker(_ sample: Float) -> Float {
        // Simple DC blocking filter (high-pass)
        let output = sample - dcBlockerX1 + 0.995 * dcBlockerY1
        dcBlockerX1 = sample
        dcBlockerY1 = output
        return output
    }
    
    private func applyToneFilter(_ sample: Float) -> Float {
        // Simple one-pole low-pass filter for tone control
        toneFilterState = toneFilterState * toneFilterCoeff + sample * (1.0 - toneFilterCoeff)
        return toneFilterState
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
        toneFilterState = 0.0
        dcBlockerX1 = 0.0
        dcBlockerY1 = 0.0
    }
    
    // MARK: - Preset Management
    
    public override func loadEffectPreset(_ preset: EffectPreset) {
        super.loadEffectPreset(preset)
        
        // Load overdrive specific parameters
        if let driveValue = preset.parameters["drive_amount"] {
            driveAmount = driveValue
        }
        
        if let outputValue = preset.parameters["output_level"] {
            outputLevel = outputValue
        }
        
        if let curveValue = preset.parameters["clipping_curve"] {
            switch Int(curveValue) {
            case 0: clippingCurve = .soft
            case 1: clippingCurve = .hard
            case 2: clippingCurve = .tube
            case 3: clippingCurve = .diode
            case 4: clippingCurve = .foldback
            default: clippingCurve = .soft
            }
        }
        
        if let asymmetryValue = preset.parameters["asymmetry"] {
            asymmetry = asymmetryValue
        }
        
        if let toneValue = preset.parameters["tone"] {
            tone = toneValue
        }
    }
    
    public override func saveEffectPreset(name: String) -> EffectPreset {
        let basePreset = super.saveEffectPreset(name: name)

        // Create new parameters dictionary with overdrive specific parameters
        var allParameters = basePreset.parameters
        allParameters["drive_amount"] = driveAmount
        allParameters["output_level"] = outputLevel
        allParameters["clipping_curve"] = Float(clippingCurve == .soft ? 0 : (clippingCurve == .hard ? 1 : (clippingCurve == .tube ? 2 : (clippingCurve == .diode ? 3 : 4))))
        allParameters["asymmetry"] = asymmetry
        allParameters["tone"] = tone

        return EffectPreset(
            name: name,
            description: nil,
            effectType: .overdrive,
            parameters: allParameters,
            metadata: basePreset.metadata
        )
    }
}

// MARK: - Factory Method

extension OverdriveEffect {
    /// Create an overdrive effect with common presets
    public static func createPreset(_ preset: OverdrivePreset) -> OverdriveEffect {
        let effect = OverdriveEffect()
        
        switch preset {
        case .clean:
            effect.driveAmount = 1.2
            effect.clippingCurve = .soft
            effect.asymmetry = 0.0
            effect.tone = 0.7
            effect.outputLevel = -2.0
            effect.wetLevel = 0.5
            
        case .warm:
            effect.driveAmount = 2.5
            effect.clippingCurve = .tube
            effect.asymmetry = 0.2
            effect.tone = 0.6
            effect.outputLevel = -4.0
            effect.wetLevel = 0.8
            
        case .crunch:
            effect.driveAmount = 4.0
            effect.clippingCurve = .diode
            effect.asymmetry = 0.1
            effect.tone = 0.5
            effect.outputLevel = -6.0
            effect.wetLevel = 1.0
            
        case .heavy:
            effect.driveAmount = 7.0
            effect.clippingCurve = .hard
            effect.asymmetry = 0.0
            effect.tone = 0.4
            effect.outputLevel = -8.0
            effect.wetLevel = 1.0
            
        case .fuzz:
            effect.driveAmount = 10.0
            effect.clippingCurve = .foldback
            effect.asymmetry = 0.3
            effect.tone = 0.3
            effect.outputLevel = -10.0
            effect.wetLevel = 1.0
        }
        
        return effect
    }
}

/// Overdrive presets
public enum OverdrivePreset: String, CaseIterable {
    case clean = "Clean"
    case warm = "Warm"
    case crunch = "Crunch"
    case heavy = "Heavy"
    case fuzz = "Fuzz"
}
