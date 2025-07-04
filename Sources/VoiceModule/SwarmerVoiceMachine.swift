// SwarmerVoiceMachine.swift
// DigitonePad - VoiceModule
//
// SWARMER Voice Machine with unison-based swarm synthesis
// Features one main oscillator and six detuned swarm oscillators for rich, thick sounds

import Foundation
import Accelerate
import MachineProtocols
import AudioEngine

// MARK: - Waveform Types

/// Basic waveforms for SWARMER oscillators
public enum SwarmerWaveform: String, CaseIterable, Codable {
    case sine = "sine"
    case triangle = "triangle"
    case sawtooth = "sawtooth"
    case square = "square"
    case pulse = "pulse"
    case noise = "noise"
    
    public var description: String {
        switch self {
        case .sine: return "Sine"
        case .triangle: return "Triangle"
        case .sawtooth: return "Sawtooth"
        case .square: return "Square"
        case .pulse: return "Pulse"
        case .noise: return "Noise"
        }
    }
}

// MARK: - Swarm Oscillator

/// Individual oscillator in the swarm with detuning and animation
public final class SwarmOscillator: @unchecked Sendable {
    
    // MARK: - Properties
    
    public var frequency: Double = 440.0
    public var waveform: SwarmerWaveform = .sawtooth
    public var amplitude: Float = 1.0
    public var detuneAmount: Float = 0.0  // In cents
    public var animationAmount: Float = 0.0
    public var pulseWidth: Float = 0.5  // For pulse wave
    
    // Internal state
    private var phase: Double = 0.0
    private var phaseIncrement: Double = 0.0
    private let sampleRate: Double
    
    // Animation LFO
    private var animationPhase: Double = 0.0
    private var animationRate: Float = 2.0  // Hz
    private var animationPhaseOffset: Float = 0.0
    
    // Noise state for noise waveform
    private var noiseValue: Float = 0.0
    private var noiseSampleCounter: Int = 0
    
    // MARK: - Initialization
    
    public init(sampleRate: Double = 44100.0, animationPhaseOffset: Float = 0.0) {
        self.sampleRate = sampleRate
        self.animationPhaseOffset = animationPhaseOffset
        updatePhaseIncrement()
    }
    
    // MARK: - Parameter Updates
    
    public func setFrequency(_ frequency: Double) {
        self.frequency = frequency
        updatePhaseIncrement()
    }
    
    public func setDetune(_ cents: Float) {
        self.detuneAmount = cents
        updatePhaseIncrement()
    }
    
    public func setAnimation(_ amount: Float, rate: Float = 2.0) {
        self.animationAmount = amount
        self.animationRate = rate
    }
    
    // MARK: - Audio Processing
    
    public func processSample() -> Float {
        // Update animation LFO
        updateAnimation()
        
        // Calculate current frequency with detune and animation
        let detuneMultiplier = pow(2.0, Double(detuneAmount) / 1200.0)  // Convert cents to frequency ratio
        let animationModulation = sin(animationPhase + Double(animationPhaseOffset)) * Double(animationAmount * 0.1)
        let currentFrequency = frequency * detuneMultiplier * (1.0 + animationModulation)
        
        // Update phase increment
        let currentPhaseIncrement = currentFrequency / sampleRate
        
        // Generate waveform
        let sample = generateWaveform()
        
        // Advance phase
        phase += currentPhaseIncrement * 2.0 * Double.pi
        while phase >= 2.0 * Double.pi {
            phase -= 2.0 * Double.pi
        }
        
        return sample * amplitude
    }
    
    // MARK: - Private Methods
    
    private func updatePhaseIncrement() {
        let detuneMultiplier = pow(2.0, Double(detuneAmount) / 1200.0)
        phaseIncrement = frequency * detuneMultiplier / sampleRate
    }
    
    private func updateAnimation() {
        let animationIncrement = Double(animationRate) / sampleRate * 2.0 * Double.pi
        animationPhase += animationIncrement
        while animationPhase >= 2.0 * Double.pi {
            animationPhase -= 2.0 * Double.pi
        }
    }
    
    private func generateWaveform() -> Float {
        let normalizedPhase = phase / (2.0 * Double.pi)
        
        switch waveform {
        case .sine:
            return Float(sin(phase))
            
        case .triangle:
            if normalizedPhase < 0.5 {
                return Float(4.0 * normalizedPhase - 1.0)
            } else {
                return Float(3.0 - 4.0 * normalizedPhase)
            }
            
        case .sawtooth:
            return Float(2.0 * normalizedPhase - 1.0)
            
        case .square:
            return normalizedPhase < 0.5 ? -1.0 : 1.0
            
        case .pulse:
            return normalizedPhase < Double(pulseWidth) ? -1.0 : 1.0
            
        case .noise:
            // Sample and hold noise
            noiseSampleCounter += 1
            if noiseSampleCounter >= Int(sampleRate / frequency / 4.0) {
                noiseValue = Float.random(in: -1.0...1.0)
                noiseSampleCounter = 0
            }
            return noiseValue
        }
    }
    
