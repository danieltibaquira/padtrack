// AppShell.swift
// DigitonePad - AppShell Module
//
// This module provides the main application shell and coordination.

import Foundation
import MachineProtocols
import DataLayer
import AudioEngine
import SequencerModule
import VoiceModule
import FilterModule
import FXModule
import MIDIModule
import UIComponents

/// Main application shell that coordinates all modules
public class AppShell {
    public static let shared = AppShell()
    
    private init() {}
    
    /// Initialize the entire application
    public func initialize() {
        // Initialize all core modules using their shared instances
        MIDIManager.shared.initialize()
        AudioEngineManager.shared.initialize()
        SequencerManager.shared.initialize()
        VoiceManager.shared.initialize()
        FilterManager.shared.initialize()
        FXManager.shared.initialize()
        
        // Start audio engine
        do {
            try AudioEngineManager.shared.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    /// Shutdown the application
    public func shutdown() {
        AudioEngineManager.shared.stop()
        // TODO: Add proper shutdown for other modules
    }
    
    /// Get current app version
    public var version: String {
        return "1.0.0"
    }
} 