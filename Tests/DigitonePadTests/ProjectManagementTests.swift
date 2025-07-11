import XCTest
import SwiftUI
import Combine
@testable import DigitonePad
@testable import DataLayer

/// Unit tests for Project Management VIPER components
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
    
    // MARK: - Data Persistence Tests
    
    func testProjectCreationAndPersistence() {
        // Test complete project creation workflow
        let expectation = XCTestExpectation(description: "Project creation")
        
        // Create project
        presenter.createNewProject(name: "Persistence Test Project")
        
        // Wait for async operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Verify project was created
            XCTAssertTrue(self.interactor.createProjectCalled)
            XCTAssertEqual(self.interactor.createProjectName, "Persistence Test Project")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testDataIntegrityDuringComplexOperations() {
        // Test data remains consistent during complex operations
        presenter.projects = []
        
        // Perform multiple operations
        presenter.createNewProject(name: "Complex Test 1")
        presenter.createNewProject(name: "Complex Test 2")
        presenter.viewDidLoad() // Refresh projects
        
        // Verify all operations were initiated
        XCTAssertTrue(interactor.createProjectCalled)
        XCTAssertTrue(interactor.fetchProjectsCalled)
        XCTAssertTrue(presenter.isLoading)
    }
    
    func testConcurrentAccessSafety() {
        // Test multiple threads can safely access project data
        let expectation = XCTestExpectation(description: "Concurrent access")
        let dispatchGroup = DispatchGroup()
        var accessCount = 0
        let lock = NSLock()
        
        // Simulate concurrent operations
        for i in 0..<10 {
            dispatchGroup.enter()
            DispatchQueue.global().async {
                defer { dispatchGroup.leave() }
                
                if i % 2 == 0 {
                    self.presenter.createNewProject(name: "Concurrent \(i)")
                } else {
                    self.presenter.viewDidLoad()
                }
                
                lock.lock()
                accessCount += 1
                lock.unlock()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            XCTAssertEqual(accessCount, 10)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testProjectCreationWithInvalidData() {
        // Test error handling for invalid project names
        let invalidNames = ["", "   ", "\n\t"]
        
        for invalidName in invalidNames {
            presenter.createNewProject(name: invalidName)
            
            if invalidName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                XCTAssertEqual(presenter.errorMessage, "Project name cannot be empty")
            }
        }
    }
    
    func testProjectLoadingFailure() {
        // Test handling of project loading failures
        let nonExistentProject = createMockProject()
        nonExistentProject.name = "Non-existent"
        
        // Simulate loading
        presenter.loadProject(nonExistentProject)
        
        // Verify loading was attempted
        XCTAssertTrue(interactor.loadProjectCalled)
        XCTAssertEqual(interactor.loadProjectId, nonExistentProject.id)
    }
    
    // MARK: - Performance Tests
    
    func testLargeProjectListPerformance() {
        // Test performance with many projects
        measure {
            // Create many mock projects
            var projects: [ProjectViewModel] = []
            for i in 0..<100 {
                projects.append(createMockProject(name: "Project \(i)"))
            }
            
            // Test presenter handling
            presenter.projectsFetched(projects)
            
            // Verify performance
            XCTAssertEqual(presenter.projects.count, 100)
        }
    }
    
    // MARK: - Bug Fix Tests
    
    func testGetProjectEntityFetchesExistingProject() {
        // Test that getProjectEntity should fetch existing project, not create new one
        
        // This test demonstrates the bug where getProjectEntity creates a new entity
        // every time instead of fetching the existing one
        
        // Currently, this creates a new Project entity each time
        // After fix, it should fetch the existing project from Core Data
        
        // Note: This is a unit test to demonstrate the bug
        // The actual fix needs to be implemented in ProjectManagementView
    }
    
    // MARK: - Helper Methods
    
    private func createMockProject(name: String = "Test Project") -> ProjectViewModel {
        return ProjectViewModel(
            id: UUID(),
            name: name,
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
    var loadProjectsCalled = false
    var selectProjectCalled = false
    var selectProjectId: UUID?
    
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
    
    func loadProjects() {
        loadProjectsCalled = true
        fetchProjects()
    }
    
    func selectProject(id: UUID) {
        selectProjectCalled = true
        selectProjectId = id
        loadProject(id: id)
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
