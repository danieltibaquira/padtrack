//
//  FMToneVoiceMachineIntegrated.swift
//  DigitonePad - VoiceModule
//
//  Complete FM TONE Voice Machine with audio engine integration
//

import Foundation
import AudioEngine
import MachineProtocols
import os.signpost

/// Complete FM TONE Voice Machine implementing VoiceMachineProtocol
public final class FMToneVoiceMachineIntegrated: VoiceMachine, @unchecked Sendable {
    
    // MARK: - Core Components
    
    // FM TONE synthesis engine
    private let fmEngine: FMToneSynthesisEngine
    
    // Performance monitoring
    private let performanceMonitor = OSSignposter(logHandle: OSLog(subsystem: "com.digitonepad.voicemodule", category: "fm-tone-machine"))
    
    // FM TONE specific parameters
    private var currentAlgorithm: Int = 1
    private var masterTuning: Double = 0.0
    private var pitchBendValue: Double = 0.0
    private var modWheelValue: Double = 0.0
    
    // MIDI and modulation state
    private var pitchBendRange: Float = 2.0  // semitones
    private var velocitySensitivity: Float = 1.0
    private var currentPitchBend: Float = 0.0
    private var currentModWheel: Float = 0.0
    
    // Audio buffer management
    private var audioBufferSize: Int = 512
    private var lastProcessedFrameCount: Int = 0
    
    public override init(name: String = "FM TONE", polyphony: Int = 16) {
        // Initialize FM TONE synthesis engine
        self.fmEngine = FMToneSynthesisEngine(sampleRate: 44100.0, maxPolyphony: polyphony)
        
        super.init(name: name, polyphony: polyphony)
        
        setupFMToneParameters()
        setupDefaultPresets()
        
        os_signpost(.begin, log: performanceMonitor.logHandle, name: "FMToneVoiceMachine")
    }
    
    // MARK: - Audio Processing Override
    
    public override func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        lastActiveTimestamp = Date()
        
        os_signpost(.begin, log: performanceMonitor.logHandle, name: "ProcessAudio")
        defer { os_signpost(.end, log: performanceMonitor.logHandle, name: "ProcessAudio") }
        
        // Process FM TONE synthesis
        let frameCount = input.frameCount
        let channelCount = input.channelCount
        lastProcessedFrameCount = frameCount
        
        // Get synthesized audio from engine
        let fmOutput = fmEngine.processBuffer(frameCount: frameCount)
        
