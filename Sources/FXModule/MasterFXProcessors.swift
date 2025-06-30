// MasterFXProcessors.swift
// DigitonePad - FXModule
//
// Supporting processors for Master FX Implementation

import Foundation
import Accelerate
import MachineProtocols

// MARK: - Advanced Overdrive Processor

/// High-quality overdrive processor for master bus
internal final class AdvancedOverdriveProcessor: @unchecked Sendable {
    
    private let sampleRate: Double
    private var preEmphasisFilter: BiquadFilter
    private var deEmphasisFilter: BiquadFilter
    private var dcBlocker: DCBlocker
    private var harmonicGenerator: HarmonicGenerator
    private var saturationProcessor: SaturationProcessor
    
    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        self.preEmphasisFilter = BiquadFilter(sampleRate: sampleRate)
        self.deEmphasisFilter = BiquadFilter(sampleRate: sampleRate)
        self.dcBlocker = DCBlocker(sampleRate: sampleRate)
        self.harmonicGenerator = HarmonicGenerator(sampleRate: sampleRate)
        self.saturationProcessor = SaturationProcessor()
    }
    
    func updateConfig(_ config: MasterOverdriveConfig) {
        setupFilters(config: config)
        saturationProcessor.setSaturationType(config.saturation)
        harmonicGenerator.setAmount(config.harmonics)
    }
    
    func process(buffer: inout [Float], frameCount: Int, channelCount: Int, config: MasterOverdriveConfig) {
        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                let index = frame * channelCount + channel
                var sample = buffer[index]
                
                // Apply pre-emphasis
                sample = preEmphasisFilter.process(sample, channel: channel)
                
                // Apply drive
                sample *= config.drive
                
                // Apply saturation
                sample = saturationProcessor.process(sample, asymmetry: config.asymmetry)
                
                // Add harmonics
                if config.harmonics > 0.0 {
                    let harmonics = harmonicGenerator.process(sample, channel: channel)
                    sample += harmonics * config.harmonics
                }
                
                // Apply de-emphasis
                sample = deEmphasisFilter.process(sample, channel: channel)
                
                // Apply DC blocking
                sample = dcBlocker.process(sample, channel: channel)
                
                // Apply stereo width (for stereo processing)
                if channelCount == 2 && config.stereoWidth != 1.0 {
                    sample = applyStereoWidth(sample, channel: channel, width: config.stereoWidth, frame: frame, buffer: buffer)
                }
                
                // Apply output level
                if config.outputLevel != 0.0 {
                    sample *= pow(10.0, config.outputLevel / 20.0)
                }
                
                buffer[index] = sample
            }
        }
    }
    
    func reset() {
        preEmphasisFilter.reset()
        deEmphasisFilter.reset()
        dcBlocker.reset()
        harmonicGenerator.reset()
        saturationProcessor.reset()
    }
    
    private func setupFilters(config: MasterOverdriveConfig) {
        // Pre-emphasis filter (high-shelf)
        let preEmphFreq = 3000.0 + config.presence * 2000.0
        let preEmphGain = config.presence * 3.0
        preEmphasisFilter.setHighShelf(frequency: Float(preEmphFreq), gain: preEmphGain, q: 0.7)
        
        // De-emphasis filter (low-shelf for warmth)
        let deEmphFreq = 200.0 + config.warmth * 300.0
        let deEmphGain = config.warmth * 2.0
        deEmphasisFilter.setLowShelf(frequency: Float(deEmphFreq), gain: deEmphGain, q: 0.7)
    }
    
    private func applyStereoWidth(_ sample: Float, channel: Int, width: Float, frame: Int, buffer: [Float]) -> Float {
        if channel == 0 { // Left channel
            let rightIndex = frame * 2 + 1
            let rightSample = buffer[rightIndex]
            
            let mid = (sample + rightSample) * 0.5
            let side = (sample - rightSample) * 0.5 * width
            
            return mid + side
        } else { // Right channel
            let leftIndex = frame * 2
            let leftSample = buffer[leftIndex]
            
            let mid = (leftSample + sample) * 0.5
            let side = (leftSample - sample) * 0.5 * width
            
            return mid - side
        }
    }
}

// MARK: - Advanced Limiter Processor

/// High-quality limiter processor for master bus
internal final class AdvancedLimiterProcessor: @unchecked Sendable {
    
