import XCTest
@testable import AudioEngine
@testable import MachineProtocols

// Import test utilities and mocks
import TestUtilities
import MockObjects

/// Tests for Audio Engine business logic (Interactor layer)
final class AudioEngineInteractorTests: AudioTestCase {
    
    var audioEngineInteractor: AudioEngineInteractor!
    var mockAudioEngine: MockAudioEngine!
    var mockPresenter: MockAudioEnginePresenter!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        mockAudioEngine = MockAudioEngine()
        mockPresenter = MockAudioEnginePresenter()
        audioEngineInteractor = AudioEngineInteractor(
            audioEngine: mockAudioEngine,
            presenter: mockPresenter
        )
    }
    
    override func tearDownWithError() throws {
        audioEngineInteractor = nil
        mockAudioEngine = nil
        mockPresenter = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Audio Engine Initialization Tests
    
    func testInitializeAudioEngineSuccess() throws {
        // GIVEN: Valid audio configuration
        let config = AudioEngineConfiguration(
            sampleRate: 44100,
            bufferSize: 512,
            channelCount: 2
        )
        
        // WHEN: Initializing audio engine
        try audioEngineInteractor.initializeAudioEngine(with: config)
        
        // THEN: Audio engine should be initialized and presenter notified
        XCTAssertTrue(mockAudioEngine.isInitialized)
        XCTAssertEqual(mockAudioEngine.sampleRate, 44100)
        XCTAssertEqual(mockAudioEngine.bufferSize, 512)
        XCTAssertEqual(mockAudioEngine.channelCount, 2)
        
        XCTAssertTrue(mockPresenter.wasAudioEngineInitializedCalled)
    }
    
    func testInitializeAudioEngineFailure() throws {
        // GIVEN: Audio engine configured to fail
        mockAudioEngine.setShouldFailOperations(true)
        
        let config = AudioEngineConfiguration(
            sampleRate: 44100,
            bufferSize: 512,
            channelCount: 2
        )
        
        // WHEN & THEN: Initialization should fail and error should be presented
        XCTAssertThrowsError(try audioEngineInteractor.initializeAudioEngine(with: config))
        XCTAssertTrue(mockPresenter.wasErrorPresentedCalled)
    }
    
    func testInitializeWithInvalidConfiguration() throws {
        // GIVEN: Invalid configuration
        let config = AudioEngineConfiguration(
            sampleRate: 0, // Invalid
            bufferSize: 512,
            channelCount: 2
        )
        
        // WHEN & THEN: Should validate configuration and fail
        XCTAssertThrowsError(try audioEngineInteractor.initializeAudioEngine(with: config)) { error in
            XCTAssertTrue(error is AudioEngineInteractorError)
        }
    }
    
    // MARK: - Audio Engine Lifecycle Tests
    
    func testStartAudioEngineSuccess() throws {
        // GIVEN: Initialized audio engine
        let config = AudioEngineConfiguration(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try mockAudioEngine.initialize(sampleRate: config.sampleRate, bufferSize: config.bufferSize, channelCount: config.channelCount)
        
        // WHEN: Starting audio engine
        try audioEngineInteractor.startAudioEngine()
        
        // THEN: Audio engine should be running
        XCTAssertTrue(mockAudioEngine.isRunning)
        XCTAssertTrue(mockPresenter.wasAudioEngineStartedCalled)
    }
    
    func testStartAudioEngineNotInitialized() throws {
        // GIVEN: Uninitialized audio engine
        
        // WHEN & THEN: Starting should fail
        XCTAssertThrowsError(try audioEngineInteractor.startAudioEngine())
        XCTAssertTrue(mockPresenter.wasErrorPresentedCalled)
    }
    
    func testStopAudioEngineSuccess() throws {
        // GIVEN: Running audio engine
        let config = AudioEngineConfiguration(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try mockAudioEngine.initialize(sampleRate: config.sampleRate, bufferSize: config.bufferSize, channelCount: config.channelCount)
        try mockAudioEngine.start()
        
        // WHEN: Stopping audio engine
        try audioEngineInteractor.stopAudioEngine()
        
        // THEN: Audio engine should be stopped
        XCTAssertFalse(mockAudioEngine.isRunning)
        XCTAssertTrue(mockPresenter.wasAudioEngineStoppedCalled)
    }
    
    func testSuspendResumeAudioEngine() throws {
        // GIVEN: Running audio engine
        let config = AudioEngineConfiguration(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try mockAudioEngine.initialize(sampleRate: config.sampleRate, bufferSize: config.bufferSize, channelCount: config.channelCount)
        try mockAudioEngine.start()
        
        // WHEN: Suspending audio engine
        try audioEngineInteractor.suspendAudioEngine()
        
        // THEN: Audio engine should be suspended
        XCTAssertFalse(mockAudioEngine.isRunning)
        XCTAssertTrue(mockPresenter.wasAudioEngineSuspendedCalled)
        
        // WHEN: Resuming audio engine
        try audioEngineInteractor.resumeAudioEngine()
        
        // THEN: Audio engine should be running again
        XCTAssertTrue(mockAudioEngine.isRunning)
        XCTAssertTrue(mockPresenter.wasAudioEngineResumedCalled)
    }
    
    // MARK: - Audio Processing Tests
    
    func testProcessAudioBuffer() throws {
        // GIVEN: Initialized and running audio engine
        let config = AudioEngineConfiguration(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try mockAudioEngine.initialize(sampleRate: config.sampleRate, bufferSize: config.bufferSize, channelCount: config.channelCount)
        try mockAudioEngine.start()
        
        let inputBuffer = TestUtilities.generateTestAudioBuffer()
        
        // WHEN: Processing audio buffer
        let outputBuffer = try audioEngineInteractor.processAudioBuffer(inputBuffer)
        
        // THEN: Output buffer should be valid
        TestUtilities.assertValidAudioBuffer(outputBuffer)
        XCTAssertEqual(outputBuffer.frameCount, inputBuffer.frameCount)
        XCTAssertEqual(outputBuffer.channelCount, inputBuffer.channelCount)
        
        TestUtilities.cleanupAudioBuffer(inputBuffer)
        TestUtilities.cleanupAudioBuffer(outputBuffer)
    }
    
    func testProcessAudioBufferEngineNotRunning() throws {
        // GIVEN: Audio engine not running
        let inputBuffer = TestUtilities.generateTestAudioBuffer()
        
        // WHEN & THEN: Processing should fail
        XCTAssertThrowsError(try audioEngineInteractor.processAudioBuffer(inputBuffer))
        
        TestUtilities.cleanupAudioBuffer(inputBuffer)
    }
    
    // MARK: - Performance Monitoring Tests
    
    func testGetPerformanceMetrics() throws {
        // GIVEN: Running audio engine
        let config = AudioEngineConfiguration(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try mockAudioEngine.initialize(sampleRate: config.sampleRate, bufferSize: config.bufferSize, channelCount: config.channelCount)
        try mockAudioEngine.start()
        
        // WHEN: Getting performance metrics
        let metrics = audioEngineInteractor.getPerformanceMetrics()
        
        // THEN: Metrics should be valid
        XCTAssertGreaterThanOrEqual(metrics.cpuUsage, 0.0)
        XCTAssertLessThanOrEqual(metrics.cpuUsage, 1.0)
        XCTAssertGreaterThanOrEqual(metrics.latency, 0.0)
        XCTAssertGreaterThanOrEqual(metrics.memoryUsage, 0.0)
        
        XCTAssertTrue(mockPresenter.wasPerformanceMetricsUpdatedCalled)
    }
    
    func testPerformanceThresholdMonitoring() throws {
        // GIVEN: Audio engine with high CPU usage
        let config = AudioEngineConfiguration(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try mockAudioEngine.initialize(sampleRate: config.sampleRate, bufferSize: config.bufferSize, channelCount: config.channelCount)
        try mockAudioEngine.start()
        
        mockAudioEngine.setSimulatedCPUUsage(0.8) // 80% CPU usage
        
        // WHEN: Monitoring performance
        audioEngineInteractor.monitorPerformance()
        
        // THEN: High CPU usage warning should be presented
        XCTAssertTrue(mockPresenter.wasPerformanceWarningPresentedCalled)
    }
    
    // MARK: - Audio Node Management Tests
    
    func testConnectAudioNodes() throws {
        // GIVEN: Audio nodes
        let sourceNode = MockAudioNode(name: "Source")
        let destinationNode = MockAudioNode(name: "Destination")
        
        // WHEN: Connecting nodes
        try audioEngineInteractor.connectAudioNodes(source: sourceNode, destination: destinationNode)
        
        // THEN: Nodes should be connected
        let connectedNodes = mockAudioEngine.getConnectedNodes()
        XCTAssertEqual(connectedNodes.count, 2)
        XCTAssertTrue(mockPresenter.wasAudioNodesConnectedCalled)
    }
    
    func testDisconnectAudioNode() throws {
        // GIVEN: Connected audio nodes
        let sourceNode = MockAudioNode(name: "Source")
        let destinationNode = MockAudioNode(name: "Destination")
        try mockAudioEngine.connectNode(sourceNode, to: destinationNode)
        
        // WHEN: Disconnecting node
        try audioEngineInteractor.disconnectAudioNode(sourceNode)
        
        // THEN: Node should be disconnected
        let connectedNodes = mockAudioEngine.getConnectedNodes()
        XCTAssertEqual(connectedNodes.count, 1) // Only destination remains
        XCTAssertTrue(mockPresenter.wasAudioNodeDisconnectedCalled)
    }
    
    // MARK: - Configuration Validation Tests
    
    func testValidateAudioConfiguration() throws {
        // Test valid configurations
        let validConfig1 = AudioEngineConfiguration(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        XCTAssertNoThrow(try audioEngineInteractor.validateConfiguration(validConfig1))
        
        let validConfig2 = AudioEngineConfiguration(sampleRate: 48000, bufferSize: 256, channelCount: 1)
        XCTAssertNoThrow(try audioEngineInteractor.validateConfiguration(validConfig2))
        
        // Test invalid configurations
        let invalidConfig1 = AudioEngineConfiguration(sampleRate: 0, bufferSize: 512, channelCount: 2)
        XCTAssertThrowsError(try audioEngineInteractor.validateConfiguration(invalidConfig1))
        
        let invalidConfig2 = AudioEngineConfiguration(sampleRate: 44100, bufferSize: 0, channelCount: 2)
        XCTAssertThrowsError(try audioEngineInteractor.validateConfiguration(invalidConfig2))
        
        let invalidConfig3 = AudioEngineConfiguration(sampleRate: 44100, bufferSize: 512, channelCount: 0)
        XCTAssertThrowsError(try audioEngineInteractor.validateConfiguration(invalidConfig3))
    }
    
    // MARK: - Error Handling Tests
    
    func testAudioEngineErrorRecovery() throws {
        // GIVEN: Audio engine that will fail
        mockAudioEngine.setShouldFailOperations(true)
        
        // WHEN: Attempting operations that fail
        XCTAssertThrowsError(try audioEngineInteractor.startAudioEngine())
        
        // THEN: Error recovery should be attempted
        XCTAssertTrue(mockPresenter.wasErrorPresentedCalled)
        XCTAssertTrue(mockPresenter.wasErrorRecoveryAttemptedCalled)
    }
    
    // MARK: - Performance Tests
    
    func testAudioProcessingPerformance() throws {
        // GIVEN: Running audio engine
        let config = AudioEngineConfiguration(sampleRate: 44100, bufferSize: 512, channelCount: 2)
        try mockAudioEngine.initialize(sampleRate: config.sampleRate, bufferSize: config.bufferSize, channelCount: config.channelCount)
        try mockAudioEngine.start()
        
        let inputBuffer = TestUtilities.generateTestAudioBuffer()
        
        // WHEN & THEN: Audio processing should be performant
        measure {
            for _ in 0..<100 {
                do {
                    let outputBuffer = try audioEngineInteractor.processAudioBuffer(inputBuffer)
                    TestUtilities.cleanupAudioBuffer(outputBuffer)
                } catch {
                    XCTFail("Audio processing failed: \(error)")
                }
            }
        }
        
        TestUtilities.cleanupAudioBuffer(inputBuffer)
    }
}

// MARK: - Mock Audio Engine Presenter

class MockAudioEnginePresenter {
    var wasAudioEngineInitializedCalled = false
    var wasAudioEngineStartedCalled = false
    var wasAudioEngineStoppedCalled = false
    var wasAudioEngineSuspendedCalled = false
    var wasAudioEngineResumedCalled = false
    var wasPerformanceMetricsUpdatedCalled = false
    var wasPerformanceWarningPresentedCalled = false
    var wasAudioNodesConnectedCalled = false
    var wasAudioNodeDisconnectedCalled = false
    var wasErrorPresentedCalled = false
    var wasErrorRecoveryAttemptedCalled = false
    
    var lastError: Error?
    var lastPerformanceMetrics: AudioPerformanceReport?
    
    func presentAudioEngineInitialized() {
        wasAudioEngineInitializedCalled = true
    }
    
    func presentAudioEngineStarted() {
        wasAudioEngineStartedCalled = true
    }
    
    func presentAudioEngineStopped() {
        wasAudioEngineStoppedCalled = true
    }
    
    func presentAudioEngineSuspended() {
        wasAudioEngineSuspendedCalled = true
    }
    
    func presentAudioEngineResumed() {
        wasAudioEngineResumedCalled = true
    }
    
    func presentPerformanceMetrics(_ metrics: AudioPerformanceReport) {
        wasPerformanceMetricsUpdatedCalled = true
        lastPerformanceMetrics = metrics
    }
    
    func presentPerformanceWarning(_ warning: String) {
        wasPerformanceWarningPresentedCalled = true
    }
    
    func presentAudioNodesConnected() {
        wasAudioNodesConnectedCalled = true
    }
    
    func presentAudioNodeDisconnected() {
        wasAudioNodeDisconnectedCalled = true
    }
    
    func presentError(_ error: Error) {
        wasErrorPresentedCalled = true
        lastError = error
    }
    
    func attemptErrorRecovery() {
        wasErrorRecoveryAttemptedCalled = true
    }
}

// MARK: - Audio Engine Interactor Implementation

class AudioEngineInteractor {
    private let audioEngine: MockAudioEngine
    private let presenter: MockAudioEnginePresenter
    
    init(audioEngine: MockAudioEngine, presenter: MockAudioEnginePresenter) {
        self.audioEngine = audioEngine
        self.presenter = presenter
    }
    
    func initializeAudioEngine(with configuration: AudioEngineConfiguration) throws {
        do {
            try validateConfiguration(configuration)
            try audioEngine.initialize(
                sampleRate: configuration.sampleRate,
                bufferSize: configuration.bufferSize,
                channelCount: configuration.channelCount
            )
            presenter.presentAudioEngineInitialized()
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func startAudioEngine() throws {
        do {
            try audioEngine.start()
            presenter.presentAudioEngineStarted()
        } catch {
            presenter.presentError(error)
            presenter.attemptErrorRecovery()
            throw error
        }
    }
    
    func stopAudioEngine() throws {
        do {
            try audioEngine.stop()
            presenter.presentAudioEngineStopped()
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func suspendAudioEngine() throws {
        do {
            try audioEngine.suspend()
            presenter.presentAudioEngineSuspended()
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func resumeAudioEngine() throws {
        do {
            try audioEngine.resume()
            presenter.presentAudioEngineResumed()
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func processAudioBuffer(_ buffer: AudioEngine.AudioBuffer) throws -> AudioEngine.AudioBuffer {
        guard audioEngine.isRunning else {
            throw AudioEngineInteractorError.engineNotRunning("Audio engine must be running to process audio")
        }
        
        return audioEngine.processAudio(inputBuffer: buffer)
    }
    
    func getPerformanceMetrics() -> AudioPerformanceReport {
        let metrics = audioEngine.getPerformanceReport()
        presenter.presentPerformanceMetrics(metrics)
        return metrics
    }
    
    func monitorPerformance() {
        let metrics = audioEngine.getPerformanceReport()
        
        if metrics.cpuUsage > 0.7 {
            presenter.presentPerformanceWarning("High CPU usage: \(Int(metrics.cpuUsage * 100))%")
        }
        
        if metrics.latency > 0.02 {
            presenter.presentPerformanceWarning("High latency: \(Int(metrics.latency * 1000))ms")
        }
    }
    
    func connectAudioNodes(source: MockAudioNode, destination: MockAudioNode) throws {
        do {
            try audioEngine.connectNode(source, to: destination)
            presenter.presentAudioNodesConnected()
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func disconnectAudioNode(_ node: MockAudioNode) throws {
        do {
            try audioEngine.disconnectNode(node)
            presenter.presentAudioNodeDisconnected()
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func validateConfiguration(_ config: AudioEngineConfiguration) throws {
        if config.sampleRate <= 0 {
            throw AudioEngineInteractorError.invalidConfiguration("Sample rate must be positive")
        }
        
        if config.bufferSize <= 0 || !config.bufferSize.isPowerOfTwo {
            throw AudioEngineInteractorError.invalidConfiguration("Buffer size must be a positive power of 2")
        }
        
        if config.channelCount <= 0 {
            throw AudioEngineInteractorError.invalidConfiguration("Channel count must be positive")
        }
    }
}

// MARK: - Audio Engine Configuration

struct AudioEngineConfiguration {
    let sampleRate: Double
    let bufferSize: Int
    let channelCount: Int
}

// MARK: - Audio Engine Interactor Errors

enum AudioEngineInteractorError: Error, LocalizedError {
    case invalidConfiguration(String)
    case engineNotRunning(String)
    case processingError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message):
            return "Invalid audio configuration: \(message)"
        case .engineNotRunning(let message):
            return "Audio engine not running: \(message)"
        case .processingError(let message):
            return "Audio processing error: \(message)"
        }
    }
}

// MARK: - Extensions

extension Int {
    var isPowerOfTwo: Bool {
        return self > 0 && (self & (self - 1)) == 0
    }
}
