# DataLayer

A comprehensive Core Data persistence layer for the Digitone Pad application.

## Overview

The DataLayer package provides a robust, thread-safe, and optimized Core Data persistence layer for managing musical projects, patterns, tracks, and related entities. It includes advanced features like caching, validation, migration support, and performance optimization.

## Topics

### Getting Started

- <doc:QuickStart>
- <doc:Installation>
- <doc:BasicUsage>

### Core Components

- ``PersistenceController``
- ``DataLayerManager``
- ``BaseRepository``

### Entity Management

- ``ProjectRepository``
- ``PatternRepository``
- ``TrackRepository``
- ``TrigRepository``
- ``KitRepository``
- ``PresetRepository``

### Advanced Features

- ``CacheService``
- ``FetchOptimizationService``
- ``ValidationService``

### Error Handling

- ``DataLayerError``
- ``ValidationError``

### Data Models

- ``Project``
- ``Pattern``
- ``Track``
- ``Trig``
- ``Kit``
- ``Preset``

## Architecture

The DataLayer follows a repository pattern with the following key components:

### PersistenceController
The central component that manages the Core Data stack, including:
- NSPersistentContainer setup
- Background context management
- Save operations with error handling
- Migration support

### Repository Pattern
Each entity type has a dedicated repository that provides:
- CRUD operations
- Type-safe queries
- Relationship management
- Validation

### Caching Layer
Intelligent caching system that:
- Caches frequently accessed objects
- Optimizes query performance
- Manages memory pressure
- Provides cache invalidation

### Validation System
Comprehensive validation that ensures:
- Data integrity
- Business rule compliance
- Relationship constraints
- Type safety

## Performance Features

### Fetch Optimization
- Batch fetching for large datasets
- Relationship prefetching
- Pagination support
- Memory-efficient queries

### Caching
- Object-level caching
- Query result caching
- Smart cache invalidation
- Memory pressure handling

### Thread Safety
- Background context operations
- Main queue coordination
- Concurrent access protection
- Deadlock prevention

## Error Handling

The DataLayer provides comprehensive error handling through:

### DataLayerError
Covers all persistence-related errors:
- Save failures
- Fetch failures
- Delete failures
- Migration errors
- Configuration errors

### ValidationError
Handles data validation issues:
- Invalid names
- Invalid values
- Relationship constraints
- Business rule violations

## Migration Support

Built-in migration capabilities:
- Automatic lightweight migrations
- Custom migration support
- Version tracking
- Rollback capabilities
- Data integrity verification

## Thread Safety

The DataLayer ensures thread safety through:
- Proper context management
- Background queue operations
- Main queue coordination
- Concurrent access protection

## Best Practices

### Context Usage
- Use background contexts for heavy operations
- Perform UI updates on main context
- Save contexts appropriately
- Handle context merging

### Performance
- Use fetch optimization for large datasets
- Leverage caching for frequently accessed data
- Implement pagination for large result sets
- Monitor memory usage

### Error Handling
- Always handle potential errors
- Provide meaningful error messages
- Implement retry logic where appropriate
- Log errors for debugging

### Validation
- Validate data before saving
- Use built-in validation rules
- Implement custom validation as needed
- Handle validation errors gracefully

## Examples

### Basic Usage

```swift
// Initialize the persistence controller
let persistenceController = PersistenceController()

// Create a data layer manager
let dataLayerManager = DataLayerManager(persistenceController: persistenceController)

// Create a new project
let project = dataLayerManager.projectRepository.createProject(name: "My Project")

// Save the project
try dataLayerManager.save()
```

### Advanced Querying

```swift
// Fetch projects with optimization
let projects = try dataLayerManager.projectRepository.fetchWithPrefetching(
    predicate: NSPredicate(format: "name CONTAINS[cd] %@", "Demo"),
    sortDescriptors: [NSSortDescriptor(key: "updatedAt", ascending: false)],
    relationshipKeyPaths: ["patterns", "presets"]
)
```

### Caching

```swift
// Preload frequently accessed data
try dataLayerManager.projectRepository.preloadCache(limit: 50)

// Use cache-aware fetching
let projects = try dataLayerManager.projectRepository.fetchWithCacheControl(
    useCache: true,
    cacheResults: true
)
```

### Background Operations

```swift
// Perform heavy operations in background
dataLayerManager.persistenceController.performBackgroundTask { context in
    // Heavy data processing
    let backgroundRepository = ProjectRepository(context: context)
    // ... perform operations
    
    try context.save()
}
```

## Testing

The DataLayer includes comprehensive test coverage:

### Unit Tests
- CRUD operation tests
- Validation tests
- Cache service tests
- Migration tests
- Optimization tests

### Integration Tests
- Repository integration tests
- Relationship tests
- Performance tests
- Error handling tests

### Test Utilities
- In-memory Core Data stack
- Test data factories
- Mock objects
- Performance measurement tools

## Requirements

- iOS 14.0+ / macOS 11.0+
- Swift 5.5+
- Core Data framework

## Installation

Add the DataLayer package to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "path/to/DataLayer", from: "1.0.0")
]
```

## License

This package is part of the Digitone Pad application and follows the project's licensing terms.
