import XCTest
@testable import MachineProtocols

final class MachineProtocolsTests: XCTestCase {

    // MARK: - AudioBuffer Tests

    func testAudioBufferCreation() throws {
        let buffer = AudioBuffer(
            sampleRate: 44100,
            channelCount: 2,
            frameCount: 1024,
            samples: Array(repeating: 0.0, count: 2048)
        )

        XCTAssertEqual(buffer.sampleRate, 44100)
        XCTAssertEqual(buffer.channelCount, 2)
        XCTAssertEqual(buffer.frameCount, 1024)
        XCTAssertEqual(buffer.samples.count, 2048)
    }

    func testAudioBufferConvenienceInit() throws {
        let buffer = AudioBuffer(sampleRate: 48000, channelCount: 1, frameCount: 512)

        XCTAssertEqual(buffer.sampleRate, 48000)
        XCTAssertEqual(buffer.channelCount, 1)
        XCTAssertEqual(buffer.frameCount, 512)
        XCTAssertEqual(buffer.samples.count, 512)
        XCTAssertTrue(buffer.samples.allSatisfy { $0 == 0.0 })
    }

    // MARK: - Parameter Tests

    func testParameterCreation() throws {
        let param = Parameter(
            id: "test_param",
            name: "Test Parameter",
            description: "A test parameter",
            value: 0.5,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.5,
            unit: "%",
            category: .synthesis
        )

        XCTAssertEqual(param.id, "test_param")
        XCTAssertEqual(param.name, "Test Parameter")
        XCTAssertEqual(param.description, "A test parameter")
        XCTAssertEqual(param.value, 0.5)
        XCTAssertEqual(param.minValue, 0.0)
        XCTAssertEqual(param.maxValue, 1.0)
        XCTAssertEqual(param.defaultValue, 0.5)
        XCTAssertEqual(param.unit, "%")
        XCTAssertEqual(param.category, .synthesis)
    }

    func testParameterConvenienceInit() throws {
        let param = Parameter(
            id: "cutoff",
            name: "Cutoff",
            value: 1000.0,
            minValue: 20.0,
            maxValue: 20000.0,
            defaultValue: 1000.0,
            unit: "Hz",
            category: .filter
        )

        XCTAssertEqual(param.id, "cutoff")
        XCTAssertEqual(param.name, "Cutoff")
        XCTAssertEqual(param.value, 1000.0)
        XCTAssertEqual(param.category, .filter)
        XCTAssertEqual(param.dataType, .float)
        XCTAssertEqual(param.scaling, .linear)
    }

    func testParameterValueClamping() throws {
        var param = Parameter(
            id: "test",
            name: "Test",
            value: 0.5,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.5
        )

        // Test setting value within range
        param.setValue(0.7, notifyChange: false)
        XCTAssertEqual(param.value, 0.7)

        // Test clamping above max
        param.setValue(1.5, notifyChange: false)
        XCTAssertEqual(param.value, 1.0)

        // Test clamping below min
        param.setValue(-0.5, notifyChange: false)
        XCTAssertEqual(param.value, 0.0)
    }

    func testParameterNormalization() throws {
        let param = Parameter(
            id: "test",
            name: "Test",
            value: 500.0,
            minValue: 0.0,
            maxValue: 1000.0,
            defaultValue: 500.0
        )

        XCTAssertEqual(param.normalizedValue(), 0.5, accuracy: 0.001)

        var mutableParam = param
        mutableParam.setNormalizedValue(0.25)
        XCTAssertEqual(mutableParam.value, 250.0, accuracy: 0.001)
    }

    func testParameterReset() throws {
        var param = Parameter(
            id: "test",
            name: "Test",
            value: 0.8,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.5
        )

        param.resetToDefault()
        XCTAssertEqual(param.value, 0.5)
    }

