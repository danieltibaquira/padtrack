import XCTest
import CoreData
@testable import DataLayer
@testable import DataModel
@testable import MachineProtocols

/// Tests for Preset Pool functionality
/// Preset Pool provides quick access to sounds within a project
class PresetPoolTests: XCTestCase {
    var testContext: NSManagedObjectContext!
    var dataLayer: DataLayerManager!
    var project: Project!
    var presetPool: PresetPool!
    
    override func setUp() {
        super.setUp()
        // Create in-memory test context
        let persistenceController = PersistenceController(inMemory: true)
        testContext = persistenceController.container.viewContext
        dataLayer = DataLayerManager(persistenceController: persistenceController)
        
        // Create test project
        project = dataLayer.projectRepository.createProject(name: "Test Project")
        try? dataLayer.save()
        
        // Initialize preset pool
        presetPool = PresetPool(project: project, context: testContext)
    }
    
    override func tearDown() {
        testContext = nil
        dataLayer = nil
        project = nil
        presetPool = nil
        super.tearDown()
    }
    
    // MARK: - Basic CRUD Operations
    
    func testPresetPoolOperations() throws {
        // Test all preset pool CRUD operations
        
        // Create test preset
        let preset = createTestPreset(machine: .fmTone)
        preset.name = "Test Bass"
        preset.category = "Bass"
        
        // Add to pool
        try presetPool.addPreset(preset)
        
        // Verify preset in pool
        XCTAssertTrue(presetPool.contains(preset))
        XCTAssertEqual(presetPool.presets(in: "Bass").count, 1)
        
        // Test preset search
        let searchResults = try presetPool.search(query: "bass")
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.name, "Test Bass")
        
        // Update preset
        preset.name = "Updated Bass"
        try presetPool.updatePreset(preset)
        
        let updatedResults = try presetPool.search(query: "Updated")
        XCTAssertEqual(updatedResults.count, 1)
        
