// MIDIClockSync.swift
// DigitonePad - MIDIModule
//
// MIDI clock synchronization for external timing and transport control

import Foundation
import CoreAudio
import MachineProtocols
import QuartzCore

/// MIDI clock synchronization manager
public final class MIDIClockSync: @unchecked Sendable {
    
    // MARK: - Properties
    
    weak var delegate: MIDIClockSyncDelegate?
    
    private let lock = NSLock()
    private var isReceivingClock = false
    private var isGeneratingClock = false
    private var syncMode: SyncMode = .internal
    
    // Clock timing
    private var currentBPM: Double = 120.0
    private var currentPosition: Int = 0
    private var beatPosition: Double = 0.0
    private var isPlaying = false
    private var isSynced = false
    
    // Clock reception
    private var lastClockTime: TimeInterval = 0
    private var clockIntervals: [TimeInterval] = []
    private var clockHistory: CircularBuffer<TimeInterval>
    private var jitterCompensation = true
    private var driftCorrection = true
    private var dropoutTolerance: TimeInterval = 0.5
    
    // Clock generation
    private var clockTimer: Timer?
    private var ppq: Int = 24 // Pulses per quarter note
    private var startQuantization: StartQuantization = .none
    private var tempoSmoothing = false
    private var smoothingRampTime: TimeInterval = 1.0
    
    // Transport state
    private var transportState: TransportState = .stopped
    private var lastTransportMessage: TransportMessage?
    
    // Performance monitoring
    private var clockAccuracy: ClockAccuracy
    private var syncStatistics: SyncStatistics
    
    // MARK: - Initialization
    
    public init() {
        clockHistory = CircularBuffer<TimeInterval>(capacity: 96) // 4 beats worth at 24 PPQ
        clockAccuracy = ClockAccuracy()
        syncStatistics = SyncStatistics()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public Interface
    
    /// Current BPM (detected or set)
    public var detectedBPM: Double {
        lock.lock()
        defer { lock.unlock() }
        return currentBPM
    }
    
    /// Current playing state
    public var playingState: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isPlaying
    }
    
