import XCTest
import CoreData
@testable import DataLayer
@testable import DataModel

/// Tests for +Drive emulation system
/// +Drive provides centralized storage for multiple projects and presets
class PlusDriveManagerTests: XCTestCase {
    var testContext: NSManagedObjectContext!
    var driveManager: PlusDriveManager!
    var dataLayer: DataLayerManager!
    
    override func setUp() {
        super.setUp()
        // Create in-memory test context
        testContext = createInMemoryTestContext()
        dataLayer = DataLayerManager(persistenceController: PersistenceController(inMemory: true))
        driveManager = PlusDriveManager(dataLayer: dataLayer)
    }
    
    override func tearDown() {
        testContext = nil
        driveManager = nil
        dataLayer = nil
        super.tearDown()
    }
    
    // MARK: - Project Listing Tests
    
    func testPlusDriveProjectListing() throws {
        // Test +Drive shows all available projects
        
        // Create test projects
        let project1 = try driveManager.createProject(name: "Project 1")
        let project2 = try driveManager.createProject(name: "Project 2")
        
        // Get project list
        let projectList = try driveManager.listProjects()
        
        XCTAssertEqual(projectList.count, 2)
        XCTAssertTrue(projectList.contains { $0.name == "Project 1" })
        XCTAssertTrue(projectList.contains { $0.name == "Project 2" })
        
        // Verify projects are sorted by name
        XCTAssertEqual(projectList[0].name, "Project 1")
        XCTAssertEqual(projectList[1].name, "Project 2")
    }
    
    func testPlusDriveProjectSearch() throws {
        // Test searching projects by name
        
        // Create test projects
        _ = try driveManager.createProject(name: "Techno Live Set")
        _ = try driveManager.createProject(name: "Ambient Experiments")
        _ = try driveManager.createProject(name: "Techno Patterns")
        
        // Search for "Techno"
        let searchResults = try driveManager.searchProjects(query: "Techno")
        
        XCTAssertEqual(searchResults.count, 2)
        XCTAssertTrue(searchResults.allSatisfy { $0.name.contains("Techno") })
    }
    
    func testPlusDriveProjectMetadata() throws {
        // Test project metadata is correctly tracked
        
        let project = try driveManager.createProject(name: "Test Project")
        
        // Add patterns and presets
        let pattern = try driveManager.addPattern(to: project, name: "Pattern 1")
        let preset = try driveManager.addPreset(to: project, name: "Bass Preset")
        
        // Get project info
        let projectInfo = try driveManager.getProjectInfo(projectId: project.id)
        
        XCTAssertEqual(projectInfo.name, "Test Project")
        XCTAssertEqual(projectInfo.patternCount, 1)
        XCTAssertEqual(projectInfo.presetCount, 1)
        XCTAssertNotNil(projectInfo.lastModified)
        XCTAssertGreaterThan(projectInfo.size, 0)
    }
    
    // MARK: - Project Export/Import Tests
    
    func testProjectExportImport() throws {
        // Test project can be exported and imported without data loss
        
        let originalProject = try createComplexTestProject()
        
        // Export project
        let exportData = try driveManager.exportProject(originalProject)
        XCTAssertGreaterThan(exportData.count, 0)
        
        // Import project
        let importedProject = try driveManager.importProject(from: exportData)
        
        // Verify data integrity
        XCTAssertEqual(importedProject.name, originalProject.name)
        XCTAssertEqual(importedProject.patterns.count, originalProject.patterns.count)
        XCTAssertEqual(importedProject.bpm, originalProject.bpm)
        
        // Deep comparison of all nested data
        XCTAssertTrue(projectsAreEqual(originalProject, importedProject))
    }
    
    func testProjectExportFormat() throws {
        // Test exported project format is correct
        
        let project = try driveManager.createProject(name: "Export Test")
        
        // Export as different formats
        let jsonData = try driveManager.exportProject(project, format: .json)
        let binaryData = try driveManager.exportProject(project, format: .binary)
        
        // Verify JSON format
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
        XCTAssertNotNil(jsonObject)
        
        // Verify binary format has header
        let header = binaryData.prefix(4)
        XCTAssertEqual(header, "DPAD".data(using: .utf8))
        
        // Both formats should be importable
        let jsonImport = try driveManager.importProject(from: jsonData)
        let binaryImport = try driveManager.importProject(from: binaryData)
        
        XCTAssertEqual(jsonImport.name, project.name)
        XCTAssertEqual(binaryImport.name, project.name)
    }
    
    func testCorruptedImportHandling() throws {
        // Test handling of corrupted import data
        
        let corruptedData = "Not a valid project file".data(using: .utf8)!
        
        XCTAssertThrowsError(try driveManager.importProject(from: corruptedData)) { error in
            XCTAssertTrue(error is PlusDriveError)
            if let driveError = error as? PlusDriveError {
                XCTAssertEqual(driveError, .invalidFileFormat)
            }
        }
    }
    
