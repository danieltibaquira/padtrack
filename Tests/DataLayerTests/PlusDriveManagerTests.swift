import XCTest
import CoreData
@testable import DataLayer
@testable import DataModel

class PlusDriveManagerTests: CoreDataTestBase {
    var driveManager: PlusDriveManager!
    
    override func setUp() {
        super.setUp()
        driveManager = PlusDriveManager(context: testContext)
    }
    
    override func tearDown() {
        driveManager = nil
        super.tearDown()
    }
    
    // MARK: - Basic Project Management Tests
    
    func testPlusDriveProjectListing() throws {
        // Test +Drive shows all available projects
        
        // Create test projects
        let project1 = try driveManager.createProject(name: "Project 1")
        let project2 = try driveManager.createProject(name: "Project 2")
        let project3 = try driveManager.createProject(name: "Project 3")
        
        // Save context
        try testContext.save()
        
        // List projects
        let projectList = try driveManager.listProjects()
        
        XCTAssertEqual(projectList.count, 3)
        XCTAssertTrue(projectList.contains { $0.name == "Project 1" })
        XCTAssertTrue(projectList.contains { $0.name == "Project 2" })
        XCTAssertTrue(projectList.contains { $0.name == "Project 3" })
    }
    
    func testProjectExportImport() throws {
        // Test project can be exported and imported without data loss
        let originalProject = createComplexTestProject()
        
        // Export project
        let exportData = try driveManager.exportProject(originalProject)
        XCTAssertGreaterThan(exportData.count, 0)
        
        // Clear context to simulate fresh import
        testContext.reset()
        
        // Import project
        let importedProject = try driveManager.importProject(from: exportData)
        
        // Verify data integrity
        XCTAssertEqual(importedProject.name, originalProject.name)
        XCTAssertEqual(importedProject.patterns?.count ?? 0, originalProject.patterns?.count ?? 0)
        XCTAssertEqual(importedProject.bpm, originalProject.bpm)
        
        // Deep comparison of all nested data
        XCTAssertTrue(projectsAreEqual(originalProject, importedProject))
    }
    
    func testProjectVersioning() throws {
        // Test project versioning prevents data loss during updates
        let project = createTestProject()
        
        // Save initial version
        let version1 = try driveManager.saveProjectVersion(project)
        
        // Modify project
        let pattern = NSEntityDescription.insertNewObject(forEntityName: "Pattern", into: testContext) as! Pattern
        pattern.name = "New Pattern"
        pattern.project = project
        try testContext.save()
        
        // Save new version
        let version2 = try driveManager.saveProjectVersion(project)
        
        // Verify versions are tracked
        let versions = try driveManager.getProjectVersions(projectId: project.objectID)
        XCTAssertEqual(versions.count, 2)
        
        // Verify can restore previous version
        let restoredProject = try driveManager.restoreProjectVersion(version1)
        XCTAssertEqual(restoredProject.patterns?.count ?? 0, (project.patterns?.count ?? 0) - 1)
    }
    
    // MARK: - Storage Management Tests
    
    func testStorageQuotaManagement() throws {
        // Test storage quota enforcement
        driveManager.setStorageQuota(megabytes: 100)
        
        // Create projects until quota exceeded
        var projects: [Project] = []
        for i in 0..<50 {
            do {
                let project = try driveManager.createProject(name: "Project \(i)")
                // Add some data to increase size
                for j in 0..<10 {
                    let pattern = NSEntityDescription.insertNewObject(forEntityName: "Pattern", into: testContext) as! Pattern
                    pattern.name = "Pattern \(j)"
                    pattern.project = project
                }
                try testContext.save()
                projects.append(project)
            } catch PlusDriveError.storageQuotaExceeded {
                // Expected when quota is exceeded
                break
            }
        }
        
        // Verify storage tracking
        let usedStorage = try driveManager.getUsedStorage()
        XCTAssertLessThanOrEqual(usedStorage, 100 * 1024 * 1024) // 100MB in bytes
    }
    
    // MARK: - Backup and Recovery Tests
    
    func testAutomaticBackup() throws {
        // Test automatic backup on save
        let project = createTestProject()
        
        // Enable automatic backup
        driveManager.enableAutomaticBackup(true)
        
        // Save project
        try driveManager.saveProject(project)
        
        // Verify backup was created
        let backups = try driveManager.listBackups(for: project.objectID)
        XCTAssertGreaterThan(backups.count, 0)
        
        // Corrupt project data
        project.name = nil
        project.bpm = -1
        
        // Restore from backup
        let restoredProject = try driveManager.restoreFromLatestBackup(projectId: project.objectID)
        XCTAssertNotNil(restoredProject.name)
        XCTAssertGreaterThan(restoredProject.bpm, 0)
    }
    
