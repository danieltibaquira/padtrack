import Foundation
import MachineProtocols
import Combine
import Accelerate

/// Integrated send effects manager that coordinates routing and track processors
public class SendEffectsManager: ObservableObject {
    
    // MARK: - Properties
    
    /// Send routing system
    @Published public private(set) var sendRoutingSystem: SendRoutingSystem
    
    /// Track processors with send controls
    @Published public private(set) var trackProcessors: [TrackEffectsProcessor] = []
    
    /// Master send bypass
    @Published public var masterSendBypass: Bool = false
    
    /// Master send level
    @Published public var masterSendLevel: Float = 1.0 {
        didSet {
            masterSendLevel = max(0.0, min(2.0, masterSendLevel))
            sendRoutingSystem.masterSendLevel = masterSendLevel
        }
    }

    /// Performance monitoring
    private var performanceMonitor = SendPerformanceMonitor()

    /// Optimization settings
    public var optimizationSettings = SendOptimizationSettings()
    
    // MARK: - Initialization
    
    public init() {
        self.sendRoutingSystem = SendRoutingSystem()
        setupDefaultConfiguration()
    }
    
    // MARK: - Track Management
    
    /// Add a track processor to the send system
    public func addTrackProcessor(_ processor: TrackEffectsProcessor) {
        trackProcessors.append(processor)
    }
    
    /// Remove a track processor
    public func removeTrackProcessor(at index: Int) -> TrackEffectsProcessor? {
        guard index >= 0 && index < trackProcessors.count else { return nil }
        return trackProcessors.remove(at: index)
    }
    
    /// Get track processor by index
    public func getTrackProcessor(at index: Int) -> TrackEffectsProcessor? {
        guard index >= 0 && index < trackProcessors.count else { return nil }
        return trackProcessors[index]
    }
    
    // MARK: - Audio Processing
    
    /// Process audio through tracks and send effects
    public func processAudio(trackInputs: [MachineProtocols.AudioBuffer]) -> [MachineProtocols.AudioBuffer] {
        performanceMonitor.startTiming()

        guard !masterSendBypass else {
            // Process tracks without sends
            let outputs = trackInputs.enumerated().map { index, input in
                if index < trackProcessors.count {
                    return trackProcessors[index].process(input: input)
                }
                return input
            }
            performanceMonitor.endTiming(samplesProcessed: trackInputs.reduce(0) { $0 + $1.samples.count })
            return outputs
        }

        // Early exit if no active sends (optimization)
        if optimizationSettings.skipInactiveSends && !hasActiveSends() {
            let outputs = trackInputs.enumerated().map { index, input in
                if index < trackProcessors.count {
                    return trackProcessors[index].process(input: input)
                }
                return input
            }
            performanceMonitor.endTiming(samplesProcessed: trackInputs.reduce(0) { $0 + $1.samples.count })
            return outputs
        }

        // Process each track through its effects processor
        var trackOutputs: [MachineProtocols.AudioBuffer] = []
        trackOutputs.reserveCapacity(trackInputs.count)

        for (index, input) in trackInputs.enumerated() {
            if index < trackProcessors.count {
                let processedTrack = trackProcessors[index].process(input: input)
                trackOutputs.append(processedTrack)
            } else {
                trackOutputs.append(input)
            }
        }

        // Collect send levels from all tracks (optimized)
        let sendLevelsMatrix = collectSendLevelsOptimized()

        // Process through send effects
        let finalOutputs = sendRoutingSystem.processSends(
            trackOutputs: trackOutputs,
            sendLevels: sendLevelsMatrix
        )

        performanceMonitor.endTiming(samplesProcessed: trackInputs.reduce(0) { $0 + $1.samples.count })
        return finalOutputs
    }
    
    // MARK: - Send Effect Management
    
    /// Get available send effects
    public func getSendEffects() -> [SendEffect] {
        return sendRoutingSystem.sendEffects
    }
    
    /// Get send effect by index
    public func getSendEffect(at index: Int) -> SendEffect? {
        return sendRoutingSystem.getSendEffect(at: index)
    }
    
    /// Add a custom send effect
    public func addSendEffect(_ effect: SendEffect) -> Bool {
        return sendRoutingSystem.addSendEffect(effect)
    }
    
    /// Remove send effect
    public func removeSendEffect(at index: Int) -> SendEffect? {
        return sendRoutingSystem.removeSendEffect(at: index)
    }
    
    // MARK: - Send Level Management
    
