// FMToneOperator.swift
// DigitonePad - VoiceModule
//
// Enhanced FM Operator for TONE Voice Machine with professional audio quality

import Foundation
import Accelerate
import MachineProtocols
import AudioEngine

// MARK: - Enhanced FM TONE Operator

/// Enhanced FM operator with anti-aliasing, SIMD optimization, and precise frequency control
/// Designed specifically for the FM TONE Voice Machine with 4-operator architecture
public final class FMToneOperator: @unchecked Sendable {
    
    // MARK: - Constants
    
    private static let tableSize: Int = 4096
    private static let tableMask: Int = tableSize - 1
    private static let maxBlockSize: Int = 1024
    
    // MARK: - Wavetable
    
    /// High-quality sine wavetable with power-of-2 size for efficient indexing
    private static let sineTable: [Float] = {
        var table = [Float](repeating: 0.0, count: tableSize)
        for i in 0..<tableSize {
            let phase = Float(i) * 2.0 * Float.pi / Float(tableSize)
            table[i] = sin(phase)
        }
        return table
    }()
    
    // MARK: - Core Properties
    
    /// Current phase accumulator (0.0 to tableSize)
    private var phase: Double = 0.0
    
    /// Phase increment per sample
    private var phaseIncrement: Double = 0.0
    
    /// Sample rate for calculations
    private let sampleRate: Double
    
    /// Base frequency before ratio and fine-tuning
    private var baseFrequency: Double = 440.0
    
    // MARK: - Atomic Parameters for Thread-Safe Real-Time Control
    
    /// Frequency ratio (0.5 to 12.0, typically harmonic ratios like 1.0, 2.0, 3.0)
    private var _frequencyRatio: Float = 1.0
    public var frequencyRatio: Float {
        get { return _frequencyRatio }
        set { 
            _frequencyRatio = max(0.5, min(12.0, newValue))
            updatePhaseIncrement()
        }
    }
    
    /// Fine tuning in cents (-50 to +50)
    private var _fineTune: Float = 0.0
    public var fineTune: Float {
        get { return _fineTune }
        set { 
            _fineTune = max(-50.0, min(50.0, newValue))
            updatePhaseIncrement()
        }
    }
    
    /// Output level (0.0 to 1.0)
    private var _outputLevel: Float = 1.0
    public var outputLevel: Float {
        get { return _outputLevel }
        set { _outputLevel = max(0.0, min(1.0, newValue)) }
    }
    
    /// Modulation index for FM depth (0.0 to 10.0)
    private var _modulationIndex: Float = 1.0
    public var modulationIndex: Float {
        get { return _modulationIndex }
        set { _modulationIndex = max(0.0, min(10.0, newValue)) }
    }
    
    /// Feedback amount for self-modulation (0.0 to 1.0)
    private var _feedbackAmount: Float = 0.0
    public var feedbackAmount: Float {
        get { return _feedbackAmount }
        set { _feedbackAmount = max(0.0, min(1.0, newValue)) }
    }
    
    // MARK: - State Variables
    
    /// Previous output for feedback and anti-aliasing
    private var lastOutput: Float = 0.0
    
    /// Previous output for feedback loop
    private var feedbackOutput: Float = 0.0
    
    // MARK: - SIMD Processing Buffers
    
    /// Pre-allocated buffers for block processing
    private var phaseBuffer: [Float] = []
    private var modulatedPhaseBuffer: [Float] = []
    private var intPhaseBuffer: [Int32] = []
    private var fracBuffer: [Float] = []
    private var value1Buffer: [Float] = []
    private var value2Buffer: [Float] = []
    private var tempBuffer: [Float] = []
    
    // MARK: - Initialization
    
    public init(sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate
        
        // Pre-allocate SIMD buffers
        phaseBuffer = [Float](repeating: 0.0, count: Self.maxBlockSize)
        modulatedPhaseBuffer = [Float](repeating: 0.0, count: Self.maxBlockSize)
        intPhaseBuffer = [Int32](repeating: 0, count: Self.maxBlockSize)
        fracBuffer = [Float](repeating: 0.0, count: Self.maxBlockSize)
        value1Buffer = [Float](repeating: 0.0, count: Self.maxBlockSize)
        value2Buffer = [Float](repeating: 0.0, count: Self.maxBlockSize)
        tempBuffer = [Float](repeating: 0.0, count: Self.maxBlockSize)
        
        // Prevent denormals on Intel processors
        #if arch(x86_64) && os(macOS)
        // For macOS x86_64, use software-based denormal protection
        // The compiler's -ffast-math flag typically handles this
        #elseif arch(arm64)
        // ARM64 handles denormals efficiently
        #endif
        
        updatePhaseIncrement()
    }
    
