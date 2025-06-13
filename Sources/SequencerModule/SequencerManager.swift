// SequencerManager.swift
// DigitonePad - SequencerModule
//
// This module handles sequencing and pattern playback.

import Foundation
import DataLayer

/// Main interface for sequencer operations
public class SequencerManager {
    public static let shared = SequencerManager()
    
    public private(set) var isInitialized = false
    
    private init() {}
    
    /// Initialize the sequencer
    public func initialize() {
        // Initialize sequencer components
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isInitialized = true
        }
    }
} 