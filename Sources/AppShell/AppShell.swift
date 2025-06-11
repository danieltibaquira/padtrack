// AppShell.swift
// DigitonePad - AppShell

import Foundation
import DataLayer
import AudioEngine
import SequencerModule
import VoiceModule
import FilterModule
import FXModule
import MIDIModule
import UIComponents
import MachineProtocols

/// Main application coordinator
public class AppShell {
    public static let shared = AppShell()
    
    private init() {}
    
    /// Initialize the entire application
    public func initialize() {
        DataLayerManager.shared.initialize()
        MIDIManager.shared.initialize()
        
        do {
            try AudioEngine.shared.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    /// Shutdown the application
    public func shutdown() {
        AudioEngine.shared.stop()
        Sequencer.shared.stop()
    }
    
    /// Get current app version
    public var version: String {
        return "1.0.0"
    }
} 