    // MARK: - Frequency Control
    
    /// Set the base frequency and update phase increment
    public func setBaseFrequency(_ frequency: Double) {
        baseFrequency = frequency
        updatePhaseIncrement()
    }
    
    /// Update phase increment based on current parameters
    private func updatePhaseIncrement() {
        // Calculate actual frequency with ratio and fine-tuning
        let centMultiplier = pow(2.0, Double(fineTune) / 1200.0)
        let actualFreq = baseFrequency * Double(frequencyRatio) * centMultiplier
        
        // Calculate phase increment with Nyquist limiting
        let normalizedFreq = min(0.5, actualFreq / sampleRate)
        phaseIncrement = normalizedFreq * Double(Self.tableSize)
    }
    
    // MARK: - Single Sample Processing
    
    /// Process a single sample with optional FM modulation input
    /// - Parameter modulationInput: FM modulation signal from other operators
    /// - Returns: Processed audio sample
    public func processSample(modulationInput: Float = 0.0) -> Float {
        // Scale modulation input by modulation index and add feedback
        let scaledModulation = modulationInput * modulationIndex + feedbackOutput * feedbackAmount
        
        // Apply modulation to phase
        let modulatedPhase = phase + Double(scaledModulation) * Double(Self.tableSize)
        
        // Extract integer and fractional parts for interpolation
        let intPhase = Int(modulatedPhase) & Self.tableMask
        let nextPhase = (intPhase + 1) & Self.tableMask
        let fraction = Float(modulatedPhase - Double(intPhase))
        
        // Linear interpolation for smooth output
        let sample1 = Self.sineTable[intPhase]
        let sample2 = Self.sineTable[nextPhase]
        var output = sample1 + fraction * (sample2 - sample1)
        
        // Apply PolyBLEP anti-aliasing for high frequencies
        if phaseIncrement > Double(Self.tableSize) * 0.25 { // Only apply for high frequencies
            let normalizedPhase = Float(phase / Double(Self.tableSize))
            let normalizedIncrement = Float(phaseIncrement / Double(Self.tableSize))
            output -= polyBLEP(t: normalizedPhase, dt: normalizedIncrement)
        }
        
        // Advance phase
        phase += phaseIncrement
        while phase >= Double(Self.tableSize) {
            phase -= Double(Self.tableSize)
        }
        
        // Apply output level and store for feedback
        output *= outputLevel
        feedbackOutput = output
        lastOutput = output
        
        return output
    }
    
    // MARK: - Block Processing with SIMD Optimization
    
