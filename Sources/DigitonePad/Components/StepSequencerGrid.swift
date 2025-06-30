// StepSequencerGrid.swift
// DigitonePad - Step Sequencer Grid Component
//
// 16-step sequencer grid with advanced features

import SwiftUI
import UIComponents

/// 16-step sequencer grid component with advanced features
struct StepSequencerGrid: View {
    @ObservedObject private var layoutState: MainLayoutState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    @State private var pressedSteps: Set<Int> = []
    @State private var longPressStep: Int? = nil
    
    public init(layoutState: MainLayoutState) {
        self.layoutState = layoutState
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Grid header
            gridHeader
            
            // Step grid
            stepGrid
            
            // Grid controls
            gridControls
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(gridBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(DigitonePadTheme.darkHardware.secondaryColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Grid Header
    
    @ViewBuilder
    private var gridHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("STEP SEQUENCER")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.textColor)
                
                Text("TRACK \(layoutState.selectedTrack) - \(layoutState.activeSteps.count)/16 STEPS")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.secondaryColor)
            }
            
            Spacer()
            
            // Step position indicator
            HStack(spacing: 4) {
                Text("STEP")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.secondaryColor)
                
                Text(layoutState.currentStep >= 0 ? "\(layoutState.currentStep + 1)" : "--")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(layoutState.currentStep >= 0 ? DigitonePadTheme.darkHardware.accentColor : DigitonePadTheme.darkHardware.textColor)
                    .frame(minWidth: 24)
            }
        }
    }
    
    // MARK: - Step Grid
    
    @ViewBuilder
    private var stepGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnsCount)
        
        LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(0..<16, id: \.self) { step in
                StepButton(
                    step: step,
                    layoutState: layoutState,
                    isPressed: pressedSteps.contains(step),
                    isLongPressed: longPressStep == step,
                    size: stepButtonSize,
                    onTap: { handleStepTap(step) },
                    onLongPress: { handleStepLongPress(step) }
                )
            }
        }
    }
    
    // MARK: - Grid Controls
    
    @ViewBuilder
    private var gridControls: some View {
        HStack(spacing: 12) {
            // Clear all button
            DigitonePadButton(
                config: ButtonConfig(
                    title: "CLEAR",
                    style: .secondary,
                    onTap: { layoutState.clearAllSteps() }
                ),
                theme: .darkHardware
            )
            .frame(height: 32)
            
            // Fill button
            DigitonePadButton(
                config: ButtonConfig(
                    title: "FILL",
                    style: .secondary,
                    onTap: { layoutState.setAllSteps() }
                ),
                theme: .darkHardware
            )
            .frame(height: 32)
            
            Spacer()
            
            // Pattern length
            HStack(spacing: 8) {
                Text("LENGTH")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.secondaryColor)
                
                Text("16")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.displayColor)
                    .frame(minWidth: 24)
            }
        }
    }
    
    // MARK: - Background
    
    @ViewBuilder
    private var gridBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.6),
                        Color.black.opacity(0.4),
                        Color.black.opacity(0.6)
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
    
    private var columnsCount: Int {
        return isLandscape ? 8 : 4
    }
    
    private var gridSpacing: CGFloat {
        return isLandscape ? 8 : 6
    }
    
    private var stepButtonSize: CGFloat {
        return isLandscape ? 44 : 50
    }
    
    // MARK: - Actions
    
    private func handleStepTap(_ step: Int) {
        pressedSteps.insert(step)
        layoutState.toggleStep(step)
        
        // Remove pressed state after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pressedSteps.remove(step)
        }
        
        // Haptic feedback
        #if canImport(UIKit)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        #endif
    }
    
    private func handleStepLongPress(_ step: Int) {
        longPressStep = step
        
        // Show parameter lock interface (placeholder)
        // This would open a parameter lock editing interface
        
        // Reset long press state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            longPressStep = nil
        }
        
        // Haptic feedback
        #if canImport(UIKit)
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        #endif
    }
}

// MARK: - Step Button

/// Individual step button with advanced styling
struct StepButton: View {
    let step: Int
    @ObservedObject var layoutState: MainLayoutState
    let isPressed: Bool
    let isLongPressed: Bool
    let size: CGFloat
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    @State private var isHighlighted = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Main button background
                RoundedRectangle(cornerRadius: 6)
                    .fill(buttonGradient)
                    .frame(width: size, height: size)
                
