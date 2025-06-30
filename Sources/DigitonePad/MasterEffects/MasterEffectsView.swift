import SwiftUI
import UIComponents
import FXModule

/// Master effects control interface
struct MasterEffectsView: View {
    @ObservedObject var masterEffects: MasterEffectsProcessor
    @State private var selectedEffect: MasterEffectType = .compressor
    @State private var showingPresets = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with master controls
            masterControlsHeader
            
            // Effect selector
            effectSelector
            
            // Selected effect controls
            selectedEffectControls
            
            // Master metering
            masterMetering
        }
        .padding()
        .background(Color.black)
        .sheet(isPresented: $showingPresets) {
            MasterEffectsPresetsView(masterEffects: masterEffects)
        }
    }
    
    // MARK: - Master Controls Header
    
    private var masterControlsHeader: some View {
        HStack {
            Text("MASTER EFFECTS")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            // Master bypass
            DigitonePadButton(
                config: ButtonConfig(
                    title: "BYPASS",
                    style: masterEffects.masterBypass ? .primary : .secondary,
                    onTap: { masterEffects.masterBypass.toggle() }
                ),
                theme: .darkHardware
            )
            .frame(width: 80)
            
            // Presets
            DigitonePadButton(
                config: ButtonConfig(
                    title: "PRESETS",
                    style: .secondary,
                    onTap: { showingPresets = true }
                ),
                theme: .darkHardware
            )
            .frame(width: 80)
        }
    }
    
    // MARK: - Effect Selector
    
    private var effectSelector: some View {
        HStack(spacing: 12) {
            ForEach(MasterEffectType.allCases, id: \.self) { effectType in
                DigitonePadButton(
                    config: ButtonConfig(
                        title: effectType.rawValue.uppercased(),
                        style: selectedEffect == effectType ? .primary : .secondary,
                        onTap: { selectedEffect = effectType }
                    ),
                    theme: .darkHardware
                )
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Selected Effect Controls
    
    @ViewBuilder
    private var selectedEffectControls: some View {
        switch selectedEffect {
        case .compressor:
            CompressorControlsView(compressor: masterEffects.compressor)
        case .overdrive:
            OverdriveControlsView(overdrive: masterEffects.overdrive)
        case .limiter:
            LimiterControlsView(limiter: masterEffects.limiter)
        }
    }
    
    // MARK: - Master Metering
    
    private var masterMetering: some View {
        VStack(spacing: 12) {
            Text("MASTER METERING")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                // Input level
                VStack {
                    Text("INPUT")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LevelMeter(
                        level: masterEffects.inputLevel,
                        orientation: .vertical
                    )
                    .frame(width: 20, height: 100)
                    
                    Text("\(dbString(from: masterEffects.inputLevel))")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
                
                // Gain reduction
                VStack {
                    Text("GR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    GainReductionMeter(
                        gainReduction: masterEffects.totalGainReduction
                    )
                    .frame(width: 20, height: 100)
                    
                    Text("-\(masterEffects.totalGainReduction, specifier: "%.1f") dB")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                
                // Output level
                VStack {
                    Text("OUTPUT")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LevelMeter(
                        level: masterEffects.outputLevel,
                        orientation: .vertical
                    )
                    .frame(width: 20, height: 100)
                    
                    Text("\(dbString(from: masterEffects.outputLevel))")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Master gain
                VStack {
                    Text("MASTER GAIN")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DigitonePadKnob(
                        value: Binding(
                            get: { masterEffects.masterGain },
                            set: { masterEffects.masterGain = $0 }
                        ),
                        range: -20...20,
                        theme: .darkHardware
                    )
                    .frame(width: 60, height: 60)
                    
                    Text("\(masterEffects.masterGain, specifier: "%.1f") dB")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    // MARK: - Utility
    
    private func dbString(from linear: Float) -> String {
        let db = 20 * log10(max(linear, 1e-6))
        return "\(db, specifier: "%.1f") dB"
    }
}

// MARK: - Individual Effect Control Views

struct CompressorControlsView: View {
    @ObservedObject var compressor: CompressorEffect
    
    var body: some View {
        VStack(spacing: 16) {
            Text("COMPRESSOR")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ParameterKnobView(
                    title: "THRESHOLD",
                    value: Binding(
                        get: { compressor.threshold },
                        set: { compressor.threshold = $0 }
                    ),
                    range: -60...0,
                    unit: "dB"
                )
                
                ParameterKnobView(
                    title: "RATIO",
                    value: Binding(
                        get: { compressor.ratio },
                        set: { compressor.ratio = $0 }
                    ),
                    range: 1...20,
                    unit: ":1"
                )
                
                ParameterKnobView(
                    title: "ATTACK",
                    value: Binding(
                        get: { compressor.attackTime },
                        set: { compressor.attackTime = $0 }
                    ),
                    range: 0.1...100,
                    unit: "ms"
                )
                
                ParameterKnobView(
                    title: "RELEASE",
                    value: Binding(
                        get: { compressor.releaseTime },
                        set: { compressor.releaseTime = $0 }
                    ),
                    range: 10...5000,
                    unit: "ms"
                )
            }
            
            HStack {
                Toggle("ENABLED", isOn: $compressor.isEnabled)
                    .toggleStyle(DigitonePadToggleStyle())
                
                Spacer()
                
                Text("GR: -\(compressor.gainReduction, specifier: "%.1f") dB")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct OverdriveControlsView: View {
    @ObservedObject var overdrive: MasterOverdriveEffect
    
    var body: some View {
        VStack(spacing: 16) {
            Text("OVERDRIVE")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ParameterKnobView(
                    title: "DRIVE",
                    value: Binding(
                        get: { overdrive.driveAmount },
                        set: { overdrive.driveAmount = $0 }
                    ),
                    range: 0...10,
                    unit: ""
                )
                
                ParameterKnobView(
                    title: "OUTPUT",
                    value: Binding(
                        get: { overdrive.outputLevel },
                        set: { overdrive.outputLevel = $0 }
                    ),
                    range: -20...20,
                    unit: "dB"
                )
                
                ParameterKnobView(
                    title: "TONE",
                    value: Binding(
                        get: { overdrive.highFreqEmphasis },
                        set: { overdrive.highFreqEmphasis = $0 }
                    ),
                    range: 0...1,
                    unit: ""
                )
                
                ParameterKnobView(
                    title: "WIDTH",
                    value: Binding(
                        get: { overdrive.stereoWidth },
                        set: { overdrive.stereoWidth = $0 }
                    ),
                    range: 0...2,
                    unit: ""
                )
            }
            
            HStack {
                Toggle("ENABLED", isOn: $overdrive.isEnabled)
                    .toggleStyle(DigitonePadToggleStyle())
                
                Spacer()
                
                Menu("TYPE: \(overdrive.saturationType.rawValue)") {
                    ForEach(MasterOverdriveEffect.SaturationType.allCases, id: \.self) { type in
                        Button(type.rawValue) {
                            overdrive.saturationType = type
                        }
                    }
                }
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct LimiterControlsView: View {
    @ObservedObject var limiter: TruePeakLimiterEffect
    
    var body: some View {
        VStack(spacing: 16) {
            Text("LIMITER")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ParameterKnobView(
                    title: "CEILING",
                    value: Binding(
                        get: { limiter.ceiling },
                        set: { limiter.ceiling = $0 }
                    ),
                    range: -20...0,
                    unit: "dB"
                )
                
                ParameterKnobView(
                    title: "RELEASE",
                    value: Binding(
                        get: { limiter.releaseTime },
                        set: { limiter.releaseTime = $0 }
                    ),
                    range: 1...1000,
                    unit: "ms"
                )
                
                ParameterKnobView(
                    title: "LOOKAHEAD",
                    value: Binding(
                        get: { limiter.lookaheadTime },
                        set: { limiter.lookaheadTime = $0 }
                    ),
                    range: 1...20,
                    unit: "ms"
                )
                
                ParameterKnobView(
                    title: "KNEE",
                    value: Binding(
                        get: { limiter.softKnee },
                        set: { limiter.softKnee = $0 }
                    ),
                    range: 0...1,
                    unit: ""
                )
            }
            
            HStack {
                Toggle("ENABLED", isOn: $limiter.isEnabled)
                    .toggleStyle(DigitonePadToggleStyle())
                
                Spacer()
                
                Text("GR: -\(limiter.gainReduction, specifier: "%.1f") dB")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Supporting Views

struct ParameterKnobView: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let unit: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            DigitonePadKnob(
                value: $value,
                range: range,
                theme: .darkHardware
            )
            .frame(width: 50, height: 50)
            
            Text("\(value, specifier: "%.1f")\(unit)")
                .font(.caption2)
                .foregroundColor(.white)
        }
    }
}

struct LevelMeter: View {
    let level: Float
    let orientation: Orientation
    
    enum Orientation {
        case horizontal, vertical
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: orientation == .vertical ? .bottom : .leading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                
                // Level indicator
                Rectangle()
                    .fill(levelColor)
                    .frame(
                        width: orientation == .vertical ? geometry.size.width : geometry.size.width * CGFloat(level),
                        height: orientation == .vertical ? geometry.size.height * CGFloat(level) : geometry.size.height
                    )
                    .animation(.easeInOut(duration: 0.1), value: level)
            }
        }
        .cornerRadius(2)
    }
    
    private var levelColor: Color {
        let db = 20 * log10(max(level, 1e-6))
        if db > -3 {
            return .red
        } else if db > -12 {
            return .yellow
        } else {
            return .green
        }
    }
}

struct GainReductionMeter: View {
    let gainReduction: Float
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                
                // Gain reduction indicator
                Rectangle()
                    .fill(Color.orange)
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height * CGFloat(min(gainReduction / 20.0, 1.0))
                    )
                    .animation(.easeInOut(duration: 0.1), value: gainReduction)
            }
        }
        .cornerRadius(2)
    }
}

// MARK: - Preview

struct MasterEffectsView_Previews: PreviewProvider {
    static var previews: some View {
        MasterEffectsView(masterEffects: MasterEffectsProcessor())
            .preferredColorScheme(.dark)
    }
}
