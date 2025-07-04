// VoiceModule.swift
// DigitonePad - VoiceModule

import Foundation
import MachineProtocols
import AudioEngine

/// Base voice machine implementation
public class VoiceMachine: VoiceMachineProtocol, SerializableMachine, @unchecked Sendable {
    public let id = UUID()
    public var name: String
    public var isEnabled: Bool = true
    public var polyphony: Int
    public var activeVoices: Int = 0
    public var voiceStealingMode: VoiceStealingMode = .oldest

    // Enhanced MachineProtocol properties
    public var isInitialized: Bool = false
    public var status: MachineStatus = .uninitialized
    public var lastActiveTimestamp: Date?
    public var lastError: MachineError?
    public var errorHandler: ((MachineError) -> Void)?
    public var performanceMetrics: MachinePerformanceMetrics = MachinePerformanceMetrics()
    public var parameters: ObservableParameterManager = ObservableParameterManager()

    // Voice-specific properties required by VoiceMachineProtocol
    public var masterVolume: Float = 0.8
    public var masterTuning: Float = 0.0
    public var portamentoTime: Float = 0.0
    public var portamentoEnabled: Bool = false
    public var velocitySensitivity: Float = 1.0
    public var pitchBendRange: Float = 2.0
    public var pitchBend: Float = 0.0
    public var modWheel: Float = 0.0

    // Voice-specific properties
    private var _voiceStates: [VoiceState] = []

    public var voiceStates: [VoiceState] { _voiceStates }
    
    public init(name: String, polyphony: Int = 8) {
        self.name = name
        self.polyphony = polyphony
        setupVoiceParameters()
    }
    
