// MIDISequencer.swift
// DigitonePad - MIDIModule
//
// MIDI track sequencer for external hardware control

import Foundation
import CoreAudio
import MachineProtocols

/// MIDI sequencer for external hardware control
public final class MIDISequencer: @unchecked Sendable {
    
    // MARK: - Properties
    
    weak var delegate: MIDISequencerDelegate?
    
    private let lock = NSLock()
    private var tracks: [MIDITrack] = []
    private var outputs: [String: MIDIOutputPort] = []
    private var defaultOutput: MIDIOutputPort?
    
    // Playback state
    private var isPlaying = false
    private var currentBPM: Double = 120.0
    private var currentPosition: Double = 0.0
    private var playbackTimer: Timer?
    private var startTime: TimeInterval = 0
    
    // Timing
    private var ppq: Int = 96 // Pulses per quarter note for high resolution
    private var ticksPerStep: Int = 24 // 16th note resolution
    private var currentTick: Int = 0
    
    // Recording
    private var recordingTrack: MIDITrack?
    private var isRecording = false
    private var recordQuantization: RecordQuantization = .sixteenth
    
    // MARK: - Initialization
    
    public init() {
        // Initialize empty sequencer
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public Interface
    
    /// Current number of tracks
    public var trackCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return tracks.count
    }
    
