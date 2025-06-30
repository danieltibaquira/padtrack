import Foundation
import SwiftUI
import Combine

// MARK: - VIPER Protocols for On-Screen Keyboard

/// View Protocol - Defines what the View can do
protocol OnScreenKeyboardViewProtocol: AnyObject {
    var presenter: OnScreenKeyboardPresenterProtocol? { get set }
    
    func updateKeyState(_ key: KeyboardKey, isPressed: Bool)
    func updateOctave(_ octave: Int)
    func updateScale(_ scale: MusicalScale?)
    func highlightChord(_ chord: [KeyboardKey])
    func showVelocityIndicator(_ velocity: Float, for key: KeyboardKey)
    func updateKeyboardLayout(_ layout: KeyboardLayout)
}

/// Presenter Protocol - Defines what the Presenter can do
protocol OnScreenKeyboardPresenterProtocol: AnyObject {
    var view: OnScreenKeyboardViewProtocol? { get set }
    var interactor: OnScreenKeyboardInteractorProtocol? { get set }
    var router: OnScreenKeyboardRouterProtocol? { get set }
    
    func viewDidLoad()
    func keyPressed(_ key: KeyboardKey, velocity: Float, at location: CGPoint)
    func keyReleased(_ key: KeyboardKey)
    func octaveShiftRequested(_ direction: OctaveDirection)
    func scaleSelected(_ scale: MusicalScale)
    func chordRequested(_ chordType: ChordType, rootNote: Note)
    func keyboardLayoutChanged(_ layout: KeyboardLayout)
}

/// Interactor Protocol - Defines what the Interactor can do
protocol OnScreenKeyboardInteractorProtocol: AnyObject {
    var presenter: OnScreenKeyboardPresenterProtocol? { get set }
    
    func processKeyPress(_ key: KeyboardKey, velocity: Float)
    func processKeyRelease(_ key: KeyboardKey)
    func changeOctave(_ direction: OctaveDirection)
    func setScale(_ scale: MusicalScale)
    func generateChord(_ chordType: ChordType, rootNote: Note) -> [KeyboardKey]
    func calculateVelocity(from touchLocation: CGPoint, keyBounds: CGRect) -> Float
    func getCurrentOctave() -> Int
    func getCurrentScale() -> MusicalScale?
}

/// Router Protocol - Defines what the Router can do
protocol OnScreenKeyboardRouterProtocol: AnyObject {
    static func createModule() -> AnyView
    
    func showScaleSelector()
    func showChordSelector()
    func showKeyboardSettings()
}

// MARK: - Data Models

/// Represents a keyboard key
struct KeyboardKey: Identifiable, Equatable, Hashable {
    let id = UUID()
    let note: Note
    let octave: Int
    let keyType: KeyType
    let position: KeyPosition
    
    var midiNote: Int {
        return note.midiValue + (octave * 12)
    }
    
    var displayName: String {
        return "\(note.name)\(octave)"
    }
}

/// Musical note representation
enum Note: Int, CaseIterable {
    case C = 0, CSharp, D, DSharp, E, F, FSharp, G, GSharp, A, ASharp, B
    
    var name: String {
        switch self {
        case .C: return "C"
        case .CSharp: return "C#"
        case .D: return "D"
        case .DSharp: return "D#"
        case .E: return "E"
        case .F: return "F"
        case .FSharp: return "F#"
        case .G: return "G"
        case .GSharp: return "G#"
        case .A: return "A"
        case .ASharp: return "A#"
        case .B: return "B"
        }
    }
    
    var midiValue: Int {
        return rawValue
    }
    
    var isBlackKey: Bool {
        switch self {
        case .CSharp, .DSharp, .FSharp, .GSharp, .ASharp:
            return true
        default:
            return false
        }
    }
}

/// Key type (white or black)
enum KeyType {
    case white
    case black
    
    var color: Color {
        switch self {
        case .white: return .white
        case .black: return .black
        }
    }
}

/// Key position on the keyboard
struct KeyPosition {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    
    var frame: CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

/// Octave shift direction
enum OctaveDirection {
    case up
    case down
}

/// Musical scales
enum MusicalScale: String, CaseIterable {
    case chromatic = "Chromatic"
    case major = "Major"
    case minor = "Minor"
    case pentatonic = "Pentatonic"
    case blues = "Blues"
    case dorian = "Dorian"
    case mixolydian = "Mixolydian"
    
