# AudioEngine API Reference

## Core Classes

### AudioEngineManager

The main interface for all audio engine operations.

#### Configuration

```swift
func configure(with configuration: AudioEngineConfiguration) throws
```
Configure the audio engine with the specified settings.

**Parameters:**
- `configuration`: Audio engine configuration including sample rate, buffer size, and channel count

**Throws:** `AudioEngineError` if configuration fails

#### Lifecycle Management

```swift
func start() throws
func stop() throws
func suspend() throws
func resume() throws
```

Control the audio engine lifecycle.

**Throws:** `AudioEngineError` for lifecycle operation failures

#### Status and Monitoring

```swift
var status: AudioEngineStatus { get }
var isRunning: Bool { get }
var configuration: AudioEngineConfiguration? { get }
func getPerformanceMetrics() -> AudioPerformanceMetrics
```

Get current engine status and performance information.

#### Callbacks

```swift
func setStatusChangeCallback(_ callback: @escaping (AudioEngineStatus) -> Void)
func setErrorCallback(_ callback: @escaping (AudioEngineError) -> Void)
func setPerformanceCallback(_ callback: @escaping (AudioPerformanceMetrics) -> Void)
```

Set up callbacks for status changes, errors, and performance monitoring.

### AudioEngineConfiguration

Configuration structure for the audio engine.

```swift
public struct AudioEngineConfiguration {
    let sampleRate: Double
    let bufferSize: Int
    let channelCount: Int
    let enablePerformanceMonitoring: Bool
    let enableErrorRecovery: Bool
    let sessionCategory: AVAudioSession.Category
    let sessionOptions: AVAudioSession.CategoryOptions
}
```

## Audio Buffer Management

### AudioBuffer

Core audio data container.

```swift
public final class AudioBuffer {
    let data: UnsafeMutablePointer<Float>
    let frameCount: Int
    let channelCount: Int
    let sampleRate: Double
}
```

#### Buffer Operations

```swift
func createAudioBuffer(frameCount: Int, channelCount: Int, sampleRate: Double) throws -> AudioBuffer
func releaseAudioBuffer(_ buffer: AudioBuffer)
func processAudioBuffer(_ buffer: AudioBuffer) throws
func validateAudioOutput(_ buffer: AudioBuffer) -> AudioValidationResult
```

### AudioBufferPool

Efficient buffer allocation and management.

```swift
func getBuffer() -> AudioBuffer?
func returnBuffer(_ buffer: AudioBuffer)
func getStatistics() -> BufferPoolStatistics
```

### AudioCircularBuffer

Lock-free circular buffer for real-time audio.

```swift
func write(_ data: UnsafePointer<Float>, frameCount: Int) -> Int
func read(_ data: UnsafeMutablePointer<Float>, frameCount: Int) -> Int
func getAvailableFrames() -> Int
func getUsedFrames() -> Int
```

## Multi-Channel Audio Support

### ChannelConfiguration

Supported channel configurations.

```swift
public enum ChannelConfiguration {
    case mono, stereo, stereo21, surround51, surround71, surround714
    case custom(channelCount: Int)
    
    var channelCount: Int { get }
    var channelLabels: [String] { get }
}
```

### MultiChannelAudioBuffer

Non-interleaved multi-channel audio buffer.

```swift
func getChannelData(channel: Int) -> UnsafeMutablePointer<Float>?
func setSample(channel: Int, frame: Int, value: Float)
func getSample(channel: Int, frame: Int) -> Float
func clear()
func copyFrom(_ other: MultiChannelAudioBuffer)
func toInterleavedBuffer() -> AudioBuffer
static func fromInterleavedBuffer(_ buffer: AudioBuffer, configuration: ChannelConfiguration) -> MultiChannelAudioBuffer
```

### Multi-Channel Operations

```swift
func setChannelConfiguration(_ configuration: ChannelConfiguration)
func getChannelConfiguration() -> ChannelConfiguration
func createMultiChannelBuffer(frameCount: Int) -> MultiChannelAudioBuffer?
func convertChannelConfiguration(source: MultiChannelAudioBuffer, to targetConfig: ChannelConfiguration) -> MultiChannelAudioBuffer?
func setChannelGain(channel: Int, gain: Float)
func setChannelMute(channel: Int, mute: Bool)
func setChannelSolo(channel: Int, solo: Bool)
func getChannelStatus(channel: Int) -> (gain: Float, mute: Bool, solo: Bool)
```

## Plugin Architecture

### AudioPlugin Protocol

Interface for audio plugins.

```swift
public protocol AudioPlugin {
    var id: UUID { get }
    var name: String { get }
    var version: String { get }
    var parameters: [AudioPluginParameter] { get }
    
    func initialize(sampleRate: Double, bufferSize: Int) throws
    func process(_ buffer: AudioBuffer) throws
    func setParameter(id: String, value: Float) throws
    func getParameter(id: String) throws -> Float
    func reset()
    func cleanup()
}
```

### Plugin Management

```swift
func scanPlugins(in directory: String) -> [AudioPluginMetadata]
func loadPlugin(id: UUID) throws -> AudioPlugin
func unloadPlugin(id: UUID)
func getPlugin(id: UUID) -> AudioPlugin?
func getAllLoadedPlugins() -> [AudioPlugin]
func processAudioThroughPlugin(pluginId: UUID, buffer: AudioBuffer) throws
func createBuiltInPlugin(type: AudioPluginManager.BuiltInPluginType) -> AudioPlugin?
```

### Plugin Parameters

