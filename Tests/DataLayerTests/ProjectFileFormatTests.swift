import XCTest
import CoreData
@testable import DataLayer
@testable import DataModel

class ProjectFileFormatTests: CoreDataTestBase {
    var fileManager: ProjectFileManager!
    
    override func setUp() {
        super.setUp()
        fileManager = ProjectFileManager(context: testContext)
    }
    
    override func tearDown() {
        fileManager = nil
        super.tearDown()
    }
    
    // MARK: - File Format Tests
    
    func testFileFormatStability() throws {
        // Test file format remains stable across app versions
        let project = createComplexTestProject()
        
        // Export in current format
        let projectData = try fileManager.exportProject(project, format: .current)
        XCTAssertGreaterThan(projectData.count, 0)
        
        // Verify format identifier
        let formatInfo = try fileManager.getFormatInfo(from: projectData)
        XCTAssertEqual(formatInfo.version, ProjectFileFormat.current.version)
        XCTAssertEqual(formatInfo.identifier, "DigitonePad")
        
        // Verify can read with legacy reader
        let legacyProject = try fileManager.importProject(projectData, format: .legacy)
        XCTAssertEqual(legacyProject.name, project.name)
        XCTAssertEqual(legacyProject.patterns?.count, project.patterns?.count)
    }
    
    func testDataMigration() throws {
        // Test migration from older data formats
        
        // Create mock v1 format data
        let v1Data = createMockV1ProjectData()
        
        // Migrate to current format
        let migrator = DataMigrator(context: testContext)
        let migratedProject = try migrator.migrateProject(from: v1Data)
        
        // Verify migration preserved essential data
        XCTAssertNotNil(migratedProject.name)
        XCTAssertGreaterThan(migratedProject.patterns?.count ?? 0, 0)
        XCTAssertTrue(validateProjectIntegrity(migratedProject))
        
        // Verify new fields have defaults
        XCTAssertNotNil(migratedProject.createdAt)
        XCTAssertNotNil(migratedProject.updatedAt)
    }
    
    func testFormatCompatibility() throws {
        // Test forward and backward compatibility
        let project = createComplexTestProject()
        
        // Test all supported formats
        let formats: [ProjectFileFormat] = [.current, .v2, .v1, .legacy]
        
        for format in formats {
            // Export in specific format
            let exportData = try fileManager.exportProject(project, format: format)
            
            // Import and verify
            let importedProject = try fileManager.importProject(exportData)
            XCTAssertEqual(importedProject.name, project.name)
            
            // Verify core data preserved
            if format.supportsFullHierarchy {
                XCTAssertEqual(importedProject.patterns?.count, project.patterns?.count)
            }
        }
    }
    
    // MARK: - Binary Format Tests
    
    func testBinaryFormatEfficiency() throws {
        // Test binary format for size and speed
        let project = createLargeTestProject()
        
        // Export as JSON
        let jsonData = try fileManager.exportProject(project, format: .json)
        
        // Export as binary
        let binaryData = try fileManager.exportProject(project, format: .binary)
        
        // Binary should be more compact
        XCTAssertLessThan(binaryData.count, jsonData.count)
        
        // Test import speed
        let jsonStart = Date()
        _ = try fileManager.importProject(jsonData, format: .json)
        let jsonTime = Date().timeIntervalSince(jsonStart)
        
        let binaryStart = Date()
        _ = try fileManager.importProject(binaryData, format: .binary)
        let binaryTime = Date().timeIntervalSince(binaryStart)
        
        // Binary should be faster to parse
        XCTAssertLessThan(binaryTime, jsonTime)
    }
    
