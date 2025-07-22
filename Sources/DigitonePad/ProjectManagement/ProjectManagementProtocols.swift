import Foundation
import SwiftUI
import Combine
import DataLayer
import DataModel

// MARK: - VIPER Protocols for Project Management

/// View Protocol - Defines what the View can do
protocol ProjectManagementViewProtocol: AnyObject {
    var presenter: ProjectManagementPresenterProtocol? { get set }
    
    func showProjects(_ projects: [ProjectViewModel])
    func showError(_ error: Error)
    func showLoading(_ isLoading: Bool)
    func showProjectCreated(_ project: ProjectViewModel)
    func showProjectDeleted()
}

/// Presenter Protocol - Defines what the Presenter can do
protocol ProjectManagementPresenterProtocol: AnyObject {
    var view: ProjectManagementViewProtocol? { get set }
    var interactor: ProjectManagementInteractorProtocol? { get set }
    var router: ProjectManagementRouterProtocol? { get set }
    
    func viewDidLoad()
    func createNewProject(name: String)
    func loadProject(_ project: ProjectViewModel)
    func deleteProject(_ project: ProjectViewModel)
    func refreshProjects()
}

/// Interactor Protocol - Defines what the Interactor can do
protocol ProjectManagementInteractorProtocol: AnyObject {
    var presenter: ProjectManagementPresenterProtocol? { get set }

    func fetchProjects()
    func createProject(name: String)
    func deleteProject(id: UUID)
    func loadProject(id: UUID)
    func loadProjects()
    func selectProject(id: UUID)
}

/// Router Protocol - Defines what the Router can do
protocol ProjectManagementRouterProtocol: AnyObject {
    static func createModule() -> AnyView

    func navigateToMainApp(with project: ProjectViewModel)
    func showProjectSettings(for project: ProjectViewModel)
}

// MARK: - View Models

public struct ProjectViewModel: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
    public let updatedAt: Date
    public let patternCount: Int
    public let kitCount: Int
    public let presetCount: Int

    public init(id: UUID = UUID(), name: String, createdAt: Date, updatedAt: Date, patternCount: Int, kitCount: Int, presetCount: Int) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.patternCount = patternCount
        self.kitCount = kitCount
        self.presetCount = presetCount
    }

    public init(from project: Project) {
        // Create a deterministic UUID from the object ID
        let objectIDString = project.objectID.uriRepresentation().absoluteString
        let uuid = UUID(uuidString: String(objectIDString.suffix(36))) ?? UUID()

        self.init(
            id: uuid,
            name: project.name ?? "Untitled Project",
            createdAt: project.createdAt ?? Date(),
            updatedAt: project.updatedAt ?? Date(),
            patternCount: project.patterns?.count ?? 0,
            kitCount: project.kits?.count ?? 0,
            presetCount: project.presets?.count ?? 0
        )
    }
}

// MARK: - Errors

enum ProjectManagementError: LocalizedError {
    case failedToCreateProject
    case failedToLoadProject
    case failedToDeleteProject
    case projectNotFound
    case invalidProjectName
    
    var errorDescription: String? {
        switch self {
        case .failedToCreateProject:
            return "Failed to create project"
        case .failedToLoadProject:
            return "Failed to load project"
        case .failedToDeleteProject:
            return "Failed to delete project"
        case .projectNotFound:
            return "Project not found"
        case .invalidProjectName:
            return "Invalid project name"
        }
    }
}
