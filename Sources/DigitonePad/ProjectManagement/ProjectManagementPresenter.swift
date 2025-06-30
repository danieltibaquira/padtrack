import Foundation
import SwiftUI

/// Presenter handles presentation logic and coordinates between View and Interactor
class ProjectManagementPresenter: ProjectManagementPresenterProtocol, ObservableObject, @unchecked Sendable {
    weak var view: ProjectManagementViewProtocol?
    var interactor: ProjectManagementInteractorProtocol?
    var router: ProjectManagementRouterProtocol?
    
    @Published var projects: [ProjectViewModel] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    init() {}
    
    // MARK: - ProjectManagementPresenterProtocol
    
    func viewDidLoad() {
        isLoading = true
        interactor?.fetchProjects()
    }
    
    func createNewProject(name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Project name cannot be empty"
            return
        }
        
        isLoading = true
        errorMessage = nil
        interactor?.createProject(name: name)
    }
    
    func loadProject(_ project: ProjectViewModel) {
        isLoading = true
        errorMessage = nil
        interactor?.loadProject(id: project.id)
    }
    
    func deleteProject(_ project: ProjectViewModel) {
        isLoading = true
        errorMessage = nil
        interactor?.deleteProject(id: project.id)
    }
    
    func refreshProjects() {
        isLoading = true
        errorMessage = nil
        interactor?.fetchProjects()
    }
    
    // MARK: - Interactor Response Handlers
    
    func projectsFetched(_ projects: [ProjectViewModel]) {
        DispatchQueue.main.async { [weak self] in
            self?.projects = projects
            self?.isLoading = false
            self?.view?.showProjects(projects)
        }
    }
    
    func projectsFetchFailed(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = false
            self?.errorMessage = error.localizedDescription
            self?.view?.showError(error)
        }
    }
    
    func projectCreated(_ project: ProjectViewModel) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = false
            self?.projects.insert(project, at: 0) // Add to beginning of list
            self?.view?.showProjectCreated(project)
        }
    }
    
    func projectCreationFailed(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = false
            self?.errorMessage = error.localizedDescription
            self?.view?.showError(error)
        }
    }
    
    func projectDeleted() {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = false
            self?.view?.showProjectDeleted()
            // Refresh the list after deletion
            self?.refreshProjects()
        }
    }
    
    func projectDeletionFailed(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = false
            self?.errorMessage = error.localizedDescription
            self?.view?.showError(error)
        }
    }
    
    func projectLoaded(_ project: ProjectViewModel) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = false
            self?.router?.navigateToMainApp(with: project)
        }
    }
    
    func projectLoadFailed(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = false
            self?.errorMessage = error.localizedDescription
            self?.view?.showError(error)
        }
    }
}

// MARK: - Helper Methods

extension ProjectManagementPresenter {
    func clearError() {
        errorMessage = nil
    }
    
    func hasProjects() -> Bool {
        return !projects.isEmpty
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
