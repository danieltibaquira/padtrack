// KeyboardTrackingIntegrationTests.swift
// DigitonePad - FilterModuleTests
//
// Comprehensive test suite for Keyboard Tracking Integration

import XCTest
import MachineProtocols
@testable import FilterModule

final class KeyboardTrackingIntegrationTests: XCTestCase {
    
    var integrationManager: KeyboardTrackingIntegrationManager!
    var mockFilter: MockFilterMachine!
    var filterBridge: FilterKeyboardTrackingBridge!
    
    override func setUp() {
        super.setUp()
        integrationManager = KeyboardTrackingIntegrationManager()
        mockFilter = MockFilterMachine()
        filterBridge = FilterKeyboardTrackingBridge(filterMachine: mockFilter, baseCutoff: 1000.0)
    }
    
    override func tearDown() {
        integrationManager = nil
        mockFilter = nil
        filterBridge = nil
        super.tearDown()
    }
    
    // MARK: - Integration Manager Tests
    
    func testIntegrationManagerInitialization() {
        XCTAssertNotNil(integrationManager)
        XCTAssertEqual(integrationManager.registeredEngineIDs.count, 0)
        XCTAssertEqual(integrationManager.globalConfig.trackingAmount, 0.0)
    }
    
    func testEngineRegistration() {
        let engineID = "test_engine"
        integrationManager.registerTrackingEngine(id: engineID)
        
        XCTAssertTrue(integrationManager.registeredEngineIDs.contains(engineID))
        XCTAssertNotNil(integrationManager.getTrackingEngine(id: engineID))
    }
    
    func testEngineUnregistration() {
        let engineID = "test_engine"
        integrationManager.registerTrackingEngine(id: engineID)
        integrationManager.unregisterTrackingEngine(id: engineID)
        
        XCTAssertFalse(integrationManager.registeredEngineIDs.contains(engineID))
        XCTAssertNil(integrationManager.getTrackingEngine(id: engineID))
    }
    
    func testVoiceAssociation() {
        let engineID = "test_engine"
        let voiceID = "test_voice"
        
        integrationManager.registerTrackingEngine(id: engineID)
        integrationManager.associateVoice(voiceID: voiceID, withTrackingEngine: engineID)
        
        XCTAssertEqual(integrationManager.getTrackingEngineID(forVoice: voiceID), engineID)
    }
    
    func testVoiceDisassociation() {
        let engineID = "test_engine"
        let voiceID = "test_voice"
        
        integrationManager.registerTrackingEngine(id: engineID)
        integrationManager.associateVoice(voiceID: voiceID, withTrackingEngine: engineID)
        integrationManager.disassociateVoice(voiceID: voiceID)
        
        XCTAssertNil(integrationManager.getTrackingEngineID(forVoice: voiceID))
    }
    
    func testMIDINoteOnProcessing() {
        let engineID = "test_engine"
        integrationManager.registerTrackingEngine(id: engineID)
        
        // Set up tracking
        var config = KeyboardTrackingConfig()
        config.trackingAmount = 100.0
        integrationManager.updateEngineConfig(engineID: engineID, config: config)
        
        // Process MIDI note on
        integrationManager.processMIDINoteOn(note: 72, velocity: 100, channel: 0)
        
        // Check that tracking was updated
        let trackedCutoff = integrationManager.calculateTrackedCutoff(engineID: engineID, baseCutoff: 1000.0)
        XCTAssertGreaterThan(trackedCutoff, 1000.0, "Higher note should increase cutoff with positive tracking")
    }
    
    func testGlobalConfigUpdate() {
        let engineID1 = "engine1"
        let engineID2 = "engine2"
        
        integrationManager.registerTrackingEngine(id: engineID1)
        integrationManager.registerTrackingEngine(id: engineID2)
        
        // Update global config
        var newConfig = KeyboardTrackingConfig()
        newConfig.trackingAmount = 75.0
        integrationManager.updateGlobalConfig(newConfig)
        
        // Check that both engines were updated
        XCTAssertEqual(integrationManager.getTrackingEngine(id: engineID1)?.config.trackingAmount, 75.0)
        XCTAssertEqual(integrationManager.getTrackingEngine(id: engineID2)?.config.trackingAmount, 75.0)
    }
    
    // MARK: - Filter Bridge Tests
    
    func testFilterBridgeInitialization() {
        XCTAssertNotNil(filterBridge)
        XCTAssertEqual(filterBridge.baseCutoff, 1000.0)
        XCTAssertTrue(filterBridge.isTrackingEnabled)
        XCTAssertEqual(filterBridge.trackingConfig.trackingAmount, 50.0) // Default
    }
    
    func testFilterBridgeNoteOn() {
        // Set up tracking
        filterBridge.setTrackingAmount(100.0)
        
        // Process note on
        filterBridge.noteOn(note: 72, velocity: 100) // C5 (one octave up)
        
        // Check that filter cutoff was updated
        XCTAssertEqual(mockFilter.cutoff, 2000.0, accuracy: 10.0, "One octave up should double cutoff")
        XCTAssertTrue(mockFilter.updateFilterCoefficientsCalled, "Filter coefficients should be updated")
    }
    
