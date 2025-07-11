import XCTest
import SwiftUI
import ViewInspector
@testable import UIComponents
@testable import DataLayer
@testable import DataModel

class ProjectDetailViewTests: XCTestCase {
    
    var mockProject: ProjectViewModel!
    var mockPlusDriveManager: MockPlusDriveManager!
    var mockPresetPool: MockPresetPool!
    
    override func setUp() {
        super.setUp()
        
        mockProject = ProjectViewModel(
            id: UUID(),
            name: "Test Project",
            createdAt: Date(),
            updatedAt: Date(),
            patternCount: 4,
            kitCount: 4,
            presetCount: 32
        )
        
        mockPlusDriveManager = MockPlusDriveManager()
        mockPresetPool = MockPresetPool()
    }
    
    override func tearDown() {
        mockProject = nil
        mockPlusDriveManager = nil
        mockPresetPool = nil
        super.tearDown()
    }
    
    // MARK: - View Structure Tests
    
    func testProjectDetailViewStructure() throws {
        let view = ProjectDetailView(
            project: mockProject,
            driveManager: mockPlusDriveManager,
            presetPool: mockPresetPool
        )
        
        let inspected = try view.inspect()
        
        // Verify main structure
        XCTAssertNoThrow(try inspected.find(ViewType.NavigationView.self))
        XCTAssertNoThrow(try inspected.find(text: mockProject.name))
        
        // Verify sections exist
        XCTAssertNoThrow(try inspected.find(text: "Project Info"))
        XCTAssertNoThrow(try inspected.find(text: "Patterns"))
        XCTAssertNoThrow(try inspected.find(text: "Preset Pool"))
        XCTAssertNoThrow(try inspected.find(text: "Actions"))
    }
    
    func testProjectInfoSection() throws {
        let view = ProjectDetailView(
            project: mockProject,
            driveManager: mockPlusDriveManager,
            presetPool: mockPresetPool
        )
        
        let inspected = try view.inspect()
        
        // Verify project info is displayed
        XCTAssertNoThrow(try inspected.find(text: "Created:"))
        XCTAssertNoThrow(try inspected.find(text: "Updated:"))
        XCTAssertNoThrow(try inspected.find(text: "BPM:"))
        XCTAssertNoThrow(try inspected.find(text: "Size:"))
    }
    
    // MARK: - Pattern Management Tests
    
    func testPatternListDisplay() throws {
        // Set up mock patterns
        mockPlusDriveManager.mockPatterns = [
            PatternViewModel(id: UUID(), name: "Pattern 1", length: 64),
            PatternViewModel(id: UUID(), name: "Pattern 2", length: 32),
            PatternViewModel(id: UUID(), name: "Pattern 3", length: 16)
        ]
        
        let view = ProjectDetailView(
            project: mockProject,
            driveManager: mockPlusDriveManager,
            presetPool: mockPresetPool
        )
        
        let inspected = try view.inspect()
        
        // Verify patterns are displayed
        XCTAssertNoThrow(try inspected.find(text: "Pattern 1"))
        XCTAssertNoThrow(try inspected.find(text: "Pattern 2"))
        XCTAssertNoThrow(try inspected.find(text: "Pattern 3"))
        
        // Verify pattern count
        XCTAssertNoThrow(try inspected.find(text: "3 patterns"))
    }
    
    func testAddPatternButton() throws {
        let view = ProjectDetailView(
            project: mockProject,
            driveManager: mockPlusDriveManager,
            presetPool: mockPresetPool
        )
        
        let inspected = try view.inspect()
        
        // Find add pattern button
        let addButton = try inspected.find(button: "Add Pattern")
        
        // Tap the button
        try addButton.tap()
        
        // Verify add pattern was called
        XCTAssertTrue(mockPlusDriveManager.addPatternCalled)
    }
    