    // MARK: - Project Versioning Tests
    
    func testProjectVersioning() throws {
        // Test project versioning prevents data loss during updates
        
        let project = try driveManager.createProject(name: "Versioned Project")
        
        // Save initial version
        let version1 = try driveManager.saveProjectVersion(project)
        
        // Modify project
        _ = try driveManager.addPattern(to: project, name: "New Pattern")
        
        // Save new version
        let version2 = try driveManager.saveProjectVersion(project)
        
        // Verify versions are tracked
        let versions = try driveManager.getProjectVersions(projectId: project.id)
        XCTAssertEqual(versions.count, 2)
        XCTAssertEqual(versions[0].id, version1.id)
        XCTAssertEqual(versions[1].id, version2.id)
        
        // Verify can restore previous version
        let restoredProject = try driveManager.restoreProjectVersion(version1)
        XCTAssertEqual(restoredProject.patterns.count, 0) // Before pattern was added
    }
    
    func testAutomaticVersioning() throws {
        // Test automatic versioning on significant changes
        
        driveManager.enableAutoVersioning = true
        driveManager.autoVersioningThreshold = 5 // Version after 5 changes
        
        let project = try driveManager.createProject(name: "Auto Version Test")
        
        // Make changes
        for i in 0..<5 {
            _ = try driveManager.addPattern(to: project, name: "Pattern \(i)")
        }
        
        // Should have created an auto-version
        let versions = try driveManager.getProjectVersions(projectId: project.id)
        XCTAssertGreaterThanOrEqual(versions.count, 1)
        XCTAssertTrue(versions.last!.isAutoSave)
    }
    
    func testVersionCleanup() throws {
        // Test old versions are cleaned up to save space
        
        driveManager.maxVersionsPerProject = 3
        
        let project = try driveManager.createProject(name: "Version Cleanup Test")
        
        // Create more versions than the limit
        for i in 0..<5 {
            _ = try driveManager.addPattern(to: project, name: "Pattern \(i)")
            _ = try driveManager.saveProjectVersion(project)
        }
        
        // Should only keep the latest 3 versions
        let versions = try driveManager.getProjectVersions(projectId: project.id)
        XCTAssertEqual(versions.count, 3)
        
        // Verify oldest versions were removed
        XCTAssertTrue(versions.allSatisfy { $0.versionNumber >= 3 })
    }
    
    // MARK: - Storage Management Tests
    
    func testStorageQuota() throws {
        // Test storage quota enforcement
        
        driveManager.storageQuotaMB = 100 // 100MB quota
        
        // Create projects until quota is reached
        var totalSize: Int64 = 0
        var projectCount = 0
        
        while totalSize < driveManager.storageQuotaMB * 1024 * 1024 {
            do {
                let project = try driveManager.createProject(name: "Project \(projectCount)")
                let info = try driveManager.getProjectInfo(projectId: project.id)
                totalSize += info.size
                projectCount += 1
            } catch PlusDriveError.storageQuotaExceeded {
                break
            }
        }
        
        // Verify quota is enforced
        XCTAssertGreaterThan(projectCount, 0)
        XCTAssertThrowsError(try driveManager.createProject(name: "Over Quota")) { error in
            XCTAssertEqual(error as? PlusDriveError, .storageQuotaExceeded)
        }
    }
    
