// UIComponents.swift
// DigitonePad - UIComponents
//
// Core UI component definitions and styling

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import MachineProtocols

// MARK: - Core Component Protocols

/// Base protocol for all DigitonePad UI components
public protocol DigitonePadComponent {
    var isEnabled: Bool { get }
}

/// Protocol for components that can provide haptic feedback
public protocol HapticComponent {
#if canImport(UIKit)
    func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle)
#else
    func triggerHapticFeedback()
#endif
}

/// Protocol for components that can be themed
public protocol ThemeableComponent {
    var theme: DigitonePadTheme { get }
}

// MARK: - Button Configuration

/// Configuration for DigitonePad buttons
public struct ButtonConfig {
    public let title: String
    public let style: ButtonStyle
    public let isEnabled: Bool
    public let isHighlighted: Bool
    public let onTap: () -> Void
    
    public enum ButtonStyle {
        case primary
        case secondary
        case accent
        case destructive
        case disabled
    }
    
    public init(
        title: String,
        style: ButtonStyle = .primary,
        isEnabled: Bool = true,
        isHighlighted: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isEnabled = isEnabled
        self.isHighlighted = isHighlighted
        self.onTap = onTap
    }
}

// MARK: - Step Configuration

/// Configuration for sequencer steps
public struct StepConfig {
    public let steps: [Bool]
    public let currentStep: Int
    public let onStepTapped: (Int) -> Void
    
    public init(steps: [Bool], currentStep: Int = -1, onStepTapped: @escaping (Int) -> Void) {
        self.steps = steps
        self.currentStep = currentStep
        self.onStepTapped = onStepTapped
    }
}

// MARK: - Parameter Configuration

/// Configuration for parameters with value ranges
public struct DigitonePadParameter {
    public let name: String
    public var value: Double
    public let range: ClosedRange<Double>
    public let unit: String

    public init(name: String, value: Double, range: ClosedRange<Double> = 0...1, unit: String = "") {
        self.name = name
        self.value = value
        self.range = range
        self.unit = unit
    }

    /// Get normalized value (0.0 to 1.0)
    public var normalizedValue: Double {
        return (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    /// Set value using normalized input (0.0 to 1.0)
    public mutating func setNormalizedValue(_ normalizedValue: Double) {
        let clampedNormalized = max(0.0, min(1.0, normalizedValue))
        value = range.lowerBound + clampedNormalized * (range.upperBound - range.lowerBound)
    }
}

// MARK: - Theme System

/// Theme definition for DigitonePad components
@MainActor
public struct DigitonePadTheme: Sendable {
    public let backgroundColor: Color
    public let primaryColor: Color
    public let secondaryColor: Color
    public let accentColor: Color
    public let textColor: Color
    public let buttonColor: Color
    public let knobColor: Color
    public let displayColor: Color
    
    public init(
        backgroundColor: Color,
        primaryColor: Color,
        secondaryColor: Color,
        accentColor: Color,
        textColor: Color,
        buttonColor: Color,
        knobColor: Color,
        displayColor: Color
    ) {
        self.backgroundColor = backgroundColor
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.accentColor = accentColor
        self.textColor = textColor
        self.buttonColor = buttonColor
        self.knobColor = knobColor
        self.displayColor = displayColor
    }
    
    @MainActor
    public static let `default`: DigitonePadTheme = {
#if canImport(UIKit)
        return DigitonePadTheme(
            backgroundColor: Color(UIColor.systemBackground),
            primaryColor: Color(UIColor.label),
            secondaryColor: Color(UIColor.secondaryLabel),
            accentColor: Color(UIColor.systemBlue),
            textColor: Color(UIColor.label),
            buttonColor: Color(UIColor.secondarySystemBackground),
            knobColor: Color(UIColor.tertiarySystemBackground),
            displayColor: Color(UIColor.systemGreen)
        )
#else
        return DigitonePadTheme(
            backgroundColor: Color(.controlBackgroundColor),
            primaryColor: Color(.labelColor),
            secondaryColor: Color(.secondaryLabelColor),
            accentColor: Color(.controlAccentColor),
            textColor: Color(.labelColor),
            buttonColor: Color(.controlColor),
            knobColor: Color(.quaternaryLabelColor),
            displayColor: Color(.systemGreen)
        )
#endif
    }()
    
    @MainActor
    public static let darkHardware = DigitonePadTheme(
        backgroundColor: Color(.black),
        primaryColor: Color(.white),
        secondaryColor: Color(.gray),
        accentColor: Color(.orange),
        textColor: Color(.white),
        buttonColor: Color(.darkGray),
        knobColor: Color(.darkGray),
        displayColor: Color(.green)
    )
}

// MARK: - Haptic Feedback System

/// Cross-platform haptic feedback styles
public enum HapticStyle: Sendable {
    case light
    case medium  
    case heavy
    case success
    case warning
    case error
}

/// Haptic feedback manager for cross-platform support
@MainActor
public final class HapticFeedbackManager: ObservableObject, Sendable {
#if canImport(UIKit)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    
    private init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notification.prepare()
    }
#else
    private init() {
        // No haptic feedback on macOS/other platforms
    }
#endif
    
    public static let shared = HapticFeedbackManager()
    
    public func trigger(_ style: HapticStyle) {
#if canImport(UIKit)
        switch style {
        case .light:
            lightImpact.impactOccurred()
        case .medium:
            mediumImpact.impactOccurred()
        case .heavy:
            heavyImpact.impactOccurred()
        case .success:
            notification.notificationOccurred(.success)
        case .warning:
            notification.notificationOccurred(.warning)
        case .error:
            notification.notificationOccurred(.error)
        }
#endif
    }
}

// MARK: - Haptic Protocol

/// Protocol for components that can trigger haptic feedback
public protocol HapticCapable {
    @MainActor func triggerHapticFeedback(_ style: HapticStyle)
}

@MainActor
public extension HapticCapable {
    func triggerHapticFeedback(_ style: HapticStyle) {
        HapticFeedbackManager.shared.trigger(style)
    }
}

// MARK: - Grid System

/// Configuration for grid layouts
public struct GridConfig: Sendable {
    public let rows: Int
    public let columns: Int
    public let spacing: CGFloat
    public let itemSize: CGSize
    
