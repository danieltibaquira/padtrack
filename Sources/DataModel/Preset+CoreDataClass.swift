//
//  Preset+CoreDataClass.swift
//  PadTrack
//
//  Created by PadTrack on 2024.
//

import Foundation
import CoreData

@objc(Preset)
public class Preset: NSManagedObject {
    
    // MARK: - Convenience Initializers
    
    convenience init(context: NSManagedObjectContext, name: String, machineTypeName: String) {
        self.init(context: context)
        self.presetID = UUID()
        self.name = name
        self.machineTypeName = machineTypeName
        self.isUserCreated = true
        self.isShared = false
        self.createdAt = Date()
        self.lastModified = Date()
    }
    
    convenience init(context: NSManagedObjectContext, name: String, machine: Machine) {
        self.init(context: context, name: name, machineTypeName: machine.typeName ?? "Unknown")
        
        // Copy machine's current parameter data
        if let parameterData = machine.parameterData {
            self.parameterData = parameterData
        }
        
        // Set additional properties from machine
        self.author = "User" // Default author for user-created presets
        self.version = "1.0"
    }
    
    // MARK: - Computed Properties
    
    /// Check if preset has been modified since creation
    var isModified: Bool {
        guard let created = createdAt, let modified = lastModified else { return false }
        return modified > created
    }
    
    /// Check if preset has parameter data
    var hasParameterData: Bool {
        return parameterData != nil && !(parameterData?.isEmpty ?? true)
    }
    
    /// Get parameter data size in bytes
    var parameterDataSize: Int {
        return parameterData?.count ?? 0
    }
    
