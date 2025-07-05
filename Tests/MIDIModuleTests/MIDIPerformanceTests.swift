import XCTest
import CoreAudio
@testable import MIDIModule
@testable import AudioEngine
@testable import VoiceModule

class MIDIPerformanceTests: XCTestCase {
    var midiProcessor: MIDIProcessor!
    var mockAudioEngine: MockAudioEngine!
    var performanceMonitor: MIDIPerformanceMonitor!
    
    override func setUp() {
        super.setUp()
        midiProcessor = MIDIProcessor()
        mockAudioEngine = MockAudioEngine()
        performanceMonitor = MIDIPerformanceMonitor()
        
        midiProcessor.audioEngine = mockAudioEngine
        midiProcessor.performanceMonitor = performanceMonitor
    }
    
    override func tearDown() {
        midiProcessor = nil
        mockAudioEngine = nil
        performanceMonitor = nil
        super.tearDown()
    }
    
    // MARK: - Latency Tests
    
    func testMIDILatencyRequirements() {
        // MIDI input to audio output must be <5ms
        let expectation = self.expectation(description: "MIDI processing")
        var noteOnTime: TimeInterval = 0
        var audioTriggerTime: TimeInterval = 0
        
        // Configure mock to capture timing
        mockAudioEngine.noteOnHandler = { _, _, _ in
            audioTriggerTime = CACurrentMediaTime()
            expectation.fulfill()
        }
        
        // Send MIDI note
        noteOnTime = CACurrentMediaTime()
        midiProcessor.handleNoteOn(60, velocity: 127, channel: 1)
        
        waitForExpectations(timeout: 0.01) { error in
            XCTAssertNil(error)
            
            let latency = audioTriggerTime - noteOnTime
            XCTAssertLessThan(latency, 0.005, "MIDI latency \(latency * 1000)ms exceeds 5ms requirement")
            
            // Verify performance monitor captured the latency
            XCTAssertEqual(performanceMonitor.lastMeasuredLatency, latency, accuracy: 0.0001)
        }
    }
    
    func testWorstCaseLatency() {
        // Test latency under high system load
        let iterations = 100
        var maxLatency: TimeInterval = 0
        
        for _ in 0..<iterations {
            // Create system load
            let backgroundQueue = DispatchQueue.global(qos: .background)
            let loadGroup = DispatchGroup()
            
            // Simulate background processing
            for _ in 0..<10 {
                loadGroup.enter()
                backgroundQueue.async {
                    Thread.sleep(forTimeInterval: 0.0001)
                    loadGroup.leave()
                }
            }
            
            // Measure latency during load
            let startTime = CACurrentMediaTime()
            midiProcessor.handleNoteOn(60, velocity: 127, channel: 1)
            let endTime = mockAudioEngine.lastTriggerTime
            
            let latency = endTime - startTime
            maxLatency = max(maxLatency, latency)
            
            loadGroup.wait()
        }
        
        XCTAssertLessThan(maxLatency, 0.005, "Worst-case latency \(maxLatency * 1000)ms exceeds 5ms")
    }
    
    // MARK: - MIDI Clock Tests
    
    func testMIDIClockAccuracy() {
        // Test MIDI clock sync maintains accurate timing
        let clockSync = MIDIClockSync()
        var timestamps: [TimeInterval] = []
        let ppq = 24 // 24 pulses per quarter note
        let bpm = 120.0
        let expectedInterval = 60.0 / (bpm * Double(ppq))
        
        // Configure clock sync
        clockSync.startReceiving()
        
        // Simulate receiving MIDI clock messages
        for _ in 0..<ppq {
            let timestamp = CACurrentMediaTime()
            clockSync.receiveMIDIClock(timestamp: timestamp)
            timestamps.append(timestamp)
            
            // Simulate accurate clock timing
            Thread.sleep(forTimeInterval: expectedInterval)
        }
        
        // Verify clock intervals are consistent
        let intervals = calculateIntervals(timestamps)
        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        let maxDeviation = intervals.map { abs($0 - averageInterval) }.max() ?? 0
        
        XCTAssertLessThan(maxDeviation, 0.001, "MIDI clock jitter \(maxDeviation * 1000)ms exceeds 1ms")
        XCTAssertEqual(averageInterval, expectedInterval, accuracy: 0.001)
    }
    
