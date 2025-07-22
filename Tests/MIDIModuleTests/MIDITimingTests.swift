import XCTest
import CoreAudio
@testable import MIDIModule
@testable import SequencerModule
@testable import AudioEngine

class MIDITimingTests: XCTestCase {
    var midiClock: MIDIClock!
    var sequencer: SequencerCore!
    var mockDelegate: MockMIDIClockDelegate!
    
    override func setUp() {
        super.setUp()
        midiClock = MIDIClock()
        sequencer = SequencerCore.shared
        mockDelegate = MockMIDIClockDelegate()
        midiClock.delegate = mockDelegate
    }
    
    override func tearDown() {
        midiClock.stop()
        sequencer.stop()
        midiClock = nil
        sequencer = nil
        mockDelegate = nil
        super.tearDown()
    }
    
    // MARK: - MIDI Clock Generation Tests
    
    func testMIDIClockGeneration() {
        // Test generating MIDI clock at various tempos
        let tempos: [Double] = [60, 120, 140, 174] // Various BPMs
        
        for bpm in tempos {
            mockDelegate.reset()
            midiClock.setBPM(bpm)
            midiClock.start()
            
            // Run for 1 second
            Thread.sleep(forTimeInterval: 1.0)
            midiClock.stop()
            
            // Verify clock pulses
            let expectedPulses = Int(bpm / 60.0 * 24) // 24 PPQ
            let actualPulses = mockDelegate.clockPulseCount
            
            XCTAssertEqual(actualPulses, expectedPulses, accuracy: 2, "Clock generation inaccurate at \(bpm) BPM")
        }
    }
    
    func testMIDIClockStability() {
        // Test clock stability over extended period
        midiClock.setBPM(120)
        midiClock.start()
        
        var intervals: [TimeInterval] = []
        mockDelegate.clockHandler = { timestamp in
            intervals.append(timestamp)
        }
        
        // Run for 10 seconds
        Thread.sleep(forTimeInterval: 10.0)
        midiClock.stop()
        
        // Calculate interval variations
        let intervalDiffs = calculateIntervalDifferences(intervals)
        let averageInterval = intervalDiffs.reduce(0, +) / Double(intervalDiffs.count)
        let maxDeviation = intervalDiffs.map { abs($0 - averageInterval) }.max() ?? 0
        
        // Verify stability
        XCTAssertLessThan(maxDeviation, 0.001, "Clock instability detected: \(maxDeviation * 1000)ms deviation")
    }
    
    // MARK: - MIDI Clock Reception Tests
    
    func testMIDIClockReception() {
        // Test receiving external MIDI clock
        let externalBPM = 125.0
        let ppq = 24
        let interval = 60.0 / (externalBPM * Double(ppq))
        
        midiClock.startReceiving()
        
        // Simulate external clock
        for _ in 0..<(ppq * 4) { // 4 beats
            midiClock.receiveClock(timestamp: CACurrentMediaTime())
            Thread.sleep(forTimeInterval: interval)
        }
        
        // Verify detected tempo
        let detectedBPM = midiClock.getDetectedBPM()
        XCTAssertNotNil(detectedBPM)
        XCTAssertEqual(detectedBPM!, externalBPM, accuracy: 0.5, "Failed to accurately detect external tempo")
    }
    
    func testMIDIClockJitterCompensation() {
        // Test compensation for jittery external clock
        let targetBPM = 120.0
        let ppq = 24
        let baseInterval = 60.0 / (targetBPM * Double(ppq))
        
        midiClock.startReceiving()
        midiClock.enableJitterCompensation(true)
        
        // Send clock with jitter
        for i in 0..<(ppq * 8) { // 8 beats
            let jitter = Double.random(in: -0.002...0.002) // ±2ms jitter
            midiClock.receiveClock(timestamp: CACurrentMediaTime())
            Thread.sleep(forTimeInterval: baseInterval + jitter)
        }
        
        // Verify compensation worked
        let compensatedBPM = midiClock.getDetectedBPM()
        XCTAssertNotNil(compensatedBPM)
        XCTAssertEqual(compensatedBPM!, targetBPM, accuracy: 1.0, "Jitter compensation failed")
        
        // Check smoothed intervals
        let smoothedIntervals = mockDelegate.smoothedIntervals
        let variance = calculateVariance(smoothedIntervals)
        XCTAssertLessThan(variance, 0.0001, "Jitter compensation insufficient")
    }
    