    /// Current playback state
    public var playbackState: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isPlaying
    }
    
    /// Current BPM
    public var bpm: Double {
        lock.lock()
        defer { lock.unlock() }
        return currentBPM
    }
    
    /// Add MIDI track
    public func addTrack(_ track: MIDITrack) {
        lock.lock()
        defer { lock.unlock() }
        
        track.sequencer = self
        tracks.append(track)
        
        delegate?.midiSequencer(self, didAddTrack: track)
    }
    
    /// Remove MIDI track
    public func removeTrack(_ track: MIDITrack) {
        lock.lock()
        defer { lock.unlock() }
        
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            tracks.remove(at: index)
            track.sequencer = nil
            
            delegate?.midiSequencer(self, didRemoveTrack: track)
        }
    }
    
    /// Get track by index
    public func getTrack(at index: Int) -> MIDITrack? {
        lock.lock()
        defer { lock.unlock() }
        
        guard index >= 0 && index < tracks.count else { return nil }
        return tracks[index]
    }
    
    /// Set default MIDI output
    public func setMIDIOutput(_ output: MIDIOutputPort) {
        lock.lock()
        defer { lock.unlock() }
        defaultOutput = output
    }
    
    /// Add named MIDI output
    public func addMIDIOutput(_ output: MIDIOutputPort, identifier: String) {
        lock.lock()
        defer { lock.unlock() }
        outputs[identifier] = output
    }
    
    /// Remove MIDI output
    public func removeMIDIOutput(identifier: String) {
        lock.lock()
        defer { lock.unlock() }
        outputs.removeValue(forKey: identifier)
    }
    
    /// Set BPM
    public func setBPM(_ bpm: Double) {
        guard bpm > 0 && bpm <= 999 else { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        currentBPM = bpm
        
        // Restart timer if playing
        if isPlaying {
            restartPlaybackTimer()
        }
        
        delegate?.midiSequencer(self, tempoChanged: bpm)
    }
    
    /// Start playback
    public func play() {
        lock.lock()
        defer { lock.unlock() }
        
        isPlaying = true
        startTime = CACurrentMediaTime()
        currentPosition = 0.0
        currentTick = 0
        
        startPlaybackTimer()
        
        // Send start message to all outputs
        sendTransportMessage(.start)
        
        delegate?.midiSequencer(self, playbackStateChanged: true)
    }
    
    /// Stop playback
    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        isPlaying = false
        currentPosition = 0.0
        currentTick = 0
        
        stopPlaybackTimer()
        
        // Send stop message to all outputs
        sendTransportMessage(.stop)
        
        // Send all notes off
        sendAllNotesOff()
        
        delegate?.midiSequencer(self, playbackStateChanged: false)
    }
    
    /// Pause playback (continue from current position)
    public func pause() {
        lock.lock()
        defer { lock.unlock() }
        
        isPlaying = false
        stopPlaybackTimer()
        
        // Send stop message but maintain position
        sendTransportMessage(.stop)
        
        delegate?.midiSequencer(self, playbackStateChanged: false)
    }
    
    /// Continue playback from current position
    public func continue() {
        lock.lock()
        defer { lock.unlock() }
        
        isPlaying = true
        startTime = CACurrentMediaTime() - (currentPosition * 60.0 / currentBPM)
        
        startPlaybackTimer()
        
        // Send continue message
        sendTransportMessage(.continue)
        
        delegate?.midiSequencer(self, playbackStateChanged: true)
    }
    
    // MARK: - Recording
    
    /// Start recording to a track
    public func startRecording(to track: MIDITrack, quantization: RecordQuantization = .sixteenth) {
        lock.lock()
        defer { lock.unlock() }
        
        recordingTrack = track
        isRecording = true
        recordQuantization = quantization
        
        // Clear existing events if recording from start
        if currentPosition == 0 {
            track.clearEvents()
        }
        
        delegate?.midiSequencer(self, recordingStateChanged: true, track: track)
    }
    
    /// Stop recording
    public func stopRecording() {
        lock.lock()
        defer { lock.unlock() }
        
        isRecording = false
        let track = recordingTrack
        recordingTrack = nil
        
        if let track = track {
            delegate?.midiSequencer(self, recordingStateChanged: false, track: track)
        }
    }
    
    /// Record MIDI event
    public func recordEvent(_ event: MIDIEvent) {
        guard isRecording, let track = recordingTrack else { return }
        
        let quantizedPosition = quantizePosition(currentPosition, quantization: recordQuantization)
        let recordedEvent = MIDIEvent(
            type: event.type,
            channel: event.channel,
            note: event.note,
            velocity: event.velocity,
            controller: event.controller,
            value: event.value,
            position: quantizedPosition,
            duration: event.duration
        )
        
        track.addEvent(recordedEvent)
        delegate?.midiSequencer(self, didRecordEvent: recordedEvent, to: track)
    }
    
    // MARK: - Pattern Management
    
    /// Set pattern for a track
    public func setPattern(_ pattern: MIDIPattern, for track: MIDITrack) {
        track.setPattern(pattern)
        delegate?.midiSequencer(self, didSetPattern: pattern, for: track)
    }
    
    /// Get pattern from track
    public func getPattern(for track: MIDITrack) -> MIDIPattern? {
        return track.currentPattern
    }
    
    // MARK: - Clock Integration
    
    /// Sync to external clock
    public func syncToExternalClock(_ clockSync: MIDIClockSync) {
        // Connect clock sync events to sequencer
        // This would integrate with the MIDIClockSync implementation
    }
    
    /// Send clock pulse to outputs
    public func sendClockPulse() {
        let timestamp = CACurrentMediaTime()
        
        for output in outputs.values {
            output.sendClock(timestamp: timestamp)
        }
        
        defaultOutput?.sendClock(timestamp: timestamp)
    }
    
    // MARK: - Private Implementation
    
    private func startPlaybackTimer() {
        let interval = 60.0 / (currentBPM * Double(ppq))
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.processSequencerTick()
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func restartPlaybackTimer() {
        stopPlaybackTimer()
        if isPlaying {
            startPlaybackTimer()
        }
    }
    
    private func processSequencerTick() {
        lock.lock()
        defer { lock.unlock() }
        
        let currentTime = CACurrentMediaTime()
        currentPosition = (currentTime - startTime) * currentBPM / 60.0
        currentTick += 1
        
        // Process all tracks
        for track in tracks {
            processTrackEvents(track, at: currentPosition, tick: currentTick)
        }
        
        // Send clock pulse
        if currentTick % (ppq / 24) == 0 { // 24 MIDI clock pulses per quarter note
            sendClockPulse()
        }
        
        delegate?.midiSequencer(self, positionChanged: currentPosition)
    }
    
    private func processTrackEvents(_ track: MIDITrack, at position: Double, tick: Int) {
        guard !track.isMuted else { return }
        
        let output = getOutputForTrack(track)
        let events = track.getEventsAtPosition(position)
        
        for event in events {
            sendMIDIEvent(event, to: output, track: track)
        }
        
        // Process pattern if active
        if let pattern = track.currentPattern {
            let patternEvents = pattern.getEventsAtTick(tick % pattern.lengthInTicks)
            
            for event in patternEvents {
                sendMIDIEvent(event, to: output, track: track)
            }
        }
    }
    
    private func sendMIDIEvent(_ event: MIDIEvent, to output: MIDIOutputPort?, track: MIDITrack) {
        guard let output = output else { return }
        
        let message = createMIDIMessage(from: event, track: track)
        output.send(message, timestamp: CACurrentMediaTime())
        
        delegate?.midiSequencer(self, didSendEvent: event, from: track)
    }
    
    private func createMIDIMessage(from event: MIDIEvent, track: MIDITrack) -> MIDIMessage {
        // Apply track transformations
        let channel = track.midiChannel
        let velocity = applyVelocityScale(event.velocity ?? 127, track: track)
        let note = applyTransposition(event.note ?? 60, track: track)
        
        switch event.type {
        case .noteOn:
            return .noteOn(channel: channel, note: note, velocity: velocity)
        case .noteOff:
            return .noteOff(channel: channel, note: note, velocity: 0)
        case .controlChange:
            return .controlChange(channel: channel, controller: event.controller ?? 0, value: event.value ?? 0)
        case .programChange:
            return MIDIMessage(type: .programChange, channel: channel, data1: event.value ?? 0, data2: 0)
        case .pitchBend:
            let pitchValue = Int(event.value ?? 64) * 128 // Convert to 14-bit
            return MIDIMessage(type: .pitchBend, channel: channel, data1: UInt8(pitchValue & 0x7F), data2: UInt8((pitchValue >> 7) & 0x7F))
        }
    }
    
    private func getOutputForTrack(_ track: MIDITrack) -> MIDIOutputPort? {
        if let outputName = track.outputDevice {
            return outputs[outputName]
        }
        return defaultOutput
    }
    
    private func applyVelocityScale(_ velocity: UInt8, track: MIDITrack) -> UInt8 {
        let scaled = Float(velocity) * track.velocityScale
        return UInt8(max(1, min(127, scaled)))
    }
    
    private func applyTransposition(_ note: UInt8, track: MIDITrack) -> UInt8 {
        let transposed = Int(note) + track.transpose
        return UInt8(max(0, min(127, transposed)))
    }
    
    private func sendTransportMessage(_ message: SequencerTransportMessage) {
        let midiMessage: MIDIMessage
        
        switch message {
        case .start:
            midiMessage = MIDIMessage(type: .start, channel: 0, data1: 0, data2: 0)
        case .stop:
            midiMessage = MIDIMessage(type: .stop, channel: 0, data1: 0, data2: 0)
        case .continue:
            midiMessage = MIDIMessage(type: .continue, channel: 0, data1: 0, data2: 0)
        }
        
        for output in outputs.values {
            output.send(midiMessage, timestamp: CACurrentMediaTime())
        }
        
        defaultOutput?.send(midiMessage, timestamp: CACurrentMediaTime())
    }
    
    private func sendAllNotesOff() {
        for channel: UInt8 in 1...16 {
            let allNotesOff = MIDIMessage.controlChange(channel: channel, controller: 123, value: 0)
            
            for output in outputs.values {
                output.send(allNotesOff, timestamp: CACurrentMediaTime())
            }
            
            defaultOutput?.send(allNotesOff, timestamp: CACurrentMediaTime())
        }
    }
    
    private func quantizePosition(_ position: Double, quantization: RecordQuantization) -> Double {
        let quantizeValue: Double
        
        switch quantization {
        case .off:
            return position
        case .sixteenth:
            quantizeValue = 0.25
        case .eighth:
            quantizeValue = 0.5
        case .quarter:
            quantizeValue = 1.0
        case .half:
            quantizeValue = 2.0
        case .whole:
            quantizeValue = 4.0
        }
        
        return round(position / quantizeValue) * quantizeValue
    }
}