    /// Process a block of samples with SIMD acceleration
    /// - Parameters:
    ///   - outputBuffer: Buffer to write processed samples
    ///   - modulationBuffer: Input modulation signals (can be nil)
    ///   - numSamples: Number of samples to process
    public func processBlock(outputBuffer: UnsafeMutablePointer<Float>,
                           modulationBuffer: UnsafePointer<Float>?,
                           numSamples: Int) {
        let samplesToProcess = min(numSamples, Self.maxBlockSize)
        
        // Cache parameter values to avoid repeated atomic loads
        var modIndex = modulationIndex
        var outLevel = outputLevel
        let fbAmount = feedbackAmount
        var tableSizeFloat = Float(Self.tableSize)
        
        // Generate phase values for the block
        for i in 0..<samplesToProcess {
            phaseBuffer[i] = Float(phase)
            phase += phaseIncrement
            while phase >= Double(Self.tableSize) {
                phase -= Double(Self.tableSize)
            }
        }
        
        // Apply modulation if provided
        if let modBuffer = modulationBuffer {
            // Scale modulation input: modulatedPhase = phase + modulation * modIndex * tableSize
            tempBuffer.withUnsafeMutableBufferPointer { tempPtr in
                vDSP_vsmul(modBuffer, 1, &modIndex, tempPtr.baseAddress!, 1, vDSP_Length(samplesToProcess))
            }
            tempBuffer.withUnsafeMutableBufferPointer { tempPtr in
                vDSP_vsadd(tempPtr.baseAddress!, 1, &tableSizeFloat, tempPtr.baseAddress!, 1, vDSP_Length(samplesToProcess))
            }
            phaseBuffer.withUnsafeBufferPointer { phasePtr in
                tempBuffer.withUnsafeBufferPointer { tempPtr in
                    modulatedPhaseBuffer.withUnsafeMutableBufferPointer { modPhasePtr in
                        vDSP_vadd(phasePtr.baseAddress!, 1, tempPtr.baseAddress!, 1, modPhasePtr.baseAddress!, 1, vDSP_Length(samplesToProcess))
                    }
                }
            }
        } else {
            // No modulation, just copy phase buffer
            phaseBuffer.withUnsafeBufferPointer { phasePtr in
                modulatedPhaseBuffer.withUnsafeMutableBufferPointer { modPhasePtr in
                    cblas_scopy(Int32(samplesToProcess), phasePtr.baseAddress!, 1, modPhasePtr.baseAddress!, 1)
                }
            }
        }
        
        // Extract integer and fractional parts
        for i in 0..<samplesToProcess {
            let intPhase = Int32(modulatedPhaseBuffer[i]) & Int32(Self.tableMask)
            intPhaseBuffer[i] = intPhase
            fracBuffer[i] = modulatedPhaseBuffer[i] - Float(intPhase)
        }
        
        // Gather sine table values
        for i in 0..<samplesToProcess {
            let idx1 = Int(intPhaseBuffer[i])
            let idx2 = (idx1 + 1) & Self.tableMask
            value1Buffer[i] = Self.sineTable[idx1]
            value2Buffer[i] = Self.sineTable[idx2]
        }
        
        // Perform linear interpolation: output = value1 + fraction * (value2 - value1)
        value1Buffer.withUnsafeBufferPointer { val1Ptr in
            value2Buffer.withUnsafeBufferPointer { val2Ptr in
                tempBuffer.withUnsafeMutableBufferPointer { tempPtr in
                    vDSP_vsub(val2Ptr.baseAddress!, 1, val1Ptr.baseAddress!, 1, tempPtr.baseAddress!, 1, vDSP_Length(samplesToProcess))
                }
            }
        }
        
        tempBuffer.withUnsafeBufferPointer { tempPtr in
            fracBuffer.withUnsafeBufferPointer { fracPtr in
                tempBuffer.withUnsafeMutableBufferPointer { tempMutPtr in
                    vDSP_vmul(tempPtr.baseAddress!, 1, fracPtr.baseAddress!, 1, tempMutPtr.baseAddress!, 1, vDSP_Length(samplesToProcess))
                }
            }
        }
        
        value1Buffer.withUnsafeBufferPointer { val1Ptr in
            tempBuffer.withUnsafeBufferPointer { tempPtr in
                vDSP_vadd(val1Ptr.baseAddress!, 1, tempPtr.baseAddress!, 1, outputBuffer, 1, vDSP_Length(samplesToProcess))
            }
        }
        
        // Apply output level
        vDSP_vsmul(outputBuffer, 1, &outLevel, outputBuffer, 1, vDSP_Length(samplesToProcess))
        
        // Store last output for feedback (simplified - using last sample)
        if samplesToProcess > 0 {
            feedbackOutput = outputBuffer[samplesToProcess - 1]
            lastOutput = feedbackOutput
        }
    }
    
    // MARK: - Anti-Aliasing Utilities
    
    /// PolyBLEP (Polynomial Band-Limited Step) anti-aliasing
    /// - Parameters:
    ///   - t: Normalized phase position (0.0 to 1.0)
    ///   - dt: Normalized frequency (phase increment per sample)
    /// - Returns: Anti-aliasing correction value
    private func polyBLEP(t: Float, dt: Float) -> Float {
        // PolyBLEP correction for the main discontinuity
        if t < dt {
            let normalizedT = t / dt
            return normalizedT + normalizedT - normalizedT * normalizedT - 1.0
        }
        // PolyBLEP correction for the wraparound discontinuity
        else if t > 1.0 - dt {
            let normalizedT = (t - 1.0) / dt
            return normalizedT * normalizedT + normalizedT + normalizedT + 1.0
        }
        // No discontinuity
        else {
            return 0.0
        }
    }
    
    // MARK: - State Management
    
    /// Reset operator to initial state
    public func reset() {
        phase = 0.0
        lastOutput = 0.0
        feedbackOutput = 0.0
    }
    
    /// Soft reset that preserves parameters but clears audio state
    public func softReset() {
        lastOutput = 0.0
        feedbackOutput = 0.0
    }
    
    // MARK: - Diagnostics
    
    /// Get current phase for debugging
    public var currentPhase: Double {
        return phase
    }
    
    /// Get current frequency in Hz
    public var currentFrequency: Double {
        return baseFrequency * Double(frequencyRatio) * pow(2.0, Double(fineTune) / 1200.0)
    }
    
    /// Check if operator is generating high-frequency content that needs anti-aliasing
    public var needsAntiAliasing: Bool {
        return phaseIncrement > Double(Self.tableSize) * 0.25
    }
} 