    /// Set send level for a specific track and send
    public func setSendLevel(_ level: Float, trackIndex: Int, sendIndex: Int) {
        guard trackIndex >= 0 && trackIndex < trackProcessors.count else { return }
        trackProcessors[trackIndex].setSendLevel(level, for: sendIndex)
    }
    
    /// Get send level for a specific track and send
    public func getSendLevel(trackIndex: Int, sendIndex: Int) -> Float {
        guard trackIndex >= 0 && trackIndex < trackProcessors.count else { return 0.0 }
        return trackProcessors[trackIndex].getSendLevel(for: sendIndex)
    }
    
    /// Reset all send levels for all tracks
    public func resetAllSendLevels() {
        for processor in trackProcessors {
            processor.resetSendLevels()
        }
    }
    
    /// Apply send preset to all tracks
    public func applySendPreset(_ preset: SendPreset) {
        for processor in trackProcessors {
            processor.setSendLevels(preset.sendLevels)
        }
    }
    
    // MARK: - Preset Management
    
    /// Save current send configuration as preset
    public func saveSendPreset(name: String) -> SendSystemPreset {
        let trackSendLevels = trackProcessors.map { $0.sendLevels }
        let sendEffectSettings = getSendEffects().map { effect in
            SendEffectSettings(
                name: effect.name,
                returnLevel: effect.returnLevel,
                isBypassed: effect.isBypassed,
                isEnabled: effect.isEnabled
            )
        }
        
        return SendSystemPreset(
            name: name,
            masterSendLevel: masterSendLevel,
            masterSendBypass: masterSendBypass,
            trackSendLevels: trackSendLevels,
            sendEffectSettings: sendEffectSettings
        )
    }
    
