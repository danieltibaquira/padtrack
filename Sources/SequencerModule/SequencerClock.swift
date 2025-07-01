// SequencerClock.swift
// DigitonePad - SequencerModule
//
// High-precision sequencer clock and timing engine with musical timing support
// Sample-accurate timing using audio callback synchronization and high-precision timers

import Foundation
import AVFoundation
import Combine
import AudioEngine

// MARK: - Clock Configuration

/// Configuration for the sequencer clock
public struct SequencerClockConfig: Codable {
    /// Tempo in BPM (30-300 with decimal precision)
    public var tempo: Double = 120.0
    
    /// Time signature numerator (1-16)
    public var timeSignatureNumerator: Int = 4
    
    /// Time signature denominator (1, 2, 4, 8, 16)
    public var timeSignatureDenominator: Int = 4
    
    /// Swing amount (0-100%)
    public var swingAmount: Float = 0.0
    
    /// MIDI clock input enabled
    public var midiClockInputEnabled: Bool = false
    
    /// MIDI clock output enabled
    public var midiClockOutputEnabled: Bool = false
    
    /// Clock resolution (pulses per quarter note)
    public var clockResolution: Int = 24  // Standard MIDI clock resolution
    
    /// Metronome enabled
    public var metronomeEnabled: Bool = false
    
    /// Metronome volume (0.0-1.0)
    public var metronomeVolume: Float = 0.5
    
    public init() {}
    
    /// Validate and clamp parameters
    public mutating func validate() {
        tempo = max(30.0, min(300.0, tempo))
        timeSignatureNumerator = max(1, min(16, timeSignatureNumerator))
        timeSignatureDenominator = [1, 2, 4, 8, 16].contains(timeSignatureDenominator) ? timeSignatureDenominator : 4
        swingAmount = max(0.0, min(100.0, swingAmount))
        clockResolution = max(1, min(96, clockResolution))
        metronomeVolume = max(0.0, min(1.0, metronomeVolume))
    }
}

// MARK: - Clock Position

/// Represents a position in musical time
public struct ClockPosition: Codable, Equatable {
    /// Bar number (1-based)
    public var bar: Int = 1
    
    /// Beat within the bar (1-based)
    public var beat: Int = 1
    
    /// Tick within the beat (0-based, resolution dependent)
    public var tick: Int = 0
    
    /// Total ticks from the beginning
    public var totalTicks: Int64 = 0
    
    /// Sample position (for sample-accurate timing)
    public var samplePosition: Int64 = 0
    
    public init(bar: Int = 1, beat: Int = 1, tick: Int = 0, totalTicks: Int64 = 0, samplePosition: Int64 = 0) {
        self.bar = bar
        self.beat = beat
        self.tick = tick
        self.totalTicks = totalTicks
        self.samplePosition = samplePosition
    }
    
    /// Create position from total ticks
    public init(totalTicks: Int64, config: SequencerClockConfig) {
        let ticksPerBeat = config.clockResolution
        let beatsPerBar = config.timeSignatureNumerator
        let ticksPerBar = ticksPerBeat * beatsPerBar
        
        self.totalTicks = totalTicks
        self.bar = Int(totalTicks / Int64(ticksPerBar)) + 1
        
        let remainingTicks = Int(totalTicks % Int64(ticksPerBar))
        self.beat = (remainingTicks / ticksPerBeat) + 1
        self.tick = remainingTicks % ticksPerBeat
        self.samplePosition = 0  // Set externally
    }
}

// MARK: - Transport State

/// Transport control states
public enum TransportState: String, CaseIterable, Codable {
    case stopped = "stopped"
    case playing = "playing"
    case paused = "paused"
    case recording = "recording"
    
    public var isPlaying: Bool {
        return self == .playing || self == .recording
    }
}

// MARK: - Clock Events

/// Clock event types
public enum ClockEvent: Equatable {
    case tick(position: ClockPosition)
    case beat(position: ClockPosition)
    case bar(position: ClockPosition)
    case transportChanged(state: TransportState)
    case tempoChanged(tempo: Double)
    case positionJumped(from: ClockPosition, to: ClockPosition)
}

// MARK: - Swing Calculator

/// Calculates swing timing offsets
public final class SwingCalculator {
    
