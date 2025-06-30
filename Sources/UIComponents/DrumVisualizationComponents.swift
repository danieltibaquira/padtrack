//
//  DrumVisualizationComponents.swift
//  DigitonePad - UIComponents
//
//  Visualization components for drum synthesis parameters
//

import SwiftUI

// MARK: - Envelope Visualization

/// Visual representation of ADSR envelope for drums
public struct EnvelopeVisualization: View {
    let attack: Double
    let decay: Double
    let sustain: Double
    let release: Double
    let title: String
    
    public init(attack: Double, decay: Double, sustain: Double, release: Double, title: String) {
        self.attack = attack
        self.decay = decay
        self.sustain = sustain
        self.release = release
        self.title = title
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption2)
                .foregroundColor(DigitonePadTheme.darkHardware.secondaryColor)
            
            Canvas { context, size in
                drawEnvelope(context: context, size: size)
            }
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.5))
            )
        }
    }
    
    private func drawEnvelope(context: GraphicsContext, size: CGSize) {
        let width = size.width - 16
        let height = size.height - 16
        let startX: CGFloat = 8
        let startY = size.height - 8
        
        // Calculate time proportions (drums typically have very short envelopes)
        let totalTime = attack + decay + release
        let attackWidth = width * (attack / totalTime)
        let decayWidth = width * (decay / totalTime)
        let releaseWidth = width * (release / totalTime)
        
        // Create envelope path
        var path = Path()
        
        // Start at zero
        path.move(to: CGPoint(x: startX, y: startY))
        
        // Attack phase
        path.addLine(to: CGPoint(x: startX + attackWidth, y: startY - height))
        
        // Decay phase (to sustain level, usually 0 for drums)
        let sustainY = startY - (height * sustain)
        path.addLine(to: CGPoint(x: startX + attackWidth + decayWidth, y: sustainY))
        
        // Release phase (back to zero)
        path.addLine(to: CGPoint(x: startX + attackWidth + decayWidth + releaseWidth, y: startY))
        
        // Draw the envelope
        context.stroke(
            path,
            with: .color(DigitonePadTheme.darkHardware.accentColor),
            lineWidth: 2
        )
        
        // Fill under the curve
        var fillPath = path
        fillPath.addLine(to: CGPoint(x: startX, y: startY))
        fillPath.closeSubpath()
        
        context.fill(
            fillPath,
            with: .color(DigitonePadTheme.darkHardware.accentColor.opacity(0.3))
        )
        
        // Draw phase markers
        drawPhaseMarkers(context: context, 
                        startX: startX, 
                        startY: startY, 
                        attackWidth: attackWidth, 
                        decayWidth: decayWidth, 
                        releaseWidth: releaseWidth)
    }
    
    private func drawPhaseMarkers(context: GraphicsContext, 
                                 startX: CGFloat, 
                                 startY: CGFloat, 
                                 attackWidth: CGFloat, 
                                 decayWidth: CGFloat, 
                                 releaseWidth: CGFloat) {
        let markerColor = DigitonePadTheme.darkHardware.secondaryColor.opacity(0.6)
        
        // Attack marker
        let attackX = startX + attackWidth
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: attackX, y: startY))
                path.addLine(to: CGPoint(x: attackX, y: startY - 40))
            },
            with: .color(markerColor),
            style: StrokeStyle(lineWidth: 1, dash: [2, 2])
        )
        
        // Decay marker
        let decayX = attackX + decayWidth
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: decayX, y: startY))
                path.addLine(to: CGPoint(x: decayX, y: startY - 40))
            },
            with: .color(markerColor),
            style: StrokeStyle(lineWidth: 1, dash: [2, 2])
        )
    }
}

// MARK: - Wavefold Visualization

/// Visual representation of wavefolding distortion
public struct WavefoldVisualization: View {
    let amount: Double
    