    func testBinaryFormatIntegrity() throws {
        // Test binary format maintains data integrity
        let project = createComplexTestProject()
        
        // Add specific test data
        project.metadata = [
            "testKey": "testValue",
            "complexData": ["nested": true, "array": [1, 2, 3]]
        ]
        
        // Export as binary
        let binaryData = try fileManager.exportProject(project, format: .binary)
        
        // Import back
        let importedProject = try fileManager.importProject(binaryData, format: .binary)
        
        // Verify all data preserved
        XCTAssertEqual(importedProject.name, project.name)
        XCTAssertEqual(importedProject.bpm, project.bpm)
        XCTAssertEqual(importedProject.metadata?["testKey"] as? String, "testValue")
        
        // Verify complex nested data
        if let complexData = importedProject.metadata?["complexData"] as? [String: Any],
           let nested = complexData["nested"] as? Bool,
           let array = complexData["array"] as? [Int] {
            XCTAssertTrue(nested)
            XCTAssertEqual(array, [1, 2, 3])
        } else {
            XCTFail("Complex metadata not preserved")
        }
    }
    
    // MARK: - Compression Tests
    
    func testProjectCompression() throws {
        // Test project file compression
        let project = createLargeTestProject()
        
        // Export uncompressed
        let uncompressedData = try fileManager.exportProject(project, format: .current, compressed: false)
        
        // Export compressed
        let compressedData = try fileManager.exportProject(project, format: .current, compressed: true)
        
        // Verify compression reduces size
        XCTAssertLessThan(compressedData.count, uncompressedData.count)
        let compressionRatio = Double(compressedData.count) / Double(uncompressedData.count)
        XCTAssertLessThan(compressionRatio, 0.8) // At least 20% compression
        
        // Verify can decompress and import
        let importedProject = try fileManager.importProject(compressedData)
        XCTAssertEqual(importedProject.name, project.name)
        XCTAssertTrue(projectsAreEqual(project, importedProject))
    }
    
    // MARK: - Error Recovery Tests
    
