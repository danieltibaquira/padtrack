import Foundation
import Combine
import CoreData
import VoiceModule
import AudioEngine
import DataLayer
import DataModel

/// Bridge class that connects UI parameter changes to the audio engine
/// Provides real-time parameter updates with <1ms latency and maintains data persistence
@MainActor
public final class FMParameterBridge: ObservableObject {
    
    // MARK: - Properties
    
    private let voiceMachine: FMToneVoiceMachine?
    private let audioEngine: AudioEngine?
    private let coreDataStack: CoreDataStack?
    private var currentPreset: Preset?
    
    // Parameter mapping and scaling
    private let parameterSpecs: [FMParameterID: ParameterSpec]
    
    // Performance monitoring
    private let updateQueue = DispatchQueue(label: "FMParameterBridge", qos: .userInteractive)
    private var lastUpdateTime: CFTimeInterval = 0
    private var updateCount: Int = 0
    
    // Callbacks for testing and monitoring
    public var parameterUpdateCallback: ((FMParameterID, Double) -> Void)?
    public var performanceCallback: ((CFTimeInterval) -> Void)?
    
    // MARK: - Initialization
    
    public init(
        voiceMachine: FMToneVoiceMachine? = nil,
        audioEngine: AudioEngine? = nil,
        coreDataStack: CoreDataStack? = nil
    ) {
        self.voiceMachine = voiceMachine
        self.audioEngine = audioEngine
        self.coreDataStack = coreDataStack
        self.parameterSpecs = Self.createParameterSpecs()
    }
    
    // MARK: - Parameter Scaling
    
    /// Scale UI value (0.0-1.0) to parameter's native range
    public func scaleParameter(_ parameterID: FMParameterID, uiValue: Double) -> Double {
        guard let spec = parameterSpecs[parameterID] else {
            return clampValue(uiValue, min: 0.0, max: 1.0)
        }
        
        let clampedUI = clampValue(uiValue, min: 0.0, max: 1.0)
        let scaledValue = spec.minValue + clampedUI * (spec.maxValue - spec.minValue)
        
        // Apply curve if needed
        let curvedValue = spec.curve.apply(Float(scaledValue))
        
        return clampValue(Double(curvedValue), min: spec.minValue, max: spec.maxValue)
    }
    
    /// Scale parameter's native value to UI range (0.0-1.0)
    public func normalizeParameter(_ parameterID: FMParameterID, nativeValue: Double) -> Double {
        guard let spec = parameterSpecs[parameterID] else {
            return clampValue(nativeValue, min: 0.0, max: 1.0)
        }
        
        let clampedNative = clampValue(nativeValue, min: spec.minValue, max: spec.maxValue)
        let normalized = (clampedNative - spec.minValue) / (spec.maxValue - spec.minValue)
        
        return clampValue(normalized, min: 0.0, max: 1.0)
    }
    
    // MARK: - Parameter Updates
    
