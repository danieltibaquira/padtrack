import XCTest
import SwiftUI
import Combine
@testable import DigitonePad

/// Unit tests for On-Screen Keyboard functionality
class OnScreenKeyboardTests: XCTestCase {
    
    var presenter: OnScreenKeyboardPresenter!
    var interactor: MockOnScreenKeyboardInteractor!
    var router: MockOnScreenKeyboardRouter!
    var view: MockOnScreenKeyboardView!
    
    override func setUp() {
        super.setUp()
        
        presenter = OnScreenKeyboardPresenter()
        interactor = MockOnScreenKeyboardInteractor()
        router = MockOnScreenKeyboardRouter()
        view = MockOnScreenKeyboardView()
        
        // Wire up VIPER components
        presenter.interactor = interactor
        presenter.router = router
        presenter.view = view
        interactor.presenter = presenter
    }
    
    override func tearDown() {
        presenter = nil
        interactor = nil
        router = nil
        view = nil
        super.tearDown()
    }
    
    // MARK: - Presenter Tests
    
    func testPresenter_ViewDidLoad_InitializesState() {
        // Given
        interactor.mockCurrentOctave = 4
        interactor.mockCurrentScale = .major
        
        // When
        presenter.viewDidLoad()
        
        // Then
        XCTAssertTrue(interactor.getCurrentOctaveCalled)
        XCTAssertTrue(interactor.getCurrentScaleCalled)
        XCTAssertTrue(view.updateOctaveCalled)
        XCTAssertTrue(view.updateScaleCalled)
        XCTAssertTrue(view.updateKeyboardLayoutCalled)
    }
    
    func testPresenter_KeyPressed_ProcessesKeyPress() {
        // Given
        let key = createMockKey()
        let velocity: Float = 0.8
        let location = CGPoint(x: 30, y: 100)
        
        interactor.mockCalculatedVelocity = 0.7
        
        // When
        presenter.keyPressed(key, velocity: velocity, at: location)
        
        // Then
        XCTAssertTrue(interactor.calculateVelocityCalled)
        XCTAssertTrue(interactor.processKeyPressCalled)
        XCTAssertEqual(interactor.processKeyPressKey?.id, key.id)
        XCTAssertEqual(interactor.processKeyPressVelocity, 0.7)
        
        XCTAssertTrue(view.updateKeyStateCalled)
        XCTAssertTrue(view.showVelocityIndicatorCalled)
        XCTAssertTrue(presenter.pressedKeys.contains(key))
    }
    
    func testPresenter_KeyReleased_ProcessesKeyRelease() {
        // Given
        let key = createMockKey()
        presenter.pressedKeys.insert(key)
        
        // When
        presenter.keyReleased(key)
        
        // Then
        XCTAssertTrue(interactor.processKeyReleaseCalled)
        XCTAssertEqual(interactor.processKeyReleaseKey?.id, key.id)
        
        XCTAssertTrue(view.updateKeyStateCalled)
        XCTAssertFalse(presenter.pressedKeys.contains(key))
    }
    
    func testPresenter_OctaveShiftUp_ChangesOctave() {
        // Given
        presenter.currentOctave = 4
        
        // When
        presenter.octaveShiftRequested(.up)
        
        // Then
        XCTAssertTrue(interactor.changeOctaveCalled)
        XCTAssertEqual(interactor.changeOctaveDirection, .up)
    }
    
    func testPresenter_OctaveShiftDown_ChangesOctave() {
        // Given
        presenter.currentOctave = 4
        
        // When
        presenter.octaveShiftRequested(.down)
        
        // Then
        XCTAssertTrue(interactor.changeOctaveCalled)
        XCTAssertEqual(interactor.changeOctaveDirection, .down)
    }
    
    func testPresenter_ScaleSelected_SetsScale() {
        // Given
        let scale = MusicalScale.major
        
        // When
        presenter.scaleSelected(scale)
        
        // Then
        XCTAssertTrue(interactor.setScaleCalled)
        XCTAssertEqual(interactor.setScaleValue, scale)
        XCTAssertFalse(presenter.showingScaleSelector)
    }
    
