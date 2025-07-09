import XCTest
import CoreData
@testable import DataLayer
@testable import DataModel

/// Tests for project file format, export/import, and data migration
class ProjectFileFormatTests: XCTestCase {
    var testContext: NSManagedObjectContext!
    var dataLayer: DataLayerManager!
    var fileManager: ProjectFileManager!
    var migrator: DataMigrator!
    
    override func setUp() {
        super.setUp()
        let persistenceController = PersistenceController(inMemory: true)
        testContext = persistenceController.container.viewContext
        dataLayer = DataLayerManager(persistenceController: persistenceController)
        fileManager = ProjectFileManager(dataLayer: dataLayer)
        migrator = DataMigrator()
    }
    
    override func tearDown() {
        testContext = nil
        dataLayer = nil
        fileManager = nil
        migrator = nil
        super.tearDown()
    }
    
    // MARK: - File Format Stability Tests
    
    func testFileFormatStability() throws {
        // Test file format remains stable across app versions
        
        let project = try createTestProject()
        
        // Export in current format
        let projectData = try fileManager.exportProject(project, format: .current)
        
        // Verify format structure
        let json = try JSONSerialization.jsonObject(with: projectData) as! [String: Any]
        
        // Check required top-level keys
        XCTAssertNotNil(json["formatVersion"])
        XCTAssertNotNil(json["project"])
        XCTAssertNotNil(json["metadata"])
        
        // Check format version
        let formatVersion = json["formatVersion"] as! String
        XCTAssertEqual(formatVersion, ProjectFileFormat.currentVersion)
        
        // Verify can read with legacy reader
        let legacyProject = try fileManager.importProject(projectData, format: .legacy)
        XCTAssertEqual(legacyProject.name, project.name)
    }
    
    func testBinaryFormatSpecification() throws {
        // Test binary format follows specification
        
        let project = try createTestProject()
        let binaryData = try fileManager.exportProject(project, format: .binary)
        
        // Verify binary header
        let header = binaryData.prefix(16)
        let magic = header.prefix(4)
        XCTAssertEqual(magic, "DPAD".data(using: .utf8))
        
        // Verify version bytes
        let versionMajor = header[4]
        let versionMinor = header[5]
        let versionPatch = header[6]
        XCTAssertEqual(versionMajor, 1)
        XCTAssertEqual(versionMinor, 0)
        XCTAssertEqual(versionPatch, 0)
        
        // Verify compression flag
        let compressionFlag = header[7]
        XCTAssertTrue(compressionFlag == 0 || compressionFlag == 1)
        
        // Verify checksum exists
        let checksumStart = binaryData.count - 32
        let checksum = binaryData.suffix(32)
        XCTAssertEqual(checksum.count, 32) // SHA256
    }
    
    func testJSONFormatReadability() throws {
        // Test JSON format is human-readable
        
        let project = try createTestProject()
        let jsonData = try fileManager.exportProject(project, format: .json)
        
        // Parse JSON
        let json = try JSONSerialization.jsonObject(with: jsonData, options: .fragmentsAllowed) as! [String: Any]
        
        // Verify structure is intuitive
        let projectData = json["project"] as! [String: Any]
        XCTAssertNotNil(projectData["name"])
        XCTAssertNotNil(projectData["patterns"])
        XCTAssertNotNil(projectData["kits"])
        XCTAssertNotNil(projectData["presets"])
        
        // Verify patterns are readable
        let patterns = projectData["patterns"] as! [[String: Any]]
        XCTAssertGreaterThan(patterns.count, 0)
        
        let pattern = patterns.first!
        XCTAssertNotNil(pattern["name"])
        XCTAssertNotNil(pattern["length"])
        XCTAssertNotNil(pattern["tempo"])
        XCTAssertNotNil(pattern["tracks"])
        
        // Verify pretty printing
        let jsonString = String(data: jsonData, encoding: .utf8)!
        XCTAssertTrue(jsonString.contains("\n")) // Should be formatted
        XCTAssertTrue(jsonString.contains("  ")) // Should be indented
    }
    
    // MARK: - Export Tests
    