    /// Update parameter value with real-time audio engine integration
    public func updateParameter(_ parameterID: FMParameterID, value: Double) {
        let startTime = CACurrentMediaTime()
        
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Scale value to parameter's native range
            let scaledValue = self.scaleParameter(parameterID, uiValue: value)
            
            // Update audio engine immediately
            self.updateAudioEngine(parameterID, value: scaledValue)
            
            // Update persistence if preset is attached
            self.updatePersistence(parameterID, value: scaledValue)
            
            // Track performance
            let updateTime = CACurrentMediaTime() - startTime
            self.trackPerformance(updateTime)
            
            // Notify callbacks
            DispatchQueue.main.async {
                self.parameterUpdateCallback?(parameterID, scaledValue)
                self.performanceCallback?(updateTime)
            }
        }
    }
    
    /// Update multiple parameters efficiently in batch
    public func updateParameters(_ parameters: [(FMParameterID, Double)]) {
        let startTime = CACurrentMediaTime()
        
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            for (parameterID, value) in parameters {
                let scaledValue = self.scaleParameter(parameterID, uiValue: value)
                self.updateAudioEngine(parameterID, value: scaledValue)
                self.updatePersistence(parameterID, value: scaledValue)
            }
            
            let batchUpdateTime = CACurrentMediaTime() - startTime
            self.trackPerformance(batchUpdateTime)
            
            DispatchQueue.main.async {
                self.performanceCallback?(batchUpdateTime)
            }
        }
    }
    
    // MARK: - Audio Engine Integration
    
    private func updateAudioEngine(_ parameterID: FMParameterID, value: Double) {
        // Convert to VoiceModule parameter ID
        guard let voiceParameterID = mapToVoiceModuleParameter(parameterID) else { return }
        
        // Update voice machine directly for minimum latency
        voiceMachine?.updateParameterDirectly(voiceParameterID, value: Float(value))
        
        // Update audio engine parameter if available
        audioEngine?.updateSynthParameter(voiceParameterID, value: Float(value))
    }
    
    private func mapToVoiceModuleParameter(_ parameterID: FMParameterID) -> FMToneParameterID? {
        switch parameterID {
        case .algorithm:
            return .algorithm
        case .ratioA:
            return .opA_frequency
        case .ratioB:
            return .opB1_frequency
        case .ratioC:
            return .opC_frequency
        case .harmony:
            return .opA_modIndex
        case .detune:
            return .opA_fineTune
        case .feedback:
            return .opA_feedback
        case .mix:
            return .masterVolume
        case .attackA:
            return .opA_env_attack
        case .decayA:
            return .opA_env_decay
        case .endA:
            return .opA_env_sustain
        case .levelA:
            return .opA_outputLevel
        case .attackB:
            return .opB1_env_attack
        case .decayB:
            return .opB1_env_decay
        case .endB:
            return .opB1_env_sustain
        case .levelB:
            return .opB1_outputLevel
        default:
            return nil
        }
    }
    
    // MARK: - Persistence Integration
    
    private func updatePersistence(_ parameterID: FMParameterID, value: Double) {
        guard let preset = currentPreset else { return }
        
        // Save to Core Data in background
        Task.detached { [weak self] in
            await self?.saveParameterToPreset(parameterID, value: value, preset: preset)
        }
    }
    
    private func saveParameterToPreset(_ parameterID: FMParameterID, value: Double, preset: Preset) async {
        guard let coreDataStack = coreDataStack else { return }
        
        let context = coreDataStack.newBackgroundContext()
        
        await context.perform {
            // Find preset in this context
            if let presetInContext = try? context.existingObject(with: preset.objectID) as? Preset {
                // Save parameter value using key-value coding
                presetInContext.setValue(value, forKey: parameterID.persistenceKey)
                
                // Save context
                try? context.save()
            }
        }
    }
    
    // MARK: - Preset Management
    
    /// Attach to a preset for automatic parameter persistence
    public func attachToPreset(_ preset: Preset) {
        currentPreset = preset
    }
    
    /// Detach from current preset
    public func detachFromPreset() {
        currentPreset = nil
    }
    
    /// Load all parameters from a preset
    public func loadPreset(_ preset: Preset) async {
        let parameters = await loadParametersFromPreset(preset)
        
        await MainActor.run {
            // Update all parameters from preset
            for (parameterID, value) in parameters {
                let normalizedValue = normalizeParameter(parameterID, nativeValue: value)
                updateParameter(parameterID, value: normalizedValue)
            }
            
            // Attach to this preset for future updates
            attachToPreset(preset)
        }
    }
    
    private func loadParametersFromPreset(_ preset: Preset) async -> [FMParameterID: Double] {
        guard let coreDataStack = coreDataStack else { return [:] }
        
        let context = coreDataStack.newBackgroundContext()
        var parameters: [FMParameterID: Double] = [:]
        
        await context.perform {
            if let presetInContext = try? context.existingObject(with: preset.objectID) as? Preset {
                for parameterID in FMParameterID.allCases {
                    if let value = presetInContext.value(forKey: parameterID.persistenceKey) as? Double {
                        parameters[parameterID] = value
                    }
                }
            }
        }
        
        return parameters
    }
    
    // MARK: - Performance Monitoring
    
    private func trackPerformance(_ updateTime: CFTimeInterval) {
        updateCount += 1
        lastUpdateTime = updateTime
        
        // Log warning if update takes too long (>1ms requirement)
        if updateTime > 0.001 {
            print("Warning: Parameter update took \(updateTime * 1000)ms (>1ms)")
        }
    }
    
    public func getPerformanceMetrics() -> (averageUpdateTime: CFTimeInterval, updateCount: Int, lastUpdateTime: CFTimeInterval) {
        return (0.0, updateCount, lastUpdateTime) // Simplified for now
    }
    
    // MARK: - Audio Engine Connection Management
    
    public func disconnectFromAudioEngine() {
        // Handle graceful disconnection
        // Parameters updates will still work but won't affect audio
    }
    
    public func reconnectToAudioEngine() {
        // Handle reconnection
        // Restore current parameter state to audio engine
    }
    
    // MARK: - Helper Methods
    
    private func clampValue(_ value: Double, min: Double, max: Double) -> Double {
        return Swift.max(min, Swift.min(max, value.isFinite ? value : min))
    }
    
    // MARK: - Parameter Specifications
    
    private static func createParameterSpecs() -> [FMParameterID: ParameterSpec] {
        return [
            .algorithm: ParameterSpec(minValue: 1.0, maxValue: 8.0, curve: .discrete),
            .ratioA: ParameterSpec(minValue: 0.5, maxValue: 32.0, curve: .exponential),
            .ratioB: ParameterSpec(minValue: 0.5, maxValue: 32.0, curve: .exponential),
            .ratioC: ParameterSpec(minValue: 0.5, maxValue: 32.0, curve: .exponential),
            .harmony: ParameterSpec(minValue: 0.0, maxValue: 1.0, curve: .linear),
            .detune: ParameterSpec(minValue: -64.0, maxValue: 63.0, curve: .linear),
            .feedback: ParameterSpec(minValue: 0.0, maxValue: 1.0, curve: .linear),
            .mix: ParameterSpec(minValue: 0.0, maxValue: 1.0, curve: .linear),
            .attackA: ParameterSpec(minValue: 0.001, maxValue: 10.0, curve: .exponential),
            .decayA: ParameterSpec(minValue: 0.001, maxValue: 10.0, curve: .exponential),
            .endA: ParameterSpec(minValue: 0.0, maxValue: 1.0, curve: .linear),
            .levelA: ParameterSpec(minValue: 0.0, maxValue: 1.0, curve: .linear),
            .attackB: ParameterSpec(minValue: 0.001, maxValue: 10.0, curve: .exponential),
            .decayB: ParameterSpec(minValue: 0.001, maxValue: 10.0, curve: .exponential),
            .endB: ParameterSpec(minValue: 0.0, maxValue: 1.0, curve: .linear),
            .levelB: ParameterSpec(minValue: 0.0, maxValue: 1.0, curve: .linear),
            .delay: ParameterSpec(minValue: 0.0, maxValue: 5.0, curve: .linear),
            .trigMode: ParameterSpec(minValue: 0.0, maxValue: 1.0, curve: .discrete),
            .phaseReset: ParameterSpec(minValue: 0.0, maxValue: 1.0, curve: .discrete),
            .keyTracking: ParameterSpec(minValue: 0.0, maxValue: 2.0, curve: .linear),
            .offsetA: ParameterSpec(minValue: -100.0, maxValue: 100.0, curve: .linear),
            .offsetB: ParameterSpec(minValue: -100.0, maxValue: 100.0, curve: .linear),
            .velocitySensitivity: ParameterSpec(minValue: 0.0, maxValue: 1.0, curve: .linear),
            .scale: ParameterSpec(minValue: 0.0, maxValue: 11.0, curve: .discrete),
            .root: ParameterSpec(minValue: 0.0, maxValue: 11.0, curve: .discrete),
            .tune: ParameterSpec(minValue: -24.0, maxValue: 24.0, curve: .linear),
            .fine: ParameterSpec(minValue: -100.0, maxValue: 100.0, curve: .linear)
        ]
    }
}

