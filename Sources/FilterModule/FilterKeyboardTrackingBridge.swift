// FilterKeyboardTrackingBridge.swift
// DigitonePad - FilterModule
//
// Bridge between keyboard tracking and filter implementations
// Provides seamless integration for real-time filter cutoff control

import Foundation
import MachineProtocols
import AudioEngine
import VoiceModule

// MARK: - Filter Keyboard Tracking Bridge

/// Bridge class that connects keyboard tracking with filter machines
public final class FilterKeyboardTrackingBridge: @unchecked Sendable {
    
    // MARK: - Core Components
    
    /// The filter machine being controlled
    public weak var filterMachine: FilterMachineProtocol?
    
    /// The keyboard tracking engine
    public let trackingEngine: KeyboardTrackingEngine
    
    /// Base cutoff frequency (without tracking)
    public var baseCutoff: Float {
        didSet {
            updateFilterCutoff()
        }
    }
    
    /// Whether tracking is enabled
    public var isTrackingEnabled: Bool = true {
        didSet {
            updateFilterCutoff()
        }
    }
    
    // MARK: - Configuration
    
    /// Tracking configuration
    public var trackingConfig: KeyboardTrackingConfig {
        get { trackingEngine.config }
        set { 
            trackingEngine.config = newValue
            updateFilterCutoff()
        }
    }
    
    /// Update rate for real-time tracking (samples)
    public var updateRate: Int = 64  // Update every 64 samples for efficiency
    
    // MARK: - Internal State
    
    private var sampleCounter: Int = 0
    private var lastTrackedCutoff: Float = 1000.0
    private var isInitialized: Bool = false
    
    // MARK: - Initialization
    
    public init(filterMachine: FilterMachineProtocol, baseCutoff: Float = 1000.0) {
        self.filterMachine = filterMachine
        self.baseCutoff = baseCutoff
        self.trackingEngine = KeyboardTrackingEngine()
        
        // Set up default tracking configuration
        setupDefaultConfiguration()
        
        self.isInitialized = true
        updateFilterCutoff()
    }
    
    // MARK: - MIDI Event Processing
    
    /// Process MIDI note on event
    public func noteOn(note: UInt8, velocity: UInt8, channel: UInt8 = 0) {
        trackingEngine.noteOn(note: note, velocity: velocity)
        updateFilterCutoff()
    }
    
    /// Process MIDI note off event
    public func noteOff(note: UInt8, channel: UInt8 = 0) {
        trackingEngine.noteOff(note: note)
        updateFilterCutoff()
    }
    
    /// Process pitch bend event
    public func pitchBend(amount: Float) {
        trackingEngine.pitchBend(amount: amount)
        updateFilterCutoff()
    }
    
    /// Process all notes off
    public func allNotesOff() {
        trackingEngine.reset()
        updateFilterCutoff()
    }
    
    // MARK: - Real-Time Processing
    
    /// Process audio samples and update tracking as needed
    public func processSamples(sampleCount: Int) {
        sampleCounter += sampleCount
        
        if sampleCounter >= updateRate {
            sampleCounter = 0
            updateFilterCutoff()
        }
    }
    
    /// Force immediate update of filter cutoff
    public func updateFilterCutoff() {
        guard isInitialized, isTrackingEnabled else { return }
        
        let trackedCutoff = trackingEngine.calculateTrackedFrequency(baseCutoff: baseCutoff)
        
        // Only update if there's a significant change to avoid unnecessary processing
        if abs(trackedCutoff - lastTrackedCutoff) > 0.1 {
            lastTrackedCutoff = trackedCutoff
            
            // Update the filter machine
            if let filter = filterMachine {
                filter.cutoff = trackedCutoff
                filter.updateFilterCoefficients()
            }
        }
    }
    
    // MARK: - Configuration Management
    
    /// Apply a tracking preset
    public func applyPreset(_ presetName: String) {
        trackingConfig.loadPreset(presetName)
        updateFilterCutoff()
    }
    
    /// Set tracking amount (0-100%)
    public func setTrackingAmount(_ amount: Float) {
        trackingConfig.trackingAmount = max(-100.0, min(100.0, amount))
        updateFilterCutoff()
    }
    
    /// Set tracking curve
    public func setTrackingCurve(_ curve: TrackingCurve) {
        trackingConfig.trackingCurve = curve
        updateFilterCutoff()
    }
    
    /// Set velocity sensitivity (0-1)
    public func setVelocitySensitivity(_ sensitivity: Float) {
        trackingConfig.velocitySensitivity = max(0.0, min(1.0, sensitivity))
        updateFilterCutoff()
    }
    
    /// Set reference note (MIDI note number)
    public func setReferenceNote(_ note: UInt8) {
        trackingConfig.referenceNote = note
        trackingConfig.referenceFrequency = KeyboardTrackingEngine.midiNoteToFrequency(note)
        updateFilterCutoff()
    }
    
    // MARK: - Information and Debugging
    
    /// Get current tracking information
    public func getTrackingInfo() -> TrackingInfo {
        return trackingEngine.getTrackingInfo()
    }
    
    /// Get current tracked cutoff frequency
    public var currentTrackedCutoff: Float {
        return lastTrackedCutoff
    }
    
    /// Check if tracking is currently active
    public var isTrackingActive: Bool {
        return isTrackingEnabled && trackingEngine.parameters.isNoteActive
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultConfiguration() {
        // Set up a reasonable default configuration
        trackingConfig.trackingAmount = 50.0  // 50% tracking
        trackingConfig.trackingCurve = .linear
        trackingConfig.velocitySensitivity = 0.2
        trackingConfig.referenceNote = 60  // C4
        trackingConfig.referenceFrequency = 261.63  // C4 frequency
    }
}

// MARK: - Enhanced Filter Machine Protocol Extension

/// Extension to FilterMachineProtocol for keyboard tracking integration
public extension FilterMachineProtocol {
    