// MARK: - Supporting Types

/// MIDI track for sequencing
public final class MIDITrack: @unchecked Sendable {
    public let id = UUID()
    public let name: String
    public let midiChannel: UInt8
    public let outputDevice: String?
    
    // Track properties
    public var isMuted = false
    public var isSolo = false
    public var velocityScale: Float = 1.0
    public var transpose: Int = 0
    public var volume: Float = 1.0
    public var pan: Float = 0.0
    
    // Sequencer reference
    weak var sequencer: MIDISequencer?
    
    // Events and patterns
    private let lock = NSLock()
    private var events: [MIDIEvent] = []
    private(set) var currentPattern: MIDIPattern?
    
    public init(name: String, channel: UInt8, outputDevice: String? = nil) {
        self.name = name
        self.midiChannel = channel
        self.outputDevice = outputDevice
    }
    
    /// Add MIDI event
    public func addEvent(_ event: MIDIEvent) {
        lock.lock()
        defer { lock.unlock() }
        
        events.append(event)
        events.sort { $0.position < $1.position }
    }
    
    /// Remove MIDI event
    public func removeEvent(_ event: MIDIEvent) {
        lock.lock()
        defer { lock.unlock() }
        
        events.removeAll { $0.id == event.id }
    }
    
    /// Clear all events
    public func clearEvents() {
        lock.lock()
        defer { lock.unlock() }
        events.removeAll()
    }
    
