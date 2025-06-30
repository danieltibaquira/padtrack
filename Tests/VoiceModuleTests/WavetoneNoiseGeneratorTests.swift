import XCTest
@testable import VoiceModule
import Accelerate

/// Comprehensive test suite for WAVETONE Noise Generator
/// Tests all noise types, spectral characteristics, and performance
final class WavetoneNoiseGeneratorTests: XCTestCase {
    
    var noiseGenerator: WavetoneNoiseGenerator!
    
    override func setUp() {
        super.setUp()
        noiseGenerator = WavetoneNoiseGenerator(sampleRate: 44100.0)
    }
    
    override func tearDown() {
        noiseGenerator = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialization() {
        XCTAssertNotNil(noiseGenerator)
        XCTAssertEqual(noiseGenerator.noiseType, .white)
        XCTAssertEqual(noiseGenerator.level, 0.0)
    }
    
    func testSilenceWhenLevelZero() {
        noiseGenerator.level = 0.0
        noiseGenerator.noiseType = .white
        
        let sample = noiseGenerator.processSample()
        XCTAssertEqual(sample, 0.0, "Should output silence when level is 0")
    }
    
    func testLevelControl() {
        noiseGenerator.noiseType = .white
        noiseGenerator.level = 0.5
        
        let sample = noiseGenerator.processSample()
        XCTAssertNotEqual(sample, 0.0, "Should output non-zero when level > 0")
        XCTAssertLessThanOrEqual(abs(sample), 0.5, "Output should be scaled by level")
    }
    
    // MARK: - White Noise Tests
    
    func testWhiteNoiseBasic() {
        noiseGenerator.noiseType = .white
        noiseGenerator.level = 1.0
        
        var samples: [Float] = []
        for _ in 0..<1000 {
            samples.append(noiseGenerator.processSample())
        }
        
        // Check that samples are within expected range
        for sample in samples {
            XCTAssertGreaterThanOrEqual(sample, -1.0)
            XCTAssertLessThanOrEqual(sample, 1.0)
        }
        
        // Check that we have variation (not all zeros)
        let variance = calculateVariance(samples)
        XCTAssertGreaterThan(variance, 0.1, "White noise should have significant variance")
    }
    
    func testWhiteNoiseSpectralCharacteristics() {
        noiseGenerator.noiseType = .white
        noiseGenerator.level = 1.0
        
        let sampleCount = 4096
        var samples: [Float] = []
        for _ in 0..<sampleCount {
            samples.append(noiseGenerator.processSample())
        }
        
        // Perform FFT analysis
        let spectrum = performFFT(samples)
        
        // White noise should have relatively flat spectrum
        let lowFreqPower = averagePower(spectrum, startBin: 10, endBin: 50)
        let midFreqPower = averagePower(spectrum, startBin: 200, endBin: 400)
        let highFreqPower = averagePower(spectrum, startBin: 800, endBin: 1200)
        
        // Powers should be relatively similar (within 6dB)
        let ratio1 = lowFreqPower / midFreqPower
        let ratio2 = midFreqPower / highFreqPower
        
        XCTAssertLessThan(abs(log10(ratio1)), 0.3, "White noise spectrum should be relatively flat")
        XCTAssertLessThan(abs(log10(ratio2)), 0.3, "White noise spectrum should be relatively flat")
    }
    
    // MARK: - Pink Noise Tests
    
    func testPinkNoiseBasic() {
        noiseGenerator.noiseType = .pink
        noiseGenerator.level = 1.0
        
        var samples: [Float] = []
        for _ in 0..<1000 {
            samples.append(noiseGenerator.processSample())
        }
        
        // Check output range
        for sample in samples {
            XCTAssertFalse(sample.isNaN, "Pink noise should not produce NaN")
            XCTAssertFalse(sample.isInfinite, "Pink noise should not produce infinite values")
        }
        
        let variance = calculateVariance(samples)
        XCTAssertGreaterThan(variance, 0.01, "Pink noise should have variance")
    }
    
    func testPinkNoiseSpectralSlope() {
        noiseGenerator.noiseType = .pink
        noiseGenerator.level = 1.0
        
        let sampleCount = 8192
        var samples: [Float] = []
        for _ in 0..<sampleCount {
            samples.append(noiseGenerator.processSample())
        }
        
        let spectrum = performFFT(samples)
        
        // Pink noise should have -3dB/octave slope (approximately)
        let lowFreqPower = averagePower(spectrum, startBin: 10, endBin: 20)
        let midFreqPower = averagePower(spectrum, startBin: 40, endBin: 80)
        let highFreqPower = averagePower(spectrum, startBin: 160, endBin: 320)
        
        // Each octave should be roughly 3dB lower
        let slope1 = 10 * log10(midFreqPower / lowFreqPower)
        let slope2 = 10 * log10(highFreqPower / midFreqPower)
        
        XCTAssertLessThan(slope1, -1.0, "Pink noise should have negative spectral slope")
        XCTAssertLessThan(slope2, -1.0, "Pink noise should have negative spectral slope")
        XCTAssertGreaterThan(slope1, -6.0, "Pink noise slope should not be too steep")
        XCTAssertGreaterThan(slope2, -6.0, "Pink noise slope should not be too steep")
    }
    
    // MARK: - Brown Noise Tests
    
    func testBrownNoiseBasic() {
        noiseGenerator.noiseType = .brown
        noiseGenerator.level = 1.0
        
        var samples: [Float] = []
        for _ in 0..<1000 {
            samples.append(noiseGenerator.processSample())
        }
        
        // Brown noise should be more correlated than white noise
        let correlation = calculateAutocorrelation(samples, lag: 1)
        XCTAssertGreaterThan(correlation, 0.5, "Brown noise should have high autocorrelation")
    }
    
    // MARK: - Blue and Violet Noise Tests
    
    func testBlueNoiseBasic() {
        noiseGenerator.noiseType = .blue
        noiseGenerator.level = 1.0
        
        var samples: [Float] = []
        for _ in 0..<1000 {
            samples.append(noiseGenerator.processSample())
        }
        
        // Check for valid output
        let variance = calculateVariance(samples)
        XCTAssertGreaterThan(variance, 0.01, "Blue noise should have variance")
    }
    
    func testVioletNoiseBasic() {
        noiseGenerator.noiseType = .violet
        noiseGenerator.level = 1.0
        
        var samples: [Float] = []
        for _ in 0..<1000 {
            samples.append(noiseGenerator.processSample())
        }
        
        // Check for valid output
        let variance = calculateVariance(samples)
        XCTAssertGreaterThan(variance, 0.01, "Violet noise should have variance")
    }
    
    // MARK: - Filtered Noise Tests
    
    func testFilteredNoiseBasic() {
        noiseGenerator.noiseType = .filtered
        noiseGenerator.level = 1.0
        noiseGenerator.baseFrequency = 1000.0
        noiseGenerator.width = 500.0
        noiseGenerator.resonance = 0.5
        
        var samples: [Float] = []
        for _ in 0..<1000 {
            samples.append(noiseGenerator.processSample())
        }
        
        let variance = calculateVariance(samples)
        XCTAssertGreaterThan(variance, 0.01, "Filtered noise should have variance")
    }
    
    func testFilteredNoiseResonance() {
        noiseGenerator.noiseType = .filtered
        noiseGenerator.level = 1.0
        noiseGenerator.baseFrequency = 1000.0
        
        // Test with low resonance
        noiseGenerator.resonance = 0.1
        var lowResSamples: [Float] = []
        for _ in 0..<1000 {
            lowResSamples.append(noiseGenerator.processSample())
        }
        
        // Reset and test with high resonance
        noiseGenerator.reset()
        noiseGenerator.resonance = 0.9
        var highResSamples: [Float] = []
        for _ in 0..<1000 {
            highResSamples.append(noiseGenerator.processSample())
        }
        
        // High resonance should produce different characteristics
        let lowResVariance = calculateVariance(lowResSamples)
        let highResVariance = calculateVariance(highResSamples)
        
        XCTAssertNotEqual(lowResVariance, highResVariance, accuracy: 0.01, "Resonance should affect output")
    }
    
    // MARK: - Granular Noise Tests
    
    func testGranularNoiseBasic() {
        noiseGenerator.noiseType = .granular
        noiseGenerator.level = 1.0
        noiseGenerator.grain = 0.5
        
        var samples: [Float] = []
        for _ in 0..<1000 {
            samples.append(noiseGenerator.processSample())
        }
        
        // Granular noise should have periods of silence
        let zeroCount = samples.filter { abs($0) < 0.001 }.count
        XCTAssertGreaterThan(zeroCount, 100, "Granular noise should have silent periods")
    }
    
    func testGranularNoiseGrainControl() {
        noiseGenerator.noiseType = .granular
        noiseGenerator.level = 1.0
        
        // Test with low grain density
        noiseGenerator.grain = 0.1
        var lowGrainSamples: [Float] = []
        for _ in 0..<1000 {
            lowGrainSamples.append(noiseGenerator.processSample())
        }
        
        // Reset and test with high grain density
        noiseGenerator.reset()
        noiseGenerator.grain = 0.9
        var highGrainSamples: [Float] = []
        for _ in 0..<1000 {
            highGrainSamples.append(noiseGenerator.processSample())
        }
        
        let lowGrainZeros = lowGrainSamples.filter { abs($0) < 0.001 }.count
        let highGrainZeros = highGrainSamples.filter { abs($0) < 0.001 }.count
        
        XCTAssertGreaterThan(lowGrainZeros, highGrainZeros, "Lower grain density should have more silence")
    }
    
    // MARK: - Crackle Noise Tests
    
    func testCrackleNoiseBasic() {
        noiseGenerator.noiseType = .crackle
        noiseGenerator.level = 1.0
        noiseGenerator.grain = 0.5
        
        var samples: [Float] = []
        for _ in 0..<1000 {
            samples.append(noiseGenerator.processSample())
        }
        
        // Crackle should be very sparse
        let nonZeroCount = samples.filter { abs($0) > 0.001 }.count
        XCTAssertLessThan(nonZeroCount, 100, "Crackle noise should be very sparse")
    }
    
    // MARK: - Performance Tests
    
    func testPerformance() {
        noiseGenerator.noiseType = .pink
        noiseGenerator.level = 1.0
        
        let sampleCount = 44100  // 1 second at 44.1kHz
        
        measure {
            for _ in 0..<sampleCount {
                _ = noiseGenerator.processSample()
            }
        }
    }
    
    func testBlockProcessing() {
        noiseGenerator.noiseType = .white
        noiseGenerator.level = 1.0
        
        let blockSize = 512
        var output = Array<Float>(repeating: 0.0, count: blockSize)
        
        noiseGenerator.processBlock(output: &output, blockSize: blockSize)
        
        // Check that block processing produces valid output
        let variance = calculateVariance(output)
        XCTAssertGreaterThan(variance, 0.1, "Block processing should produce valid noise")
    }
    
    // MARK: - Utility Methods
    
    private func calculateVariance(_ samples: [Float]) -> Float {
        let mean = samples.reduce(0, +) / Float(samples.count)
        let squaredDiffs = samples.map { ($0 - mean) * ($0 - mean) }
        return squaredDiffs.reduce(0, +) / Float(samples.count)
    }
    
    private func calculateAutocorrelation(_ samples: [Float], lag: Int) -> Float {
        guard lag < samples.count else { return 0.0 }
        
        var correlation: Float = 0.0
        for i in 0..<(samples.count - lag) {
            correlation += samples[i] * samples[i + lag]
        }
        
        return correlation / Float(samples.count - lag)
    }
    
    private func performFFT(_ samples: [Float]) -> [Float] {
        let count = samples.count
        let log2n = vDSP_Length(log2(Float(count)))
        
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return []
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        var realp = [Float](repeating: 0.0, count: count/2)
        var imagp = [Float](repeating: 0.0, count: count/2)
        var output = DSPSplitComplex(realp: &realp, imagp: &imagp)
        
        var input = samples
        input.withUnsafeMutableBufferPointer { inputPtr in
            vDSP_ctoz(UnsafePointer<DSPComplex>(OpaquePointer(inputPtr.baseAddress!)), 2, &output, 1, vDSP_Length(count/2))
        }
        
        vDSP_fft_zrip(fftSetup, &output, 1, log2n, FFTDirection(FFT_FORWARD))
        
        var magnitudes = [Float](repeating: 0.0, count: count/2)
        vDSP_zvmags(&output, 1, &magnitudes, 1, vDSP_Length(count/2))
        
        return magnitudes
    }
    
    private func averagePower(_ spectrum: [Float], startBin: Int, endBin: Int) -> Float {
        let clampedStart = max(0, startBin)
        let clampedEnd = min(spectrum.count - 1, endBin)
        
        guard clampedStart < clampedEnd else { return 0.0 }
        
        let sum = spectrum[clampedStart...clampedEnd].reduce(0, +)
        return sum / Float(clampedEnd - clampedStart + 1)
    }
}
