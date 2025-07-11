import SwiftUI
import DataLayer
import DataModel
import UIComponents

/// Main view for project management using SwiftUI
public struct ProjectManagementView: View {
    @StateObject private var presenter = ProjectManagementPresenter()
    @State private var showingCreateProject = false
    @State private var newProjectName = ""
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var selectedProject: ProjectViewModel?
    @State private var showingProjectDetail = false
    @State private var searchQuery = ""
    @State private var sortOption = ProjectSortOption.dateNewest
    @State private var filterOption = ProjectFilterOption.all
    
    public var body: some View {
        NavigationView {
            VStack {
                // Header with search and filter
                VStack(spacing: 16) {
                    HStack {
                        Text("DigitonePad Projects")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            showingCreateProject = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Search and filter bar
                    HStack {
                        // Search field
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search projects...", text: $searchQuery)
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                        
                        // Sort menu
                        Menu {
                            Button(action: { sortOption = .dateNewest }) {
                                Label("Newest First", systemImage: sortOption == .dateNewest ? "checkmark" : "")
                            }
                            Button(action: { sortOption = .dateOldest }) {
                                Label("Oldest First", systemImage: sortOption == .dateOldest ? "checkmark" : "")
                            }
                            Button(action: { sortOption = .name }) {
                                Label("Name", systemImage: sortOption == .name ? "checkmark" : "")
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                
                // Projects List
                if presenter.projects.isEmpty {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        
                        Text("No Projects")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        Text("Create your first project to get started")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)
                        ], spacing: 16) {
                            ForEach(filteredProjects, id: \.id) { project in
                                ProjectCard(
                                    project: ProjectDisplayModel(from: project),
                                    onSelect: { 
                                        selectedProject = project
                                        showingProjectDetail = true
                                    },
                                    onDelete: { presenter.deleteProject(project) },
                                    onDuplicate: { duplicateProject(project) },
                                    onExport: { exportProject(project) }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
            #if os(iOS)
            .navigationBarHidden(true)
            #else
            .toolbar(.hidden)
            #endif
            .onAppear {
                presenter.loadProjects()
            }
            .sheet(isPresented: $showingCreateProject) {
                CreateProjectSheet(
                    projectName: $newProjectName,
                    onCreate: { name in
                        presenter.createProject(name: name)
                        showingCreateProject = false
                        newProjectName = ""
                    },
                    onCancel: {
                        showingCreateProject = false
                        newProjectName = ""
                    }
                )
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .onReceive(presenter.$errorMessage) { error in
                if let error = error {
                    errorMessage = error
                    showingError = true
                }
            }
            .sheet(isPresented: $showingProjectDetail) {
                if let project = selectedProject,
                   let projectEntity = getProjectEntity(for: project) {
                    ProjectDetailView(
                        project: project,
                        driveManager: AppState.shared.driveManager,
                        presetPool: AppState.shared.presetPool(for: projectEntity)
                    )
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredProjects: [ProjectViewModel] {
        var projects = presenter.projects
        
        // Apply search filter
        if !searchQuery.isEmpty {
            projects = projects.filter { project in
                project.name.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        // Apply sort
        switch sortOption {
        case .dateNewest:
            projects.sort { $0.updatedAt > $1.updatedAt }
        case .dateOldest:
            projects.sort { $0.updatedAt < $1.updatedAt }
        case .name:
            projects.sort { $0.name < $1.name }
        }
        
        return projects
    }
    
    // MARK: - Methods
    
    private func duplicateProject(_ project: ProjectViewModel) {
        // TODO: Implement project duplication
    }
    
    private func exportProject(_ project: ProjectViewModel) {
        // TODO: Implement project export
    }
    
    private func getProjectEntity(for viewModel: ProjectViewModel) -> Project? {
        // Fetch existing project from Core Data
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<Project> = Project.fetchRequest()
        
        // Try to match by name and creation date
        fetchRequest.predicate = NSPredicate(
            format: "name == %@ AND createdAt == %@",
            viewModel.name,
            viewModel.createdAt as CVarArg
        )
        fetchRequest.fetchLimit = 1
        
        do {
            let projects = try context.fetch(fetchRequest)
            if let existingProject = projects.first {
                return existingProject
            }
            
            // If not found, create a new project (should rarely happen)
            let newProject = Project(context: context)
            newProject.name = viewModel.name
            newProject.createdAt = viewModel.createdAt
            newProject.updatedAt = viewModel.updatedAt
            
            // Save to persist the new project
            try context.save()
            
            return newProject
        } catch {
            print("Error fetching project: \(error)")
            return nil
        }
    }
}

struct ProjectCard: View {
    let project: ProjectDisplayModel
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onExport: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(project.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Menu {
                    Button(action: onDuplicate) {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    
                    Button(action: onExport) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gray)
                }
            }
            
            Text("Updated \(project.lastModified, style: .relative) ago")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Open Project") {
                onSelect()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .frame(height: 150)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}

struct CreateProjectSheet: View {
    @Binding var projectName: String
    let onCreate: (String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create New Project")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                TextField("Project Name", text: $projectName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        onCreate(projectName)
                    }
                    .disabled(projectName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(projectName)
                    }
                    .disabled(projectName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                #endif
            }
        }
    }
}

// MARK: - Supporting Types

struct ProjectDisplayModel: Identifiable {
    let id: UUID
    let name: String
    let lastModified: Date

    init(from project: Project) {
        // Create a deterministic UUID from the Core Data objectID
        let objectIDString = project.objectID.uriRepresentation().absoluteString
        let hash = objectIDString.hash
        var uuid = UUID().uuidString
        uuid.replaceSubrange(uuid.startIndex..<uuid.index(uuid.startIndex, offsetBy: 8), with: String(format: "%08X", abs(hash)))
        self.id = UUID(uuidString: uuid) ?? UUID()
        self.name = project.name ?? "Untitled Project"
        self.lastModified = project.updatedAt ?? Date()
    }

    init(from viewModel: ProjectViewModel) {
        self.id = viewModel.id
        self.name = viewModel.name
        self.lastModified = viewModel.updatedAt
    }
}

// MARK: - Supporting Types

enum ProjectSortOption {
    case dateNewest
    case dateOldest
    case name
}

enum ProjectFilterOption {
    case all
    case recent
    case favorites
}

// MARK: - Preview

struct ProjectManagementView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectManagementView()
    }
}