```swift
func setPluginParameter(pluginId: UUID, parameterId: String, value: Float) throws
func getPluginParameter(pluginId: UUID, parameterId: String) throws -> Float
func getPluginParameters(id: UUID) -> [AudioPluginParameter]
func resetPlugin(id: UUID)
```

## Audio File I/O

### File Operations

```swift
func loadAudioFile(from url: URL) throws -> (buffer: AudioBuffer, metadata: AudioFileMetadata)
func saveAudioFile(_ buffer: AudioBuffer, to url: URL, format: AudioFileFormat, metadata: AudioFileMetadata?) throws
func getAudioFileMetadata(for url: URL) throws -> AudioFileMetadata
func convertAudioFile(from sourceURL: URL, to destinationURL: URL, targetFormat: AudioFileFormat) throws
```

### Streaming Audio

```swift
func createStreamingAudioReader(for url: URL, bufferSize: Int) throws -> (id: UUID, reader: StreamingAudioFileReader)
func getStreamingAudioReader(id: UUID) -> StreamingAudioFileReader?
func removeStreamingAudioReader(id: UUID)
```

### Supported Formats

```swift
public enum AudioFileFormat: String, CaseIterable {
    case wav, aiff, mp3, aac, flac, ogg
}

func getSupportedAudioFormats() -> [AudioFileFormat]
func isAudioFormatSupported(_ format: AudioFileFormat) -> Bool
```

## MIDI Integration

### Device Management

```swift
func scanMIDIDevices() -> [MIDIDeviceInfo]
func connectMIDIDevice(_ deviceId: UUID) throws
func disconnectMIDIDevice(_ deviceId: UUID)
func getConnectedMIDIDevices() -> [MIDIDeviceInfo]
```

### Message Handling

```swift
func sendMIDIMessage(_ message: MIDIMessage) throws
func setMIDIMessageCallback(_ callback: @escaping (MIDIMessage) -> Void)
```

### Parameter Mapping

```swift
func addMIDIParameterMapping(midiCC: UInt8, parameterPath: String, range: (Float, Float)) throws
func removeMIDIParameterMapping(midiCC: UInt8)
func getMIDIParameterMappings() -> [MIDIParameterMapping]
```

## Audio Clock and Synchronization

### Clock Control

```swift
func startAudioClock()
func stopAudioClock()
func pauseAudioClock()
func resumeAudioClock()
func getCurrentAudioTime() -> TimeInterval
func getCurrentSamplePosition() -> Int64
```

### Musical Timing

```swift
func setTempo(_ bpm: Double)
func setTimeSignature(beatsPerBar: Int, noteValue: TempoTracker.NoteValue)
func updateMusicalPosition()
func getCurrentMusicalPosition() -> (bar: Int, beat: Double, bpm: Double)
```

### Stream Synchronization

```swift
func addSynchronizedStream(name: String, offset: TimeInterval) -> UUID?
func removeSynchronizedStream(id: UUID)
func getSynchronizedTime(for streamId: UUID) -> TimeInterval?
```

### External Synchronization

```swift
func enableExternalSync(type: ExternalSyncType)
func disableExternalSync()
func getAudioClockStatus() -> AudioClockStatus?
```

## DSP Processing

### Audio Filters

```swift
func createFilter(type: FilterType, frequency: Float, resonance: Float, sampleRate: Double) -> AudioFilter
func applyFilter(_ filter: AudioFilter, to buffer: AudioBuffer)
```

### Audio Effects

```swift
func createReverb(parameters: [String: Float]) -> ReverbAlgorithm
func createDelay(maxDelay: Int) -> DelayLine
func createChorus(parameters: [String: Float]) -> ChorusEffect
func createDistortion(parameters: [String: Float]) -> DistortionEffect
func createCompressor(parameters: [String: Float]) -> CompressorEffect
```

### Analysis Tools

```swift
func performFFT(_ buffer: AudioBuffer, windowSize: Int) -> FFTResult
func analyzeSpectrum(_ buffer: AudioBuffer) -> SpectrumAnalysisResult
func measureLevel(_ buffer: AudioBuffer) -> AudioLevelMeasurement
```

## Error Handling

### AudioEngineError

```swift
public enum AudioEngineError: Error {
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

## Testing Framework

### Test Operations

```swift
func testAudioEngineInitialization() -> AudioTestResult
func testAudioProcessingPipeline() -> AudioTestResult
func testBufferManagement() -> AudioTestResult
func runComprehensiveTests() -> [AudioTestResult]
```

### Test Results

```swift
public struct AudioTestResult {
    let testName: String
    let passed: Bool
    let executionTime: TimeInterval
    let metrics: [String: Double]
    let errorMessage: String?
}
```

## Performance Monitoring

### Performance Metrics

```swift
public struct AudioPerformanceMetrics {
    let cpuUsage: Double
    let memoryUsage: Double
    let averageLatency: Double
    let peakLatency: Double
    let bufferUnderruns: Int
    let bufferOverruns: Int
    let activeNodes: Int
    let sampleRate: Double
    let bufferSize: Int
    // ... additional metrics
}
```

## Constants and Enumerations

### Audio Engine Status

```swift
public enum AudioEngineStatus {
    case stopped, starting, running, stopping, suspended, error
}
```

### Filter Types

```swift
public enum FilterType {
    case lowpass, highpass, bandpass, notch, allpass
}
```

### Note Values

```swift
public enum NoteValue: Double {
    case whole = 1.0, half = 2.0, quarter = 4.0, eighth = 8.0, sixteenth = 16.0
}
```