    func testCompleteProjectExport() throws {
        // Test exporting a complete project preserves all data
        
        let project = try createComplexProject()
        
        // Export project
        let exportData = try fileManager.exportProject(project)
        
        // Parse exported data
        let json = try JSONSerialization.jsonObject(with: exportData) as! [String: Any]
        let projectData = json["project"] as! [String: Any]
        
        // Verify all data exported
        XCTAssertEqual(projectData["name"] as? String, project.name)
        
        // Verify patterns
        let patterns = projectData["patterns"] as! [[String: Any]]
        XCTAssertEqual(patterns.count, project.patterns?.count)
        
        // Verify tracks in patterns
        for pattern in patterns {
            let tracks = pattern["tracks"] as! [[String: Any]]
            XCTAssertEqual(tracks.count, 16) // All tracks exported
            
            // Verify trigs in tracks
            for track in tracks {
                let trigs = track["trigs"] as! [[String: Any]]
                XCTAssertGreaterThan(trigs.count, 0)
                
                // Verify parameter locks
                for trig in trigs {
                    if let pLocks = trig["parameterLocks"] as? [String: Any] {
                        XCTAssertGreaterThan(pLocks.count, 0)
                    }
                }
            }
        }
        
        // Verify kits
        let kits = projectData["kits"] as! [[String: Any]]
        XCTAssertEqual(kits.count, project.kits?.count)
        
        // Verify presets
        let presets = projectData["presets"] as! [[String: Any]]
        XCTAssertEqual(presets.count, project.presets?.count)
    }
    
    func testSelectiveExport() throws {
        // Test selective export of project components
        
        let project = try createComplexProject()
        
        // Export only patterns
        let options = ExportOptions(
            includePatterns: true,
            includeKits: false,
            includePresets: false,
            includeAudioFiles: false
        )
        
        let exportData = try fileManager.exportProject(project, options: options)
        let json = try JSONSerialization.jsonObject(with: exportData) as! [String: Any]
        let projectData = json["project"] as! [String: Any]
        
        // Verify selective export
        XCTAssertNotNil(projectData["patterns"])
        XCTAssertNil(projectData["kits"])
        XCTAssertNil(projectData["presets"])
        
        // Verify patterns still have track references
        let patterns = projectData["patterns"] as! [[String: Any]]
        for pattern in patterns {
            let tracks = pattern["tracks"] as! [[String: Any]]
            for track in tracks {
                // Kit and preset IDs should be preserved for re-linking
                XCTAssertNotNil(track["kitId"])
                XCTAssertNotNil(track["presetId"])
            }
        }
    }
    
    func testCompressedExport() throws {
        // Test compressed export reduces file size
        
        let project = try createComplexProject()
        
        // Export uncompressed
        let uncompressed = try fileManager.exportProject(project, compressed: false)
        
        // Export compressed
        let compressed = try fileManager.exportProject(project, compressed: true)
        
        // Verify compression
        XCTAssertLessThan(compressed.count, uncompressed.count)
        
        // Verify can decompress and import
        let imported = try fileManager.importProject(from: compressed)
        XCTAssertEqual(imported.name, project.name)
        XCTAssertEqual(imported.patterns?.count, project.patterns?.count)
    }
    
    // MARK: - Import Tests
    
    func testCompleteProjectImport() throws {
        // Test importing preserves all project data
        
        let originalProject = try createComplexProject()
        
        // Export and reimport
        let exportData = try fileManager.exportProject(originalProject)
        
        // Delete original to ensure clean import
        try dataLayer.projectRepository.delete(originalProject)
        try dataLayer.save()
        
        // Import project
        let importedProject = try fileManager.importProject(from: exportData)
        
        // Verify all data imported correctly
        XCTAssertEqual(importedProject.name, originalProject.name)
        XCTAssertEqual(importedProject.patterns?.count, originalProject.patterns?.count)
        XCTAssertEqual(importedProject.kits?.count, originalProject.kits?.count)
        XCTAssertEqual(importedProject.presets?.count, originalProject.presets?.count)
        
        // Deep verify pattern data
        let originalPatterns = (originalProject.patterns?.allObjects as? [Pattern] ?? []).sorted { $0.name! < $1.name! }
        let importedPatterns = (importedProject.patterns?.allObjects as? [Pattern] ?? []).sorted { $0.name! < $1.name! }
        
        for (original, imported) in zip(originalPatterns, importedPatterns) {
            XCTAssertEqual(imported.name, original.name)
            XCTAssertEqual(imported.length, original.length)
            XCTAssertEqual(imported.tempo, original.tempo)
            XCTAssertEqual(imported.tracks?.count, original.tracks?.count)
        }
    }
    
