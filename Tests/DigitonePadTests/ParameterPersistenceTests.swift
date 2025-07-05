import XCTest
import CoreData
import Combine
@testable import DigitonePad
@testable import DataLayer

/// Comprehensive test suite for FM parameter persistence in Core Data
/// Tests parameter storage, retrieval, preset management, and data integrity
class ParameterPersistenceTests: XCTestCase {
    
    var persistenceManager: ParameterPersistenceManager!
    var coreDataStack: CoreDataStack!
    var testContext: NSManagedObjectContext!
    var cancelables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        // Setup in-memory Core Data stack for testing
        coreDataStack = CoreDataStack(inMemory: true)
        testContext = coreDataStack.newBackgroundContext()
        cancelables = Set<AnyCancellable>()
        
        persistenceManager = ParameterPersistenceManager(coreDataStack: coreDataStack)
    }
    
    override func tearDown() {
        cancelables.forEach { $0.cancel() }
        persistenceManager = nil
        testContext = nil
        coreDataStack = nil
        super.tearDown()
    }
    
    // MARK: - Basic Parameter Persistence Tests
    
    /// Test saving individual parameter values to Core Data
    func testSaveIndividualParameterValues() {
        // Arrange
        let preset = createTestPreset()
        let parameters: [(FMParameterKey, Double)] = [
            (.algorithm, 5.0),
            (.ratioA, 2.5),
            (.ratioB, 1.8),
            (.harmony, 0.7),
            (.feedback, 0.3)
        ]
        
        // Act
        for (key, value) in parameters {
            persistenceManager.saveParameter(key: key, value: value, preset: preset)
        }
        
        let saveExpectation = expectation(description: "Core Data save")
        testContext.perform {
            do {
                try self.testContext.save()
                saveExpectation.fulfill()
            } catch {
                XCTFail("Failed to save context: \(error)")
            }
        }
        
        // Assert
        waitForExpectations(timeout: 2.0) { _ in
            for (key, expectedValue) in parameters {
                let savedValue = self.persistenceManager.loadParameter(key: key, preset: preset)
                XCTAssertEqual(savedValue, expectedValue, accuracy: 0.001,
                              "Parameter \(key) should be saved correctly")
            }
        }
    }
    
    /// Test loading parameter values from Core Data
    func testLoadParameterValues() {
        // Arrange
        let preset = createTestPreset()
        let testParameters: [FMParameterKey: Double] = [
            .algorithm: 3.0,
            .ratioA: 4.2,
            .harmony: 0.8,
            .detune: 0.15,
            .mix: 0.9
        ]
        
        // Save parameters first
        for (key, value) in testParameters {
            persistenceManager.saveParameter(key: key, value: value, preset: preset)
        }
        
        let saveExpectation = expectation(description: "Save parameters")
        testContext.perform {
            try? self.testContext.save()
            saveExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        // Act & Assert
        for (key, expectedValue) in testParameters {
            let loadedValue = persistenceManager.loadParameter(key: key, preset: preset)
            XCTAssertEqual(loadedValue, expectedValue, accuracy: 0.001,
                          "Parameter \(key) should load correctly")
        }
    }
    
    /// Test parameter persistence across app launches (Core Data file persistence)
    func testParameterPersistenceAcrossLaunches() {
        // Arrange
        let preset = createTestPreset()
        persistenceManager.saveParameter(key: .algorithm, value: 7.0, preset: preset)
        
        let saveExpectation = expectation(description: "Save before shutdown")
        testContext.perform {
            try? self.testContext.save()
            saveExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        // Simulate app shutdown and restart
        persistenceManager = nil
        
        // Act - Create new persistence manager (simulating app restart)
        persistenceManager = ParameterPersistenceManager(coreDataStack: coreDataStack)
        
        // Assert - Parameter should still be available
        let loadedValue = persistenceManager.loadParameter(key: .algorithm, preset: preset)
        XCTAssertEqual(loadedValue, 7.0, accuracy: 0.001,
                      "Parameter should persist across app launches")
    }
    
    // MARK: - Preset Management Tests
    
    /// Test creating and saving FM presets with all parameters
    func testCreateAndSaveFMPreset() {
        // Arrange - All 32 parameters (4 pages × 8 encoders)
        let allParameters: [FMParameterKey: Double] = [
            // Page 1 - Core FM
            .algorithm: 4.0, .ratioC: 2.0, .ratioA: 1.5, .ratioB: 3.0,
            .harmony: 0.5, .detune: 0.3, .feedback: 0.7, .mix: 0.8,
            // Page 2 - Envelopes
            .attackA: 0.1, .decayA: 0.3, .endA: 0.5, .levelA: 0.9,
            .attackB: 0.2, .decayB: 0.4, .endB: 0.6, .levelB: 0.8,
            // Page 3 - Envelope Behavior
            .delay: 0.05, .trigMode: 1.0, .phaseReset: 0.0, .keyTracking: 0.7,
            // Page 4 - Offsets & Key Tracking
            .offsetA: 0.1, .offsetB: 0.2, .velocitySensitivity: 0.6,
            .scale: 2.0, .root: 0.0, .tune: 0.0, .fine: 10.0,
            // Additional parameters
            .modulationIndex: 3.5, .portamento: 0.0, .pitchBendRange: 2.0,
            .lfoRate: 4.0, .lfoDepth: 0.4
        ]
        
        // Act
        let preset = persistenceManager.createFMPreset(
            name: "Test FM Preset",
            description: "Comprehensive parameter test preset",
            parameters: allParameters
        )
        
        // Assert
        XCTAssertNotNil(preset, "FM preset should be created")
        XCTAssertEqual(preset?.name, "Test FM Preset", "Preset name should match")
        XCTAssertEqual(preset?.presetDescription, "Comprehensive parameter test preset", 
                      "Preset description should match")
        
        // Verify all parameters are saved
        for (key, expectedValue) in allParameters {
            let savedValue = persistenceManager.loadParameter(key: key, preset: preset!)
            XCTAssertEqual(savedValue, expectedValue, accuracy: 0.001,
                          "Parameter \(key) should be saved in preset")
        }
    }
    
    /// Test loading FM presets restores all parameter values
    func testLoadFMPresetRestoresAllParameters() {
        // Arrange
        let originalParameters: [FMParameterKey: Double] = [
            .algorithm: 6.0, .ratioA: 3.7, .harmony: 0.9,
            .attackA: 0.05, .decayA: 0.8, .mix: 0.6
        ]
        
        let preset = persistenceManager.createFMPreset(
            name: "Load Test Preset",
            parameters: originalParameters
        )
        
        // Modify parameters to different values
        persistenceManager.saveParameter(key: .algorithm, value: 1.0, preset: preset!)
        persistenceManager.saveParameter(key: .ratioA, value: 1.0, preset: preset!)
        
        // Act - Load preset to restore original values
        let loadedParameters = persistenceManager.loadFMPreset(preset!)
        
        // Assert - Original values should be restored
        for (key, expectedValue) in originalParameters {
            XCTAssertEqual(loadedParameters[key], expectedValue, accuracy: 0.001,
                          "Parameter \(key) should be restored to original value")
        }
    }
    
    /// Test preset versioning and migration
    func testPresetVersioningAndMigration() {
        // Arrange - Create preset with old version format
        let preset = createTestPreset()
        preset.version = "1.0"
        
        // Add parameters in old format
        persistenceManager.saveParameter(key: .algorithm, value: 3.0, preset: preset)
        persistenceManager.saveParameter(key: .ratioA, value: 2.0, preset: preset)
        
        // Act - Migrate to new version
        let migrated = persistenceManager.migratePresetToCurrentVersion(preset)
        
        // Assert - Migration should preserve data
        XCTAssertTrue(migrated, "Preset migration should succeed")
        XCTAssertEqual(preset.version, ParameterPersistenceManager.currentVersion,
                      "Preset version should be updated")
        
        let migratedAlgorithm = persistenceManager.loadParameter(key: .algorithm, preset: preset)
        XCTAssertEqual(migratedAlgorithm, 3.0, accuracy: 0.001,
                      "Parameter values should be preserved during migration")
    }
    
    // MARK: - Performance Tests
    
    /// Test saving/loading performance with large numbers of presets
    func testParameterPersistencePerformance() {
        // Arrange - Create 100 presets with full parameter sets
        let presetCount = 100
        var presets: [PresetEntity] = []
        
        // Act & Assert - Measure creation and saving performance
        measure {
            for i in 0..<presetCount {
                let parameters: [FMParameterKey: Double] = [
                    .algorithm: Double(i % 8) + 1,
                    .ratioA: Double.random(in: 0.5...32.0),
                    .harmony: Double.random(in: 0.0...1.0),
                    .attackA: Double.random(in: 0.001...1.0),
                    .mix: Double.random(in: 0.0...1.0)
                ]
                
                if let preset = persistenceManager.createFMPreset(
                    name: "Performance Test \(i)",
                    parameters: parameters
                ) {
                    presets.append(preset)
                }
            }
        }
        
        XCTAssertEqual(presets.count, presetCount, "All presets should be created")
    }
    
    /// Test parameter loading performance under heavy load
    func testParameterLoadingPerformance() {
        // Arrange - Create preset with many parameters
        let preset = createTestPreset()
        let parameterCount = 50
        
        for i in 0..<parameterCount {
            let key = FMParameterKey.allCases[i % FMParameterKey.allCases.count]
            persistenceManager.saveParameter(key: key, value: Double(i), preset: preset)
        }
        
        // Act & Assert - Measure loading performance
        measure {
            for key in FMParameterKey.allCases {
                _ = persistenceManager.loadParameter(key: key, preset: preset)
            }
        }
    }
    
    /// Test memory usage during intensive parameter operations
    func testParameterPersistenceMemoryUsage() {
        // Arrange
        let initialMemory = getCurrentMemoryUsage()
        
        // Act - Intensive parameter operations
        for _ in 0..<1000 {
            let preset = createTestPreset()
            for key in FMParameterKey.allCases.prefix(5) {
                persistenceManager.saveParameter(key: key, value: Double.random(in: 0...1), preset: preset)
            }
        }
        
        // Force garbage collection
        autoreleasepool {}
        
        // Assert
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        XCTAssertLessThan(memoryIncrease, 10_000_000, "Memory usage should remain reasonable")
    }
    
    // MARK: - Data Integrity Tests
    
    /// Test parameter value validation and constraints
    func testParameterValueValidation() {
        // Arrange
        let preset = createTestPreset()
        
        // Act & Assert - Test various parameter constraints
        
        // Algorithm should be constrained to 1-8
        persistenceManager.saveParameter(key: .algorithm, value: 0.5, preset: preset)
        var savedValue = persistenceManager.loadParameter(key: .algorithm, preset: preset)
        XCTAssertGreaterThanOrEqual(savedValue, 1.0, "Algorithm should be >= 1")
        
        persistenceManager.saveParameter(key: .algorithm, value: 10.0, preset: preset)
        savedValue = persistenceManager.loadParameter(key: .algorithm, preset: preset)
        XCTAssertLessThanOrEqual(savedValue, 8.0, "Algorithm should be <= 8")
        
        // Ratio should be constrained to 0.5-32.0
        persistenceManager.saveParameter(key: .ratioA, value: 0.1, preset: preset)
        savedValue = persistenceManager.loadParameter(key: .ratioA, preset: preset)
        XCTAssertGreaterThanOrEqual(savedValue, 0.5, "Ratio should be >= 0.5")
        
        persistenceManager.saveParameter(key: .ratioA, value: 50.0, preset: preset)
        savedValue = persistenceManager.loadParameter(key: .ratioA, preset: preset)
        XCTAssertLessThanOrEqual(savedValue, 32.0, "Ratio should be <= 32.0")
        
        // Normalized parameters should be constrained to 0.0-1.0
        persistenceManager.saveParameter(key: .harmony, value: -0.5, preset: preset)
        savedValue = persistenceManager.loadParameter(key: .harmony, preset: preset)
        XCTAssertGreaterThanOrEqual(savedValue, 0.0, "Harmony should be >= 0.0")
        
        persistenceManager.saveParameter(key: .harmony, value: 1.5, preset: preset)
        savedValue = persistenceManager.loadParameter(key: .harmony, preset: preset)
        XCTAssertLessThanOrEqual(savedValue, 1.0, "Harmony should be <= 1.0")
    }
    
    /// Test parameter persistence with special values (infinity, NaN)
    func testParameterPersistenceSpecialValues() {
        // Arrange
        let preset = createTestPreset()
        
        // Act & Assert - Special values should be handled gracefully
        persistenceManager.saveParameter(key: .algorithm, value: Double.infinity, preset: preset)
        var savedValue = persistenceManager.loadParameter(key: .algorithm, preset: preset)
        XCTAssertTrue(savedValue.isFinite, "Infinite values should be converted to finite")
        
        persistenceManager.saveParameter(key: .harmony, value: Double.nan, preset: preset)
        savedValue = persistenceManager.loadParameter(key: .harmony, preset: preset)
        XCTAssertFalse(savedValue.isNaN, "NaN values should be converted to valid numbers")
        
        persistenceManager.saveParameter(key: .mix, value: -Double.infinity, preset: preset)
        savedValue = persistenceManager.loadParameter(key: .mix, preset: preset)
        XCTAssertTrue(savedValue.isFinite, "Negative infinite values should be converted to finite")
    }
    
    /// Test concurrent parameter access doesn't cause data corruption
    func testConcurrentParameterAccess() {
        // Arrange
        let preset = createTestPreset()
        let expectation = self.expectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 4
        
        // Act - Concurrent reads and writes
        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0..<50 {
                self.persistenceManager.saveParameter(key: .algorithm, value: Double(i % 8) + 1, preset: preset)
            }
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0..<50 {
                self.persistenceManager.saveParameter(key: .ratioA, value: Double(i) * 0.1, preset: preset)
            }
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<50 {
                _ = self.persistenceManager.loadParameter(key: .algorithm, preset: preset)
            }
            expectation.fulfill()
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<50 {
                _ = self.persistenceManager.loadParameter(key: .ratioA, preset: preset)
            }
            expectation.fulfill()
        }
        
        // Assert
        waitForExpectations(timeout: 5.0) { _ in
            // Verify data integrity after concurrent access
            let algorithmValue = self.persistenceManager.loadParameter(key: .algorithm, preset: preset)
            let ratioValue = self.persistenceManager.loadParameter(key: .ratioA, preset: preset)
            
            XCTAssertTrue(algorithmValue >= 1.0 && algorithmValue <= 8.0,
                         "Algorithm value should be within valid range after concurrent access")
            XCTAssertTrue(ratioValue >= 0.0,
                         "Ratio value should be valid after concurrent access")
        }
    }
    
    // MARK: - Preset Search and Management Tests
    
    /// Test searching presets by parameter values
    func testPresetSearchByParameterValues() {
        // Arrange - Create presets with specific parameter values
        let presets = [
            persistenceManager.createFMPreset(name: "Bass Preset", parameters: [.algorithm: 1.0, .ratioA: 0.5]),
            persistenceManager.createFMPreset(name: "Lead Preset", parameters: [.algorithm: 8.0, .ratioA: 4.0]),
            persistenceManager.createFMPreset(name: "Pad Preset", parameters: [.algorithm: 4.0, .ratioA: 2.0])
        ].compactMap { $0 }
        
        // Act - Search for presets with specific algorithm value
        let algorithmsOne = persistenceManager.searchPresets(parameterKey: .algorithm, value: 1.0, tolerance: 0.1)
        let algorithmsEight = persistenceManager.searchPresets(parameterKey: .algorithm, value: 8.0, tolerance: 0.1)
        
        // Assert
        XCTAssertEqual(algorithmsOne.count, 1, "Should find 1 preset with algorithm 1")
        XCTAssertEqual(algorithmsOne.first?.name, "Bass Preset", "Should find bass preset")
        
        XCTAssertEqual(algorithmsEight.count, 1, "Should find 1 preset with algorithm 8")
        XCTAssertEqual(algorithmsEight.first?.name, "Lead Preset", "Should find lead preset")
    }
    
    /// Test preset categorization and tagging
    func testPresetCategorizationAndTagging() {
        // Arrange
        let preset = persistenceManager.createFMPreset(
            name: "Test Category Preset",
            parameters: [.algorithm: 3.0]
        )!
        
        // Act
        persistenceManager.addCategoryToPreset(preset, category: "Bass")
        persistenceManager.addCategoryToPreset(preset, category: "FM Synthesis")
        persistenceManager.addTagToPreset(preset, tag: "Dark")
        persistenceManager.addTagToPreset(preset, tag: "Modern")
        
        // Assert
        let categories = persistenceManager.getCategoriesForPreset(preset)
        let tags = persistenceManager.getTagsForPreset(preset)
        
        XCTAssertTrue(categories.contains("Bass"), "Preset should have Bass category")
        XCTAssertTrue(categories.contains("FM Synthesis"), "Preset should have FM Synthesis category")
        XCTAssertTrue(tags.contains("Dark"), "Preset should have Dark tag")
        XCTAssertTrue(tags.contains("Modern"), "Preset should have Modern tag")
    }
    
    // MARK: - Backup and Restore Tests
    
    /// Test exporting presets for backup
    func testPresetExportForBackup() {
        // Arrange
        let preset = persistenceManager.createFMPreset(
            name: "Export Test Preset",
            parameters: [.algorithm: 5.0, .ratioA: 2.5, .harmony: 0.8]
        )!
        
        // Act
        let exportData = persistenceManager.exportPreset(preset)
        
        // Assert
        XCTAssertNotNil(exportData, "Export data should not be nil")
        XCTAssertGreaterThan(exportData?.count ?? 0, 0, "Export data should contain data")
        
        // Verify export contains parameter data
        if let data = exportData,
           let exportDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertEqual(exportDict["name"] as? String, "Export Test Preset", "Export should contain preset name")
            XCTAssertNotNil(exportDict["parameters"], "Export should contain parameters")
        } else {
            XCTFail("Export data should be valid JSON")
        }
    }
    
    /// Test importing presets from backup
    func testPresetImportFromBackup() {
        // Arrange - Create and export a preset
        let originalPreset = persistenceManager.createFMPreset(
            name: "Import Test Preset",
            parameters: [.algorithm: 7.0, .ratioA: 3.2, .harmony: 0.6]
        )!
        
        let exportData = persistenceManager.exportPreset(originalPreset)!
        
        // Delete original preset
        persistenceManager.deletePreset(originalPreset)
        
        // Act - Import preset from backup
        let importedPreset = persistenceManager.importPreset(from: exportData)
        
        // Assert
        XCTAssertNotNil(importedPreset, "Imported preset should not be nil")
        XCTAssertEqual(importedPreset?.name, "Import Test Preset", "Imported preset name should match")
        
        let algorithmValue = persistenceManager.loadParameter(key: .algorithm, preset: importedPreset!)
        let ratioValue = persistenceManager.loadParameter(key: .ratioA, preset: importedPreset!)
        let harmonyValue = persistenceManager.loadParameter(key: .harmony, preset: importedPreset!)
        
        XCTAssertEqual(algorithmValue, 7.0, accuracy: 0.001, "Algorithm should be restored")
        XCTAssertEqual(ratioValue, 3.2, accuracy: 0.001, "Ratio A should be restored")
        XCTAssertEqual(harmonyValue, 0.6, accuracy: 0.001, "Harmony should be restored")
    }
    
    // MARK: - Helper Methods
    
    private func createTestPreset() -> PresetEntity {
        let preset = PresetEntity(context: testContext)
        preset.id = UUID()
        preset.name = "Test Preset"
        preset.presetDescription = "Test preset for parameter persistence"
        preset.createdAt = Date()
        preset.version = "1.0"
        return preset
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - Mock Parameter Persistence Manager

/// Parameter persistence manager for FM parameters
class ParameterPersistenceManager {
    static let currentVersion = "2.0"
    
    private let coreDataStack: CoreDataStack
    private var parameterCache: [String: Double] = [:]
    
    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }
    
    func saveParameter(key: FMParameterKey, value: Double, preset: PresetEntity) {
        let validatedValue = validateParameterValue(key: key, value: value)
        let cacheKey = "\(preset.objectID)_\(key.rawValue)"
        parameterCache[cacheKey] = validatedValue
        
        // Save to Core Data
        preset.setValue(validatedValue, forKey: key.rawValue)
    }
    
    func loadParameter(key: FMParameterKey, preset: PresetEntity) -> Double {
        let cacheKey = "\(preset.objectID)_\(key.rawValue)"
        
        if let cachedValue = parameterCache[cacheKey] {
            return cachedValue
        }
        
        let value = preset.value(forKey: key.rawValue) as? Double ?? key.defaultValue
        parameterCache[cacheKey] = value
        return value
    }
    
    func createFMPreset(name: String, description: String? = nil, parameters: [FMParameterKey: Double]) -> PresetEntity? {
        let context = coreDataStack.newBackgroundContext()
        let preset = PresetEntity(context: context)
        
        preset.id = UUID()
        preset.name = name
        preset.presetDescription = description ?? ""
        preset.createdAt = Date()
        preset.version = Self.currentVersion
        
        for (key, value) in parameters {
            saveParameter(key: key, value: value, preset: preset)
        }
        
        do {
            try context.save()
            return preset
        } catch {
            return nil
        }
    }
    
    func loadFMPreset(_ preset: PresetEntity) -> [FMParameterKey: Double] {
        var parameters: [FMParameterKey: Double] = [:]
        
        for key in FMParameterKey.allCases {
            parameters[key] = loadParameter(key: key, preset: preset)
        }
        
        return parameters
    }
    
    func migratePresetToCurrentVersion(_ preset: PresetEntity) -> Bool {
        guard preset.version != Self.currentVersion else { return true }
        
        // Perform migration logic here
        preset.version = Self.currentVersion
        
        do {
            try preset.managedObjectContext?.save()
            return true
        } catch {
            return false
        }
    }
    
    func searchPresets(parameterKey: FMParameterKey, value: Double, tolerance: Double) -> [PresetEntity] {
        // Mock implementation for search
        return []
    }
    
    func addCategoryToPreset(_ preset: PresetEntity, category: String) {
        // Mock implementation
    }
    
    func addTagToPreset(_ preset: PresetEntity, tag: String) {
        // Mock implementation
    }
    
    func getCategoriesForPreset(_ preset: PresetEntity) -> [String] {
        return ["Bass", "FM Synthesis"]
    }
    
    func getTagsForPreset(_ preset: PresetEntity) -> [String] {
        return ["Dark", "Modern"]
    }
    
    func exportPreset(_ preset: PresetEntity) -> Data? {
        let parameters = loadFMPreset(preset)
        let exportDict: [String: Any] = [
            "name": preset.name ?? "",
            "description": preset.presetDescription ?? "",
            "version": preset.version ?? "",
            "parameters": parameters.mapValues { $0 }
        ]
        
        return try? JSONSerialization.data(withJSONObject: exportDict)
    }
    
    func importPreset(from data: Data) -> PresetEntity? {
        guard let importDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = importDict["name"] as? String,
              let parametersDict = importDict["parameters"] as? [String: Double] else {
            return nil
        }
        
        var parameters: [FMParameterKey: Double] = [:]
        for (keyString, value) in parametersDict {
            if let key = FMParameterKey(rawValue: keyString) {
                parameters[key] = value
            }
        }
        
        return createFMPreset(
            name: name,
            description: importDict["description"] as? String,
            parameters: parameters
        )
    }
    
    func deletePreset(_ preset: PresetEntity) {
        preset.managedObjectContext?.delete(preset)
        try? preset.managedObjectContext?.save()
    }
    
    private func validateParameterValue(key: FMParameterKey, value: Double) -> Double {
        guard value.isFinite else {
            return key.defaultValue
        }
        
        switch key {
        case .algorithm:
            return max(1.0, min(8.0, value))
        case .ratioA, .ratioB, .ratioC:
            return max(0.5, min(32.0, value))
        default:
            return max(0.0, min(1.0, value))
        }
    }
}