        // Remove preset
        try presetPool.removePreset(preset)
        XCTAssertFalse(presetPool.contains(preset))
    }
    
    func testPresetCategories() throws {
        // Test preset categorization
        
        // Add presets in different categories
        let categories = ["Bass", "Lead", "Pad", "FX", "Drums"]
        
        for (index, category) in categories.enumerated() {
            for i in 0..<3 {
                let preset = createTestPreset(machine: .fmTone)
                preset.name = "\(category) \(i)"
                preset.category = category
                try presetPool.addPreset(preset)
            }
        }
        
        // Verify categories
        let allCategories = presetPool.allCategories()
        XCTAssertEqual(allCategories.count, 5)
        XCTAssertEqual(Set(allCategories), Set(categories))
        
        // Verify preset count per category
        for category in categories {
            let presetsInCategory = presetPool.presets(in: category)
            XCTAssertEqual(presetsInCategory.count, 3)
        }
        
        // Test uncategorized presets
        let uncategorized = createTestPreset(machine: .fmTone)
        uncategorized.name = "No Category"
        uncategorized.category = nil
        try presetPool.addPreset(uncategorized)
        
        let uncategorizedPresets = presetPool.presetsWithoutCategory()
        XCTAssertEqual(uncategorizedPresets.count, 1)
    }
    
    func testPresetTags() throws {
        // Test preset tagging system
        
        let preset = createTestPreset(machine: .fmTone)
        preset.name = "Tagged Preset"
        
        // Add tags
        try presetPool.addTags(["warm", "analog", "vintage"], to: preset)
        
        // Verify tags
        let tags = presetPool.tags(for: preset)
        XCTAssertEqual(tags.count, 3)
        XCTAssertTrue(tags.contains("warm"))
        XCTAssertTrue(tags.contains("analog"))
        XCTAssertTrue(tags.contains("vintage"))
        
        // Search by tag
        let warmPresets = try presetPool.searchByTag("warm")
        XCTAssertEqual(warmPresets.count, 1)
        XCTAssertEqual(warmPresets.first?.name, "Tagged Preset")
        
        // Remove tag
        try presetPool.removeTag("vintage", from: preset)
        let updatedTags = presetPool.tags(for: preset)
        XCTAssertEqual(updatedTags.count, 2)
        XCTAssertFalse(updatedTags.contains("vintage"))
    }
    
    // MARK: - Search and Filter Tests
    
    func testAdvancedSearch() throws {
        // Test advanced search capabilities
        
        // Create diverse presets
        let presets = [
            ("FM Bass 1", "Bass", .fmTone, ["deep", "sub"]),
            ("FM Bass 2", "Bass", .fmTone, ["punchy", "aggressive"]),
            ("Drum Kit 1", "Drums", .fmDrum, ["808", "kick"]),
            ("Pad Heaven", "Pad", .wavetone, ["ambient", "lush"]),
            ("Lead Synth", "Lead", .fmTone, ["bright", "cutting"])
        ]
        
        for (name, category, machine, tags) in presets {
            let preset = createTestPreset(machine: machine)
            preset.name = name
            preset.category = category
            try presetPool.addPreset(preset)
            try presetPool.addTags(tags, to: preset)
        }
        
        // Test combined search
        let searchCriteria = PresetSearchCriteria(
            query: "Bass",
            category: "Bass",
            machine: .fmTone,
            tags: ["deep"]
        )
        
        let results = try presetPool.advancedSearch(criteria: searchCriteria)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "FM Bass 1")
        
        // Test machine type filter
        let fmTonePresets = try presetPool.presets(forMachine: .fmTone)
        XCTAssertEqual(fmTonePresets.count, 3)
        
        // Test fuzzy search
        let fuzzyResults = try presetPool.search(query: "bas", fuzzy: true)
        XCTAssertEqual(fuzzyResults.count, 2) // Both bass presets
    }
    
    func testPresetSorting() throws {
        // Test preset sorting options
        
        // Create presets with different attributes
        for i in 0..<5 {
            let preset = createTestPreset(machine: .fmTone)
            preset.name = "Preset \(String(UnicodeScalar(65 + i)!))" // A, B, C, D, E
            preset.category = ["Bass", "Lead", "Pad"][i % 3]
            preset.createdAt = Date().addingTimeInterval(TimeInterval(-i * 3600))
            preset.lastUsed = Date().addingTimeInterval(TimeInterval(-i * 1800))
            try presetPool.addPreset(preset)
        }
        
        // Sort by name
        let sortedByName = presetPool.allPresets(sortedBy: .name)
        XCTAssertEqual(sortedByName.first?.name, "Preset A")
        XCTAssertEqual(sortedByName.last?.name, "Preset E")
        
        // Sort by date created (newest first)
        let sortedByDate = presetPool.allPresets(sortedBy: .dateCreated)
        XCTAssertEqual(sortedByDate.first?.name, "Preset A")
        
        // Sort by last used
        let sortedByUsage = presetPool.allPresets(sortedBy: .lastUsed)
        XCTAssertEqual(sortedByUsage.first?.name, "Preset A")
        
        // Sort by category
        let sortedByCategory = presetPool.allPresets(sortedBy: .category)
        XCTAssertEqual(sortedByCategory.first?.category, "Bass")
    }
    
    // MARK: - Persistence Tests
    
    func testPresetPoolPersistence() throws {
        // Test preset pool survives project save/load
        
        // Add multiple presets
        for i in 0..<10 {
            let preset = createTestPreset(machine: .fmTone)
            preset.name = "Preset \(i)"
            preset.category = ["Bass", "Lead", "Pad", "FX"][i % 4]
            try presetPool.addPreset(preset)
            
            // Add some tags
            if i % 2 == 0 {
                try presetPool.addTags(["favorite"], to: preset)
            }
        }
        
        // Save project
        try dataLayer.save()
        
        // Create new preset pool instance
        let newPresetPool = PresetPool(project: project, context: testContext)
        
        // Verify all presets are intact
        XCTAssertEqual(newPresetPool.allPresets().count, 10)
        
        for i in 0..<10 {
            let preset = newPresetPool.preset(named: "Preset \(i)")
            XCTAssertNotNil(preset)
            
            // Verify tags persisted
            if i % 2 == 0 {
                let tags = newPresetPool.tags(for: preset!)
                XCTAssertTrue(tags.contains("favorite"))
            }
        }
    }
    
    func testPresetPoolMigration() throws {
        // Test preset pool data migration
        
        // Simulate old format presets
        let oldPresets = createOldFormatPresets()
        
        // Migrate to new format
        let migrator = PresetPoolMigrator()
        let migratedPool = try migrator.migrate(oldPresets: oldPresets, to: project)
        
        // Verify migration preserved all data
        XCTAssertEqual(migratedPool.allPresets().count, oldPresets.count)
        
        // Verify preset data was correctly converted
        for oldPreset in oldPresets {
            let migratedPreset = migratedPool.preset(named: oldPreset.name)
            XCTAssertNotNil(migratedPreset)
            XCTAssertEqual(migratedPreset?.category, oldPreset.category)
        }
    }
    
    // MARK: - Performance Tests
    
    func testPresetPoolPerformance() throws {
        // Test preset pool performance with large numbers of presets
        
        measure {
            // Add 1000 presets
            for i in 0..<1000 {
                let preset = createTestPreset(machine: .fmTone)
                preset.name = "Preset \(i)"
                preset.category = ["Bass", "Lead", "Pad", "FX"][i % 4]
                try? presetPool.addPreset(preset)
            }
        }
        
        // Search performance test
        measure {
            let results = try? presetPool.search(query: "Preset 5")
            XCTAssertGreaterThan(results?.count ?? 0, 0)
        }
        
        // Category filtering performance
        measure {
            let bassPresets = presetPool.presets(in: "Bass")
            XCTAssertEqual(bassPresets.count, 250) // 1000 / 4 categories
        }
    }
    
    func testConcurrentAccess() throws {
        // Test thread-safe concurrent access
        
        let dispatchGroup = DispatchGroup()
        var errors: [Error] = []
        let queue = DispatchQueue(label: "test.queue", attributes: .concurrent)
        
        // Concurrent writes
        for i in 0..<20 {
            dispatchGroup.enter()
            queue.async {
                defer { dispatchGroup.leave() }
                
                do {
                    let preset = self.createTestPreset(machine: .fmTone)
                    preset.name = "Concurrent \(i)"
                    try self.presetPool.addPreset(preset)
                } catch {
                    errors.append(error)
                }
            }
        }
        
        // Concurrent reads
        for _ in 0..<20 {
            dispatchGroup.enter()
            queue.async {
                defer { dispatchGroup.leave() }
                
                _ = self.presetPool.allPresets()
                _ = try? self.presetPool.search(query: "Concurrent")
            }
        }
        
        dispatchGroup.wait()
        XCTAssertTrue(errors.isEmpty, "Concurrent access errors: \(errors)")
        XCTAssertEqual(presetPool.allPresets().count, 20)
    }
    
    // MARK: - Preset Usage Tracking
    
    func testPresetUsageTracking() throws {
        // Test tracking of preset usage statistics
        
        let preset = createTestPreset(machine: .fmTone)
        preset.name = "Tracked Preset"
        try presetPool.addPreset(preset)
        
        // Record usage
        try presetPool.recordUsage(of: preset)
        try presetPool.recordUsage(of: preset)
        try presetPool.recordUsage(of: preset)
        
        // Get usage stats
        let stats = presetPool.usageStats(for: preset)
        XCTAssertEqual(stats.useCount, 3)
        XCTAssertNotNil(stats.lastUsed)
        XCTAssertNotNil(stats.firstUsed)
        
        // Get most used presets
        let mostUsed = presetPool.mostUsedPresets(limit: 10)
        XCTAssertEqual(mostUsed.first?.name, "Tracked Preset")
        
        // Get recently used presets
        let recentlyUsed = presetPool.recentlyUsedPresets(limit: 10)
        XCTAssertEqual(recentlyUsed.first?.name, "Tracked Preset")
    }
    
    // MARK: - Preset Comparison
    
    func testPresetComparison() throws {
        // Test preset comparison functionality
        
        let preset1 = createTestPreset(machine: .fmTone)
        preset1.name = "Preset 1"
        preset1.settings = ["algorithm": 3, "ratio": 1.5, "feedback": 0.8]
        
        let preset2 = createTestPreset(machine: .fmTone)
        preset2.name = "Preset 2"
        preset2.settings = ["algorithm": 3, "ratio": 2.0, "feedback": 0.8]
        
        try presetPool.addPreset(preset1)
        try presetPool.addPreset(preset2)
        
        // Compare presets
        let differences = presetPool.comparePresets(preset1, preset2)
        XCTAssertEqual(differences.count, 1) // Only ratio is different
        XCTAssertEqual(differences.first?.parameter, "ratio")
        XCTAssertEqual(differences.first?.value1 as? Double, 1.5)
        XCTAssertEqual(differences.first?.value2 as? Double, 2.0)
        
        // Find similar presets
        let similar = try presetPool.findSimilarPresets(to: preset1, threshold: 0.8)
        XCTAssertEqual(similar.count, 1)
        XCTAssertEqual(similar.first?.name, "Preset 2")
    }
    
    // MARK: - Preset Validation
    
    func testPresetValidation() throws {
        // Test preset validation before adding to pool
        
        // Valid preset
        let validPreset = createTestPreset(machine: .fmTone)
        validPreset.name = "Valid Preset"
        XCTAssertNoThrow(try presetPool.validatePreset(validPreset))
        
        // Invalid preset - no name
        let noNamePreset = createTestPreset(machine: .fmTone)
        noNamePreset.name = nil
        XCTAssertThrowsError(try presetPool.validatePreset(noNamePreset)) { error in
            XCTAssertEqual(error as? PresetPoolError, .invalidPresetName)
        }
        
        // Invalid preset - duplicate name
        try presetPool.addPreset(validPreset)
        let duplicatePreset = createTestPreset(machine: .fmTone)
        duplicatePreset.name = "Valid Preset"
        XCTAssertThrowsError(try presetPool.addPreset(duplicatePreset)) { error in
            XCTAssertEqual(error as? PresetPoolError, .duplicatePresetName)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestPreset(machine: MachineType) -> Preset {
        let preset = dataLayer.presetRepository.createPreset(
            name: "Test Preset",
            project: project
        )
        preset.settings = createDefaultSettings(for: machine)
        preset.machine = machine.rawValue
        return preset
    }
    
    private func createDefaultSettings(for machine: MachineType) -> [String: Any] {
        switch machine {
        case .fmTone:
            return [
                "algorithm": 1,
                "ratio": 1.0,
                "feedback": 0.5,
                "level": 0.8
            ]
        case .fmDrum:
            return [
                "pitch": 60,
                "decay": 0.5,
                "noise": 0.2,
                "level": 0.8
            ]
        case .wavetone:
            return [
                "waveform": "saw",
                "position": 0.5,
                "width": 0.5,
                "level": 0.8
            ]
        case .swarmer:
            return [
                "voices": 7,
                "detune": 0.1,
                "spread": 0.5,
                "level": 0.8
            ]
        }
    }
    
    private func createOldFormatPresets() -> [OldFormatPreset] {
        // Simulate old preset format for migration testing
        return [
            OldFormatPreset(name: "Old Bass", category: "Bass", data: Data()),
            OldFormatPreset(name: "Old Lead", category: "Lead", data: Data()),
            OldFormatPreset(name: "Old Pad", category: "Pad", data: Data())
        ]
    }
}

// MARK: - Supporting Types

enum PresetPoolError: Error, Equatable {
    case invalidPresetName
    case duplicatePresetName
    case presetNotFound
    case invalidCategory
    case tagLimitExceeded
}

struct PresetSearchCriteria {
    let query: String?
    let category: String?
    let machine: MachineType?
    let tags: [String]?
}

enum PresetSortOption {
    case name
    case dateCreated
    case lastUsed
    case category
}

struct PresetUsageStats {
    let useCount: Int
    let firstUsed: Date?
    let lastUsed: Date?
}

struct PresetDifference {
    let parameter: String
    let value1: Any
    let value2: Any
}

struct OldFormatPreset {
    let name: String
    let category: String
    let data: Data
}

class PresetPoolMigrator {
    func migrate(oldPresets: [OldFormatPreset], to project: Project) throws -> PresetPool {
        // Migration implementation would go here
        return PresetPool(project: project, context: project.managedObjectContext!)
    }
}

// MARK: - Preset Extension for Testing

extension Preset {
    var machine: String? {
        get { settings?["machine"] as? String }
        set { 
            var currentSettings = settings ?? [:]
            currentSettings["machine"] = newValue
            settings = currentSettings
        }
    }
    
    var lastUsed: Date? {
        get { settings?["lastUsed"] as? Date }
        set {
            var currentSettings = settings ?? [:]
            currentSettings["lastUsed"] = newValue
            settings = currentSettings
        }
    }
}