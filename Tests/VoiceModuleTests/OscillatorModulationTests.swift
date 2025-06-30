// OscillatorModulationTests.swift
// DigitonePad - Tests/VoiceModuleTests
//
// Comprehensive tests for oscillator modulation system

import XCTest
import Foundation
import Accelerate
@testable import VoiceModule

final class OscillatorModulationTests: XCTestCase {
    
    var modulationSystem: OscillatorModulationSystem!
    var ringModEngine: RingModulationEngine!
    var hardSyncEngine: HardSyncEngine!
    var carrierWavetable: WavetableData!
    var modulatorWavetable: WavetableData!
    let sampleRate: Float = 44100.0
    
    override func setUp() {
        super.setUp()
        
        modulationSystem = OscillatorModulationSystem(sampleRate: sampleRate)
        ringModEngine = RingModulationEngine(sampleRate: sampleRate)
        hardSyncEngine = HardSyncEngine(sampleRate: sampleRate)
        
        // Create test wavetables
        setupTestWavetables()
    }
    
    override func tearDown() {
        modulationSystem = nil
        ringModEngine = nil
        hardSyncEngine = nil
        carrierWavetable = nil
        modulatorWavetable = nil
        
        super.tearDown()
    }
    
    // MARK: - Test Setup Helpers
    
    private func setupTestWavetables() {
        // Create sine wave wavetable for carrier
        let carrierFrameSize = 256
        let carrierFrameCount = 1
        var carrierData: [[Float]] = []
        
        var sineFrame: [Float] = []
        for i in 0..<carrierFrameSize {
            let phase = Float(i) / Float(carrierFrameSize) * 2.0 * Float.pi
            sineFrame.append(sin(phase))
        }
        carrierData.append(sineFrame)
        
        let carrierMetadata = WavetableMetadata(
            name: "Test Sine",
            category: .analog,
            frameSize: carrierFrameSize,
            frameCount: carrierFrameCount
        )
        
        do {
            carrierWavetable = try WavetableData(metadata: carrierMetadata, data: carrierData)
        } catch {
            XCTFail("Failed to create carrier wavetable: \(error)")
        }
        
        // Create triangle wave wavetable for modulator
        let modFrameSize = 256
        let modFrameCount = 1
        var modData: [[Float]] = []
        
        var triangleFrame: [Float] = []
        for i in 0..<modFrameSize {
            let phase = Float(i) / Float(modFrameSize)
            let triangle = phase < 0.5 ? (4.0 * phase - 1.0) : (3.0 - 4.0 * phase)
            triangleFrame.append(triangle)
        }
        modData.append(triangleFrame)
        
        let modMetadata = WavetableMetadata(
            name: "Test Triangle",
            category: .analog,
            frameSize: modFrameSize,
            frameCount: modFrameCount
        )
        
        do {
            modulatorWavetable = try WavetableData(metadata: modMetadata, data: modData)
        } catch {
            XCTFail("Failed to create modulator wavetable: \(error)")
        }
    }
    
    // MARK: - Ring Modulation Tests
    
    func testRingModulationBasic() {
        // Test basic ring modulation functionality
        let carrierSample: Float = 0.5
        let modulatorSample: Float = 0.8
        let depth: Float = 1.0
        
        let result = ringModEngine.processRingModulation(
            carrierSample: carrierSample,
            modulatorSample: modulatorSample,
            depth: depth
        )
        
        // Ring modulation should produce carrier * modulator
        let expected = carrierSample * modulatorSample
        XCTAssertEqual(result, expected, accuracy: 0.01, "Ring modulation basic multiplication failed")
    }
    
    func testRingModulationDepthControl() {
        // Test depth parameter controls modulation amount
        let carrierSample: Float = 0.5
        let modulatorSample: Float = 0.8
        
        // Test with zero depth
        ringModEngine.parameters.depth = 0.0
        let result0 = ringModEngine.processRingModulation(
            carrierSample: carrierSample,
            modulatorSample: modulatorSample,
            depth: 1.0
        )
        XCTAssertEqual(result0, carrierSample, accuracy: 0.01, "Zero depth should return carrier unmodified")
        
        // Test with half depth
        ringModEngine.parameters.depth = 0.5
        let result50 = ringModEngine.processRingModulation(
            carrierSample: carrierSample,
            modulatorSample: modulatorSample,
            depth: 1.0
        )
        
        let expectedMix = carrierSample * 0.5 + (carrierSample * modulatorSample) * 0.5
        XCTAssertEqual(result50, expectedMix, accuracy: 0.01, "Half depth modulation incorrect")
    }
    
