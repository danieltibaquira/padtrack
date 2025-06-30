import SwiftUI
import UIComponents
import FXModule

/// Main view for controlling track effects
struct TrackEffectsView: View {
    @ObservedObject var trackProcessor: TrackEffectsProcessor
    @State private var selectedEffectIndex: Int = 0
    @State private var showingEffectSelector = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Track header with basic controls
            trackHeaderView
            
            // Effect chain view
            effectChainView
            
            // Selected effect controls
            if !trackProcessor.getEffects().isEmpty {
                selectedEffectControlsView
            }
            
            Spacer()
        }
        .padding()
        .background(Color.black)
        .foregroundColor(.white)
    }
    
    // MARK: - Track Header
    
    private var trackHeaderView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("TRACK \(trackProcessor.trackId)")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Bypass button
                DigitonePadButton(
                    config: ButtonConfig(
                        title: "BYP",
                        style: trackProcessor.isBypassed ? .primary : .secondary,
                        onTap: { trackProcessor.setBypass(!trackProcessor.isBypassed) }
                    ),
                    theme: .darkHardware
                )
                .frame(width: 50)
                
                // Mute button
                DigitonePadButton(
                    config: ButtonConfig(
                        title: "MUTE",
                        style: trackProcessor.isMuted ? .primary : .secondary,
                        onTap: { trackProcessor.setMute(!trackProcessor.isMuted) }
                    ),
                    theme: .darkHardware
                )
                .frame(width: 60)
            }
            
            // Gain controls
            HStack(spacing: 20) {
                VStack {
                    Text("INPUT")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DigitonePadKnob(
                        value: Binding(
                            get: { trackProcessor.inputGain },
                            set: { trackProcessor.setInputGain($0) }
                        ),
                        range: -60...20,
                        theme: .darkHardware
                    )
                    .frame(width: 60, height: 60)
                    
                    Text("\(trackProcessor.inputGain, specifier: "%.1f") dB")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("OUTPUT")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DigitonePadKnob(
                        value: Binding(
                            get: { trackProcessor.outputGain },
                            set: { trackProcessor.setOutputGain($0) }
                        ),
                        range: -60...20,
                        theme: .darkHardware
                    )
                    .frame(width: 60, height: 60)
                    
                    Text("\(trackProcessor.outputGain, specifier: "%.1f") dB")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("PAN")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DigitonePadKnob(
                        value: Binding(
                            get: { trackProcessor.pan },
                            set: { trackProcessor.setPan($0) }
                        ),
                        range: -1...1,
                        theme: .darkHardware
                    )
                    .frame(width: 60, height: 60)
                    
                    Text(panDisplayText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    // MARK: - Effect Chain
    
    private var effectChainView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EFFECTS CHAIN")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                DigitonePadButton(
                    config: ButtonConfig(
                        title: "+ FX",
                        style: .secondary,
                        onTap: { showingEffectSelector = true }
                    ),
                    theme: .darkHardware
                )
                .frame(width: 60)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(trackProcessor.getEffects().enumerated()), id: \.offset) { index, effect in
                        EffectSlotView(
                            effect: effect,
                            index: index,
                            isSelected: index == selectedEffectIndex,
                            onTap: { selectedEffectIndex = index },
                            onRemove: { 
                                _ = trackProcessor.removeEffect(at: index)
                                if selectedEffectIndex >= trackProcessor.effectCount {
                                    selectedEffectIndex = max(0, trackProcessor.effectCount - 1)
                                }
                            }
                        )
                    }
                    
                    // Empty slot indicator
                    if trackProcessor.effectCount < 8 {
                        EmptyEffectSlotView()
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .sheet(isPresented: $showingEffectSelector) {
            EffectSelectorView(trackProcessor: trackProcessor)
        }
    }
    
    // MARK: - Selected Effect Controls
    
    private var selectedEffectControlsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            let effects = trackProcessor.getEffects()
            if selectedEffectIndex < effects.count {
                let selectedEffect = effects[selectedEffectIndex]
                
                Text("EFFECT CONTROLS - \(selectedEffect.name.uppercased())")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                // Effect-specific controls
                Group {
                    if let bitReduction = selectedEffect as? BitReductionEffect {
                        BitReductionControlsView(effect: bitReduction)
                    } else if let sampleRateReduction = selectedEffect as? SampleRateReductionEffect {
                        SampleRateReductionControlsView(effect: sampleRateReduction)
                    } else if let overdrive = selectedEffect as? OverdriveEffect {
                        OverdriveControlsView(effect: overdrive)
                    } else {
                        GenericEffectControlsView(effect: selectedEffect)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var panDisplayText: String {
        let pan = trackProcessor.pan
        if abs(pan) < 0.05 {
            return "C"
        } else if pan > 0 {
            return "R\(Int(pan * 100))"
        } else {
            return "L\(Int(-pan * 100))"
        }
    }
}

// MARK: - Effect Slot View

struct EffectSlotView: View {
    let effect: FXProcessor
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(effectAbbreviation)
                    .font(.caption2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            
            // Bypass indicator
            Circle()
                .fill(effect.isBypassed ? Color.red : Color.green)
                .frame(width: 8, height: 8)
            
            // Effect type indicator
            Text(effect.effectType.rawValue.prefix(3).uppercased())
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .frame(width: 80, height: 60)
        .background(isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
        .cornerRadius(6)
        .onTapGesture(perform: onTap)
    }
    
    private var effectAbbreviation: String {
        switch effect.effectType {
        case .bitCrusher: return "BIT"
        case .sampleRateReduction: return "SRR"
        case .overdrive: return "OVR"
        default: return "FX"
        }
    }
}

// MARK: - Empty Effect Slot View

struct EmptyEffectSlotView: View {
    var body: some View {
        VStack {
            Image(systemName: "plus.circle.dashed")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("EMPTY")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 80, height: 60)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary, style: StrokeStyle(lineWidth: 1, dash: [5]))
        )
    }
}

// MARK: - Effect Selector View

struct EffectSelectorView: View {
    let trackProcessor: TrackEffectsProcessor
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                ForEach(TrackEffectsProcessor.AvailableEffect.allCases, id: \.self) { effectType in
                    Button(action: {
                        _ = trackProcessor.addEffect(effectType)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(effectType.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(effectDescription(for: effectType))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Add Effect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func effectDescription(for effectType: TrackEffectsProcessor.AvailableEffect) -> String {
        switch effectType {
        case .bitReduction:
            return "Reduce bit depth for lo-fi character"
        case .sampleRateReduction:
            return "Reduce sample rate with anti-aliasing"
        case .overdrive:
            return "Add harmonic distortion and warmth"
        }
    }
}

// MARK: - Preview

struct TrackEffectsView_Previews: PreviewProvider {
    static var previews: some View {
        TrackEffectsView(trackProcessor: TrackEffectsProcessor(trackId: 1))
            .preferredColorScheme(.dark)
    }
}
