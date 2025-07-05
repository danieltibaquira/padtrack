// ExternalControllerManager.swift
// DigitonePad - MIDIModule
//
// Manager for external MIDI controllers with preset mappings and automatic detection

import Foundation
import CoreMIDI
import MachineProtocols

/// Manager for external MIDI controllers
public final class ExternalControllerManager: @unchecked Sendable {
    
    // MARK: - Properties
    
    weak var delegate: ExternalControllerManagerDelegate?
    
    private let lock = NSLock()
    private var detectedControllers: [ExternalController] = []
    private var controllerMappings: [String: ControllerMapping] = [:]
    private var deviceRouting: [String: RoutingConfiguration] = [:]
    private var lastCCValues: [ChannelCCKey: UInt8] = [:]
    private var autoLEDSync: Set<String> = []
    
    // Message routing
    private var routedMessages: [(message: MIDIMessage, destination: RoutingDestination)] = []
    private var processedMessageCount = 0
    private var droppedMessageCount = 0
    
    // MARK: - Initialization
    
    public init() {
        setupBuiltInControllerMappings()
    }
    
    // MARK: - Public Interface
    
    /// Get list of detected controllers
    public var allDetectedControllers: [ExternalController] {
        lock.lock()
        defer { lock.unlock() }
        return Array(detectedControllers)
    }
    
    /// Add a MIDI device for controller detection
    public func addMIDIDevice(_ device: MIDIDeviceProtocol) {
        let controller = detectControllerType(device)
        
        lock.lock()
        defer { lock.unlock() }
        
        detectedControllers.append(controller)
        
        // Load preset mapping if available
        if let presetMapping = getBuiltInMapping(for: device) {
            controllerMappings[device.name] = presetMapping
        }
        
        delegate?.controllerManager(self, didDetectController: controller)
    }
    
    /// Remove a MIDI device
    public func removeMIDIDevice(_ device: MIDIDeviceProtocol) {
        lock.lock()
        defer { lock.unlock() }
        
        if let index = detectedControllers.firstIndex(where: { $0.name == device.name }) {
            let controller = detectedControllers.remove(at: index)
            controllerMappings.removeValue(forKey: device.name)
            deviceRouting.removeValue(forKey: device.name)
            autoLEDSync.remove(device.name)
            
            delegate?.controllerManager(self, didRemoveController: controller)
        }
    }
    
    /// Get preset mapping for a device
    public func getPresetMapping(for device: MIDIDeviceProtocol) -> ControllerMapping? {
        lock.lock()
        defer { lock.unlock() }
        return controllerMappings[device.name]
    }
    
    /// Set custom controller mapping
    public func setControllerMapping(_ device: MIDIDeviceProtocol, mapping: ControllerMapping) {
        lock.lock()
        defer { lock.unlock() }
        controllerMappings[device.name] = mapping
    }
    
    /// Get controller mapping
    public func getMapping(for device: MIDIDeviceProtocol) -> ControllerMapping? {
        lock.lock()
        defer { lock.unlock() }
        return controllerMappings[device.name]
    }
    
    // MARK: - Message Routing
    
    /// Route controller to destination
    public func routeController(_ device: MIDIDeviceProtocol, to destination: RoutingDestination, for messageType: MessageType = .all) {
        lock.lock()
        defer { lock.unlock() }
        
        if deviceRouting[device.name] == nil {
            deviceRouting[device.name] = RoutingConfiguration()
        }
        
        switch messageType {
        case .notes:
            deviceRouting[device.name]?.noteDestination = destination
        case .cc:
            deviceRouting[device.name]?.ccDestination = destination
        case .all:
            deviceRouting[device.name]?.noteDestination = destination
            deviceRouting[device.name]?.ccDestination = destination
        }
    }
    