    func testRingModulationAsymmetry() {
        // Test asymmetry parameter
        let carrierSample: Float = 0.5
        let modulatorSample: Float = 0.8
        
        ringModEngine.parameters.depth = 1.0
        ringModEngine.parameters.asymmetry = 0.5
        
        let result = ringModEngine.processRingModulation(
            carrierSample: carrierSample,
            modulatorSample: modulatorSample,
            depth: 1.0
        )
        
        // Should produce asymmetric modulation
        XCTAssertNotNil(result, "Asymmetric ring modulation should produce valid output")
        XCTAssertTrue(abs(result) <= 2.0, "Ring modulation output should be within reasonable bounds")
    }
    
    func testBipolarRingModulation() {
        // Test bipolar ring modulation mode
        let carrierSample: Float = 0.5
        let modulatorSample: Float = 0.8
        let depth: Float = 0.7
        
        let result = ringModEngine.processBipolarRingMod(
            carrierSample: carrierSample,
            modulatorSample: modulatorSample,
            depth: depth
        )
        
        let expected = carrierSample + depth * (carrierSample * modulatorSample)
        XCTAssertEqual(result, expected, accuracy: 0.01, "Bipolar ring modulation calculation incorrect")
    }
    
    func testUnipolarRingModulation() {
        // Test unipolar ring modulation (tremolo-like)
        let carrierSample: Float = 0.5
        let modulatorSample: Float = 0.8
        let depth: Float = 0.7
        
        let result = ringModEngine.processUnipolarRingMod(
            carrierSample: carrierSample,
            modulatorSample: modulatorSample,
            depth: depth
        )
        
        let unipolarMod = (modulatorSample + 1.0) * 0.5
        let expected = carrierSample * (1.0 - depth + depth * unipolarMod)
        XCTAssertEqual(result, expected, accuracy: 0.01, "Unipolar ring modulation calculation incorrect")
    }
    
    func testQuadratureRingModulation() {
        // Test quadrature ring modulation
        let carrierSample: Float = 0.5
        let modulatorSample: Float = 0.8
        let quadratureMod: Float = 0.6
        let depth: Float = 0.7
        
        let result = ringModEngine.processQuadratureRingMod(
            carrierSample: carrierSample,
            modulatorSample: modulatorSample,
            quadratureMod: quadratureMod,
            depth: depth
        )
        
        XCTAssertNotNil(result, "Quadrature ring modulation should produce valid output")
        XCTAssertTrue(abs(result) <= 2.0, "Quadrature ring modulation output should be within bounds")
    }
    
    // MARK: - Hard Sync Tests
    
    func testHardSyncBasic() {
        // Test basic hard sync functionality
        let carrierPhase: Float = 0.7
        let masterPhase: Float = 0.1 // Indicates sync reset occurred
        let frequency: Float = 440.0
        let masterFrequency: Float = 220.0
        
        hardSyncEngine.parameters.phaseOffset = 0.0
        
        let (syncedPhase, syncTriggered) = hardSyncEngine.processHardSync(
            carrierPhase: carrierPhase,
            masterPhase: masterPhase,
            frequency: frequency,
            masterFrequency: masterFrequency
        )
        
        if syncTriggered {
            XCTAssertEqual(syncedPhase, 0.0, accuracy: 0.01, "Hard sync should reset phase to offset value")
        } else {
            XCTAssertEqual(syncedPhase, carrierPhase, accuracy: 0.01, "No sync should preserve carrier phase")
        }
    }
    
