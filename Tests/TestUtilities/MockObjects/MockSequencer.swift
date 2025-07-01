import Foundation
@testable import SequencerModule
@testable import MachineProtocols

/// Mock implementation of Sequencer for testing
public class MockSequencer: SequencerProtocol {
    
    // MARK: - Properties
    
    public var isRunning: Bool = false
    public var isInitialized: Bool = false
    public var bpm: Float = 120.0
    public var currentStep: Int = 0
    public var currentPattern: SequencerMockPattern?
    public var patterns: [SequencerMockPattern] = []
    public var isRecording: Bool = false
    public var recordingMode: RecordingMode = .step
    
    private var shouldFailOperations: Bool = false
    private var stepTimer: Timer?
    private var eventHandlers: [SequencerEventHandler] = []
    
    // MARK: - Mock Configuration
    
    public init() {}
    
    /// Configure the mock to simulate operation failures
    public func setShouldFailOperations(_ shouldFail: Bool) {
        self.shouldFailOperations = shouldFail
    }
    
    // MARK: - SequencerProtocol Implementation
    
    public func initialize() throws {
        if shouldFailOperations {
            throw SequencerError.initializationFailed("Mock initialization failure")
        }
        
        isInitialized = true
    }
    
    public func start() throws {
        if shouldFailOperations {
            throw SequencerError.startFailed("Mock start failure")
        }
        
        guard isInitialized else {
            throw SequencerError.notInitialized("Sequencer not initialized")
        }
        
        isRunning = true
        startStepTimer()
        
        // Notify event handlers
        for handler in eventHandlers {
            handler.onSequencerStarted()
        }
    }
    
    public func stop() throws {
        if shouldFailOperations {
            throw SequencerError.stopFailed("Mock stop failure")
        }
        
        isRunning = false
        stopStepTimer()
        currentStep = 0
        
        // Notify event handlers
        for handler in eventHandlers {
            handler.onSequencerStopped()
        }
    }
    
    public func pause() throws {
        if shouldFailOperations {
            throw SequencerError.pauseFailed("Mock pause failure")
        }
        
        isRunning = false
        stopStepTimer()
        
        // Notify event handlers
        for handler in eventHandlers {
            handler.onSequencerPaused()
        }
    }
    
    public func resume() throws {
        if shouldFailOperations {
            throw SequencerError.resumeFailed("Mock resume failure")
        }
        
        guard isInitialized else {
            throw SequencerError.notInitialized("Sequencer not initialized")
        }
        
        isRunning = true
        startStepTimer()
        
        // Notify event handlers
        for handler in eventHandlers {
            handler.onSequencerResumed()
        }
    }
    
    public func shutdown() {
        isRunning = false
        isInitialized = false
        stopStepTimer()
        patterns.removeAll()
        eventHandlers.removeAll()
        currentPattern = nil
        currentStep = 0
    }
    
    // MARK: - Pattern Management
    
    public func loadPattern(_ pattern: SequencerMockPattern) throws {
        if shouldFailOperations {
            throw SequencerError.patternLoadFailed("Mock pattern load failure")
        }
        
        currentPattern = pattern
        currentStep = 0
        
        // Notify event handlers
        for handler in eventHandlers {
            handler.onPatternChanged(pattern)
        }
    }
    
    public func createPattern(name: String, length: Int) -> SequencerMockPattern {
        let pattern = SequencerMockPattern(
            id: UUID(),
            name: name,
            length: length,
            steps: Array(repeating: SequencerMockStep(), count: length)
        )
        
        patterns.append(pattern)
        return pattern
    }
    
    public func deletePattern(_ pattern: SequencerMockPattern) throws {
        if shouldFailOperations {
            throw SequencerError.patternDeleteFailed("Mock pattern delete failure")
        }
        
        patterns.removeAll { $0.id == pattern.id }
        
        if currentPattern?.id == pattern.id {
            currentPattern = nil
        }
    }
    
    // MARK: - Step Management
    
    public func setStep(_ stepIndex: Int, enabled: Bool) throws {
        if shouldFailOperations {
            throw SequencerError.stepUpdateFailed("Mock step update failure")
        }
        
        guard let pattern = currentPattern else {
            throw SequencerError.noPatternLoaded("No pattern loaded")
        }
        
        guard stepIndex >= 0 && stepIndex < pattern.steps.count else {
            throw SequencerError.invalidStepIndex("Invalid step index: \(stepIndex)")
        }
        
        pattern.steps[stepIndex].isEnabled = enabled
        
        // Notify event handlers
        for handler in eventHandlers {
            handler.onStepChanged(stepIndex, enabled)
        }
    }
    
    public func getStep(_ stepIndex: Int) throws -> SequencerMockStep {
        guard let pattern = currentPattern else {
            throw SequencerError.noPatternLoaded("No pattern loaded")
        }
        
        guard stepIndex >= 0 && stepIndex < pattern.steps.count else {
            throw SequencerError.invalidStepIndex("Invalid step index: \(stepIndex)")
        }
        
        return pattern.steps[stepIndex]
    }
    
    // MARK: - Recording
    
    public func startRecording(mode: RecordingMode) throws {
        if shouldFailOperations {
            throw SequencerError.recordingFailed("Mock recording start failure")
        }
        
        isRecording = true
        recordingMode = mode
        
        // Notify event handlers
        for handler in eventHandlers {
            handler.onRecordingStarted(mode)
        }
    }
    
