import SwiftUI
import UIComponents

/// Main SwiftUI view for the on-screen keyboard
struct OnScreenKeyboardView: View {
    @EnvironmentObject private var presenterObject: OnScreenKeyboardPresenter
    @State private var keyboardKeys: [KeyboardKey] = []
    @State private var velocityIndicators: [KeyboardKey: Float] = [:]
    
    var body: some View {
        VStack(spacing: 8) {
            // Control bar
            keyboardControlsView
            
            // Main keyboard
            keyboardView
        }
        .background(Color.black)
        .onAppear {
            generateKeyboardKeys()
            presenterObject.viewDidLoad()
        }
        .onChange(of: presenterObject.keyboardLayout) { _ in
            generateKeyboardKeys()
        }
        .sheet(isPresented: $presenterObject.showingScaleSelector) {
            ScaleSelectorView(presenter: presenterObject)
        }
        .sheet(isPresented: $presenterObject.showingChordSelector) {
            ChordSelectorView(presenter: presenterObject)
        }
    }
    
    // MARK: - Control Bar
    
    private var keyboardControlsView: some View {
        HStack(spacing: 16) {
            // Octave controls
            HStack(spacing: 8) {
                DigitonePadButton(
                    config: ButtonConfig(
                        title: "OCT-",
                        style: .secondary,
                        onTap: { presenterObject.transposeDown() }
                    ),
                    theme: .darkHardware
                )
                .frame(width: 60)
                
                Text(presenterObject.getOctaveDisplayText())
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 80)
                
                DigitonePadButton(
                    config: ButtonConfig(
                        title: "OCT+",
                        style: .secondary,
                        onTap: { presenterObject.transposeUp() }
                    ),
                    theme: .darkHardware
                )
                .frame(width: 60)
            }
            
            Spacer()
            
            // Scale selector
            DigitonePadButton(
                config: ButtonConfig(
                    title: presenterObject.getScaleDisplayText(),
                    style: presenterObject.currentScale != nil ? .primary : .secondary,
                    onTap: { presenterObject.showScaleSelector() }
                ),
                theme: .darkHardware
            )
            .frame(width: 120)
            
            // Chord selector
            DigitonePadButton(
                config: ButtonConfig(
                    title: "CHORD",
                    style: !presenterObject.highlightedChord.isEmpty ? .primary : .secondary,
                    onTap: { presenterObject.showChordSelector() }
                ),
                theme: .darkHardware
            )
            .frame(width: 80)
            
            // Clear button
            DigitonePadButton(
                config: ButtonConfig(
                    title: "CLEAR",
                    style: .secondary,
                    onTap: { 
                        presenterObject.clearScale()
                        presenterObject.clearChordHighlight()
                    }
                ),
                theme: .darkHardware
            )
            .frame(width: 80)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.2))
    }
    
    // MARK: - Keyboard View
    
    private var keyboardView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ZStack {
                // White keys layer
                HStack(spacing: presenterObject.keyboardLayout.keySpacing) {
                    ForEach(whiteKeys, id: \.id) { key in
                        KeyView(
                            key: key,
                            isPressed: presenterObject.isKeyPressed(key),
                            color: presenterObject.getKeyColor(key),
                            velocity: velocityIndicators[key],
                            onPress: { location in
                                handleKeyPress(key, at: location)
                            },
                            onRelease: {
                                handleKeyRelease(key)
                            }
                        )
                    }
                }
                
                // Black keys layer (overlaid on white keys)
                HStack(spacing: 0) {
                    ForEach(blackKeys, id: \.id) { key in
                        KeyView(
                            key: key,
                            isPressed: presenterObject.isKeyPressed(key),
                            color: presenterObject.getKeyColor(key),
                            velocity: velocityIndicators[key],
                            onPress: { location in
                                handleKeyPress(key, at: location)
                            },
                            onRelease: {
                                handleKeyRelease(key)
                            }
                        )
                        .offset(x: key.position.x, y: 0)
                    }
                }
            }
        }
        .frame(height: presenterObject.keyboardLayout.whiteKeyHeight + 20)
    }
    
    // MARK: - Computed Properties
    
    private var whiteKeys: [KeyboardKey] {
        return keyboardKeys.filter { $0.keyType == .white }
    }
    
    private var blackKeys: [KeyboardKey] {
        return keyboardKeys.filter { $0.keyType == .black }
    }
    
    // MARK: - OnScreenKeyboardViewProtocol
    
    func updateKeyState(_ key: KeyboardKey, isPressed: Bool) {
        // State is managed through the presenter's published properties
    }
    
    func updateOctave(_ octave: Int) {
        generateKeyboardKeys()
    }
    
    func updateScale(_ scale: MusicalScale?) {
        // Scale highlighting is handled through the presenter's computed properties
    }
    
    func highlightChord(_ chord: [KeyboardKey]) {
        // Chord highlighting is handled through the presenter's published properties
    }
    
    func showVelocityIndicator(_ velocity: Float, for key: KeyboardKey) {
        velocityIndicators[key] = velocity
        
        // Clear velocity indicator after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            velocityIndicators.removeValue(forKey: key)
        }
    }
    
    func updateKeyboardLayout(_ layout: KeyboardLayout) {
        generateKeyboardKeys()
    }
    
    // MARK: - Private Methods
    

    
    private func generateKeyboardKeys() {
        var keys: [KeyboardKey] = []
        let layout = presenterObject.keyboardLayout
        
        for octave in layout.octaveRange {
            for note in Note.allCases {
                let position = calculateKeyPosition(note: note, octave: octave, layout: layout)
                let key = KeyboardKey(
                    note: note,
                    octave: octave,
                    keyType: note.isBlackKey ? .black : .white,
                    position: position
                )
                keys.append(key)
            }
        }
        
        keyboardKeys = keys
    }
    
    private func calculateKeyPosition(note: Note, octave: Int, layout: KeyboardLayout) -> KeyPosition {
        let whiteKeyIndex = getWhiteKeyIndex(for: note)
        let octaveOffset = CGFloat(octave - layout.octaveRange.lowerBound)
        let whiteKeysPerOctave: CGFloat = 7
        
        if note.isBlackKey {
            // Black key positioning
            let blackKeyOffset = getBlackKeyOffset(for: note, layout: layout)
            let x = octaveOffset * (whiteKeysPerOctave * layout.whiteKeyWidth) + 
                    CGFloat(whiteKeyIndex) * layout.whiteKeyWidth + blackKeyOffset
            
            return KeyPosition(
                x: x,
                y: 0,
                width: layout.blackKeyWidth,
                height: layout.blackKeyHeight
            )
        } else {
            // White key positioning
            let x = octaveOffset * (whiteKeysPerOctave * layout.whiteKeyWidth) + 
                    CGFloat(whiteKeyIndex) * layout.whiteKeyWidth
            
            return KeyPosition(
                x: x,
                y: 0,
                width: layout.whiteKeyWidth,
                height: layout.whiteKeyHeight
            )
        }
    }
    
    private func getWhiteKeyIndex(for note: Note) -> Int {
        switch note {
        case .C: return 0
        case .D: return 1
        case .E: return 2
        case .F: return 3
        case .G: return 4
        case .A: return 5
        case .B: return 6
        default: return 0
        }
    }
    
    private func getBlackKeyOffset(for note: Note, layout: KeyboardLayout) -> CGFloat {
        let whiteKeyWidth = layout.whiteKeyWidth
        let blackKeyWidth = layout.blackKeyWidth
        
        switch note {
        case .CSharp: return whiteKeyWidth - (blackKeyWidth / 2)
        case .DSharp: return (whiteKeyWidth * 2) - (blackKeyWidth / 2)
        case .FSharp: return (whiteKeyWidth * 4) - (blackKeyWidth / 2)
        case .GSharp: return (whiteKeyWidth * 5) - (blackKeyWidth / 2)
        case .ASharp: return (whiteKeyWidth * 6) - (blackKeyWidth / 2)
        default: return 0
        }
    }
    
    private func handleKeyPress(_ key: KeyboardKey, at location: CGPoint) {
        presenterObject.keyPressed(key, velocity: 0.8, at: location)
    }
    
    private func handleKeyRelease(_ key: KeyboardKey) {
        presenterObject.keyReleased(key)
    }
}

