// DrumComponents.swift
// DigitonePad - VoiceModule
//
// Supporting components for FM drum synthesis

import Foundation
import Accelerate

// MARK: - Noise Generator

/// Flexible noise generator for drum transients
public final class NoiseGenerator: @unchecked Sendable {
    private var level: Double = 1.0
    private var noiseType: NoiseType = .white
    private var pinkFilter: PinkNoiseFilter
    
    public init() {
        self.pinkFilter = PinkNoiseFilter()
    }
    
    public func processSample() -> Double {
        let whiteSample = Double.random(in: -1.0...1.0)
        
        switch noiseType {
        case .white:
            return whiteSample * level
        case .pink:
            return pinkFilter.process(whiteSample) * level
        case .brown:
            return pinkFilter.processBrown(whiteSample) * level
        }
    }
    
    public func setLevel(_ level: Double) {
        self.level = max(0.0, min(1.0, level))
    }
    
    public func setNoiseType(_ type: NoiseType) {
        self.noiseType = type
    }
}

public enum NoiseType {
    case white
    case pink
    case brown
}

// MARK: - Pink Noise Filter

/// Simple pink noise filter using pole-zero approximation
private final class PinkNoiseFilter: @unchecked Sendable {
    private var b0: Double = 0.0
    private var b1: Double = 0.0
    private var b2: Double = 0.0
    private var b3: Double = 0.0
    private var b4: Double = 0.0
    private var b5: Double = 0.0
    private var b6: Double = 0.0
    
    // Brown noise state
    private var brownState: Double = 0.0
    
    func process(_ input: Double) -> Double {
        b0 = 0.99886 * b0 + input * 0.0555179
        b1 = 0.99332 * b1 + input * 0.0750759
        b2 = 0.96900 * b2 + input * 0.1538520
        b3 = 0.86650 * b3 + input * 0.3104856
        b4 = 0.55000 * b4 + input * 0.5329522
        b5 = -0.7616 * b5 - input * 0.0168980
        
        let output = b0 + b1 + b2 + b3 + b4 + b5 + b6 + input * 0.5362
        b6 = input * 0.115926
        
        return output * 0.11
    }
    
    func processBrown(_ input: Double) -> Double {
        brownState += input * 0.02
        brownState = max(-1.0, min(1.0, brownState))
        return brownState
    }
}

// MARK: - Bandpass Filter

/// Simple bandpass filter for noise shaping
public final class BandpassFilter: @unchecked Sendable {
    private let sampleRate: Double
    private var frequency: Double = 1000.0
    private var resonance: Double = 0.5
    private var x1: Double = 0.0
    private var x2: Double = 0.0
    private var y1: Double = 0.0
    private var y2: Double = 0.0
    
    // Filter coefficients
    private var a0: Double = 1.0
    private var a1: Double = 0.0
    private var a2: Double = 0.0
    private var b1: Double = 0.0
    private var b2: Double = 0.0
    
    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
        updateCoefficients()
    }
    
    public func process(input: Double, cutoffMod: Double = 0.0) -> Double {
        // Apply cutoff modulation
        let modFreq = frequency * (1.0 + cutoffMod * 2.0)
        if abs(modFreq - frequency) > 1.0 {
            frequency = max(20.0, min(sampleRate * 0.45, modFreq))
            updateCoefficients()
        }
        
        // Process sample
        let output = a0 * input + a1 * x1 + a2 * x2 - b1 * y1 - b2 * y2
        
        // Update delay lines
        x2 = x1
        x1 = input
        y2 = y1
        y1 = output
        
        return output
    }
    
    public func setCutoff(frequency: Double, resonance: Double) {
        self.frequency = max(20.0, min(sampleRate * 0.45, frequency))
        self.resonance = max(0.1, min(10.0, resonance))
        updateCoefficients()
    }
    
    private func updateCoefficients() {
        let omega = 2.0 * Double.pi * frequency / sampleRate
        let alpha = sin(omega) / (2.0 * resonance)
        
        let cosOmega = cos(omega)
        
        // Bandpass coefficients
        a0 = alpha
        a1 = 0.0
        a2 = -alpha
        b1 = -2.0 * cosOmega
        b2 = 1.0 - alpha
        
        // Normalize
        let norm = 1.0 / (1.0 + alpha)
        a0 *= norm
        a1 *= norm
        a2 *= norm
        b1 *= norm
        b2 *= norm
    }
}

// MARK: - Pitch Envelope

