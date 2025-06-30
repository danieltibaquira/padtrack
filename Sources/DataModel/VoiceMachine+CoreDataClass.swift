//
//  VoiceMachine+CoreDataClass.swift
//  PadTrack
//
//  Created by PadTrack on 2024.
//

import Foundation
import CoreData

@objc(VoiceMachine)
public class VoiceMachine: Machine {
    
    // MARK: - Convenience Initializers
    
    convenience init(context: NSManagedObjectContext, name: String) {
        self.init(context: context, name: name, typeName: "VoiceMachine")
        
        // Set voice machine defaults
        self.polyphony = 8
        self.portamentoTime = 0.0
        self.keyboardTracking = true
        self.velocitySensitivity = 1.0
        self.pitchBendRange = 2.0
        self.sustainPedal = false
    }
    
    // MARK: - Computed Properties
    
    /// Check if machine is monophonic (polyphony = 1)
    var isMonophonic: Bool {
        return polyphony == 1
    }
    
    /// Check if machine is polyphonic (polyphony > 1)
    var isPolyphonic: Bool {
        return polyphony > 1
    }
    
    /// Check if portamento is enabled
    var hasPortamento: Bool {
        return portamentoTime > 0.0
    }
    
    /// Check if velocity affects the sound
    var hasVelocitySensitivity: Bool {
        return velocitySensitivity > 0.0
    }
    
    /// Check if pitch bend is enabled
    var hasPitchBend: Bool {
        return pitchBendRange > 0.0
    }
    
    /// Get voice allocation mode
    var voiceAllocationMode: VoiceAllocationMode {
        if isMonophonic {
            return .monophonic
        } else if polyphony <= 4 {
            return .lowPolyphony
        } else if polyphony <= 8 {
            return .mediumPolyphony
        } else {
            return .highPolyphony
        }
    }
    
    /// Calculate CPU usage estimate based on polyphony
    var cpuUsageEstimate: Double {
        let baseUsage = 0.1  // Base CPU usage for one voice
        return baseUsage * Double(polyphony)
    }
    
    // MARK: - Polyphony Management
    
    /// Set polyphony with validation
    func setPolyphony(_ voices: Int16) throws {
        guard voices >= 1 && voices <= 32 else {
            throw VoiceMachineError.invalidPolyphony(voices)
        }
        polyphony = voices
        lastModified = Date()
    }
    
    /// Make machine monophonic
    func makeMonophonic() {
        polyphony = 1
        lastModified = Date()
    }
    
    /// Set common polyphony presets
    func setPolyphonyPreset(_ preset: PolyphonyPreset) {
        polyphony = preset.voiceCount
        lastModified = Date()
    }
    
    // MARK: - Portamento Management
    
    /// Set portamento time with validation
    func setPortamentoTime(_ time: Double) throws {
        guard time >= 0.0 && time <= 10.0 else {
            throw VoiceMachineError.invalidPortamentoTime(time)
        }
        portamentoTime = time
        lastModified = Date()
    }
    
    /// Enable portamento with specific time
    func enablePortamento(time: Double = 0.1) throws {
        try setPortamentoTime(time)
    }
    
    /// Disable portamento
    func disablePortamento() {
        portamentoTime = 0.0
        lastModified = Date()
    }
    
    /// Toggle portamento
    func togglePortamento() {
        if hasPortamento {
            disablePortamento()
        } else {
            try? enablePortamento()
        }
    }
    
    // MARK: - MIDI and Performance Controls
    
    /// Set velocity sensitivity with validation
    func setVelocitySensitivity(_ sensitivity: Double) throws {
        guard sensitivity >= 0.0 && sensitivity <= 2.0 else {
            throw VoiceMachineError.invalidVelocitySensitivity(sensitivity)
        }
        velocitySensitivity = sensitivity
        lastModified = Date()
    }
    
    /// Set pitch bend range with validation
    func setPitchBendRange(_ range: Double) throws {
        guard range >= 0.0 && range <= 24.0 else {
            throw VoiceMachineError.invalidPitchBendRange(range)
        }
        pitchBendRange = range
        lastModified = Date()
    }
    
    /// Enable/disable keyboard tracking
    func setKeyboardTracking(_ enabled: Bool) {
        keyboardTracking = enabled
        lastModified = Date()
    }
    
    /// Toggle keyboard tracking
    func toggleKeyboardTracking() {
        keyboardTracking.toggle()
        lastModified = Date()
    }
    
