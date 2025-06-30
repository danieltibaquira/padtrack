# AudioEngine Module

## Overview

The AudioEngine module provides a comprehensive, professional-grade audio processing system for iOS and macOS applications. It features real-time audio processing, multi-channel support, plugin architecture, MIDI integration, and advanced audio effects.

## Features

### Core Audio Engine
- **Real-time Audio Processing**: Low-latency audio processing optimized for professional applications
- **Cross-platform Support**: Compatible with iOS and macOS
- **Configurable Audio Settings**: Flexible sample rates, buffer sizes, and channel configurations
- **Performance Monitoring**: Real-time performance metrics and optimization

### Multi-Channel Audio Support
- **Standard Configurations**: Mono, Stereo, 2.1, 5.1, 7.1, 7.1.4 Atmos
- **Custom Configurations**: Support for any number of channels
- **Format Conversion**: High-quality upmixing and downmixing
- **Channel Processing**: Individual channel gain, mute, and solo controls

### Plugin Architecture
- **Dynamic Loading**: Runtime plugin loading with validation
- **Sandboxing**: Secure plugin execution with resource monitoring
- **Built-in Plugins**: High-quality gain, delay, and reverb effects
- **Parameter System**: Professional parameter handling with type safety

### Audio File I/O
- **Multiple Formats**: Support for WAV, AIFF, MP3, AAC, FLAC, OGG
- **Streaming Support**: Memory-efficient streaming for large files
- **Metadata Handling**: Complete metadata extraction and preservation
- **Format Conversion**: Convert between different audio formats

### MIDI Integration
- **Device Management**: Automatic MIDI device discovery and connection
- **Message Processing**: Complete MIDI message parsing and routing
- **Parameter Mapping**: Map MIDI controls to audio parameters
- **Real-time Processing**: Low-latency MIDI message handling

### Audio Clock and Synchronization
- **High-precision Timing**: Sample-accurate audio clock
- **Tempo Tracking**: Musical tempo and beat tracking
- **Multi-stream Sync**: Synchronize multiple audio streams
- **External Sync**: Support for MIDI Clock, Link, LTC, Word Clock

### DSP Algorithm Library
- **Audio Filters**: High-quality filters (lowpass, highpass, bandpass, notch)
- **Effects Processing**: Reverb, delay, chorus, distortion, compression
- **Analysis Tools**: FFT, spectrum analysis, level metering
- **Modulation**: LFO, envelope generators, modulation matrix

### Advanced Features
- **Buffer Management**: Efficient audio buffer pooling and circular buffers
- **Thread Management**: Optimized thread pool for audio processing
- **Error Recovery**: Automatic error detection and recovery
- **Audio Routing**: Flexible audio routing matrix with dynamic routing
- **Format Conversion**: Real-time format conversion between different audio formats
- **Performance Analysis**: Comprehensive performance monitoring and optimization

## Quick Start

### Basic Setup

```swift
import AudioEngine

// Create audio engine configuration
let config = AudioEngineConfiguration(
    sampleRate: 44100.0,
    bufferSize: 512,
    channelCount: 2
)

// Initialize audio engine
let audioEngine = AudioEngineManager()

do {
    try audioEngine.configure(with: config)
    try audioEngine.start()
    print("Audio engine started successfully")
} catch {
    print("Failed to start audio engine: \(error)")
}
```

### Multi-Channel Audio

```swift
// Set up 5.1 surround sound
audioEngine.setChannelConfiguration(.surround51)

// Create multi-channel buffer
let multiBuffer = audioEngine.createMultiChannelBuffer(frameCount: 512)

// Process multi-channel audio
audioEngine.processMultiChannelBuffer(multiBuffer)

// Convert between formats
let stereoBuffer = audioEngine.convertChannelConfiguration(
    source: multiBuffer,
    to: .stereo
)
```

### Plugin Usage

```swift
// Scan for plugins
let plugins = audioEngine.scanPlugins(in: "/path/to/plugins")

// Load a plugin
if let pluginMetadata = plugins.first {
    let plugin = try audioEngine.loadPlugin(id: pluginMetadata.id)
    
    // Initialize plugin
    try audioEngine.initializePlugin(plugin)
    
    // Set parameters
    try audioEngine.setPluginParameter(
        pluginId: plugin.id,
        parameterId: "gain",
        value: 0.8
    )
}

// Create built-in plugins
let gainPlugin = audioEngine.createBuiltInPlugin(type: .gain)
let delayPlugin = audioEngine.createBuiltInPlugin(type: .delay)
```

### Audio File Processing

