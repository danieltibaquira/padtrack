//
//  FMDrumDSPOptimizations.swift
//  DigitonePad - VoiceModule
//
//  Optimized DSP algorithms for FM DRUM voice machine
//

import Foundation
import Accelerate
import simd

/// High-performance DSP optimizations for FM DRUM synthesis
public final class FMDrumDSPOptimizations: @unchecked Sendable {
    
    // MARK: - SIMD-Optimized FM Operator
    
    /// Optimized FM operator using SIMD instructions
    public final class OptimizedFMOperator: @unchecked Sendable {
        // Core properties (aligned for SIMD)
        private var frequency: Double = 440.0
        private var amplitude: Double = 1.0
        private var phase: Double = 0.0
        private var phaseIncrement: Double = 0.0
        
        // Modulation properties
        private var modulationIndex: Double = 0.0
        private var feedbackAmount: Double = 0.0
        private var pitchModulation: Double = 0.0
        
        // State
        private let sampleRate: Double
        private var previousOutput: Double = 0.0
        
        // SIMD optimization buffers
        private var phaseBuffer: [Double] = []
        private var outputBuffer: [Double] = []
        private let vectorSize = 4 // Process 4 samples at once
        
        public init(sampleRate: Double) {
            self.sampleRate = sampleRate
            self.phaseBuffer = Array(repeating: 0.0, count: vectorSize)
            self.outputBuffer = Array(repeating: 0.0, count: vectorSize)
            updatePhaseIncrement()
        }
        
        /// Process multiple samples using SIMD
        public func processVector(modulationInput: [Double] = []) -> [Double] {
            let inputCount = max(vectorSize, modulationInput.count)
            var output = Array(repeating: 0.0, count: inputCount)
            
            // Process in SIMD-sized chunks
            for i in stride(from: 0, to: inputCount, by: vectorSize) {
                let endIndex = min(i + vectorSize, inputCount)
                let chunkSize = endIndex - i
                
                // Prepare phase values
                for j in 0..<chunkSize {
                    phaseBuffer[j] = phase + Double(j) * phaseIncrement
                }
                
                // Apply modulation if present
                if !modulationInput.isEmpty {
                    for j in 0..<chunkSize {
                        let modIndex = min(i + j, modulationInput.count - 1)
                        phaseBuffer[j] += modulationInput[modIndex] * modulationIndex
                    }
                }
                
                // Apply feedback
                if feedbackAmount > 0.0 {
                    for j in 0..<chunkSize {
                        phaseBuffer[j] += previousOutput * feedbackAmount
                    }
                }
                
                // Compute sine values using vDSP
                var phaseFloat = phaseBuffer.map { Float($0) }
                var outputFloat = Array<Float>(repeating: 0.0, count: chunkSize)
                
                vvsinf(&outputFloat, &phaseFloat, [Int32(chunkSize)])
                
                // Apply amplitude and store results
                for j in 0..<chunkSize {
                    output[i + j] = Double(outputFloat[j]) * amplitude
                }
                
                // Update phase
                phase += Double(chunkSize) * phaseIncrement
                
                // Wrap phase to avoid overflow
                if phase > 2.0 * .pi {
                    phase = phase.truncatingRemainder(dividingBy: 2.0 * .pi)
                }
                
                // Store last output for feedback
                if chunkSize > 0 {
                    previousOutput = output[i + chunkSize - 1]
                }
            }
            
            return output
        }
        
        /// Single sample processing (fallback)
        public func processSample(modulationInput: Double = 0.0) -> Double {
            // Apply modulation and feedback
            let modulatedPhase = phase + modulationInput * modulationIndex + previousOutput * feedbackAmount
            
            // Generate sine wave
            let output = sin(modulatedPhase) * amplitude
            
            // Update phase
            phase += phaseIncrement
            if phase > 2.0 * .pi {
                phase -= 2.0 * .pi
            }
            
            previousOutput = output
            return output
        }
        
        public func setFrequency(_ freq: Double) {
            frequency = freq
            updatePhaseIncrement()
        }
        
        public func setAmplitude(_ amp: Double) {
            amplitude = amp
        }
        
        public func setPitchModulation(_ mod: Double) {
            pitchModulation = mod
            updatePhaseIncrement()
        }
        
        private func updatePhaseIncrement() {
            let modulatedFreq = frequency * (1.0 + pitchModulation)
            phaseIncrement = 2.0 * .pi * modulatedFreq / sampleRate
        }
        
        public func reset() {
            phase = 0.0
            previousOutput = 0.0
        }
    }
    
