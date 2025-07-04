import Foundation
import CoreData
import DataLayer
import Combine

/// Project Management Interactor - handles business logic for project management
class ProjectManagementInteractor: ProjectManagementInteractorProtocol, @unchecked Sendable {
    
    weak var presenter: ProjectManagementPresenterProtocol?
    private let dataLayerManager: DataLayerManager
    
    // MARK: - Initialization
    init(dataLayerManager: DataLayerManager = DataLayerManager.shared) {
        self.dataLayerManager = dataLayerManager
    }
    
    // MARK: - Project Management
    
    func fetchProjects() {
        Task { [weak self] in
            do {
                let projects = try self?.dataLayerManager.projectRepository.fetch() ?? []
                await MainActor.run {
                    self?.presenter?.projectsFetchSucceeded(projects)
                }
            } catch {
                await MainActor.run {
                    self?.presenter?.projectsFetchFailed(error)
                }
            }
        }
    }
    
    func createProject(name: String) {
        Task { [weak self] in
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
                await MainActor.run {
                    self?.presenter?.projectCreationFailed(ProjectManagementError.invalidProjectName)
                }
                return
            }
            
            do {
                let project = self?.dataLayerManager.projectRepository.createProject(name: name)
                try self?.dataLayerManager.save()
                await MainActor.run {
                    if let project = project {
                        self?.presenter?.projectCreationSucceeded(project)
                    }
                }
            } catch {
                await MainActor.run {
                    self?.presenter?.projectCreationFailed(error)
                }
            }
        }
    }
    
    func deleteProject(id: UUID) {
        Task { [weak self] in
            do {
                let projects = try self?.dataLayerManager.projectRepository.fetch() ?? []
                guard let project = projects.first(where: { $0.objectID.uriRepresentation().absoluteString.contains(id.uuidString) }) else {
                    await MainActor.run {
                        self?.presenter?.projectDeletionFailed(ProjectManagementError.projectNotFound)
                    }
                    return
                }
                try self?.dataLayerManager.projectRepository.delete(project)
                await MainActor.run {
                    self?.presenter?.projectDeletionSucceeded(project)
                }
            } catch {
                await MainActor.run {
                    self?.presenter?.projectDeletionFailed(error)
                }
            }
        }
    }

    func loadProject(id: UUID) {
        Task { [weak self] in
            do {
                let projects = try self?.dataLayerManager.projectRepository.fetch() ?? []
                guard let project = projects.first(where: { $0.objectID.uriRepresentation().absoluteString.contains(id.uuidString) }) else {
                    await MainActor.run {
                        self?.presenter?.projectSelectionFailed(ProjectManagementError.projectNotFound)
                    }
                    return
                }
                // Store active project ID in UserDefaults for now
                UserDefaults.standard.set(project.objectID.uriRepresentation().absoluteString, forKey: "ActiveProjectID")
                await MainActor.run {
                    self?.presenter?.projectSelectionSucceeded(project)
                }
            } catch {
                await MainActor.run {
                    self?.presenter?.projectSelectionFailed(error)
                }
            }
        }
    }

    func deleteProject(_ project: Project) {
        Task { [weak self] in
            do {
                try self?.dataLayerManager.projectRepository.delete(project)
                await MainActor.run {
                    self?.presenter?.projectDeletionSucceeded(project)
                }
            } catch {
                await MainActor.run {
                    self?.presenter?.projectDeletionFailed(error)
                }
            }
        }
    }
    
    func updateProject(_ project: Project, newName: String) {
        Task { [weak self] in
            guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else {
                await MainActor.run {
                    self?.presenter?.projectUpdateFailed(ProjectManagementError.invalidProjectName)
                }
                return
            }
            
            do {
                project.name = newName
                try self?.dataLayerManager.save()
                await MainActor.run {
                    self?.presenter?.projectUpdateSucceeded(project)
                }
            } catch {
                await MainActor.run {
                    self?.presenter?.projectUpdateFailed(error)
                }
            }
        }
    }
    
    func selectProject(_ project: Project) {
        Task { [weak self] in
            do {
                // Store active project ID in UserDefaults for now
                UserDefaults.standard.set(project.objectID.uriRepresentation().absoluteString, forKey: "ActiveProjectID")
                await MainActor.run {
                    self?.presenter?.projectSelectionSucceeded(project)
                }
            } catch {
                await MainActor.run {
                    self?.presenter?.projectSelectionFailed(error)
                }
            }
        }
    }

    // MARK: - Protocol Methods

    /// Load projects - alias for fetchProjects
    func loadProjects() {
        fetchProjects()
    }

    /// Select project by ID
    func selectProject(id: UUID) {
        Task {
            do {
                let projects = try self.dataLayerManager.projectRepository.fetch()
                guard let project = projects.first(where: { $0.objectID.uriRepresentation().absoluteString.contains(id.uuidString) }) else {
                    await MainActor.run {
                        self.presenter?.projectSelectionFailed(ProjectManagementError.projectNotFound)
                    }
                    return
                }

                // Store active project ID in UserDefaults for now
                UserDefaults.standard.set(project.objectID.uriRepresentation().absoluteString, forKey: "ActiveProjectID")
                await MainActor.run {
                    self.presenter?.projectSelectionSucceeded(project)
                }
            } catch {
                await MainActor.run {
                    self.presenter?.projectSelectionFailed(error)
                }
            }
        }
    }
}



// MARK: - Presenter Protocol Extensions

extension ProjectManagementPresenterProtocol {
    func projectsFetchSucceeded(_ projects: [Project]) {}
    func projectsFetchFailed(_ error: Error) {}
    func projectCreationSucceeded(_ project: Project) {}
    func projectCreationFailed(_ error: Error) {}
    func projectDeletionSucceeded(_ project: Project) {}
    func projectDeletionFailed(_ error: Error) {}
    func projectUpdateSucceeded(_ project: Project) {}
    func projectUpdateFailed(_ error: Error) {}
    func projectSelectionSucceeded(_ project: Project) {}
    func projectSelectionFailed(_ error: Error) {}
}