    func testFilterBridgeNoteOff() {
        // Set up tracking and trigger note
        filterBridge.setTrackingAmount(100.0)
        filterBridge.noteOn(note: 72, velocity: 100)
        
        // Reset mock state
        mockFilter.updateFilterCoefficientsCalled = false
        
        // Process note off
        filterBridge.noteOff(note: 72)
        
        // Check that filter was updated (should return to base cutoff)
        XCTAssertEqual(mockFilter.cutoff, 1000.0, accuracy: 10.0, "Note off should return to base cutoff")
        XCTAssertTrue(mockFilter.updateFilterCoefficientsCalled, "Filter coefficients should be updated")
    }
    
    func testFilterBridgeTrackingDisabled() {
        // Disable tracking
        filterBridge.isTrackingEnabled = false
        filterBridge.setTrackingAmount(100.0)
        
        // Process note on
        filterBridge.noteOn(note: 72, velocity: 100)
        
        // Check that filter cutoff was not changed
        XCTAssertEqual(mockFilter.cutoff, 1000.0, "Disabled tracking should not change cutoff")
    }
    
    func testFilterBridgeBaseCutoffChange() {
        filterBridge.setTrackingAmount(100.0)
        filterBridge.noteOn(note: 72, velocity: 100) // C5
        
        // Change base cutoff
        filterBridge.baseCutoff = 2000.0
        
        // Check that tracked cutoff updated proportionally
        XCTAssertEqual(mockFilter.cutoff, 4000.0, accuracy: 20.0, "Base cutoff change should update tracked cutoff")
    }
    
    func testFilterBridgePresetApplication() {
        filterBridge.applyPreset("Full")
        
        XCTAssertEqual(filterBridge.trackingConfig.trackingAmount, 100.0, "Full preset should set 100% tracking")
        
        filterBridge.applyPreset("Off")
        
        XCTAssertEqual(filterBridge.trackingConfig.trackingAmount, 0.0, "Off preset should set 0% tracking")
    }
    
    func testFilterBridgeVelocitySensitivity() {
        filterBridge.setTrackingAmount(100.0)
        filterBridge.setVelocitySensitivity(0.5)
        
        // Test low velocity
        filterBridge.noteOn(note: 60, velocity: 64) // Half velocity
        let lowVelCutoff = mockFilter.cutoff
        
        // Test high velocity
        filterBridge.noteOn(note: 60, velocity: 127) // Full velocity
        let highVelCutoff = mockFilter.cutoff
        
        XCTAssertGreaterThan(highVelCutoff, lowVelCutoff, "Higher velocity should increase cutoff")
    }
    
    // MARK: - Voice Machine Integration Tests
    
    func testVoiceMachineFilterIntegration() {
        let mockVoice = MockVoiceMachine()
        let integration = VoiceMachineFilterTrackingIntegration(voiceMachine: mockVoice)
        
        // Add a filter
        integration.addFilter(mockFilter, id: "main_filter", baseCutoff: 1500.0)
        
        XCTAssertTrue(integration.filterIDs.contains("main_filter"))
        XCTAssertNotNil(integration.getFilterBridge(id: "main_filter"))
    }
    
    func testVoiceMachineFilterNoteProcessing() {
        let mockVoice = MockVoiceMachine()
        let integration = VoiceMachineFilterTrackingIntegration(voiceMachine: mockVoice)
        
        // Add filter with tracking
        integration.addFilter(mockFilter, id: "main_filter", baseCutoff: 1000.0)
        integration.setTrackingAmount(100.0, forFilter: "main_filter")
        
        // Process note on
        integration.noteOn(note: 72, velocity: 100) // C5
        
        // Check that filter was updated
        XCTAssertEqual(mockFilter.cutoff, 2000.0, accuracy: 10.0, "Integration should update filter cutoff")
    }
    
    func testVoiceMachineFilterMultipleFilters() {
        let mockVoice = MockVoiceMachine()
        let integration = VoiceMachineFilterTrackingIntegration(voiceMachine: mockVoice)
        let mockFilter2 = MockFilterMachine()
        
        // Add multiple filters
        integration.addFilter(mockFilter, id: "filter1", baseCutoff: 1000.0)
        integration.addFilter(mockFilter2, id: "filter2", baseCutoff: 2000.0)
        
        // Set different tracking amounts
        integration.setTrackingAmount(100.0, forFilter: "filter1")
        integration.setTrackingAmount(50.0, forFilter: "filter2")
        
        // Process note on
        integration.noteOn(note: 72, velocity: 100) // C5
        
        // Check that both filters were updated with different amounts
        XCTAssertEqual(mockFilter.cutoff, 2000.0, accuracy: 10.0, "Filter 1 should have full tracking")
        XCTAssertEqual(mockFilter2.cutoff, 3000.0, accuracy: 20.0, "Filter 2 should have half tracking")
    }
    
