// FMToneParameterInteractor.swift
// DigitonePad - FM TONE Parameter Interactor Component
//
// Business logic for FM TONE parameter management

import Foundation
import VoiceModule
import UIComponents

/// Interactor handles business logic for FM TONE parameter management
public class FMToneParameterInteractor: FMToneParameterInteractorProtocol {
    // MARK: - Properties
    
    private weak var fmVoiceMachine: FMVoiceMachine?
    weak var presenter: FMToneParameterPresenterProtocol?
    private var parameterDefinitions: [FMToneParameter] = []
    
    // Current parameter values (normalized 0.0-1.0)
    private var currentValues: [String: Double] = [:]
    
    // MARK: - Initialization
    
    public init(fmVoiceMachine: FMVoiceMachine? = nil) {
        self.fmVoiceMachine = fmVoiceMachine
        setupParameterDefinitions()
        initializeDefaultValues()
    }
    
    // MARK: - FMToneParameterInteractorProtocol
    
    /// Get parameter labels for a specific page
    public func getParameterLabels(for page: Int) -> [String] {
        guard page >= 1 && page <= 4 else { return [] }
        
        let parameters = parameterDefinitions.filter { $0.page == page }
        let sortedParameters = parameters.sorted { $0.index < $1.index }
        
        var labels: [String] = []
        for i in 0..<8 {
            if i < sortedParameters.count {
                labels.append(sortedParameters[i].shortName)
            } else {
                labels.append("---")
            }
        }
        return labels
    }
    
    /// Update parameter value
    public func updateParameter(at index: Int, page: Int, normalizedValue: Double) {
        guard page >= 1 && page <= 4 else {
            presenter?.showError(FMToneParameterError.invalidPageNumber)
            return
        }
        
        guard index >= 0 && index < 8 else {
            presenter?.showError(FMToneParameterError.invalidParameterIndex)
            return
        }
        
        let parameters = parameterDefinitions.filter { $0.page == page && $0.index == index }
        guard let parameter = parameters.first else {
            presenter?.showError(FMToneParameterError.invalidParameterIndex)
            return
        }
        
        // Validate normalized value
        guard normalizedValue >= 0.0 && normalizedValue <= 1.0 else {
            presenter?.showError(FMToneParameterError.invalidParameterValue)
            return
        }
        
        // Convert normalized value to actual value
        let actualValue = parameter.minValue + (normalizedValue * (parameter.maxValue - parameter.minValue))
        
        // Store the normalized value
        currentValues[parameter.id] = normalizedValue
        
        // Update the FM voice machine if available
        do {
            try updateFMVoiceMachine(parameter: parameter, value: actualValue)
            presenter?.updateParameterDisplay(at: index, formattedValue: getFormattedValue(at: index, page: page))
        } catch {
            presenter?.showError(error)
        }
    }
    
    /// Get current parameter value (normalized)
    public func getParameterValue(at index: Int, page: Int) -> Double {
        guard page >= 1 && page <= 4, index >= 0 && index < 8 else { return 0.0 }
        
        let parameters = parameterDefinitions.filter { $0.page == page && $0.index == index }
        guard let parameter = parameters.first else { return 0.0 }
        
        return currentValues[parameter.id] ?? parameter.defaultValue
    }
    
    /// Reset all parameters to default values
    public func resetAllParameters() {
        for parameter in parameterDefinitions {
            currentValues[parameter.id] = parameter.defaultValue
            
            // Calculate actual value and update voice machine
            let actualValue = parameter.minValue + (parameter.defaultValue * (parameter.maxValue - parameter.minValue))
            try? updateFMVoiceMachine(parameter: parameter, value: actualValue)
        }
        
        // Update all displays
        for page in 1...4 {
            for index in 0..<8 {
                presenter?.updateParameterDisplay(at: index, formattedValue: getFormattedValue(at: index, page: page))
            }
        }
    }
    
    /// Validate parameter value
    public func validateParameterValue(_ value: Double, for parameter: FMToneParameter) -> Bool {
        return value >= 0.0 && value <= 1.0
    }
    
