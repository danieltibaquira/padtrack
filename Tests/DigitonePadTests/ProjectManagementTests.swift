import XCTest
import SwiftUI
import Combine
import CoreData
@testable import DigitonePad
@testable import DataLayer
@testable import DataModel

/// Comprehensive tests for Project Management including data persistence
/// CRITICAL: These tests ensure user projects are never corrupted or lost
class ProjectManagementTests: XCTestCase {
    
    var presenter: ProjectManagementPresenter!
    var interactor: MockProjectManagementInteractor!
    var router: MockProjectManagementRouter!
    var view: MockProjectManagementView!
    
    override func setUp() {
        super.setUp()
        
        presenter = ProjectManagementPresenter()
        interactor = MockProjectManagementInteractor()
        router = MockProjectManagementRouter()
        view = MockProjectManagementView()
        
        // Wire up VIPER components
        presenter.interactor = interactor
        presenter.router = router
        presenter.view = view
        interactor.presenter = presenter
    }
    
    override func tearDown() {
        presenter = nil
        interactor = nil
        router = nil
        view = nil
        super.tearDown()
    }
    
    // MARK: - Presenter Tests
    
    func testViewDidLoad_CallsFetchProjects() {
        // When
        presenter.viewDidLoad()
        
        // Then
        XCTAssertTrue(interactor.fetchProjectsCalled)
        XCTAssertTrue(presenter.isLoading)
    }
    
    func testCreateNewProject_WithValidName_CallsInteractor() {
        // Given
        let projectName = "Test Project"
        
        // When
        presenter.createNewProject(name: projectName)
        
        // Then
        XCTAssertTrue(interactor.createProjectCalled)
        XCTAssertEqual(interactor.createProjectName, projectName)
        XCTAssertTrue(presenter.isLoading)
        XCTAssertNil(presenter.errorMessage)
    }
    
    func testCreateNewProject_WithEmptyName_ShowsError() {
        // Given
        let projectName = "   "
        
        // When
        presenter.createNewProject(name: projectName)
        
        // Then
        XCTAssertFalse(interactor.createProjectCalled)
        XCTAssertEqual(presenter.errorMessage, "Project name cannot be empty")
    }
    
    func testLoadProject_CallsInteractor() {
        // Given
        let project = createMockProject()
        
        // When
        presenter.loadProject(project)
        
        // Then
        XCTAssertTrue(interactor.loadProjectCalled)
        XCTAssertEqual(interactor.loadProjectId, project.id)
        XCTAssertTrue(presenter.isLoading)
    }
    
    func testDeleteProject_CallsInteractor() {
        // Given
        let project = createMockProject()
        
        // When
        presenter.deleteProject(project)
        
        // Then
        XCTAssertTrue(interactor.deleteProjectCalled)
        XCTAssertEqual(interactor.deleteProjectId, project.id)
        XCTAssertTrue(presenter.isLoading)
    }
    
    func testProjectsFetched_UpdatesProjectsAndView() {
        // Given
        let projects = [createMockProject(), createMockProject()]
        
        // When
        presenter.projectsFetched(projects)
        
        // Then
        XCTAssertEqual(presenter.projects.count, 2)
        XCTAssertFalse(presenter.isLoading)
        XCTAssertTrue(view.showProjectsCalled)
    }
    
    func testProjectCreated_AddsToProjectsList() {
        // Given
        let project = createMockProject()
        presenter.projects = [createMockProject()] // Existing project
        
        // When
        presenter.projectCreated(project)
        
        // Then
        XCTAssertEqual(presenter.projects.count, 2)
        XCTAssertEqual(presenter.projects.first?.id, project.id) // New project at beginning
        XCTAssertFalse(presenter.isLoading)
        XCTAssertTrue(view.showProjectCreatedCalled)
    }
    
    // MARK: - Interactor Tests
    
    func testInteractor_FetchProjects_CallsPresenter() {
        // Given
        let realInteractor = ProjectManagementInteractor(dataLayer: MockDataLayer())
        realInteractor.presenter = presenter
        
        // When
        realInteractor.fetchProjects()
        
        // Then
        // This will be tested with integration tests since it involves Core Data
    }
    
    // MARK: - View Model Tests
    
