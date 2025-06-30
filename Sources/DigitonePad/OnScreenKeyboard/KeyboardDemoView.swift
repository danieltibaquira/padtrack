import SwiftUI
import UIComponents

/// Demo view showing how to integrate and use the On-Screen Keyboard
struct KeyboardDemoView: View {
    @State private var playedNotes: [PlayedNote] = []
    @State private var currentChord: String = "None"
    @State private var currentScale: String = "Chromatic"
    @State private var isRecording = false
    @State private var recordedSequence: [PlayedNote] = []
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerView
            
            // Note display area
            noteDisplayView
            
            // Keyboard
            OnScreenKeyboardRouter.createKeyboardView()
            
            // Controls
            controlsView
        }
        .background(Color.black)
        .foregroundColor(.white)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("DigitonePad Keyboard Demo")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Touch the keys to play notes • Use controls to change octave and scale")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Note Display
    
    private var noteDisplayView: some View {
        VStack(spacing: 12) {
            // Current status
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("CURRENT SCALE")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(currentScale)
                        .font(.headline)
                }
                
                VStack(alignment: .leading) {
                    Text("CURRENT CHORD")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(currentChord)
                        .font(.headline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("RECORDING")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Circle()
                        .fill(isRecording ? Color.red : Color.gray)
                        .frame(width: 20, height: 20)
                }
            }
            
            // Recently played notes
            VStack(alignment: .leading, spacing: 8) {
                Text("RECENTLY PLAYED NOTES")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(playedNotes.suffix(10), id: \.id) { note in
                            NoteDisplayView(note: note)
                        }
                        
                        if playedNotes.isEmpty {
                            Text("No notes played yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 60)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    // MARK: - Controls
    
    private var controlsView: some View {
        VStack(spacing: 12) {
            // Recording controls
            HStack(spacing: 16) {
                DigitonePadButton(
                    config: ButtonConfig(
                        title: isRecording ? "STOP REC" : "START REC",
                        style: isRecording ? .primary : .secondary,
                        onTap: { toggleRecording() }
                    ),
                    theme: .darkHardware
                )
                .frame(width: 100)
                
                DigitonePadButton(
                    config: ButtonConfig(
                        title: "PLAY BACK",
                        style: .secondary,
                        onTap: { playBackRecording() }
                    ),
                    theme: .darkHardware
                )
                .frame(width: 100)
                
                DigitonePadButton(
                    config: ButtonConfig(
                        title: "CLEAR",
                        style: .secondary,
                        onTap: { clearRecording() }
                    ),
                    theme: .darkHardware
                )
                .frame(width: 80)
                
                Spacer()
                
                Text("Recorded: \(recordedSequence.count) notes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Quick actions
            HStack(spacing: 12) {
                DigitonePadButton(
                    config: ButtonConfig(
                        title: "CLEAR NOTES",
                        style: .secondary,
                        onTap: { clearPlayedNotes() }
                    ),
                    theme: .darkHardware
                )
                .frame(width: 120)
                
                Spacer()
                
                Text("Total notes played: \(playedNotes.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    // MARK: - OnScreenKeyboardDelegate
    
    func keyboardDidPressKey(_ key: KeyboardKey, velocity: Float) {
        let playedNote = PlayedNote(
            key: key,
            velocity: velocity,
            timestamp: Date()
        )
        
        // Add to played notes
        playedNotes.append(playedNote)
        
        // Add to recording if active
        if isRecording {
            recordedSequence.append(playedNote)
        }
        
        // Limit displayed notes to prevent memory issues
        if playedNotes.count > 100 {
            playedNotes.removeFirst(playedNotes.count - 100)
        }
        
        // In a real app, this would trigger audio playback
        print("Playing note: \(key.displayName) with velocity: \(velocity)")
    }
    
    func keyboardDidReleaseKey(_ key: KeyboardKey) {
        // In a real app, this would stop the note
        print("Stopping note: \(key.displayName)")
    }
    
    func keyboardDidChangeOctave(_ octave: Int) {
        print("Octave changed to: \(octave)")
    }
    
    func keyboardDidSelectScale(_ scale: MusicalScale?) {
        currentScale = scale?.rawValue ?? "Chromatic"
        print("Scale changed to: \(currentScale)")
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        isRecording.toggle()
        if isRecording {
            recordedSequence.removeAll()
        }
    }
    
    private func playBackRecording() {
        guard !recordedSequence.isEmpty else { return }
        
        // In a real app, this would play back the recorded sequence
        print("Playing back \(recordedSequence.count) recorded notes")
        
        // Simulate playback by adding notes back to played notes
        for note in recordedSequence {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // This would trigger actual audio playback
                print("Playback: \(note.key.displayName)")
            }
        }
    }
    
    private func clearRecording() {
        recordedSequence.removeAll()
        isRecording = false
    }
    
    private func clearPlayedNotes() {
        playedNotes.removeAll()
    }
}

// MARK: - Note Display View

struct NoteDisplayView: View {
    let note: PlayedNote
    
    var body: some View {
        VStack(spacing: 4) {
            Text(note.key.note.name)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(note.key.keyType == .white ? .black : .white)
            
            Text("\(note.key.octave)")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Velocity indicator
            Rectangle()
                .fill(Color.blue)
                .frame(width: 20, height: CGFloat(note.velocity * 20))
                .cornerRadius(2)
        }
        .padding(6)
        .background(note.key.keyType.color)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray, lineWidth: 1)
        )
    }
}

// MARK: - Played Note Model

struct PlayedNote: Identifiable {
    let id = UUID()
    let key: KeyboardKey
    let velocity: Float
    let timestamp: Date
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Compact Demo View

struct CompactKeyboardDemoView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Compact Keyboard Demo")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            OnScreenKeyboardRouter.createCompactKeyboardView()
            
            Text("This is a compact version suitable for limited space")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.black)
    }
}

// MARK: - Custom Keyboard Demo View

struct CustomKeyboardDemoView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Custom Keyboard Demo")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            OnScreenKeyboardRouter.createCustomKeyboardView(
                octaveRange: 3...5,
                keySize: CGSize(width: 80, height: 180)
            )
            
            Text("Custom layout: 3 octaves, larger keys")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.black)
    }
}

// MARK: - Preview

struct KeyboardDemoView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            KeyboardDemoView()
                .preferredColorScheme(.dark)
            
            CompactKeyboardDemoView()
                .preferredColorScheme(.dark)
            
            CustomKeyboardDemoView()
                .preferredColorScheme(.dark)
        }
    }
}