    private let sampleRate: Double
    private var lookaheadBuffer: LookaheadBuffer
    private var envelopeFollower: EnvelopeFollower
    private var oversamplingProcessor: OversamplingProcessor?
    private var isrDetector: ISRDetector
    
    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        self.lookaheadBuffer = LookaheadBuffer(maxDelay: 0.01, sampleRate: sampleRate)
        self.envelopeFollower = EnvelopeFollower(sampleRate: sampleRate)
        self.isrDetector = ISRDetector(sampleRate: sampleRate)
    }
    
    func updateConfig(_ config: MasterLimiterConfig) {
        lookaheadBuffer.setDelay(config.lookahead)
        envelopeFollower.setRelease(config.release)
        
        // Setup oversampling if needed
        if config.oversampling > 1 {
            oversamplingProcessor = OversamplingProcessor(factor: config.oversampling, sampleRate: sampleRate)
        } else {
            oversamplingProcessor = nil
        }
    }
    
    func process(buffer: inout [Float], frameCount: Int, channelCount: Int, config: MasterLimiterConfig) {
        if let oversampler = oversamplingProcessor {
            // Process with oversampling
            processWithOversampling(&buffer, frameCount: frameCount, channelCount: channelCount, config: config, oversampler: oversampler)
        } else {
            // Process without oversampling
            processWithoutOversampling(&buffer, frameCount: frameCount, channelCount: channelCount, config: config)
        }
    }
    
    func reset() {
        lookaheadBuffer.reset()
        envelopeFollower.reset()
        oversamplingProcessor?.reset()
        isrDetector.reset()
    }
    
    private func processWithoutOversampling(_ buffer: inout [Float], frameCount: Int, channelCount: Int, config: MasterLimiterConfig) {
        let ceilingLinear = pow(10.0, config.ceiling / 20.0)
        
        for frame in 0..<frameCount {
            var peakLevel: Float = 0.0
            
            // Find peak level for this frame
            for channel in 0..<channelCount {
                let index = frame * channelCount + channel
                let sample = buffer[index]
                peakLevel = max(peakLevel, abs(sample))
            }
            
            // Detect inter-sample peaks if enabled
            if config.isr {
                peakLevel = max(peakLevel, isrDetector.detectISR(buffer, frame: frame, channelCount: channelCount))
            }
            
            // Calculate gain reduction
            let gainReduction = calculateLimiterGainReduction(peakLevel, ceiling: ceilingLinear, softKnee: config.softKnee)
            let smoothedGainReduction = envelopeFollower.process(gainReduction, channel: 0)
            
            // Apply limiting to all channels
            for channel in 0..<channelCount {
                let index = frame * channelCount + channel
                let delayed = lookaheadBuffer.process(buffer[index], channel: channel)
                buffer[index] = delayed * smoothedGainReduction
            }
        }
    }
    
    private func processWithOversampling(_ buffer: inout [Float], frameCount: Int, channelCount: Int, config: MasterLimiterConfig, oversampler: OversamplingProcessor) {
        // Upsample, process, and downsample
        let upsampledBuffer = oversampler.upsample(buffer, frameCount: frameCount, channelCount: channelCount)
        var processedBuffer = upsampledBuffer
        
        processWithoutOversampling(&processedBuffer, frameCount: frameCount * oversampler.factor, channelCount: channelCount, config: config)
        
        let downsampledBuffer = oversampler.downsample(processedBuffer, frameCount: frameCount * oversampler.factor, channelCount: channelCount)
        
        for i in 0..<frameCount * channelCount {
            buffer[i] = downsampledBuffer[i]
        }
    }
    
    private func calculateLimiterGainReduction(_ level: Float, ceiling: Float, softKnee: Float) -> Float {
        guard level > ceiling else { return 1.0 }
        
        let ratio = level / ceiling
        
        if softKnee > 0.0 {
            // Soft knee limiting
            let kneeStart = ceiling * (1.0 - softKnee * 0.1)
            if level > kneeStart {
                let kneeRatio = (level - kneeStart) / (ceiling - kneeStart)
                let softRatio = 1.0 - kneeRatio * kneeRatio * 0.5
                return ceiling / level * softRatio
            }
        }
        
        // Hard limiting
        return ceiling / level
    }
}

// MARK: - Master EQ Processor

/// 4-band EQ processor for master bus
internal final class MasterEQProcessor: @unchecked Sendable {
    