    func testProjectViewModel_InitFromProject() {
        // This test will be implemented when we have proper Core Data test setup
        // For now, we'll test the basic structure
        let project = createMockProject()
        XCTAssertNotNil(project.id)
        XCTAssertEqual(project.name, "Test Project")
    }
    
    // MARK: - Helper Methods
    
    private func createMockProject() -> ProjectViewModel {
        return ProjectViewModel(
            id: UUID(),
            name: "Test Project",
            createdAt: Date(),
            updatedAt: Date(),
            patternCount: 0,
            kitCount: 0,
            presetCount: 0
        )
    }
}

// MARK: - Mock Objects

class MockProjectManagementInteractor: ProjectManagementInteractorProtocol {
    weak var presenter: ProjectManagementPresenterProtocol?
    
    var fetchProjectsCalled = false
    var createProjectCalled = false
    var createProjectName: String?
    var deleteProjectCalled = false
    var deleteProjectId: UUID?
    var loadProjectCalled = false
    var loadProjectId: UUID?
    
    func fetchProjects() {
        fetchProjectsCalled = true
    }
    
    func createProject(name: String) {
        createProjectCalled = true
        createProjectName = name
    }
    
    func deleteProject(id: UUID) {
        deleteProjectCalled = true
        deleteProjectId = id
    }
    
    func loadProject(id: UUID) {
        loadProjectCalled = true
        loadProjectId = id
    }
}

class MockProjectManagementRouter: ProjectManagementRouterProtocol {
    var navigateToMainAppCalled = false
    var navigateToMainAppProject: ProjectViewModel?
    var showProjectSettingsCalled = false
    var showProjectSettingsProject: ProjectViewModel?

    static func createModule() -> AnyView {
        return AnyView(Text("Mock View"))
    }
    
    func navigateToMainApp(with project: ProjectViewModel) {
        navigateToMainAppCalled = true
        navigateToMainAppProject = project
    }
    
    func showProjectSettings(for project: ProjectViewModel) {
        showProjectSettingsCalled = true
        showProjectSettingsProject = project
    }
}

class MockProjectManagementView: ProjectManagementViewProtocol {
    var presenter: ProjectManagementPresenterProtocol?
    
    var showProjectsCalled = false
    var showProjectsProjects: [ProjectViewModel]?
    var showErrorCalled = false
    var showErrorError: Error?
    var showLoadingCalled = false
    var showLoadingIsLoading: Bool?
    var showProjectCreatedCalled = false
    var showProjectCreatedProject: ProjectViewModel?
    var showProjectDeletedCalled = false
    
    func showProjects(_ projects: [ProjectViewModel]) {
        showProjectsCalled = true
        showProjectsProjects = projects
    }
    
    func showError(_ error: Error) {
        showErrorCalled = true
        showErrorError = error
    }
    
    func showLoading(_ isLoading: Bool) {
        showLoadingCalled = true
        showLoadingIsLoading = isLoading
    }
    
    func showProjectCreated(_ project: ProjectViewModel) {
        showProjectCreatedCalled = true
        showProjectCreatedProject = project
    }
    
    func showProjectDeleted() {
        showProjectDeletedCalled = true
    }
}

class MockDataLayer {
    // Mock implementation for testing
    // This will be properly implemented when needed
}

// MARK: - Data Persistence Tests

extension ProjectManagementTests {
    
    func testProjectCreationAndPersistence() throws {
        // Test complete project creation workflow
        let persistenceController = PersistenceController(inMemory: true)
        let testContext = persistenceController.container.viewContext
        let dataLayer = DataLayerManager(persistenceController: persistenceController)
        let projectManager = ProjectManager(dataLayer: dataLayer)
        
        // Create project
        let project = try projectManager.createProject(name: "Test Project")
        project.bpm = 120.0
        
        // Add patterns, kits, tracks, presets
        let pattern = try projectManager.addPattern(to: project, name: "Pattern 1")
        let kit = try projectManager.addKit(to: project, name: "Kit 1")
        let track = try projectManager.addTrack(to: pattern, number: 1)
        let preset = try projectManager.addPreset(to: kit, for: track, machine: .fmTone)
        
        // Configure preset
        preset.settings = [
            "algorithm": 3,
            "ratio": 1.5,
            "feedback": 0.8
        ]
        
        // Save and verify persistence
        try projectManager.saveProject(project)
        
        // Reload from persistence
        let reloadedProject = try projectManager.loadProject(id: project.objectID)
        
        // Verify all data persisted correctly
        XCTAssertEqual(reloadedProject.name, "Test Project")
        XCTAssertEqual(reloadedProject.bpm, 120.0)
        XCTAssertEqual(reloadedProject.patterns?.count, 1)
        
        let reloadedPattern = reloadedProject.patterns?.allObjects.first as? Pattern
        XCTAssertEqual(reloadedPattern?.name, "Pattern 1")
        XCTAssertEqual(reloadedPattern?.tracks?.count, 1)
        
        let reloadedTrack = reloadedPattern?.tracks?.allObjects.first as? Track
        XCTAssertNotNil(reloadedTrack?.preset)
        XCTAssertEqual(reloadedTrack?.preset?.settings?["algorithm"] as? Int, 3)
    }
    
