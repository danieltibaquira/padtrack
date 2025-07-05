import XCTest
@testable import MIDIModule
@testable import SequencerModule
@testable import AudioEngine

class MIDITrackTests: XCTestCase {
    var sequencer: MIDISequencer!
    var mockMIDIOutput: MockMIDIOutput!
    var mockDelegate: MockMIDITrackDelegate!
    
    override func setUp() {
        super.setUp()
        sequencer = MIDISequencer()
        mockMIDIOutput = MockMIDIOutput()
        mockDelegate = MockMIDITrackDelegate()
        sequencer.setMIDIOutput(mockMIDIOutput)
    }
    
    override func tearDown() {
        sequencer.stop()
        sequencer = nil
        mockMIDIOutput = nil
        mockDelegate = nil
        super.tearDown()
    }
    
    // MARK: - MIDI Track Creation Tests
    
    func testMIDITrackCreation() {
        // Test creating MIDI tracks with different configurations
        let track1 = MIDITrack(channel: 1, outputDevice: "External Synth 1")
        let track2 = MIDITrack(channel: 2, outputDevice: "External Synth 2")
        
        XCTAssertEqual(track1.channel, 1)
        XCTAssertEqual(track1.outputDevice, "External Synth 1")
        XCTAssertEqual(track2.channel, 2)
        XCTAssertEqual(track2.outputDevice, "External Synth 2")
        
        // Test adding to sequencer
        sequencer.addTrack(track1)
        sequencer.addTrack(track2)
        
        XCTAssertEqual(sequencer.trackCount, 2)
    }
    
    func testMIDITrackProperties() {
        // Test MIDI track property management
        let track = MIDITrack(channel: 1, outputDevice: "Test Device")
        
        // Test mute/solo
        track.isMuted = true
        XCTAssertTrue(track.isMuted)
        
        track.isSolo = true
        XCTAssertTrue(track.isSolo)
        
        // Test volume/pan
        track.volume = 0.75
        track.pan = -0.5
        XCTAssertEqual(track.volume, 0.75)
        XCTAssertEqual(track.pan, -0.5)
        
        // Test program change
        track.programNumber = 42
        XCTAssertEqual(track.programNumber, 42)
    }
    
    // MARK: - MIDI Note Sequencing Tests
    
    func testMIDISequencing() {
        // Test MIDI tracks can sequence external hardware
        let midiTrack = MIDITrack(channel: 1, outputDevice: "External Synth")
        midiTrack.delegate = mockDelegate
        
        // Add notes to MIDI track
        midiTrack.addNote(60, velocity: 127, at: 0.0, duration: 0.5)
        midiTrack.addNote(64, velocity: 100, at: 0.5, duration: 0.5)
        midiTrack.addNote(67, velocity: 80, at: 1.0, duration: 0.5)
        
        sequencer.addTrack(midiTrack)
        
        // Play sequence
        sequencer.play()
        
        // Wait for playback
        Thread.sleep(forTimeInterval: 2.0)
        sequencer.stop()
        
        // Verify MIDI notes sent to external device
        let sentMessages = mockMIDIOutput.sentMessages
        
        // Should have 6 messages (3 note on + 3 note off)
        XCTAssertEqual(sentMessages.count, 6)
        
        // Verify note on messages
        let noteOnMessages = sentMessages.filter { $0.isNoteOn }
        XCTAssertEqual(noteOnMessages.count, 3)
        XCTAssertEqual(noteOnMessages[0].note, 60)
        XCTAssertEqual(noteOnMessages[1].note, 64)
        XCTAssertEqual(noteOnMessages[2].note, 67)
        
        // Verify timing
        XCTAssertEqual(noteOnMessages[0].timestamp, 0.0, accuracy: 0.01)
        XCTAssertEqual(noteOnMessages[1].timestamp, 0.5, accuracy: 0.01)
        XCTAssertEqual(noteOnMessages[2].timestamp, 1.0, accuracy: 0.01)
    }
    
