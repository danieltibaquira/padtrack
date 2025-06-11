// UIComponents.swift
// DigitonePad - UIComponents

import Foundation
import MachineProtocols

/// Base component for DigitonePad UI elements
public protocol DigitonePadComponent {
    var isEnabled: Bool { get set }
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
    
    public init(value: Float = 0.0, range: ClosedRange<Float> = 0...1) {
        self.value = value
        self.range = range
    }
} 