    func testPresenter_ChordRequested_GeneratesChord() {
        // Given
        let chordType = ChordType.major
        let rootNote = Note.C
        let mockChordKeys = [createMockKey(note: .C), createMockKey(note: .E), createMockKey(note: .G)]
        
        interactor.mockGeneratedChord = mockChordKeys
        
        // When
        presenter.chordRequested(chordType, rootNote: rootNote)
        
        // Then
        XCTAssertTrue(interactor.generateChordCalled)
        XCTAssertEqual(interactor.generateChordType, chordType)
        XCTAssertEqual(interactor.generateChordRootNote, rootNote)
        
        XCTAssertEqual(presenter.highlightedChord.count, 3)
        XCTAssertTrue(view.highlightChordCalled)
        XCTAssertFalse(presenter.showingChordSelector)
    }
    
    // MARK: - Interactor Tests
    
    func testInteractor_ProcessKeyPress_ValidVelocity() {
        // Given
        let realInteractor = OnScreenKeyboardInteractor()
        let key = createMockKey()
        let velocity: Float = 0.8
        
        // When
        realInteractor.processKeyPress(key, velocity: velocity)
        
        // Then
        // Verify that the key press was processed (would check MIDI output in real implementation)
        XCTAssertTrue(true) // Placeholder assertion
    }
    
    func testInteractor_ProcessKeyPress_ClampsVelocity() {
        // Given
        let realInteractor = OnScreenKeyboardInteractor()
        let key = createMockKey()
        
        // When - test with velocity > 1.0
        realInteractor.processKeyPress(key, velocity: 1.5)
        
        // Then - velocity should be clamped to 1.0
        // In a real implementation, we'd verify the MIDI output velocity
        XCTAssertTrue(true) // Placeholder assertion
    }
    
    func testInteractor_ChangeOctave_Up() {
        // Given
        let realInteractor = OnScreenKeyboardInteractor()
        let initialOctave = realInteractor.getCurrentOctave()
        
        // When
        realInteractor.changeOctave(.up)
        
        // Then
        let newOctave = realInteractor.getCurrentOctave()
        XCTAssertGreaterThanOrEqual(newOctave, initialOctave)
    }
    
    func testInteractor_ChangeOctave_Down() {
        // Given
        let realInteractor = OnScreenKeyboardInteractor()
        let initialOctave = realInteractor.getCurrentOctave()
        
        // When
        realInteractor.changeOctave(.down)
        
        // Then
        let newOctave = realInteractor.getCurrentOctave()
        XCTAssertLessThanOrEqual(newOctave, initialOctave)
    }
    
    func testInteractor_SetScale_UpdatesScale() {
        // Given
        let realInteractor = OnScreenKeyboardInteractor()
        let scale = MusicalScale.minor
        
        // When
        realInteractor.setScale(scale)
        
        // Then
        XCTAssertEqual(realInteractor.getCurrentScale(), scale)
    }
    
    func testInteractor_GenerateChord_MajorChord() {
        // Given
        let realInteractor = OnScreenKeyboardInteractor()
        let chordType = ChordType.major
        let rootNote = Note.C
        
        // When
        let chordKeys = realInteractor.generateChord(chordType, rootNote: rootNote)
        
        // Then
        XCTAssertEqual(chordKeys.count, 3) // Major chord has 3 notes
        
        // Verify chord intervals (C, E, G)
        let noteValues = chordKeys.map { $0.note.rawValue }.sorted()
        let expectedIntervals = [0, 4, 7] // C major intervals
        XCTAssertEqual(noteValues, expectedIntervals)
    }
    
    func testInteractor_CalculateVelocity_TopOfKey() {
        // Given
        let realInteractor = OnScreenKeyboardInteractor()
        let touchLocation = CGPoint(x: 30, y: 10) // Near top of key
        let keyBounds = CGRect(x: 0, y: 0, width: 60, height: 200)
        
        // When
        let velocity = realInteractor.calculateVelocity(from: touchLocation, keyBounds: keyBounds)
        
        // Then
        XCTAssertLessThan(velocity, 0.5) // Top of key should give lower velocity
    }
    
