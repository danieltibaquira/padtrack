import Foundation
import CoreData
import DataModel
import MachineProtocols

/// Preset Pool provides quick access to sounds within a project
/// Manages preset organization, searching, and usage tracking
public final class PresetPool: @unchecked Sendable {
    private let project: Project
    private let context: NSManagedObjectContext
    private let queue = DispatchQueue(label: "com.digitonepad.presetpool", attributes: .concurrent)
    
    // Cache for performance
    private var presetCache: [UUID: Preset] = [:]
    private var categoryCache: [String: [Preset]] = [:]
    private var tagCache: [UUID: Set<String>] = [:]
    private var usageCache: [UUID: PresetUsageStats] = [:]
    
    // MARK: - Initialization
    
    public init(project: Project, context: NSManagedObjectContext) {
        self.project = project
        self.context = context
        loadPresetsIntoCache()
    }
    
    private func loadPresetsIntoCache() {
        queue.async(flags: .barrier) {
            self.presetCache.removeAll()
            self.categoryCache.removeAll()
            
            for preset in self.project.presets?.allObjects as? [Preset] ?? [] {
                let uuid = self.getPresetUUID(preset)
                self.presetCache[uuid] = preset
                
                if let category = preset.category {
                    self.categoryCache[category, default: []].append(preset)
                }
                
                // Load tags from preset settings
                if let tags = preset.settings?["tags"] as? [String] {
                    self.tagCache[uuid] = Set(tags)
                }
                
                // Load usage stats
                if let stats = preset.settings?["usageStats"] as? [String: Any] {
                    self.usageCache[uuid] = PresetUsageStats(
                        useCount: stats["useCount"] as? Int ?? 0,
                        firstUsed: stats["firstUsed"] as? Date,
                        lastUsed: stats["lastUsed"] as? Date
                    )
                }
            }
        }
    }
    
    // MARK: - Basic Operations
    
    public func addPreset(_ preset: Preset) throws {
        try validatePreset(preset)
        
        preset.project = project
        
        queue.async(flags: .barrier) {
            let uuid = self.getPresetUUID(preset)
            self.presetCache[uuid] = preset
            
            if let category = preset.category {
                self.categoryCache[category, default: []].append(preset)
            }
        }
        
        try context.save()
    }
    
    public func updatePreset(_ preset: Preset) throws {
        guard contains(preset) else {
            throw PresetPoolError.presetNotFound
        }
        
        queue.async(flags: .barrier) {
            // Update category cache if needed
            if let oldCategory = self.findOldCategory(for: preset),
               oldCategory != preset.category {
                self.categoryCache[oldCategory]?.removeAll { $0 == preset }
                
                if let newCategory = preset.category {
                    self.categoryCache[newCategory, default: []].append(preset)
                }
            }
        }
        
        try context.save()
    }
    
    public func removePreset(_ preset: Preset) throws {
        queue.async(flags: .barrier) {
            let uuid = self.getPresetUUID(preset)
            self.presetCache.removeValue(forKey: uuid)
            
            if let category = preset.category {
                self.categoryCache[category]?.removeAll { $0 == preset }
            }
            
            self.tagCache.removeValue(forKey: uuid)
            self.usageCache.removeValue(forKey: uuid)
        }
        
        context.delete(preset)
        try context.save()
    }
    
    public func contains(_ preset: Preset) -> Bool {
        return queue.sync {
            let uuid = getPresetUUID(preset)
            return presetCache[uuid] != nil
        }
    }
    
    // MARK: - Search and Filter
    
    public func search(query: String, fuzzy: Bool = false) throws -> [Preset] {
        return queue.sync {
            let lowercaseQuery = query.lowercased()
            
            return presetCache.values.filter { preset in
                let name = preset.name?.lowercased() ?? ""
                
                if fuzzy {
                    // Fuzzy search - match if query characters appear in order
                    var queryIndex = lowercaseQuery.startIndex
                    for char in name {
                        if queryIndex < lowercaseQuery.endIndex && char == lowercaseQuery[queryIndex] {
                            queryIndex = lowercaseQuery.index(after: queryIndex)
                        }
                    }
                    return queryIndex == lowercaseQuery.endIndex
                } else {
                    // Exact substring match
                    return name.contains(lowercaseQuery)
                }
            }
        }
    }
    
