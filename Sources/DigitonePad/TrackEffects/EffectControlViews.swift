import SwiftUI
import UIComponents
import FXModule

// MARK: - Bit Reduction Controls

struct BitReductionControlsView: View {
    @ObservedObject var effect: BitReductionEffect
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // Bit Depth Control
                VStack {
                    Text("BIT DEPTH")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DigitonePadKnob(
                        value: Binding(
                            get: { effect.bitDepth },
                            set: { effect.bitDepth = $0 }
                        ),
                        range: 1...16,
                        theme: .darkHardware
                    )
                    .frame(width: 60, height: 60)
                    
                    Text("\(Int(effect.bitDepth)) bits")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Dither Amount Control
                VStack {
                    Text("DITHER")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DigitonePadKnob(
                        value: Binding(
                            get: { effect.ditherAmount },
                            set: { effect.ditherAmount = $0 }
                        ),
                        range: 0...1,
                        theme: .darkHardware
                    )
                    .frame(width: 60, height: 60)
                    
                    Text("\(Int(effect.ditherAmount * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Wet/Dry Mix
                VStack {
                    Text("WET/DRY")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DigitonePadKnob(
                        value: Binding(
                            get: { effect.wetLevel },
                            set: { 
                                effect.wetLevel = $0
                                effect.dryLevel = 1.0 - $0
                            }
                        ),
                        range: 0...1,
                        theme: .darkHardware
                    )
                    .frame(width: 60, height: 60)
                    
                    Text("\(Int(effect.wetLevel * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Dither Type Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("DITHER TYPE")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(BitReductionEffect.DitherType.allCases, id: \.self) { ditherType in
                        DigitonePadButton(
                            config: ButtonConfig(
                                title: ditherType.rawValue.uppercased(),
                                style: effect.ditherType == ditherType ? .primary : .secondary,
                                onTap: { effect.ditherType = ditherType }
                            ),
                            theme: .darkHardware
                        )
                        .frame(width: 80)
                    }
                }
            }
            
            // Bypass Control
            HStack {
                Text("BYPASS")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                DigitonePadButton(
                    config: ButtonConfig(
                        title: effect.isBypassed ? "ON" : "OFF",
                        style: effect.isBypassed ? .primary : .secondary,
                        onTap: { effect.isBypassed.toggle() }
                    ),
                    theme: .darkHardware
                )
                .frame(width: 60)
            }
        }
    }
}

// MARK: - Sample Rate Reduction Controls