    public func reset() {
        phase = 0.0
        animationPhase = Double(animationPhaseOffset)
        noiseValue = 0.0
        noiseSampleCounter = 0
    }
}

// MARK: - SWARMER Voice Machine

/// Complete SWARMER Voice Machine with main oscillator and swarm
public final class SwarmerVoiceMachine: VoiceMachine, @unchecked Sendable {
    
    // MARK: - Core Components
    
    /// Main oscillator
    private var mainOscillator: SwarmOscillator
    
    /// Six swarm oscillators
    private var swarmOscillators: [SwarmOscillator] = []
    
    /// Envelope system for amplitude control
    private var envelopeSystem: WavetoneEnvelopeSystem
    
    // MARK: - Voice State
    
    private var currentNote: UInt8 = 60
    private var currentVelocity: UInt8 = 100
    private var isNoteActive: Bool = false
    
    // MARK: - Audio Processing
    
    private let sampleRate: Double
    private var outputBuffer: [Float] = []
    private var tempBuffer: [Float] = []
    
    // MARK: - Initialization
    
    public override init(name: String = "SWARMER", polyphony: Int = 16) {
        self.sampleRate = 44100.0
        
        // Initialize main oscillator
        self.mainOscillator = SwarmOscillator(sampleRate: sampleRate)
        
        // Initialize swarm oscillators with phase offsets for stereo spread
        for i in 0..<6 {
            let phaseOffset = Float(i) * Float.pi / 3.0  // 60° phase offset between oscillators
            let swarmOsc = SwarmOscillator(sampleRate: sampleRate, animationPhaseOffset: phaseOffset)
            swarmOscillators.append(swarmOsc)
        }
        
        // Initialize envelope system
        self.envelopeSystem = WavetoneEnvelopeSystem()
        
        super.init(name: name, polyphony: polyphony)
        
        setupSwarmerParameters()
        setupDefaultSettings()
        
        // Initialize buffers
        outputBuffer = [Float](repeating: 0.0, count: 1024)
        tempBuffer = [Float](repeating: 0.0, count: 1024)
    }
    
    // MARK: - VoiceMachine Protocol Implementation
    
    public override func noteOn(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?) {
        currentNote = note
        currentVelocity = velocity
        isNoteActive = true
        
        // Calculate frequency from MIDI note
        let frequency = 440.0 * pow(2.0, Double(Int(note) - 69) / 12.0)
        
        // Set main oscillator frequency
        mainOscillator.setFrequency(frequency)
        
        // Set swarm oscillator frequencies
        for swarmOsc in swarmOscillators {
            swarmOsc.setFrequency(frequency)
        }
        
        // Apply velocity sensitivity
        let velocityScale = Float(velocity) / 127.0
        mainOscillator.amplitude = velocityScale
        for swarmOsc in swarmOscillators {
            swarmOsc.amplitude = velocityScale
        }
        
        // Trigger envelopes
        envelopeSystem.trigger(velocity: velocityScale, noteNumber: note)
        
        super.noteOn(note: note, velocity: velocity, channel: channel, timestamp: timestamp)
    }
    
    public override func noteOff(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?) {
        if note == currentNote {
            isNoteActive = false
            envelopeSystem.release()
        }
        
        super.noteOff(note: note, velocity: velocity, channel: channel, timestamp: timestamp)
    }
    
    public override func allNotesOff() {
        isNoteActive = false
        mainOscillator.reset()
        for swarmOsc in swarmOscillators {
            swarmOsc.reset()
        }
        envelopeSystem.reset()
        
        super.allNotesOff()
    }
    
    public override func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        let frameCount = input.frameCount
        let channelCount = input.channelCount
        
        // Ensure output buffer is large enough
        if outputBuffer.count < frameCount * channelCount {
            outputBuffer = [Float](repeating: 0.0, count: frameCount * channelCount)
            tempBuffer = [Float](repeating: 0.0, count: frameCount)
        }
        
        // Clear output buffer
        for i in 0..<frameCount * channelCount {
            outputBuffer[i] = 0.0
        }
        
