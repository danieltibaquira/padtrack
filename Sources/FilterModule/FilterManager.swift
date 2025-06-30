// FilterManager.swift
// DigitonePad - FilterModule
//
// This module handles audio filtering operations.

import Foundation
import AudioEngine
import Accelerate
import simd

/// Main interface for filter operations
public final class FilterManager: @unchecked Sendable {
    public static let shared = FilterManager()
    
    public private(set) var isInitialized = false
    
    private init() {}
    
    /// Initialize the filter module
    public func initialize() {
        // Initialize filter components
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isInitialized = true
        }
    }
}

// MARK: - Keyboard Tracking Configuration

/// Configuration for keyboard tracking behavior
public struct KeyboardTrackingConfig: Sendable {
    public var trackingAmount: Float = 0.0      // -100% to +100% (negative = inverse tracking)
    public var referenceNote: UInt8 = 60       // C4 (MIDI note 60) as reference
    public var referenceFrequency: Float = 261.63  // C4 frequency in Hz
    public var trackingCurve: TrackingCurve = .linear
    public var velocitySensitivity: Float = 0.0    // 0.0 to 1.0
    public var trackingRange: ClosedRange<Float> = 20.0...20000.0  // Frequency limits
    
    public init() {}
    
    public init(trackingAmount: Float = 0.0, referenceNote: UInt8 = 60, referenceFrequency: Float = 261.63, trackingCurve: TrackingCurve = .linear, velocitySensitivity: Float = 0.0, trackingRange: ClosedRange<Float> = 20.0...20000.0) {
        self.trackingAmount = trackingAmount
        self.referenceNote = referenceNote
        self.referenceFrequency = referenceFrequency
        self.trackingCurve = trackingCurve
        self.velocitySensitivity = velocitySensitivity
        self.trackingRange = trackingRange
    }
}

/// Tracking curve types for different musical behaviors
public enum TrackingCurve: CaseIterable, Codable, Sendable {
    case linear      // Direct 1:1 tracking
    case exponential // Exponential curve for more dramatic high-end tracking
    case logarithmic // Logarithmic curve for subtle high-end tracking
    case sCurve      // S-curve for smooth transitions
}

// MARK: - Keyboard Tracking Parameters

/// Real-time parameters for keyboard tracking modulation
public struct KeyboardTrackingParameters {
    public var currentNote: UInt8 = 60          // Currently played MIDI note
    public var velocity: UInt8 = 100            // MIDI velocity (0-127)
    public var pitchBend: Float = 0.0           // Pitch bend amount (-1.0 to +1.0)
    public var isNoteActive: Bool = false       // Whether a note is currently pressed
    public var portamentoTime: Float = 0.0     // Glide time between notes
    
    public init() {}
}

// MARK: - Keyboard Tracking Engine

/// High-performance keyboard tracking processor for filter cutoff control
public class KeyboardTrackingEngine {
    
    // MARK: - Configuration
    public var config = KeyboardTrackingConfig()
    public var parameters = KeyboardTrackingParameters()
    
    // MARK: - Internal State
    private var currentTrackingFrequency: Float = 261.63  // Current tracked frequency
    private var smoothedFrequency: Float = 261.63         // Smoothed for portamento
    private var previousNote: UInt8 = 60                  // For portamento calculation
    private var portamentoPhase: Float = 1.0              // Portamento progress (0.0-1.0)
    
    public init() {}
    
    // MARK: - Public Interface
    