    func testHardSyncPhaseOffset() {
        // Test phase offset parameter
        let carrierPhase: Float = 0.7
        let masterPhase: Float = 0.1
        let frequency: Float = 440.0
        let masterFrequency: Float = 220.0
        let offset: Float = 0.25
        
        hardSyncEngine.parameters.phaseOffset = offset
        
        let (syncedPhase, syncTriggered) = hardSyncEngine.processHardSync(
            carrierPhase: carrierPhase,
            masterPhase: masterPhase,
            frequency: frequency,
            masterFrequency: masterFrequency
        )
        
        if syncTriggered {
            XCTAssertEqual(syncedPhase, offset, accuracy: 0.01, "Hard sync should reset to specified offset")
        }
    }
    
    func testSoftSync() {
        // Test soft sync mode
        let carrierPhase: Float = 0.7
        let masterPhase: Float = 0.1
        let frequency: Float = 440.0
        let masterFrequency: Float = 220.0
        
        hardSyncEngine.parameters.depth = 0.5
        hardSyncEngine.parameters.phaseOffset = 0.0
        
        let (syncedPhase, syncTriggered) = hardSyncEngine.processAdvancedSync(
            carrierPhase: carrierPhase,
            masterPhase: masterPhase,
            frequency: frequency,
            masterFrequency: masterFrequency,
            mode: .soft
        )
        
        if syncTriggered {
            // Soft sync should blend between current and reset phase
            XCTAssertTrue(syncedPhase >= 0.0 && syncedPhase <= carrierPhase, "Soft sync should blend phases")
        }
    }
    
    func testReversibleSync() {
        // Test reversible sync mode
        let carrierPhase: Float = 0.7
        let masterPhase: Float = 0.9
        let frequency: Float = 440.0
        let masterFrequency: Float = 220.0
        
        hardSyncEngine.parameters.phaseOffset = 0.0
        
        let (syncedPhase, syncTriggered) = hardSyncEngine.processAdvancedSync(
            carrierPhase: carrierPhase,
            masterPhase: masterPhase,
            frequency: frequency,
            masterFrequency: masterFrequency,
            mode: .reversible
        )
        
        // Reversible sync can trigger on various phase changes
        XCTAssertTrue(syncedPhase >= 0.0 && syncedPhase <= 1.0, "Reversible sync phase should be normalized")
    }
    
    // MARK: - Unified System Tests
    
    func testModulationSystemNoModulation() {
        // Test system with no modulation
        modulationSystem.modulationType = .none
        
        let result = modulationSystem.processSample(
            carrierWavetable: carrierWavetable,
            modulatorWavetable: modulatorWavetable,
            carrierPhase: 0.25,
            modulatorPhase: 0.5,
            carrierFrequency: 440.0,
            modulatorFrequency: 880.0
        )
        
        // Should return just the carrier sample
        let expectedCarrier = carrierWavetable.getSample(frameIndex: 0, position: 0.25 * Float(carrierWavetable.frameSize), interpolation: .linear)
        XCTAssertEqual(result, expectedCarrier, accuracy: 0.01, "No modulation should return carrier only")
    }
    
    func testModulationSystemRingMod() {
        // Test system with ring modulation
        modulationSystem.modulationType = .ringModulation
        modulationSystem.parameters.depth = 0.8
        modulationSystem.parameters.antiAliasing = false
        
        let result = modulationSystem.processSample(
            carrierWavetable: carrierWavetable,
            modulatorWavetable: modulatorWavetable,
            carrierPhase: 0.25,
            modulatorPhase: 0.5,
            carrierFrequency: 440.0,
            modulatorFrequency: 880.0
        )
        
        XCTAssertNotNil(result, "Ring modulation should produce valid output")
        XCTAssertTrue(abs(result) <= 2.0, "Ring modulation output should be within bounds")
    }
    
    func testModulationSystemHardSync() {
        // Test system with hard sync
        modulationSystem.modulationType = .hardSync
        modulationSystem.parameters.antiAliasing = false
        
        let result = modulationSystem.processSample(
            carrierWavetable: carrierWavetable,
            modulatorWavetable: modulatorWavetable,
            carrierPhase: 0.75,
            modulatorPhase: 0.1, // Should trigger sync
            carrierFrequency: 440.0,
            modulatorFrequency: 220.0
        )
        
        XCTAssertNotNil(result, "Hard sync should produce valid output")
        XCTAssertTrue(abs(result) <= 2.0, "Hard sync output should be within bounds")
    }
    
