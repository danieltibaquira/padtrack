//
//  FMDrumCPUOptimizer.swift
//  DigitonePad - VoiceModule
//
//  CPU usage optimization system for FM DRUM voice machine
//

import Foundation
import os.signpost

/// Comprehensive CPU optimization system for FM DRUM synthesis
public final class FMDrumCPUOptimizer: @unchecked Sendable {
    
    // MARK: - Performance Monitoring
    
    private let performanceLog = OSLog(subsystem: "com.digitonepad.voicemodule", category: "performance")
    private let cpuSignpost = OSSignposter(logHandle: OSLog(subsystem: "com.digitonepad.voicemodule", category: "cpu"))
    
    // CPU usage tracking
    private var cpuUsageHistory: [Double] = []
    private var averageCPUUsage: Double = 0.0
    private var peakCPUUsage: Double = 0.0
    private var currentCPUUsage: Double = 0.0
    
    // Performance thresholds
    private let cpuWarningThreshold: Double = 0.7  // 70% CPU usage
    private let cpuCriticalThreshold: Double = 0.85 // 85% CPU usage
    private let historySize: Int = 100
    
    // Optimization state
    private var optimizationLevel: OptimizationLevel = .balanced
    private var isAdaptiveOptimizationEnabled: Bool = true
    private var lastOptimizationTime: Date = Date()
    
    // Voice management optimization
    private var maxActiveVoices: Int = 8
    private var voiceStealingEnabled: Bool = true
    private var voicePriorityQueue: [VoicePriority] = []
    
    // Processing optimization
    private var bufferSizeOptimization: Bool = true
    private var simdOptimizationEnabled: Bool = true
    private var backgroundProcessingEnabled: Bool = false
    
    public init() {
        setupPerformanceMonitoring()
    }
    
    // MARK: - CPU Monitoring
    
    /// Update CPU usage measurement
    public func updateCPUUsage(_ usage: Double) {
        currentCPUUsage = usage
        
        // Add to history
        cpuUsageHistory.append(usage)
        if cpuUsageHistory.count > historySize {
            cpuUsageHistory.removeFirst()
        }
        
        // Update statistics
        averageCPUUsage = cpuUsageHistory.reduce(0, +) / Double(cpuUsageHistory.count)
        peakCPUUsage = max(peakCPUUsage, usage)
        
        // Trigger adaptive optimization if enabled
        if isAdaptiveOptimizationEnabled {
            adaptiveOptimization()
        }
        
        // Log performance warnings
        logPerformanceWarnings(usage)
    }
    
    /// Get current CPU usage statistics
    public func getCPUStatistics() -> CPUStatistics {
        return CPUStatistics(
            current: currentCPUUsage,
            average: averageCPUUsage,
            peak: peakCPUUsage,
            optimizationLevel: optimizationLevel
        )
    }
    
    // MARK: - Adaptive Optimization
    
    private func adaptiveOptimization() {
        let now = Date()
        
        // Only optimize every 100ms to avoid thrashing
        guard now.timeIntervalSince(lastOptimizationTime) > 0.1 else { return }
        lastOptimizationTime = now
        
        let signpostID = cpuSignpost.makeSignpostID()
        let intervalState = cpuSignpost.beginInterval("AdaptiveOptimization", id: signpostID)
        
        defer {
            cpuSignpost.endInterval("AdaptiveOptimization", intervalState)
        }
        
        if currentCPUUsage > cpuCriticalThreshold {
            // Critical CPU usage - aggressive optimization
            optimizationLevel = .aggressive
            applyAggressiveOptimizations()
            
        } else if currentCPUUsage > cpuWarningThreshold {
            // High CPU usage - moderate optimization
            optimizationLevel = .moderate
            applyModerateOptimizations()
            
        } else if averageCPUUsage < 0.3 && optimizationLevel != .quality {
            // Low CPU usage - can afford quality improvements
            optimizationLevel = .quality
            applyQualityOptimizations()
            
        } else if averageCPUUsage < 0.5 && optimizationLevel == .aggressive {
            // CPU usage normalized - return to balanced
            optimizationLevel = .balanced
            applyBalancedOptimizations()
        }
    }
    
