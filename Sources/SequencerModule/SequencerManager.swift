// SequencerManager.swift
// DigitonePad - SequencerModule
//
// This module handles sequencing and pattern playback.

import Foundation
import Combine
import MachineProtocols
import DataLayer

/// Main interface for sequencer operations
public final class SequencerManager: @unchecked Sendable, SequencerEventPublisher {
    public static let shared = SequencerManager()

    public private(set) var isInitialized = false
    private let sequencer = Sequencer.shared
    private var cancellables = Set<AnyCancellable>()

    // Event publishing
    private let eventSubject = PassthroughSubject<SequencerEvent, Never>()
    public var eventPublisher: AnyPublisher<SequencerEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    private init() {
        setupEventHandling()
    }

    /// Initialize the sequencer
    public func initialize() {
        // Initialize sequencer components
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isInitialized = true
        }
    }

    // MARK: - Playback Control

    /// Start pattern playback
    public func play() {
        guard isInitialized else { return }
        sequencer.play()
    }

    /// Stop pattern playback
    public func stop() {
        guard isInitialized else { return }
        sequencer.stop()
    }

    /// Set playback tempo
    public func setTempo(_ bpm: Double) {
        guard isInitialized else { return }
        sequencer.setTempo(bpm)
    }

    // MARK: - Pattern Management

    /// Load a pattern for playback
    public func loadPattern(_ pattern: Pattern, forTrack trackId: Int) {
        guard isInitialized else { return }
        sequencer.loadPattern(pattern, forTrack: trackId)
    }

    /// Create a simple test pattern
    public func createTestPattern(forTrack trackId: Int) -> Pattern {
        var steps: [PatternStep] = []

        // Create a simple 16-step pattern with notes on steps 0, 4, 8, 12
        for i in 0..<16 {
            let isActive = (i % 4 == 0)
            let note: UInt8? = isActive ? 60 : nil // Middle C
            let step = PatternStep(note: note, velocity: 100, isActive: isActive)
            steps.append(step)
        }

        return Pattern(trackId: trackId, steps: steps, name: "Test Pattern \(trackId)")
    }

    /// Get current timing information
    public var timing: SequencerTiming {
        sequencer.timing
    }

    // MARK: - Private Implementation

    private func setupEventHandling() {
        // Forward sequencer events
        sequencer.eventPublisher
            .sink { [weak self] event in
                self?.eventSubject.send(event)
            }
            .store(in: &cancellables)
    }
}