    /// Process incoming message from controller
    public func processControllerMessage(_ message: MIDIMessage, from device: MIDIDeviceProtocol) {
        // Update last CC values tracking
        if message.type == .controlChange {
            let key = ChannelCCKey(channel: message.channel, cc: message.data1)
            lock.lock()
            lastCCValues[key] = message.data2
            lock.unlock()
        }
        
        // Route message based on configuration
        if let routing = deviceRouting[device.name] {
            let destination = getDestinationForMessage(message, routing: routing)
            
            lock.lock()
            routedMessages.append((message: message, destination: destination))
            processedMessageCount += 1
            lock.unlock()
            
            delegate?.controllerManager(self, routedMessage: message, to: destination)
        } else {
            lock.lock()
            droppedMessageCount += 1
            lock.unlock()
            
            delegate?.controllerManager(self, droppedMessage: message)
        }
        
        // Handle LED feedback if enabled
        if autoLEDSync.contains(device.name) {
            handleAutoLEDFeedback(message, device: device)
        }
    }
    
    /// Get last CC value for a controller/channel
    public func getLastCCValue(_ controller: UInt8, channel: UInt8) -> UInt8? {
        lock.lock()
        defer { lock.unlock() }
        
        let key = ChannelCCKey(channel: channel, cc: controller)
        return lastCCValues[key]
    }
    
    /// Get all messages from a specific device
    public func getMessagesFromDevice(_ device: MIDIDeviceProtocol) -> [MIDIMessage] {
        lock.lock()
        defer { lock.unlock() }
        
        // In a real implementation, this would track messages per device
        // For now, return all routed messages (simplified)
        return routedMessages.map { $0.message }
    }
    
    // MARK: - LED Feedback
    
    /// Set LED color for a pad
    public func setPadLED(row: Int, column: Int, color: LEDColor, on device: MIDIDeviceProtocol) {
        guard let mapping = controllerMappings[device.name] else { return }
        
        if let message = mapping.createLEDMessage(row: row, column: column, color: color) {
            device.send(message)
        }
    }
    
    /// Enable automatic LED synchronization
    public func enableAutoLEDSync(for device: MIDIDeviceProtocol) {
        lock.lock()
        defer { lock.unlock() }
        autoLEDSync.insert(device.name)
    }
    
    /// Disable automatic LED synchronization
    public func disableAutoLEDSync(for device: MIDIDeviceProtocol) {
        lock.lock()
        defer { lock.unlock() }
        autoLEDSync.remove(device.name)
    }
    
    // MARK: - Statistics
    
    /// Get processing statistics
    public func getStatistics() -> ControllerManagerStatistics {
        lock.lock()
        defer { lock.unlock() }
        
        return ControllerManagerStatistics(
            detectedControllers: detectedControllers.count,
            processedMessages: processedMessageCount,
            droppedMessages: droppedMessageCount,
            activeRoutings: deviceRouting.count
        )
    }
    
    // MARK: - Private Implementation
    
    private func detectControllerType(_ device: MIDIDeviceProtocol) -> ExternalController {
        let controllerType = inferControllerType(name: device.name, manufacturer: device.manufacturer)
        
        return ExternalController(
            name: device.name,
            manufacturer: device.manufacturer,
            type: controllerType,
            isConnected: device.isConnected,
            capabilities: getControllerCapabilities(type: controllerType)
        )
    }
    
    private func inferControllerType(name: String, manufacturer: String) -> ControllerType {
        let lowercaseName = name.lowercased()
        let lowercaseManufacturer = manufacturer.lowercased()
        
        // LaunchPad detection
        if lowercaseName.contains("launchpad") || lowercaseManufacturer.contains("novation") {
            if lowercaseName.contains("pro") {
                return .launchPadPro
            } else if lowercaseName.contains("mini") {
                return .launchPadMini
            } else {
                return .launchPadMk2
            }
        }
        
        // Push detection
        if lowercaseName.contains("push") || lowercaseManufacturer.contains("ableton") {
            if lowercaseName.contains("2") {
                return .push2
            } else {
                return .push1
            }
        }
        
        // Arturia detection
        if lowercaseManufacturer.contains("arturia") {
            if lowercaseName.contains("keylab") {
                return .keyLab
            } else if lowercaseName.contains("beatstep") {
                return .beatStep
            } else {
                return .arturiaGeneric
            }
        }
        
        // Akai detection
        if lowercaseManufacturer.contains("akai") {
            if lowercaseName.contains("mpk") {
                return .mpkMini
            } else if lowercaseName.contains("apc") {
                return .apcMini
            } else {
                return .akaiGeneric
            }
        }
        
        return .generic
    }
    
