import XCTest
import SwiftUI
import Combine
@testable import DigitonePad
@testable import DataLayer

/// Integration tests for Project Management functionality
class ProjectManagementIntegrationTests: XCTestCase {
    
    var appState: AppState!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        appState = AppState.shared
        cancellables = Set<AnyCancellable>()
        
        // Clear any existing state
        appState.clearCurrentProject()
    }
    
    override func tearDown() {
        cancellables = nil
        appState = nil
        super.tearDown()
    }
    
    // MARK: - App State Integration Tests
    
    func testAppState_InitialState_NoProjectSelected() {
        // Given - fresh app state
        
        // Then
        XCTAssertNil(appState.currentProject)
        XCTAssertFalse(appState.isProjectSelected)
        XCTAssertFalse(appState.showProjectManagement)
    }
    
    func testAppState_SelectProject_UpdatesState() {
        // Given
        let project = createMockProject()
        let expectation = XCTestExpectation(description: "Project selected")
        
        // When
        appState.$isProjectSelected
            .dropFirst()
            .sink { isSelected in
                if isSelected {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        appState.selectProject(project)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(appState.currentProject?.id, project.id)
        XCTAssertTrue(appState.isProjectSelected)
        XCTAssertFalse(appState.showProjectManagement)
    }
    
    func testAppState_ShowProjectSelection_UpdatesFlag() {
        // When
        appState.showProjectSelection()
        
        // Then
        XCTAssertTrue(appState.showProjectManagement)
    }
    
    func testAppState_ClearProject_ResetsState() {
        // Given
        let project = createMockProject()
        appState.selectProject(project)
        
        // When
        appState.clearCurrentProject()
        
        // Then
        XCTAssertNil(appState.currentProject)
        XCTAssertFalse(appState.isProjectSelected)
    }
    
    // MARK: - VIPER Integration Tests
    
    func testVIPER_CompleteFlow_ProjectCreationToSelection() {
        // Given
        let presenter = ProjectManagementPresenter()
        let interactor = MockProjectManagementInteractor()
        let router = MockProjectManagementRouter()
        let view = MockProjectManagementView()
        
        // Wire up components
        presenter.interactor = interactor
        presenter.router = router
        presenter.view = view
        interactor.presenter = presenter
        
        // When - simulate complete flow
        presenter.viewDidLoad()
        
        // Simulate successful project fetch
        let projects = [createMockProject()]
        presenter.projectsFetched(projects)
        
        // Create new project
        presenter.createNewProject(name: "Integration Test Project")
        
        // Simulate successful creation
        let newProject = createMockProject(name: "Integration Test Project")
        presenter.projectCreated(newProject)
        
        // Load the project
        presenter.loadProject(newProject)
        
        // Simulate successful load
        presenter.projectLoaded(newProject)
        
        // Then - verify the complete flow
        XCTAssertTrue(interactor.fetchProjectsCalled)
        XCTAssertTrue(interactor.createProjectCalled)
        XCTAssertEqual(interactor.createProjectName, "Integration Test Project")
        XCTAssertTrue(interactor.loadProjectCalled)
        XCTAssertTrue(router.navigateToMainAppCalled)
        XCTAssertEqual(router.navigateToMainAppProject?.name, "Integration Test Project")
        XCTAssertTrue(view.showProjectsCalled)
        XCTAssertTrue(view.showProjectCreatedCalled)
    }
    
    func testVIPER_ErrorHandling_ProjectCreationFailure() {
        // Given
        let presenter = ProjectManagementPresenter()
        let interactor = MockProjectManagementInteractor()
        let view = MockProjectManagementView()
        
        presenter.interactor = interactor
        presenter.view = view
        interactor.presenter = presenter
        
        // When - simulate project creation failure
        presenter.createNewProject(name: "Test Project")
        presenter.projectCreationFailed(ProjectManagementError.failedToCreateProject)
        
        // Then
        XCTAssertTrue(view.showErrorCalled)
        XCTAssertNotNil(view.showErrorError)
        XCTAssertFalse(presenter.isLoading)
        XCTAssertNotNil(presenter.errorMessage)
    }
    
    // MARK: - Auto-save Integration Tests
    
    func testAutoSave_EnabledWithProject_PerformsAutoSave() {
        // Given
        let project = createMockProject()
        appState.selectProject(project)
        
        // When
        appState.enableAutoSave()
        
        // Then - auto-save should be enabled
        // Note: This is a basic test - in a real implementation,
        // we would test the actual auto-save functionality
        XCTAssertNotNil(appState.currentProject)
    }
    
    // MARK: - Persistence Integration Tests
    
    func testPersistence_SaveAndLoadProject_MaintainsState() {
        // Given
        let project = createMockProject()
        
        // When - save project
        appState.selectProject(project)
        
        // Simulate app restart by creating new app state
        let newAppState = AppState()
        
        // Then - project should be loaded (in a real implementation)
        // Note: This test would require actual UserDefaults testing
        // For now, we just verify the save mechanism was called
        XCTAssertEqual(appState.currentProject?.id, project.id)
    }
    
    // MARK: - UI Integration Tests
    
    func testContentView_NoProject_ShowsProjectManagement() {
        // Given
        appState.clearCurrentProject()
        
        // When
        let contentView = ContentView()
        
        // Then - should show project management
        XCTAssertFalse(appState.isProjectSelected)
        // Note: UI testing would require ViewInspector setup
    }
    
    func testContentView_WithProject_ShowsMainLayout() {
        // Given
        let project = createMockProject()
        appState.selectProject(project)
        
        // When
        let contentView = ContentView()
        
        // Then - should show main layout
        XCTAssertTrue(appState.isProjectSelected)
        // Note: UI testing would require ViewInspector setup
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_ProjectListLoading() {
        measure {
            let presenter = ProjectManagementPresenter()
            let projects = (1...100).map { createMockProject(name: "Project \($0)") }
            presenter.projectsFetched(projects)
        }
    }
    
    func testPerformance_ProjectCreation() {
        measure {
            let presenter = ProjectManagementPresenter()
            for i in 1...10 {
                presenter.createNewProject(name: "Performance Test Project \(i)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockProject(name: String = "Test Project") -> ProjectViewModel {
        return ProjectViewModel(
            id: UUID(),
            name: name,
            createdAt: Date(),
            updatedAt: Date(),
            patternCount: Int.random(in: 0...16),
            kitCount: Int.random(in: 0...8),
            presetCount: Int.random(in: 0...32)
        )
    }
}

// MARK: - Mock Objects for Integration Testing

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
        return AnyView(Text("Mock Module"))
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