    public func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        lastActiveTimestamp = Date()
        // TODO: Implement audio processing
        return input
    }
    
    public func noteOn(note: UInt8, velocity: UInt8) {
        noteOn(note: note, velocity: velocity, channel: 0, timestamp: nil)
    }

    public func noteOn(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?) {
        lastActiveTimestamp = Date()

        if activeVoices >= polyphony {
            // Voice stealing
            if voiceStealingMode != .none {
                let voiceToSteal = findVoiceToSteal()
                if let voiceId = voiceToSteal {
                    releaseVoice(voiceId: voiceId)
                }
            } else {
                return // Ignore new note
            }
        }

        let voiceId = allocateVoice()
        let voiceState = VoiceState(
            voiceId: voiceId,
            note: note,
            velocity: velocity,
            startTime: timestamp ?? UInt64(Date().timeIntervalSince1970 * 1000)
        )

        _voiceStates.append(voiceState)
        activeVoices += 1
    }

    public func noteOff(note: UInt8) {
        noteOff(note: note, velocity: 64, channel: 0, timestamp: nil)
    }

    public func noteOff(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?) {
        lastActiveTimestamp = Date()

        if let index = _voiceStates.firstIndex(where: { $0.note == note && $0.isActive }) {
            _voiceStates[index] = VoiceState(
                voiceId: _voiceStates[index].voiceId,
                note: _voiceStates[index].note,
                velocity: _voiceStates[index].velocity,
                startTime: _voiceStates[index].startTime,
                isActive: false
            )
            activeVoices = max(0, activeVoices - 1)
        }
    }

    public func allNotesOff() {
        lastActiveTimestamp = Date()
        _voiceStates.removeAll()
        activeVoices = 0
    }

    public func allNotesOff(channel: UInt8) {
        // For this implementation, just call allNotesOff
        allNotesOff()
    }

    public func getVoiceAllocation(for note: UInt8) -> VoiceAllocation? {
        guard let voiceState = _voiceStates.first(where: { $0.note == note && $0.isActive }) else {
            return nil
        }

        return VoiceAllocation(
            voiceId: voiceState.voiceId,
            note: note,
            velocity: voiceState.velocity,
            timestamp: voiceState.startTime
        )
    }
    
    public func reset() {
        allNotesOff()
        polyphony = 8
        voiceStealingMode = .oldest
        isEnabled = true
        lastError = nil
        performanceMetrics.reset()
        parameters.resetAllToDefaults()
        status = .ready
    }

    // MARK: - VoiceMachineProtocol Required Methods

    public func getVoiceParameterGroups() -> [ParameterGroup] {
        let synthGroup = ParameterGroup(
            id: "synthesis",
            name: "Synthesis",
            category: .effects,
            parameterIds: ["masterVolume", "masterTuning", "polyphony"]
        )
        
        let expressionGroup = ParameterGroup(
            id: "expression",
            name: "Expression",
            category: .effects,
            parameterIds: ["velocitySensitivity", "pitchBendRange", "portamentoTime", "portamentoEnabled"]
        )
        
        return [synthGroup, expressionGroup]
    }

    public func applyPitchBend(_ value: Float) {
        pitchBend = max(-1.0, min(1.0, value))
        // TODO: Apply pitch bend to all active voices
    }

    public func applyModulation(_ value: Float) {
        modWheel = max(0.0, min(1.0, value))
        // TODO: Apply modulation to all active voices
    }

    public func setVoiceParameter(voiceId: Int, parameterId: String, value: Float) throws {
        // TODO: Implement voice-specific parameter setting
        throw CommonMachineError(code: "NOT_IMPLEMENTED", message: "Voice parameter setting not implemented", severity: .warning)
    }

    public func getVoiceParameter(voiceId: Int, parameterId: String) -> Float? {
        // TODO: Implement voice-specific parameter getting
        return nil
    }

    public func setSustainPedal(_ enabled: Bool) {
        // TODO: Implement sustain pedal handling
    }

    public func setSostenutoPedal(_ enabled: Bool) {
        // TODO: Implement sostenuto pedal handling
    }

    public func setSoftPedal(_ enabled: Bool) {
        // TODO: Implement soft pedal handling
    }

    public func setAftertouch(_ pressure: Float) {
        // TODO: Implement aftertouch handling
    }

    public func setPolyphonicAftertouch(note: UInt8, pressure: Float) {
        // TODO: Implement polyphonic aftertouch handling
    }

    // MARK: - MachineProtocol Required Methods

    public func validateParameters() throws -> Bool {
        // Basic validation
        guard polyphony >= 1 && polyphony <= 64 else {
            throw CommonMachineError(code: "INVALID_POLYPHONY", message: "Polyphony must be between 1 and 64", severity: .error)
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

    // MARK: - Helper Methods

    private func allocateVoice() -> Int {
        return Int.random(in: 0..<polyphony)
    }

    private func findVoiceToSteal() -> Int? {
        guard !_voiceStates.isEmpty else { return nil }

        switch voiceStealingMode {
        case .oldest:
            return _voiceStates.min(by: { $0.startTime < $1.startTime })?.voiceId
        case .quietest:
            return _voiceStates.min(by: { $0.amplitude < $1.amplitude })?.voiceId
        case .newest:
            return _voiceStates.max(by: { $0.startTime < $1.startTime })?.voiceId
        case .none:
            return nil
        }
    }

    private func releaseVoice(voiceId: Int) {
        if let index = _voiceStates.firstIndex(where: { $0.voiceId == voiceId }) {
            _voiceStates.remove(at: index)
            activeVoices = max(0, activeVoices - 1)
        }
    }
    
    // Enhanced lifecycle methods
    public func initialize(configuration: MachineConfiguration) throws {
        status = .initializing
        // TODO: Initialize voice engine with configuration
        isInitialized = true
        status = .ready
    }
    
    public func start() throws {
        guard isInitialized else {
            throw CommonMachineError(code: "NOT_INITIALIZED", message: "Voice machine not initialized", severity: .error)
        }
        status = .running
    }
    
    public func stop() throws {
        status = .stopping
        allNotesOff()
        // TODO: Clean shutdown
        status = .ready
    }
    
    public func suspend() throws {
        status = .suspended
        allNotesOff()
    }
    
    public func resume() throws {
        status = .running
    }
    
    public func updateParameter(key: String, value: Any) throws {
        switch key {
        case "polyphony":
            if let intValue = value as? Int {
                polyphony = max(1, min(intValue, 64)) // Clamp between 1 and 64
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for polyphony", severity: .error)
            }
        case "voiceStealingMode":
            if let stringValue = value as? String, let mode = VoiceStealingMode(rawValue: stringValue) {
                voiceStealingMode = mode
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for voiceStealingMode", severity: .error)
            }
        case "masterVolume":
            if let floatValue = value as? Float {
                masterVolume = max(0.0, min(1.0, floatValue))
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for masterVolume", severity: .error)
            }
        case "masterTuning":
            if let floatValue = value as? Float {
                masterTuning = max(-100.0, min(100.0, floatValue))
            } else {
                throw CommonMachineError(code: "INVALID_PARAMETER_TYPE", message: "Invalid type for masterTuning", severity: .error)
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
            machineType: "VoiceMachine",
            parameters: parameters.getAllValues(),
            metadata: [
                "name": name,
                "enabled": String(isEnabled),
                "polyphony": String(polyphony),
                "activeVoices": String(activeVoices),
                "voiceStealingMode": voiceStealingMode.rawValue,
                "status": status.rawValue,
                "isInitialized": String(isInitialized),
                "masterVolume": String(masterVolume),
                "masterTuning": String(masterTuning),
                "portamentoTime": String(portamentoTime),
                "portamentoEnabled": String(portamentoEnabled),
                "velocitySensitivity": String(velocitySensitivity),
                "pitchBendRange": String(pitchBendRange)
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
        if let polyphonyString = state.metadata["polyphony"],
           let polyphonyValue = Int(polyphonyString) {
            polyphony = polyphonyValue
        }
        if let activeVoicesString = state.metadata["activeVoices"],
           let activeVoicesValue = Int(activeVoicesString) {
            activeVoices = activeVoicesValue
        }
        if let voiceStealingString = state.metadata["voiceStealingMode"],
           let mode = VoiceStealingMode(rawValue: voiceStealingString) {
            voiceStealingMode = mode
        }
        if let statusString = state.metadata["status"],
           let machineStatus = MachineStatus(rawValue: statusString) {
            status = machineStatus
        }
        if let initializedString = state.metadata["isInitialized"] {
            isInitialized = initializedString == "true"
        }
        if let masterVolumeString = state.metadata["masterVolume"],
           let masterVolumeValue = Float(masterVolumeString) {
            masterVolume = masterVolumeValue
        }
        if let masterTuningString = state.metadata["masterTuning"],
           let masterTuningValue = Float(masterTuningString) {
            masterTuning = masterTuningValue
        }
        if let portamentoTimeString = state.metadata["portamentoTime"],
           let portamentoTimeValue = Float(portamentoTimeString) {
            portamentoTime = portamentoTimeValue
        }
        if let portamentoEnabledString = state.metadata["portamentoEnabled"] {
            portamentoEnabled = portamentoEnabledString == "true"
        }
        if let velocitySensitivityString = state.metadata["velocitySensitivity"],
           let velocitySensitivityValue = Float(velocitySensitivityString) {
            velocitySensitivity = velocitySensitivityValue
        }
        if let pitchBendRangeString = state.metadata["pitchBendRange"],
           let pitchBendRangeValue = Float(pitchBendRangeString) {
            pitchBendRange = pitchBendRangeValue
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
            machineType: "VoiceMachine",
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
        return data.machineType == "VoiceMachine"
    }

    public func getSupportedSerializationVersion() -> SerializationVersion {
        return .current
    }

    // MARK: - Setup Methods

    public func setupVoiceParameters() {
        // Add voice-specific parameters using default implementations
        // The default implementations from VoiceMachineProtocol will handle parameter setup
    }
}