    /// Current sync state
    public var syncState: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isSynced
    }
    
    /// Set sync mode
    public func setSyncMode(_ mode: SyncMode) {
        lock.lock()
        defer { lock.unlock() }
        
        syncMode = mode
        
        switch mode {
        case .`internal`:
            stopReceivingClock()
            startGeneratingClock()
        case .external:
            stopGeneratingClock()
            startReceivingClock()
        case .auto:
            // Start receiving and generate if no external clock detected
            startReceivingClock()
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if !self.isSynced {
                    self.startGeneratingClock()
                }
            }
        }
    }
    
    /// Set internal BPM (for internal sync mode)
    public func setBPM(_ bpm: Double) {
        guard bpm > 0 && bpm <= 999 else { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        if tempoSmoothing && isPlaying {
            smoothTransitionToBPM(bpm)
        } else {
            currentBPM = bpm
            delegate?.midiClockSync(self, tempoChanged: bpm)
            
            if syncMode == .internal && isGeneratingClock {
                restartClockGeneration()
            }
        }
    }
    
    /// Start playback
    public func start() {
        lock.lock()
        defer { lock.unlock() }
        
        isPlaying = true
        transportState = .playing
        
        if syncMode == .`internal` || (syncMode == .auto && !isSynced) {
            startClockGeneration()
        }
        
        delegate?.midiClockSync(self, transportStateChanged: .playing)
    }
    
    /// Stop playback
    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        isPlaying = false
        transportState = .stopped
        currentPosition = 0
        beatPosition = 0.0
        
        stopClockGeneration()
        
        delegate?.midiClockSync(self, transportStateChanged: .stopped)
    }
    
    /// Continue playback from current position
    public func `continue`() {
        lock.lock()
        defer { lock.unlock() }
        
        isPlaying = true
        transportState = .continuing
        
        if syncMode == .`internal` || (syncMode == .auto && !isSynced) {
            startClockGeneration()
        }
        
        delegate?.midiClockSync(self, transportStateChanged: .continuing)
    }
    
    // MARK: - External Clock Reception
    
    /// Process incoming MIDI clock message
    public func receiveClock(timestamp: TimeInterval) {
        guard isReceivingClock else { return }
        
        let currentTime = timestamp
        
        // Check for dropout
        if lastClockTime > 0 {
            let interval = currentTime - lastClockTime
            
            if interval > dropoutTolerance {
                handleClockDropout()
                return
            }
            
            // Apply jitter compensation
            let processedInterval = jitterCompensation ? applyJitterCompensation(interval) : interval
            
            // Add to history
            clockHistory.append(processedInterval)
            clockIntervals.append(processedInterval)
            
            // Keep history manageable
            if clockIntervals.count > 96 {
                clockIntervals.removeFirst(24)
            }
            
            // Update detected tempo
            updateDetectedTempo()
            
            // Update position
            updatePositionFromClock()
        }
        
        lastClockTime = currentTime
        
        // Mark as synced if we have stable clock
        if !isSynced && clockIntervals.count >= 24 {
            let variance = calculateClockVariance()
            if variance < 0.001 { // Less than 1ms variance
                isSynced = true
                delegate?.midiClockSyncAcquired(self)
            }
        }
        
        // Update accuracy statistics
        clockAccuracy.recordClockPulse(timestamp)
        
        delegate?.midiClockSync(self, receivedClockPulse: timestamp)
    }
    
    /// Process incoming transport message
    public func receiveTransportMessage(_ message: TransportMessage, timestamp: TimeInterval = CACurrentMediaTime()) {
        lock.lock()
        defer { lock.unlock() }
        
        lastTransportMessage = message
        
        switch message {
        case .start:
            currentPosition = 0
            beatPosition = 0.0
            isPlaying = true
            transportState = .playing
            delegate?.midiClockSync(self, transportStateChanged: .playing)
            
        case .`continue`:
            isPlaying = true
            transportState = .continuing
            delegate?.midiClockSync(self, transportStateChanged: .continuing)
            
        case .stop:
            isPlaying = false
            transportState = .stopped
            delegate?.midiClockSync(self, transportStateChanged: .stopped)
        }
        
        syncStatistics.transportMessageCount += 1
    }
    
    /// Process song position pointer
    public func receiveSongPositionPointer(beats: Int, timestamp: TimeInterval = CACurrentMediaTime()) {
        lock.lock()
        defer { lock.unlock() }
        
        currentPosition = beats
        beatPosition = Double(beats)
        
        delegate?.midiClockSync(self, songPositionChanged: beats)
    }
    
    // MARK: - Configuration
    
    /// Enable/disable jitter compensation
    public func setJitterCompensation(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        jitterCompensation = enabled
    }
    
    /// Enable/disable drift correction
    public func setDriftCorrection(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        driftCorrection = enabled
    }
    
    /// Set dropout tolerance in seconds
    public func setDropoutTolerance(_ seconds: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        dropoutTolerance = max(0.1, min(5.0, seconds))
    }
    
    /// Set tempo smoothing
    public func setTempoSmoothing(_ enabled: Bool, rampTime: TimeInterval = 1.0) {
        lock.lock()
        defer { lock.unlock() }
        tempoSmoothing = enabled
        smoothingRampTime = max(0.1, min(10.0, rampTime))
    }
    
    /// Set start quantization
    public func setStartQuantization(_ quantization: StartQuantization) {
        lock.lock()
        defer { lock.unlock() }
        startQuantization = quantization
    }
    
    // MARK: - Statistics
    
    /// Get current clock accuracy
    public func getClockAccuracy() -> ClockAccuracyReport {
        lock.lock()
        defer { lock.unlock() }
        return clockAccuracy.generateReport()
    }
    
    /// Get synchronization statistics
    public func getSyncStatistics() -> SyncStatistics {
        lock.lock()
        defer { lock.unlock() }
        return syncStatistics
    }
    
    /// Get current timing information
    public func getTimingInfo() -> TimingInfo {
        lock.lock()
        defer { lock.unlock() }
        
        return TimingInfo(
            bpm: currentBPM,
            position: currentPosition,
            beatPosition: beatPosition,
            isPlaying: isPlaying,
            isSynced: isSynced,
            syncMode: syncMode,
            transportState: transportState
        )
    }
    
    // MARK: - Private Implementation
    
    private func startReceivingClock() {
        isReceivingClock = true
        lastClockTime = 0
        clockIntervals.removeAll()
        clockHistory.clear()
        isSynced = false
        clockAccuracy.reset()
    }
    
    private func stopReceivingClock() {
        isReceivingClock = false
        isSynced = false
    }
    
    private func startGeneratingClock() {
        guard syncMode == .`internal` || (syncMode == .auto && !isSynced) else { return }
        isGeneratingClock = true
        startClockGeneration()
    }
    
    private func stopGeneratingClock() {
        isGeneratingClock = false
        stopClockGeneration()
    }
    
    private func startClockGeneration() {
        guard isGeneratingClock else { return }
        
        let interval = 60.0 / (currentBPM * Double(ppq))
        
        switch startQuantization {
        case .none:
            scheduleClockPulses(interval: interval)
        case .beat:
            let beatInterval = 60.0 / currentBPM
            let currentTime = CACurrentMediaTime()
            let nextBeat = ceil(currentTime / beatInterval) * beatInterval
            let delay = nextBeat - currentTime
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.scheduleClockPulses(interval: interval)
            }
        case .bar:
            // Similar to beat but for bar boundaries
            let barInterval = 240.0 / currentBPM // 4 beats per bar
            let currentTime = CACurrentMediaTime()
            let nextBar = ceil(currentTime / barInterval) * barInterval
            let delay = nextBar - currentTime
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.scheduleClockPulses(interval: interval)
            }
        }
    }
    
    private func stopClockGeneration() {
        clockTimer?.invalidate()
        clockTimer = nil
    }
    
    private func restartClockGeneration() {
        stopClockGeneration()
        if isPlaying && isGeneratingClock {
            startClockGeneration()
        }
    }
    
    private func scheduleClockPulses(interval: TimeInterval) {
        clockTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let timestamp = CACurrentMediaTime()
            self.delegate?.midiClockSync(self, generatedClockPulse: timestamp)
            
            // Update position
            self.lock.lock()
            self.currentPosition += 1
            self.beatPosition = Double(self.currentPosition) / Double(self.ppq)
            self.lock.unlock()
        }
    }
    
    private func updateDetectedTempo() {
        guard clockIntervals.count >= 24 else { return }
        
        let recentIntervals = Array(clockIntervals.suffix(24))
        let averageInterval = recentIntervals.reduce(0, +) / Double(recentIntervals.count)
        let detectedBPM = 60.0 / (averageInterval * Double(ppq))
        
        // Apply drift correction if enabled
        if driftCorrection {
            let drift = abs(detectedBPM - currentBPM)
            if drift > 0.5 && drift < 10.0 { // Reasonable drift range
                currentBPM = currentBPM * 0.95 + detectedBPM * 0.05 // Smooth correction
                delegate?.midiClockSync(self, tempoChanged: currentBPM)
            }
        } else {
            currentBPM = detectedBPM
            delegate?.midiClockSync(self, tempoChanged: currentBPM)
        }
        
        syncStatistics.lastDetectedBPM = detectedBPM
    }
    
    private func updatePositionFromClock() {
        currentPosition += 1
        beatPosition = Double(currentPosition) / Double(ppq)
        
        // Notify on beat boundaries
        if currentPosition % ppq == 0 {
            let beat = currentPosition / ppq
            delegate?.midiClockSync(self, beatChanged: beat)
        }
    }
    
    private func applyJitterCompensation(_ interval: TimeInterval) -> TimeInterval {
        // Simple moving average filter
        let windowSize = min(8, clockHistory.itemCount)
        guard windowSize > 0 else { return interval }
        
        let recentIntervals = clockHistory.recentValues(count: windowSize)
        let averageInterval = recentIntervals.reduce(0, +) / Double(recentIntervals.count)
        
        // Weighted average: 70% history, 30% current
        return averageInterval * 0.7 + interval * 0.3
    }
    
    private func calculateClockVariance() -> Double {
        guard clockIntervals.count >= 24 else { return Double.infinity }
        
        let recentIntervals = Array(clockIntervals.suffix(24))
        let mean = recentIntervals.reduce(0, +) / Double(recentIntervals.count)
        let squaredDifferences = recentIntervals.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(recentIntervals.count)
        
        return variance
    }
    
    private func handleClockDropout() {
        isSynced = false
        delegate?.midiClockSyncLost(self)
        
        syncStatistics.dropoutCount += 1
        
        // Attempt to recover sync after a brief period
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.isReceivingClock && !self.isSynced {
                self.delegate?.midiClockSyncRecovering(self)
            }
        }
    }
    
    private func smoothTransitionToBPM(_ targetBPM: Double) {
        let startBPM = currentBPM
        let startTime = CACurrentMediaTime()
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            let elapsed = CACurrentMediaTime() - startTime
            let progress = min(elapsed / self.smoothingRampTime, 1.0)
            
            self.lock.lock()
            self.currentBPM = startBPM + (targetBPM - startBPM) * progress
            self.lock.unlock()
            
            self.delegate?.midiClockSync(self, tempoChanged: self.currentBPM)
            
            if progress >= 1.0 {
                timer.invalidate()
                self.restartClockGeneration()
            }
        }
    }
}

