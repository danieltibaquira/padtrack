import XCTest
import CoreData
@testable import DataLayer
@testable import DataModel
@testable import MachineProtocols

class PresetPoolTests: CoreDataTestBase {
    var presetPool: PresetPool!
    var testProject: Project!
    
    override func setUp() {
        super.setUp()
        testProject = createTestProject()
        presetPool = PresetPool(project: testProject, context: testContext)
    }
    
    override func tearDown() {
        presetPool = nil
        testProject = nil
        super.tearDown()
    }
    
    // MARK: - Basic Operations Tests
    
    func testPresetPoolOperations() throws {
        // Test all preset pool CRUD operations
        
        // Create test preset
        let preset = createTestPreset(machine: .fmTone)
        preset.name = "Test Bass"
        preset.category = "Bass"
        preset.tags = ["deep", "sub", "808"]
        
        // Add to pool
        try presetPool.addPreset(preset)
        
        // Verify preset in pool
        XCTAssertTrue(presetPool.contains(preset))
        XCTAssertEqual(presetPool.presets(in: "Bass").count, 1)
        
        // Test preset search
        let searchResults = try presetPool.search(query: "bass")
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.name, "Test Bass")
        
        // Test tag search
        let tagResults = try presetPool.search(tag: "808")
        XCTAssertEqual(tagResults.count, 1)
        
