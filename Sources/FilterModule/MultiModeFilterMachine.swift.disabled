import Foundation
import Accelerate
import simd
import MachineProtocols

// MARK: - Multi-Mode Filter Machine

/// Comprehensive Multi-Mode Filter Machine integrating all filter components
public class MultiModeFilterMachine {
    
    // MARK: - Core Components
    
    private let coefficientCalculator: FilterCoefficientCalculator
    private let morphingEngine: FilterMorphingEngine
    private let resonanceEngine: FilterResonanceEngine
    private let keyboardTracking: KeyboardTrackingEngine
    private let parameterSmoother: FilterParameterSmoother
    private let performanceEngine: HighPerformanceFilterEngine
    
    // MARK: - Configuration
    
    public var config: MultiModeFilterConfig {
        didSet { updateConfiguration() }
    }
    
    // MARK: - State Management
    
    private var currentCoefficients: BiquadCoefficients
    private var isActive: Bool = true
    private var sampleRate: Float = 44100.0
    
    // MARK: - Parameter Management
    
    public private(set) var parameters: FilterParameters
    
    // MARK: - Performance Metrics
    
    public var performanceMetrics: FilterPerformanceMetrics {
        return performanceEngine.getPerformanceMetrics()
    }
    
    // MARK: - Initialization
    
    public init(config: MultiModeFilterConfig = MultiModeFilterConfig()) {
        self.config = config
        
        // Initialize core components
        self.coefficientCalculator = FilterCoefficientCalculator()
        self.morphingEngine = FilterMorphingEngine()
        self.resonanceEngine = FilterResonanceEngine()
        self.keyboardTracking = KeyboardTrackingEngine()
        self.parameterSmoother = FilterParameterSmoother()
        self.performanceEngine = HighPerformanceFilterEngine(config: FilterPerformanceConfig())
        
        // Initialize parameters
        self.parameters = FilterParameters()
        
        // Calculate initial coefficients
        self.currentCoefficients = coefficientCalculator.calculateBiquadCoefficients(
            type: config.defaultFilterType,
            config: FilterCoefficientConfig()
        )
        
        // Setup parameter smoothing
        setupParameterSmoothing()
    }
    
    // MARK: - Audio Processing
    
    /// Process a single audio sample
    public func processSample(_ input: Float) -> Float {
        guard isActive else { return input }
        
        // Update smoothed parameters
        let smoothedParams = parameterSmoother.getSmoothedParameters()
        updateInternalParameters(smoothedParams)
        
        // Process through performance engine
        return performanceEngine.processSIMDSample(input, coefficients: currentCoefficients)
    }
    
    /// Process audio buffer with optimal performance
    public func processBuffer(
        input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        guard isActive else {
            // Bypass processing - copy input to output
            cblas_scopy(Int32(frameCount), input, 1, output, 1)
            return
        }
        
        // Update parameters for entire buffer
        updateParametersForBuffer()
        
        // Process through high-performance engine
        performanceEngine.processSIMDBuffer(
            input: input,
            output: output,
            frameCount: frameCount,
            coefficients: currentCoefficients
        )
    }
    
    /// Process stereo audio buffer
    public func processStereoBuffer(
        inputLeft: UnsafePointer<Float>,
        inputRight: UnsafePointer<Float>,
        outputLeft: UnsafeMutablePointer<Float>,
        outputRight: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        // Process left channel
        processBuffer(input: inputLeft, output: outputLeft, frameCount: frameCount)
        
        // Process right channel (could be optimized with stereo processing)
        processBuffer(input: inputRight, output: outputRight, frameCount: frameCount)
    }
    
    // MARK: - Parameter Control
    
    /// Set cutoff frequency with immediate update
    public func setCutoff(_ frequency: Float) {
        parameters.cutoff = max(20.0, min(20000.0, frequency))
        parameterSmoother.updateParameter("cutoff", value: parameters.cutoff)
        scheduleCoefficientsUpdate()
    }
    
    /// Set resonance amount
    public func setResonance(_ resonance: Float) {
        parameters.resonance = max(0.0, min(1.0, resonance))
        parameterSmoother.updateParameter("resonance", value: parameters.resonance)
        updateResonanceEngine()
    }
    
    /// Set filter morphing position
    public func setMorphPosition(_ position: Float) {
        parameters.morphPosition = max(0.0, min(1.0, position))
        parameterSmoother.updateParameter("morphPosition", value: parameters.morphPosition)
        scheduleCoefficientsUpdate()
    }
    