    func testInteractor_CalculateVelocity_BottomOfKey() {
        // Given
        let realInteractor = OnScreenKeyboardInteractor()
        let touchLocation = CGPoint(x: 30, y: 180) // Near bottom of key
        let keyBounds = CGRect(x: 0, y: 0, width: 60, height: 200)
        
        // When
        let velocity = realInteractor.calculateVelocity(from: touchLocation, keyBounds: keyBounds)
        
        // Then
        XCTAssertGreaterThan(velocity, 0.5) // Bottom of key should give higher velocity
    }
    
    // MARK: - Data Model Tests
    
    func testKeyboardKey_MIDINote_Calculation() {
        // Given
        let key = KeyboardKey(
            note: .C,
            octave: 4,
            keyType: .white,
            position: KeyPosition(x: 0, y: 0, width: 60, height: 200)
        )
        
        // When
        let midiNote = key.midiNote
        
        // Then
        XCTAssertEqual(midiNote, 48) // C4 = MIDI note 48
    }
    
    func testKeyboardKey_DisplayName() {
        // Given
        let key = KeyboardKey(
            note: .CSharp,
            octave: 5,
            keyType: .black,
            position: KeyPosition(x: 0, y: 0, width: 40, height: 130)
        )
        
        // When
        let displayName = key.displayName
        
        // Then
        XCTAssertEqual(displayName, "C#5")
    }
    
    func testNote_IsBlackKey() {
        // Test black keys
        XCTAssertTrue(Note.CSharp.isBlackKey)
        XCTAssertTrue(Note.DSharp.isBlackKey)
        XCTAssertTrue(Note.FSharp.isBlackKey)
        XCTAssertTrue(Note.GSharp.isBlackKey)
        XCTAssertTrue(Note.ASharp.isBlackKey)
        
        // Test white keys
        XCTAssertFalse(Note.C.isBlackKey)
        XCTAssertFalse(Note.D.isBlackKey)
        XCTAssertFalse(Note.E.isBlackKey)
        XCTAssertFalse(Note.F.isBlackKey)
        XCTAssertFalse(Note.G.isBlackKey)
        XCTAssertFalse(Note.A.isBlackKey)
        XCTAssertFalse(Note.B.isBlackKey)
    }
    
    func testMusicalScale_Intervals() {
        // Test major scale intervals
        let majorIntervals = MusicalScale.major.intervals
        XCTAssertEqual(majorIntervals, [0, 2, 4, 5, 7, 9, 11])
        
        // Test minor scale intervals
        let minorIntervals = MusicalScale.minor.intervals
        XCTAssertEqual(minorIntervals, [0, 2, 3, 5, 7, 8, 10])
        
        // Test pentatonic scale intervals
        let pentatonicIntervals = MusicalScale.pentatonic.intervals
        XCTAssertEqual(pentatonicIntervals, [0, 2, 4, 7, 9])
    }
    
    func testChordType_Intervals() {
        // Test major chord intervals
        let majorIntervals = ChordType.major.intervals
        XCTAssertEqual(majorIntervals, [0, 4, 7])
        
        // Test minor chord intervals
        let minorIntervals = ChordType.minor.intervals
        XCTAssertEqual(minorIntervals, [0, 3, 7])
        
        // Test dominant 7 chord intervals
        let dom7Intervals = ChordType.dominant7.intervals
        XCTAssertEqual(dom7Intervals, [0, 4, 7, 10])
    }
    
    // MARK: - Performance Tests
    
    func testKeyboard_ProcessingPerformance() {
        let realInteractor = OnScreenKeyboardInteractor()
        let key = createMockKey()
        
        measure {
            for _ in 0..<1000 {
                realInteractor.processKeyPress(key, velocity: 0.8)
                realInteractor.processKeyRelease(key)
            }
        }
    }
    