// MARK: - Supporting Types

/// Sync modes
public enum SyncMode: String, CaseIterable {
    case `internal` = "internal"
    case external = "external"
    case auto = "auto"
}

/// Start quantization options
public enum StartQuantization: String, CaseIterable {
    case none = "none"
    case beat = "beat"
    case bar = "bar"
}

/// Transport states
public enum TransportState: String, CaseIterable {
    case stopped = "stopped"
    case playing = "playing"
    case continuing = "continuing"
}

/// Transport messages
public enum TransportMessage: String, CaseIterable {
    case start = "start"
    case `continue` = "continue"
    case stop = "stop"
}

/// Timing information
public struct TimingInfo {
    public let bpm: Double
    public let position: Int
    public let beatPosition: Double
    public let isPlaying: Bool
    public let isSynced: Bool
    public let syncMode: SyncMode
    public let transportState: TransportState
}

/// Clock accuracy tracking
private class ClockAccuracy {
    private var pulseTimestamps: [TimeInterval] = []
    private var intervals: [TimeInterval] = []
    private var jitter: [TimeInterval] = []
    
    func recordClockPulse(_ timestamp: TimeInterval) {
        pulseTimestamps.append(timestamp)
        
        if pulseTimestamps.count > 1 {
            let interval = timestamp - pulseTimestamps[pulseTimestamps.count - 2]
            intervals.append(interval)
            
            if intervals.count > 1 {
                let expectedInterval = intervals.reduce(0, +) / Double(intervals.count)
                let deviation = abs(interval - expectedInterval)
                jitter.append(deviation)
            }
        }
        
        // Keep history manageable
        if pulseTimestamps.count > 200 {
            pulseTimestamps.removeFirst(50)
            intervals.removeFirst(50)
            jitter.removeFirst(50)
        }
    }
    