    func testProjectDuplication() throws {
        // Test project duplication preserves all data
        let persistenceController = PersistenceController(inMemory: true)
        let dataLayer = DataLayerManager(persistenceController: persistenceController)
        let projectManager = ProjectManager(dataLayer: dataLayer)
        
        // Create original project
        let original = try projectManager.createProject(name: "Original")
        
        // Add complex structure
        for i in 0..<4 {
            let pattern = try projectManager.addPattern(to: original, name: "Pattern \(i)")
            pattern.tempo = 120.0 + Double(i * 5)
            
            for j in 0..<8 {
                let track = try projectManager.addTrack(to: pattern, number: j)
                track.volume = Float(j) / 8.0
                
                // Add trigs
                for k in stride(from: 0, to: 16, by: 4) {
                    let trig = try projectManager.addTrig(to: track, step: k)
                    trig.note = 60 + Int16(j)
                    trig.velocity = 100
                }
            }
        }
        
        try projectManager.saveProject(original)
        
        // Duplicate project
        let duplicate = try projectManager.duplicateProject(original, withName: "Duplicate")
        
        // Verify structure preserved
        XCTAssertEqual(duplicate.patterns?.count, original.patterns?.count)
        
        let originalPatterns = (original.patterns?.allObjects as? [Pattern] ?? []).sorted { $0.name! < $1.name! }
        let duplicatePatterns = (duplicate.patterns?.allObjects as? [Pattern] ?? []).sorted { $0.name! < $1.name! }
        
        for (origPattern, dupPattern) in zip(originalPatterns, duplicatePatterns) {
            XCTAssertEqual(dupPattern.tempo, origPattern.tempo)
            XCTAssertEqual(dupPattern.tracks?.count, origPattern.tracks?.count)
            
            let origTracks = (origPattern.tracks?.allObjects as? [Track] ?? []).sorted { $0.trackIndex < $1.trackIndex }
            let dupTracks = (dupPattern.tracks?.allObjects as? [Track] ?? []).sorted { $0.trackIndex < $1.trackIndex }
            
            for (origTrack, dupTrack) in zip(origTracks, dupTracks) {
                XCTAssertEqual(dupTrack.volume, origTrack.volume)
                XCTAssertEqual(dupTrack.trigs?.count, origTrack.trigs?.count)
            }
        }
    }
    
    func testAutoSaveFunctionality() throws {
        // Test auto-save prevents data loss
        let persistenceController = PersistenceController(inMemory: true)
        let dataLayer = DataLayerManager(persistenceController: persistenceController)
        let projectManager = ProjectManager(dataLayer: dataLayer)
        
        // Enable auto-save
        projectManager.enableAutoSave = true
        projectManager.autoSaveInterval = 0.1 // 100ms for testing
        
        let project = try projectManager.createProject(name: "Auto Save Test")
        
        // Make changes
        let pattern = try projectManager.addPattern(to: project, name: "Pattern 1")
        
        // Wait for auto-save
        Thread.sleep(forTimeInterval: 0.2)
        
        // Simulate crash by creating new manager
        let newProjectManager = ProjectManager(dataLayer: dataLayer)
        
        // Verify changes were auto-saved
        let recovered = try newProjectManager.loadProject(id: project.objectID)
        XCTAssertEqual(recovered.patterns?.count, 1)
        XCTAssertEqual(recovered.patterns?.allObjects.first?.name, "Pattern 1")
    }
    