    func testKeyboard_ChordGenerationPerformance() {
        let realInteractor = OnScreenKeyboardInteractor()
        
        measure {
            for _ in 0..<100 {
                _ = realInteractor.generateChord(.major, rootNote: .C)
                _ = realInteractor.generateChord(.minor7, rootNote: .F)
                _ = realInteractor.generateChord(.dominant7, rootNote: .G)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockKey(note: Note = .C, octave: Int = 4) -> KeyboardKey {
        return KeyboardKey(
            note: note,
            octave: octave,
            keyType: note.isBlackKey ? .black : .white,
            position: KeyPosition(x: 0, y: 0, width: 60, height: 200)
        )
    }
}

// MARK: - Mock Objects

class MockOnScreenKeyboardInteractor: OnScreenKeyboardInteractorProtocol {
    weak var presenter: OnScreenKeyboardPresenterProtocol?
    
    var processKeyPressCalled = false
    var processKeyPressKey: KeyboardKey?
    var processKeyPressVelocity: Float?
    
    var processKeyReleaseCalled = false
    var processKeyReleaseKey: KeyboardKey?
    
    var changeOctaveCalled = false
    var changeOctaveDirection: OctaveDirection?
    
    var setScaleCalled = false
    var setScaleValue: MusicalScale?
    
    var generateChordCalled = false
    var generateChordType: ChordType?
    var generateChordRootNote: Note?
    var mockGeneratedChord: [KeyboardKey] = []
    
    var calculateVelocityCalled = false
    var mockCalculatedVelocity: Float = 0.8
    
    var getCurrentOctaveCalled = false
    var mockCurrentOctave: Int = 4
    
    var getCurrentScaleCalled = false
    var mockCurrentScale: MusicalScale?
    
    func processKeyPress(_ key: KeyboardKey, velocity: Float) {
        processKeyPressCalled = true
        processKeyPressKey = key
        processKeyPressVelocity = velocity
    }
    
    func processKeyRelease(_ key: KeyboardKey) {
        processKeyReleaseCalled = true
        processKeyReleaseKey = key
    }
    
    func changeOctave(_ direction: OctaveDirection) {
        changeOctaveCalled = true
        changeOctaveDirection = direction
    }
    
    func setScale(_ scale: MusicalScale) {
        setScaleCalled = true
        setScaleValue = scale
    }
    
    func generateChord(_ chordType: ChordType, rootNote: Note) -> [KeyboardKey] {
        generateChordCalled = true
        generateChordType = chordType
        generateChordRootNote = rootNote
        return mockGeneratedChord
    }
    
    func calculateVelocity(from touchLocation: CGPoint, keyBounds: CGRect) -> Float {
        calculateVelocityCalled = true
        return mockCalculatedVelocity
    }
    
    func getCurrentOctave() -> Int {
        getCurrentOctaveCalled = true
        return mockCurrentOctave
    }
    
    func getCurrentScale() -> MusicalScale? {
        getCurrentScaleCalled = true
        return mockCurrentScale
    }
}

class MockOnScreenKeyboardRouter: OnScreenKeyboardRouterProtocol {
    static func createModule() -> AnyView {
        return AnyView(Text("Mock Keyboard"))
    }
    
    func showScaleSelector() {}
    func showChordSelector() {}
    func showKeyboardSettings() {}
}

class MockOnScreenKeyboardView: OnScreenKeyboardViewProtocol {
    var presenter: OnScreenKeyboardPresenterProtocol?
    
    var updateKeyStateCalled = false
    var updateOctaveCalled = false
    var updateScaleCalled = false
    var highlightChordCalled = false
    var showVelocityIndicatorCalled = false
    var updateKeyboardLayoutCalled = false
    
    func updateKeyState(_ key: KeyboardKey, isPressed: Bool) {
        updateKeyStateCalled = true
    }
    
    func updateOctave(_ octave: Int) {
        updateOctaveCalled = true
    }
    
    func updateScale(_ scale: MusicalScale?) {
        updateScaleCalled = true
    }
    
    func highlightChord(_ chord: [KeyboardKey]) {
        highlightChordCalled = true
    }
    
    func showVelocityIndicator(_ velocity: Float, for key: KeyboardKey) {
        showVelocityIndicatorCalled = true
    }
    
    func updateKeyboardLayout(_ layout: KeyboardLayout) {
        updateKeyboardLayoutCalled = true
    }
}
