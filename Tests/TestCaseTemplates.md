# Test Case Templates

This document provides standardized templates for creating test cases across all DigitonePad modules.

## Unit Test Template

```swift
// MARK: - [Feature Name] Tests

func test[FeatureName][Scenario]() throws {
    // GIVEN: Setup test conditions
    let testObject = createTestObject()
    let expectedValue = "expected_result"
    
    // WHEN: Execute the action being tested
    let result = try testObject.performAction()
    
    // THEN: Verify the results
    XCTAssertEqual(result, expectedValue)
    XCTAssertTrue(testObject.isInExpectedState)
}

func test[FeatureName][ErrorScenario]() throws {
    // GIVEN: Setup error conditions
    let testObject = createTestObjectWithErrorCondition()
    
    // WHEN & THEN: Verify error is thrown
    XCTAssertThrowsError(try testObject.performAction()) { error in
        XCTAssertTrue(error is ExpectedErrorType)
        if case ExpectedErrorType.specificError(let message) = error {
            XCTAssertEqual(message, "expected error message")
        }
    }
}
```

## Performance Test Template

```swift
func test[FeatureName]Performance() throws {
    // GIVEN: Setup performance test conditions
    let testObject = createTestObject()
    let iterations = 1000
    
    // WHEN & THEN: Measure performance
    measure {
        for _ in 0..<iterations {
            _ = testObject.performAction()
        }
    }
    
    // Additional performance assertions
    let (result, time) = TestUtilities.measureExecutionTime {
        return testObject.performAction()
    }
    
    XCTAssertLessThan(time, 0.001, "Operation should complete within 1ms")
}
```

## Integration Test Template

```swift
func test[Module1][Module2]Integration() throws {
    // GIVEN: Setup multiple modules
    let module1 = createModule1()
    let module2 = createModule2()
    
    try module1.initialize()
    try module2.initialize()
    
    // WHEN: Perform cross-module operation
    let data = module1.generateData()
    let result = try module2.processData(data)
    
    // THEN: Verify integration works correctly
    XCTAssertNotNil(result)
    XCTAssertEqual(module1.state, .completed)
    XCTAssertEqual(module2.state, .processed)
}
```

## Mock Test Template

```swift
func test[FeatureName]WithMock() throws {
    // GIVEN: Setup with mock dependencies
    let mockDependency = MockDependency()
    let testObject = TestObject(dependency: mockDependency)
    
    mockDependency.setShouldReturnValue("mock_result")
    
    // WHEN: Execute action
    let result = try testObject.performAction()
    
    // THEN: Verify mock interactions
    XCTAssertEqual(result, "mock_result")
    XCTAssertEqual(mockDependency.callCount, 1)
    XCTAssertTrue(mockDependency.wasCalledWith("expected_parameter"))
}
```

## Async Test Template

```swift
func test[FeatureName]Async() async throws {
    // GIVEN: Setup async test conditions
    let testObject = createAsyncTestObject()
    let expectation = XCTestExpectation(description: "Async operation completes")
    
    // WHEN: Execute async operation
    let result = try await testObject.performAsyncAction()
    
    // THEN: Verify async results
    XCTAssertNotNil(result)
    expectation.fulfill()
    
    await fulfillment(of: [expectation], timeout: 5.0)
}
```

## Audio Processing Test Template

```swift
func test[AudioFeature]Processing() throws {
    // GIVEN: Setup audio test conditions
    let inputBuffer = TestUtilities.generateTestAudioBuffer(
        frameCount: 512,
        channelCount: 2,
        sampleRate: 44100
    )
    let processor = createAudioProcessor()
    
    // WHEN: Process audio
    let outputBuffer = processor.process(inputBuffer)
    
    // THEN: Verify audio processing
    TestUtilities.assertValidAudioBuffer(outputBuffer)
    XCTAssertEqual(outputBuffer.frameCount, inputBuffer.frameCount)
    XCTAssertEqual(outputBuffer.channelCount, inputBuffer.channelCount)
    
    // Verify audio quality
    let snr = calculateSignalToNoiseRatio(inputBuffer, outputBuffer)
    XCTAssertGreaterThan(snr, 60.0, "SNR should be > 60dB")
    
    // Cleanup
    TestUtilities.cleanupAudioBuffer(inputBuffer)
    TestUtilities.cleanupAudioBuffer(outputBuffer)
}
```

## UI Test Template

```swift
func test[UIComponent][Interaction]() throws {
    // GIVEN: Setup UI test conditions
    let view = createTestView()
    let inspector = try view.inspect()
    
    // WHEN: Perform UI interaction
    try inspector.button("Test Button").tap()
    
    // THEN: Verify UI state changes
    XCTAssertEqual(try inspector.text().string(), "Expected Text")
    XCTAssertTrue(try inspector.button("Test Button").isDisabled())
}
```

## Core Data Test Template

```swift
func test[Entity][Operation]() throws {
    // GIVEN: Setup Core Data test context
    let context = createTestContext()
    let entity = createTestEntity(in: context)
    
    // WHEN: Perform Core Data operation
    try context.save()
    
    // THEN: Verify data persistence
    let fetchRequest = NSFetchRequest<TestEntity>(entityName: "TestEntity")
    let results = try context.fetch(fetchRequest)
    
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results.first?.testProperty, "expected_value")
}
```

