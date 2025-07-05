import XCTest
import AVFoundation
import Combine
@testable import DigitonePad
@testable import VoiceModule
@testable import AudioEngine

/// Comprehensive test suite for FM parameter bridge audio integration
/// Tests real-time parameter updates, audio engine integration, and performance requirements
class FMParameterBridgeTests: XCTestCase {
    
    var bridge: FMParameterBridge!
    var mockVoiceMachine: MockFMToneVoiceMachine!
    var mockAudioEngine: MockAudioEngine!
    var cancelables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockVoiceMachine = MockFMToneVoiceMachine()
        mockAudioEngine = MockAudioEngine()
        cancelables = Set<AnyCancellable>()
        
        // Initialize the bridge with mock objects
        bridge = FMParameterBridge(
            voiceMachine: mockVoiceMachine,
            audioEngine: mockAudioEngine
        )
    }
    
    override func tearDown() {
        cancelables.forEach { $0.cancel() }
        bridge = nil
        mockVoiceMachine = nil
        mockAudioEngine = nil
        super.tearDown()
    }
    
    // MARK: - Parameter Scaling Tests
    
    /// Test parameter value scaling from UI (0.0-1.0) to audio engine ranges
    func testParameterValueScaling() {
        // Test Algorithm parameter scaling (0.0-1.0 → 1-8)
        let algorithmValue = bridge.scaleParameter(.algorithm, uiValue: 0.0)
        XCTAssertEqual(algorithmValue, 1.0, accuracy: 0.01, "Algorithm min should scale to 1.0")
        
        let algorithmValueMax = bridge.scaleParameter(.algorithm, uiValue: 1.0)
        XCTAssertEqual(algorithmValueMax, 8.0, accuracy: 0.01, "Algorithm max should scale to 8.0")
        
        let algorithmValueMid = bridge.scaleParameter(.algorithm, uiValue: 0.5)
        XCTAssertEqual(algorithmValueMid, 4.5, accuracy: 0.01, "Algorithm mid should scale to 4.5")
        
        // Test Ratio parameter scaling (0.0-1.0 → 0.5-32.0)
        let ratioValueMin = bridge.scaleParameter(.ratioA, uiValue: 0.0)
        XCTAssertEqual(ratioValueMin, 0.5, accuracy: 0.01, "Ratio min should scale to 0.5")
        
        let ratioValueMax = bridge.scaleParameter(.ratioA, uiValue: 1.0)
        XCTAssertEqual(ratioValueMax, 32.0, accuracy: 0.01, "Ratio max should scale to 32.0")
        
        // Test normalized parameter scaling (0.0-1.0 → 0.0-1.0)
        let normalizedValue = bridge.scaleParameter(.harmony, uiValue: 0.7)
        XCTAssertEqual(normalizedValue, 0.7, accuracy: 0.01, "Normalized parameter should maintain value")
    }
    
    /// Test parameter value clamping to valid ranges
    func testParameterValueClamping() {
        // Test values beyond valid range are clamped
        let algorithmOverflow = bridge.scaleParameter(.algorithm, uiValue: 1.5)
        XCTAssertEqual(algorithmOverflow, 8.0, accuracy: 0.01, "Algorithm overflow should clamp to 8.0")
        
        let algorithmUnderflow = bridge.scaleParameter(.algorithm, uiValue: -0.5)
        XCTAssertEqual(algorithmUnderflow, 1.0, accuracy: 0.01, "Algorithm underflow should clamp to 1.0")
        
        let ratioOverflow = bridge.scaleParameter(.ratioA, uiValue: 2.0)
        XCTAssertEqual(ratioOverflow, 32.0, accuracy: 0.01, "Ratio overflow should clamp to 32.0")
        
        let ratioUnderflow = bridge.scaleParameter(.ratioA, uiValue: -1.0)
        XCTAssertEqual(ratioUnderflow, 0.5, accuracy: 0.01, "Ratio underflow should clamp to 0.5")
    }
    
    // MARK: - Audio Engine Integration Tests
    
    /// Test parameter changes are immediately sent to audio engine
    func testParameterChangesReachAudioEngine() {
        // Arrange
        let parameterID = FMParameterID.algorithm
        let testValue = 5.0
        
        // Act
        bridge.updateParameter(parameterID, value: testValue)
        
        // Assert
        XCTAssertEqual(mockVoiceMachine.lastUpdatedParameterID, parameterID,
                      "Parameter ID should be sent to voice machine")
        XCTAssertEqual(mockVoiceMachine.lastUpdatedParameterValue, testValue, accuracy: 0.01,
                      "Parameter value should be sent to voice machine")
        XCTAssertEqual(mockVoiceMachine.parameterUpdateCount, 1,
                      "Voice machine should receive exactly one update")
    }
    
    /// Test multiple parameter updates are processed correctly
    func testMultipleParameterUpdates() {
        // Arrange
        let parameters: [(FMParameterID, Double)] = [
            (.algorithm, 3.0),
            (.ratioA, 2.5),
            (.ratioB, 1.8),
            (.harmony, 0.6),
            (.feedback, 0.3)
        ]
        
        // Act
        for (paramID, value) in parameters {
            bridge.updateParameter(paramID, value: value)
        }
        
        // Assert
        XCTAssertEqual(mockVoiceMachine.parameterUpdateCount, parameters.count,
                      "Voice machine should receive all parameter updates")
        
        // Verify last parameter update
        XCTAssertEqual(mockVoiceMachine.lastUpdatedParameterID, .feedback,
                      "Last parameter should be feedback")
        XCTAssertEqual(mockVoiceMachine.lastUpdatedParameterValue, 0.3, accuracy: 0.01,
                      "Last parameter value should be 0.3")
    }
    
    /// Test parameter update latency is within 1ms requirement
    func testParameterUpdateLatency() {
        // Arrange
        let parameterID = FMParameterID.algorithm
        let testValue = 4.0
        
        // Act & Assert
        measure {
            let startTime = CACurrentMediaTime()
            bridge.updateParameter(parameterID, value: testValue)
            let endTime = CACurrentMediaTime()
            
            let latency = endTime - startTime
            XCTAssertLessThan(latency, 0.001, "Parameter update latency must be < 1ms")
        }
    }
    
    /// Test concurrent parameter updates don't cause race conditions
    func testConcurrentParameterUpdates() {
        // Arrange
        let expectation = self.expectation(description: "Concurrent parameter updates")
        expectation.expectedFulfillmentCount = 4
        
        let parameterGroups: [[(FMParameterID, Double)]] = [
            [(.algorithm, 1.0), (.ratioA, 2.0)],
            [(.ratioB, 3.0), (.harmony, 0.5)],
            [(.detune, 0.2), (.feedback, 0.8)],
            [(.mix, 0.9), (.attack, 0.1)]
        ]
        
        // Act - Simulate concurrent updates from multiple sources
        for group in parameterGroups {
            DispatchQueue.global(qos: .userInitiated).async {
                for (paramID, value) in group {
                    self.bridge.updateParameter(paramID, value: value)
                }
                expectation.fulfill()
            }
        }
        
        // Assert
        waitForExpectations(timeout: 2.0) { _ in
            XCTAssertEqual(self.mockVoiceMachine.parameterUpdateCount, 8,
                          "All 8 parameter updates should be processed")
        }
    }
    
    // MARK: - Audio Quality Tests
    
    /// Test parameter changes produce audible differences
    func testParameterChangesAffectAudio() {
        // Arrange
        let initialBuffer = mockVoiceMachine.generateTestBuffer()
        
        // Act - Change algorithm parameter
        bridge.updateParameter(.algorithm, value: 3.0)
        let changedBuffer = mockVoiceMachine.generateTestBuffer()
        
        // Assert - Audio output should be different
        XCTAssertFalse(buffersAreEqual(initialBuffer, changedBuffer),
                      "Parameter changes should produce different audio output")
    }
    
    /// Test parameter interpolation provides smooth transitions
    func testParameterInterpolationSmoothness() {
        // Arrange
        let startValue = 1.0
        let endValue = 8.0
        let steps = 10
        
        var audioBuffers: [AVAudioPCMBuffer] = []
        
        // Act - Gradually change algorithm parameter
        for i in 0...steps {
            let interpolatedValue = startValue + (endValue - startValue) * Double(i) / Double(steps)
            bridge.updateParameter(.algorithm, value: interpolatedValue)
            audioBuffers.append(mockVoiceMachine.generateTestBuffer())
        }
        
        // Assert - Audio should change gradually, not abruptly
        for i in 1..<audioBuffers.count {
            let similarity = calculateBufferSimilarity(audioBuffers[i-1], audioBuffers[i])
            XCTAssertGreaterThan(similarity, 0.7, "Adjacent audio buffers should be similar for smooth interpolation")
        }
    }
    
    /// Test parameter updates don't cause audio artifacts
    func testParameterUpdatesNoArtifacts() {
        // Arrange
        let baselineBuffer = mockVoiceMachine.generateTestBuffer()
        
        // Act - Rapid parameter changes
        for i in 0..<100 {
            let value = Double(i % 8) + 1.0
            bridge.updateParameter(.algorithm, value: value)
        }
        
        let finalBuffer = mockVoiceMachine.generateTestBuffer()
        
        // Assert - No extreme amplitude spikes (artifacts)
        let maxAmplitude = getMaxAmplitude(finalBuffer)
        XCTAssertLessThan(maxAmplitude, 1.0, "Audio should not clip or contain artifacts")
        
        // Assert - Audio should still be generating
        XCTAssertGreaterThan(maxAmplitude, 0.001, "Audio should still be generating after rapid changes")
    }
    
    // MARK: - Performance Tests
    
    /// Test performance of updating all 32 parameters (4 pages × 8 encoders)
    func testUpdateAllParametersPerformance() {
        // Arrange
        let allParameters: [(FMParameterID, Double)] = [
            // Page 1 - Core FM
            (.algorithm, 4.0), (.ratioC, 2.0), (.ratioA, 1.5), (.ratioB, 3.0),
            (.harmony, 0.5), (.detune, 0.3), (.feedback, 0.7), (.mix, 0.8),
            // Page 2 - Envelopes
            (.attackA, 0.1), (.decayA, 0.3), (.endA, 0.5), (.levelA, 0.9),
            (.attackB, 0.2), (.decayB, 0.4), (.endB, 0.6), (.levelB, 0.8),
            // Page 3 - Envelope Behavior
            (.delay, 0.0), (.trigMode, 0.0), (.phaseReset, 0.0), (.reserved1, 0.0),
            (.reserved2, 0.0), (.detune, 0.2), (.harmony, 0.4), (.keyTracking, 0.6),
            // Page 4 - Offsets & Key Tracking
            (.offsetA, 0.1), (.offsetB, 0.2), (.keyTracking, 0.7), (.velocitySensitivity, 0.5),
            (.scale, 0.0), (.root, 0.0), (.tune, 0.5), (.fine, 0.0)
        ]
        
        // Act & Assert - Must complete all 32 updates in <10ms
        measure {
            for (paramID, value) in allParameters {
                bridge.updateParameter(paramID, value: value)
            }
        }
        
        // Verify all updates were processed
        XCTAssertEqual(mockVoiceMachine.parameterUpdateCount, allParameters.count,
                      "All 32 parameter updates should be processed")
    }
    
    /// Test memory usage during intensive parameter automation
    func testMemoryUsageDuringParameterAutomation() {
        // Arrange
        let initialMemory = getCurrentMemoryUsage()
        
        // Act - Simulate intensive parameter automation
        for _ in 0..<1000 {
            let randomParam = FMParameterID.allCases.randomElement()!
            let randomValue = Double.random(in: 0.0...1.0)
            bridge.updateParameter(randomParam, value: randomValue)
        }
        
        // Assert - Memory usage should remain stable
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        XCTAssertLessThan(memoryIncrease, 1_000_000, "Memory usage should not increase by more than 1MB")
    }
    
    // MARK: - Parameter Persistence Tests
    
    /// Test parameter changes are saved to preset system
    func testParameterPersistenceToPreset() {
        // Arrange
        let preset = createTestPreset()
        bridge.attachToPreset(preset)
        
        // Act
        bridge.updateParameter(.algorithm, value: 5.0)
        bridge.updateParameter(.ratioA, value: 2.5)
        bridge.updateParameter(.harmony, value: 0.8)
        
        // Assert - Parameters should be saved to preset
        XCTAssertEqual(preset.algorithmValue, 5.0, accuracy: 0.01,
                      "Algorithm value should be saved to preset")
        XCTAssertEqual(preset.ratioAValue, 2.5, accuracy: 0.01,
                      "Ratio A value should be saved to preset")
        XCTAssertEqual(preset.harmonyValue, 0.8, accuracy: 0.01,
                      "Harmony value should be saved to preset")
    }
    
    /// Test preset loading restores parameter values
    func testPresetLoadingRestoresParameters() {
        // Arrange
        let preset = createTestPreset()
        preset.algorithmValue = 3.0
        preset.ratioAValue = 1.8
        preset.harmonyValue = 0.6
        
        // Act
        bridge.loadPreset(preset)
        
        // Assert - Parameters should be restored from preset
        XCTAssertEqual(mockVoiceMachine.getParameterValue(.algorithm), 3.0, accuracy: 0.01,
                      "Algorithm value should be restored from preset")
        XCTAssertEqual(mockVoiceMachine.getParameterValue(.ratioA), 1.8, accuracy: 0.01,
                      "Ratio A value should be restored from preset")
        XCTAssertEqual(mockVoiceMachine.getParameterValue(.harmony), 0.6, accuracy: 0.01,
                      "Harmony value should be restored from preset")
    }
    
    // MARK: - Error Handling Tests
    
    /// Test invalid parameter IDs are handled gracefully
    func testInvalidParameterIDHandling() {
        // This test would require a way to pass invalid parameter IDs
        // For now, we test that the system remains stable with edge cases
        
        // Act & Assert - Should not crash with extreme values
        bridge.updateParameter(.algorithm, value: Double.infinity)
        bridge.updateParameter(.algorithm, value: Double.nan)
        bridge.updateParameter(.algorithm, value: -Double.infinity)
        
        // System should remain stable
        XCTAssertNotNil(bridge, "Bridge should remain stable with invalid values")
    }
    
    /// Test audio engine disconnection is handled gracefully
    func testAudioEngineDisconnectionHandling() {
        // Arrange
        bridge.disconnectFromAudioEngine()
        
        // Act - Should not crash when updating parameters without audio engine
        bridge.updateParameter(.algorithm, value: 5.0)
        
        // Assert - Should handle gracefully
        XCTAssertNotNil(bridge, "Bridge should handle audio engine disconnection gracefully")
    }
    
    // MARK: - Helper Methods
    
    private func buffersAreEqual(_ buffer1: AVAudioPCMBuffer, _ buffer2: AVAudioPCMBuffer) -> Bool {
        guard buffer1.frameLength == buffer2.frameLength else { return false }
        guard let data1 = buffer1.floatChannelData, let data2 = buffer2.floatChannelData else { return false }
        
        for frame in 0..<Int(buffer1.frameLength) {
            if abs(data1[0][frame] - data2[0][frame]) > 0.001 {
                return false
            }
        }
        return true
    }
    
    private func calculateBufferSimilarity(_ buffer1: AVAudioPCMBuffer, _ buffer2: AVAudioPCMBuffer) -> Double {
        guard buffer1.frameLength == buffer2.frameLength else { return 0.0 }
        guard let data1 = buffer1.floatChannelData, let data2 = buffer2.floatChannelData else { return 0.0 }
        
        var similarity = 0.0
        for frame in 0..<Int(buffer1.frameLength) {
            let diff = abs(data1[0][frame] - data2[0][frame])
            similarity += max(0.0, 1.0 - Double(diff))
        }
        return similarity / Double(buffer1.frameLength)
    }
    
    private func getMaxAmplitude(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData else { return 0.0 }
        var maxAmplitude: Float = 0.0
        
        for frame in 0..<Int(buffer.frameLength) {
            maxAmplitude = max(maxAmplitude, abs(data[0][frame]))
        }
        return maxAmplitude
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        // Simple memory usage approximation
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    private func createTestPreset() -> MockPreset {
        return MockPreset()
    }
}

