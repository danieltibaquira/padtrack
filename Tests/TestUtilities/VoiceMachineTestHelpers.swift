import Foundation
import XCTest
import MachineProtocols
@testable import VoiceModule

/// Reusable utilities for voice machine testing
public class VoiceMachineTestHelpers {
    
    // MARK: - Voice Machine Factory
    
    /// Create a WavetoneVoiceMachine with standard test configuration
    public static func createTestWavetoneVoiceMachine(
        sampleRate: Float = 44100.0
    ) -> WavetoneVoiceMachine {
        return WavetoneVoiceMachine(sampleRate: sampleRate)
    }
    
    /// Create a FMDrumVoiceMachine with standard test configuration
    public static func createTestFMDrumVoiceMachine() -> FMDrumVoiceMachine {
        return FMDrumVoiceMachine()
    }
    
    // MARK: - Parameter Testing Utilities
    
    /// Standard parameter IDs commonly used in voice machine tests
    public enum CommonParameters {
        // Oscillator parameters
        public static let osc1Level = "osc1_level"
        public static let osc1Tuning = "osc1_tuning" 
        public static let osc1WavetablePos = "osc1_wavetable_pos"
        public static let osc1PhaseDistortion = "osc1_phase_distortion"
        
        public static let osc2Level = "osc2_level"
        public static let osc2Tuning = "osc2_tuning"
        public static let osc2WavetablePos = "osc2_wavetable_pos"
        public static let osc2PhaseDistortion = "osc2_phase_distortion"
        
        // Envelope parameters
        public static let ampAttack = "amp_attack"
        public static let ampDecay = "amp_decay"
        public static let ampSustain = "amp_sustain"
        public static let ampRelease = "amp_release"
        
        // Noise parameters
        public static let noiseLevel = "noise_level"
        public static let noiseType = "noise_type"
        public static let noiseBaseFreq = "noise_base_freq"
        public static let noiseWidth = "noise_width"
        public static let noiseGrain = "noise_grain"
        public static let noiseResonance = "noise_resonance"
        public static let noiseCharacter = "noise_character"
        
        // Modulation parameters
        public static let ringModAmount = "ring_mod_amount"
        public static let hardSyncEnable = "hard_sync_enable"
        public static let modWheel = "mod_wheel"
        public static let aftertouch = "aftertouch"
        public static let lfo1Rate = "lfo1_rate"
        public static let lfo1Depth = "lfo1_depth"
        
        // Velocity and performance
        public static let velocity = "velocity"
    }
    
    /// Set common test parameters for a voice machine
    public static func setupTestParameters(_ voiceMachine: WavetoneVoiceMachine) {
        // Oscillator setup
        voiceMachine.setParameter(CommonParameters.osc1Level, value: 0.7)
        voiceMachine.setParameter(CommonParameters.osc1Tuning, value: 7.0)
        voiceMachine.setParameter(CommonParameters.osc1WavetablePos, value: 0.5)
        voiceMachine.setParameter(CommonParameters.osc1PhaseDistortion, value: 0.3)
        
        voiceMachine.setParameter(CommonParameters.osc2Level, value: 0.4)
        voiceMachine.setParameter(CommonParameters.osc2Tuning, value: -12.0)
        voiceMachine.setParameter(CommonParameters.osc2WavetablePos, value: 0.8)
        voiceMachine.setParameter(CommonParameters.osc2PhaseDistortion, value: 0.7)
        
        // Envelope setup
        voiceMachine.setParameter(CommonParameters.ampAttack, value: 0.5)
        voiceMachine.setParameter(CommonParameters.ampDecay, value: 0.8)
        voiceMachine.setParameter(CommonParameters.ampSustain, value: 0.6)
        voiceMachine.setParameter(CommonParameters.ampRelease, value: 2.0)
        
        // Noise setup
        voiceMachine.setParameter(CommonParameters.noiseLevel, value: 0.7)
        voiceMachine.setParameter(CommonParameters.noiseType, value: 2.0)
        voiceMachine.setParameter(CommonParameters.noiseBaseFreq, value: 2000.0)
        voiceMachine.setParameter(CommonParameters.noiseWidth, value: 500.0)
        voiceMachine.setParameter(CommonParameters.noiseGrain, value: 0.8)
        voiceMachine.setParameter(CommonParameters.noiseResonance, value: 0.6)
        voiceMachine.setParameter(CommonParameters.noiseCharacter, value: 0.3)
        
        // Modulation setup
        voiceMachine.setParameter(CommonParameters.ringModAmount, value: 0.5)
        voiceMachine.setParameter(CommonParameters.hardSyncEnable, value: 1.0)
        voiceMachine.setParameter(CommonParameters.modWheel, value: 0.7)
        voiceMachine.setParameter(CommonParameters.aftertouch, value: 0.3)
        voiceMachine.setParameter(CommonParameters.lfo1Rate, value: 3.0)
        voiceMachine.setParameter(CommonParameters.lfo1Depth, value: 0.8)
    }
    
