import XCTest
import MachineProtocols
@testable import FilterModule
@testable import TestUtilities

/// Performance tests for FilterModule real-time audio processing
final class FilterPerformanceTests: XCTestCase {
    
    // MARK: - Real-Time Performance Tests
    
    func testFilterResonanceRealTimePerformance() {
        let constraints = AudioPerformanceBenchmarks.RealTimeConstraints(
            sampleRate: 44100.0,
            bufferSize: 512,
            channelCount: 2
        )
        
        let resonanceEngine = FilterResonanceEngine()
        let testInput: Float = 0.5
        let cutoffFreq: Float = 1000.0
        
        measureRealTimeAudioPerformance(
            name: "FilterResonance Single Sample",
            constraints: constraints
        ) {
            _ = resonanceEngine.processSample(
                input: testInput,
                cutoffFrequency: cutoffFreq,
                sampleRate: Float(constraints.sampleRate)
            )
        }
    }
    
    func testFilterResonanceBufferPerformance() {
        let constraints = AudioPerformanceBenchmarks.RealTimeConstraints(
            sampleRate: 44100.0,
            bufferSize: 512,
            channelCount: 2
        )
        
        let resonanceEngine = FilterResonanceEngine()
        let testBuffer: [Float] = Array(0..<constraints.bufferSize).map { i in
            sin(Float(i) * 2.0 * Float.pi * 440.0 / Float(constraints.sampleRate)) * 0.5
        }
        let cutoffFreq: Float = 1000.0
        
        measureRealTimeAudioPerformance(
            name: "FilterResonance Buffer Processing",
            constraints: constraints
        ) {
            _ = resonanceEngine.processBuffer(
                input: testBuffer,
                cutoffFrequency: cutoffFreq,
                sampleRate: Float(constraints.sampleRate)
            )
        }
    }
    
    func testFourPoleLadderFilterPerformance() {
        let constraints = AudioPerformanceBenchmarks.RealTimeConstraints(
            sampleRate: 44100.0,
            bufferSize: 512,
            channelCount: 2
        )
        
        var config = LadderFilterConfig()
        config.cutoff = 1000.0
        config.resonance = 0.5
        config.drive = 1.0
        
        let ladderFilter = FourPoleLadderFilter(config: config, sampleRate: constraints.sampleRate)
        let testInput: Float = 0.5
        
        measureRealTimeAudioPerformance(
            name: "FourPoleLadderFilter Single Sample",
            constraints: constraints
        ) {
            _ = ladderFilter.processSample(testInput)
        }
    }
    
    // MARK: - Comprehensive Filter Performance Suite
    
    func testFilterModulePerformanceSuite() {
        let constraints = AudioPerformanceBenchmarks.RealTimeConstraints(
            sampleRate: 44100.0,
            bufferSize: 512,
            channelCount: 2
        )
        
        // Run comprehensive benchmarks
        var results: [AudioPerformanceBenchmarks.BenchmarkResult] = []
        
        // FilterResonance benchmarks
        results.append(benchmarkFilterResonanceEngine(constraints: constraints))
        results.append(benchmarkFilterResonanceModulation(constraints: constraints))
        
        // FourPoleLadderFilter benchmarks
        results.append(benchmarkLadderFilterProcessing(constraints: constraints))
        results.append(benchmarkLadderFilterParameterChanges(constraints: constraints))
        
        // Generate and print report
        let report = AudioPerformanceBenchmarks.generateReport(results)
        print("\n" + report)
        
        // Assert that critical filters meet real-time requirements
        for result in results {
            XCTAssertTrue(
                result.isRealTimeCapable,
                "\(result.testName) failed real-time constraint: \(result.processingTime * 1000)ms > \(result.maxLatency * 1000)ms"
            )
        }
        
        // Assert overall performance
        let passRate = Double(results.filter { $0.isRealTimeCapable }.count) / Double(results.count)
        XCTAssertGreaterThanOrEqual(passRate, 0.9, "At least 90% of filter tests should meet real-time constraints")
    }
    
    // MARK: - Specific Filter Benchmarks
    
    private func benchmarkFilterResonanceEngine(
        constraints: AudioPerformanceBenchmarks.RealTimeConstraints
    ) -> AudioPerformanceBenchmarks.BenchmarkResult {
        let resonanceEngine = FilterResonanceEngine()
        let testInput: Float = 0.5
        let cutoffFreq: Float = 1000.0
        
        return AudioPerformanceBenchmarks.runBenchmark(
            name: "FilterResonanceEngine Processing",
            constraints: constraints,
            iterations: 10000
        ) {
            _ = resonanceEngine.processSample(
                input: testInput,
                cutoffFrequency: cutoffFreq,
                sampleRate: Float(constraints.sampleRate)
            )
        }
    }
    
