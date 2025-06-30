// MIDIModule.swift
// DigitonePad - MIDIModule
//
// This module handles MIDI I/O and routing.

import Foundation
import CoreMIDI
import MachineProtocols

// MARK: - Public SwiftUI Interface

/// Main SwiftUI view for MIDI interaction
public typealias MIDIView = MIDISwiftUIView

/// Main interface for MIDI operations (legacy support)
public final class MIDIManager: @unchecked Sendable {
    public static let shared = MIDIManager()
    
    private let interactor: MIDIInteractor
    
    private init() {
        self.interactor = MIDIInteractor()
    }
    
    /// Initialize the MIDI module
    public func initialize() {
        interactor.initialize()
    }
    
    /// Send MIDI message
    public func sendMIDI(note: UInt8, velocity: UInt8, channel: UInt8) {
        let message = MIDIMessage(
            type: velocity > 0 ? .noteOn : .noteOff,
            channel: channel,
            data1: note,
            data2: velocity
        )
        interactor.sendMIDIMessage(message)
    }
    
    /// Set MIDI input handler
    public func setInputHandler(_ handler: @escaping (UInt8, UInt8, UInt8) -> Void) {
        interactor.setMIDIInputHandler { message in
            handler(message.data1, message.data2, message.channel)
        }
    }
    
    /// Discover available MIDI devices
    public func discoverDevices() {
        interactor.discoverMIDIDevices()
    }
    
    /// Connect to a MIDI device
    public func connect(to device: MIDIDevice) {
        interactor.connectToDevice(device)
    }
    
    /// Disconnect from a MIDI device
    public func disconnect(from device: MIDIDevice) {
        interactor.disconnectFromDevice(device)
    }
} 