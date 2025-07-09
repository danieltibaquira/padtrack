import Foundation
import SwiftUI

/// Global app state management
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var selectedProject: ProjectViewModel?
    @Published var isProjectLoaded = false
    
    private init() {}
    
    func selectProject(_ project: ProjectViewModel) {
        selectedProject = project
        isProjectLoaded = true
        
        // In a real implementation, this would:
        // 1. Load the project data
        // 2. Initialize the audio engine with project settings
        // 3. Navigate to the main synthesizer view
    }
    
    func closeProject() {
        selectedProject = nil
        isProjectLoaded = false
    }
}