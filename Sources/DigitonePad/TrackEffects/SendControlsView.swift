import SwiftUI
import UIComponents
import FXModule

/// UI component for controlling track send levels to global effects
struct SendControlsView: View {
    @ObservedObject var trackProcessor: TrackEffectsProcessor
    let sendEffectNames: [String]
    
    init(trackProcessor: TrackEffectsProcessor, sendEffectNames: [String] = ["Delay", "Reverb", "Chorus", "Send 4"]) {
        self.trackProcessor = trackProcessor
        self.sendEffectNames = sendEffectNames
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SEND LEVELS")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            // Send controls grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(0..<min(trackProcessor.sendLevels.count, sendEffectNames.count), id: \.self) { sendIndex in
                    SendControlView(
                        sendName: sendEffectNames[sendIndex],
                        sendLevel: Binding(
                            get: { trackProcessor.getSendLevel(for: sendIndex) },
                            set: { trackProcessor.setSendLevel($0, for: sendIndex) }
                        )
                    )
                }
            }
            
            // Quick actions
            HStack(spacing: 12) {
                DigitonePadButton(
                    config: ButtonConfig(
                        title: "RESET",
                        style: .secondary,
                        onTap: { trackProcessor.resetSendLevels() }
                    ),
                    theme: .darkHardware
                )
                .frame(width: 80)
                
                Spacer()
                
                // Send level presets
                Menu("PRESETS") {
                    Button("Dry (No Sends)") {
                        trackProcessor.setSendLevels([0.0, 0.0, 0.0, 0.0])
                    }
                    
                    Button("Subtle Ambience") {
                        trackProcessor.setSendLevels([0.1, 0.15, 0.05, 0.0])
                    }
                    
                    Button("Medium Space") {
                        trackProcessor.setSendLevels([0.2, 0.25, 0.1, 0.0])
                    }
                    
                    Button("Heavy Effects") {
                        trackProcessor.setSendLevels([0.4, 0.4, 0.3, 0.0])
                    }
                    
                    Button("Delay Focus") {
                        trackProcessor.setSendLevels([0.5, 0.1, 0.0, 0.0])
                    }
                    
                    Button("Reverb Focus") {
                        trackProcessor.setSendLevels([0.1, 0.5, 0.0, 0.0])
                    }
                    
                    Button("Chorus Focus") {
                        trackProcessor.setSendLevels([0.0, 0.1, 0.5, 0.0])
                    }
                }
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
}

// MARK: - Individual Send Control

struct SendControlView: View {
    let sendName: String
    @Binding var sendLevel: Float
    
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Send name
            Text(sendName.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // Knob control
            DigitonePadKnob(
                value: Binding(
                    get: { Double(sendLevel) },
                    set: { sendLevel = Float($0) }
                ),
                range: 0...1,
                label: sendName.uppercased(),
                theme: .darkHardware
            )
            .frame(width: 50, height: 50)
            .scaleEffect(isDragging ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isDragging)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isDragging {
                            isDragging = true
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            
            // Level display
            VStack(spacing: 2) {
                Text("\(Int(sendLevel * 100))%")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                // Level meter
                LevelMeterView(level: sendLevel)
                    .frame(width: 40, height: 4)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Level Meter

struct LevelMeterView: View {
    let level: Float
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .cornerRadius(2)
                
                // Level indicator
                Rectangle()
                    .fill(levelColor)
                    .frame(width: geometry.size.width * CGFloat(level))
                    .cornerRadius(2)
                    .animation(.easeInOut(duration: 0.1), value: level)
            }
        }
    }
    
    private var levelColor: Color {
        if level < 0.3 {
            return .green
        } else if level < 0.7 {
            return .yellow
        } else {
            return .orange
        }
    }
}

// MARK: - Send Matrix View

/// Comprehensive send matrix for multiple tracks
struct SendMatrixView: View {
    let trackProcessors: [TrackEffectsProcessor]
    let sendEffectNames: [String]
    
    @State private var selectedTrack: Int = 0
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("SEND MATRIX")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Track selector
                Picker("Track", selection: $selectedTrack) {
                    ForEach(0..<trackProcessors.count, id: \.self) { index in
                        Text("Track \(index + 1)").tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            // Send controls for selected track
            if selectedTrack < trackProcessors.count {
                SendControlsView(
                    trackProcessor: trackProcessors[selectedTrack],
                    sendEffectNames: sendEffectNames
                )
            }
            
            // Matrix overview (simplified)
            VStack(alignment: .leading, spacing: 8) {
                Text("MATRIX OVERVIEW")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<trackProcessors.count, id: \.self) { trackIndex in
                            TrackSendSummaryView(
                                trackIndex: trackIndex,
                                trackProcessor: trackProcessors[trackIndex],
                                isSelected: trackIndex == selectedTrack,
                                onTap: { selectedTrack = trackIndex }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding()
        .background(Color.black)
    }
}

// MARK: - Track Send Summary

struct TrackSendSummaryView: View {
    let trackIndex: Int
    let trackProcessor: TrackEffectsProcessor
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 6) {
            Text("T\(trackIndex + 1)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .blue : .white)
            
            // Mini send level indicators
            VStack(spacing: 2) {
                ForEach(0..<trackProcessor.sendLevels.count, id: \.self) { sendIndex in
                    Rectangle()
                        .fill(sendLevelColor(trackProcessor.getSendLevel(for: sendIndex)))
                        .frame(width: 30, height: 3)
                        .cornerRadius(1)
                }
            }
        }
        .padding(8)
        .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
        .cornerRadius(6)
        .onTapGesture(perform: onTap)
    }
    
    private func sendLevelColor(_ level: Float) -> Color {
        if level < 0.01 {
            return .gray.opacity(0.3)
        } else if level < 0.3 {
            return .green
        } else if level < 0.7 {
            return .yellow
        } else {
            return .orange
        }
    }
}

// MARK: - Preview

struct SendControlsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SendControlsView(trackProcessor: TrackEffectsProcessor(trackId: 1))
                .preferredColorScheme(.dark)
            
            SendMatrixView(
                trackProcessors: [
                    TrackEffectsProcessor(trackId: 1),
                    TrackEffectsProcessor(trackId: 2),
                    TrackEffectsProcessor(trackId: 3)
                ],
                sendEffectNames: ["Delay", "Reverb", "Chorus", "Send 4"]
            )
            .preferredColorScheme(.dark)
        }
    }
}