    func testMIDIPatternPlayback() {
        // Test pattern-based MIDI sequencing
        let midiTrack = MIDITrack(channel: 1, outputDevice: "External Synth")
        let pattern = MIDIPattern(length: 16, stepDuration: 0.125) // 16 steps, 16th notes
        
        // Create drum pattern
        pattern.addTrigger(step: 0, note: 36, velocity: 127)  // Kick
        pattern.addTrigger(step: 4, note: 38, velocity: 100)  // Snare
        pattern.addTrigger(step: 8, note: 36, velocity: 127)  // Kick
        pattern.addTrigger(step: 12, note: 38, velocity: 100) // Snare
        
        // Add hi-hats
        for step in stride(from: 0, to: 16, by: 2) {
            pattern.addTrigger(step: step, note: 42, velocity: 60)
        }
        
        midiTrack.setPattern(pattern)
        sequencer.addTrack(midiTrack)
        sequencer.setBPM(120)
        sequencer.play()
        
        // Play for one pattern length
        Thread.sleep(forTimeInterval: 2.0)
        sequencer.stop()
        
        // Verify pattern output
        let sentMessages = mockMIDIOutput.sentMessages.filter { $0.isNoteOn }
        
        // Should have kick, snare, and hi-hat messages
        let kickMessages = sentMessages.filter { $0.note == 36 }
        let snareMessages = sentMessages.filter { $0.note == 38 }
        let hihatMessages = sentMessages.filter { $0.note == 42 }
        
        XCTAssertEqual(kickMessages.count, 2)
        XCTAssertEqual(snareMessages.count, 2)
        XCTAssertEqual(hihatMessages.count, 8)
    }
    
    // MARK: - MIDI Recording Tests
    
    func testMIDIRecording() {
        // Test recording MIDI input into patterns
        let recorder = MIDIRecorder()
        let midiTrack = MIDITrack(channel: 1, outputDevice: "External Synth")
        
        recorder.startRecording(to: midiTrack, quantization: .off)
        
        // Simulate MIDI input with precise timing
        let notes: [(note: UInt8, velocity: UInt8, time: TimeInterval, duration: TimeInterval)] = [
            (60, 127, 0.0, 0.5),
            (64, 100, 0.5, 0.5),
            (67, 80, 1.0, 0.5),
            (72, 90, 1.5, 0.5)
        ]
        
        for noteData in notes {
            recorder.handleNoteOn(noteData.note, velocity: noteData.velocity, at: noteData.time)
            recorder.handleNoteOff(noteData.note, at: noteData.time + noteData.duration)
        }
        
        recorder.stopRecording()
        
        // Verify recorded notes
        let recordedNotes = midiTrack.notes
        XCTAssertEqual(recordedNotes.count, 4)
        
        for (index, noteData) in notes.enumerated() {
            XCTAssertEqual(recordedNotes[index].pitch, noteData.note)
            XCTAssertEqual(recordedNotes[index].velocity, noteData.velocity)
            XCTAssertEqual(recordedNotes[index].startTime, noteData.time, accuracy: 0.01)
            XCTAssertEqual(recordedNotes[index].duration, noteData.duration, accuracy: 0.01)
        }
    }
    
    func testQuantizedMIDIRecording() {
        // Test recording with quantization
        let recorder = MIDIRecorder()
        let midiTrack = MIDITrack(channel: 1, outputDevice: "External Synth")
        
        recorder.startRecording(to: midiTrack, quantization: .sixteenth, bpm: 120)
        
        // Simulate slightly off-time MIDI input
        recorder.handleNoteOn(60, velocity: 127, at: 0.02)    // Should quantize to 0.0
        recorder.handleNoteOn(64, velocity: 100, at: 0.27)    // Should quantize to 0.25
        recorder.handleNoteOn(67, velocity: 80, at: 0.48)     // Should quantize to 0.5
        recorder.handleNoteOn(72, velocity: 90, at: 0.73)     // Should quantize to 0.75
        
        // Note offs
        recorder.handleNoteOff(60, at: 0.25)
        recorder.handleNoteOff(64, at: 0.5)
        recorder.handleNoteOff(67, at: 0.75)
        recorder.handleNoteOff(72, at: 1.0)
        
        recorder.stopRecording()
        
        // Verify quantization
        let recordedNotes = midiTrack.notes
        XCTAssertEqual(recordedNotes[0].startTime, 0.0, accuracy: 0.001)
        XCTAssertEqual(recordedNotes[1].startTime, 0.25, accuracy: 0.001)
        XCTAssertEqual(recordedNotes[2].startTime, 0.5, accuracy: 0.001)
        XCTAssertEqual(recordedNotes[3].startTime, 0.75, accuracy: 0.001)
    }
    
