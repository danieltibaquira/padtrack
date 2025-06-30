import XCTest
@testable import VoiceModule
@testable import MachineProtocols

/// Comprehensive test suite for WAVETONE Oscillator Modulation System
/// Tests Ring Modulation, Hard Sync, Phase Modulation, and Amplitude Modulation
final class WavetoneOscillatorModulationTests: XCTestCase {
    
    var oscillator1: WavetoneOscillator!
    var oscillator2: WavetoneOscillator!
    var wavetableManager: WavetableManager!
    var testWavetable: WavetableData!
    
    override func setUp() {
        super.setUp()
        
        // Initialize wavetable manager and test wavetable
        wavetableManager = WavetableManager()
        testWavetable = wavetableManager.getBuiltInWavetables().first
        
        // Initialize oscillators
        oscillator1 = WavetoneOscillator(sampleRate: 44100.0)
        oscillator2 = WavetoneOscillator(sampleRate: 44100.0)
        
        // Set up basic configuration
        oscillator1.currentWavetable = testWavetable
        oscillator2.currentWavetable = testWavetable
        oscillator1.frequency = 440.0
        oscillator2.frequency = 880.0  // One octave higher
        oscillator1.amplitude = 0.5
        oscillator2.amplitude = 0.5
    }
    
    override func tearDown() {
        oscillator1 = nil
        oscillator2 = nil
        wavetableManager = nil
        testWavetable = nil
        super.tearDown()
    }
    
    // MARK: - Ring Modulation Tests
    
    func testRingModulationBasicFunctionality() {
        // Configure ring modulation
        oscillator1.setModulation(type: .ringModulation, amount: 1.0)
        
        // Generate test samples
        let osc1Sample = oscillator1.processSample()
        let osc2Sample = oscillator2.processSample()
        
        // Test ring modulation with full amount
        let ringModulatedSample = oscillator1.processSample(modulationInput: osc2Sample)
        
        // Ring modulated signal should be different from dry signal
        XCTAssertNotEqual(ringModulatedSample, osc1Sample, accuracy: 0.001)
        
        // With full ring modulation, output should be close to multiplication
        let expectedRingMod = osc1Sample * osc2Sample
        XCTAssertEqual(ringModulatedSample, expectedRingMod, accuracy: 0.1)
    }
    
    func testRingModulationAmountControl() {
        oscillator1.setModulation(type: .ringModulation, amount: 0.5)
        
        let osc1Sample = oscillator1.processSample()
        let osc2Sample = oscillator2.processSample()
        
        // Reset oscillators to get same samples
        oscillator1.resetPhase()
        oscillator2.resetPhase()
        
        let dryOsc1 = oscillator1.processSample()
        let testOsc2 = oscillator2.processSample()
        
        oscillator1.resetPhase()
        oscillator2.resetPhase()
        
        let ringModulatedSample = oscillator1.processSample(modulationInput: testOsc2)
        
        // With 50% ring modulation, should be blend of dry and ring modulated
        let expectedDry = dryOsc1 * 0.5
        let expectedRing = (dryOsc1 * testOsc2) * 0.5
        let expectedTotal = expectedDry + expectedRing
        
        XCTAssertEqual(ringModulatedSample, expectedTotal, accuracy: 0.01)
    }
    
    func testRingModulationDisabled() {
        oscillator1.setModulation(type: .none, amount: 0.0)
        
        let osc2Sample = oscillator2.processSample()
        
        // Reset to get consistent sample
        oscillator1.resetPhase()
        let dryOsc1 = oscillator1.processSample()
        
        oscillator1.resetPhase()
        let modulatedOsc1 = oscillator1.processSample(modulationInput: osc2Sample)
        
        // With no modulation, output should be identical
        XCTAssertEqual(dryOsc1, modulatedOsc1, accuracy: 0.001)
    }
    
    // MARK: - Hard Sync Tests
    
    func testHardSyncBasicFunctionality() {
        // Configure hard sync: OSC2 synced to OSC1
        oscillator2.setModulation(type: .hardSync, amount: 1.0)
        oscillator2.syncSource = oscillator1
        
        // Set different frequencies for sync effect
        oscillator1.frequency = 220.0  // Lower frequency (sync source)
        oscillator2.frequency = 660.0  // Higher frequency (sync target)
        
        var syncDetected = false
        var lastOsc2Phase = oscillator2.currentPhase
        
        // Process samples and look for phase reset
        for _ in 0..<1000 {
            _ = oscillator1.processSample()
            _ = oscillator2.processSample()
            
            let currentOsc2Phase = oscillator2.currentPhase
            
            // Detect if phase was reset (hard sync occurred)
            if currentOsc2Phase < lastOsc2Phase && lastOsc2Phase > 3.0 {
                syncDetected = true
                break
            }
            
            lastOsc2Phase = currentOsc2Phase
        }
        
        XCTAssertTrue(syncDetected, "Hard sync should cause phase resets in OSC2")
    }
    
