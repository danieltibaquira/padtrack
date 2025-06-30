// WavetableData.swift
// DigitonePad - VoiceModule
//
// Comprehensive Wavetable Data Structures for WAVETONE Voice Machine
// Provides efficient storage, access, and management of wavetable data

import Foundation
import Accelerate
import MachineProtocols
import AudioEngine

// MARK: - Wavetable Interpolation Methods

/// Supported interpolation methods for wavetable lookup
public enum WavetableInterpolation: String, CaseIterable, Codable {
    case none = "none"              // Nearest neighbor (fastest)
    case linear = "linear"          // Linear interpolation (good quality/performance balance)
    case cubic = "cubic"            // Cubic interpolation (higher quality)
    case hermite = "hermite"        // Hermite interpolation (smoothest)
    case lanczos = "lanczos"        // Lanczos interpolation (best quality, slowest)
    
    public var description: String {
        switch self {
        case .none: return "None (Nearest Neighbor)"
        case .linear: return "Linear"
        case .cubic: return "Cubic"
        case .hermite: return "Hermite"
        case .lanczos: return "Lanczos"
        }
    }
}

// MARK: - Wavetable Errors

public struct WavetableError: MachineError {
    public let code: String
    public let message: String
    public let severity: ErrorSeverity
    public let timestamp: Date
    
    public init(code: String, message: String, severity: ErrorSeverity = .error) {
        self.code = code
        self.message = message
        self.severity = severity
        self.timestamp = Date()
    }
    
    // Common wavetable errors
    public static func invalidFrameSize(_ size: Int) -> WavetableError {
        WavetableError(code: "WAVETABLE_INVALID_FRAME_SIZE", 
                      message: "Frame size \(size) must be a power of 2 between 64 and 4096")
    }
    
    public static func invalidFrameCount(_ count: Int) -> WavetableError {
        WavetableError(code: "WAVETABLE_INVALID_FRAME_COUNT",
                      message: "Frame count \(count) must be between 1 and 256")
    }
    
    public static func invalidWavetableData() -> WavetableError {
        WavetableError(code: "WAVETABLE_INVALID_DATA",
                      message: "Wavetable data is corrupted or invalid")
    }
}

// MARK: - Wavetable Metadata

/// Comprehensive metadata for wavetable categorization and management
public struct WavetableMetadata: Codable, Hashable {
    public let id: UUID
    public let name: String
    public let category: WavetableCategory
    public let subcategory: String?
    public let description: String?
    public let frameSize: Int
    public let frameCount: Int
    public let sampleRate: Double
    public let creator: String?
    public let version: String
    public let createdDate: Date
    public let tags: [String]
    public let fundamentalFrequency: Double
    public let harmonicContent: [Double]  // FFT analysis of harmonic content
    public let isDynamic: Bool            // Whether frames represent a progression
    
    public init(id: UUID = UUID(),
                name: String,
                category: WavetableCategory,
                subcategory: String? = nil,
                description: String? = nil,
                frameSize: Int,
                frameCount: Int,
                sampleRate: Double = 44100.0,
                creator: String? = nil,
                version: String = "1.0",
                tags: [String] = [],
                fundamentalFrequency: Double = 440.0,
                harmonicContent: [Double] = [],
                isDynamic: Bool = true) {
        self.id = id
        self.name = name
        self.category = category
        self.subcategory = subcategory
        self.description = description
        self.frameSize = frameSize
        self.frameCount = frameCount
        self.sampleRate = sampleRate
        self.creator = creator
        self.version = version
        self.createdDate = Date()
        self.tags = tags
        self.fundamentalFrequency = fundamentalFrequency
        self.harmonicContent = harmonicContent
        self.isDynamic = isDynamic
    }
}

