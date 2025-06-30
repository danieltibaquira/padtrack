//
//  FMToneSynthesisEngine.swift
//  DigitonePad - VoiceModule
//
//  FM TONE synthesis engine managing multiple voices with advanced optimizations
//

import Foundation
import Accelerate
import QuartzCore
import os.signpost

/// FM TONE synthesis engine with comprehensive voice management and optimization
public final class FMToneSynthesisEngine: @unchecked Sendable {
    
    // MARK: - Engine Configuration
    
    private let sampleRate: Double
    private let maxPolyphony: Int
    private let bufferSize: Int = 512
    
    // Voice management
    private var voices: [FMToneVoiceMachine] = []
    private var activeVoices: Set<Int> = []
    private var outputBuffer: [Double]
    
    // DSP optimization system
    private let dspOptimizations: FMToneDSPOptimizations
    private let performanceMonitor = OSSignposter(logHandle: OSLog(subsystem: "com.digitonepad.voicemodule", category: "fm-tone-engine"))
    
    // Global parameters
    private var masterVolume: Double = 0.8
    private var currentAlgorithm: Int = 1
    private var masterTuning: Double = 0.0
    private var pitchBendRange: Double = 2.0  // semitones
    private var currentPitchBend: Double = 0.0
    private var modWheel: Double = 0.0
    
    // Performance metrics
    private var metrics = FMToneDSPOptimizations.PerformanceMetrics()
    
    // Thread safety
    private let engineQueue = DispatchQueue(label: "FMToneEngine", qos: .userInitiated)
    
    public init(sampleRate: Double = 44100.0, maxPolyphony: Int = 16) {
        self.sampleRate = sampleRate
        self.maxPolyphony = maxPolyphony
        self.outputBuffer = [Double](repeating: 0.0, count: bufferSize)
        
        // Initialize DSP optimizations
        let optimizationSettings = FMToneDSPOptimizations.OptimizationSettings.defaultSettings
        self.dspOptimizations = FMToneDSPOptimizations(sampleRate: sampleRate, settings: optimizationSettings)
        
        // Initialize voices
        initializeVoices()
        setupDefaultParameters()
        
        os_signpost(.begin, log: performanceMonitor.logHandle, name: "FMToneSynthesisEngine")
    }
    
    private func initializeVoices() {
        for _ in 0..<maxPolyphony {
            let voice = FMToneVoiceMachine(sampleRate: sampleRate)
            voices.append(voice)
        }
    }
    
    private func setupDefaultParameters() {
        masterVolume = 0.8
        currentAlgorithm = 1
        masterTuning = 0.0
        pitchBendRange = 2.0
        currentPitchBend = 0.0
        modWheel = 0.0
    }
    
    // MARK: - Voice Management
    
    /// Start a note with comprehensive parameter setup
    public func noteOn(note: UInt8, velocity: UInt8, channel: UInt8 = 0) -> Bool {
        return engineQueue.sync {
            let startTime = CACurrentMediaTime()
            defer {
                let endTime = CACurrentMediaTime()
                metrics.totalProcessingTime += (endTime - startTime)
            }
            
            // Find available voice
            guard let voiceIndex = findAvailableVoice() else {
                // Voice stealing with intelligent selection
                guard let stolenVoice = performVoiceStealing() else { return false }
                return startVoice(index: stolenVoice, note: note, velocity: velocity, channel: channel)
            }
            
            return startVoice(index: voiceIndex, note: note, velocity: velocity, channel: channel)
        }
    }
    
