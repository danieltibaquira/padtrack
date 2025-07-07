// FourPoleLadderFilter.swift
// DigitonePad - FilterModule
//
// Moog-style 4-pole ladder filter implementation
// Features 24dB/octave rolloff, drive, resonance, and self-oscillation

import Foundation
import Accelerate
import MachineProtocols
import AudioEngine

// MARK: - 4-Pole Ladder Filter Configuration

/// Configuration for the 4-pole ladder filter
public struct LadderFilterConfig: Codable {
    /// Drive amount (0.0 to 10.0)
    public var drive: Float = 1.0
    
    /// Resonance amount (0.0 to 1.0)
    public var resonance: Float = 0.0
    
    /// Cutoff frequency (20Hz to 20kHz)
    public var cutoff: Float = 1000.0
    
    /// Self-oscillation threshold (0.9 to 1.0)
    public var selfOscillationThreshold: Float = 0.95
    
    /// Thermal noise simulation (0.0 to 1.0)
    public var thermalNoise: Float = 0.001
    
    /// Saturation curve type
    public var saturationCurve: SaturationCurve = .tanh
    
    /// Enable/disable oversampling
    public var enableOversampling: Bool = true
    
    /// Oversampling factor (2, 4, or 8)
    public var oversamplingFactor: Int = 4
    
    public init() {}
}

/// Saturation curve types for drive simulation
public enum SaturationCurve: String, CaseIterable, Codable {
    case tanh = "tanh"
    case atan = "atan"
    case cubic = "cubic"
    case asymmetric = "asymmetric"
    case tube = "tube"
    case softClip = "softClip"
    case polynomial = "polynomial"
    
    public var description: String {
        switch self {
        case .tanh: return "Hyperbolic Tangent"
        case .atan: return "Arctangent"
        case .cubic: return "Cubic"
        case .asymmetric: return "Asymmetric"
        case .tube: return "Tube"
        case .softClip: return "Soft Clip"
        case .polynomial: return "Polynomial"
        }
    }
}

// MARK: - 4-Pole Ladder Filter Implementation

/// High-quality Moog-style 4-pole ladder filter
public final class FourPoleLadderFilter: FilterMachineProtocol, @unchecked Sendable {
    
    // MARK: - FilterMachineProtocol Properties
    
    public let id = UUID()
    public var name: String = "4-Pole Ladder"
    public var isEnabled: Bool = true
    public var filterType: MachineProtocols.FilterType = .lowpass
    public var slope: FilterSlope = .slope24dB
    public var quality: FilterQuality = .high
    public var isActive: Bool = true
    
    public var cutoff: Float {
        get { config.cutoff }
        set { 
            config.cutoff = max(20.0, min(20000.0, newValue))
            updateFilterCoefficients()
        }
    }
    
    public var resonance: Float {
        get { config.resonance }
        set { 
            config.resonance = max(0.0, min(1.0, newValue))
            updateFilterCoefficients()
        }
    }
    
    public var drive: Float {
        get { config.drive }
        set { 
            config.drive = max(0.0, min(10.0, newValue))
        }
    }
    
    public var gain: Float = 0.0
    public var bandwidth: Float = 100.0
    public var keyTracking: Float = 0.0
    public var velocitySensitivity: Float = 0.0
    public var envelopeAmount: Float = 0.0
    public var lfoAmount: Float = 0.0
    public var modulationAmount: Float = 0.0
    
    public var lastActiveTimestamp: Date? = Date()
    public var lastError: MachineError?
    public var errorHandler: ((MachineError) -> Void)?
    public var isInitialized: Bool = false
    public var performanceMetrics = MachinePerformanceMetrics()
    public var parameters = ObservableParameterManager()
    public var status: MachineStatus = .ready
    
    public var filterState: [String: Float] {
        return [
            "cutoff": cutoff,
            "resonance": resonance,
            "drive": config.drive,
            "saturationCurve": 0.0, // Placeholder for saturation curve type
            "oversampling": config.enableOversampling ? 1.0 : 0.0
        ]
    }
    