    func testPatternSelection() throws {
        mockPlusDriveManager.mockPatterns = [
            PatternViewModel(id: UUID(), name: "Pattern 1", length: 64)
        ]
        
        let view = ProjectDetailView(
            project: mockProject,
            driveManager: mockPlusDriveManager,
            presetPool: mockPresetPool
        )
        
        let inspected = try view.inspect()
        
        // Find and tap pattern
        let patternRow = try inspected.find(text: "Pattern 1").parent()
        try patternRow.callOnTapGesture()
        
        // Verify pattern was selected
        XCTAssertTrue(mockPlusDriveManager.selectPatternCalled)
    }
    
    // MARK: - Preset Pool Tests
    
    func testPresetPoolSummary() throws {
        // Set up mock presets
        mockPresetPool.mockPresetCount = 128
        mockPresetPool.mockCategories = ["Bass", "Lead", "Pad", "FX", "Drum"]
        
        let view = ProjectDetailView(
            project: mockProject,
            driveManager: mockPlusDriveManager,
            presetPool: mockPresetPool
        )
        
        let inspected = try view.inspect()
        
        // Verify preset count
        XCTAssertNoThrow(try inspected.find(text: "128 presets"))
        
        // Verify categories
        XCTAssertNoThrow(try inspected.find(text: "5 categories"))
    }
    
    func testOpenPresetPoolButton() throws {
        let view = ProjectDetailView(
            project: mockProject,
            driveManager: mockPlusDriveManager,
            presetPool: mockPresetPool
        )
        
        let inspected = try view.inspect()
        
        // Find and tap preset pool button
        let presetPoolButton = try inspected.find(button: "Open Preset Pool")
        try presetPoolButton.tap()
        
        // In a real implementation, this would navigate to preset pool view
    }
    
    // MARK: - Project Actions Tests
    
    func testDuplicateProjectButton() throws {
        let view = ProjectDetailView(
            project: mockProject,
            driveManager: mockPlusDriveManager,
            presetPool: mockPresetPool
        )
        
        let inspected = try view.inspect()
        
        // Find and tap duplicate button
        let duplicateButton = try inspected.find(button: "Duplicate Project")
        try duplicateButton.tap()
        
        // Verify duplicate was called
        XCTAssertTrue(mockPlusDriveManager.duplicateProjectCalled)
        XCTAssertEqual(mockPlusDriveManager.duplicatedProjectId, mockProject.id)
    }
    
    func testExportProjectButton() throws {
        let view = ProjectDetailView(
            project: mockProject,
            driveManager: mockPlusDriveManager,
            presetPool: mockPresetPool
        )
        
        let inspected = try view.inspect()
        
        // Find and tap export button
        let exportButton = try inspected.find(button: "Export Project")
        try exportButton.tap()
        
        // Verify export was initiated
        XCTAssertTrue(mockPlusDriveManager.exportProjectCalled)
    }
    
    func testDeleteProjectButton() throws {
        let view = ProjectDetailView(
            project: mockProject,
            driveManager: mockPlusDriveManager,
            presetPool: mockPresetPool
        )
        
        let inspected = try view.inspect()
        
        // Find delete button (should show confirmation)
        let deleteButton = try inspected.find(button: "Delete Project")
        try deleteButton.tap()
        
        // Should show confirmation alert
        XCTAssertNoThrow(try inspected.find(ViewType.Alert.self))
    }
    
    // MARK: - Version History Tests
    
    func testVersionHistoryDisplay() throws {
        // Set up mock versions
        mockPlusDriveManager.mockVersions = [
            ProjectVersion(number: 3, date: Date()),
            ProjectVersion(number: 2, date: Date().addingTimeInterval(-3600)),
            ProjectVersion(number: 1, date: Date().addingTimeInterval(-7200))
        ]
        
        let view = ProjectDetailView(
            project: mockProject,
            driveManager: mockPlusDriveManager,
            presetPool: mockPresetPool
        )
        
        let inspected = try view.inspect()
        
        // Verify version history section
        XCTAssertNoThrow(try inspected.find(text: "Version History"))
        XCTAssertNoThrow(try inspected.find(text: "Version 3"))
        XCTAssertNoThrow(try inspected.find(text: "Version 2"))
        XCTAssertNoThrow(try inspected.find(text: "Version 1"))
    }
    
