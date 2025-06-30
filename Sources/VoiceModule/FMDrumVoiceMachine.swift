// FMDrumVoiceMachine.swift
// DigitonePad - VoiceModule
//
// FM DRUM Voice Machine for percussion sounds

import Foundation
import AudioEngine
import MachineProtocols

/// FM DRUM Voice Machine implementing specialized percussion synthesis
public final class FMDrumVoiceMachine: VoiceMachine, @unchecked Sendable {
    // FM-specific components for drums
    private let fmEngine: FMDrumSynthesisEngine

    // MIDI input handler (temporarily disabled)
    // private var midiHandler: FMDrumMIDIHandler?

    // Preset system (temporarily disabled)
    // private let presetSystem: FMDrumPresetSystem

    // Drum-specific parameters
    private var bodyTone: Double = 0.5          // Body fundamental tone
    private var noiseLevel: Double = 0.3        // Transient noise level
    private var pitchSweepAmount: Double = 0.4  // Pitch envelope amount
    private var pitchSweepTime: Double = 0.1    // Pitch envelope time
    private var wavefoldAmount: Double = 0.2    // Wavefolding distortion
    private var drumType: DrumType = .kick      // Type of drum sound
    
    public override init(name: String = "FM DRUM", polyphony: Int = 8) {
        // Initialize FM drum engine
        self.fmEngine = FMDrumSynthesisEngine(sampleRate: 44100.0, maxPolyphony: polyphony)
        
        // self.presetSystem = FMDrumPresetSystem()

        super.init(name: name, polyphony: polyphony)

        setupDrumParameters()
        setupMIDIHandler()
    }
    
    // MARK: - Audio Processing Override
    
    public override func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        lastActiveTimestamp = Date()

        // Process FM drum synthesis
        let frameCount = input.frameCount
        let drumOutput = fmEngine.processBuffer(frameCount: frameCount)

