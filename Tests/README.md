# Tests

This directory contains all test files for the DigitonePad application modules.

## Test Structure

Each module in the Sources directory has corresponding test files in this directory:

- Unit tests for individual components
- Integration tests for module interactions
- Performance tests for audio processing components
- UI tests for user interface components

## Test Organization

Tests are organized to mirror the source structure:
- `UnitTests/`: Unit tests for each module
- `IntegrationTests/`: Cross-module integration tests
- `PerformanceTests/`: Audio performance and latency tests
- `UITests/`: User interface automation tests

## Running Tests

Run tests using Swift Package Manager:
```bash
swift test
```

Or from Xcode using Cmd+U. 