// SequencerModule.swift
// DigitonePad - SequencerModule

import Foundation
import MachineProtocols
import DataLayer

/// Main sequencer for pattern playback
public final class Sequencer: @unchecked Sendable {
    public static let shared = Sequencer()
    private init() {}
    
    /// Start sequencer playback
    public func play() {
        // TODO: Implement sequencer playback
    }
    
    /// Stop sequencer playback
    public func stop() {
        // TODO: Stop sequencer
    }
} 