    /// Release a note
    public func noteOff(note: UInt8, velocity: UInt8 = 64, channel: UInt8 = 0) {
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Find active voice with this note
            for voiceIndex in self.activeVoices {
                let voice = self.voices[voiceIndex]
                if voice.noteNumber == Int(note) && voice.active {
                    voice.noteOff()
                    // Voice will be removed from activeVoices when it becomes inactive
                    break
                }
            }
        }
    }
    
    /// Stop all notes immediately
    public func allNotesOff() {
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            
            for voiceIndex in self.activeVoices {
                self.voices[voiceIndex].noteOff()
            }
            // Voices will be removed as they become inactive
        }
    }
    
    /// Emergency stop all voices
    public func stopAllVoices() {
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            
            for voiceIndex in self.activeVoices {
                self.voices[voiceIndex].reset()
            }
            self.activeVoices.removeAll()
        }
    }
    
    private func findAvailableVoice() -> Int? {
        for (index, voice) in voices.enumerated() {
            if !voice.active && !activeVoices.contains(index) {
                return index
            }
        }
        return nil
    }
    
    private func performVoiceStealing() -> Int? {
        // Intelligent voice stealing algorithm
        guard !activeVoices.isEmpty else { return nil }
        
        // Priority 1: Find quietest voice
        var quietestVoice: Int?
        var quietestLevel: Double = Double.greatestFiniteMagnitude
        
        // Priority 2: Find oldest voice (fallback)
        var oldestVoice: Int?
        var oldestTime: Double = Double.greatestFiniteMagnitude
        
        for voiceIndex in activeVoices {
            let voice = voices[voiceIndex]
            
            // Check if voice is in release phase (easier to steal)
            if !voice.active {
                return voiceIndex
            }
            
            // Track oldest voice as fallback
            let voiceAge = CACurrentMediaTime() // Would need proper timing
            if voiceAge < oldestTime {
                oldestTime = voiceAge
                oldestVoice = voiceIndex
            }
        }
        
        // Return quietest voice if found, otherwise oldest
        return quietestVoice ?? oldestVoice
    }
    
    private func startVoice(index: Int, note: UInt8, velocity: UInt8, channel: UInt8) -> Bool {
        guard index < voices.count else { return false }
        
        let voice = voices[index]
        
        // Configure voice with current engine parameters
        voice.setAlgorithm(currentAlgorithm)
        
        // Apply global modulation
        applyGlobalModulationToVoice(voice)
        
        // Start the voice
        voice.noteOn(noteNumber: Int(note), velocity: Float(velocity) / 127.0)
        activeVoices.insert(index)
        
        return true
    }
    
    private func applyGlobalModulationToVoice(_ voice: FMToneVoiceMachine) {
        // Apply pitch bend, mod wheel, and other global parameters
        let parameterControl = voice.getParameterControl()
        
        // Apply master tuning
        if masterTuning != 0.0 {
            parameterControl.setParameter(.masterTune, value: Float(masterTuning))
        }
        
        // Apply mod wheel to modulation indices
        if modWheel > 0.0 {
            let modAmount = Float(modWheel)
            parameterControl.setParameter(.operator2ModIndex, 
                                        value: parameterControl.getParameterValue(.operator2ModIndex) * (1.0 + modAmount))
            parameterControl.setParameter(.operator3ModIndex, 
                                        value: parameterControl.getParameterValue(.operator3ModIndex) * (1.0 + modAmount))
        }
    }
    
    // MARK: - Audio Processing
    
    /// Process audio buffer with comprehensive optimization
    public func processBuffer(frameCount: Int) -> [Double] {
        let startTime = CACurrentMediaTime()
        defer {
            let endTime = CACurrentMediaTime()
            metrics.totalProcessingTime += (endTime - startTime)
            metrics.blocksProcessed += 1
            metrics.samplesProcessed += frameCount
        }
        
        os_signpost(.begin, log: performanceMonitor.logHandle, name: "ProcessBuffer")
        defer { os_signpost(.end, log: performanceMonitor.logHandle, name: "ProcessBuffer") }
        
        // Handle large buffers by processing in chunks
        guard frameCount <= bufferSize else {
            return processLargeBuffer(frameCount: frameCount)
        }
        
        return engineQueue.sync { [weak self] in
            guard let self = self else { return Array(repeating: 0.0, count: frameCount) }
            
            // Clear output buffer
            for i in 0..<frameCount {
                self.outputBuffer[i] = 0.0
            }
            
            // Process each active voice
            var voicesToRemove: Set<Int> = []
            
            for voiceIndex in self.activeVoices {
                let voice = self.voices[voiceIndex]
                
                if voice.active {
                    // Process voice buffer
                    let voiceOutput = voice.processBuffer(frameCount: frameCount)
                    
                    // Mix into output buffer using SIMD when possible
                    if voiceOutput.count >= frameCount {
                        for i in 0..<frameCount {
                            self.outputBuffer[i] += voiceOutput[i]
                        }
                    }
                } else {
                    // Voice has become inactive, mark for removal
                    voicesToRemove.insert(voiceIndex)
                }
            }
            
            // Remove inactive voices
            for voiceIndex in voicesToRemove {
                self.activeVoices.remove(voiceIndex)
            }
            
            // Apply master volume using SIMD
            if self.masterVolume != 1.0 {
                var masterVol = self.masterVolume
                vDSP_vsmulD(self.outputBuffer, 1, &masterVol, &self.outputBuffer, 1, vDSP_Length(frameCount))
            }
            
            return Array(self.outputBuffer[0..<frameCount])
        }
    }
    
    private func processLargeBuffer(frameCount: Int) -> [Double] {
        var result: [Double] = []
        var remaining = frameCount
        
        while remaining > 0 {
            let chunkSize = min(remaining, bufferSize)
            let chunk = processBuffer(frameCount: chunkSize)
            result.append(contentsOf: chunk)
            remaining -= chunkSize
        }
        
        return result
    }
    
    /// Process single sample for real-time applications
    public func processSample() -> Double {
        return engineQueue.sync { [weak self] in
            guard let self = self else { return 0.0 }
            
            var output: Double = 0.0
            var voicesToRemove: Set<Int> = []
            
            // Sum all active voices
            for voiceIndex in self.activeVoices {
                let voice = self.voices[voiceIndex]
                
                if voice.active {
                    output += voice.processSample()
                } else {
                    voicesToRemove.insert(voiceIndex)
                }
            }
            
            // Remove inactive voices
            for voiceIndex in voicesToRemove {
                self.activeVoices.remove(voiceIndex)
            }
            
            return output * self.masterVolume
        }
    }
    
    // MARK: - Parameter Control
    
    /// Set the FM algorithm for all voices
    public func setAlgorithm(_ algorithmNumber: Int) {
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.currentAlgorithm = max(1, min(8, algorithmNumber))
            
            // Update all voices
            for voice in self.voices {
                voice.setAlgorithm(self.currentAlgorithm)
            }
        }
    }
    
    /// Set master volume (0.0 to 1.0)
    public func setMasterVolume(_ volume: Double) {
        masterVolume = max(0.0, min(1.0, volume))
    }
    
    /// Set master tuning in cents
    public func setMasterTuning(_ cents: Double) {
        masterTuning = max(-100.0, min(100.0, cents))
        
        // Update all active voices
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            for voiceIndex in self.activeVoices {
                self.applyGlobalModulationToVoice(self.voices[voiceIndex])
            }
        }
    }
    
    /// Set pitch bend (-1.0 to +1.0)
    public func setPitchBend(_ bend: Double) {
        currentPitchBend = max(-1.0, min(1.0, bend))
        
        // Apply to all active voices
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            let pitchBendCents = self.currentPitchBend * self.pitchBendRange * 100.0 // Convert to cents
            
            for voiceIndex in self.activeVoices {
                let voice = self.voices[voiceIndex]
                let parameterControl = voice.getParameterControl()
                parameterControl.setParameter(.masterTune, value: Float(pitchBendCents))
            }
        }
    }
    
    /// Set modulation wheel (0.0 to 1.0)
    public func setModWheel(_ value: Double) {
        modWheel = max(0.0, min(1.0, value))
        
        // Apply to all active voices
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            for voiceIndex in self.activeVoices {
                self.applyGlobalModulationToVoice(self.voices[voiceIndex])
            }
        }
    }
    
    /// Set pitch bend range in semitones
    public func setPitchBendRange(_ semitones: Double) {
        pitchBendRange = max(0.0, min(24.0, semitones))
    }
    
    // MARK: - Performance and Diagnostics
    
    /// Get current performance metrics
    public func getPerformanceMetrics() -> FMToneDSPOptimizations.PerformanceMetrics {
        return metrics
    }
    
    /// Run performance benchmark
    public func runPerformanceBenchmark() -> FMToneDSPOptimizations.FMTonePerformanceBenchmark.BenchmarkResult? {
        return dspOptimizations.runBenchmark()
    }
    
    /// Get current polyphony usage
    public var polyphonyUsage: Int {
        return engineQueue.sync { activeVoices.count }
    }
    
    /// Check if engine is processing audio
    public var isActive: Bool {
        return engineQueue.sync { !activeVoices.isEmpty }
    }
    
    /// Get voice pool usage
    public var voicePoolUsage: Float {
        return dspOptimizations.poolUsage
    }
    
    /// Reset engine to initial state
    public func reset() {
        engineQueue.sync { [weak self] in
            guard let self = self else { return }
            
            // Stop all voices
            self.stopAllVoices()
            
            // Reset all voices
            for voice in self.voices {
                voice.reset()
            }
            
            // Reset parameters
            self.setupDefaultParameters()
            
            // Reset metrics
            self.metrics = FMToneDSPOptimizations.PerformanceMetrics()
        }
    }
    
    // MARK: - Advanced Voice Management
    
    /// Get voice by index for direct parameter control
    public func getVoice(at index: Int) -> FMToneVoiceMachine? {
        guard index >= 0 && index < voices.count else { return nil }
        return voices[index]
    }
    
    /// Get all active voice indices
    public var activeVoiceIndices: Set<Int> {
        return engineQueue.sync { activeVoices }
    }
    
    /// Set optimization level for all voices
    public func setOptimizationLevel(_ level: FMToneDSPOptimizations.OptimizationLevel) {
        let settings = FMToneDSPOptimizations.OptimizationSettings(level: level)
        
        for voice in voices {
            voice.setOptimizedDSP(level != .minimal)
        }
    }
    
    deinit {
        os_signpost(.end, log: performanceMonitor.logHandle, name: "FMToneSynthesisEngine")
    }
} 