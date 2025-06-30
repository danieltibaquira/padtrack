# Tests

This directory contains all test files for the DigitonePad application modules.

## Test Structure

Each module in the Sources directory has corresponding test files in this directory:

- `DataLayerTests/` - Tests for Core Data models and persistence
- `AudioEngineTests/` - Tests for audio processing components
- `SequencerModuleTests/` - Tests for sequencing functionality
- `VoiceModuleTests/` - Tests for voice synthesis
- `FilterModuleTests/` - Tests for audio filtering
- `FXModuleTests/` - Tests for audio effects
- `MIDIModuleTests/` - Tests for MIDI functionality
- `UIComponentsTests/` - Tests for UI components
- `MachineProtocolsTests/` - Tests for shared protocols
- `AppShellTests/` - Tests for the main application shell
- `DigitonePadTests/` - Integration tests for the main app

## Test Utilities

### TestUtilities.swift
Shared utilities for all test modules including:
- Mock data generators
- Test helpers and assertions
- Performance testing utilities
- Common test fixtures

### MockObjects/
Mock implementations for testing:
- MockAudioEngine
- MockDataLayer
- MockSequencer
- MockVoiceMachine

## Running Tests

Run tests using Swift Package Manager:
```bash
swift test
```

Or from Xcode using Cmd+U.

## Test Coverage

Run tests with coverage analysis:
```bash
swift test --enable-code-coverage
```

## Performance Testing

Performance tests are included in each module's test suite. Use XCTest's `measure` blocks for performance testing.

## Continuous Integration

Tests are automatically run in CI/CD pipeline on:
- Pull requests
- Main branch commits
- Release builds