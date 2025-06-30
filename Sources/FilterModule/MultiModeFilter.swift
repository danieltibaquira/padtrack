// MultiModeFilter.swift
// DigitonePad - FilterModule
//
// Multi-Mode Filter with morphing between LP-BP-HP filter types
// Uses state-variable filter topology for smooth morphing

import Foundation
import MachineProtocols
import AudioEngine

/// Multi-Mode Filter implementing morphing between LP, BP, and HP filter types
/// Uses a state-variable filter design for smooth transitions
public class MultiModeFilter: FilterMachineProtocol, SerializableMachine, @unchecked Sendable {
    public let id = UUID()
    public var name: String
    public var isEnabled: Bool = true
    public var filterType: MachineProtocols.FilterType = .lowpass
    public var slope: FilterSlope = .slope24dB
    public var quality: FilterQuality = .medium
    public var isActive: Bool = true

    // Enhanced MachineProtocol properties
    public var isInitialized: Bool = false
    public var status: MachineStatus = .uninitialized
    public var lastActiveTimestamp: Date?
    public var lastError: MachineError?
    public var errorHandler: ((MachineError) -> Void)?
    public var performanceMetrics: MachinePerformanceMetrics = MachinePerformanceMetrics()
    public var parameters: ObservableParameterManager = ObservableParameterManager()

    // Multi-Mode Filter specific properties
    /// Morph parameter: 0.0 = LP, 0.5 = BP, 1.0 = HP
    public var morph: Float = 0.0
    
    // State-variable filter state variables
    private var lowpass1: Float = 0.0
    private var bandpass1: Float = 0.0
    private var lowpass2: Float = 0.0
    private var bandpass2: Float = 0.0
    
    // Filter coefficients
    private var frequency: Float = 0.0
    private var dampening: Float = 0.0
    
    // Parameter smoothing
    private var smoothedCutoff: Float = 1000.0
    private var smoothedResonance: Float = 0.1
    private var smoothedMorph: Float = 0.0
    private var smoothedDrive: Float = 0.0
    
    // Smoothing coefficients (for 44.1kHz, adjust for other sample rates)
    private let smoothingCoeff: Float = 0.999
    
    public var filterState: [String: Float] {
        return [
            "cutoff": cutoff,
            "resonance": resonance,
            "drive": drive,
            "gain": gain,
            "bandwidth": bandwidth,
            "morph": morph,
            "lowpass1": lowpass1,
            "bandpass1": bandpass1,
            "lowpass2": lowpass2,
            "bandpass2": bandpass2
        ]
    }
    
    public init(name: String) {
        self.name = name
        setupMultiModeFilterParameters()
    }
    
    // MARK: - Core Processing
    
    public func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        lastActiveTimestamp = Date()
        
        guard isActive && isEnabled else {
            return input
        }
        
        // Update smoothed parameters
        updateSmoothedParameters()
        
        // Update filter coefficients
        updateFilterCoefficients()
        
        var output = input
        
        // Process each sample
        for i in 0..<output.samples.count {
            var sample = output.samples[i]
            
            // Apply drive/saturation before filtering
            if smoothedDrive > 0.0 {
                sample = applySaturation(sample, drive: smoothedDrive)
            }
            
            // State-variable filter processing (2-pole)
            let (lp, bp, hp) = processStateVariableFilter(sample)
            
            // Morph between filter outputs
            let morphedOutput = morphFilterOutputs(lp: lp, bp: bp, hp: hp, morph: smoothedMorph)
            
            output.samples[i] = morphedOutput
        }
        