    /// Apply preset values
    public func applyPreset(_ preset: FMTonePreset) {
        for (parameterId, value) in preset.parameters {
            if let parameter = parameterDefinitions.first(where: { $0.id == parameterId }) {
                // Ensure value is in valid range
                let clampedValue = max(0.0, min(1.0, value))
                currentValues[parameter.id] = clampedValue
                
                // Update voice machine
                let actualValue = parameter.minValue + (clampedValue * (parameter.maxValue - parameter.minValue))
                try? updateFMVoiceMachine(parameter: parameter, value: actualValue)
            }
        }
        
        // Update all displays
        for page in 1...4 {
            for index in 0..<8 {
                presenter?.updateParameterDisplay(at: index, formattedValue: getFormattedValue(at: index, page: page))
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupParameterDefinitions() {
        parameterDefinitions = [
            // Page 1 - Core FM
            FMToneParameter(id: "algorithm", name: "Algorithm", shortName: "ALGO", page: 1, index: 0,
                          minValue: 1, maxValue: 4, defaultValue: 0.0, isDiscrete: true),
            FMToneParameter(id: "operator4_ratio", name: "Ratio C", shortName: "RATIO C", page: 1, index: 1,
                          minValue: 0.25, maxValue: 32.0, defaultValue: 0.03125),
            FMToneParameter(id: "operator1_ratio", name: "Ratio A", shortName: "RATIO A", page: 1, index: 2,
                          minValue: 0.25, maxValue: 32.0, defaultValue: 0.03125),
            FMToneParameter(id: "operator2_ratio", name: "Ratio B", shortName: "RATIO B", page: 1, index: 3,
                          minValue: 0.25, maxValue: 32.0, defaultValue: 0.03125),
            FMToneParameter(id: "harmonic", name: "Harmonic", shortName: "HARM", page: 1, index: 4,
                          minValue: 0.0, maxValue: 127.0, defaultValue: 0.0),
            FMToneParameter(id: "detune", name: "Detune", shortName: "DTUN", page: 1, index: 5,
                          minValue: -50.0, maxValue: 50.0, defaultValue: 0.0, unit: "¢"),
            FMToneParameter(id: "feedback", name: "Feedback", shortName: "FDBK", page: 1, index: 6,
                          minValue: 0.0, maxValue: 127.0, defaultValue: 0.0),
            FMToneParameter(id: "mix", name: "Mix", shortName: "MIX", page: 1, index: 7,
                          minValue: 0.0, maxValue: 127.0, defaultValue: 1.0),
            
            // Page 2 - Envelopes
            FMToneParameter(id: "operator1_attack", name: "Attack A", shortName: "ATK A", page: 2, index: 0,
                          minValue: 0.0, maxValue: 127.0, defaultValue: 0.0),
            FMToneParameter(id: "operator1_decay", name: "Decay A", shortName: "DEC A", page: 2, index: 1,
                          minValue: 0.0, maxValue: 127.0, defaultValue: 0.5),
            FMToneParameter(id: "operator1_end", name: "End A", shortName: "END A", page: 2, index: 2,
                          minValue: 0.0, maxValue: 127.0, defaultValue: 0.0),
            FMToneParameter(id: "operator1_level", name: "Level A", shortName: "LEV A", page: 2, index: 3,
                          minValue: 0.0, maxValue: 127.0, defaultValue: 1.0),
            FMToneParameter(id: "operator2_attack", name: "Attack B", shortName: "ATK B", page: 2, index: 4,
                          minValue: 0.0, maxValue: 127.0, defaultValue: 0.0),
            FMToneParameter(id: "operator2_decay", name: "Decay B", shortName: "DEC B", page: 2, index: 5,
                          minValue: 0.0, maxValue: 127.0, defaultValue: 0.5),
            FMToneParameter(id: "operator2_end", name: "End B", shortName: "END B", page: 2, index: 6,
                          minValue: 0.0, maxValue: 127.0, defaultValue: 0.0),
            FMToneParameter(id: "operator2_level", name: "Level B", shortName: "LEV B", page: 2, index: 7,
                          minValue: 0.0, maxValue: 127.0, defaultValue: 1.0),
            
            // Page 3 - Behavior
            FMToneParameter(id: "envelope_delay", name: "Env Delay", shortName: "DELAY", page: 3, index: 0,
                          minValue: 0.0, maxValue: 127.0, defaultValue: 0.0),
            FMToneParameter(id: "trig_mode", name: "Trig Mode", shortName: "TRIG", page: 3, index: 1,
                          minValue: 0, maxValue: 3, defaultValue: 0.0, isDiscrete: true),
            FMToneParameter(id: "phase_reset", name: "Phase Reset", shortName: "PHASE", page: 3, index: 2,
                          minValue: 0, maxValue: 1, defaultValue: 0.0, isDiscrete: true),
            FMToneParameter(id: "velocity_sensitivity", name: "Velocity", shortName: "VEL", page: 3, index: 3,
                          minValue: 0.0, maxValue: 127.0, defaultValue: 0.5),
            FMToneParameter(id: "note_priority", name: "Note Priority", shortName: "PRIOR", page: 3, index: 4,
                          minValue: 0, maxValue: 2, defaultValue: 0.0, isDiscrete: true),
            FMToneParameter(id: "porta_time", name: "Porta Time", shortName: "PORTA", page: 3, index: 5,
                          minValue: 0.0, maxValue: 127.0, defaultValue: 0.0),
            FMToneParameter(id: "legato", name: "Legato", shortName: "LEGATO", page: 3, index: 6,
                          minValue: 0, maxValue: 1, defaultValue: 0.0, isDiscrete: true),
            FMToneParameter(id: "sustain_mode", name: "Sustain", shortName: "SUST", page: 3, index: 7,
                          minValue: 0, maxValue: 1, defaultValue: 0.0, isDiscrete: true),
            
            // Page 4 - Tracking
            FMToneParameter(id: "key_tracking", name: "Key Track", shortName: "TRACK", page: 4, index: 0,
                          minValue: -100, maxValue: 100, defaultValue: 0.0, unit: "%"),
            FMToneParameter(id: "fine_tune", name: "Fine Tune", shortName: "FINE", page: 4, index: 1,
                          minValue: -50.0, maxValue: 50.0, defaultValue: 0.0, unit: "¢"),
            FMToneParameter(id: "operator1_offset", name: "Offset A", shortName: "OFS A", page: 4, index: 2,
                          minValue: -50.0, maxValue: 50.0, defaultValue: 0.0, unit: "¢"),
            FMToneParameter(id: "operator2_offset", name: "Offset B", shortName: "OFS B", page: 4, index: 3,
                          minValue: -50.0, maxValue: 50.0, defaultValue: 0.0, unit: "¢"),
            FMToneParameter(id: "operator1_tracking", name: "Track A", shortName: "TRK A", page: 4, index: 4,
                          minValue: -100, maxValue: 100, defaultValue: 0.0, unit: "%"),
            FMToneParameter(id: "operator2_tracking", name: "Track B", shortName: "TRK B", page: 4, index: 5,
                          minValue: -100, maxValue: 100, defaultValue: 0.0, unit: "%"),
            FMToneParameter(id: "modulation_depth", name: "Mod Depth", shortName: "DEPTH", page: 4, index: 6,
                          minValue: 0.0, maxValue: 127.0, defaultValue: 0.5),
            FMToneParameter(id: "global_level", name: "Global Level", shortName: "LEVEL", page: 4, index: 7,
                          minValue: 0.0, maxValue: 127.0, defaultValue: 1.0)
        ]
    }
    
    private func initializeDefaultValues() {
        for parameter in parameterDefinitions {
            currentValues[parameter.id] = parameter.defaultValue
        }
    }
    
    private func getParameter(at index: Int, page: Int) -> FMToneParameter? {
        return parameterDefinitions.first { $0.page == page && $0.index == index }
    }
    
    private func updateFMVoiceMachine(parameter: FMToneParameter, value: Double) throws {
        guard let fmVoiceMachine = fmVoiceMachine else {
            throw FMToneParameterError.voiceMachineNotAvailable
        }
        
        do {
            try fmVoiceMachine.updateParameter(key: parameter.id, value: value)
        } catch {
            throw FMToneParameterError.parameterUpdateFailed
        }
    }
    
    private func getFormattedValue(at index: Int, page: Int) -> String {
        guard let parameter = getParameter(at: index, page: page) else { return "---" }
        
        let normalizedValue = currentValues[parameter.id] ?? parameter.defaultValue
        let actualValue = parameter.minValue + (normalizedValue * (parameter.maxValue - parameter.minValue))
        
        // Format based on parameter type
        if parameter.isDiscrete {
            if parameter.id == "algorithm" {
                return "ALG\(Int(actualValue))"
            } else if parameter.id == "trig_mode" {
                let modes = ["NORM", "RETRIG", "ONCE", "HOLD"]
                let index = Int(actualValue)
                return modes[index]
            } else if parameter.id == "note_priority" {
                let priorities = ["LOW", "HIGH", "LAST"]
                let index = Int(actualValue)
                return priorities[index]
            } else if parameter.id == "phase_reset" || parameter.id == "legato" || parameter.id == "sustain_mode" {
                return actualValue > 0.5 ? "ON" : "OFF"
            } else {
                return String(format: "%.0f", actualValue)
            }
        } else if let unit = parameter.unit {
            return String(format: "%.1f%@", actualValue, unit)
        } else {
            return String(format: "%.1f", actualValue)
        }
    }
}

// MARK: - Supporting Types
// Note: FMToneParameter, FMTonePreset, and FMToneParameterError are defined in FMToneParameterProtocols.swift

extension FMToneParameterError {
    var errorDescription: String? {
        switch self {
        case .invalidParameterIndex:
            return "Invalid parameter index"
        case .invalidParameterValue:
            return "Invalid parameter value"
        case .parameterUpdateFailed:
            return "Failed to update parameter"
        case .voiceMachineNotAvailable:
            return "FM voice machine not available"
        case .presetLoadFailed:
            return "Failed to load preset"
        case .invalidPageNumber:
            return "Invalid page number"
        }
    }
}