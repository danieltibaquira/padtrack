// NoiseGeneratorModuleTests.swift
// DigitonePad - VoiceModuleTests
//
// Comprehensive test suite for Noise Generator Module

import XCTest
import AudioEngine
import MachineProtocols
@testable import VoiceModule

final class NoiseGeneratorModuleTests: XCTestCase {
    
    var noiseGenerator: NoiseGeneratorModule!
    let sampleRate: Double = 44100.0
    let bufferSize = 512
    
    override func setUp() {
        super.setUp()
        var config = NoiseGeneratorConfig()
        config.sampleRate = sampleRate
        config.level = 1.0
        noiseGenerator = NoiseGeneratorModule(config: config)
    }
    
    override func tearDown() {
        noiseGenerator = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialization() {
        XCTAssertNotNil(noiseGenerator)
        XCTAssertEqual(noiseGenerator.config.sampleRate, sampleRate)
        XCTAssertEqual(noiseGenerator.config.level, 1.0)
        XCTAssertEqual(noiseGenerator.config.noiseType, .white)
    }
    
    func testWhiteNoiseGeneration() {
        noiseGenerator.config.noiseType = .white
        noiseGenerator.config.level = 1.0
        
        var samples: [Float] = []
        for _ in 0..<1000 {
            samples.append(noiseGenerator.processSample())
        }
        
        // Check that we get non-zero output
        let hasNonZeroOutput = samples.contains { $0 != 0.0 }
        XCTAssertTrue(hasNonZeroOutput, "White noise should produce non-zero output")
        
        // Check that samples are within expected range
        let maxSample = samples.max() ?? 0.0
        let minSample = samples.min() ?? 0.0
        XCTAssertLessThanOrEqual(maxSample, 1.0, "White noise should not exceed level")
        XCTAssertGreaterThanOrEqual(minSample, -1.0, "White noise should not go below -level")
        
        // Check for reasonable distribution (should have both positive and negative values)
        let positiveCount = samples.filter { $0 > 0.0 }.count
        let negativeCount = samples.filter { $0 < 0.0 }.count
        XCTAssertGreaterThan(positiveCount, 100, "Should have positive samples")
        XCTAssertGreaterThan(negativeCount, 100, "Should have negative samples")
    }
    
    func testPinkNoiseGeneration() {
        noiseGenerator.config.noiseType = .pink
        noiseGenerator.config.level = 1.0
        
        var samples: [Float] = []
        for _ in 0..<1000 {
            samples.append(noiseGenerator.processSample())
        }
        
        // Check that we get non-zero output
        let hasNonZeroOutput = samples.contains { $0 != 0.0 }
        XCTAssertTrue(hasNonZeroOutput, "Pink noise should produce non-zero output")
        
        // Pink noise should be different from white noise (less high-frequency content)
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
        XCTAssertGreaterThan(rms, 0.01, "Pink noise should have reasonable RMS level")
    }
    
    func testBrownNoiseGeneration() {
        noiseGenerator.config.noiseType = .brown
        noiseGenerator.config.level = 1.0
        
        var samples: [Float] = []
        for _ in 0..<1000 {
            samples.append(noiseGenerator.processSample())
        }
        
        // Check that we get non-zero output
        let hasNonZeroOutput = samples.contains { $0 != 0.0 }
        XCTAssertTrue(hasNonZeroOutput, "Brown noise should produce non-zero output")
        
        // Brown noise should be smoother than white noise (check for correlation)
        var correlation: Float = 0.0
        for i in 1..<samples.count {
            correlation += samples[i] * samples[i-1]
        }
        correlation /= Float(samples.count - 1)
        XCTAssertGreaterThan(correlation, 0.0, "Brown noise should have positive correlation between adjacent samples")
    }
    
    func testFilteredNoiseGeneration() {
        noiseGenerator.config.noiseType = .filtered
        noiseGenerator.config.level = 1.0
        noiseGenerator.config.filterFrequency = 1000.0
        noiseGenerator.config.filterBandwidth = 200.0
        
        var samples: [Float] = []
        for _ in 0..<1000 {
            samples.append(noiseGenerator.processSample())
        }
        
        // Check that we get non-zero output
        let hasNonZeroOutput = samples.contains { $0 != 0.0 }
        XCTAssertTrue(hasNonZeroOutput, "Filtered noise should produce non-zero output")
        
        // Filtered noise should have different characteristics than white noise
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
        XCTAssertGreaterThan(rms, 0.001, "Filtered noise should have measurable output")
    }
    
    func testGranularNoiseGeneration() {
        noiseGenerator.config.noiseType = .granular
        noiseGenerator.config.level = 1.0
        noiseGenerator.config.grainDensity = 0.5
        noiseGenerator.config.grainSize = 0.01
        
        var samples: [Float] = []
        for _ in 0..<1000 {
            samples.append(noiseGenerator.processSample())
        }
        
        // Granular noise should have periods of silence
        let silentCount = samples.filter { abs($0) < 0.001 }.count
        XCTAssertGreaterThan(silentCount, 100, "Granular noise should have silent periods")
        
        // Should also have non-silent periods
        let nonSilentCount = samples.filter { abs($0) >= 0.001 }.count
        XCTAssertGreaterThan(nonSilentCount, 100, "Granular noise should have active periods")
    }
    
    func testCracklingNoiseGeneration() {
        noiseGenerator.config.noiseType = .crackling
        noiseGenerator.config.level = 1.0
        noiseGenerator.config.cracklingRate = 10.0
        noiseGenerator.config.cracklingIntensity = 1.0
        
        var samples: [Float] = []
        for _ in 0..<Int(sampleRate) {  // 1 second of samples
            samples.append(noiseGenerator.processSample())
        }
        
        // Crackling noise should be mostly silent with occasional bursts
        let silentCount = samples.filter { abs($0) < 0.001 }.count
        let totalCount = samples.count
        let silentRatio = Float(silentCount) / Float(totalCount)
        
        XCTAssertGreaterThan(silentRatio, 0.8, "Crackling noise should be mostly silent")
        
        // Should have some non-silent samples
        let nonSilentCount = totalCount - silentCount
        XCTAssertGreaterThan(nonSilentCount, 10, "Crackling noise should have some active samples")
    }
    
    func testDigitalNoiseGeneration() {
        noiseGenerator.config.noiseType = .digital
        noiseGenerator.config.level = 1.0
        noiseGenerator.config.bitDepth = 4  // Low bit depth for obvious quantization
        
        var samples: [Float] = []
        for _ in 0..<1000 {
            samples.append(noiseGenerator.processSample())
        }
        
        // Check that we get non-zero output
        let hasNonZeroOutput = samples.contains { $0 != 0.0 }
        XCTAssertTrue(hasNonZeroOutput, "Digital noise should produce non-zero output")
        
        // Digital noise should show quantization effects
        let uniqueValues = Set(samples.map { round($0 * 16.0) / 16.0 })
        XCTAssertLessThan(uniqueValues.count, samples.count / 2, "Digital noise should show quantization")
    }
    
    // MARK: - Parameter Tests
    
    func testLevelControl() {
        noiseGenerator.config.noiseType = .white
        
        // Test level 0.0 (should be silent)
        noiseGenerator.config.level = 0.0
        let silentSample = noiseGenerator.processSample()
        XCTAssertEqual(silentSample, 0.0, "Level 0.0 should produce silence")
        
        // Test level 0.5
        noiseGenerator.config.level = 0.5
        var samples: [Float] = []
        for _ in 0..<100 {
            samples.append(noiseGenerator.processSample())
        }
        
        let maxSample = samples.max() ?? 0.0
        XCTAssertLessThanOrEqual(maxSample, 0.5, "Level 0.5 should limit output")
        
        // Test level 1.0
        noiseGenerator.config.level = 1.0
        samples = []
        for _ in 0..<100 {
            samples.append(noiseGenerator.processSample())
        }
        
        let maxSampleFull = samples.max() ?? 0.0
        XCTAssertGreaterThan(maxSampleFull, maxSample, "Level 1.0 should produce higher output than 0.5")
    }
    
    func testFilterParameters() {
        noiseGenerator.config.noiseType = .filtered
        noiseGenerator.config.level = 1.0
        
        // Test different filter frequencies
        noiseGenerator.config.filterFrequency = 500.0
        var lowFreqSamples: [Float] = []
        for _ in 0..<1000 {
            lowFreqSamples.append(noiseGenerator.processSample())
        }
        
        noiseGenerator.reset()
        noiseGenerator.config.filterFrequency = 2000.0
        var highFreqSamples: [Float] = []
        for _ in 0..<1000 {
            highFreqSamples.append(noiseGenerator.processSample())
        }
        
        // Different filter frequencies should produce different results
        let lowRMS = sqrt(lowFreqSamples.map { $0 * $0 }.reduce(0, +) / Float(lowFreqSamples.count))
        let highRMS = sqrt(highFreqSamples.map { $0 * $0 }.reduce(0, +) / Float(highFreqSamples.count))
        
        // Both should produce output
        XCTAssertGreaterThan(lowRMS, 0.001, "Low frequency filter should produce output")
        XCTAssertGreaterThan(highRMS, 0.001, "High frequency filter should produce output")
    }
    
    // MARK: - Block Processing Tests
    
    func testBlockProcessing() {
        noiseGenerator.config.noiseType = .white
        noiseGenerator.config.level = 1.0
        
        let blockSize = 256
        var output = [Float](repeating: 0.0, count: blockSize)
        
        noiseGenerator.processBlock(output: &output, blockSize: blockSize)
        
        // Check that we get non-zero output
        let hasNonZeroOutput = output.contains { $0 != 0.0 }
        XCTAssertTrue(hasNonZeroOutput, "Block processing should produce non-zero output")
        
        // Check that all samples are filled
        let nonZeroCount = output.filter { $0 != 0.0 }.count
        XCTAssertGreaterThan(nonZeroCount, blockSize / 2, "Most samples should be non-zero")
    }
    
    func testBlockProcessingWithZeroLevel() {
        noiseGenerator.config.noiseType = .white
        noiseGenerator.config.level = 0.0
        
        let blockSize = 256
        var output = [Float](repeating: 1.0, count: blockSize)  // Pre-fill with non-zero
        
        noiseGenerator.processBlock(output: &output, blockSize: blockSize)
        
        // All samples should be zero
        let allZero = output.allSatisfy { $0 == 0.0 }
        XCTAssertTrue(allZero, "Zero level should produce all zero output")
    }
    
    // MARK: - Performance Tests
    
    func testPerformance() {
        noiseGenerator.config.noiseType = .white
        noiseGenerator.config.level = 1.0
        
        measure {
            for _ in 0..<10000 {
                _ = noiseGenerator.processSample()
            }
        }
    }
    
    func testBlockPerformance() {
        noiseGenerator.config.noiseType = .white
        noiseGenerator.config.level = 1.0
        
        let blockSize = 512
        var output = [Float](repeating: 0.0, count: blockSize)
        
        measure {
            for _ in 0..<100 {
                noiseGenerator.processBlock(output: &output, blockSize: blockSize)
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testReset() {
        noiseGenerator.config.noiseType = .brown
        noiseGenerator.config.level = 1.0
        
        // Generate some samples to establish state
        for _ in 0..<100 {
            _ = noiseGenerator.processSample()
        }
        
        // Reset and check that state is cleared
        noiseGenerator.reset()
        
        // After reset, should still produce valid output
        let sample = noiseGenerator.processSample()
        XCTAssertFalse(sample.isNaN, "Sample after reset should not be NaN")
        XCTAssertFalse(sample.isInfinite, "Sample after reset should not be infinite")
    }
    
    func testAllNoiseTypes() {
        // Test that all noise types can be generated without errors
        for noiseType in NoiseGenerationType.allCases {
            noiseGenerator.config.noiseType = noiseType
            noiseGenerator.config.level = 1.0
            noiseGenerator.reset()
            
            var samples: [Float] = []
            for _ in 0..<100 {
                let sample = noiseGenerator.processSample()
                XCTAssertFalse(sample.isNaN, "\(noiseType) should not produce NaN")
                XCTAssertFalse(sample.isInfinite, "\(noiseType) should not produce infinite values")
                samples.append(sample)
            }
            
            // Most noise types should produce some non-zero output
            if noiseType != .crackling {  // Crackling might be mostly silent
                let hasOutput = samples.contains { abs($0) > 0.001 }
                XCTAssertTrue(hasOutput, "\(noiseType) should produce some output")
            }
        }
    }
    
    func testConfigurationChanges() {
        noiseGenerator.config.noiseType = .white
        noiseGenerator.config.level = 1.0
        
        // Change configuration and verify it takes effect
        noiseGenerator.config.noiseType = .pink
        noiseGenerator.config.level = 0.5
        
        let sample = noiseGenerator.processSample()
        XCTAssertLessThanOrEqual(abs(sample), 0.5, "Configuration change should take effect")
    }
}