// MARK: - Individual Key View

struct KeyView: View {
    let key: KeyboardKey
    let isPressed: Bool
    let color: Color
    let velocity: Float?
    let onPress: (CGPoint) -> Void
    let onRelease: () -> Void
    
    @State private var dragLocation: CGPoint = .zero
    
    var body: some View {
        ZStack {
            // Key background
            RoundedRectangle(cornerRadius: 4)
                .fill(keyColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .frame(width: key.position.width, height: key.position.height)
            
            // Key label
            VStack {
                Spacer()
                Text(key.note.name)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(labelColor)
                    .padding(.bottom, 8)
            }
            
            // Velocity indicator
            if let velocity = velocity {
                VStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .opacity(Double(velocity))
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isPressed {
                        dragLocation = value.location
                        onPress(value.location)
                    }
                }
                .onEnded { _ in
                    if isPressed {
                        onRelease()
                    }
                }
        )
    }
    
    private var keyColor: Color {
        if isPressed {
            return color.opacity(0.7)
        } else {
            return color
        }
    }
    
    private var labelColor: Color {
        return key.keyType == .white ? .black : .white
    }
}

// MARK: - Preview

struct OnScreenKeyboardView_Previews: PreviewProvider {
    static var previews: some View {
        OnScreenKeyboardRouter.createModule()
            .preferredColorScheme(.dark)
    }
}