    public func advancedSearch(criteria: PresetSearchCriteria) throws -> [Preset] {
        return queue.sync {
            var results = Array(presetCache.values)
            
            // Filter by query
            if let query = criteria.query {
                let lowercaseQuery = query.lowercased()
                results = results.filter { preset in
                    preset.name?.lowercased().contains(lowercaseQuery) ?? false
                }
            }
            
            // Filter by category
            if let category = criteria.category {
                results = results.filter { $0.category == category }
            }
            
            // Filter by machine type
            if let machine = criteria.machine {
                results = results.filter { preset in
                    preset.settings?["machine"] as? String == machine.rawValue
                }
            }
            
            // Filter by tags
            if let requiredTags = criteria.tags, !requiredTags.isEmpty {
                results = results.filter { preset in
                    let uuid = getPresetUUID(preset)
                    let presetTags = tagCache[uuid] ?? Set()
                    return requiredTags.allSatisfy { presetTags.contains($0) }
                }
            }
            
            return results
        }
    }
    
    public func searchByTag(_ tag: String) throws -> [Preset] {
        return queue.sync {
            presetCache.values.filter { preset in
                let uuid = getPresetUUID(preset)
                return tagCache[uuid]?.contains(tag) ?? false
            }
        }
    }
    
    // MARK: - Categories
    
    public func allCategories() -> [String] {
        return queue.sync {
            Array(categoryCache.keys).sorted()
        }
    }
    
    public func presets(in category: String) -> [Preset] {
        return queue.sync {
            categoryCache[category] ?? []
        }
    }
    
    public func presetsWithoutCategory() -> [Preset] {
        return queue.sync {
            presetCache.values.filter { $0.category == nil }
        }
    }
    
    // MARK: - Tags
    
    public func addTags(_ tags: [String], to preset: Preset) throws {
        guard contains(preset) else {
            throw PresetPoolError.presetNotFound
        }
        
        queue.async(flags: .barrier) {
            let uuid = self.getPresetUUID(preset)
            var currentTags = self.tagCache[uuid] ?? Set()
            currentTags.formUnion(tags)
            
            // Limit tags per preset
            if currentTags.count > 20 {
                throw PresetPoolError.tagLimitExceeded
            }
            
            self.tagCache[uuid] = currentTags
            
            // Save to preset settings
            var settings = preset.settings ?? [:]
            settings["tags"] = Array(currentTags)
            preset.settings = settings
        }
        
        try context.save()
    }
    
    public func removeTag(_ tag: String, from preset: Preset) throws {
        guard contains(preset) else {
            throw PresetPoolError.presetNotFound
        }
        
        queue.async(flags: .barrier) {
            let uuid = self.getPresetUUID(preset)
            self.tagCache[uuid]?.remove(tag)
            
            // Update preset settings
            var settings = preset.settings ?? [:]
            settings["tags"] = Array(self.tagCache[uuid] ?? Set())
            preset.settings = settings
        }
        
        try context.save()
    }
    
    public func tags(for preset: Preset) -> Set<String> {
        return queue.sync {
            let uuid = getPresetUUID(preset)
            return tagCache[uuid] ?? Set()
        }
    }
    
    // MARK: - Preset Access
    
    public func allPresets(sortedBy option: PresetSortOption = .name) -> [Preset] {
        return queue.sync {
            let presets = Array(presetCache.values)
            
            switch option {
            case .name:
                return presets.sorted { ($0.name ?? "") < ($1.name ?? "") }
            case .dateCreated:
                return presets.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
            case .lastUsed:
                return presets.sorted { preset1, preset2 in
                    let uuid1 = getPresetUUID(preset1)
                    let uuid2 = getPresetUUID(preset2)
                    let date1 = usageCache[uuid1]?.lastUsed ?? Date.distantPast
                    let date2 = usageCache[uuid2]?.lastUsed ?? Date.distantPast
                    return date1 > date2
                }
            case .category:
                return presets.sorted { ($0.category ?? "") < ($1.category ?? "") }
            }
        }
    }
    
    public func preset(named name: String) -> Preset? {
        return queue.sync {
            presetCache.values.first { $0.name == name }
        }
    }
    
    public func presets(forMachine machine: MachineType) throws -> [Preset] {
        return queue.sync {
            presetCache.values.filter { preset in
                preset.settings?["machine"] as? String == machine.rawValue
            }
        }
    }
    
    // MARK: - Usage Tracking
    
    public func recordUsage(of preset: Preset) throws {
        guard contains(preset) else {
            throw PresetPoolError.presetNotFound
        }
        
        queue.async(flags: .barrier) {
            let uuid = self.getPresetUUID(preset)
            var stats = self.usageCache[uuid] ?? PresetUsageStats(useCount: 0, firstUsed: nil, lastUsed: nil)
            
            stats.useCount += 1
            stats.lastUsed = Date()
            if stats.firstUsed == nil {
                stats.firstUsed = Date()
            }
            
            self.usageCache[uuid] = stats
            
            // Save to preset settings
            var settings = preset.settings ?? [:]
            settings["usageStats"] = [
                "useCount": stats.useCount,
                "firstUsed": stats.firstUsed as Any,
                "lastUsed": stats.lastUsed as Any
            ]
            preset.settings = settings
        }
        
        try context.save()
    }
    