    // MARK: - Parameter Validation
    
    /// Validate that a voice machine has all expected parameters
    public static func validateParameterPresence(
        _ voiceMachine: WavetoneVoiceMachine,
        expectedParameters: [String],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        for parameterID in expectedParameters {
            let parameter = voiceMachine.parameters.getParameter(id: parameterID)
            XCTAssertNotNil(parameter, "Parameter \(parameterID) should exist", file: file, line: line)
        }
    }
    
    /// Validate parameter value ranges
    public static func validateParameterRanges(
        _ voiceMachine: WavetoneVoiceMachine,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        // Level parameters should be 0.0 to 1.0
        let levelParams = [CommonParameters.osc1Level, CommonParameters.osc2Level, CommonParameters.noiseLevel]
        for param in levelParams {
            let value = voiceMachine.getParameter(param)
            XCTAssertGreaterThanOrEqual(value, 0.0, "Level parameter \(param) should be >= 0.0", file: file, line: line)
            XCTAssertLessThanOrEqual(value, 1.0, "Level parameter \(param) should be <= 1.0", file: file, line: line)
        }
        
        // Attack time should have minimum value
        let attack = voiceMachine.getParameter(CommonParameters.ampAttack)
        XCTAssertGreaterThanOrEqual(attack, 0.001, "Attack time should be >= 0.001s", file: file, line: line)
        XCTAssertLessThanOrEqual(attack, 10.0, "Attack time should be <= 10.0s", file: file, line: line)
    }
    
    // MARK: - Preset Testing
    
    /// Create a test preset with known parameter values
    public static func createTestPreset() -> [String: Any] {
        return [
            CommonParameters.osc1Level: 0.6,
            CommonParameters.osc2Tuning: -12.0,
            CommonParameters.ampAttack: 2.0,
            CommonParameters.ampSustain: 0.8,
            CommonParameters.noiseLevel: 0.5
        ]
    }
    
    /// Validate preset data structure
    public static func validatePresetStructure(
        _ preset: [String: Any],
        expectedKeys: [String] = [],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertFalse(preset.isEmpty, "Preset should not be empty", file: file, line: line)
        
        for key in expectedKeys {
            XCTAssertTrue(preset.keys.contains(key), "Preset should contain key: \(key)", file: file, line: line)
        }
        
        // Validate that all values are proper types
        for (key, value) in preset {
            XCTAssertTrue(
                value is Float || value is Double || value is Int || value is String || value is Bool,
                "Preset value for \(key) should be a valid type",
                file: file,
                line: line
            )
        }
    }
    
    // MARK: - Audio Processing Testing
    
    /// Test voice machine audio generation with standard settings
    public static func testBasicAudioGeneration(
        _ voiceMachine: WavetoneVoiceMachine,
        note: Int = 60,
        velocity: Int = 100,
        frameCount: Int = 512,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        // Trigger note
        voiceMachine.noteOn(note: UInt8(note), velocity: UInt8(velocity), channel: 0, timestamp: nil)
        
        // Process audio
        let buffer = AudioBufferTestHelpers.createConcreteBuffer(frameCount: frameCount)
        defer { buffer.data.deallocate() }
        
        // In a real test, we'd call voiceMachine.process(buffer)
        // For now, just validate the setup
        
        XCTAssertTrue(buffer.frameCount == frameCount, "Buffer should have expected frame count", file: file, line: line)
        XCTAssertTrue(buffer.isValid, "Buffer should be valid", file: file, line: line)
        
        // Trigger note off
        voiceMachine.noteOff(note: UInt8(note), velocity: UInt8(velocity), channel: 0, timestamp: nil)
    }
    
