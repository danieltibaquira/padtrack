import SwiftUI
import DataLayer
import DataModel

/// Enhanced project browser view with +Drive integration
struct ProjectBrowserView: View {
    @StateObject private var viewModel = ProjectBrowserViewModel()
    @State private var searchText = ""
    @State private var selectedFilter: ProjectFilter = .all
    @State private var showingCreateProject = false
    @State private var showingImportProject = false
    @State private var sortOption: SortOption = .dateModified
    @State private var showingDriveManager = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with +Drive indicator
                HeaderView(
                    storageUsed: viewModel.storageUsed,
                    storageQuota: viewModel.storageQuota,
                    onDriveTapped: {
                        showingDriveManager = true
                    }
                )
                
                // Search and Filter Bar
                SearchFilterBar(
                    searchText: $searchText,
                    selectedFilter: $selectedFilter,
                    sortOption: $sortOption,
                    projectCount: viewModel.filteredProjects.count
                )
                
                // Projects Grid
                if viewModel.isLoading {
                    LoadingView()
                } else if viewModel.filteredProjects.isEmpty {
                    EmptyStateView(
                        filter: selectedFilter,
                        onCreateProject: {
                            showingCreateProject = true
                        }
                    )
                } else {
                    ProjectsGridView(
                        projects: viewModel.filteredProjects,
                        onSelectProject: viewModel.selectProject,
                        onDeleteProject: viewModel.deleteProject,
                        onDuplicateProject: viewModel.duplicateProject,
                        onExportProject: viewModel.exportProject,
                        onShowVersions: viewModel.showProjectVersions
                    )
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
            .onAppear {
                viewModel.loadProjects()
                viewModel.updateStorageInfo()
            }
            .onChange(of: searchText) { newValue in
                viewModel.searchQuery = newValue
            }
            .onChange(of: selectedFilter) { newValue in
                viewModel.filter = newValue
            }
            .onChange(of: sortOption) { newValue in
                viewModel.sortOption = newValue
            }
            .sheet(isPresented: $showingCreateProject) {
                CreateProjectView { name in
                    viewModel.createProject(name: name)
                }
            }
            .sheet(isPresented: $showingImportProject) {
                ImportProjectView { data in
                    viewModel.importProject(from: data)
                }
            }
            .sheet(isPresented: $showingDriveManager) {
                PlusDriveManagerView()
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

// MARK: - Header View

struct HeaderView: View {
    let storageUsed: Int64
    let storageQuota: Int64
    let onDriveTapped: () -> Void
    
    private var storagePercentage: Double {
        guard storageQuota > 0 else { return 0 }
        return Double(storageUsed) / Double(storageQuota)
    }
    
    private var storageString: String {
        let usedMB = Double(storageUsed) / 1_048_576
        let quotaMB = Double(storageQuota) / 1_048_576
        return String(format: "%.1f / %.0f MB", usedMB, quotaMB)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("DigitonePad Projects")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Tap a project to open")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // +Drive Storage Indicator
            Button(action: onDriveTapped) {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "internaldrive")
                            .font(.title3)
                        Text("+Drive")
                            .font(.headline)
                    }
                    .foregroundColor(.blue)
                    
                    Text(storageString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: storagePercentage)
                        .frame(width: 100)
                        .tint(storagePercentage > 0.8 ? .orange : .blue)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
}

// MARK: - Search and Filter Bar

struct SearchFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedFilter: ProjectFilter
    @Binding var sortOption: SortOption
    let projectCount: Int
    
    var body: some View {
        VStack(spacing: 12) {
            // Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search projects...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            
            // Filter and Sort Options
            HStack {
                // Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(ProjectFilter.allCases, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: 300)
                
                Spacer()
                
                // Sort Menu
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(action: { sortOption = option }) {
                            HStack {
                                Text(option.displayName)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text("Sort")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                
                // Project Count
                Text("\(projectCount) projects")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }
}

// MARK: - Projects Grid View

struct ProjectsGridView: View {
    let projects: [ProjectInfo]
    let onSelectProject: (ProjectInfo) -> Void
    let onDeleteProject: (ProjectInfo) -> Void
    let onDuplicateProject: (ProjectInfo) -> Void
    let onExportProject: (ProjectInfo) -> Void
    let onShowVersions: (ProjectInfo) -> Void
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)
            ], spacing: 16) {
                ForEach(projects, id: \.id) { project in
                    ProjectCardEnhanced(
                        project: project,
                        onSelect: { onSelectProject(project) },
                        onDelete: { onDeleteProject(project) },
                        onDuplicate: { onDuplicateProject(project) },
                        onExport: { onExportProject(project) },
                        onShowVersions: { onShowVersions(project) }
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Enhanced Project Card

struct ProjectCardEnhanced: View {
    let project: ProjectInfo
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onExport: () -> Void
    let onShowVersions: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("Modified \(project.lastModified ?? Date(), style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Menu {
                    Button(action: onDuplicate) {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    
                    Button(action: onExport) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: onShowVersions) {
                        Label("Show Versions", systemImage: "clock.arrow.circlepath")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
            }
            .padding()
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Project Stats
            HStack(spacing: 20) {
                ProjectStatView(
                    icon: "square.grid.3x3",
                    value: "\(project.patternCount)",
                    label: "Patterns"
                )
                
                ProjectStatView(
                    icon: "waveform",
                    value: "\(project.presetCount)",
                    label: "Presets"
                )
                
                ProjectStatView(
                    icon: "folder",
                    value: formatFileSize(project.size),
                    label: "Size"
                )
            }
            .padding()
            
            // Open Button
            Button(action: onSelect) {
                HStack {
                    Image(systemName: "folder.open")
                    Text("Open Project")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isHovered ? Color.blue.opacity(0.8) : Color.blue)
                .foregroundColor(.white)
                .font(.subheadline.weight(.medium))
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Project Stat View

struct ProjectStatView: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let filter: ProjectFilter
    let onCreateProject: () -> Void
    
    var message: String {
        switch filter {
        case .all:
            return "No projects yet. Create your first project to get started!"
        case .recent:
            return "No recent projects"
        case .favorites:
            return "No favorite projects"
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text(message)
                .font(.title3)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            if filter == .all {
                Button(action: onCreateProject) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Create New Project")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            Text("Loading projects...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Types

enum ProjectFilter: String, CaseIterable {
    case all = "All"
    case recent = "Recent"
    case favorites = "Favorites"
    
    var displayName: String { rawValue }
}

enum SortOption: String, CaseIterable {
    case dateModified = "Date Modified"
    case name = "Name"
    case size = "Size"
    
    var displayName: String { rawValue }
}

// MARK: - View Model

class ProjectBrowserViewModel: ObservableObject {
    @Published var projects: [ProjectInfo] = []
    @Published var filteredProjects: [ProjectInfo] = []
    @Published var isLoading = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var storageUsed: Int64 = 0
    @Published var storageQuota: Int64 = 500 * 1024 * 1024 // 500MB default
    
    @Published var searchQuery = "" {
        didSet { filterProjects() }
    }
    
    @Published var filter: ProjectFilter = .all {
        didSet { filterProjects() }
    }
    
    @Published var sortOption: SortOption = .dateModified {
        didSet { filterProjects() }
    }
    
    private let dataLayer = DataLayerManager.shared
    private let plusDriveManager: PlusDriveManager
    
    init() {
        self.plusDriveManager = PlusDriveManager(dataLayer: dataLayer)
    }
    
    func loadProjects() {
        isLoading = true
        
        DispatchQueue.global().async { [weak self] in
            do {
                let driveProjects = try self?.plusDriveManager.listProjects() ?? []
                let projectInfos = try driveProjects.compactMap { project in
                    try self?.plusDriveManager.getProjectInfo(projectId: project.id)
                }
                
                DispatchQueue.main.async {
                    self?.projects = projectInfos
                    self?.filterProjects()
                    self?.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                    self?.showingError = true
                    self?.isLoading = false
                }
            }
        }
    }
    
    func updateStorageInfo() {
        DispatchQueue.global().async { [weak self] in
            do {
                let used = try self?.plusDriveManager.getCurrentStorageUsage() ?? 0
                let quota = self?.plusDriveManager.storageQuotaMB ?? 500
                
                DispatchQueue.main.async {
                    self?.storageUsed = used
                    self?.storageQuota = quota * 1024 * 1024
                }
            } catch {
                print("Failed to update storage info: \(error)")
            }
        }
    }
    
    func createProject(name: String) {
        DispatchQueue.global().async { [weak self] in
            do {
                _ = try self?.plusDriveManager.createProject(name: name)
                DispatchQueue.main.async {
                    self?.loadProjects()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                    self?.showingError = true
                }
            }
        }
    }
    
    func selectProject(_ project: ProjectInfo) {
        // Navigate to main app with selected project
        // Implementation depends on navigation setup
    }
    
    func deleteProject(_ project: ProjectInfo) {
        // Show confirmation dialog first
        DispatchQueue.global().async { [weak self] in
            do {
                if let driveProject = try self?.plusDriveManager.loadProject(projectId: project.id) {
                    try self?.plusDriveManager.deleteProject(driveProject)
                    DispatchQueue.main.async {
                        self?.loadProjects()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                    self?.showingError = true
                }
            }
        }
    }
    
    func duplicateProject(_ project: ProjectInfo) {
        // Implement project duplication
    }
    
    func exportProject(_ project: ProjectInfo) {
        // Implement project export
    }
    
    func showProjectVersions(_ project: ProjectInfo) {
        // Show version history
    }
    
    func importProject(from data: Data) {
        DispatchQueue.global().async { [weak self] in
            do {
                _ = try self?.plusDriveManager.importProject(from: data)
                DispatchQueue.main.async {
                    self?.loadProjects()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                    self?.showingError = true
                }
            }
        }
    }
    
    private func filterProjects() {
        var filtered = projects
        
        // Apply search filter
        if !searchQuery.isEmpty {
            filtered = filtered.filter { project in
                project.name.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        // Apply category filter
        switch filter {
        case .all:
            break
        case .recent:
            let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            filtered = filtered.filter { project in
                (project.lastModified ?? Date.distantPast) > oneWeekAgo
            }
        case .favorites:
            // Implement favorites logic
            break
        }
        
        // Apply sorting
        switch sortOption {
        case .dateModified:
            filtered.sort { ($0.lastModified ?? Date.distantPast) > ($1.lastModified ?? Date.distantPast) }
        case .name:
            filtered.sort { $0.name < $1.name }
        case .size:
            filtered.sort { $0.size > $1.size }
        }
        
        filteredProjects = filtered
    }
}

// MARK: - Additional Views

struct CreateProjectView: View {
    @State private var projectName = ""
    @Environment(\.dismiss) var dismiss
    let onCreate: (String) -> Void
    
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(projectName)
                        dismiss()
                    }
                    .disabled(projectName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct ImportProjectView: View {
    @Environment(\.dismiss) var dismiss
    let onImport: (Data) -> Void
    
    var body: some View {
        // File picker implementation
        Text("Import Project")
            .onAppear {
                // Show file picker
            }
    }
}

struct PlusDriveManagerView: View {
    var body: some View {
        NavigationView {
            Text("+Drive Manager")
                .navigationTitle("+Drive")
        }
    }
}