struct SampleRateReductionControlsView: View {
    @ObservedObject var effect: SampleRateReductionEffect
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // Sample Rate Control
                VStack {
                    Text("SAMPLE RATE")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DigitonePadKnob(
                        value: Binding(
                            get: { effect.targetSampleRate },
                            set: { effect.targetSampleRate = $0 }
                        ),
                        range: 100...48000,
                        theme: .darkHardware
                    )
                    .frame(width: 60, height: 60)
                    
                    Text("\(Int(effect.targetSampleRate)) Hz")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Filter Cutoff Control
                VStack {
                    Text("FILTER")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DigitonePadKnob(
                        value: Binding(
                            get: { effect.filterCutoffRatio },
                            set: { effect.filterCutoffRatio = $0 }
                        ),
                        range: 0.1...0.5,
                        theme: .darkHardware
                    )
                    .frame(width: 60, height: 60)
                    
                    Text("\(Int(effect.filterCutoffRatio * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Wet/Dry Mix
                VStack {
                    Text("WET/DRY")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DigitonePadKnob(
                        value: Binding(
                            get: { effect.wetLevel },
                            set: { 
                                effect.wetLevel = $0
                                effect.dryLevel = 1.0 - $0
                            }
                        ),
                        range: 0...1,
                        theme: .darkHardware
                    )
                    .frame(width: 60, height: 60)
                    
                    Text("\(Int(effect.wetLevel * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Anti-aliasing Toggle
            HStack {
                Text("ANTI-ALIASING")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                DigitonePadButton(
                    config: ButtonConfig(
                        title: effect.antiAliasingEnabled ? "ON" : "OFF",
                        style: effect.antiAliasingEnabled ? .primary : .secondary,
                        onTap: { effect.antiAliasingEnabled.toggle() }
                    ),
                    theme: .darkHardware
                )
                .frame(width: 60)
            }
            
            // Bypass Control
            HStack {
                Text("BYPASS")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                DigitonePadButton(
                    config: ButtonConfig(
                        title: effect.isBypassed ? "ON" : "OFF",
                        style: effect.isBypassed ? .primary : .secondary,
                        onTap: { effect.isBypassed.toggle() }
                    ),
                    theme: .darkHardware
                )
                .frame(width: 60)
            }
        }
    }
}

// MARK: - Overdrive Controls

struct OverdriveControlsView: View {
    @ObservedObject var effect: OverdriveEffect
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // Drive Amount Control
                VStack {
                    Text("DRIVE")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DigitonePadKnob(
                        value: Binding(
                            get: { Double(effect.driveAmount) },
                            set: { effect.driveAmount = Float($0) }
                        ),
                        range: 0...10,
                        label: "DRIVE",
                        theme: .darkHardware
                    )
                    .frame(width: 60, height: 60)
                    
                    Text("\(effect.driveAmount, specifier: "%.1f")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Output Level Control
                VStack {
                    Text("OUTPUT")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DigitonePadKnob(
                        value: Binding(
                            get: { Double(effect.outputLevel) },
                            set: { effect.outputLevel = Float($0) }
                        ),
                        range: -20...20,
                        label: "LEVEL",
                        theme: .darkHardware
                    )
                    .frame(width: 60, height: 60)
                    
                    Text("\(effect.outputLevel, specifier: "%.1f") dB")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Tone Control
                VStack {
                    Text("TONE")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DigitonePadKnob(
                        value: Binding(
                            get: { effect.tone },
                            set: { effect.tone = $0 }
                        ),
                        range: 0...1,
                        theme: .darkHardware
                    )
                    .frame(width: 60, height: 60)
                    
                    Text("\(Int(effect.tone * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Asymmetry Control
                VStack {
                    Text("ASYM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DigitonePadKnob(
                        value: Binding(
                            get: { effect.asymmetry },
                            set: { effect.asymmetry = $0 }
                        ),
                        range: -1...1,
                        theme: .darkHardware
                    )
                    .frame(width: 60, height: 60)
                    
                    Text("\(Int(effect.asymmetry * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Clipping Curve Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("CLIPPING CURVE")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(OverdriveEffect.ClippingCurve.allCases, id: \.self) { curve in
                            DigitonePadButton(
                                config: ButtonConfig(
                                    title: curve.rawValue.uppercased(),
                                    style: effect.clippingCurve == curve ? .primary : .secondary,
                                    onTap: { effect.clippingCurve = curve }
                                ),
                                theme: .darkHardware
                            )
                            .frame(width: 80)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Bypass Control
            HStack {
                Text("BYPASS")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                DigitonePadButton(
                    config: ButtonConfig(
                        title: effect.isBypassed ? "ON" : "OFF",
                        style: effect.isBypassed ? .primary : .secondary,
                        onTap: { effect.isBypassed.toggle() }
                    ),
                    theme: .darkHardware
                )
                .frame(width: 60)
            }
        }
    }
}

// MARK: - Generic Effect Controls

struct GenericEffectControlsView: View {
    let effect: FXProcessor
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // Wet/Dry Mix
                VStack {
                    Text("WET/DRY")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DigitonePadKnob(
                        value: Binding(
                            get: { Double(effect.wetLevel) },
                            set: {
                                effect.wetLevel = Float($0)
                                effect.dryLevel = Float(1.0 - $0)
                            }
                        ),
                        range: 0...1,
                        label: "WET",
                        theme: .darkHardware
                    )
                    .frame(width: 60, height: 60)
                    
                    Text("\(Int(effect.wetLevel * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Input Gain
                VStack {
                    Text("INPUT")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DigitonePadKnob(
                        value: Binding(
                            get: { Double(effect.inputGain) },
                            set: { effect.inputGain = Float($0) }
                        ),
                        range: -20...20,
                        label: "GAIN",
                        theme: .darkHardware
                    )
                    .frame(width: 60, height: 60)
                    
                    Text("\(effect.inputGain, specifier: "%.1f") dB")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Output Gain
                VStack {
                    Text("OUTPUT")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DigitonePadKnob(
                        value: Binding(
                            get: { Double(effect.outputGain) },
                            set: { effect.outputGain = Float($0) }
                        ),
                        range: -20...20,
                        label: "OUTPUT",
                        theme: .darkHardware
                    )
                    .frame(width: 60, height: 60)
                    
                    Text("\(effect.outputGain, specifier: "%.1f") dB")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Bypass Control
            HStack {
                Text("BYPASS")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                DigitonePadButton(
                    config: ButtonConfig(
                        title: effect.isBypassed ? "ON" : "OFF",
                        style: effect.isBypassed ? .primary : .secondary,
                        onTap: { effect.isBypassed.toggle() }
                    ),
                    theme: .darkHardware
                )
                .frame(width: 60)
            }
        }
    }
}