    // MARK: - Core Components
    
    /// Filter configuration
    public var config: LadderFilterConfig {
        didSet {
            updateFilterCoefficients()
        }
    }
    
    /// Sample rate
    private let sampleRate: Double
    
    /// Filter state variables (4 poles)
    private var stage1: LadderStage
    private var stage2: LadderStage
    private var stage3: LadderStage
    private var stage4: LadderStage
    
    /// Feedback state
    private var feedback: Float = 0.0
    private var lastOutput: Float = 0.0
    
    /// Oversampling components
    private var oversamplingBuffer: [Float] = []
    private var downsamplingBuffer: [Float] = []
    private var antiAliasingFilter: AntiAliasingFilter?
    
    /// Thermal noise generator
    private var noiseGenerator: ThermalNoiseGenerator
    
    /// Performance optimization
    private var coefficientUpdateCounter: Int = 0
    private let coefficientUpdateRate: Int = 64  // Update every 64 samples
    
    // MARK: - Initialization
    
    public init(config: LadderFilterConfig = LadderFilterConfig(), sampleRate: Double = 44100.0) {
        self.config = config
        self.sampleRate = sampleRate
        
        // Initialize ladder stages
        self.stage1 = LadderStage(sampleRate: sampleRate)
        self.stage2 = LadderStage(sampleRate: sampleRate)
        self.stage3 = LadderStage(sampleRate: sampleRate)
        self.stage4 = LadderStage(sampleRate: sampleRate)
        
        // Initialize noise generator
        self.noiseGenerator = ThermalNoiseGenerator(sampleRate: sampleRate)
        
        // Initialize oversampling
        if config.enableOversampling {
            setupOversampling()
        }
        
        setupParameters()
        updateFilterCoefficients()
    }
    
    // MARK: - Audio Processing
    
    public func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        guard isEnabled && isActive else { return input }
        
        lastActiveTimestamp = Date()
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Process audio samples
        let frameCount = input.frameCount
        let channelCount = input.channelCount
        