    private func getControllerCapabilities(type: ControllerType) -> ControllerCapabilities {
        switch type {
        case .launchPadPro:
            return ControllerCapabilities(
                hasPads: true,
                padCount: 64,
                hasEncoders: false,
                encoderCount: 0,
                hasSliders: false,
                sliderCount: 0,
                hasLEDs: true,
                ledType: .rgb,
                supportsSysEx: true
            )
            
        case .push2:
            return ControllerCapabilities(
                hasPads: true,
                padCount: 64,
                hasEncoders: true,
                encoderCount: 8,
                hasSliders: false,
                sliderCount: 0,
                hasLEDs: true,
                ledType: .rgb,
                supportsSysEx: true
            )
            
        case .keyLab:
            return ControllerCapabilities(
                hasPads: true,
                padCount: 16,
                hasEncoders: true,
                encoderCount: 8,
                hasSliders: true,
                sliderCount: 9,
                hasLEDs: true,
                ledType: .monochrome,
                supportsSysEx: true
            )
            
        case .mpkMini:
            return ControllerCapabilities(
                hasPads: true,
                padCount: 8,
                hasEncoders: true,
                encoderCount: 8,
                hasSliders: false,
                sliderCount: 0,
                hasLEDs: false,
                ledType: .none,
                supportsSysEx: false
            )
            
        default:
            return ControllerCapabilities(
                hasPads: false,
                padCount: 0,
                hasEncoders: false,
                encoderCount: 0,
                hasSliders: false,
                sliderCount: 0,
                hasLEDs: false,
                ledType: .none,
                supportsSysEx: false
            )
        }
    }
    
    private func setupBuiltInControllerMappings() {
        // These would be loaded from configuration files or built-in presets
        // For now, we'll create some basic mappings programmatically
    }
    
    private func getBuiltInMapping(for device: MIDIDeviceProtocol) -> ControllerMapping? {
        let controllerType = inferControllerType(name: device.name, manufacturer: device.manufacturer)
        
        switch controllerType {
        case .launchPadPro:
            return LaunchPadProMapping()
        case .push2:
            return Push2Mapping()
        case .keyLab:
            return KeyLabMapping()
        case .mpkMini:
            return MPKMiniMapping()
        default:
            return nil
        }
    }
    
    private func getDestinationForMessage(_ message: MIDIMessage, routing: RoutingConfiguration) -> RoutingDestination {
        switch message.type {
        case .noteOn, .noteOff:
            return routing.noteDestination
        case .controlChange:
            return routing.ccDestination
        default:
            return routing.ccDestination
        }
    }
    
    private func handleAutoLEDFeedback(_ message: MIDIMessage, device: MIDIDeviceProtocol) {
        // Automatically sync LED state with button presses
        if message.type == .noteOn {
            let note = message.data1
            let velocity = message.data2
            
            // Simple LED feedback - turn on LED when note is pressed
            if velocity > 0 {
                device.send(MIDIMessage(type: .noteOn, channel: 1, data1: note, data2: velocity))
            } else {
                device.send(MIDIMessage(type: .noteOff, channel: 1, data1: note, data2: 0))
            }
        }
    }
}

// MARK: - Supporting Types

/// External controller representation
public struct ExternalController {
    public let name: String
    public let manufacturer: String
    public let type: ControllerType
    public let isConnected: Bool
    public let capabilities: ControllerCapabilities
}