        // Create output buffer with allocated memory
        let totalSamples = frameCount * input.channelCount
        let outputData = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)
        outputData.initialize(repeating: 0.0, count: totalSamples)

        let outputBuffer = AudioEngine.AudioBuffer(
            data: outputData,
            frameCount: frameCount,
            channelCount: input.channelCount,
            sampleRate: input.sampleRate
        )

        // Copy drum output to all channels (mono to stereo/multi-channel)
        for channel in 0..<input.channelCount {
            for frame in 0..<frameCount {
                let sampleIndex = channel * frameCount + frame
                if sampleIndex < totalSamples && frame < drumOutput.count {
                    outputData[sampleIndex] = Float(drumOutput[frame])
                }
            }
        }

        return outputBuffer
    }
    
    // MARK: - Note Handling Override
    
    public override func noteOn(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?) {
        super.noteOn(note: note, velocity: velocity, channel: channel, timestamp: timestamp)
        
        // Trigger FM drum engine with velocity-sensitive parameters
        _ = fmEngine.noteOn(note: note, velocity: velocity)
    }
    
    public override func noteOff(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?) {
        super.noteOff(note: note, velocity: velocity, channel: channel, timestamp: timestamp)
        
        // For drums, note off is usually immediate or ignored
        fmEngine.noteOff(note: note)
    }
    
    // MARK: - Parameter Setup
    
    private func setupDrumParameters() {
        // Body tone parameter
        let bodyToneParam = Parameter(
            id: "body_tone",
            name: "Body Tone",
            value: Float(bodyTone),
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.5,
            unit: "",
            category: .synthesis,
            changeCallback: { [weak self] id, oldValue, newValue in
                self?.bodyTone = Double(newValue)
                self?.fmEngine.setBodyTone(Double(newValue))
            }
        )
        parameters.addParameter(bodyToneParam)

        // Noise level parameter
        let noiseLevelParam = Parameter(
            id: "noise_level",
            name: "Noise Level",
            value: Float(noiseLevel),
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.3,
            unit: "",
            category: .synthesis,
            changeCallback: { [weak self] id, oldValue, newValue in
                self?.noiseLevel = Double(newValue)
                self?.fmEngine.setNoiseLevel(Double(newValue))
            }
        )
        parameters.addParameter(noiseLevelParam)

        // Pitch sweep amount parameter
        let pitchSweepAmountParam = Parameter(
            id: "pitch_sweep_amount",
            name: "Pitch Sweep",
            value: Float(pitchSweepAmount),
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.4,
            unit: "",
            category: .synthesis,
            changeCallback: { [weak self] id, oldValue, newValue in
                self?.pitchSweepAmount = Double(newValue)
                self?.fmEngine.setPitchSweepAmount(Double(newValue))
            }
        )
        parameters.addParameter(pitchSweepAmountParam)

        // Pitch sweep time parameter
        let pitchSweepTimeParam = Parameter(
            id: "pitch_sweep_time",
            name: "Sweep Time",
            value: Float(pitchSweepTime),
            minValue: 0.01,
            maxValue: 1.0,
            defaultValue: 0.1,
            unit: "s",
            category: .synthesis,
            changeCallback: { [weak self] id, oldValue, newValue in
                self?.pitchSweepTime = Double(newValue)
                self?.fmEngine.setPitchSweepTime(Double(newValue))
            }
        )
        parameters.addParameter(pitchSweepTimeParam)

        // Wavefold amount parameter
        let wavefoldAmountParam = Parameter(
            id: "wavefold_amount",
            name: "Wavefold",
            value: Float(wavefoldAmount),
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.2,
            unit: "",
            category: .synthesis,
            changeCallback: { [weak self] id, oldValue, newValue in
                self?.wavefoldAmount = Double(newValue)
                self?.fmEngine.setWavefoldAmount(Double(newValue))
            }
        )
        parameters.addParameter(wavefoldAmountParam)

        // Output stage parameters
        setupOutputStageParameters()
    }
    
    // MARK: - Drum Type Management
    
    /// Set the drum type for specialized parameter mappings
    public func setDrumType(_ type: DrumType) {
        drumType = type
        fmEngine.setDrumType(type)
        updateParametersForDrumType(type)
    }
    
    private func updateParametersForDrumType(_ type: DrumType) {
        switch type {
        case .kick:
            bodyTone = 0.8
            noiseLevel = 0.1
            pitchSweepAmount = 0.6
            pitchSweepTime = 0.05
            wavefoldAmount = 0.3
        case .snare:
            bodyTone = 0.4
            noiseLevel = 0.7
            pitchSweepAmount = 0.2
            pitchSweepTime = 0.02
            wavefoldAmount = 0.1
        case .hihat:
            bodyTone = 0.1
            noiseLevel = 0.9
            pitchSweepAmount = 0.1
            pitchSweepTime = 0.01
            wavefoldAmount = 0.0
        case .tom:
            bodyTone = 0.6
            noiseLevel = 0.2
            pitchSweepAmount = 0.4
            pitchSweepTime = 0.08
            wavefoldAmount = 0.2
        case .cymbal:
            bodyTone = 0.2
            noiseLevel = 0.8
            pitchSweepAmount = 0.1
            pitchSweepTime = 0.02
            wavefoldAmount = 0.1
        }
        
        // Update engine parameters
        fmEngine.setBodyTone(bodyTone)
        fmEngine.setNoiseLevel(noiseLevel)
        fmEngine.setPitchSweepAmount(pitchSweepAmount)
        fmEngine.setPitchSweepTime(pitchSweepTime)
        fmEngine.setWavefoldAmount(wavefoldAmount)
    }

    // MARK: - Output Stage Parameter Setup

    private func setupOutputStageParameters() {
        // Output gain parameter
        let outputGainParam = Parameter(
            id: "output_gain",
            name: "Output Gain",
            value: 1.0,
            minValue: 0.0,
            maxValue: 2.0,
            defaultValue: 1.0,
            unit: "",
            category: .mixer,
            changeCallback: { [weak self] id, oldValue, newValue in
                self?.fmEngine.setOutputGain(Double(newValue))
            }
        )
        parameters.addParameter(outputGainParam)

        // Pan position parameter
        let panParam = Parameter(
            id: "pan_position",
            name: "Pan",
            value: 0.0,
            minValue: -1.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .mixer,
            changeCallback: { [weak self] id, oldValue, newValue in
                self?.fmEngine.setPanPosition(Double(newValue))
            }
        )
        parameters.addParameter(panParam)

        // Reverb send parameter
        let reverbSendParam = Parameter(
            id: "reverb_send",
            name: "Reverb Send",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .effects,
            changeCallback: { [weak self] id, oldValue, newValue in
                self?.fmEngine.setReverbSend(Double(newValue))
            }
        )
        parameters.addParameter(reverbSendParam)

        // Distortion amount parameter
        let distortionParam = Parameter(
            id: "distortion_amount",
            name: "Distortion",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .effects,
            changeCallback: { [weak self] id, oldValue, newValue in
                self?.fmEngine.setDistortionAmount(Double(newValue))
            }
        )
        parameters.addParameter(distortionParam)

        // Compression amount parameter
        let compressionParam = Parameter(
            id: "compression_amount",
            name: "Compression",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: "",
            category: .effects,
            changeCallback: { [weak self] id, oldValue, newValue in
                self?.fmEngine.setCompressionAmount(Double(newValue))
            }
        )
        parameters.addParameter(compressionParam)
    }

    // MARK: - MIDI Handler Setup

    private func setupMIDIHandler() {
        // Temporarily disabled - MIDI handler implementation
        /*
        midiHandler = FMDrumMIDIHandler(voiceMachine: self)

        // Set up MIDI event callbacks
        midiHandler?.onNoteEvent = { [weak self] note, velocity, isNoteOn in
            // Additional processing for MIDI note events if needed
            print("MIDI Note: \(note), Velocity: \(velocity), On: \(isNoteOn)")
        }

        midiHandler?.onParameterChange = { [weak self] parameterId, value in
            // Additional processing for MIDI parameter changes if needed
            print("MIDI CC: \(parameterId) = \(value)")
        }
        */
    }

    // MARK: - MIDI Interface (temporarily disabled)

    /*
    /// Get the MIDI handler for external configuration
    public func getMIDIHandler() -> FMDrumMIDIHandler? {
        return midiHandler
    }

    /// Set MIDI channel (0 = omni mode)
    public func setMIDIChannel(_ channel: UInt8) {
        midiHandler?.setMIDIChannel(channel)
    }

    /// Configure MIDI CC mapping
    public func setMIDICCMapping(cc: UInt8, parameterId: String) {
        midiHandler?.setCCMapping(cc: cc, parameterId: parameterId)
    }
    */

    /// Stop all MIDI notes
    public override func allNotesOff() {
        // midiHandler?.allNotesOff()
        super.allNotesOff()
    }

    /// Emergency stop all sound
    public func panic() {
        // midiHandler?.panic()
        fmEngine.stopAllVoices()
    }

    /// Stop all active voices immediately
    public func stopAllVoices() {
        fmEngine.stopAllVoices()
    }

    // MARK: - Output Stage Access (temporarily disabled)

    /*
    /// Get output stage for direct configuration
    public func getOutputStage() -> FMDrumOutputStage {
        return fmEngine.getOutputStage()
    }

    /// Get output monitoring data
    public func getOutputPeakLevel() -> Double {
        return fmEngine.getOutputPeakLevel()
    }

    public func getOutputRMSLevel() -> Double {
        return fmEngine.getOutputRMSLevel()
    }

    public func getOutputCPUUsage() -> Double {
        return fmEngine.getOutputCPUUsage()
    }

    /// Configure output effects directly
    public func configureReverb(roomSize: Double, damping: Double, wetLevel: Double) {
        fmEngine.configureReverb(roomSize: roomSize, damping: damping, wetLevel: wetLevel)
    }

    public func configureDistortion(type: DistortionType, amount: Double, tone: Double) {
        fmEngine.configureDistortion(type: type, amount: amount, tone: tone)
    }

    public func configureCompressor(threshold: Double, ratio: Double, attack: Double, release: Double) {
        fmEngine.configureCompressor(threshold: threshold, ratio: ratio, attack: attack, release: release)
    }
    */

    // MARK: - Modulation Matrix Access (temporarily disabled)

    /*
    /// Get modulation matrix from the first voice (all voices share the same matrix structure)
    public func getModulationMatrix() -> FMDrumModulationMatrix? {
        return fmEngine.getModulationMatrix()
    }

    /// Update MIDI modulation sources for all voices
    public func updateMIDIModulation(
        pitchBend: Double = 0.0,
        modWheel: Double = 0.0,
        aftertouch: Double = 0.0
    ) {
        fmEngine.updateMIDIModulation(
            pitchBend: pitchBend,
            modWheel: modWheel,
            aftertouch: aftertouch
        )
    }

    // MARK: - Preset Management

    /// Get the preset system for external access
    public func getPresetSystem() -> FMDrumPresetSystem {
        return presetSystem
    }

    /// Save current state as a preset
    public func savePreset(name: String, category: String = "User") -> Bool {
        return presetSystem.savePreset(name: name, category: category, voiceMachine: self)
    }

    /// Load a preset by ID
    public func loadPreset(id: String) -> Bool {
        let success = presetSystem.loadPreset(id: id, into: self)
        if success {
            // Notify that preset has been loaded
            presetSystem.markAsModified()
        }
        return success
    }

    /// Get all presets in a category
    public func getPresetsInCategory(_ category: String) -> [FMDrumPreset] {
        return presetSystem.getPresetsInCategory(category)
    }

    /// Get all available preset categories
    public func getPresetCategories() -> [String] {
        return presetSystem.getAllCategories()
    }

    /// Search presets by name or tags
    public func searchPresets(query: String) -> [FMDrumPreset] {
        return presetSystem.searchPresets(query: query)
    }

    /// Get current preset information
    public func getCurrentPreset() -> FMDrumPreset? {
        return presetSystem.getCurrentPreset()
    }

    /// Check if current preset has been modified
    public func isPresetModified() -> Bool {
        return presetSystem.isCurrentPresetModified()
    }

    /// Delete a user preset
    public func deletePreset(id: String) -> Bool {
        return presetSystem.deletePreset(id: id)
    }

    /// Get preset statistics
    public func getPresetStatistics() -> (total: Int, factory: Int, user: Int) {
        return (
            total: presetSystem.getPresetCount(),
            factory: presetSystem.getFactoryPresetCount(),
            user: presetSystem.getUserPresetCount()
        )
    }
    */
}

// MARK: - Drum Types

/// Drum sound types for specialized parameter mappings
public enum DrumType: String, CaseIterable {
    case kick = "kick"
    case snare = "snare"
    case hihat = "hihat"
    case tom = "tom"
    case cymbal = "cymbal"
    
    public var displayName: String {
        switch self {
        case .kick: return "Kick"
        case .snare: return "Snare"
        case .hihat: return "Hi-Hat"
        case .tom: return "Tom"
        case .cymbal: return "Cymbal"
        }
    }
}
