// FMDrumSynthesisEngine.swift
// DigitonePad - VoiceModule
//
// Specialized FM synthesis engine for drum sounds

import Foundation
import Accelerate
import QuartzCore

/// FM synthesis engine optimized for percussion sounds
public final class FMDrumSynthesisEngine: @unchecked Sendable {
    // Engine properties
    private let sampleRate: Double
    private let maxPolyphony: Int
    private let bufferSize: Int = 512
    
    // Voice management
    private var voices: [FMDrumVoice] = []
    private var activeVoices: Set<Int> = []
    private var outputBuffer: [Double]

    // Output stage (temporarily disabled)
    // private let outputStage: FMDrumOutputStage

    // CPU optimization (temporarily disabled)
    // private let cpuOptimizer: FMDrumCPUOptimizer
    // private let cpuMeasurement: CPUUsageMeasurement
    
    // Global parameters
    private var masterVolume: Double = 0.8
    private var bodyTone: Double = 0.5
    private var noiseLevel: Double = 0.3
    private var pitchSweepAmount: Double = 0.4
    private var pitchSweepTime: Double = 0.1
    private var wavefoldAmount: Double = 0.2
    private var drumType: DrumType = .kick
    
    public init(sampleRate: Double = 44100.0, maxPolyphony: Int = 8) {
        self.sampleRate = sampleRate
        self.maxPolyphony = maxPolyphony
        self.outputBuffer = [Double](repeating: 0.0, count: bufferSize)
        // self.outputStage = FMDrumOutputStage(sampleRate: sampleRate, bufferSize: bufferSize)
        // self.cpuOptimizer = FMDrumCPUOptimizer()
        // self.cpuMeasurement = CPUUsageMeasurement()

        // Initialize drum voices
        for _ in 0..<maxPolyphony {
            voices.append(FMDrumVoice(sampleRate: sampleRate))
        }

        setupDefaultParameters()
    }
    
    // MARK: - Voice Management
    
    /// Start a drum note
    public func noteOn(note: UInt8, velocity: UInt8) -> Bool {
        // Temporarily disabled CPU optimization
        /*
        guard cpuOptimizer.optimizeVoiceAllocation(activeVoices: &activeVoices, voices: voices) else {
            return false // CPU too high, reject new note
        }
        */

        // Find available voice
        guard let voiceIndex = findAvailableVoice() else {
            // Voice stealing for drums - steal oldest voice
            guard let stolenVoice = stealOldestVoice() else { return false }
            return startVoice(index: stolenVoice, note: note, velocity: velocity)
        }

        return startVoice(index: voiceIndex, note: note, velocity: velocity)
    }
    
    /// Stop a drum note (usually immediate for drums)
    public func noteOff(note: UInt8) {
        // For drums, we typically let the envelope complete naturally
        // But we can implement quick release if needed
        for voiceIndex in activeVoices {
            if voices[voiceIndex].note == note {
                voices[voiceIndex].quickRelease()
            }
        }
    }
    
    private func findAvailableVoice() -> Int? {
        for (index, voice) in voices.enumerated() {
            if !voice.isActive {
                return index
            }
        }
        return nil
    }
    
    private func stealOldestVoice() -> Int? {
        var oldestVoice: Int?
        var oldestTime: Double = Double.greatestFiniteMagnitude
        
        for voiceIndex in activeVoices {
            let voice = voices[voiceIndex]
            if voice.startTime < oldestTime {
                oldestTime = voice.startTime
                oldestVoice = voiceIndex
            }
        }
        
        return oldestVoice
    }
    
    private func startVoice(index: Int, note: UInt8, velocity: UInt8) -> Bool {
        let voice = voices[index]
        
        // Configure voice for current drum type and parameters
        voice.configureDrumVoice(
            drumType: drumType,
            bodyTone: bodyTone,
            noiseLevel: noiseLevel,
            pitchSweepAmount: pitchSweepAmount,
            pitchSweepTime: pitchSweepTime,
            wavefoldAmount: wavefoldAmount
        )
        
        // Start the voice
        voice.noteOn(note: note, velocity: velocity)
        activeVoices.insert(index)
        
        return true
    }
    
    // MARK: - Audio Processing
    
