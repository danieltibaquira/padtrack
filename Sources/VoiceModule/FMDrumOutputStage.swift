//
//  FMDrumOutputStage.swift
//  DigitonePad - VoiceModule
//
//  Final audio output stage for FM DRUM voice machine with mixing and effects
//

import Foundation
import CoreAudio
import AudioEngine
import MachineProtocols
import QuartzCore

/// Final output stage for FM DRUM voice machine with mixing and effects
public final class FMDrumOutputStage: @unchecked Sendable {
    // Audio processing components
    private let sampleRate: Double
    private let bufferSize: Int
    
    // Mixing components
    private var masterVolume: Double = 0.8
    private var outputGain: Double = 1.0
    private var panPosition: Double = 0.0  // -1.0 (left) to 1.0 (right)
    
    // Built-in effects
    private var distortion: DrumDistortion
    private var reverb: DrumReverb
    private var compressor: DrumCompressor
    
    // Effect sends
    private var reverbSend: Double = 0.0
    private var distortionAmount: Double = 0.0
    private var compressionAmount: Double = 0.0
    
    // Output routing
    private var outputRouting: OutputRouting = .stereo
    private var channelMapping: [Int] = [0, 1] // Default stereo mapping
    
    // Performance monitoring
    private var cpuUsage: Double = 0.0
    private var peakLevel: Double = 0.0
    private var rmsLevel: Double = 0.0
    
    // Output buffers
    private var stereoBuffer: [Double] = []
    private var monoBuffer: [Double] = []
    
    public init(sampleRate: Double = 44100.0, bufferSize: Int = 512) {
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
        
        // Initialize effects
        self.distortion = DrumDistortion(sampleRate: sampleRate)
        self.reverb = DrumReverb(sampleRate: sampleRate)
        self.compressor = DrumCompressor(sampleRate: sampleRate)
        
        // Initialize buffers
        self.stereoBuffer = Array(repeating: 0.0, count: bufferSize * 2)
        self.monoBuffer = Array(repeating: 0.0, count: bufferSize)
        
        setupDefaultSettings()
    }
    
    // MARK: - Audio Processing
    
    /// Process drum audio through the output stage
    public func processAudio(input: [Double]) -> [Double] {
        let startTime = CACurrentMediaTime()
        
        // Ensure input size matches buffer size
        let frameCount = min(input.count, bufferSize)
        var processedAudio = Array(input.prefix(frameCount))
        
        // Apply master volume
        applyMasterVolume(&processedAudio)
        
        // Apply compression if enabled
        if compressionAmount > 0.0 {
            processedAudio = compressor.process(input: processedAudio, amount: compressionAmount)
        }
        
        // Apply distortion if enabled
        if distortionAmount > 0.0 {
            processedAudio = distortion.process(input: processedAudio, amount: distortionAmount)
        }
        
        // Apply reverb if enabled
        if reverbSend > 0.0 {
            processedAudio = reverb.process(input: processedAudio, wetLevel: reverbSend)
        }
        
        // Apply output gain
        applyOutputGain(&processedAudio)
        
        // Update metering
        updateMetering(processedAudio)
        
        // Route to output format
        let finalOutput = routeToOutput(processedAudio)
        
        // Update CPU usage
        let endTime = CACurrentMediaTime()
        cpuUsage = (endTime - startTime) * 1000.0 // Convert to milliseconds
        
        return finalOutput
    }
    
    // MARK: - Audio Processing Helpers
    
    private func applyMasterVolume(_ audio: inout [Double]) {
        if masterVolume != 1.0 {
            for i in 0..<audio.count {
                audio[i] *= masterVolume
            }
        }
    }
    
    private func applyOutputGain(_ audio: inout [Double]) {
        if outputGain != 1.0 {
            for i in 0..<audio.count {
                audio[i] *= outputGain
            }
        }
    }
    
    private func routeToOutput(_ monoInput: [Double]) -> [Double] {
        switch outputRouting {
        case .mono:
            return monoInput
            
        case .stereo:
            return createStereoOutput(from: monoInput)
            
        case .multiChannel:
            return createMultiChannelOutput(from: monoInput)
        }
    }
    
    private func createStereoOutput(from monoInput: [Double]) -> [Double] {
        let frameCount = monoInput.count
        stereoBuffer = Array(repeating: 0.0, count: frameCount * 2)
        
        // Calculate pan gains
        let leftGain = cos((panPosition + 1.0) * .pi / 4.0)
        let rightGain = sin((panPosition + 1.0) * .pi / 4.0)
        
        for frame in 0..<frameCount {
            let sample = monoInput[frame]
            stereoBuffer[frame * 2] = sample * leftGain      // Left channel
            stereoBuffer[frame * 2 + 1] = sample * rightGain // Right channel
        }
        
        return stereoBuffer
    }
    