    // MARK: - Performance Tests
    
    func testFilterBridgePerformance() {
        filterBridge.setTrackingAmount(100.0)
        filterBridge.noteOn(note: 60, velocity: 100)
        
        measure {
            for _ in 0..<1000 {
                filterBridge.processSamples(sampleCount: 64)
            }
        }
    }
    
    func testIntegrationManagerPerformance() {
        // Register multiple engines
        for i in 0..<10 {
            integrationManager.registerTrackingEngine(id: "engine_\(i)")
        }
        
        measure {
            for _ in 0..<100 {
                integrationManager.processMIDINoteOn(note: 60, velocity: 100, channel: 0)
                integrationManager.processMIDINoteOff(note: 60, velocity: 0, channel: 0)
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testFilterBridgeWithNilFilter() {
        let bridgeWithNilFilter = FilterKeyboardTrackingBridge(filterMachine: nil, baseCutoff: 1000.0)
        
        // Should not crash
        bridgeWithNilFilter.noteOn(note: 72, velocity: 100)
        bridgeWithNilFilter.updateFilterCutoff()
        
        XCTAssertEqual(bridgeWithNilFilter.baseCutoff, 1000.0, "Should maintain base cutoff")
    }
    
    func testIntegrationManagerWithInvalidEngineID() {
        let invalidID = "nonexistent_engine"
        
        // Should not crash
        let cutoff = integrationManager.calculateTrackedCutoff(engineID: invalidID, baseCutoff: 1000.0)
        XCTAssertEqual(cutoff, 1000.0, "Should return base cutoff for invalid engine ID")
        
        let info = integrationManager.getTrackingInfo(engineID: invalidID)
        XCTAssertNil(info, "Should return nil for invalid engine ID")
    }
    
    func testFilterBridgeExtremeValues() {
        filterBridge.setTrackingAmount(100.0)
        
        // Test extreme MIDI notes
        filterBridge.noteOn(note: 0, velocity: 100) // Very low
        XCTAssertFalse(mockFilter.cutoff.isNaN, "Should handle extreme low note")
        XCTAssertFalse(mockFilter.cutoff.isInfinite, "Should handle extreme low note")
        
        filterBridge.noteOn(note: 127, velocity: 100) // Very high
        XCTAssertFalse(mockFilter.cutoff.isNaN, "Should handle extreme high note")
        XCTAssertFalse(mockFilter.cutoff.isInfinite, "Should handle extreme high note")
    }
}

// MARK: - Mock Objects

class MockFilterMachine: FilterMachineProtocol {
    var id = UUID()
    var name = "Mock Filter"
    var isEnabled = true
    var filterType: FilterType = .lowpass
    var slope: FilterSlope = .slope24dB
    var quality: FilterQuality = .medium
    var isActive = true
    var cutoff: Float = 1000.0
    var resonance: Float = 0.5
    var drive: Float = 0.0
    var gain: Float = 0.0
    var bandwidth: Float = 100.0
    var keyTracking: Float = 0.0
    var velocitySensitivity: Float = 0.0
    var envelopeAmount: Float = 0.0
    var lfoAmount: Float = 0.0
    var modulationAmount: Float = 0.0
    var lastActiveTimestamp = Date()
    var lastError: (any Error)?
    var performanceMetrics = FilterPerformanceMetrics()
    var parameters = ParameterManager()
    var status: MachineStatus = .ready
    
    var updateFilterCoefficientsCalled = false
    
    func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        return input
    }
    
    func reset() {}
    
    func getFrequencyResponse(at frequency: Float) -> FilterResponse {
        return FilterResponse(magnitude: 1.0, phase: 0.0, frequency: frequency)
    }
    
    func saveFilterPreset(name: String) -> FilterPreset {
        return FilterPreset(name: name, filterType: filterType, cutoff: cutoff, resonance: resonance, drive: drive, slope: slope, quality: quality, gain: gain, bandwidth: bandwidth, keyTracking: keyTracking, velocitySensitivity: velocitySensitivity, envelopeAmount: envelopeAmount, lfoAmount: lfoAmount, modulationAmount: modulationAmount)
    }
    
    func updateFilterCoefficients() {
        updateFilterCoefficientsCalled = true
    }
    
    func setCutoffWithKeyTracking(baseFreq: Float, note: UInt8, velocity: UInt8) {
        cutoff = baseFreq
        updateFilterCoefficients()
    }
    
    func modulateFilter(cutoffMod: Float, resonanceMod: Float) {
        cutoff *= (1.0 + cutoffMod)
        resonance += resonanceMod
        updateFilterCoefficients()
    }
}

class MockVoiceMachine: VoiceMachine {
    override init(name: String = "Mock Voice", polyphony: Int = 16) {
        super.init(name: name, polyphony: polyphony)
    }
    
    override func process(input: AudioEngine.AudioBuffer) -> AudioEngine.AudioBuffer {
        return input
    }
}