    // MARK: - Transport Control Tests
    
    func testMIDITransportMessages() {
        // Test MIDI transport control messages
        var transportState: MIDITransportState = .stopped
        
        mockDelegate.transportHandler = { state in
            transportState = state
        }
        
        // Test Start
        midiClock.receiveTransportMessage(.start)
        XCTAssertEqual(transportState, .playing)
        XCTAssertTrue(midiClock.isPlaying)
        
        // Test Stop
        midiClock.receiveTransportMessage(.stop)
        XCTAssertEqual(transportState, .stopped)
        XCTAssertFalse(midiClock.isPlaying)
        
        // Test Continue
        midiClock.receiveTransportMessage(.continue)
        XCTAssertEqual(transportState, .continuing)
        XCTAssertTrue(midiClock.isPlaying)
    }
    
    func testSongPositionPointer() {
        // Test MIDI Song Position Pointer handling
        midiClock.receiveSongPositionPointer(beats: 16)
        
        XCTAssertEqual(midiClock.currentPosition, 16)
        XCTAssertEqual(mockDelegate.lastSongPosition, 16)
    }
    
    // MARK: - Sequencer Integration Tests
    
    func testSequencerMIDIClockSync() {
        // Test sequencer syncing to MIDI clock
        sequencer.setSyncMode(.external)
        
        // Start external clock
        let externalBPM = 130.0
        simulateExternalClock(bpm: externalBPM, duration: 2.0)
        
        // Verify sequencer matched tempo
        XCTAssertEqual(sequencer.currentBPM, externalBPM, accuracy: 1.0)
        XCTAssertTrue(sequencer.isPlaying)
    }
    
    func testSequencerMIDIClockOutput() {
        // Test sequencer generating MIDI clock
        sequencer.setSyncMode(.internal)
        sequencer.setBPM(140)
        sequencer.enableMIDIClockOutput(true)
        
        var outputClockCount = 0
        mockDelegate.clockHandler = { _ in
            outputClockCount += 1
        }
        
        sequencer.play()
        Thread.sleep(forTimeInterval: 1.0)
        sequencer.stop()
        
        // Verify clock output
        let expectedClocks = Int(140.0 / 60.0 * 24) // 24 PPQ for 1 second
        XCTAssertEqual(outputClockCount, expectedClocks, accuracy: 2)
    }
    
    // MARK: - Phase Sync Tests
    
    func testBeatPhaseAlignment() {
        // Test beat phase alignment when syncing
        midiClock.startReceiving()
        
        // Send clock with beat markers
        for beat in 0..<4 {
            for pulse in 0..<24 {
                let isBeat = pulse == 0
                midiClock.receiveClock(timestamp: CACurrentMediaTime(), isBeat: isBeat)
                
                if isBeat {
                    XCTAssertEqual(midiClock.currentBeat, beat + 1)
                }
                
                Thread.sleep(forTimeInterval: 0.0208) // 120 BPM
            }
        }
        
        // Verify phase alignment
        XCTAssertEqual(midiClock.beatPhase, 0.0, accuracy: 0.01)
    }
    
    func testStartQuantization() {
        // Test quantized start on beat boundaries
        midiClock.setStartQuantization(.beat)
        midiClock.setBPM(120)
        
        // Start clock off-beat
        let startTime = CACurrentMediaTime()
        midiClock.start()
        
        // Verify first clock pulse is quantized
        let firstPulseTime = mockDelegate.firstClockTimestamp
        let expectedBeatTime = ceil(startTime * 2) / 2 // Next beat at 120 BPM
        
        XCTAssertEqual(firstPulseTime, expectedBeatTime, accuracy: 0.01)
    }
    
    // MARK: - Tempo Change Tests
    