    /// Calculate swing offset for a given tick position
    public static func calculateSwingOffset(
        tick: Int,
        swingAmount: Float,
        clockResolution: Int
    ) -> Double {
        guard swingAmount > 0.0 else { return 0.0 }
        
        let ticksPerBeat = clockResolution
        let tickWithinBeat = tick % ticksPerBeat
        
        // Apply swing to off-beat positions (typically 8th note positions)
        let swingPosition = ticksPerBeat / 2  // 8th note position
        
        if tickWithinBeat == swingPosition {
            // Convert swing percentage to timing offset
            let maxOffset = Double(ticksPerBeat) * 0.25  // Max 25% delay
            return Double(swingAmount / 100.0) * maxOffset
        }
        
        return 0.0
    }
    
    /// Calculate humanization offset (random timing variation)
    public static func calculateHumanizationOffset(
        humanizationAmount: Float
    ) -> Double {
        guard humanizationAmount > 0.0 else { return 0.0 }
        
        let maxOffset = Double(humanizationAmount) * 0.1  // Up to 10% of a tick
        return Double.random(in: -maxOffset...maxOffset)
    }
}

// MARK: - High-Precision Timer

/// High-precision timer for sample-accurate timing
public final class HighPrecisionTimer {
    
    private let sampleRate: Double
    private var lastSampleTime: Int64 = 0
    private var accumulatedError: Double = 0.0
    
    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }
    
    /// Calculate exact sample position for a given tempo and tick
    public func calculateSamplePosition(
        tick: Int64,
        tempo: Double,
        clockResolution: Int
    ) -> Int64 {
        // Calculate samples per tick
        let samplesPerMinute = sampleRate * 60.0
        let samplesPerQuarterNote = samplesPerMinute / tempo
        let samplesPerTick = samplesPerQuarterNote / Double(clockResolution)
        
        // Apply accumulated error correction
        let exactPosition = Double(tick) * samplesPerTick + accumulatedError
        let samplePosition = Int64(exactPosition)
        
        // Update accumulated error for next calculation
        accumulatedError = exactPosition - Double(samplePosition)
        
        return samplePosition
    }
    
    /// Reset timer state
    public func reset() {
        lastSampleTime = 0
        accumulatedError = 0.0
    }
}

// MARK: - MIDI Clock Handler

/// Handles MIDI clock synchronization
public final class MIDIClockHandler {
    
    // MIDI Clock timing
    private var lastMIDIClockTime: CFAbsoluteTime = 0
    private var midiClockInterval: CFAbsoluteTime = 0
    private var midiClockBuffer: [CFAbsoluteTime] = []
    private let bufferSize = 8
    
    // Output clock
    private var outputClockTimer: Timer?
    private var outputClockCallback: (() -> Void)?
    
    public init() {}
    
    /// Process incoming MIDI clock message
    public func processMIDIClockMessage() -> Double? {
        let currentTime = CFAbsoluteTimeGetCurrent()
        
        if lastMIDIClockTime > 0 {
            let interval = currentTime - lastMIDIClockTime
            
            // Add to buffer for averaging
            midiClockBuffer.append(interval)
            if midiClockBuffer.count > bufferSize {
                midiClockBuffer.removeFirst()
            }
            
            // Calculate average interval
            let averageInterval = midiClockBuffer.reduce(0, +) / Double(midiClockBuffer.count)
            
            // Convert to BPM (24 PPQN standard)
            let bpm = 60.0 / (averageInterval * 24.0)
            
            lastMIDIClockTime = currentTime
            return bpm
        }
        
        lastMIDIClockTime = currentTime
        return nil
    }
    
    /// Start MIDI clock output
    public func startMIDIClockOutput(tempo: Double, callback: @escaping () -> Void) {
        stopMIDIClockOutput()
        
        outputClockCallback = callback
        let interval = 60.0 / (tempo * 24.0)  // 24 PPQN
        
        outputClockTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            callback()
        }
    }
    
    /// Stop MIDI clock output
    public func stopMIDIClockOutput() {
        outputClockTimer?.invalidate()
        outputClockTimer = nil
        outputClockCallback = nil
    }
    
    /// Reset MIDI clock state
    public func reset() {
        lastMIDIClockTime = 0
        midiClockInterval = 0
        midiClockBuffer.removeAll()
        stopMIDIClockOutput()
    }
}

// MARK: - Main Sequencer Clock

/// High-precision sequencer clock with musical timing
public final class SequencerClock: ObservableObject {
    
    // MARK: - Configuration
    