    public init(amount: Double) {
        self.amount = amount
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            Text("WAVEFOLD")
                .font(.caption2)
                .foregroundColor(DigitonePadTheme.darkHardware.secondaryColor)
            
            Canvas { context, size in
                drawWaveform(context: context, size: size)
            }
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.5))
            )
        }
    }
    
    private func drawWaveform(context: GraphicsContext, size: CGSize) {
        let width = size.width - 16
        let height = size.height - 16
        let centerY = size.height / 2
        let startX: CGFloat = 8
        
        // Draw original sine wave
        var originalPath = Path()
        var foldedPath = Path()
        
        let samples = 100
        for i in 0...samples {
            let x = startX + (width * CGFloat(i) / CGFloat(samples))
            let phase = Double(i) * 2.0 * .pi / Double(samples)
            
            // Original sine wave
            let originalY = centerY - (height / 2) * sin(phase)
            if i == 0 {
                originalPath.move(to: CGPoint(x: x, y: originalY))
                foldedPath.move(to: CGPoint(x: x, y: originalY))
            } else {
                originalPath.addLine(to: CGPoint(x: x, y: originalY))
            }
            
            // Folded wave
            let sineValue = sin(phase)
            let foldedValue = applyWavefolding(sineValue, amount: amount)
            let foldedY = centerY - (height / 2) * foldedValue
            foldedPath.addLine(to: CGPoint(x: x, y: foldedY))
        }
        
        // Draw original wave (dimmed)
        context.stroke(
            originalPath,
            with: .color(DigitonePadTheme.darkHardware.secondaryColor.opacity(0.3)),
            lineWidth: 1
        )
        
        // Draw folded wave
        context.stroke(
            foldedPath,
            with: .color(DigitonePadTheme.darkHardware.accentColor),
            lineWidth: 2
        )
        
        // Draw fold threshold lines
        if amount > 0.1 {
            let threshold = 1.0 - amount
            let thresholdY1 = centerY - (height / 2) * threshold
            let thresholdY2 = centerY + (height / 2) * threshold
            
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: startX, y: thresholdY1))
                    path.addLine(to: CGPoint(x: startX + width, y: thresholdY1))
                    path.move(to: CGPoint(x: startX, y: thresholdY2))
                    path.addLine(to: CGPoint(x: startX + width, y: thresholdY2))
                },
                with: .color(DigitonePadTheme.darkHardware.primaryColor.opacity(0.5)),
                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
            )
        }
    }
    
    private func applyWavefolding(_ input: Double, amount: Double) -> Double {
        guard amount > 0.0 else { return input }
        
        let threshold = 1.0 - amount
        let scaledInput = input / threshold
        
        if abs(scaledInput) <= 1.0 {
            return scaledInput * threshold
        } else {
            // Fold the wave
            let folded = 2.0 - abs(scaledInput)
            return (scaledInput < 0 ? -folded : folded) * threshold
        }
    }
}

// MARK: - Parameter Knob

/// Rotary knob control for parameters
public struct ParameterKnob: View {
    let parameter: DigitonePadParameter?
    let title: String
    let theme: DigitonePadTheme
    @State private var isDragging = false
    @State private var dragStartValue: Double = 0
    @State private var dragStartLocation: CGPoint = .zero
    
    public init(parameter: DigitonePadParameter?, title: String, theme: DigitonePadTheme) {
        self.parameter = parameter
        self.title = title
        self.theme = theme
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Knob
            ZStack {
                // Outer ring
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                theme.secondaryColor.opacity(0.3),
                                theme.primaryColor.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 54, height: 54)
                
                // Main knob body
                Circle()
                    .fill(knobGradient)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(theme.primaryColor.opacity(0.2), lineWidth: 1)
                    )
                
                // Value indicator
                Rectangle()
                    .fill(theme.accentColor)
                    .frame(width: 2, height: 15)
                    .offset(y: -12)
                    .rotationEffect(.degrees(knobRotation))
                
                // Center dot
                Circle()
                    .fill(theme.primaryColor.opacity(0.8))
                    .frame(width: 4, height: 4)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStartValue = parameter?.normalizedValue ?? 0
                            dragStartLocation = value.startLocation
                        }
                        
                        let deltaY = dragStartLocation.y - value.location.y
                        let sensitivity: Double = 0.005
                        let newValue = dragStartValue + (Double(deltaY) * sensitivity)
                        
                        // Update parameter value (this would need proper binding)
                        // parameter?.setNormalizedValue(max(0, min(1, newValue)))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            
            // Title and value
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(theme.secondaryColor)
                
                Text(valueText)
                    .font(.caption2)
                    .foregroundColor(theme.primaryColor)
                    .monospacedDigit()
            }
        }
    }
    
    private var knobGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                theme.knobColor.opacity(0.9),
                theme.knobColor.opacity(0.6),
                theme.knobColor.opacity(0.9)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var knobRotation: Double {
        let normalizedValue = parameter?.normalizedValue ?? 0
        return -135 + (normalizedValue * 270) // -135° to +135° range
    }
    
    private var valueText: String {
        guard let parameter = parameter else { return "--" }
        
        if parameter.unit.isEmpty {
            return String(format: "%.2f", parameter.value)
        } else {
            return String(format: "%.1f%@", parameter.value, parameter.unit)
        }
    }
}

// MARK: - Preview Support

#if DEBUG
struct DrumVisualizationComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            EnvelopeVisualization(
                attack: 0.001,
                decay: 0.3,
                sustain: 0.0,
                release: 0.1,
                title: "AMP ENV"
            )
            
            WavefoldVisualization(amount: 0.5)
            
            HStack {
                ParameterKnob(
                    parameter: DigitonePadParameter(
                        name: "Test",
                        value: 0.7,
                        range: 0...1,
                        unit: ""
                    ),
                    title: "LEVEL",
                    theme: .darkHardware
                )
            }
        }
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
#endif
