import XCTest
import SwiftUI
import ViewInspector
@testable import UIComponents
@testable import DataLayer
@testable import DataModel

class PresetPoolViewTests: XCTestCase {
    
    var mockPresetPool: MockPresetPoolForView!
    var mockPresets: [PresetViewModel]!
    
    override func setUp() {
        super.setUp()
        
        mockPresetPool = MockPresetPoolForView()
        
        // Create test presets
        mockPresets = [
            PresetViewModel(id: UUID(), name: "808 Bass", category: "Bass", tags: ["808", "sub", "deep"]),
            PresetViewModel(id: UUID(), name: "Juno Lead", category: "Lead", tags: ["juno", "bright", "classic"]),
            PresetViewModel(id: UUID(), name: "Ambient Pad", category: "Pad", tags: ["ambient", "warm", "lush"]),
            PresetViewModel(id: UUID(), name: "FM Bell", category: "Lead", tags: ["fm", "bell", "metallic"]),
            PresetViewModel(id: UUID(), name: "Kick Drum", category: "Drum", tags: ["kick", "punch", "909"])
        ]
        
        mockPresetPool.mockPresets = mockPresets
    }
    
    override func tearDown() {
        mockPresetPool = nil
        mockPresets = nil
        super.tearDown()
    }
    
    // MARK: - View Structure Tests
    
    func testPresetPoolViewStructure() throws {
        let view = PresetPoolView(presetPool: mockPresetPool)
        let inspected = try view.inspect()
        
        // Verify main structure
        XCTAssertNoThrow(try inspected.find(ViewType.NavigationView.self))
        XCTAssertNoThrow(try inspected.find(text: "Preset Pool"))
        
        // Verify search bar
        XCTAssertNoThrow(try inspected.find(ViewType.TextField.self))
        
        // Verify category filter
        XCTAssertNoThrow(try inspected.find(ViewType.Picker.self))
        
        // Verify preset grid
        XCTAssertNoThrow(try inspected.find(ViewType.ScrollView.self))
    }
    
    func testPresetDisplay() throws {
        let view = PresetPoolView(presetPool: mockPresetPool)
        let inspected = try view.inspect()
        
        // Verify all presets are displayed
        for preset in mockPresets {
            XCTAssertNoThrow(try inspected.find(text: preset.name))
            XCTAssertNoThrow(try inspected.find(text: preset.category))
        }
    }
    
    // MARK: - Search Tests
    
    func testSearchFunctionality() throws {
        let view = PresetPoolView(presetPool: mockPresetPool)
        let inspected = try view.inspect()
        
        // Find search field
        let searchField = try inspected.find(ViewType.TextField.self)
        
        // Enter search query
        try searchField.setInput("bass")
        
        // Verify search was triggered
        XCTAssertTrue(mockPresetPool.searchCalled)
        XCTAssertEqual(mockPresetPool.searchQuery, "bass")
    }
    
    func testSearchResultsDisplay() throws {
        // Set up search results
        mockPresetPool.searchResults = [mockPresets[0]] // Only 808 Bass
        
        let view = PresetPoolView(presetPool: mockPresetPool)
        view.searchQuery = "bass"
        
        let inspected = try view.inspect()
        
        // Should show only search results
        XCTAssertNoThrow(try inspected.find(text: "808 Bass"))
        
        // Other presets should not be visible
        XCTAssertThrowsError(try inspected.find(text: "Juno Lead"))
        XCTAssertThrowsError(try inspected.find(text: "Ambient Pad"))
    }
    
    func testClearSearchButton() throws {
        let view = PresetPoolView(presetPool: mockPresetPool)
        view.searchQuery = "test"
        
        let inspected = try view.inspect()
        
        // Find clear button
        let clearButton = try inspected.find(button: "Clear")
        try clearButton.tap()
        
        // Verify search was cleared
        XCTAssertEqual(view.searchQuery, "")
    }
    
    // MARK: - Category Filter Tests
    