    var intervals: [Int] {
        switch self {
        case .chromatic:
            return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        case .major:
            return [0, 2, 4, 5, 7, 9, 11]
        case .minor:
            return [0, 2, 3, 5, 7, 8, 10]
        case .pentatonic:
            return [0, 2, 4, 7, 9]
        case .blues:
            return [0, 3, 5, 6, 7, 10]
        case .dorian:
            return [0, 2, 3, 5, 7, 9, 10]
        case .mixolydian:
            return [0, 2, 4, 5, 7, 9, 10]
        }
    }
}

/// Chord types
enum ChordType: String, CaseIterable {
    case major = "Major"
    case minor = "Minor"
    case diminished = "Diminished"
    case augmented = "Augmented"
    case major7 = "Major 7"
    case minor7 = "Minor 7"
    case dominant7 = "Dominant 7"
    
    var intervals: [Int] {
        switch self {
        case .major:
            return [0, 4, 7]
        case .minor:
            return [0, 3, 7]
        case .diminished:
            return [0, 3, 6]
        case .augmented:
            return [0, 4, 8]
        case .major7:
            return [0, 4, 7, 11]
        case .minor7:
            return [0, 3, 7, 10]
        case .dominant7:
            return [0, 4, 7, 10]
        }
    }
}

/// Keyboard layout configuration
struct KeyboardLayout {
    let octaveRange: ClosedRange<Int>
    let whiteKeyWidth: CGFloat
    let whiteKeyHeight: CGFloat
    let blackKeyWidth: CGFloat
    let blackKeyHeight: CGFloat
    let keySpacing: CGFloat
    
    static let standard = KeyboardLayout(
        octaveRange: 2...6,
        whiteKeyWidth: 60,
        whiteKeyHeight: 200,
        blackKeyWidth: 40,
        blackKeyHeight: 130,
        keySpacing: 2
    )
    
    static let compact = KeyboardLayout(
        octaveRange: 3...5,
        whiteKeyWidth: 45,
        whiteKeyHeight: 150,
        blackKeyWidth: 30,
        blackKeyHeight: 100,
        keySpacing: 1
    )
}

/// Keyboard state for managing current settings
class KeyboardState: ObservableObject {
    @Published var currentOctave: Int = 4
    @Published var currentScale: MusicalScale? = nil
    @Published var highlightedChord: [KeyboardKey] = []
    @Published var pressedKeys: Set<KeyboardKey> = []
    @Published var keyboardLayout: KeyboardLayout = .standard
    @Published var velocitySensitivity: Float = 1.0
    
    func isKeyInScale(_ key: KeyboardKey) -> Bool {
        guard let scale = currentScale else { return true }
        let noteInScale = scale.intervals.contains(key.note.rawValue % 12)
        return noteInScale
    }
    
    func isKeyInChord(_ key: KeyboardKey) -> Bool {
        return highlightedChord.contains(key)
    }
    
    func addPressedKey(_ key: KeyboardKey) {
        pressedKeys.insert(key)
    }
    
    func removePressedKey(_ key: KeyboardKey) {
        pressedKeys.remove(key)
    }
    
    func clearPressedKeys() {
        pressedKeys.removeAll()
    }
}

// MARK: - Keyboard Events

/// Event for key press/release
struct KeyboardEvent {
    let key: KeyboardKey
    let velocity: Float
    let timestamp: Date
    let eventType: KeyboardEventType
    
    init(key: KeyboardKey, velocity: Float, eventType: KeyboardEventType) {
        self.key = key
        self.velocity = velocity
        self.eventType = eventType
        self.timestamp = Date()
    }
}

enum KeyboardEventType {
    case keyDown
    case keyUp
}

// MARK: - Keyboard Delegate

/// Delegate protocol for keyboard events
protocol OnScreenKeyboardDelegate: AnyObject {
    func keyboardDidPressKey(_ key: KeyboardKey, velocity: Float)
    func keyboardDidReleaseKey(_ key: KeyboardKey)
    func keyboardDidChangeOctave(_ octave: Int)
    func keyboardDidSelectScale(_ scale: MusicalScale?)
}

// MARK: - Errors

enum OnScreenKeyboardError: LocalizedError {
    case invalidOctave
    case invalidNote
    case keyboardNotInitialized
    case invalidVelocity
    
    var errorDescription: String? {
        switch self {
        case .invalidOctave:
            return "Invalid octave value"
        case .invalidNote:
            return "Invalid note value"
        case .keyboardNotInitialized:
            return "Keyboard not properly initialized"
        case .invalidVelocity:
            return "Invalid velocity value"
        }
    }
}
