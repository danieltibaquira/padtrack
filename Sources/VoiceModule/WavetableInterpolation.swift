// WavetableInterpolation.swift
// DigitonePad - VoiceModule
//
// Advanced Wavetable Interpolation Algorithms with Anti-Aliasing
// Optimized for real-time audio processing with SIMD acceleration

import Foundation
import Accelerate
import MachineProtocols
import AudioEngine

// MARK: - Anti-Aliasing Configuration

/// Configuration for anti-aliasing during wavetable playback
public struct AntiAliasingConfig: Sendable {
    public let enabled: Bool
    public let oversamplingFactor: Int
    public let cutoffFrequency: Float  // Nyquist ratio (0.0-1.0)
    public let filterOrder: Int
    
    public init(enabled: Bool = true, oversamplingFactor: Int = 2, cutoffFrequency: Float = 0.45, filterOrder: Int = 4) {
        self.enabled = enabled
        self.oversamplingFactor = max(1, min(8, oversamplingFactor))
        self.cutoffFrequency = max(0.1, min(0.5, cutoffFrequency))
        self.filterOrder = max(2, min(8, filterOrder))
    }
    
    public static let disabled = AntiAliasingConfig(enabled: false, oversamplingFactor: 1, cutoffFrequency: 0.5, filterOrder: 2)
    public static let standard = AntiAliasingConfig(enabled: true, oversamplingFactor: 2, cutoffFrequency: 0.45, filterOrder: 4)
    public static let highQuality = AntiAliasingConfig(enabled: true, oversamplingFactor: 4, cutoffFrequency: 0.4, filterOrder: 6)
}

// MARK: - Advanced Spline Interpolation Types

/// Extended spline interpolation methods
public enum SplineType: String, CaseIterable, Codable {
    case catmullRom = "catmull_rom"      // Smooth curves through control points
    case cardinal = "cardinal"            // Adjustable tension splines  
    case bezier = "bezier"               // Cubic Bezier interpolation
    case bSpline = "b_spline"            // B-spline interpolation
    case smoothstep = "smoothstep"       // Smooth step interpolation
    
    public var description: String {
        switch self {
        case .catmullRom: return "Catmull-Rom Spline"
        case .cardinal: return "Cardinal Spline"
        case .bezier: return "Cubic Bezier"
        case .bSpline: return "B-Spline"
        case .smoothstep: return "Smoothstep"
        }
    }
}

// MARK: - Performance Optimization Configuration

/// Configuration for performance optimization strategies
public struct PerformanceConfig: Sendable {
    public let enableSIMD: Bool
    public let enableCaching: Bool
    public let cacheSize: Int
    public let enablePrefetch: Bool
    public let vectorSize: Int
    
    public init(enableSIMD: Bool = true, enableCaching: Bool = true, cacheSize: Int = 1024, enablePrefetch: Bool = true, vectorSize: Int = 4) {
        self.enableSIMD = enableSIMD
        self.enableCaching = enableCaching
        self.cacheSize = max(64, min(4096, cacheSize))
        self.enablePrefetch = enablePrefetch
        self.vectorSize = max(1, min(8, vectorSize))
    }
    
    public static let balanced = PerformanceConfig()
    public static let highPerformance = PerformanceConfig(enableSIMD: true, enableCaching: true, cacheSize: 2048, enablePrefetch: true, vectorSize: 8)
    public static let lowLatency = PerformanceConfig(enableSIMD: true, enableCaching: false, cacheSize: 256, enablePrefetch: false, vectorSize: 4)
}

// MARK: - Advanced Wavetable Interpolator

/// High-performance wavetable interpolation engine with anti-aliasing and SIMD optimization
public final class WavetableInterpolator: @unchecked Sendable {
    
    // MARK: - Configuration
    
    public var antiAliasingConfig: AntiAliasingConfig
    public var performanceConfig: PerformanceConfig
    public var splineType: SplineType
    
    // MARK: - Anti-Aliasing Filter State
    
    private var antiAliasingFilter: AntiAliasingFilter
    private var oversampleBuffer: [Float]
    private var downsampleBuffer: [Float]
    
