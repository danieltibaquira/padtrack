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
    
    func getAllProjects() {
        Task { [weak self] in
            do {
                let projects = try await self?.dataLayerManager.fetchAllProjects() ?? []
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
                let project = try await self?.dataLayerManager.createProject(name: name)
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
    
    func deleteProject(_ project: Project) {
        Task { [weak self] in
            do {
                try await self?.dataLayerManager.deleteProject(project)
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
                try await self?.dataLayerManager.saveContext()
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
                try await self?.dataLayerManager.setActiveProject(project)
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
}

// MARK: - DataLayerManager Extensions

extension DataLayerManager {
    
    /// Convenience method to create a new project
    func createProject(name: String) async throws -> Project {
        let context = persistentContainer.viewContext
        return try await context.perform {
            let project = Project(context: context)
            project.id = UUID()
            project.name = name
            project.createdAt = Date()
            project.updatedAt = Date()
            
            try context.save()
            return project
        }
    }
    
    /// Convenience method to fetch all projects
    func fetchAllProjects() async throws -> [Project] {
        let context = persistentContainer.viewContext
        return try await context.perform {
            let request: NSFetchRequest<Project> = Project.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Project.updatedAt, ascending: false)]
            return try context.fetch(request)
        }
    }
    
    /// Convenience method to delete a project
    func deleteProject(_ project: Project) async throws {
        let context = persistentContainer.viewContext
        try await context.perform {
            context.delete(project)
            try context.save()
        }
    }
    
    /// Convenience method to set active project
    func setActiveProject(_ project: Project) async throws {
        // Implementation for setting active project
        // This would involve storing the active project ID in UserDefaults
        // or some other persistent storage mechanism
        UserDefaults.standard.set(project.id?.uuidString, forKey: "ActiveProjectID")
    }
    
    /// Save the managed object context
    func saveContext() async throws {
        let context = persistentContainer.viewContext
        try await context.perform {
            if context.hasChanges {
                try context.save()
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