        guard isNoteActive else {
            // Return silent buffer
            let totalSamples = frameCount * channelCount
            let silentData = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)
            silentData.initialize(repeating: 0.0, count: totalSamples)
            return AudioEngine.AudioBuffer(
                data: silentData,
                frameCount: frameCount,
                channelCount: channelCount,
                sampleRate: input.sampleRate
            )
        }
        
        // Process audio block
        processAudioBlock(frameCount: frameCount)
        
        // Interleave for stereo output
        for frame in 0..<frameCount {
            let sample = tempBuffer[frame]
            for channel in 0..<channelCount {
                outputBuffer[frame * channelCount + channel] = sample
            }
        }
        
        // Convert array to pointer
        let totalSamples = frameCount * channelCount
        let bufferPointer = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)
        bufferPointer.initialize(from: outputBuffer, count: totalSamples)

        return AudioEngine.AudioBuffer(
            data: bufferPointer,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: input.sampleRate
        )
    }
    
    // MARK: - Audio Processing Implementation
    
    private func processAudioBlock(frameCount: Int) {
        // Get envelope values
        let ampEnvelope = envelopeSystem.processSample()
        
        // Get parameter values
        let mainOctave = parameters.getParameterValue(id: "main_octave") ?? 0.0
        let swarmMix = parameters.getParameterValue(id: "swarm_mix") ?? 0.5
        let detuneAmount = parameters.getParameterValue(id: "detune_amount") ?? 15.0
        let animationAmount = parameters.getParameterValue(id: "animation_amount") ?? 0.3
        
        // Apply main octave offset
        let mainOctaveMultiplier = pow(2.0, Double(-mainOctave))  // Negative because it's octaves down
        
        // Process each sample
        for i in 0..<frameCount {
            var sample: Float = 0.0
            
            // Process main oscillator
            let mainSample = mainOscillator.processSample()
            sample += mainSample * (1.0 - swarmMix)
            
            // Process swarm oscillators
            var swarmSample: Float = 0.0
            for (index, swarmOsc) in swarmOscillators.enumerated() {
                // Apply individual detune amounts
                let individualDetune = detuneAmount * (Float(index) - 2.5) * 0.4  // Spread around center
                swarmOsc.setDetune(individualDetune)
                swarmOsc.setAnimation(animationAmount)
                
                swarmSample += swarmOsc.processSample()
            }
            
            // Normalize swarm output and mix
            swarmSample /= Float(swarmOscillators.count)
            sample += swarmSample * swarmMix
            
            // Apply envelope
            sample *= ampEnvelope
            
            // Store sample
            tempBuffer[i] = sample * 0.5  // Scale down to prevent clipping
        }
    }

    // MARK: - Parameter Management

    private func setupSwarmerParameters() {
        // Main oscillator parameters
        parameters.addParameter(Parameter(
            id: "tune",
            name: "Tune",
            description: "Main tuning offset in semitones",
            value: 0.0,
            minValue: -24.0,
            maxValue: 24.0,
            defaultValue: 0.0,
            unit: "semitones",
            category: .synthesis,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "main_waveform",
            name: "Main Waveform",
            description: "Main oscillator waveform",
            value: 2.0,
            minValue: 0.0,
            maxValue: Float(SwarmerWaveform.allCases.count - 1),
            defaultValue: 2.0,
            unit: "",
            category: .synthesis,
            dataType: .integer,
            scaling: .linear,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "main_octave",
            name: "Main Octave",
            description: "Main oscillator octave offset",
            value: 0.0,
            minValue: 0.0,
            maxValue: 2.0,
            defaultValue: 0.0,
            unit: "octaves",
            category: .synthesis,
            dataType: .integer,
            scaling: .linear,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        // Swarm parameters
        parameters.addParameter(Parameter(
            id: "swarm_waveform",
            name: "Swarm Waveform",
            description: "Swarm oscillators waveform",
            value: 2.0,
            minValue: 0.0,
            maxValue: Float(SwarmerWaveform.allCases.count - 1),
            defaultValue: 2.0,
            unit: "",
            category: .synthesis,
            dataType: .integer,
            scaling: .linear,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "detune_amount",
            name: "Detune",
            description: "Swarm oscillator detune amount",
            value: 20.0,
            minValue: 0.0,
            maxValue: 100.0,
            defaultValue: 20.0,
            unit: "cents",
            category: .synthesis,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "swarm_mix",
            name: "Mix",
            description: "Mix between main and swarm oscillators",
            value: 0.7,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.7,
            unit: "",
            category: .synthesis,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "animation_amount",
            name: "Animation",
            description: "Swarm animation modulation amount",
            value: 0.3,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.3,
            unit: "",
            category: .modulation,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "animation_rate",
            name: "Animation Rate",
            description: "Swarm animation modulation rate",
            value: 2.0,
            minValue: 0.1,
            maxValue: 20.0,
            defaultValue: 2.0,
            unit: "Hz",
            category: .modulation,
            dataType: .float,
            scaling: .logarithmic,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        parameters.addParameter(Parameter(
            id: "spread",
            name: "Spread",
            description: "Stereo spread of swarm oscillators",
            value: 0.5,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.5,
            unit: "",
            category: .synthesis,
            dataType: .float,
            scaling: .linear,
            isAutomatable: true,
            stepSize: nil,
            enumerationValues: nil,
            changeCallback: nil
        ))

        // Set parameter update callback
        parameters.setUpdateCallback { [weak self] parameterID, value in
            self?.handleParameterUpdate(parameterID: parameterID, value: value)
        }
    }

    private func handleParameterUpdate(parameterID: String, value: Float) {
        switch parameterID {
        case "tune":
            // Apply tuning offset to all oscillators
            let frequency = 440.0 * pow(2.0, Double(Int(currentNote) - 69 + Int(value)) / 12.0)
            mainOscillator.setFrequency(frequency)
            for swarmOsc in swarmOscillators {
                swarmOsc.setFrequency(frequency)
            }

        case "main_waveform":
            let waveformIndex = Int(value)
            if waveformIndex < SwarmerWaveform.allCases.count {
                mainOscillator.waveform = SwarmerWaveform.allCases[waveformIndex]
            }

        case "swarm_waveform":
            let waveformIndex = Int(value)
            if waveformIndex < SwarmerWaveform.allCases.count {
                let waveform = SwarmerWaveform.allCases[waveformIndex]
                for swarmOsc in swarmOscillators {
                    swarmOsc.waveform = waveform
                }
            }

        case "animation_rate":
            for swarmOsc in swarmOscillators {
                swarmOsc.setAnimation(swarmOsc.animationAmount, rate: value)
            }

        default:
            break
        }
    }

    private func setupDefaultSettings() {
        // Set default waveforms
        mainOscillator.waveform = .sawtooth
        for swarmOsc in swarmOscillators {
            swarmOsc.waveform = .sawtooth
        }

        // Set default detune spread for swarm oscillators
        for (index, swarmOsc) in swarmOscillators.enumerated() {
            let baseDetune = Float(Double(index) - 2.5) * 8.0  // Spread from -20 to +20 cents
            swarmOsc.setDetune(baseDetune)
            swarmOsc.setAnimation(0.3, rate: 2.0)
        }
    }

    // MARK: - Preset Management

    /// Create preset configurations for different SWARMER sounds
    public static func createPreset(type: SwarmerPresetType) -> [String: Float] {
        var preset: [String: Float] = [:]

        switch type {
        case .lush:
            preset["detune_amount"] = 25.0
            preset["swarm_mix"] = 0.8
            preset["animation_amount"] = 0.4
            preset["animation_rate"] = 1.5
            preset["main_waveform"] = 2.0  // Sawtooth
            preset["swarm_waveform"] = 2.0  // Sawtooth

        case .wide:
            preset["detune_amount"] = 40.0
            preset["swarm_mix"] = 0.9
            preset["animation_amount"] = 0.2
            preset["animation_rate"] = 0.8
            preset["spread"] = 1.0
            preset["main_waveform"] = 1.0  // Triangle
            preset["swarm_waveform"] = 2.0  // Sawtooth

        case .subtle:
            preset["detune_amount"] = 10.0
            preset["swarm_mix"] = 0.5
            preset["animation_amount"] = 0.1
            preset["animation_rate"] = 3.0
            preset["main_waveform"] = 0.0  // Sine
            preset["swarm_waveform"] = 0.0  // Sine

        case .aggressive:
            preset["detune_amount"] = 60.0
            preset["swarm_mix"] = 0.7
            preset["animation_amount"] = 0.8
            preset["animation_rate"] = 5.0
            preset["main_waveform"] = 3.0  // Square
            preset["swarm_waveform"] = 2.0  // Sawtooth

        case .organic:
            preset["detune_amount"] = 30.0
            preset["swarm_mix"] = 0.6
            preset["animation_amount"] = 0.6
            preset["animation_rate"] = 1.2
            preset["main_waveform"] = 1.0  // Triangle
            preset["swarm_waveform"] = 1.0  // Triangle
        }

        return preset
    }

    /// Apply a preset to the voice machine
    public func applyPreset(_ preset: [String: Float]) {
        for (parameterID, value) in preset {
            try? parameters.updateParameter(id: parameterID, value: value)
        }
    }
}

// MARK: - SWARMER Preset Types

/// Preset types for SWARMER configurations
public enum SwarmerPresetType: String, CaseIterable, Codable {
    case lush = "lush"
    case wide = "wide"
    case subtle = "subtle"
    case aggressive = "aggressive"
    case organic = "organic"

    public var description: String {
        switch self {
        case .lush: return "Lush"
        case .wide: return "Wide"
        case .subtle: return "Subtle"
        case .aggressive: return "Aggressive"
        case .organic: return "Organic"
        }
    }
}