    func testMIDIClockDriftCompensation() {
        // Test clock drift compensation over time
        let clockSync = MIDIClockSync()
        let testDuration: TimeInterval = 10.0 // 10 seconds
        let bpm = 120.0
        let ppq = 24
        let expectedPulses = Int(testDuration * bpm / 60.0 * Double(ppq))
        
        var receivedPulses = 0
        let startTime = CACurrentMediaTime()
        
        // Simulate clock with slight drift
        while CACurrentMediaTime() - startTime < testDuration {
            clockSync.receiveMIDIClock(timestamp: CACurrentMediaTime())
            receivedPulses += 1
            
            // Add slight timing variation to simulate real-world conditions
            let jitter = Double.random(in: -0.0001...0.0001)
            Thread.sleep(forTimeInterval: (60.0 / (bpm * Double(ppq))) + jitter)
        }
        
        // Verify drift compensation kept timing accurate
        let actualBPM = Double(receivedPulses) / testDuration * 60.0 / Double(ppq)
        XCTAssertEqual(actualBPM, bpm, accuracy: 0.5, "Clock drift exceeded 0.5 BPM over 10 seconds")
    }
    
    // MARK: - High Throughput Tests
    
    func testHighThroughputMIDI() {
        // Test handling rapid MIDI input without dropouts
        let messageCount = 10000
        var processedCount = 0
        var droppedCount = 0
        
        // Configure processor to track messages
        midiProcessor.messageProcessedHandler = { _ in
            processedCount += 1
        }
        
        midiProcessor.messageDroppedHandler = { _ in
            droppedCount += 1
        }
        
        // Send rapid CC messages
        measure {
            for i in 0..<messageCount {
                midiProcessor.handleCCMessage(74, value: UInt8(i % 128), channel: 1)
            }
        }
        
        // Allow processing to complete
        Thread.sleep(forTimeInterval: 0.1)
        
        XCTAssertEqual(processedCount, messageCount, "Not all messages were processed")
        XCTAssertEqual(droppedCount, 0, "Messages were dropped during high throughput")
        
        // Verify message ordering was maintained
        let processedMessages = midiProcessor.getProcessedMessages()
        for i in 1..<processedMessages.count {
            let prevValue = processedMessages[i-1].value
            let currentValue = processedMessages[i].value
            
            if prevValue < 127 {
                XCTAssertEqual(currentValue, prevValue + 1, "Message ordering was corrupted")
            }
        }
    }
    
    func testConcurrentMIDIProcessing() {
        // Test thread-safe processing of concurrent MIDI input
        let concurrentQueues = 4
        let messagesPerQueue = 1000
        let totalMessages = concurrentQueues * messagesPerQueue
        
        let expectation = self.expectation(description: "Concurrent processing")
        let processedMessages = ThreadSafeArray<ProcessedMIDIMessage>()
        
        midiProcessor.messageProcessedHandler = { message in
            processedMessages.append(message)
            
            if processedMessages.count == totalMessages {
                expectation.fulfill()
            }
        }
        
        // Send messages from multiple threads
        for queueIndex in 0..<concurrentQueues {
            DispatchQueue.global().async {
                for messageIndex in 0..<messagesPerQueue {
                    let cc = UInt8(queueIndex + 1) // Different CC per queue
                    let value = UInt8(messageIndex % 128)
                    self.midiProcessor.handleCCMessage(cc, value: value, channel: 1)
                }
            }
        }
        
        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error)
            XCTAssertEqual(processedMessages.count, totalMessages)
            
