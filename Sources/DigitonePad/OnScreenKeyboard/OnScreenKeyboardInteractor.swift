import Foundation
import SwiftUI
import Combine

/// Interactor handles business logic for the on-screen keyboard
class OnScreenKeyboardInteractor: OnScreenKeyboardInteractorProtocol {
    weak var presenter: OnScreenKeyboardPresenterProtocol?
    
    private var keyboardState = KeyboardState()
    private var activeNotes: [KeyboardKey: Date] = [:]
    private let maxPolyphony = 10
    
    // MARK: - OnScreenKeyboardInteractorProtocol
    
    func processKeyPress(_ key: KeyboardKey, velocity: Float) {
        // Validate velocity
        let clampedVelocity = max(0.0, min(1.0, velocity))
        
        // Check polyphony limit
        if activeNotes.count >= maxPolyphony {
            // Remove oldest note
            if let oldestKey = activeNotes.min(by: { $0.value < $1.value })?.key {
                processKeyRelease(oldestKey)
            }
        }
        
        // Add to active notes
        activeNotes[key] = Date()
        keyboardState.addPressedKey(key)
        
        // Notify presenter
        presenter?.keyPressed(key, velocity: clampedVelocity)
        
        // Send MIDI note on event (would integrate with audio engine)
        sendMIDINoteOn(key: key, velocity: clampedVelocity)
    }
    
    func processKeyRelease(_ key: KeyboardKey) {
        // Remove from active notes
        activeNotes.removeValue(forKey: key)
        keyboardState.removePressedKey(key)
        
        // Notify presenter
        presenter?.keyReleased(key)
        
        // Send MIDI note off event
        sendMIDINoteOff(key: key)
    }
    
    func changeOctave(_ direction: OctaveDirection) {
        let currentOctave = keyboardState.currentOctave
        let newOctave: Int
        
        switch direction {
        case .up:
            newOctave = min(currentOctave + 1, keyboardState.keyboardLayout.octaveRange.upperBound)
        case .down:
            newOctave = max(currentOctave - 1, keyboardState.keyboardLayout.octaveRange.lowerBound)
        }
        
        if newOctave != currentOctave {
            keyboardState.currentOctave = newOctave
            presenter?.octaveChanged(newOctave)
        }
    }
    
    func setScale(_ scale: MusicalScale) {
        keyboardState.currentScale = scale
        presenter?.scaleChanged(scale)
        
        // Update key highlighting based on scale
        updateScaleHighlighting()
    }
    
    func generateChord(_ chordType: ChordType, rootNote: Note) -> [KeyboardKey] {
        let intervals = chordType.intervals
        let currentOctave = keyboardState.currentOctave
        
        var chordKeys: [KeyboardKey] = []
        
        for interval in intervals {
            let noteValue = (rootNote.rawValue + interval) % 12
            let octaveOffset = (rootNote.rawValue + interval) / 12
            let chordNote = Note(rawValue: noteValue) ?? rootNote
            let chordOctave = currentOctave + octaveOffset
            
            // Create key position (simplified for now)
            let position = calculateKeyPosition(note: chordNote, octave: chordOctave)
            
            let key = KeyboardKey(
                note: chordNote,
                octave: chordOctave,
                keyType: chordNote.isBlackKey ? .black : .white,
                position: position
            )
            
            chordKeys.append(key)
        }
        
        keyboardState.highlightedChord = chordKeys
        return chordKeys
    }
    
    func calculateVelocity(from touchLocation: CGPoint, keyBounds: CGRect) -> Float {
        // Calculate velocity based on touch position within the key
        // Higher touch = lower velocity, lower touch = higher velocity
        let relativeY = (touchLocation.y - keyBounds.minY) / keyBounds.height
        let velocity = 1.0 - Float(relativeY) // Invert so bottom = max velocity
        
        // Apply velocity sensitivity curve
        let sensitivityCurve = keyboardState.velocitySensitivity
        let adjustedVelocity = pow(velocity, 1.0 / sensitivityCurve)
        
        return max(0.1, min(1.0, adjustedVelocity)) // Ensure minimum velocity
    }
    
    func getCurrentOctave() -> Int {
        return keyboardState.currentOctave
    }
    
    func getCurrentScale() -> MusicalScale? {
        return keyboardState.currentScale
    }
    
    // MARK: - Private Methods
    
    private func sendMIDINoteOn(key: KeyboardKey, velocity: Float) {
        // This would integrate with the audio engine to send MIDI events
        // For now, we'll just log the event
        print("MIDI Note On: \(key.displayName) (MIDI: \(key.midiNote)) Velocity: \(velocity)")
        
        // TODO: Integrate with AudioEngine for actual MIDI output
        // AudioEngine.shared.sendMIDINoteOn(note: key.midiNote, velocity: UInt8(velocity * 127))
    }
    
