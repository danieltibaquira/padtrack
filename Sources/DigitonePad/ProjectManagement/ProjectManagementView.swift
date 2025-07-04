import SwiftUI
import DataLayer

/// Main view for project management using SwiftUI
struct ProjectManagementView: View {
    @StateObject private var presenter = ProjectManagementPresenter()
    @State private var showingCreateProject = false
    @State private var newProjectName = ""
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Header
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
                            ForEach(presenter.projects, id: \.id) { project in
                                ProjectCard(
                                    project: ProjectDisplayModel(from: project),
                                    onSelect: { presenter.selectProject(project) },
                                    onDelete: { presenter.deleteProject(project) }
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
        }
    }
}

struct ProjectCard: View {
    let project: ProjectDisplayModel
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(project.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Menu {
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
        self.id = project.id ?? UUID()
        self.name = project.name ?? "Untitled Project"
        self.lastModified = project.updatedAt ?? Date()
    }

    init(from viewModel: ProjectViewModel) {
        self.id = viewModel.id
        self.name = viewModel.name
        self.lastModified = viewModel.updatedAt
    }
}

// MARK: - Preview

struct ProjectManagementView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectManagementView()
    }
}
