// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DigitonePad",
    platforms: [
        .iOS(.v16)
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
            targets: ["MachineProtocols"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // Add external dependencies here as needed
    ],
    targets: [
        // MARK: - Core Targets
        
        // Shared protocols (no dependencies to prevent circular references)
        .target(
            name: "MachineProtocols",
            dependencies: []),
        
        // Data persistence layer
        .target(
            name: "DataLayer",
            dependencies: ["MachineProtocols"]),
        
        // Core audio processing engine
        .target(
            name: "AudioEngine",
            dependencies: ["MachineProtocols"]),
        
        // Pattern sequencing module
        .target(
            name: "SequencerModule", 
            dependencies: ["MachineProtocols", "DataLayer"]),
        
        // Sound synthesis module
        .target(
            name: "VoiceModule",
            dependencies: ["MachineProtocols", "AudioEngine"]),
        
        // Audio filtering module
        .target(
            name: "FilterModule",
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
            dependencies: ["MachineProtocols"]),
        
        // Main application shell
        .target(
            name: "AppShell",
            dependencies: [
                "DataLayer",
                "AudioEngine", 
                "SequencerModule",
                "VoiceModule",
                "FilterModule",
                "FXModule",
                "MIDIModule",
                "UIComponents",
                "MachineProtocols"
            ]),
        
        // MARK: - Test Targets
        
        .testTarget(
            name: "MachineProtocolsTests",
            dependencies: ["MachineProtocols"]),
        
        .testTarget(
            name: "DataLayerTests",
            dependencies: ["DataLayer"]),
        
        .testTarget(
            name: "AudioEngineTests",
            dependencies: ["AudioEngine"]),
        
        .testTarget(
            name: "SequencerModuleTests",
            dependencies: ["SequencerModule"]),
        
        .testTarget(
            name: "VoiceModuleTests",
            dependencies: ["VoiceModule"]),
        
        .testTarget(
            name: "FilterModuleTests",
            dependencies: ["FilterModule"]),
        
        .testTarget(
            name: "FXModuleTests",
            dependencies: ["FXModule"]),
        
        .testTarget(
            name: "MIDIModuleTests",
            dependencies: ["MIDIModule"]),
        
        .testTarget(
            name: "UIComponentsTests",
            dependencies: ["UIComponents"]),
        
        .testTarget(
            name: "AppShellTests",
            dependencies: ["AppShell"])
    ]
) 