    public func stopRecording() throws {
        if shouldFailOperations {
            throw SequencerError.recordingFailed("Mock recording stop failure")
        }
        
        isRecording = false
        
        // Notify event handlers
        for handler in eventHandlers {
            handler.onRecordingStopped()
        }
    }
    
    // MARK: - Event Handling
    
    public func addEventHandler(_ handler: SequencerEventHandler) {
        eventHandlers.append(handler)
    }
    
    public func removeEventHandler(_ handler: SequencerEventHandler) {
        eventHandlers.removeAll { $0 === handler }
    }
    
    // MARK: - Private Methods
    
    private func startStepTimer() {
        stopStepTimer()
        
        let stepInterval = 60.0 / (Double(bpm) * 4.0) // 16th note intervals
        stepTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] _ in
            self?.advanceStep()
        }
    }
    
    private func stopStepTimer() {
        stepTimer?.invalidate()
        stepTimer = nil
    }
    
    private func advanceStep() {
        guard let pattern = currentPattern else { return }
        
        currentStep = (currentStep + 1) % pattern.length
        
        // Check if current step is enabled and trigger events
        if pattern.steps[currentStep].isEnabled {
            for handler in eventHandlers {
                handler.onStepTriggered(currentStep, pattern.steps[currentStep])
            }
        }
        
        // Notify step position change
        for handler in eventHandlers {
            handler.onStepPositionChanged(currentStep)
        }
    }
}

// MARK: - Mock Data Models

public class SequencerMockPattern: Identifiable {
    public let id: UUID
    public var name: String
    public var length: Int
    public var steps: [SequencerMockStep]
    
    public init(id: UUID, name: String, length: Int, steps: [SequencerMockStep]) {
        self.id = id
        self.name = name
        self.length = length
        self.steps = steps
    }
}

public class SequencerMockStep {
    public var isEnabled: Bool = false
    public var velocity: Float = 0.8
    public var note: Int = 60
    public var parameters: [String: Float] = [:]
    
    public init(isEnabled: Bool = false, velocity: Float = 0.8, note: Int = 60) {
        self.isEnabled = isEnabled
        self.velocity = velocity
        self.note = note
    }
}

// MARK: - Protocol Definitions

public protocol SequencerProtocol {
    var isRunning: Bool { get }
    var isInitialized: Bool { get }
    var bpm: Float { get set }
    var currentStep: Int { get }
    var isRecording: Bool { get }
    var recordingMode: RecordingMode { get }
    
    func initialize() throws
    func start() throws
    func stop() throws
    func pause() throws
    func resume() throws
    func shutdown()
    
    func loadPattern(_ pattern: SequencerMockPattern) throws
    func createPattern(name: String, length: Int) -> SequencerMockPattern
    func deletePattern(_ pattern: SequencerMockPattern) throws
    
    func setStep(_ stepIndex: Int, enabled: Bool) throws
    func getStep(_ stepIndex: Int) throws -> SequencerMockStep
    
    func startRecording(mode: RecordingMode) throws
    func stopRecording() throws
    
    func addEventHandler(_ handler: SequencerEventHandler)
    func removeEventHandler(_ handler: SequencerEventHandler)
}

public protocol SequencerEventHandler: AnyObject {
    func onSequencerStarted()
    func onSequencerStopped()
    func onSequencerPaused()
    func onSequencerResumed()
    func onPatternChanged(_ pattern: SequencerMockPattern)
    func onStepChanged(_ stepIndex: Int, _ enabled: Bool)
    func onStepTriggered(_ stepIndex: Int, _ step: SequencerMockStep)
    func onStepPositionChanged(_ stepIndex: Int)
    func onRecordingStarted(_ mode: RecordingMode)
    func onRecordingStopped()
}

public enum RecordingMode {
    case step
    case live
    case grid
}

// MARK: - Error Types

public enum SequencerError: Error, LocalizedError {
    case initializationFailed(String)
    case startFailed(String)
    case stopFailed(String)
    case pauseFailed(String)
    case resumeFailed(String)
    case patternLoadFailed(String)
    case patternDeleteFailed(String)
    case stepUpdateFailed(String)
    case recordingFailed(String)
    case notInitialized(String)
    case noPatternLoaded(String)
    case invalidStepIndex(String)
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "Sequencer initialization failed: \(message)"
        case .startFailed(let message):
            return "Sequencer start failed: \(message)"
        case .stopFailed(let message):
            return "Sequencer stop failed: \(message)"
        case .pauseFailed(let message):
            return "Sequencer pause failed: \(message)"
        case .resumeFailed(let message):
            return "Sequencer resume failed: \(message)"
        case .patternLoadFailed(let message):
            return "Pattern load failed: \(message)"
        case .patternDeleteFailed(let message):
            return "Pattern delete failed: \(message)"
        case .stepUpdateFailed(let message):
            return "Step update failed: \(message)"
        case .recordingFailed(let message):
            return "Recording operation failed: \(message)"
        case .notInitialized(let message):
            return "Sequencer not initialized: \(message)"
        case .noPatternLoaded(let message):
            return "No pattern loaded: \(message)"
        case .invalidStepIndex(let message):
            return "Invalid step index: \(message)"
        }
    }
}
