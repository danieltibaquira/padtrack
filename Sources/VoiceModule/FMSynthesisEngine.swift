// FMSynthesisEngine.swift
// DigitonePad - VoiceModule
//
// Main FM Synthesis Engine

import Foundation
import Accelerate
import MachineProtocols
import AudioEngine

// MARK: - FM Synthesis Engine

/// Main FM synthesis engine managing multiple voices
public final class FMSynthesisEngine: @unchecked Sendable {
    // Voice management
    private var voices: [FMVoice] = []
    private var activeVoices: Set<Int> = []
    private let maxPolyphony: Int
    
    // Engine properties
    private let sampleRate: Double
    private var currentAlgorithm: FMAlgorithm = FMAlgorithms.algorithm1
    
    // Global parameters
    public var masterVolume: Double = 1.0
    public var operatorRatios: [Double] = [1.0, 1.0, 1.0, 1.0]
    public var operatorLevels: [Double] = [1.0, 0.5, 0.3, 0.2]
    public var modulationIndices: [Double] = [0.0, 1.0, 1.0, 1.0]
    
    // Performance optimization
    private var outputBuffer: [Double] = []
    private let bufferSize: Int = 512
    
    public init(sampleRate: Double = 44100.0, maxPolyphony: Int = 8) {
        self.sampleRate = sampleRate
        self.maxPolyphony = maxPolyphony
        self.outputBuffer = [Double](repeating: 0.0, count: bufferSize)
        
        // Initialize voices
        for _ in 0..<maxPolyphony {
            voices.append(FMVoice(sampleRate: sampleRate))
        }
        
        setupDefaultParameters()
    }
    
    // MARK: - Voice Management
    
    /// Start a note
    public func noteOn(note: UInt8, velocity: UInt8) -> Bool {
        // Find available voice
        guard let voiceIndex = findAvailableVoice() else {
            // Voice stealing if no available voice
            guard let stolenVoice = stealVoice() else { return false }
            return startVoice(index: stolenVoice, note: note, velocity: velocity)
        }
        
        return startVoice(index: voiceIndex, note: note, velocity: velocity)
    }
    
    /// Stop a note
    public func noteOff(note: UInt8) {
        // Find active voice with this note
        for voiceIndex in activeVoices {
            if voices[voiceIndex].note == note {
                voices[voiceIndex].noteOff()
                activeVoices.remove(voiceIndex)
                break
            }
        }
    }
    
    /// Stop all notes
    public func allNotesOff() {
        for voiceIndex in activeVoices {
            voices[voiceIndex].noteOff()
        }
        activeVoices.removeAll()
    }
    
    // MARK: - Audio Processing
    
    /// Process a buffer of audio samples
    public func processBuffer(frameCount: Int) -> [Double] {
        guard frameCount <= bufferSize else {
            // Handle larger buffers by processing in chunks
            var result: [Double] = []
            var remaining = frameCount
            var offset = 0
            
            while remaining > 0 {
                let chunkSize = min(remaining, bufferSize)
                let chunk = processBuffer(frameCount: chunkSize)
                result.append(contentsOf: chunk)
                remaining -= chunkSize
                offset += chunkSize
            }
            return result
        }
        
        // Clear output buffer
        for i in 0..<frameCount {
            outputBuffer[i] = 0.0
        }
        
        // Process each active voice
        for voiceIndex in activeVoices {
            let voice = voices[voiceIndex]
            
            for i in 0..<frameCount {
                outputBuffer[i] += voice.processSample()
            }
        }
        
        // Apply master volume
        if masterVolume != 1.0 {
            vDSP_vsmulD(outputBuffer, 1, &masterVolume, &outputBuffer, 1, vDSP_Length(frameCount))
        }
        
        return Array(outputBuffer[0..<frameCount])
    }
    
    /// Process a single sample (for real-time processing)
    public func processSample() -> Double {
        var output: Double = 0.0
        
        // Sum all active voices
        for voiceIndex in activeVoices {
            output += voices[voiceIndex].processSample()
        }
        
        return output * masterVolume
    }
    
    // MARK: - Parameter Control
    
    /// Set the FM algorithm
    public func setAlgorithm(_ algorithm: FMAlgorithm) {
        currentAlgorithm = algorithm
        
        // Update all voices with new algorithm
        for voice in voices {
            voice.algorithm = algorithm
        }
    }
    
    /// Set operator frequency ratios
    public func setOperatorRatios(_ ratios: [Double]) {
        guard ratios.count == 4 else { return }
        operatorRatios = ratios
        
        // Update all voices
        for voice in voices {
            voice.operatorRatios = ratios
        }
    }
    
    /// Set operator output levels
    public func setOperatorLevels(_ levels: [Double]) {
        guard levels.count == 4 else { return }
        operatorLevels = levels
        
        // Update all voices
        for voice in voices {
            voice.operatorLevels = levels
        }
    }
    
    /// Set modulation indices for operators
    public func setModulationIndices(_ indices: [Double]) {
        guard indices.count == 4 else { return }
        modulationIndices = indices
        
        // Update operator modulation indices
        for voice in voices {
            for (index, fmOperator) in voice.operators.enumerated() {
                if index < indices.count {
                    fmOperator.modulationIndex = indices[index]
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func findAvailableVoice() -> Int? {
        for i in 0..<maxPolyphony {
            if !activeVoices.contains(i) {
                return i
            }
        }
        return nil
    }
    
    private func stealVoice() -> Int? {
        // Simple voice stealing: steal the oldest voice
        // TODO: Implement more sophisticated voice stealing algorithms
        return activeVoices.first
    }
    
    private func startVoice(index: Int, note: UInt8, velocity: UInt8) -> Bool {
        guard index < voices.count else { return false }
        
        let voice = voices[index]
        voice.algorithm = currentAlgorithm
        voice.operatorRatios = operatorRatios
        voice.operatorLevels = operatorLevels
        
        // Set modulation indices
        for (opIndex, fmOperator) in voice.operators.enumerated() {
            if opIndex < modulationIndices.count {
                fmOperator.modulationIndex = modulationIndices[opIndex]
            }
        }
        
        voice.noteOn(note: note, velocity: velocity)
        activeVoices.insert(index)
        
        return true
    }
    
    private func setupDefaultParameters() {
        // Set up default FM parameters for classic FM sounds
        operatorRatios = [1.0, 2.0, 3.0, 4.0]  // Harmonic ratios
        operatorLevels = [1.0, 0.8, 0.6, 0.4]  // Decreasing levels
        modulationIndices = [0.0, 2.0, 1.5, 1.0]  // Modulation amounts
    }
    
    // MARK: - Engine Control
    
    /// Reset the engine
    public func reset() {
        allNotesOff()
        
        for voice in voices {
            voice.reset()
        }
        
        setupDefaultParameters()
    }
    
    /// Get current polyphony usage
    public var polyphonyUsage: Int {
        return activeVoices.count
    }
    
    /// Check if engine is active
    public var isActive: Bool {
        return !activeVoices.isEmpty
    }
}