/// Specialized envelope for pitch sweeps
public final class PitchEnvelope: @unchecked Sendable {
    private let sampleRate: Double
    private var startPitch: Double = 1.0
    private var endPitch: Double = 0.0
    private var decayTime: Double = 0.1
    private var currentValue: Double = 0.0
    private var phase: Double = 0.0
    private var isActive: Bool = false
    private var decayRate: Double = 0.0
    
    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
        calculateDecayRate()
    }
    
    public func trigger() {
        isActive = true
        phase = 0.0
        currentValue = startPitch
        calculateDecayRate()
    }
    
    public func processSample() -> Double {
        guard isActive else { return 0.0 }
        
        if phase >= 1.0 {
            isActive = false
            currentValue = endPitch
            return currentValue
        }
        
        // Exponential decay curve
        let curve = exp(-phase * 5.0)  // Exponential curve
        currentValue = endPitch + (startPitch - endPitch) * curve
        
        phase += decayRate
        
        return currentValue
    }
    
    public func configure(startPitch: Double, endPitch: Double, decayTime: Double) {
        self.startPitch = startPitch
        self.endPitch = endPitch
        self.decayTime = max(0.001, decayTime)
        calculateDecayRate()
    }
    
    public func setDecayTime(_ time: Double) {
        self.decayTime = max(0.001, time)
        calculateDecayRate()
    }
    
    private func calculateDecayRate() {
        decayRate = 1.0 / (decayTime * sampleRate)
    }
}

// MARK: - Wave Folder

/// Wavefolding distortion for complex harmonics
public final class WaveFolder: @unchecked Sendable {
    private var threshold: Double = 0.7
    
    public func process(input: Double, amount: Double) -> Double {
        guard amount > 0.0 else { return input }
        
        let scaledInput = input * (1.0 + amount * 3.0)
        
        // Simple wavefolding algorithm
        var output = scaledInput
        
        while abs(output) > threshold {
            if output > threshold {
                output = 2.0 * threshold - output
            } else if output < -threshold {
                output = -2.0 * threshold - output
            }
        }
        
        // Apply soft clipping to smooth the result
        output = tanh(output * 0.8)
        
        return output * (1.0 - amount * 0.3)  // Compensate for level increase
    }
    
    public func setThreshold(_ threshold: Double) {
        self.threshold = max(0.1, min(1.0, threshold))
    }
}

// MARK: - Drum ADSR

private enum DrumEnvelopePhase {
    case idle
    case attack
    case decay
    case sustain
    case release
}

/// Specialized ADSR envelope for drum components
public final class DrumADSR: @unchecked Sendable {
    public enum EnvelopeType {
        case amplitude
        case noise
        case filter
    }
    
    private let sampleRate: Double
    private let type: EnvelopeType
    
    // ADSR parameters
    private var attackTime: Double = 0.001
    private var decayTime: Double = 0.1
    private var sustainLevel: Double = 0.0
    private var releaseTime: Double = 0.05
    
    // State
    private var phase: DrumEnvelopePhase = .idle
    private var currentLevel: Double = 0.0
    private var targetLevel: Double = 0.0
    private var rate: Double = 0.0
    private var velocity: Double = 1.0
    
    public var isFinished: Bool {
        return phase == .idle && currentLevel <= 0.001
    }
    
    public init(sampleRate: Double, type: EnvelopeType) {
        self.sampleRate = sampleRate
        self.type = type
    }
    
    public func noteOn(velocity: UInt8) {
        self.velocity = Double(velocity) / 127.0
        phase = .attack
        targetLevel = self.velocity
        rate = targetLevel / (attackTime * sampleRate)
    }
    
    public func noteOff() {
        phase = .release
        targetLevel = 0.0
        rate = -currentLevel / (releaseTime * sampleRate)
    }
    
    public func quickRelease() {
        phase = .release
        targetLevel = 0.0
        rate = -currentLevel / (0.01 * sampleRate)  // Quick 10ms release
    }
    
    public func processSample() -> Double {
        switch phase {
        case .idle:
            return 0.0
            
        case .attack:
            currentLevel += rate
            if currentLevel >= targetLevel {
                currentLevel = targetLevel
                phase = .decay
                targetLevel = sustainLevel * velocity
                rate = (targetLevel - currentLevel) / (decayTime * sampleRate)
            }
            
        case .decay:
            currentLevel += rate
            if currentLevel <= targetLevel {
                currentLevel = targetLevel
                phase = .sustain
            }
            
        case .sustain:
            currentLevel = targetLevel
            // For drums, sustain is usually 0, so move to release immediately
            if sustainLevel <= 0.001 {
                phase = .release
                targetLevel = 0.0
                rate = -currentLevel / (releaseTime * sampleRate)
            }
            
        case .release:
            currentLevel += rate
            if currentLevel <= 0.001 {
                currentLevel = 0.0
                phase = .idle
            }
        }
        
        return max(0.0, currentLevel)
    }
    
    public func setTimes(attack: Double, decay: Double, sustain: Double, release: Double) {
        self.attackTime = max(0.001, attack)
        self.decayTime = max(0.001, decay)
        self.sustainLevel = max(0.0, min(1.0, sustain))
        self.releaseTime = max(0.001, release)
    }
}