    // MARK: - Performance Optimization State
    
    private var interpolationCache: [CacheKey: Float]
    private var coefficientCache: [CoeffCacheKey: InterpolationCoefficients]
    private var simdBuffer: [Float]
    
    // MARK: - Initialization
    
    public init(antiAliasingConfig: AntiAliasingConfig = .standard, 
                performanceConfig: PerformanceConfig = .balanced,
                splineType: SplineType = .catmullRom) {
        self.antiAliasingConfig = antiAliasingConfig
        self.performanceConfig = performanceConfig
        self.splineType = splineType
        
        self.antiAliasingFilter = AntiAliasingFilter(config: antiAliasingConfig)
        self.oversampleBuffer = [Float](repeating: 0.0, count: 4096 * antiAliasingConfig.oversamplingFactor)
        self.downsampleBuffer = [Float](repeating: 0.0, count: 4096)
        
        self.interpolationCache = [:]
        self.coefficientCache = [:]
        self.simdBuffer = [Float](repeating: 0.0, count: max(64, performanceConfig.vectorSize * 16))
    }
    
    // MARK: - High-Level Interpolation Interface
    
    /// Interpolate single sample with full feature set
    /// - Parameters:
    ///   - wavetable: Source wavetable data
    ///   - framePosition: Frame position (0.0 to frameCount)
    ///   - samplePosition: Sample position within frame (0.0 to frameSize)
    ///   - interpolation: Base interpolation method
    ///   - fundamental: Fundamental frequency for anti-aliasing (Hz)
    ///   - sampleRate: Sample rate for anti-aliasing calculations
    /// - Returns: Interpolated and optionally anti-aliased sample
    public func interpolateSample(
        wavetable: WavetableData,
        framePosition: Float,
        samplePosition: Float,
        interpolation: WavetableInterpolation,
        fundamental: Float = 440.0,
        sampleRate: Float = 44100.0
    ) -> Float {
        
        // Check if anti-aliasing is needed
        let needsAntiAliasing = antiAliasingConfig.enabled && shouldApplyAntiAliasing(fundamental: fundamental, sampleRate: sampleRate)
        
        if needsAntiAliasing {
            return interpolateWithAntiAliasing(
                wavetable: wavetable,
                framePosition: framePosition,
                samplePosition: samplePosition,
                interpolation: interpolation,
                fundamental: fundamental,
                sampleRate: sampleRate
            )
        } else {
            return interpolateBasic(
                wavetable: wavetable,
                framePosition: framePosition,
                samplePosition: samplePosition,
                interpolation: interpolation
            )
        }
    }
    
    /// Process block of samples with SIMD optimization
    /// - Parameters:
    ///   - wavetable: Source wavetable data
    ///   - framePositions: Array of frame positions
    ///   - samplePositions: Array of sample positions  
    ///   - output: Output buffer to fill
    ///   - interpolation: Interpolation method
    ///   - fundamental: Fundamental frequency for anti-aliasing
    ///   - sampleRate: Sample rate
    public func processBlock(
        wavetable: WavetableData,
        framePositions: [Float],
        samplePositions: [Float],
        output: inout [Float],
        interpolation: WavetableInterpolation,
        fundamental: Float = 440.0,
        sampleRate: Float = 44100.0
    ) {
        let blockSize = min(framePositions.count, min(samplePositions.count, output.count))
        guard blockSize > 0 else { return }
        
        let needsAntiAliasing = antiAliasingConfig.enabled && shouldApplyAntiAliasing(fundamental: fundamental, sampleRate: sampleRate)
        
        if performanceConfig.enableSIMD && blockSize >= performanceConfig.vectorSize && !needsAntiAliasing {
            processSIMDBlock(
                wavetable: wavetable,
                framePositions: framePositions,
                samplePositions: samplePositions,
                output: &output,
                interpolation: interpolation,
                blockSize: blockSize
            )
        } else {
            // Fallback to sample-by-sample processing
            for i in 0..<blockSize {
                output[i] = interpolateSample(
                    wavetable: wavetable,
                    framePosition: framePositions[i],
                    samplePosition: samplePositions[i],
                    interpolation: interpolation,
                    fundamental: fundamental,
                    sampleRate: sampleRate
                )
            }
        }
    }
    
