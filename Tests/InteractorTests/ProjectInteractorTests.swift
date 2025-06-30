import XCTest
@testable import DataLayer
@testable import MachineProtocols

// Import test utilities and mocks
import TestUtilities
import MockObjects

/// Tests for Project-related business logic (Interactor layer)
final class ProjectInteractorTests: DigitonePadTestCase {
    
    var projectInteractor: ProjectInteractor!
    var mockDataLayer: MockDataLayerManager!
    var mockPresenter: MockProjectPresenter!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        mockDataLayer = MockDataLayerManager()
        mockPresenter = MockProjectPresenter()
        projectInteractor = ProjectInteractor(
            dataLayer: mockDataLayer,
            presenter: mockPresenter
        )
        
        try mockDataLayer.initialize()
    }
    
    override func tearDownWithError() throws {
        projectInteractor = nil
        mockDataLayer = nil
        mockPresenter = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Project Creation Tests
    
    func testCreateProjectSuccess() throws {
        // GIVEN: Valid project parameters
        let projectName = "Test Project"
        let bpm: Float = 120.0
        
        // WHEN: Creating a project
        try projectInteractor.createProject(name: projectName, bpm: bpm)
        
        // THEN: Project should be created and presenter notified
        let projects = try mockDataLayer.fetchProjects()
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects.first?.name, projectName)
        XCTAssertEqual(projects.first?.bpm, bpm)
        
        XCTAssertTrue(mockPresenter.wasProjectCreatedCalled)
        XCTAssertEqual(mockPresenter.lastCreatedProject?.name, projectName)
    }
    
    func testCreateProjectWithInvalidName() throws {
        // GIVEN: Invalid project name (empty)
        let projectName = ""
        let bpm: Float = 120.0
        
        // WHEN & THEN: Creating project should fail
        XCTAssertThrowsError(try projectInteractor.createProject(name: projectName, bpm: bpm)) { error in
            XCTAssertTrue(error is ProjectInteractorError)
            if case ProjectInteractorError.invalidProjectName = error {
                // Expected error
            } else {
                XCTFail("Expected invalidProjectName error")
            }
        }
        
        XCTAssertTrue(mockPresenter.wasErrorPresentedCalled)
    }
    
    func testCreateProjectWithInvalidBPM() throws {
        // GIVEN: Invalid BPM (out of range)
        let projectName = "Test Project"
        let bpm: Float = 300.0 // Too high
        
        // WHEN & THEN: Creating project should fail
        XCTAssertThrowsError(try projectInteractor.createProject(name: projectName, bpm: bpm)) { error in
            XCTAssertTrue(error is ProjectInteractorError)
            if case ProjectInteractorError.invalidBPM = error {
                // Expected error
            } else {
                XCTFail("Expected invalidBPM error")
            }
        }
    }
    
    func testCreateProjectDataLayerFailure() throws {
        // GIVEN: Data layer configured to fail
        mockDataLayer.setShouldFailOperations(true)
        
        // WHEN & THEN: Creating project should handle data layer failure
        XCTAssertThrowsError(try projectInteractor.createProject(name: "Test", bpm: 120.0)) { error in
            XCTAssertTrue(error is DataLayerError)
        }
        
        XCTAssertTrue(mockPresenter.wasErrorPresentedCalled)
    }
    
    // MARK: - Project Loading Tests
    
    func testLoadProjectsSuccess() throws {
        // GIVEN: Projects exist in data layer
        _ = try mockDataLayer.createProject(name: "Project 1", bpm: 120.0)
        _ = try mockDataLayer.createProject(name: "Project 2", bpm: 140.0)
        
        // WHEN: Loading projects
        try projectInteractor.loadProjects()
        
        // THEN: Projects should be loaded and presented
        XCTAssertTrue(mockPresenter.wasProjectsLoadedCalled)
        XCTAssertEqual(mockPresenter.lastLoadedProjects?.count, 2)
    }
    
    func testLoadProjectsEmpty() throws {
        // GIVEN: No projects exist
        
        // WHEN: Loading projects
        try projectInteractor.loadProjects()
        
        // THEN: Empty list should be presented
        XCTAssertTrue(mockPresenter.wasProjectsLoadedCalled)
        XCTAssertEqual(mockPresenter.lastLoadedProjects?.count, 0)
    }
    
    func testLoadProjectsDataLayerFailure() throws {
        // GIVEN: Data layer configured to fail
        mockDataLayer.setShouldFailOperations(true)
        
        // WHEN & THEN: Loading projects should handle failure
        XCTAssertThrowsError(try projectInteractor.loadProjects())
        XCTAssertTrue(mockPresenter.wasErrorPresentedCalled)
    }
    
    // MARK: - Project Update Tests
    
    func testUpdateProjectSuccess() throws {
        // GIVEN: Existing project
        let project = try mockDataLayer.createProject(name: "Original", bpm: 120.0)
        
        // WHEN: Updating project
        var updatedProject = project
        updatedProject.name = "Updated"
        updatedProject.bpm = 140.0
        
        try projectInteractor.updateProject(updatedProject)
        
        // THEN: Project should be updated
        let projects = try mockDataLayer.fetchProjects()
        XCTAssertEqual(projects.first?.name, "Updated")
        XCTAssertEqual(projects.first?.bpm, 140.0)
        
        XCTAssertTrue(mockPresenter.wasProjectUpdatedCalled)
    }
    
    func testUpdateNonexistentProject() throws {
        // GIVEN: Project that doesn't exist
        let project = MockProject(
            id: UUID(),
            name: "Nonexistent",
            bpm: 120.0,
            createdAt: Date(),
            modifiedAt: Date()
        )
        
        // WHEN & THEN: Updating should handle gracefully
        try projectInteractor.updateProject(project)
        
        // Should not crash, but may not find project to update
        XCTAssertTrue(mockPresenter.wasProjectUpdatedCalled)
    }
    
    // MARK: - Project Deletion Tests
    
    func testDeleteProjectSuccess() throws {
        // GIVEN: Existing project
        let project = try mockDataLayer.createProject(name: "To Delete", bpm: 120.0)
        
        // WHEN: Deleting project
        try projectInteractor.deleteProject(project)
        
        // THEN: Project should be deleted
        let projects = try mockDataLayer.fetchProjects()
        XCTAssertEqual(projects.count, 0)
        
        XCTAssertTrue(mockPresenter.wasProjectDeletedCalled)
    }
    
    func testDeleteProjectWithPatterns() throws {
        // GIVEN: Project with patterns
        let project = try mockDataLayer.createProject(name: "With Patterns", bpm: 120.0)
        _ = try mockDataLayer.createPattern(name: "Pattern 1", projectId: project.id)
        _ = try mockDataLayer.createPattern(name: "Pattern 2", projectId: project.id)
        
        // WHEN: Deleting project
        try projectInteractor.deleteProject(project)
        
        // THEN: Project and patterns should be deleted
        let projects = try mockDataLayer.fetchProjects()
        XCTAssertEqual(projects.count, 0)
        
        let patterns = try mockDataLayer.fetchPatterns(for: project.id)
        XCTAssertEqual(patterns.count, 0)
    }
    
    // MARK: - Business Logic Validation Tests
    
    func testValidateProjectName() throws {
        // Test valid names
        XCTAssertNoThrow(try projectInteractor.validateProjectName("Valid Name"))
        XCTAssertNoThrow(try projectInteractor.validateProjectName("Project 123"))
        XCTAssertNoThrow(try projectInteractor.validateProjectName("My-Project_2024"))
        
        // Test invalid names
        XCTAssertThrowsError(try projectInteractor.validateProjectName(""))
        XCTAssertThrowsError(try projectInteractor.validateProjectName("   "))
        XCTAssertThrowsError(try projectInteractor.validateProjectName(String(repeating: "a", count: 256)))
    }
    
    func testValidateBPM() throws {
        // Test valid BPM values
        XCTAssertNoThrow(try projectInteractor.validateBPM(60.0))
        XCTAssertNoThrow(try projectInteractor.validateBPM(120.0))
        XCTAssertNoThrow(try projectInteractor.validateBPM(200.0))
        
        // Test invalid BPM values
        XCTAssertThrowsError(try projectInteractor.validateBPM(30.0)) // Too low
        XCTAssertThrowsError(try projectInteractor.validateBPM(300.0)) // Too high
        XCTAssertThrowsError(try projectInteractor.validateBPM(0.0))
        XCTAssertThrowsError(try projectInteractor.validateBPM(-10.0))
    }
    
    // MARK: - Performance Tests
    
    func testCreateMultipleProjectsPerformance() throws {
        measure {
            for i in 0..<100 {
                do {
                    try projectInteractor.createProject(name: "Project \(i)", bpm: Float(120 + i))
                } catch {
                    XCTFail("Failed to create project: \(error)")
                }
            }
        }
    }
    
    func testLoadLargeProjectListPerformance() throws {
        // GIVEN: Many projects
        for i in 0..<1000 {
            _ = try mockDataLayer.createProject(name: "Project \(i)", bpm: 120.0)
        }
        
        // WHEN & THEN: Loading should be performant
        measure {
            do {
                try projectInteractor.loadProjects()
            } catch {
                XCTFail("Failed to load projects: \(error)")
            }
        }
    }
}

