# DigitonePad

A powerful iOS application that recreates the Elektron Digitone experience with advanced pattern sequencing, FM synthesis, and comprehensive MIDI integration.

## Overview

DigitonePad brings the acclaimed Elektron Digitone workflow to iOS, featuring:

- **8-voice FM synthesis engine** with classic 4-operator architecture
- **Pattern-based sequencing** with parameter locks and conditional trigs
- **Comprehensive MIDI integration** for external device control
- **Advanced filtering and effects** processing
- **Modular architecture** built with Swift Package Manager

## Features

### Synthesis Engine
- 8 polyphonic voices with 4-operator FM synthesis
- Multiple algorithm configurations
- Real-time parameter modulation
- High-quality audio processing

### Sequencer
- 64-step pattern sequencing
- Parameter locks for automation
- Conditional triggers and probability
- Pattern chaining and song mode
- Real-time recording and editing

### MIDI Integration
- Full MIDI input/output support
- External device sequencing
- MIDI CC mapping and automation
- Bluetooth MIDI connectivity

### Effects & Filtering
- Multi-mode resonant filters
- Delay, reverb, and modulation effects
- Per-track and master effects chains
- Real-time parameter control

## Architecture

DigitonePad is built using a modular architecture with Swift Package Manager:

```
DigitonePad/
├── Sources/
│   ├── MachineProtocols/     # Core protocol definitions
│   ├── AudioEngine/          # Audio processing and routing
│   ├── DataLayer/           # Data persistence and models
│   ├── SequencerModule/     # Pattern sequencing logic
│   ├── VoiceModule/         # FM synthesis implementation
│   ├── FilterModule/        # Audio filtering components
│   ├── FXModule/            # Effects processing
│   ├── MIDIModule/          # MIDI input/output handling
│   ├── UIComponents/        # Reusable UI elements
│   └── AppShell/            # Application coordination
├── Tests/                   # Unit and integration tests
├── Resources/               # App resources and assets
└── Documentation/           # Project documentation
```

## Requirements

- iOS 16.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Setup

### Prerequisites

1. Install Xcode from the Mac App Store
2. Install XcodeGen:
   ```bash
   brew install xcodegen
   ```

### Building the Project

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/padtrack.git
   cd padtrack
   ```

2. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```

3. Open the project in Xcode:
   ```bash
   open DigitonePad.xcodeproj
   ```

4. Build and run the project (⌘+R)

### Swift Package Development

Each module can be developed independently as a Swift Package:

```bash
# Build all packages
swift build

# Run tests
swift test

# Build specific package
cd Sources/AudioEngine
swift build
```

## Development

### Code Style

This project uses SwiftLint for code style enforcement. Run SwiftLint before committing:

```bash
swiftlint
```

### Testing

Run the test suite:

```bash
# Swift Package tests
swift test

# iOS app tests
xcodebuild test -project DigitonePad.xcodeproj -scheme DigitonePad -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Continuous Integration

The project uses GitHub Actions for CI/CD:
- Automated building and testing
- Code quality checks with SwiftLint
- Security scanning

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by the Elektron Digitone hardware synthesizer
- Built with love for the iOS music production community

## Support

For questions, issues, or feature requests, please:
- Open an issue on GitHub
- Check the [Documentation](Documentation/) folder
- Review existing discussions and issues

---

**Note**: This is an independent project and is not affiliated with Elektron Music Machines AB. 