    private func benchmarkFilterResonanceModulation(
        constraints: AudioPerformanceBenchmarks.RealTimeConstraints
    ) -> AudioPerformanceBenchmarks.BenchmarkResult {
        let resonanceEngine = FilterResonanceEngine()
        let testInput: Float = 0.5
        let cutoffFreq: Float = 1000.0
        
        // Enable modulation for more realistic CPU load
        resonanceEngine.parameters.modulation = 0.5
        resonanceEngine.parameters.keyTracking = 0.3
        
        return AudioPerformanceBenchmarks.runBenchmark(
            name: "FilterResonance with Modulation",
            constraints: constraints,
            iterations: 10000
        ) {
            _ = resonanceEngine.processSample(
                input: testInput,
                cutoffFrequency: cutoffFreq,
                sampleRate: Float(constraints.sampleRate)
            )
        }
    }
    
    private func benchmarkLadderFilterProcessing(
        constraints: AudioPerformanceBenchmarks.RealTimeConstraints
    ) -> AudioPerformanceBenchmarks.BenchmarkResult {
        var config = LadderFilterConfig()
        config.cutoff = 1000.0
        config.resonance = 0.7
        config.drive = 2.0
        
        let ladderFilter = FourPoleLadderFilter(config: config, sampleRate: constraints.sampleRate)
        let testInput: Float = 0.5
        
        return AudioPerformanceBenchmarks.runBenchmark(
            name: "FourPoleLadderFilter Processing",
            constraints: constraints,
            iterations: 10000
        ) {
            _ = ladderFilter.processSample(testInput)
        }
    }
    
    private func benchmarkLadderFilterParameterChanges(
        constraints: AudioPerformanceBenchmarks.RealTimeConstraints
    ) -> AudioPerformanceBenchmarks.BenchmarkResult {
        var config = LadderFilterConfig()
        config.cutoff = 1000.0
        config.resonance = 0.5
        
        let ladderFilter = FourPoleLadderFilter(config: config, sampleRate: constraints.sampleRate)
        let testInput: Float = 0.5
        
        return AudioPerformanceBenchmarks.runBenchmark(
            name: "LadderFilter Parameter Updates",
            constraints: constraints,
            iterations: 5000
        ) {
            // Simulate real-time parameter changes
            ladderFilter.cutoff = Float.random(in: 200...8000)
            ladderFilter.resonance = Float.random(in: 0.1...0.9)
            _ = ladderFilter.processSample(testInput)
        }
    }
    
    // MARK: - Stress Tests
    
    func testFilterUnderStress() {
        let constraints = AudioPerformanceBenchmarks.RealTimeConstraints(
            sampleRate: 44100.0,
            bufferSize: 128, // Smaller buffer = more demanding
            channelCount: 2
        )
        
        let resonanceEngine = FilterResonanceEngine()
        
        // High resonance, self-oscillation, maximum processing load
        resonanceEngine.parameters.amount = 0.95
        resonanceEngine.parameters.modulation = 1.0
        resonanceEngine.config.selfOscillationThreshold = 0.8
        
        let testInput: Float = 1.0  // High input level
        let cutoffFreq: Float = 100.0  // Low cutoff for maximum resonance effect
        
        measureRealTimeAudioPerformance(
            name: "FilterResonance Stress Test",
            constraints: constraints
        ) {
            _ = resonanceEngine.processSample(
                input: testInput,
                cutoffFrequency: cutoffFreq,
                sampleRate: Float(constraints.sampleRate)
            )
        }
    }
    
    // MARK: - Memory Performance Tests
    
    func testFilterMemoryPerformance() {
        let constraints = AudioPerformanceBenchmarks.RealTimeConstraints()
        
        measure {
            // Test filter creation and destruction performance
            for _ in 0..<100 {
                var config = LadderFilterConfig()
                config.cutoff = 1000.0
                let filter = FourPoleLadderFilter(config: config, sampleRate: constraints.sampleRate)
                _ = filter.processSample(0.5)
                // Filter goes out of scope here
            }
        }
    }
    
    // MARK: - Polyphony Performance Tests
    
    func testMultipleFilterInstances() {
        let constraints = AudioPerformanceBenchmarks.RealTimeConstraints(
            sampleRate: 44100.0,
            bufferSize: 512,
            channelCount: 2
        )
        
        // Create multiple filter instances (simulating polyphony)
        let filterCount = 8
        var filters: [FourPoleLadderFilter] = []
        
        for i in 0..<filterCount {
            var config = LadderFilterConfig()
            config.cutoff = 500.0 + Float(i) * 200.0  // Different cutoff for each
            config.resonance = 0.6
            filters.append(FourPoleLadderFilter(config: config, sampleRate: constraints.sampleRate))
        }
        
        let testInput: Float = 0.5
        
        measureRealTimeAudioPerformance(
            name: "Multiple Filter Instances",
            constraints: constraints
        ) {
            for filter in filters {
                _ = filter.processSample(testInput)
            }
        }
        
        // Assert that polyphonic processing is still real-time capable
        let maxLatency = Double(constraints.bufferSize) / constraints.sampleRate * 0.5
        let result = AudioPerformanceBenchmarks.runBenchmark(
            name: "8-Voice Filter Polyphony",
            constraints: constraints
        ) {
            for filter in filters {
                _ = filter.processSample(testInput)
            }
        }
        
        XCTAssertTrue(result.isRealTimeCapable, "8-voice filter polyphony should be real-time capable")
    }
}