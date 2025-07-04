import XCTest
@testable import UIComponents
@testable import MachineProtocols

// Import test utilities

/// Tests for Key Combo System core logic
final class KeyComboTests: DigitonePadTestCase {
    
    var keyComboRegistry: KeyComboRegistry!
    var keyComboDetector: KeyComboDetector!
    var keyComboInteractor: KeyComboInteractor!
    var mockPresenter: MockKeyComboPresenter!
    var mockActionExecutor: MockKeyComboActionExecutor!
    var mockContextProvider: MockKeyComboContextProvider!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        keyComboRegistry = KeyComboRegistry()
        mockPresenter = MockKeyComboPresenter()
        mockActionExecutor = MockKeyComboActionExecutor()
        mockContextProvider = MockKeyComboContextProvider()
        
        keyComboInteractor = KeyComboInteractor(
            registry: keyComboRegistry,
            contextProvider: mockContextProvider,
            actionExecutor: mockActionExecutor,
            presenter: mockPresenter
        )
        
        keyComboDetector = KeyComboDetector()
        keyComboDetector.interactor = keyComboInteractor
    }
    
    override func tearDownWithError() throws {
        keyComboRegistry = nil
        keyComboDetector = nil
        keyComboInteractor = nil
        mockPresenter = nil
        mockActionExecutor = nil
        mockContextProvider = nil
        try super.tearDownWithError()
    }
    
    // MARK: - KeyCombo Entity Tests
    
    func testKeyComboCreation() throws {
        // GIVEN: Valid key combo parameters
        let combo = KeyCombo(
            id: "func_pad1",
            modifier: .func,
            key: .pad(1),
            context: KeyComboContext(mode: .pattern, subMode: nil, conditions: [:]),
            action: KeyComboAction(type: .pattern, parameters: ["pattern": "1"], target: nil),
            description: "Select pattern 1",
            shortDescription: "Pattern 1",
            isEnabled: true,
            priority: 5,
            category: .pattern
        )
        
        // THEN: Key combo should be created with correct properties
        XCTAssertEqual(combo.id, "func_pad1")
        XCTAssertEqual(combo.modifier, .func)
        XCTAssertEqual(combo.key, .pad(1))
        XCTAssertEqual(combo.description, "Select pattern 1")
        XCTAssertTrue(combo.isEnabled)
        XCTAssertEqual(combo.priority, 5)
    }
    
    func testKeyModifierSymbols() throws {
        // GIVEN: Key modifiers
        
        // THEN: Should have correct symbols
        XCTAssertEqual(KeyModifier.func.symbol, "⚙️")
        XCTAssertEqual(KeyModifier.shift.symbol, "⇧")
        XCTAssertEqual(KeyModifier.alt.symbol, "⌥")
    }
    
    func testKeySymbols() throws {
        // GIVEN: Various keys
        
        // THEN: Should have correct symbols
        XCTAssertEqual(Key.pad(1).symbol, "P1")
        XCTAssertEqual(Key.play.symbol, "▶️")
        XCTAssertEqual(Key.stop.symbol, "⏹️")
        XCTAssertEqual(Key.record.symbol, "⏺️")
        XCTAssertEqual(Key.tempo.symbol, "🎵")
    }
    
    // MARK: - KeyComboRegistry Tests
    
    func testRegisterKeyCombo() throws {
        // GIVEN: A key combo
        let combo = createTestKeyCombo(id: "test_combo")
        
        // WHEN: Registering the combo
        keyComboRegistry.register(combo)
        
        // THEN: Combo should be registered
        let registeredCombo = keyComboRegistry.getCombo(id: "test_combo")
        XCTAssertNotNil(registeredCombo)
        XCTAssertEqual(registeredCombo?.id, "test_combo")
    }
    
    func testUnregisterKeyCombo() throws {
        // GIVEN: A registered combo
        let combo = createTestKeyCombo(id: "test_combo")
        keyComboRegistry.register(combo)
        
        // WHEN: Unregistering the combo
        keyComboRegistry.unregister(id: "test_combo")
        
        // THEN: Combo should be removed
        let registeredCombo = keyComboRegistry.getCombo(id: "test_combo")
        XCTAssertNil(registeredCombo)
    }
    
    func testGetCombosForContext() throws {
        // GIVEN: Multiple combos with different contexts
        let patternCombo = createTestKeyCombo(id: "pattern_combo", context: .pattern)
        let kitCombo = createTestKeyCombo(id: "kit_combo", context: .kit)
        
        keyComboRegistry.register(patternCombo)
        keyComboRegistry.register(kitCombo)
        
        // WHEN: Getting combos for pattern context
        let patternContext = KeyComboContext(mode: .pattern, subMode: nil, conditions: [:])
        let patternCombos = keyComboRegistry.getCombos(for: patternContext)
        
        // THEN: Should only return pattern combos
        XCTAssertEqual(patternCombos.count, 1)
        XCTAssertEqual(patternCombos.first?.id, "pattern_combo")
    }
    
    func testFindComboByKeys() throws {
        // GIVEN: A registered combo
        let combo = createTestKeyCombo(id: "func_pad1", modifier: .func, key: .pad(1))
        keyComboRegistry.register(combo)
        
        // WHEN: Finding combo by keys
        let foundCombo = keyComboRegistry.findCombo(modifier: .func, key: .pad(1))
        
        // THEN: Should find the correct combo
        XCTAssertNotNil(foundCombo)
        XCTAssertEqual(foundCombo?.id, "func_pad1")
    }
    
    // MARK: - KeyComboDetector Tests
    
    func testModifierKeyPress() throws {
        // GIVEN: Key combo detector
        
        // WHEN: Pressing FUNC key
        keyComboDetector.handleKeyPress(.func)
        
        // THEN: Should activate detection mode
        XCTAssertTrue(keyComboDetector.isDetectionActive)
        XCTAssertTrue(keyComboDetector.activeModifiers.contains(.func))
    }
    
    func testModifierKeyRelease() throws {
        // GIVEN: Active modifier
        keyComboDetector.handleKeyPress(.func)
        
        // WHEN: Releasing FUNC key
        keyComboDetector.handleKeyRelease(.func)
        
        // THEN: Should deactivate detection mode
        XCTAssertFalse(keyComboDetector.isDetectionActive)
        XCTAssertFalse(keyComboDetector.activeModifiers.contains(.func))
    }
    
    func testComboDetection() throws {
        // GIVEN: Registered combo and active modifier
        let combo = createTestKeyCombo(id: "func_pad1", modifier: .func, key: .pad(1))
        keyComboRegistry.register(combo)
        keyComboDetector.handleKeyPress(.func)
        
        // WHEN: Pressing target key
        keyComboDetector.handleKeyPress(.pad(1))
        
        // THEN: Should execute combo
        XCTAssertTrue(mockActionExecutor.wasExecuteCalled)
        XCTAssertEqual(mockActionExecutor.lastExecutedCombo?.id, "func_pad1")
    }
    
    func testInvalidComboDetection() throws {
        // GIVEN: No registered combo for keys
        keyComboDetector.handleKeyPress(.func)
        
        // WHEN: Pressing unregistered key
        keyComboDetector.handleKeyPress(.pad(1))
        
        // THEN: Should not execute any combo
        XCTAssertFalse(mockActionExecutor.wasExecuteCalled)
    }
    
    func testKeyDebouncing() throws {
        // GIVEN: Rapid key presses
        let combo = createTestKeyCombo(id: "func_pad1", modifier: .func, key: .pad(1))
        keyComboRegistry.register(combo)
        keyComboDetector.handleKeyPress(.func)
        
        // WHEN: Rapidly pressing the same key
        keyComboDetector.handleKeyPress(.pad(1))
        keyComboDetector.handleKeyPress(.pad(1)) // Should be debounced
        
        // THEN: Should only execute once
        XCTAssertEqual(mockActionExecutor.executeCallCount, 1)
    }
    
    // MARK: - KeyComboInteractor Tests
    
    func testRegisterComboThroughInteractor() throws {
        // GIVEN: A key combo
        let combo = createTestKeyCombo(id: "test_combo")
        
        // WHEN: Registering through interactor
        keyComboInteractor.registerKeyCombo(combo)
        
        // THEN: Should be registered in registry
        let registeredCombo = keyComboRegistry.getCombo(id: "test_combo")
        XCTAssertNotNil(registeredCombo)
    }
    
    func testDetectKeyCombo() throws {
        // GIVEN: Registered combo
        let combo = createTestKeyCombo(id: "func_pad1", modifier: .func, key: .pad(1))
        keyComboInteractor.registerKeyCombo(combo)
        
        // WHEN: Detecting combo
        let detectedCombo = keyComboInteractor.detectKeyCombo(modifier: .func, key: .pad(1))
        
        // THEN: Should return the correct combo
        XCTAssertNotNil(detectedCombo)
        XCTAssertEqual(detectedCombo?.id, "func_pad1")
    }
    
    func testExecuteKeyCombo() throws {
        // GIVEN: Valid combo
        let combo = createTestKeyCombo(id: "test_combo")
        
        // WHEN: Executing combo
        XCTAssertNoThrow(try keyComboInteractor.executeKeyCombo(combo))
        
        // THEN: Should execute action and notify presenter
        XCTAssertTrue(mockActionExecutor.wasExecuteCalled)
        XCTAssertTrue(mockPresenter.wasComboExecutedCalled)
    }
    
    func testExecuteDisabledCombo() throws {
        // GIVEN: Disabled combo
        var combo = createTestKeyCombo(id: "disabled_combo")
        combo.isEnabled = false
        
        // WHEN & THEN: Executing should throw error
        XCTAssertThrowsError(try keyComboInteractor.executeKeyCombo(combo)) { error in
            XCTAssertTrue(error is KeyComboError)
            if case KeyComboError.comboDisabled = error {
                // Expected error
            } else {
                XCTFail("Expected comboDisabled error")
            }
        }
    }
    
    func testGetAvailableCombos() throws {
        // GIVEN: Multiple combos with different contexts
        let patternCombo = createTestKeyCombo(id: "pattern_combo", context: .pattern)
        let kitCombo = createTestKeyCombo(id: "kit_combo", context: .kit)
        
        keyComboInteractor.registerKeyCombo(patternCombo)
        keyComboInteractor.registerKeyCombo(kitCombo)
        
        // WHEN: Getting available combos for pattern context
        let patternContext = KeyComboContext(mode: .pattern, subMode: nil, conditions: [:])
        let availableCombos = keyComboInteractor.getAvailableCombos(for: patternContext)
        
        // THEN: Should return only pattern combos
        XCTAssertEqual(availableCombos.count, 1)
        XCTAssertEqual(availableCombos.first?.id, "pattern_combo")
    }
    
    func testUpdateContext() throws {
        // GIVEN: New context
        let newContext = KeyComboContext(mode: .kit, subMode: nil, conditions: [:])
        
        // WHEN: Updating context
        keyComboInteractor.updateContext(newContext)
        
        // THEN: Should notify presenter of context change
        XCTAssertTrue(mockPresenter.wasContextChangedCalled)
        XCTAssertEqual(mockPresenter.lastContext?.mode, .kit)
    }
    
    // MARK: - Performance Tests
    
    func testComboDetectionPerformance() throws {
        // GIVEN: Many registered combos
        for i in 1...100 {
            let combo = createTestKeyCombo(id: "combo_\(i)", key: .pad(i % 16 + 1))
            keyComboInteractor.registerKeyCombo(combo)
        }
        
        // WHEN & THEN: Detection should be performant
        measure {
            for i in 1...100 {
                _ = keyComboInteractor.detectKeyCombo(modifier: .func, key: .pad(i % 16 + 1))
            }
        }
    }
    
    func testRegistryPerformance() throws {
        measure {
            for i in 1...1000 {
                let combo = createTestKeyCombo(id: "combo_\(i)")
                keyComboRegistry.register(combo)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestKeyCombo(
        id: String,
        modifier: KeyModifier = .func,
        key: Key = .pad(1),
        context: KeyComboContext.AppMode = .pattern
    ) -> KeyCombo {
        return KeyCombo(
            id: id,
            modifier: modifier,
            key: key,
            context: KeyComboContext(mode: context, subMode: nil, conditions: [:]),
            action: KeyComboAction(type: .pattern, parameters: [:], target: nil),
            description: "Test combo",
            shortDescription: "Test",
            isEnabled: true,
            priority: 5,
            category: .pattern
        )
    }
}

// MARK: - Mock Objects

class MockKeyComboPresenter: KeyComboPresenterProtocol {
    var wasComboExecutedCalled = false
    var wasComboFailedCalled = false
    var wasContextChangedCalled = false
    var wasAvailableCombosCalled = false
    
    var lastExecutedCombo: KeyCombo?
    var lastFailedCombo: KeyCombo?
    var lastContext: KeyComboContext?
    var lastError: Error?
    
    func presentAvailableCombos(_ combos: [KeyCombo]) {
        wasAvailableCombosCalled = true
    }
    
    func presentComboExecuted(_ combo: KeyCombo, result: KeyComboExecutionResult) {
        wasComboExecutedCalled = true
        lastExecutedCombo = combo
    }
    
    func presentComboFailed(_ combo: KeyCombo, error: KeyComboError) {
        wasComboFailedCalled = true
        lastFailedCombo = combo
        lastError = error
    }
    
    func presentComboHelp(_ combos: [KeyCombo]) {}
    
    func presentVisualFeedback(for combo: KeyCombo) {}
    
    func presentContextChanged(_ context: KeyComboContext) {
        wasContextChangedCalled = true
        lastContext = context
    }
}

class MockKeyComboActionExecutor: KeyComboActionExecutor {
    var wasExecuteCalled = false
    var executeCallCount = 0
    var lastExecutedCombo: KeyCombo?
    
    override func execute(_ combo: KeyCombo) throws -> KeyComboExecutionResult {
        wasExecuteCalled = true
        executeCallCount += 1
        lastExecutedCombo = combo
        return KeyComboExecutionResult(success: true, message: "Mock execution")
    }
}

class MockKeyComboContextProvider: KeyComboContextProvider {
    var currentContext = KeyComboContext(mode: .pattern, subMode: nil, conditions: [:])
    
    override func getCurrentContext() -> KeyComboContext {
        return currentContext
    }
    
    func setContext(_ context: KeyComboContext) {
        currentContext = context
    }
}
