import Foundation
import Accelerate
import simd
import MachineProtocols

/// Performance-optimized effect processing utilities
public struct OptimizedEffectProcessing {
    
    // MARK: - SIMD-Optimized Bit Reduction
    
    /// Optimized bit reduction using SIMD operations
    public static func optimizedBitReduction(
        samples: inout [Float],
        bitDepth: Float,
        ditherAmount: Float = 0.0
    ) {
        let sampleCount = samples.count
        guard sampleCount > 0 else { return }
        
        // Calculate quantization parameters
        let levels = pow(2.0, bitDepth)
        let quantizationStep = 2.0 / levels
        let invQuantizationStep = 1.0 / quantizationStep
        
        // Process in chunks of 4 for SIMD optimization
        let simdCount = sampleCount & ~3 // Round down to multiple of 4
        
        samples.withUnsafeMutableBufferPointer { buffer in
            let ptr = buffer.baseAddress!
            
            // SIMD processing for main chunk
            for i in stride(from: 0, to: simdCount, by: 4) {
                // Load 4 samples
                var samples4 = simd_float4(ptr[i], ptr[i+1], ptr[i+2], ptr[i+3])
                
                // Apply dithering if needed
                if ditherAmount > 0.0 {
                    let dither = simd_float4(
                        Float.random(in: -1...1),
                        Float.random(in: -1...1),
                        Float.random(in: -1...1),
                        Float.random(in: -1...1)
                    ) * ditherAmount * quantizationStep * 0.5
                    samples4 += dither
                }
                
                // Quantize
                samples4 = round(samples4 * invQuantizationStep) * quantizationStep
                
                // Clamp to valid range
                samples4 = simd_clamp(samples4, simd_float4(repeating: -1.0), simd_float4(repeating: 1.0))
                
                // Store back
                ptr[i] = samples4.x
                ptr[i+1] = samples4.y
                ptr[i+2] = samples4.z
                ptr[i+3] = samples4.w
            }
            
            // Process remaining samples
            for i in simdCount..<sampleCount {
                var sample = ptr[i]
                
                // Apply dithering
                if ditherAmount > 0.0 {
                    let dither = Float.random(in: -1...1) * ditherAmount * quantizationStep * 0.5
                    sample += dither
                }
                
                // Quantize and clamp
                sample = max(-1.0, min(1.0, round(sample * invQuantizationStep) * quantizationStep))
                ptr[i] = sample
            }
        }
    }
    
    // MARK: - Vectorized Overdrive Processing
    
    /// Optimized overdrive processing using Accelerate framework
    public static func optimizedOverdrive(
        samples: inout [Float],
        driveAmount: Float,
        clippingType: OverdriveClippingType = .soft
    ) {
        let sampleCount = vDSP_Length(samples.count)
        guard sampleCount > 0 else { return }
        
        // Apply drive gain using vDSP
        var drive = driveAmount
        vDSP_vsmul(samples, 1, &drive, &samples, 1, sampleCount)
        
        // Apply clipping based on type
        switch clippingType {
        case .soft:
            // Use vvtanhf for vectorized tanh
            var count = Int32(samples.count)
            vvtanhf(&samples, samples, &count)
            
        case .hard:
            // Hard clipping using vDSP
            var lowerBound: Float = -1.0
            var upperBound: Float = 1.0
            vDSP_vclip(samples, 1, &lowerBound, &upperBound, &samples, 1, sampleCount)
            
        case .tube:
            // Custom tube-style clipping
            let sampleCount = samples.count
            samples.withUnsafeMutableBufferPointer { buffer in
                let ptr = buffer.baseAddress!
                let simdCount = sampleCount & ~3
                
                for i in stride(from: 0, to: simdCount, by: 4) {
                    var samples4 = simd_float4(ptr[i], ptr[i+1], ptr[i+2], ptr[i+3])
                    
                    // Asymmetric clipping
                    let positive = simd_max(samples4, simd_float4(repeating: 0.0))
                    let negative = simd_min(samples4, simd_float4(repeating: 0.0))
                    
                    samples4 = tanh(positive * 0.7) + tanh(negative * 1.2)
                    
                    ptr[i] = samples4.x
                    ptr[i+1] = samples4.y
                    ptr[i+2] = samples4.z
                    ptr[i+3] = samples4.w
                }
                
                // Process remaining samples
                for i in simdCount..<sampleCount {
                    let sample = ptr[i]
                    if sample >= 0.0 {
                        ptr[i] = tanh(sample * 0.7)
                    } else {
                        ptr[i] = tanh(sample * 1.2)
                    }
                }
            }
        }
    }
    
    // MARK: - Optimized Sample Rate Reduction
    
    /// Optimized sample rate reduction with anti-aliasing
    public static func optimizedSampleRateReduction(
        samples: inout [Float],
        targetSampleRate: Float,
        inputSampleRate: Float = 44100.0,
        antiAliasing: Bool = true,
        filterState: inout Float
    ) {
        guard targetSampleRate < inputSampleRate else { return }
        
        let downsamplingRatio = inputSampleRate / targetSampleRate
        
        // Apply anti-aliasing filter if enabled
        if antiAliasing {
            let cutoffFreq = targetSampleRate * 0.45
            let normalizedCutoff = cutoffFreq / inputSampleRate
            let filterCoeff = exp(-2.0 * Float.pi * normalizedCutoff)
            
            // Vectorized one-pole low-pass filter
            applyOptimizedLowPassFilter(samples: &samples, coefficient: filterCoeff, state: &filterState)
        }
        
        // Apply sample rate reduction with optimized hold logic
        var accumulator: Float = 0.0
        var lastSample: Float = 0.0
        
        for i in 0..<samples.count {
            accumulator += 1.0
            
            if accumulator >= downsamplingRatio {
                accumulator -= downsamplingRatio
                lastSample = samples[i]
            }
            
            samples[i] = lastSample
        }
    }
    