        // Create output buffer with proper memory management
        let totalSamples = frameCount * channelCount
        let outputData = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)
        outputData.initialize(repeating: 0.0, count: totalSamples)
        defer { outputData.deallocate() }
        
        let outputBuffer = AudioEngine.AudioBuffer(
            data: outputData,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: input.sampleRate
        )
        
        // Convert and distribute audio to all channels
        distributeAudioToChannels(
            fmOutput: fmOutput,
            outputData: outputData,
            frameCount: frameCount,
            channelCount: channelCount
        )
        
        // Update performance metrics
        updatePerformanceMetrics()
        
        return outputBuffer
    }
    
    private func distributeAudioToChannels(
        fmOutput: [Double],
        outputData: UnsafeMutablePointer<Float>,
        frameCount: Int,
        channelCount: Int
    ) {
        // Distribute mono FM output to all channels (interleaved format)
        for frame in 0..<frameCount {
            let sample = frame < fmOutput.count ? Float(fmOutput[frame]) : 0.0
            
            for channel in 0..<channelCount {
                let sampleIndex = frame * channelCount + channel
                outputData[sampleIndex] = sample
            }
        }
    }
    
    // MARK: - Voice Management Override
    
    public override func noteOn(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?) {
        super.noteOn(note: note, velocity: velocity, channel: channel, timestamp: timestamp)
        
        // Apply velocity sensitivity
        let adjustedVelocity = UInt8(Float(velocity) * velocitySensitivity)
        
        // Trigger FM engine with enhanced parameters
        let success = fmEngine.noteOn(note: note, velocity: adjustedVelocity, channel: channel)
        
        if !success {
            // Voice allocation failed - remove from base class tracking
            if let index = _voiceStates.firstIndex(where: { $0.note == note && $0.isActive }) {
                _voiceStates.remove(at: index)
                activeVoices = max(0, activeVoices - 1)
            }
        }
    }
    
    public override func noteOff(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?) {
        super.noteOff(note: note, velocity: velocity, channel: channel, timestamp: timestamp)
        
        // Release note in FM engine
        fmEngine.noteOff(note: note, velocity: velocity, channel: channel)
    }
    
    public override func allNotesOff() {
        super.allNotesOff()
        fmEngine.allNotesOff()
    }
    
    public override func allNotesOff(channel: UInt8) {
        super.allNotesOff(channel: channel)
        // For this implementation, treat channel-specific as global
        fmEngine.allNotesOff()
    }
    
    // MARK: - FM TONE Parameter Management
    
    private func setupFMToneParameters() {
        // Initialize VoiceMachine protocol parameters
        masterVolume = 0.8
        masterTuning = 0.0
        portamentoTime = 0.0
        portamentoEnabled = false
        velocitySensitivity = 1.0
        pitchBendRange = 2.0
        pitchBend = 0.0
        modWheel = 0.0
        
        // Set up FM-specific parameters
        currentAlgorithm = 1
        masterTuning = 0.0
        
        // Configure engine
        fmEngine.setMasterVolume(Double(masterVolume))
        fmEngine.setAlgorithm(currentAlgorithm)
        fmEngine.setPitchBendRange(Double(pitchBendRange))
    }
    
    private func setupDefaultPresets() {
        // Set up default FM TONE preset
        setAlgorithm(1) // Simple FM
        
        // Configure default operator settings through engine
        if let voice = fmEngine.getVoice(at: 0) {
            let params = voice.getParameterControl()
            
            // Operator 1 (Carrier)
            params.setParameter(.operator1FreqRatio, value: 1.0)
            params.setParameter(.operator1OutputLevel, value: 1.0)
            params.setParameter(.operator1ModIndex, value: 0.0)
            
            // Operator 2 (Modulator)
            params.setParameter(.operator2FreqRatio, value: 2.0)
            params.setParameter(.operator2OutputLevel, value: 0.8)
            params.setParameter(.operator2ModIndex, value: 3.0)
            
            // Operator 3
            params.setParameter(.operator3FreqRatio, value: 1.5)
            params.setParameter(.operator3OutputLevel, value: 0.6)
            params.setParameter(.operator3ModIndex, value: 1.5)
            
            // Operator 4
            params.setParameter(.operator4FreqRatio, value: 0.5)
            params.setParameter(.operator4OutputLevel, value: 0.4)
            params.setParameter(.operator4ModIndex, value: 0.8)
        }
    }
    
    // MARK: - VoiceMachine Protocol Parameter Implementation
    
    public override var masterVolume: Float {
        get { return Float(fmEngine.getPerformanceMetrics().totalProcessingTime > 0 ? 0.8 : 0.8) }
        set {
            super.masterVolume = newValue
            fmEngine.setMasterVolume(Double(newValue))
        }
    }
    
    public override var masterTuning: Float {
        get { return Float(masterTuning) }
        set {
            super.masterTuning = newValue
            masterTuning = Double(newValue)
            fmEngine.setMasterTuning(Double(newValue))
        }
    }
    
    public override var pitchBend: Float {
        get { return currentPitchBend }
        set {
            super.pitchBend = newValue
            currentPitchBend = newValue
            fmEngine.setPitchBend(Double(newValue))
        }
    }
    
    public override var modWheel: Float {
        get { return currentModWheel }
        set {
            super.modWheel = newValue
            currentModWheel = newValue
            fmEngine.setModWheel(Double(newValue))
        }
    }
    
    public override var pitchBendRange: Float {
        get { return pitchBendRange }
        set {
            super.pitchBendRange = newValue
            self.pitchBendRange = newValue
            fmEngine.setPitchBendRange(Double(newValue))
        }
    }
    
    // MARK: - FM TONE Specific Interface
    
    /// Set the FM algorithm (1-8)
    public func setAlgorithm(_ algorithmNumber: Int) {
        currentAlgorithm = max(1, min(8, algorithmNumber))
        fmEngine.setAlgorithm(currentAlgorithm)
    }
    
    /// Get current algorithm number
    public var algorithm: Int {
        return currentAlgorithm
    }
    
    /// Set operator frequency ratio
    public func setOperatorFrequencyRatio(_ operatorIndex: Int, ratio: Float) {
        guard operatorIndex >= 0 && operatorIndex < 4 else { return }
        
        // Apply to all voices
        for voiceIndex in 0..<polyphony {
            if let voice = fmEngine.getVoice(at: voiceIndex) {
                let params = voice.getParameterControl()
                let parameter: FMToneParameterControl.Parameter
                
                switch operatorIndex {
                case 0: parameter = .operator1FreqRatio
                case 1: parameter = .operator2FreqRatio
                case 2: parameter = .operator3FreqRatio
                case 3: parameter = .operator4FreqRatio
                default: return
                }
                
                params.setParameter(parameter, value: ratio)
            }
        }
    }
    
    /// Set operator output level
    public func setOperatorOutputLevel(_ operatorIndex: Int, level: Float) {
        guard operatorIndex >= 0 && operatorIndex < 4 else { return }
        
        // Apply to all voices
        for voiceIndex in 0..<polyphony {
            if let voice = fmEngine.getVoice(at: voiceIndex) {
                let params = voice.getParameterControl()
                let parameter: FMToneParameterControl.Parameter
                
                switch operatorIndex {
                case 0: parameter = .operator1OutputLevel
                case 1: parameter = .operator2OutputLevel
                case 2: parameter = .operator3OutputLevel
                case 3: parameter = .operator4OutputLevel
                default: return
                }
                
                params.setParameter(parameter, value: level)
            }
        }
    }
    
    /// Set operator modulation index
    public func setOperatorModulationIndex(_ operatorIndex: Int, index: Float) {
        guard operatorIndex >= 0 && operatorIndex < 4 else { return }
        
        // Apply to all voices
        for voiceIndex in 0..<polyphony {
            if let voice = fmEngine.getVoice(at: voiceIndex) {
                let params = voice.getParameterControl()
                let parameter: FMToneParameterControl.Parameter
                
                switch operatorIndex {
                case 0: parameter = .operator1ModIndex
                case 1: parameter = .operator2ModIndex
                case 2: parameter = .operator3ModIndex
                case 3: parameter = .operator4ModIndex
                default: return
                }
                
                params.setParameter(parameter, value: index)
            }
        }
    }
    
    // MARK: - Performance and Diagnostics
    
    /// Get current polyphony usage from engine
    public override var activeVoices: Int {
        return fmEngine.polyphonyUsage
    }
    
    /// Get FM engine performance metrics
    public func getFMPerformanceMetrics() -> FMToneDSPOptimizations.PerformanceMetrics {
        return fmEngine.getPerformanceMetrics()
    }
    
    /// Run performance benchmark
    public func runPerformanceBenchmark() -> FMToneDSPOptimizations.FMTonePerformanceBenchmark.BenchmarkResult? {
        return fmEngine.runPerformanceBenchmark()
    }
    
    /// Get voice pool usage
    public var voicePoolUsage: Float {
        return fmEngine.voicePoolUsage
    }
    
    private func updatePerformanceMetrics() {
        let fmMetrics = fmEngine.getPerformanceMetrics()
        
        // Update base class performance metrics
        performanceMetrics.totalProcessingTime = fmMetrics.totalProcessingTime
        performanceMetrics.peakProcessingTime = max(performanceMetrics.peakProcessingTime, fmMetrics.averageBlockTime)
        performanceMetrics.buffersProcessed = fmMetrics.blocksProcessed
        performanceMetrics.samplesProcessed = fmMetrics.samplesProcessed
        
        // Calculate CPU usage estimate
        if lastProcessedFrameCount > 0 {
            let sampleRate = 44100.0
            let realTimeForBuffer = Double(lastProcessedFrameCount) / sampleRate
            let cpuUsage = fmMetrics.averageBlockTime / realTimeForBuffer
            performanceMetrics.cpuUsage = Float(min(1.0, max(0.0, cpuUsage)))
        }
    }
    
    // MARK: - Advanced Features
    
    /// Enable/disable optimized DSP processing
    public func setOptimizedDSP(_ enabled: Bool) {
        let level: FMToneDSPOptimizations.OptimizationLevel = enabled ? .balanced : .minimal
        fmEngine.setOptimizationLevel(level)
    }
    
    /// Set DSP optimization level
    public func setOptimizationLevel(_ level: FMToneDSPOptimizations.OptimizationLevel) {
        fmEngine.setOptimizationLevel(level)
    }
    
    /// Emergency stop all voices immediately
    public func stopAllVoices() {
        fmEngine.stopAllVoices()
        super.allNotesOff()
    }
    
    /// Reset to initial state
    public override func reset() {
        super.reset()
        fmEngine.reset()
        setupFMToneParameters()
        setupDefaultPresets()
    }
    
    // MARK: - Voice-Specific Parameter Setup Override
    
    public override func setupVoiceParameters() {
        super.setupVoiceParameters()
        
        // Add FM TONE specific parameters to the parameter manager
        let parameterManager = parameters
        
        // Algorithm parameter
        parameterManager.addParameter(Parameter(
            id: "algorithm",
            name: "Algorithm",
            unit: "",
            range: 1...8,
            defaultValue: 1,
            flags: []
        ))
        
        // Operator parameters (4 operators × 3 parameters each)
        for op in 1...4 {
            parameterManager.addParameter(Parameter(
                id: "op\(op)_ratio",
                name: "Op\(op) Freq Ratio",
                unit: "",
                range: 0.1...16.0,
                defaultValue: op == 1 ? 1.0 : Float(op),
                flags: []
            ))
            
            parameterManager.addParameter(Parameter(
                id: "op\(op)_level",
                name: "Op\(op) Level",
                unit: "",
                range: 0.0...1.0,
                defaultValue: 1.0 / Float(op),
                flags: []
            ))
            
            parameterManager.addParameter(Parameter(
                id: "op\(op)_mod",
                name: "Op\(op) Mod Index",
                unit: "",
                range: 0.0...10.0,
                defaultValue: op > 1 ? Float(op) : 0.0,
                flags: []
            ))
        }
    }
    
    deinit {
        os_signpost(.end, log: performanceMonitor.logHandle, name: "FMToneVoiceMachine")
    }
} 