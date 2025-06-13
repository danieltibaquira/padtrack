# Usage Guide

Comprehensive guide for using the DataLayer package effectively.

## Overview

This guide covers advanced usage patterns, best practices, and common scenarios when working with the DataLayer package.

## Table of Contents

1. [Basic Operations](#basic-operations)
2. [Advanced Querying](#advanced-querying)
3. [Performance Optimization](#performance-optimization)
4. [Caching Strategies](#caching-strategies)
5. [Background Operations](#background-operations)
6. [Error Handling](#error-handling)
7. [Testing](#testing)
8. [Migration](#migration)

## Basic Operations

### Creating Entities

```swift
// Initialize the data layer
let persistenceController = PersistenceController()
let dataLayerManager = DataLayerManager(persistenceController: persistenceController)

// Create a project
let project = dataLayerManager.projectRepository.createProject(name: "My Song")

// Create a pattern
let pattern = dataLayerManager.patternRepository.createPattern(
    name: "Verse",
    project: project,
    length: 16,
    tempo: 120.0
)

// Create tracks
let kickTrack = dataLayerManager.trackRepository.createTrack(
    name: "Kick",
    pattern: pattern,
    trackIndex: 0
)

// Save all changes
try dataLayerManager.save()
```

### Reading Entities

```swift
// Fetch all projects
let allProjects = try dataLayerManager.projectRepository.fetch()

// Find projects by name
let searchResults = try dataLayerManager.projectRepository.fetch(
    predicate: NSPredicate(format: "name CONTAINS[cd] %@", "Demo")
)

// Fetch with sorting
let sortedProjects = try dataLayerManager.projectRepository.fetch(
    sortDescriptors: [NSSortDescriptor(key: "updatedAt", ascending: false)]
)
```

### Updating Entities

```swift
// Update project properties
project.name = "Updated Project Name"
project.updatedAt = Date()

// Update pattern tempo
pattern.tempo = 140.0

// Save changes
try dataLayerManager.save()
```

### Deleting Entities

```swift
// Delete a specific entity
try dataLayerManager.projectRepository.delete(project)

// Delete with predicate
try dataLayerManager.projectRepository.deleteAll(
    predicate: NSPredicate(format: "name BEGINSWITH %@", "Test")
)

// Save deletions
try dataLayerManager.save()
```

## Advanced Querying

### Complex Predicates

```swift
// Multiple conditions
let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
    NSPredicate(format: "tempo >= %f", 120.0),
    NSPredicate(format: "length <= %d", 32),
    NSPredicate(format: "project.name CONTAINS[cd] %@", "Song")
])

let patterns = try dataLayerManager.patternRepository.fetch(predicate: predicate)
```

### Relationship Queries

```swift
// Fetch patterns for a specific project
let projectPatterns = try dataLayerManager.patternRepository.fetchPatterns(for: project)

// Fetch tracks for a pattern
let patternTracks = try dataLayerManager.trackRepository.fetchTracks(for: pattern)

// Fetch active trigs for a track
let activeTrigs = try dataLayerManager.trigRepository.fetchActiveTrigs(for: track)
```

### Pagination

```swift
// Fetch first page (10 items)
let firstPage = try dataLayerManager.projectRepository.fetchPaginated(
    page: 0,
    pageSize: 10
)

// Fetch second page
let secondPage = try dataLayerManager.projectRepository.fetchPaginated(
    page: 1,
    pageSize: 10
)
```

### Counting

```swift
// Count all projects
let totalProjects = try dataLayerManager.projectRepository.count()

// Count with predicate
let recentProjects = try dataLayerManager.projectRepository.count(
    predicate: NSPredicate(format: "updatedAt >= %@", lastWeek)
)
```

## Performance Optimization

### Fetch Optimization

```swift
// Use batch fetching for large datasets
let optimizedRequest = NSFetchRequest<Project>(entityName: "Project")
optimizedRequest.fetchBatchSize = 20

let projects = try FetchOptimizationService.shared.optimizedFetch(
    optimizedRequest,
    in: dataLayerManager.persistenceController.container.viewContext
)
```

### Relationship Prefetching

```swift
// Prefetch relationships to avoid N+1 queries
let projectsWithPatterns = try dataLayerManager.projectRepository.fetchWithPrefetching(
    relationshipKeyPaths: ["patterns", "presets"]
)

// Now accessing patterns won't trigger additional queries
for project in projectsWithPatterns {
    print("Project: \(project.name), Patterns: \(project.patterns?.count ?? 0)")
}
```

### Memory Management

```swift
// Use object IDs for large datasets
let objectIDs = try FetchOptimizationService.shared.fetchObjectIDs(
    entityName: "Project",
    in: context
)

// Convert back to objects when needed
let objects = try FetchOptimizationService.shared.objectsFromIDs(objectIDs, in: context)
```

## Caching Strategies

### Automatic Caching

```swift
// Caching is automatic with standard fetch operations
let projects = try dataLayerManager.projectRepository.fetch() // Cached automatically
```

### Manual Cache Control

```swift
// Disable caching for specific operations
let freshData = try dataLayerManager.projectRepository.fetchWithCacheControl(
    useCache: false,
    cacheResults: false
)

// Preload cache for frequently accessed data
try dataLayerManager.projectRepository.preloadCache(limit: 50)
```

### Cache Management

```swift
// Clear cache when needed
dataLayerManager.projectRepository.clearCache()

// Handle memory pressure
CacheService.shared.handleMemoryPressure()

// Restore normal cache limits
CacheService.shared.restoreNormalCacheLimits()
```

## Background Operations

### Heavy Data Processing

```swift
// Perform heavy operations in background
dataLayerManager.persistenceController.performBackgroundTask { context in
    let backgroundProjectRepo = ProjectRepository(context: context)
    
    // Create many projects
    for i in 1...1000 {
        let project = backgroundProjectRepo.createProject(name: "Project \(i)")
    }
    
    try context.save()
}
```

### Background Fetching

```swift
// Fetch data in background
let request = NSFetchRequest<Project>(entityName: "Project")

FetchOptimizationService.shared.backgroundFetch(
    request,
    persistenceController: dataLayerManager.persistenceController
) { result in
    switch result {
    case .success(let projects):
        DispatchQueue.main.async {
            // Update UI with projects
        }
    case .failure(let error):
        print("Background fetch failed: \(error)")
    }
}
```

## Error Handling

### Comprehensive Error Handling

```swift
do {
    let project = dataLayerManager.projectRepository.createProject(name: "Test")
    try dataLayerManager.save()
} catch let error as DataLayerError {
    switch error {
    case .saveError(let underlyingError):
        print("Save failed: \(underlyingError)")
    case .fetchError(let underlyingError):
        print("Fetch failed: \(underlyingError)")
    case .validationError(let message):
        print("Validation failed: \(message)")
    default:
        print("DataLayer error: \(error.localizedDescription)")
    }
} catch let error as ValidationError {
    switch error {
    case .invalidName(let message):
        print("Invalid name: \(message)")
    case .invalidValue(let message):
        print("Invalid value: \(message)")
    case .relationshipConstraint(let message):
        print("Relationship constraint: \(message)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

### Validation

```swift
// Manual validation
do {
    try ValidationService.shared.validateProject(project)
    try dataLayerManager.save()
} catch let validationError as ValidationError {
    // Handle validation error
    print("Validation failed: \(validationError.localizedDescription)")
}
```

## Testing

### Test Setup

```swift
class DataLayerTests: XCTestCase {
    var testPersistenceController: PersistenceController!
    var testDataLayerManager: DataLayerManager!
    
    override func setUpWithError() throws {
        testPersistenceController = PersistenceController(inMemory: true)
        testDataLayerManager = DataLayerManager(persistenceController: testPersistenceController)
    }
    
    override func tearDownWithError() throws {
        testPersistenceController = nil
        testDataLayerManager = nil
    }
}
```

### Test Data Creation

```swift
func createTestProject() -> Project {
    return testDataLayerManager.projectRepository.createProject(name: "Test Project")
}

func createTestPattern(project: Project) -> Pattern {
    return testDataLayerManager.patternRepository.createPattern(
        name: "Test Pattern",
        project: project
    )
}
```

### Performance Testing

```swift
func testFetchPerformance() throws {
    // Create test data
    for i in 1...1000 {
        testDataLayerManager.projectRepository.createProject(name: "Project \(i)")
    }
    try testDataLayerManager.save()
    
    // Measure fetch performance
    let request = NSFetchRequest<Project>(entityName: "Project")
    let (results, executionTime) = try FetchOptimizationService.shared.measureFetchPerformance(
        request,
        in: testDataLayerManager.persistenceController.container.viewContext,
        label: "Project Fetch"
    )
    
    XCTAssertEqual(results.count, 1000)
    XCTAssertLessThan(executionTime, 1.0) // Should complete within 1 second
}
```

## Migration

### Handling Migrations

```swift
// Migration is handled automatically by PersistenceController
let persistenceController = PersistenceController()

// Check if migration was successful
let isValid = persistenceController.validateDataIntegrity()
if !isValid {
    print("Data validation failed after migration")
}
```

### Creating Backups

```swift
// Create a backup before major operations
do {
    let backupURL = try persistenceController.createBackup()
    print("Backup created at: \(backupURL)")
} catch {
    print("Backup failed: \(error)")
}
```

## Best Practices

### 1. Context Management
- Use the main context for UI operations
- Use background contexts for heavy data processing
- Always save contexts on the appropriate queue

### 2. Memory Management
- Use pagination for large datasets
- Leverage caching for frequently accessed data
- Clear caches when memory pressure is detected

### 3. Error Handling
- Always handle potential errors
- Provide meaningful error messages to users
- Log errors for debugging purposes

### 4. Performance
- Use fetch optimization for large queries
- Prefetch relationships when needed
- Monitor and measure performance regularly

### 5. Testing
- Use in-memory stores for testing
- Create comprehensive test coverage
- Test error conditions and edge cases