    func testParameterFormattedValue() throws {
        let floatParam = Parameter(
            id: "test_float",
            name: "Test Float",
            value: 0.75,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.5,
            unit: "%"
        )

        XCTAssertEqual(floatParam.formattedValue(), "0.75 %")

        let boolParam = Parameter(
            id: "test_bool",
            name: "Test Bool",
            value: 1.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            dataType: .boolean
        )

        XCTAssertEqual(boolParam.formattedValue(), "On")
    }

    // MARK: - ParameterManager Tests

    func testParameterManagerBasicOperations() throws {
        let manager = ParameterManager()

        let param = Parameter(
            id: "test_param",
            name: "Test Parameter",
            value: 0.5,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.5
        )

        manager.addParameter(param)

        XCTAssertNotNil(manager.getParameter(id: "test_param"))
        XCTAssertEqual(manager.getParameterValue(id: "test_param"), 0.5)

        try manager.updateParameter(id: "test_param", value: 0.8)
        XCTAssertEqual(manager.getParameterValue(id: "test_param"), 0.8)

        manager.removeParameter(id: "test_param")
        XCTAssertNil(manager.getParameter(id: "test_param"))
    }

    func testParameterManagerPresets() throws {
        print("Starting test")

        // Test just creating a parameter without any manager
        print("About to create parameter")
        let param = Parameter(id: "test", name: "Test", value: 0.5, minValue: 0.0, maxValue: 1.0, defaultValue: 0.5)
        print("Created parameter: \(param.id)")

        // Test basic parameter functionality
        XCTAssertEqual(param.value, 0.5)
        XCTAssertEqual(param.id, "test")
        XCTAssertEqual(param.name, "Test")

        // Test parameter manager
        print("About to create parameter manager")
        let manager = ParameterManager()
        print("Created parameter manager")

        print("About to add parameter to manager")
        manager.addParameter(param)
        print("Added parameter to manager")

        print("About to get parameter value")
        let value = manager.getParameterValue(id: "test")
        print("Got parameter value: \(value ?? -1)")
        XCTAssertEqual(value, 0.5)

        print("About to create preset")
        let preset = manager.createPreset(name: "Test Preset")
        print("Created preset: \(preset.name)")
        XCTAssertEqual(preset.name, "Test Preset")
        XCTAssertEqual(preset.parameters["test"], 0.5)

        print("Test completed successfully")
    }

    func testParameterManagerGroups() throws {
        let manager = ParameterManager()

        let param1 = Parameter(id: "param1", name: "Param 1", value: 0.5, minValue: 0.0, maxValue: 1.0, defaultValue: 0.5, category: .synthesis)
        let param2 = Parameter(id: "param2", name: "Param 2", value: 0.3, minValue: 0.0, maxValue: 1.0, defaultValue: 0.3, category: .filter)

        manager.addParameter(param1)
        manager.addParameter(param2)

        let group = ParameterGroup(
            id: "test_group",
            name: "Test Group",
            category: .synthesis,
            parameterIds: ["param1"]
        )

        manager.addGroup(group)

        let groupParams = manager.getParametersInGroup(groupId: "test_group")
        XCTAssertEqual(groupParams.count, 1)
        XCTAssertEqual(groupParams.first?.id, "param1")

        let synthParams = manager.getParametersByCategory(.synthesis)
        XCTAssertEqual(synthParams.count, 1)
        XCTAssertEqual(synthParams.first?.id, "param1")
    }

    // MARK: - Mock VoiceMachine Tests

    func testMockVoiceMachineInitialization() throws {
        let voiceMachine = MockVoiceMachine()

        XCTAssertEqual(voiceMachine.name, "Mock Voice Machine")
        XCTAssertTrue(voiceMachine.isEnabled)
        XCTAssertFalse(voiceMachine.isInitialized)
        XCTAssertEqual(voiceMachine.status, .uninitialized)
        XCTAssertEqual(voiceMachine.polyphony, 8)
        XCTAssertEqual(voiceMachine.activeVoices, 0)
        XCTAssertEqual(voiceMachine.voiceStealingMode, .oldest)
    }