// MARK: - Mock Project Presenter

class MockProjectPresenter {
    var wasProjectCreatedCalled = false
    var wasProjectsLoadedCalled = false
    var wasProjectUpdatedCalled = false
    var wasProjectDeletedCalled = false
    var wasErrorPresentedCalled = false
    
    var lastCreatedProject: MockProject?
    var lastLoadedProjects: [MockProject]?
    var lastUpdatedProject: MockProject?
    var lastDeletedProject: MockProject?
    var lastError: Error?
    
    func presentProjectCreated(_ project: MockProject) {
        wasProjectCreatedCalled = true
        lastCreatedProject = project
    }
    
    func presentProjectsLoaded(_ projects: [MockProject]) {
        wasProjectsLoadedCalled = true
        lastLoadedProjects = projects
    }
    
    func presentProjectUpdated(_ project: MockProject) {
        wasProjectUpdatedCalled = true
        lastUpdatedProject = project
    }
    
    func presentProjectDeleted(_ project: MockProject) {
        wasProjectDeletedCalled = true
        lastDeletedProject = project
    }
    
    func presentError(_ error: Error) {
        wasErrorPresentedCalled = true
        lastError = error
    }
}

// MARK: - Project Interactor Implementation

class ProjectInteractor {
    private let dataLayer: MockDataLayerManager
    private let presenter: MockProjectPresenter
    