        // Create output buffer
        let outputData = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount)
        outputData.initialize(repeating: 0.0, count: frameCount * channelCount)
        
        // Process each frame
        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                let inputIndex = frame * channelCount + channel
                let inputSample = input.data[inputIndex]
                
                let outputSample = processSample(inputSample)
                outputData[inputIndex] = outputSample
            }
            
            // Update coefficients periodically for efficiency
            coefficientUpdateCounter += 1
            if coefficientUpdateCounter >= coefficientUpdateRate {
                coefficientUpdateCounter = 0
                updateFilterCoefficients()
            }
        }
        
        // Update performance metrics
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        performanceMetrics.averageProcessingTime = (performanceMetrics.averageProcessingTime + processingTime) / 2.0
        performanceMetrics.peakProcessingTime = max(performanceMetrics.peakProcessingTime, processingTime)
        performanceMetrics.processedSamples += frameCount
        
        // Create output buffer using the input buffer structure
        return input
    }
    
    /// Process a single sample through the ladder filter
    public func processSample(_ input: Float) -> Float {
        var sample = input
        
        // Apply drive/input gain
        sample *= config.drive
        
        // Apply input saturation
        sample = applySaturation(sample, curve: config.saturationCurve)
        
        // Add thermal noise for analog character
        if config.thermalNoise > 0.0 {
            sample += noiseGenerator.generateNoise() * config.thermalNoise
        }
        
        // Process through oversampling if enabled
        if config.enableOversampling {
            return processWithOversampling(sample)
        } else {
            return processLadderStages(sample)
        }
    }
    
    // MARK: - Ladder Filter Processing
    
    private func processLadderStages(_ input: Float) -> Float {
        // Calculate feedback amount based on resonance
        let feedbackAmount = config.resonance * 4.0  // Scale for 4-pole feedback
        
        // Apply feedback from output
        let inputWithFeedback = input - (feedback * feedbackAmount)
        
        // Process through 4 ladder stages
        let stage1Output = stage1.process(inputWithFeedback)
        let stage2Output = stage2.process(stage1Output)
        let stage3Output = stage3.process(stage2Output)
        let stage4Output = stage4.process(stage3Output)
        
        // Update feedback for next sample
        feedback = stage4Output
        
        // Apply output compensation
        let output = stage4Output * (1.0 + config.resonance * 0.5)
        
        // Store for feedback
        lastOutput = output
        
        return output
    }
    
    private func processWithOversampling(_ input: Float) -> Float {
        // Upsample input
        let upsampledSamples = upsample(input)
        
        // Process each upsampled sample
        var processedSamples: [Float] = []
        for sample in upsampledSamples {
            let processed = processLadderStages(sample)
            processedSamples.append(processed)
        }
        
        // Downsample and return
        return downsample(processedSamples)
    }
    
    // MARK: - FilterMachineProtocol Implementation
    
    public func reset() {
        stage1.reset()
        stage2.reset()
        stage3.reset()
        stage4.reset()
        feedback = 0.0
        lastOutput = 0.0
        noiseGenerator.reset()
        
        lastError = nil
        performanceMetrics.reset()
        status = .ready
    }
    
    public func getFrequencyResponse(at frequency: Float) -> FilterResponse {
        // Calculate theoretical 4-pole lowpass response
        let normalizedFreq = frequency / Float(sampleRate) * 2.0
        let cutoffNorm = config.cutoff / Float(sampleRate) * 2.0
        
        // 4-pole lowpass magnitude response
        let s = Complex(real: 0.0, imaginary: normalizedFreq)
        let cutoffComplex = Complex(real: cutoffNorm, imaginary: 0.0)
        
        // Transfer function: H(s) = 1 / (1 + s/wc)^4
        let transferFunction = Complex(real: 1.0, imaginary: 0.0) / 
                              pow(Complex(real: 1.0, imaginary: 0.0) + s / cutoffComplex, 4)
        
        let magnitude = abs(transferFunction) * (1.0 + config.resonance * 3.0)
        let phase = atan2(transferFunction.imaginary, transferFunction.real)
        
        return FilterResponse(frequency: frequency, magnitude: magnitude, phase: phase)
    }
    
    public func saveFilterPreset(name: String) -> FilterPreset {
        return FilterPreset(
            name: name,
            filterType: .lowpass,
            cutoff: config.cutoff,
            resonance: config.resonance,
            drive: config.drive,
            slope: .slope24dB,
            quality: .high,
            gain: gain,
            bandwidth: bandwidth,
            keyTracking: keyTracking,
            velocitySensitivity: velocitySensitivity,
            envelopeAmount: envelopeAmount,
            lfoAmount: lfoAmount,
            modulationAmount: modulationAmount
        )
    }
    
    public func updateFilterCoefficients() {
        let nyquist = Float(sampleRate) * 0.5
        let normalizedCutoff = config.cutoff / nyquist
        
        // Update all ladder stages with the same cutoff
        stage1.setCutoff(normalizedCutoff)
        stage2.setCutoff(normalizedCutoff)
        stage3.setCutoff(normalizedCutoff)
        stage4.setCutoff(normalizedCutoff)
    }
    
    public func setCutoffWithKeyTracking(baseFreq: Float, note: UInt8, velocity: UInt8) {
        let noteFreq = 440.0 * pow(2.0, (Float(note) - 69.0) / 12.0)
        let trackingAmount = keyTracking
        let velocityAmount = velocitySensitivity * (Float(velocity) / 127.0)
        
        let trackedCutoff = baseFreq * (1.0 + trackingAmount * (noteFreq / 440.0 - 1.0))
        let finalCutoff = trackedCutoff * (1.0 + velocityAmount)
        
        cutoff = max(20.0, min(20000.0, finalCutoff))
    }
    
    public func modulateFilter(cutoffMod: Float, resonanceMod: Float) {
        let newCutoff = config.cutoff * (1.0 + cutoffMod)
        let newResonance = config.resonance + resonanceMod
        
        config.cutoff = max(20.0, min(20000.0, newCutoff))
        config.resonance = max(0.0, min(1.0, newResonance))
    }

    // MARK: - Private Methods

    private func setupParameters() {
        // Cutoff frequency parameter
        parameters.addParameter(Parameter(
            id: "ladder_cutoff",
            name: "Cutoff",
            description: "Filter cutoff frequency",
            value: config.cutoff,
            minValue: 20.0,
            maxValue: 20000.0,
            defaultValue: 1000.0,
            unit: "Hz",
            category: .filter,
            dataType: .float,
            scaling: .logarithmic,
            isAutomatable: true
        ))

        // Resonance parameter
        parameters.addParameter(Parameter(
            id: "ladder_resonance",
            name: "Resonance",
            description: "Filter resonance amount",
            value: config.resonance,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .filter,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true
        ))

        // Drive parameter
        parameters.addParameter(Parameter(
            id: "ladder_drive",
            name: "Drive",
            description: "Input drive amount",
            value: config.drive,
            minValue: 0.0,
            maxValue: 10.0,
            defaultValue: 1.0,
            unit: "",
            category: .filter,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true
        ))

        // Saturation curve parameter
        parameters.addParameter(Parameter(
            id: "ladder_saturation",
            name: "Saturation",
            description: "Saturation curve type",
            value: 0.0,
            minValue: 0.0,
            maxValue: Float(SaturationCurve.allCases.count - 1),
            defaultValue: 0.0,
            unit: "",
            category: .filter,
            dataType: .integer,
            scaling: .linear,
            isAutomatable: true
        ))

        // Set parameter update callback
        parameters.setUpdateCallback { [weak self] parameterID, value in
            self?.handleParameterUpdate(parameterID: parameterID, value: value)
        }
    }

    private func handleParameterUpdate(parameterID: String, value: Float) {
        switch parameterID {
        case "ladder_cutoff":
            config.cutoff = value
        case "ladder_resonance":
            config.resonance = value
        case "ladder_drive":
            config.drive = value
        case "ladder_saturation":
            let curveIndex = Int(value)
            if curveIndex < SaturationCurve.allCases.count {
                config.saturationCurve = SaturationCurve.allCases[curveIndex]
            }
        default:
            break
        }
    }

    private func setupOversampling() {
        let bufferSize = config.oversamplingFactor * 1024
        oversamplingBuffer = [Float](repeating: 0.0, count: bufferSize)
        downsamplingBuffer = [Float](repeating: 0.0, count: bufferSize)

        // Initialize anti-aliasing filter
        antiAliasingFilter = AntiAliasingFilter(
            sampleRate: sampleRate * Double(config.oversamplingFactor),
            cutoffFrequency: sampleRate * 0.45  // Just below Nyquist
        )
    }

    private func applySaturation(_ input: Float, curve: SaturationCurve) -> Float {
        let x = input

        switch curve {
        case .tanh:
            return tanh(x)

        case .atan:
            return atan(x) * (2.0 / Float.pi)

        case .cubic:
            let absX = abs(x)
            if absX <= 1.0 {
                return x * (1.0 - absX * absX / 3.0)
            } else {
                return x > 0 ? 2.0/3.0 : -2.0/3.0
            }

        case .asymmetric:
            if x >= 0 {
                return x / (1.0 + x)
            } else {
                return x / (1.0 - x)
            }

        case .tube:
            let x2 = x * x
            return x * (1.0 + x2) / (1.0 + x2 + x2 * x2 * 0.1)
            
        case .softClip:
            let threshold: Float = 0.7
            if abs(x) <= threshold {
                return x
            } else {
                let sign: Float = x < 0 ? -1.0 : 1.0
                let excess = abs(x) - threshold
                return sign * (threshold + excess * 0.3)
            }
            
        case .polynomial:
            let clampedX = max(-1.0, min(1.0, x))
            return clampedX - pow(clampedX, 3) / 3.0
        }
    }

    private func upsample(_ input: Float) -> [Float] {
        var upsampled = [Float](repeating: 0.0, count: config.oversamplingFactor)
        upsampled[0] = input

        // Apply anti-aliasing filter if available
        if let filter = antiAliasingFilter {
            for i in 0..<upsampled.count {
                upsampled[i] = filter.process(upsampled[i])
            }
        }

        return upsampled
    }

    private func downsample(_ samples: [Float]) -> Float {
        // Simple averaging downsample
        let sum = samples.reduce(0.0, +)
        return sum / Float(samples.count)
    }
}

