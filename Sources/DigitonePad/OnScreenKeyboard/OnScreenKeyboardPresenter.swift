import Foundation
import SwiftUI
import Combine

/// Presenter handles presentation logic and coordinates between View and Interactor
class OnScreenKeyboardPresenter: OnScreenKeyboardPresenterProtocol, ObservableObject {
    weak var view: OnScreenKeyboardViewProtocol?
    var interactor: OnScreenKeyboardInteractorProtocol?
    var router: OnScreenKeyboardRouterProtocol?
    
    // Published properties for SwiftUI binding
    @Published var currentOctave: Int = 4
    @Published var currentScale: MusicalScale? = nil
    @Published var highlightedChord: [KeyboardKey] = []
    @Published var pressedKeys: Set<KeyboardKey> = []
    @Published var keyboardLayout: KeyboardLayout = .standard
    @Published var showingScaleSelector = false
    @Published var showingChordSelector = false
    
    // Delegate for external keyboard events
    weak var delegate: OnScreenKeyboardDelegate?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    // MARK: - OnScreenKeyboardPresenterProtocol
    
    func viewDidLoad() {
        // Initialize keyboard state
        currentOctave = interactor?.getCurrentOctave() ?? 4
        currentScale = interactor?.getCurrentScale()
        
        // Update view with initial state
        view?.updateOctave(currentOctave)
        if let scale = currentScale {
            view?.updateScale(scale)
        }
        view?.updateKeyboardLayout(keyboardLayout)
    }
    
    func keyPressed(_ key: KeyboardKey, velocity: Float, at location: CGPoint) {
        // Calculate velocity based on touch location
        let calculatedVelocity = interactor?.calculateVelocity(
            from: location,
            keyBounds: key.position.frame
        ) ?? velocity
        
        // Process key press through interactor
        interactor?.processKeyPress(key, velocity: calculatedVelocity)
        
        // Update view
        view?.updateKeyState(key, isPressed: true)
        view?.showVelocityIndicator(calculatedVelocity, for: key)
        
        // Update local state
        pressedKeys.insert(key)
        
        // Notify delegate
        delegate?.keyboardDidPressKey(key, velocity: calculatedVelocity)
    }
    
    func keyReleased(_ key: KeyboardKey) {
        // Process key release through interactor
        interactor?.processKeyRelease(key)
        
        // Update view
        view?.updateKeyState(key, isPressed: false)
        
        // Update local state
        pressedKeys.remove(key)
        
        // Notify delegate
        delegate?.keyboardDidReleaseKey(key)
    }
    
    func octaveShiftRequested(_ direction: OctaveDirection) {
        interactor?.changeOctave(direction)
    }
    
    func scaleSelected(_ scale: MusicalScale) {
        interactor?.setScale(scale)
        showingScaleSelector = false
    }
    
    func chordRequested(_ chordType: ChordType, rootNote: Note) {
        guard let chordKeys = interactor?.generateChord(chordType, rootNote: rootNote) else {
            return
        }
        
        highlightedChord = chordKeys
        view?.highlightChord(chordKeys)
        showingChordSelector = false
    }
    
    func keyboardLayoutChanged(_ layout: KeyboardLayout) {
        keyboardLayout = layout
        interactor?.updateKeyboardLayout(layout)
    }
    
    // MARK: - Interactor Response Handlers
    
    func keyPressed(_ key: KeyboardKey, velocity: Float) {
        // This is called by the interactor after processing
        DispatchQueue.main.async { [weak self] in
            self?.pressedKeys.insert(key)
        }
    }
    
    func keyReleased(_ key: KeyboardKey) {
        // This is called by the interactor after processing
        DispatchQueue.main.async { [weak self] in
            self?.pressedKeys.remove(key)
        }
    }
    