    func testCategoryFilterDisplay() throws {
        let view = PresetPoolView(presetPool: mockPresetPool)
        let inspected = try view.inspect()
        
        // Find category picker
        let categoryPicker = try inspected.find(ViewType.Picker.self)
        
        // Verify "All" option exists
        XCTAssertNoThrow(try categoryPicker.find(text: "All Categories"))
        
        // Verify all categories are listed
        let categories = ["Bass", "Lead", "Pad", "Drum", "FX"]
        for category in categories {
            XCTAssertNoThrow(try categoryPicker.find(text: category))
        }
    }
    
    func testCategoryFiltering() throws {
        let view = PresetPoolView(presetPool: mockPresetPool)
        view.selectedCategory = "Bass"
        
        mockPresetPool.filteredPresets = [mockPresets[0]] // Only bass preset
        
        let inspected = try view.inspect()
        
        // Should show only bass presets
        XCTAssertNoThrow(try inspected.find(text: "808 Bass"))
        
        // Other categories should not be visible
        XCTAssertThrowsError(try inspected.find(text: "Juno Lead"))
        XCTAssertThrowsError(try inspected.find(text: "Kick Drum"))
    }
    
    // MARK: - Preset Selection Tests
    
    func testPresetSelection() throws {
        let view = PresetPoolView(presetPool: mockPresetPool)
        let inspected = try view.inspect()
        
        // Find and tap a preset
        let presetCard = try inspected.find(text: "808 Bass").parent().parent()
        try presetCard.callOnTapGesture()
        
        // Verify selection
        XCTAssertTrue(mockPresetPool.selectPresetCalled)
        XCTAssertEqual(mockPresetPool.selectedPresetId, mockPresets[0].id)
    }
    
    func testPresetLoadButton() throws {
        let view = PresetPoolView(presetPool: mockPresetPool)
        view.selectedPreset = mockPresets[0]
        
        let inspected = try view.inspect()
        
        // Find load button
        let loadButton = try inspected.find(button: "Load Preset")
        try loadButton.tap()
        
        // Verify load was called
        XCTAssertTrue(mockPresetPool.loadPresetCalled)
        XCTAssertEqual(mockPresetPool.loadedPresetId, mockPresets[0].id)
    }
    
    // MARK: - Tag Display Tests
    
    func testTagDisplay() throws {
        let view = PresetPoolView(presetPool: mockPresetPool)
        let inspected = try view.inspect()
        
        // Find preset with tags
        let bassPreset = try inspected.find(text: "808 Bass").parent().parent()
        
        // Verify tags are displayed
        XCTAssertNoThrow(try bassPreset.find(text: "808"))
        XCTAssertNoThrow(try bassPreset.find(text: "sub"))
        XCTAssertNoThrow(try bassPreset.find(text: "deep"))
    }
    
    func testTagFiltering() throws {
        let view = PresetPoolView(presetPool: mockPresetPool)
        let inspected = try view.inspect()
        
        // Tap a tag
        let tag808 = try inspected.find(text: "808")
        try tag808.callOnTapGesture()
        
        // Verify tag filter was applied
        XCTAssertTrue(mockPresetPool.filterByTagCalled)
        XCTAssertEqual(mockPresetPool.filterTag, "808")
    }
    
    // MARK: - Sorting Tests
    
    func testSortOptions() throws {
        let view = PresetPoolView(presetPool: mockPresetPool)
        let inspected = try view.inspect()
        
        // Find sort menu
        let sortMenu = try inspected.find(ViewType.Menu.self)
        
        // Verify sort options
        XCTAssertNoThrow(try sortMenu.find(text: "Name"))
        XCTAssertNoThrow(try sortMenu.find(text: "Category"))
        XCTAssertNoThrow(try sortMenu.find(text: "Newest"))
        XCTAssertNoThrow(try sortMenu.find(text: "Most Used"))
    }
    
    func testSortByName() throws {
        let view = PresetPoolView(presetPool: mockPresetPool)
        let inspected = try view.inspect()
        
        // Select sort by name
        let sortMenu = try inspected.find(ViewType.Menu.self)
        let nameOption = try sortMenu.find(button: "Name")
        try nameOption.tap()
        
        // Verify sort was applied
        XCTAssertTrue(mockPresetPool.sortCalled)
        XCTAssertEqual(mockPresetPool.sortOption, .name)
    }
    
    // MARK: - Usage Statistics Tests
    
