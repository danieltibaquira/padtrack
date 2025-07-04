//
//  FMDrumMIDIHandler.swift
//  DigitonePad - VoiceModule
//
//  MIDI input handling for FM DRUM voice machine
//

import Foundation
import CoreMIDI
import MachineProtocols
import QuartzCore

#if canImport(MIDIModule)
import MIDIModule
#endif

/// MIDI input handler specifically designed for FM DRUM voice machine
public final class FMDrumMIDIHandler: @unchecked Sendable {
    // MIDI configuration
    private let midiChannel: UInt8
    private let velocitySensitivity: Double
    private let noteRange: ClosedRange<UInt8>
    
    // Parameter CC mappings
    private var ccMappings: [UInt8: String] = [:]
    
    // Voice machine reference
    private weak var voiceMachine: FMDrumVoiceMachine?
    
    // MIDI state tracking
    private var activeNotes: Set<UInt8> = []
    private var lastVelocity: UInt8 = 100
    private var lastNoteOnTime: [UInt8: TimeInterval] = [:]
    
    // Callbacks
    public var onNoteEvent: ((UInt8, UInt8, Bool) -> Void)?
    public var onParameterChange: ((String, Float) -> Void)?
    
    public init(
        voiceMachine: FMDrumVoiceMachine,
        midiChannel: UInt8 = 0,
        velocitySensitivity: Double = 1.0,
        noteRange: ClosedRange<UInt8> = 36...96
    ) {
        self.voiceMachine = voiceMachine
        self.midiChannel = midiChannel
        self.velocitySensitivity = velocitySensitivity
        self.noteRange = noteRange
        
        setupDefaultCCMappings()
        setupMIDIInputHandler()
    }
    
    // MARK: - MIDI Input Handling
    
    /// Process incoming MIDI message
    public func processMIDIMessage(_ message: MIDIModule.MIDIMessage) {
        // Filter by channel (0 = omni mode)
        if midiChannel != 0 && message.channel != midiChannel {
            return
        }
        
        switch message.type {
        case .noteOn:
            handleNoteOn(note: message.data1, velocity: message.data2)
            
        case .noteOff:
            handleNoteOff(note: message.data1)
            
        case .controlChange:
            handleControlChange(cc: message.data1, value: message.data2)
            
        case .programChange:
            handleProgramChange(program: message.data1)
            
        case .pitchBend:
            handlePitchBend(lsb: message.data1, msb: message.data2)
            
        default:
            // Ignore other message types (timingClock, start, continue, stop, systemExclusive)
            break
        }
    }
    
    // MARK: - Note Handling
    
    private func handleNoteOn(note: UInt8, velocity: UInt8) {
        // Check note range
        guard noteRange.contains(note) else { return }
        
        // Handle velocity 0 as note off
        if velocity == 0 {
            handleNoteOff(note: note)
            return
        }
        
        // Apply velocity sensitivity
        let adjustedVelocity = applyVelocitySensitivity(velocity)
        
        // Track active notes
        activeNotes.insert(note)
        lastVelocity = adjustedVelocity
        lastNoteOnTime[note] = CACurrentMediaTime()
        
        // Trigger voice machine
        voiceMachine?.noteOn(
            note: note,
            velocity: adjustedVelocity,
            channel: midiChannel,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000)
        )
        
