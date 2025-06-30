// MIDIIOModuleTests.swift
// DigitonePad - MIDIModuleTests
//
// Comprehensive test suite for MIDI I/O Module

import XCTest
import CoreMIDI
@testable import MIDIModule

final class MIDIIOModuleTests: XCTestCase {
    
    var midiIO: MIDIIOModule!
    var config: MIDIIOConfig!
    
    override func setUp() {
        super.setUp()
        config = MIDIIOConfig()
        midiIO = MIDIIOModule(config: config)
    }
    
    override func tearDown() {
        midiIO = nil
        config = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialization() {
        XCTAssertNotNil(midiIO)
        XCTAssertTrue(midiIO.config.input.enabled)
        XCTAssertTrue(midiIO.config.output.enabled)
        XCTAssertTrue(midiIO.config.routing.enableRouting)
    }
    
    func testConfigurationUpdate() {
        var newConfig = MIDIIOConfig()
        newConfig.input.bufferSize = 2048
        newConfig.output.enableLatencyCompensation = false
        newConfig.filtering.enableFiltering = true
        
        midiIO.config = newConfig
        
        XCTAssertEqual(midiIO.config.input.bufferSize, 2048)
        XCTAssertFalse(midiIO.config.output.enableLatencyCompensation)
        XCTAssertTrue(midiIO.config.filtering.enableFiltering)
    }
    
    func testLifecycleManagement() {
        // Test initialization
        XCTAssertNoThrow(try midiIO.initialize())
        
        // Test start
        XCTAssertNoThrow(try midiIO.start())
        
        // Test stop
        midiIO.stop()
        
        // Test reset
        XCTAssertNoThrow(try midiIO.reset())
    }
    
    // MARK: - Configuration Tests
    
    func testInputConfiguration() {
        var inputConfig = MIDIInputConfig()
        inputConfig.bufferSize = 512
        inputConfig.enableTimestamping = false
        inputConfig.enableChannelFiltering = true
        inputConfig.allowedChannels = Set([0, 1, 2])
        inputConfig.enableVelocityScaling = true
        inputConfig.velocityScale = 0.8
        
        config.input = inputConfig
        midiIO.config = config
        
        XCTAssertEqual(midiIO.config.input.bufferSize, 512)
        XCTAssertFalse(midiIO.config.input.enableTimestamping)
        XCTAssertTrue(midiIO.config.input.enableChannelFiltering)
        XCTAssertEqual(midiIO.config.input.allowedChannels, Set([0, 1, 2]))
        XCTAssertTrue(midiIO.config.input.enableVelocityScaling)
        XCTAssertEqual(midiIO.config.input.velocityScale, 0.8, accuracy: 0.01)
    }
    
    func testOutputConfiguration() {
        var outputConfig = MIDIOutputConfig()
        outputConfig.bufferSize = 256
        outputConfig.enableLatencyCompensation = true
        outputConfig.latencyCompensationMs = 5.0
        outputConfig.enableChannelRemapping = true
        outputConfig.channelMap = [0: 1, 1: 2]
        outputConfig.velocityCurve = .exponential
        
        config.output = outputConfig
        midiIO.config = config
        
        XCTAssertEqual(midiIO.config.output.bufferSize, 256)
        XCTAssertTrue(midiIO.config.output.enableLatencyCompensation)
        XCTAssertEqual(midiIO.config.output.latencyCompensationMs, 5.0, accuracy: 0.01)
        XCTAssertTrue(midiIO.config.output.enableChannelRemapping)
        XCTAssertEqual(midiIO.config.output.channelMap, [0: 1, 1: 2])
        XCTAssertEqual(midiIO.config.output.velocityCurve, .exponential)
    }
    
    func testRoutingConfiguration() {
        var routingConfig = MIDIRoutingConfig()
        routingConfig.maxRoutes = 32
        routingConfig.enableSplitting = false
        routingConfig.enableMerging = false
        routingConfig.enableThru = true
        routingConfig.thruDelay = 2.0
        
        config.routing = routingConfig
        midiIO.config = config
        
        XCTAssertEqual(midiIO.config.routing.maxRoutes, 32)
        XCTAssertFalse(midiIO.config.routing.enableSplitting)
        XCTAssertFalse(midiIO.config.routing.enableMerging)
        XCTAssertTrue(midiIO.config.routing.enableThru)
        XCTAssertEqual(midiIO.config.routing.thruDelay, 2.0, accuracy: 0.01)
    }
    
    func testFilteringConfiguration() {
        var filteringConfig = MIDIFilteringConfig()
        filteringConfig.enableFiltering = true
        filteringConfig.allowedMessageTypes = Set([.noteOn, .noteOff, .controlChange])
        filteringConfig.blockedMessageTypes = Set([.systemExclusive])
        filteringConfig.enableChannelFiltering = true
        filteringConfig.allowedChannels = Set([0, 9])  // Channel 1 and 10
        filteringConfig.enableVelocityFiltering = true
        filteringConfig.minVelocity = 10
        filteringConfig.maxVelocity = 120
        
        config.filtering = filteringConfig
        midiIO.config = config
        
        XCTAssertTrue(midiIO.config.filtering.enableFiltering)
        XCTAssertEqual(midiIO.config.filtering.allowedMessageTypes, Set([.noteOn, .noteOff, .controlChange]))
        XCTAssertEqual(midiIO.config.filtering.blockedMessageTypes, Set([.systemExclusive]))
        XCTAssertTrue(midiIO.config.filtering.enableChannelFiltering)
        XCTAssertEqual(midiIO.config.filtering.allowedChannels, Set([0, 9]))
        XCTAssertTrue(midiIO.config.filtering.enableVelocityFiltering)
        XCTAssertEqual(midiIO.config.filtering.minVelocity, 10)
        XCTAssertEqual(midiIO.config.filtering.maxVelocity, 120)
    }
    
    // MARK: - Device Management Tests
    
    func testDeviceDiscovery() {
        XCTAssertNoThrow(try midiIO.initialize())
        XCTAssertNoThrow(try midiIO.discoverDevices())
        
        // Initially no devices should be connected
        XCTAssertTrue(midiIO.connectedInputDevices.isEmpty)
        XCTAssertTrue(midiIO.connectedOutputDevices.isEmpty)
    }
    
    func testDeviceConnection() {
        let mockDevice = createMockDevice(supportsInput: true, supportsOutput: false)
        
        XCTAssertNoThrow(try midiIO.initialize())
        
        // Test input device connection
        XCTAssertNoThrow(try midiIO.connectInputDevice(mockDevice))
        
        // Test output device connection (should fail for input-only device)
        XCTAssertThrowsError(try midiIO.connectOutputDevice(mockDevice))
    }
    
    func testDeviceDisconnection() {
        let mockDevice = createMockDevice(supportsInput: true, supportsOutput: false)
        
        XCTAssertNoThrow(try midiIO.initialize())
        XCTAssertNoThrow(try midiIO.connectInputDevice(mockDevice))
        XCTAssertNoThrow(try midiIO.disconnectInputDevice(mockDevice))
    }
    
    // MARK: - Message Processing Tests
    
    func testMessageSending() {
        let mockDevice = createMockDevice(supportsInput: false, supportsOutput: true)
        let message = MIDIMessage(type: .noteOn, channel: 0, data1: 60, data2: 100)
        
        XCTAssertNoThrow(try midiIO.initialize())
        XCTAssertNoThrow(try midiIO.start())
        XCTAssertNoThrow(try midiIO.connectOutputDevice(mockDevice))
        
        // Test sending message to specific device
        XCTAssertNoThrow(try midiIO.sendMessage(message, to: mockDevice))
        
        midiIO.stop()
    }
    
    func testMessageBroadcasting() {
        let message = MIDIMessage(type: .noteOn, channel: 0, data1: 60, data2: 100)
        
        XCTAssertNoThrow(try midiIO.initialize())
        XCTAssertNoThrow(try midiIO.start())
        
        // Test broadcasting message (should work even with no connected devices)
        XCTAssertNoThrow(try midiIO.broadcastMessage(message))
        
        midiIO.stop()
    }
    
    func testMessageRouting() {
        let message = MIDIMessage(type: .noteOn, channel: 0, data1: 60, data2: 100)
        let sourceDevice = createMockDevice(supportsInput: true, supportsOutput: false)
        
        XCTAssertNoThrow(try midiIO.initialize())
        
        // Test message routing
        midiIO.routeMessage(message, from: sourceDevice)
        
        // Should complete without error
        XCTAssertTrue(true)
    }
    
    // MARK: - Routing Management Tests
    
    func testRouteManagement() {
        let route = MIDIRoute(
            name: "Test Route",
            sourceChannel: 0,
            destinationChannel: 1,
            messageTypeFilter: Set([.noteOn, .noteOff]),
            enabled: true,
            priority: 10
        )
        
        // Test adding route
        midiIO.addRoute(route)
        XCTAssertTrue(midiIO.routes.contains { $0.id == route.id })
        
        // Test updating route
        var updatedRoute = route
        updatedRoute = MIDIRoute(
            id: route.id,
            name: "Updated Route",
            sourceChannel: route.sourceChannel,
            destinationChannel: route.destinationChannel,
            messageTypeFilter: route.messageTypeFilter,
            enabled: false,
            priority: route.priority
        )
        midiIO.updateRoute(updatedRoute)
        
        let foundRoute = midiIO.routes.first { $0.id == route.id }
        XCTAssertEqual(foundRoute?.name, "Updated Route")
        XCTAssertFalse(foundRoute?.enabled ?? true)
        
        // Test removing route
        midiIO.removeRoute(id: route.id)
        XCTAssertFalse(midiIO.routes.contains { $0.id == route.id })
    }
    
    func testRouteClearance() {
        let route1 = MIDIRoute(name: "Route 1")
        let route2 = MIDIRoute(name: "Route 2")
        
        midiIO.addRoute(route1)
        midiIO.addRoute(route2)
        
        XCTAssertEqual(midiIO.routes.count, 2)
        
        midiIO.clearRoutes()
        XCTAssertTrue(midiIO.routes.isEmpty)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() {
        let invalidDevice = createMockDevice(supportsInput: false, supportsOutput: false)
        
        XCTAssertNoThrow(try midiIO.initialize())
        
        // Test connecting to device that doesn't support input
        XCTAssertThrowsError(try midiIO.connectInputDevice(invalidDevice))
        
        // Test connecting to device that doesn't support output
        XCTAssertThrowsError(try midiIO.connectOutputDevice(invalidDevice))
        
        // Test sending message without starting
        let message = MIDIMessage(type: .noteOn, channel: 0, data1: 60, data2: 100)
        XCTAssertThrowsError(try midiIO.sendMessage(message, to: invalidDevice))
    }
    
    // MARK: - Performance Tests
    
    func testInitializationPerformance() {
        measure {
            let testMIDIIO = MIDIIOModule(config: config)
            try? testMIDIIO.initialize()
        }
    }
    
    func testMessageProcessingPerformance() {
        XCTAssertNoThrow(try midiIO.initialize())
        XCTAssertNoThrow(try midiIO.start())
        
        let message = MIDIMessage(type: .noteOn, channel: 0, data1: 60, data2: 100)
        
        measure {
            for _ in 0..<1000 {
                midiIO.routeMessage(message)
            }
        }
        
        midiIO.stop()
    }
    
    func testRouteManagementPerformance() {
        measure {
            for i in 0..<100 {
                let route = MIDIRoute(name: "Route \(i)", priority: i)
                midiIO.addRoute(route)
            }
            
            midiIO.clearRoutes()
        }
    }
    
    // MARK: - Statistics Tests
    
    func testStatistics() {
        XCTAssertEqual(midiIO.statistics.messagesReceived, 0)
        XCTAssertEqual(midiIO.statistics.messagesSent, 0)
        XCTAssertEqual(midiIO.statistics.errors, 0)
        
        // Statistics would be updated during actual MIDI operations
        // This test verifies the initial state
    }
    
    // MARK: - Helper Methods
    
    private func createMockDevice(supportsInput: Bool, supportsOutput: Bool) -> EnhancedMIDIDevice {
        var device = EnhancedMIDIDevice(
            name: "Mock Device",
            manufacturer: "Test",
            model: "Mock",
            uniqueID: 12345,
            deviceType: .controller,
            connectionType: .usb,
            isOnline: true,
            isConnected: false
        )
        
        device.capabilities.supportsInput = supportsInput
        device.capabilities.supportsOutput = supportsOutput
        
        return device
    }
}

// MARK: - MIDI I/O Support Tests

final class MIDIIOSupportTests: XCTestCase {
    
    // MARK: - Statistics Tests
    
    func testMIDIIOStatistics() {
        var stats = MIDIIOStatistics()
        
        // Test initial state
        XCTAssertEqual(stats.messagesReceived, 0)
        XCTAssertEqual(stats.messagesSent, 0)
        XCTAssertEqual(stats.errors, 0)
        
        // Test recording operations
        stats.recordMessageReceived(bytes: 3)
        XCTAssertEqual(stats.messagesReceived, 1)
        XCTAssertEqual(stats.bytesReceived, 3)
        
        stats.recordMessageSent(bytes: 3)
        XCTAssertEqual(stats.messagesSent, 1)
        XCTAssertEqual(stats.bytesSent, 3)
        
        stats.recordError()
        XCTAssertEqual(stats.errors, 1)
        
        stats.recordDroppedMessage()
        XCTAssertEqual(stats.droppedMessages, 1)
        
        stats.recordLatency(5.0)
        XCTAssertEqual(stats.averageLatency, 5.0, accuracy: 0.01)
        XCTAssertEqual(stats.maxLatency, 5.0, accuracy: 0.01)
        
        // Test reset
        stats.reset()
        XCTAssertEqual(stats.messagesReceived, 0)
        XCTAssertEqual(stats.messagesSent, 0)
        XCTAssertEqual(stats.errors, 0)
    }
    
    // MARK: - Error Tests
    
    func testMIDIIOErrors() {
        let initError = MIDIIOError.initializationFailed("Test error")
        XCTAssertNotNil(initError.errorDescription)
        XCTAssertTrue(initError.errorDescription!.contains("initialization failed"))
        
        let deviceError = MIDIIOError.deviceError("Device not found")
        XCTAssertNotNil(deviceError.errorDescription)
        XCTAssertTrue(deviceError.errorDescription!.contains("device error"))
        
        let bufferError = MIDIIOError.bufferOverflow
        XCTAssertNotNil(bufferError.errorDescription)
        XCTAssertTrue(bufferError.errorDescription!.contains("buffer overflow"))
    }
}
