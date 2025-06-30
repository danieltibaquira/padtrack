import XCTest
import SwiftUI
@testable import UIComponents

@MainActor
final class UIComponentsTests: XCTestCase {
    
    // MARK: - Theme Tests
    
    func testDefaultTheme() throws {
        let theme = DigitonePadTheme.default
        
        XCTAssertEqual(theme.primaryColor, Color.blue)
        XCTAssertEqual(theme.secondaryColor, Color.gray)
        XCTAssertEqual(theme.accentColor, Color.orange)
        XCTAssertEqual(theme.backgroundColor, Color.white)
        XCTAssertEqual(theme.buttonColor, Color.blue)
        XCTAssertEqual(theme.displayColor, Color.black)
    }
    
    func testDarkHardwareTheme() throws {
        let theme = DigitonePadTheme.darkHardware
        
        XCTAssertEqual(theme.primaryColor, Color.white)
        XCTAssertEqual(theme.secondaryColor, Color.gray)
        XCTAssertEqual(theme.accentColor, Color.orange)
        XCTAssertEqual(theme.backgroundColor, Color.black)
        XCTAssertEqual(theme.buttonColor, Color.gray)
        XCTAssertEqual(theme.displayColor, Color.green)
    }
    
    // MARK: - Parameter Tests
    
    func testParameterNormalizedValue() throws {
        let parameter = DigitonePadParameter(
            name: "Test",
            value: 0.5,
            range: 0.0...1.0,
            unit: ""
        )
        
        XCTAssertEqual(parameter.normalizedValue, 0.5, accuracy: 0.001)
    }
    
    func testParameterSetNormalizedValue() throws {
        var parameter = DigitonePadParameter(
            name: "Cutoff",
            value: 550.0,
            range: 100.0...1000.0,
            unit: "Hz"
        )
        
        parameter.setNormalizedValue(0.0)
        XCTAssertEqual(parameter.value, 100.0, accuracy: 0.001)
        
        parameter.setNormalizedValue(1.0)
        XCTAssertEqual(parameter.value, 1000.0, accuracy: 0.001)
        
        parameter.setNormalizedValue(0.5)
        XCTAssertEqual(parameter.value, 550.0, accuracy: 0.001)
    }
    
    func testParameterClampedValue() throws {
        var parameter = DigitonePadParameter(
            name: "Volume",
            value: 500.0,
            range: 100.0...1000.0,
            unit: "Hz"
        )
        
        // Test clamping beyond range
        parameter.setNormalizedValue(-0.5) // Should clamp to 0.0
        XCTAssertEqual(parameter.value, 100.0, accuracy: 0.001)
        
        parameter.setNormalizedValue(1.5) // Should clamp to 1.0
        XCTAssertEqual(parameter.value, 1000.0, accuracy: 0.001)
    }
    
    // MARK: - Grid State Tests
    
    func testGridStepState() throws {
        let stepState = GridStepState(
            isActive: true,
            isPlaying: false,
            hasParameterLock: true,
            velocity: 0.8
        )
        
        XCTAssertTrue(stepState.isActive)
        XCTAssertFalse(stepState.isPlaying)
        XCTAssertTrue(stepState.hasParameterLock)
        XCTAssertEqual(stepState.velocity, 0.8, accuracy: 0.001)
    }
    
    // MARK: - Haptic Manager Tests
    
    func testHapticManagerSingleton() throws {
        let manager1 = HapticFeedbackManager.shared
        let manager2 = HapticFeedbackManager.shared
        
        XCTAssertTrue(manager1 === manager2)
    }
    
    // MARK: - Configuration Tests
    
    func testButtonConfiguration() throws {
        let config = DigitonePadButtonConfig(
            title: "PLAY",
            style: .primary,
            isEnabled: true,
            onTap: { }
        )
        
        XCTAssertEqual(config.title, "PLAY")
        XCTAssertTrue(config.isEnabled)
    }
    
    func testEncoderConfiguration() throws {
        let parameter = DigitonePadParameter(
            name: "CUTOFF",
            value: 0.5,
            range: 0.0...1.0,
            unit: "Hz"
        )
        
        let config = DigitonePadEncoderConfig(
            label: "CUTOFF",
            parameter: parameter,
            onValueChange: { _ in },
            isEnabled: true,
            showValue: true
        )
        
        XCTAssertEqual(config.label, "CUTOFF")
        XCTAssertEqual(config.parameter.name, "CUTOFF")
        XCTAssertTrue(config.isEnabled)
        XCTAssertTrue(config.showValue)
    }
    
    func testDisplayConfiguration() throws {
        let config = DigitonePadDisplayConfig(
            text: "HELLO",
            style: .lcd,
            isActive: true
        )
        
        XCTAssertEqual(config.text, "HELLO")
        XCTAssertEqual(config.style, .lcd)
        XCTAssertTrue(config.isActive)
    }
    
    // MARK: - Component Creation Tests
    
