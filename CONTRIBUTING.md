# Contributing to DigitonePad

Thank you for your interest in contributing to DigitonePad! This document provides guidelines and information for contributors.

## Code of Conduct

By participating in this project, you agree to abide by our code of conduct:
- Be respectful and inclusive
- Focus on constructive feedback
- Help create a welcoming environment for all contributors

## Getting Started

### Prerequisites

- macOS with Xcode 15.0 or later
- Swift 5.9 or later
- XcodeGen (`brew install xcodegen`)
- SwiftLint (`brew install swiftlint`)

### Setting Up Your Development Environment

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/your-username/padtrack.git
   cd padtrack
   ```
3. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```
4. Open the project in Xcode:
   ```bash
   open DigitonePad.xcodeproj
   ```

## Development Workflow

### Branching Strategy

- `main`: Stable release branch
- `develop`: Integration branch for new features
- `feature/feature-name`: Feature development branches
- `bugfix/bug-description`: Bug fix branches
- `hotfix/critical-fix`: Critical fixes for production

### Making Changes

1. Create a new branch from `develop`:
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/your-feature-name
   ```

2. Make your changes following our coding standards
3. Add tests for new functionality
4. Ensure all tests pass
5. Commit your changes with descriptive messages

### Commit Message Format

Use conventional commit format:
```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(audio): add FM synthesis algorithm selection
fix(sequencer): resolve pattern playback timing issue
docs(readme): update installation instructions
```

## Coding Standards

### Swift Style Guide

We follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) with these additions:

#### Naming Conventions
- Use descriptive names for variables, functions, and types
- Prefer clarity over brevity
- Use camelCase for variables and functions
- Use PascalCase for types and protocols

#### Code Organization
- Group related functionality together
- Use MARK comments to organize code sections
- Keep functions focused and small (< 50 lines when possible)
- Prefer composition over inheritance

#### Documentation
- Document public APIs with Swift documentation comments
- Include usage examples for complex functionality
- Document any non-obvious behavior or side effects

### SwiftLint Configuration

The project uses SwiftLint for code style enforcement. Run before committing:
```bash
swiftlint
```

Key rules:
- Line length: 120 characters (warning), 150 (error)
- Function body length: 50 lines (warning), 100 (error)
- No force unwrapping in production code
- Consistent spacing and formatting

## Testing Guidelines

### Test Structure

- **Unit Tests**: Test individual components in isolation
- **Integration Tests**: Test module interactions
- **Performance Tests**: Test audio processing performance
- **UI Tests**: Test user interface functionality

### Writing Tests

1. Follow the Arrange-Act-Assert pattern
2. Use descriptive test names that explain the scenario
3. Test both success and failure cases
4. Mock external dependencies
5. Ensure tests are deterministic and isolated

Example:
```swift
func testFMSynthesisGeneratesExpectedFrequency() {
    // Arrange
    let synthesizer = FMSynthesizer()
    let expectedFrequency: Float = 440.0
    
    // Act
    synthesizer.setFrequency(expectedFrequency)
    let result = synthesizer.generateTone(duration: 0.1)
    
    // Assert
    XCTAssertEqual(result.fundamentalFrequency, expectedFrequency, accuracy: 0.1)
}
```

### Running Tests

```bash
# Swift Package tests
swift test

# iOS app tests
xcodebuild test -project DigitonePad.xcodeproj -scheme DigitonePad -destination 'platform=iOS Simulator,name=iPhone 15'

# Specific test target
swift test --filter AudioEngineTests
```

## Module Development

### Architecture Principles

- **Separation of Concerns**: Each module has a single responsibility
- **Dependency Injection**: Use protocols for dependencies
- **Testability**: Design for easy testing and mocking
- **Performance**: Optimize for real-time audio processing

### Adding New Modules

1. Create module directory in `Sources/`
2. Add corresponding test directory in `Tests/`
3. Update `Package.swift` with new target
4. Update `project.yml` for Xcode integration
5. Add module documentation

### Module Dependencies

Follow the dependency hierarchy:
```
MachineProtocols (base protocols)
├── DataLayer
├── AudioEngine
├── MIDIModule
├── UIComponents
└── Higher-level modules (VoiceModule, FilterModule, etc.)
    └── AppShell (top-level coordination)
```

## Audio Development Guidelines

### Real-time Constraints

- Avoid memory allocation in audio callbacks
- Use lock-free data structures when possible
- Minimize computational complexity in audio threads
- Profile performance regularly

### Audio Quality

- Use appropriate sample rates and bit depths
- Implement proper anti-aliasing
- Handle edge cases (silence, clipping, etc.)
- Test with various audio configurations

## Pull Request Process

### Before Submitting

1. Ensure all tests pass
2. Run SwiftLint and fix any issues
3. Update documentation if needed
4. Add changelog entry for significant changes
5. Rebase your branch on the latest `develop`

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No new warnings introduced
```

### Review Process

1. Automated checks must pass (CI, tests, linting)
2. At least one code review approval required
3. Address all review feedback
4. Maintain clean commit history

## Performance Considerations

### Audio Processing

- Target < 5ms latency for real-time processing
- Use SIMD instructions where appropriate
- Profile with Instruments regularly
- Test on various iOS devices

### Memory Management

- Use ARC effectively
- Avoid retain cycles
- Monitor memory usage in audio contexts
- Use weak references appropriately

## Documentation

### Code Documentation

- Document all public APIs
- Include usage examples
- Explain complex algorithms
- Document performance characteristics

### Architecture Documentation

- Update architecture diagrams for significant changes
- Document module interactions
- Explain design decisions
- Maintain API documentation

## Getting Help

### Resources

- [Swift Documentation](https://swift.org/documentation/)
- [iOS Audio Development](https://developer.apple.com/audio/)
- [Core Audio Programming Guide](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/)

### Communication

- GitHub Issues: Bug reports and feature requests
- GitHub Discussions: General questions and ideas
- Code Reviews: Technical discussions

## Recognition

Contributors will be recognized in:
- README.md acknowledgments
- Release notes for significant contributions
- Project documentation

Thank you for contributing to DigitonePad! 