/// Controller type enumeration
public enum ControllerType: String, CaseIterable {
    case launchPadPro = "launchpad_pro"
    case launchPadMk2 = "launchpad_mk2"
    case launchPadMini = "launchpad_mini"
    case push1 = "push_1"
    case push2 = "push_2"
    case keyLab = "keylab"
    case beatStep = "beatstep"
    case arturiaGeneric = "arturia_generic"
    case mpkMini = "mpk_mini"
    case apcMini = "apc_mini"
    case akaiGeneric = "akai_generic"
    case generic = "generic"
}

/// Controller capabilities
public struct ControllerCapabilities {
    public let hasPads: Bool
    public let padCount: Int
    public let hasEncoders: Bool
    public let encoderCount: Int
    public let hasSliders: Bool
    public let sliderCount: Int
    public let hasLEDs: Bool
    public let ledType: LEDType
    public let supportsSysEx: Bool
}

/// LED types
public enum LEDType {
    case none
    case monochrome
    case rgb
}

/// LED colors
public enum LEDColor {
    case off
    case red
    case green
    case blue
    case yellow
    case cyan
    case magenta
    case white
    case custom(r: UInt8, g: UInt8, b: UInt8)
}

/// Message types for routing
public enum MessageType {
    case notes
    case cc
    case all
}

/// Routing destinations
public enum RoutingDestination: Equatable {
    case track(Int)
    case global
    case effects
    case mixer
}

/// Routing configuration
private struct RoutingConfiguration {
    var noteDestination: RoutingDestination = .track(1)
    var ccDestination: RoutingDestination = .global
}

/// Channel/CC key for tracking values
private struct ChannelCCKey: Hashable {
    let channel: UInt8
    let cc: UInt8
}

/// Manager statistics
public struct ControllerManagerStatistics {
    public let detectedControllers: Int
    public let processedMessages: Int
    public let droppedMessages: Int
    public let activeRoutings: Int
}

// MARK: - Controller Mapping Protocol

/// Base protocol for controller mappings
public protocol ControllerMapping {
    func createLEDMessage(row: Int, column: Int, color: LEDColor) -> MIDIMessage?
}

// MARK: - Built-in Controller Mappings

/// LaunchPad Pro mapping
public class LaunchPadProMapping: ControllerMapping {
    public func createLEDMessage(row: Int, column: Int, color: LEDColor) -> MIDIMessage? {
        // LaunchPad Pro uses SysEx for RGB LED control
        let note = UInt8(row * 8 + column)
        
        switch color {
        case .off:
            return .noteOff(channel: 1, note: note, velocity: 0)
        case .red:
            return .noteOn(channel: 1, note: note, velocity: 5)
        case .green:
            return .noteOn(channel: 1, note: note, velocity: 21)
        case .blue:
            return .noteOn(channel: 1, note: note, velocity: 41)
        case .yellow:
            return .noteOn(channel: 1, note: note, velocity: 13)
        default:
            return .noteOn(channel: 1, note: note, velocity: 127)
        }
    }
    
    public func padToNote(row: Int, column: Int) -> UInt8 {
        return UInt8(row * 8 + column + 36) // Start at C2
    }
    
    public func sideButtonCC(index: Int) -> UInt8 {
        return UInt8(89 + index) // Side buttons start at CC 89
    }
}

/// Push 2 mapping
public class Push2Mapping: ControllerMapping {
    let velocityCurve: ControllerVelocityCurve = .linear
    
    public func createLEDMessage(row: Int, column: Int, color: LEDColor) -> MIDIMessage? {
        // Push 2 uses SysEx for RGB control
        let note = UInt8(row * 8 + column + 36)
        
        switch color {
        case .off:
            return .noteOff(channel: 1, note: note, velocity: 0)
        default:
            return .noteOn(channel: 1, note: note, velocity: 127)
        }
    }
    