    private func sendMIDINoteOff(key: KeyboardKey) {
        // This would integrate with the audio engine to send MIDI events
        print("MIDI Note Off: \(key.displayName) (MIDI: \(key.midiNote))")
        
        // TODO: Integrate with AudioEngine for actual MIDI output
        // AudioEngine.shared.sendMIDINoteOff(note: key.midiNote)
    }
    
    private func updateScaleHighlighting() {
        // Notify presenter to update scale highlighting
        if let scale = keyboardState.currentScale {
            presenter?.scaleHighlightingUpdated(scale)
        }
    }
    
    private func calculateKeyPosition(note: Note, octave: Int) -> KeyPosition {
        let layout = keyboardState.keyboardLayout
        
        // Calculate position based on note and octave
        let whiteKeyIndex = getWhiteKeyIndex(for: note)
        let octaveOffset = CGFloat(octave - layout.octaveRange.lowerBound)
        let whiteKeysPerOctave: CGFloat = 7
        
        if note.isBlackKey {
            // Black key positioning
            let blackKeyOffset = getBlackKeyOffset(for: note)
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
        // Map notes to white key indices (C=0, D=1, E=2, F=3, G=4, A=5, B=6)
        switch note {
        case .C: return 0
        case .D: return 1
        case .E: return 2
        case .F: return 3
        case .G: return 4
        case .A: return 5
        case .B: return 6
        default: return 0 // Black keys don't have white key indices
        }
    }
    
    private func getBlackKeyOffset(for note: Note) -> CGFloat {
        let layout = keyboardState.keyboardLayout
        let whiteKeyWidth = layout.whiteKeyWidth
        let blackKeyWidth = layout.blackKeyWidth
        
        // Offset black keys to be positioned between white keys
        switch note {
        case .CSharp: return whiteKeyWidth - (blackKeyWidth / 2)
        case .DSharp: return (whiteKeyWidth * 2) - (blackKeyWidth / 2)
        case .FSharp: return (whiteKeyWidth * 4) - (blackKeyWidth / 2)
        case .GSharp: return (whiteKeyWidth * 5) - (blackKeyWidth / 2)
        case .ASharp: return (whiteKeyWidth * 6) - (blackKeyWidth / 2)
        default: return 0
        }
    }
    
    // MARK: - Keyboard State Management
    
    func getKeyboardState() -> KeyboardState {
        return keyboardState
    }
    
    func updateKeyboardLayout(_ layout: KeyboardLayout) {
        keyboardState.keyboardLayout = layout
        
        // Clear active notes when layout changes
        for key in activeNotes.keys {
            processKeyRelease(key)
        }
        
        presenter?.keyboardLayoutUpdated(layout)
    }
    
    func setVelocitySensitivity(_ sensitivity: Float) {
        keyboardState.velocitySensitivity = max(0.1, min(2.0, sensitivity))
    }
    
    func clearAllActiveNotes() {
        for key in activeNotes.keys {
            processKeyRelease(key)
        }
        keyboardState.clearPressedKeys()
    }
}

// MARK: - Presenter Protocol Extensions

extension OnScreenKeyboardPresenterProtocol {
    func keyPressed(_ key: KeyboardKey, velocity: Float) {}
    func keyReleased(_ key: KeyboardKey) {}
    func octaveChanged(_ octave: Int) {}
    func scaleChanged(_ scale: MusicalScale) {}
    func scaleHighlightingUpdated(_ scale: MusicalScale) {}
    func keyboardLayoutUpdated(_ layout: KeyboardLayout) {}
}

// MARK: - Utility Extensions

extension Note {
    static func fromMIDI(_ midiNote: Int) -> (note: Note, octave: Int) {
        let noteValue = midiNote % 12
        let octave = midiNote / 12
        let note = Note(rawValue: noteValue) ?? .C
        return (note, octave)
    }
}

extension KeyboardKey {
    static func fromMIDI(_ midiNote: Int, layout: KeyboardLayout) -> KeyboardKey? {
        let (note, octave) = Note.fromMIDI(midiNote)
        
        guard layout.octaveRange.contains(octave) else {
            return nil
        }
        
        // Calculate position (simplified)
        let position = KeyPosition(x: 0, y: 0, width: 60, height: 200)
        
        return KeyboardKey(
            note: note,
            octave: octave,
            keyType: note.isBlackKey ? .black : .white,
            position: position
        )
    }
}
