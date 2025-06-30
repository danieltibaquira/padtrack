//
//  FilterMachine+CoreDataClass.swift
//  PadTrack
//
//  Created by PadTrack on 2024.
//

import Foundation
import CoreData

@objc(FilterMachine)
public class FilterMachine: Machine {
    
    // MARK: - Convenience Initializers
    
    convenience init(context: NSManagedObjectContext, name: String) {
        self.init(context: context, name: name, typeName: "FilterMachine")
        
        // Set filter machine defaults
        self.cutoffFrequency = 1000.0
        self.resonance = 0.5
        self.morphAmount = 0.0
        self.keyboardTracking = 0.0
        self.envelopeAmount = 0.0
        self.lfoAmount = 0.0
    }
    
    // MARK: - Computed Properties
    
    /// Check if filter has any modulation applied
    var hasModulation: Bool {
        return envelopeAmount > 0.0 || lfoAmount > 0.0 || keyboardTracking > 0.0
    }
    
    /// Check if filter morphing is active
    var hasMorphing: Bool {
        return morphAmount > 0.0
    }
    
    /// Check if resonance is in self-oscillation range
    var isSelfOscillating: Bool {
        return resonance >= 0.9
    }
    
    /// Check if keyboard tracking is enabled
    var hasKeyboardTracking: Bool {
        return keyboardTracking > 0.0
    }
    
    /// Get cutoff frequency in Hz
    var cutoffHz: Double {
        return cutoffFrequency
    }
    
    /// Get cutoff frequency as MIDI note number
    var cutoffMidiNote: Double {
        return 12.0 * log2(cutoffFrequency / 440.0) + 69.0
    }
    
    /// Calculate filter complexity based on modulation sources
    var filterComplexity: FilterComplexity {
        let modCount = (envelopeAmount > 0.0 ? 1 : 0) + 
                      (lfoAmount > 0.0 ? 1 : 0) + 
                      (keyboardTracking > 0.0 ? 1 : 0) + 
                      (hasMorphing ? 1 : 0)
        
        if modCount == 0 {
            return .simple
        } else if modCount <= 2 {
            return .moderate
        } else {
            return .complex
        }
    }
    
    // MARK: - Cutoff Frequency Management
    
    /// Set cutoff frequency with validation
    func setCutoffFrequency(_ frequency: Double) throws {
        guard frequency >= 20.0 && frequency <= 20000.0 else {
            throw FilterMachineError.invalidCutoffFrequency(frequency)
        }
        cutoffFrequency = frequency
        lastModified = Date()
    }
    
    /// Set cutoff from MIDI note number
    func setCutoffFromMidiNote(_ midiNote: Double) throws {
        let frequency = 440.0 * pow(2.0, (midiNote - 69.0) / 12.0)
        try setCutoffFrequency(frequency)
    }
    
    /// Adjust cutoff by semitones
    func adjustCutoffBySemitones(_ semitones: Double) throws {
        let currentNote = cutoffMidiNote
        try setCutoffFromMidiNote(currentNote + semitones)
    }
    
    /// Adjust cutoff by octaves
    func adjustCutoffByOctaves(_ octaves: Double) throws {
        try adjustCutoffBySemitones(octaves * 12.0)
    }
    
    // MARK: - Resonance Management
    
    /// Set resonance with validation
    func setResonance(_ resonanceValue: Double) throws {
        guard resonanceValue >= 0.0 && resonanceValue <= 1.0 else {
            throw FilterMachineError.invalidResonance(resonanceValue)
        }
        resonance = resonanceValue
        lastModified = Date()
    }
    
    /// Enable self-oscillation
    func enableSelfOscillation() {
        resonance = 0.95
        lastModified = Date()
    }
    
    /// Disable self-oscillation
    func disableSelfOscillation() {
        if isSelfOscillating {
            resonance = 0.8
            lastModified = Date()
        }
    }
    
    /// Toggle self-oscillation
    func toggleSelfOscillation() {
        if isSelfOscillating {
            disableSelfOscillation()
        } else {
            enableSelfOscillation()
        }
    }
    
    // MARK: - Morphing Control
    
    /// Set morph amount with validation
    func setMorphAmount(_ amount: Double) throws {
        guard amount >= 0.0 && amount <= 1.0 else {
            throw FilterMachineError.invalidMorphAmount(amount)
        }
        morphAmount = amount
        lastModified = Date()
    }
    
    /// Enable morphing
    func enableMorphing(amount: Double = 0.5) throws {
        try setMorphAmount(amount)
    }
    
    /// Disable morphing
    func disableMorphing() {
        morphAmount = 0.0
        lastModified = Date()
    }
    
    /// Toggle morphing
    func toggleMorphing() {
        if hasMorphing {
            disableMorphing()
        } else {
            try? enableMorphing()
        }
    }
    
    // MARK: - Keyboard Tracking
    