    func testSmoothTempoTransition() {
        // Test smooth tempo transitions
        midiClock.setBPM(120)
        midiClock.setTempoSmoothing(true, rampTime: 1.0)
        midiClock.start()
        
        var tempoSamples: [Double] = []
        mockDelegate.tempoChangeHandler = { tempo in
            tempoSamples.append(tempo)
        }
        
        // Change tempo
        midiClock.setBPM(140)
        
        // Sample tempo during transition
        for _ in 0..<20 {
            Thread.sleep(forTimeInterval: 0.05)
            tempoSamples.append(midiClock.currentBPM)
        }
        
        // Verify smooth transition
        for i in 1..<tempoSamples.count {
            let tempoDiff = abs(tempoSamples[i] - tempoSamples[i-1])
            XCTAssertLessThan(tempoDiff, 5.0, "Tempo transition not smooth")
        }
        
        // Verify final tempo
        XCTAssertEqual(midiClock.currentBPM, 140, accuracy: 0.1)
    }
    
    func testInstantTempoChange() {
        // Test instant tempo changes
        midiClock.setBPM(100)
        midiClock.setTempoSmoothing(false)
        midiClock.start()
        
        Thread.sleep(forTimeInterval: 0.1)
        
        // Change tempo instantly
        midiClock.setBPM(160)
        
        // Verify immediate change
        XCTAssertEqual(midiClock.currentBPM, 160)
        XCTAssertEqual(mockDelegate.lastTempo, 160)
    }
    
    // MARK: - Sync Error Recovery Tests
    
    func testClockDropoutRecovery() {
        // Test recovery from clock dropouts
        midiClock.startReceiving()
        midiClock.setDropoutTolerance(500) // 500ms tolerance
        
        let normalInterval = 0.0208 // 120 BPM, 24 PPQ
        
        // Send normal clock
        for _ in 0..<24 {
            midiClock.receiveClock(timestamp: CACurrentMediaTime())
            Thread.sleep(forTimeInterval: normalInterval)
        }
        
        // Simulate dropout
        Thread.sleep(forTimeInterval: 0.3)
        
        // Resume clock
        var recoveredSync = false
        mockDelegate.syncRecoveredHandler = {
            recoveredSync = true
        }
        
        for _ in 0..<24 {
            midiClock.receiveClock(timestamp: CACurrentMediaTime())
            Thread.sleep(forTimeInterval: normalInterval)
        }
        
        XCTAssertTrue(recoveredSync, "Failed to recover from clock dropout")
        XCTAssertTrue(midiClock.isSynced)
    }
    
    func testClockDriftCorrection() {
        // Test correction of gradual clock drift
        midiClock.startReceiving()
        midiClock.enableDriftCorrection(true)
        
        let targetBPM = 120.0
        let baseInterval = 60.0 / (targetBPM * 24)
        
        // Send clock with gradual drift
        var currentInterval = baseInterval
        for i in 0..<(24 * 16) { // 16 beats
            midiClock.receiveClock(timestamp: CACurrentMediaTime())
            
            // Introduce gradual drift
            currentInterval += 0.00001 // Gradually slow down
            Thread.sleep(forTimeInterval: currentInterval)
        }
        
        // Verify drift was corrected
        let correctedBPM = midiClock.getDetectedBPM() ?? 0
        XCTAssertEqual(correctedBPM, targetBPM, accuracy: 2.0, "Drift correction failed")
    }
}

// MARK: - Helper Functions

extension MIDITimingTests {
    func calculateIntervalDifferences(_ timestamps: [TimeInterval]) -> [TimeInterval] {
        guard timestamps.count > 1 else { return [] }
        
        var intervals: [TimeInterval] = []
        for i in 1..<timestamps.count {
            intervals.append(timestamps[i] - timestamps[i-1])
        }
        return intervals
    }
    
    func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / Double(values.count)
    }
    
    func simulateExternalClock(bpm: Double, duration: TimeInterval) {
        let ppq = 24
        let interval = 60.0 / (bpm * Double(ppq))
        let pulseCount = Int(duration * bpm / 60.0 * Double(ppq))
        
        for _ in 0..<pulseCount {
            midiClock.receiveClock(timestamp: CACurrentMediaTime())
            Thread.sleep(forTimeInterval: interval)
        }
    }
}

// MARK: - Mock Objects

