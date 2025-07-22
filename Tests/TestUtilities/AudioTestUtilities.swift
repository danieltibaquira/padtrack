import Foundation
import XCTest
import MachineProtocols
@testable import AudioEngine

/// Reusable utilities for audio processing tests
public class AudioTestUtilities {
    
    // MARK: - AudioBuffer Creation Utilities
    
    /// Create a test AudioBuffer with specified parameters
    public static func createTestBuffer(
        frameCount: Int = 512,
        channelCount: Int = 2,
        sampleRate: Double = 44100.0
    ) -> AudioEngine.AudioBuffer {
        let data = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount)
        data.initialize(repeating: 0.0, count: frameCount * channelCount)
        
        return AudioEngine.AudioBuffer(
            data: data,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: sampleRate
        )
    }
    
    /// Create a sine wave test signal in an AudioBuffer
    public static func createSineWaveBuffer(
        frequency: Float = 440.0,
        amplitude: Float = 0.5,
        frameCount: Int = 512,
        channelCount: Int = 2,
        sampleRate: Double = 44100.0
    ) -> AudioEngine.AudioBuffer {
        let buffer = createTestBuffer(frameCount: frameCount, channelCount: channelCount, sampleRate: sampleRate)
        
        for frame in 0..<frameCount {
            let phase = Float(frame) * 2.0 * Float.pi * frequency / Float(sampleRate)
            let sample = sin(phase) * amplitude
            
            for channel in 0..<channelCount {
                buffer.data[frame * channelCount + channel] = sample
            }
        }
        
        return buffer
    }
    
    /// Create a noise test signal in an AudioBuffer
    public static func createNoiseBuffer(
        amplitude: Float = 0.1,
        frameCount: Int = 512,
        channelCount: Int = 2,
        sampleRate: Double = 44100.0
    ) -> AudioEngine.AudioBuffer {
        let buffer = createTestBuffer(frameCount: frameCount, channelCount: channelCount, sampleRate: sampleRate)
        
        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                let sample = Float.random(in: -amplitude...amplitude)
                buffer.data[frame * channelCount + channel] = sample
            }
        }
        
        return buffer
    }
    
    // MARK: - Audio Analysis Utilities
    
    /// Calculate RMS (Root Mean Square) of audio buffer
    public static func calculateRMS(_ buffer: AudioEngine.AudioBuffer) -> Float {
        var sum: Float = 0.0
        let totalSamples = buffer.frameCount * buffer.channelCount
        
        for i in 0..<totalSamples {
            let sample = buffer.data[i]
            sum += sample * sample
        }
        
        return sqrt(sum / Float(totalSamples))
    }
    
    /// Calculate peak amplitude in audio buffer
    public static func calculatePeak(_ buffer: AudioEngine.AudioBuffer) -> Float {
        var peak: Float = 0.0
        let totalSamples = buffer.frameCount * buffer.channelCount
        
        for i in 0..<totalSamples {
            peak = max(peak, abs(buffer.data[i]))
        }
        
        return peak
    }
    
    /// Check if audio buffer contains only silence (below threshold)
    public static func isSilent(_ buffer: AudioEngine.AudioBuffer, threshold: Float = 0.001) -> Bool {
        return calculatePeak(buffer) < threshold
    }
    
    /// Check if audio buffer contains valid audio (no NaN or infinite values)
    public static func isValidAudio(_ buffer: AudioEngine.AudioBuffer) -> Bool {
        let totalSamples = buffer.frameCount * buffer.channelCount
        
        for i in 0..<totalSamples {
            let sample = buffer.data[i]
            if sample.isNaN || sample.isInfinite {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Performance Measurement Utilities
    
    /// Measure audio processing performance
    public static func measureAudioProcessingTime<T>(
        iterations: Int = 1000,
        operation: () -> T
    ) -> (result: T?, averageTime: TimeInterval) {
        var result: T?
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            result = operation()
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        let averageTime = totalTime / Double(iterations)
        
        return (result: result, averageTime: averageTime)
    }
    
    /// Assert that processing time is within acceptable real-time constraints
    public static func assertRealTimePerformance(
        _ processingTime: TimeInterval,
        bufferSizeFrames: Int = 512,
        sampleRate: Double = 44100.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let bufferDuration = Double(bufferSizeFrames) / sampleRate
        let maxAcceptableTime = bufferDuration * 0.5  // 50% of buffer duration
        
        XCTAssertLessThan(
            processingTime,
            maxAcceptableTime,
            "Processing time \(processingTime)s exceeds real-time constraint of \(maxAcceptableTime)s",
            file: file,
            line: line
        )
    }
    
    // MARK: - Mock Audio Objects
    
    /// Mock AudioEngine for testing
    public class MockAudioEngine {
        public var isRunning = false
        public var sampleRate: Double = 44100.0
        public var bufferSize = 512
        public var parameterValues: [String: Float] = [:]
        
        public init() {}
        
        public func start() throws {
            isRunning = true
        }
        
        public func stop() {
            isRunning = false
        }
        
        public func setParameter(id: String, value: Float) throws {
            parameterValues[id] = value
        }
        
        public func getParameter(id: String) throws -> Float {
            return parameterValues[id] ?? 0.0
        }
    }
    
    // MARK: - Test Assertions
    
    /// Assert that two audio buffers are approximately equal
    public static func assertAudioBuffersEqual(
        _ buffer1: MachineProtocols.AudioBuffer,
        _ buffer2: MachineProtocols.AudioBuffer,
        accuracy: Float = 0.001,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(buffer1.frameCount, buffer2.frameCount, "Frame counts must match", file: file, line: line)
        XCTAssertEqual(buffer1.channelCount, buffer2.channelCount, "Channel counts must match", file: file, line: line)
        
        let totalSamples = buffer1.frameCount * buffer1.channelCount
        
        for i in 0..<totalSamples {
            XCTAssertEqual(
                buffer1.data[i],
                buffer2.data[i],
                accuracy: accuracy,
                "Sample \(i) differs: \(buffer1.data[i]) vs \(buffer2.data[i])",
                file: file,
                line: line
            )
        }
    }
    
    /// Assert that audio buffer has expected characteristics
    public static func assertAudioCharacteristics(
        _ buffer: AudioEngine.AudioBuffer,
        expectedRMS: Float? = nil,
        expectedPeak: Float? = nil,
        rmsAccuracy: Float = 0.01,
        peakAccuracy: Float = 0.01,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        // Always check for valid audio
        XCTAssertTrue(isValidAudio(buffer), "Audio buffer contains invalid samples (NaN or infinite)", file: file, line: line)
        
        if let expectedRMS = expectedRMS {
            let actualRMS = calculateRMS(buffer)
            XCTAssertEqual(actualRMS, expectedRMS, accuracy: rmsAccuracy, "RMS mismatch", file: file, line: line)
        }
        
        if let expectedPeak = expectedPeak {
            let actualPeak = calculatePeak(buffer)
            XCTAssertEqual(actualPeak, expectedPeak, accuracy: peakAccuracy, "Peak amplitude mismatch", file: file, line: line)
        }
    }
    
    // MARK: - Memory Management
    
    /// Safely deallocate an AudioBuffer's data
    public static func deallocateBuffer(_ buffer: AudioEngine.AudioBuffer) {
        buffer.data.deallocate()
    }
}

// MARK: - AudioBuffer Extensions for Testing

extension AudioEngine.AudioBuffer {
    /// Convenience property to check if buffer is valid
    public var isValid: Bool {
        return AudioTestUtilities.isValidAudio(self)
    }
    
    /// Convenience property to get RMS value
    public var rms: Float {
        return AudioTestUtilities.calculateRMS(self)
    }
    
    /// Convenience property to get peak amplitude
    public var peak: Float {
        return AudioTestUtilities.calculatePeak(self)
    }
    
    /// Convenience method to check if silent
    public func isSilent(threshold: Float = 0.001) -> Bool {
        return AudioTestUtilities.isSilent(self, threshold: threshold)
    }
}