    init(dataLayer: MockDataLayerManager, presenter: MockProjectPresenter) {
        self.dataLayer = dataLayer
        self.presenter = presenter
    }
    
    func createProject(name: String, bpm: Float) throws {
        do {
            try validateProjectName(name)
            try validateBPM(bpm)
            
            let project = try dataLayer.createProject(name: name, bpm: bpm)
            presenter.presentProjectCreated(project)
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func loadProjects() throws {
        do {
            let projects = try dataLayer.fetchProjects()
            presenter.presentProjectsLoaded(projects)
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func updateProject(_ project: MockProject) throws {
        do {
            try validateProjectName(project.name)
            try validateBPM(project.bpm)
            
            try dataLayer.updateProject(project)
            presenter.presentProjectUpdated(project)
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func deleteProject(_ project: MockProject) throws {
        do {
            // Delete associated patterns first
            let patterns = try dataLayer.fetchPatterns(for: project.id)
            for pattern in patterns {
                // In real implementation, would delete pattern
            }
            
            try dataLayer.deleteProject(project)
            presenter.presentProjectDeleted(project)
        } catch {
            presenter.presentError(error)
            throw error
        }
    }
    
    func validateProjectName(_ name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            throw ProjectInteractorError.invalidProjectName("Project name cannot be empty")
        }
        
        if trimmedName.count > 255 {
            throw ProjectInteractorError.invalidProjectName("Project name too long")
        }
    }
    
    func validateBPM(_ bpm: Float) throws {
        if bpm < 40.0 || bpm > 250.0 {
            throw ProjectInteractorError.invalidBPM("BPM must be between 40 and 250")
        }
    }
}

// MARK: - Project Interactor Errors

enum ProjectInteractorError: Error, LocalizedError {
    case invalidProjectName(String)
    case invalidBPM(String)
    case projectNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidProjectName(let message):
            return "Invalid project name: \(message)"
        case .invalidBPM(let message):
            return "Invalid BPM: \(message)"
        case .projectNotFound(let message):
            return "Project not found: \(message)"
        }
    }
}
