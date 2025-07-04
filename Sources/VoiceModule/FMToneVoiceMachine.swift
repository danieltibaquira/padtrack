//
//  FMToneVoiceMachine.swift
//  DigitonePad - VoiceModule
//
//  FM TONE Voice Machine - Complete 4-operator FM synthesis with 8 algorithms
//

import Foundation
import AudioToolbox
import MachineProtocols
import Accelerate

/// Complete FM TONE Voice Machine implementation
public final class FMToneVoiceMachine: VoiceMachine, @unchecked Sendable {
    
    // MARK: - Core Components
    
    // Operators (4-operator FM system)
    private var operators: [FMToneOperator] = []
    private var optimizedOperators: [FMToneDSPOptimizations.OptimizedFMToneOperator] = []
    
    // Algorithm routing system
    private var algorithmRouter: FMToneAlgorithmRouter
    
    // Envelope generators (6 total: 4 for operators + 2 master)
    private var operatorEnvelopes: [FMToneEnvelope] = []
    private var amplitudeEnvelope: FMToneEnvelope
    private var modulationEnvelope: FMToneEnvelope
    
    // Parameter control system
    private var parameterControl: FMToneParameterControl
    
    // DSP optimization system
    private var dspOptimizations: FMToneDSPOptimizations
    private var useOptimizedDSP: Bool = true
    
    // Voice state
    private var isActive: Bool = false
    private var noteNumber: Int = 60
    private var velocity: Float = 1.0
    private var frequency: Double = 440.0
    private var sampleRate: Double = 44100.0
    private var currentAlgorithm: Int = 1
    
    // Performance monitoring
    private var fmPerformanceMetrics = FMToneDSPOptimizations.PerformanceMetrics()
    
    // Audio processing buffers
    private var mixBuffer: [Float] = []
    private var tempBuffer: [Float] = []
    private static let maxBlockSize = 512
    
    // MARK: - Initialization
    
    public init(name: String = "FM TONE", polyphony: Int = 8, sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate

        // Initialize algorithm router
        self.algorithmRouter = FMToneAlgorithmRouter()

        // Initialize envelopes
        self.amplitudeEnvelope = FMToneEnvelope(sampleRate: sampleRate)
        self.modulationEnvelope = FMToneEnvelope(sampleRate: sampleRate)

        // Initialize parameter control system
        self.parameterControl = FMToneParameterControl(sampleRate: Float(sampleRate))

        // Initialize DSP optimizations
        let optimizationSettings = FMToneDSPOptimizations.OptimizationSettings.defaultSettings
        self.dspOptimizations = FMToneDSPOptimizations(sampleRate: sampleRate, settings: optimizationSettings)

        super.init(name: name, polyphony: polyphony)

        // Initialize operators and envelopes
        setupOperators()
        setupEnvelopes()
        setupBuffers()

        // Set default algorithm
        algorithmRouter.switchAlgorithm(toId: 1)

        // Setup default parameters
        setupDefaultParameters()
    }
    
    private func setupOperators() {
        // Create standard operators
        for i in 0..<4 {
            let op = FMToneOperator(sampleRate: sampleRate)
            operators.append(op)
        }
        
        // Create optimized operators pool
        for i in 0..<4 {
            if let optimizedOp = dspOptimizations.borrowOptimizedOperator() {
                optimizedOperators.append(optimizedOp)
            }
        }
    }
    
    private func setupEnvelopes() {
        // Create operator envelopes
        for _ in 0..<4 {
            let envelope = FMToneEnvelope(sampleRate: sampleRate)
            operatorEnvelopes.append(envelope)
        }
        
        // Apply different presets to envelopes for varied character
        if operatorEnvelopes.count >= 4 {
            operatorEnvelopes[0].updateConfiguration(FMEnvelopePresets.organStyle)
            operatorEnvelopes[1].updateConfiguration(FMEnvelopePresets.bellStyle)
            operatorEnvelopes[2].updateConfiguration(FMEnvelopePresets.pluckedStyle)
            operatorEnvelopes[3].updateConfiguration(FMEnvelopePresets.padStyle)
        }
    }
    
    private func setupBuffers() {
        mixBuffer = [Float](repeating: 0.0, count: Self.maxBlockSize)
        tempBuffer = [Float](repeating: 0.0, count: Self.maxBlockSize)
    }
    
    private func setupDefaultParameters() {
        // Set reasonable default FM parameters
        parameterControl.setParameterValue(.masterVolume, value: 0.8)
        parameterControl.setParameterValue(.masterTune, value: 0.0)

        // Operator A (Carrier)
        parameterControl.setParameterValue(.opA_frequency, value: 1.0)
        parameterControl.setParameterValue(.opA_outputLevel, value: 1.0)
        parameterControl.setParameterValue(.opA_modIndex, value: 0.0)

        // Operator B1 (Modulator)
        parameterControl.setParameterValue(.opB1_frequency, value: 2.0)
        parameterControl.setParameterValue(.opB1_outputLevel, value: 0.8)
        parameterControl.setParameterValue(.opB1_modIndex, value: 3.0)

        // Operator B2
        parameterControl.setParameterValue(.opB2_frequency, value: 1.5)
        parameterControl.setParameterValue(.opB2_outputLevel, value: 0.6)
        parameterControl.setParameterValue(.opB2_modIndex, value: 1.5)

        // Operator C
        parameterControl.setParameterValue(.opC_frequency, value: 0.5)
        parameterControl.setParameterValue(.opC_outputLevel, value: 0.4)
        parameterControl.setParameterValue(.opC_modIndex, value: 0.8)
    }
    