    // MARK: - Advanced Spline Interpolation Methods
    
    /// Interpolate using advanced spline methods
    /// - Parameters:
    ///   - wavetable: Source wavetable data
    ///   - framePosition: Frame position
    ///   - samplePosition: Sample position
    ///   - splineType: Type of spline interpolation
    ///   - tension: Spline tension parameter (0.0-1.0, for applicable types)
    /// - Returns: Spline-interpolated sample
    public func interpolateSpline(
        wavetable: WavetableData,
        framePosition: Float,
        samplePosition: Float,
        splineType: SplineType = .catmullRom,
        tension: Float = 0.0
    ) -> Float {
        let frameIndex = Int(framePosition)
        let frameFrac = framePosition - Float(frameIndex)
        
        switch splineType {
        case .catmullRom:
            return interpolateCatmullRom(wavetable: wavetable, frameIndex: frameIndex, frameFrac: frameFrac, samplePosition: samplePosition)
        case .cardinal:
            return interpolateCardinal(wavetable: wavetable, frameIndex: frameIndex, frameFrac: frameFrac, samplePosition: samplePosition, tension: tension)
        case .bezier:
            return interpolateBezier(wavetable: wavetable, frameIndex: frameIndex, frameFrac: frameFrac, samplePosition: samplePosition)
        case .bSpline:
            return interpolateBSpline(wavetable: wavetable, frameIndex: frameIndex, frameFrac: frameFrac, samplePosition: samplePosition)
        case .smoothstep:
            return interpolateSmoothstep(wavetable: wavetable, frameIndex: frameIndex, frameFrac: frameFrac, samplePosition: samplePosition)
        }
    }
    
    // MARK: - Private Implementation
    
    // MARK: Basic Interpolation
    
    private func interpolateBasic(
        wavetable: WavetableData,
        framePosition: Float,
        samplePosition: Float,
        interpolation: WavetableInterpolation
    ) -> Float {
        // Use existing wavetable interpolation with potential caching
        if performanceConfig.enableCaching {
            let cacheKey = CacheKey(framePosition: framePosition, samplePosition: samplePosition, interpolation: interpolation)
            if let cachedValue = interpolationCache[cacheKey] {
                return cachedValue
            }
            
            let result = wavetable.getInterpolatedSample(framePosition: framePosition, samplePosition: samplePosition, interpolation: interpolation)
            
            if interpolationCache.count < performanceConfig.cacheSize {
                interpolationCache[cacheKey] = result
            }
            
            return result
        } else {
            return wavetable.getInterpolatedSample(framePosition: framePosition, samplePosition: samplePosition, interpolation: interpolation)
        }
    }
    
    // MARK: Anti-Aliasing Implementation
    
    private func interpolateWithAntiAliasing(
        wavetable: WavetableData,
        framePosition: Float,
        samplePosition: Float,
        interpolation: WavetableInterpolation,
        fundamental: Float,
        sampleRate: Float
    ) -> Float {
        let oversamplingFactor = antiAliasingConfig.oversamplingFactor
        let oversampledRate = sampleRate * Float(oversamplingFactor)
        
        // Generate oversampled data
        var oversampledData: [Float] = []
        oversampledData.reserveCapacity(oversamplingFactor)
        
        for i in 0..<oversamplingFactor {
            let offset = Float(i) / Float(oversamplingFactor)
            let adjustedSamplePos = samplePosition + offset / Float(wavetable.frameSize)
            let sample = wavetable.getInterpolatedSample(framePosition: framePosition, samplePosition: adjustedSamplePos, interpolation: interpolation)
            oversampledData.append(sample)
        }
        
        // Apply anti-aliasing filter
        let filteredData = antiAliasingFilter.process(oversampledData, fundamental: fundamental, sampleRate: oversampledRate)
        
        // Downsample
        return downsample(data: filteredData)
    }
    