/// Wavetable categories for organization
public enum WavetableCategory: String, CaseIterable, Codable {
    case analog = "analog"          // Classic analog waveforms
    case digital = "digital"        // Digital synthesis waveforms
    case formant = "formant"        // Formant synthesis
    case vocal = "vocal"            // Vocal formants and sounds
    case strings = "strings"        // String instrument samples
    case brass = "brass"            // Brass instrument samples
    case woodwind = "woodwind"      // Woodwind instrument samples
    case percussion = "percussion"  // Percussion samples
    case ambient = "ambient"        // Atmospheric textures
    case noise = "noise"            // Noise-based waveforms
    case custom = "custom"          // User-created waveforms
    case experimental = "experimental" // Experimental sounds
}

// MARK: - Core Wavetable Data Structure

/// High-performance wavetable data structure optimized for real-time audio processing
public final class WavetableData: @unchecked Sendable {
    
    // MARK: - Constants
    
    public static let minFrameSize: Int = 64
    public static let maxFrameSize: Int = 4096
    public static let minFrameCount: Int = 1
    public static let maxFrameCount: Int = 256
    
    // MARK: - Core Properties
    
    public let metadata: WavetableMetadata
    public let frameSize: Int
    public let frameCount: Int
    public let frameMask: Int           // For efficient modulo operations
    
    // MARK: - Optimized Data Storage
    
    /// Flattened wavetable data for efficient SIMD processing
    /// Layout: [frame0_sample0, frame0_sample1, ..., frame0_sampleN, frame1_sample0, ...]
    private let wavetableData: [Float]
    
    /// Pre-computed frame lookup table for frequency-based selection
    private let frameLookupTable: [Int]
    
    /// Cached interpolation coefficients for common interpolation ratios
    private var interpolationCache: [Float: (Float, Float, Float, Float)] = [:]
    
    // MARK: - Performance Optimization
    
    /// Pre-allocated buffers for SIMD operations
    private var tempBuffer1: [Float]
    private var tempBuffer2: [Float]
    private var tempBuffer3: [Float]
    private var tempBuffer4: [Float]
    
    // MARK: - Initialization
    
    /// Initialize wavetable from raw data
    /// - Parameters:
    ///   - metadata: Wavetable metadata
    ///   - data: Raw wavetable data organized as [frame][sample]
    public init(metadata: WavetableMetadata, data: [[Float]]) throws {
        // Validate frame size (must be power of 2)
        guard metadata.frameSize.isPowerOfTwo,
              metadata.frameSize >= Self.minFrameSize,
              metadata.frameSize <= Self.maxFrameSize else {
            throw WavetableError.invalidFrameSize(metadata.frameSize)
        }
        
        // Validate frame count
        guard metadata.frameCount >= Self.minFrameCount,
              metadata.frameCount <= Self.maxFrameCount else {
            throw WavetableError.invalidFrameCount(metadata.frameCount)
        }
        
        // Validate data consistency
        guard data.count == metadata.frameCount else {
            throw WavetableError.invalidWavetableData()
        }
        
        for frame in data {
            guard frame.count == metadata.frameSize else {
                throw WavetableError.invalidWavetableData()
            }
        }
        
        self.metadata = metadata
        self.frameSize = metadata.frameSize
        self.frameCount = metadata.frameCount
        self.frameMask = frameSize - 1
        
        // Flatten data for efficient access
        var flattenedData: [Float] = []
        flattenedData.reserveCapacity(frameCount * frameSize)
        for frame in data {
            flattenedData.append(contentsOf: frame)
        }
        self.wavetableData = flattenedData
        
        // Pre-compute frame lookup table for frequency-based selection
        // Maps normalized frequency (0.0-1.0) to frame index
        var lookup: [Int] = []
        lookup.reserveCapacity(1024)
        for i in 0..<1024 {
            let normalizedFreq = Float(i) / 1024.0
            let frameIndex = Int(normalizedFreq * Float(frameCount - 1))
            lookup.append(min(frameIndex, frameCount - 1))
        }
        self.frameLookupTable = lookup
        
        // Initialize SIMD buffers
        let bufferSize = max(frameSize, 1024)
        self.tempBuffer1 = [Float](repeating: 0.0, count: bufferSize)
        self.tempBuffer2 = [Float](repeating: 0.0, count: bufferSize)
        self.tempBuffer3 = [Float](repeating: 0.0, count: bufferSize)
        self.tempBuffer4 = [Float](repeating: 0.0, count: bufferSize)
    }
    