    public func encoderCC(index: Int) -> UInt8 {
        return UInt8(71 + index) // Encoders start at CC 71
    }
}

/// KeyLab mapping
public class KeyLabMapping: ControllerMapping {
    public func createLEDMessage(row: Int, column: Int, color: LEDColor) -> MIDIMessage? {
        // KeyLab uses simpler LED control
        let note = UInt8(row * 4 + column + 36)
        
        switch color {
        case .off:
            return .noteOff(channel: 1, note: note, velocity: 0)
        default:
            return .noteOn(channel: 1, note: note, velocity: 127)
        }
    }
}

/// MPK Mini mapping
public class MPKMiniMapping: ControllerMapping {
    public func createLEDMessage(row: Int, column: Int, color: LEDColor) -> MIDIMessage? {
        // MPK Mini doesn't have LEDs
        return nil
    }
}

/// Custom controller mapping
public class CustomControllerMapping: ControllerMapping {
    private var padMappings: [String: UInt8] = [:]
    private var encoderMappings: [Int: UInt8] = [:]
    private var sliderMappings: [Int: UInt8] = [:]
    
    public func createLEDMessage(row: Int, column: Int, color: LEDColor) -> MIDIMessage? {
        // Custom implementation depends on specific controller
        return nil
    }
    
    public func addPadMapping(note: UInt8, row: Int, column: Int) {
        padMappings["\(row)-\(column)"] = note
    }
    
    public func addEncoderMapping(cc: UInt8, index: Int) {
        encoderMappings[index] = cc
    }
    
    public func addSliderMapping(cc: UInt8, index: Int) {
        sliderMappings[index] = cc
    }
}

/// Velocity curve types for controllers
public enum ControllerVelocityCurve {
    case linear
    case exponential
    case logarithmic
}

// MARK: - Delegate Protocol

/// External controller manager delegate
public protocol ExternalControllerManagerDelegate: AnyObject {
    func controllerManager(_ manager: ExternalControllerManager, didDetectController controller: ExternalController)
    func controllerManager(_ manager: ExternalControllerManager, didRemoveController controller: ExternalController)
    func controllerManager(_ manager: ExternalControllerManager, routedMessage message: MIDIMessage, to destination: RoutingDestination)
    func controllerManager(_ manager: ExternalControllerManager, droppedMessage: MIDIMessage)
}

// MARK: - MIDI Device Protocol Extension

/// Protocol for MIDI devices that can be controlled
public protocol MIDIDeviceProtocol: AnyObject {
    var name: String { get }
    var manufacturer: String { get }
    var isConnected: Bool { get }
    
    func send(_ message: MIDIMessage)
}

// MARK: - MIDIMessage Pattern Matching

/// Pattern matching support for MIDIMessage
public extension MIDIMessage {
    enum MessagePattern {
        case noteOn(channel: UInt8, note: UInt8, velocity: UInt8)
        case noteOff(channel: UInt8, note: UInt8, velocity: UInt8)
        case controlChange(channel: UInt8, controller: UInt8, value: UInt8)
        case programChange(channel: UInt8, program: UInt8)
        case pitchBend(channel: UInt8, lsb: UInt8, msb: UInt8)
        case sysex(data: [UInt8])
    }
    
    var pattern: MessagePattern {
        switch type {
        case .noteOn:
            return .noteOn(channel: channel, note: data1, velocity: data2)
        case .noteOff:
            return .noteOff(channel: channel, note: data1, velocity: data2)
        case .controlChange:
            return .controlChange(channel: channel, controller: data1, value: data2)
        case .programChange:
            return .programChange(channel: channel, program: data1)
        case .pitchBend:
            return .pitchBend(channel: channel, lsb: data1, msb: data2)
        case .systemExclusive:
            return .sysex(data: [data1, data2]) // Simplified
        default:
            return .controlChange(channel: channel, controller: data1, value: data2)
        }
    }
}