class MockMIDIClockDelegate: MIDIClockDelegate {
    var clockPulseCount = 0
    var clockHandler: ((TimeInterval) -> Void)?
    var transportHandler: ((MIDITransportState) -> Void)?
    var tempoChangeHandler: ((Double) -> Void)?
    var syncRecoveredHandler: (() -> Void)?
    var firstClockTimestamp: TimeInterval = 0
    var lastSongPosition: Int = 0
    var lastTempo: Double = 0
    var smoothedIntervals: [TimeInterval] = []
    
    func reset() {
        clockPulseCount = 0
        firstClockTimestamp = 0
        lastSongPosition = 0
        lastTempo = 0
        smoothedIntervals.removeAll()
    }
    
    func midiClock(_ clock: MIDIClock, receivedClockPulse timestamp: TimeInterval) {
        clockPulseCount += 1
        if firstClockTimestamp == 0 {
            firstClockTimestamp = timestamp
        }
        clockHandler?(timestamp)
    }
    
    func midiClock(_ clock: MIDIClock, transportStateChanged state: MIDITransportState) {
        transportHandler?(state)
    }
    
    func midiClock(_ clock: MIDIClock, tempoChanged bpm: Double) {
        lastTempo = bpm
        tempoChangeHandler?(bpm)
    }
    
    func midiClock(_ clock: MIDIClock, songPositionChanged position: Int) {
        lastSongPosition = position
    }
    
    func midiClock(_ clock: MIDIClock, smoothedInterval interval: TimeInterval) {
        smoothedIntervals.append(interval)
    }
    
    func midiClockSyncRecovered(_ clock: MIDIClock) {
        syncRecoveredHandler?()
    }
}

// MARK: - MIDI Clock Implementation

class MIDIClock {
    weak var delegate: MIDIClockDelegate?
    
    private(set) var isPlaying = false
    private(set) var isSynced = false
    private(set) var currentBPM: Double = 120.0
    private(set) var currentBeat = 0
    private(set) var currentPosition = 0
    private(set) var beatPhase: Double = 0.0
    
    private var clockTimer: Timer?
    private var isReceiving = false
    private var lastClockTime: TimeInterval = 0
    private var clockIntervals: [TimeInterval] = []
    private var jitterCompensation = false
    private var driftCorrection = false
    private var tempoSmoothing = false
    private var smoothingRampTime: TimeInterval = 1.0
    private var startQuantization: StartQuantization = .none
    private var dropoutTolerance: TimeInterval = 1.0
    
    enum StartQuantization {
        case none, beat, bar
    }
    
    func setBPM(_ bpm: Double) {
        if tempoSmoothing && isPlaying {
            smoothTransitionToBPM(bpm)
        } else {
            currentBPM = bpm
            delegate?.midiClock(self, tempoChanged: bpm)
            restartClockTimer()
        }
    }
    