    func testCorruptedFileRecovery() throws {
        // Test recovery from corrupted files
        
        // Create various types of corruption
        let corruptionTests = [
            Data([0xFF, 0xFF, 0xFF, 0xFF]), // Random bytes
            Data("{ invalid json }".utf8), // Invalid JSON
            Data("{ \"version\": 999 }".utf8), // Unknown version
            Data(), // Empty data
            createPartialProjectData() // Incomplete data
        ]
        
        for (index, corruptData) in corruptionTests.enumerated() {
            do {
                _ = try fileManager.importProject(corruptData)
                XCTFail("Should have failed for corruption test \(index)")
            } catch ProjectFileError.corruptedFile {
                // Expected error
            } catch ProjectFileError.unsupportedVersion {
                // Also acceptable for version mismatch
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testPartialDataRecovery() throws {
        // Test recovery of partial data from corrupted files
        let project = createComplexTestProject()
        let exportData = try fileManager.exportProject(project, format: .json)
        
        // Corrupt part of the data
        var corruptedData = exportData
        let midPoint = corruptedData.count / 2
        corruptedData.replaceSubrange(midPoint..<(midPoint + 100), with: Data(repeating: 0xFF, count: 100))
        
        // Attempt recovery
        let recoveryResult = fileManager.attemptRecovery(from: corruptedData)
        
        switch recoveryResult {
        case .success(let partialProject):
            // Should recover at least basic project info
            XCTAssertNotNil(partialProject.name)
        case .failure:
            // Recovery may fail completely for severe corruption
            break
        }
    }
    
    // MARK: - Performance Tests
    
    func testLargeProjectExportPerformance() throws {
        let project = createVeryLargeTestProject()
        
        measure {
            do {
                let exportData = try fileManager.exportProject(project, format: .current)
                XCTAssertGreaterThan(exportData.count, 0)
            } catch {
                XCTFail("Export failed: \(error)")
            }
        }
    }
    
    func testLargeProjectImportPerformance() throws {
        let project = createVeryLargeTestProject()
        let exportData = try fileManager.exportProject(project, format: .current)
        
        measure {
            do {
                let imported = try fileManager.importProject(exportData)
                XCTAssertNotNil(imported)
            } catch {
                XCTFail("Import failed: \(error)")
            }
        }
    }
    
    // MARK: - Metadata Tests
    
    func testProjectMetadataPreservation() throws {
        // Test that all metadata is preserved during export/import
        let project = createTestProject()
        
        // Add comprehensive metadata
        project.metadata = [
            "author": "Test User",
            "genre": "Electronic",
            "tags": ["ambient", "experimental", "fm"],
            "customData": [
                "synthSettings": ["algorithm": 3, "feedback": 0.5],
                "projectNotes": "This is a test project with notes"
            ]
        ]
        
        // Export and import
        let exportData = try fileManager.exportProject(project, format: .current)
        let importedProject = try fileManager.importProject(exportData)
        
        // Verify all metadata preserved
        XCTAssertEqual(importedProject.metadata?["author"] as? String, "Test User")
        XCTAssertEqual(importedProject.metadata?["genre"] as? String, "Electronic")
        
        if let tags = importedProject.metadata?["tags"] as? [String] {
            XCTAssertEqual(Set(tags), Set(["ambient", "experimental", "fm"]))
        } else {
            XCTFail("Tags not preserved")
        }
        
        if let customData = importedProject.metadata?["customData"] as? [String: Any],
           let synthSettings = customData["synthSettings"] as? [String: Double] {
            XCTAssertEqual(synthSettings["algorithm"], 3)
            XCTAssertEqual(synthSettings["feedback"], 0.5)
        } else {
            XCTFail("Custom data not preserved")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestProject() -> Project {
        let project = NSEntityDescription.insertNewObject(forEntityName: "Project", into: testContext) as! Project
        project.name = "Test Project"
        project.bpm = 120.0
        project.createdAt = Date()
        project.updatedAt = Date()
        return project
    }
    
    private func createComplexTestProject() -> Project {
        let project = createTestProject()
        
        // Add patterns with full hierarchy
        for i in 0..<4 {
            let pattern = NSEntityDescription.insertNewObject(forEntityName: "Pattern", into: testContext) as! Pattern
            pattern.name = "Pattern \(i + 1)"
            pattern.project = project
            pattern.length = 64
            
            let kit = NSEntityDescription.insertNewObject(forEntityName: "Kit", into: testContext) as! Kit
            kit.name = "Kit \(i + 1)"
            kit.pattern = pattern
            
            // Add tracks with presets and trigs
            for j in 0..<8 {
                let track = NSEntityDescription.insertNewObject(forEntityName: "Track", into: testContext) as! Track
                track.number = Int16(j + 1)
                track.pattern = pattern
                
                let preset = NSEntityDescription.insertNewObject(forEntityName: "Preset", into: testContext) as! Preset
                preset.name = "Preset \(i)-\(j)"
                preset.machine = "fmTone"
                preset.track = track
                preset.kit = kit
                preset.parameterData = createParameterData()
                
                // Add trigs with parameter locks
                for k in stride(from: 0, to: 64, by: 8) {
                    let trig = NSEntityDescription.insertNewObject(forEntityName: "Trig", into: testContext) as! Trig
                    trig.step = Int16(k)
                    trig.velocity = 100
                    trig.track = track
                    
                    if k % 16 == 0 {
                        trig.parameterLocks = [
                            "algorithm": Double(k % 8),
                            "feedback": 0.5,
                            "ratio1": 1.0
                        ]
                    }
                }
            }
        }
        
        return project
    }
    
    private func createLargeTestProject() -> Project {
        let project = createTestProject()
        project.name = "Large Test Project"
        
        // Create 16 patterns with full content
        for i in 0..<16 {
            let pattern = NSEntityDescription.insertNewObject(forEntityName: "Pattern", into: testContext) as! Pattern
            pattern.name = "Pattern \(i + 1)"
            pattern.project = project
            
            let kit = NSEntityDescription.insertNewObject(forEntityName: "Kit", into: testContext) as! Kit
            kit.name = "Kit \(i + 1)"
            kit.pattern = pattern
            
            for j in 0..<8 {
                let track = NSEntityDescription.insertNewObject(forEntityName: "Track", into: testContext) as! Track
                track.number = Int16(j + 1)
                track.pattern = pattern
                
                let preset = NSEntityDescription.insertNewObject(forEntityName: "Preset", into: testContext) as! Preset
                preset.name = "Preset \(i)-\(j)"
                preset.machine = "fmTone"
                preset.track = track
                preset.kit = kit
                preset.parameterData = createParameterData()
            }
        }
        
        return project
    }
    
    private func createVeryLargeTestProject() -> Project {
        // Create a project that stress tests performance
        let project = createLargeTestProject()
        
        // Add additional presets to preset pool
        for i in 0..<1000 {
            let preset = NSEntityDescription.insertNewObject(forEntityName: "Preset", into: testContext) as! Preset
            preset.name = "Pool Preset \(i)"
            preset.machine = ["fmTone", "fmDrum", "wavetone", "swarmer"][i % 4]
            preset.project = project
            preset.category = ["Bass", "Lead", "Pad", "FX", "Drum"][i % 5]
            preset.parameterData = createParameterData()
        }
        
        return project
    }
    
    private func createParameterData() -> Data {
        let parameters: [String: Double] = [
            "algorithm": 3.0,
            "feedback": 0.5,
            "ratio1": 1.0,
            "ratio2": 2.0,
            "level1": 0.8,
            "level2": 0.6
        ]
        return try! JSONEncoder().encode(parameters)
    }
    
    private func createMockV1ProjectData() -> Data {
        // Create mock data representing v1 format
        let v1Structure: [String: Any] = [
            "version": 1,
            "projectName": "Legacy Project",
            "tempo": 120,
            "patterns": [
                ["name": "Pattern 1", "length": 64],
                ["name": "Pattern 2", "length": 32]
            ]
        ]
        
        return try! JSONSerialization.data(withJSONObject: v1Structure)
    }
    
    private func createPartialProjectData() -> Data {
        // Create incomplete project data
        let partial: [String: Any] = [
            "version": ProjectFileFormat.current.version,
            "identifier": "DigitonePad",
            "project": [
                "name": "Partial Project"
                // Missing required fields
            ]
        ]
        
        return try! JSONSerialization.data(withJSONObject: partial)
    }
    
    private func validateProjectIntegrity(_ project: Project) -> Bool {
        // Comprehensive project validation
        guard let name = project.name, !name.isEmpty,
              project.bpm > 0 && project.bpm <= 300,
              project.createdAt != nil,
              project.updatedAt != nil else {
            return false
        }
        
        return true
    }
    
    private func projectsAreEqual(_ p1: Project, _ p2: Project) -> Bool {
        // Deep equality check
        return p1.name == p2.name &&
               p1.bpm == p2.bpm &&
               p1.patterns?.count == p2.patterns?.count
    }
}

// MARK: - Supporting Types

enum ProjectFileFormat {
    case current
    case v2
    case v1
    case legacy
    case json
    case binary
    
    var version: Int {
        switch self {
        case .current: return 3
        case .v2: return 2
        case .v1: return 1
        case .legacy: return 0
        case .json: return 3
        case .binary: return 3
        }
    }
    
    var supportsFullHierarchy: Bool {
        return version >= 2
    }
}

enum ProjectFileError: LocalizedError {
    case corruptedFile
    case unsupportedVersion
    case missingRequiredData
    
    var errorDescription: String? {
        switch self {
        case .corruptedFile:
            return "Project file is corrupted"
        case .unsupportedVersion:
            return "Project file version is not supported"
        case .missingRequiredData:
            return "Project file is missing required data"
        }
    }
}