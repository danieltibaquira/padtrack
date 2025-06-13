// VoiceManager.swift
// DigitonePad - VoiceModule
//
// This module handles voice synthesis and management.

import Foundation
import AudioEngine

/// Main interface for voice operations
public final class VoiceManager: @unchecked Sendable {
    public static let shared = VoiceManager()
    
    public private(set) var isInitialized = false
    
    private init() {}
    
    /// Initialize the voice module
    public func initialize() {
        // Initialize voice components
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.isInitialized = true
        }
    }
} 