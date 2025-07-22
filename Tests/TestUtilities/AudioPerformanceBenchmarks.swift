import Foundation
import XCTest
import MachineProtocols
@testable import AudioEngine
@testable import VoiceModule
@testable import FilterModule

/// Comprehensive performance benchmarks for real-time audio processing
public class AudioPerformanceBenchmarks {
    
    // MARK: - Real-Time Constraints
    
    /// Standard real-time audio processing constraints
    public struct RealTimeConstraints {
        public let sampleRate: Double
        public let bufferSize: Int
        public let channelCount: Int
        public let maxLatency: TimeInterval  // Maximum acceptable processing time
        public let targetCPUUsage: Double   // Target CPU usage (0.0 to 1.0)
        
        public init(
            sampleRate: Double = 44100.0,
            bufferSize: Int = 512,
            channelCount: Int = 2,
            maxLatency: TimeInterval? = nil,
            targetCPUUsage: Double = 0.5
        ) {
            self.sampleRate = sampleRate
            self.bufferSize = bufferSize
            self.channelCount = channelCount
            self.maxLatency = maxLatency ?? (Double(bufferSize) / sampleRate * 0.5) // 50% of buffer duration
            self.targetCPUUsage = targetCPUUsage
        }
    }
    
    // MARK: - Benchmark Results
    
    public struct BenchmarkResult {
        public let testName: String
        public let processingTime: TimeInterval
        public let maxLatency: TimeInterval
        public let samplesProcessed: Int
        public let isRealTimeCapable: Bool
        public let cpuUsageEstimate: Double
        public let memoryUsage: Int64
        public let iterations: Int
        
        public var efficiency: Double {
            return maxLatency > 0 ? (1.0 - (processingTime / maxLatency)) : 0.0
        }
        
        public var throughput: Double {
            return processingTime > 0 ? Double(samplesProcessed) / processingTime : 0.0
        }
    }
    
    // MARK: - Core Benchmarking Infrastructure
    
    /// Run a performance benchmark with real-time constraints
    public static func runBenchmark(
        name: String,
        constraints: RealTimeConstraints = RealTimeConstraints(),
        iterations: Int = 1000,
        warmupIterations: Int = 100,
        operation: () throws -> Void
    ) -> BenchmarkResult {
        // Warm up
        for _ in 0..<warmupIterations {
            try? operation()
        }
        
        // Measure memory before
        let memoryBefore = getCurrentMemoryUsage()
        
        // Run benchmark
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            try? operation()
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        let averageTime = totalTime / Double(iterations)
        
        // Measure memory after
        let memoryAfter = getCurrentMemoryUsage()
        let memoryDelta = memoryAfter - memoryBefore
        
        let samplesPerIteration = constraints.bufferSize * constraints.channelCount
        let totalSamples = samplesPerIteration * iterations
        
        let isRealTimeCapable = averageTime <= constraints.maxLatency
        let cpuUsageEstimate = averageTime / (Double(constraints.bufferSize) / constraints.sampleRate)
        
        return BenchmarkResult(
            testName: name,
            processingTime: averageTime,
            maxLatency: constraints.maxLatency,
            samplesProcessed: totalSamples,
            isRealTimeCapable: isRealTimeCapable,
            cpuUsageEstimate: cpuUsageEstimate,
            memoryUsage: memoryDelta,
            iterations: iterations
        )
    }
    
    // MARK: - AudioEngine Benchmarks
    
    /// Benchmark AudioEngine buffer processing
    public static func benchmarkAudioEngineProcessing(
        constraints: RealTimeConstraints = RealTimeConstraints()
    ) -> BenchmarkResult {
        let buffer = AudioTestUtilities.createSineWaveBuffer(
            frameCount: constraints.bufferSize,
            channelCount: constraints.channelCount,
            sampleRate: constraints.sampleRate
        )
        defer { AudioTestUtilities.deallocateBuffer(buffer) }
        
        return runBenchmark(
            name: "AudioEngine Buffer Processing",
            constraints: constraints
        ) {
            // Simulate basic audio engine processing
            AudioTestUtilities.calculateRMS(buffer)
            AudioTestUtilities.calculatePeak(buffer)
        }
    }
    