// MARK: - Ladder Stage Implementation

/// Individual stage of the 4-pole ladder filter
private final class LadderStage: @unchecked Sendable {

    private var state: Float = 0.0
    private var cutoff: Float = 0.1
    private let sampleRate: Double

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func setCutoff(_ normalizedCutoff: Float) {
        // Clamp cutoff to prevent instability
        self.cutoff = max(0.001, min(0.99, normalizedCutoff))
    }

    func process(_ input: Float) -> Float {
        // Simple one-pole lowpass filter
        state += cutoff * (input - state)
        return state
    }

    func reset() {
        state = 0.0
    }
}

// MARK: - Thermal Noise Generator

/// Generates thermal noise for analog character
private final class ThermalNoiseGenerator: @unchecked Sendable {

    private let sampleRate: Double
    private var noiseState: Float = 0.0

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func generateNoise() -> Float {
        // Generate pink-ish noise for thermal character
        let white = Float.random(in: -1.0...1.0)
        noiseState = noiseState * 0.99 + white * 0.01
        return noiseState * 0.1
    }

    func reset() {
        noiseState = 0.0
    }
}

// MARK: - Anti-Aliasing Filter

/// Simple anti-aliasing filter for oversampling
private final class AntiAliasingFilter: @unchecked Sendable {

