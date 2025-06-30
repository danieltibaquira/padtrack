//
//  ParameterLock+CoreDataClass.swift
//  PadTrack
//
//  Created by PadTrack on 2024.
//

import Foundation
import CoreData

@objc(ParameterLock)
public class ParameterLock: NSManagedObject {
    
    // MARK: - Convenience Initializers
    
    convenience init(context: NSManagedObjectContext, parameterName: String, value: Double) {
        self.init(context: context)
        self.lockID = UUID()
        self.parameterName = parameterName
        self.value = value
        self.createdAt = Date()
        self.lastModified = Date()
    }
    
    // MARK: - Computed Properties
    
    /// Check if parameter lock has been modified since creation
    var isModified: Bool {
        guard let created = createdAt, let modified = lastModified else { return false }
        return modified > created
    }
    
    /// Get display name for the parameter
    var displayName: String {
        return parameterName?.capitalized ?? "Unknown Parameter"
    }
    
    /// Get formatted value string for display
    var formattedValue: String {
        return String(format: "%.3f", value)
    }
    
    /// Get percentage representation of value (0-100%)
    var percentageValue: Double {
        return value * 100.0
    }
    
    /// Get formatted percentage string
    var formattedPercentage: String {
        return String(format: "%.1f%%", percentageValue)
    }
    
    /// Check if value is at minimum (0.0)
    var isAtMinimum: Bool {
        return value <= 0.0
    }
    
    /// Check if value is at maximum (1.0)
    var isAtMaximum: Bool {
        return value >= 1.0
    }
    
    /// Check if value is at center (0.5)
    var isAtCenter: Bool {
        return abs(value - 0.5) < 0.001
    }
    
    // MARK: - Parameter Categories
    
    /// Check if this is a synthesis parameter
    var isSynthParameter: Bool {
        guard let name = parameterName?.lowercased() else { return false }
        let synthParams = ["osc", "filter", "env", "lfo", "amp", "pitch", "detune", "wave"]
        return synthParams.contains { name.contains($0) }
    }
    
    /// Check if this is an effect parameter
    var isEffectParameter: Bool {
        guard let name = parameterName?.lowercased() else { return false }
        let fxParams = ["reverb", "delay", "chorus", "distortion", "comp", "eq", "send"]
        return fxParams.contains { name.contains($0) }
    }
    
    /// Check if this is a mixer parameter
    var isMixerParameter: Bool {
        guard let name = parameterName?.lowercased() else { return false }
        let mixerParams = ["volume", "pan", "gain", "level", "mix"]
        return mixerParams.contains { name.contains($0) }
    }
    
    /// Get parameter category for organization
    var category: ParameterCategory {
        if isSynthParameter {
            return .synthesis
        } else if isEffectParameter {
            return .effects
        } else if isMixerParameter {
            return .mixer
        } else {
            return .other
        }
    }
    
    // MARK: - Value Management
    
    /// Set value with validation
    func setValue(_ newValue: Double) throws {
        guard newValue >= 0.0 && newValue <= 1.0 else {
            throw ParameterLockError.invalidValue(newValue)
        }
        value = newValue
        lastModified = Date()
    }
    
    /// Set value from percentage (0-100%)
    func setValueFromPercentage(_ percentage: Double) throws {
        guard percentage >= 0.0 && percentage <= 100.0 else {
            throw ParameterLockError.invalidPercentage(percentage)
        }
        try setValue(percentage / 100.0)
    }
    
    /// Adjust value by offset with clamping
    func adjustValue(by offset: Double) throws {
        let newValue = max(0.0, min(1.0, value + offset))
        try setValue(newValue)
    }
    
    /// Set value to minimum (0.0)
    func setToMinimum() {
        value = 0.0
        lastModified = Date()
    }
    
    /// Set value to maximum (1.0)
    func setToMaximum() {
        value = 1.0
        lastModified = Date()
    }
    
    /// Set value to center (0.5)
    func setToCenter() {
        value = 0.5
        lastModified = Date()
    }
    
    /// Invert value (1.0 - current value)
    func invertValue() {
        value = 1.0 - value
        lastModified = Date()
    }
    
    // MARK: - Parameter Name Management
    