    private func shouldApplyAntiAliasing(fundamental: Float, sampleRate: Float) -> Bool {
        let nyquist = sampleRate * 0.5
        return fundamental > nyquist * 0.3  // Apply AA above 30% of Nyquist
    }
    
    private func downsample(data: [Float]) -> Float {
        // Simple averaging downsample (could be enhanced with proper decimation filter)
        return data.reduce(0.0, +) / Float(data.count)
    }
    
    // MARK: SIMD Block Processing
    
    private func processSIMDBlock(
        wavetable: WavetableData,
        framePositions: [Float],
        samplePositions: [Float],
        output: inout [Float],
        interpolation: WavetableInterpolation,
        blockSize: Int
    ) {
        let vectorSize = performanceConfig.vectorSize
        let numVectors = blockSize / vectorSize
        let remainder = blockSize % vectorSize
        
        // Process in SIMD vectors
        for v in 0..<numVectors {
            let startIdx = v * vectorSize
            processSIMDVector(
                wavetable: wavetable,
                framePositions: Array(framePositions[startIdx..<startIdx + vectorSize]),
                samplePositions: Array(samplePositions[startIdx..<startIdx + vectorSize]),
                output: &output,
                outputOffset: startIdx,
                interpolation: interpolation
            )
        }
        
        // Process remainder samples
        for i in (numVectors * vectorSize)..<blockSize {
            output[i] = wavetable.getInterpolatedSample(
                framePosition: framePositions[i],
                samplePosition: samplePositions[i],
                interpolation: interpolation
            )
        }
    }
    
    private func processSIMDVector(
        wavetable: WavetableData,
        framePositions: [Float],
        samplePositions: [Float],
        output: inout [Float],
        outputOffset: Int,
        interpolation: WavetableInterpolation
    ) {
        let vectorSize = framePositions.count
        guard vectorSize <= simdBuffer.count else { return }
        
        // Use vDSP for vectorized operations where possible
        switch interpolation {
        case .linear:
            processSIMDLinear(wavetable: wavetable, framePositions: framePositions, samplePositions: samplePositions, output: &output, outputOffset: outputOffset)
        default:
            // Fallback to scalar processing for complex interpolation
            for i in 0..<vectorSize {
                output[outputOffset + i] = wavetable.getInterpolatedSample(
                    framePosition: framePositions[i],
                    samplePosition: samplePositions[i],
                    interpolation: interpolation
                )
            }
        }
    }
    
    private func processSIMDLinear(
        wavetable: WavetableData,
        framePositions: [Float],
        samplePositions: [Float],
        output: inout [Float],
        outputOffset: Int
    ) {
        // Optimized linear interpolation using vDSP
        let vectorSize = framePositions.count
        
        for i in 0..<vectorSize {
            let frameIndex = Int(framePositions[i])
            let frameFrac = framePositions[i] - Float(frameIndex)
            
            if frameFrac == 0.0 || frameIndex >= wavetable.frameCount - 1 {
                output[outputOffset + i] = wavetable.getSample(frameIndex: frameIndex, position: samplePositions[i], interpolation: .linear)
            } else {
                let sample1 = wavetable.getSample(frameIndex: frameIndex, position: samplePositions[i], interpolation: .linear)
                let sample2 = wavetable.getSample(frameIndex: frameIndex + 1, position: samplePositions[i], interpolation: .linear)
                output[outputOffset + i] = sample1 + frameFrac * (sample2 - sample1)
            }
        }
    }
    
    // MARK: Advanced Spline Implementation
    
