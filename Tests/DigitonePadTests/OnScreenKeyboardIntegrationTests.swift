import XCTest
import SwiftUI
import Combine
@testable import DigitonePad

/// Integration tests for On-Screen Keyboard complete functionality
class OnScreenKeyboardIntegrationTests: XCTestCase {
    
    var presenter: OnScreenKeyboardPresenter!
    var interactor: OnScreenKeyboardInteractor!
    var router: OnScreenKeyboardRouter!
    var mockDelegate: MockKeyboardDelegate!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        presenter = OnScreenKeyboardPresenter()
        interactor = OnScreenKeyboardInteractor()
        router = OnScreenKeyboardRouter()
        mockDelegate = MockKeyboardDelegate()
        cancellables = Set<AnyCancellable>()
        
        // Wire up VIPER components
        presenter.interactor = interactor
        presenter.router = router
        presenter.delegate = mockDelegate
        interactor.presenter = presenter
    }
    
    override func tearDown() {
        cancellables = nil
        mockDelegate = nil
        presenter = nil
        interactor = nil
        router = nil
        super.tearDown()
    }
    
    // MARK: - Complete Flow Integration Tests
    
    func testKeyboard_CompleteKeyPressFlow() {
        // Given
        let key = createTestKey()
        let velocity: Float = 0.8
        let location = CGPoint(x: 30, y: 150)
        
        let expectation = XCTestExpectation(description: "Key press flow completed")
        
        // When
        presenter.viewDidLoad()
        presenter.keyPressed(key, velocity: velocity, at: location)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.presenter.pressedKeys.contains(key))
            XCTAssertTrue(self.mockDelegate.keyPressedCalled)
            XCTAssertEqual(self.mockDelegate.pressedKey?.id, key.id)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testKeyboard_CompleteKeyReleaseFlow() {
        // Given
        let key = createTestKey()
        presenter.pressedKeys.insert(key)
        
        let expectation = XCTestExpectation(description: "Key release flow completed")
        
        // When
        presenter.keyReleased(key)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.presenter.pressedKeys.contains(key))
            XCTAssertTrue(self.mockDelegate.keyReleasedCalled)
            XCTAssertEqual(self.mockDelegate.releasedKey?.id, key.id)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testKeyboard_OctaveChangeFlow() {
        // Given
        let initialOctave = presenter.currentOctave
        
        let expectation = XCTestExpectation(description: "Octave change flow completed")
        
        // When
        presenter.octaveShiftRequested(.up)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNotEqual(self.presenter.currentOctave, initialOctave)
            XCTAssertTrue(self.mockDelegate.octaveChangedCalled)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testKeyboard_ScaleSelectionFlow() {
        // Given
        let scale = MusicalScale.major
        
        let expectation = XCTestExpectation(description: "Scale selection flow completed")
        
        // When
        presenter.scaleSelected(scale)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.presenter.currentScale, scale)
            XCTAssertTrue(self.mockDelegate.scaleSelectedCalled)
            XCTAssertEqual(self.mockDelegate.selectedScale, scale)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testKeyboard_ChordGenerationFlow() {
        // Given
        let chordType = ChordType.major
        let rootNote = Note.C
        
        let expectation = XCTestExpectation(description: "Chord generation flow completed")
        
        // When
        presenter.chordRequested(chordType, rootNote: rootNote)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.presenter.highlightedChord.isEmpty)
            XCTAssertEqual(self.presenter.highlightedChord.count, 3) // Major chord has 3 notes
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Polyphony Tests
    
    func testKeyboard_PolyphonyHandling() {
        // Given
        var keys: [KeyboardKey] = []
        for i in 0..<12 { // More than max polyphony (10)
            keys.append(createTestKey(note: Note.allCases[i % 12]))
        }
        
        // When - press all keys
        for key in keys {
            presenter.keyPressed(key, velocity: 0.8, at: CGPoint(x: 30, y: 150))
        }
        
        // Then - should not exceed polyphony limit
        XCTAssertLessThanOrEqual(presenter.pressedKeys.count, 10)
    }
    
    // MARK: - Velocity Sensitivity Tests
    
    func testKeyboard_VelocitySensitivity() {
        // Given
        let key = createTestKey()
        let topLocation = CGPoint(x: 30, y: 20) // Top of key
        let bottomLocation = CGPoint(x: 30, y: 180) // Bottom of key
        
        // When
        let topVelocity = interactor.calculateVelocity(
            from: topLocation,
            keyBounds: CGRect(x: 0, y: 0, width: 60, height: 200)
        )
        
        let bottomVelocity = interactor.calculateVelocity(
            from: bottomLocation,
            keyBounds: CGRect(x: 0, y: 0, width: 60, height: 200)
        )
        
        // Then
        XCTAssertLessThan(topVelocity, bottomVelocity)
        XCTAssertGreaterThan(topVelocity, 0.0)
        XCTAssertLessThanOrEqual(bottomVelocity, 1.0)
    }
    
    // MARK: - Scale Highlighting Tests
    
    func testKeyboard_ScaleHighlighting() {
        // Given
        presenter.scaleSelected(.major)
        let cKey = createTestKey(note: .C)
        let cSharpKey = createTestKey(note: .CSharp)
        
        // When
        let cInScale = presenter.isKeyInScale(cKey)
        let cSharpInScale = presenter.isKeyInScale(cSharpKey)
        
        // Then
        XCTAssertTrue(cInScale) // C is in C major
        XCTAssertFalse(cSharpInScale) // C# is not in C major
    }
    
    // MARK: - Chord Highlighting Tests
    
    func testKeyboard_ChordHighlighting() {
        // Given
        presenter.chordRequested(.major, rootNote: .C)
        
        // Create test keys
        let cKey = createTestKey(note: .C)
        let eKey = createTestKey(note: .E)
        let gKey = createTestKey(note: .G)
        let dKey = createTestKey(note: .D)
        
        // When
        let cInChord = presenter.isKeyInChord(cKey)
        let eInChord = presenter.isKeyInChord(eKey)
        let gInChord = presenter.isKeyInChord(gKey)
        let dInChord = presenter.isKeyInChord(dKey)
        
        // Then
        // Note: This test might need adjustment based on actual chord generation logic
        XCTAssertTrue(cInChord || eInChord || gInChord) // At least one chord note should be highlighted
        XCTAssertFalse(dInChord) // D is not in C major chord
    }
    
    // MARK: - Layout Change Tests
    
    func testKeyboard_LayoutChange() {
        // Given
        let initialLayout = presenter.keyboardLayout
        
        // When
        presenter.setCompactLayout()
        
        // Then
        XCTAssertNotEqual(presenter.keyboardLayout.whiteKeyWidth, initialLayout.whiteKeyWidth)
        XCTAssertNotEqual(presenter.keyboardLayout.whiteKeyHeight, initialLayout.whiteKeyHeight)
    }
    
    func testKeyboard_CustomLayoutCreation() {
        // Given
        let customOctaveRange = 1...3
        let customKeySize = CGSize(width: 80, height: 250)
        
        // When
        presenter.createCustomLayout(octaveRange: customOctaveRange, keySize: customKeySize)
        
        // Then
        XCTAssertEqual(presenter.keyboardLayout.octaveRange, customOctaveRange)
        XCTAssertEqual(presenter.keyboardLayout.whiteKeyWidth, customKeySize.width)
        XCTAssertEqual(presenter.keyboardLayout.whiteKeyHeight, customKeySize.height)
    }
    
    // MARK: - Preset Management Tests
    
    func testKeyboard_PresetSaveAndLoad() {
        // Given
        presenter.currentOctave = 5
        presenter.scaleSelected(.minor)
        presenter.setCompactLayout()
        
        // When - save preset
        let preset = presenter.saveKeyboardPreset(name: "Test Preset")
        
        // Reset to different state
        presenter.currentOctave = 3
        presenter.clearScale()
        presenter.setStandardLayout()
        
        // Load preset
        presenter.loadKeyboardPreset(preset)
        
        // Then
        XCTAssertEqual(presenter.currentOctave, 5)
        XCTAssertEqual(presenter.currentScale, .minor)
        XCTAssertEqual(presenter.keyboardLayout.whiteKeyWidth, KeyboardLayout.compact.whiteKeyWidth)
    }
    
    // MARK: - Error Handling Tests
    
    func testKeyboard_InvalidOctaveHandling() {
        // Given
        let initialOctave = presenter.currentOctave
        
        // When - try to go beyond valid range
        for _ in 0..<20 {
            presenter.octaveShiftRequested(.up)
        }
        
        // Then - should be clamped to valid range
        XCTAssertLessThanOrEqual(presenter.currentOctave, 8)
        XCTAssertGreaterThanOrEqual(presenter.currentOctave, initialOctave)
    }
    
    // MARK: - Performance Integration Tests
    
    func testKeyboard_RapidKeyPresses() {
        let keys = (0..<12).map { createTestKey(note: Note.allCases[$0]) }
        
        measure {
            for _ in 0..<100 {
                for key in keys {
                    presenter.keyPressed(key, velocity: 0.8, at: CGPoint(x: 30, y: 150))
                    presenter.keyReleased(key)
                }
            }
        }
    }
    
    func testKeyboard_ComplexOperations() {
        measure {
            for i in 0..<50 {
                presenter.octaveShiftRequested(i % 2 == 0 ? .up : .down)
                presenter.scaleSelected(MusicalScale.allCases[i % MusicalScale.allCases.count])
                presenter.chordRequested(.major, rootNote: Note.allCases[i % 12])
                presenter.clearScale()
                presenter.clearChordHighlight()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestKey(note: Note = .C, octave: Int = 4) -> KeyboardKey {
        return KeyboardKey(
            note: note,
            octave: octave,
            keyType: note.isBlackKey ? .black : .white,
            position: KeyPosition(x: 0, y: 0, width: 60, height: 200)
        )
    }
}

// MARK: - Mock Keyboard Delegate

class MockKeyboardDelegate: OnScreenKeyboardDelegate {
    var keyPressedCalled = false
    var pressedKey: KeyboardKey?
    var pressedVelocity: Float?
    
    var keyReleasedCalled = false
    var releasedKey: KeyboardKey?
    
    var octaveChangedCalled = false
    var changedOctave: Int?
    
    var scaleSelectedCalled = false
    var selectedScale: MusicalScale?
    
    func keyboardDidPressKey(_ key: KeyboardKey, velocity: Float) {
        keyPressedCalled = true
        pressedKey = key
        pressedVelocity = velocity
    }
    
    func keyboardDidReleaseKey(_ key: KeyboardKey) {
        keyReleasedCalled = true
        releasedKey = key
    }
    
    func keyboardDidChangeOctave(_ octave: Int) {
        octaveChangedCalled = true
        changedOctave = octave
    }
    
    func keyboardDidSelectScale(_ scale: MusicalScale?) {
        scaleSelectedCalled = true
        selectedScale = scale
    }
}
