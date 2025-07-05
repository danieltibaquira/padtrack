// SequencerBridge.swift
// DigitonePad - Sequencer Bridge
//
// Bridge between step sequencer UI and audio engine

import Foundation
import Combine
import SequencerModule

/// Bridge class that connects step sequencer to audio engine and voice machines
@MainActor
public class SequencerBridge: ObservableObject {
    
    // MARK: - Properties
    
    private var voiceMachineManager: VoiceMachineManager?
    private var sequencerCore: SequencerCore?
    private var cancellables = Set<AnyCancellable>()
    
    // Sequencer state
    @Published public var isRunning = false
    @Published public var currentStep = -1
    @Published public var currentBPM: Double = 120.0
    
    // Pattern data for each track
    private var trackPatterns: [Int: [Bool]] = [:]
    
    // Timing
    private var stepTimer: Timer?
    private var stepDuration: TimeInterval {
        return 60.0 / (currentBPM * 4) // 16th note duration
    }
    
    // MARK: - Initialization
    
    public init() {
        setupDefaultPatterns()
        setupSequencerCore()
    }
    
    public func setVoiceMachineManager(_ manager: VoiceMachineManager) {
        self.voiceMachineManager = manager
        sequencerCore?.setVoiceMachineManager(manager)
    }
    
    // MARK: - Transport Controls
    
    public func start() {
        isRunning = true
        currentStep = -1
        startStepTimer()
        sequencerCore?.start()
    }
    
    public func stop() {
        isRunning = false
        currentStep = -1
        stopStepTimer()
        sequencerCore?.stop()
    }
    
    public func pause() {
        isRunning = false
        stopStepTimer()
        sequencerCore?.pause()
    }
    
    public func resume() {
        isRunning = true
        startStepTimer()
        sequencerCore?.resume()
    }
    
    // MARK: - Pattern Management
    
    public func toggleStep(_ step: Int, track: Int) {
        guard step >= 0 && step < 16 && track >= 1 && track <= 4 else { return }
        
        if trackPatterns[track] == nil {
            trackPatterns[track] = Array(repeating: false, count: 16)
        }
        
        trackPatterns[track]?[step].toggle()
        sequencerCore?.toggleStep(step, track: track)
    }
    
    public func isStepActive(_ step: Int, track: Int) -> Bool {
        return trackPatterns[track]?[step] ?? false
    }
    
    public func setPattern(_ pattern: [Bool], for track: Int) {
        guard track >= 1 && track <= 4 else { return }
        trackPatterns[track] = pattern
        sequencerCore?.setPattern(pattern, for: track)
    }
    
    public func getPattern(for track: Int) -> [Bool] {
        return trackPatterns[track] ?? Array(repeating: false, count: 16)
    }
    
    public func clearPattern(for track: Int) {
        setPattern(Array(repeating: false, count: 16), for: track)
    }
    
    public func fillPattern(for track: Int) {
        setPattern(Array(repeating: true, count: 16), for: track)
    }
    
    // MARK: - Step Triggers
    
    public func triggerStep(_ step: Int, track: Int) {
        guard let voiceMachineManager = voiceMachineManager else { return }
        
        // Trigger note on voice machine
        voiceMachineManager.triggerVoice(track: track, note: 60, velocity: 100)
        
        // Update sequencer core
        sequencerCore?.triggerStep(step, track: track)
    }
    
    // MARK: - BPM Control
    
    public func setBPM(_ bpm: Double) {
        currentBPM = max(60.0, min(200.0, bpm))
        
        // Restart timer if running
        if isRunning {
            stopStepTimer()
            startStepTimer()
        }
    }
    
    public func tapTempo() {
        // Simple tap tempo implementation
        // In a real implementation, this would calculate BPM from tap intervals
        let newBPM = currentBPM + 5.0
        setBPM(newBPM > 180.0 ? 120.0 : newBPM)
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultPatterns() {
        // Setup default patterns for each track
        trackPatterns[1] = [true, false, false, false, true, false, false, false,
                           true, false, false, false, true, false, false, false] // Kick pattern
        trackPatterns[2] = [false, false, true, false, false, false, true, false,
                           false, false, true, false, false, false, true, false] // Snare pattern
        trackPatterns[3] = [true, true, true, true, true, true, true, true,
                           true, true, true, true, true, true, true, true] // Hi-hat pattern
        trackPatterns[4] = [false, false, false, false, false, false, false, false,
                           false, false, false, false, false, false, false, false] // Empty pattern
    }
    
    private func setupSequencerCore() {
        sequencerCore = SequencerCore()
        
        // Set initial patterns
        for track in 1...4 {
            if let pattern = trackPatterns[track] {
                sequencerCore?.setPattern(pattern, for: track)
            }
        }
    }
    
    private func startStepTimer() {
        stopStepTimer()
        
        stepTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceStep()
            }
        }
    }
    
    private func stopStepTimer() {
        stepTimer?.invalidate()
        stepTimer = nil
    }
    
    private func advanceStep() {
        currentStep = (currentStep + 1) % 16
        
        // Check each track for active steps
        for track in 1...4 {
            if isStepActive(currentStep, track: track) {
                triggerStep(currentStep, track: track)
            }
        }
        
        // Process step in sequencer core
        sequencerCore?.processStep(currentStep)
    }
}

// MARK: - Simple Sequencer Core Implementation

public class SequencerCore {
    private var voiceMachineManager: VoiceMachineManager?
    private var patterns: [Int: [Bool]] = [:]
    private var isRunning = false
    private var currentPosition = 0
    
    public func setVoiceMachineManager(_ manager: VoiceMachineManager) {
        self.voiceMachineManager = manager
    }
    
    public func start() {
        isRunning = true
        currentPosition = 0
    }
    
    public func stop() {
        isRunning = false
        currentPosition = 0
    }
    
    public func pause() {
        isRunning = false
    }
    
    public func resume() {
        isRunning = true
    }
    
    public func setPattern(_ pattern: [Bool], for track: Int) {
        patterns[track] = pattern
    }
    
    public func toggleStep(_ step: Int, track: Int) {
        if patterns[track] == nil {
            patterns[track] = Array(repeating: false, count: 16)
        }
        patterns[track]?[step].toggle()
    }
    
    public func triggerStep(_ step: Int, track: Int) {
        voiceMachineManager?.triggerVoice(track: track, note: 60, velocity: 100)
    }
    
    public func processStep(_ step: Int) {
        currentPosition = step
        
        for track in 1...4 {
            if let pattern = patterns[track], step < pattern.count, pattern[step] {
                triggerStep(step, track: track)
            }
        }
    }
}