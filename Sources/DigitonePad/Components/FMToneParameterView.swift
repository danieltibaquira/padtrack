// FMToneParameterView.swift
// DigitonePad - FM TONE Parameter View Component
//
// Specialized parameter view for FM TONE voice machine parameters

import SwiftUI
import UIComponents
import VoiceModule

/// FM TONE specific parameter view with 4-page navigation
public struct FMToneParameterView: View {
    @ObservedObject private var layoutState: MainLayoutState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    // FM Voice Machine reference for parameter updates
    private let fmVoiceMachine: FMVoiceMachine?
    
    public init(layoutState: MainLayoutState, fmVoiceMachine: FMVoiceMachine? = nil) {
        self.layoutState = layoutState
        self.fmVoiceMachine = fmVoiceMachine
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Page header with FM TONE branding
            fmTonePageHeader
            
            // Parameter content area
            fmToneParameterContentArea
            
            // Page navigation controls (limited to 4 pages for FM TONE)
            fmTonePageNavigationControls
        }
        .padding(16)
        .background(fmTonePageBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DigitonePadTheme.darkHardware.accentColor.opacity(0.4), lineWidth: 2)
        )
        .onAppear {
            layoutState.setFMToneMode(true)
        }
        .onDisappear {
            layoutState.setFMToneMode(false)
        }
    }
    
    // MARK: - FM TONE Page Header
    
    @ViewBuilder
    private var fmTonePageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("FM TONE PARAMETERS")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.accentColor)
                
                Text(fmTonePageSubtitle)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.textColor)
            }
            
            Spacer()
            
            // Current page indicator (1-4 for FM TONE)
            HStack(spacing: 8) {
                Text("PAGE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.secondaryColor)
                
                DigitonePadDisplay(
                    text: "\(min(layoutState.currentPage, 4))",
                    isActive: true,
                    theme: .darkHardware
                )
                .frame(width: 40, height: 24)
                
                Text("/ 4")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.secondaryColor)
            }
        }
    }
    
    // MARK: - FM TONE Parameter Content Area
    
    @ViewBuilder
    private var fmToneParameterContentArea: some View {
        VStack(spacing: 20) {
            // Parameter grid with FM TONE specific styling
            fmToneParameterGrid
            
            // Parameter value displays with real-time updates
            fmToneParameterValueDisplays
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.4),
                            DigitonePadTheme.darkHardware.accentColor.opacity(0.1),
                            Color.black.opacity(0.4)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .padding(8)
    }
    
    // MARK: - FM TONE Parameter Grid
    
    @ViewBuilder
    private var fmToneParameterGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(0..<8, id: \.self) { index in
                FMToneParameterCard(
                    index: index,
                    layoutState: layoutState,
                    fmVoiceMachine: fmVoiceMachine
                )
            }
        }
    }
    
    // MARK: - FM TONE Parameter Value Displays
    
    @ViewBuilder
    private var fmToneParameterValueDisplays: some View {
        VStack(spacing: 12) {
            // Top row (parameters 0-3)
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { index in
                    FMToneValueDisplay(
                        index: index,
                        layoutState: layoutState
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            
            // Bottom row (parameters 4-7)
            HStack(spacing: 12) {
                ForEach(4..<8, id: \.self) { index in
                    FMToneValueDisplay(
                        index: index,
                        layoutState: layoutState
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - FM TONE Page Navigation Controls
    
    @ViewBuilder
    private var fmTonePageNavigationControls: some View {
        HStack(spacing: 20) {
            // Previous page button
            DigitonePadButton(
                config: ButtonConfig(
                    title: "◀ PREV",
                    style: layoutState.currentPage > 1 ? .primary : .disabled,
                    onTap: {
                        if layoutState.currentPage > 1 {
                            layoutState.previousPage()
                        }
                    }
                ),
                theme: .darkHardware
            )
            .frame(maxWidth: .infinity)
            
            // Page indicators (1-4 for FM TONE)
            HStack(spacing: 8) {
                ForEach(1...4, id: \.self) { page in
                    VStack(spacing: 2) {
                        Circle()
                            .fill(page == layoutState.currentPage ? 
                                  DigitonePadTheme.darkHardware.accentColor : 
                                  DigitonePadTheme.darkHardware.secondaryColor.opacity(0.3))
                            .frame(width: 10, height: 10)
                            .onTapGesture {
                                layoutState.setPage(page)
                            }
                        
                        Text(fmTonePageNames[page - 1])
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(page == layoutState.currentPage ? 
                                           DigitonePadTheme.darkHardware.accentColor : 
                                           DigitonePadTheme.darkHardware.secondaryColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            // Next page button
            DigitonePadButton(
                config: ButtonConfig(
                    title: "NEXT ▶",
                    style: layoutState.currentPage < 4 ? .primary : .disabled,
                    onTap: {
                        if layoutState.currentPage < 4 {
                            layoutState.nextPage()
                        }
                    }
                ),
                theme: .darkHardware
            )
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var fmTonePageBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.8),
                        DigitonePadTheme.darkHardware.accentColor.opacity(0.1),
                        Color.black.opacity(0.6),
                        DigitonePadTheme.darkHardware.accentColor.opacity(0.05),
                        Color.black.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    // MARK: - Computed Properties

    private var isLandscape: Bool {
        return horizontalSizeClass == .regular && verticalSizeClass == .compact
    }

    private var gridColumns: [GridItem] {
        let columns = isLandscape ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: columns)
    }

    private var fmTonePageSubtitle: String {
        let pageNames = fmTonePageNames
        let pageIndex = min(layoutState.currentPage - 1, 3)
        return pageNames[pageIndex]
    }
    
    private var fmTonePageNames: [String] {
        return [
            "CORE FM",      // Page 1
            "ENVELOPES",    // Page 2
            "BEHAVIOR",     // Page 3
            "TRACKING"      // Page 4
        ]
    }
}

// MARK: - FM TONE Parameter Card

/// Individual FM TONE parameter card with specialized styling
struct FMToneParameterCard: View {
    let index: Int
    @ObservedObject var layoutState: MainLayoutState
    let fmVoiceMachine: FMVoiceMachine?
    
    @State private var isDragging: Bool = false
    @State private var lastDragValue: CGFloat = 0

    var body: some View {
        VStack(spacing: 8) {
            // Parameter name with FM TONE styling
            Text(layoutState.parameterLabels[index])
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(DigitonePadTheme.darkHardware.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Parameter value and control
            VStack(spacing: 6) {
                // Value display
                DigitonePadDisplay(
                    text: formattedFMValue,
                    isActive: true,
                    theme: .darkHardware
                )
                .frame(height: 24)

                // Interactive value bar with gesture handling
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DigitonePadTheme.darkHardware.secondaryColor.opacity(0.3))
                            .frame(height: 8)

                        // Value bar with FM TONE accent
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        DigitonePadTheme.darkHardware.accentColor.opacity(0.8),
                                        DigitonePadTheme.darkHardware.accentColor,
                                        DigitonePadTheme.darkHardware.accentColor.opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(layoutState.parameterValues[index]), height: 8)
                    }
                }
                .frame(height: 8)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                lastDragValue = value.location.x
                            }
                            
                            updateParameterValue(dragLocation: value.location.x, geometryWidth: UIScreen.main.bounds.width * 0.2)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isDragging ? 
                            DigitonePadTheme.darkHardware.accentColor.opacity(0.6) :
                            DigitonePadTheme.darkHardware.secondaryColor.opacity(0.2), 
                            lineWidth: isDragging ? 2 : 1
                        )
                )
        )
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isDragging)
    }

    private var formattedFMValue: String {
        let value = layoutState.parameterValues[index]
        
        // Format value based on current page and parameter
        switch layoutState.currentPage {
        case 1:
            // Page 1 - Core FM parameters
            switch index {
            case 0: // Algorithm
                return "\(Int(value * 4) + 1)"
            case 1, 2, 3: // Ratios
                return String(format: "%.2f", value * 32.0)
            default:
                return String(format: "%.2f", value)
            }
        case 2:
            // Page 2 - Envelope parameters
            return String(format: "%.2f", value)
        case 3:
            // Page 3 - Behavior parameters
            return String(format: "%.2f", value)
        case 4:
            // Page 4 - Tracking parameters
            return String(format: "%.2f", value)
        default:
            return String(format: "%.2f", value)
        }
    }
    
    private func updateParameterValue(dragLocation: CGFloat, geometryWidth: CGFloat) {
        let newValue = max(0.0, min(1.0, dragLocation / geometryWidth))
        
        // Update the layout state
        layoutState.parameterValues[index] = newValue
        
        // Update the corresponding FM parameter in the voice machine
        updateFMVoiceMachineParameter(newValue)
    }
    
    private func updateFMVoiceMachineParameter(_ normalizedValue: Double) {
        guard let fmVoiceMachine = fmVoiceMachine else { return }
        
        do {
            switch layoutState.currentPage {
            case 1:
                // Page 1 - Core FM parameters
                switch index {
                case 0: // Algorithm
                    let algorithmValue = Int(normalizedValue * 4) + 1
                    try fmVoiceMachine.updateParameter(key: "algorithm", value: algorithmValue)
                    layoutState.updateFMToneParameter(key: "algorithm", value: Double(algorithmValue))
                    
                case 1: // Ratio C (Carrier)
                    let ratioValue = normalizedValue * 32.0
                    try fmVoiceMachine.updateParameter(key: "operator4_ratio", value: ratioValue)
                    layoutState.updateFMToneParameter(key: "operator4_ratio", value: ratioValue)
                    
                case 2: // Ratio A
                    let ratioValue = normalizedValue * 32.0
                    try fmVoiceMachine.updateParameter(key: "operator1_ratio", value: ratioValue)
                    layoutState.updateFMToneParameter(key: "operator1_ratio", value: ratioValue)
                    
                case 3: // Ratio B
                    let ratioValue = normalizedValue * 32.0
                    try fmVoiceMachine.updateParameter(key: "operator2_ratio", value: ratioValue)
                    layoutState.updateFMToneParameter(key: "operator2_ratio", value: ratioValue)
                    
                case 7: // Mix
                    layoutState.updateFMToneParameter(key: "mix", value: normalizedValue)
                    
                default:
                    break
                }
                
            case 2:
                // Page 2 - Envelope parameters
                switch index {
                case 3: // LEV A
                    try fmVoiceMachine.updateParameter(key: "operator1_level", value: normalizedValue)
                    layoutState.updateFMToneParameter(key: "operator1_level", value: normalizedValue)
                    
                case 7: // LEV B
                    try fmVoiceMachine.updateParameter(key: "operator2_level", value: normalizedValue)
                    layoutState.updateFMToneParameter(key: "operator2_level", value: normalizedValue)
                    
                default:
                    break
                }
                
            default:
                break
            }
        } catch {
            print("Error updating FM parameter: \(error)")
        }
    }
}

// MARK: - FM TONE Value Display

/// Specialized value display for FM TONE parameters
struct FMToneValueDisplay: View {
    let index: Int
    @ObservedObject var layoutState: MainLayoutState
    
    var body: some View {
        VStack(spacing: 4) {
            Text(layoutState.parameterLabels[index])
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(DigitonePadTheme.darkHardware.accentColor)
                .lineLimit(1)
            
            DigitonePadDisplay(
                text: formattedDisplayValue,
                isActive: true,
                theme: .darkHardware
            )
            .frame(height: 20)
        }
    }
    
    private var formattedDisplayValue: String {
        let value = layoutState.parameterValues[index]
        
        // Format display value based on current page and parameter
        switch layoutState.currentPage {
        case 1:
            // Page 1 - Core FM parameters
            switch index {
            case 0: // Algorithm
                return "ALG\(Int(value * 4) + 1)"
            case 1, 2, 3: // Ratios
                return String(format: "%.2f", value * 32.0)
            default:
                return String(format: "%.0f", value * 127)
            }
        default:
            return String(format: "%.0f", value * 127)
        }
    }
} 