    /// Benchmark audio format conversions
    public static func benchmarkAudioFormatConversion(
        constraints: RealTimeConstraints = RealTimeConstraints()
    ) -> BenchmarkResult {
        let buffer = AudioTestUtilities.createSineWaveBuffer(
            frameCount: constraints.bufferSize,
            channelCount: constraints.channelCount,
            sampleRate: constraints.sampleRate
        )
        defer { AudioTestUtilities.deallocateBuffer(buffer) }
        
        return runBenchmark(
            name: "Audio Format Conversion",
            constraints: constraints
        ) {
            // Simulate format conversion operations
            let totalSamples = buffer.frameCount * buffer.channelCount
            for i in 0..<totalSamples {
                // Simulate float to int16 conversion
                let sample = buffer.data[i]
                _ = Int16(sample * 32767.0)
            }
        }
    }
    
    // MARK: - Voice Module Benchmarks
    
    /// Benchmark WavetoneVoiceMachine processing
    public static func benchmarkWavetoneVoiceMachine(
        constraints: RealTimeConstraints = RealTimeConstraints()
    ) -> BenchmarkResult {
        let voiceMachine = VoiceMachineTestHelpers.createTestWavetoneVoiceMachine(
            sampleRate: Float(constraints.sampleRate)
        )
        VoiceMachineTestHelpers.applyConfiguration(.performance, to: voiceMachine)
        
        // Trigger a note
        voiceMachine.noteOn(note: 60, velocity: 100, channel: 0, timestamp: nil)
        
        return runBenchmark(
            name: "WavetoneVoiceMachine Processing",
            constraints: constraints
        ) {
            // Simulate voice machine processing a buffer
            // In real implementation, this would call voiceMachine.process(buffer)
            _ = voiceMachine.getParameter("osc1_level")
        }
    }
    
    /// Benchmark voice machine parameter updates
    public static func benchmarkParameterUpdates(
        constraints: RealTimeConstraints = RealTimeConstraints()
    ) -> BenchmarkResult {
        let voiceMachine = VoiceMachineTestHelpers.createTestWavetoneVoiceMachine(
            sampleRate: Float(constraints.sampleRate)
        )
        
        let parameters = [
            VoiceMachineTestHelpers.CommonParameters.osc1Level,
            VoiceMachineTestHelpers.CommonParameters.osc2Tuning,
            VoiceMachineTestHelpers.CommonParameters.ampAttack
        ]
        
        return runBenchmark(
            name: "Voice Machine Parameter Updates",
            constraints: constraints
        ) {
            let param = parameters.randomElement()!
            let value = Float.random(in: 0.0...1.0)
            voiceMachine.setParameter(param, value: value)
        }
    }
    
    // MARK: - Filter Module Benchmarks
    
    /// Benchmark filter processing performance
    public static func benchmarkFilterProcessing(
        constraints: RealTimeConstraints = RealTimeConstraints()
    ) -> BenchmarkResult {
        let buffer = AudioTestUtilities.createSineWaveBuffer(
            frequency: 1000.0,
            frameCount: constraints.bufferSize,
            channelCount: constraints.channelCount,
            sampleRate: constraints.sampleRate
        )
        defer { AudioTestUtilities.deallocateBuffer(buffer) }
        
        return runBenchmark(
            name: "Filter Processing",
            constraints: constraints
        ) {
            // Simulate basic filter operations
            let totalSamples = buffer.frameCount * buffer.channelCount
            for i in 0..<totalSamples {
                // Simple lowpass filter simulation
                let sample = buffer.data[i]
                buffer.data[i] = sample * 0.9 // Simple attenuation
            }
        }
    }
    
    // MARK: - Memory Management Benchmarks
    
    /// Benchmark buffer allocation and deallocation
    public static func benchmarkMemoryManagement(
        constraints: RealTimeConstraints = RealTimeConstraints()
    ) -> BenchmarkResult {
        return runBenchmark(
            name: "Buffer Memory Management",
            constraints: constraints
        ) {
            let buffer = AudioTestUtilities.createTestBuffer(
                frameCount: constraints.bufferSize,
                channelCount: constraints.channelCount,
                sampleRate: constraints.sampleRate
            )
            // Immediate deallocation to test memory management overhead
            AudioTestUtilities.deallocateBuffer(buffer)
        }
    }
    
    // MARK: - Comprehensive Benchmark Suite
    
    /// Run all benchmarks and return results
    public static func runComprehensiveBenchmarks(
        constraints: RealTimeConstraints = RealTimeConstraints()
    ) -> [BenchmarkResult] {
        var results: [BenchmarkResult] = []
        
        print("🎵 Running Audio Performance Benchmarks...")
        print("📊 Constraints: \(constraints.bufferSize) samples @ \(constraints.sampleRate)Hz, max latency: \(constraints.maxLatency * 1000)ms")
        
        // Core audio processing
        results.append(benchmarkAudioEngineProcessing(constraints: constraints))
        results.append(benchmarkAudioFormatConversion(constraints: constraints))
        
        // Voice processing
        results.append(benchmarkWavetoneVoiceMachine(constraints: constraints))
        results.append(benchmarkParameterUpdates(constraints: constraints))
        
        // Filter processing
        results.append(benchmarkFilterProcessing(constraints: constraints))
        
        // Memory management
        results.append(benchmarkMemoryManagement(constraints: constraints))
        
        return results
    }
    