    // MARK: - Sample Access Methods
    
    /// Get sample at specific frame and position with interpolation
    /// - Parameters:
    ///   - frameIndex: Frame index (0 to frameCount-1)
    ///   - position: Position within frame (0.0 to frameSize as Float)
    ///   - interpolation: Interpolation method
    /// - Returns: Interpolated sample value
    public func getSample(frameIndex: Int, position: Float, interpolation: WavetableInterpolation = .linear) -> Float {
        let clampedFrame = max(0, min(frameCount - 1, frameIndex))
        let frameOffset = clampedFrame * frameSize
        
        switch interpolation {
        case .none:
            let sampleIndex = Int(position) & frameMask
            return wavetableData[frameOffset + sampleIndex]
            
        case .linear:
            let intPos = Int(position)
            let fracPos = position - Float(intPos)
            let idx1 = intPos & frameMask
            let idx2 = (intPos + 1) & frameMask
            
            let sample1 = wavetableData[frameOffset + idx1]
            let sample2 = wavetableData[frameOffset + idx2]
            return sample1 + fracPos * (sample2 - sample1)
            
        case .cubic:
            return getCubicSample(frameOffset: frameOffset, position: position)
            
        case .hermite:
            return getHermiteSample(frameOffset: frameOffset, position: position)
            
        case .lanczos:
            return getLanczosSample(frameOffset: frameOffset, position: position)
        }
    }
    
    /// Get interpolated sample between two frames
    /// - Parameters:
    ///   - framePosition: Frame position (0.0 to frameCount as Float)
    ///   - samplePosition: Sample position within frame (0.0 to frameSize as Float)
    ///   - interpolation: Interpolation method
    /// - Returns: Interpolated sample value
    public func getInterpolatedSample(framePosition: Float, samplePosition: Float, interpolation: WavetableInterpolation = .linear) -> Float {
        let frameIndex = Int(framePosition)
        let frameFrac = framePosition - Float(frameIndex)
        
        if frameFrac == 0.0 || frameIndex >= frameCount - 1 {
            return getSample(frameIndex: frameIndex, position: samplePosition, interpolation: interpolation)
        }
        
        let sample1 = getSample(frameIndex: frameIndex, position: samplePosition, interpolation: interpolation)
        let sample2 = getSample(frameIndex: frameIndex + 1, position: samplePosition, interpolation: interpolation)
        
        return sample1 + frameFrac * (sample2 - sample1)
    }
    
    // MARK: - Block Processing with SIMD
    
