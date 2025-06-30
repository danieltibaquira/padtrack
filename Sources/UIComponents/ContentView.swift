// ContentView.swift
// DigitonePad - UIComponents
//
// SwiftUI Components for DigitonePad Interface

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Type Aliases for Test Compatibility

/// Type aliases for test compatibility
public typealias DigitoneButton = DigitonePadButton
public typealias DigitoneEncoder = DigitonePadKnob
public typealias DigitoneDisplay = DigitonePadDisplay

// MARK: - Digitone Button Component

/// Configurable button component
public struct DigitonePadButton: View, HapticCapable {
    public let config: ButtonConfig
    public let theme: DigitonePadTheme
    @ObservedObject private var hapticManager = HapticFeedbackManager.shared
    
    public init(config: ButtonConfig, theme: DigitonePadTheme = .default) {
        self.config = config
        self.theme = theme
    }
    
    public var body: some View {
        Button(action: {
            if config.style != .disabled {
                triggerHapticFeedback(.medium)
                config.onTap()
            }
        }) {
            Text(config.title)
                .font(.headline)
                .foregroundColor(textColor)
                .padding()
                .frame(minWidth: 120, minHeight: 44)
                .background(buttonBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
                .cornerRadius(8)
        }
        .disabled(!config.isEnabled)
        .opacity(config.isEnabled ? 1.0 : 0.6)
        .scaleEffect(config.isHighlighted ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: config.isHighlighted)
    }
    
    private var textColor: Color {
        switch config.style {
        case .primary: return theme.backgroundColor
        case .secondary: return theme.primaryColor
        case .accent: return theme.backgroundColor
        case .destructive: return Color.white
        case .disabled: return theme.secondaryColor.opacity(0.5)
        }
    }

    private var buttonBackgroundColor: Color {
        switch config.style {
        case .primary: return theme.primaryColor
        case .secondary: return theme.buttonColor
        case .accent: return theme.accentColor
        case .destructive: return Color.red
        case .disabled: return theme.buttonColor.opacity(0.3)
        }
    }

    private var borderColor: Color {
        switch config.style {
        case .primary: return theme.primaryColor.opacity(0.3)
        case .secondary: return theme.secondaryColor
        case .accent: return theme.accentColor.opacity(0.3)
        case .destructive: return Color.red.opacity(0.3)
        case .disabled: return theme.secondaryColor.opacity(0.2)
        }
    }
}

// MARK: - Digitone Encoder Component

/// Rotary knob component
public struct DigitonePadKnob: View, HapticCapable {
    @Binding public var value: Double
    public let range: ClosedRange<Double>
    public let step: Double
    public let label: String
    public let theme: DigitonePadTheme
    @State private var isDragging = false
    @State private var lastDragValue: CGFloat = 0
    @ObservedObject private var hapticManager = HapticFeedbackManager.shared
    
    public init(
        value: Binding<Double>,
        range: ClosedRange<Double> = 0...1,
        step: Double = 0.01,
        label: String,
        theme: DigitonePadTheme = .default
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.label = label
        self.theme = theme
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(theme.knobColor)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(theme.primaryColor, lineWidth: 2)
                    )
                
                Rectangle()
                    .fill(theme.displayColor)
                    .frame(width: 3, height: 20)
                    .offset(y: -15)
                    .rotationEffect(Angle(degrees: rotationAngle))
            }
            .scaleEffect(isDragging ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isDragging)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            lastDragValue = gesture.translation.height
                            triggerHapticFeedback(.light)
                        }
                        
                        let sensitivity: CGFloat = 0.01
                        let delta = (lastDragValue - gesture.translation.height) * sensitivity
                        lastDragValue = gesture.translation.height
                        
                        let newValue = value + Double(delta) * (range.upperBound - range.lowerBound)
                        value = max(range.lowerBound, min(range.upperBound, newValue))
                        
                        // Quantize to step
                        value = round(value / step) * step
                    }
                    .onEnded { _ in
                        isDragging = false
                        triggerHapticFeedback(.medium)
                    }
            )
            
            Text(label)
                .font(.caption)
                .foregroundColor(theme.textColor)
            
            Text(String(format: "%.2f", value))
                .font(.caption2)
                .foregroundColor(theme.secondaryColor)
        }
    }
    
    private var rotationAngle: Double {
        let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return normalizedValue * 270 - 135 // -135° to +135° range
    }
}

// MARK: - Digitone Display Component

/// LED-style display component
public struct DigitonePadDisplay: View, HapticCapable {
    public let text: String
    public let isActive: Bool
    public let theme: DigitonePadTheme
    @ObservedObject private var hapticManager = HapticFeedbackManager.shared
    
    public init(text: String, isActive: Bool = true, theme: DigitonePadTheme = .default) {
        self.text = text
        self.isActive = isActive
        self.theme = theme
    }
    
    public var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .regular, design: .monospaced))
            .foregroundColor(isActive ? theme.displayColor : theme.secondaryColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(theme.secondaryColor, lineWidth: 1)
                    )
            )
            .opacity(isActive ? 1.0 : 0.5)
            .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