    /// Calculate the tracked cutoff frequency based on current MIDI input
    public func calculateTrackedFrequency(baseCutoff: Float) -> Float {
        
        guard parameters.isNoteActive else {
            // No note active - return base cutoff
            return baseCutoff
        }
        
        // Calculate note offset from reference
        let noteOffset = Float(parameters.currentNote) - Float(config.referenceNote)
        
        // Apply pitch bend
        let adjustedNoteOffset = noteOffset + (parameters.pitchBend * 2.0) // ±2 semitones bend range
        
        // Calculate frequency ratio based on tracking curve
        let frequencyRatio = calculateFrequencyRatio(noteOffset: adjustedNoteOffset)
        
        // Apply tracking amount (with negative tracking support)
        let trackingMultiplier = 1.0 + (config.trackingAmount * 0.01 * (frequencyRatio - 1.0))
        
        // Calculate base tracked frequency
        var trackedFrequency = baseCutoff * trackingMultiplier
        
        // Apply velocity sensitivity
        if config.velocitySensitivity > 0.0 {
            let velocityFactor = Float(parameters.velocity) / 127.0
            let velocityModulation = 1.0 + (config.velocitySensitivity * (velocityFactor - 0.5) * 2.0)
            trackedFrequency *= velocityModulation
        }
        
        // Clamp to tracking range
        trackedFrequency = max(config.trackingRange.lowerBound, 
                              min(config.trackingRange.upperBound, trackedFrequency))
        
        // Update internal tracking state
        currentTrackingFrequency = trackedFrequency
        
        // Apply portamento if enabled
        if config.trackingAmount > 0.0 && parameters.portamentoTime > 0.0 {
            return applyPortamento(targetFrequency: trackedFrequency)
        }
        
        return trackedFrequency
    }
    
    /// Process a MIDI note on event
    public func noteOn(note: UInt8, velocity: UInt8) {
        previousNote = parameters.currentNote
        parameters.currentNote = note
        parameters.velocity = velocity
        parameters.isNoteActive = true
        portamentoPhase = 0.0  // Reset portamento
    }
    
    /// Process a MIDI note off event
    public func noteOff(note: UInt8) {
        if note == parameters.currentNote {
            parameters.isNoteActive = false
        }
    }
    
    /// Process pitch bend change
    public func pitchBend(amount: Float) {
        parameters.pitchBend = max(-1.0, min(1.0, amount))
    }
    
    /// Update portamento time (in seconds)
    public func setPortamentoTime(_ time: Float) {
        parameters.portamentoTime = max(0.0, min(5.0, time))  // 0-5 second range
    }
    
    // MARK: - Frequency Calculation Methods
    
    /// Calculate frequency ratio based on note offset and tracking curve
    private func calculateFrequencyRatio(noteOffset: Float) -> Float {
        
        // Base frequency ratio (semitone = 2^(1/12))
        let baseRatio = pow(2.0, noteOffset / 12.0)
        
        switch config.trackingCurve {
        case .linear:
            return baseRatio
            
        case .exponential:
            // Exponential curve - more dramatic for higher notes
            let normalizedOffset = noteOffset / 48.0  // Normalize to ±4 octaves
            let curveAmount = 1.0 + (normalizedOffset * abs(normalizedOffset) * 0.5)
            return baseRatio * curveAmount
            
        case .logarithmic:
            // Logarithmic curve - subtle for higher notes
            let normalizedOffset = noteOffset / 48.0
            let curveAmount = 1.0 + (sign(normalizedOffset) * log(1.0 + abs(normalizedOffset)) * 0.3)
            return baseRatio * curveAmount
            
        case .sCurve:
            // S-curve using tanh for smooth transitions
            let normalizedOffset = noteOffset / 24.0  // Normalize to ±2 octaves
            let curveAmount = 1.0 + (tanh(normalizedOffset * 2.0) * 0.4)
            return baseRatio * curveAmount
        }
    }
    
    /// Apply portamento (glide) between notes
    private func applyPortamento(targetFrequency: Float, sampleRate: Float = 44100.0) -> Float {
        
        guard parameters.portamentoTime > 0.0 && portamentoPhase < 1.0 else {
            smoothedFrequency = targetFrequency
            return targetFrequency
        }
        
        // Calculate portamento increment per sample
        let portamentoIncrement = 1.0 / (parameters.portamentoTime * sampleRate)
        portamentoPhase = min(1.0, portamentoPhase + portamentoIncrement)
        
        // Apply smooth curve (exponential for natural feel)
        let curvePhase = 1.0 - exp(-portamentoPhase * 4.0)
        
        // Interpolate frequencies (logarithmic interpolation for musical behavior)
        let startFreq = smoothedFrequency
        let logStart = log(startFreq)
        let logTarget = log(targetFrequency)
        let logResult = logStart + (logTarget - logStart) * curvePhase
        
        smoothedFrequency = exp(logResult)
        return smoothedFrequency
    }
    
    // MARK: - Analysis and Utilities
    