    /// Load send preset
    public func loadSendPreset(_ preset: SendSystemPreset) {
        masterSendLevel = preset.masterSendLevel
        masterSendBypass = preset.masterSendBypass
        
        // Apply track send levels
        for (trackIndex, sendLevels) in preset.trackSendLevels.enumerated() {
            if trackIndex < trackProcessors.count {
                trackProcessors[trackIndex].setSendLevels(sendLevels)
            }
        }
        
        // Apply send effect settings
        for (effectIndex, settings) in preset.sendEffectSettings.enumerated() {
            if let effect = getSendEffect(at: effectIndex) {
                effect.returnLevel = settings.returnLevel
                effect.isBypassed = settings.isBypassed
                effect.isEnabled = settings.isEnabled
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Reset entire send system
    public func resetSendSystem() {
        resetAllSendLevels()
        masterSendLevel = 1.0
        masterSendBypass = false
        
        // Reset all send effects
        for effect in getSendEffects() {
            effect.resetState()
            effect.isBypassed = false
            effect.isEnabled = true
        }
    }
    
    /// Get send system status
    public func getSendSystemStatus() -> SendSystemStatus {
        let totalSendLevels = trackProcessors.flatMap { $0.sendLevels }.reduce(0, +)
        let activeSends = trackProcessors.flatMap { $0.sendLevels }.filter { $0 > 0.01 }.count
        let enabledEffects = getSendEffects().filter { $0.isEnabled && !$0.isBypassed }.count
        
        return SendSystemStatus(
            isActive: !masterSendBypass && totalSendLevels > 0,
            activeSendCount: activeSends,
            enabledEffectCount: enabledEffects,
            totalSendLevel: totalSendLevels,
            masterLevel: masterSendLevel
        )
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultConfiguration() {
        // Send routing system is already initialized with default effects
        masterSendLevel = 1.0
        masterSendBypass = false
    }

    // MARK: - Performance Optimization

    private func hasActiveSends() -> Bool {
        return trackProcessors.contains { processor in
            processor.sendLevels.contains { $0 > optimizationSettings.minimumSendLevel }
        }
    }

    private func collectSendLevelsOptimized() -> [[Float]] {
        if optimizationSettings.cacheSendLevels {
            // Use cached send levels if they haven't changed
            return trackProcessors.map { $0.sendLevels }
        } else {
            return trackProcessors.map { $0.sendLevels }
        }
    }

    /// Get performance metrics
    public func getPerformanceMetrics() -> SendPerformanceMetrics {
        return performanceMonitor.getMetrics()
    }

    /// Reset performance metrics
    public func resetPerformanceMetrics() {
        performanceMonitor.reset()
    }
}

// MARK: - Supporting Types

/// Send preset for individual tracks
public struct SendPreset: Sendable {
    public let name: String
    public let sendLevels: [Float]
    
    public init(name: String, sendLevels: [Float]) {
        self.name = name
        self.sendLevels = sendLevels
    }
    
    // Common presets
    public static let dry = SendPreset(name: "Dry", sendLevels: [0.0, 0.0, 0.0, 0.0])
    public static let subtle = SendPreset(name: "Subtle", sendLevels: [0.1, 0.15, 0.05, 0.0])
    public static let medium = SendPreset(name: "Medium", sendLevels: [0.2, 0.25, 0.1, 0.0])
    public static let heavy = SendPreset(name: "Heavy", sendLevels: [0.4, 0.4, 0.3, 0.0])
}

/// Complete send system preset
public struct SendSystemPreset: Codable {
    public let name: String
    public let masterSendLevel: Float
    public let masterSendBypass: Bool
    public let trackSendLevels: [[Float]]
    public let sendEffectSettings: [SendEffectSettings]
    
    public init(name: String, masterSendLevel: Float, masterSendBypass: Bool, trackSendLevels: [[Float]], sendEffectSettings: [SendEffectSettings]) {
        self.name = name
        self.masterSendLevel = masterSendLevel
        self.masterSendBypass = masterSendBypass
        self.trackSendLevels = trackSendLevels
        self.sendEffectSettings = sendEffectSettings
    }
}

/// Send effect settings for presets
public struct SendEffectSettings: Codable {
    public let name: String
    public let returnLevel: Float
    public let isBypassed: Bool
    public let isEnabled: Bool
    
    public init(name: String, returnLevel: Float, isBypassed: Bool, isEnabled: Bool) {
        self.name = name
        self.returnLevel = returnLevel
        self.isBypassed = isBypassed
        self.isEnabled = isEnabled
    }
}

/// Send system status information
public struct SendSystemStatus {
    public let isActive: Bool
    public let activeSendCount: Int
    public let enabledEffectCount: Int
    public let totalSendLevel: Float
    public let masterLevel: Float
    
    public init(isActive: Bool, activeSendCount: Int, enabledEffectCount: Int, totalSendLevel: Float, masterLevel: Float) {
        self.isActive = isActive
        self.activeSendCount = activeSendCount
        self.enabledEffectCount = enabledEffectCount
        self.totalSendLevel = totalSendLevel
        self.masterLevel = masterLevel
    }
}

// MARK: - Performance Monitoring

/// Performance monitoring for send effects processing
public class SendPerformanceMonitor {
    private var metrics = SendPerformanceMetrics()
    private var startTime: CFAbsoluteTime = 0.0

    func startTiming() {
        startTime = CFAbsoluteTimeGetCurrent()
    }

    func endTiming(samplesProcessed: Int) {
        let endTime = CFAbsoluteTimeGetCurrent()
        let processingTime = endTime - startTime

        metrics.totalProcessingTime += processingTime
        metrics.totalSamplesProcessed += samplesProcessed
        metrics.processCallCount += 1

        // Update peak processing time
        if processingTime > metrics.peakProcessingTime {
            metrics.peakProcessingTime = processingTime
        }
    }

    func getMetrics() -> SendPerformanceMetrics {
        return metrics
    }

    func reset() {
        metrics = SendPerformanceMetrics()
    }
}

/// Performance metrics for send effects
public struct SendPerformanceMetrics {
    public var totalProcessingTime: TimeInterval = 0.0
    public var totalSamplesProcessed: Int = 0
    public var processCallCount: Int = 0
    public var peakProcessingTime: TimeInterval = 0.0

    public var averageProcessingTime: TimeInterval {
        guard processCallCount > 0 else { return 0.0 }
        return totalProcessingTime / Double(processCallCount)
    }

    public var averageProcessingTimePerSample: TimeInterval {
        guard totalSamplesProcessed > 0 else { return 0.0 }
        return totalProcessingTime / Double(totalSamplesProcessed)
    }

    public var cpuUsageEstimate: Float {
        // Rough estimate based on processing time vs real time
        let realTimeForSamples = Double(totalSamplesProcessed) / 44100.0 // Assume 44.1kHz
        guard realTimeForSamples > 0 else { return 0.0 }
        return Float(totalProcessingTime / realTimeForSamples)
    }
}

/// Optimization settings for send effects
public struct SendOptimizationSettings {
    /// Skip processing when no sends are active
    public var skipInactiveSends: Bool = true

    /// Minimum send level to consider active
    public var minimumSendLevel: Float = 0.001

    /// Cache send levels between processing calls
    public var cacheSendLevels: Bool = false

    /// Use SIMD optimizations where available
    public var useSIMDOptimizations: Bool = true

    /// Maximum number of concurrent send effects
    public var maxConcurrentEffects: Int = 4

    public init() {}
}