    /// Get events at specific position
    public func getEventsAtPosition(_ position: Double, tolerance: Double = 0.01) -> [MIDIEvent] {
        lock.lock()
        defer { lock.unlock() }
        
        return events.filter { abs($0.position - position) <= tolerance }
    }
    
    /// Set pattern
    public func setPattern(_ pattern: MIDIPattern) {
        lock.lock()
        defer { lock.unlock() }
        currentPattern = pattern
    }
    
    /// Clear pattern
    public func clearPattern() {
        lock.lock()
        defer { lock.unlock() }
        currentPattern = nil
    }
    
    /// Get all events
    public func getAllEvents() -> [MIDIEvent] {
        lock.lock()
        defer { lock.unlock() }
        return Array(events)
    }
}

/// MIDI event for sequencing
public struct MIDIEvent {
    public let id = UUID()
    public let type: MIDIEventType
    public let channel: UInt8
    public let note: UInt8?
    public let velocity: UInt8?
    public let controller: UInt8?
    public let value: UInt8?
    public let position: Double // Position in beats
    public let duration: Double? // Duration in beats
    
    public init(type: MIDIEventType, channel: UInt8, note: UInt8? = nil, velocity: UInt8? = nil, controller: UInt8? = nil, value: UInt8? = nil, position: Double, duration: Double? = nil) {
        self.type = type
        self.channel = channel
        self.note = note
        self.velocity = velocity
        self.controller = controller
        self.value = value
        self.position = position
        self.duration = duration
    }
}

/// MIDI event types
public enum MIDIEventType: String, CaseIterable {
    case noteOn
    case noteOff
    case controlChange
    case programChange
    case pitchBend
}

/// MIDI pattern for step sequencing
public final class MIDIPattern: @unchecked Sendable {
    public let id = UUID()
    public let name: String
    public let lengthInSteps: Int
    public let stepsPerBeat: Int
    
    private let lock = NSLock()
    private var steps: [Int: [MIDIEvent]] = [:]
    
