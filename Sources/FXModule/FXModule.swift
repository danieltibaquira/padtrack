// FXModule.swift
// DigitonePad - FXModule

import Foundation
import MachineProtocols
import AudioEngine

/// Base effects processor implementation
public class FXProcessor: FXProcessorProtocol, SerializableMachine, @unchecked Sendable {
    public let id = UUID()
    public var name: String
    public var isEnabled: Bool = true
    public var effectType: EffectType = .delay
    public var processingMode: EffectProcessingMode = .insert
    public var quality: EffectQuality = .good
    public var isBypassed: Bool = false

    // Enhanced MachineProtocol properties
    public var isInitialized: Bool = false
    public var status: MachineStatus = .uninitialized
    public var lastActiveTimestamp: Date?
    public var lastError: MachineError?
    public var errorHandler: ((MachineError) -> Void)?
    public var performanceMetrics: MachinePerformanceMetrics = MachinePerformanceMetrics()
    public var parameters: ObservableParameterManager = ObservableParameterManager()

    // FXProcessorProtocol properties
    public var wetLevel: Float = 1.0
    public var dryLevel: Float = 0.0
    public var inputGain: Float = 0.0
    public var outputGain: Float = 0.0
    public var intensity: Float = 0.5
    public var rate: Float = 1.0
    public var feedback: Float = 0.0
    public var modDepth: Float = 0.0
    public var stereoWidth: Float = 0.0

    public var latency: Int { 0 }
    public var isProcessing: Bool { status == .running && !isBypassed }
    public var effectState: [String: Float] {
        return [
            "wetLevel": wetLevel,
            "dryLevel": dryLevel,
            "inputPeak": inputPeak,
            "outputPeak": outputPeak
        ]
    }
    public var inputPeak: Float = 0.0
    public var outputPeak: Float = 0.0
    
    public init(name: String) {
        self.name = name
        setupEffectParameters()
    }
    