    func testUsageStatisticsDisplay() throws {
        // Set up usage stats
        mockPresetPool.mockUsageStats = [
            mockPresets[0].id: 25,
            mockPresets[1].id: 10
        ]
        
        let view = PresetPoolView(presetPool: mockPresetPool)
        let inspected = try view.inspect()
        
        // Find preset cards
        let bassCard = try inspected.find(text: "808 Bass").parent().parent()
        
        // Verify usage count is displayed
        XCTAssertNoThrow(try bassCard.find(text: "Used 25 times"))
    }
    
    // MARK: - Import/Export Tests
    
    func testExportPresetsButton() throws {
        let view = PresetPoolView(presetPool: mockPresetPool)
        view.selectedCategory = "Bass"
        
        let inspected = try view.inspect()
        
        // Find export button
        let exportButton = try inspected.find(button: "Export Category")
        try exportButton.tap()
        
        // Verify export was called
        XCTAssertTrue(mockPresetPool.exportCalled)
        XCTAssertEqual(mockPresetPool.exportCategory, "Bass")
    }
    
    func testImportPresetsButton() throws {
        let view = PresetPoolView(presetPool: mockPresetPool)
        let inspected = try view.inspect()
        
        // Find import button
        let importButton = try inspected.find(button: "Import Presets")
        try importButton.tap()
        
        // Should show file picker (in real implementation)
        XCTAssertTrue(mockPresetPool.showImportPickerCalled)
    }
    
    // MARK: - Performance Tests
    
    func testLargePresetPoolPerformance() throws {
        // Create many presets
        mockPresetPool.mockPresets = (0..<1000).map { i in
            PresetViewModel(
                id: UUID(),
                name: "Preset \(i)",
                category: ["Bass", "Lead", "Pad", "FX", "Drum"][i % 5],
                tags: ["tag1", "tag2", "tag3"]
            )
        }
        
        measure {
            let view = PresetPoolView(presetPool: mockPresetPool)
            _ = try? view.inspect()
        }
    }
}

// MARK: - Mock Classes

class MockPresetPoolForView {
    var mockPresets: [PresetViewModel] = []
    var searchResults: [PresetViewModel] = []
    var filteredPresets: [PresetViewModel] = []
    var mockUsageStats: [UUID: Int] = [:]
    
    var searchCalled = false
    var searchQuery: String?
    
    var selectPresetCalled = false
    var selectedPresetId: UUID?
    
    var loadPresetCalled = false
    var loadedPresetId: UUID?
    
    var filterByTagCalled = false
    var filterTag: String?
    
    var sortCalled = false
    var sortOption: PresetSortOption?
    
    var exportCalled = false
    var exportCategory: String?
    
    var showImportPickerCalled = false
    
    func allPresets() -> [PresetViewModel] {
        return mockPresets
    }
    
    func search(query: String) -> [PresetViewModel] {
        searchCalled = true
        searchQuery = query
        return searchResults.isEmpty ? mockPresets.filter { $0.name.lowercased().contains(query.lowercased()) } : searchResults
    }
    
    func presets(in category: String) -> [PresetViewModel] {
        return filteredPresets.isEmpty ? mockPresets.filter { $0.category == category } : filteredPresets
    }
    
    func selectPreset(_ id: UUID) {
        selectPresetCalled = true
        selectedPresetId = id
    }
    
    func loadPreset(_ id: UUID) {
        loadPresetCalled = true
        loadedPresetId = id
    }
    
    func filterByTag(_ tag: String) {
        filterByTagCalled = true
        filterTag = tag
    }
    
    func sort(by option: PresetSortOption) {
        sortCalled = true
        sortOption = option
    }
    
    func exportPresets(category: String?) {
        exportCalled = true
        exportCategory = category
    }
    
    func showImportPicker() {
        showImportPickerCalled = true
    }
    
    func getUsageCount(for presetId: UUID) -> Int {
        return mockUsageStats[presetId] ?? 0
    }
    
    func allCategories() -> [String] {
        return ["Bass", "Lead", "Pad", "Drum", "FX"]
    }
}

// MARK: - Supporting Types

struct PresetViewModel: Identifiable {
    let id: UUID
    let name: String
    let category: String
    let tags: [String]
    var isSelected: Bool = false
}