    func generateReport() -> ClockAccuracyReport {
        guard !intervals.isEmpty else {
            return ClockAccuracyReport(
                averageInterval: 0,
                intervalVariance: 0,
                maxJitter: 0,
                averageJitter: 0,
                stabilityScore: 0
            )
        }
        
        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.map { pow($0 - averageInterval, 2) }.reduce(0, +) / Double(intervals.count)
        let maxJitter = jitter.max() ?? 0
        let averageJitter = jitter.isEmpty ? 0 : jitter.reduce(0, +) / Double(jitter.count)
        let stabilityScore = max(0, 1.0 - (averageJitter / 0.01)) // 0-1 score, 1 = perfect
        
        return ClockAccuracyReport(
            averageInterval: averageInterval,
            intervalVariance: variance,
            maxJitter: maxJitter,
            averageJitter: averageJitter,
            stabilityScore: stabilityScore
        )
    }
    
    func reset() {
        pulseTimestamps.removeAll()
        intervals.removeAll()
        jitter.removeAll()
    }
}

/// Clock accuracy report
public struct ClockAccuracyReport {
    public let averageInterval: TimeInterval
    public let intervalVariance: TimeInterval
    public let maxJitter: TimeInterval
    public let averageJitter: TimeInterval
    public let stabilityScore: Double // 0.0 to 1.0
}

/// Synchronization statistics
public struct SyncStatistics {
    public var clockPulseCount: Int = 0
    public var transportMessageCount: Int = 0
    public var dropoutCount: Int = 0
    public var syncAcquisitionTime: TimeInterval = 0
    public var lastDetectedBPM: Double = 0
    public var averageLatency: TimeInterval = 0
}

/// Circular buffer for efficient history tracking
private class CircularBuffer<T> {
    private var buffer: [T]
    private var head: Int = 0
    private var tail: Int = 0
    private var count: Int = 0
    private let capacity: Int
    
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array<T?>(repeating: nil, count: capacity) as! [T]
    }
    
    func append(_ element: T) {
        buffer[tail] = element
        tail = (tail + 1) % capacity
        
        if count < capacity {
            count += 1
        } else {
            head = (head + 1) % capacity
        }
    }
    
    func recentValues(count requestedCount: Int) -> [T] {
        let actualCount = min(requestedCount, count)
        var result: [T] = []
        
        for i in 0..<actualCount {
            let index = (tail - actualCount + i + capacity) % capacity
            result.append(buffer[index])
        }
        
        return result
    }
    
    func clear() {
        head = 0
        tail = 0
        count = 0
    }
    
    var itemCount: Int {
        return count
    }
}

// MARK: - Delegate Protocol

/// MIDI clock sync delegate
public protocol MIDIClockSyncDelegate: AnyObject {
    func midiClockSync(_ sync: MIDIClockSync, receivedClockPulse timestamp: TimeInterval)
    func midiClockSync(_ sync: MIDIClockSync, generatedClockPulse timestamp: TimeInterval)
    func midiClockSync(_ sync: MIDIClockSync, transportStateChanged state: TransportState)
    func midiClockSync(_ sync: MIDIClockSync, tempoChanged bpm: Double)
    func midiClockSync(_ sync: MIDIClockSync, songPositionChanged position: Int)
    func midiClockSync(_ sync: MIDIClockSync, beatChanged beat: Int)
    func midiClockSyncAcquired(_ sync: MIDIClockSync)
    func midiClockSyncLost(_ sync: MIDIClockSync)
    func midiClockSyncRecovering(_ sync: MIDIClockSync)
}