    func testHardSyncDisabled() {
        // Configure no sync
        oscillator2.setModulation(type: .none, amount: 0.0)
        oscillator2.syncSource = nil
        
        oscillator1.frequency = 220.0
        oscillator2.frequency = 660.0
        
        let initialPhase = oscillator2.currentPhase
        
        // Process many samples
        for _ in 0..<1000 {
            _ = oscillator1.processSample()
            _ = oscillator2.processSample()
        }
        
        // Phase should have advanced normally without resets
        XCTAssertGreaterThan(oscillator2.currentPhase, initialPhase)
    }
    
    // MARK: - Phase Modulation Tests
    
    func testPhaseModulationBasicFunctionality() {
        oscillator1.setModulation(type: .phaseModulation, amount: 0.5)
        
        let modulationInput: Float = 0.5
        
        // Reset to get consistent samples
        oscillator1.resetPhase()
        let dryOsc1 = oscillator1.processSample()
        
        oscillator1.resetPhase()
        let phaseModulatedOsc1 = oscillator1.processSample(modulationInput: modulationInput)
        
        // Phase modulated signal should be different from dry
        XCTAssertNotEqual(dryOsc1, phaseModulatedOsc1, accuracy: 0.001)
    }
    
    func testPhaseModulationAmount() {
        // Test different modulation amounts
        let modulationInput: Float = 1.0
        
        oscillator1.setModulation(type: .phaseModulation, amount: 0.0)
        oscillator1.resetPhase()
        let noModSample = oscillator1.processSample(modulationInput: modulationInput)
        
        oscillator1.setModulation(type: .phaseModulation, amount: 0.5)
        oscillator1.resetPhase()
        let halfModSample = oscillator1.processSample(modulationInput: modulationInput)
        
        oscillator1.setModulation(type: .phaseModulation, amount: 1.0)
        oscillator1.resetPhase()
        let fullModSample = oscillator1.processSample(modulationInput: modulationInput)
        
        // All samples should be different
        XCTAssertNotEqual(noModSample, halfModSample, accuracy: 0.001)
        XCTAssertNotEqual(halfModSample, fullModSample, accuracy: 0.001)
        XCTAssertNotEqual(noModSample, fullModSample, accuracy: 0.001)
    }
    
    // MARK: - Amplitude Modulation Tests
    
    func testAmplitudeModulationBasicFunctionality() {
        oscillator1.setModulation(type: .amplitudeModulation, amount: 1.0)
        
        let modulationInput: Float = 0.5
        
        oscillator1.resetPhase()
        let dryOsc1 = oscillator1.processSample()
        
        oscillator1.resetPhase()
        let ampModulatedOsc1 = oscillator1.processSample(modulationInput: modulationInput)
        
        // AM modulated signal should be different from dry
        XCTAssertNotEqual(dryOsc1, ampModulatedOsc1, accuracy: 0.001)
        
        // With positive modulation input, amplitude should be increased
        XCTAssertGreaterThan(abs(ampModulatedOsc1), abs(dryOsc1))
    }
    
    func testAmplitudeModulationNegativeInput() {
        oscillator1.setModulation(type: .amplitudeModulation, amount: 1.0)
        
        let negativeModulationInput: Float = -0.5
        
        oscillator1.resetPhase()
        let dryOsc1 = oscillator1.processSample()
        
        oscillator1.resetPhase()
        let ampModulatedOsc1 = oscillator1.processSample(modulationInput: negativeModulationInput)
        
        // With negative modulation input, amplitude should be decreased
        XCTAssertLessThan(abs(ampModulatedOsc1), abs(dryOsc1))
    }
    
    // MARK: - Performance Tests
    
    func testModulationPerformance() {
        oscillator1.setModulation(type: .ringModulation, amount: 1.0)
        
        let sampleCount = 44100  // 1 second at 44.1kHz
        let modulationInput: Float = 0.5
        
        measure {
            for _ in 0..<sampleCount {
                _ = oscillator1.processSample(modulationInput: modulationInput)
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testExtremeModulationAmounts() {
        // Test with extreme modulation amounts
        oscillator1.setModulation(type: .ringModulation, amount: 10.0)  // Beyond normal range
        
        let modulationInput: Float = 1.0
        let sample = oscillator1.processSample(modulationInput: modulationInput)
        
        // Should not crash or produce NaN
        XCTAssertFalse(sample.isNaN)
        XCTAssertFalse(sample.isInfinite)
    }
    
    func testZeroFrequencyOscillator() {
        oscillator1.frequency = 0.0
        oscillator1.setModulation(type: .ringModulation, amount: 1.0)
        
        let sample = oscillator1.processSample(modulationInput: 0.5)
        
        // Should handle zero frequency gracefully
        XCTAssertFalse(sample.isNaN)
        XCTAssertFalse(sample.isInfinite)
    }
}
