// FXManager.swift
// DigitonePad - FXModule
//
// This module handles audio effects processing.

import Foundation
import AudioEngine

/// Main interface for FX operations
public final class FXManager: @unchecked Sendable {
    public static let shared = FXManager()
    
    public private(set) var isInitialized = false
    
    private init() {}
    
    /// Initialize the FX module
    public func initialize() {
        // Initialize FX components
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            self.isInitialized = true
        }
    }
} 