    /// Process a block of samples with SIMD optimization
    /// - Parameters:
    ///   - framePosition: Current frame position
    ///   - samplePositions: Array of sample positions within frame
    ///   - output: Output buffer (will be filled)
    ///   - interpolation: Interpolation method
    public func processBlock(framePosition: Float, samplePositions: [Float], output: inout [Float], interpolation: WavetableInterpolation = .linear) {
        let blockSize = min(samplePositions.count, output.count)
        let frameIndex = Int(framePosition)
        let frameFrac = framePosition - Float(frameIndex)
        let frameOffset = frameIndex * frameSize
        
        guard frameIndex < frameCount else { return }
        
        switch interpolation {
        case .linear:
            processLinearBlock(frameOffset: frameOffset, frameFrac: frameFrac, samplePositions: samplePositions, output: &output, blockSize: blockSize)
        default:
            // Fallback to sample-by-sample for complex interpolation
            for i in 0..<blockSize {
                output[i] = getInterpolatedSample(framePosition: framePosition, samplePosition: samplePositions[i], interpolation: interpolation)
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Get frame index based on normalized frequency (0.0 to 1.0)
    public func frameIndexForFrequency(_ normalizedFrequency: Float) -> Int {
        let lookupIndex = Int(normalizedFrequency * 1023.0)
        return frameLookupTable[max(0, min(1023, lookupIndex))]
    }
    
    /// Analyze harmonic content of a specific frame
    public func analyzeFrame(_ frameIndex: Int) -> [Double] {
        guard frameIndex >= 0 && frameIndex < frameCount else { return [] }
        
        let frameOffset = frameIndex * frameSize
        let frameData = Array(wavetableData[frameOffset..<frameOffset + frameSize])
        
        // Perform FFT analysis using Accelerate framework
        var realParts = frameData.map { Double($0) }
        var imaginaryParts = [Double](repeating: 0.0, count: frameSize)
        
        var splitComplex = DSPDoubleSplitComplex(realp: &realParts, imagp: &imaginaryParts)
        let log2Size = vDSP_Length(log2(Double(frameSize)))
        let fftSetup = vDSP_create_fftsetupD(log2Size, FFTRadix(kFFTRadix2))!
        
        vDSP_fft_zipD(fftSetup, &splitComplex, 1, log2Size, FFTDirection(FFT_FORWARD))
        
        // Calculate magnitude spectrum
        var magnitudes = [Double](repeating: 0.0, count: frameSize / 2)
        for i in 0..<frameSize / 2 {
            magnitudes[i] = sqrt(realParts[i] * realParts[i] + imaginaryParts[i] * imaginaryParts[i])
        }
        
        vDSP_destroy_fftsetupD(fftSetup)
        return magnitudes
    }
    
    // MARK: - Private Interpolation Methods
    
    private func getCubicSample(frameOffset: Int, position: Float) -> Float {
        let intPos = Int(position)
        let fracPos = position - Float(intPos)
        
        let idx0 = (intPos - 1) & frameMask
        let idx1 = intPos & frameMask
        let idx2 = (intPos + 1) & frameMask
        let idx3 = (intPos + 2) & frameMask
        
        let y0 = wavetableData[frameOffset + idx0]
        let y1 = wavetableData[frameOffset + idx1]
        let y2 = wavetableData[frameOffset + idx2]
        let y3 = wavetableData[frameOffset + idx3]
        
        let a = y3 - y2 - y0 + y1
        let b = y0 - y1 - a
        let c = y2 - y0
        let d = y1
        
        return ((a * fracPos + b) * fracPos + c) * fracPos + d
    }
    
    private func getHermiteSample(frameOffset: Int, position: Float) -> Float {
        let intPos = Int(position)
        let fracPos = position - Float(intPos)
        
        let idx0 = (intPos - 1) & frameMask
        let idx1 = intPos & frameMask
        let idx2 = (intPos + 1) & frameMask
        let idx3 = (intPos + 2) & frameMask
        
        let y0 = wavetableData[frameOffset + idx0]
        let y1 = wavetableData[frameOffset + idx1]
        let y2 = wavetableData[frameOffset + idx2]
        let y3 = wavetableData[frameOffset + idx3]
        
        let c0 = y1
        let c1 = 0.5 * (y2 - y0)
        let c2 = y0 - 2.5 * y1 + 2.0 * y2 - 0.5 * y3
        let c3 = 0.5 * (y3 - y0) + 1.5 * (y1 - y2)
        
        return ((c3 * fracPos + c2) * fracPos + c1) * fracPos + c0
    }
    
    private func getLanczosSample(frameOffset: Int, position: Float) -> Float {
        let intPos = Int(position)
        let fracPos = position - Float(intPos)
        
        var result: Float = 0.0
        let radius = 2
        
        for i in -radius...radius {
            let idx = (intPos + i) & frameMask
            let x = fracPos - Float(i)
            let weight = lanczosSinc(x: x, radius: Float(radius))
            result += wavetableData[frameOffset + idx] * weight
        }
        
        return result
    }
    
    private func lanczosSinc(x: Float, radius: Float) -> Float {
        if abs(x) < 0.00001 { return 1.0 }
        if abs(x) >= radius { return 0.0 }
        
        let piX = Float.pi * x
        let piXOverRadius = piX / radius
        
        return (sin(piX) / piX) * (sin(piXOverRadius) / piXOverRadius)
    }
    
    private func processLinearBlock(frameOffset: Int, frameFrac: Float, samplePositions: [Float], output: inout [Float], blockSize: Int) {
        // SIMD-optimized linear interpolation for block processing
        for i in 0..<blockSize {
            let position = samplePositions[i]
            let intPos = Int(position)
            let fracPos = position - Float(intPos)
            let idx1 = intPos & frameMask
            let idx2 = (intPos + 1) & frameMask
            
            let sample1 = wavetableData[frameOffset + idx1]
            let sample2 = wavetableData[frameOffset + idx2]
            output[i] = sample1 + fracPos * (sample2 - sample1)
        }
    }
}

// MARK: - Wavetable Manager

/// Thread-safe manager for collections of wavetables
public final class WavetableManager: @unchecked Sendable {
    
    private let queue = DispatchQueue(label: "wavetable.manager", qos: .userInitiated, attributes: .concurrent)
    private var wavetables: [UUID: WavetableData] = [:]
    private var categorizedWavetables: [WavetableCategory: [UUID]] = [:]
    
    public init() {
        // Initialize with built-in wavetables
        loadBuiltInWavetables()
    }
    
    // MARK: - Wavetable Management
    
    /// Add a wavetable to the manager
    public func addWavetable(_ wavetable: WavetableData) {
        queue.async(flags: .barrier) { [weak self] in
            self?.wavetables[wavetable.metadata.id] = wavetable
            self?.updateCategoryIndex(for: wavetable.metadata)
        }
    }
    
    /// Get wavetable by ID
    public func getWavetable(id: UUID) -> WavetableData? {
        return queue.sync {
            return wavetables[id]
        }
    }

    /// Get wavetable by name
    public func getWavetable(named name: String) -> WavetableData? {
        return queue.sync {
            return wavetables.values.first { $0.metadata.name == name }
        }
    }
    
    /// Get all wavetables in a category
    public func getWavetables(in category: WavetableCategory) -> [WavetableData] {
        return queue.sync {
            let ids = categorizedWavetables[category] ?? []
            return ids.compactMap { wavetables[$0] }
        }
    }
    
    /// Remove wavetable by ID
    public func removeWavetable(id: UUID) {
        queue.async(flags: .barrier) { [weak self] in
            if let wavetable = self?.wavetables.removeValue(forKey: id) {
                self?.removeCategoryIndex(for: wavetable.metadata)
            }
        }
    }
    
    /// Get all available wavetables
    public func getAllWavetables() -> [WavetableData] {
        return queue.sync {
            return Array(wavetables.values)
        }
    }
    
    // MARK: - Search and Filter
    
    /// Search wavetables by name or tags
    public func searchWavetables(query: String) -> [WavetableData] {
        return queue.sync {
            let lowercaseQuery = query.lowercased()
            return wavetables.values.filter { wavetable in
                wavetable.metadata.name.lowercased().contains(lowercaseQuery) ||
                wavetable.metadata.tags.contains { $0.lowercased().contains(lowercaseQuery) }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateCategoryIndex(for metadata: WavetableMetadata) {
        if categorizedWavetables[metadata.category] == nil {
            categorizedWavetables[metadata.category] = []
        }
        categorizedWavetables[metadata.category]?.append(metadata.id)
    }
    
    private func removeCategoryIndex(for metadata: WavetableMetadata) {
        categorizedWavetables[metadata.category]?.removeAll { $0 == metadata.id }
    }
    
    private func loadBuiltInWavetables() {
        // Create built-in wavetables
        createSineProgression()
        createSawtoothProgression()
        createSquareProgression()
    }
    
    // MARK: - Built-in Wavetable Creation
    
    private func createSineProgression() {
        let frameSize = 1024
        let frameCount = 64
        var frames: [[Float]] = []
        
        for frameIndex in 0..<frameCount {
            var frame = [Float](repeating: 0.0, count: frameSize)
            let harmonicCount = 1 + frameIndex / 8  // Add harmonics gradually
            
            for i in 0..<frameSize {
                let phase = Float(i) * 2.0 * Float.pi / Float(frameSize)
                var sample: Float = 0.0
                
                for harmonic in 1...harmonicCount {
                    let amplitude = 1.0 / Float(harmonic)  // Sawtooth-like harmonic rolloff
                    sample += amplitude * sin(phase * Float(harmonic))
                }
                
                frame[i] = sample / Float(harmonicCount)  // Normalize
            }
            frames.append(frame)
        }
        
        let metadata = WavetableMetadata(
            name: "Sine Progression",
            category: .analog,
            description: "Progressive sine wave with increasing harmonic content",
            frameSize: frameSize,
            frameCount: frameCount,
            tags: ["sine", "progression", "harmonic"],
            isDynamic: true
        )
        
        if let wavetable = try? WavetableData(metadata: metadata, data: frames) {
            wavetables[metadata.id] = wavetable
            updateCategoryIndex(for: metadata)
        }
    }
    
    private func createSawtoothProgression() {
        let frameSize = 1024
        let frameCount = 32
        var frames: [[Float]] = []
        
        for frameIndex in 0..<frameCount {
            var frame = [Float](repeating: 0.0, count: frameSize)
            let rolloffFactor = 1.0 + Float(frameIndex) * 0.1  // Progressive rolloff
            
            for i in 0..<frameSize {
                let phase = Float(i) * 2.0 * Float.pi / Float(frameSize)
                var sample: Float = 0.0
                
                for harmonic in 1...50 {
                    let amplitude = 1.0 / (Float(harmonic) * rolloffFactor)
                    sample += amplitude * sin(phase * Float(harmonic))
                }
                
                frame[i] = sample * 0.5  // Scale down
            }
            frames.append(frame)
        }
        
        let metadata = WavetableMetadata(
            name: "Sawtooth Progression",
            category: .analog,
            description: "Progressive sawtooth with variable harmonic rolloff",
            frameSize: frameSize,
            frameCount: frameCount,
            tags: ["sawtooth", "progression", "analog"],
            isDynamic: true
        )
        
        if let wavetable = try? WavetableData(metadata: metadata, data: frames) {
            wavetables[metadata.id] = wavetable
            updateCategoryIndex(for: metadata)
        }
    }
    
    private func createSquareProgression() {
        let frameSize = 1024
        let frameCount = 16
        var frames: [[Float]] = []
        
        for frameIndex in 0..<frameCount {
            var frame = [Float](repeating: 0.0, count: frameSize)
            let pulseWidth = 0.1 + Float(frameIndex) * 0.05  // Variable pulse width
            
            for i in 0..<frameSize {
                let normalizedPhase = Float(i) / Float(frameSize)
                frame[i] = normalizedPhase < pulseWidth ? 1.0 : -1.0
            }
            
            frames.append(frame)
        }
        
        let metadata = WavetableMetadata(
            name: "Square Progression",
            category: .analog,
            description: "Progressive square wave with variable pulse width",
            frameSize: frameSize,
            frameCount: frameCount,
            tags: ["square", "pulse", "progression"],
            isDynamic: true
        )
        
        if let wavetable = try? WavetableData(metadata: metadata, data: frames) {
            wavetables[metadata.id] = wavetable
            updateCategoryIndex(for: metadata)
        }
    }
}

// MARK: - Extensions

extension Int {
    var isPowerOfTwo: Bool {
        return self > 0 && (self & (self - 1)) == 0
    }
} 