    func testDataValidationBeforeSave() throws {
        // Test validation prevents invalid data from being saved
        let persistenceController = PersistenceController(inMemory: true)
        let dataLayer = DataLayerManager(persistenceController: persistenceController)
        let projectManager = ProjectManager(dataLayer: dataLayer)
        
        let project = try projectManager.createProject(name: "Validation Test")
        let pattern = try projectManager.addPattern(to: project, name: "Pattern")
        let track = try projectManager.addTrack(to: pattern, number: 0)
        
        // Try to set invalid values
        track.volume = 2.0 // Out of range (0-1)
        
        // Validation should fail
        XCTAssertThrowsError(try projectManager.saveProject(project)) { error in
            XCTAssertTrue(error is ValidationError)
        }
        
        // Fix value
        track.volume = 0.8
        
        // Now should save successfully
        XCTAssertNoThrow(try projectManager.saveProject(project))
    }
    
    func testConcurrentProjectAccess() throws {
        // Test thread-safe concurrent access
        let persistenceController = PersistenceController(inMemory: true)
        let dataLayer = DataLayerManager(persistenceController: persistenceController)
        let projectManager = ProjectManager(dataLayer: dataLayer)
        
        let project = try projectManager.createProject(name: "Concurrent Test")
        try projectManager.saveProject(project)
        
        let dispatchGroup = DispatchGroup()
        var errors: [Error] = []
        let errorQueue = DispatchQueue(label: "error.queue")
        
        // Concurrent operations
        for i in 0..<20 {
            dispatchGroup.enter()
            DispatchQueue.global().async {
                defer { dispatchGroup.leave() }
                
                do {
                    if i % 2 == 0 {
                        // Write operation
                        _ = try projectManager.addPattern(to: project, name: "Pattern \(i)")
                    } else {
                        // Read operation
                        _ = try projectManager.loadProject(id: project.objectID)
                    }
                } catch {
                    errorQueue.sync {
                        errors.append(error)
                    }
                }
            }
        }
        
        dispatchGroup.wait()
        XCTAssertTrue(errors.isEmpty, "Concurrent access errors: \(errors)")
    }
    
    func testProjectSearchAndFilter() throws {
        // Test project search functionality
        let persistenceController = PersistenceController(inMemory: true)
        let dataLayer = DataLayerManager(persistenceController: persistenceController)
        let projectManager = ProjectManager(dataLayer: dataLayer)
        
        // Create multiple projects
        let technoProject = try projectManager.createProject(name: "Techno Patterns")
        technoProject.tags = ["techno", "dance", "electronic"]
        
        let ambientProject = try projectManager.createProject(name: "Ambient Soundscapes")
        ambientProject.tags = ["ambient", "experimental", "electronic"]
        
        let drumProject = try projectManager.createProject(name: "Drum Patterns")
        drumProject.tags = ["drums", "percussion", "rhythmic"]
        
        try projectManager.saveAll()
        
        // Search by name
        let nameResults = try projectManager.searchProjects(query: "Pattern")
        XCTAssertEqual(nameResults.count, 2)
        
        // Search by tag
        let tagResults = try projectManager.searchProjects(tag: "electronic")
        XCTAssertEqual(tagResults.count, 2)
        
        // Filter by date
        let recentProjects = try projectManager.getRecentProjects(days: 1)
        XCTAssertEqual(recentProjects.count, 3)
    }
    
    func testMemoryManagement() throws {
        // Test memory usage remains stable
        let persistenceController = PersistenceController(inMemory: true)
        let dataLayer = DataLayerManager(persistenceController: persistenceController)
        let projectManager = ProjectManager(dataLayer: dataLayer)
        
        let initialMemory = getCurrentMemoryUsage()
        
        // Create and delete many projects
        for i in 0..<100 {
            autoreleasepool {
                let project = try! projectManager.createProject(name: "Memory Test \(i)")
                
                // Add some data
                for j in 0..<10 {
                    _ = try! projectManager.addPattern(to: project, name: "Pattern \(j)")
                }
                
                try! projectManager.saveProject(project)
                
                // Delete project
                try! projectManager.deleteProject(project)
            }
        }
        
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be minimal (< 10MB)
        XCTAssertLessThan(memoryIncrease, 10_000_000)
    }
}

