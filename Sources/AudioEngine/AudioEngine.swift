// AudioEngine.swift
// DigitonePad - AudioEngine
//
// This module handles audio processing and playback.

import Foundation
import AVFoundation
import MachineProtocols

/// Main interface for audio operations
@objc public final class AudioEngineManager: NSObject, @unchecked Sendable {
    @objc public static let shared = AudioEngineManager()
    
    private let engine = AVAudioEngine()
    
    private override init() {
        super.init()
    }
    
    /// Initialize the audio engine
    @objc public func initialize() {
        // TODO: Setup audio engine nodes and connections
    }
    
    /// Start the audio engine
    @objc public func start() throws {
        try engine.start()
    }
    
    /// Stop the audio engine
    @objc public func stop() {
        engine.stop()
    }
} 