    // MARK: - Optimized Noise Generator
    
    /// High-performance noise generator using SIMD
    public final class OptimizedNoiseGenerator: @unchecked Sendable {
        private var level: Double = 1.0
        private var noiseType: NoiseType = .white
        
        // Pink noise filter state
        private var pinkState: [Double] = Array(repeating: 0.0, count: 7)
        private var brownState: Double = 0.0
        
        // SIMD buffers
        private let vectorSize = 8
        private var noiseBuffer: [Float] = []
        
        public init() {
            self.noiseBuffer = Array(repeating: 0.0, count: vectorSize)
        }
        
        /// Generate multiple noise samples using SIMD
        public func processVector(sampleCount: Int) -> [Double] {
            var output = Array(repeating: 0.0, count: sampleCount)
            
            // Process in SIMD-sized chunks
            for i in stride(from: 0, to: sampleCount, by: vectorSize) {
                let endIndex = min(i + vectorSize, sampleCount)
                let chunkSize = endIndex - i
                
                // Generate white noise using arc4random for better performance
                for j in 0..<chunkSize {
                    let randomValue = arc4random_uniform(UInt32.max)
                    noiseBuffer[j] = (Float(randomValue) / Float(UInt32.max)) * 2.0 - 1.0
                }
                
                // Apply noise coloring
                switch noiseType {
                case .white:
                    for j in 0..<chunkSize {
                        output[i + j] = Double(noiseBuffer[j]) * level
                    }
                    
                case .pink:
                    for j in 0..<chunkSize {
                        output[i + j] = processPinkNoise(Double(noiseBuffer[j])) * level
                    }
                    
                case .brown:
                    for j in 0..<chunkSize {
                        output[i + j] = processBrownNoise(Double(noiseBuffer[j])) * level
                    }
                }
            }
            
            return output
        }
        
        public func processSample() -> Double {
            let whiteSample = (Double(arc4random_uniform(UInt32.max)) / Double(UInt32.max)) * 2.0 - 1.0
            
            switch noiseType {
            case .white:
                return whiteSample * level
            case .pink:
                return processPinkNoise(whiteSample) * level
            case .brown:
                return processBrownNoise(whiteSample) * level
            }
        }
        
        private func processPinkNoise(_ input: Double) -> Double {
            // Paul Kellet's pink noise algorithm (optimized)
            pinkState[0] = 0.99886 * pinkState[0] + input * 0.0555179
            pinkState[1] = 0.99332 * pinkState[1] + input * 0.0750759
            pinkState[2] = 0.96900 * pinkState[2] + input * 0.1538520
            pinkState[3] = 0.86650 * pinkState[3] + input * 0.3104856
            pinkState[4] = 0.55000 * pinkState[4] + input * 0.5329522
            pinkState[5] = -0.7616 * pinkState[5] - input * 0.0168980
            
            let output = pinkState[0] + pinkState[1] + pinkState[2] + pinkState[3] + pinkState[4] + pinkState[5] + pinkState[6] + input * 0.5362
            pinkState[6] = input * 0.115926
            
            return output * 0.11
        }
        
        private func processBrownNoise(_ input: Double) -> Double {
            brownState += input * 0.02
            brownState = max(-1.0, min(1.0, brownState))
            return brownState
        }
        
        public func setLevel(_ level: Double) {
            self.level = max(0.0, min(1.0, level))
        }
        
        public func setNoiseType(_ type: NoiseType) {
            self.noiseType = type
        }
    }
    
    // MARK: - Optimized Bandpass Filter
    
    /// High-performance bandpass filter using biquad implementation
    public final class OptimizedBandpassFilter: @unchecked Sendable {
        private let sampleRate: Double
        private var frequency: Double = 1000.0
        private var resonance: Double = 0.5
        
        // Biquad filter state (optimized for cache locality)
        private var x1: Double = 0.0
        private var x2: Double = 0.0
        private var y1: Double = 0.0
        private var y2: Double = 0.0
        
        // Filter coefficients (pre-computed)
        private var a0: Double = 1.0
        private var a1: Double = 0.0
        private var a2: Double = 0.0
        private var b1: Double = 0.0
        private var b2: Double = 0.0
        
        // SIMD processing buffers
        private let vectorSize = 4
        private var inputBuffer: [Double] = []
        private var outputBuffer: [Double] = []
        
        public init(sampleRate: Double) {
            self.sampleRate = sampleRate
            self.inputBuffer = Array(repeating: 0.0, count: vectorSize)
            self.outputBuffer = Array(repeating: 0.0, count: vectorSize)
            updateCoefficients()
        }
        
