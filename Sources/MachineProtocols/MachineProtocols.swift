// MachineProtocols.swift
// DigitonePad - MachineProtocols Module
//
// This module defines the core protocols that prevent circular dependencies
// between other modules in the DigitonePad application.

import Foundation

/// Base protocol for all audio processing machines
public protocol MachineProtocol {
    /// Unique identifier for the machine instance
    var id: UUID { get }
    
    /// Human-readable name for the machine
    var name: String { get }
    
    /// Whether the machine is currently active/enabled
    var isEnabled: Bool { get set }
    
    /// Process audio input and return processed output
    func process(input: AudioBuffer) -> AudioBuffer
    
    /// Reset the machine to its initial state
    func reset()
}

/// Protocol for voice/synthesis machines
public protocol VoiceMachineProtocol: MachineProtocol {
    /// Trigger a note with given parameters
    func noteOn(note: UInt8, velocity: UInt8)
    
    /// Release a note
    func noteOff(note: UInt8)
    
    /// Number of simultaneous voices supported
    var polyphony: Int { get }
}

/// Protocol for filter machines
public protocol FilterMachineProtocol: MachineProtocol {
    /// Filter cutoff frequency
    var cutoff: Float { get set }
    
    /// Filter resonance
    var resonance: Float { get set }
    
    /// Filter type/mode
    var filterType: FilterType { get set }
}

/// Protocol for effect machines
public protocol FXProcessorProtocol: MachineProtocol {
    /// Wet/dry mix control
    var wetLevel: Float { get set }
    
    /// Dry signal level
    var dryLevel: Float { get set }
    
    /// Bypass the effect processing
    var isBypassed: Bool { get set }
}

/// Basic audio buffer structure
public struct AudioBuffer {
    public let sampleRate: Double
    public let channelCount: Int
    public let frameCount: Int
    public let data: [Float]
    
    public init(sampleRate: Double, channelCount: Int, frameCount: Int, data: [Float]) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.frameCount = frameCount
        self.data = data
    }
}

/// Filter types enumeration
public enum FilterType: CaseIterable {
    case lowpass
    case highpass
    case bandpass
    case notch
    case allpass
}

/// Parameter types for machine configuration
public protocol ParameterProtocol {
    var value: Float { get set }
    var minValue: Float { get }
    var maxValue: Float { get }
    var defaultValue: Float { get }
    var name: String { get }
}

/// Basic parameter implementation
public struct Parameter: ParameterProtocol {
    public var value: Float
    public let minValue: Float
    public let maxValue: Float
    public let defaultValue: Float
    public let name: String
    
    public init(name: String, value: Float, minValue: Float, maxValue: Float, defaultValue: Float) {
        self.name = name
        self.value = value
        self.minValue = minValue
        self.maxValue = maxValue
        self.defaultValue = defaultValue
    }
} 