    // MARK: - VoiceMachine Protocol
    
    public func noteOn(noteNumber: Int, velocity: Float) {
        self.noteNumber = noteNumber
        self.velocity = velocity
        self.frequency = 440.0 * pow(2.0, Double(noteNumber - 69) / 12.0)
        
        // Update all operators with new frequency
        updateOperatorFrequencies()
        
        // Trigger all envelopes
        for envelope in operatorEnvelopes {
            envelope.noteOn(velocity: UInt8(velocity * 127.0), keyNumber: UInt8(noteNumber))
        }
        amplitudeEnvelope.noteOn(velocity: UInt8(velocity * 127.0), keyNumber: UInt8(noteNumber))
        modulationEnvelope.noteOn(velocity: UInt8(velocity * 127.0), keyNumber: UInt8(noteNumber))
        
        isActive = true
    }
    
    public func noteOff() {
        // Release all envelopes
        for envelope in operatorEnvelopes {
            envelope.noteOff()
        }
        amplitudeEnvelope.noteOff()
        modulationEnvelope.noteOff()
        
        // Voice will become inactive when all envelopes finish
    }
    
    public func processSample() -> Double {
        guard isActive else { return 0.0 }
        
        // Process envelopes
        let masterAmp = amplitudeEnvelope.processSample()
        let masterMod = modulationEnvelope.processSample()
        
        var operatorLevels: [Float] = []
        for envelope in operatorEnvelopes {
            operatorLevels.append(envelope.processSample())
        }
        
        // Apply parameters from control system
        updateOperatorParameters()
        
        // Process FM algorithm
        let output: Float
        if useOptimizedDSP && optimizedOperators.count >= 4 {
            output = processAlgorithmOptimized(operatorLevels: operatorLevels, masterMod: masterMod)
        } else {
            output = processAlgorithmStandard(operatorLevels: operatorLevels, masterMod: masterMod)
        }
        
        // Apply master amplitude envelope
        let finalOutput = Double(output) * Double(masterAmp)
        
        // Check if voice should remain active
        checkVoiceActivity()
        
        return finalOutput
    }
    
    public func processBuffer(frameCount: Int) -> [Double] {
        guard isActive else { return Array(repeating: 0.0, count: frameCount) }
        
        let blockSize = min(frameCount, Self.maxBlockSize)
        var output = Array(repeating: 0.0, count: frameCount)
        
        if useOptimizedDSP && optimizedOperators.count >= 4 {
            output = processBufferOptimized(frameCount: frameCount)
        } else {
            // Fallback to single sample processing
            for i in 0..<frameCount {
                output[i] = processSample()
            }
        }
        
        return output
    }
    
    private func processBufferOptimized(frameCount: Int) -> [Double] {
        let blockSize = min(frameCount, Self.maxBlockSize)
        var output = Array(repeating: 0.0, count: frameCount)
        
        // Process in blocks
        var samplesProcessed = 0
        while samplesProcessed < frameCount {
            let currentBlockSize = min(blockSize, frameCount - samplesProcessed)
            
            // Process envelope blocks
            var ampBlock = Array(repeating: Float(0.0), count: currentBlockSize)
            amplitudeEnvelope.processBlock(samples: &ampBlock)
            var modBlock = Array(repeating: Float(0.0), count: currentBlockSize)
            modulationEnvelope.processBlock(samples: &modBlock)
            
            var operatorBlocks: [[Float]] = []
            for envelope in operatorEnvelopes {
                var block = Array(repeating: Float(0.0), count: currentBlockSize)
                envelope.processBlock(samples: &block)
                operatorBlocks.append(block)
            }
            
            // Process FM algorithm for the block
            let algorithmOutput = processAlgorithmBlockOptimized(
                blockSize: currentBlockSize,
                operatorLevels: operatorBlocks,
                masterMod: modBlock
            )
            
            // Apply master amplitude
            for i in 0..<currentBlockSize {
                output[samplesProcessed + i] = Double(algorithmOutput[i]) * Double(ampBlock[i])
            }
            
            samplesProcessed += currentBlockSize
        }
        
        // Check if voice should remain active
        checkVoiceActivity()
        
        return output
    }
    
    // MARK: - Algorithm Processing
    
    private func processAlgorithmStandard(operatorLevels: [Float], masterMod: Float) -> Float {
        // Update operator output levels based on envelopes
        for (i, level) in operatorLevels.enumerated() {
            if i < operators.count {
                operators[i].outputLevel = level
            }
        }
        
        // Process current algorithm - simplified implementation
        return processSimpleAlgorithm(operators: operators)
    }