    private func createMultiChannelOutput(from monoInput: [Double]) -> [Double] {
        let frameCount = monoInput.count
        let channelCount = channelMapping.count
        var multiChannelBuffer = Array(repeating: 0.0, count: frameCount * channelCount)
        
        for frame in 0..<frameCount {
            let sample = monoInput[frame]
            for (channelIndex, outputChannel) in channelMapping.enumerated() {
                if outputChannel >= 0 && outputChannel < channelCount {
                    multiChannelBuffer[frame * channelCount + channelIndex] = sample
                }
            }
        }
        
        return multiChannelBuffer
    }
    
    // MARK: - Metering
    
    private func updateMetering(_ audio: [Double]) {
        var peak: Double = 0.0
        var rmsSum: Double = 0.0
        
        for sample in audio {
            let absSample = abs(sample)
            peak = max(peak, absSample)
            rmsSum += sample * sample
        }
        
        peakLevel = peak
        rmsLevel = sqrt(rmsSum / Double(audio.count))
    }
    
    // MARK: - Parameter Control
    
    public func setMasterVolume(_ volume: Double) {
        masterVolume = max(0.0, min(2.0, volume))
    }
    
    public func setOutputGain(_ gain: Double) {
        outputGain = max(0.0, min(2.0, gain))
    }
    
    public func setPanPosition(_ pan: Double) {
        panPosition = max(-1.0, min(1.0, pan))
    }
    
    public func setReverbSend(_ send: Double) {
        reverbSend = max(0.0, min(1.0, send))
        reverb.setWetLevel(send)
    }
    
    public func setDistortionAmount(_ amount: Double) {
        distortionAmount = max(0.0, min(1.0, amount))
        distortion.setAmount(amount)
    }
    
    public func setCompressionAmount(_ amount: Double) {
        compressionAmount = max(0.0, min(1.0, amount))
        compressor.setAmount(amount)
    }
    
    public func setOutputRouting(_ routing: OutputRouting) {
        outputRouting = routing
    }
    
    public func setChannelMapping(_ mapping: [Int]) {
        channelMapping = mapping
    }
    
    // MARK: - Effect Configuration
    
    public func configureReverb(roomSize: Double, damping: Double, wetLevel: Double) {
        reverb.configure(roomSize: roomSize, damping: damping, wetLevel: wetLevel)
    }
    
    public func configureDistortion(type: DistortionType, amount: Double, tone: Double) {
        distortion.configure(type: type, amount: amount, tone: tone)
    }
    
    public func configureCompressor(threshold: Double, ratio: Double, attack: Double, release: Double) {
        compressor.configure(threshold: threshold, ratio: ratio, attack: attack, release: release)
    }
    
    // MARK: - Monitoring
    
    public func getPeakLevel() -> Double {
        return peakLevel
    }
    
    public func getRMSLevel() -> Double {
        return rmsLevel
    }
    
    public func getCPUUsage() -> Double {
        return cpuUsage
    }
    
    // MARK: - Setup
    
    private func setupDefaultSettings() {
        // Configure reverb for drums
        reverb.configure(roomSize: 0.3, damping: 0.7, wetLevel: 0.0)
        
        // Configure distortion for drums
        distortion.configure(type: .tube, amount: 0.0, tone: 0.5)
        
        // Configure compressor for drums
        compressor.configure(threshold: 0.7, ratio: 4.0, attack: 0.001, release: 0.1)
    }
}

// MARK: - Output Routing Types

public enum OutputRouting {
    case mono
    case stereo
    case multiChannel
}

// MARK: - Drum-Specific Effects

/// Simple distortion effect optimized for drums
private final class DrumDistortion: @unchecked Sendable {
    private let sampleRate: Double
    private var type: DistortionType = .tube
    private var amount: Double = 0.0
    private var tone: Double = 0.5
    
    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }
    
    func process(input: [Double], amount: Double) -> [Double] {
        guard amount > 0.0 else { return input }
        
        return input.map { sample in
            switch type {
            case .tube:
                return tanhDistortion(sample, amount: amount)
            case .hard:
                return hardClipping(sample, amount: amount)
            case .soft:
                return softClipping(sample, amount: amount)
            }
        }
    }
    
    func configure(type: DistortionType, amount: Double, tone: Double) {
        self.type = type
        self.amount = amount
        self.tone = tone
    }
    
    func setAmount(_ amount: Double) {
        self.amount = max(0.0, min(1.0, amount))
    }
    
    private func tanhDistortion(_ sample: Double, amount: Double) -> Double {
        let drive = 1.0 + amount * 9.0 // 1x to 10x drive
        return tanh(sample * drive) / drive
    }
    
    private func hardClipping(_ sample: Double, amount: Double) -> Double {
        let threshold = 1.0 - amount * 0.8 // Reduce threshold with amount
        return max(-threshold, min(threshold, sample))
    }
    
    private func softClipping(_ sample: Double, amount: Double) -> Double {
        let drive = 1.0 + amount * 4.0
        let driven = sample * drive
        return driven / (1.0 + abs(driven)) / drive
    }
}