    public init(rows: Int, columns: Int, spacing: CGFloat = 8, itemSize: CGSize = CGSize(width: 44, height: 44)) {
        self.rows = rows
        self.columns = columns
        self.spacing = spacing
        self.itemSize = itemSize
    }
    
    public static let standard = GridConfig(rows: 4, columns: 4)
    public static let compact = GridConfig(rows: 4, columns: 4, spacing: 4, itemSize: CGSize(width: 32, height: 32))
}

// MARK: - Animation System

/// Animation configurations for UI components
public struct AnimationConfig: Sendable {
    public let duration: Double
    public let delay: Double
    public let curve: Animation
    
    public init(duration: Double = 0.25, delay: Double = 0, curve: Animation = .easeInOut) {
        self.duration = duration
        self.delay = delay
        self.curve = curve
    }
    
    public static let quick = AnimationConfig(duration: 0.1)
    public static let standard = AnimationConfig(duration: 0.25)
    public static let slow = AnimationConfig(duration: 0.5)
}

// MARK: - Color Extensions

public extension Color {
    /// Creates a color that adapts between light and dark appearances
    static func adaptive(light: Color, dark: Color) -> Color {
#if canImport(UIKit)
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
#else
        return light // Default to light on non-iOS platforms
#endif
    }
}



// MARK: - Accessibility

/// Accessibility configuration for components
public struct AccessibilityConfig: Sendable {
    public let label: String?
    public let hint: String?
    public let value: String?
    public let traits: AccessibilityTraits?
    
    public init(label: String? = nil, hint: String? = nil, value: String? = nil, traits: AccessibilityTraits? = nil) {
        self.label = label
        self.hint = hint
        self.value = value
        self.traits = traits
    }
}

// MARK: - Component Configuration

/// Configuration for DigitonePad encoders/knobs
public struct DigitonePadEncoderConfig {
    public let label: String
    public var parameter: DigitonePadParameter
    public let onValueChange: (Double) -> Void
    public var isEnabled: Bool
    public var showValue: Bool
    
    public init(label: String, parameter: DigitonePadParameter, onValueChange: @escaping (Double) -> Void, isEnabled: Bool = true, showValue: Bool = true) {
        self.label = label
        self.parameter = parameter
        self.onValueChange = onValueChange
        self.isEnabled = isEnabled
        self.showValue = showValue
    }
}

/// Configuration for DigitonePad displays
public struct DigitonePadDisplayConfig {
    public enum Style {
        case lcd, led, oled
    }
    
    public let text: String
    public let style: Style
    public let isActive: Bool
    
    public init(text: String, style: Style = .lcd, isActive: Bool = true) {
        self.text = text
        self.style = style
        self.isActive = isActive
    }
}

// MARK: - Grid Configuration

/// Configuration for sequencer grid components
public struct GridConfiguration {
    public let rows: Int
    public let columns: Int
    public let stepStates: [GridStepState]
    public let onStepTapped: (Int) -> Void
    
    public init(rows: Int, columns: Int, stepStates: [GridStepState], onStepTapped: @escaping (Int) -> Void) {
        self.rows = rows
        self.columns = columns
        self.stepStates = stepStates
        self.onStepTapped = onStepTapped
    }
}

/// State for individual grid steps
public struct GridStepState {
    public var isActive: Bool
    public var isPlaying: Bool
    public var hasParameterLock: Bool
    public var velocity: Double
    
    public init(isActive: Bool = false, isPlaying: Bool = false, hasParameterLock: Bool = false, velocity: Double = 0.0) {
        self.isActive = isActive
        self.isPlaying = isPlaying
        self.hasParameterLock = hasParameterLock
        self.velocity = max(0.0, min(1.0, velocity))
    }
}

// MARK: - Keyboard Configuration

/// Configuration for on-screen musical keyboard
public struct KeyboardConfiguration {
    public let octaves: Int
    public let startingOctave: Int
    public let keyLayout: KeyLayout
    public let onKeyPressed: (Note) -> Void
    public let onKeyReleased: (Note) -> Void
    
    public enum KeyLayout {
        case piano
        case chromatic
        case isomorphic
    }
    
    public init(octaves: Int = 2, startingOctave: Int = 3, keyLayout: KeyLayout = .piano, 
                onKeyPressed: @escaping (Note) -> Void, onKeyReleased: @escaping (Note) -> Void) {
        self.octaves = octaves
        self.startingOctave = startingOctave
        self.keyLayout = keyLayout
        self.onKeyPressed = onKeyPressed
        self.onKeyReleased = onKeyReleased
    }
}

/// Musical note representation
public struct Note {
    public let midiNumber: Int
    public let name: String
    public let octave: Int
    public let isSharp: Bool
    
    public init(midiNumber: Int) {
        self.midiNumber = midiNumber
        self.octave = (midiNumber / 12) - 1
        
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let noteIndex = midiNumber % 12
        self.name = noteNames[noteIndex]
        self.isSharp = name.contains("#")
    }
}

// MARK: - Type Aliases for Test Compatibility

/// Type alias for test compatibility
public typealias DigitonePadButtonConfig = ButtonConfig

// MARK: - Module Export

public struct UIComponentsModule {
    public static let version = "1.0.0"
}