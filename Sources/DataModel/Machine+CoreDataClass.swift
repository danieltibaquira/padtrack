//
//  Machine+CoreDataClass.swift
//  PadTrack
//
//  Created by PadTrack on 2024.
//

import Foundation
import CoreData

@objc(Machine)
public class Machine: NSManagedObject {
    
    // MARK: - Convenience Initializers
    
    convenience init(context: NSManagedObjectContext, name: String, typeName: String) {
        self.init(context: context)
        self.machineID = UUID()
        self.name = name
        self.typeName = typeName
        self.isEnabled = true
        self.bypass = false
        self.createdAt = Date()
        self.lastModified = Date()
    }
    
    // MARK: - Computed Properties
    
    /// Check if machine has been modified since creation
    var isModified: Bool {
        guard let created = createdAt, let modified = lastModified else { return false }
        return modified > created
    }
    
    /// Check if machine is effectively processing (enabled and not bypassed)
    var isProcessing: Bool {
        return isEnabled && !bypass
    }
    
    /// Get display name for UI
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return typeName ?? "Unknown Machine"
    }
    
    /// Check if machine has binary parameter data
    var hasParameterData: Bool {
        return parameterData != nil && !(parameterData?.isEmpty ?? true)
    }
    
    /// Get parameter data size in bytes
    var parameterDataSize: Int {
        return parameterData?.count ?? 0
    }
    
    // MARK: - Machine Type Identification
    
    /// Check if this is a voice machine
    var isVoiceMachine: Bool {
        return self is VoiceMachine
    }
    
    /// Check if this is a filter machine
    var isFilterMachine: Bool {
        return self is FilterMachine
    }
    
    /// Check if this is an effect machine
    var isFXMachine: Bool {
        return self is FXMachine
    }
    
    /// Get machine category based on type
    var category: MachineCategory {
        if isVoiceMachine {
            return .voice
        } else if isFilterMachine {
            return .filter
        } else if isFXMachine {
            return .effects
        } else {
            return .other
        }
    }
    
    // MARK: - Enable/Disable Management
    
    /// Enable the machine
    func enable() {
        isEnabled = true
        lastModified = Date()
    }
    
    /// Disable the machine
    func disable() {
        isEnabled = false
        lastModified = Date()
    }
    
    /// Toggle enabled state
    func toggleEnabled() {
        isEnabled.toggle()
        lastModified = Date()
    }
    
    /// Set enabled state explicitly
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        lastModified = Date()
    }
    
    // MARK: - Bypass Management
    
    /// Bypass the machine (pass signal through unchanged)
    func enableBypass() {
        bypass = true
        lastModified = Date()
    }
    
    /// Remove bypass (process signal normally)
    func disableBypass() {
        bypass = false
        lastModified = Date()
    }
    
    /// Toggle bypass state
    func toggleBypass() {
        bypass.toggle()
        lastModified = Date()
    }
    
    /// Set bypass state explicitly
    func setBypass(_ bypassed: Bool) {
        bypass = bypassed
        lastModified = Date()
    }
    
    // MARK: - Parameter Data Management
    
    /// Set parameter data from dictionary
    func setParameterData(from parameters: [String: Any]) throws {
        do {
            let data = try JSONSerialization.data(withJSONObject: parameters, options: [])
            parameterData = data
            lastModified = Date()
        } catch {
            throw MachineError.parameterSerializationFailed(error)
        }
    }
    
    /// Get parameter data as dictionary
    func getParameterData() throws -> [String: Any] {
        guard let data = parameterData else {
            return [:]
        }
        
        do {
            guard let parameters = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw MachineError.invalidParameterData
            }
            return parameters
        } catch {
            throw MachineError.parameterDeserializationFailed(error)
        }
    }
    
    /// Set specific parameter value
    func setParameter(_ name: String, value: Any) throws {
        var parameters = try getParameterData()
        parameters[name] = value
        try setParameterData(from: parameters)
    }
    
    /// Get specific parameter value
    func getParameter<T>(_ name: String, type: T.Type) -> T? {
        guard let parameters = try? getParameterData() else { return nil }
        return parameters[name] as? T
    }
    
    /// Remove specific parameter
    func removeParameter(_ name: String) throws {
        var parameters = try getParameterData()
        parameters.removeValue(forKey: name)
        try setParameterData(from: parameters)
    }
    
    /// Clear all parameter data
    func clearParameterData() {
        parameterData = nil
        lastModified = Date()
    }
    
    // MARK: - Machine Operations
    
    /// Set machine name with validation
    func setName(_ newName: String) throws {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw MachineError.emptyName
        }
        name = trimmedName
        lastModified = Date()
    }
    
    /// Set machine type with validation
    func setTypeName(_ newTypeName: String) throws {
        let trimmedType = newTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedType.isEmpty else {
            throw MachineError.emptyTypeName
        }
        typeName = trimmedType
        lastModified = Date()
    }
    
    /// Copy settings from another machine
    func copySettings(from source: Machine) {
        name = source.name
        typeName = source.typeName
        isEnabled = source.isEnabled
        bypass = source.bypass
        parameterData = source.parameterData
        lastModified = Date()
    }
    
    /// Create a duplicate of this machine
    func duplicate(in context: NSManagedObjectContext) -> Machine {
        let duplicate = Machine(context: context, 
                              name: "\(name ?? "Machine") Copy", 
                              typeName: typeName ?? "Unknown")
        duplicate.isEnabled = self.isEnabled
        duplicate.bypass = self.bypass
        duplicate.parameterData = self.parameterData
        return duplicate
    }
    
    /// Reset machine to default state
    func resetToDefaults() {
        isEnabled = true
        bypass = false
        clearParameterData()
        lastModified = Date()
    }
    
    // MARK: - Preset Management
    
    /// Check if machine has associated presets
    var hasPresets: Bool {
        guard let presets = presets as? Set<Preset> else { return false }
        return !presets.isEmpty
    }
    
    /// Get all presets sorted by name
    var sortedPresets: [Preset] {
        guard let presets = presets as? Set<Preset> else { return [] }
        return presets.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
    
    /// Count of associated presets
    var presetCount: Int {
        return presets?.count ?? 0
    }
    
    // MARK: - Export and Metadata
    
    /// Generate export metadata
    func exportMetadata() -> [String: Any] {
        var metadata: [String: Any] = [
            "machineID": machineID?.uuidString ?? "",
            "name": name ?? "",
            "typeName": typeName ?? "",
            "category": category.rawValue,
            "isEnabled": isEnabled,
            "bypass": bypass,
            "isProcessing": isProcessing,
            "hasParameterData": hasParameterData,
            "parameterDataSize": parameterDataSize,
            "presetCount": presetCount,
            "createdAt": createdAt?.timeIntervalSince1970 ?? 0,
            "lastModified": lastModified?.timeIntervalSince1970 ?? 0
        ]
        
        // Include parameter data if available
        if let parameters = try? getParameterData() {
            metadata["parameters"] = parameters
        }
        
        return metadata
    }
    
    // MARK: - Audio Processing Interface
    
    /// Process audio - to be overridden by subclasses
    func processAudio(inputBuffer: UnsafePointer<Float>, 
                     outputBuffer: UnsafeMutablePointer<Float>, 
                     frameCount: Int) {
        // Base implementation: pass through if bypassed, silence if disabled
        if !isProcessing {
            // If disabled, output silence
            if !isEnabled {
                for i in 0..<frameCount {
                    outputBuffer[i] = 0.0
                }
            } else {
                // If bypassed, copy input to output
                for i in 0..<frameCount {
                    outputBuffer[i] = inputBuffer[i]
                }
            }
        }
        // Subclasses should override this method for actual processing
    }
    
    /// Initialize audio processing - to be overridden by subclasses
    func initializeAudio(sampleRate: Double, bufferSize: Int) {
        // Base implementation does nothing
        // Subclasses should override this method
    }
    
    /// Clean up audio processing - to be overridden by subclasses
    func cleanupAudio() {
        // Base implementation does nothing
        // Subclasses should override this method
    }
    
    // MARK: - Validation
    
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateMachine()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateMachine()
    }
    
    private func validateMachine() throws {
        // Validate name
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MachineError.emptyName
        }
        
        // Validate type name
        guard let typeName = typeName, !typeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MachineError.emptyTypeName
        }
    }
}

// MARK: - Machine Categories

enum MachineCategory: String, CaseIterable {
    case voice = "voice"
    case filter = "filter" 
    case effects = "effects"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .voice:
            return "Voice"
        case .filter:
            return "Filter"
        case .effects:
            return "Effects"
        case .other:
            return "Other"
        }
    }
}

// MARK: - Machine Errors

enum MachineError: LocalizedError {
    case emptyName
    case emptyTypeName
    case parameterSerializationFailed(Error)
    case parameterDeserializationFailed(Error)
    case invalidParameterData
    
    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Machine name cannot be empty"
        case .emptyTypeName:
            return "Machine type name cannot be empty"
        case .parameterSerializationFailed(let error):
            return "Failed to serialize parameters: \(error.localizedDescription)"
        case .parameterDeserializationFailed(let error):
            return "Failed to deserialize parameters: \(error.localizedDescription)"
        case .invalidParameterData:
            return "Invalid parameter data format"
        }
    }
} 