    @Published public var config: SequencerClockConfig {
        didSet {
            config.validate()
            updateInternalTiming()
        }
    }
    
    // MARK: - State
    
    @Published public private(set) var transportState: TransportState = .stopped
    @Published public private(set) var currentPosition: ClockPosition = ClockPosition()
    @Published public private(set) var isRunning: Bool = false
    
    // MARK: - Publishers
    
    public let clockEventPublisher = PassthroughSubject<ClockEvent, Never>()
    
    // MARK: - Internal Components
    
    private let highPrecisionTimer: HighPrecisionTimer
    private let midiClockHandler: MIDIClockHandler
    private let sampleRate: Double
    
    // MARK: - Timing State
    
    private var currentTick: Int64 = 0
    private var nextTickSamplePosition: Int64 = 0
    private var currentSamplePosition: Int64 = 0
    private var lastBeatTick: Int64 = -1
    private var lastBarTick: Int64 = -1
    
    // MARK: - Audio Callback Integration
    
    private var audioCallbackHandler: ((Int) -> Void)?
    
    // MARK: - Loop Points
    
    public var loopStartPosition: ClockPosition?
    public var loopEndPosition: ClockPosition?
    public var loopEnabled: Bool = false
    
    // MARK: - Initialization
    
    public init(config: SequencerClockConfig = SequencerClockConfig(), sampleRate: Double = 44100.0) {
        self.config = config
        self.sampleRate = sampleRate
        self.highPrecisionTimer = HighPrecisionTimer(sampleRate: sampleRate)
        self.midiClockHandler = MIDIClockHandler()
        
        self.config.validate()
        updateInternalTiming()
    }
    
    // MARK: - Transport Controls
    
    /// Start playback
    public func play() {
        guard transportState != .playing else { return }
        
        let previousState = transportState
        transportState = .playing
        isRunning = true
        
        if previousState == .stopped {
            // Reset position if starting from stop
            currentTick = 0
            updateCurrentPosition()
        }
        
        updateInternalTiming()
        startMIDIClockOutput()
        
        clockEventPublisher.send(.transportChanged(state: transportState))
    }
    
    /// Pause playback
    public func pause() {
        guard transportState.isPlaying else { return }
        
        transportState = .paused
        isRunning = false
        
        stopMIDIClockOutput()
        
        clockEventPublisher.send(.transportChanged(state: transportState))
    }
    
    /// Stop playback and reset position
    public func stop() {
        let wasPlaying = transportState.isPlaying
        
        transportState = .stopped
        isRunning = false
        
        // Reset to beginning
        let oldPosition = currentPosition
        currentTick = 0
        updateCurrentPosition()
        
        if wasPlaying {
            stopMIDIClockOutput()
        }
        
        highPrecisionTimer.reset()
        
        clockEventPublisher.send(.transportChanged(state: transportState))
        
        if oldPosition != currentPosition {
            clockEventPublisher.send(.positionJumped(from: oldPosition, to: currentPosition))
        }
    }
    
    /// Continue playback from current position
    public func continue() {
        guard transportState == .paused else { return }
        
        transportState = .playing
        isRunning = true
        
        updateInternalTiming()
        startMIDIClockOutput()
        
        clockEventPublisher.send(.transportChanged(state: transportState))
    }
    
    /// Start recording
    public func record() {
        transportState = .recording
        isRunning = true
        
        updateInternalTiming()
        startMIDIClockOutput()
        
        clockEventPublisher.send(.transportChanged(state: transportState))
    }
    
    // MARK: - Position Control
    
    /// Seek to a specific position
    public func seek(to position: ClockPosition) {
        let oldPosition = currentPosition
        
        currentTick = position.totalTicks
        updateCurrentPosition()
        
        if transportState.isPlaying {
            updateInternalTiming()
        }
        
        clockEventPublisher.send(.positionJumped(from: oldPosition, to: currentPosition))
    }
    
    /// Seek to a specific bar
    public func seekToBar(_ bar: Int) {
        let ticksPerBeat = Int64(config.clockResolution)
        let beatsPerBar = Int64(config.timeSignatureNumerator)
        let ticksPerBar = ticksPerBeat * beatsPerBar
        
        let targetTick = Int64(bar - 1) * ticksPerBar
        let targetPosition = ClockPosition(totalTicks: targetTick, config: config)
        
        seek(to: targetPosition)
    }
    