    func testStorageCleanup() throws {
        // Test storage cleanup suggestions
        
        // Create projects with different access patterns
        let oldProject = try driveManager.createProject(name: "Old Project")
        let largeProject = try driveManager.createProject(name: "Large Project")
        
        // Simulate old project not being accessed
        Thread.sleep(forTimeInterval: 0.1)
        
        // Add lots of data to large project
        for i in 0..<100 {
            _ = try driveManager.addPreset(to: largeProject, name: "Preset \(i)")
        }
        
        // Get cleanup suggestions
        let suggestions = try driveManager.getCleanupSuggestions()
        
        XCTAssertGreaterThan(suggestions.count, 0)
        XCTAssertTrue(suggestions.contains { $0.reason == .notRecentlyUsed || $0.reason == .largeSize })
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentProjectAccess() throws {
        // Test multiple threads can safely access project data
        
        let project = try driveManager.createProject(name: "Concurrent Test")
        let dispatchGroup = DispatchGroup()
        var errors: [Error] = []
        
        // Simulate concurrent read/write operations
        for i in 0..<10 {
            dispatchGroup.enter()
            DispatchQueue.global().async {
                defer { dispatchGroup.leave() }
                
                do {
                    if i % 2 == 0 {
                        // Write operation
                        _ = try self.driveManager.addPattern(to: project, name: "Pattern \(i)")
                    } else {
                        // Read operation
                        _ = try self.driveManager.getProjectInfo(projectId: project.id)
                    }
                } catch {
                    errors.append(error)
                }
            }
        }
        
        dispatchGroup.wait()
        XCTAssertTrue(errors.isEmpty, "Concurrent access errors: \(errors)")
        
        // Verify all patterns were added
        let finalProject = try driveManager.loadProject(projectId: project.id)
        XCTAssertEqual(finalProject.patterns.count, 5) // 5 even numbers
    }
    
    // MARK: - Backup and Recovery Tests
    
    func testAutomaticBackup() throws {
        // Test automatic backup creation
        
        driveManager.enableAutoBackup = true
        
        let project = try driveManager.createProject(name: "Backup Test")
        
        // Make changes to trigger backup
        _ = try driveManager.addPattern(to: project, name: "Pattern 1")
        try driveManager.saveProject(project)
        
        // Verify backup was created
        let backups = try driveManager.getProjectBackups(projectId: project.id)
        XCTAssertGreaterThan(backups.count, 0)
        XCTAssertEqual(backups.first?.projectId, project.id)
    }
    
    func testDisasterRecovery() throws {
        // Test recovery from catastrophic failure
        
        let project = try driveManager.createProject(name: "Recovery Test")
        _ = try driveManager.addPattern(to: project, name: "Important Pattern")
        
        // Simulate corruption
        try driveManager.simulateCorruption(projectId: project.id)
        
        // Attempt recovery
        let recoveredProject = try driveManager.recoverProject(projectId: project.id)
        
        XCTAssertNotNil(recoveredProject)
        XCTAssertEqual(recoveredProject.name, "Recovery Test")
        // May have lost some recent changes but core data should be intact
    }
    
    // MARK: - Performance Tests
    
    func testLargeProjectListPerformance() throws {
        // Test performance with many projects
        
        // Create many projects
        for i in 0..<100 {
            _ = try driveManager.createProject(name: "Project \(i)")
        }
        
        measure {
            do {
                let projects = try driveManager.listProjects()
                XCTAssertEqual(projects.count, 100)
            } catch {
                XCTFail("Failed to list projects: \(error)")
            }
        }
    }
    
    func testProjectLoadPerformance() throws {
        // Test loading performance for complex projects
        
        let project = try createComplexTestProject()
        let projectId = project.id
        
        measure {
            do {
                let loadedProject = try driveManager.loadProject(projectId: projectId)
                XCTAssertNotNil(loadedProject)
            } catch {
                XCTFail("Failed to load project: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createInMemoryTestContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "DigitonePad")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load in-memory store: \(error)")
            }
        }
        
        return container.viewContext
    }
    
    private func createComplexTestProject() throws -> PlusDriveProject {
        let project = try driveManager.createProject(name: "Complex Project")
        project.bpm = 128.0
        
        // Add patterns
        for i in 0..<4 {
            let pattern = try driveManager.addPattern(to: project, name: "Pattern \(i)")
            pattern.length = 16
            pattern.tempo = 120.0 + Double(i * 5)
            
            // Add tracks to pattern
            for j in 0..<8 {
                let track = try driveManager.addTrack(to: pattern, name: "Track \(j)")
                track.volume = 0.8
                track.pan = Float(j - 4) / 4.0
                
                // Add trigs to track
                for k in stride(from: 0, to: 16, by: 4) {
                    let trig = try driveManager.addTrig(to: track, step: k)
                    trig.note = 60 + (j * 2)
                    trig.velocity = 100
                    trig.probability = 80
                }
            }
        }
        
        // Add presets
        for i in 0..<20 {
            let preset = try driveManager.addPreset(to: project, name: "Preset \(i)")
            preset.category = ["Bass", "Lead", "Pad", "FX"][i % 4]
            preset.settings = ["algorithm": i % 8, "ratio": 1.0 + Double(i) / 10.0]
        }
        
        return project
    }
    
    private func projectsAreEqual(_ p1: PlusDriveProject, _ p2: PlusDriveProject) -> Bool {
        // Deep comparison of project data
        guard p1.name == p2.name,
              p1.bpm == p2.bpm,
              p1.patterns.count == p2.patterns.count,
              p1.presets.count == p2.presets.count else {
            return false
        }
        
        // Compare patterns
        let patterns1 = p1.patterns.sorted { $0.name < $1.name }
        let patterns2 = p2.patterns.sorted { $0.name < $1.name }
        
        for (pattern1, pattern2) in zip(patterns1, patterns2) {
            guard pattern1.name == pattern2.name,
                  pattern1.length == pattern2.length,
                  pattern1.tempo == pattern2.tempo,
                  pattern1.tracks.count == pattern2.tracks.count else {
                return false
            }
        }
        
        return true
    }
}

// MARK: - PlusDriveError Definition

enum PlusDriveError: Error, Equatable {
    case projectNotFound
    case invalidFileFormat
    case storageQuotaExceeded
    case versionNotFound
    case backupNotFound
    case exportFailed(String)
    case importFailed(String)
}