    func testBackupRetention() throws {
        // Test backup retention policy
        let project = createTestProject()
        
        // Set retention policy
        driveManager.setBackupRetentionDays(7)
        driveManager.setMaxBackupsPerProject(5)
        
        // Create multiple backups
        for i in 0..<10 {
            project.name = "Version \(i)"
            try driveManager.saveProjectVersion(project)
        }
        
        // Verify retention limits
        let backups = try driveManager.listBackups(for: project.objectID)
        XCTAssertLessThanOrEqual(backups.count, 5)
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentProjectAccess() throws {
        // Test thread-safe concurrent access
        let expectation = XCTestExpectation(description: "Concurrent access")
        let project = createTestProject()
        
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        var errors: [Error] = []
        let errorLock = NSLock()
        
        // Simulate concurrent reads and writes
        for i in 0..<20 {
            group.enter()
            queue.async {
                defer { group.leave() }
                
                do {
                    if i % 2 == 0 {
                        // Read operation
                        _ = try self.driveManager.loadProject(id: project.objectID)
                    } else {
                        // Write operation
                        let pattern = NSEntityDescription.insertNewObject(forEntityName: "Pattern", into: self.testContext) as! Pattern
                        pattern.name = "Concurrent Pattern \(i)"
                        pattern.project = project
                        try self.driveManager.saveProject(project)
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
    
    // MARK: - Error Handling Tests
    
    func testCorruptedProjectRecovery() throws {
        // Test recovery from corrupted project data
        let project = createTestProject()
        let projectId = project.objectID
        
        // Save valid project
        try driveManager.saveProject(project)
        
        // Simulate corruption by directly manipulating data
        let corruptData = Data([0xFF, 0xFF, 0xFF, 0xFF]) // Invalid data
        
        // Attempt to import corrupt data
        do {
            _ = try driveManager.importProject(from: corruptData)
            XCTFail("Should have thrown corruption error")
        } catch PlusDriveError.corruptedProjectData {
            // Expected error
            
            // Verify can still load original project
            let validProject = try driveManager.loadProject(id: projectId)
            XCTAssertNotNil(validProject)
        }
    }
    
    // MARK: - Performance Tests
    
    func testLargeProjectPerformance() throws {
        // Test performance with large projects
        measure {
            let project = createLargeTestProject()
            
            do {
                // Export performance
                let exportData = try driveManager.exportProject(project)
                
                // Import performance
                _ = try driveManager.importProject(from: exportData)
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
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
        
        // Add patterns
        for i in 0..<4 {
            let pattern = NSEntityDescription.insertNewObject(forEntityName: "Pattern", into: testContext) as! Pattern
            pattern.name = "Pattern \(i + 1)"
            pattern.project = project
            
            // Add kit
            let kit = NSEntityDescription.insertNewObject(forEntityName: "Kit", into: testContext) as! Kit
            kit.name = "Kit \(i + 1)"
            kit.pattern = pattern
            
            // Add tracks
            for j in 0..<8 {
                let track = NSEntityDescription.insertNewObject(forEntityName: "Track", into: testContext) as! Track
                track.number = Int16(j + 1)
                track.pattern = pattern
                
                // Add preset
                let preset = NSEntityDescription.insertNewObject(forEntityName: "Preset", into: testContext) as! Preset
                preset.name = "Preset \(j + 1)"
                preset.machine = "fmTone"
                preset.track = track
                preset.kit = kit
                
                // Add trigs
                for k in stride(from: 0, to: 64, by: 4) {
                    let trig = NSEntityDescription.insertNewObject(forEntityName: "Trig", into: testContext) as! Trig
                    trig.step = Int16(k)
                    trig.velocity = 100
                    trig.track = track
                }
            }
        }
        
        return project
    }
    
    private func createLargeTestProject() -> Project {
        let project = createTestProject()
        
        // Create a project with realistic complexity
        // 16 patterns, 64 tracks total, 1000+ trigs
        for i in 0..<16 {
            let pattern = NSEntityDescription.insertNewObject(forEntityName: "Pattern", into: testContext) as! Pattern
            pattern.name = "Pattern \(i + 1)"
            pattern.project = project
            
            let kit = NSEntityDescription.insertNewObject(forEntityName: "Kit", into: testContext) as! Kit
            kit.name = "Kit \(i + 1)"
            kit.pattern = pattern
            
            for j in 0..<4 {
                let track = NSEntityDescription.insertNewObject(forEntityName: "Track", into: testContext) as! Track
                track.number = Int16(j + 1)
                track.pattern = pattern
                
                let preset = NSEntityDescription.insertNewObject(forEntityName: "Preset", into: testContext) as! Preset
                preset.name = "Preset \(i)-\(j)"
                preset.machine = "fmTone"
                preset.track = track
                preset.kit = kit
                
                // Add many trigs
                for k in 0..<64 {
                    let trig = NSEntityDescription.insertNewObject(forEntityName: "Trig", into: testContext) as! Trig
                    trig.step = Int16(k)
                    trig.velocity = 100
                    trig.track = track
                    
                    // Add parameter locks
                    if k % 4 == 0 {
                        trig.parameterLocks = ["algorithm": 3.0, "feedback": 0.5]
                    }
                }
            }
        }
        
        return project
    }
    
    private func projectsAreEqual(_ p1: Project, _ p2: Project) -> Bool {
        // Deep comparison of project data
        guard p1.name == p2.name,
              p1.bpm == p2.bpm,
              p1.patterns?.count == p2.patterns?.count else {
            return false
        }
        
        // Compare patterns
        let patterns1 = (p1.patterns?.allObjects as? [Pattern] ?? []).sorted { $0.name ?? "" < $1.name ?? "" }
        let patterns2 = (p2.patterns?.allObjects as? [Pattern] ?? []).sorted { $0.name ?? "" < $1.name ?? "" }
        
        for (pattern1, pattern2) in zip(patterns1, patterns2) {
            guard pattern1.name == pattern2.name,
                  pattern1.tracks?.count == pattern2.tracks?.count else {
                return false
            }
        }
        
        return true
    }
}

// MARK: - PlusDriveError

enum PlusDriveError: LocalizedError {
    case storageQuotaExceeded
    case corruptedProjectData
    case backupNotFound
    case versionNotFound
    case projectNotFound
    
    var errorDescription: String? {
        switch self {
        case .storageQuotaExceeded:
            return "Storage quota exceeded"
        case .corruptedProjectData:
            return "Project data is corrupted"
        case .backupNotFound:
            return "Backup not found"
        case .versionNotFound:
            return "Version not found"
        case .projectNotFound:
            return "Project not found"
        }
    }
}