        // Test preset removal
        try presetPool.removePreset(preset)
        XCTAssertFalse(presetPool.contains(preset))
    }
    
    func testPresetPoolPersistence() throws {
        // Test preset pool survives project save/load
        
        // Add multiple presets
        for i in 0..<10 {
            let preset = createTestPreset(machine: .fmTone)
            preset.name = "Preset \(i)"
            preset.category = i % 2 == 0 ? "Bass" : "Lead"
            try presetPool.addPreset(preset)
        }
        
        // Save context
        try testContext.save()
        
        // Create new preset pool instance
        let newPresetPool = PresetPool(project: testProject, context: testContext)
        
        // Verify preset pool intact
        XCTAssertEqual(newPresetPool.presetCount, 10)
        
        for i in 0..<10 {
            let preset = try newPresetPool.preset(named: "Preset \(i)")
            XCTAssertNotNil(preset)
        }
    }
    
    func testPresetPoolPerformance() throws {
        // Test preset pool performance with large numbers of presets
        
        measure {
            // Add 1000 presets
            for i in 0..<1000 {
                let preset = createTestPreset(machine: .fmTone)
                preset.name = "Preset \(i)"
                preset.category = ["Bass", "Lead", "Pad", "FX", "Drum"][i % 5]
                do {
                    try presetPool.addPreset(preset)
                } catch {
                    XCTFail("Failed to add preset: \(error)")
                }
            }
        }
        
        // Search performance test
        measure {
            do {
                let results = try presetPool.search(query: "Preset 5")
                XCTAssertGreaterThan(results.count, 0)
            } catch {
                XCTFail("Search failed: \(error)")
            }
        }
    }
    
    // MARK: - Category Management Tests
    
    func testPresetCategories() throws {
        // Test preset categorization
        
        // Add presets in different categories
        let categories = ["Bass", "Lead", "Pad", "FX", "Drum"]
        for (index, category) in categories.enumerated() {
            for j in 0..<5 {
                let preset = createTestPreset(machine: .fmTone)
                preset.name = "\(category) \(j)"
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
            let presets = presetPool.presets(in: category)
            XCTAssertEqual(presets.count, 5)
        }
    }
    
    func testPresetSorting() throws {
        // Test preset sorting options
        
        // Add presets with different attributes
        let presetData = [
            ("Zebra Bass", "Bass", Date().addingTimeInterval(-3600)),
            ("Alpha Lead", "Lead", Date().addingTimeInterval(-7200)),
            ("Beta Pad", "Pad", Date()),
            ("Gamma FX", "FX", Date().addingTimeInterval(-1800))
        ]
        
        for (name, category, date) in presetData {
            let preset = createTestPreset(machine: .fmTone)
            preset.name = name
            preset.category = category
            preset.createdAt = date
            try presetPool.addPreset(preset)
        }
        
        // Sort by name
        let sortedByName = presetPool.allPresets(sortedBy: .name)
        XCTAssertEqual(sortedByName.map { $0.name }, ["Alpha Lead", "Beta Pad", "Gamma FX", "Zebra Bass"])
        
        // Sort by category
        let sortedByCategory = presetPool.allPresets(sortedBy: .category)
        XCTAssertEqual(sortedByCategory.first?.category, "Bass")
        
        // Sort by date (newest first)
        let sortedByDate = presetPool.allPresets(sortedBy: .dateNewest)
        XCTAssertEqual(sortedByDate.first?.name, "Beta Pad")
    }
    
    // MARK: - Search and Filter Tests
    
    func testAdvancedSearch() throws {
        // Test advanced search capabilities
        
        // Create diverse preset pool
        let presetData = [
            ("808 Bass", "Bass", ["808", "sub", "deep"]),
            ("909 Kick", "Drum", ["909", "kick", "punch"]),
            ("Juno Pad", "Pad", ["juno", "warm", "vintage"]),
            ("FM Bell", "Lead", ["fm", "bell", "metallic"]),
            ("Sub Bass", "Bass", ["sub", "low", "deep"])
        ]
        
        for (name, category, tags) in presetData {
            let preset = createTestPreset(machine: .fmTone)
            preset.name = name
            preset.category = category
            preset.tags = tags
            try presetPool.addPreset(preset)
        }
        
        // Test fuzzy search
        let fuzzyResults = try presetPool.search(query: "bas", fuzzy: true)
        XCTAssertEqual(fuzzyResults.count, 2) // Should find both bass presets
        
        // Test tag filtering
        let tagResults = try presetPool.search(tags: ["sub"])
        XCTAssertEqual(tagResults.count, 2) // 808 Bass and Sub Bass
        
        // Test combined search
        let combinedResults = try presetPool.search(query: "bass", category: "Bass", tags: ["808"])
        XCTAssertEqual(combinedResults.count, 1)
        XCTAssertEqual(combinedResults.first?.name, "808 Bass")
    }
    
    // MARK: - Usage Tracking Tests
    
    func testPresetUsageTracking() throws {
        // Test preset usage statistics
        
        let preset = createTestPreset(machine: .fmTone)
        preset.name = "Popular Preset"
        try presetPool.addPreset(preset)
        
        // Track usage
        for _ in 0..<10 {
            presetPool.trackUsage(of: preset)
        }
        
        // Verify usage count
        let usage = presetPool.getUsageCount(for: preset)
        XCTAssertEqual(usage, 10)
        
        // Test most used presets
        let mostUsed = presetPool.mostUsedPresets(limit: 5)
        XCTAssertTrue(mostUsed.contains(preset))
        
        // Test recently used
        presetPool.trackUsage(of: preset)
        let recentlyUsed = presetPool.recentlyUsedPresets(limit: 5)
        XCTAssertEqual(recentlyUsed.first, preset)
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentPresetAccess() throws {
        // Test thread-safe access
        let expectation = XCTestExpectation(description: "Concurrent preset access")
        let queue = DispatchQueue(label: "test.preset.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        var errors: [Error] = []
        let errorLock = NSLock()
        
        // Add initial presets
        for i in 0..<10 {
            let preset = createTestPreset(machine: .fmTone)
            preset.name = "Initial \(i)"
            try presetPool.addPreset(preset)
        }
        
        // Simulate concurrent operations
        for i in 0..<20 {
            group.enter()
            queue.async {
                defer { group.leave() }
                
                do {
                    if i % 3 == 0 {
                        // Add operation
                        let preset = self.createTestPreset(machine: .fmTone)
                        preset.name = "Concurrent \(i)"
                        try self.presetPool.addPreset(preset)
                    } else if i % 3 == 1 {
                        // Search operation
                        _ = try self.presetPool.search(query: "Initial")
                    } else {
                        // Category operation
                        _ = self.presetPool.allCategories()
                    }
                } catch {
                    errorLock.lock()
                    errors.append(error)
                    errorLock.unlock()
                }
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        XCTAssertTrue(errors.isEmpty, "Concurrent access errors: \(errors)")
    }
    
    // MARK: - Import/Export Tests
    
    func testPresetImportExport() throws {
        // Test preset import/export functionality
        
        // Create presets
        let originalPresets: [Preset] = []
        for i in 0..<5 {
            let preset = createTestPreset(machine: .fmTone)
            preset.name = "Export Test \(i)"
            preset.category = "Test"
            preset.parameterData = createTestParameterData()
            try presetPool.addPreset(preset)
        }
        
        // Export presets
        let exportData = try presetPool.exportPresets(category: "Test")
        XCTAssertGreaterThan(exportData.count, 0)
        
        // Clear pool
        for preset in presetPool.presets(in: "Test") {
            try presetPool.removePreset(preset)
        }
        XCTAssertEqual(presetPool.presets(in: "Test").count, 0)
        
        // Import presets
        let importedCount = try presetPool.importPresets(from: exportData)
        XCTAssertEqual(importedCount, 5)
        
        // Verify imported presets
        let imported = presetPool.presets(in: "Test")
        XCTAssertEqual(imported.count, 5)
        
        for preset in imported {
            XCTAssertTrue(preset.name?.hasPrefix("Export Test") ?? false)
            XCTAssertNotNil(preset.parameterData)
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryEfficiency() throws {
        // Test memory usage with large preset pools
        
        // Monitor memory before
        let initialMemory = getMemoryUsage()
        
        // Add many presets
        for i in 0..<1000 {
            autoreleasepool {
                let preset = createTestPreset(machine: .fmTone)
                preset.name = "Memory Test \(i)"
                preset.parameterData = createTestParameterData()
                try? presetPool.addPreset(preset)
            }
        }
        
        // Monitor memory after
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Should be less than 10MB for 1000 presets
        XCTAssertLessThan(memoryIncrease, 10_000_000)
    }
    
    // MARK: - Helper Methods
    
    private func createTestProject() -> Project {
        let project = NSEntityDescription.insertNewObject(forEntityName: "Project", into: testContext) as! Project
        project.name = "Test Project"
        project.createdAt = Date()
        project.updatedAt = Date()
        return project
    }
    
    private func createTestPreset(machine: MachineType) -> Preset {
        let preset = NSEntityDescription.insertNewObject(forEntityName: "Preset", into: testContext) as! Preset
        preset.machine = machine.rawValue
        preset.createdAt = Date()
        preset.updatedAt = Date()
        preset.project = testProject
        return preset
    }
    
    private func createTestParameterData() -> Data {
        // Create realistic parameter data
        let parameters: [String: Double] = [
            "algorithm": 3.0,
            "feedback": 0.5,
            "ratio1": 1.0,
            "ratio2": 2.0,
            "level1": 0.8,
            "level2": 0.6,
            "attack": 0.001,
            "decay": 0.2,
            "sustain": 0.7,
            "release": 0.5
        ]
        
        return try! JSONEncoder().encode(parameters)
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - PresetPool Sorting Options

enum PresetSortOption {
    case name
    case category
    case dateNewest
    case dateOldest
    case mostUsed
}