    func testImportValidation() throws {
        // Test import validation catches invalid data
        
        // Test corrupted file
        let corruptedData = "Not a valid project file".data(using: .utf8)!
        XCTAssertThrowsError(try fileManager.importProject(from: corruptedData)) { error in
            XCTAssertEqual(error as? FileFormatError, .invalidFormat)
        }
        
        // Test wrong format version
        var invalidJSON: [String: Any] = [
            "formatVersion": "99.0.0",
            "project": [:]
        ]
        let invalidData = try JSONSerialization.data(withJSONObject: invalidJSON)
        XCTAssertThrowsError(try fileManager.importProject(from: invalidData)) { error in
            XCTAssertEqual(error as? FileFormatError, .unsupportedVersion)
        }
        
        // Test missing required fields
        invalidJSON = [
            "formatVersion": ProjectFileFormat.currentVersion,
            "project": [
                // Missing name
                "patterns": []
            ]
        ]
        let missingFieldData = try JSONSerialization.data(withJSONObject: invalidJSON)
        XCTAssertThrowsError(try fileManager.importProject(from: missingFieldData)) { error in
            XCTAssertEqual(error as? FileFormatError, .missingRequiredField("name"))
        }
    }
    
    func testImportConflictResolution() throws {
        // Test handling of naming conflicts during import
        
        let project1 = try createTestProject()
        project1.name = "My Project"
        try dataLayer.save()
        
        // Export project
        let exportData = try fileManager.exportProject(project1)
        
        // Import same project - should handle name conflict
        let importedProject = try fileManager.importProject(from: exportData)
        
        // Should have different name
        XCTAssertNotEqual(importedProject.name, project1.name)
        XCTAssertTrue(importedProject.name?.contains("My Project") ?? false)
        XCTAssertTrue(importedProject.name?.contains("Copy") ?? false || 
                     importedProject.name?.contains("2") ?? false)
    }
    
    // MARK: - Migration Tests
    
    func testDataMigration() throws {
        // Test migration from older data formats
        
        let oldFormatData = loadTestFile("project_v1.dppad")
        
        // Migrate project
        let migratedProject = try migrator.migrateProject(from: oldFormatData)
        
        // Verify migration preserved essential data
        XCTAssertNotNil(migratedProject.name)
        XCTAssertGreaterThan(migratedProject.patterns?.count ?? 0, 0)
        XCTAssertTrue(try validateProjectIntegrity(migratedProject))
        
        // Verify new fields have defaults
        for pattern in migratedProject.patterns?.allObjects as? [Pattern] ?? [] {
            XCTAssertNotNil(pattern.createdAt)
            XCTAssertNotNil(pattern.updatedAt)
        }
    }
    
    func testMigrationPath() throws {
        // Test complete migration path from v1 to current
        
        let versions = ["v1", "v2", "v3"]
        var projectData = loadTestFile("project_v1.dppad")
        
        for (index, version) in versions.enumerated() {
            if index < versions.count - 1 {
                let nextVersion = versions[index + 1]
                projectData = try migrator.migrate(from: version, to: nextVersion, data: projectData)
            }
        }
        
        // Import final migrated data
        let project = try fileManager.importProject(from: projectData)
        XCTAssertNotNil(project)
        XCTAssertTrue(try validateProjectIntegrity(project))
    }
    
    func testBackwardCompatibility() throws {
        // Test current format can be read by older versions (with degradation)
        
        let project = try createComplexProject()
        
        // Export in compatibility mode
        let compatData = try fileManager.exportProject(project, format: .compatible)
        
        // Verify older version markers
        let json = try JSONSerialization.jsonObject(with: compatData) as! [String: Any]
        let metadata = json["metadata"] as! [String: Any]
        XCTAssertNotNil(metadata["backwardCompatible"])
        XCTAssertEqual(metadata["minVersion"] as? String, "1.0.0")
        
        // Verify non-essential new features are excluded
        let projectData = json["project"] as! [String: Any]
        // New features should be in separate extension block
        XCTAssertNotNil(projectData["extensions"])
    }
    
    // MARK: - Performance Tests
    
    func testLargeProjectExportPerformance() throws {
        // Test export performance with large projects
        
        let project = try createLargeProject()
        
        measure {
            do {
                let _ = try fileManager.exportProject(project)
            } catch {
                XCTFail("Export failed: \(error)")
            }
        }
    }
    
