import XCTest
import SwiftUI
import Combine
@testable import DigitonePad
@testable import UIComponents

/// Comprehensive test suite for parameter encoder UI responsiveness and interaction
/// Tests encoder visualization, user interaction, and 60fps performance requirements
class ParameterEncoderTests: XCTestCase {
    
    var encoder: ParameterEncoder!
    var layoutState: MainLayoutState!
    var cancelables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        layoutState = MainLayoutState()
        cancelables = Set<AnyCancellable>()
        
        // Initialize encoder for algorithm parameter
        encoder = ParameterEncoder(
            parameter: .algorithm,
            layoutState: layoutState,
            index: 0
        )
    }
    
    override func tearDown() {
        cancelables.forEach { $0.cancel() }
        encoder = nil
        layoutState = nil
        super.tearDown()
    }
    
    // MARK: - Encoder Visualization Tests
    
    /// Test encoder rotation produces immediate visual feedback
    func testEncoderVisualizationImmediate() {
        // Arrange
        layoutState.setFMToneMode(true)
        layoutState.setPage(1)
        
        // Act - Update encoder value
        encoder.updateValue(0.5)
        
        // Assert - Visual feedback should be immediate
        XCTAssertEqual(encoder.displayValue, "4", "Algorithm encoder should display '4' for 0.5 value")
        XCTAssertEqual(encoder.visualProgress, 0.375, accuracy: 0.01, "Visual progress should be (4-1)/(8-1) = 0.375")
        XCTAssertEqual(encoder.normalizedValue, 0.5, accuracy: 0.01, "Normalized value should match input")
    }
    
    /// Test encoder value formatting for different parameter types
    func testEncoderValueFormatting() {
        // Test Algorithm parameter (discrete 1-8)
        encoder.parameter = .algorithm
        encoder.updateValue(0.0)
        XCTAssertEqual(encoder.displayValue, "1", "Algorithm min should display '1'")
        
        encoder.updateValue(1.0)
        XCTAssertEqual(encoder.displayValue, "8", "Algorithm max should display '8'")
        
        encoder.updateValue(0.375) // Should map to algorithm 3.625 -> displayed as "4"
        XCTAssertEqual(encoder.displayValue, "4", "Algorithm mid-range should display '4'")
        
        // Test Ratio parameter (continuous 0.5-32.0)
        encoder.parameter = .ratioA
        encoder.updateValue(0.0)
        XCTAssertEqual(encoder.displayValue, "0.50", "Ratio min should display '0.50'")
        
        encoder.updateValue(1.0)
        XCTAssertEqual(encoder.displayValue, "32.0", "Ratio max should display '32.0'")
        
        encoder.updateValue(0.5)
        XCTAssertEqual(encoder.displayValue, "16.2", accuracy: 0.1, "Ratio mid should display approximately '16.2'")
        
        // Test Normalized parameter (0.0-1.0)
        encoder.parameter = .harmony
        encoder.updateValue(0.7)
        XCTAssertEqual(encoder.displayValue, "89", "Harmony 0.7 should display as '89' (0.7 * 127)")
    }
    
    /// Test encoder visual progress calculation
    func testEncoderVisualProgress() {
        // Algorithm parameter visual progress
        encoder.parameter = .algorithm
        
        encoder.updateValue(0.0)
        XCTAssertEqual(encoder.visualProgress, 0.0, accuracy: 0.01, "Algorithm min visual progress should be 0.0")
        
        encoder.updateValue(1.0)
        XCTAssertEqual(encoder.visualProgress, 1.0, accuracy: 0.01, "Algorithm max visual progress should be 1.0")
        
        encoder.updateValue(0.5)
        XCTAssertEqual(encoder.visualProgress, 0.5, accuracy: 0.01, "Algorithm mid visual progress should be 0.5")
        
        // Ratio parameter visual progress
        encoder.parameter = .ratioA
        
        encoder.updateValue(0.0)
        XCTAssertEqual(encoder.visualProgress, 0.0, accuracy: 0.01, "Ratio min visual progress should be 0.0")
        
        encoder.updateValue(1.0)
        XCTAssertEqual(encoder.visualProgress, 1.0, accuracy: 0.01, "Ratio max visual progress should be 1.0")
    }
    
    // MARK: - User Interaction Tests
    
    /// Test encoder responds to touch gestures
    func testEncoderTouchGestureResponse() {
        // Arrange
        layoutState.setFMToneMode(true)
        layoutState.setPage(1)
        
        var gestureDetected = false
        let expectation = self.expectation(description: "Gesture response")
        
        encoder.onValueChanged = { newValue in
            gestureDetected = true
            expectation.fulfill()
        }
        
        // Act - Simulate touch gesture
        encoder.handleTouchGesture(delta: 0.1)
        
        // Assert
        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertTrue(gestureDetected, "Encoder should respond to touch gestures")
        }
    }
    
    /// Test encoder value changes update main layout state
    func testEncoderUpdatesLayoutState() {
        // Arrange
        layoutState.setFMToneMode(true)
        layoutState.setPage(1) // Algorithm is encoder 0 on page 1
        
        let initialValue = layoutState.parameterValues[0]
        
        // Act
        encoder.updateValue(0.8)
        
        // Assert
        XCTAssertNotEqual(layoutState.parameterValues[0], initialValue, 
                         "Layout state parameter value should change")
        XCTAssertEqual(layoutState.parameterValues[0], 0.8, accuracy: 0.01,
                      "Layout state should reflect encoder value")
    }
    
    /// Test encoder interaction triggers parameter bridge updates
    func testEncoderTriggersParameterBridge() {
        // Arrange
        var bridgeUpdateCalled = false
        var updatedParameterID: FMParameterID?
        var updatedValue: Double?
        
        encoder.parameterBridge = MockParameterBridge { paramID, value in
            bridgeUpdateCalled = true
            updatedParameterID = paramID
            updatedValue = value
        }
        
        // Act
        encoder.updateValue(0.6)
        
        // Assert
        XCTAssertTrue(bridgeUpdateCalled, "Encoder should trigger parameter bridge update")
        XCTAssertEqual(updatedParameterID, .algorithm, "Correct parameter ID should be sent to bridge")
        XCTAssertEqual(updatedValue, 0.6, accuracy: 0.01, "Correct value should be sent to bridge")
    }
    
    // MARK: - Performance Tests
    
    /// Test encoder visual updates maintain 60fps during rapid changes
    func testEncoderVisualPerformance60FPS() {
        // Arrange
        let targetFrameTime = 1.0 / 60.0 // 16.67ms for 60fps
        
        // Act & Assert - Measure visual update performance
        measure {
            for i in 0..<60 {
                let value = Double(i) / 60.0
                let startTime = CACurrentMediaTime()
                
                encoder.updateValue(value)
                encoder.refreshVisualState()
                
                let frameTime = CACurrentMediaTime() - startTime
                XCTAssertLessThan(frameTime, targetFrameTime, 
                                 "Visual update should complete within 16.67ms for 60fps")
            }
        }
    }
    
    /// Test encoder handles rapid user input without lag
    func testEncoderRapidInputHandling() {
        // Arrange
        var updateCount = 0
        encoder.onValueChanged = { _ in
            updateCount += 1
        }
        
        // Act - Simulate rapid user input
        let startTime = CACurrentMediaTime()
        for i in 0..<100 {
            encoder.handleTouchGesture(delta: 0.01)
        }
        let endTime = CACurrentMediaTime()
        
        // Assert
        let totalTime = endTime - startTime
        XCTAssertLessThan(totalTime, 0.1, "100 rapid inputs should complete in < 100ms")
        XCTAssertEqual(updateCount, 100, "All rapid inputs should be processed")
    }
    
    /// Test encoder memory usage remains stable during intensive interaction
    func testEncoderMemoryStability() {
        // Arrange
        let initialMemory = getCurrentMemoryUsage()
        
        // Act - Intensive encoder interaction
        for _ in 0..<1000 {
            encoder.updateValue(Double.random(in: 0.0...1.0))
            encoder.refreshVisualState()
        }
        
        // Assert
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        XCTAssertLessThan(memoryIncrease, 500_000, "Memory usage should not increase by more than 500KB")
    }
    
    // MARK: - Multi-Encoder Tests
    
    /// Test multiple encoders on same page work independently
    func testMultipleEncodersIndependence() {
        // Arrange
        layoutState.setFMToneMode(true)
        layoutState.setPage(1)
        
        let encoder2 = ParameterEncoder(parameter: .ratioA, layoutState: layoutState, index: 2)
        let encoder3 = ParameterEncoder(parameter: .harmony, layoutState: layoutState, index: 4)
        
        // Act - Update different encoders
        encoder.updateValue(0.8)  // Algorithm
        encoder2.updateValue(0.3) // Ratio A
        encoder3.updateValue(0.9) // Harmony
        
        // Assert - Each encoder should maintain its own value
        XCTAssertEqual(encoder.normalizedValue, 0.8, accuracy: 0.01, "Encoder 1 should maintain its value")
        XCTAssertEqual(encoder2.normalizedValue, 0.3, accuracy: 0.01, "Encoder 2 should maintain its value")
        XCTAssertEqual(encoder3.normalizedValue, 0.9, accuracy: 0.01, "Encoder 3 should maintain its value")
        
        // Assert - Layout state should reflect all changes
        XCTAssertEqual(layoutState.parameterValues[0], 0.8, accuracy: 0.01, "Algorithm value in layout state")
        XCTAssertEqual(layoutState.parameterValues[2], 0.3, accuracy: 0.01, "Ratio A value in layout state")
        XCTAssertEqual(layoutState.parameterValues[4], 0.9, accuracy: 0.01, "Harmony value in layout state")
    }
    
    /// Test encoder page switching preserves individual encoder states
    func testEncoderPageSwitchingPreservesState() {
        // Arrange
        layoutState.setFMToneMode(true)
        layoutState.setPage(1)
        encoder.updateValue(0.7)
        
        let originalValue = encoder.normalizedValue
        let originalDisplayValue = encoder.displayValue
        
        // Act - Switch to different page and back
        layoutState.setPage(2)
        layoutState.setPage(1)
        
        // Assert - Encoder state should be preserved
        XCTAssertEqual(encoder.normalizedValue, originalValue, accuracy: 0.01,
                      "Encoder value should be preserved across page switches")
        XCTAssertEqual(encoder.displayValue, originalDisplayValue,
                      "Encoder display value should be preserved across page switches")
    }
    
    // MARK: - Visual State Tests
    
    /// Test encoder visual states (normal, active, disabled)
    func testEncoderVisualStates() {
        // Test normal state
        encoder.setState(.normal)
        XCTAssertEqual(encoder.currentState, .normal, "Encoder should be in normal state")
        XCTAssertFalse(encoder.isHighlighted, "Normal state should not be highlighted")
        
        // Test active state (being touched)
        encoder.setState(.active)
        XCTAssertEqual(encoder.currentState, .active, "Encoder should be in active state")
        XCTAssertTrue(encoder.isHighlighted, "Active state should be highlighted")
        
        // Test disabled state
        encoder.setState(.disabled)
        XCTAssertEqual(encoder.currentState, .disabled, "Encoder should be in disabled state")
        XCTAssertFalse(encoder.isInteractionEnabled, "Disabled state should not allow interaction")
    }
    
    /// Test encoder color coding for different parameter types
    func testEncoderColorCoding() {
        // Algorithm parameter should use algorithm color
        encoder.parameter = .algorithm
        XCTAssertEqual(encoder.parameterColor, DigitonePadTheme.darkHardware.algorithmColor,
                      "Algorithm parameter should use algorithm color")
        
        // Ratio parameters should use operator color
        encoder.parameter = .ratioA
        XCTAssertEqual(encoder.parameterColor, DigitonePadTheme.darkHardware.operatorColor,
                      "Ratio parameter should use operator color")
        
        // Envelope parameters should use envelope color
        encoder.parameter = .attackA
        XCTAssertEqual(encoder.parameterColor, DigitonePadTheme.darkHardware.envelopeColor,
                      "Envelope parameter should use envelope color")
    }
    
    // MARK: - Accessibility Tests
    
    /// Test encoder accessibility support
    func testEncoderAccessibilitySupport() {
        // Arrange
        encoder.parameter = .algorithm
        encoder.updateValue(0.5)
        
        // Assert - Accessibility labels should be descriptive
        XCTAssertEqual(encoder.accessibilityLabel, "Algorithm parameter encoder",
                      "Encoder should have descriptive accessibility label")
        XCTAssertEqual(encoder.accessibilityValue, "Algorithm 4 of 8",
                      "Encoder should have descriptive accessibility value")
        XCTAssertTrue(encoder.isAccessibilityElement, "Encoder should be accessibility element")
        
        // Assert - Accessibility actions should be available
        XCTAssertTrue(encoder.accessibilityTraits.contains(.adjustable),
                     "Encoder should have adjustable accessibility trait")
    }
    
    /// Test encoder voice-over support
    func testEncoderVoiceOverSupport() {
        // Arrange
        encoder.parameter = .ratioA
        encoder.updateValue(0.25)
        
        // Act - Simulate accessibility increment/decrement
        encoder.accessibilityIncrement()
        let incrementedValue = encoder.normalizedValue
        
        encoder.accessibilityDecrement()
        encoder.accessibilityDecrement()
        let decrementedValue = encoder.normalizedValue
        
        // Assert
        XCTAssertGreaterThan(incrementedValue, 0.25, "Accessibility increment should increase value")
        XCTAssertLessThan(decrementedValue, 0.25, "Accessibility decrement should decrease value")
    }
    
    // MARK: - Error Handling Tests
    
    /// Test encoder handles invalid parameter values gracefully
    func testEncoderInvalidValueHandling() {
        // Act & Assert - Should not crash with invalid values
        encoder.updateValue(Double.infinity)
        XCTAssertTrue(encoder.normalizedValue.isFinite, "Encoder should handle infinite values")
        
        encoder.updateValue(Double.nan)
        XCTAssertFalse(encoder.normalizedValue.isNaN, "Encoder should handle NaN values")
        
        encoder.updateValue(-5.0)
        XCTAssertGreaterThanOrEqual(encoder.normalizedValue, 0.0, "Encoder should clamp negative values")
        
        encoder.updateValue(5.0)
        XCTAssertLessThanOrEqual(encoder.normalizedValue, 1.0, "Encoder should clamp excessive values")
    }
    
    /// Test encoder remains functional during layout state changes
    func testEncoderFunctionalityDuringLayoutChanges() {
        // Arrange
        encoder.updateValue(0.6)
        let originalValue = encoder.normalizedValue
        
        // Act - Rapid layout state changes
        for _ in 0..<10 {
            layoutState.setFMToneMode(false)
            layoutState.setFMToneMode(true)
            layoutState.setPage(Int.random(in: 1...4))
        }
        
        // Assert - Encoder should remain functional
        encoder.updateValue(0.8)
        XCTAssertEqual(encoder.normalizedValue, 0.8, accuracy: 0.01,
                      "Encoder should remain functional after layout changes")
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - Mock Objects and Extensions

/// Mock parameter bridge for testing encoder integration
class MockParameterBridge {
    private let updateCallback: (FMParameterID, Double) -> Void
    
    init(updateCallback: @escaping (FMParameterID, Double) -> Void) {
        self.updateCallback = updateCallback
    }
    
    func updateParameter(_ parameterID: FMParameterID, value: Double) {
        updateCallback(parameterID, value)
    }
}

/// Parameter encoder implementation for testing
class ParameterEncoder: ObservableObject {
    @Published var normalizedValue: Double = 0.0
    @Published var displayValue: String = "0"
    @Published var visualProgress: Double = 0.0
    @Published var currentState: EncoderState = .normal
    @Published var isHighlighted: Bool = false
    @Published var isInteractionEnabled: Bool = true
    
    var parameter: FMParameterID
    var layoutState: MainLayoutState
    var index: Int
    var parameterBridge: MockParameterBridge?
    var onValueChanged: ((Double) -> Void)?
    
    // Accessibility properties
    var accessibilityLabel: String {
        return "\(parameter.displayName) parameter encoder"
    }
    
    var accessibilityValue: String {
        switch parameter {
        case .algorithm:
            let algoNumber = Int(normalizedValue * 7) + 1
            return "Algorithm \(algoNumber) of 8"
        case .ratioA, .ratioB, .ratioC:
            let ratioValue = 0.5 + normalizedValue * 31.5
            return String(format: "Ratio %.1f", ratioValue)
        default:
            let percentage = Int(normalizedValue * 100)
            return "\(percentage) percent"
        }
    }
    
    var isAccessibilityElement: Bool = true
    var accessibilityTraits: UIAccessibilityTraits = .adjustable
    
    var parameterColor: UIColor {
        switch parameter {
        case .algorithm:
            return DigitonePadTheme.darkHardware.algorithmColor
        case .ratioA, .ratioB, .ratioC:
            return DigitonePadTheme.darkHardware.operatorColor
        case .attackA, .decayA, .endA, .attackB, .decayB, .endB:
            return DigitonePadTheme.darkHardware.envelopeColor
        default:
            return DigitonePadTheme.darkHardware.accentColor
        }
    }
    
    init(parameter: FMParameterID, layoutState: MainLayoutState, index: Int) {
        self.parameter = parameter
        self.layoutState = layoutState
        self.index = index
        updateDisplayValue()
    }
    
    func updateValue(_ value: Double) {
        let clampedValue = max(0.0, min(1.0, value.isFinite ? value : 0.0))
        normalizedValue = clampedValue
        visualProgress = clampedValue
        
        updateDisplayValue()
        updateLayoutState()
        notifyParameterBridge()
        onValueChanged?(clampedValue)
    }
    
    func handleTouchGesture(delta: Double) {
        let newValue = normalizedValue + delta
        updateValue(newValue)
    }
    
    func setState(_ state: EncoderState) {
        currentState = state
        isHighlighted = (state == .active)
        isInteractionEnabled = (state != .disabled)
    }
    
    func refreshVisualState() {
        // Trigger visual updates
        objectWillChange.send()
    }
    
    func accessibilityIncrement() {
        updateValue(normalizedValue + 0.1)
    }
    
    func accessibilityDecrement() {
        updateValue(normalizedValue - 0.1)
    }
    
    private func updateDisplayValue() {
        switch parameter {
        case .algorithm:
            let algoNumber = Int(normalizedValue * 7) + 1
            displayValue = "\(algoNumber)"
        case .ratioA, .ratioB, .ratioC:
            let ratioValue = 0.5 + normalizedValue * 31.5
            displayValue = String(format: "%.1f", ratioValue)
        default:
            let scaledValue = Int(normalizedValue * 127)
            displayValue = "\(scaledValue)"
        }
    }
    
    private func updateLayoutState() {
        if index < layoutState.parameterValues.count {
            layoutState.parameterValues[index] = normalizedValue
        }
    }
    
    private func notifyParameterBridge() {
        parameterBridge?.updateParameter(parameter, value: normalizedValue)
    }
}

enum EncoderState {
    case normal, active, disabled
}

// Mock theme colors for testing
extension DigitonePadTheme {
    static let darkHardware = DigitonePadThemeColors(
        algorithmColor: UIColor.systemBlue,
        operatorColor: UIColor.systemGreen,
        envelopeColor: UIColor.systemOrange,
        accentColor: UIColor.systemRed
    )
}

struct DigitonePadThemeColors {
    let algorithmColor: UIColor
    let operatorColor: UIColor
    let envelopeColor: UIColor
    let accentColor: UIColor
}

enum DigitonePadTheme {
    static var darkHardware: DigitonePadThemeColors {
        return DigitonePadThemeColors(
            algorithmColor: UIColor.systemBlue,
            operatorColor: UIColor.systemGreen,
            envelopeColor: UIColor.systemOrange,
            accentColor: UIColor.systemRed
        )
    }
}

// Additional FMParameterID cases for testing
extension FMParameterID {
    var displayName: String {
        switch self {
        case .algorithm: return "Algorithm"
        case .ratioA: return "Ratio A"
        case .ratioB: return "Ratio B"
        case .ratioC: return "Ratio C"
        case .harmony: return "Harmony"
        case .detune: return "Detune"
        case .feedback: return "Feedback"
        case .mix: return "Mix"
        case .attackA: return "Attack A"
        case .decayA: return "Decay A"
        case .endA: return "End A"
        case .levelA: return "Level A"
        case .attackB: return "Attack B"
        case .decayB: return "Decay B"
        case .endB: return "End B"
        case .levelB: return "Level B"
        default: return "Unknown"
        }
    }
}