    func testDigitoneButtonCreation() throws {
        let config = DigitonePadButtonConfig(
            title: "TEST",
            style: .primary,
            isEnabled: true,
            onTap: { }
        )
        
        let button = DigitoneButton(config: config)
        XCTAssertEqual(button.theme.primaryColor, DigitonePadTheme.default.primaryColor)
    }
    
    func testDigitoneButtonWithTheme() throws {
        let config = DigitonePadButtonConfig(
            title: "TEST",
            style: .secondary,
            isEnabled: true,
            onTap: { }
        )
        
        let button = DigitoneButton(config: config, theme: .darkHardware)
        XCTAssertEqual(button.theme.primaryColor, Color.white)
    }
    
    func testDigitoneEncoderCreation() throws {
        @State var value: Double = 0.5

        let encoder = DigitoneEncoder(
            value: $value,
            range: 0.0...1.0,
            label: "CUTOFF"
        )
        XCTAssertEqual(encoder.theme.primaryColor, DigitonePadTheme.default.primaryColor)
    }
    
    func testDigitoneEncoderWithCustomSensitivity() throws {
        @State var value: Double = 0.3

        let encoder = DigitoneEncoder(
            value: $value,
            range: 0.0...1.0,
            step: 0.1,
            label: "RESONANCE"
        )
        XCTAssertEqual(encoder.theme.primaryColor, DigitonePadTheme.default.primaryColor)
    }
    
    func testDigitoneDisplayCreation() throws {
        let display = DigitoneDisplay(text: "DIGITONE", isActive: true)
        XCTAssertEqual(display.theme.displayColor, DigitonePadTheme.default.displayColor)
    }
    
    func testDigitoneDisplayStyles() throws {
        let lcdDisplay = DigitoneDisplay(text: "LCD", isActive: true)
        let ledDisplay = DigitoneDisplay(text: "LED", isActive: true)
        let oledDisplay = DigitoneDisplay(text: "OLED", isActive: true)

        // All displays should use the same theme
        XCTAssertEqual(lcdDisplay.theme.displayColor, ledDisplay.theme.displayColor)
        XCTAssertEqual(ledDisplay.theme.displayColor, oledDisplay.theme.displayColor)
    }
    
    func testDigitoneGridCreation() throws {
        let stepStates = createSampleStepStates()
        
        let config = GridConfiguration(
            rows: 2,
            columns: 8,
            stepStates: stepStates,
            onStepTapped: { _ in }
        )
        
        let grid = DigitoneGrid(config: config)
        XCTAssertEqual(grid.theme.accentColor, DigitonePadTheme.default.accentColor)
    }
    
    func testDigitoneGridWithTheme() throws {
        let stepStates = createSampleStepStates()
        
        let config = GridConfiguration(
            rows: 2,
            columns: 8,
            stepStates: stepStates,
            onStepTapped: { _ in }
        )
        
        let grid = DigitoneGrid(config: config, theme: .darkHardware)
        XCTAssertEqual(grid.theme.accentColor, Color.orange)
    }
    
    // MARK: - Integration Tests
    
    func testComponentsWithSharedTheme() throws {
        let theme = DigitonePadTheme.darkHardware

        let buttonConfig = DigitonePadButtonConfig(
            title: "SHARED",
            style: .primary,
            isEnabled: true,
            onTap: { }
        )

        @State var encoderValue: Double = 0.5

        let button = DigitoneButton(config: buttonConfig, theme: theme)
        let encoder = DigitoneEncoder(
            value: $encoderValue,
            range: 0.0...1.0,
            label: "SHARED",
            theme: theme
        )
        let display = DigitoneDisplay(text: "SHARED", isActive: true, theme: theme)

        XCTAssertEqual(button.theme.primaryColor, theme.primaryColor)
        XCTAssertEqual(encoder.theme.primaryColor, theme.primaryColor)
        XCTAssertEqual(display.theme.primaryColor, theme.primaryColor)
    }
    
    func testParameterValueUpdates() throws {
        var parameter = DigitonePadParameter(
            name: "TEST",
            value: 50.0,
            range: 0.0...100.0,
            unit: "%"
        )
        
        // Test normalized value setting
        parameter.setNormalizedValue(0.75)
        XCTAssertEqual(parameter.value, 75.0, accuracy: 0.001)
        XCTAssertEqual(parameter.normalizedValue, 0.75, accuracy: 0.001)
        
        // Test normalized value setting
        parameter.setNormalizedValue(0.25)
        XCTAssertEqual(parameter.value, 25.0, accuracy: 0.001)
        XCTAssertEqual(parameter.normalizedValue, 0.25, accuracy: 0.001)
    }
    
    // MARK: - Helper Methods
    
    private func createSampleStepStates() -> [GridStepState] {
        var stepStates: [GridStepState] = []
        for index in 0..<16 {
            let stepState = GridStepState(
                isActive: index % 4 == 0,
                isPlaying: index == 0,
                hasParameterLock: index % 8 == 0,
                velocity: Double(index) / 16.0
            )
            stepStates.append(stepState)
        }
        return stepStates
    }
} 