    func testLargeProjectImportPerformance() throws {
        // Test import performance with large projects
        
        let project = try createLargeProject()
        let exportData = try fileManager.exportProject(project)
        
        // Delete original
        try dataLayer.projectRepository.delete(project)
        try dataLayer.save()
        
        measure {
            do {
                let _ = try fileManager.importProject(from: exportData)
            } catch {
                XCTFail("Import failed: \(error)")
            }
        }
    }
    
    // MARK: - Checksum and Integrity Tests
    
    func testExportChecksum() throws {
        // Test export includes valid checksum
        
        let project = try createTestProject()
        let exportData = try fileManager.exportProject(project)
        
        // Verify checksum
        let isValid = try fileManager.verifyChecksum(of: exportData)
        XCTAssertTrue(isValid)
        
        // Corrupt data
        var corruptedData = exportData
        corruptedData[100] = 0xFF
        
        // Verify checksum fails
        let isCorrupted = try fileManager.verifyChecksum(of: corruptedData)
        XCTAssertFalse(isCorrupted)
    }
    
    func testIncrementalExport() throws {
        // Test incremental export for efficient backups
        
        let project = try createTestProject()
        
        // Initial export
        let initialExport = try fileManager.exportProject(project)
        let initialChecksum = try fileManager.calculateChecksum(of: initialExport)
        
        // Make small change
        let pattern = project.patterns?.allObjects.first as? Pattern
        pattern?.name = "Updated Pattern"
        try dataLayer.save()
        
        // Incremental export
        let incrementalData = try fileManager.exportIncremental(
            project: project,
            basedOn: initialChecksum
        )
        
        // Should be much smaller
        XCTAssertLessThan(incrementalData.count, initialExport.count / 2)
        
        // Apply incremental to get full project
        let fullData = try fileManager.applyIncremental(
            incrementalData,
            to: initialExport
        )
        
        // Import and verify
        let imported = try fileManager.importProject(from: fullData)
        XCTAssertEqual(imported.patterns?.allObjects.first?.name, "Updated Pattern")
    }
    
    // MARK: - Helper Methods
    
    private func createTestProject() throws -> Project {
        let project = dataLayer.projectRepository.createProject(name: "Test Project")
        
        let pattern = dataLayer.patternRepository.createPattern(
            name: "Pattern 1",
            project: project
        )
        
        let track = dataLayer.trackRepository.createTrack(
            name: "Track 1",
            pattern: pattern,
            trackIndex: 0
        )
        
        _ = dataLayer.trigRepository.createTrig(
            step: 0,
            note: 60,
            velocity: 100,
            track: track
        )
        
        try dataLayer.save()
        return project
    }
    
    private func createComplexProject() throws -> Project {
        let project = dataLayer.projectRepository.createProject(name: "Complex Project")
        
        // Create multiple patterns
        for i in 0..<4 {
            let pattern = dataLayer.patternRepository.createPattern(
                name: "Pattern \(i)",
                project: project,
                length: 16,
                tempo: 120.0 + Double(i * 5)
            )
            
            // Create kit
            let kit = dataLayer.kitRepository.createKit(name: "Kit \(i)")
            kit.project = project
            
            // Create tracks
            for j in 0..<16 {
                let track = dataLayer.trackRepository.createTrack(
                    name: "Track \(j)",
                    pattern: pattern,
                    trackIndex: Int16(j)
                )
                track.kit = kit
                
                // Create preset
                let preset = dataLayer.presetRepository.createPreset(
                    name: "Preset \(i)-\(j)",
                    project: project
                )
                preset.settings = [
                    "algorithm": i % 8,
                    "ratio": 1.0 + Double(j) / 10.0,
                    "feedback": 0.5
                ]
                track.preset = preset
                
                // Create trigs with parameter locks
                for k in stride(from: 0, to: 16, by: 4) {
                    let trig = dataLayer.trigRepository.createTrig(
                        step: Int16(k),
                        note: Int16(36 + j * 2),
                        velocity: 100,
                        track: track
                    )
                    
                    trig.pLocks = [
                        "cutoff": Double(k) / 16.0,
                        "resonance": 0.5 + Double(k) / 32.0
                    ]
                }
            }
        }
        
        try dataLayer.save()
        return project
    }
    