    /// Set keyboard tracking amount
    public func setKeyboardTracking(_ amount: Float) {
        parameters.keyboardTracking = max(-1.0, min(1.0, amount))
        parameterSmoother.updateParameter("keyboardTracking", value: parameters.keyboardTracking)
        updateKeyboardTracking()
    }
    
    /// Set filter drive/gain
    public func setDrive(_ drive: Float) {
        parameters.drive = max(0.0, min(2.0, drive))
        parameterSmoother.updateParameter("drive", value: parameters.drive)
        scheduleCoefficientsUpdate()
    }
    
    /// Set multiple parameters at once
    public func setParameters(_ newParams: FilterParameters) {
        parameters = newParams
        
        // Update all smoothers
        parameterSmoother.updateParameters([
            "cutoff": parameters.cutoff,
            "resonance": parameters.resonance,
            "morphPosition": parameters.morphPosition,
            "keyboardTracking": parameters.keyboardTracking,
            "drive": parameters.drive
        ])
        
        updateAllSystems()
    }
    
    // MARK: - MIDI Integration
    
    /// Handle MIDI note on event
    public func noteOn(note: UInt8, velocity: UInt8) {
        let trackingParams = KeyboardTrackingParameters(
            currentNote: note,
            velocity: velocity,
            isNoteActive: true
        )
        
        keyboardTracking.updateTrackingParameters(trackingParams)
        updateCutoffWithTracking()
    }
    
    /// Handle MIDI note off event
    public func noteOff(note: UInt8) {
        keyboardTracking.noteOff(note: note)
        updateCutoffWithTracking()
    }
    
    /// Handle pitch bend
    public func pitchBend(_ value: Float) {
        keyboardTracking.setPitchBend(value)
        updateCutoffWithTracking()
    }
    
    // MARK: - Configuration Updates
    
    /// Update sample rate for all components
    public func setSampleRate(_ sampleRate: Float) {
        self.sampleRate = sampleRate
        
        // Update all components
        var coeffConfig = FilterCoefficientConfig()
        coeffConfig.sampleRate = sampleRate
        
        var smoothingConfig = parameterSmoother.config
        smoothingConfig.sampleRate = sampleRate
        parameterSmoother.updateConfig(smoothingConfig)
        
        var performanceConfig = performanceEngine.config
        performanceEngine.updateConfig(performanceConfig)
        
        scheduleCoefficientsUpdate()
    }
    
    /// Update filter configuration
    private func updateConfiguration() {
        // Update morphing engine
        var morphConfig = FilterMorphingConfig()
        morphConfig.morphingMode = config.morphingMode
        morphingEngine.updateConfig(morphConfig)
        
        // Update resonance engine
        var resonanceConfig = FilterResonanceConfig()
        resonanceConfig.maxResonance = config.maxResonance
        resonanceConfig.selfOscillationThreshold = config.selfOscillationThreshold
        resonanceEngine.updateConfig(resonanceConfig)
        
        scheduleCoefficientsUpdate()
    }
    
    // MARK: - Internal Parameter Updates
    
    private func setupParameterSmoothing() {
        // Register all filter parameters with appropriate smoothing times
        parameterSmoother.registerParameter(
            "cutoff",
            smoothingTime: 0.005,    // 5ms for frequency changes
            curve: .exponential
        )
        
        parameterSmoother.registerParameter(
            "resonance",
            smoothingTime: 0.010,    // 10ms for resonance changes
            curve: .linear
        )
        
        parameterSmoother.registerParameter(
            "morphPosition",
            smoothingTime: 0.020,    // 20ms for morphing changes
            curve: .sCurve
        )
        
        parameterSmoother.registerParameter(
            "keyboardTracking",
            smoothingTime: 0.050,    // 50ms for tracking changes
            curve: .linear
        )
        
        parameterSmoother.registerParameter(
            "drive",
            smoothingTime: 0.003,    // 3ms for drive changes
            curve: .linear
        )
    }
    
    private func updateInternalParameters(_ smoothedParams: [String: Float]) {
        // Update parameters from smoothed values
        if let cutoff = smoothedParams["cutoff"] {
            parameters.cutoff = cutoff
        }
        if let resonance = smoothedParams["resonance"] {
            parameters.resonance = resonance
        }
        if let morphPosition = smoothedParams["morphPosition"] {
            parameters.morphPosition = morphPosition
        }
        if let keyboardTracking = smoothedParams["keyboardTracking"] {
            parameters.keyboardTracking = keyboardTracking
        }
        if let drive = smoothedParams["drive"] {
            parameters.drive = drive
        }
        
        updateCoefficients()
    }
    