    // MARK: - Optimization Strategies
    
    private func applyAggressiveOptimizations() {
        os_signpost(.event, log: performanceLog, name: "AggressiveOptimization")
        
        // Reduce polyphony
        maxActiveVoices = max(2, maxActiveVoices - 1)
        
        // Enable all CPU-saving features
        simdOptimizationEnabled = true
        bufferSizeOptimization = true
        voiceStealingEnabled = true
        
        // Reduce quality for performance
        setProcessingQuality(.low)
        
        // Enable background processing for non-critical tasks
        backgroundProcessingEnabled = true
    }
    
    private func applyModerateOptimizations() {
        os_signpost(.event, log: performanceLog, name: "ModerateOptimization")
        
        // Slightly reduce polyphony
        maxActiveVoices = max(4, maxActiveVoices)
        
        // Enable performance features
        simdOptimizationEnabled = true
        bufferSizeOptimization = true
        voiceStealingEnabled = true
        
        // Balanced quality
        setProcessingQuality(.medium)
    }
    
    private func applyBalancedOptimizations() {
        os_signpost(.event, log: performanceLog, name: "BalancedOptimization")
        
        // Standard polyphony
        maxActiveVoices = 8
        
        // Standard optimizations
        simdOptimizationEnabled = true
        bufferSizeOptimization = true
        voiceStealingEnabled = true
        
        // Balanced quality
        setProcessingQuality(.medium)
        backgroundProcessingEnabled = false
    }
    
    private func applyQualityOptimizations() {
        os_signpost(.event, log: performanceLog, name: "QualityOptimization")
        
        // Allow higher polyphony
        maxActiveVoices = min(16, maxActiveVoices + 1)
        
        // Keep essential optimizations
        simdOptimizationEnabled = true
        bufferSizeOptimization = false // Allow smaller buffers for lower latency
        voiceStealingEnabled = false   // Avoid stealing for better quality
        
        // High quality processing
        setProcessingQuality(.high)
        backgroundProcessingEnabled = false
    }
    
    // MARK: - Voice Management Optimization
    
    /// Optimize voice allocation based on CPU usage
    public func optimizeVoiceAllocation(activeVoices: inout Set<Int>, voices: [FMDrumVoice]) -> Bool {
        // Check if we need to steal voices
        if activeVoices.count >= maxActiveVoices && voiceStealingEnabled {
            return performVoiceStealing(activeVoices: &activeVoices, voices: voices)
        }
        
        return activeVoices.count < maxActiveVoices
    }
    
    private func performVoiceStealing(activeVoices: inout Set<Int>, voices: [FMDrumVoice]) -> Bool {
        // Find the best voice to steal based on priority
        var oldestVoice: Int?
        var oldestTime: Double = Date().timeIntervalSince1970
        
        for voiceIndex in activeVoices {
            let voice = voices[voiceIndex]
            if voice.startTime < oldestTime {
                oldestTime = voice.startTime
                oldestVoice = voiceIndex
            }
        }
        
        if let voiceToSteal = oldestVoice {
            voices[voiceToSteal].quickRelease()
            activeVoices.remove(voiceToSteal)
            return true
        }
        
        return false
    }
    
    // MARK: - Processing Quality Control
    
    private func setProcessingQuality(_ quality: ProcessingQuality) {
        // This would be implemented to adjust various quality parameters
        // For now, we'll just track the setting
    }
    
    // MARK: - Buffer Size Optimization
    
    /// Get optimized buffer size based on CPU usage
    public func getOptimizedBufferSize(requestedSize: Int) -> Int {
        guard bufferSizeOptimization else { return requestedSize }
        
        switch optimizationLevel {
        case .aggressive:
            // Larger buffers for efficiency
            return max(requestedSize, 1024)
            
        case .moderate:
            // Slightly larger buffers
            return max(requestedSize, 512)
            
        case .balanced:
            // Use requested size
            return requestedSize
            
        case .quality:
            // Smaller buffers for lower latency
            return min(requestedSize, 256)
        }
    }
    
