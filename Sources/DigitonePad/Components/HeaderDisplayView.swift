// HeaderDisplayView.swift
// DigitonePad - Header Display Component
//
// LCD-style header display component for the main application

import SwiftUI
import UIComponents

/// Header display component that mimics the Digitone LCD display
struct HeaderDisplayView: View {
    @ObservedObject private var layoutState: MainLayoutState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    public init(layoutState: MainLayoutState) {
        self.layoutState = layoutState
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Main LCD Display
            mainDisplayArea
            
            // Status Bar
            statusBar
        }
        .background(lcdBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(DigitonePadTheme.darkHardware.secondaryColor, lineWidth: 2)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Main Display Area
    
    @ViewBuilder
    private var mainDisplayArea: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Primary display text
                Text(layoutState.displayText)
                    .font(.system(size: displayFontSize, weight: .medium, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.displayColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Secondary info line
                Text(secondaryDisplayText)
                    .font(.system(size: displayFontSize * 0.7, weight: .regular, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.displayColor.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            Spacer()
            
            // Right side indicators
            VStack(alignment: .trailing, spacing: 4) {
                // Transport status
                transportStatusIndicator
                
                // Recording indicator
                if layoutState.isRecording {
                    recordingIndicator
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Status Bar
    
    @ViewBuilder
    private var statusBar: some View {
        HStack(spacing: 16) {
            // Left side status
            HStack(spacing: 12) {
                StatusIndicator(
                    label: "BPM",
                    value: "120",
                    isActive: layoutState.isPlaying
                )
                
                StatusIndicator(
                    label: "PATTERN",
                    value: "A\(String(format: "%02d", layoutState.currentPage))",
                    isActive: true
                )
                
                StatusIndicator(
                    label: "TRACK",
                    value: "\(layoutState.selectedTrack)",
                    isActive: true
                )
            }
            
            Spacer()
            
            // Right side status
            HStack(spacing: 12) {
                StatusIndicator(
                    label: "MODE",
                    value: layoutState.currentMode.rawValue,
                    isActive: true
                )
                
                StatusIndicator(
                    label: "FUNC",
                    value: layoutState.selectedFunction.rawValue,
                    isActive: true
                )
                
                // Step position indicator
                StatusIndicator(
                    label: "STEP",
                    value: layoutState.currentStep >= 0 ? "\(layoutState.currentStep + 1)" : "--",
                    isActive: layoutState.currentStep >= 0
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.3))
        )
    }
    
    // MARK: - Supporting Views
    
    @ViewBuilder
    private var transportStatusIndicator: some View {
        HStack(spacing: 4) {
            if layoutState.isPlaying {
                Image(systemName: "play.fill")
                    .foregroundColor(DigitonePadTheme.darkHardware.accentColor)
                    .font(.caption)
                Text("PLAY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.accentColor)
            } else {
                Image(systemName: "pause.fill")
                    .foregroundColor(DigitonePadTheme.darkHardware.secondaryColor)
                    .font(.caption)
                Text("STOP")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.secondaryColor)
            }
        }
    }
    
    @ViewBuilder
    private var recordingIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(recordingBlinkOpacity)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: recordingBlinkOpacity)
            
            Text("REC")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color.red)
        }
        .onAppear {
            recordingBlinkOpacity = 0.3
        }
    }
    
    @ViewBuilder
    private var lcdBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color.black.opacity(0.9),
                        Color.black
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
    
    // MARK: - Computed Properties
    
    private var displayFontSize: CGFloat {
        if horizontalSizeClass == .regular && verticalSizeClass == .compact {
            return 20 // Landscape
        } else {
            return 18 // Portrait
        }
    }
    
    private var secondaryDisplayText: String {
        switch layoutState.selectedFunction {
        case .grid:
            return "GRID MODE - STEP SEQUENCER"
        case .parameter:
            return "PARAMETER MODE - \(layoutState.parameterLabels[0])"
        case .mixer:
            return "MIXER MODE - TRACK \(layoutState.selectedTrack)"
        }
    }
    
    @State private var recordingBlinkOpacity: Double = 1.0
}

// MARK: - Enhanced Status Indicator

/// Enhanced status indicator with better styling
struct StatusIndicator: View {
    let label: String
    let value: String
    let isActive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(DigitonePadTheme.darkHardware.secondaryColor)
            
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(isActive ? DigitonePadTheme.darkHardware.displayColor : DigitonePadTheme.darkHardware.textColor.opacity(0.6))
                .frame(minWidth: 24, alignment: .leading)
        }
    }
}

// MARK: - Preview

struct HeaderDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        let layoutState = MainLayoutState()
        
        Group {
            // Portrait preview
            HeaderDisplayView(layoutState: layoutState)
                .previewLayout(.fixed(width: 375, height: 120))
                .previewDisplayName("Portrait")
            
            // Landscape preview
            HeaderDisplayView(layoutState: layoutState)
                .previewLayout(.fixed(width: 667, height: 100))
                .previewDisplayName("Landscape")
            
            // Playing state preview
            HeaderDisplayView(layoutState: {
                let state = MainLayoutState()
                state.isPlaying = true
                state.currentStep = 4
                return state
            }())
            .previewLayout(.fixed(width: 375, height: 120))
            .previewDisplayName("Playing")
            
            // Recording state preview
            HeaderDisplayView(layoutState: {
                let state = MainLayoutState()
                state.isRecording = true
                state.isPlaying = true
                return state
            }())
            .previewLayout(.fixed(width: 375, height: 120))
            .previewDisplayName("Recording")
        }
        .background(DigitonePadTheme.darkHardware.backgroundColor)
    }
}