                // Border
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: borderWidth)
                    .frame(width: size, height: size)
                
                // Step number
                Text("\(step + 1)")
                    .font(.system(size: stepNumberFontSize, weight: .bold, design: .monospaced))
                    .foregroundColor(textColor)
                
                // Playing indicator
                if layoutState.currentStep == step {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(DigitonePadTheme.darkHardware.accentColor, lineWidth: 3)
                        .frame(width: size + 2, height: size + 2)
                        .opacity(playingOpacity)
                        .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: playingOpacity)
                }
                
                // Parameter lock indicator
                if hasParameterLock {
                    Circle()
                        .fill(DigitonePadTheme.darkHardware.displayColor)
                        .frame(width: 4, height: 4)
                        .offset(x: size * 0.3, y: -size * 0.3)
                }
            }
        }
        .scaleEffect(scaleEffect)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .animation(.easeInOut(duration: 0.1), value: isHighlighted)
        .onLongPressGesture(minimumDuration: 0.5) {
            onLongPress()
        }
        .onAppear {
            if layoutState.currentStep == step {
                playingOpacity = 0.3
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isActive: Bool {
        return layoutState.activeSteps.contains(step)
    }
    
    private var isPlaying: Bool {
        return layoutState.currentStep == step
    }
    
    private var hasParameterLock: Bool {
        // Placeholder - would check for parameter locks on this step
        return step % 5 == 0 && isActive // Demo: every 5th active step has parameter lock
    }
    
    private var buttonGradient: LinearGradient {
        if isPlaying {
            return LinearGradient(
                gradient: Gradient(colors: [
                    DigitonePadTheme.darkHardware.accentColor,
                    DigitonePadTheme.darkHardware.accentColor.opacity(0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isActive {
            return LinearGradient(
                gradient: Gradient(colors: [
                    DigitonePadTheme.darkHardware.primaryColor.opacity(0.8),
                    DigitonePadTheme.darkHardware.primaryColor.opacity(0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [
                    DigitonePadTheme.darkHardware.buttonColor,
                    DigitonePadTheme.darkHardware.buttonColor.opacity(0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var borderColor: Color {
        if isLongPressed {
            return DigitonePadTheme.darkHardware.displayColor
        } else if isPlaying {
            return DigitonePadTheme.darkHardware.accentColor.opacity(0.8)
        } else if isActive {
            return DigitonePadTheme.darkHardware.primaryColor.opacity(0.5)
        } else {
            return DigitonePadTheme.darkHardware.secondaryColor.opacity(0.3)
        }
    }
    
    private var borderWidth: CGFloat {
        return isLongPressed ? 3 : 2
    }
    
    private var textColor: Color {
        if isPlaying || isActive {
            return DigitonePadTheme.darkHardware.backgroundColor
        } else {
            return DigitonePadTheme.darkHardware.textColor
        }
    }
    
    private var stepNumberFontSize: CGFloat {
        return size > 45 ? 12 : 10
    }
    
    private var scaleEffect: CGFloat {
        if isPressed {
            return 0.9
        } else if isPlaying {
            return 1.05
        } else {
            return 1.0
        }
    }
    
    @State private var playingOpacity: Double = 1.0
}

// MARK: - Preview

struct StepSequencerGrid_Previews: PreviewProvider {
    static var previews: some View {
        let layoutState = MainLayoutState()
        
        Group {
            // Portrait preview
            StepSequencerGrid(layoutState: layoutState)
                .previewLayout(.fixed(width: 375, height: 300))
                .previewDisplayName("Portrait")
            
            // Landscape preview
            StepSequencerGrid(layoutState: layoutState)
                .previewLayout(.fixed(width: 667, height: 200))
                .previewDisplayName("Landscape")
            
            // Playing state preview
            StepSequencerGrid(layoutState: {
                let state = MainLayoutState()
                state.isPlaying = true
                state.currentStep = 4
                return state
            }())
            .previewLayout(.fixed(width: 375, height: 300))
            .previewDisplayName("Playing")
        }
        .background(DigitonePadTheme.darkHardware.backgroundColor)
    }
}