    /// Enable/disable sustain pedal support
    func setSustainPedal(_ enabled: Bool) {
        sustainPedal = enabled
        lastModified = Date()
    }
    
    /// Toggle sustain pedal support
    func toggleSustainPedal() {
        sustainPedal.toggle()
        lastModified = Date()
    }
    
    // MARK: - Voice Machine Configuration
    
    /// Apply common voice machine preset
    func applyPreset(_ preset: VoiceMachinePreset) {
        polyphony = preset.polyphony
        portamentoTime = preset.portamentoTime
        velocitySensitivity = preset.velocitySensitivity
        pitchBendRange = preset.pitchBendRange
        keyboardTracking = preset.keyboardTracking
        sustainPedal = preset.sustainPedal
        lastModified = Date()
    }
    
    /// Get current configuration as preset
    func getCurrentConfiguration() -> VoiceMachinePreset {
        return VoiceMachinePreset(
            polyphony: polyphony,
            portamentoTime: portamentoTime,
            velocitySensitivity: velocitySensitivity,
            pitchBendRange: pitchBendRange,
            keyboardTracking: keyboardTracking,
            sustainPedal: sustainPedal
        )
    }
    
    /// Reset voice parameters to defaults
    func resetVoiceParameters() {
        polyphony = 8
        portamentoTime = 0.0
        keyboardTracking = true
        velocitySensitivity = 1.0
        pitchBendRange = 2.0
        sustainPedal = false
        lastModified = Date()
    }
    
    // MARK: - Copy and Duplication
    
    /// Copy voice-specific settings from another voice machine
    override func copySettings(from source: Machine) {
        super.copySettings(from: source)
        
        if let voiceSource = source as? VoiceMachine {
            polyphony = voiceSource.polyphony
            portamentoTime = voiceSource.portamentoTime
            keyboardTracking = voiceSource.keyboardTracking
            velocitySensitivity = voiceSource.velocitySensitivity
            pitchBendRange = voiceSource.pitchBendRange
            sustainPedal = voiceSource.sustainPedal
        }
    }
    
    /// Create a duplicate voice machine
    override func duplicate(in context: NSManagedObjectContext) -> Machine {
        let duplicate = VoiceMachine(context: context, name: "\(name ?? "Voice") Copy")
        duplicate.copySettings(from: self)
        return duplicate
    }
    
    // MARK: - Export and Metadata
    
    /// Generate voice machine specific export metadata
    override func exportMetadata() -> [String: Any] {
        var metadata = super.exportMetadata()
        
        // Add voice machine specific properties
        metadata["voiceMachineProperties"] = [
            "polyphony": polyphony,
            "isMonophonic": isMonophonic,
            "isPolyphonic": isPolyphonic,
            "portamentoTime": portamentoTime,
            "hasPortamento": hasPortamento,
            "keyboardTracking": keyboardTracking,
            "velocitySensitivity": velocitySensitivity,
            "hasVelocitySensitivity": hasVelocitySensitivity,
            "pitchBendRange": pitchBendRange,
            "hasPitchBend": hasPitchBend,
            "sustainPedal": sustainPedal,
            "voiceAllocationMode": voiceAllocationMode.rawValue,
            "cpuUsageEstimate": cpuUsageEstimate
        ]
        
        return metadata
    }
    
    // MARK: - Audio Processing
    
    /// Voice-specific audio processing
    override func processAudio(inputBuffer: UnsafePointer<Float>, 
                              outputBuffer: UnsafeMutablePointer<Float>, 
                              frameCount: Int) {
        if !isProcessing {
            super.processAudio(inputBuffer: inputBuffer, 
                             outputBuffer: outputBuffer, 
                             frameCount: frameCount)
            return
        }
        
        // Voice machine specific processing would go here
        // This is a placeholder for the actual synthesis implementation
        
        // For now, just pass through the input
        for i in 0..<frameCount {
            outputBuffer[i] = inputBuffer[i]
        }
    }
    
    /// Initialize voice-specific audio processing
    override func initializeAudio(sampleRate: Double, bufferSize: Int) {
        super.initializeAudio(sampleRate: sampleRate, bufferSize: bufferSize)
        
        // Initialize voice allocation, envelopes, oscillators, etc.
        // This would be implemented when the actual audio engine is built
    }
    
