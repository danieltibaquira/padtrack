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
        return String(format: "%.2f", value)
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
                layoutState.parameterValues[index] = max(0.0, min(1.0, newValue))
                
                // Quantize to step
                let step = 0.01
                layoutState.parameterValues[index] = round(layoutState.parameterValues[index] / step) * step
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
