# Quick Start Guide

Get up and running with the DataLayer package in minutes.

## Overview

This guide will help you quickly integrate the DataLayer package into your application and perform basic operations.

## Step 1: Initialize the Persistence Controller

The `PersistenceController` is the foundation of the DataLayer. It manages the Core Data stack and provides thread-safe access to your data.

```swift
import DataLayer

// Create a persistence controller
let persistenceController = PersistenceController()

// For testing, you can use an in-memory store
let testPersistenceController = PersistenceController(inMemory: true)
```

## Step 2: Create a DataLayerManager

The `DataLayerManager` provides high-level access to all repositories and manages the persistence layer.

```swift
// Create the data layer manager
let dataLayerManager = DataLayerManager(persistenceController: persistenceController)
```

## Step 3: Create Your First Project

Projects are the top-level containers for your musical data.

```swift
// Create a new project
let project = dataLayerManager.projectRepository.createProject(name: "My First Project")

// Save the project
try dataLayerManager.save()
```

## Step 4: Add Patterns to Your Project

Patterns contain the musical sequences and are associated with projects.

```swift
// Create a pattern
let pattern = dataLayerManager.patternRepository.createPattern(
    name: "Main Pattern",
    project: project,
    length: 16,
    tempo: 120.0
)

// Save the pattern
try dataLayerManager.save()
```

## Step 5: Add Tracks to Your Pattern

Tracks represent individual instrument channels within a pattern.

```swift
// Create tracks
let kickTrack = dataLayerManager.trackRepository.createTrack(
    name: "Kick",
    pattern: pattern,
    trackIndex: 0
)

let snareTrack = dataLayerManager.trackRepository.createTrack(
    name: "Snare",
    pattern: pattern,
    trackIndex: 1
)

// Save the tracks
try dataLayerManager.save()
```

## Step 6: Add Trigs to Your Tracks

Trigs are the individual note events that make up your patterns.

```swift
// Create trigs for the kick track
let kickTrig1 = dataLayerManager.trigRepository.createTrig(
    step: 0,
    note: 36, // C2 - typical kick drum note
    velocity: 127,
    track: kickTrack
)

let kickTrig2 = dataLayerManager.trigRepository.createTrig(
    step: 8,
    note: 36,
    velocity: 100,
    track: kickTrack
)

// Create trigs for the snare track
let snareTrig = dataLayerManager.trigRepository.createTrig(
    step: 4,
    note: 38, // D2 - typical snare drum note
    velocity: 110,
    track: snareTrack
)

// Save all trigs
try dataLayerManager.save()
```

## Step 7: Query Your Data

Retrieve and work with your saved data using the repository methods.

```swift
// Fetch all projects
let allProjects = try dataLayerManager.projectRepository.fetch()

// Find a specific project by name
let myProject = try dataLayerManager.projectRepository.findByName("My First Project")

// Fetch patterns for a project
let projectPatterns = try dataLayerManager.patternRepository.fetchPatterns(for: project)

// Fetch tracks for a pattern
let patternTracks = try dataLayerManager.trackRepository.fetchTracks(for: pattern)

// Fetch trigs for a track
let trackTrigs = try dataLayerManager.trigRepository.fetchTrigs(for: kickTrack)
```

## Step 8: Update Your Data

Modify existing entities and save the changes.

```swift
// Update a project name
project.name = "Updated Project Name"

// Update pattern tempo
pattern.tempo = 140.0

// Update trig velocity
kickTrig1.velocity = 120

// Save all changes
try dataLayerManager.save()
```

## Step 9: Delete Data

Remove entities when they're no longer needed.

```swift
// Delete a specific trig
try dataLayerManager.trigRepository.delete(snareTrig)

// Delete all trigs for a track
try dataLayerManager.trigRepository.deleteTrigs(for: snareTrack)

// Delete a track (this will also delete associated trigs)
try dataLayerManager.trackRepository.delete(snareTrack)

// Save the deletions
try dataLayerManager.save()
```

## Error Handling

Always wrap DataLayer operations in do-catch blocks to handle potential errors.

```swift
do {
    let project = dataLayerManager.projectRepository.createProject(name: "Test Project")
    try dataLayerManager.save()
    print("Project created successfully")
} catch let error as DataLayerError {
    print("DataLayer error: \(error.localizedDescription)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Performance Tips

### Use Caching for Frequently Accessed Data

```swift
// Preload frequently accessed projects
try dataLayerManager.projectRepository.preloadCache(limit: 20)

// Use cache-aware fetching
let projects = try dataLayerManager.projectRepository.fetchWithCacheControl(
    useCache: true,
    cacheResults: true
)
```

### Optimize Fetch Requests

```swift
// Use pagination for large datasets
let firstPage = try dataLayerManager.projectRepository.fetchPaginated(
    page: 0,
    pageSize: 10
)

// Prefetch relationships to avoid N+1 queries
let projectsWithPatterns = try dataLayerManager.projectRepository.fetchWithPrefetching(
    relationshipKeyPaths: ["patterns", "presets"]
)
```

### Background Operations

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

## Next Steps

- Read the <doc:BasicUsage> guide for more detailed examples
- Explore the <doc:AdvancedFeatures> documentation
- Check out the API reference for specific classes and methods
- Review the test files for additional usage examples

## Common Patterns

### Creating a Complete Musical Setup

```swift
// Create a complete project with patterns, tracks, and trigs
let project = dataLayerManager.projectRepository.createProject(name: "Song Demo")
let pattern = dataLayerManager.patternRepository.createPattern(name: "Verse", project: project)

// Create drum tracks
let tracks = [
    ("Kick", 0),
    ("Snare", 1),
    ("Hi-Hat", 2),
    ("Open Hat", 3)
].map { name, index in
    dataLayerManager.trackRepository.createTrack(name: name, pattern: pattern, trackIndex: Int16(index))
}

// Add basic drum pattern
let kickSteps = [0, 4, 8, 12]
let snareSteps = [4, 12]
let hihatSteps = [2, 6, 10, 14]

for step in kickSteps {
    dataLayerManager.trigRepository.createTrig(step: Int16(step), note: 36, velocity: 127, track: tracks[0])
}

for step in snareSteps {
    dataLayerManager.trigRepository.createTrig(step: Int16(step), note: 38, velocity: 110, track: tracks[1])
}

for step in hihatSteps {
    dataLayerManager.trigRepository.createTrig(step: Int16(step), note: 42, velocity: 80, track: tracks[2])
}

try dataLayerManager.save()
```

This creates a basic 4/4 drum pattern with kick, snare, and hi-hat elements.
