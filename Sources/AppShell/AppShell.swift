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
public final class AppShell: @unchecked Sendable {
    public static let shared = AppShell()
    
    private init() {}
    
    /// Initialize the entire application
    public func initialize() {
        // Initialize audio engine
        do {
            try AudioEngineManager.shared.initialize()
            try AudioEngineManager.shared.start()
        } catch {
            print("Failed to initialize/start audio engine: \(error)")
        }

        // TODO: Initialize other modules as they are implemented
        // - MIDI Module
        // - Sequencer Module
        // - Voice Module
        // - Filter Module
        // - FX Module
    }
    
    /// Shutdown the application
    public func shutdown() {
        do {
            try AudioEngineManager.shared.stop()
        } catch {
            print("Failed to stop audio engine: \(error)")
        }
        // TODO: Add proper shutdown for other modules
    }
    
    /// Get current app version
    public var version: String {
        return "1.0.0"
    }
} 