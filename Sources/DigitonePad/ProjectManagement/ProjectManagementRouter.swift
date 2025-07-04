import Foundation
import SwiftUI

/// Router handles navigation for project management
public final class ProjectManagementRouter: ProjectManagementRouterProtocol, ObservableObject {

    // MARK: - Navigation Methods

    public static func createModule() -> AnyView {
        let view = ProjectManagementView()
        let presenter = ProjectManagementPresenter()
        let interactor = ProjectManagementInteractor()
        let router = ProjectManagementRouter()

        // Wire up VIPER components - Note: SwiftUI views handle their own state
        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter

        return AnyView(view.environmentObject(presenter))
    }

    static func createProjectManagementModule() -> ProjectManagementView {
        let view = ProjectManagementView()
        return view
    }
    
    public func navigateToMainApp(with project: ProjectViewModel) {
        Task { @MainActor in
            AppState.shared.selectProject(project)
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