    func start() {
        isPlaying = true
        
        switch startQuantization {
        case .none:
            startClockTimer()
        case .beat:
            let beatInterval = 60.0 / currentBPM
            let currentTime = CACurrentMediaTime()
            let nextBeat = ceil(currentTime / beatInterval) * beatInterval
            let delay = nextBeat - currentTime
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.startClockTimer()
            }
        case .bar:
            // Similar to beat but quantized to bar boundaries
            break
        }
    }
    
    func stop() {
        isPlaying = false
        clockTimer?.invalidate()
        clockTimer = nil
    }
    
    func startReceiving() {
        isReceiving = true
        clockIntervals.removeAll()
        lastClockTime = 0
    }
    
    func receiveClock(timestamp: TimeInterval, isBeat: Bool = false) {
        guard isReceiving else { return }
        
        if lastClockTime > 0 {
            let interval = timestamp - lastClockTime
            
            // Check for dropout
            if interval > dropoutTolerance {
                handleClockDropout()
                return
            }
            
            if jitterCompensation {
                let smoothedInterval = applyJitterCompensation(interval)
                clockIntervals.append(smoothedInterval)
                delegate?.midiClock(self, smoothedInterval: smoothedInterval)
            } else {
                clockIntervals.append(interval)
            }
            
            updateDetectedTempo()
        }
        
        lastClockTime = timestamp
        
        if isBeat {
            currentBeat += 1
            beatPhase = 0.0
        }
        
        delegate?.midiClock(self, receivedClockPulse: timestamp)
    }
    
    func receiveTransportMessage(_ message: MIDITransportMessage) {
        switch message {
        case .start:
            isPlaying = true
            currentPosition = 0
            currentBeat = 0
            delegate?.midiClock(self, transportStateChanged: .playing)
            
        case .stop:
            isPlaying = false
            delegate?.midiClock(self, transportStateChanged: .stopped)
            
        case .continue:
            isPlaying = true
            delegate?.midiClock(self, transportStateChanged: .continuing)
        }
    }
    
    func receiveSongPositionPointer(beats: Int) {
        currentPosition = beats
        delegate?.midiClock(self, songPositionChanged: beats)
    }
    
    func getDetectedBPM() -> Double? {
        guard !clockIntervals.isEmpty else { return nil }
        
        let averageInterval = clockIntervals.suffix(24).reduce(0, +) / Double(min(clockIntervals.count, 24))
        let bpm = 60.0 / (averageInterval * 24) // 24 PPQ
        
        return bpm
    }
    
    // Configuration methods
    
    func enableJitterCompensation(_ enable: Bool) {
        jitterCompensation = enable
    }
    
    func enableDriftCorrection(_ enable: Bool) {
        driftCorrection = enable
    }
    
    func setTempoSmoothing(_ enable: Bool, rampTime: TimeInterval = 1.0) {
        tempoSmoothing = enable
        smoothingRampTime = rampTime
    }
    
    func setStartQuantization(_ quantization: StartQuantization) {
        startQuantization = quantization
    }
    
    func setDropoutTolerance(_ milliseconds: TimeInterval) {
        dropoutTolerance = milliseconds / 1000.0
    }
    
    // Private methods
    
    private func startClockTimer() {
        let interval = 60.0 / (currentBPM * 24) // 24 PPQ
        
        clockTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.delegate?.midiClock(self, receivedClockPulse: CACurrentMediaTime())
        }
    }
    
    private func restartClockTimer() {
        guard isPlaying else { return }
        clockTimer?.invalidate()
        startClockTimer()
    }
    
    private func smoothTransitionToBPM(_ targetBPM: Double) {
        let startBPM = currentBPM
        let startTime = CACurrentMediaTime()
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            let elapsed = CACurrentMediaTime() - startTime
            let progress = min(elapsed / self.smoothingRampTime, 1.0)
            
            self.currentBPM = startBPM + (targetBPM - startBPM) * progress
            self.delegate?.midiClock(self, tempoChanged: self.currentBPM)
            
            if progress >= 1.0 {
                timer.invalidate()
                self.restartClockTimer()
            }
        }
    }
    
    private func applyJitterCompensation(_ interval: TimeInterval) -> TimeInterval {
        // Simple moving average filter
        let windowSize = 8
        let recentIntervals = clockIntervals.suffix(windowSize) + [interval]
        return recentIntervals.reduce(0, +) / Double(recentIntervals.count)
    }
    
    private func updateDetectedTempo() {
        guard driftCorrection else { return }
        
        if let detectedBPM = getDetectedBPM() {
            let drift = abs(detectedBPM - currentBPM)
            if drift > 1.0 {
                // Apply gradual correction
                currentBPM = currentBPM * 0.95 + detectedBPM * 0.05
                delegate?.midiClock(self, tempoChanged: currentBPM)
            }
        }
    }
    
    private func handleClockDropout() {
        isSynced = false
        // Wait for stable clock before declaring sync recovered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.isReceiving && !self.clockIntervals.isEmpty {
                self.isSynced = true
                self.delegate?.midiClockSyncRecovered(self)
            }
        }
    }
}

// MARK: - Protocol Definitions

protocol MIDIClockDelegate: AnyObject {
    func midiClock(_ clock: MIDIClock, receivedClockPulse timestamp: TimeInterval)
    func midiClock(_ clock: MIDIClock, transportStateChanged state: MIDITransportState)
    func midiClock(_ clock: MIDIClock, tempoChanged bpm: Double)
    func midiClock(_ clock: MIDIClock, songPositionChanged position: Int)
    func midiClock(_ clock: MIDIClock, smoothedInterval interval: TimeInterval)
    func midiClockSyncRecovered(_ clock: MIDIClock)
}

enum MIDITransportState {
    case stopped, playing, continuing
}

enum MIDITransportMessage {
    case start, stop, `continue`
}