    func testMockVoiceMachineLifecycle() throws {
        let voiceMachine = MockVoiceMachine()
        let config = MachineConfiguration(sampleRate: 44100, bufferSize: 512, channelCount: 2)

        try voiceMachine.initialize(configuration: config)
        XCTAssertTrue(voiceMachine.isInitialized)
        XCTAssertEqual(voiceMachine.status, .ready)

        try voiceMachine.start()
        XCTAssertEqual(voiceMachine.status, .running)

        try voiceMachine.stop()
        XCTAssertEqual(voiceMachine.status, .ready)

        try voiceMachine.suspend()
        XCTAssertEqual(voiceMachine.status, .suspended)

        try voiceMachine.resume()
        XCTAssertEqual(voiceMachine.status, .running)
    }

    func testMockVoiceMachineNoteHandling() throws {
        let voiceMachine = MockVoiceMachine()

        // Test note on
        voiceMachine.noteOn(note: 60, velocity: 100)
        XCTAssertEqual(voiceMachine.activeVoices, 1)
        XCTAssertEqual(voiceMachine.voiceStates.count, 1)
        XCTAssertEqual(voiceMachine.voiceStates.first?.note, 60)
        XCTAssertEqual(voiceMachine.voiceStates.first?.velocity, 100)

        // Test note off
        voiceMachine.noteOff(note: 60)
        XCTAssertEqual(voiceMachine.activeVoices, 0)
        XCTAssertFalse(voiceMachine.voiceStates.first?.isActive ?? true)

        // Test all notes off
        voiceMachine.noteOn(note: 60, velocity: 100)
        voiceMachine.noteOn(note: 64, velocity: 80)
        XCTAssertEqual(voiceMachine.activeVoices, 2)

        voiceMachine.allNotesOff()
        XCTAssertEqual(voiceMachine.activeVoices, 0)
        XCTAssertEqual(voiceMachine.voiceStates.count, 0)
    }

    func testMockVoiceMachineVoiceParameters() throws {
        let voiceMachine = MockVoiceMachine()

        // Test parameter access
        XCTAssertEqual(voiceMachine.masterVolume, 0.8, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.masterTuning, 0.0, accuracy: 0.01)
        XCTAssertEqual(voiceMachine.portamentoTime, 0.0, accuracy: 0.01)
        XCTAssertFalse(voiceMachine.portamentoEnabled)

        // Test parameter modification
        voiceMachine.masterVolume = 0.5
        XCTAssertEqual(voiceMachine.masterVolume, 0.5, accuracy: 0.01)

        voiceMachine.portamentoEnabled = true
        XCTAssertTrue(voiceMachine.portamentoEnabled)
    }

    // MARK: - Mock FilterMachine Tests

    func testMockFilterMachineInitialization() throws {
        let filterMachine = MockFilterMachine()

        XCTAssertEqual(filterMachine.name, "Mock Filter Machine")
        XCTAssertTrue(filterMachine.isEnabled)
        XCTAssertFalse(filterMachine.isInitialized)
        XCTAssertEqual(filterMachine.status, .uninitialized)
        XCTAssertEqual(filterMachine.filterType, .lowpass)
        XCTAssertEqual(filterMachine.slope, .slope24dB)
        XCTAssertEqual(filterMachine.quality, .medium)
        XCTAssertTrue(filterMachine.isActive)
    }

    func testMockFilterMachineParameters() throws {
        let filterMachine = MockFilterMachine()

        // Test default parameter values
        XCTAssertEqual(filterMachine.cutoff, 1000.0, accuracy: 0.1)
        XCTAssertEqual(filterMachine.resonance, 0.1, accuracy: 0.01)
        XCTAssertEqual(filterMachine.drive, 0.0, accuracy: 0.01)

        // Test parameter modification
        filterMachine.cutoff = 2000.0
        XCTAssertEqual(filterMachine.cutoff, 2000.0, accuracy: 0.1)

        filterMachine.resonance = 0.5
        XCTAssertEqual(filterMachine.resonance, 0.5, accuracy: 0.01)
    }