    private let sampleRate: Double
    private var lowShelfFilter: BiquadFilter
    private var lowMidFilter: BiquadFilter
    private var highMidFilter: BiquadFilter
    private var highShelfFilter: BiquadFilter
    
    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        self.lowShelfFilter = BiquadFilter(sampleRate: sampleRate)
        self.lowMidFilter = BiquadFilter(sampleRate: sampleRate)
        self.highMidFilter = BiquadFilter(sampleRate: sampleRate)
        self.highShelfFilter = BiquadFilter(sampleRate: sampleRate)
    }
    
    func updateConfig(_ config: MasterEQConfig) {
        lowShelfFilter.setLowShelf(frequency: config.lowShelf.frequency, gain: config.lowShelf.gain, q: config.lowShelf.q)
        lowMidFilter.setPeaking(frequency: config.lowMid.frequency, gain: config.lowMid.gain, q: config.lowMid.q)
        highMidFilter.setPeaking(frequency: config.highMid.frequency, gain: config.highMid.gain, q: config.highMid.q)
        highShelfFilter.setHighShelf(frequency: config.highShelf.frequency, gain: config.highShelf.gain, q: config.highShelf.q)
    }
    
    func process(buffer: inout [Float], frameCount: Int, channelCount: Int, config: MasterEQConfig) {
        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                let index = frame * channelCount + channel
                var sample = buffer[index]
                
                // Process through EQ bands
                if config.lowShelf.enabled {
                    sample = lowShelfFilter.process(sample, channel: channel)
                }
                
                if config.lowMid.enabled {
                    sample = lowMidFilter.process(sample, channel: channel)
                }
                
                if config.highMid.enabled {
                    sample = highMidFilter.process(sample, channel: channel)
                }
                
                if config.highShelf.enabled {
                    sample = highShelfFilter.process(sample, channel: channel)
                }
                
                buffer[index] = sample
            }
        }
    }
    
    func reset() {
        lowShelfFilter.reset()
        lowMidFilter.reset()
        highMidFilter.reset()
        highShelfFilter.reset()
    }
}

// MARK: - Master Output Processor

/// Master output processor with dithering and format conversion
internal final class MasterOutputProcessor: @unchecked Sendable {
    
    private let sampleRate: Double
    private var dcBlocker: DCBlocker
    private var ditherGenerator: DitherGenerator
    
    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        self.dcBlocker = DCBlocker(sampleRate: sampleRate)
        self.ditherGenerator = DitherGenerator()
    }
    
    func updateConfig(_ config: MasterOutputConfig) {
        ditherGenerator.setType(config.ditherType)
    }
    
    func process(buffer: inout [Float], frameCount: Int, channelCount: Int, config: MasterOutputConfig) {
        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                let index = frame * channelCount + channel
                var sample = buffer[index]
                
                // Apply master gain
                if config.gain != 0.0 {
                    sample *= pow(10.0, config.gain / 20.0)
                }
                
                // Apply stereo width
                if channelCount == 2 && config.stereoWidth != 1.0 {
                    sample = applyStereoWidth(sample, channel: channel, width: config.stereoWidth, frame: frame, buffer: buffer)
                }
                
                // Apply DC blocking
                if config.dcBlock {
                    sample = dcBlocker.process(sample, channel: channel)
                }
                
                // Apply dithering
                if config.dithering {
                    sample += ditherGenerator.generate(config.ditherType)
                }
                
                // Apply output format conversion
                sample = applyOutputFormat(sample, format: config.outputFormat)
                
                buffer[index] = sample
            }
        }
    }
    
    func reset() {
        dcBlocker.reset()
        ditherGenerator.reset()
    }
    
    private func applyStereoWidth(_ sample: Float, channel: Int, width: Float, frame: Int, buffer: [Float]) -> Float {
        if channel == 0 { // Left channel
            let rightIndex = frame * 2 + 1
            let rightSample = buffer[rightIndex]
            
            let mid = (sample + rightSample) * 0.5
            let side = (sample - rightSample) * 0.5 * width
            
            return mid + side
        } else { // Right channel
            let leftIndex = frame * 2
            let leftSample = buffer[leftIndex]
            
            let mid = (leftSample + sample) * 0.5
            let side = (leftSample - sample) * 0.5 * width
            
            return mid - side
        }
    }
    
    private func applyOutputFormat(_ sample: Float, format: OutputFormat) -> Float {
        switch format {
        case .float32:
            return sample
        case .int24:
            let scaled = sample * 8388607.0 // 2^23 - 1
            return round(scaled) / 8388607.0
        case .int16:
            let scaled = sample * 32767.0 // 2^15 - 1
            return round(scaled) / 32767.0
        }
    }
}