    /// Set parameter name with validation
    func setParameterName(_ name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ParameterLockError.emptyParameterName
        }
        parameterName = trimmedName
        lastModified = Date()
    }
    
    /// Check if parameter name is valid
    var hasValidParameterName: Bool {
        guard let name = parameterName else { return false }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Copy and Comparison
    
    /// Copy settings from another parameter lock
    func copySettings(from source: ParameterLock) {
        parameterName = source.parameterName
        value = source.value
        lastModified = Date()
    }
    
    /// Check if this parameter lock is equivalent to another
    func isEquivalent(to other: ParameterLock) -> Bool {
        return parameterName == other.parameterName && abs(value - other.value) < 0.001
    }
    
    /// Create a duplicate of this parameter lock
    func duplicate(in context: NSManagedObjectContext) -> ParameterLock {
        let duplicate = ParameterLock(context: context, 
                                    parameterName: parameterName ?? "", 
                                    value: value)
        return duplicate
    }
    
    // MARK: - Export and Metadata
    
    /// Generate export metadata
    func exportMetadata() -> [String: Any] {
        return [
            "lockID": lockID?.uuidString ?? "",
            "parameterName": parameterName ?? "",
            "value": value,
            "percentageValue": percentageValue,
            "category": category.rawValue,
            "isSynthParameter": isSynthParameter,
            "isEffectParameter": isEffectParameter,
            "isMixerParameter": isMixerParameter,
            "isAtMinimum": isAtMinimum,
            "isAtMaximum": isAtMaximum,
            "isAtCenter": isAtCenter,
            "createdAt": createdAt?.timeIntervalSince1970 ?? 0,
            "lastModified": lastModified?.timeIntervalSince1970 ?? 0
        ]
    }
    
    // MARK: - Common Parameter Presets
    
    /// Create common synthesis parameter locks
    static func createSynthParameterLock(context: NSManagedObjectContext, 
                                       type: SynthParameterType, 
                                       value: Double) -> ParameterLock {
        return ParameterLock(context: context, 
                           parameterName: type.parameterName, 
                           value: value)
    }
    
    /// Create common effect parameter locks
    static func createEffectParameterLock(context: NSManagedObjectContext,
                                        type: EffectParameterType,
                                        value: Double) -> ParameterLock {
        return ParameterLock(context: context,
                           parameterName: type.parameterName,
                           value: value)
    }
    
    // MARK: - Validation
    
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateParameterLock()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateParameterLock()
    }
    
    private func validateParameterLock() throws {
        // Validate parameter name
        guard hasValidParameterName else {
            throw ParameterLockError.emptyParameterName
        }
        
        // Validate value
        guard value >= 0.0 && value <= 1.0 else {
            throw ParameterLockError.invalidValue(value)
        }
    }
}

// MARK: - Parameter Categories

enum ParameterCategory: String, CaseIterable {
    case synthesis = "synthesis"
    case effects = "effects"
    case mixer = "mixer"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .synthesis:
            return "Synthesis"
        case .effects:
            return "Effects"
        case .mixer:
            return "Mixer"
        case .other:
            return "Other"
        }
    }
}

// MARK: - Common Parameter Types

enum SynthParameterType: String, CaseIterable {
    case oscPitch = "osc_pitch"
    case oscDetune = "osc_detune"
    case oscWave = "osc_wave"
    case filterCutoff = "filter_cutoff"
    case filterResonance = "filter_resonance"
    case filterEnvAmount = "filter_env_amount"
    case ampAttack = "amp_attack"
    case ampDecay = "amp_decay"
    case ampSustain = "amp_sustain"
    case ampRelease = "amp_release"
    case lfoRate = "lfo_rate"
    case lfoAmount = "lfo_amount"
    
    var parameterName: String {
        return rawValue
    }
    
    var displayName: String {
        switch self {
        case .oscPitch: return "Osc Pitch"
        case .oscDetune: return "Osc Detune"
        case .oscWave: return "Osc Wave"
        case .filterCutoff: return "Filter Cutoff"
        case .filterResonance: return "Filter Resonance"
        case .filterEnvAmount: return "Filter Env Amount"
        case .ampAttack: return "Amp Attack"
        case .ampDecay: return "Amp Decay"
        case .ampSustain: return "Amp Sustain"
        case .ampRelease: return "Amp Release"
        case .lfoRate: return "LFO Rate"
        case .lfoAmount: return "LFO Amount"
        }
    }
}

enum EffectParameterType: String, CaseIterable {
    case reverbSize = "reverb_size"
    case reverbDamping = "reverb_damping"
    case reverbMix = "reverb_mix"
    case delayTime = "delay_time"
    case delayFeedback = "delay_feedback"
    case delayMix = "delay_mix"
    case distortionDrive = "distortion_drive"
    case distortionTone = "distortion_tone"
    case compThreshold = "comp_threshold"
    case compRatio = "comp_ratio"
    
    var parameterName: String {
        return rawValue
    }
    
    var displayName: String {
        switch self {
        case .reverbSize: return "Reverb Size"
        case .reverbDamping: return "Reverb Damping"
        case .reverbMix: return "Reverb Mix"
        case .delayTime: return "Delay Time"
        case .delayFeedback: return "Delay Feedback"
        case .delayMix: return "Delay Mix"
        case .distortionDrive: return "Distortion Drive"
        case .distortionTone: return "Distortion Tone"
        case .compThreshold: return "Comp Threshold"
        case .compRatio: return "Comp Ratio"
        }
    }
}

// MARK: - Parameter Lock Errors

enum ParameterLockError: LocalizedError {
    case emptyParameterName
    case invalidValue(Double)
    case invalidPercentage(Double)
    
    var errorDescription: String? {
        switch self {
        case .emptyParameterName:
            return "Parameter name cannot be empty"
        case .invalidValue(let value):
            return "Invalid value: \(value). Must be between 0.0 and 1.0"
        case .invalidPercentage(let percentage):
            return "Invalid percentage: \(percentage). Must be between 0.0 and 100.0"
        }
    }
} 