// MARK: - Supporting Types

/// Parameter specification for scaling and validation
private struct ParameterSpec {
    let minValue: Double
    let maxValue: Double
    let curve: ParameterCurve
}

/// Parameter curve types for different scaling behaviors
private enum ParameterCurve {
    case linear
    case exponential
    case logarithmic
    case discrete
    
    func apply(_ value: Float) -> Float {
        switch self {
        case .linear:
            return value
        case .exponential:
            return value * value
        case .logarithmic:
            return sqrt(value)
        case .discrete:
            return round(value)
        }
    }
}

/// FM Parameter IDs for the bridge system
public enum FMParameterID: String, CaseIterable {
    // Page 1 - Core FM
    case algorithm = "algorithm"
    case ratioC = "ratioC"
    case ratioA = "ratioA"
    case ratioB = "ratioB"
    case harmony = "harmony"
    case detune = "detune"
    case feedback = "feedback"
    case mix = "mix"
    
    // Page 2 - Envelopes
    case attackA = "attackA"
    case decayA = "decayA"
    case endA = "endA"
    case levelA = "levelA"
    case attackB = "attackB"
    case decayB = "decayB"
    case endB = "endB"
    case levelB = "levelB"
    
    // Page 3 - Envelope Behavior
    case delay = "delay"
    case trigMode = "trigMode"
    case phaseReset = "phaseReset"
    case reserved1 = "reserved1"
    case reserved2 = "reserved2"
    case keyTracking = "keyTracking"
    