    /// Process a buffer of audio samples
    public func processBuffer(frameCount: Int) -> [Double] {
        // let startTime = CACurrentMediaTime()

        // Get buffer size (CPU optimization temporarily disabled)
        let actualFrameCount = min(frameCount, bufferSize)
        // let actualFrameCount = cpuOptimizer.getOptimizedBufferSize(requestedSize: requestedFrameCount)

        // Clear output buffer
        outputBuffer.withUnsafeMutableBufferPointer { buffer in
            buffer.initialize(repeating: 0.0)
        }
        
        // Process all active voices
        var voicesToRemove: Set<Int> = []
        
        for voiceIndex in activeVoices {
            let voice = voices[voiceIndex]
            
            // Process voice samples
            for frame in 0..<actualFrameCount {
                let sample = voice.processSample()
                outputBuffer[frame] += sample
            }
            
            // Check if voice is still active
            if !voice.isActive {
                voicesToRemove.insert(voiceIndex)
            }
        }
        
        // Remove inactive voices
        for voiceIndex in voicesToRemove {
            activeVoices.remove(voiceIndex)
        }
        
        // Apply master volume
        let rawOutput = Array(outputBuffer[0..<actualFrameCount])
        let finalOutput = rawOutput.map { $0 * masterVolume }

        // Temporarily disabled output stage and CPU monitoring
        /*
        let finalOutput = outputStage.processAudio(input: rawOutput)

        // Measure and update CPU usage
        let endTime = CACurrentMediaTime()
        let processingTime = endTime - startTime
        let cpuUsage = processingTime / (Double(actualFrameCount) / sampleRate)
        cpuOptimizer.updateCPUUsage(cpuUsage)
        */

        return finalOutput
    }

    /// Process audio buffer with SIMD optimization
    public func processBufferOptimized(frameCount: Int) -> [Double] {
        let actualFrameCount = min(frameCount, bufferSize)

        // Only use optimization for larger buffer sizes
        if actualFrameCount < 4 {
            return processBuffer(frameCount: frameCount)
        }

        // Clear output buffer
        outputBuffer = Array(repeating: 0.0, count: actualFrameCount)

        // Process all active voices using vector processing
        var voicesToRemove: Set<Int> = []

        for voiceIndex in activeVoices {
            let voice = voices[voiceIndex]

            // Enable optimized DSP for this voice
            voice.setOptimizedDSP(true)

            // Process entire buffer at once using SIMD
            let voiceOutput = voice.processVector(sampleCount: actualFrameCount)

            // Add to output buffer using vDSP for better performance
            var voiceOutputFloat = voiceOutput.map { Float($0) }
            var outputBufferFloat = outputBuffer.map { Float($0) }
            var resultBuffer = Array<Float>(repeating: 0.0, count: actualFrameCount)

            vDSP_vadd(&outputBufferFloat, 1, &voiceOutputFloat, 1, &resultBuffer, 1, vDSP_Length(actualFrameCount))

            outputBuffer = resultBuffer.map { Double($0) }

            // Check if voice is still active
            if !voice.isActive {
                voicesToRemove.insert(voiceIndex)
            }
        }

        // Remove inactive voices
        for voiceIndex in voicesToRemove {
            activeVoices.remove(voiceIndex)
        }

        // Process through output stage (temporarily disabled - using pass-through)
        let rawOutput = Array(outputBuffer[0..<actualFrameCount])
        let finalOutput = rawOutput.map { $0 * masterVolume }

        return finalOutput
    }

    /// Enable or disable optimized processing for all voices
    public func setOptimizedProcessing(_ enabled: Bool) {
        for voice in voices {
            voice.setOptimizedDSP(enabled)
        }
    }

    // MARK: - Parameter Control
    
    public func setBodyTone(_ value: Double) {
        bodyTone = max(0.0, min(1.0, value))
        updateActiveVoices()
    }
    
    public func setNoiseLevel(_ value: Double) {
        noiseLevel = max(0.0, min(1.0, value))
        updateActiveVoices()
    }
    
    public func setPitchSweepAmount(_ value: Double) {
        pitchSweepAmount = max(0.0, min(1.0, value))
        updateActiveVoices()
    }
    
    public func setPitchSweepTime(_ value: Double) {
        pitchSweepTime = max(0.01, min(1.0, value))
        updateActiveVoices()
    }
    
    public func setWavefoldAmount(_ value: Double) {
        wavefoldAmount = max(0.0, min(1.0, value))
        updateActiveVoices()
    }
    
    public func setDrumType(_ type: DrumType) {
        drumType = type
        updateActiveVoices()
    }
    
    public func setMasterVolume(_ volume: Double) {
        masterVolume = max(0.0, min(1.0, volume))
    }
    
    private func updateActiveVoices() {
        // Update parameters for all active voices
        for voiceIndex in activeVoices {
            let voice = voices[voiceIndex]
            voice.updateParameters(
                bodyTone: bodyTone,
                noiseLevel: noiseLevel,
                pitchSweepAmount: pitchSweepAmount,
                pitchSweepTime: pitchSweepTime,
                wavefoldAmount: wavefoldAmount
            )
        }
    }
    
    // MARK: - Setup
    
    private func setupDefaultParameters() {
        // Set up default drum parameters
        bodyTone = 0.5
        noiseLevel = 0.3
        pitchSweepAmount = 0.4
        pitchSweepTime = 0.1
        wavefoldAmount = 0.2
        masterVolume = 0.8
    }
    
    // MARK: - Utility
    
    /// Get current active voice count
    public var activeVoiceCount: Int {
        return activeVoices.count
    }
    