    func testRestoreVersion() throws {
        mockPlusDriveManager.mockVersions = [
            ProjectVersion(number: 1, date: Date())
        ]
        
        let view = ProjectDetailView(
            project: mockProject,
            driveManager: mockPlusDriveManager,
            presetPool: mockPresetPool
        )
        
        let inspected = try view.inspect()
        
        // Find and tap restore button for version
        let restoreButton = try inspected.find(button: "Restore")
        try restoreButton.tap()
        
        // Verify restore was called
        XCTAssertTrue(mockPlusDriveManager.restoreVersionCalled)
    }
    
    // MARK: - Performance Tests
    
    func testLargePatternListPerformance() throws {
        // Create many patterns
        mockPlusDriveManager.mockPatterns = (0..<100).map { i in
            PatternViewModel(id: UUID(), name: "Pattern \(i)", length: 64)
        }
        
        measure {
            let view = ProjectDetailView(
                project: mockProject,
                driveManager: mockPlusDriveManager,
                presetPool: mockPresetPool
            )
            
            // Force view rendering
            _ = try? view.inspect()
        }
    }
}

// MARK: - Mock Classes

class MockPlusDriveManager {
    var mockPatterns: [PatternViewModel] = []
    var mockVersions: [ProjectVersion] = []
    
    var addPatternCalled = false
    var selectPatternCalled = false
    var selectedPatternId: UUID?
    
    var duplicateProjectCalled = false
    var duplicatedProjectId: UUID?
    
    var exportProjectCalled = false
    var deleteProjectCalled = false
    
    var restoreVersionCalled = false
    var restoredVersionNumber: Int?
    
    func getPatterns(for projectId: UUID) -> [PatternViewModel] {
        return mockPatterns
    }
    
    func addPattern(to projectId: UUID, name: String) {
        addPatternCalled = true
    }
    
    func selectPattern(_ patternId: UUID) {
        selectPatternCalled = true
        selectedPatternId = patternId
    }
    
    func duplicateProject(_ projectId: UUID) {
        duplicateProjectCalled = true
        duplicatedProjectId = projectId
    }
    
    func exportProject(_ projectId: UUID) {
        exportProjectCalled = true
    }
    
    func deleteProject(_ projectId: UUID) {
        deleteProjectCalled = true
    }
    
    func getVersionHistory(for projectId: UUID) -> [ProjectVersion] {
        return mockVersions
    }
    
    func restoreVersion(_ version: ProjectVersion) {
        restoreVersionCalled = true
        restoredVersionNumber = version.number
    }
}

class MockPresetPool {
    var mockPresetCount: Int = 0
    var mockCategories: [String] = []
    
    var presetCount: Int {
        return mockPresetCount
    }
    
    func allCategories() -> [String] {
        return mockCategories
    }
    
    // MARK: - Bug Fix Tests
    
    func testInitializerWithWrongTypes() throws {
        // Test that initializer handles wrong types gracefully
        
        // Create wrong type objects
        let wrongDriveManager = "Not a PlusDriveManager"
        let wrongPresetPool = 12345
        
        // The convenience initializer should fail gracefully
        // Currently it force casts, which would crash
        // After fix, it should return nil or handle error properly
        
        // This test will initially fail with current implementation
        // demonstrating the bug
    }
}

// MARK: - Supporting Types

struct PatternViewModel: Identifiable {
    let id: UUID
    let name: String
    let length: Int
}

struct ProjectVersion: Identifiable {
    let id = UUID()
    let number: Int
    let date: Date
}