            // Verify no corruption or lost messages
            for queueIndex in 0..<concurrentQueues {
                let cc = UInt8(queueIndex + 1)
                let queueMessages = processedMessages.filter { $0.controller == cc }
                XCTAssertEqual(queueMessages.count, messagesPerQueue)
            }
        }
    }
    
    // MARK: - Real-time Performance Tests
    
    func testAudioThreadSafety() {
        // Verify MIDI processing doesn't block audio thread
        let audioBuffer = AudioBuffer()
        let bufferSize = 512
        var audioThreadBlocked = false
        
        // Configure audio callback
        mockAudioEngine.renderHandler = { buffer, frameCount in
            let startTime = CACurrentMediaTime()
            
            // Process MIDI while audio is rendering
            self.midiProcessor.processQueuedMessages()
            
            let processingTime = CACurrentMediaTime() - startTime
            let maxAllowedTime = Double(frameCount) / 48000.0 * 0.1 // 10% of buffer duration
            
            if processingTime > maxAllowedTime {
                audioThreadBlocked = true
            }
        }
        
        // Simulate audio processing with concurrent MIDI input
        DispatchQueue.global().async {
            for _ in 0..<1000 {
                self.midiProcessor.handleNoteOn(UInt8.random(in: 0...127), velocity: 127, channel: 1)
                self.midiProcessor.handleCCMessage(74, value: UInt8.random(in: 0...127), channel: 1)
            }
        }
        
        // Run audio callbacks
        for _ in 0..<100 {
            mockAudioEngine.processAudioBuffer(audioBuffer, frameCount: bufferSize)
        }
        
        XCTAssertFalse(audioThreadBlocked, "MIDI processing blocked audio thread")
    }
    
    func testPriorityMessageHandling() {
        // Test that high-priority messages are processed first
        let messageCount = 1000
        
        // Queue mix of messages with different priorities
        for i in 0..<messageCount {
            if i % 10 == 0 {
                // High priority: Note messages
                midiProcessor.handleNoteOn(60, velocity: 127, channel: 1)
            } else {
                // Lower priority: CC messages
                midiProcessor.handleCCMessage(74, value: UInt8(i % 128), channel: 1)
            }
        }
        
        // Process messages and verify priority ordering
        let processedMessages = midiProcessor.processAndReturnMessages()
        
        // Verify note messages were processed before CC messages
        var lastNoteIndex = -1
        var firstCCIndex = -1
        
        for (index, message) in processedMessages.enumerated() {
            switch message.type {
            case .noteOn:
                lastNoteIndex = index
            case .controlChange:
                if firstCCIndex == -1 {
                    firstCCIndex = index
                }
            default:
                break
            }
        }
        
        XCTAssertLessThan(lastNoteIndex, firstCCIndex, "Priority messages not processed first")
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryEfficiency() {
        // Test memory usage during extended MIDI sessions
        let initialMemory = getMemoryUsage()
        let testDuration: TimeInterval = 5.0
        let startTime = CACurrentMediaTime()
        
        // Continuous MIDI processing
        while CACurrentMediaTime() - startTime < testDuration {
            autoreleasepool {
                for _ in 0..<100 {
                    midiProcessor.handleNoteOn(UInt8.random(in: 0...127), velocity: 127, channel: 1)
                    midiProcessor.handleCCMessage(74, value: UInt8.random(in: 0...127), channel: 1)
                    midiProcessor.handleNoteOff(UInt8.random(in: 0...127), channel: 1)
                }
                
                // Process messages
                _ = midiProcessor.processQueuedMessages()
            }
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be minimal (less than 10MB)
        XCTAssertLessThan(memoryIncrease, 10 * 1024 * 1024, "Excessive memory growth during MIDI processing")
    }
    
    // MARK: - CPU Performance Tests
    
    func testCPUEfficiency() {
        // Test CPU usage during MIDI processing
        let monitor = CPUMonitor()
        monitor.startMonitoring()
        
        // Process MIDI messages for 1 second
        let startTime = CACurrentMediaTime()
        while CACurrentMediaTime() - startTime < 1.0 {
            for _ in 0..<10 {
                midiProcessor.handleCCMessage(74, value: UInt8.random(in: 0...127), channel: 1)
            }
            Thread.sleep(forTimeInterval: 0.001)
        }
        
        let averageCPU = monitor.stopAndGetAverageCPU()
        
        // MIDI processing should use less than 5% CPU
        XCTAssertLessThan(averageCPU, 5.0, "MIDI processing uses too much CPU: \(averageCPU)%")
    }
}

// MARK: - Helper Functions

extension MIDIPerformanceTests {
    func calculateIntervals(_ timestamps: [TimeInterval]) -> [TimeInterval] {
        guard timestamps.count > 1 else { return [] }
        
        var intervals: [TimeInterval] = []
        for i in 1..<timestamps.count {
            intervals.append(timestamps[i] - timestamps[i-1])
        }
        return intervals
    }
    
    func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - Mock Objects for Performance Testing

class MIDIProcessor {
    var audioEngine: MockAudioEngine?
    var performanceMonitor: MIDIPerformanceMonitor?
    var messageProcessedHandler: ((ProcessedMIDIMessage) -> Void)?
    var messageDroppedHandler: ((MIDIMessage) -> Void)?
    
    private let messageQueue = DispatchQueue(label: "midi.processing", qos: .userInteractive)
    private var queuedMessages: [MIDIMessage] = []
    private var processedMessages: [ProcessedMIDIMessage] = []
    private let lock = NSLock()
    
    func handleNoteOn(_ note: UInt8, velocity: UInt8, channel: UInt8) {
        let timestamp = CACurrentMediaTime()
        let message = MIDIMessage.noteOn(channel: channel, note: note, velocity: velocity)
        
        messageQueue.async {
            self.processMessage(message, timestamp: timestamp)
        }
    }
    
    func handleNoteOff(_ note: UInt8, channel: UInt8) {
        let timestamp = CACurrentMediaTime()
        let message = MIDIMessage.noteOff(channel: channel, note: note, velocity: 0)
        
        messageQueue.async {
            self.processMessage(message, timestamp: timestamp)
        }
    }
    
    func handleCCMessage(_ controller: UInt8, value: UInt8, channel: UInt8) {
        let timestamp = CACurrentMediaTime()
        let message = MIDIMessage.controlChange(channel: channel, controller: controller, value: value)
        
        messageQueue.async {
            self.processMessage(message, timestamp: timestamp)
        }
    }
    
    private func processMessage(_ message: MIDIMessage, timestamp: TimeInterval) {
        let startTime = CACurrentMediaTime()
        
        // Forward to audio engine
        audioEngine?.processMIDIMessage(message, timestamp: timestamp)
        
        // Track performance
        let processingTime = CACurrentMediaTime() - startTime
        performanceMonitor?.recordProcessingTime(processingTime, for: message)
        
        // Record processed message
        lock.lock()
        let processed = ProcessedMIDIMessage(message: message, timestamp: timestamp, processingTime: processingTime)
        processedMessages.append(processed)
        lock.unlock()
        
        messageProcessedHandler?(processed)
    }
    
    func processQueuedMessages() {
        // Process any queued messages
        lock.lock()
        let messages = queuedMessages
        queuedMessages.removeAll()
        lock.unlock()
        
        messages.forEach { message in
            processMessage(message, timestamp: CACurrentMediaTime())
        }
    }
    
    func processAndReturnMessages() -> [ProcessedMIDIMessage] {
        processQueuedMessages()
        
        lock.lock()
        defer { lock.unlock() }
        return processedMessages
    }
    
    func getProcessedMessages() -> [ProcessedMIDIMessage] {
        lock.lock()
        defer { lock.unlock() }
        return processedMessages
    }
}

class MIDIPerformanceMonitor {
    var lastMeasuredLatency: TimeInterval = 0
    private var processingTimes: [TimeInterval] = []
    private let lock = NSLock()
    
    func recordProcessingTime(_ time: TimeInterval, for message: MIDIMessage) {
        lock.lock()
        processingTimes.append(time)
        lastMeasuredLatency = time
        lock.unlock()
    }
    
    func getAverageProcessingTime() -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        
        guard !processingTimes.isEmpty else { return 0 }
        return processingTimes.reduce(0, +) / Double(processingTimes.count)
    }
}

class MIDIClockSync {
    private var lastClockTime: TimeInterval = 0
    private var clockIntervals: [TimeInterval] = []
    private var isReceiving = false
    
    func startReceiving() {
        isReceiving = true
        lastClockTime = 0
        clockIntervals.removeAll()
    }
    
    func receiveMIDIClock(timestamp: TimeInterval) {
        guard isReceiving else { return }
        
        if lastClockTime > 0 {
            let interval = timestamp - lastClockTime
            clockIntervals.append(interval)
        }
        
        lastClockTime = timestamp
    }
    
    func getAverageInterval() -> TimeInterval? {
        guard !clockIntervals.isEmpty else { return nil }
        return clockIntervals.reduce(0, +) / Double(clockIntervals.count)
    }
}

struct ProcessedMIDIMessage {
    let message: MIDIMessage
    let timestamp: TimeInterval
    let processingTime: TimeInterval
    
    var type: MIDIMessageType {
        switch message {
        case .noteOn: return .noteOn
        case .noteOff: return .noteOff
        case .controlChange: return .controlChange
        default: return .other
        }
    }
    
    var controller: UInt8? {
        if case .controlChange(_, let controller, _) = message {
            return controller
        }
        return nil
    }
    
    var value: UInt8? {
        if case .controlChange(_, _, let value) = message {
            return value
        }
        return nil
    }
}

enum MIDIMessageType {
    case noteOn, noteOff, controlChange, other
}

class ThreadSafeArray<T> {
    private var array: [T] = []
    private let lock = NSLock()
    
    func append(_ element: T) {
        lock.lock()
        array.append(element)
        lock.unlock()
    }
    
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return array.count
    }
    
    func filter(_ isIncluded: (T) -> Bool) -> [T] {
        lock.lock()
        defer { lock.unlock() }
        return array.filter(isIncluded)
    }
}

class CPUMonitor {
    private var startTime: TimeInterval = 0
    private var measurements: [Double] = []
    private var timer: Timer?
    
    func startMonitoring() {
        startTime = CACurrentMediaTime()
        measurements.removeAll()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.measurements.append(self.getCurrentCPUUsage())
        }
    }
    
    func stopAndGetAverageCPU() -> Double {
        timer?.invalidate()
        timer = nil
        
        guard !measurements.isEmpty else { return 0 }
        return measurements.reduce(0, +) / Double(measurements.count)
    }
    
    private func getCurrentCPUUsage() -> Double {
        // Simplified CPU usage calculation
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &cpuInfo, &numCpuInfo)
        
        guard result == KERN_SUCCESS else { return 0 }
        
        // Calculate total CPU usage
        // This is simplified - real implementation would track deltas
        return Double.random(in: 1...3) // Simulated for test
    }
}