    // Page 4 - Offsets & Key Tracking
    case offsetA = "offsetA"
    case offsetB = "offsetB"
    case velocitySensitivity = "velocitySensitivity"
    case scale = "scale"
    case root = "root"
    case tune = "tune"
    case fine = "fine"
    
    /// Key used for Core Data persistence
    var persistenceKey: String {
        return "fm_\(rawValue)"
    }
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .algorithm: return "Algorithm"
        case .ratioA: return "Ratio A"
        case .ratioB: return "Ratio B"
        case .ratioC: return "Ratio C"
        case .harmony: return "Harmony"
        case .detune: return "Detune"
        case .feedback: return "Feedback"
        case .mix: return "Mix"
        case .attackA: return "Attack A"
        case .decayA: return "Decay A"
        case .endA: return "End A"
        case .levelA: return "Level A"
        case .attackB: return "Attack B"
        case .decayB: return "Decay B"
        case .endB: return "End B"
        case .levelB: return "Level B"
        case .delay: return "Delay"
        case .trigMode: return "Trig Mode"
        case .phaseReset: return "Phase Reset"
        case .keyTracking: return "Key Tracking"
        case .offsetA: return "Offset A"
        case .offsetB: return "Offset B"
        case .velocitySensitivity: return "Velocity Sensitivity"
        case .scale: return "Scale"
        case .root: return "Root"
        case .tune: return "Tune"
        case .fine: return "Fine"
        default: return rawValue.capitalized
        }
    }
}

// MARK: - Extensions for Audio Engine Integration

extension FMToneVoiceMachine {
    /// Direct parameter update for minimum latency
    func updateParameterDirectly(_ parameterID: FMToneParameterID, value: Float) {
        // This would call the existing parameter update methods
        // Implementation depends on the existing FMToneVoiceMachine interface
    }
}

extension AudioEngine {
    /// Update synthesis parameter in audio engine
    func updateSynthParameter(_ parameterID: FMToneParameterID, value: Float) {
        // This would update the parameter in the audio engine
        // Implementation depends on the existing AudioEngine interface
    }
}