    // MARK: - Performance Logging
    
    private func setupPerformanceMonitoring() {
        // Initialize performance monitoring
        os_signpost(.begin, log: performanceLog, name: "FMDrumCPUOptimizer")
    }
    
    private func logPerformanceWarnings(_ cpuUsage: Double) {
        if cpuUsage > cpuCriticalThreshold {
            os_log(.error, log: performanceLog, "Critical CPU usage: %.1f%%", cpuUsage * 100)
        } else if cpuUsage > cpuWarningThreshold {
            os_log(.info, log: performanceLog, "High CPU usage: %.1f%%", cpuUsage * 100)
        }
    }
    
    // MARK: - Configuration
    
    public func setAdaptiveOptimization(_ enabled: Bool) {
        isAdaptiveOptimizationEnabled = enabled
    }
    
    public func setOptimizationLevel(_ level: OptimizationLevel) {
        optimizationLevel = level
        
        switch level {
        case .aggressive:
            applyAggressiveOptimizations()
        case .moderate:
            applyModerateOptimizations()
        case .balanced:
            applyBalancedOptimizations()
        case .quality:
            applyQualityOptimizations()
        }
    }
    
    public func setSIMDOptimization(_ enabled: Bool) {
        simdOptimizationEnabled = enabled
    }
    
    public func setMaxActiveVoices(_ count: Int) {
        maxActiveVoices = max(1, min(32, count))
    }
    
    // MARK: - Getters
    
    public func getOptimizationLevel() -> OptimizationLevel {
        return optimizationLevel
    }
    
    public func getMaxActiveVoices() -> Int {
        return maxActiveVoices
    }
    
    public func isSIMDOptimizationEnabled() -> Bool {
        return simdOptimizationEnabled
    }
    
    public func isVoiceStealingEnabled() -> Bool {
        return voiceStealingEnabled
    }
}

// MARK: - Supporting Types

public enum OptimizationLevel: String, CaseIterable {
    case aggressive = "aggressive"
    case moderate = "moderate"
    case balanced = "balanced"
    case quality = "quality"
}

public enum ProcessingQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

public struct CPUStatistics {
    public let current: Double
    public let average: Double
    public let peak: Double
    public let optimizationLevel: OptimizationLevel
}

public struct VoicePriority {
    public let voiceIndex: Int
    public let priority: Double
    public let startTime: Double
    public let velocity: UInt8
}

// MARK: - CPU Usage Measurement

/// Utility for measuring actual CPU usage
public final class CPUUsageMeasurement: @unchecked Sendable {
    private var lastCPUTime: UInt64 = 0
    private var lastSystemTime: UInt64 = 0
    
    public init() {
        updateBaseline()
    }
    
    /// Measure current CPU usage percentage
    public func measureCPUUsage() -> Double {
        let currentTime = mach_absolute_time()
        let currentCPUTime = getCurrentCPUTime()
        
        defer {
            lastSystemTime = currentTime
            lastCPUTime = currentCPUTime
        }
        
        guard lastSystemTime > 0 && lastCPUTime > 0 else {
            return 0.0
        }
        
        let systemTimeDelta = currentTime - lastSystemTime
        let cpuTimeDelta = currentCPUTime - lastCPUTime
        
        guard systemTimeDelta > 0 else { return 0.0 }
        
        return Double(cpuTimeDelta) / Double(systemTimeDelta)
    }
    
    private func updateBaseline() {
        lastSystemTime = mach_absolute_time()
        lastCPUTime = getCurrentCPUTime()
    }
    
    private func getCurrentCPUTime() -> UInt64 {
        var info = thread_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                thread_info(mach_thread_self(), thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0 }
        
        return UInt64(info.user_time.seconds) * 1_000_000 + UInt64(info.user_time.microseconds) +
               UInt64(info.system_time.seconds) * 1_000_000 + UInt64(info.system_time.microseconds)
    }
}