    func octaveChanged(_ octave: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.currentOctave = octave
            self?.view?.updateOctave(octave)
            self?.delegate?.keyboardDidChangeOctave(octave)
        }
    }
    
    func scaleChanged(_ scale: MusicalScale) {
        DispatchQueue.main.async { [weak self] in
            self?.currentScale = scale
            self?.view?.updateScale(scale)
            self?.delegate?.keyboardDidSelectScale(scale)
        }
    }
    
    func scaleHighlightingUpdated(_ scale: MusicalScale) {
        DispatchQueue.main.async { [weak self] in
            self?.view?.updateScale(scale)
        }
    }
    
    func keyboardLayoutUpdated(_ layout: KeyboardLayout) {
        DispatchQueue.main.async { [weak self] in
            self?.keyboardLayout = layout
            self?.view?.updateKeyboardLayout(layout)
        }
    }
    
    // MARK: - User Actions
    
    func showScaleSelector() {
        showingScaleSelector = true
    }
    
    func hideScaleSelector() {
        showingScaleSelector = false
    }
    
    func showChordSelector() {
        showingChordSelector = true
    }
    
    func hideChordSelector() {
        showingChordSelector = false
    }
    
    func clearScale() {
        currentScale = nil
        view?.updateScale(nil)
        delegate?.keyboardDidSelectScale(nil)
    }
    
    func clearChordHighlight() {
        highlightedChord.removeAll()
        view?.highlightChord([])
    }
    
    func transposeUp() {
        octaveShiftRequested(.up)
    }
    
    func transposeDown() {
        octaveShiftRequested(.down)
    }
    
    // MARK: - Keyboard Layout Management
    
    func setCompactLayout() {
        keyboardLayoutChanged(.compact)
    }
    
    func setStandardLayout() {
        keyboardLayoutChanged(.standard)
    }
    
    func createCustomLayout(octaveRange: ClosedRange<Int>, keySize: CGSize) {
        let customLayout = KeyboardLayout(
            octaveRange: octaveRange,
            whiteKeyWidth: keySize.width,
            whiteKeyHeight: keySize.height,
            blackKeyWidth: keySize.width * 0.7,
            blackKeyHeight: keySize.height * 0.65,
            keySpacing: 2
        )
        keyboardLayoutChanged(customLayout)
    }
    
    // MARK: - Utility Methods
    
    func isKeyPressed(_ key: KeyboardKey) -> Bool {
        return pressedKeys.contains(key)
    }
    
    func isKeyInScale(_ key: KeyboardKey) -> Bool {
        guard let scale = currentScale else { return true }
        return scale.intervals.contains(key.note.rawValue % 12)
    }
    
    func isKeyInChord(_ key: KeyboardKey) -> Bool {
        return highlightedChord.contains(key)
    }
    
    func getKeyColor(_ key: KeyboardKey) -> Color {
        if isKeyPressed(key) {
            return .blue
        } else if isKeyInChord(key) {
            return .yellow
        } else if !isKeyInScale(key) && currentScale != nil {
            return key.keyType.color.opacity(0.5)
        } else {
            return key.keyType.color
        }
    }
    
    func getOctaveDisplayText() -> String {
        return "OCT \(currentOctave)"
    }
    
    func getScaleDisplayText() -> String {
        return currentScale?.rawValue ?? "CHROMATIC"
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Set up any Combine bindings if needed
        // This could be used for reactive updates between properties
    }
    
    // MARK: - Preset Management
    
    func saveKeyboardPreset(name: String) -> KeyboardPreset {
        return KeyboardPreset(
            name: name,
            octave: currentOctave,
            scale: currentScale,
            layout: keyboardLayout
        )
    }
    
    func loadKeyboardPreset(_ preset: KeyboardPreset) {
        currentOctave = preset.octave
        currentScale = preset.scale
        keyboardLayout = preset.layout
        
        // Update interactor and view
        interactor?.changeOctave(.up) // This will set to current octave
        if let scale = preset.scale {
            interactor?.setScale(scale)
        }
        interactor?.updateKeyboardLayout(preset.layout)
        
        // Update view
        view?.updateOctave(preset.octave)
        view?.updateScale(preset.scale)
        view?.updateKeyboardLayout(preset.layout)
    }
}

// MARK: - Keyboard Preset

struct KeyboardPreset: Codable {
    let name: String
    let octave: Int
    let scale: MusicalScale?
    let layout: KeyboardLayout
    
    init(name: String, octave: Int, scale: MusicalScale?, layout: KeyboardLayout) {
        self.name = name
        self.octave = octave
        self.scale = scale
        self.layout = layout
    }
}

// MARK: - Keyboard Layout Codable

extension KeyboardLayout: Codable {
    enum CodingKeys: String, CodingKey {
        case octaveRangeLower, octaveRangeUpper
        case whiteKeyWidth, whiteKeyHeight
        case blackKeyWidth, blackKeyHeight
        case keySpacing
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lower = try container.decode(Int.self, forKey: .octaveRangeLower)
        let upper = try container.decode(Int.self, forKey: .octaveRangeUpper)
        
        self.octaveRange = lower...upper
        self.whiteKeyWidth = try container.decode(CGFloat.self, forKey: .whiteKeyWidth)
        self.whiteKeyHeight = try container.decode(CGFloat.self, forKey: .whiteKeyHeight)
        self.blackKeyWidth = try container.decode(CGFloat.self, forKey: .blackKeyWidth)
        self.blackKeyHeight = try container.decode(CGFloat.self, forKey: .blackKeyHeight)
        self.keySpacing = try container.decode(CGFloat.self, forKey: .keySpacing)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(octaveRange.lowerBound, forKey: .octaveRangeLower)
        try container.encode(octaveRange.upperBound, forKey: .octaveRangeUpper)
        try container.encode(whiteKeyWidth, forKey: .whiteKeyWidth)
        try container.encode(whiteKeyHeight, forKey: .whiteKeyHeight)
        try container.encode(blackKeyWidth, forKey: .blackKeyWidth)
        try container.encode(blackKeyHeight, forKey: .blackKeyHeight)
        try container.encode(keySpacing, forKey: .keySpacing)
    }
}
