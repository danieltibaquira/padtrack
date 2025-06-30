//
//  FMDrumVoiceView.swift
//  DigitonePad - UIComponents
//
//  User interface for the FM DRUM voice machine
//

import SwiftUI
import MachineProtocols

/// User interface for controlling the FM DRUM voice machine
public struct FMDrumVoiceView: View {
    @ObservedObject private var parameterManager: ObservableParameterManager
    @State private var selectedDrumType: DrumType = .kick
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    public init(parameterManager: ObservableParameterManager) {
        self.parameterManager = parameterManager
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header with drum type selection
            drumTypeSelector
            
            // Main parameter sections
            if isLandscape {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .padding(16)
        .background(drumMachineBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DigitonePadTheme.darkHardware.accentColor.opacity(0.3), lineWidth: 2)
        )
    }
    
    // MARK: - Drum Type Selector
    
    @ViewBuilder
    private var drumTypeSelector: some View {
        VStack(spacing: 12) {
            Text("FM DRUM")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(DigitonePadTheme.darkHardware.primaryColor)
            
            HStack(spacing: 8) {
                ForEach(DrumType.allCases, id: \.self) { drumType in
                    DrumTypeButton(
                        drumType: drumType,
                        isSelected: selectedDrumType == drumType,
                        onTap: {
                            selectedDrumType = drumType
                            updateDrumTypeParameters(drumType)
                        }
                    )
                }
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Layout Variants
    
    @ViewBuilder
    private var landscapeLayout: some View {
        HStack(spacing: 24) {
            // Left column: Body and Noise
            VStack(spacing: 20) {
                bodySection
                noiseSection
            }
            .frame(maxWidth: .infinity)
            
            // Right column: Pitch Sweep and Wavefold
            VStack(spacing: 20) {
                pitchSweepSection
                wavefoldSection
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private var portraitLayout: some View {
        VStack(spacing: 20) {
            bodySection
            noiseSection
            pitchSweepSection
            wavefoldSection
        }
    }
    
    // MARK: - Parameter Sections
    
    @ViewBuilder
    private var bodySection: some View {
        ParameterSection(title: "BODY") {
            VStack(spacing: 16) {
                ParameterKnob(
                    parameter: getParameter("body_tone"),
                    title: "TONE",
                    theme: .darkHardware
                )
                
                // Body envelope visualization
                EnvelopeVisualization(
                    attack: 0.001,
                    decay: getDecayTimeForDrumType(),
                    sustain: 0.0,
                    release: getReleaseTimeForDrumType(),
                    title: "AMP ENV"
                )
            }
        }
    }
    
    @ViewBuilder
    private var noiseSection: some View {
        ParameterSection(title: "NOISE") {
            VStack(spacing: 16) {
                ParameterKnob(
                    parameter: getParameter("noise_level"),
                    title: "LEVEL",
                    theme: .darkHardware
                )
                
                // Noise type selector
                NoiseTypeSelector(
                    selectedType: .white, // This would be bound to actual parameter
                    onTypeChanged: { _ in }
                )
            }
        }
    }
    
    @ViewBuilder
    private var pitchSweepSection: some View {
        ParameterSection(title: "PITCH SWEEP") {
            HStack(spacing: 16) {
                ParameterKnob(
                    parameter: getParameter("pitch_sweep_amount"),
                    title: "AMOUNT",
                    theme: .darkHardware
                )
                
                ParameterKnob(
                    parameter: getParameter("pitch_sweep_time"),
                    title: "TIME",
                    theme: .darkHardware
                )
            }
        }
    }
    
    @ViewBuilder
    private var wavefoldSection: some View {
        ParameterSection(title: "WAVEFOLD") {
            VStack(spacing: 16) {
                ParameterKnob(
                    parameter: getParameter("wavefold_amount"),
                    title: "AMOUNT",
                    theme: .darkHardware
                )
                
                // Wavefold visualization
                WavefoldVisualization(
                    amount: getParameter("wavefold_amount")?.normalizedValue ?? 0.0
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getParameter(_ id: String) -> DigitonePadParameter? {
        // Convert from ParameterManager to DigitonePadParameter
        guard let param = parameterManager.getParameter(id: id) else { return nil }
        return DigitonePadParameter(
            name: param.name,
            value: Double(param.value),
            range: Double(param.minValue)...Double(param.maxValue),
            unit: param.unit ?? ""
        )
    }
    
    private func updateDrumTypeParameters(_ drumType: DrumType) {
        // This would trigger parameter updates in the voice machine
        // Implementation would depend on how the voice machine is connected
    }
    
    private func getDecayTimeForDrumType() -> Double {
        switch selectedDrumType {
        case .kick: return 0.3
        case .snare: return 0.15
        case .hihat: return 0.05
        case .tom: return 0.2
        case .cymbal: return 0.8
        }
    }
    
    private func getReleaseTimeForDrumType() -> Double {
        switch selectedDrumType {
        case .kick: return 0.1
        case .snare: return 0.05
        case .hihat: return 0.02
        case .tom: return 0.08
        case .cymbal: return 0.3
        }
    }
    
    // MARK: - Computed Properties
    
    private var isLandscape: Bool {
        return horizontalSizeClass == .regular && verticalSizeClass == .compact
    }
    
    @ViewBuilder
    private var drumMachineBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.8),
                        Color.black.opacity(0.6),
                        Color.black.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

// MARK: - Supporting Views

/// Drum type selection button
struct DrumTypeButton: View {
    let drumType: DrumType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(drumType.displayName.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .black : DigitonePadTheme.darkHardware.primaryColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? DigitonePadTheme.darkHardware.accentColor : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(DigitonePadTheme.darkHardware.accentColor, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Parameter section container
struct ParameterSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(DigitonePadTheme.darkHardware.secondaryColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DigitonePadTheme.darkHardware.secondaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

/// Noise type selector
struct NoiseTypeSelector: View {
    let selectedType: NoiseType
    let onTypeChanged: (NoiseType) -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach([NoiseType.white, .pink, .brown], id: \.self) { type in
                Button(action: { onTypeChanged(type) }) {
                    Text(typeDisplayName(type))
                        .font(.caption2)
                        .foregroundColor(selectedType == type ? .black : DigitonePadTheme.darkHardware.primaryColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(selectedType == type ? DigitonePadTheme.darkHardware.accentColor : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func typeDisplayName(_ type: NoiseType) -> String {
        switch type {
        case .white: return "WHT"
        case .pink: return "PNK"
        case .brown: return "BRN"
        }
    }
}

// MARK: - Drum Type Enum Extension

public enum DrumType: String, CaseIterable {
    case kick = "kick"
    case snare = "snare"
    case hihat = "hihat"
    case tom = "tom"
    case cymbal = "cymbal"
    
    public var displayName: String {
        switch self {
        case .kick: return "Kick"
        case .snare: return "Snare"
        case .hihat: return "Hi-Hat"
        case .tom: return "Tom"
        case .cymbal: return "Cymbal"
        }
    }
}

public enum NoiseType {
    case white
    case pink
    case brown
}