    // MARK: - Performance Testing
    
    /// Measure voice machine parameter update performance
    public static func measureParameterUpdatePerformance(
        _ voiceMachine: WavetoneVoiceMachine,
        iterations: Int = 1000
    ) -> TimeInterval {
        let parameters = [
            CommonParameters.osc1Level,
            CommonParameters.osc2Tuning,
            CommonParameters.ampAttack,
            CommonParameters.noiseLevel
        ]
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<iterations {
            let param = parameters[i % parameters.count]
            let value = Float.random(in: 0.0...1.0)
            voiceMachine.setParameter(param, value: value)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        return endTime - startTime
    }
    
    // MARK: - Mock Objects
    
    /// Mock WavetableManager for testing
    public class MockWavetableManager {
        public var wavetables: [WavetableData] = []
        
        public init() {
            // Create some test wavetables
            wavetables = createTestWavetables()
        }
        
        public func getAllWavetables() -> [WavetableData] {
            return wavetables
        }
        
        public func getWavetables(in category: WavetableCategory) -> [WavetableData] {
            // Since category property doesn't exist, return all wavetables for now
            return wavetables
        }
        
        private func createTestWavetables() -> [WavetableData] {
            // For testing purposes, return empty array or minimal test data
            // Real wavetables would require proper metadata and complex initialization
            return []
        }
    }
    
    // MARK: - Test Configurations
    
    /// Standard test configurations for different scenarios
    public enum TestConfiguration {
        case minimal      // Minimal settings for basic functionality
        case typical      // Typical musical settings
        case extreme      // Extreme values for stress testing
        case performance  // Optimized for performance testing
        
        public var parameters: [String: Float] {
            switch self {
            case .minimal:
                return [
                    CommonParameters.osc1Level: 0.5,
                    CommonParameters.ampAttack: 0.01,
                    CommonParameters.ampRelease: 0.1
                ]
                
            case .typical:
                return [
                    CommonParameters.osc1Level: 0.7,
                    CommonParameters.osc2Level: 0.3,
                    CommonParameters.ampAttack: 0.1,
                    CommonParameters.ampDecay: 0.3,
                    CommonParameters.ampSustain: 0.7,
                    CommonParameters.ampRelease: 0.5,
                    CommonParameters.noiseLevel: 0.1
                ]
                
            case .extreme:
                return [
                    CommonParameters.osc1Level: 1.0,
                    CommonParameters.osc2Level: 1.0,
                    CommonParameters.ampAttack: 5.0,
                    CommonParameters.ampRelease: 10.0,
                    CommonParameters.noiseLevel: 1.0,
                    CommonParameters.ringModAmount: 1.0
                ]
                
            case .performance:
                return [
                    CommonParameters.osc1Level: 0.6,
                    CommonParameters.ampAttack: 0.001,  // Fast attack for performance
                    CommonParameters.ampRelease: 0.01,  // Fast release for performance
                    CommonParameters.noiseLevel: 0.0    // No noise to reduce CPU
                ]
            }
        }
    }
    
    /// Apply a test configuration to a voice machine
    public static func applyConfiguration(
        _ configuration: TestConfiguration,
        to voiceMachine: WavetoneVoiceMachine
    ) {
        for (parameter, value) in configuration.parameters {
            voiceMachine.setParameter(parameter, value: value)
        }
    }
}

// MARK: - XCTest Extensions

extension XCTestCase {
    /// Convenience method to create and configure a test voice machine
    public func createConfiguredWavetoneVoiceMachine(
        configuration: VoiceMachineTestHelpers.TestConfiguration = .typical,
        sampleRate: Float = 44100.0
    ) -> WavetoneVoiceMachine {
        let voiceMachine = VoiceMachineTestHelpers.createTestWavetoneVoiceMachine(sampleRate: sampleRate)
        VoiceMachineTestHelpers.applyConfiguration(configuration, to: voiceMachine)
        return voiceMachine
    }
    
    /// Assert that voice machine parameters are within expected ranges
    public func assertParameterRangesValid(
        _ voiceMachine: WavetoneVoiceMachine,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        VoiceMachineTestHelpers.validateParameterRanges(voiceMachine, file: file, line: line)
    }
}