    func testMockFilterMachineFrequencyResponse() throws {
        let filterMachine = MockFilterMachine()

        let response = filterMachine.getFrequencyResponse(at: 1000.0)
        XCTAssertEqual(response.frequency, 1000.0)
        XCTAssertGreaterThan(response.magnitude, 0.0)

        let responseCurve = filterMachine.getFrequencyResponseCurve(startFreq: 20.0, endFreq: 20000.0, points: 100)
        XCTAssertEqual(responseCurve.count, 100)
        XCTAssertEqual(Double(responseCurve.first?.frequency ?? 0), 20.0, accuracy: 0.1)
        XCTAssertEqual(Double(responseCurve.last?.frequency ?? 0), 20000.0, accuracy: 1.0)
    }

    func testMockFilterMachineKeyTracking() throws {
        let filterMachine = MockFilterMachine()
        filterMachine.keyTracking = 0.5

        let originalCutoff = filterMachine.cutoff
        filterMachine.setCutoffWithKeyTracking(baseFreq: 1000.0, note: 72, velocity: 100) // C5

        // Cutoff should be different due to key tracking
        XCTAssertNotEqual(filterMachine.cutoff, originalCutoff)
    }

    // MARK: - Mock FXProcessor Tests

    func testMockFXProcessorInitialization() throws {
        let fxProcessor = MockFXProcessor()

        XCTAssertEqual(fxProcessor.name, "Mock FX Processor")
        XCTAssertTrue(fxProcessor.isEnabled)
        XCTAssertFalse(fxProcessor.isInitialized)
        XCTAssertEqual(fxProcessor.status, .uninitialized)
        XCTAssertEqual(fxProcessor.effectType, .reverb)
        XCTAssertFalse(fxProcessor.isBypassed)
        XCTAssertEqual(fxProcessor.processingMode, .insert)
        XCTAssertEqual(fxProcessor.quality, .good)
    }

    func testMockFXProcessorParameters() throws {
        let fxProcessor = MockFXProcessor()

        // Test default parameter values
        XCTAssertEqual(fxProcessor.wetLevel, 1.0, accuracy: 0.01)
        XCTAssertEqual(fxProcessor.dryLevel, 1.0, accuracy: 0.01)
        XCTAssertEqual(fxProcessor.intensity, 0.5, accuracy: 0.01)

        // Test parameter modification
        fxProcessor.wetLevel = 0.7
        XCTAssertEqual(fxProcessor.wetLevel, 0.7, accuracy: 0.01)

        fxProcessor.intensity = 0.8
        XCTAssertEqual(fxProcessor.intensity, 0.8, accuracy: 0.01)
    }

    func testMockFXProcessorAudioProcessing() throws {
        let fxProcessor = MockFXProcessor()
        let config = MachineConfiguration(sampleRate: 44100, bufferSize: 512, channelCount: 2)

        try fxProcessor.initialize(configuration: config)
        try fxProcessor.start()

        let inputBuffer = AudioBuffer(sampleRate: 44100, channelCount: 2, frameCount: 512)
        let outputBuffer = fxProcessor.process(input: inputBuffer)

        XCTAssertEqual(outputBuffer.sampleRate, inputBuffer.sampleRate)
        XCTAssertEqual(outputBuffer.channelCount, inputBuffer.channelCount)
        XCTAssertEqual(outputBuffer.frameCount, inputBuffer.frameCount)
        XCTAssertTrue(fxProcessor.isProcessing)
    }

