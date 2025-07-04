// FilterModule.swift
// DigitonePad - FilterModule

import Foundation
import MachineProtocols
import AudioEngine

/// Base filter machine implementation
public class FilterMachine: FilterMachineProtocol, SerializableMachine, @unchecked Sendable {
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

    // FilterMachineProtocol required properties
    public var cutoff: Float = 1000.0
    public var resonance: Float = 0.0
    public var drive: Float = 0.0
    public var gain: Float = 0.0
    public var bandwidth: Float = 1.0
    public var keyTracking: Float = 0.0
    public var velocitySensitivity: Float = 0.0
    public var envelopeAmount: Float = 0.0
    public var lfoAmount: Float = 0.0
    public var modulationAmount: Float = 0.0

    public var filterState: [String: Float] {
        return [
            "cutoff": cutoff,
            "resonance": resonance,
            "drive": drive,
            "gain": gain,
            "bandwidth": bandwidth
        ]
    }
    
    public init(name: String) {
        self.name = name
        setupFilterParameters()
    }
    
    public func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        lastActiveTimestamp = Date()
        // TODO: Implement filter processing
        return input
    }
    
    public func reset() {
        resetFilterState()
        cutoff = 1000.0
        resonance = 0.0
        drive = 0.0
        gain = 0.0
        bandwidth = 1.0
        keyTracking = 0.0
        velocitySensitivity = 0.0
        envelopeAmount = 0.0
        lfoAmount = 0.0
        modulationAmount = 0.0
        filterType = .lowpass
        slope = .slope24dB
        quality = .medium
        isActive = true
        isEnabled = true
        lastError = nil
        performanceMetrics.reset()
        parameters.resetAllToDefaults()
        status = .ready
    }

    // MARK: - FilterMachineProtocol Required Methods

    public func getFrequencyResponse(at frequency: Float) -> FilterResponse {
        // Basic frequency response calculation
        let normalizedFreq = frequency / 20000.0
        let cutoffNorm = cutoff / 20000.0

        var magnitude: Float = 1.0
        var phase: Float = 0.0

        switch filterType {
        case .lowpass:
            if normalizedFreq > cutoffNorm {
                let slopeValue = Float(slope.rawValue.dropLast(2)) ?? 24.0
                let rolloff = pow(normalizedFreq / cutoffNorm, -slopeValue / 6.0)
                magnitude = rolloff * (1.0 + resonance * 2.0)
            }
            phase = -normalizedFreq * Float.pi / 2.0

        case .highpass:
            if normalizedFreq < cutoffNorm {
                let slopeValue = Float(slope.rawValue.dropLast(2)) ?? 24.0
                let rolloff = pow(normalizedFreq / cutoffNorm, slopeValue / 6.0)
                magnitude = rolloff * (1.0 + resonance * 2.0)
            }
            phase = normalizedFreq * Float.pi / 2.0

        case .bandpass:
            let distance = abs(normalizedFreq - cutoffNorm)
            magnitude = 1.0 / (1.0 + distance * 10.0 / bandwidth)
            magnitude *= (1.0 + resonance * 3.0)

        case .notch:
            let distance = abs(normalizedFreq - cutoffNorm)
            magnitude = distance * 10.0 / bandwidth
            magnitude = min(1.0, magnitude)

        case .peak:
            let distance = abs(normalizedFreq - cutoffNorm)
            if distance < bandwidth / 10.0 {
                magnitude = 1.0 + gain / 24.0
            }

        case .lowshelf:
            if normalizedFreq < cutoffNorm {
                magnitude = 1.0 + gain / 24.0
            }

        case .highshelf:
            if normalizedFreq > cutoffNorm {
                magnitude = 1.0 + gain / 24.0
            }

        case .allpass:
            magnitude = 1.0
        }

        // Apply drive
        magnitude *= (1.0 + drive * 0.5)

        return FilterResponse(frequency: frequency, magnitude: magnitude, phase: phase)
    }

    public func getFrequencyResponseCurve(startFreq: Float, endFreq: Float, points: Int) -> [FilterResponse] {
        var responses: [FilterResponse] = []
        let logStart = log10(startFreq)
        let logEnd = log10(endFreq)
        let step = (logEnd - logStart) / Float(points - 1)
        
        for i in 0..<points {
            let logFreq = logStart + Float(i) * step
            let freq = pow(10.0, logFreq)
            responses.append(getFrequencyResponse(at: freq))
        }
        
        return responses
    }

    public func resetFilterState() {
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

    public func getFilterParameterGroups() -> [ParameterGroup] {
        let coreGroup = ParameterGroup(
            id: "core",
            name: "Core Filter",
            category: .filter,
            parameterIds: ["cutoff", "resonance", "filterType", "drive"]
        )

        let modulationGroup = ParameterGroup(
            id: "modulation",
            name: "Modulation",
            category: .filter,
            parameterIds: ["keyTracking", "velocitySensitivity", "envelopeAmount", "lfoAmount", "modulationAmount"]
        )
        
        return [coreGroup, modulationGroup]
    }

    public func setupFilterParameters() {
        // Add filter-specific parameters using default implementations
        // The default implementations from FilterMachineProtocol will handle parameter setup
    }

    public func applyFilterModulation(envelope: Float, lfo: Float, modulation: Float) {
        let envelopeMod = envelope * envelopeAmount
        let lfoMod = lfo * lfoAmount
        let modMod = modulation * modulationAmount
        
        let totalMod = envelopeMod + lfoMod + modMod
        
        // Apply modulation to cutoff
        let modulatedCutoff = cutoff * (1.0 + totalMod)
        cutoff = max(20.0, min(20000.0, modulatedCutoff))
        
        updateFilterCoefficients()
    }

    public func updateFilterCoefficients() {
        // Filter coefficient update - in a real implementation this would recalculate filter coefficients
        lastActiveTimestamp = Date()
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

    // MARK: - MachineProtocol Required Methods

    public func validateParameters() throws -> Bool {
        guard cutoff >= 20.0 && cutoff <= 20000.0 else {
            throw CommonMachineError(code: "INVALID_CUTOFF", message: "Cutoff must be between 20 and 20000 Hz", severity: .error)
        }
        guard resonance >= 0.0 && resonance <= 1.0 else {
            throw CommonMachineError(code: "INVALID_RESONANCE", message: "Resonance must be between 0.0 and 1.0", severity: .error)
        }
        return true
    }

    public func healthCheck() -> MachineHealthStatus {
        if lastError != nil {
            return .warning
        }
        if !isInitialized {
            return .critical
        }
        return .healthy
    }
    
    // Enhanced lifecycle methods
    public func initialize(configuration: MachineConfiguration) throws {
        status = .initializing
        // TODO: Initialize filter with configuration
        isInitialized = true
        status = .ready
    }
    
    public func start() throws {
        guard isInitialized else {
            throw CommonMachineError(code: "NOT_INITIALIZED", message: "Filter not initialized", severity: .error)
        }
        status = .running
    }
    
    public func stop() throws {
        status = .stopping
        // TODO: Clean shutdown
        status = .ready
    }
    
    public func suspend() throws {
        status = .suspended
    }
    
    public func resume() throws {
        status = .running
    }
    
    public func updateParameter(key: String, value: Any) throws {
        switch key {
        case "cutoff":
            if let floatValue = value as? Float {
                cutoff = max(20.0, min(20000.0, floatValue))
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for cutoff", severity: .error)
            }
        case "resonance":
            if let floatValue = value as? Float {
                resonance = max(0.0, min(1.0, floatValue))
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for resonance", severity: .error)
            }
        case "drive":
            if let floatValue = value as? Float {
                drive = max(0.0, min(1.0, floatValue))
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for drive", severity: .error)
            }
        case "filterType":
            if let stringValue = value as? String, let type = FilterType(rawValue: stringValue) {
                filterType = type
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for filterType", severity: .error)
            }
        default:
            throw CommonMachineError(code: "UNKNOWN_PARAMETER", message: "Unknown parameter: \(key)", severity: .warning)
        }
        updateFilterCoefficients()
    }
    
    public func resetPerformanceCounters() {
        performanceMetrics.reset()
    }
    
    public func getState() -> MachineState {
        return MachineState(
            machineType: "FilterMachine",
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
                "cutoff": String(cutoff),
                "resonance": String(resonance),
                "drive": String(drive),
                "gain": String(gain),
                "bandwidth": String(bandwidth)
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
        if let cutoffString = state.metadata["cutoff"],
           let cutoffValue = Float(cutoffString) {
            cutoff = cutoffValue
        }
        if let resonanceString = state.metadata["resonance"],
           let resonanceValue = Float(resonanceString) {
            resonance = resonanceValue
        }
        if let driveString = state.metadata["drive"],
           let driveValue = Float(driveString) {
            drive = driveValue
        }
        if let gainString = state.metadata["gain"],
           let gainValue = Float(gainString) {
            gain = gainValue
        }
        if let bandwidthString = state.metadata["bandwidth"],
           let bandwidthValue = Float(bandwidthString) {
            bandwidth = bandwidthValue
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
    }

    // MARK: - SerializableMachine

    public func getSerializationData() -> MachineSerializationData {
        return MachineSerializationData(
            machineId: id.uuidString,
            machineType: "FilterMachine",
            name: name,
            isEnabled: isEnabled,
            parameters: parameters.getAllValues()
        )
    }

    public func restoreFromSerializationData(_ data: MachineSerializationData) throws {
        name = data.name
        isEnabled = data.isEnabled
        try parameters.setValues(data.parameters, notifyChanges: false)
    }

    public func validateSerializationData(_ data: MachineSerializationData) -> Bool {
        return data.machineType == "FilterMachine"
    }

    public func getSupportedSerializationVersion() -> SerializationVersion {
        return .current
    }
}

/// Filter Module main class
public class FilterModule: @unchecked Sendable {
    public static let shared = FilterModule()
    
    private init() {}
    
    public func initialize() {
        // Initialize Filter module
    }
}