    // MARK: - Validation
    
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateVoiceMachine()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateVoiceMachine()
    }
    
    private func validateVoiceMachine() throws {
        // Validate polyphony
        guard polyphony >= 1 && polyphony <= 32 else {
            throw VoiceMachineError.invalidPolyphony(polyphony)
        }
        
        // Validate portamento time
        guard portamentoTime >= 0.0 && portamentoTime <= 10.0 else {
            throw VoiceMachineError.invalidPortamentoTime(portamentoTime)
        }
        
        // Validate velocity sensitivity
        guard velocitySensitivity >= 0.0 && velocitySensitivity <= 2.0 else {
            throw VoiceMachineError.invalidVelocitySensitivity(velocitySensitivity)
        }
        
        // Validate pitch bend range
        guard pitchBendRange >= 0.0 && pitchBendRange <= 24.0 else {
            throw VoiceMachineError.invalidPitchBendRange(pitchBendRange)
        }
    }
}

// MARK: - Voice Allocation Modes

enum VoiceAllocationMode: String, CaseIterable {
    case monophonic = "monophonic"
    case lowPolyphony = "low_polyphony"
    case mediumPolyphony = "medium_polyphony"
    case highPolyphony = "high_polyphony"
    
    var displayName: String {
        switch self {
        case .monophonic:
            return "Monophonic"
        case .lowPolyphony:
            return "Low Polyphony (2-4 voices)"
        case .mediumPolyphony:
            return "Medium Polyphony (5-8 voices)"
        case .highPolyphony:
            return "High Polyphony (9+ voices)"
        }
    }
}

// MARK: - Polyphony Presets

enum PolyphonyPreset: String, CaseIterable {
    case mono = "mono"
    case duo = "duo"
    case quad = "quad"
    case standard = "standard"
    case extended = "extended"
    case maximum = "maximum"
    
    var voiceCount: Int16 {
        switch self {
        case .mono:
            return 1
        case .duo:
            return 2
        case .quad:
            return 4
        case .standard:
            return 8
        case .extended:
            return 16
        case .maximum:
            return 32
        }
    }
    
    var displayName: String {
        switch self {
        case .mono:
            return "Mono (1 voice)"
        case .duo:
            return "Duo (2 voices)"
        case .quad:
            return "Quad (4 voices)"
        case .standard:
            return "Standard (8 voices)"
        case .extended:
            return "Extended (16 voices)"
        case .maximum:
            return "Maximum (32 voices)"
        }
    }
}

// MARK: - Voice Machine Configuration

struct VoiceMachinePreset {
    let polyphony: Int16
    let portamentoTime: Double
    let velocitySensitivity: Double
    let pitchBendRange: Double
    let keyboardTracking: Bool
    let sustainPedal: Bool
    
    static let classic = VoiceMachinePreset(
        polyphony: 8,
        portamentoTime: 0.0,
        velocitySensitivity: 1.0,
        pitchBendRange: 2.0,
        keyboardTracking: true,
        sustainPedal: true
    )
    
    static let mono = VoiceMachinePreset(
        polyphony: 1,
        portamentoTime: 0.1,
        velocitySensitivity: 1.2,
        pitchBendRange: 12.0,
        keyboardTracking: true,
        sustainPedal: false
    )
    
    static let poly = VoiceMachinePreset(
        polyphony: 16,
        portamentoTime: 0.0,
        velocitySensitivity: 0.8,
        pitchBendRange: 2.0,
        keyboardTracking: true,
        sustainPedal: true
    )
}

// MARK: - Voice Machine Errors

enum VoiceMachineError: LocalizedError {
    case invalidPolyphony(Int16)
    case invalidPortamentoTime(Double)
    case invalidVelocitySensitivity(Double)
    case invalidPitchBendRange(Double)
    
    var errorDescription: String? {
        switch self {
        case .invalidPolyphony(let voices):
            return "Invalid polyphony: \(voices). Must be between 1 and 32"
        case .invalidPortamentoTime(let time):
            return "Invalid portamento time: \(time). Must be between 0.0 and 10.0 seconds"
        case .invalidVelocitySensitivity(let sensitivity):
            return "Invalid velocity sensitivity: \(sensitivity). Must be between 0.0 and 2.0"
        case .invalidPitchBendRange(let range):
            return "Invalid pitch bend range: \(range). Must be between 0.0 and 24.0 semitones"
        }
    }
} 