    func testLiveMIDIRecordingAccuracy() {
        // Test real-time MIDI recording accuracy
        let recorder = MIDIRecorder()
        let midiTrack = MIDITrack(channel: 1, outputDevice: "External Synth")
        
        recorder.startRecording(to: midiTrack, quantization: .sixteenth, bpm: 120)
        
        // Simulate real-time MIDI input with precise timing
        let baseTime = CACurrentMediaTime()
        recorder.handleNoteOn(60, velocity: 127, at: baseTime + 0.0)
        recorder.handleNoteOn(64, velocity: 100, at: baseTime + 0.25)
        recorder.handleNoteOn(67, velocity: 80, at: baseTime + 0.5)
        
        let pattern = recorder.stopRecording()
        
        // Verify quantization and timing accuracy
        XCTAssertEqual(pattern.triggers.count, 3)
        XCTAssertEqual(pattern.triggers[0].step, 0)
        XCTAssertEqual(pattern.triggers[1].step, 4) // Quantized to 16th note
        XCTAssertEqual(pattern.triggers[2].step, 8)
    }
    
    // MARK: - MIDI Output Routing Tests
    
    func testMIDIOutputRouting() {
        // Test routing to specific MIDI outputs
        let output1 = MockMIDIOutput(name: "Output 1")
        let output2 = MockMIDIOutput(name: "Output 2")
        
        sequencer.addMIDIOutput(output1, identifier: "Output 1")
        sequencer.addMIDIOutput(output2, identifier: "Output 2")
        
        let track1 = MIDITrack(channel: 1, outputDevice: "Output 1")
        let track2 = MIDITrack(channel: 2, outputDevice: "Output 2")
        
        track1.addNote(60, velocity: 127, at: 0.0, duration: 0.5)
        track2.addNote(64, velocity: 100, at: 0.0, duration: 0.5)
        
        sequencer.addTrack(track1)
        sequencer.addTrack(track2)
        
        sequencer.play()
        Thread.sleep(forTimeInterval: 1.0)
        sequencer.stop()
        
        // Verify routing
        XCTAssertEqual(output1.sentMessages.filter { $0.isNoteOn }.count, 1)
        XCTAssertEqual(output2.sentMessages.filter { $0.isNoteOn }.count, 1)
        XCTAssertEqual(output1.sentMessages.first?.note, 60)
        XCTAssertEqual(output2.sentMessages.first?.note, 64)
    }
    
    func testMIDIChannelRouting() {
        // Test proper MIDI channel assignment
        let midiOutput = MockMIDIOutput()
        sequencer.setMIDIOutput(midiOutput)
        
        // Create tracks on different channels
        for channel in 1...16 {
            let track = MIDITrack(channel: UInt8(channel), outputDevice: "Default")
            track.addNote(60, velocity: 100, at: 0.0, duration: 0.1)
            sequencer.addTrack(track)
        }
        
        sequencer.play()
        Thread.sleep(forTimeInterval: 0.5)
        sequencer.stop()
        
        // Verify each channel received its message
        let noteOnMessages = midiOutput.sentMessages.filter { $0.isNoteOn }
        XCTAssertEqual(noteOnMessages.count, 16)
        
        for (index, message) in noteOnMessages.enumerated() {
            XCTAssertEqual(message.channel, UInt8(index + 1))
        }
    }
    
    // MARK: - MIDI Effects Tests
    
    func testMIDIVelocityScaling() {
        // Test velocity scaling on MIDI tracks
        let track = MIDITrack(channel: 1, outputDevice: "Default")
        track.velocityScale = 0.5
        
        track.addNote(60, velocity: 127, at: 0.0, duration: 0.5)
        track.addNote(64, velocity: 100, at: 0.5, duration: 0.5)
        
        sequencer.addTrack(track)
        sequencer.play()
        Thread.sleep(forTimeInterval: 1.5)
        sequencer.stop()
        
        let noteOnMessages = mockMIDIOutput.sentMessages.filter { $0.isNoteOn }
        XCTAssertEqual(noteOnMessages[0].velocity, 63) // 127 * 0.5
        XCTAssertEqual(noteOnMessages[1].velocity, 50) // 100 * 0.5
    }
    
