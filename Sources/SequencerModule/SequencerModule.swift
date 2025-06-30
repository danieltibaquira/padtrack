// SequencerModule.swift
// DigitonePad - SequencerModule

import Foundation
import Combine
import MachineProtocols
import DataLayer

// Re-export types from MachineProtocols for convenience
public typealias SequencerEvent = MachineProtocols.SequencerEvent
public typealias SequencerTiming = MachineProtocols.SequencerTiming
public typealias TimeSignature = MachineProtocols.TimeSignature

// MARK: - Sequencer Clock

/// High-precision clock for sequencer timing
public final class SequencerClock: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.digitonepad.sequencer.clock",
                                     qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var isRunning = false

    // Timing properties
    private var _bpm: Double = 120.0
    private var _timeSignature: TimeSignature = .fourFour
    private var _sampleRate: Double = 44100.0

    // Step tracking
    private var currentStep: Int = 0
    private var stepCount: Int = 16

    // Event publishing
    private let eventSubject = PassthroughSubject<SequencerEvent, Never>()
    public var eventPublisher: AnyPublisher<SequencerEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    public init(sampleRate: Double = 44100.0) {
        self._sampleRate = sampleRate
    }

    // MARK: - Public Interface

    public var bpm: Double {
        get { _bpm }
        set {
            queue.sync {
                _bpm = newValue
                if isRunning {
                    restartTimer()
                }
                eventSubject.send(.tempoChanged(bpm: newValue))
            }
        }
    }

    public var timeSignature: TimeSignature {
        get { _timeSignature }
        set {
            queue.sync {
                _timeSignature = newValue
                if isRunning {
                    restartTimer()
                }
            }
        }
    }

    public var timing: SequencerTiming {
        SequencerTiming(
            currentStep: currentStep,
            currentPattern: 0, // TODO: Track current pattern
            bpm: _bpm,
            timeSignature: (_timeSignature.numerator, _timeSignature.denominator),
            sampleRate: _sampleRate
        )
    }

    public func start() {
        queue.async { [weak self] in
            guard let self = self, !self.isRunning else { return }
            self.isRunning = true
            self.currentStep = 0
            self.startTimer()
            self.eventSubject.send(.playbackStarted)
        }
    }

    public func stop() {
        queue.async { [weak self] in
            guard let self = self, self.isRunning else { return }
            self.isRunning = false
            self.stopTimer()
            self.currentStep = 0
            self.eventSubject.send(.playbackStopped)
        }
    }

    // MARK: - Private Implementation

    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        let interval = calculateStepInterval()

        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.onTimerTick()
        }

        self.timer = timer
        timer.resume()
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func restartTimer() {
        stopTimer()
        if isRunning {
            startTimer()
        }
    }

    private func calculateStepInterval() -> DispatchTimeInterval {
        // Calculate interval for 16th notes
        let secondsPerStep = 60.0 / (_bpm * 4.0)
        let nanoseconds = UInt64(secondsPerStep * 1_000_000_000)
        return .nanoseconds(Int(nanoseconds))
    }

    private func onTimerTick() {
        currentStep = (currentStep + 1) % stepCount
        eventSubject.send(.stepAdvanced(step: currentStep, pattern: 0))
    }
}

// MARK: - Pattern Data Structure

/// Represents a single step in a pattern
public struct PatternStep: Sendable, Codable {
    public let note: UInt8?
    public let velocity: UInt8
    public let length: Double // In steps (1.0 = one step)
    public let probability: Double // 0.0 to 1.0
    public let isActive: Bool

    public init(note: UInt8? = nil, velocity: UInt8 = 100,
                length: Double = 1.0, probability: Double = 1.0,
                isActive: Bool = false) {
        self.note = note
        self.velocity = velocity
        self.length = length
        self.probability = probability
        self.isActive = isActive
    }
}

/// Represents a complete pattern for a single track
public struct Pattern: Sendable, Codable, Identifiable {
    public let id = UUID()
    public let trackId: Int
    public let steps: [PatternStep]
    public let length: Int // Number of steps
    public let name: String

    public init(trackId: Int, steps: [PatternStep], name: String = "Pattern") {
        self.trackId = trackId
        self.steps = steps
        self.length = steps.count
        self.name = name
    }

    /// Get step at position, wrapping around if necessary
    public func step(at position: Int) -> PatternStep {
        let index = position % steps.count
        return steps[index]
    }
}

// MARK: - Main Sequencer

/// Main sequencer for pattern playback
public final class Sequencer: @unchecked Sendable {
    public static let shared = Sequencer()

    // Core components
    private let clock: SequencerClock
    private var patterns: [Int: Pattern] = [:]
    private var activePatterns: Set<Int> = []

    // Event publishing
    private let eventSubject = PassthroughSubject<SequencerEvent, Never>()
    public var eventPublisher: AnyPublisher<SequencerEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    // Subscriptions
    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.clock = SequencerClock()
        setupEventHandling()
    }

    // MARK: - Public Interface

    /// Start sequencer playback
    public func play() {
        clock.start()
        eventSubject.send(.playbackStarted)
    }

    /// Stop sequencer playback
    public func stop() {
        clock.stop()
        eventSubject.send(.playbackStopped)
    }

    /// Set the tempo in BPM
    public func setTempo(_ bpm: Double) {
        clock.bpm = bpm
    }

    /// Set the time signature
    public func setTimeSignature(numerator: Int, denominator: Int) {
        clock.timeSignature = TimeSignature(numerator: numerator, denominator: denominator)
    }

    /// Set the time signature using TimeSignature struct
    public func setTimeSignature(_ timeSignature: TimeSignature) {
        clock.timeSignature = timeSignature
    }

    /// Load a pattern for a specific track
    public func loadPattern(_ pattern: Pattern, forTrack trackId: Int) {
        patterns[trackId] = pattern
        activePatterns.insert(trackId)
    }

    /// Remove pattern from a track
    public func removePattern(fromTrack trackId: Int) {
        patterns.removeValue(forKey: trackId)
        activePatterns.remove(trackId)
    }

    /// Get current timing information
    public var timing: SequencerTiming {
        clock.timing
    }

    // MARK: - Private Implementation

    private func setupEventHandling() {
        // Subscribe to clock events
        clock.eventPublisher
            .sink { [weak self] event in
                self?.handleClockEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleClockEvent(_ event: SequencerEvent) {
        switch event {
        case .stepAdvanced(let step, _):
            processStep(step)
        default:
            // Forward other events
            eventSubject.send(event)
        }
    }

    private func processStep(_ step: Int) {
        // Process each active pattern
        for trackId in activePatterns {
            guard let pattern = patterns[trackId] else { continue }

            let patternStep = pattern.step(at: step)

            // Check if step should trigger based on probability
            if patternStep.isActive && shouldTrigger(probability: patternStep.probability) {
                if let note = patternStep.note {
                    eventSubject.send(.noteTriggered(note: note,
                                                   velocity: patternStep.velocity,
                                                   track: trackId))
                }
            }
        }

        // Forward step event
        eventSubject.send(.stepAdvanced(step: step, pattern: 0))
    }

    private func shouldTrigger(probability: Double) -> Bool {
        return Double.random(in: 0...1) <= probability
    }
}