        return output
    }
    
    // MARK: - State-Variable Filter Implementation
    
    /// Process a single sample through the state-variable filter
    /// Returns (lowpass, bandpass, highpass) outputs
    private func processStateVariableFilter(_ input: Float) -> (Float, Float, Float) {
        // First stage
        let highpass1 = input - lowpass1 - dampening * bandpass1
        bandpass1 += frequency * highpass1
        lowpass1 += frequency * bandpass1
        
        // Second stage (for 24dB slope)
        let highpass2 = lowpass1 - lowpass2 - dampening * bandpass2
        bandpass2 += frequency * highpass2
        lowpass2 += frequency * bandpass2
        
        return (lowpass2, bandpass2, highpass2)
    }
    
    /// Morph between filter outputs based on morph parameter
    private func morphFilterOutputs(lp: Float, bp: Float, hp: Float, morph: Float) -> Float {
        if morph <= 0.5 {
            // Morph between LP and BP
            let blend = morph * 2.0
            return lp * (1.0 - blend) + bp * blend
        } else {
            // Morph between BP and HP
            let blend = (morph - 0.5) * 2.0
            return bp * (1.0 - blend) + hp * blend
        }
    }
    
    /// Apply saturation/drive to input signal
    private func applySaturation(_ input: Float, drive: Float) -> Float {
        let driveAmount = 1.0 + drive * 9.0 // 1x to 10x gain
        let driven = input * driveAmount
        
        // Soft clipping using tanh
        return tanh(driven) / driveAmount
    }
    
    // MARK: - Parameter Management
    
    private func updateSmoothedParameters() {
        smoothedCutoff = smoothedCutoff * smoothingCoeff + cutoff * (1.0 - smoothingCoeff)
        smoothedResonance = smoothedResonance * smoothingCoeff + resonance * (1.0 - smoothingCoeff)
        smoothedMorph = smoothedMorph * smoothingCoeff + morph * (1.0 - smoothingCoeff)
        smoothedDrive = smoothedDrive * smoothingCoeff + drive * (1.0 - smoothingCoeff)
    }
    
    public func updateFilterCoefficients() {
        // Calculate filter coefficients for state-variable filter
        let sampleRate: Float = 44100.0 // TODO: Get from audio engine
        let nyquist = sampleRate * 0.5
        
        // Clamp cutoff frequency
        let clampedCutoff = max(20.0, min(nyquist * 0.99, smoothedCutoff))
        
        // Calculate frequency coefficient
        frequency = 2.0 * sin(Float.pi * clampedCutoff / sampleRate)
        
        // Calculate dampening (resonance) coefficient
        // Higher resonance = lower dampening
        let q = 0.5 + smoothedResonance * 19.5 // Q range: 0.5 to 20
        dampening = 1.0 / q
        
        lastActiveTimestamp = Date()
    }
    
    private func setupMultiModeFilterParameters() {
        // Set up base filter parameters
        setupFilterParameters()
        
        // Add morph parameter
        let morphParam = Parameter(
            id: "filter_morph",
            name: "Morph",
            description: "Morph between LP-BP-HP filter types",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .filter
        )
        
        parameters.addParameter(morphParam)
    }
    
    // MARK: - FilterMachineProtocol Implementation
    
    public func getFrequencyResponse(at frequency: Float) -> FilterResponse {
        // Calculate frequency response for current morph setting
        let normalizedFreq = frequency / 20000.0
        let cutoffNorm = cutoff / 20000.0
        
        var magnitude: Float = 1.0
        let phase: Float = 0.0
        
        // Calculate response based on morph position
        if morph <= 0.5 {
            // LP to BP transition
            let blend = morph * 2.0
            let lpMag = calculateLowpassResponse(normalizedFreq, cutoffNorm)
            let bpMag = calculateBandpassResponse(normalizedFreq, cutoffNorm)
            magnitude = lpMag * (1.0 - blend) + bpMag * blend
        } else {
            // BP to HP transition
            let blend = (morph - 0.5) * 2.0
            let bpMag = calculateBandpassResponse(normalizedFreq, cutoffNorm)
            let hpMag = calculateHighpassResponse(normalizedFreq, cutoffNorm)
            magnitude = bpMag * (1.0 - blend) + hpMag * blend
        }
        
        // Apply drive effect
        magnitude *= (1.0 + drive * 0.5)
        
        return FilterResponse(frequency: frequency, magnitude: magnitude, phase: phase)
    }
    
    private func calculateLowpassResponse(_ normalizedFreq: Float, _ cutoffNorm: Float) -> Float {
        if normalizedFreq > cutoffNorm {
            let rolloff = pow(normalizedFreq / cutoffNorm, -4.0) // 24dB/octave
            return rolloff * (1.0 + resonance * 2.0)
        }
        return 1.0 + resonance * 0.5
    }
    
    private func calculateBandpassResponse(_ normalizedFreq: Float, _ cutoffNorm: Float) -> Float {
        let distance = abs(normalizedFreq - cutoffNorm)
        let response = 1.0 / (1.0 + distance * 10.0)
        return response * (1.0 + resonance * 3.0)
    }
    
    private func calculateHighpassResponse(_ normalizedFreq: Float, _ cutoffNorm: Float) -> Float {
        if normalizedFreq < cutoffNorm {
            let rolloff = pow(normalizedFreq / cutoffNorm, 4.0) // 24dB/octave
            return rolloff * (1.0 + resonance * 2.0)
        }
        return 1.0 + resonance * 0.5
    }
    
    public func resetFilterState() {
        lowpass1 = 0.0
        bandpass1 = 0.0
        lowpass2 = 0.0
        bandpass2 = 0.0
        smoothedCutoff = cutoff
        smoothedResonance = resonance
        smoothedMorph = morph
        smoothedDrive = drive
        isActive = true
    }
    
    public func loadFilterPreset(_ preset: FilterPreset) {
        filterType = preset.filterType
        cutoff = preset.cutoff
        resonance = preset.resonance
        drive = preset.drive
        slope = preset.slope
        quality = preset.quality
        gain = preset.gain
        bandwidth = preset.bandwidth
        keyTracking = preset.keyTracking
        velocitySensitivity = preset.velocitySensitivity
        envelopeAmount = preset.envelopeAmount
        lfoAmount = preset.lfoAmount
        modulationAmount = preset.modulationAmount
        
        // Set morph based on filter type
        switch preset.filterType {
        case .lowpass:
            morph = 0.0
        case .bandpass:
            morph = 0.5
        case .highpass:
            morph = 1.0
        default:
            morph = 0.0
        }
        
        updateFilterCoefficients()
    }
    
    public func saveFilterPreset(name: String) -> FilterPreset {
        return FilterPreset(
            name: name,
            filterType: filterType,
            cutoff: cutoff,
            resonance: resonance,
            drive: drive,
            slope: slope,
            quality: quality,
            gain: gain,
            bandwidth: bandwidth,
            keyTracking: keyTracking,
            velocitySensitivity: velocitySensitivity,
            envelopeAmount: envelopeAmount,
            lfoAmount: lfoAmount,
            modulationAmount: modulationAmount
        )
    }

    public func setCutoffWithKeyTracking(baseFreq: Float, note: UInt8, velocity: UInt8) {
        let noteFreq = 440.0 * pow(2.0, (Float(note) - 69.0) / 12.0)
        let trackingAmount = keyTracking
        let velocityAmount = velocitySensitivity * (Float(velocity) / 127.0)

        let trackedCutoff = baseFreq * (1.0 + trackingAmount * (noteFreq / 440.0 - 1.0))
        let finalCutoff = trackedCutoff * (1.0 + velocityAmount)

        cutoff = max(20.0, min(20000.0, finalCutoff))
        updateFilterCoefficients()
    }

    public func modulateFilter(cutoffMod: Float, resonanceMod: Float) {
        let newCutoff = cutoff * (1.0 + cutoffMod)
        let newResonance = resonance + resonanceMod

        cutoff = max(20.0, min(20000.0, newCutoff))
        resonance = max(0.0, min(1.0, newResonance))
        updateFilterCoefficients()
    }

    // MARK: - Enhanced MachineProtocol Implementation

    public func initialize(configuration: MachineConfiguration) throws {
        status = .initializing

        // Initialize filter state
        resetFilterState()

        // Set up parameters if not already done
        if parameters.parameters.isEmpty {
            setupMultiModeFilterParameters()
        }

        isInitialized = true
        status = .ready
    }

    public func start() throws {
        guard isInitialized else {
            throw CommonMachineError(code: "NOT_INITIALIZED", message: "MultiModeFilter not initialized", severity: .error)
        }
        status = .running
    }

    public func stop() throws {
        status = .stopping
        resetFilterState()
        status = .ready
    }

    public func suspend() throws {
        status = .suspended
    }

    public func resume() throws {
        status = .running
    }

    public func reset() {
        resetFilterState()
        filterType = .lowpass
        slope = .slope24dB
        quality = .medium
        isActive = true
        isEnabled = true
        morph = 0.0
        lastError = nil
        performanceMetrics.reset()
        parameters.resetAllToDefaults()
        status = .ready
    }

    public func updateParameter(key: String, value: Any) throws {
        switch key {
        case "cutoff":
            if let floatValue = value as? Float {
                cutoff = floatValue
                updateFilterCoefficients()
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for cutoff", severity: .error)
            }
        case "resonance":
            if let floatValue = value as? Float {
                resonance = floatValue
                updateFilterCoefficients()
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for resonance", severity: .error)
            }
        case "drive":
            if let floatValue = value as? Float {
                drive = floatValue
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for drive", severity: .error)
            }
        case "morph":
            if let floatValue = value as? Float {
                morph = max(0.0, min(1.0, floatValue))
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for morph", severity: .error)
            }
        case "filterType":
            if let stringValue = value as? String, let type = FilterType(rawValue: stringValue) {
                filterType = type
                // Update morph to match filter type
                switch type {
                case .lowpass:
                    morph = 0.0
                case .bandpass:
                    morph = 0.5
                case .highpass:
                    morph = 1.0
                default:
                    break
                }
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for filterType", severity: .error)
            }
        default:
            throw CommonMachineError(code: "UNKNOWN_PARAMETER", message: "Unknown parameter: \(key)", severity: .warning)
        }
    }

    public func resetPerformanceCounters() {
        performanceMetrics.reset()
    }

    public func getState() -> MachineState {
        return MachineState(
            machineType: "MultiModeFilter",
            parameters: parameters.getAllValues(),
            metadata: [
                "name": name,
                "enabled": String(isEnabled),
                "filterType": filterType.rawValue,
                "slope": slope.rawValue,
                "quality": quality.rawValue,
                "isActive": String(isActive),
                "status": status.rawValue,
                "isInitialized": String(isInitialized),
                "morph": String(morph)
            ]
        )
    }

    public func setState(_ state: MachineState) {
        if let nameValue = state.metadata["name"] {
            name = nameValue
        }
        if let enabledString = state.metadata["enabled"] {
            isEnabled = enabledString == "true"
        }
        if let filterTypeString = state.metadata["filterType"],
           let type = FilterType(rawValue: filterTypeString) {
            filterType = type
        }
        if let slopeString = state.metadata["slope"],
           let filterSlope = FilterSlope(rawValue: slopeString) {
            slope = filterSlope
        }
        if let qualityString = state.metadata["quality"],
           let filterQuality = FilterQuality(rawValue: qualityString) {
            quality = filterQuality
        }
        if let activeString = state.metadata["isActive"] {
            isActive = activeString == "true"
        }
        if let statusString = state.metadata["status"],
           let machineStatus = MachineStatus(rawValue: statusString) {
            status = machineStatus
        }
        if let initializedString = state.metadata["isInitialized"] {
            isInitialized = initializedString == "true"
        }
        if let morphString = state.metadata["morph"],
           let morphValue = Float(morphString) {
            morph = morphValue
        }

        // Set parameters
        do {
            try parameters.setValues(state.parameters, notifyChanges: false)
        } catch {
            // Log error but don't throw - allow partial state restoration
            if let errorHandler = errorHandler {
                errorHandler(CommonMachineError(
                    code: "STATE_RESTORATION_PARTIAL_FAILURE",
                    message: "Failed to restore some parameters: \(error.localizedDescription)",
                    severity: .warning
                ))
            }
        }

        // Update filter coefficients after state restoration
        updateFilterCoefficients()
    }

    public func healthCheck() -> MachineHealthStatus {
        // Check for NaN or infinite values in filter state
        if lowpass1.isNaN || lowpass1.isInfinite ||
           bandpass1.isNaN || bandpass1.isInfinite ||
           lowpass2.isNaN || lowpass2.isInfinite ||
           bandpass2.isNaN || bandpass2.isInfinite {
            return .critical
        }

        // Check parameter ranges
        if cutoff < 20.0 || cutoff > 20000.0 ||
           resonance < 0.0 || resonance > 1.0 ||
           morph < 0.0 || morph > 1.0 {
            return .warning
        }

        return .healthy
    }
}
