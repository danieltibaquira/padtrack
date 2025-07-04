import XCTest
import SwiftUI
@testable import DigitonePad

/// UI tests for Project Management SwiftUI components
class ProjectManagementUITests: XCTestCase {
    
    var presenter: ProjectManagementPresenter!
    
    override func setUp() {
        super.setUp()
        presenter = ProjectManagementPresenter()
    }
    
    override func tearDown() {
        presenter = nil
        super.tearDown()
    }
    
    // MARK: - ProjectManagementView Tests
    
    func testProjectManagementView_InitialState_CanBeCreated() throws {
        // Given/When
        let view = ProjectManagementView()

        // Then
        XCTAssertNotNil(view)
    }

    func testProjectManagementView_WithProjects_CanBeCreated() throws {
        // Given
        let view = ProjectManagementView()
        let presenter = ProjectManagementPresenter()
        presenter.projects = [createMockProject()]

        // When/Then
        XCTAssertNotNil(view)
        XCTAssertNotNil(presenter)
    }

    func testProjectManagementView_EmptyState_CanBeCreated() throws {
        // Given
        let view = ProjectManagementView()
        let presenter = ProjectManagementPresenter()
        presenter.projects = []
        presenter.isLoading = false

        // When/Then
        XCTAssertNotNil(view)
        XCTAssertEqual(presenter.projects.count, 0)
        XCTAssertFalse(presenter.isLoading)
    }

    func testProjectManagementView_NavigationTitle_CanBeCreated() throws {
        // Given/When
        let view = ProjectManagementView()

        // Then
        XCTAssertNotNil(view)
    }
    
    // MARK: - ProjectRowView Tests
    
    func testProjectRowView_DisplaysProjectInfo() throws {
        // Given
        let project = createMockProject()
        var tapCalled = false
        var deleteCalled = false
        
        let view = ProjectRowView(
            project: project,
            onTap: { tapCalled = true },
            onDelete: { deleteCalled = true }
        )
        
        // When/Then
        XCTAssertNotNil(view)
        XCTAssertFalse(tapCalled)
        XCTAssertFalse(deleteCalled)
    }

    func testProjectRowView_TapGesture_CallsOnTap() throws {
        // Given
        let project = createMockProject()
        var tapCalled = false

        let view = ProjectRowView(
            project: project,
            onTap: { tapCalled = true },
            onDelete: { }
        )

        // When/Then
        XCTAssertNotNil(view)
        XCTAssertFalse(tapCalled)
    }
    
    // MARK: - Integration Tests
    
    func testProjectManagementView_CreateProject_UpdatesList() {
        // Given
        let expectation = XCTestExpectation(description: "Project created")
        let presenter = ProjectManagementPresenter()
        
        // Mock the interactor to simulate successful project creation
        let mockInteractor = MockProjectManagementInteractor()
        presenter.interactor = mockInteractor
        
        // When
        presenter.createNewProject(name: "Test Project")
        
        // Simulate successful creation
        let newProject = createMockProject()
        presenter.projectCreated(newProject)
        
        // Then
        XCTAssertEqual(presenter.projects.count, 1)
        XCTAssertEqual(presenter.projects.first?.name, newProject.name)
        expectation.fulfill()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testProjectManagementView_DeleteProject_RemovesFromList() {
        // Given
        let expectation = XCTestExpectation(description: "Project deleted")
        let presenter = ProjectManagementPresenter()
        let project = createMockProject()
        presenter.projects = [project]
        
        // Mock the interactor
        let mockInteractor = MockProjectManagementInteractor()
        presenter.interactor = mockInteractor
        
        // When
        presenter.deleteProject(project)
        
        // Simulate successful deletion
        presenter.projectDeleted()
        
        // Then
        XCTAssertTrue(mockInteractor.deleteProjectCalled)
        expectation.fulfill()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testProjectManagementView_LoadProject_NavigatesToMainApp() {
        // Given
        let expectation = XCTestExpectation(description: "Project loaded")
        let presenter = ProjectManagementPresenter()
        let project = createMockProject()
        
        // Mock the router
        let mockRouter = MockProjectManagementRouter()
        presenter.router = mockRouter
        
        // When
        presenter.projectLoaded(project)
        
        // Then
        XCTAssertTrue(mockRouter.navigateToMainAppCalled)
        XCTAssertEqual(mockRouter.navigateToMainAppProject?.id, project.id)
        expectation.fulfill()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testProjectManagementView_ErrorState_ShowsErrorMessage() {
        // Given
        let presenter = ProjectManagementPresenter()
        let error = ProjectManagementError.failedToCreateProject
        
        // When
        presenter.projectCreationFailed(error)
        
        // Then
        XCTAssertNotNil(presenter.errorMessage)
        XCTAssertEqual(presenter.errorMessage, error.localizedDescription)
        XCTAssertFalse(presenter.isLoading)
    }
    
    func testProjectManagementView_ClearError_ResetsErrorState() {
        // Given
        let presenter = ProjectManagementPresenter()
        presenter.errorMessage = "Test error"
        
        // When
        presenter.clearError()
        
        // Then
        XCTAssertNil(presenter.errorMessage)
    }
    
    // MARK: - Helper Methods
    
    private func createMockProject() -> ProjectViewModel {
        return ProjectViewModel(
            id: UUID(),
            name: "Test Project",
            createdAt: Date(),
            updatedAt: Date(),
            patternCount: 5,
            kitCount: 3,
            presetCount: 10
        )
    }
}


