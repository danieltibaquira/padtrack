// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DigitonePad",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        // The main application shell
        .library(
            name: "AppShell",
            targets: ["AppShell"]),
        
        // Core audio processing
        .library(
            name: "AudioEngine", 
            targets: ["AudioEngine"]),
        
        // Data persistence layer
        .library(
            name: "DataLayer",
            targets: ["DataLayer"]),
        
        // Data models (Core Data)
        .library(
            name: "DataModel",
            targets: ["DataModel"]),
        
        // Pattern sequencing
        .library(
            name: "SequencerModule",
            targets: ["SequencerModule"]),
        
        // Sound synthesis
        .library(
            name: "VoiceModule", 
            targets: ["VoiceModule"]),
        
        // Audio filtering
        .library(
            name: "FilterModule",
            targets: ["FilterModule"]),
        
        // Filter machines
        .library(
            name: "FilterMachine",
            targets: ["FilterMachine"]),
        
        // Audio effects
        .library(
            name: "FXModule",
            targets: ["FXModule"]),
        
        // MIDI input/output
        .library(
            name: "MIDIModule",
            targets: ["MIDIModule"]),
        
        // Reusable UI components
        .library(
            name: "UIComponents",
            targets: ["UIComponents"]),
        
        // Shared protocols to prevent circular dependencies
        .library(
            name: "MachineProtocols",
            targets: ["MachineProtocols"]),

        // Main DigitonePad application
        .executable(
            name: "DigitonePad",
            targets: ["DigitonePad"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.9.0")
    ],
    targets: [
        // MARK: - Core Targets
        
        // Shared protocols (no dependencies to prevent circular references)
        .target(
            name: "MachineProtocols",
            dependencies: []),
        
        // Data models (Core Data)
        .target(
            name: "DataModel",
            dependencies: ["MachineProtocols"]),
        
        // Data persistence layer
        .target(
            name: "DataLayer",
            dependencies: ["MachineProtocols", "DataModel"],
            resources: [.process("Resources")]),
        
        // Core audio processing engine
        .target(
            name: "AudioEngine",
            dependencies: ["MachineProtocols"],
            exclude: ["README.md", "Documentation/"]),
        
        // Pattern sequencing module
        .target(
            name: "SequencerModule",
            dependencies: ["MachineProtocols", "DataLayer", "DataModel", "AudioEngine"]),
        
        // Sound synthesis module
        .target(
            name: "VoiceModule",
            dependencies: ["MachineProtocols", "AudioEngine"]),
        
        // Audio filtering module
        .target(
            name: "FilterModule",
            dependencies: ["MachineProtocols", "AudioEngine", "VoiceModule"]),
        
        // Filter machines module
        .target(
            name: "FilterMachine",
            dependencies: ["MachineProtocols", "AudioEngine"]),
        
        // Audio effects module
        .target(
            name: "FXModule",
            dependencies: ["MachineProtocols", "AudioEngine"]),
        
        // MIDI input/output module
        .target(
            name: "MIDIModule",
            dependencies: ["MachineProtocols"]),
        
        // Reusable UI components
        .target(
            name: "UIComponents",
            dependencies: ["MachineProtocols"],
            exclude: ["KeyCombo/KeyComboSystemDesign.md"]),
        
        // Main application shell
        .target(
            name: "AppShell",
            dependencies: [
                "DataLayer",
                "DataModel",
                "AudioEngine",
                "SequencerModule",
                "VoiceModule",
                "FilterModule",
                "FilterMachine",
                "FXModule",
                "MIDIModule",
                "UIComponents",
                "MachineProtocols"
            ]),

        // Main DigitonePad application target
        .executableTarget(
            name: "DigitonePad",
            dependencies: [
                "AppShell",
                "DataLayer",
                "DataModel",
                "FXModule",
                "UIComponents",
                "MachineProtocols"
            ]),
        
        // MARK: - Test Targets

        // Test utilities and mock objects
        .target(
            name: "TestUtilities",
            dependencies: ["MachineProtocols", "DataLayer", "DataModel", "AudioEngine"],
            path: "Tests/TestUtilities"),

        .testTarget(
            name: "MachineProtocolsTests",
            dependencies: ["MachineProtocols", "TestUtilities"]),

        .testTarget(
            name: "DataLayerTests",
            dependencies: ["DataLayer", "TestUtilities"]),

        .testTarget(
            name: "AudioEngineTests",
            dependencies: ["AudioEngine", "SequencerModule", "TestUtilities"]),

        .testTarget(
            name: "SequencerModuleTests",
            dependencies: ["SequencerModule", "TestUtilities"]),

        .testTarget(
            name: "VoiceModuleTests",
            dependencies: ["VoiceModule", "TestUtilities"]),

        .testTarget(
            name: "FilterModuleTests",
            dependencies: ["FilterModule", "TestUtilities"]),

        .testTarget(
            name: "FilterMachineTests",
            dependencies: ["FilterMachine", "TestUtilities"]),

        .testTarget(
            name: "FXModuleTests",
            dependencies: ["FXModule", "TestUtilities"]),

        .testTarget(
            name: "MIDIModuleTests",
            dependencies: ["MIDIModule", "TestUtilities"]),

        .testTarget(
            name: "UIComponentsTests",
            dependencies: ["UIComponents", "TestUtilities"]),

        .testTarget(
            name: "AppShellTests",
            dependencies: ["AppShell", "TestUtilities"]),

        .testTarget(
            name: "DigitonePadTests",
            dependencies: [
                "DigitonePad",
                "DataLayer",
                "DataModel",
                "FXModule",
                "UIComponents",
                "TestUtilities",
                .product(name: "ViewInspector", package: "ViewInspector")
            ]),

        // Interactor tests
        .testTarget(
            name: "InteractorTests",
            dependencies: ["TestUtilities"],
            path: "Tests/InteractorTests"),

        // Code coverage tests
        .testTarget(
            name: "CodeCoverageTests",
            dependencies: ["TestUtilities"],
            path: "Tests/CodeCoverageTests"),

        // Simple demo app for iPad testing
        .executableTarget(
            name: "DigitonePadDemo",
            dependencies: [
                "UIComponents"
            ]),

        // iOS App target for iPad
        .executableTarget(
            name: "DigitonePadApp",
            dependencies: [
                "UIComponents"
            ])
    ]
)