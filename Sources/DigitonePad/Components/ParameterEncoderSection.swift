// ParameterEncoderSection.swift
// DigitonePad - Parameter Encoder Section
//
// Parameter encoder section with 8 rotary encoders

import SwiftUI
import UIComponents

/// Parameter encoder section with 8 rotary encoders
struct ParameterEncoderSection: View {
    @ObservedObject private var layoutState: MainLayoutState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    public init(layoutState: MainLayoutState) {
        self.layoutState = layoutState
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Section header
            sectionHeader
            
            // Encoder grid
            if isLandscape {
                landscapeEncoderLayout
            } else {
                portraitEncoderLayout
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(encoderSectionBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(DigitonePadTheme.darkHardware.secondaryColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Section Header
    
    @ViewBuilder
    private var sectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PARAMETERS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.textColor)
                
                Text(sectionSubtitle)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.secondaryColor)
            }
            
            Spacer()
            
            // Page indicator
            HStack(spacing: 4) {
                ForEach(1...8, id: \.self) { page in
                    Circle()
                        .fill(page == layoutState.currentPage ? DigitonePadTheme.darkHardware.accentColor : DigitonePadTheme.darkHardware.secondaryColor.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }
    
    // MARK: - Encoder Layouts
    
    @ViewBuilder
    private var landscapeEncoderLayout: some View {
        HStack(spacing: 16) {
            ForEach(0..<8, id: \.self) { index in
                EnhancedParameterEncoder(
                    index: index,
                    layoutState: layoutState,
                    isCompact: false
                )
            }
        }
    }
    
    @ViewBuilder
    private var portraitEncoderLayout: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { index in
                    EnhancedParameterEncoder(
                        index: index,
                        layoutState: layoutState,
                        isCompact: true
                    )
                }
            }
            
            HStack(spacing: 16) {
                ForEach(4..<8, id: \.self) { index in
                    EnhancedParameterEncoder(
                        index: index,
                        layoutState: layoutState,
                        isCompact: true
                    )
                }
            }
        }
    }
    
    // MARK: - Background
    
    @ViewBuilder
    private var encoderSectionBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.4),
                        Color.black.opacity(0.2),
                        Color.black.opacity(0.4)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
    
    // MARK: - Computed Properties
    
    private var isLandscape: Bool {
        return horizontalSizeClass == .regular && verticalSizeClass == .compact
    }
    
    private var sectionSubtitle: String {
        switch layoutState.selectedFunction {
        case .grid:
            return "STEP PARAMETERS"
        case .parameter:
            return "SOUND PARAMETERS"
        case .mixer:
            return "MIXER PARAMETERS"
        }
    }
}

// MARK: - Enhanced Parameter Encoder

/// Enhanced parameter encoder with additional features
struct EnhancedParameterEncoder: View {
    let index: Int
    @ObservedObject var layoutState: MainLayoutState
    let isCompact: Bool
    
    @State private var isDragging = false
    @State private var lastDragValue: CGFloat = 0
    @State private var showValuePopup = false
    