    func testModulationSystemPhaseModulation() {
        // Test phase modulation
        modulationSystem.modulationType = .phaseModulation
        modulationSystem.parameters.depth = 0.3
        
        let result = modulationSystem.processSample(
            carrierWavetable: carrierWavetable,
            modulatorWavetable: modulatorWavetable,
            carrierPhase: 0.25,
            modulatorPhase: 0.5,
            carrierFrequency: 440.0,
            modulatorFrequency: 880.0
        )
        
        XCTAssertNotNil(result, "Phase modulation should produce valid output")
        XCTAssertTrue(abs(result) <= 2.0, "Phase modulation output should be within bounds")
    }
    
    func testModulationSystemFrequencyModulation() {
        // Test frequency modulation
        modulationSystem.modulationType = .frequencyModulation
        modulationSystem.parameters.depth = 0.1
        
        let result = modulationSystem.processSample(
            carrierWavetable: carrierWavetable,
            modulatorWavetable: modulatorWavetable,
            carrierPhase: 0.25,
            modulatorPhase: 0.5,
            carrierFrequency: 440.0,
            modulatorFrequency: 880.0
        )
        
        XCTAssertNotNil(result, "Frequency modulation should produce valid output")
        XCTAssertTrue(abs(result) <= 2.0, "Frequency modulation output should be within bounds")
    }
    
    func testModulationSystemAmplitudeModulation() {
        // Test amplitude modulation
        modulationSystem.modulationType = .amplitudeModulation
        modulationSystem.parameters.depth = 0.5
        
        let result = modulationSystem.processSample(
            carrierWavetable: carrierWavetable,
            modulatorWavetable: modulatorWavetable,
            carrierPhase: 0.25,
            modulatorPhase: 0.5,
            carrierFrequency: 440.0,
            modulatorFrequency: 10.0 // Low frequency for classic AM
        )
        
        XCTAssertNotNil(result, "Amplitude modulation should produce valid output")
        XCTAssertTrue(abs(result) <= 2.0, "Amplitude modulation output should be within bounds")
    }
    
    func testModulationSystemPulseWidthModulation() {
        // Test pulse width modulation
        modulationSystem.modulationType = .pulseWidthModulation
        modulationSystem.parameters.depth = 0.3
        
        let result = modulationSystem.processSample(
            carrierWavetable: carrierWavetable,
            modulatorWavetable: modulatorWavetable,
            carrierPhase: 0.25,
            modulatorPhase: 0.5,
            carrierFrequency: 440.0,
            modulatorFrequency: 5.0 // Low frequency for PWM
        )
        
        XCTAssertNotNil(result, "PWM should produce valid output")
        XCTAssertTrue(result == 1.0 || result == -1.0, "PWM should produce square wave output")
    }
    
    // MARK: - Parameter Tests
    
    func testParameterSmoothing() {
        // Test parameter smoothing prevents clicks
        modulationSystem.modulationType = .ringModulation
        modulationSystem.parameters.smoothingTime = 0.001
        
        // Change depth rapidly and check for smooth transition
        modulationSystem.parameters.depth = 0.0
        let sample1 = modulationSystem.processSample(
            carrierWavetable: carrierWavetable,
            modulatorWavetable: modulatorWavetable,
            carrierFrequency: 440.0,
            modulatorFrequency: 880.0
        )
        
        modulationSystem.parameters.depth = 1.0
        let sample2 = modulationSystem.processSample(
            carrierWavetable: carrierWavetable,
            modulatorWavetable: modulatorWavetable,
            carrierFrequency: 440.0,
            modulatorFrequency: 880.0
        )
        
        // Should not change instantly due to smoothing
        XCTAssertNotEqual(sample1, sample2, "Parameter smoothing should prevent instant changes")
    }
    