    public func usageStats(for preset: Preset) -> PresetUsageStats {
        return queue.sync {
            let uuid = getPresetUUID(preset)
            return usageCache[uuid] ?? PresetUsageStats(useCount: 0, firstUsed: nil, lastUsed: nil)
        }
    }
    
    public func mostUsedPresets(limit: Int) -> [Preset] {
        return queue.sync {
            let sortedPresets = presetCache.values.sorted { preset1, preset2 in
                let uuid1 = getPresetUUID(preset1)
                let uuid2 = getPresetUUID(preset2)
                let count1 = usageCache[uuid1]?.useCount ?? 0
                let count2 = usageCache[uuid2]?.useCount ?? 0
                return count1 > count2
            }
            
            return Array(sortedPresets.prefix(limit))
        }
    }
    
    public func recentlyUsedPresets(limit: Int) -> [Preset] {
        return queue.sync {
            let sortedPresets = presetCache.values.sorted { preset1, preset2 in
                let uuid1 = getPresetUUID(preset1)
                let uuid2 = getPresetUUID(preset2)
                let date1 = usageCache[uuid1]?.lastUsed ?? Date.distantPast
                let date2 = usageCache[uuid2]?.lastUsed ?? Date.distantPast
                return date1 > date2
            }
            
            return Array(sortedPresets.prefix(limit))
        }
    }
    
    // MARK: - Comparison
    
    public func comparePresets(_ preset1: Preset, _ preset2: Preset) -> [PresetDifference] {
        var differences: [PresetDifference] = []
        
        let settings1 = preset1.settings ?? [:]
        let settings2 = preset2.settings ?? [:]
        
        let allKeys = Set(settings1.keys).union(Set(settings2.keys))
        
        for key in allKeys {
            let value1 = settings1[key]
            let value2 = settings2[key]
            
            if !areValuesEqual(value1, value2) {
                differences.append(PresetDifference(
                    parameter: key,
                    value1: value1 ?? NSNull(),
                    value2: value2 ?? NSNull()
                ))
            }
        }
        
        return differences
    }
    
    public func findSimilarPresets(to preset: Preset, threshold: Double) throws -> [Preset] {
        return queue.sync {
            presetCache.values.filter { otherPreset in
                guard otherPreset != preset else { return false }
                
                let differences = comparePresets(preset, otherPreset)
                let totalParameters = max(
                    preset.settings?.count ?? 0,
                    otherPreset.settings?.count ?? 0
                )
                
                guard totalParameters > 0 else { return false }
                
                let similarity = 1.0 - (Double(differences.count) / Double(totalParameters))
                return similarity >= threshold
            }
        }
    }
    
    // MARK: - Validation
    
    public func validatePreset(_ preset: Preset) throws {
        // Validate name
        guard let name = preset.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PresetPoolError.invalidPresetName
        }
        
        // Check for duplicate names
        if let existing = preset(named: name), existing != preset {
            throw PresetPoolError.duplicatePresetName
        }
        
        // Validate category if present
        if let category = preset.category, category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw PresetPoolError.invalidCategory
        }
    }
    
    // MARK: - Private Helpers
    
    private func getPresetUUID(_ preset: Preset) -> UUID {
        // Generate deterministic UUID from object ID
        let objectIDString = preset.objectID.uriRepresentation().absoluteString
        return UUID(uuidString: String(objectIDString.suffix(36))) ?? UUID()
    }
    
    private func findOldCategory(for preset: Preset) -> String? {
        for (category, presets) in categoryCache {
            if presets.contains(preset) {
                return category
            }
        }
        return nil
    }
    
    private func areValuesEqual(_ value1: Any?, _ value2: Any?) -> Bool {
        // Compare values for equality
        switch (value1, value2) {
        case (nil, nil):
            return true
        case (let v1 as NSNumber, let v2 as NSNumber):
            return v1 == v2
        case (let v1 as String, let v2 as String):
            return v1 == v2
        case (let v1 as Data, let v2 as Data):
            return v1 == v2
        case (let v1 as Date, let v2 as Date):
            return v1 == v2
        case (let v1 as [String: Any], let v2 as [String: Any]):
            return NSDictionary(dictionary: v1).isEqual(to: v2)
        case (let v1 as [Any], let v2 as [Any]):
            return NSArray(array: v1).isEqual(to: v2)
        default:
            return false
        }
    }
}

// MARK: - Error Extension

extension PresetPoolError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidPresetName:
            return "Preset name cannot be empty"
        case .duplicatePresetName:
            return "A preset with this name already exists"
        case .presetNotFound:
            return "Preset not found in pool"
        case .invalidCategory:
            return "Category name cannot be empty"
        case .tagLimitExceeded:
            return "Maximum number of tags exceeded (limit: 20)"
        }
    }
}