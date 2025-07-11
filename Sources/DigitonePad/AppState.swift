import Foundation
import SwiftUI
import DataLayer
import DataModel

/// Global app state management
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var selectedProject: ProjectViewModel?
    @Published var isProjectLoaded = false
    
    // Shared instances to avoid redundant creation
    lazy var driveManager = PlusDriveManager(context: CoreDataStack.shared.context)
    private var presetPools: [UUID: PresetPool] = [:]
    
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
    
    /// Get or create a PresetPool for a given project
    func presetPool(for project: Project) -> PresetPool {
        let projectID = project.objectID.uriRepresentation().absoluteString
        let uuid = UUID(uuidString: projectID) ?? UUID()
        
        if let existingPool = presetPools[uuid] {
            return existingPool
        }
        
        let newPool = PresetPool(project: project, context: CoreDataStack.shared.context)
        presetPools[uuid] = newPool
        return newPool
    }
}