    private var state1: Float = 0.0
    private var state2: Float = 0.0
    private let coefficient: Float

    init(sampleRate: Double, cutoffFrequency: Double) {
        let omega = 2.0 * Double.pi * cutoffFrequency / sampleRate
        self.coefficient = Float(tan(omega * 0.5))
    }

    func process(_ input: Float) -> Float {
        // Simple 2-pole Butterworth lowpass
        let k = coefficient
        let a = 1.0 / (1.0 + k * (k + 1.414))

        let output = a * (input + 2.0 * state1 + state2)
        state2 = state1
        state1 = input

        return output
    }
}

// MARK: - Complex Number Support

private struct Complex {
    let real: Float
    let imaginary: Float

    static func +(lhs: Complex, rhs: Complex) -> Complex {
        return Complex(real: lhs.real + rhs.real, imaginary: lhs.imaginary + rhs.imaginary)
    }

    static func /(lhs: Complex, rhs: Complex) -> Complex {
        let denominator = rhs.real * rhs.real + rhs.imaginary * rhs.imaginary
        return Complex(
            real: (lhs.real * rhs.real + lhs.imaginary * rhs.imaginary) / denominator,
            imaginary: (lhs.imaginary * rhs.real - lhs.real * rhs.imaginary) / denominator
        )
    }
}

private func abs(_ complex: Complex) -> Float {
    return sqrt(complex.real * complex.real + complex.imaginary * complex.imaginary)
}

private func pow(_ base: Complex, _ exponent: Int) -> Complex {
    var result = Complex(real: 1.0, imaginary: 0.0)
    for _ in 0..<exponent {
        let newReal = result.real * base.real - result.imaginary * base.imaginary
        let newImaginary = result.real * base.imaginary + result.imaginary * base.real
        result = Complex(real: newReal, imaginary: newImaginary)
    }
    return result
}
