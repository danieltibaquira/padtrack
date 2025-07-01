// MIDIPresenter.swift
// DigitonePad - MIDIModule
//
// VIPER Presenter for MIDI functionality

import Foundation
import MachineProtocols

/// Presenter that handles MIDI presentation logic and mediates between View and Interactor
@MainActor
public final class MIDIPresenter: MIDIPresenterProtocol, MIDIInteractorOutputProtocol {
    public weak var view: MIDIViewProtocol?
    public var interactor: MIDIInteractorProtocol?
    public var router: MIDIRouterProtocol?
    
    // MARK: - State
    private var discoveredDevices: [MIDIDevice] = []
    private var connectionStatus: MIDIConnectionStatus = .disconnected
    
    public init() {}
    
    // MARK: - MIDIPresenterProtocol
    
    public func viewDidLoad() {
        refreshMIDIDevices()
    }
    
    public func refreshMIDIDevices() {
        // For now, just show empty list - actual implementation would call interactor
        view?.showMIDIDevices([])
    }
    
    public func connectToDevice(_ device: MIDIDevice) {
        // For now, just update status - actual implementation would call interactor
        connectionStatus = .connected
        view?.showMIDIConnection(status: .connected)
    }
    
    public func disconnectFromDevice(_ device: MIDIDevice) {
        // For now, just update status - actual implementation would call interactor
        connectionStatus = .disconnected
        view?.showMIDIConnection(status: .disconnected)
    }
    
    public func sendMIDIMessage(_ message: MIDIMessage) {
        // For now, just a placeholder - actual implementation would call interactor
    }
    
    public func handleMIDIReceived(_ message: MIDIMessage) {
        view?.showMIDIActivity(message: message)
    }
    
    public func handleConnectionStatusChanged(_ status: MIDIConnectionStatus) {
        connectionStatus = status
        view?.showMIDIConnection(status: status)
    }
    
    public func handleError(_ error: MIDIError) {
        view?.showError(error)
    }

    // MARK: - MIDIInteractorOutputProtocol

    public func didInitializeMIDI() {
        // Handle MIDI initialization completion
    }

    public func didDiscoverMIDIDevices(_ devices: [MIDIDevice]) {
        discoveredDevices = devices
        view?.showMIDIDevices(devices)
    }

    public func didConnectToDevice(_ device: MIDIDevice) {
        connectionStatus = .connected
        view?.showMIDIConnection(status: .connected)
    }

    public func didDisconnectFromDevice(_ device: MIDIDevice) {
        connectionStatus = .disconnected
        view?.showMIDIConnection(status: .disconnected)
    }

    public func didReceiveMIDIMessage(_ message: MIDIMessage) {
        view?.showMIDIActivity(message: message)
    }

    public func didFailWithError(_ error: MIDIError) {
        view?.showError(error)
    }
}

 