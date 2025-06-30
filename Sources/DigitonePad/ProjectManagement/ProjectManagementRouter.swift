import Foundation
import SwiftUI

/// Router handles navigation for project management
public final class ProjectManagementRouter: ProjectManagementRouterProtocol, ObservableObject {
    
    // MARK: - Navigation Methods
    
    public static func createProjectManagementModule() -> ProjectManagementView {
        let view = ProjectManagementView()
        let presenter = ProjectManagementPresenter()
        let interactor = ProjectManagementInteractor()
        let router = ProjectManagementRouter()
        
        // Wire up VIPER components
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter
        
        return view
    }
    
    @MainActor
    public func navigateToMainApp(with project: ProjectViewModel) {
        Task {
            await AppState.shared.selectProject(project)
        }
        // Additional navigation logic would go here
        // For example, presenting the main app view
    }

    public func showProjectSettings(for project: ProjectViewModel) {
        // TODO: Show project settings view
        // This will be implemented when project settings are needed
        print("Showing settings for project: \(project.name)")
    }
}