    /// Stop all voices immediately
    public func allNotesOff() {
        for voiceIndex in activeVoices {
            voices[voiceIndex].noteOff()
        }
        activeVoices.removeAll()
    }

    /// Emergency stop all voices (immediate silence)
    public func stopAllVoices() {
        for voiceIndex in activeVoices {
            voices[voiceIndex].quickRelease()
        }
        activeVoices.removeAll()
    }

    // MARK: - Output Stage Access (temporarily disabled)

    /*
    /// Get the output stage for external configuration
    public func getOutputStage() -> FMDrumOutputStage {
        return outputStage
    }

    /// Configure output stage effects
    public func configureReverb(roomSize: Double, damping: Double, wetLevel: Double) {
        outputStage.configureReverb(roomSize: roomSize, damping: damping, wetLevel: wetLevel)
    }

    public func configureDistortion(type: DistortionType, amount: Double, tone: Double) {
        outputStage.configureDistortion(type: type, amount: amount, tone: tone)
    }

    public func configureCompressor(threshold: Double, ratio: Double, attack: Double, release: Double) {
        outputStage.configureCompressor(threshold: threshold, ratio: ratio, attack: attack, release: release)
    }

    /// Set output stage parameters
    public func setOutputGain(_ gain: Double) {
        outputStage.setOutputGain(gain)
    }

    public func setPanPosition(_ pan: Double) {
        outputStage.setPanPosition(pan)
    }

    public func setReverbSend(_ send: Double) {
        outputStage.setReverbSend(send)
    }

    public func setDistortionAmount(_ amount: Double) {
        outputStage.setDistortionAmount(amount)
    }

    public func setCompressionAmount(_ amount: Double) {
        outputStage.setCompressionAmount(amount)
    }

    /// Get output stage monitoring data
    public func getOutputPeakLevel() -> Double {
        return outputStage.getPeakLevel()
    }

    public func getOutputRMSLevel() -> Double {
        return outputStage.getRMSLevel()
    }

    public func getOutputCPUUsage() -> Double {
        return outputStage.getCPUUsage()
    }
    */

    // MARK: - CPU Optimization Access (temporarily disabled)

    /*
    /// Get the CPU optimizer for external configuration
    public func getCPUOptimizer() -> FMDrumCPUOptimizer {
        return cpuOptimizer
    }

    /// Get current CPU statistics
    public func getCPUStatistics() -> CPUStatistics {
        return cpuOptimizer.getCPUStatistics()
    }

    /// Set CPU optimization level
    public func setCPUOptimizationLevel(_ level: OptimizationLevel) {
        cpuOptimizer.setOptimizationLevel(level)
    }

    /// Enable or disable adaptive CPU optimization
    public func setAdaptiveCPUOptimization(_ enabled: Bool) {
        cpuOptimizer.setAdaptiveOptimization(enabled)
    }

    /// Set maximum active voices for CPU management
    public func setMaxActiveVoices(_ count: Int) {
        cpuOptimizer.setMaxActiveVoices(count)
    }

    /// Get current optimization level
    public func getCurrentOptimizationLevel() -> OptimizationLevel {
        return cpuOptimizer.getOptimizationLevel()
    }

    /// Measure real-time CPU usage
    public func measureRealTimeCPUUsage() -> Double {
        return cpuMeasurement.measureCPUUsage()
    }

    // MARK: - Modulation Matrix Access

    /// Get modulation matrix from the first voice
    public func getModulationMatrix() -> FMDrumModulationMatrix? {
        guard !voices.isEmpty else { return nil }
        return voices[0].getModulationMatrix()
    }

    /// Update MIDI modulation sources for all active voices
    public func updateMIDIModulation(
        pitchBend: Double = 0.0,
        modWheel: Double = 0.0,
        aftertouch: Double = 0.0
    ) {
        for voiceIndex in activeVoices {
            voices[voiceIndex].updateMIDIModulation(
                pitchBend: pitchBend,
                modWheel: modWheel,
                aftertouch: aftertouch
            )
        }
    }
    */

    // MARK: - Temporary Output Stage Methods (for compilation compatibility)
    
    /// Temporary placeholder methods for output stage functionality
    /// These will be properly implemented when output stage is enabled
    
    public func setOutputGain(_ gain: Double) {
        // Temporarily map to master volume
        masterVolume = max(0.0, min(1.0, gain))
    }

    public func setPanPosition(_ pan: Double) {
        // Placeholder - pan position not implemented yet
        // Will be implemented with proper output stage
    }

    public func setReverbSend(_ send: Double) {
        // Placeholder - reverb send not implemented yet
        // Will be implemented with proper output stage
    }

    public func setDistortionAmount(_ amount: Double) {
        // Placeholder - distortion amount not implemented yet
        // Will be implemented with proper output stage
    }

    public func setCompressionAmount(_ amount: Double) {
        // Placeholder - compression amount not implemented yet
        // Will be implemented with proper output stage
    }
}