    /// Get current tracking information for debugging/display
    public func getTrackingInfo() -> TrackingInfo {
        return TrackingInfo(
            currentNote: parameters.currentNote,
            referenceNote: config.referenceNote,
            noteOffset: Float(parameters.currentNote) - Float(config.referenceNote),
            trackingAmount: config.trackingAmount,
            currentFrequency: currentTrackingFrequency,
            isActive: parameters.isNoteActive,
            portamentoPhase: portamentoPhase
        )
    }
    
    /// Convert MIDI note to frequency (for reference)
    public static func midiNoteToFrequency(_ note: UInt8) -> Float {
        let noteFloat = Float(note)
        return 440.0 * pow(2.0, (noteFloat - 69.0) / 12.0)  // A4 = 440Hz = MIDI note 69
    }
    
    /// Convert frequency to nearest MIDI note (for display)
    public static func frequencyToMidiNote(_ frequency: Float) -> UInt8 {
        let noteFloat = 69.0 + 12.0 * log2(frequency / 440.0)
        return UInt8(max(0, min(127, round(noteFloat))))
    }
    
    /// Reset all tracking state
    public func reset() {
        parameters.isNoteActive = false
        parameters.currentNote = config.referenceNote
        parameters.velocity = 100
        parameters.pitchBend = 0.0
        currentTrackingFrequency = config.referenceFrequency
        smoothedFrequency = config.referenceFrequency
        portamentoPhase = 1.0
    }
}

// MARK: - Tracking Information Structure

/// Structure containing current tracking state information
public struct TrackingInfo {
    public let currentNote: UInt8
    public let referenceNote: UInt8
    public let noteOffset: Float
    public let trackingAmount: Float
    public let currentFrequency: Float
    public let isActive: Bool
    public let portamentoPhase: Float
    
    /// Generate a human-readable description
    public var description: String {
        let noteName = noteNumberToName(currentNote)
        let refName = noteNumberToName(referenceNote)
        let direction = trackingAmount >= 0 ? "positive" : "negative"
        
        return """
        Keyboard Tracking Info:
        Current Note: \(noteName) (MIDI \(currentNote))
        Reference: \(refName) (MIDI \(referenceNote))
        Offset: \(noteOffset > 0 ? "+" : "")\(String(format: "%.1f", noteOffset)) semitones
        Tracking: \(String(format: "%.1f", abs(trackingAmount)))% (\(direction))
        Frequency: \(String(format: "%.2f", currentFrequency)) Hz
        Active: \(isActive ? "Yes" : "No")
        Portamento: \(String(format: "%.1f", portamentoPhase * 100))% complete
        """
    }
    
    /// Convert MIDI note number to note name
    private func noteNumberToName(_ note: UInt8) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(note) / 12 - 1
        let noteIndex = Int(note) % 12
        return "\(noteNames[noteIndex])\(octave)"
    }
}

// MARK: - Preset Configurations

extension KeyboardTrackingConfig {
    
    /// Common tracking presets for different musical styles
    public static let trackingPresets: [String: KeyboardTrackingConfig] = [
        "Off": KeyboardTrackingConfig(trackingAmount: 0.0),
        
        "Subtle": KeyboardTrackingConfig(
            trackingAmount: 25.0,
            trackingCurve: .linear,
            velocitySensitivity: 0.1
        ),
        
        "Standard": KeyboardTrackingConfig(
            trackingAmount: 50.0,
            trackingCurve: .linear,
            velocitySensitivity: 0.2
        ),
        
        "Full": KeyboardTrackingConfig(
            trackingAmount: 100.0,
            trackingCurve: .linear,
            velocitySensitivity: 0.3
        ),
        
        "Inverse": KeyboardTrackingConfig(
            trackingAmount: -50.0,
            trackingCurve: .linear,
            velocitySensitivity: 0.1
        ),
        
        "Exponential": KeyboardTrackingConfig(
            trackingAmount: 75.0,
            trackingCurve: .exponential,
            velocitySensitivity: 0.4
        ),
        
        "Smooth": KeyboardTrackingConfig(
            trackingAmount: 60.0,
            trackingCurve: .sCurve,
            velocitySensitivity: 0.25
        )
    ]
    
    /// Load a preset configuration
    public mutating func loadPreset(_ presetName: String) {
        if let preset = Self.trackingPresets[presetName] {
            self = preset
        }
    }
} 