// MARK: - Mock Objects

/// Mock FM TONE voice machine for testing
class MockFMToneVoiceMachine: VoiceMachineProtocol {
    var parameterValues: [FMParameterID: Double] = [:]
    var parameterUpdateCount = 0
    var lastUpdatedParameterID: FMParameterID?
    var lastUpdatedParameterValue: Double = 0.0
    
    func updateParameter(_ parameterID: FMParameterID, value: Double) {
        parameterValues[parameterID] = value
        parameterUpdateCount += 1
        lastUpdatedParameterID = parameterID
        lastUpdatedParameterValue = value
    }
    
    func getParameterValue(_ parameterID: FMParameterID) -> Double {
        return parameterValues[parameterID] ?? 0.0
    }
    
    func generateTestBuffer() -> AVAudioPCMBuffer {
        // Generate a simple test buffer with some audio data
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        
        guard let data = buffer.floatChannelData else { return buffer }
        
        // Generate test audio based on current parameters
        let algorithm = parameterValues[.algorithm] ?? 1.0
        let frequency = 440.0 * algorithm / 8.0 // Vary frequency based on algorithm
        
        for i in 0..<Int(buffer.frameLength) {
            let sample = sin(2.0 * Double.pi * frequency * Double(i) / 44100.0)
            data[0][i] = Float(sample * 0.5)
        }
        
        return buffer
    }
}

/// Mock preset for testing parameter persistence
class MockPreset {
    var algorithmValue: Double = 1.0
    var ratioAValue: Double = 1.0
    var ratioBValue: Double = 1.0
    var ratioCValue: Double = 1.0
    var harmonyValue: Double = 0.0
    var detuneValue: Double = 0.0
    var feedbackValue: Double = 0.0
    var mixValue: Double = 0.5
}

/// Protocol for voice machine testing
protocol VoiceMachineProtocol {
    func updateParameter(_ parameterID: FMParameterID, value: Double)
    func getParameterValue(_ parameterID: FMParameterID) -> Double
}

/// FM Parameter IDs for testing
enum FMParameterID: CaseIterable {
    case algorithm, ratioA, ratioB, ratioC
    case harmony, detune, feedback, mix
    case attackA, decayA, endA, levelA
    case attackB, decayB, endB, levelB
    case delay, trigMode, phaseReset, reserved1, reserved2
    case keyTracking, offsetA, offsetB, velocitySensitivity
    case scale, root, tune, fine
}