    func testMIDITransposition() {
        // Test note transposition
        let track = MIDITrack(channel: 1, outputDevice: "Default")
        track.transpose = 5 // Up 5 semitones
        
        track.addNote(60, velocity: 100, at: 0.0, duration: 0.5) // C4 -> F4
        track.addNote(64, velocity: 100, at: 0.5, duration: 0.5) // E4 -> A4
        
        sequencer.addTrack(track)
        sequencer.play()
        Thread.sleep(forTimeInterval: 1.5)
        sequencer.stop()
        
        let noteOnMessages = mockMIDIOutput.sentMessages.filter { $0.isNoteOn }
        XCTAssertEqual(noteOnMessages[0].note, 65) // 60 + 5
        XCTAssertEqual(noteOnMessages[1].note, 69) // 64 + 5
    }
    
    // MARK: - MIDI CC Automation Tests
    
    func testMIDICCAutomation() {
        // Test CC automation on MIDI tracks
        let track = MIDITrack(channel: 1, outputDevice: "Default")
        
        // Add CC automation
        track.addCCAutomation(controller: 74, values: [
            (time: 0.0, value: 0),
            (time: 0.5, value: 64),
            (time: 1.0, value: 127)
        ])
        
        sequencer.addTrack(track)
        sequencer.play()
        Thread.sleep(forTimeInterval: 1.5)
        sequencer.stop()
        
        // Verify CC messages
        let ccMessages = mockMIDIOutput.sentMessages.filter { $0.isControlChange }
        XCTAssertGreaterThanOrEqual(ccMessages.count, 3)
        
        // Check key points
        let firstCC = ccMessages.first { $0.timestamp <= 0.01 }
        let midCC = ccMessages.first { abs($0.timestamp - 0.5) <= 0.01 }
        let lastCC = ccMessages.first { abs($0.timestamp - 1.0) <= 0.01 }
        
        XCTAssertEqual(firstCC?.value, 0)
        XCTAssertEqual(midCC?.value, 64)
        XCTAssertEqual(lastCC?.value, 127)
    }
    
    // MARK: - Integration Tests
    
    func testMIDITrackSequencerIntegration() {
        // Test full integration with sequencer
        let sequencer = SequencerCore.shared
        let midiTrack = MIDITrack(channel: 1, outputDevice: "External")
        
        // Create pattern
        let pattern = MIDIPattern(length: 16, stepDuration: 0.125)
        pattern.addTrigger(step: 0, note: 60, velocity: 127)
        pattern.addTrigger(step: 4, note: 64, velocity: 100)
        pattern.addTrigger(step: 8, note: 67, velocity: 80)
        pattern.addTrigger(step: 12, note: 72, velocity: 90)
        
        midiTrack.setPattern(pattern)
        
        // Add to sequencer
        sequencer.addMIDITrack(midiTrack)
        
        // Verify integration
        XCTAssertTrue(sequencer.hasMIDITracks)
        XCTAssertEqual(sequencer.midiTrackCount, 1)
        
        // Test playback
        sequencer.setBPM(120)
        sequencer.play()
        
        Thread.sleep(forTimeInterval: 2.0)
        sequencer.stop()
        
        // Verify MIDI output
        XCTAssertGreaterThan(mockMIDIOutput.sentMessages.count, 0)
    }
}

// MARK: - Mock Objects

class MockMIDIOutput: MIDIOutputProtocol {
    let name: String
    var sentMessages: [MIDIOutputMessage] = []
    
    init(name: String = "Mock Output") {
        self.name = name
    }
    
    func send(_ message: MIDIMessage, timestamp: TimeInterval = 0) {
        let outputMessage = MIDIOutputMessage(
            message: message,
            timestamp: timestamp,
            channel: message.channel ?? 1,
            note: message.note,
            velocity: message.velocity,
            controller: message.controller,
            value: message.value
        )
        sentMessages.append(outputMessage)
    }
    
    func reset() {
        sentMessages.removeAll()
    }
}

struct MIDIOutputMessage {
    let message: MIDIMessage
    let timestamp: TimeInterval
    let channel: UInt8
    let note: UInt8?
    let velocity: UInt8?
    let controller: UInt8?
    let value: UInt8?
    
    var isNoteOn: Bool {
        if case .noteOn = message {
            return true
        }
        return false
    }
    
    var isNoteOff: Bool {
        if case .noteOff = message {
            return true
        }
        return false
    }
    
