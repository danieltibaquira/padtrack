import SwiftUI
import UIComponents

// MARK: - Scale Selector View

struct ScaleSelectorView: View {
    let presenter: OnScreenKeyboardPresenter
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section("MUSICAL SCALES") {
                    ForEach(MusicalScale.allCases, id: \.self) { scale in
                        Button(action: {
                            presenter.scaleSelected(scale)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(scale.rawValue)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(scaleDescription(for: scale))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Intervals: \(intervalString(for: scale))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if presenter.currentScale == scale {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section("ACTIONS") {
                    Button(action: {
                        presenter.clearScale()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Text("Clear Scale")
                                .foregroundColor(.red)
                            Spacer()
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Select Scale")
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
    
    private func scaleDescription(for scale: MusicalScale) -> String {
        switch scale {
        case .chromatic:
            return "All 12 semitones"
        case .major:
            return "Happy, bright sound"
        case .minor:
            return "Sad, dark sound"
        case .pentatonic:
            return "5-note scale, common in folk music"
        case .blues:
            return "Expressive, soulful sound"
        case .dorian:
            return "Minor with raised 6th"
        case .mixolydian:
            return "Major with lowered 7th"
        }
    }
    
    private func intervalString(for scale: MusicalScale) -> String {
        return scale.intervals.map { String($0) }.joined(separator: ", ")
    }
}

// MARK: - Chord Selector View

struct ChordSelectorView: View {
    let presenter: OnScreenKeyboardPresenter
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedRootNote: Note = .C
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Root note selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("ROOT NOTE")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Note.allCases, id: \.self) { note in
                                DigitonePadButton(
                                    config: ButtonConfig(
                                        title: note.name,
                                        style: selectedRootNote == note ? .primary : .secondary,
                                        onTap: { selectedRootNote = note }
                                    ),
                                    theme: .darkHardware
                                )
                                .frame(width: 50)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                
                // Chord type selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("CHORD TYPE")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(ChordType.allCases, id: \.self) { chordType in
                            Button(action: {
                                presenter.chordRequested(chordType, rootNote: selectedRootNote)
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                VStack(spacing: 8) {
                                    Text(chordType.rawValue)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(chordDescription(for: chordType))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                    
                                    Text("Intervals: \(intervalString(for: chordType))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                Spacer()
                
                // Clear chord button
                Button(action: {
                    presenter.clearChordHighlight()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Clear Chord Highlight")
                    }
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 20)
            .navigationTitle("Select Chord")
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
    
    private func chordDescription(for chordType: ChordType) -> String {
        switch chordType {
        case .major:
            return "Bright, happy sound"
        case .minor:
            return "Dark, sad sound"
        case .diminished:
            return "Tense, unstable"
        case .augmented:
            return "Dreamy, floating"
        case .major7:
            return "Jazzy, sophisticated"
        case .minor7:
            return "Smooth, mellow"
        case .dominant7:
            return "Bluesy, driving"
        }
    }
    
    private func intervalString(for chordType: ChordType) -> String {
        return chordType.intervals.map { String($0) }.joined(separator: ", ")
    }
}

// MARK: - Keyboard Settings View

struct KeyboardSettingsView: View {
    let presenter: OnScreenKeyboardPresenter
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedLayout: KeyboardLayoutType = .standard
    @State private var customOctaveRange: ClosedRange<Int> = 2...6
    @State private var customKeySize: CGSize = CGSize(width: 60, height: 200)
    
    enum KeyboardLayoutType: String, CaseIterable {
        case standard = "Standard"
        case compact = "Compact"
        case custom = "Custom"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("KEYBOARD LAYOUT") {
                    Picker("Layout Type", selection: $selectedLayout) {
                        ForEach(KeyboardLayoutType.allCases, id: \.self) { layout in
                            Text(layout.rawValue).tag(layout)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if selectedLayout == .custom {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Octave Range")
                                .font(.headline)
                            
                            HStack {
                                Text("From:")
                                Stepper("\(customOctaveRange.lowerBound)", value: .constant(customOctaveRange.lowerBound), in: 0...8)
                                
                                Text("To:")
                                Stepper("\(customOctaveRange.upperBound)", value: .constant(customOctaveRange.upperBound), in: 0...8)
                            }
                            
                            Text("Key Size")
                                .font(.headline)
                            
                            HStack {
                                Text("Width:")
                                Slider(value: Binding(
                                    get: { customKeySize.width },
                                    set: { customKeySize.width = $0 }
                                ), in: 30...100)
                                Text("\(Int(customKeySize.width))")
                            }
                            
                            HStack {
                                Text("Height:")
                                Slider(value: Binding(
                                    get: { customKeySize.height },
                                    set: { customKeySize.height = $0 }
                                ), in: 100...300)
                                Text("\(Int(customKeySize.height))")
                            }
                        }
                    }
                }
                
                Section("ACTIONS") {
                    Button("Apply Layout") {
                        applyLayout()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.blue)
                    
                    Button("Reset to Default") {
                        presenter.setStandardLayout()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("Keyboard Settings")
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
    
    private func applyLayout() {
        switch selectedLayout {
        case .standard:
            presenter.setStandardLayout()
        case .compact:
            presenter.setCompactLayout()
        case .custom:
            presenter.createCustomLayout(octaveRange: customOctaveRange, keySize: customKeySize)
        }
    }
}

// MARK: - Preview

struct KeyboardSelectorViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ScaleSelectorView(presenter: OnScreenKeyboardPresenter())
                .preferredColorScheme(.dark)
            
            ChordSelectorView(presenter: OnScreenKeyboardPresenter())
                .preferredColorScheme(.dark)
            
            KeyboardSettingsView(presenter: OnScreenKeyboardPresenter())
                .preferredColorScheme(.dark)
        }
    }
}