    public init(name: String = "Pattern", lengthInSteps: Int = 16, stepsPerBeat: Int = 4) {
        self.name = name
        self.lengthInSteps = lengthInSteps
        self.stepsPerBeat = stepsPerBeat
    }
    
    /// Length in ticks (for high-resolution timing)
    public var lengthInTicks: Int {
        return lengthInSteps * 24 // 24 ticks per step for 16th note resolution
    }
    
    /// Add event to step
    public func addEvent(_ event: MIDIEvent, at step: Int) {
        guard step >= 0 && step < lengthInSteps else { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        if steps[step] == nil {
            steps[step] = []
        }
        steps[step]?.append(event)
    }
    
    /// Remove event from step
    public func removeEvent(_ eventId: UUID, from step: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        steps[step]?.removeAll { $0.id == eventId }
    }
    
    /// Get events at step
    public func getEventsAtStep(_ step: Int) -> [MIDIEvent] {
        lock.lock()
        defer { lock.unlock() }
        
        return steps[step] ?? []
    }
    
    /// Get events at tick (for high-resolution playback)
    public func getEventsAtTick(_ tick: Int) -> [MIDIEvent] {
        let step = tick / 24 // Convert tick to step
        return getEventsAtStep(step)
    }
    
    /// Clear step
    public func clearStep(_ step: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        steps[step] = []
    }
    
    /// Clear all steps
    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        
        steps.removeAll()
    }
}

/// Record quantization options
public enum RecordQuantization: String, CaseIterable {
    case off
    case sixteenth
    case eighth
    case quarter
    case half
    case whole
}

/// Sequencer transport messages
public enum SequencerTransportMessage {
    case start
    case stop
    case `continue`
}

/// MIDI output port protocol
public protocol MIDIOutputPort: AnyObject {
    func send(_ message: MIDIMessage, timestamp: TimeInterval)
    func sendClock(timestamp: TimeInterval)
}

// MARK: - Delegate Protocol

/// MIDI sequencer delegate
public protocol MIDISequencerDelegate: AnyObject {
    func midiSequencer(_ sequencer: MIDISequencer, didAddTrack track: MIDITrack)
    func midiSequencer(_ sequencer: MIDISequencer, didRemoveTrack track: MIDITrack)
    func midiSequencer(_ sequencer: MIDISequencer, playbackStateChanged isPlaying: Bool)
    func midiSequencer(_ sequencer: MIDISequencer, tempoChanged bpm: Double)
    func midiSequencer(_ sequencer: MIDISequencer, positionChanged position: Double)
    func midiSequencer(_ sequencer: MIDISequencer, recordingStateChanged isRecording: Bool, track: MIDITrack)
    func midiSequencer(_ sequencer: MIDISequencer, didRecordEvent event: MIDIEvent, to track: MIDITrack)
    func midiSequencer(_ sequencer: MIDISequencer, didSendEvent event: MIDIEvent, from track: MIDITrack)
    func midiSequencer(_ sequencer: MIDISequencer, didSetPattern pattern: MIDIPattern, for track: MIDITrack)
}

// MARK: - Convenience Extensions

/// Convenience methods for creating common MIDI events
public extension MIDIEvent {
    static func noteOn(note: UInt8, velocity: UInt8, channel: UInt8 = 1, position: Double, duration: Double) -> MIDIEvent {
        return MIDIEvent(type: .noteOn, channel: channel, note: note, velocity: velocity, position: position, duration: duration)
    }
    
    static func noteOff(note: UInt8, channel: UInt8 = 1, position: Double) -> MIDIEvent {
        return MIDIEvent(type: .noteOff, channel: channel, note: note, velocity: 0, position: position)
    }
    
    static func controlChange(controller: UInt8, value: UInt8, channel: UInt8 = 1, position: Double) -> MIDIEvent {
        return MIDIEvent(type: .controlChange, channel: channel, controller: controller, value: value, position: position)
    }
}