    private func createLargeProject() throws -> Project {
        let project = dataLayer.projectRepository.createProject(name: "Large Project")
        
        // Create many patterns
        for i in 0..<16 {
            let pattern = dataLayer.patternRepository.createPattern(
                name: "Pattern \(i)",
                project: project,
                length: 64,
                tempo: 120.0
            )
            
            // Create maximum tracks
            for j in 0..<16 {
                let track = dataLayer.trackRepository.createTrack(
                    name: "Track \(j)",
                    pattern: pattern,
                    trackIndex: Int16(j)
                )
                
                // Create many trigs
                for k in 0..<64 {
                    _ = dataLayer.trigRepository.createTrig(
                        step: Int16(k),
                        note: Int16(36 + (k % 24)),
                        velocity: Int16(64 + (k % 64)),
                        track: track
                    )
                }
            }
        }
        
        // Create many presets
        for i in 0..<128 {
            let preset = dataLayer.presetRepository.createPreset(
                name: "Preset \(i)",
                project: project
            )
            preset.settings = generateComplexPresetSettings()
        }
        
        try dataLayer.save()
        return project
    }
    
    private func generateComplexPresetSettings() -> [String: Any] {
        return [
            "algorithm": Int.random(in: 0..<8),
            "operators": [
                ["ratio": Double.random(in: 0.5...4.0), "level": Double.random(in: 0...1)],
                ["ratio": Double.random(in: 0.5...4.0), "level": Double.random(in: 0...1)],
                ["ratio": Double.random(in: 0.5...4.0), "level": Double.random(in: 0...1)],
                ["ratio": Double.random(in: 0.5...4.0), "level": Double.random(in: 0...1)]
            ],
            "envelopes": [
                ["attack": Double.random(in: 0...2), "decay": Double.random(in: 0...2)],
                ["attack": Double.random(in: 0...2), "decay": Double.random(in: 0...2)]
            ],
            "filter": [
                "cutoff": Double.random(in: 0...1),
                "resonance": Double.random(in: 0...1)
            ]
        ]
    }
    
    private func loadTestFile(_ filename: String) -> Data {
        // In real implementation, this would load test fixture files
        // For testing, return mock data
        return Data()
    }
    
    private func validateProjectIntegrity(_ project: Project) throws -> Bool {
        // Basic integrity check
        guard project.name != nil else { return false }
        
        for pattern in project.patterns?.allObjects as? [Pattern] ?? [] {
            guard pattern.project == project,
                  pattern.name != nil else {
                return false
            }
        }
        
        return true
    }
}

// MARK: - Supporting Types

enum FileFormatError: Error, Equatable {
    case invalidFormat
    case unsupportedVersion
    case missingRequiredField(String)
    case checksumMismatch
    case compressionError
}

struct ProjectFileFormat {
    static let currentVersion = "2.0.0"
    static let minimumSupportedVersion = "1.0.0"
}

struct ExportOptions {
    let includePatterns: Bool
    let includeKits: Bool
    let includePresets: Bool
    let includeAudioFiles: Bool
}

class ProjectFileManager {
    let dataLayer: DataLayerManager
    
    init(dataLayer: DataLayerManager) {
        self.dataLayer = dataLayer
    }
    
    enum Format {
        case current
        case legacy
        case binary
        case json
        case compatible
    }
    
    func exportProject(_ project: Project, format: Format = .current, compressed: Bool = true, options: ExportOptions? = nil) throws -> Data {
        // Implementation would go here
        return Data()
    }
    
    func importProject(from data: Data, format: Format = .current) throws -> Project {
        // Implementation would go here
        return dataLayer.projectRepository.createProject(name: "Imported")
    }
    
    func verifyChecksum(of data: Data) throws -> Bool {
        // Implementation would go here
        return true
    }
    
    func calculateChecksum(of data: Data) throws -> String {
        // Implementation would go here
        return "checksum"
    }
    
    func exportIncremental(project: Project, basedOn checksum: String) throws -> Data {
        // Implementation would go here
        return Data()
    }
    
    func applyIncremental(_ incremental: Data, to base: Data) throws -> Data {
        // Implementation would go here
        return base
    }
}

class DataMigrator {
    func migrateProject(from data: Data) throws -> Project {
        // Implementation would go here
        let dataLayer = DataLayerManager.shared
        return dataLayer.projectRepository.createProject(name: "Migrated")
    }
    
    func migrate(from version: String, to nextVersion: String, data: Data) throws -> Data {
        // Implementation would go here
        return data
    }
}