public enum DistortionType {
    case tube
    case hard
    case soft
}

/// Simple reverb effect optimized for drums
private final class DrumReverb: @unchecked Sendable {
    private let sampleRate: Double
    private var roomSize: Double = 0.3
    private var damping: Double = 0.7
    private var wetLevel: Double = 0.0
    
    // Simple delay lines for reverb
    private var delayLines: [SimpleDelayLine] = []
    
    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        setupDelayLines()
    }
    
    func process(input: [Double], wetLevel: Double) -> [Double] {
        guard wetLevel > 0.0 else { return input }
        
        return input.enumerated().map { index, sample in
            var reverbSample: Double = 0.0
            
            // Process through delay lines
            for delayLine in delayLines {
                reverbSample += delayLine.process(sample) * 0.25
            }
            
            // Mix wet and dry
            return sample * (1.0 - wetLevel) + reverbSample * wetLevel
        }
    }
    
    func configure(roomSize: Double, damping: Double, wetLevel: Double) {
        self.roomSize = roomSize
        self.damping = damping
        self.wetLevel = wetLevel
    }
    
    func setWetLevel(_ level: Double) {
        wetLevel = max(0.0, min(1.0, level))
    }
    
    private func setupDelayLines() {
        // Create simple delay lines for reverb
        let delayTimes = [0.03, 0.05, 0.07, 0.09] // Different delay times in seconds
        
        for delayTime in delayTimes {
            let delayLine = SimpleDelayLine(sampleRate: sampleRate, delayTime: delayTime)
            delayLines.append(delayLine)
        }
    }
}

/// Simple compressor effect optimized for drums
private final class DrumCompressor: @unchecked Sendable {
    private let sampleRate: Double
    private var threshold: Double = 0.7
    private var ratio: Double = 4.0
    private var attack: Double = 0.001
    private var release: Double = 0.1
    private var envelope: Double = 0.0
    
    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }
    
    func process(input: [Double], amount: Double) -> [Double] {
        guard amount > 0.0 else { return input }
        
        return input.map { sample in
            let inputLevel = abs(sample)
            
            // Calculate target envelope
            let targetEnvelope = inputLevel > threshold ? 
                threshold + (inputLevel - threshold) / ratio : inputLevel
            
            // Smooth envelope following
            let attackCoeff = exp(-1.0 / (attack * sampleRate))
            let releaseCoeff = exp(-1.0 / (release * sampleRate))
            
            if targetEnvelope > envelope {
                envelope = targetEnvelope + (envelope - targetEnvelope) * attackCoeff
            } else {
                envelope = targetEnvelope + (envelope - targetEnvelope) * releaseCoeff
            }
            
            // Apply compression
            let gain = inputLevel > 0.0 ? envelope / inputLevel : 1.0
            let compressedSample = sample * gain
            
            // Mix compressed and dry signal based on amount
            return sample * (1.0 - amount) + compressedSample * amount
        }
    }
    
    func configure(threshold: Double, ratio: Double, attack: Double, release: Double) {
        self.threshold = threshold
        self.ratio = ratio
        self.attack = attack
        self.release = release
    }
    
    func setAmount(_ amount: Double) {
        // Amount is handled in the process function
    }
}

/// Simple delay line for reverb
private final class SimpleDelayLine: @unchecked Sendable {
    private var buffer: [Double]
    private var writeIndex: Int = 0
    private let delayInSamples: Int
    private let feedback: Double = 0.3
    
    init(sampleRate: Double, delayTime: Double) {
        self.delayInSamples = Int(delayTime * sampleRate)
        self.buffer = Array(repeating: 0.0, count: delayInSamples)
    }
    
    func process(_ input: Double) -> Double {
        let readIndex = (writeIndex - delayInSamples + buffer.count) % buffer.count
        let output = buffer[readIndex]
        
        buffer[writeIndex] = input + output * feedback
        writeIndex = (writeIndex + 1) % buffer.count
        
        return output
    }
}