    var body: some View {
        VStack(spacing: isCompact ? 6 : 8) {
            // Encoder knob
            ZStack {
                // Outer ring
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                DigitonePadTheme.darkHardware.secondaryColor.opacity(0.3),
                                DigitonePadTheme.darkHardware.primaryColor.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: knobSize + 4, height: knobSize + 4)
                
                // Main knob body
                Circle()
                    .fill(knobGradient)
                    .frame(width: knobSize, height: knobSize)
                    .overlay(
                        Circle()
                            .stroke(DigitonePadTheme.darkHardware.primaryColor.opacity(0.2), lineWidth: 1)
                    )
                
                // Value arc
                Circle()
                    .trim(from: 0, to: CGFloat(layoutState.parameterValues[index]))
                    .stroke(
                        DigitonePadTheme.darkHardware.accentColor,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: knobSize - 8, height: knobSize - 8)
                    .rotationEffect(.degrees(-90))
                
                // Indicator line
                Rectangle()
                    .fill(DigitonePadTheme.darkHardware.displayColor)
                    .frame(width: 2, height: knobSize * 0.3)
                    .offset(y: -knobSize * 0.25)
                    .rotationEffect(Angle(degrees: rotationAngle))
            }
            .scaleEffect(isDragging ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isDragging)
            .gesture(dragGesture)
            .overlay(
                // Value popup
                Group {
                    if showValuePopup {
                        valuePopup
                            .offset(y: -knobSize * 0.8)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
            )
            
            // Parameter label
            Text(layoutState.parameterLabels[index])
                .font(.system(size: isCompact ? 10 : 12, weight: .medium, design: .monospaced))
                .foregroundColor(DigitonePadTheme.darkHardware.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // Parameter value
            Text(formattedValue)
                .font(.system(size: isCompact ? 9 : 10, weight: .bold, design: .monospaced))
                .foregroundColor(DigitonePadTheme.darkHardware.displayColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var knobSize: CGFloat {
        return isCompact ? 50 : 60
    }
    
    private var rotationAngle: Double {
        let normalizedValue = layoutState.parameterValues[index]
        return normalizedValue * 270 - 135 // -135° to +135° range
    }
    
    private var formattedValue: String {
        let value = layoutState.parameterValues[index]
        
        // Format based on FM TONE mode and current page/encoder
        if layoutState.isFMToneMode {
            return formatFMParameterValue(page: layoutState.currentPage, encoder: index, value: value)
        } else {
            return String(format: "%.2f", value)
        }
    }
    
    private func formatFMParameterValue(page: Int, encoder: Int, value: Double) -> String {
        switch (page, encoder) {
        // Page 1 - Core FM Parameters
        case (1, 0): // Algorithm
            let algoNumber = Int(value * 7) + 1
            return "\(algoNumber)"
        case (1, 1), (1, 2), (1, 3): // Ratios C/A/B
            let ratioValue = 0.5 + value * 31.5
            return String(format: "%.1f", ratioValue)
        case (1, 4): // Harmony
            let harmonyValue = Int(value * 127)
            return "\(harmonyValue)"
        case (1, 5): // Detune
            let detuneValue = Int((value - 0.5) * 127) // -64 to +63
            return detuneValue >= 0 ? "+\(detuneValue)" : "\(detuneValue)"
        case (1, 6), (1, 7): // Feedback, Mix
            let percentage = Int(value * 100)
            return "\(percentage)%"
            
        // Page 2 - Envelope parameters
        case (2, 0), (2, 1), (2, 4), (2, 5): // Attack, Decay times
            let timeValue = value * 10.0 // 0-10 seconds
            return String(format: "%.2fs", timeValue)
        case (2, 2), (2, 6): // End levels
            let percentage = Int(value * 100)
            return "\(percentage)%"
        case (2, 3), (2, 7): // Operator levels
            let level = Int(value * 127)
            return "\(level)"
            
        // Page 3 - Envelope behavior
        case (3, 0): // Delay
            let delayTime = value * 5.0
            return String(format: "%.2fs", delayTime)
        case (3, 1), (3, 2): // Trig Mode, Phase Reset (discrete)
            return value > 0.5 ? "ON" : "OFF"
        case (3, 7): // Key Tracking
            let trackingValue = value * 200 - 100 // -100 to +100
            return String(format: "%.0f%%", trackingValue)
            
        // Page 4 - Offsets & Key Tracking
        case (4, 0), (4, 1): // Offsets A/B
            let offsetValue = (value - 0.5) * 200 // -100 to +100
            return String(format: "%.0f", offsetValue)
        case (4, 2): // Key Tracking
            let trackingValue = value * 200
            return String(format: "%.0f%%", trackingValue)
        case (4, 3): // Velocity Sensitivity
            let percentage = Int(value * 100)
            return "\(percentage)%"
        case (4, 4), (4, 5): // Scale, Root (discrete 0-11)
            let scaleValue = Int(value * 11)
            return "\(scaleValue)"
        case (4, 6): // Tune
            let tuneValue = (value - 0.5) * 48 // -24 to +24 semitones
            return String(format: "%.0f", tuneValue)
        case (4, 7): // Fine
            let fineValue = (value - 0.5) * 200 // -100 to +100 cents
            return String(format: "%.0f", fineValue)
            
        default:
            let percentage = Int(value * 100)
            return "\(percentage)%"
        }
    }
    
    private var knobGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                DigitonePadTheme.darkHardware.knobColor.opacity(0.9),
                DigitonePadTheme.darkHardware.knobColor.opacity(0.6),
                DigitonePadTheme.darkHardware.knobColor.opacity(0.9)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    @ViewBuilder
    private var valuePopup: some View {
        Text(formattedValue)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(DigitonePadTheme.darkHardware.backgroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(DigitonePadTheme.darkHardware.accentColor)
            )
    }
    
    // MARK: - Gesture
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { gesture in
                if !isDragging {
                    isDragging = true
                    lastDragValue = gesture.translation.height
                    showValuePopup = true
                    
                    // Haptic feedback
                    #if canImport(UIKit)
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    #endif
                }
                
                let sensitivity: CGFloat = 0.01
                let delta = (lastDragValue - gesture.translation.height) * sensitivity
                lastDragValue = gesture.translation.height
                
                let newValue = layoutState.parameterValues[index] + Double(delta)
                let clampedValue = max(0.0, min(1.0, newValue))
                
                // Quantize to step for smoother control
                let step = 0.01
                let quantizedValue = round(clampedValue / step) * step
                
                // Update layout state
                layoutState.parameterValues[index] = quantizedValue
                
                // Update FM parameter bridge for real-time audio (if in FM mode)
                if layoutState.isFMToneMode {
                    layoutState.updateEncoderValue(index, value: quantizedValue)
                }
            }
            .onEnded { _ in
                isDragging = false
                
                // Hide popup after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showValuePopup = false
                }
                
                // Haptic feedback
                #if canImport(UIKit)
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                #endif
            }
    }
}

// MARK: - Preview

struct ParameterEncoderSection_Previews: PreviewProvider {
    static var previews: some View {
        let layoutState = MainLayoutState()
        
        Group {
            // Portrait preview
            ParameterEncoderSection(layoutState: layoutState)
                .previewLayout(.fixed(width: 375, height: 200))
                .previewDisplayName("Portrait")
            
            // Landscape preview
            ParameterEncoderSection(layoutState: layoutState)
                .previewLayout(.fixed(width: 667, height: 150))
                .previewDisplayName("Landscape")
        }
        .background(DigitonePadTheme.darkHardware.backgroundColor)
    }
}