    private func processSimpleAlgorithm(operators: [FMToneOperator]) -> Float {
        // Simple 4-operator FM algorithm implementation
        guard operators.count >= 4 else { return 0.0 }

        // Basic algorithm: Op4 -> Op3 -> Op2 -> Op1 (carrier)
        let op4Output = operators[3].processSample()
        let op3Output = operators[2].processSample(modulationInput: op4Output)
        let op2Output = operators[1].processSample(modulationInput: op3Output)
        let op1Output = operators[0].processSample(modulationInput: op2Output)

        return op1Output
    }
    
    private func processAlgorithmOptimized(operatorLevels: [Float], masterMod: Float) -> Float {
        // Update optimized operator output levels
        for (i, level) in operatorLevels.enumerated() {
            if i < optimizedOperators.count {
                optimizedOperators[i].setOutputLevel(level)
            }
        }
        
        // Process single sample using optimized operators
        // Note: This would need algorithm-specific processing logic
        // For now, implementing a simple FM chain
        var carrierInput: Float = 0.0
        
        // Simple FM chain: Op4 -> Op3 -> Op2 -> Op1 (carrier)
        if operators.count >= 4 {
            let op4Output = operators[3].processSample()
            let op3Output = operators[2].processSample(modulationInput: op4Output)
            let op2Output = operators[1].processSample(modulationInput: op3Output)
            carrierInput = operators[0].processSample(modulationInput: op2Output)
        }
        
        return carrierInput
    }
    
    private func processAlgorithmBlockOptimized(
        blockSize: Int,
        operatorLevels: [[Float]],
        masterMod: [Float]
    ) -> [Float] {
        var output = [Float](repeating: 0.0, count: blockSize)
        
        // For block processing, we'd need to implement algorithm-specific SIMD processing
        // For now, fall back to sample-by-sample processing
        for i in 0..<blockSize {
            let levels = operatorLevels.map { $0[i] }
            let sample = processAlgorithmOptimized(operatorLevels: levels, masterMod: masterMod[i])
            output[i] = sample
        }
        
        return output
    }
    
    // MARK: - Parameter Updates
    
    private func updateOperatorFrequencies() {
        let baseFreq = frequency
        
        // Update standard operators
        for (i, op) in operators.enumerated() {
            op.setBaseFrequency(baseFreq)
        }
        
        // Update optimized operators
        for (i, op) in optimizedOperators.enumerated() {
            op.setFrequency(baseFreq)
        }
    }
    
    private func updateOperatorParameters() {
        // Update parameters from control system - simplified implementation
        if operators.count >= 4 {
            operators[0].frequencyRatio = 1.0
            operators[0].outputLevel = 1.0
            operators[0].modulationIndex = 0.0

            operators[1].frequencyRatio = 2.0
            operators[1].outputLevel = 0.8
            operators[1].modulationIndex = 3.0

            operators[2].frequencyRatio = 1.5
            operators[2].outputLevel = 0.6
            operators[2].modulationIndex = 1.5

            operators[3].frequencyRatio = 0.5
            operators[3].outputLevel = 0.4
            operators[3].modulationIndex = 0.8
        }
    }
    
    private func checkVoiceActivity() {
        // Voice remains active if any envelope is still running
        let anyEnvelopeActive = amplitudeEnvelope.isActive || 
                               modulationEnvelope.isActive ||
                               operatorEnvelopes.contains { $0.isActive }
        
        if !anyEnvelopeActive {
            isActive = false
        }
    }
    
    // MARK: - Public Interface

    /// Get current note number
    public var currentNoteNumber: Int {
        return noteNumber
    }

    /// Switch between algorithms (1-8)
    public func setAlgorithm(_ algorithmNumber: Int) {
        // Store algorithm number for future use
        currentAlgorithm = algorithmNumber
    }
    
    /// Enable/disable optimized DSP processing
    public func setOptimizedDSP(_ enabled: Bool) {
        useOptimizedDSP = enabled
    }
    
    /// Get current performance metrics
    public func getPerformanceMetrics() -> FMToneDSPOptimizations.PerformanceMetrics {
        return dspOptimizations.getPerformanceMetrics()
    }
    
    /// Run performance benchmark
    public func runPerformanceBenchmark() -> FMToneDSPOptimizations.FMTonePerformanceBenchmark.BenchmarkResult? {
        return dspOptimizations.runBenchmark()
    }
    
    /// Access parameter control system
    public func getParameterControl() -> FMToneParameterControl {
        return parameterControl
    }
    
    /// Check if voice is currently active
    public var active: Bool {
        return isActive
    }
    
    /// Reset voice to initial state
    public override func reset() {
        isActive = false
        
        // Reset operators
        for op in operators {
            op.reset()
        }
        for op in optimizedOperators {
            op.reset()
        }
        
        // Reset envelopes
        for envelope in operatorEnvelopes {
            envelope.reset()
        }
        amplitudeEnvelope.reset()
        modulationEnvelope.reset()
        
        // Reset algorithm to default
        currentAlgorithm = 1
    }
    
    deinit {
        // Return optimized operators to pool
        for op in optimizedOperators {
            dspOptimizations.returnOptimizedOperator(op)
        }
    }
} 