    /// Set keyboard tracking amount with validation
    func setKeyboardTracking(_ amount: Double) throws {
        guard amount >= 0.0 && amount <= 1.0 else {
            throw FilterMachineError.invalidKeyboardTracking(amount)
        }
        keyboardTracking = amount
        lastModified = Date()
    }
    
    /// Enable full keyboard tracking
    func enableFullKeyboardTracking() {
        keyboardTracking = 1.0
        lastModified = Date()
    }
    
    /// Disable keyboard tracking
    func disableKeyboardTracking() {
        keyboardTracking = 0.0
        lastModified = Date()
    }
    
    /// Toggle keyboard tracking
    func toggleKeyboardTracking() {
        if hasKeyboardTracking {
            disableKeyboardTracking()
        } else {
            enableFullKeyboardTracking()
        }
    }
    
    // MARK: - Modulation Management
    
    /// Set envelope modulation amount with validation
    func setEnvelopeAmount(_ amount: Double) throws {
        guard amount >= -1.0 && amount <= 1.0 else {
            throw FilterMachineError.invalidEnvelopeAmount(amount)
        }
        envelopeAmount = amount
        lastModified = Date()
    }
    
    /// Set LFO modulation amount with validation
    func setLFOAmount(_ amount: Double) throws {
        guard amount >= -1.0 && amount <= 1.0 else {
            throw FilterMachineError.invalidLFOAmount(amount)
        }
        lfoAmount = amount
        lastModified = Date()
    }
    
    /// Clear all modulation
    func clearModulation() {
        envelopeAmount = 0.0
        lfoAmount = 0.0
        keyboardTracking = 0.0
        lastModified = Date()
    }
    
    // MARK: - Filter Presets
    
    /// Apply filter preset
    func applyPreset(_ preset: FilterPreset) {
        cutoffFrequency = preset.cutoffFrequency
        resonance = preset.resonance
        morphAmount = preset.morphAmount
        keyboardTracking = preset.keyboardTracking
        envelopeAmount = preset.envelopeAmount
        lfoAmount = preset.lfoAmount
        lastModified = Date()
    }
    
    /// Get current configuration as preset
    func getCurrentConfiguration() -> FilterPreset {
        return FilterPreset(
            cutoffFrequency: cutoffFrequency,
            resonance: resonance,
            morphAmount: morphAmount,
            keyboardTracking: keyboardTracking,
            envelopeAmount: envelopeAmount,
            lfoAmount: lfoAmount
        )
    }
    
    /// Reset filter to default settings
    func resetToDefaults() {
        cutoffFrequency = 1000.0
        resonance = 0.5
        morphAmount = 0.0
        keyboardTracking = 0.0
        envelopeAmount = 0.0
        lfoAmount = 0.0
        lastModified = Date()
    }
    
    // MARK: - Copy and Duplication
    
    /// Copy filter-specific settings from another filter machine
    override func copySettings(from source: Machine) {
        super.copySettings(from: source)
        
        if let filterSource = source as? FilterMachine {
            cutoffFrequency = filterSource.cutoffFrequency
            resonance = filterSource.resonance
            morphAmount = filterSource.morphAmount
            keyboardTracking = filterSource.keyboardTracking
            envelopeAmount = filterSource.envelopeAmount
            lfoAmount = filterSource.lfoAmount
        }
    }
    
    /// Create a duplicate filter machine
    override func duplicate(in context: NSManagedObjectContext) -> Machine {
        let duplicate = FilterMachine(context: context, name: "\(name ?? "Filter") Copy")
        duplicate.copySettings(from: self)
        return duplicate
    }
    
    // MARK: - Export and Metadata
    
    /// Generate filter machine specific export metadata
    override func exportMetadata() -> [String: Any] {
        var metadata = super.exportMetadata()
        
        // Add filter machine specific properties
        metadata["filterMachineProperties"] = [
            "cutoffFrequency": cutoffFrequency,
            "cutoffHz": cutoffHz,
            "cutoffMidiNote": cutoffMidiNote,
            "resonance": resonance,
            "isSelfOscillating": isSelfOscillating,
            "morphAmount": morphAmount,
            "hasMorphing": hasMorphing,
            "keyboardTracking": keyboardTracking,
            "hasKeyboardTracking": hasKeyboardTracking,
            "envelopeAmount": envelopeAmount,
            "lfoAmount": lfoAmount,
            "hasModulation": hasModulation,
            "filterComplexity": filterComplexity.rawValue
        ]
        
        return metadata
    }
    
    // MARK: - Audio Processing
    
    /// Filter-specific audio processing
    override func processAudio(inputBuffer: UnsafePointer<Float>, 
                              outputBuffer: UnsafeMutablePointer<Float>, 
                              frameCount: Int) {
        if !isProcessing {
            super.processAudio(inputBuffer: inputBuffer, 
                             outputBuffer: outputBuffer, 
                             frameCount: frameCount)
            return
        }
        
        // Filter machine specific processing would go here
        // This would include the actual filter implementation
        
        // For now, just pass through the input
        for i in 0..<frameCount {
            outputBuffer[i] = inputBuffer[i]
        }
    }
    
