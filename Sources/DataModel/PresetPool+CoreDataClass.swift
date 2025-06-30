//
//  PresetPool+CoreDataClass.swift
//  PadTrack
//
//  Created by PadTrack on 2024.
//

import Foundation
import CoreData

@objc(PresetPool)
public class PresetPool: NSManagedObject {
    
    // MARK: - Convenience Initializers
    
    convenience init(context: NSManagedObjectContext, name: String) {
        self.init(context: context)
        self.poolID = UUID()
        self.name = name
        self.isShared = false
        self.createdAt = Date()
        self.lastModified = Date()
    }
    
    // MARK: - Computed Properties
    
    /// Check if preset pool has been modified since creation
    var isModified: Bool {
        guard let created = createdAt, let modified = lastModified else { return false }
        return modified > created
    }
    
    /// Get display name for UI
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return "Unnamed Pool"
    }
    
    /// Get all presets sorted by name
    var sortedPresets: [Preset] {
        guard let presets = presets as? Set<Preset> else { return [] }
        return presets.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
    
    /// Count of presets in this pool
    var presetCount: Int {
        return presets?.count ?? 0
    }
    
    /// Check if pool has any presets
    var hasPresets: Bool {
        return presetCount > 0
    }
    
    /// Check if pool is empty
    var isEmpty: Bool {
        return presetCount == 0
    }
    
    /// Get presets grouped by machine type
    var presetsByMachineType: [String: [Preset]] {
        var grouped: [String: [Preset]] = [:]
        
        for preset in sortedPresets {
            let machineType = preset.machineTypeName ?? "Unknown"
            if grouped[machineType] == nil {
                grouped[machineType] = []
            }
            grouped[machineType]?.append(preset)
        }
        
        return grouped
    }
    
    /// Get all machine types represented in this pool
    var machineTypes: [String] {
        return Array(presetsByMachineType.keys).sorted()
    }
    
    /// Get presets grouped by category
    var presetsByCategory: [PresetCategory: [Preset]] {
        var grouped: [PresetCategory: [Preset]] = [:]
        
        for preset in sortedPresets {
            let category = preset.category
            if grouped[category] == nil {
                grouped[category] = []
            }
            grouped[category]?.append(preset)
        }
        
        return grouped
    }
    
    // MARK: - Pool Management
    
    /// Set pool name with validation
    func setName(_ newName: String) throws {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw PresetPoolError.emptyName
        }
        name = trimmedName
        lastModified = Date()
    }
    
    /// Set description
    func setDescription(_ newDescription: String) {
        poolDescription = newDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        lastModified = Date()
    }
    
    /// Mark pool as shared
    func markAsShared() {
        isShared = true
        lastModified = Date()
    }
    
    /// Mark pool as private
    func markAsPrivate() {
        isShared = false
        lastModified = Date()
    }
    
    /// Toggle shared state
    func toggleShared() {
        isShared.toggle()
        lastModified = Date()
    }
    
    // MARK: - Preset Management
    
    /// Add preset to pool
    func addPreset(_ preset: Preset) {
        preset.presetPool = self
        lastModified = Date()
    }
    
    /// Remove preset from pool
    func removePreset(_ preset: Preset) {
        if preset.presetPool == self {
            preset.presetPool = nil
            lastModified = Date()
        }
    }
    
    /// Remove all presets from pool
    func removeAllPresets() {
        for preset in sortedPresets {
            preset.presetPool = nil
        }
        lastModified = Date()
    }
    
    /// Get presets for specific machine type
    func presets(for machineType: String) -> [Preset] {
        return sortedPresets.filter { $0.machineTypeName == machineType }
    }
    
    /// Get presets with specific tag
    func presets(withTag tag: String) -> [Preset] {
        return sortedPresets.filter { $0.hasTag(tag) }
    }
    
    /// Get presets by category
    func presets(inCategory category: PresetCategory) -> [Preset] {
        return sortedPresets.filter { $0.category == category }
    }
    
    /// Get presets by author
    func presets(byAuthor author: String) -> [Preset] {
        return sortedPresets.filter { $0.author == author }
    }
    
    /// Search presets by name
    func searchPresets(containing searchTerm: String) -> [Preset] {
        let lowercaseSearch = searchTerm.lowercased()
        return sortedPresets.filter { preset in
            let name = preset.name?.lowercased() ?? ""
            let description = preset.presetDescription?.lowercased() ?? ""
            let tags = preset.tags?.lowercased() ?? ""
            return name.contains(lowercaseSearch) || 
                   description.contains(lowercaseSearch) || 
                   tags.contains(lowercaseSearch)
        }
    }
    
    /// Check if pool contains preset
    func contains(_ preset: Preset) -> Bool {
        return preset.presetPool == self
    }
    
    /// Get random preset from pool
    func randomPreset() -> Preset? {
        let presets = sortedPresets
        guard !presets.isEmpty else { return nil }
        return presets.randomElement()
    }
    
    /// Get random preset for specific machine type
    func randomPreset(for machineType: String) -> Preset? {
        let typePresets = presets(for: machineType)
        guard !typePresets.isEmpty else { return nil }
        return typePresets.randomElement()
    }
    
    // MARK: - Pool Operations
    
    /// Copy all presets from another pool
    func copyPresets(from sourcePool: PresetPool, in context: NSManagedObjectContext) {
        for sourcePreset in sourcePool.sortedPresets {
            let duplicatedPreset = sourcePreset.duplicate(in: context)
            addPreset(duplicatedPreset)
        }
    }
    
    /// Merge another pool into this one
    func merge(with otherPool: PresetPool) {
        for preset in otherPool.sortedPresets {
            addPreset(preset)
        }
        // The other pool will become empty after this operation
    }
    
    /// Create a duplicate of this pool
    func duplicate(in context: NSManagedObjectContext, name: String? = nil) -> PresetPool {
        let duplicatedPool = PresetPool(context: context, 
                                      name: name ?? "\(self.name ?? "Pool") Copy")
        duplicatedPool.poolDescription = self.poolDescription
        duplicatedPool.isShared = false  // Duplicates start as private
        
        // Copy all presets
        duplicatedPool.copyPresets(from: self, in: context)
        
        return duplicatedPool
    }
    
    /// Clear pool (remove all presets)
    func clear() {
        removeAllPresets()
    }
    
    /// Organize presets by machine type (for UI purposes)
    func organizeByMachineType() -> [(String, [Preset])] {
        let grouped = presetsByMachineType
        return grouped.map { (key, value) in
            (key, value.sorted { ($0.name ?? "") < ($1.name ?? "") })
        }.sorted { $0.0 < $1.0 }
    }
    
    // MARK: - Statistics
    
    /// Get statistics about the pool
    var statistics: PresetPoolStatistics {
        let presets = sortedPresets
        let machineTypes = Set(presets.compactMap { $0.machineTypeName })
        let authors = Set(presets.compactMap { $0.author })
        let userCreated = presets.filter { $0.isUserCreated }.count
        let factoryPresets = presets.filter { !$0.isUserCreated }.count
        let sharedPresets = presets.filter { $0.isShared }.count
        
        return PresetPoolStatistics(
            totalPresets: presets.count,
            machineTypeCount: machineTypes.count,
            authorCount: authors.count,
            userCreatedCount: userCreated,
            factoryPresetCount: factoryPresets,
            sharedPresetCount: sharedPresets
        )
    }
    
    // MARK: - Export and Import
    
    /// Generate export metadata
    func exportMetadata() -> [String: Any] {
        let stats = statistics
        
        return [
            "poolID": poolID?.uuidString ?? "",
            "name": name ?? "",
            "description": poolDescription ?? "",
            "isShared": isShared,
            "presetCount": presetCount,
            "machineTypes": machineTypes,
            "statistics": [
                "totalPresets": stats.totalPresets,
                "machineTypeCount": stats.machineTypeCount,
                "authorCount": stats.authorCount,
                "userCreatedCount": stats.userCreatedCount,
                "factoryPresetCount": stats.factoryPresetCount,
                "sharedPresetCount": stats.sharedPresetCount
            ],
            "createdAt": createdAt?.timeIntervalSince1970 ?? 0,
            "lastModified": lastModified?.timeIntervalSince1970 ?? 0
        ]
    }
    
    /// Export pool for sharing
    func exportForSharing() throws -> [String: Any] {
        var exportedPresets: [[String: Any]] = []
        
        for preset in sortedPresets {
            exportedPresets.append(try preset.exportForSharing())
        }
        
        return [
            "name": name ?? "",
            "description": poolDescription ?? "",
            "presets": exportedPresets,
            "exportedAt": Date().timeIntervalSince1970
        ]
    }
    
    /// Import presets from exported data
    func importPresets(from exportData: [String: Any], in context: NSManagedObjectContext) throws {
        guard let presetsData = exportData["presets"] as? [[String: Any]] else {
            throw PresetPoolError.invalidImportData("Missing presets data")
        }
        
        for presetData in presetsData {
            guard let name = presetData["name"] as? String,
                  let machineTypeName = presetData["machineTypeName"] as? String,
                  let parameters = presetData["parameters"] as? [String: Any] else {
                throw PresetPoolError.invalidImportData("Invalid preset data")
            }
            
            let preset = Preset(context: context, name: name, machineTypeName: machineTypeName)
            
            // Set optional metadata
            if let author = presetData["author"] as? String {
                preset.author = author
            }
            if let description = presetData["description"] as? String {
                preset.presetDescription = description
            }
            if let tags = presetData["tags"] as? [String] {
                preset.setTags(tags)
            }
            if let version = presetData["version"] as? String {
                preset.version = version
            }
            
            // Set parameter data
            try preset.setParameterData(from: parameters)
            
            // Add to this pool
            addPreset(preset)
        }
    }
    
    // MARK: - Validation
    
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validatePresetPool()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validatePresetPool()
    }
    
    private func validatePresetPool() throws {
        // Validate name
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PresetPoolError.emptyName
        }
    }
}

// MARK: - Preset Pool Statistics

struct PresetPoolStatistics {
    let totalPresets: Int
    let machineTypeCount: Int
    let authorCount: Int
    let userCreatedCount: Int
    let factoryPresetCount: Int
    let sharedPresetCount: Int
}

// MARK: - Preset Pool Errors

enum PresetPoolError: LocalizedError {
    case emptyName
    case invalidImportData(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Preset pool name cannot be empty"
        case .invalidImportData(let details):
            return "Invalid import data: \(details)"
        }
    }
} 