    // MARK: - Tempo Control
    
    /// Set tempo
    public func setTempo(_ tempo: Double) {
        let oldTempo = config.tempo
        config.tempo = max(30.0, min(300.0, tempo))
        
        if abs(oldTempo - config.tempo) > 0.01 {
            updateInternalTiming()
            updateMIDIClockOutput()
            clockEventPublisher.send(.tempoChanged(tempo: config.tempo))
        }
    }
    
    /// Tap tempo calculation
    private var tapTimes: [CFAbsoluteTime] = []
    
    public func tapTempo() {
        let currentTime = CFAbsoluteTimeGetCurrent()
        tapTimes.append(currentTime)
        
        // Keep only last 8 taps
        if tapTimes.count > 8 {
            tapTimes.removeFirst()
        }
        
        // Calculate tempo from intervals
        if tapTimes.count >= 2 {
            var intervals: [CFAbsoluteTime] = []
            for i in 1..<tapTimes.count {
                intervals.append(tapTimes[i] - tapTimes[i-1])
            }
            
            let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
            let calculatedTempo = 60.0 / averageInterval
            
            // Apply tempo if reasonable
            if calculatedTempo >= 60.0 && calculatedTempo <= 200.0 {
                setTempo(calculatedTempo)
            }
        }
    }
    
    // MARK: - Audio Callback Integration
    
    /// Process audio callback for sample-accurate timing
    public func processAudioCallback(frameCount: Int) {
        guard isRunning else { return }
        
        let startSample = currentSamplePosition
        let endSample = startSample + Int64(frameCount)
        
        // Check for tick events within this audio buffer
        while nextTickSamplePosition < endSample {
            // Calculate swing offset
            let swingOffset = SwingCalculator.calculateSwingOffset(
                tick: Int(currentTick),
                swingAmount: config.swingAmount,
                clockResolution: config.clockResolution
            )
            
            // Apply swing offset to sample position
            let adjustedSamplePosition = nextTickSamplePosition + Int64(swingOffset)
            
            // Update position
            updateCurrentPosition()
            
            // Send clock events
            sendClockEvents()
            
            // Check for loop
            if loopEnabled {
                checkLoopBoundaries()
            }
            
            // Advance to next tick
            currentTick += 1
            calculateNextTickPosition()
        }
        
        currentSamplePosition = endSample
    }
    
    /// Set audio callback handler
    public func setAudioCallbackHandler(_ handler: @escaping (Int) -> Void) {
        audioCallbackHandler = handler
    }
    
    // MARK: - MIDI Clock Integration
    
    /// Process incoming MIDI clock
    public func processMIDIClockMessage() {
        guard config.midiClockInputEnabled else { return }
        
        if let detectedTempo = midiClockHandler.processMIDIClockMessage() {
            // Sync to external MIDI clock
            setTempo(detectedTempo)
        }
    }
    
    /// Process MIDI start message
    public func processMIDIStart() {
        guard config.midiClockInputEnabled else { return }
        stop()
        play()
    }
    
    /// Process MIDI stop message
    public func processMIDIStop() {
        guard config.midiClockInputEnabled else { return }
        stop()
    }
    
    /// Process MIDI continue message
    public func processMIDIContinue() {
        guard config.midiClockInputEnabled else { return }
        continue()
    }
    
    // MARK: - Loop Control
    
    /// Set loop points
    public func setLoop(start: ClockPosition, end: ClockPosition) {
        loopStartPosition = start
        loopEndPosition = end
    }
    
    /// Enable/disable loop
    public func setLoopEnabled(_ enabled: Bool) {
        loopEnabled = enabled
    }
    
    // MARK: - Private Implementation
    
    private func updateInternalTiming() {
        calculateNextTickPosition()
    }
    
    private func calculateNextTickPosition() {
        nextTickSamplePosition = highPrecisionTimer.calculateSamplePosition(
            tick: currentTick + 1,
            tempo: config.tempo,
            clockResolution: config.clockResolution
        )
    }
    
    private func updateCurrentPosition() {
        currentPosition = ClockPosition(totalTicks: currentTick, config: config)
        currentPosition.samplePosition = currentSamplePosition
    }
    
