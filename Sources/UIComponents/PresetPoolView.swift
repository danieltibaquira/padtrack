import SwiftUI
import DataLayer
import DataModel

/// View for browsing and managing the preset pool
public struct PresetPoolView: View {
    
    // MARK: - Properties
    
    let presetPool: PresetPool
    
    @State var searchQuery = ""
    @State var selectedCategory = "All Categories"
    @State var selectedPreset: PresetViewModel?
    @State private var sortOption: PresetSortOption = .name
    @State private var selectedTags: Set<String> = []
    @State private var showingImportPicker = false
    @State private var showingExportSheet = false
    @State private var isLoading = false
    @State private var presets: [PresetViewModel] = []
    @State private var filteredPresets: [PresetViewModel] = []
    
    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 16)
    ]
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndFilterBar
                
                Divider()
                
                // Main Content
                if filteredPresets.isEmpty && !searchQuery.isEmpty {
                    emptySearchResults
                } else if presets.isEmpty {
                    emptyState
                } else {
                    presetGrid
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Preset Pool")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingExportSheet) {
                exportSheet
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .onAppear {
                loadPresets()
            }
            .onChange(of: searchQuery) { _ in
                filterPresets()
            }
            .onChange(of: selectedCategory) { _ in
                filterPresets()
            }
            .onChange(of: selectedTags) { _ in
                filterPresets()
            }
            .onChange(of: sortOption) { _ in
                sortPresets()
            }
        }
    }
    
    // MARK: - Search and Filter Bar
    
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search presets...", text: $searchQuery)
                    .textFieldStyle(.plain)
                
                if !searchQuery.isEmpty {
                    Button("Clear") {
                        searchQuery = ""
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            
            // Category filter and sort
            HStack {
                Picker("Category", selection: $selectedCategory) {
                    Text("All Categories").tag("All Categories")
                    Divider()
                    ForEach(presetPool.allCategories(), id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.menu)
                
                Spacer()
                
                Menu {
                    Button(action: { sortOption = .name }) {
                        Label("Name", systemImage: sortOption == .name ? "checkmark" : "")
                    }
                    Button(action: { sortOption = .category }) {
                        Label("Category", systemImage: sortOption == .category ? "checkmark" : "")
                    }
                    Button(action: { sortOption = .dateNewest }) {
                        Label("Newest", systemImage: sortOption == .dateNewest ? "checkmark" : "")
                    }
                    Button(action: { sortOption = .mostUsed }) {
                        Label("Most Used", systemImage: sortOption == .mostUsed ? "checkmark" : "")
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                        .foregroundColor(.accentColor)
                }
            }
            
            // Selected tags
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Array(selectedTags), id: \.self) { tag in
                            TagChip(tag: tag, isSelected: true) {
                                selectedTags.remove(tag)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    // MARK: - Content Views
    
    private var presetGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredPresets) { preset in
                    PresetCard(
                        preset: preset,
                        usageCount: getUsageCount(for: preset),
                        isSelected: selectedPreset?.id == preset.id,
                        onSelect: {
                            selectPreset(preset)
                        },
                        onTagTap: { tag in
                            toggleTag(tag)
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Presets")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("Import presets or create them in the synthesizer")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showingImportPicker = true }) {
                Label("Import Presets", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptySearchResults: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Results")
                .font(.title3)
                .foregroundColor(.gray)
            
            Text("Try adjusting your search or filters")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button(action: { showingImportPicker = true }) {
                    Label("Import Presets", systemImage: "square.and.arrow.down")
                }
                
                Button(action: { showingExportSheet = true }) {
                    Label(
                        selectedCategory == "All Categories" ? "Export All" : "Export Category",
                        systemImage: "square.and.arrow.up"
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        
        if selectedPreset != nil {
            ToolbarItem(placement: .bottomBar) {
                Button(action: loadSelectedPreset) {
                    Label("Load Preset", systemImage: "arrow.down.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    // MARK: - Sheets
    
    private var exportSheet: some View {
        VStack(spacing: 20) {
            Text("Export Presets")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(selectedCategory == "All Categories" 
                ? "Export all \(presets.count) presets"
                : "Export \(filteredPresets.count) presets from \(selectedCategory)")
                .foregroundColor(.secondary)
            
            Button(action: performExport) {
                Label("Export", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            Button("Cancel") {
                showingExportSheet = false
            }
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func loadPresets() {
        isLoading = true
        
        // Convert Core Data presets to view models
        let allPresets = presetPool.allPresets(sortedBy: sortOption)
        presets = allPresets.map { preset in
            PresetViewModel(
                id: UUID(), // Generate stable ID
                name: preset.name ?? "Untitled",
                category: preset.category ?? "Uncategorized",
                tags: preset.tags ?? []
            )
        }
        
        filteredPresets = presets
        isLoading = false
    }
    
    private func filterPresets() {
        var results = presets
        
        // Filter by search query
        if !searchQuery.isEmpty {
            results = results.filter { preset in
                preset.name.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        // Filter by category
        if selectedCategory != "All Categories" {
            results = results.filter { $0.category == selectedCategory }
        }
        
        // Filter by tags
        if !selectedTags.isEmpty {
            results = results.filter { preset in
                selectedTags.isSubset(of: Set(preset.tags))
            }
        }
        
        filteredPresets = results
    }
    
    private func sortPresets() {
        loadPresets() // Reload with new sort option
    }
    
    private func selectPreset(_ preset: PresetViewModel) {
        if selectedPreset?.id == preset.id {
            selectedPreset = nil
        } else {
            selectedPreset = preset
            presetPool.trackUsage(of: getCoreDataPreset(for: preset))
        }
    }
    
    private func loadSelectedPreset() {
        guard let preset = selectedPreset else { return }
        // In real implementation, would load preset into synthesizer
        selectedPreset = nil
    }
    
    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    private func performExport() {
        do {
            let category = selectedCategory == "All Categories" ? nil : selectedCategory
            let exportData = try presetPool.exportPresets(category: category)
            
            // In real implementation, would save to file
            showingExportSheet = false
        } catch {
            // Handle error
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let data = try Data(contentsOf: url)
                let count = try presetPool.importPresets(from: data)
                // Show success message
                loadPresets()
            } catch {
                // Handle error
            }
            
        case .failure(let error):
            // Handle error
            break
        }
    }
    
    private func getUsageCount(for preset: PresetViewModel) -> Int {
        // In real implementation, would get from preset pool
        return 0
    }
    
    private func getCoreDataPreset(for viewModel: PresetViewModel) -> Preset {
        // In real implementation, would map view model to Core Data preset
        // This is a placeholder
        return Preset()
    }
}

// MARK: - Supporting Views

private struct PresetCard: View {
    let preset: PresetViewModel
    let usageCount: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onTagTap: (String) -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text(preset.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }
                
                // Category
                Text(preset.category)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Tags
                if !preset.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(preset.tags, id: \.self) { tag in
                                TagChip(tag: tag, isSelected: false) {
                                    onTagTap(tag)
                                }
                            }
                        }
                    }
                }
                
                // Usage stats
                if usageCount > 0 {
                    Text("Used \(usageCount) times")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TagChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemBackground))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Models

public struct PresetViewModel: Identifiable {
    public let id: UUID
    public let name: String
    public let category: String
    public let tags: [String]
    
    public init(id: UUID, name: String, category: String, tags: [String]) {
        self.id = id
        self.name = name
        self.category = category
        self.tags = tags
    }
}

// MARK: - Extensions

extension PresetPoolView {
    public init(presetPool: Any) {
        self.presetPool = presetPool as! PresetPool
    }
}