    private func updateParametersForBuffer() {
        // Get current smoothed parameter values
        let smoothedParams = parameterSmoother.getSmoothedParameters()
        updateInternalParameters(smoothedParams)
    }
    
    private func updateCoefficients() {
        // Calculate base coefficients
        var coeffConfig = FilterCoefficientConfig()
        coeffConfig.cutoffFrequency = parameters.cutoff
        coeffConfig.resonance = parameters.resonance
        coeffConfig.sampleRate = sampleRate
        coeffConfig.gain = parameters.drive
        
        // Apply keyboard tracking to cutoff
        let trackedCutoff = applyKeyboardTracking(parameters.cutoff)
        coeffConfig.cutoffFrequency = trackedCutoff
        
        // Get base coefficients for morphing
        let baseCoeffs = coefficientCalculator.calculateBiquadCoefficients(
            type: config.baseFilterType,
            config: coeffConfig
        )
        
        // Apply morphing if needed
        if parameters.morphPosition > 0.0 {
            let targetCoeffs = coefficientCalculator.calculateBiquadCoefficients(
                type: config.targetFilterType,
                config: coeffConfig
            )
            
            let morphParams = FilterMorphParameters(
                morphPosition: parameters.morphPosition,
                morphingMode: config.morphingMode
            )
            
            currentCoefficients = morphingEngine.morphCoefficients(
                from: baseCoeffs,
                to: targetCoeffs,
                parameters: morphParams
            )
        } else {
            currentCoefficients = baseCoeffs
        }
        
        // Apply resonance processing
        updateResonanceEngine()
    }
    
    private func applyKeyboardTracking(_ baseCutoff: Float) -> Float {
        guard parameters.keyboardTracking != 0.0 else { return baseCutoff }
        
        let trackingInfo = keyboardTracking.getTrackingInfo()
        let frequencyMultiplier = trackingInfo.frequencyMultiplier
        
        return baseCutoff * frequencyMultiplier
    }
    
    private func updateResonanceEngine() {
        let resonanceParams = ResonanceParameters(
            resonanceAmount: parameters.resonance,
            cutoffFrequency: parameters.cutoff,
            modulation: 0.0,
            velocity: 1.0
        )
        
        resonanceEngine.updateParameters(resonanceParams)
    }
    
    private func updateKeyboardTracking() {
        var trackingConfig = keyboardTracking.config
        trackingConfig.trackingAmount = parameters.keyboardTracking
        keyboardTracking.updateConfig(trackingConfig)
    }
    
    private func updateCutoffWithTracking() {
        let trackingInfo = keyboardTracking.getTrackingInfo()
        let trackedCutoff = parameters.cutoff * trackingInfo.frequencyMultiplier
        
        var coeffConfig = FilterCoefficientConfig()
        coeffConfig.cutoffFrequency = trackedCutoff
        coeffConfig.resonance = parameters.resonance
        coeffConfig.sampleRate = sampleRate
        
        scheduleCoefficientsUpdate()
    }
    
    private func scheduleCoefficientsUpdate() {
        // In a real-time system, this would schedule an update for the next audio callback
        updateCoefficients()
    }
    
    private func updateAllSystems() {
        updateResonanceEngine()
        updateKeyboardTracking()
        scheduleCoefficientsUpdate()
    }
    
    // MARK: - State Management
    
    /// Activate/deactivate the filter
    public func setActive(_ active: Bool) {
        isActive = active
    }
    
    /// Reset all filter state
    public func reset() {
        performanceEngine.reset()
        resonanceEngine.reset()
        parameterSmoother.reset()
        keyboardTracking.reset()
        
        // Reset to default coefficients
        currentCoefficients = coefficientCalculator.calculateBiquadCoefficients(
            type: config.defaultFilterType,
            config: FilterCoefficientConfig()
        )
    }
    
    // MARK: - Analysis and Visualization
    
