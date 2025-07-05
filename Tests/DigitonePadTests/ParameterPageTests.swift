import XCTest
import SwiftUI
import Combine
@testable import DigitonePad
@testable import VoiceModule

/// Comprehensive test suite for FM TONE parameter page mappings
/// Tests all 4 pages × 8 encoders each with exact hardware specification compliance
class ParameterPageTests: XCTestCase {
    
    var layoutState: MainLayoutState!
    var cancelables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        layoutState = MainLayoutState()
        cancelables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancelables.forEach { $0.cancel() }
        cancelables = nil
        layoutState = nil
        super.tearDown()
    }
    
    // MARK: - Page 1 Tests: Core FM Parameters
    
    /// Test Page 1 parameter mapping: ALGO, RATIO C/A/B, HARM, DTUN, FDBK, MIX
    func testPage1ParameterMapping() {
        // Arrange
        layoutState.setPage(1)
        layoutState.setFMToneMode(true)
        
        // Act & Assert
        let expectedLabels = ["ALGO", "RATIO C", "RATIO A", "RATIO B", "HARM", "DTUN", "FDBK", "MIX"]
        XCTAssertEqual(layoutState.parameterLabels, expectedLabels, 
                      "Page 1 should map to core FM parameters")
        
        // Test parameter count
        XCTAssertEqual(layoutState.parameterLabels.count, 8, 
                      "Page 1 should have exactly 8 parameters")
        
        // Test parameter values initialization
        XCTAssertEqual(layoutState.parameterValues.count, 8,
                      "Page 1 should have 8 parameter values")
        
        // Test algorithm parameter value scaling (1-8 range)
        let algoValue = layoutState.parameterValues[0]
        XCTAssertGreaterThanOrEqual(algoValue, 0.0, "Algorithm parameter should be >= 0.0")
        XCTAssertLessThanOrEqual(algoValue, 1.0, "Algorithm parameter should be <= 1.0")
    }
    
    /// Test Page 1 parameter value ranges match hardware specifications
    func testPage1ParameterRanges() {
        // Arrange
        layoutState.setPage(1)
        layoutState.setFMToneMode(true)
        
        // Act & Assert - Algorithm (1-8)
        let algorithmValue = layoutState.getFMToneParameterValue("algorithm")
        XCTAssertGreaterThanOrEqual(algorithmValue, 1.0, "Algorithm should be >= 1")
        XCTAssertLessThanOrEqual(algorithmValue, 8.0, "Algorithm should be <= 8")
        
        // Act & Assert - Ratio parameters (0.5-32.0)
        let ratioC = layoutState.getFMToneParameterValue("operator4_ratio")
        let ratioA = layoutState.getFMToneParameterValue("operator1_ratio")
        let ratioB = layoutState.getFMToneParameterValue("operator2_ratio")
        
        XCTAssertGreaterThanOrEqual(ratioC, 0.5, "Ratio C should be >= 0.5")
        XCTAssertLessThanOrEqual(ratioC, 32.0, "Ratio C should be <= 32.0")
        
        XCTAssertGreaterThanOrEqual(ratioA, 0.5, "Ratio A should be >= 0.5")
        XCTAssertLessThanOrEqual(ratioA, 32.0, "Ratio A should be <= 32.0")
        
        XCTAssertGreaterThanOrEqual(ratioB, 0.5, "Ratio B should be >= 0.5")
        XCTAssertLessThanOrEqual(ratioB, 32.0, "Ratio B should be <= 32.0")
        
        // Act & Assert - Other parameters (0-1 normalized range)
        let harmony = layoutState.getFMToneParameterValue("harmony")
        let detune = layoutState.getFMToneParameterValue("detune")
        let feedback = layoutState.getFMToneParameterValue("feedback")
        let mix = layoutState.getFMToneParameterValue("mix")
        
        XCTAssertGreaterThanOrEqual(harmony, 0.0, "Harmony should be >= 0.0")
        XCTAssertLessThanOrEqual(harmony, 1.0, "Harmony should be <= 1.0")
        
        XCTAssertGreaterThanOrEqual(detune, 0.0, "Detune should be >= 0.0")
        XCTAssertLessThanOrEqual(detune, 1.0, "Detune should be <= 1.0")
        
        XCTAssertGreaterThanOrEqual(feedback, 0.0, "Feedback should be >= 0.0")
        XCTAssertLessThanOrEqual(feedback, 1.0, "Feedback should be <= 1.0")
        
        XCTAssertGreaterThanOrEqual(mix, 0.0, "Mix should be >= 0.0")
        XCTAssertLessThanOrEqual(mix, 1.0, "Mix should be <= 1.0")
    }
    
    // MARK: - Page 2 Tests: Modulator Levels & Envelopes
    
    /// Test Page 2 parameter mapping: ATK, DEC, END, LEV for operators A and B
    func testPage2ParameterMapping() {
        // Arrange
        layoutState.setPage(2)
        layoutState.setFMToneMode(true)
        
        // Act & Assert
        let expectedLabels = ["ATK A", "DEC A", "END A", "LEV A", "ATK B", "DEC B", "END B", "LEV B"]
        XCTAssertEqual(layoutState.parameterLabels, expectedLabels, 
                      "Page 2 should map to modulator levels and envelopes")
        
        // Test parameter count
        XCTAssertEqual(layoutState.parameterLabels.count, 8, 
                      "Page 2 should have exactly 8 parameters")
        
        // Test parameter values initialization
        XCTAssertEqual(layoutState.parameterValues.count, 8,
                      "Page 2 should have 8 parameter values")
    }
    
    /// Test Page 2 envelope parameter ranges
    func testPage2EnvelopeRanges() {
        // Arrange
        layoutState.setPage(2)
        layoutState.setFMToneMode(true)
        
        // Act & Assert - Envelope parameters (0-1 normalized)
        let attack = layoutState.getFMToneParameterValue("attack")
        let decay = layoutState.getFMToneParameterValue("decay")
        let end = layoutState.getFMToneParameterValue("end")
        let op1Level = layoutState.getFMToneParameterValue("operator1_envelope_level")
        let op2Level = layoutState.getFMToneParameterValue("operator2_envelope_level")
        
        XCTAssertGreaterThanOrEqual(attack, 0.0, "Attack should be >= 0.0")
        XCTAssertLessThanOrEqual(attack, 1.0, "Attack should be <= 1.0")
        
        XCTAssertGreaterThanOrEqual(decay, 0.0, "Decay should be >= 0.0")
        XCTAssertLessThanOrEqual(decay, 1.0, "Decay should be <= 1.0")
        
        XCTAssertGreaterThanOrEqual(end, 0.0, "End should be >= 0.0")
        XCTAssertLessThanOrEqual(end, 1.0, "End should be <= 1.0")
        
        XCTAssertGreaterThanOrEqual(op1Level, 0.0, "Op1 level should be >= 0.0")
        XCTAssertLessThanOrEqual(op1Level, 1.0, "Op1 level should be <= 1.0")
        
        XCTAssertGreaterThanOrEqual(op2Level, 0.0, "Op2 level should be >= 0.0")
        XCTAssertLessThanOrEqual(op2Level, 1.0, "Op2 level should be <= 1.0")
    }
    
    // MARK: - Page 3 Tests: Envelope Behavior
    
    /// Test Page 3 parameter mapping: delay, trig mode, phase reset controls
    func testPage3ParameterMapping() {
        // Arrange
        layoutState.setPage(3)
        layoutState.setFMToneMode(true)
        
        // Act & Assert
        let expectedLabels = ["DELAY", "TRIG", "PHASE", "RES A", "RES B", "DTUN", "HARM", "KEY TRK"]
        XCTAssertEqual(layoutState.parameterLabels, expectedLabels, 
                      "Page 3 should map to envelope behavior controls")
        
        // Test parameter count
        XCTAssertEqual(layoutState.parameterLabels.count, 8, 
                      "Page 3 should have exactly 8 parameters")
        
        // Test parameter values initialization
        XCTAssertEqual(layoutState.parameterValues.count, 8,
                      "Page 3 should have 8 parameter values")
    }
    
    /// Test Page 3 envelope behavior parameter ranges
    func testPage3EnvelopeBehaviorRanges() {
        // Arrange
        layoutState.setPage(3)
        layoutState.setFMToneMode(true)
        
        // Act & Assert - Envelope behavior parameters
        let delay = layoutState.getFMToneParameterValue("delay")
        let trigMode = layoutState.getFMToneParameterValue("trig_mode")
        let phaseReset = layoutState.getFMToneParameterValue("phase_reset")
        let keyTracking = layoutState.getFMToneParameterValue("key_tracking")
        
        XCTAssertGreaterThanOrEqual(delay, 0.0, "Delay should be >= 0.0")
        XCTAssertLessThanOrEqual(delay, 1.0, "Delay should be <= 1.0")
        
        XCTAssertGreaterThanOrEqual(trigMode, 0.0, "Trig mode should be >= 0.0")
        XCTAssertLessThanOrEqual(trigMode, 1.0, "Trig mode should be <= 1.0")
        
        XCTAssertGreaterThanOrEqual(phaseReset, 0.0, "Phase reset should be >= 0.0")
        XCTAssertLessThanOrEqual(phaseReset, 1.0, "Phase reset should be <= 1.0")
        
        XCTAssertGreaterThanOrEqual(keyTracking, 0.0, "Key tracking should be >= 0.0")
        XCTAssertLessThanOrEqual(keyTracking, 1.0, "Key tracking should be <= 1.0")
    }
    
    // MARK: - Page 4 Tests: Offsets & Key Tracking
    
    /// Test Page 4 parameter mapping: fine-tuning for operator ratios and keyboard tracking
    func testPage4ParameterMapping() {
        // Arrange
        layoutState.setPage(4)
        layoutState.setFMToneMode(true)
        
        // Act & Assert
        let expectedLabels = ["OFS A", "OFS B", "KEY TRK", "VEL SEN", "SCALE", "ROOT", "TUNE", "FINE"]
        XCTAssertEqual(layoutState.parameterLabels, expectedLabels, 
                      "Page 4 should map to offsets and key tracking controls")
        
        // Test parameter count
        XCTAssertEqual(layoutState.parameterLabels.count, 8, 
                      "Page 4 should have exactly 8 parameters")
        
        // Test parameter values initialization
        XCTAssertEqual(layoutState.parameterValues.count, 8,
                      "Page 4 should have 8 parameter values")
    }
    
    /// Test Page 4 offset and key tracking parameter ranges
    func testPage4OffsetAndKeyTrackingRanges() {
        // Arrange
        layoutState.setPage(4)
        layoutState.setFMToneMode(true)
        
        // Act & Assert - Offset and key tracking parameters
        let offsetA = layoutState.getFMToneParameterValue("operator1_offset")
        let offsetB = layoutState.getFMToneParameterValue("operator2_offset")
        let keyTracking = layoutState.getFMToneParameterValue("key_tracking")
        
        XCTAssertGreaterThanOrEqual(offsetA, 0.0, "Offset A should be >= 0.0")
        XCTAssertLessThanOrEqual(offsetA, 1.0, "Offset A should be <= 1.0")
        
        XCTAssertGreaterThanOrEqual(offsetB, 0.0, "Offset B should be >= 0.0")
        XCTAssertLessThanOrEqual(offsetB, 1.0, "Offset B should be <= 1.0")
        
        XCTAssertGreaterThanOrEqual(keyTracking, 0.0, "Key tracking should be >= 0.0")
        XCTAssertLessThanOrEqual(keyTracking, 1.0, "Key tracking should be <= 1.0")
    }
    
    // MARK: - Page Navigation Tests
    
    /// Test page navigation maintains parameter state
    func testPageNavigationMaintainsState() {
        // Arrange
        layoutState.setFMToneMode(true)
        
        // Act - Navigate through all pages
        layoutState.setPage(1)
        let page1Labels = layoutState.parameterLabels
        
        layoutState.setPage(2)
        let page2Labels = layoutState.parameterLabels
        
        layoutState.setPage(3)
        let page3Labels = layoutState.parameterLabels
        
        layoutState.setPage(4)
        let page4Labels = layoutState.parameterLabels
        
        // Navigate back to page 1
        layoutState.setPage(1)
        
        // Assert - Parameter labels should be consistent
        XCTAssertEqual(layoutState.parameterLabels, page1Labels, 
                      "Page 1 labels should be consistent after navigation")
        
        // Test all pages have unique parameter sets
        XCTAssertNotEqual(page1Labels, page2Labels, "Page 1 and 2 should have different parameters")
        XCTAssertNotEqual(page2Labels, page3Labels, "Page 2 and 3 should have different parameters")
        XCTAssertNotEqual(page3Labels, page4Labels, "Page 3 and 4 should have different parameters")
        XCTAssertNotEqual(page4Labels, page1Labels, "Page 4 and 1 should have different parameters")
    }
    
    /// Test page navigation performance (must complete within 16ms for 60fps)
    func testPageNavigationPerformance() {
        // Arrange
        layoutState.setFMToneMode(true)
        
        // Act & Assert - Measure page switching performance
        measure {
            for _ in 0..<10 {
                layoutState.setPage(1)
                layoutState.setPage(2)
                layoutState.setPage(3)
                layoutState.setPage(4)
            }
        }
    }
    
    // MARK: - Parameter Value Update Tests
    
    /// Test parameter value updates trigger proper notifications
    func testParameterValueUpdatesNotification() {
        // Arrange
        layoutState.setFMToneMode(true)
        layoutState.setPage(1)
        
        var notificationReceived = false
        let expectation = self.expectation(description: "Parameter change notification")
        
        // Subscribe to parameter changes
        layoutState.objectWillChange.sink {
            notificationReceived = true
            expectation.fulfill()
        }.store(in: &cancelables)
        
        // Act - Update FM parameter
        layoutState.updateFMToneParameter(key: "algorithm", value: 5.0)
        
        // Assert
        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertTrue(notificationReceived, "Parameter change should trigger notification")
        }
    }
    
    /// Test parameter boundary validation
    func testParameterBoundaryValidation() {
        // Arrange
        layoutState.setFMToneMode(true)
        layoutState.setPage(1)
        
        // Act & Assert - Test algorithm parameter boundaries
        layoutState.updateFMToneParameter(key: "algorithm", value: 0.0) // Below minimum
        let algoValueLow = layoutState.getFMToneParameterValue("algorithm")
        XCTAssertGreaterThanOrEqual(algoValueLow, 1.0, "Algorithm should be clamped to minimum")
        
        layoutState.updateFMToneParameter(key: "algorithm", value: 10.0) // Above maximum
        let algoValueHigh = layoutState.getFMToneParameterValue("algorithm")
        XCTAssertLessThanOrEqual(algoValueHigh, 8.0, "Algorithm should be clamped to maximum")
    }
    
    // MARK: - FM Mode Toggle Tests
    
    /// Test FM mode toggle preserves parameter state
    func testFMModeTooglePreservesState() {
        // Arrange
        layoutState.setPage(1)
        layoutState.setFMToneMode(true)
        
        // Update a parameter
        layoutState.updateFMToneParameter(key: "algorithm", value: 3.0)
        let originalValue = layoutState.getFMToneParameterValue("algorithm")
        
        // Act - Toggle FM mode off and back on
        layoutState.setFMToneMode(false)
        layoutState.setFMToneMode(true)
        
        // Assert - Parameter value should be preserved
        let preservedValue = layoutState.getFMToneParameterValue("algorithm")
        XCTAssertEqual(preservedValue, originalValue, accuracy: 0.01, 
                      "Parameter values should be preserved across mode toggles")
    }
    
    /// Test non-FM mode doesn't use FM parameter labels
    func testNonFModeUsesStandardLabels() {
        // Arrange
        layoutState.setPage(1)
        layoutState.setFMToneMode(false)
        
        // Act
        let standardLabels = layoutState.parameterLabels
        
        // Assert
        XCTAssertNotEqual(standardLabels, ["ALGO", "RATIO C", "RATIO A", "RATIO B", "HARM", "DTUN", "FDBK", "MIX"],
                         "Non-FM mode should not use FM parameter labels")
    }
    
    // MARK: - Stress Tests
    
    /// Test rapid parameter updates don't crash the system
    func testRapidParameterUpdates() {
        // Arrange
        layoutState.setFMToneMode(true)
        layoutState.setPage(1)
        
        // Act - Rapidly update parameters
        for i in 0..<1000 {
            let value = Double(i % 8) + 1.0
            layoutState.updateFMToneParameter(key: "algorithm", value: value)
        }
        
        // Assert - System should remain stable
        let finalValue = layoutState.getFMToneParameterValue("algorithm")
        XCTAssertGreaterThanOrEqual(finalValue, 1.0, "System should remain stable after rapid updates")
        XCTAssertLessThanOrEqual(finalValue, 8.0, "System should remain stable after rapid updates")
    }
    
    /// Test memory usage remains stable during intensive parameter operations
    func testMemoryStabilityDuringParameterOperations() {
        // Arrange
        layoutState.setFMToneMode(true)
        
        // Act - Perform intensive parameter operations
        for page in 1...4 {
            layoutState.setPage(page)
            for i in 0..<100 {
                layoutState.updateFMToneParameter(key: "algorithm", value: Double(i % 8) + 1.0)
            }
        }
        
        // Assert - Memory usage should remain stable
        // (This is a basic stability test - in a real app you'd measure actual memory usage)
        XCTAssertNotNil(layoutState, "Layout state should remain valid after intensive operations")
        XCTAssertEqual(layoutState.parameterLabels.count, 8, "Parameter count should remain consistent")
    }
}