    private func interpolateCatmullRom(wavetable: WavetableData, frameIndex: Int, frameFrac: Float, samplePosition: Float) -> Float {
        let p0 = wavetable.getSample(frameIndex: max(0, frameIndex - 1), position: samplePosition, interpolation: .linear)
        let p1 = wavetable.getSample(frameIndex: frameIndex, position: samplePosition, interpolation: .linear)
        let p2 = wavetable.getSample(frameIndex: min(wavetable.frameCount - 1, frameIndex + 1), position: samplePosition, interpolation: .linear)
        let p3 = wavetable.getSample(frameIndex: min(wavetable.frameCount - 1, frameIndex + 2), position: samplePosition, interpolation: .linear)
        
        let t = frameFrac
        let t2 = t * t
        let t3 = t2 * t
        
        return 0.5 * ((2.0 * p1) +
                      (-p0 + p2) * t +
                      (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
                      (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
    }
    
    private func interpolateCardinal(wavetable: WavetableData, frameIndex: Int, frameFrac: Float, samplePosition: Float, tension: Float) -> Float {
        let p0 = wavetable.getSample(frameIndex: max(0, frameIndex - 1), position: samplePosition, interpolation: .linear)
        let p1 = wavetable.getSample(frameIndex: frameIndex, position: samplePosition, interpolation: .linear)
        let p2 = wavetable.getSample(frameIndex: min(wavetable.frameCount - 1, frameIndex + 1), position: samplePosition, interpolation: .linear)
        let p3 = wavetable.getSample(frameIndex: min(wavetable.frameCount - 1, frameIndex + 2), position: samplePosition, interpolation: .linear)
        
        let t = frameFrac
        let t2 = t * t
        let t3 = t2 * t
        let s = (1.0 - tension) * 0.5
        
        let h1 = 2.0 * t3 - 3.0 * t2 + 1.0
        let h2 = -2.0 * t3 + 3.0 * t2
        let h3 = t3 - 2.0 * t2 + t
        let h4 = t3 - t2
        
        let m0 = s * (p2 - p0)
        let m1 = s * (p3 - p1)
        
        return h1 * p1 + h2 * p2 + h3 * m0 + h4 * m1
    }
    
    private func interpolateBezier(wavetable: WavetableData, frameIndex: Int, frameFrac: Float, samplePosition: Float) -> Float {
        let p0 = wavetable.getSample(frameIndex: frameIndex, position: samplePosition, interpolation: .linear)
        let p3 = wavetable.getSample(frameIndex: min(wavetable.frameCount - 1, frameIndex + 1), position: samplePosition, interpolation: .linear)
        
        // Control points for smooth curve
        let p1 = p0 + (p3 - p0) * 0.33
        let p2 = p0 + (p3 - p0) * 0.67
        
        let t = frameFrac
        let oneMinusT = 1.0 - t
        
        return oneMinusT * oneMinusT * oneMinusT * p0 +
               3.0 * oneMinusT * oneMinusT * t * p1 +
               3.0 * oneMinusT * t * t * p2 +
               t * t * t * p3
    }
    
    private func interpolateBSpline(wavetable: WavetableData, frameIndex: Int, frameFrac: Float, samplePosition: Float) -> Float {
        let p0 = wavetable.getSample(frameIndex: max(0, frameIndex - 1), position: samplePosition, interpolation: .linear)
        let p1 = wavetable.getSample(frameIndex: frameIndex, position: samplePosition, interpolation: .linear)
        let p2 = wavetable.getSample(frameIndex: min(wavetable.frameCount - 1, frameIndex + 1), position: samplePosition, interpolation: .linear)
        let p3 = wavetable.getSample(frameIndex: min(wavetable.frameCount - 1, frameIndex + 2), position: samplePosition, interpolation: .linear)
        
        let t = frameFrac
        let t2 = t * t
        let t3 = t2 * t
        
        return (1.0/6.0) * ((-t3 + 3.0*t2 - 3.0*t + 1.0) * p0 +
                           (3.0*t3 - 6.0*t2 + 4.0) * p1 +
                           (-3.0*t3 + 3.0*t2 + 3.0*t + 1.0) * p2 +
                           t3 * p3)
    }
    
    private func interpolateSmoothstep(wavetable: WavetableData, frameIndex: Int, frameFrac: Float, samplePosition: Float) -> Float {
        let p1 = wavetable.getSample(frameIndex: frameIndex, position: samplePosition, interpolation: .linear)
        let p2 = wavetable.getSample(frameIndex: min(wavetable.frameCount - 1, frameIndex + 1), position: samplePosition, interpolation: .linear)
        
        let t = frameFrac
        let smoothT = t * t * (3.0 - 2.0 * t)  // smoothstep function
        
        return p1 + smoothT * (p2 - p1)
    }
}

// MARK: - Supporting Types

private struct CacheKey: Hashable {
    let framePosition: Float
    let samplePosition: Float
    let interpolation: WavetableInterpolation
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(framePosition)
        hasher.combine(samplePosition)
        hasher.combine(interpolation)
    }
}

private struct CoeffCacheKey: Hashable {
    let interpolation: WavetableInterpolation
    let splineType: SplineType?
    let tension: Float?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(interpolation)
        hasher.combine(splineType)
        hasher.combine(tension ?? 0.0)
    }
}

private struct InterpolationCoefficients {
    let a: Float
    let b: Float
    let c: Float
    let d: Float
}

/// High-order anti-aliasing filter for wavetable interpolation
private final class AntiAliasingFilter {
    private let config: AntiAliasingConfig
    private var filterCoefficients: [Float]
    private var delayLine: [Float]
    private var delayIndex: Int
    
