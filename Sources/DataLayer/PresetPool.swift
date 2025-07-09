import Foundation
import CoreData
import DataModel
import MachineProtocols

/// Manages the preset pool for quick access to sounds within a project
public class PresetPool {
    
    // MARK: - Properties
    
    private let project: Project
    private let context: NSManagedObjectContext
    private var presetCache: [UUID: Preset] = [:]
    private var categoryCache: [String: [Preset]] = [:]
    private var usageStats: [UUID: UsageStats] = [:]
    private let cacheLock = NSLock()
    
    // MARK: - Initialization
    
    public init(project: Project, context: NSManagedObjectContext) {
        self.project = project
        self.context = context
        refreshCache()
    }
    
    // MARK: - Basic Operations
    
    /// Adds a preset to the pool
    public func addPreset(_ preset: Preset) throws {
        preset.project = project
        preset.createdAt = preset.createdAt ?? Date()
        preset.updatedAt = Date()
        
        try context.save()
        
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        if let id = preset.objectID.uriRepresentation().absoluteString.data(using: .utf8) {
            let uuid = UUID(uuid: uuid_t(tuple: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))) ?? UUID()
            presetCache[uuid] = preset
            
            // Update category cache
            let category = preset.category ?? "Uncategorized"
            if categoryCache[category] == nil {
                categoryCache[category] = []
            }
            categoryCache[category]?.append(preset)
        }
    }
    
    /// Removes a preset from the pool
    public func removePreset(_ preset: Preset) throws {
        context.delete(preset)
        try context.save()
        
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        // Remove from caches
        if let uuid = getUUID(for: preset) {
            presetCache.removeValue(forKey: uuid)
            usageStats.removeValue(forKey: uuid)
        }
        
        // Update category cache
        if let category = preset.category {
            categoryCache[category]?.removeAll { $0 == preset }
        }
    }
    
    /// Checks if a preset is in the pool
    public func contains(_ preset: Preset) -> Bool {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        if let uuid = getUUID(for: preset) {
            return presetCache[uuid] != nil
        }
        
        // Fallback to checking project relationship
        return preset.project == project
    }
    
    /// Gets the total number of presets
    public var presetCount: Int {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return presetCache.count
    }
    
    // MARK: - Search and Retrieval
    
    /// Searches for presets by query
    public func search(query: String, fuzzy: Bool = false) throws -> [Preset] {
        let lowercasedQuery = query.lowercased()
        
        cacheLock.lock()
        let allPresets = Array(presetCache.values)
        cacheLock.unlock()
        
        return allPresets.filter { preset in
            let name = preset.name?.lowercased() ?? ""
            
            if fuzzy {
                // Fuzzy search - check if all characters appear in order
                var queryIndex = lowercasedQuery.startIndex
                for char in name {
                    if queryIndex < lowercasedQuery.endIndex && char == lowercasedQuery[queryIndex] {
                        queryIndex = lowercasedQuery.index(after: queryIndex)
                    }
                }
                return queryIndex == lowercasedQuery.endIndex
            } else {
                // Standard search
                return name.contains(lowercasedQuery)
            }
        }
    }
    
    /// Searches for presets by tag
    public func search(tag: String) throws -> [Preset] {
        cacheLock.lock()
        let allPresets = Array(presetCache.values)
        cacheLock.unlock()
        
        return allPresets.filter { preset in
            preset.tags?.contains(tag) ?? false
        }
    }
    
    /// Searches for presets by multiple tags
    public func search(tags: [String]) throws -> [Preset] {
        cacheLock.lock()
        let allPresets = Array(presetCache.values)
        cacheLock.unlock()
        
        return allPresets.filter { preset in
            guard let presetTags = preset.tags else { return false }
            return tags.allSatisfy { presetTags.contains($0) }
        }
    }
    
    /// Combined search with multiple criteria
    public func search(query: String? = nil, category: String? = nil, tags: [String]? = nil) throws -> [Preset] {
        cacheLock.lock()
        var results = Array(presetCache.values)
        cacheLock.unlock()
        
        // Filter by query
        if let query = query, !query.isEmpty {
            results = results.filter { preset in
                preset.name?.lowercased().contains(query.lowercased()) ?? false
            }
        }
        
        // Filter by category
        if let category = category {
            results = results.filter { $0.category == category }
        }
        
        // Filter by tags
        if let tags = tags, !tags.isEmpty {
            results = results.filter { preset in
                guard let presetTags = preset.tags else { return false }
                return tags.allSatisfy { presetTags.contains($0) }
            }
        }
        
        return results
    }
    
    /// Gets a preset by name
    public func preset(named name: String) throws -> Preset? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        return presetCache.values.first { $0.name == name }
    }
    
    // MARK: - Category Management
    
    /// Gets all presets in a category
    public func presets(in category: String) -> [Preset] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        return categoryCache[category] ?? []
    }
    
    /// Gets all categories
    public func allCategories() -> [String] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        return Array(categoryCache.keys).sorted()
    }
    
    // MARK: - Sorting
    
    /// Gets all presets sorted by the specified option
    public func allPresets(sortedBy option: PresetSortOption = .name) -> [Preset] {
        cacheLock.lock()
        let allPresets = Array(presetCache.values)
        cacheLock.unlock()
        
        switch option {
        case .name:
            return allPresets.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .category:
            return allPresets.sorted { 
                let cat1 = $0.category ?? "Uncategorized"
                let cat2 = $1.category ?? "Uncategorized"
                if cat1 == cat2 {
                    return ($0.name ?? "") < ($1.name ?? "")
                }
                return cat1 < cat2
            }
        case .dateNewest:
            return allPresets.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
        case .dateOldest:
            return allPresets.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
        case .mostUsed:
            return allPresets.sorted { preset1, preset2 in
                let usage1 = getUsageCount(for: preset1)
                let usage2 = getUsageCount(for: preset2)
                return usage1 > usage2
            }
        }
    }
    
    // MARK: - Usage Tracking
    
    /// Tracks usage of a preset
    public func trackUsage(of preset: Preset) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        guard let uuid = getUUID(for: preset) else { return }
        
        if usageStats[uuid] == nil {
            usageStats[uuid] = UsageStats()
        }
        
        usageStats[uuid]?.usageCount += 1
        usageStats[uuid]?.lastUsed = Date()
    }
    
    /// Gets the usage count for a preset
    public func getUsageCount(for preset: Preset) -> Int {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        guard let uuid = getUUID(for: preset) else { return 0 }
        return usageStats[uuid]?.usageCount ?? 0
    }
    
    /// Gets the most used presets
    public func mostUsedPresets(limit: Int) -> [Preset] {
        return allPresets(sortedBy: .mostUsed).prefix(limit).map { $0 }
    }
    
    /// Gets recently used presets
    public func recentlyUsedPresets(limit: Int) -> [Preset] {
        cacheLock.lock()
        let stats = usageStats
        let cache = presetCache
        cacheLock.unlock()
        
        let sortedByRecent = stats
            .compactMap { (uuid, stat) -> (Preset, Date)? in
                guard let preset = cache[uuid], let lastUsed = stat.lastUsed else { return nil }
                return (preset, lastUsed)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
        
        return Array(sortedByRecent)
    }
    
    // MARK: - Import/Export
    
    /// Exports presets in a category
    public func exportPresets(category: String? = nil) throws -> Data {
        let presetsToExport: [Preset]
        
        if let category = category {
            presetsToExport = presets(in: category)
        } else {
            cacheLock.lock()
            presetsToExport = Array(presetCache.values)
            cacheLock.unlock()
        }
        
        let exportData = presetsToExport.map { preset in
            return [
                "name": preset.name ?? "",
                "category": preset.category ?? "",
                "machine": preset.machine ?? "",
                "tags": preset.tags ?? [],
                "parameterData": preset.parameterData?.base64EncodedString() ?? ""
            ] as [String: Any]
        }
        
        return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
    
    /// Imports presets from data
    public func importPresets(from data: Data) throws -> Int {
        guard let presetArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw PresetPoolError.invalidImportData
        }
        
        var importedCount = 0
        
        for presetData in presetArray {
            let preset = NSEntityDescription.insertNewObject(forEntityName: "Preset", into: context) as! Preset
            preset.name = presetData["name"] as? String
            preset.category = presetData["category"] as? String
            preset.machine = presetData["machine"] as? String
            preset.tags = presetData["tags"] as? [String]
            
            if let parameterDataString = presetData["parameterData"] as? String,
               let parameterData = Data(base64Encoded: parameterDataString) {
                preset.parameterData = parameterData
            }
            
            try addPreset(preset)
            importedCount += 1
        }
        
        return importedCount
    }
    
    // MARK: - Private Methods
    
    private func refreshCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        presetCache.removeAll()
        categoryCache.removeAll()
        
        guard let presets = project.presets?.allObjects as? [Preset] else { return }
        
        for preset in presets {
            if let uuid = getUUID(for: preset) {
                presetCache[uuid] = preset
                
                let category = preset.category ?? "Uncategorized"
                if categoryCache[category] == nil {
                    categoryCache[category] = []
                }
                categoryCache[category]?.append(preset)
            }
        }
    }
    
    private func getUUID(for preset: Preset) -> UUID? {
        // Generate a stable UUID from the object ID
        let objectIDString = preset.objectID.uriRepresentation().absoluteString
        
        // Use a hash of the object ID to create a deterministic UUID
        var hasher = Hasher()
        hasher.combine(objectIDString)
        let hashValue = hasher.finalize()
        
        // Convert hash to UUID format
        let uuidString = String(format: "%08X-0000-0000-0000-000000000000", abs(hashValue))
        return UUID(uuidString: uuidString)
    }
}

// MARK: - Supporting Types

/// Usage statistics for a preset
private struct UsageStats {
    var usageCount: Int = 0
    var lastUsed: Date?
}

/// Error types for preset pool operations
enum PresetPoolError: LocalizedError {
    case invalidImportData
    case presetNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidImportData:
            return "Invalid import data format"
        case .presetNotFound:
            return "Preset not found"
        }
    }
}