    /// Get current frequency response
    public func getFrequencyResponse(frequencies: [Float]) -> [FilterResponse] {
        return frequencies.map { frequency in
            let magnitude = calculateMagnitudeResponse(frequency: frequency)
            let phase = calculatePhaseResponse(frequency: frequency)
            return FilterResponse(frequency: frequency, magnitude: magnitude, phase: phase)
        }
    }
    
    private func calculateMagnitudeResponse(frequency: Float) -> Float {
        // Simplified magnitude response calculation
        let normalizedFreq = frequency / sampleRate
        let omega = 2.0 * Float.pi * normalizedFreq
        
        let cos_w = cos(omega)
        let sin_w = sin(omega)
        let cos_2w = cos(2.0 * omega)
        
        // Calculate H(e^jω) magnitude
        let num_real = currentCoefficients.b0 + currentCoefficients.b1 * cos_w + currentCoefficients.b2 * cos_2w
        let num_imag = currentCoefficients.b1 * sin_w + currentCoefficients.b2 * sin(2.0 * omega)
        let num_mag_sq = num_real * num_real + num_imag * num_imag
        
        let den_real = 1.0 + currentCoefficients.a1 * cos_w + currentCoefficients.a2 * cos_2w
        let den_imag = currentCoefficients.a1 * sin_w + currentCoefficients.a2 * sin(2.0 * omega)
        let den_mag_sq = den_real * den_real + den_imag * den_imag
        
        return sqrt(num_mag_sq / den_mag_sq)
    }
    
    private func calculatePhaseResponse(frequency: Float) -> Float {
        // Simplified phase response calculation
        let normalizedFreq = frequency / sampleRate
        let omega = 2.0 * Float.pi * normalizedFreq
        
        // This would calculate the actual phase response
        // For now, return a simplified approximation
        return -omega * 2.0  // Simplified linear phase approximation
    }
    
    /// Get comprehensive filter status
    public func getFilterStatus() -> FilterStatus {
        return FilterStatus(
            isActive: isActive,
            currentCoefficients: currentCoefficients,
            parameters: parameters,
            performanceMetrics: performanceMetrics,
            resonanceInfo: resonanceEngine.getResonanceInfo(),
            trackingInfo: keyboardTracking.getTrackingInfo()
        )
    }
}

// MARK: - Configuration Structures

// Use FilterType from MachineProtocols instead of local definition

/// Filter morphing modes
public enum FilterMorphingMode: String, CaseIterable, Codable {
    case lpBpHp = "lpBpHp"
    case lpHp = "lpHp"
    case bpNotch = "bpNotch"
    case shelfMorph = "shelfMorph"
}

/// Resonance information for filters
public struct ResonanceInfo: Codable {
    public let q: Float
    public let bandwidth: Float
    public let selfOscillating: Bool
    public let dampingFactor: Float
    
    public init(q: Float, bandwidth: Float, selfOscillating: Bool, dampingFactor: Float) {
        self.q = q
        self.bandwidth = bandwidth
        self.selfOscillating = selfOscillating
        self.dampingFactor = dampingFactor
    }
}

/// Configuration for the Multi-Mode Filter Machine
public struct MultiModeFilterConfig {
    public var defaultFilterType: FilterType = .lowpass
    public var baseFilterType: FilterType = .lowpass
    public var targetFilterType: FilterType = .highpass
    public var morphingMode: FilterMorphingMode = .lpBpHp
    public var maxResonance: Float = 0.99
    public var selfOscillationThreshold: Float = 0.95
    public var enableKeyboardTracking: Bool = true
    public var enableParameterSmoothing: Bool = true
    public var enablePerformanceOptimization: Bool = true
    
    public init() {}
}

/// Current filter parameters
public struct FilterParameters {
    public var cutoff: Float = 1000.0           // Hz
    public var resonance: Float = 0.1           // 0.0 - 1.0
    public var morphPosition: Float = 0.0       // 0.0 - 1.0
    public var keyboardTracking: Float = 0.0    // -1.0 - 1.0
    public var drive: Float = 1.0               // 0.0 - 2.0
    
    public init() {}
}

/// Comprehensive filter status information
public struct FilterStatus {
    public let isActive: Bool
    public let currentCoefficients: BiquadCoefficients
    public let parameters: FilterParameters
    public let performanceMetrics: FilterPerformanceMetrics
    public let resonanceInfo: ResonanceInfo
    public let trackingInfo: TrackingInfo
}

/// Filter response data for visualization
public struct FilterResponse {
    public let frequency: Float
    public let magnitude: Float
    public let phase: Float
} 