    /// Initialize filter-specific audio processing
    override func initializeAudio(sampleRate: Double, bufferSize: Int) {
        super.initializeAudio(sampleRate: sampleRate, bufferSize: bufferSize)
        
        // Initialize filter coefficients, state variables, etc.
        // This would be implemented when the actual filter engine is built
    }
    
    // MARK: - Validation
    
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateFilterMachine()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateFilterMachine()
    }
    
    private func validateFilterMachine() throws {
        // Validate cutoff frequency
        guard cutoffFrequency >= 20.0 && cutoffFrequency <= 20000.0 else {
            throw FilterMachineError.invalidCutoffFrequency(cutoffFrequency)
        }
        
        // Validate resonance
        guard resonance >= 0.0 && resonance <= 1.0 else {
            throw FilterMachineError.invalidResonance(resonance)
        }
        
        // Validate morph amount
        guard morphAmount >= 0.0 && morphAmount <= 1.0 else {
            throw FilterMachineError.invalidMorphAmount(morphAmount)
        }
        
        // Validate keyboard tracking
        guard keyboardTracking >= 0.0 && keyboardTracking <= 1.0 else {
            throw FilterMachineError.invalidKeyboardTracking(keyboardTracking)
        }
        
        // Validate envelope amount
        guard envelopeAmount >= -1.0 && envelopeAmount <= 1.0 else {
            throw FilterMachineError.invalidEnvelopeAmount(envelopeAmount)
        }
        
        // Validate LFO amount
        guard lfoAmount >= -1.0 && lfoAmount <= 1.0 else {
            throw FilterMachineError.invalidLFOAmount(lfoAmount)
        }
    }
}

// MARK: - Filter Complexity

enum FilterComplexity: String, CaseIterable {
    case simple = "simple"
    case moderate = "moderate"
    case complex = "complex"
    
    var displayName: String {
        switch self {
        case .simple:
            return "Simple (No modulation)"
        case .moderate:
            return "Moderate (1-2 modulation sources)"
        case .complex:
            return "Complex (3+ modulation sources)"
        }
    }
}

// MARK: - Filter Presets

struct FilterPreset {
    let cutoffFrequency: Double
    let resonance: Double
    let morphAmount: Double
    let keyboardTracking: Double
    let envelopeAmount: Double
    let lfoAmount: Double
    
    static let lowPass = FilterPreset(
        cutoffFrequency: 1000.0,
        resonance: 0.3,
        morphAmount: 0.0,
        keyboardTracking: 0.0,
        envelopeAmount: 0.0,
        lfoAmount: 0.0
    )
    
    static let acidBass = FilterPreset(
        cutoffFrequency: 800.0,
        resonance: 0.8,
        morphAmount: 0.0,
        keyboardTracking: 0.3,
        envelopeAmount: 0.7,
        lfoAmount: 0.0
    )
    
    static let sweptFilter = FilterPreset(
        cutoffFrequency: 2000.0,
        resonance: 0.6,
        morphAmount: 0.0,
        keyboardTracking: 0.0,
        envelopeAmount: 0.0,
        lfoAmount: 0.8
    )
    
    static let morphingFilter = FilterPreset(
        cutoffFrequency: 1500.0,
        resonance: 0.5,
        morphAmount: 0.7,
        keyboardTracking: 0.2,
        envelopeAmount: 0.3,
        lfoAmount: 0.2
    )
}

// MARK: - Filter Machine Errors

enum FilterMachineError: LocalizedError {
    case invalidCutoffFrequency(Double)
    case invalidResonance(Double)
    case invalidMorphAmount(Double)
    case invalidKeyboardTracking(Double)
    case invalidEnvelopeAmount(Double)
    case invalidLFOAmount(Double)
    
    var errorDescription: String? {
        switch self {
        case .invalidCutoffFrequency(let frequency):
            return "Invalid cutoff frequency: \(frequency) Hz. Must be between 20.0 and 20000.0 Hz"
        case .invalidResonance(let resonance):
            return "Invalid resonance: \(resonance). Must be between 0.0 and 1.0"
        case .invalidMorphAmount(let amount):
            return "Invalid morph amount: \(amount). Must be between 0.0 and 1.0"
        case .invalidKeyboardTracking(let tracking):
            return "Invalid keyboard tracking: \(tracking). Must be between 0.0 and 1.0"
        case .invalidEnvelopeAmount(let amount):
            return "Invalid envelope amount: \(amount). Must be between -1.0 and 1.0"
        case .invalidLFOAmount(let amount):
            return "Invalid LFO amount: \(amount). Must be between -1.0 and 1.0"
        }
    }
} 