        // Notify callback
        onNoteEvent?(note, adjustedVelocity, true)
    }
    
    private func handleNoteOff(note: UInt8) {
        // Check note range
        guard noteRange.contains(note) else { return }
        
        // Remove from active notes
        activeNotes.remove(note)
        
        // For drums, note off usually triggers quick release
        voiceMachine?.noteOff(note: note, velocity: 0, channel: midiChannel, timestamp: nil)
        
        // Notify callback
        onNoteEvent?(note, 0, false)
    }
    
    // MARK: - Control Change Handling
    
    private func handleControlChange(cc: UInt8, value: UInt8) {
        guard let parameterId = ccMappings[cc] else { return }
        
        // Convert MIDI value (0-127) to normalized parameter value (0.0-1.0)
        let normalizedValue = Float(value) / 127.0
        
        // Update parameter in voice machine
        if let parameter = voiceMachine?.parameters.getParameter(id: parameterId) {
            let scaledValue = parameter.minValue + normalizedValue * (parameter.maxValue - parameter.minValue)
            voiceMachine?.parameters.updateParameter(id: parameterId, value: scaledValue)
            
            // Notify callback
            onParameterChange?(parameterId, scaledValue)
        }
    }
    
    // MARK: - Other MIDI Handlers
    
    private func handleProgramChange(program: UInt8) {
        // Map program changes to drum types
        let drumTypes = DrumType.allCases
        let drumTypeIndex = Int(program) % drumTypes.count
        let drumType = drumTypes[drumTypeIndex]
        
        voiceMachine?.setDrumType(drumType)
    }
    
    private func handlePitchBend(lsb: UInt8, msb: UInt8) {
        // Combine LSB and MSB to get 14-bit pitch bend value
        let pitchBendValue = Int(msb) << 7 | Int(lsb)
        let normalizedBend = (Double(pitchBendValue) - 8192.0) / 8192.0 // -1.0 to 1.0
        
        // Apply pitch bend to pitch sweep amount
        let bendAmount = normalizedBend * 0.5 // Scale to reasonable range
        if let parameter = voiceMachine?.parameters.getParameter(id: "pitch_sweep_amount") {
            let newValue = Float(max(0.0, min(1.0, Double(parameter.defaultValue) + bendAmount)))
            voiceMachine?.parameters.updateParameter(id: "pitch_sweep_amount", value: newValue)
        }
    }
    
    private func handleAftertouch(pressure: UInt8) {
        // Map aftertouch to wavefold amount for expression
        let normalizedPressure = Float(pressure) / 127.0
        if let parameter = voiceMachine?.parameters.getParameter(id: "wavefold_amount") {
            let newValue = normalizedPressure * parameter.maxValue
            voiceMachine?.parameters.updateParameter(id: "wavefold_amount", value: newValue)
        }
    }
    
    private func handlePolyAftertouch(note: UInt8, pressure: UInt8) {
        // For drums, poly aftertouch could modulate individual voice parameters
        // This is advanced functionality that could be implemented later
    }
    
    // MARK: - Configuration
    
    private func setupDefaultCCMappings() {
        // Standard CC mappings for FM DRUM parameters
        ccMappings = [
            1:  "body_tone",           // Modulation wheel -> Body Tone
            7:  "master_volume",       // Volume -> Master Volume
            10: "noise_level",         // Pan -> Noise Level (repurposed)
            11: "wavefold_amount",     // Expression -> Wavefold Amount
            74: "pitch_sweep_amount",  // Filter Cutoff -> Pitch Sweep Amount
            75: "pitch_sweep_time",    // Filter Resonance -> Pitch Sweep Time
            91: "reverb_send",         // Reverb Send (if implemented)
            93: "chorus_send"          // Chorus Send (if implemented)
        ]
    }
    
    /// Update CC mapping for a specific parameter
    public func setCCMapping(cc: UInt8, parameterId: String) {
        ccMappings[cc] = parameterId
    }
    
    /// Remove CC mapping
    public func removeCCMapping(cc: UInt8) {
        ccMappings.removeValue(forKey: cc)
    }
    
    /// Get current CC mappings
    public func getCCMappings() -> [UInt8: String] {
        return ccMappings
    }
    
    // MARK: - Velocity Processing
    
    private func applyVelocitySensitivity(_ velocity: UInt8) -> UInt8 {
        let normalizedVelocity = Double(velocity) / 127.0
        let adjustedVelocity = pow(normalizedVelocity, velocitySensitivity)
        return UInt8(max(1, min(127, adjustedVelocity * 127.0)))
    }
    
    // MARK: - MIDI Setup
    
    private func setupMIDIInputHandler() {
        // Register with MIDI manager to receive input
        MIDIManager.shared.setInputHandler { [weak self] note, velocity, channel in
            let message = MIDIModule.MIDIMessage(
                type: velocity > 0 ? .noteOn : .noteOff,
                channel: channel,
                data1: note,
                data2: velocity
            )
            self?.processMIDIMessage(message)
        }
    }
    
    // MARK: - State Management
    
    /// Get currently active notes
    public func getActiveNotes() -> Set<UInt8> {
        return activeNotes
    }
    
    /// Stop all active notes
    public func allNotesOff() {
        for note in activeNotes {
            handleNoteOff(note: note)
        }
        activeNotes.removeAll()
    }
    
    /// Panic - immediately stop all sound
    public func panic() {
        allNotesOff()
        voiceMachine?.stopAllVoices()
    }
    
    // MARK: - Configuration Properties
    
    /// Set MIDI channel (0 = omni)
    public func setMIDIChannel(_ channel: UInt8) {
        // This would require reinitializing the handler
        // For now, we'll store it for future use
    }
    
    /// Set velocity sensitivity curve
    public func setVelocitySensitivity(_ sensitivity: Double) {
        // Clamp to reasonable range and update the stored value
        _ = max(0.1, min(3.0, sensitivity))
        // Would need to update the stored value
    }
    
    /// Set note range for filtering
    public func setNoteRange(_ range: ClosedRange<UInt8>) {
        // Would need to update the stored range
    }
}

// MARK: - MIDI Message Extension

extension MIDIModule.MIDIMessage {
    /// Create a note on message
    static func noteOn(note: UInt8, velocity: UInt8, channel: UInt8) -> MIDIModule.MIDIMessage {
        return MIDIModule.MIDIMessage(type: .noteOn, channel: channel, data1: note, data2: velocity)
    }
    
    /// Create a note off message
    static func noteOff(note: UInt8, velocity: UInt8, channel: UInt8) -> MIDIModule.MIDIMessage {
        return MIDIModule.MIDIMessage(type: .noteOff, channel: channel, data1: note, data2: velocity)
    }
    
    /// Create a control change message
    static func controlChange(cc: UInt8, value: UInt8, channel: UInt8) -> MIDIModule.MIDIMessage {
        return MIDIModule.MIDIMessage(type: .controlChange, channel: channel, data1: cc, data2: value)
    }
}