    // MARK: - Optimized Filter Processing
    
    /// Optimized one-pole low-pass filter using SIMD
    private static func applyOptimizedLowPassFilter(
        samples: inout [Float],
        coefficient: Float,
        state: inout Float
    ) {
        let oneMinusCoeff = 1.0 - coefficient
        
        // Process samples with optimized loop
        for i in 0..<samples.count {
            state = state * coefficient + samples[i] * oneMinusCoeff
            samples[i] = state
        }
    }
    
    // MARK: - Batch Processing Utilities
    
    /// Process multiple buffers in batch for better cache efficiency
    public static func batchProcessEffects(
        buffers: inout [MachineProtocols.AudioBuffer],
        processor: (inout MachineProtocols.AudioBuffer) -> Void
    ) {
        // Process buffers in batches to improve cache locality
        let batchSize = 4
        
        for batchStart in stride(from: 0, to: buffers.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, buffers.count)
            
            for i in batchStart..<batchEnd {
                processor(&buffers[i])
            }
        }
    }
    
    // MARK: - Memory Pool for Audio Buffers
    
    /// Memory pool for reusing audio buffers to reduce allocations
    public class AudioBufferPool: @unchecked Sendable {
        private var availableBuffers: [MachineProtocols.AudioBuffer] = []
        private let maxPoolSize: Int = 16
        private let queue = DispatchQueue(label: "AudioBufferPool", qos: .userInteractive)
        
        public init() {}
        
        /// Get a buffer from the pool or create a new one
        public func getBuffer(frameCount: Int, channelCount: Int, sampleRate: Double) -> MachineProtocols.AudioBuffer {
            return queue.sync {
                if let buffer = availableBuffers.popLast() {
                    // Reuse existing buffer if it matches requirements
                    if buffer.frameCount >= frameCount && buffer.channelCount == channelCount {
                        return buffer
                    }
                }
                
                // Create new buffer
                return createAudioBuffer(frameCount: frameCount, channelCount: channelCount, sampleRate: sampleRate)
            }
        }
        
        /// Return a buffer to the pool
        public func returnBuffer(_ buffer: MachineProtocols.AudioBuffer) {
            queue.async { [weak self] in
                guard let self = self else { return }
                
                if self.availableBuffers.count < self.maxPoolSize {
                    // Clear the buffer data
                    var mutableBuffer = buffer
                    for i in 0..<mutableBuffer.samples.count {
                        mutableBuffer.samples[i] = 0.0
                    }

                    self.availableBuffers.append(mutableBuffer)
                }
            }
        }
        
        private func createAudioBuffer(frameCount: Int, channelCount: Int, sampleRate: Double) -> MachineProtocols.AudioBuffer {
            // Create a basic AudioBuffer implementation
            return BasicAudioBuffer(
                samples: Array(repeating: 0.0, count: frameCount * channelCount),
                frameCount: frameCount,
                channelCount: channelCount,
                sampleRate: sampleRate
            )
        }
    }
    
    // MARK: - Performance Monitoring
    
    /// Performance metrics for effect processing
    public struct EffectPerformanceMetrics {
        public var processingTime: TimeInterval = 0.0
        public var samplesProcessed: Int = 0
        public var bufferUnderruns: Int = 0
        public var cpuUsage: Float = 0.0
        
        public mutating func reset() {
            processingTime = 0.0
            samplesProcessed = 0
            bufferUnderruns = 0
            cpuUsage = 0.0
        }
        
        public var averageProcessingTimePerSample: TimeInterval {
            guard samplesProcessed > 0 else { return 0.0 }
            return processingTime / Double(samplesProcessed)
        }
    }
    
    /// Performance monitor for tracking effect processing efficiency
    public class EffectPerformanceMonitor {
        public private(set) var metrics = EffectPerformanceMetrics()
        private var startTime: CFAbsoluteTime = 0.0
        
        public init() {}
        
        /// Start timing a processing operation
        public func startTiming() {
            startTime = CFAbsoluteTimeGetCurrent()
        }
        
        /// End timing and update metrics
        public func endTiming(samplesProcessed: Int) {
            let endTime = CFAbsoluteTimeGetCurrent()
            let processingTime = endTime - startTime
            
            metrics.processingTime += processingTime
            metrics.samplesProcessed += samplesProcessed
        }
        
        /// Reset all metrics
        public func reset() {
            metrics.reset()
        }
        
        /// Get current metrics
        public func getMetrics() -> EffectPerformanceMetrics {
            return metrics
        }
    }
}

// MARK: - Supporting Types

public enum OverdriveClippingType {
    case soft
    case hard
    case tube
}

// Basic AudioBuffer implementation for the pool
private struct BasicAudioBuffer: MachineProtocols.AudioBufferProtocol, @unchecked Sendable {
    var samples: [Float]
    let frameCount: Int
    let channelCount: Int
    let sampleRate: Double
    private let _data: UnsafeMutablePointer<Float>

    var data: UnsafeMutablePointer<Float> { _data }

    init(samples: [Float], frameCount: Int, channelCount: Int, sampleRate: Double) {
        self.samples = samples
        self.frameCount = frameCount
        self.channelCount = channelCount
        self.sampleRate = sampleRate
        self._data = UnsafeMutablePointer<Float>.allocate(capacity: samples.count)
        self._data.initialize(from: samples, count: samples.count)
    }
}