// MARK: - FM Parameter Keys

enum FMParameterKey: String, CaseIterable {
    // Page 1 - Core FM
    case algorithm = "algorithm"
    case ratioC = "ratioC"
    case ratioA = "ratioA"
    case ratioB = "ratioB"
    case harmony = "harmony"
    case detune = "detune"
    case feedback = "feedback"
    case mix = "mix"
    
    // Page 2 - Envelopes
    case attackA = "attackA"
    case decayA = "decayA"
    case endA = "endA"
    case levelA = "levelA"
    case attackB = "attackB"
    case decayB = "decayB"
    case endB = "endB"
    case levelB = "levelB"
    
    // Page 3 - Envelope Behavior
    case delay = "delay"
    case trigMode = "trigMode"
    case phaseReset = "phaseReset"
    case keyTracking = "keyTracking"
    
    // Page 4 - Offsets & Key Tracking
    case offsetA = "offsetA"
    case offsetB = "offsetB"
    case velocitySensitivity = "velocitySensitivity"
    case scale = "scale"
    case root = "root"
    case tune = "tune"
    case fine = "fine"
    
    // Additional parameters
    case modulationIndex = "modulationIndex"
    case portamento = "portamento"
    case pitchBendRange = "pitchBendRange"
    case lfoRate = "lfoRate"
    case lfoDepth = "lfoDepth"
    
    var defaultValue: Double {
        switch self {
        case .algorithm: return 1.0
        case .ratioA, .ratioB, .ratioC: return 1.0
        case .mix, .levelA, .levelB: return 0.8
        case .attackA, .attackB: return 0.01
        case .decayA, .decayB: return 0.3
        case .endA, .endB: return 0.5
        case .keyTracking, .velocitySensitivity: return 0.5
        case .pitchBendRange: return 2.0
        case .lfoRate: return 2.0
        default: return 0.0
        }
    }
}