## VIPER Component Test Templates

### Interactor Test Template

```swift
func test[Interactor][BusinessLogic]() throws {
    // GIVEN: Setup interactor with mock dependencies
    let mockRepository = MockRepository()
    let mockPresenter = MockPresenter()
    let interactor = TestInteractor(
        repository: mockRepository,
        presenter: mockPresenter
    )
    
    // WHEN: Execute business logic
    try interactor.performBusinessLogic()
    
    // THEN: Verify business logic execution
    XCTAssertTrue(mockRepository.wasDataFetched)
    XCTAssertTrue(mockPresenter.wasResultPresented)
}
```

### Presenter Test Template

```swift
func test[Presenter][ViewModelCreation]() throws {
    // GIVEN: Setup presenter with mock view
    let mockView = MockView()
    let presenter = TestPresenter(view: mockView)
    
    // WHEN: Present data
    let testData = createTestData()
    presenter.presentData(testData)
    
    // THEN: Verify view model creation
    XCTAssertTrue(mockView.wasViewModelUpdated)
    XCTAssertEqual(mockView.lastViewModel?.title, "Expected Title")
}
```

### Router Test Template

```swift
func test[Router][Navigation]() throws {
    // GIVEN: Setup router with mock view controller
    let mockViewController = MockViewController()
    let router = TestRouter(viewController: mockViewController)
    
    // WHEN: Perform navigation
    router.navigateToDestination()
    
    // THEN: Verify navigation occurred
    XCTAssertTrue(mockViewController.wasNavigationPerformed)
    XCTAssertEqual(mockViewController.lastDestination, "ExpectedDestination")
}
```

## Test Data Generators

### Audio Test Data

```swift
func generateSineWave(frequency: Float, duration: Float, sampleRate: Float) -> AudioBuffer {
    let frameCount = Int(duration * sampleRate)
    let data = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
    
    for i in 0..<frameCount {
        let time = Float(i) / sampleRate
        data[i] = sin(2.0 * .pi * frequency * time)
    }
    
    return AudioBuffer(
        data: data,
        frameCount: frameCount,
        channelCount: 1,
        sampleRate: sampleRate
    )
}
```

### MIDI Test Data

```swift
func generateTestMIDISequence() -> [MIDIEvent] {
    return [
        MIDIEvent.noteOn(note: 60, velocity: 100, timestamp: 0.0),
        MIDIEvent.noteOff(note: 60, timestamp: 0.5),
        MIDIEvent.noteOn(note: 64, velocity: 80, timestamp: 1.0),
        MIDIEvent.noteOff(note: 64, timestamp: 1.5)
    ]
}
```

### Pattern Test Data

```swift
func generateTestPattern(length: Int = 16) -> Pattern {
    var steps = Array(repeating: false, count: length)
    // Create a basic kick pattern
    steps[0] = true
    steps[4] = true
    steps[8] = true
    steps[12] = true
    
    return Pattern(
        name: "Test Pattern",
        length: length,
        steps: steps
    )
}
```

## Test Assertions

### Custom Audio Assertions

```swift
func assertAudioBuffersEqual(_ buffer1: AudioBuffer, _ buffer2: AudioBuffer, tolerance: Float = 0.001) {
    XCTAssertEqual(buffer1.frameCount, buffer2.frameCount)
    XCTAssertEqual(buffer1.channelCount, buffer2.channelCount)
    XCTAssertEqual(buffer1.sampleRate, buffer2.sampleRate)
    
    for i in 0..<(buffer1.frameCount * buffer1.channelCount) {
        XCTAssertEqual(buffer1.data[i], buffer2.data[i], accuracy: tolerance)
    }
}

func assertAudioSilence(_ buffer: AudioBuffer, threshold: Float = 0.001) {
    for i in 0..<(buffer.frameCount * buffer.channelCount) {
        XCTAssertLessThan(abs(buffer.data[i]), threshold, "Buffer should be silent")
    }
}
```

### Custom MIDI Assertions

```swift
func assertMIDIEventsEqual(_ event1: MIDIEvent, _ event2: MIDIEvent) {
    XCTAssertEqual(event1.type, event2.type)
    XCTAssertEqual(event1.timestamp, event2.timestamp, accuracy: 0.001)
    
    switch (event1, event2) {
    case (.noteOn(let note1, let vel1, _), .noteOn(let note2, let vel2, _)):
        XCTAssertEqual(note1, note2)
        XCTAssertEqual(vel1, vel2)
    case (.noteOff(let note1, _), .noteOff(let note2, _)):
        XCTAssertEqual(note1, note2)
    default:
        XCTFail("MIDI event types don't match")
    }
}
```

## Test Cleanup Templates

```swift
override func tearDown() {
    // Audio cleanup
    if let audioBuffer = testAudioBuffer {
        TestUtilities.cleanupAudioBuffer(audioBuffer)
        testAudioBuffer = nil
    }
    
    // Core Data cleanup
    if let context = testContext {
        context.reset()
        testContext = nil
    }
    
    // Mock cleanup
    mockObjects.forEach { $0.reset() }
    mockObjects.removeAll()
    
    super.tearDown()
}
```