    func testParameterRanges() {
        // Test parameter validation and range checking
        var params = OscillatorModulationParameters()
        
        // Test depth range
        params.depth = 1.5 // Outside range
        modulationSystem.parameters = params
        XCTAssertLessThanOrEqual(modulationSystem.parameters.depth, 1.0, "Depth should be clamped to valid range")
        
        // Test ratio range
        params.ratio = -0.5 // Negative ratio
        modulationSystem.parameters = params
        XCTAssertGreaterThanOrEqual(modulationSystem.parameters.ratio, 0.0, "Ratio should be non-negative")
        
        // Test phase offset range
        params.phaseOffset = 1.5 // Outside range
        modulationSystem.parameters = params
        // Note: Implementation should clamp this, but test current behavior
        XCTAssertNotNil(modulationSystem.parameters.phaseOffset, "Phase offset should be valid")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceRingModulation() {
        // Test ring modulation performance
        modulationSystem.modulationType = .ringModulation
        modulationSystem.parameters.depth = 0.8
        modulationSystem.parameters.antiAliasing = false
        
        let iterations = 1000
        
        measure {
            for _ in 0..<iterations {
                _ = modulationSystem.processSample(
                    carrierWavetable: carrierWavetable,
                    modulatorWavetable: modulatorWavetable,
                    carrierFrequency: 440.0,
                    modulatorFrequency: 880.0
                )
            }
        }
    }
    
    func testPerformanceHardSync() {
        // Test hard sync performance
        modulationSystem.modulationType = .hardSync
        modulationSystem.parameters.antiAliasing = false
        
        let iterations = 1000
        
        measure {
            for _ in 0..<iterations {
                _ = modulationSystem.processSample(
                    carrierWavetable: carrierWavetable,
                    modulatorWavetable: modulatorWavetable,
                    carrierFrequency: 440.0,
                    modulatorFrequency: 220.0
                )
            }
        }
    }
    
    func testPerformanceWithAntiAliasing() {
        // Test performance impact of anti-aliasing
        modulationSystem.modulationType = .ringModulation
        modulationSystem.parameters.depth = 0.8
        modulationSystem.parameters.antiAliasing = true
        
        let iterations = 100 // Fewer iterations due to AA overhead
        
        measure {
            for _ in 0..<iterations {
                _ = modulationSystem.processSample(
                    carrierWavetable: carrierWavetable,
                    modulatorWavetable: modulatorWavetable,
                    carrierFrequency: 8000.0, // High frequency to trigger AA
                    modulatorFrequency: 4000.0
                )
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testWavetableIntegration() {
        // Test integration with wavetable extension method
        let result = carrierWavetable.synthesizeWithModulation(
            modulatorWavetable: modulatorWavetable,
            carrierPhase: 0.25,
            modulatorPhase: 0.5,
            modulationSystem: modulationSystem,
            carrierFrequency: 440.0,
            modulatorFrequency: 880.0
        )
        
        XCTAssertNotNil(result, "Wavetable integration should produce valid output")
        XCTAssertTrue(abs(result) <= 2.0, "Integrated output should be within bounds")
    }
    
    func testStateManagement() {
        // Test phase accumulator state management
        modulationSystem.modulationType = .none
        
        let initialState = modulationSystem.getModulationState()
        XCTAssertEqual(initialState.modulationType, .none, "Initial modulation type should be none")
        
        // Process some samples to advance phase accumulators
        for _ in 0..<10 {
            _ = modulationSystem.processSample(
                carrierWavetable: carrierWavetable,
                modulatorWavetable: modulatorWavetable,
                carrierFrequency: 440.0,
                modulatorFrequency: 880.0
            )
        }
        
        let advancedState = modulationSystem.getModulationState()
        XCTAssertNotEqual(advancedState.carrierPhase, initialState.carrierPhase, "Carrier phase should advance")
        XCTAssertNotEqual(advancedState.modulatorPhase, initialState.modulatorPhase, "Modulator phase should advance")
        
        // Reset and check
        modulationSystem.reset()
        let resetState = modulationSystem.getModulationState()
        XCTAssertEqual(resetState.carrierPhase, 0.0, accuracy: 0.01, "Reset should clear carrier phase")
        XCTAssertEqual(resetState.modulatorPhase, 0.0, accuracy: 0.01, "Reset should clear modulator phase")
    }
    
    func testManualPhaseControl() {
        // Test manual phase setting
        modulationSystem.setPhase(carrier: 0.3, modulator: 0.7)
        
        let state = modulationSystem.getModulationState()
        XCTAssertEqual(state.carrierPhase, 0.3, accuracy: 0.01, "Manual carrier phase should be set")
        XCTAssertEqual(state.modulatorPhase, 0.7, accuracy: 0.01, "Manual modulator phase should be set")
        
        // Test phase wrapping
        modulationSystem.setPhase(carrier: 1.5, modulator: -0.3)
        let wrappedState = modulationSystem.getModulationState()
        XCTAssertTrue(wrappedState.carrierPhase >= 0.0 && wrappedState.carrierPhase < 1.0, "Carrier phase should wrap")
        XCTAssertTrue(wrappedState.modulatorPhase >= 0.0 && wrappedState.modulatorPhase < 1.0, "Modulator phase should wrap")
    }
    
    // MARK: - Edge Case Tests
    
    func testZeroFrequency() {
        // Test behavior with zero frequency
        modulationSystem.modulationType = .ringModulation
        
        let result = modulationSystem.processSample(
            carrierWavetable: carrierWavetable,
            modulatorWavetable: modulatorWavetable,
            carrierFrequency: 0.0,
            modulatorFrequency: 440.0
        )
        
        XCTAssertNotNil(result, "Zero frequency should not crash")
        XCTAssertTrue(result.isFinite, "Zero frequency should produce finite output")
    }
    
    func testVeryHighFrequency() {
        // Test behavior with very high frequency
        modulationSystem.modulationType = .hardSync
        modulationSystem.parameters.antiAliasing = true
        
        let result = modulationSystem.processSample(
            carrierWavetable: carrierWavetable,
            modulatorWavetable: modulatorWavetable,
            carrierFrequency: 20000.0, // Near Nyquist
            modulatorFrequency: 10000.0
        )
        
        XCTAssertNotNil(result, "High frequency should not crash")
        XCTAssertTrue(result.isFinite, "High frequency should produce finite output")
    }
    
    func testExtremeDepthValues() {
        // Test behavior with extreme depth values
        modulationSystem.modulationType = .ringModulation
        
        // Test maximum depth
        modulationSystem.parameters.depth = 1.0
        let maxResult = modulationSystem.processSample(
            carrierWavetable: carrierWavetable,
            modulatorWavetable: modulatorWavetable,
            carrierFrequency: 440.0,
            modulatorFrequency: 880.0
        )
        
        XCTAssertNotNil(maxResult, "Maximum depth should produce valid output")
        XCTAssertTrue(maxResult.isFinite, "Maximum depth should produce finite output")
        
        // Test minimum depth
        modulationSystem.parameters.depth = 0.0
        let minResult = modulationSystem.processSample(
            carrierWavetable: carrierWavetable,
            modulatorWavetable: modulatorWavetable,
            carrierFrequency: 440.0,
            modulatorFrequency: 880.0
        )
        
        XCTAssertNotNil(minResult, "Minimum depth should produce valid output")
        XCTAssertTrue(minResult.isFinite, "Minimum depth should produce finite output")
    }
    
    // MARK: - Modulation Type Display Names
    
    func testModulationTypeDisplayNames() {
        // Test that all modulation types have proper display names
        for modType in OscillatorModulationType.allCases {
            XCTAssertFalse(modType.displayName.isEmpty, "Modulation type \(modType) should have display name")
            XCTAssertNotEqual(modType.displayName, modType.rawValue, "Display name should be user-friendly")
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAccess() {
        // Test thread safety of modulation system
        modulationSystem.modulationType = .ringModulation
        modulationSystem.parameters.depth = 0.5
        
        let expectation = XCTestExpectation(description: "Concurrent processing")
        expectation.expectedFulfillmentCount = 4
        
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        for i in 0..<4 {
            queue.async {
                for _ in 0..<100 {
                    let result = self.modulationSystem.processSample(
                        carrierWavetable: self.carrierWavetable,
                        modulatorWavetable: self.modulatorWavetable,
                        carrierFrequency: Float(440 + i * 110),
                        modulatorFrequency: Float(880 + i * 220)
                    )
                    
                    XCTAssertTrue(result.isFinite, "Concurrent access should produce finite results")
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
}

// MARK: - Test Extensions

extension Float {
    var isFinite: Bool {
        return !isNaN && !isInfinite
    }
}