    private func sendClockEvents() {
        // Send tick event
        clockEventPublisher.send(.tick(position: currentPosition))
        
        // Check for beat event
        let beatTick = (currentTick / Int64(config.clockResolution)) * Int64(config.clockResolution)
        if beatTick != lastBeatTick && currentTick % Int64(config.clockResolution) == 0 {
            lastBeatTick = beatTick
            clockEventPublisher.send(.beat(position: currentPosition))
        }
        
        // Check for bar event
        let ticksPerBar = Int64(config.clockResolution * config.timeSignatureNumerator)
        let barTick = (currentTick / ticksPerBar) * ticksPerBar
        if barTick != lastBarTick && currentTick % ticksPerBar == 0 {
            lastBarTick = barTick
            clockEventPublisher.send(.bar(position: currentPosition))
        }
    }
    
    private func checkLoopBoundaries() {
        guard let loopStart = loopStartPosition,
              let loopEnd = loopEndPosition else { return }
        
        if currentPosition.totalTicks >= loopEnd.totalTicks {
            seek(to: loopStart)
        }
    }
    
    private func startMIDIClockOutput() {
        guard config.midiClockOutputEnabled else { return }
        
        midiClockHandler.startMIDIClockOutput(tempo: config.tempo) { [weak self] in
            // Send MIDI clock message
            self?.sendMIDIClockMessage()
        }
    }
    
    private func stopMIDIClockOutput() {
        midiClockHandler.stopMIDIClockOutput()
    }
    
    private func updateMIDIClockOutput() {
        if config.midiClockOutputEnabled && transportState.isPlaying {
            startMIDIClockOutput()
        }
    }
    
    private func sendMIDIClockMessage() {
        // This would send actual MIDI clock messages
        // Implementation depends on MIDI output system
    }
}

// MARK: - Clock Utilities

extension SequencerClock {
    
    /// Convert samples to musical time
    public func samplesToPosition(samples: Int64) -> ClockPosition {
        let samplesPerTick = (sampleRate * 60.0) / (config.tempo * Double(config.clockResolution))
        let ticks = Int64(Double(samples) / samplesPerTick)
        return ClockPosition(totalTicks: ticks, config: config)
    }
    
    /// Convert musical time to samples
    public func positionToSamples(position: ClockPosition) -> Int64 {
        return highPrecisionTimer.calculateSamplePosition(
            tick: position.totalTicks,
            tempo: config.tempo,
            clockResolution: config.clockResolution
        )
    }
    
    /// Get current tempo in BPM
    public var currentTempo: Double {
        return config.tempo
    }
    
    /// Get current time signature
    public var currentTimeSignature: (Int, Int) {
        return (config.timeSignatureNumerator, config.timeSignatureDenominator)
    }
    
    /// Calculate bars per minute
    public var barsPerMinute: Double {
        return config.tempo / Double(config.timeSignatureNumerator)
    }
    
    /// Calculate beats per second
    public var beatsPerSecond: Double {
        return config.tempo / 60.0
    }
}

// MARK: - Clock Status

extension SequencerClock {
    
    /// Get comprehensive clock status
    public var clockStatus: ClockStatus {
        return ClockStatus(
            transportState: transportState,
            position: currentPosition,
            tempo: config.tempo,
            timeSignature: (config.timeSignatureNumerator, config.timeSignatureDenominator),
            swingAmount: config.swingAmount,
            isRunning: isRunning,
            loopEnabled: loopEnabled,
            midiClockInput: config.midiClockInputEnabled,
            midiClockOutput: config.midiClockOutputEnabled
        )
    }
}

/// Clock status information
public struct ClockStatus {
    public let transportState: TransportState
    public let position: ClockPosition
    public let tempo: Double
    public let timeSignature: (Int, Int)
    public let swingAmount: Float
    public let isRunning: Bool
    public let loopEnabled: Bool
    public let midiClockInput: Bool
    public let midiClockOutput: Bool
    
    public init(
        transportState: TransportState,
        position: ClockPosition,
        tempo: Double,
        timeSignature: (Int, Int),
        swingAmount: Float,
        isRunning: Bool,
        loopEnabled: Bool,
        midiClockInput: Bool,
        midiClockOutput: Bool
    ) {
        self.transportState = transportState
        self.position = position
        self.tempo = tempo
        self.timeSignature = timeSignature
        self.swingAmount = swingAmount
        self.isRunning = isRunning
        self.loopEnabled = loopEnabled
        self.midiClockInput = midiClockInput
        self.midiClockOutput = midiClockOutput
    }
}