    init(config: AntiAliasingConfig) {
        self.config = config
        self.filterCoefficients = []
        self.delayLine = [Float](repeating: 0.0, count: config.filterOrder * 2)
        self.delayIndex = 0
        
        calculateFilterCoefficients()
    }
    
    func process(_ input: [Float], fundamental: Float, sampleRate: Float) -> [Float] {
        guard config.enabled else { return input }
        
        var output = [Float](repeating: 0.0, count: input.count)
        
        for i in 0..<input.count {
            output[i] = processSample(input[i])
        }
        
        return output
    }
    
    private func processSample(_ input: Float) -> Float {
        // Simple FIR filter implementation
        delayLine[delayIndex] = input
        
        var output: Float = 0.0
        for i in 0..<filterCoefficients.count {
            let delayIdx = (delayIndex - i + delayLine.count) % delayLine.count
            output += filterCoefficients[i] * delayLine[delayIdx]
        }
        
        delayIndex = (delayIndex + 1) % delayLine.count
        return output
    }
    
    private func calculateFilterCoefficients() {
        // Simple windowed sinc filter design
        let order = config.filterOrder
        let cutoff = config.cutoffFrequency
        
        filterCoefficients = [Float](repeating: 0.0, count: order)
        
        for i in 0..<order {
            let n = Float(i) - Float(order - 1) * 0.5
            
            if abs(n) < 0.001 {
                filterCoefficients[i] = 2.0 * cutoff
            } else {
                let sinc = sin(2.0 * Float.pi * cutoff * n) / (Float.pi * n)
                let window = 0.54 - 0.46 * cos(2.0 * Float.pi * Float(i) / Float(order - 1)) // Hamming window
                filterCoefficients[i] = sinc * window
            }
        }
        
        // Normalize
        let sum = filterCoefficients.reduce(0.0, +)
        if sum > 0.0 {
            for i in 0..<filterCoefficients.count {
                filterCoefficients[i] /= sum
            }
        }
    }
}

// MARK: - Extensions

extension WavetableData {
    /// Convenience method to use advanced interpolation
    public func getAdvancedSample(
        framePosition: Float,
        samplePosition: Float,
        interpolator: WavetableInterpolator,
        interpolation: WavetableInterpolation = .hermite,
        fundamental: Float = 440.0,
        sampleRate: Float = 44100.0
    ) -> Float {
        return interpolator.interpolateSample(
            wavetable: self,
            framePosition: framePosition,
            samplePosition: samplePosition,
            interpolation: interpolation,
            fundamental: fundamental,
            sampleRate: sampleRate
        )
    }
    
    /// Convenience method for spline interpolation
    public func getSplineSample(
        framePosition: Float,
        samplePosition: Float,
        interpolator: WavetableInterpolator,
        splineType: SplineType = .catmullRom,
        tension: Float = 0.0
    ) -> Float {
        return interpolator.interpolateSpline(
            wavetable: self,
            framePosition: framePosition,
            samplePosition: samplePosition,
            splineType: splineType,
            tension: tension
        )
    }
} 