```swift
// Load audio file
let fileURL = URL(fileURLWithPath: "/path/to/audio.wav")
let (buffer, metadata) = try audioEngine.loadAudioFile(from: fileURL)

// Process audio
// ... apply effects, processing, etc.

// Save processed audio
try audioEngine.saveAudioFile(
    buffer,
    to: URL(fileURLWithPath: "/path/to/output.wav"),
    format: .wav
)

// Streaming for large files
let (streamId, reader) = try audioEngine.createStreamingAudioReader(for: fileURL)
while let chunk = try reader.readNextChunk() {
    // Process chunk
    audioEngine.processAudioBuffer(chunk)
}
```

### MIDI Integration

```swift
// Scan for MIDI devices
let devices = audioEngine.scanMIDIDevices()

// Connect to device
if let device = devices.first {
    try audioEngine.connectMIDIDevice(device.id)
}

// Set up parameter mapping
try audioEngine.addMIDIParameterMapping(
    midiCC: 1,
    parameterPath: "plugin.gain",
    range: (0.0, 1.0)
)

// Send MIDI message
let noteOn = MIDIMessage.noteOn(channel: 0, note: 60, velocity: 127)
audioEngine.sendMIDIMessage(noteOn)
```

### Audio Clock and Timing

```swift
// Start audio clock
audioEngine.startAudioClock()

// Set tempo
audioEngine.setTempo(120.0)

// Set time signature
audioEngine.setTimeSignature(beatsPerBar: 4, noteValue: .quarter)

// Get current position
let (bar, beat, bpm) = audioEngine.getCurrentMusicalPosition()
print("Position: Bar \(bar), Beat \(beat), BPM \(bpm)")

// Synchronize streams
let streamId = audioEngine.addSynchronizedStream(name: "Track 1")
let syncTime = audioEngine.getSynchronizedTime(for: streamId)
```

## Architecture

### Core Components

1. **AudioEngineManager**: Main interface for all audio operations
2. **AudioBuffer**: Efficient audio data container with memory management
3. **AudioBufferPool**: Memory pool for efficient buffer allocation
4. **AudioCircularBuffer**: Lock-free circular buffer for real-time audio
5. **AudioRoutingMatrix**: Flexible audio routing and mixing
6. **AudioFormatConversionManager**: Real-time format conversion

### Processing Pipeline

```
Audio Input → Buffer Pool → Routing Matrix → DSP Processing → Plugin Chain → Multi-Channel Processing → Audio Output
                ↓
        Performance Monitoring ← Error Recovery ← Thread Management
```

### Thread Architecture

- **Audio Thread**: Real-time audio processing (highest priority)
- **MIDI Thread**: MIDI message processing
- **Plugin Threads**: Sandboxed plugin execution
- **Background Threads**: File I/O, analysis, non-real-time processing

## Performance Considerations

### Real-time Safety
- All audio processing is lock-free and wait-free
- Memory allocation avoided in audio threads
- Predictable execution times for all operations

### Memory Management
- Efficient buffer pooling reduces allocation overhead
- Circular buffers for streaming audio data
- Automatic memory cleanup and leak prevention

### CPU Optimization
- SIMD instructions for audio processing where available
- Multi-threaded processing for non-real-time operations
- Adaptive buffer sizes based on system performance

## Error Handling

The AudioEngine provides comprehensive error handling:

```swift
enum AudioEngineError: Error {
    case configurationError(String)
    case audioSessionError(String)
    case bufferError(String)
    case routingError(String)
    case formatError(String)
    case pluginError(String)
    case midiError(String)
    case fileIOError(String)
    case performanceError(String)
    case interruptionError(String)
    case routeChangeError(String)
    case unsupportedFormat(String)
}
```

## Testing

The AudioEngine includes a comprehensive testing framework:

```swift
// Run audio engine tests
let testResult = audioEngine.testAudioEngineInitialization()
print("Test passed: \(testResult.passed)")

// Performance testing
let performanceResult = audioEngine.testAudioProcessingPipeline()
print("Processing time: \(performanceResult.executionTime)ms")

// Buffer validation
let bufferResult = audioEngine.testBufferManagement()
print("Buffer test metrics: \(bufferResult.metrics)")
```

## Examples

See the `Examples/` directory for complete example projects demonstrating:
- Basic audio playback and recording
- Multi-channel surround sound processing
- Plugin development and integration
- MIDI controller integration
- Real-time audio effects
- Audio file processing and conversion

## API Reference

For complete API documentation, see the generated documentation or use Xcode's Quick Help.

## Requirements

- iOS 14.0+ / macOS 11.0+
- Xcode 13.0+
- Swift 5.5+

## License

See LICENSE file for details.