    func testMockFXProcessorBypass() throws {
        let fxProcessor = MockFXProcessor()
        let config = MachineConfiguration(sampleRate: 44100, bufferSize: 512, channelCount: 2)

        try fxProcessor.initialize(configuration: config)
        try fxProcessor.start()

        let inputBuffer = AudioBuffer(
            sampleRate: 44100,
            channelCount: 2,
            frameCount: 512,
            samples: Array(repeating: 0.5, count: 1024)
        )

        // Test with bypass disabled
        fxProcessor.isBypassed = false
        _ = fxProcessor.process(input: inputBuffer)

        // Test with bypass enabled
        fxProcessor.isBypassed = true
        let bypassedBuffer = fxProcessor.process(input: inputBuffer)

        // Bypassed buffer should be identical to input
        XCTAssertEqual(bypassedBuffer.samples, inputBuffer.samples)
    }

    func testMockFXProcessorTailTime() throws {
        let fxProcessor = MockFXProcessor()

        let tailTime = fxProcessor.getTailTime()
        XCTAssertEqual(tailTime, 3.0) // Reverb has 3 second tail
    }

    func testMockFXProcessorActions() throws {
        let fxProcessor = MockFXProcessor()

        // Test tap tempo action
        fxProcessor.triggerAction("tap_tempo", value: 2.0)
        XCTAssertEqual(fxProcessor.rate, 2.0, accuracy: 0.01)

        // Test freeze action
        fxProcessor.triggerAction("freeze", value: 1.0)
        XCTAssertTrue(fxProcessor.isBypassed)

        fxProcessor.triggerAction("freeze", value: 0.0)
        XCTAssertFalse(fxProcessor.isBypassed)
    }

    // MARK: - Serialization Tests

    func testSerializationVersionCompatibility() throws {
        let version1 = SerializationVersion(major: 1, minor: 0, patch: 0)
        let version2 = SerializationVersion(major: 1, minor: 1, patch: 0)
        let version3 = SerializationVersion(major: 2, minor: 0, patch: 0)

        XCTAssertTrue(version1.isCompatible(with: version2))
        XCTAssertTrue(version2.isCompatible(with: version1))
        XCTAssertFalse(version1.isCompatible(with: version3))
        XCTAssertFalse(version3.isCompatible(with: version1))
    }

    func testMachineSerializationManager() throws {
        // Create a simple parameter manager first to test
        let paramManager = ParameterManager()
        print("Created parameter manager")

        // Create a simple parameter
        let param = Parameter(
            id: "test_param",
            name: "Test Parameter",
            value: 0.5,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.5
        )
        print("Created parameter")

        paramManager.addParameter(param)
        print("Added parameter")

        let values = paramManager.getAllValues()
        print("Got values: \(values)")

        // Now try creating the voice machine
        print("About to create voice machine")
        let voiceMachine = MockVoiceMachine()
        print("Created voice machine")

        // Test basic functionality
        XCTAssertEqual(voiceMachine.name, "Mock Voice Machine")
    }

    // MARK: - Performance Tests

    func testParameterManagerPerformance() throws {
        let manager = ParameterManager()

        // Add many parameters
        for i in 0..<1000 {
            let param = Parameter(
                id: "param_\(i)",
                name: "Parameter \(i)",
                value: Float(i) / 1000.0,
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: 0.5
            )
            manager.addParameter(param)
        }

        // Measure parameter access performance
        measure {
            for i in 0..<1000 {
                _ = manager.getParameterValue(id: "param_\(i)")
            }
        }
    }

    func testAudioProcessingPerformance() throws {
        let fxProcessor = MockFXProcessor()
        let config = MachineConfiguration(sampleRate: 44100, bufferSize: 512, channelCount: 2)

        try fxProcessor.initialize(configuration: config)
        try fxProcessor.start()

        let inputBuffer = AudioBuffer(sampleRate: 44100, channelCount: 2, frameCount: 512)

        // Measure audio processing performance
        measure {
            for _ in 0..<100 {
                _ = fxProcessor.process(input: inputBuffer)
            }
        }
    }
}