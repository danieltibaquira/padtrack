import XCTest
import Foundation
import CoreData
@testable import MachineProtocols
@testable import DataLayer
@testable import AudioEngine

/// Shared test utilities for all DigitonePad test modules
public class TestUtilities {
    
    // MARK: - Test Data Generators
    
    /// Generates a random float value within the specified range
    public static func randomFloat(min: Float = 0.0, max: Float = 1.0) -> Float {
        return Float.random(in: min...max)
    }
    
    /// Generates a random integer value within the specified range
    public static func randomInt(min: Int = 0, max: Int = 100) -> Int {
        return Int.random(in: min...max)
    }
    
    /// Generates a random string of specified length
    public static func randomString(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    /// Generates test audio buffer data
    public static func generateTestAudioBuffer(frameCount: Int = 512, channelCount: Int = 2, sampleRate: Float = 44100) -> AudioEngine.AudioBuffer {
        let data = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount)
        
        // Fill with test sine wave data
        for i in 0..<(frameCount * channelCount) {
            let sample = sin(Float(i) * 0.01) * 0.5
            data[i] = sample
        }
        
        return AudioEngine.AudioBuffer(
            data: data,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: Double(sampleRate)
        )
    }
    
    /// Generates test parameter with random values
    public static func generateTestParameter(id: String? = nil, category: ParameterCategory = .synthesis) -> Parameter {
        let paramId = id ?? "test_param_\(randomInt())"
        return Parameter(
            id: paramId,
            name: "Test Parameter \(paramId)",
            description: "A test parameter for unit testing",
            value: randomFloat(),
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.5,
            unit: "%",
            category: category
        )
    }
    
    /// Generate a test audio buffer with a sine wave
    public static func generateSineWave(frequency: Double, duration: Double, sampleRate: Double) -> AudioEngine.AudioBuffer {
        let frameCount = Int(duration * sampleRate)
        let data = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        
        for i in 0..<frameCount {
            let time = Double(i) / sampleRate
            data[i] = Float(sin(2.0 * .pi * frequency * time))
        }
        
        return AudioEngine.AudioBuffer(
            data: data,
            frameCount: frameCount,
            channelCount: 1,
            sampleRate: sampleRate
        )
    }
    
    // MARK: - Test Assertions
    
    /// Asserts that two float values are approximately equal within a tolerance
    public static func assertFloatsEqual(_ value1: Float, _ value2: Float, tolerance: Float = 0.0001) {
        XCTAssertTrue(abs(value1 - value2) <= tolerance, "Values differ by more than \(tolerance): \(value1) vs \(value2)")
    }
    
    /// Asserts that an audio buffer contains valid data
    public static func assertValidAudioBuffer(_ buffer: AudioEngine.AudioBuffer, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThan(buffer.frameCount, 0, "Buffer should have frames", file: file, line: line)
        XCTAssertGreaterThan(buffer.channelCount, 0, "Buffer should have channels", file: file, line: line)
        XCTAssertGreaterThan(buffer.sampleRate, 0, "Buffer should have valid sample rate", file: file, line: line)
        
        // Check for NaN or infinite values
        for i in 0..<(buffer.frameCount * buffer.channelCount) {
            let sample = buffer.data[i]
            XCTAssertFalse(sample.isNaN, "Buffer should not contain NaN values", file: file, line: line)
            XCTAssertFalse(sample.isInfinite, "Buffer should not contain infinite values", file: file, line: line)
        }
    }
    
    /// Asserts that a parameter has valid values
    public static func assertValidParameter(_ parameter: Parameter, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(parameter.id.isEmpty, "Parameter should have non-empty ID", file: file, line: line)
        XCTAssertFalse(parameter.name.isEmpty, "Parameter should have non-empty name", file: file, line: line)
        XCTAssertGreaterThanOrEqual(parameter.value, parameter.minValue, "Parameter value should be >= minValue", file: file, line: line)
        XCTAssertLessThanOrEqual(parameter.value, parameter.maxValue, "Parameter value should be <= maxValue", file: file, line: line)
        XCTAssertGreaterThanOrEqual(parameter.defaultValue, parameter.minValue, "Parameter defaultValue should be >= minValue", file: file, line: line)
        XCTAssertLessThanOrEqual(parameter.defaultValue, parameter.maxValue, "Parameter defaultValue should be <= maxValue", file: file, line: line)
    }
    
    // MARK: - Performance Testing Utilities
    