    public func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        lastActiveTimestamp = Date()
        // TODO: Implement effects processing
        return input
    }
    
    public func reset() {
        resetEffectState()
        wetLevel = 1.0
        dryLevel = 0.0
        inputGain = 0.0
        outputGain = 0.0
        intensity = 0.5
        rate = 1.0
        feedback = 0.0
        modDepth = 0.0
        stereoWidth = 0.0
        processingMode = .insert
        quality = .good
        isBypassed = false
        isEnabled = true
        lastError = nil
        performanceMetrics.reset()
        parameters.resetAllToDefaults()
        status = .ready
    }

    // MARK: - MachineProtocol Required Methods

    public func validateParameters() throws -> Bool {
        guard wetLevel >= 0.0 && wetLevel <= 1.0 else {
            throw CommonMachineError(code: "INVALID_WET_LEVEL", message: "Wet level must be between 0.0 and 1.0", severity: .error)
        }
        guard dryLevel >= 0.0 && dryLevel <= 1.0 else {
            throw CommonMachineError(code: "INVALID_DRY_LEVEL", message: "Dry level must be between 0.0 and 1.0", severity: .error)
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

    // MARK: - FXProcessorProtocol Implementation

    public func loadEffectPreset(_ preset: EffectPreset) {
        effectType = preset.effectType
        wetLevel = preset.wetLevel
        dryLevel = preset.dryLevel
        processingMode = preset.processingMode
        quality = preset.quality

        // Set effect-specific parameters
        do {
            try parameters.setValues(preset.parameters, notifyChanges: false)
        } catch {
            if let errorHandler = errorHandler {
                errorHandler(CommonMachineError(
                    code: "PRESET_LOAD_ERROR",
                    message: "Failed to load preset parameters: \(error.localizedDescription)",
                    severity: .warning
                ))
            }
        }
    }

    public func saveEffectPreset(name: String) -> EffectPreset {
        return EffectPreset(
            name: name,
            effectType: effectType,
            parameters: parameters.getAllValues(),
            processingMode: processingMode,
            quality: quality,
            wetLevel: wetLevel,
            dryLevel: dryLevel
        )
    }

    public func resetEffectState() {
        inputPeak = 0.0
        outputPeak = 0.0
        lastActiveTimestamp = Date()
    }

    public func flushBuffers() {
        // Clear any internal buffers
        resetEffectState()
    }

    public func setupEffectParameters() {
        // Add effect-specific parameters using default implementations
        // The default implementations from FXProcessorProtocol will handle parameter setup
    }

    public func getEffectParameterGroups() -> [ParameterGroup] {
        let mixGroup = ParameterGroup(
            id: "mix",
            name: "Mix",
            category: .mixer,
            parameterIds: ["wetLevel", "dryLevel", "inputGain", "outputGain"]
        )

        let processingGroup = ParameterGroup(
            id: "processing",
            name: "Processing",
            category: .effects,
            parameterIds: ["intensity", "rate", "feedback", "modDepth"]
        )
        
        return [mixGroup, processingGroup]
    }

    public func processSidechain(input: MachineProtocols.AudioBuffer, sidechain: MachineProtocols.AudioBuffer?) -> MachineProtocols.AudioBuffer {
        // Default implementation ignores sidechain
        return process(input: input)
    }

    public func getTailTime() -> Double {
        // Default no tail time
        return 0.0
    }

    public func setTempoSync(bpm: Double, timeSignature: MachineProtocols.TimeSignature) {
        // Store tempo sync information
        parameters.updateParameter(id: "bpm", value: Float(bpm))
        parameters.updateParameter(id: "timeSignatureNumerator", value: Float(timeSignature.numerator))
        parameters.updateParameter(id: "timeSignatureDenominator", value: Float(timeSignature.denominator))
    }

    public func modulateEffect(intensity: Float, rate: Float, feedback: Float) {
        self.intensity = max(0.0, min(1.0, intensity))
        self.rate = max(0.0, rate)
        self.feedback = max(0.0, min(1.0, feedback))
    }

    public func setEffectParameter(id: String, value: Float, smoothTime: Float) {
        parameters.updateParameter(id: id, value: value)
    }

    public func triggerAction(_ action: String, value: Float) {
        switch action {
        case "bypass":
            isBypassed = !isBypassed
        case "reset":
            resetEffectState()
        case "freeze":
            // Effect-specific freeze implementation
            break
        case "reverse":
            // Effect-specific reverse implementation
            break
        case "tap":
            // Effect-specific tap tempo implementation
            break
        default:
            break
        }
        lastActiveTimestamp = Date()
    }
    
    // Enhanced lifecycle methods
    public func initialize(configuration: MachineConfiguration) throws {
        status = .initializing
        // TODO: Initialize effect with configuration
        isInitialized = true
        status = .ready
    }
    
    public func start() throws {
        guard isInitialized else {
            throw CommonMachineError(code: "NOT_INITIALIZED", message: "Effect not initialized", severity: .error)
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
        case "wetLevel":
            if let floatValue = value as? Float {
                wetLevel = max(0.0, min(1.0, floatValue))
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for wetLevel", severity: .error)
            }
        case "dryLevel":
            if let floatValue = value as? Float {
                dryLevel = max(0.0, min(1.0, floatValue))
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for dryLevel", severity: .error)
            }
        case "isBypassed":
            if let boolValue = value as? Bool {
                isBypassed = boolValue
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for isBypassed", severity: .error)
            }
        case "effectType":
            if let stringValue = value as? String, let type = EffectType(rawValue: stringValue) {
                effectType = type
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for effectType", severity: .error)
            }
        case "intensity":
            if let floatValue = value as? Float {
                intensity = max(0.0, min(1.0, floatValue))
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for intensity", severity: .error)
            }
        case "rate":
            if let floatValue = value as? Float {
                rate = max(0.0, floatValue)
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for rate", severity: .error)
            }
        case "feedback":
            if let floatValue = value as? Float {
                feedback = max(0.0, min(1.0, floatValue))
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for feedback", severity: .error)
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
            machineType: "FXProcessor",
            parameters: parameters.getAllValues(),
            metadata: [
                "name": name,
                "enabled": String(isEnabled),
                "isBypassed": String(isBypassed),
                "effectType": effectType.rawValue,
                "processingMode": processingMode.rawValue,
                "quality": quality.rawValue,
                "status": status.rawValue,
                "isInitialized": String(isInitialized),
                "wetLevel": String(wetLevel),
                "dryLevel": String(dryLevel),
                "intensity": String(intensity),
                "rate": String(rate),
                "feedback": String(feedback)
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
        if let bypassedString = state.metadata["isBypassed"] {
            isBypassed = bypassedString == "true"
        }
        if let effectTypeString = state.metadata["effectType"],
           let type = EffectType(rawValue: effectTypeString) {
            effectType = type
        }
        if let processingModeString = state.metadata["processingMode"],
           let mode = EffectProcessingMode(rawValue: processingModeString) {
            processingMode = mode
        }
        if let qualityString = state.metadata["quality"],
           let effectQuality = EffectQuality(rawValue: qualityString) {
            quality = effectQuality
        }
        if let statusString = state.metadata["status"],
           let machineStatus = MachineStatus(rawValue: statusString) {
            status = machineStatus
        }
        if let initializedString = state.metadata["isInitialized"] {
            isInitialized = initializedString == "true"
        }
        if let wetLevelString = state.metadata["wetLevel"],
           let wetLevelValue = Float(wetLevelString) {
            wetLevel = wetLevelValue
        }
        if let dryLevelString = state.metadata["dryLevel"],
           let dryLevelValue = Float(dryLevelString) {
            dryLevel = dryLevelValue
        }
        if let intensityString = state.metadata["intensity"],
           let intensityValue = Float(intensityString) {
            intensity = intensityValue
        }
        if let rateString = state.metadata["rate"],
           let rateValue = Float(rateString) {
            rate = rateValue
        }
        if let feedbackString = state.metadata["feedback"],
           let feedbackValue = Float(feedbackString) {
            feedback = feedbackValue
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
            machineType: "FXProcessor",
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
        return data.machineType == "FXProcessor"
    }

    public func getSupportedSerializationVersion() -> SerializationVersion {
        return .current
    }
}

/// FX Module main class
public class FXModule: @unchecked Sendable {
    public static let shared = FXModule()
    
    private init() {}
    
    public func initialize() {
        // Initialize FX module
    }
}