    var isControlChange: Bool {
        if case .controlChange = message {
            return true
        }
        return false
    }
}

class MockMIDITrackDelegate: MIDITrackDelegate {
    var notePlayedCount = 0
    var lastPlayedNote: UInt8?
    var lastPlayedVelocity: UInt8?
    
    func midiTrack(_ track: MIDITrack, playedNote note: UInt8, velocity: UInt8, at timestamp: TimeInterval) {
        notePlayedCount += 1
        lastPlayedNote = note
        lastPlayedVelocity = velocity
    }
}

// MARK: - MIDI Track Implementation Stubs

class MIDITrack {
    let channel: UInt8
    let outputDevice: String
    weak var delegate: MIDITrackDelegate?
    
    var isMuted = false
    var isSolo = false
    var volume: Float = 1.0
    var pan: Float = 0.0
    var programNumber: UInt8 = 0
    var velocityScale: Float = 1.0
    var transpose: Int = 0
    
    private(set) var notes: [MIDINote] = []
    private var pattern: MIDIPattern?
    private var ccAutomation: [CCAutomation] = []
    
    init(channel: UInt8, outputDevice: String) {
        self.channel = channel
        self.outputDevice = outputDevice
    }
    
    func addNote(_ pitch: UInt8, velocity: UInt8, at time: TimeInterval, duration: TimeInterval) {
        let note = MIDINote(pitch: pitch, velocity: velocity, startTime: time, duration: duration)
        notes.append(note)
    }
    
    func setPattern(_ pattern: MIDIPattern) {
        self.pattern = pattern
    }
    
    func addCCAutomation(controller: UInt8, values: [(time: TimeInterval, value: UInt8)]) {
        let automation = CCAutomation(controller: controller, values: values)
        ccAutomation.append(automation)
    }
}

struct MIDINote {
    let pitch: UInt8
    let velocity: UInt8
    let startTime: TimeInterval
    let duration: TimeInterval
}

class MIDIPattern {
    let length: Int
    let stepDuration: TimeInterval
    private(set) var triggers: [MIDITrigger] = []
    
    init(length: Int, stepDuration: TimeInterval) {
        self.length = length
        self.stepDuration = stepDuration
    }
    
    func addTrigger(step: Int, note: UInt8, velocity: UInt8) {
        let trigger = MIDITrigger(step: step, note: note, velocity: velocity)
        triggers.append(trigger)
    }
}

struct MIDITrigger {
    let step: Int
    let note: UInt8
    let velocity: UInt8
}

struct CCAutomation {
    let controller: UInt8
    let values: [(time: TimeInterval, value: UInt8)]
}

class MIDIRecorder {
    private var recordingTrack: MIDITrack?
    private var quantization: Quantization = .off
    private var bpm: Double = 120
    private var recordedEvents: [(type: EventType, note: UInt8, velocity: UInt8, time: TimeInterval)] = []
    
    enum Quantization {
        case off, sixteenth, eighth, quarter
    }
    
    enum EventType {
        case noteOn, noteOff
    }
    
    func startRecording(to track: MIDITrack, quantization: Quantization = .off, bpm: Double = 120) {
        recordingTrack = track
        self.quantization = quantization
        self.bpm = bpm
        recordedEvents.removeAll()
    }
    
    func handleNoteOn(_ note: UInt8, velocity: UInt8, at timestamp: TimeInterval) {
        let quantizedTime = quantizeTime(timestamp)
        recordedEvents.append((type: .noteOn, note: note, velocity: velocity, time: quantizedTime))
    }
    
    func handleNoteOff(_ note: UInt8, at timestamp: TimeInterval) {
        let quantizedTime = quantizeTime(timestamp)
        recordedEvents.append((type: .noteOff, note: note, velocity: 0, time: quantizedTime))
    }
    
    func stopRecording() -> MIDIPattern {
        // Process recorded events into notes
        var noteOnEvents: [UInt8: (velocity: UInt8, time: TimeInterval)] = [:]
        
        for event in recordedEvents {
            switch event.type {
            case .noteOn:
                noteOnEvents[event.note] = (velocity: event.velocity, time: event.time)
            case .noteOff:
                if let noteOn = noteOnEvents[event.note] {
                    let duration = event.time - noteOn.time
                    recordingTrack?.addNote(event.note, velocity: noteOn.velocity, at: noteOn.time, duration: duration)
                    noteOnEvents.removeValue(forKey: event.note)
                }
            }
        }
        
        // Create pattern from recorded notes
        let pattern = MIDIPattern(length: 16, stepDuration: 0.125)
        for note in recordingTrack?.notes ?? [] {
            let step = Int(note.startTime / 0.125)
            pattern.addTrigger(step: step, note: note.pitch, velocity: note.velocity)
        }
        
        return pattern
    }
    