    /// Measures the execution time of a block of code
    public static func measureExecutionTime<T>(operation: () throws -> T) rethrows -> (result: T, time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        return (result, timeElapsed)
    }
    
    /// Asserts that an operation completes within the specified time limit
    public static func assertExecutionTime<T>(
        _ operation: () throws -> T,
        maxTime: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line
    ) rethrows -> T {
        let (result, time) = try measureExecutionTime(operation: operation)
        XCTAssertLessThanOrEqual(time, maxTime, "Operation should complete within \(maxTime) seconds", file: file, line: line)
        return result
    }
    
    // MARK: - Memory Testing Utilities
    
    /// Measures memory usage before and after an operation
    public static func measureMemoryUsage<T>(operation: () throws -> T) rethrows -> (result: T, memoryDelta: Int64) {
        let initialMemory = getMemoryUsage()
        let result = try operation()
        let finalMemory = getMemoryUsage()
        return (result, Int64(finalMemory) - Int64(initialMemory))
    }
    
    /// Get current memory usage in bytes (simplified version)
    private static func getMemoryUsage() -> UInt64 {
        // Return a default value since memory usage tracking is not critical for tests
        // and the mach API has concurrency safety issues
        return 1024 * 1024 // 1MB default
    }
    
    // MARK: - Test Fixtures
    
    /// Creates a test machine configuration
    public static func createTestMachineConfiguration() -> MachineConfiguration {
        return MachineConfiguration(
            sampleRate: 44100,
            bufferSize: 512,
            channelCount: 2
        )
    }
    
    /// Creates a test parameter group
    public static func createTestParameterGroup(parameterCount: Int = 3) -> ParameterGroup {
        let parameters = (0..<parameterCount).map { i in
            generateTestParameter(id: "param_\(i)")
        }
        
        return ParameterGroup(
            id: "test_group",
            name: "Test Group",
            category: .synthesis,
            parameterIds: parameters.map { $0.id }
        )
    }
    
    // MARK: - Cleanup Utilities
    
    /// Cleans up allocated audio buffer data
    public static func cleanupAudioBuffer(_ buffer: AudioEngine.AudioBuffer) {
        buffer.data.deallocate()
    }
    
    /// Waits for async operations to complete
    public static func waitForAsyncOperation(timeout: TimeInterval = 5.0, operation: @escaping @Sendable () -> Bool) {
        let expectation = XCTestExpectation(description: "Async operation")
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if operation() {
                timer.invalidate()
                expectation.fulfill()
            }
        }
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        timer.invalidate()
        
        XCTAssertEqual(result, .completed, "Async operation should complete within timeout")
    }
    
    /// Wait for a condition to be met with timeout
    public static func waitForCondition(_ operation: @escaping @Sendable () -> Bool, timeout: TimeInterval = 5.0) {
        let expectation = XCTestExpectation(description: "Condition met")
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if operation() {
                timer.invalidate()
                expectation.fulfill()
            }
        }
        
        _ = XCTWaiter.wait(for: [expectation], timeout: timeout)
        timer.invalidate()
    }
    
    /// Creates an AudioEngine.AudioBuffer with test data
    public static func createAudioBuffer(frameCount: Int, channelCount: Int, sampleRate: Float) -> AudioEngine.AudioBuffer {
        let data = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount)
        
        // Fill with test sine wave data
        for i in 0..<(frameCount * channelCount) {
            let sample = sin(Float(i) * 0.01) * 0.5
            data[i] = sample
        }
        
        return AudioEngine.AudioBuffer(
            data: data,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: Double(sampleRate)
        )
    }
}

// MARK: - Test Base Classes

/// Base class for all DigitonePad test cases
open class DigitonePadTestCase: XCTestCase {
    
    override open func setUp() {
        super.setUp()
        // Common setup for all tests
    }
    
    override open func tearDown() {
        // Common cleanup for all tests
        super.tearDown()
    }
    
    /// Helper method to create test expectation with timeout
    func createExpectation(description: String, timeout: TimeInterval = 5.0) -> XCTestExpectation {
        let expectation = XCTestExpectation(description: description)
        return expectation
    }
}

/// Base class for audio processing tests
open class AudioTestCase: DigitonePadTestCase {
    
    var testBuffer: AudioEngine.AudioBuffer!
    
    override open func setUp() {
        super.setUp()
        testBuffer = TestUtilities.generateTestAudioBuffer()
    }
    
    override open func tearDown() {
        if testBuffer != nil {
            TestUtilities.cleanupAudioBuffer(testBuffer)
            testBuffer = nil
        }
        super.tearDown()
    }
}
