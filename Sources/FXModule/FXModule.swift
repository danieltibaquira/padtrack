// FXModule.swift
// DigitonePad - FXModule

import Foundation
import MachineProtocols
import AudioEngine

/// Base effects processor implementation
public class FXProcessor: FXProcessorProtocol {
    public let id = UUID()
    public var name: String
    public var isEnabled: Bool = true
    public var wetLevel: Float = 0.5
    public var dryLevel: Float = 0.5
    public var isBypassed: Bool = false
    
    public init(name: String) {
        self.name = name
    }
    
    public func process(input: AudioBuffer) -> AudioBuffer {
        // TODO: Implement effects processing
        return input
    }
    
    public func reset() {
        // TODO: Reset effects state
    }
} 