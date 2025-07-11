import SwiftUI
import DataLayer
import DataModel

/// Detailed view for managing a project
public struct ProjectDetailView: View {
    
    // MARK: - Properties
    
    let project: ProjectViewModel
    let driveManager: PlusDriveManager
    let presetPool: PresetPool
    
    @State private var showingDeleteConfirmation = false
    @State private var showingExportSheet = false
    @State private var showingVersionHistory = false
    @State private var showingAddPatternSheet = false
    @State private var showingPresetPool = false
    @State private var newPatternName = ""
    @State private var selectedPattern: PatternViewModel?
    @State private var patterns: [PatternViewModel] = []
    @State private var versions: [ProjectVersionViewModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Project Info Section
                    projectInfoSection
                    
                    Divider()
                    
                    // Patterns Section
                    patternsSection
                    
                    Divider()
                    
                    // Preset Pool Section
                    presetPoolSection
                    
                    Divider()
                    
                    // Actions Section
                    actionsSection
                    
                    if showingVersionHistory {
                        Divider()
                        versionHistorySection
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle(project.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingAddPatternSheet) {
                addPatternSheet
            }
            .sheet(isPresented: $showingExportSheet) {
                exportSheet
            }
            .sheet(isPresented: $showingPresetPool) {
                NavigationView {
                    PresetPoolView(presetPool: presetPool)
                }
            }
            .alert("Delete Project", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteProject()
                }
            } message: {
                Text("Are you sure you want to delete this project? This action cannot be undone.")
            }
            .onAppear {
                loadProjectData()
            }
        }
    }
    
    // MARK: - Sections
    
    private var projectInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Project Info")
                .font(.headline)
            
            HStack {
                Label("Created:", systemImage: "calendar")
                    .foregroundColor(.secondary)
                Text(project.createdAt, style: .date)
                Spacer()
            }
            
            HStack {
                Label("Updated:", systemImage: "clock")
                    .foregroundColor(.secondary)
                Text(project.updatedAt, style: .relative) + Text(" ago")
                Spacer()
            }
            
            HStack {
                Label("BPM:", systemImage: "metronome")
                    .foregroundColor(.secondary)
                Text("120") // TODO: Get from project
                Spacer()
            }
            
            HStack {
                Label("Size:", systemImage: "doc")
                    .foregroundColor(.secondary)
                Text(formatFileSize(getProjectSize()))
                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Patterns")
                    .font(.headline)
                
                Spacer()
                
                Text("\(patterns.count) patterns")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: { showingAddPatternSheet = true }) {
                    Label("Add Pattern", systemImage: "plus.circle.fill")
                        .font(.caption)
                }
            }
            
            if patterns.isEmpty {
                Text("No patterns yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(patterns) { pattern in
                    PatternRow(pattern: pattern) {
                        selectPattern(pattern)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var presetPoolSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preset Pool")
                    .font(.headline)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(presetPool.presetCount) presets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(presetPool.allCategories().count) categories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: { showingPresetPool = true }) {
                Label("Open Preset Pool", systemImage: "music.note.list")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button(action: duplicateProject) {
                    Label("Duplicate Project", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: { showingExportSheet = true }) {
                    Label("Export Project", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            
            Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                Label("Delete Project", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var versionHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Version History")
                .font(.headline)
            
            if versions.isEmpty {
                Text("No versions saved")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(versions) { version in
                    VersionRow(version: version) {
                        restoreVersion(version)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showingVersionHistory.toggle() }) {
                Image(systemName: showingVersionHistory ? "clock.arrow.circlepath" : "clock")
            }
        }
        #else
        ToolbarItem(placement: .automatic) {
            Button(action: { showingVersionHistory.toggle() }) {
                Label("Version History", systemImage: showingVersionHistory ? "clock.arrow.circlepath" : "clock")
            }
        }
        #endif
    }
    
    // MARK: - Sheets
    
    private var addPatternSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("New Pattern")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                TextField("Pattern Name", text: $newPatternName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Spacer()
            }
            .padding()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newPatternName = ""
                        showingAddPatternSheet = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        addPattern()
                    }
                    .disabled(newPatternName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var exportSheet: some View {
        VStack(spacing: 20) {
            Text("Export Project")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Choose export format:")
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Button(action: { exportProject(format: .json) }) {
                    Label("Export as JSON", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: { exportProject(format: .binary) }) {
                    Label("Export as Binary", systemImage: "doc.zipper")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            Button("Cancel") {
                showingExportSheet = false
            }
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func loadProjectData() {
        isLoading = true
        
        // Load patterns
        // In real implementation, would fetch from driveManager
        patterns = []
        
        // Load versions
        // In real implementation, would fetch from driveManager
        versions = []
        
        isLoading = false
    }
    
    private func addPattern() {
        let trimmedName = newPatternName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        // In real implementation, would use driveManager.addPattern
        let newPattern = PatternViewModel(id: UUID(), name: trimmedName, length: 64)
        patterns.append(newPattern)
        
        newPatternName = ""
        showingAddPatternSheet = false
    }
    
    private func selectPattern(_ pattern: PatternViewModel) {
        selectedPattern = pattern
        // Navigate to pattern editor
    }
    
    private func duplicateProject() {
        // In real implementation, would use driveManager.duplicateProject
    }
    
    private func exportProject(format: ProjectFileFormat) {
        // In real implementation, would use driveManager.exportProject
        showingExportSheet = false
    }
    
    private func deleteProject() {
        // In real implementation, would use driveManager.deleteProject
    }
    
    private func restoreVersion(_ version: ProjectVersionViewModel) {
        // In real implementation, would use driveManager.restoreVersion
    }
    
    private func getProjectSize() -> Int64 {
        // In real implementation, would calculate actual size
        return 1024 * 1024 * 5 // 5MB dummy value
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Supporting Views

private struct PatternRow: View {
    let pattern: PatternViewModel
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pattern.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text("\(pattern.length) steps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

private struct VersionRow: View {
    let version: ProjectVersionViewModel
    let onRestore: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Version \(version.number)")
                    .font(.body)
                
                Text(version.date, style: .relative) + Text(" ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Restore", action: onRestore)
                .font(.caption)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - View Models

public struct ProjectVersionViewModel: Identifiable {
    public let id = UUID()
    public let number: Int
    public let date: Date
    
    public init(number: Int, date: Date) {
        self.number = number
        self.date = date
    }
}

public struct PatternViewModel: Identifiable {
    public let id: UUID
    public let name: String
    public let length: Int
    
    public init(id: UUID, name: String, length: Int) {
        self.id = id
        self.name = name
        self.length = length
    }
}

// MARK: - Extensions

extension ProjectDetailView {
    public init?(project: ProjectViewModel, driveManager: Any, presetPool: Any) {
        guard let driveManager = driveManager as? PlusDriveManager,
              let presetPool = presetPool as? PresetPool else {
            return nil
        }
        
        self.project = project
        self.driveManager = driveManager
        self.presetPool = presetPool
    }
}