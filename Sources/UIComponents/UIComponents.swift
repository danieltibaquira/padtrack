// UIComponents.swift
// DigitonePad - UIComponents

import Foundation
import MachineProtocols
import AudioEngine
import DataLayer
import SequencerModule
import VoiceModule
import FilterModule
import FXModule
import MIDIModule

/// Base protocol for all DigitonePad UI components
public protocol DigitonePadComponent {
    var isEnabled: Bool { get set }
}

/// Base component for DigitonePad UI elements
public struct UIComponent {
    public let id: String
    public let type: ComponentType
    
    public init(id: String, type: ComponentType) {
        self.id = id
        self.type = type
    }
}

public enum ComponentType {
    case button
    case knob
    case slider
    case display
}

/// Represents a parameter that can be controlled
public struct Parameter {
    public let name: String
    public let value: Double
    public let range: ClosedRange<Double>
    
    public init(name: String, value: Double, range: ClosedRange<Double>) {
        self.name = name
        self.value = value
        self.range = range
    }
}

/// Protocol for UI components that can be controlled
public protocol ControllableComponent {
    var parameter: Parameter { get set }
    mutating func updateValue(_ newValue: Double)
}

/// Basic knob component
public struct KnobComponent: ControllableComponent {
    public var parameter: Parameter
    
    public init(parameter: Parameter) {
        self.parameter = parameter
    }
    
    public mutating func updateValue(_ newValue: Double) {
        // Update parameter value within range
        let clampedValue = min(max(newValue, parameter.range.lowerBound), parameter.range.upperBound)
        parameter = Parameter(name: parameter.name, value: clampedValue, range: parameter.range)
    }
}

/// Basic button component
public struct ButtonComponent {
    public let id: String
    public let title: String
    public var isPressed: Bool = false
    
    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

/// A UI component that manages parameter values
public struct ParameterControl {
    public var parameter: Parameter
    public var isEnabled: Bool = true
    
    public init(parameter: Parameter) {
        self.parameter = parameter
    }
    
    /// Get the current parameter value as a percentage (0.0 to 1.0)
    public var normalizedValue: Double {
        let range = parameter.range
        return (parameter.value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
    
    /// Set the parameter value from a normalized value (0.0 to 1.0)
    public mutating func setNormalizedValue(_ normalizedValue: Double) {
        let range = parameter.range
        let clampedNormalized = min(max(normalizedValue, 0.0), 1.0)
        let newValue = range.lowerBound + (clampedNormalized * (range.upperBound - range.lowerBound))
        parameter = Parameter(name: parameter.name, value: newValue, range: parameter.range)
    }
    
    public mutating func updateValue(_ newValue: Double) {
        // Update parameter value within range
        let clampedValue = min(max(newValue, parameter.range.lowerBound), parameter.range.upperBound)
        parameter = Parameter(name: parameter.name, value: clampedValue, range: parameter.range)
    }
}

/// Basic button component interface
public struct DigitonePadButtonConfig: DigitonePadComponent {
    public var isEnabled: Bool = true
    public let title: String
    public let action: () -> Void
    
    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
}

/// Basic knob/rotary control interface
public struct DigitonePadKnobConfig: DigitonePadComponent {
    public var isEnabled: Bool = true
    public var value: Float
    public let range: ClosedRange<Float>
    public let label: String
    
    public init(label: String, value: Float, range: ClosedRange<Float>) {
        self.label = label
        self.value = value
        self.range = range
    }
}

public struct UIComponentsModule {
    public static let version = "1.0.0"
} 