    /// Get display name for UI
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return "Unnamed Preset"
    }
    
    /// Get full display name with machine type
    var fullDisplayName: String {
        let machineName = machineTypeName?.capitalized ?? "Unknown"
        return "\(displayName) (\(machineName))"
    }
    
    /// Check if this is a factory preset
    var isFactoryPreset: Bool {
        return !isUserCreated
    }
    
    /// Get preset category based on machine type
    var category: PresetCategory {
        guard let typeName = machineTypeName?.lowercased() else { return .other }
        
        if typeName.contains("voice") || typeName.contains("synth") || typeName.contains("osc") {
            return .voice
        } else if typeName.contains("filter") {
            return .filter
        } else if typeName.contains("fx") || typeName.contains("effect") || 
                  typeName.contains("reverb") || typeName.contains("delay") {
            return .effects
        } else if typeName.contains("drum") || typeName.contains("perc") {
            return .drum
        } else {
            return .other
        }
    }
    
    /// Calculate preset complexity based on parameter count
    var complexityScore: Int {
        guard let parameters = try? getParameterData() else { return 0 }
        let parameterCount = parameters.count
        
        // Simple scoring: 0-5 params = 1, 6-15 = 2, 16-30 = 3, 31+ = 4
        if parameterCount <= 5 {
            return 1
        } else if parameterCount <= 15 {
            return 2
        } else if parameterCount <= 30 {
            return 3
        } else {
            return 4
        }
    }
    
    // MARK: - Parameter Data Management
    
    /// Set parameter data from dictionary
    func setParameterData(from parameters: [String: Any]) throws {
        do {
            let data = try JSONSerialization.data(withJSONObject: parameters, options: [])
            parameterData = data
            lastModified = Date()
        } catch {
            throw PresetError.parameterSerializationFailed(error)
        }
    }
    
    /// Get parameter data as dictionary
    func getParameterData() throws -> [String: Any] {
        guard let data = parameterData else {
            return [:]
        }
        
        do {
            guard let parameters = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw PresetError.invalidParameterData
            }
            return parameters
        } catch {
            throw PresetError.parameterDeserializationFailed(error)
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
    
    /// Get parameter names
    var parameterNames: [String] {
        guard let parameters = try? getParameterData() else { return [] }
        return Array(parameters.keys).sorted()
    }
    
    /// Get parameter count
    var parameterCount: Int {
        guard let parameters = try? getParameterData() else { return 0 }
        return parameters.count
    }
    
    // MARK: - Preset Management
    
    /// Set preset name with validation
    func setName(_ newName: String) throws {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw PresetError.emptyName
        }
        name = trimmedName
        lastModified = Date()
    }
    
    /// Set machine type name with validation
    func setMachineTypeName(_ typeName: String) throws {
        let trimmedType = typeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedType.isEmpty else {
            throw PresetError.emptyMachineTypeName
        }
        machineTypeName = trimmedType
        lastModified = Date()
    }
    
    /// Update metadata
    func updateMetadata(author: String? = nil, 
                       description: String? = nil, 
                       tags: String? = nil,
                       version: String? = nil) {
        if let author = author {
            self.author = author
        }
        if let description = description {
            self.presetDescription = description
        }
        if let tags = tags {
            self.tags = tags
        }
        if let version = version {
            self.version = version
        }
        lastModified = Date()
    }
    
    /// Mark preset as shared
    func markAsShared() {
        isShared = true
        lastModified = Date()
    }
    
    /// Mark preset as private
    func markAsPrivate() {
        isShared = false
        lastModified = Date()
    }
    
    /// Toggle shared state
    func toggleShared() {
        isShared.toggle()
        lastModified = Date()
    }
    
    // MARK: - Preset Operations
    
    /// Apply this preset to a machine
    func applyTo(machine: Machine) throws {
        guard machine.typeName == machineTypeName else {
            throw PresetError.incompatibleMachineType(expected: machineTypeName ?? "Unknown", 
                                                    actual: machine.typeName ?? "Unknown")
        }
        
        // Copy parameter data to machine
        if let data = parameterData {
            machine.parameterData = data
            machine.lastModified = Date()
        }
    }
    
    /// Create preset from machine's current state
    func captureFrom(machine: Machine) throws {
        guard machine.typeName == machineTypeName else {
            throw PresetError.incompatibleMachineType(expected: machineTypeName ?? "Unknown",
                                                    actual: machine.typeName ?? "Unknown")
        }
        
        // Copy machine's parameter data
        parameterData = machine.parameterData
        lastModified = Date()
    }
    
    /// Create a duplicate of this preset
    func duplicate(in context: NSManagedObjectContext, name: String? = nil) -> Preset {
        let duplicatedPreset = Preset(context: context, 
                                    name: name ?? "\(self.name ?? "Preset") Copy",
                                    machineTypeName: machineTypeName ?? "Unknown")
        
        // Copy all properties
        duplicatedPreset.parameterData = self.parameterData
        duplicatedPreset.author = self.author
        duplicatedPreset.presetDescription = self.presetDescription
        duplicatedPreset.tags = self.tags
        duplicatedPreset.version = self.version
        duplicatedPreset.isUserCreated = true  // Duplicates are always user-created
        duplicatedPreset.isShared = false      // Duplicates start as private
        
        return duplicatedPreset
    }
    
    /// Compare with another preset
    func isEquivalent(to other: Preset) -> Bool {
        guard machineTypeName == other.machineTypeName else { return false }
        
        // Compare parameter data
        let thisData = parameterData ?? Data()
        let otherData = other.parameterData ?? Data()
        return thisData == otherData
    }
    
    // MARK: - Tag Management
    
    /// Get tags as array
    var tagArray: [String] {
        guard let tags = tags else { return [] }
        return tags.components(separatedBy: ",")
                  .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                  .filter { !$0.isEmpty }
    }
    
    /// Set tags from array
    func setTags(_ tagArray: [String]) {
        let cleanTags = tagArray.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                              .filter { !$0.isEmpty }
        tags = cleanTags.joined(separator: ", ")
        lastModified = Date()
    }
    
    /// Add tag
    func addTag(_ tag: String) {
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTag.isEmpty else { return }
        
        var currentTags = tagArray
        if !currentTags.contains(cleanTag) {
            currentTags.append(cleanTag)
            setTags(currentTags)
        }
    }
    
    /// Remove tag
    func removeTag(_ tag: String) {
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        var currentTags = tagArray
        currentTags.removeAll { $0 == cleanTag }
        setTags(currentTags)
    }
    
    /// Check if preset has specific tag
    func hasTag(_ tag: String) -> Bool {
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        return tagArray.contains(cleanTag)
    }
    
    // MARK: - Export and Import
    
    /// Generate export metadata
    func exportMetadata() -> [String: Any] {
        var metadata: [String: Any] = [
            "presetID": presetID?.uuidString ?? "",
            "name": name ?? "",
            "machineTypeName": machineTypeName ?? "",
            "category": category.rawValue,
            "author": author ?? "",
            "description": presetDescription ?? "",
            "tags": tagArray,
            "version": version ?? "",
            "isUserCreated": isUserCreated,
            "isShared": isShared,
            "complexityScore": complexityScore,
            "parameterCount": parameterCount,
            "parameterDataSize": parameterDataSize,
            "createdAt": createdAt?.timeIntervalSince1970 ?? 0,
            "lastModified": lastModified?.timeIntervalSince1970 ?? 0
        ]
        
        // Include parameter data if available
        if let parameters = try? getParameterData() {
            metadata["parameters"] = parameters
        }
        
        return metadata
    }
    
    /// Export preset for sharing
    func exportForSharing() throws -> [String: Any] {
        return [
            "name": name ?? "",
            "machineTypeName": machineTypeName ?? "",
            "author": author ?? "",
            "description": presetDescription ?? "",
            "tags": tagArray,
            "version": version ?? "",
            "parameters": try getParameterData(),
            "exportedAt": Date().timeIntervalSince1970
        ]
    }
    
    // MARK: - Validation
    
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validatePreset()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validatePreset()
    }
    
    private func validatePreset() throws {
        // Validate name
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PresetError.emptyName
        }
        
        // Validate machine type name
        guard let typeName = machineTypeName, !typeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PresetError.emptyMachineTypeName
        }
    }
}

// MARK: - Preset Categories

enum PresetCategory: String, CaseIterable {
    case voice = "voice"
    case filter = "filter"
    case effects = "effects"
    case drum = "drum"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .voice:
            return "Voice"
        case .filter:
            return "Filter"
        case .effects:
            return "Effects"
        case .drum:
            return "Drum"
        case .other:
            return "Other"
        }
    }
}

// MARK: - Preset Errors

enum PresetError: LocalizedError {
    case emptyName
    case emptyMachineTypeName
    case parameterSerializationFailed(Error)
    case parameterDeserializationFailed(Error)
    case invalidParameterData
    case incompatibleMachineType(expected: String, actual: String)
    
    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Preset name cannot be empty"
        case .emptyMachineTypeName:
            return "Machine type name cannot be empty"
        case .parameterSerializationFailed(let error):
            return "Failed to serialize parameters: \(error.localizedDescription)"
        case .parameterDeserializationFailed(let error):
            return "Failed to deserialize parameters: \(error.localizedDescription)"
        case .invalidParameterData:
            return "Invalid parameter data format"
        case .incompatibleMachineType(let expected, let actual):
            return "Incompatible machine type. Expected: \(expected), Actual: \(actual)"
        }
    }
} 