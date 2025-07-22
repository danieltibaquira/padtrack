import Foundation
import XCTest
import MachineProtocols
import AudioEngine

/// Helpers to resolve AudioBuffer type ambiguity and provide test-specific utilities
public struct AudioBufferTestHelpers {
    
    // MARK: - Type Aliases for Clarity
    
    /// Concrete AudioBuffer implementation from AudioEngine module
    public typealias ConcreteAudioBuffer = AudioEngine.AudioBuffer
    
    /// Protocol-based AudioBuffer from MachineProtocols (for interface compatibility)
    // Note: Protocol can't be instantiated, use ConcreteAudioBuffer instead
    
    // MARK: - Factory Methods
    
    /// Create a concrete AudioBuffer for direct audio processing tests
    public static func createConcreteBuffer(
        frameCount: Int = 512,
        channelCount: Int = 2,
        sampleRate: Double = 44100.0,
        fillWithSilence: Bool = true
    ) -> ConcreteAudioBuffer {
        let data = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount)
        
        if fillWithSilence {
            data.initialize(repeating: 0.0, count: frameCount * channelCount)
        }
        
        return ConcreteAudioBuffer(
            data: data,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: sampleRate
        )
    }
    
    /// Create an AudioBuffer that conforms to the protocol for interface testing
    /// Note: Returns ConcreteAudioBuffer which conforms to AudioBufferProtocol
    public static func createProtocolBuffer(
        frameCount: Int = 512,
        channelCount: Int = 2,
        sampleRate: Double = 44100.0,
        fillWithSilence: Bool = true
    ) -> ConcreteAudioBuffer {
        return createConcreteBuffer(
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: sampleRate,
            fillWithSilence: fillWithSilence
        )
    }
    
    // MARK: - Conversion Utilities
    
    /// Convert AudioBuffer to protocol type (actually just returns the same buffer since ConcreteAudioBuffer conforms to the protocol)
    public static func asProtocol(_ buffer: ConcreteAudioBuffer) -> any MachineProtocols.AudioBufferProtocol {
        return buffer
    }
    
    /// Get concrete buffer from protocol type (casting)
    public static func asConcrete(_ buffer: any MachineProtocols.AudioBufferProtocol) -> ConcreteAudioBuffer? {
        return buffer as? ConcreteAudioBuffer
    }
    
    // MARK: - Test Pattern Generators
    
    /// Generate common test patterns for audio testing
    public enum TestPattern {
        case silence
        case sineWave(frequency: Float, amplitude: Float)
        case squareWave(frequency: Float, amplitude: Float)
        case sawtoothWave(frequency: Float, amplitude: Float)
        case whiteNoise(amplitude: Float)
        case impulse(position: Int, amplitude: Float)
        case ramp(startAmplitude: Float, endAmplitude: Float)
    }
    
    /// Fill a buffer with a test pattern
    public static func fillBuffer(
        _ buffer: UnsafeMutablePointer<Float>,
        frameCount: Int,
        channelCount: Int,
        sampleRate: Double,
        pattern: TestPattern
    ) {
        switch pattern {
        case .silence:
            for i in 0..<(frameCount * channelCount) {
                buffer[i] = 0.0
            }
            
        case .sineWave(let frequency, let amplitude):
            for frame in 0..<frameCount {
                let phase = Float(frame) * 2.0 * Float.pi * frequency / Float(sampleRate)
                let sample = sin(phase) * amplitude
                for channel in 0..<channelCount {
                    buffer[frame * channelCount + channel] = sample
                }
            }
            
        case .squareWave(let frequency, let amplitude):
            for frame in 0..<frameCount {
                let phase = Float(frame) * frequency / Float(sampleRate)
                let sample = (phase.truncatingRemainder(dividingBy: 1.0) < 0.5) ? amplitude : -amplitude
                for channel in 0..<channelCount {
                    buffer[frame * channelCount + channel] = sample
                }
            }
            
        case .sawtoothWave(let frequency, let amplitude):
            for frame in 0..<frameCount {
                let phase = Float(frame) * frequency / Float(sampleRate)
                let sample = (2.0 * (phase.truncatingRemainder(dividingBy: 1.0)) - 1.0) * amplitude
                for channel in 0..<channelCount {
                    buffer[frame * channelCount + channel] = sample
                }
            }
            
        case .whiteNoise(let amplitude):
            for i in 0..<(frameCount * channelCount) {
                buffer[i] = Float.random(in: -amplitude...amplitude)
            }
            
        case .impulse(let position, let amplitude):
            // Fill with silence first
            for i in 0..<(frameCount * channelCount) {
                buffer[i] = 0.0
            }
            // Add impulse at specified position
            if position < frameCount {
                for channel in 0..<channelCount {
                    buffer[position * channelCount + channel] = amplitude
                }
            }
            
        case .ramp(let startAmplitude, let endAmplitude):
            for frame in 0..<frameCount {
                let progress = Float(frame) / Float(frameCount - 1)
                let sample = startAmplitude + (endAmplitude - startAmplitude) * progress
                for channel in 0..<channelCount {
                    buffer[frame * channelCount + channel] = sample
                }
            }
        }
    }
    
    /// Create a buffer with a specific test pattern
    public static func createBufferWithPattern(
        _ pattern: TestPattern,
        frameCount: Int = 512,
        channelCount: Int = 2,
        sampleRate: Double = 44100.0
    ) -> ConcreteAudioBuffer {
        let data = UnsafeMutablePointer<Float>.allocate(capacity: frameCount * channelCount)
        fillBuffer(data, frameCount: frameCount, channelCount: channelCount, sampleRate: sampleRate, pattern: pattern)
        
        return ConcreteAudioBuffer(
            data: data,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: sampleRate
        )
    }
    
    // MARK: - DSP Utilities for Testing
    
    /// Calculate FFT magnitude spectrum for frequency domain analysis
    public static func calculateMagnitudeSpectrum(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int) -> [Float] {
        // Simple magnitude calculation - would use vDSP for full implementation
        var magnitudes: [Float] = []
        
        // For testing purposes, return a simplified spectrum
        let spectrumSize = frameCount / 2
        magnitudes.reserveCapacity(spectrumSize)
        
        for i in 0..<spectrumSize {
            let real = buffer[i * 2]
            let imag = buffer[i * 2 + 1]
            let magnitude = sqrt(real * real + imag * imag)
            magnitudes.append(magnitude)
        }
        
        return magnitudes
    }
    
    /// Detect if buffer contains a specific frequency component
    public static func containsFrequency(
        _ buffer: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Double,
        targetFrequency: Float,
        tolerance: Float = 50.0,
        threshold: Float = 0.1
    ) -> Bool {
        // Simple frequency detection for testing
        // In a real implementation, this would use FFT
        
        let samplesPerCycle = Int(Double(sampleRate) / Double(targetFrequency))
        var correlationSum: Float = 0.0
        let testSamples = min(frameCount, samplesPerCycle * 4) // Test a few cycles
        
        for i in 0..<testSamples {
            let expectedPhase = Float(i) * 2.0 * Float.pi * targetFrequency / Float(sampleRate)
            let expectedSample = sin(expectedPhase)
            correlationSum += buffer[i] * expectedSample
        }
        
        let normalizedCorrelation = abs(correlationSum) / Float(testSamples)
        return normalizedCorrelation > threshold
    }
    
    // MARK: - Memory Safety
    
    /// Safely create and manage temporary buffers for testing
    public static func withTemporaryBuffer<T>(
        frameCount: Int = 512,
        channelCount: Int = 2,
        sampleRate: Double = 44100.0,
        operation: (UnsafeMutablePointer<Float>, Int, Int, Double) throws -> T
    ) rethrows -> T {
        let totalSamples = frameCount * channelCount
        let data = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)
        data.initialize(repeating: 0.0, count: totalSamples)
        
        defer {
            data.deinitialize(count: totalSamples)
            data.deallocate()
        }
        
        return try operation(data, frameCount, channelCount, sampleRate)
    }
}

// MARK: - XCTest Integration

extension XCTestCase {
    /// Convenience method to create test buffers in test cases
    public func createTestAudioBuffer(
        pattern: AudioBufferTestHelpers.TestPattern = .silence,
        frameCount: Int = 512,
        channelCount: Int = 2,
        sampleRate: Double = 44100.0
    ) -> AudioBufferTestHelpers.ConcreteAudioBuffer {
        return AudioBufferTestHelpers.createBufferWithPattern(
            pattern,
            frameCount: frameCount,
            channelCount: channelCount,
            sampleRate: sampleRate
        )
    }
    
    /// Assert that buffer matches expected frequency content
    public func assertContainsFrequency(
        _ buffer: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Double = 44100.0,
        frequency: Float,
        tolerance: Float = 50.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let containsFreq = AudioBufferTestHelpers.containsFrequency(
            buffer,
            frameCount: frameCount,
            sampleRate: sampleRate,
            targetFrequency: frequency,
            tolerance: tolerance
        )
        
        XCTAssertTrue(
            containsFreq,
            "Buffer should contain frequency component at \(frequency) Hz",
            file: file,
            line: line
        )
    }
}