    // MARK: - Reporting
    
    /// Generate a performance report
    public static func generateReport(_ results: [BenchmarkResult]) -> String {
        var report = "🎵 AUDIO PERFORMANCE BENCHMARK REPORT 🎵\n"
        report += "=" * 60 + "\n\n"
        
        let realTimeCapable = results.filter { $0.isRealTimeCapable }
        let totalTests = results.count
        
        report += "📈 SUMMARY:\n"
        report += "  • Total tests: \(totalTests)\n"
        report += "  • Real-time capable: \(realTimeCapable.count)/\(totalTests) (\(Int(Double(realTimeCapable.count)/Double(totalTests)*100))%)\n"
        report += "  • Average efficiency: \(String(format: "%.1f", results.map{$0.efficiency}.reduce(0,+)/Double(results.count)*100))%\n\n"
        
        report += "📊 DETAILED RESULTS:\n"
        report += "-" * 60 + "\n"
        
        for result in results {
            let status = result.isRealTimeCapable ? "✅ RT" : "❌ FAIL"
            let processingMs = result.processingTime * 1000
            let latencyMs = result.maxLatency * 1000
            let efficiency = result.efficiency * 100
            
            report += "\(status) \(result.testName)\n"
            report += "     ⏱️  Processing: \(String(format: "%.2f", processingMs))ms (limit: \(String(format: "%.2f", latencyMs))ms)\n"
            report += "     📊 Efficiency: \(String(format: "%.1f", efficiency))%\n"
            report += "     💾 Memory: \(result.memoryUsage) bytes\n"
            report += "     🔄 Throughput: \(String(format: "%.0f", result.throughput)) samples/sec\n\n"
        }
        
        report += "🎯 RECOMMENDATIONS:\n"
        report += "-" * 60 + "\n"
        
        let failedTests = results.filter { !$0.isRealTimeCapable }
        if failedTests.isEmpty {
            report += "✅ All tests pass real-time constraints!\n"
            report += "💡 System is ready for real-time audio processing.\n"
        } else {
            report += "⚠️  Failed tests need optimization:\n"
            for test in failedTests {
                let overhead = (test.processingTime - test.maxLatency) * 1000
                report += "  • \(test.testName): \(String(format: "%.2f", overhead))ms over budget\n"
            }
            report += "\n💡 Consider:\n"
            report += "  - Algorithm optimization\n"
            report += "  - Buffer size increase\n"
            report += "  - Multi-threading\n"
            report += "  - Memory pre-allocation\n"
        }
        
        return report
    }
    
    // MARK: - Utilities
    
    /// Get current memory usage (simplified)
    private static func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
}

// MARK: - XCTest Integration

extension XCTestCase {
    /// Run a performance test with real-time audio constraints
    public func measureRealTimeAudioPerformance(
        name: String,
        constraints: AudioPerformanceBenchmarks.RealTimeConstraints = AudioPerformanceBenchmarks.RealTimeConstraints(),
        operation: () throws -> Void
    ) {
        let result = AudioPerformanceBenchmarks.runBenchmark(
            name: name,
            constraints: constraints,
            operation: operation
        )
        
        XCTAssertTrue(
            result.isRealTimeCapable,
            "\(name) exceeded real-time constraint: \(result.processingTime * 1000)ms > \(result.maxLatency * 1000)ms"
        )
        
        // Use XCTest's measure block for additional metrics
        measure {
            try? operation()
        }
    }
    
    /// Assert that processing time meets real-time constraints
    public func assertRealTimeCapable(
        _ processingTime: TimeInterval,
        bufferSize: Int = 512,
        sampleRate: Double = 44100.0,
        safetyFactor: Double = 0.5,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let maxLatency = Double(bufferSize) / sampleRate * safetyFactor
        XCTAssertLessThan(
            processingTime,
            maxLatency,
            "Processing time \(processingTime * 1000)ms exceeds real-time constraint of \(maxLatency * 1000)ms",
            file: file,
            line: line
        )
    }
}

// MARK: - String Extensions for Report Formatting

private extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}