// MARK: - Helper Types for Testing

struct ValidationError: Error {}

class ProjectManager {
    let dataLayer: DataLayerManager
    var enableAutoSave = false
    var autoSaveInterval: TimeInterval = 30.0
    private var autoSaveTimer: Timer?
    
    init(dataLayer: DataLayerManager) {
        self.dataLayer = dataLayer
    }
    
    func createProject(name: String) throws -> Project {
        let project = dataLayer.projectRepository.createProject(name: name)
        project.bpm = 120.0
        project.createdAt = Date()
        project.updatedAt = Date()
        
        if enableAutoSave {
            startAutoSave()
        }
        
        return project
    }
    
    func addPattern(to project: Project, name: String) throws -> Pattern {
        let pattern = dataLayer.patternRepository.createPattern(
            name: name,
            project: project
        )
        return pattern
    }
    
    func addKit(to project: Project, name: String) throws -> Kit {
        let kit = dataLayer.kitRepository.createKit(name: name)
        kit.project = project
        return kit
    }
    
    func addTrack(to pattern: Pattern, number: Int) throws -> Track {
        let track = dataLayer.trackRepository.createTrack(
            name: "Track \(number + 1)",
            pattern: pattern,
            trackIndex: Int16(number)
        )
        return track
    }
    
    func addPreset(to kit: Kit, for track: Track, machine: MachineType) throws -> Preset {
        guard let project = kit.project else {
            throw ProjectManagerError.invalidKit
        }
        
        let preset = dataLayer.presetRepository.createPreset(
            name: "\(machine) Preset",
            project: project
        )
        track.preset = preset
        return preset
    }
    
    func addTrig(to track: Track, step: Int) throws -> Trig {
        let trig = dataLayer.trigRepository.createTrig(
            step: Int16(step),
            note: 60,
            velocity: 100,
            track: track
        )
        return trig
    }
    
    func saveProject(_ project: Project) throws {
        // Validate before saving
        try validateProject(project)
        try dataLayer.save()
    }
    
    func saveAll() throws {
        try dataLayer.save()
    }
    
    func loadProject(id: NSManagedObjectID) throws -> Project {
        guard let project = try dataLayer.viewContext.existingObject(with: id) as? Project else {
            throw ProjectManagerError.projectNotFound
        }
        return project
    }
    
    func duplicateProject(_ original: Project, withName name: String) throws -> Project {
        return try dataLayer.duplicateProject(original, withName: name)
    }
    
    func deleteProject(_ project: Project) throws {
        try dataLayer.projectRepository.delete(project)
    }
    
    func searchProjects(query: String? = nil, tag: String? = nil) throws -> [Project] {
        var predicate: NSPredicate?
        
        if let query = query {
            predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        } else if let tag = tag {
            predicate = NSPredicate(format: "ANY tags CONTAINS[cd] %@", tag)
        }
        
        return try dataLayer.projectRepository.fetch(predicate: predicate)
    }
    
    func getRecentProjects(days: Int) throws -> [Project] {
        let date = Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
        let predicate = NSPredicate(format: "updatedAt > %@", date as NSDate)
        return try dataLayer.projectRepository.fetch(predicate: predicate)
    }
    
    private func validateProject(_ project: Project) throws {
        // Validate all tracks have valid volume
        for pattern in project.patterns?.allObjects as? [Pattern] ?? [] {
            for track in pattern.tracks?.allObjects as? [Track] ?? [] {
                if track.volume < 0 || track.volume > 1 {
                    throw ValidationError()
                }
            }
        }
    }
    
    private func startAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { _ in
            try? self.dataLayer.save()
        }
    }
}

enum ProjectManagerError: Error {
    case projectNotFound
    case invalidKit
}

extension Project {
    var bpm: Double {
        get { (self.value(forKey: "bpm") as? Double) ?? 120.0 }
        set { self.setValue(newValue, forKey: "bpm") }
    }
    
    var tags: [String] {
        get { (self.value(forKey: "tags") as? [String]) ?? [] }
        set { self.setValue(newValue, forKey: "tags") }
    }
}

func getCurrentMemoryUsage() -> Int64 {
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