// MARK: - Digitone Grid Component

/// SwiftUI grid component for sequencer step visualization
public struct DigitoneGrid: View, HapticCapable {
    @ObservedObject private var hapticManager = HapticFeedbackManager.shared
    public let config: GridConfiguration
    public let theme: DigitonePadTheme

    public init(config: GridConfiguration, theme: DigitonePadTheme = .default) {
        self.config = config
        self.theme = theme
    }
    
    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: config.columns), spacing: 8) {
            ForEach(0..<config.stepStates.count, id: \.self) { index in
                Button(action: {
                    triggerHapticFeedback(.medium)
                    config.onStepTapped(index)
                }) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(stepColor(for: index))
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(stepBorderColor(for: index), lineWidth: 2)
                        )
                }
                .scaleEffect(config.stepStates[index].isPlaying ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: config.stepStates[index].isPlaying)
            }
        }
        .padding()
    }

    private func stepColor(for index: Int) -> Color {
        let stepState = config.stepStates[index]
        if stepState.isPlaying {
            return theme.accentColor
        } else if stepState.isActive {
            return theme.primaryColor.opacity(stepState.velocity)
        } else {
            return theme.buttonColor
        }
    }

    private func stepBorderColor(for index: Int) -> Color {
        let stepState = config.stepStates[index]
        if stepState.isPlaying {
            return theme.accentColor.opacity(0.8)
        } else if stepState.isActive {
            return theme.primaryColor.opacity(0.5)
        } else {
            return theme.secondaryColor.opacity(0.3)
        }
    }
}

// MARK: - Preview Providers

struct DigitonePadButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            DigitonePadButton(
                config: ButtonConfig(
                    title: "Primary",
                    style: .primary,
                    onTap: {}
                ),
                theme: .default
            )
            
            DigitonePadButton(
                config: ButtonConfig(
                    title: "Secondary",
                    style: .secondary,
                    onTap: {}
                ),
                theme: .default
            )
            
            DigitonePadButton(
                config: ButtonConfig(
                    title: "Disabled",
                    style: .primary,
                    isEnabled: false,
                    onTap: {}
                ),
                theme: .default
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

struct DigitonePadKnob_Previews: PreviewProvider {
    static var previews: some View {
        DigitonePadKnob(
            value: .constant(0.5),
            range: 0...1,
            step: 0.01,
            label: "Volume",
            theme: .default
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

struct DigitonePadDisplay_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            DigitonePadDisplay(text: "120 BPM", isActive: true, theme: .default)
            DigitonePadDisplay(text: "STOPPED", isActive: false, theme: .default)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

struct DigitoneGrid_Previews: PreviewProvider {
    static var previews: some View {
        let stepStates: [GridStepState] = [
            GridStepState(isActive: true, isPlaying: false, hasParameterLock: true, velocity: 0.8),
            GridStepState(isActive: false, isPlaying: false, hasParameterLock: false, velocity: 0.0),
            GridStepState(isActive: true, isPlaying: true, hasParameterLock: false, velocity: 1.0),
            GridStepState(isActive: false, isPlaying: false, hasParameterLock: false, velocity: 0.0),
            GridStepState(isActive: true, isPlaying: false, hasParameterLock: false, velocity: 0.6),
            GridStepState(isActive: false, isPlaying: false, hasParameterLock: false, velocity: 0.0),
            GridStepState(isActive: false, isPlaying: false, hasParameterLock: false, velocity: 0.0),
            GridStepState(isActive: true, isPlaying: false, hasParameterLock: true, velocity: 0.9),
            GridStepState(isActive: false, isPlaying: false, hasParameterLock: false, velocity: 0.0),
            GridStepState(isActive: true, isPlaying: false, hasParameterLock: false, velocity: 0.7),
            GridStepState(isActive: false, isPlaying: false, hasParameterLock: false, velocity: 0.0),
            GridStepState(isActive: false, isPlaying: false, hasParameterLock: false, velocity: 0.0),
            GridStepState(isActive: true, isPlaying: false, hasParameterLock: false, velocity: 0.5),
            GridStepState(isActive: false, isPlaying: false, hasParameterLock: false, velocity: 0.0),
            GridStepState(isActive: false, isPlaying: false, hasParameterLock: false, velocity: 0.0),
            GridStepState(isActive: true, isPlaying: false, hasParameterLock: false, velocity: 0.8)
        ]

        let config = GridConfiguration(
            rows: 2,
            columns: 8,
            stepStates: stepStates,
            onStepTapped: { _ in }
        )

        DigitoneGrid(config: config, theme: .default)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}

// MARK: - Parameter Preview

struct DigitonePadParameter_Previews: PreviewProvider {
    static var previews: some View {
        let parameter = DigitonePadParameter(
            name: "Cutoff",
            value: 0.7,
            range: 0...1
        )
        
        DigitonePadKnob(value: .constant(parameter.value), range: parameter.range, step: 0.01, label: parameter.name, theme: .default)
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 