    /// Create a keyboard tracking bridge for this filter
    func createKeyboardTrackingBridge(baseCutoff: Float? = nil) -> FilterKeyboardTrackingBridge {
        let cutoff = baseCutoff ?? self.cutoff
        return FilterKeyboardTrackingBridge(filterMachine: self, baseCutoff: cutoff)
    }
    
    /// Set up automatic keyboard tracking with default configuration
    func enableKeyboardTracking(amount: Float = 50.0, curve: TrackingCurve = .linear) -> FilterKeyboardTrackingBridge {
        let bridge = createKeyboardTrackingBridge()
        bridge.setTrackingAmount(amount)
        bridge.setTrackingCurve(curve)
        return bridge
    }
}

// MARK: - Voice Machine Filter Integration

/// Integration helper for voice machines with filters
public final class VoiceMachineFilterTrackingIntegration: @unchecked Sendable {
    
    // MARK: - Components
    
    /// The voice machine
    public weak var voiceMachine: VoiceMachine?
    
    /// Filter tracking bridges (one per filter)
    private var filterBridges: [String: FilterKeyboardTrackingBridge] = [:]
    
    /// Current MIDI state
    private var currentNote: UInt8 = 60
    private var currentVelocity: UInt8 = 100
    private var isNoteActive: Bool = false
    
    // MARK: - Initialization
    
    public init(voiceMachine: VoiceMachine) {
        self.voiceMachine = voiceMachine
    }
    
    // MARK: - Filter Management
    
    /// Add a filter for keyboard tracking
    public func addFilter(_ filter: FilterMachineProtocol, id: String, baseCutoff: Float? = nil) {
        let bridge = filter.createKeyboardTrackingBridge(baseCutoff: baseCutoff)
        filterBridges[id] = bridge
        
        // Apply current MIDI state if active
        if isNoteActive {
            bridge.noteOn(note: currentNote, velocity: currentVelocity)
        }
    }
    
    /// Remove a filter from tracking
    public func removeFilter(id: String) {
        filterBridges.removeValue(forKey: id)
    }
    
    /// Get a filter bridge by ID
    public func getFilterBridge(id: String) -> FilterKeyboardTrackingBridge? {
        return filterBridges[id]
    }
    
    /// Get all filter bridge IDs
    public var filterIDs: [String] {
        return Array(filterBridges.keys)
    }
    
    // MARK: - MIDI Integration
    
    /// Process note on for all filters
    public func noteOn(note: UInt8, velocity: UInt8, channel: UInt8 = 0) {
        currentNote = note
        currentVelocity = velocity
        isNoteActive = true
        
        for bridge in filterBridges.values {
            bridge.noteOn(note: note, velocity: velocity, channel: channel)
        }
    }
    
    /// Process note off for all filters
    public func noteOff(note: UInt8, channel: UInt8 = 0) {
        if note == currentNote {
            isNoteActive = false
        }
        
        for bridge in filterBridges.values {
            bridge.noteOff(note: note, channel: channel)
        }
    }
    
    /// Process pitch bend for all filters
    public func pitchBend(amount: Float) {
        for bridge in filterBridges.values {
            bridge.pitchBend(amount: amount)
        }
    }
    
    /// Process all notes off for all filters
    public func allNotesOff() {
        isNoteActive = false
        
        for bridge in filterBridges.values {
            bridge.allNotesOff()
        }
    }
    
    // MARK: - Real-Time Processing
    
    /// Process audio samples for all filter bridges
    public func processSamples(sampleCount: Int) {
        for bridge in filterBridges.values {
            bridge.processSamples(sampleCount: sampleCount)
        }
    }
    
    // MARK: - Configuration Management
    
    /// Apply preset to all filters
    public func applyPresetToAllFilters(_ presetName: String) {
        for bridge in filterBridges.values {
            bridge.applyPreset(presetName)
        }
    }
    
    /// Apply preset to specific filter
    public func applyPreset(_ presetName: String, toFilter filterID: String) {
        filterBridges[filterID]?.applyPreset(presetName)
    }
    
    /// Set tracking amount for all filters
    public func setTrackingAmountForAllFilters(_ amount: Float) {
        for bridge in filterBridges.values {
            bridge.setTrackingAmount(amount)
        }
    }
    
    /// Set tracking amount for specific filter
    public func setTrackingAmount(_ amount: Float, forFilter filterID: String) {
        filterBridges[filterID]?.setTrackingAmount(amount)
    }
    
    /// Enable/disable tracking for all filters
    public func setTrackingEnabledForAllFilters(_ enabled: Bool) {
        for bridge in filterBridges.values {
            bridge.isTrackingEnabled = enabled
        }
    }
    
    /// Enable/disable tracking for specific filter
    public func setTrackingEnabled(_ enabled: Bool, forFilter filterID: String) {
        filterBridges[filterID]?.isTrackingEnabled = enabled
    }
    
    // MARK: - Information
    
    /// Get tracking info for all filters
    public func getAllTrackingInfo() -> [String: TrackingInfo] {
        var info: [String: TrackingInfo] = [:]
        for (id, bridge) in filterBridges {
            info[id] = bridge.getTrackingInfo()
        }
        return info
    }
    
    /// Get tracking info for specific filter
    public func getTrackingInfo(forFilter filterID: String) -> TrackingInfo? {
        return filterBridges[filterID]?.getTrackingInfo()
    }
    
    /// Check if any filter has active tracking
    public var hasActiveTracking: Bool {
        return filterBridges.values.contains { $0.isTrackingActive }
    }
}