        /// Process multiple samples using optimized biquad
        public func processVector(_ input: [Double], cutoffMod: Double = 0.0) -> [Double] {
            let sampleCount = input.count
            var output = Array(repeating: 0.0, count: sampleCount)
            
            // Update coefficients if modulation is applied
            if cutoffMod != 0.0 {
                let modulatedFreq = frequency * (1.0 + cutoffMod)
                updateCoefficients(freq: modulatedFreq)
            }
            
            // Process samples using direct form II biquad
            for i in 0..<sampleCount {
                let x0 = input[i]
                
                // Direct form II biquad implementation
                let w = x0 - b1 * x1 - b2 * x2
                let y0 = a0 * w + a1 * x1 + a2 * x2
                
                // Update state
                x2 = x1
                x1 = w
                
                output[i] = y0
            }
            
            return output
        }
        
        public func process(input: Double, cutoffMod: Double = 0.0) -> Double {
            // Update coefficients if modulation is applied
            if cutoffMod != 0.0 {
                let modulatedFreq = frequency * (1.0 + cutoffMod)
                updateCoefficients(freq: modulatedFreq)
            }
            
            // Direct form II biquad
            let w = input - b1 * y1 - b2 * y2
            let output = a0 * w + a1 * y1 + a2 * y2
            
            // Update state
            y2 = y1
            y1 = w
            
            return output
        }
        
        public func setCutoff(frequency: Double, resonance: Double) {
            self.frequency = frequency
            self.resonance = resonance
            updateCoefficients()
        }
        
        private func updateCoefficients(freq: Double? = nil) {
            let f = freq ?? frequency
            let omega = 2.0 * .pi * f / sampleRate
            let alpha = sin(omega) / (2.0 * resonance)
            
            let cosOmega = cos(omega)
            
            // Bandpass filter coefficients
            let norm = 1.0 + alpha
            a0 = alpha / norm
            a1 = 0.0
            a2 = -alpha / norm
            b1 = -2.0 * cosOmega / norm
            b2 = (1.0 - alpha) / norm
        }
    }
    
    // MARK: - Memory Pool for DSP Objects
    
    /// Memory pool for reusing DSP objects to minimize allocations
    public final class DSPObjectPool: @unchecked Sendable {
        private var operatorPool: [OptimizedFMOperator] = []
        private var noiseGeneratorPool: [OptimizedNoiseGenerator] = []
        private var filterPool: [OptimizedBandpassFilter] = []
        
        private let poolQueue = DispatchQueue(label: "DSPObjectPool", qos: .userInitiated)
        private let sampleRate: Double
        
        public init(sampleRate: Double) {
            self.sampleRate = sampleRate
            preallocateObjects()
        }
        
        private func preallocateObjects() {
            // Pre-allocate common DSP objects
            for _ in 0..<16 {
                operatorPool.append(OptimizedFMOperator(sampleRate: sampleRate))
                noiseGeneratorPool.append(OptimizedNoiseGenerator())
                filterPool.append(OptimizedBandpassFilter(sampleRate: sampleRate))
            }
        }
        
        public func borrowOperator() -> OptimizedFMOperator {
            return poolQueue.sync {
                if let fmOperator = operatorPool.popLast() {
                    fmOperator.reset()
                    return fmOperator
                } else {
                    return OptimizedFMOperator(sampleRate: sampleRate)
                }
            }
        }
        
        public func returnOperator(_ fmOperator: OptimizedFMOperator) {
            poolQueue.sync {
                if operatorPool.count < 32 {
                    fmOperator.reset()
                    operatorPool.append(fmOperator)
                }
            }
        }
        
        public func borrowNoiseGenerator() -> OptimizedNoiseGenerator {
            return poolQueue.sync {
                return noiseGeneratorPool.popLast() ?? OptimizedNoiseGenerator()
            }
        }
        
        public func returnNoiseGenerator(_ generator: OptimizedNoiseGenerator) {
            poolQueue.sync {
                if noiseGeneratorPool.count < 16 {
                    noiseGeneratorPool.append(generator)
                }
            }
        }
        
        public func borrowFilter() -> OptimizedBandpassFilter {
            return poolQueue.sync {
                return filterPool.popLast() ?? OptimizedBandpassFilter(sampleRate: sampleRate)
            }
        }
        
        public func returnFilter(_ filter: OptimizedBandpassFilter) {
            poolQueue.sync {
                if filterPool.count < 16 {
                    filterPool.append(filter)
                }
            }
        }
    }
}