    private func quantizeTime(_ time: TimeInterval) -> TimeInterval {
        guard quantization != .off else { return time }
        
        let stepDuration: TimeInterval
        switch quantization {
        case .sixteenth:
            stepDuration = 60.0 / bpm / 4
        case .eighth:
            stepDuration = 60.0 / bpm / 2
        case .quarter:
            stepDuration = 60.0 / bpm
        case .off:
            return time
        }
        
        return round(time / stepDuration) * stepDuration
    }
}

class MIDISequencer {
    private(set) var trackCount = 0
    private var tracks: [MIDITrack] = []
    private var outputs: [String: MIDIOutputProtocol] = [:]
    private var defaultOutput: MIDIOutputProtocol?
    private var isPlaying = false
    private var currentBPM: Double = 120
    
    func addTrack(_ track: MIDITrack) {
        tracks.append(track)
        trackCount = tracks.count
    }
    
    func setMIDIOutput(_ output: MIDIOutputProtocol) {
        defaultOutput = output
    }
    
    func addMIDIOutput(_ output: MIDIOutputProtocol, identifier: String) {
        outputs[identifier] = output
    }
    
    func setBPM(_ bpm: Double) {
        currentBPM = bpm
    }
    
    func play() {
        isPlaying = true
        
        // Simulate playback
        for track in tracks {
            guard !track.isMuted else { continue }
            
            let output = outputs[track.outputDevice] ?? defaultOutput
            
            for note in track.notes {
                // Apply velocity scaling
                let scaledVelocity = UInt8(min(127, Float(note.velocity) * track.velocityScale))
                
                // Apply transposition
                let transposedNote = UInt8(max(0, min(127, Int(note.pitch) + track.transpose)))
                
                // Send note on
                let noteOn = MIDIMessage.noteOn(
                    channel: track.channel,
                    note: transposedNote,
                    velocity: scaledVelocity
                )
                output?.send(noteOn, timestamp: note.startTime)
                
                // Send note off
                let noteOff = MIDIMessage.noteOff(
                    channel: track.channel,
                    note: transposedNote,
                    velocity: 0
                )
                output?.send(noteOff, timestamp: note.startTime + note.duration)
            }
        }
    }
    
    func stop() {
        isPlaying = false
    }
}

// MARK: - Protocol Definitions

protocol MIDIOutputProtocol {
    func send(_ message: MIDIMessage, timestamp: TimeInterval)
}

protocol MIDITrackDelegate: AnyObject {
    func midiTrack(_ track: MIDITrack, playedNote note: UInt8, velocity: UInt8, at timestamp: TimeInterval)
}

// MARK: - SequencerCore Extension

extension SequencerCore {
    private static var _midiTracks: [MIDITrack] = []
    
    var hasMIDITracks: Bool {
        return !Self._midiTracks.isEmpty
    }
    
    var midiTrackCount: Int {
        return Self._midiTracks.count
    }
    
    func addMIDITrack(_ track: MIDITrack) {
        Self._midiTracks.append(track)
    }
}

// MARK: - MIDIMessage Extension

extension MIDIMessage {
    var channel: UInt8? {
        switch self {
        case .noteOn(let channel, _, _),
             .noteOff(let channel, _, _),
             .controlChange(let channel, _, _):
            return channel
        default:
            return nil
        }
    }
    
    var note: UInt8? {
        switch self {
        case .noteOn(_, let note, _),
             .noteOff(_, let note, _):
            return note
        default:
            return nil
        }
    }
    
    var velocity: UInt8? {
        switch self {
        case .noteOn(_, _, let velocity),
             .noteOff(_, _, let velocity):
            return velocity
        default:
            return nil
        }
    }
    
    var controller: UInt8? {
        if case .controlChange(_, let controller, _) = self {
            return controller
        }
        return nil
    }
    
    var value: UInt8? {
        if case .controlChange(_, _, let value) = self {
            return value
        }
        return nil
    }
}