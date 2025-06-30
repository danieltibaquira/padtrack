// FMVoiceMachine.swift
// DigitonePad - VoiceModule
//
// FM Voice Machine Implementation

import Foundation
import MachineProtocols
import AudioEngine

/// FM Voice Machine implementing the VoiceMachineProtocol
public final class FMVoiceMachine: VoiceMachine, @unchecked Sendable {
    // FM-specific components
    private let fmEngine: FMSynthesisEngine
    
    // FM Parameters
    private var currentAlgorithm: Int = 1
    private var operatorFreqRatios: [Double] = [1.0, 2.0, 3.0, 4.0]
    private var operatorLevels: [Double] = [1.0, 0.8, 0.6, 0.4]
    private var modulationIndices: [Double] = [0.0, 2.0, 1.5, 1.0]
    private var feedbackAmount: Double = 0.0
    
    public override init(name: String = "FM TONE", polyphony: Int = 8) {
        // Initialize FM engine
        self.fmEngine = FMSynthesisEngine(sampleRate: 44100.0, maxPolyphony: polyphony)
        
        super.init(name: name, polyphony: polyphony)
        
        setupFMParameters()
    }
    
    // MARK: - Audio Processing Override
    
    public override func process(input: MachineProtocols.AudioBuffer) -> MachineProtocols.AudioBuffer {
        lastActiveTimestamp = Date()

        // Process FM synthesis
        let frameCount = input.frameCount
        let fmOutput = fmEngine.processBuffer(frameCount: frameCount)

        // Create output buffer with allocated memory
        let totalSamples = frameCount * input.channelCount
        let outputData = UnsafeMutablePointer<Float>.allocate(capacity: totalSamples)
        outputData.initialize(repeating: 0.0, count: totalSamples)

        let outputBuffer = AudioEngine.AudioBuffer(
            data: outputData,
            frameCount: frameCount,
            channelCount: input.channelCount,
            sampleRate: input.sampleRate
        )

        // Copy FM output to all channels (mono to stereo/multi-channel)
        for channel in 0..<input.channelCount {
            for frame in 0..<frameCount {
                let sampleIndex = channel * frameCount + frame
                if sampleIndex < totalSamples && frame < fmOutput.count {
                    outputData[sampleIndex] = Float(fmOutput[frame])
                }
            }
        }

        return outputBuffer
    }
    
    // MARK: - Note Handling Override
    
    public override func noteOn(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?) {
        super.noteOn(note: note, velocity: velocity, channel: channel, timestamp: timestamp)
        
        // Trigger FM engine
        _ = fmEngine.noteOn(note: note, velocity: velocity)
    }
    
    public override func noteOff(note: UInt8, velocity: UInt8, channel: UInt8, timestamp: UInt64?) {
        super.noteOff(note: note, velocity: velocity, channel: channel, timestamp: timestamp)
        
        // Release in FM engine
        fmEngine.noteOff(note: note)
    }
    
    public override func allNotesOff() {
        super.allNotesOff()
        fmEngine.allNotesOff()
    }
    
    // MARK: - Parameter Management
    
    public override func updateParameter(key: String, value: Any) throws {
        switch key {
        case "algorithm":
            if let intValue = value as? Int, intValue >= 1 && intValue <= 4 {
                setAlgorithm(intValue)
            } else {
                throw CommonMachineError(code: "INVALID_ALGORITHM", message: "Algorithm must be 1-4", severity: .error)
            }
            
        case "operator1_ratio":
            if let doubleValue = value as? Double {
                setOperatorRatio(operatorIndex: 0, ratio: doubleValue)
            }

        case "operator2_ratio":
            if let doubleValue = value as? Double {
                setOperatorRatio(operatorIndex: 1, ratio: doubleValue)
            }

        case "operator3_ratio":
            if let doubleValue = value as? Double {
                setOperatorRatio(operatorIndex: 2, ratio: doubleValue)
            }

        case "operator4_ratio":
            if let doubleValue = value as? Double {
                setOperatorRatio(operatorIndex: 3, ratio: doubleValue)
            }
            
        case "operator1_level":
            if let doubleValue = value as? Double {
                setOperatorLevel(operatorIndex: 0, level: doubleValue)
            }

        case "operator2_level":
            if let doubleValue = value as? Double {
                setOperatorLevel(operatorIndex: 1, level: doubleValue)
            }

        case "operator3_level":
            if let doubleValue = value as? Double {
                setOperatorLevel(operatorIndex: 2, level: doubleValue)
            }

        case "operator4_level":
            if let doubleValue = value as? Double {
                setOperatorLevel(operatorIndex: 3, level: doubleValue)
            }
            
        case "modulation_index":
            if let doubleValue = value as? Double {
                setGlobalModulationIndex(doubleValue)
            }
            
        case "feedback":
            if let doubleValue = value as? Double {
                setFeedback(doubleValue)
            }
            
        default:
            // Try parent class parameters
            try super.updateParameter(key: key, value: value)
        }
    }
    
    // MARK: - FM-Specific Methods
    
    /// Set the FM algorithm (1-4)
    public func setAlgorithm(_ algorithm: Int) {
        guard algorithm >= 1 && algorithm <= 4 else { return }
        
        currentAlgorithm = algorithm
        
        let fmAlgorithm: FMAlgorithm
        switch algorithm {
        case 1:
            fmAlgorithm = FMAlgorithms.algorithm1
        case 2:
            fmAlgorithm = FMAlgorithms.algorithm2
        case 3:
            fmAlgorithm = FMAlgorithms.algorithm3
        case 4:
            fmAlgorithm = FMAlgorithms.algorithm4
        default:
            fmAlgorithm = FMAlgorithms.algorithm1
        }
        
        fmEngine.setAlgorithm(fmAlgorithm)
        
        // Update parameter
        do {
            try parameters.updateParameter(id: "algorithm", value: Float(algorithm))
        } catch {
            // Log error but continue
        }
    }
    
    /// Set frequency ratio for an operator
    public func setOperatorRatio(operatorIndex: Int, ratio: Double) {
        guard operatorIndex >= 0 && operatorIndex < 4 else { return }

        operatorFreqRatios[operatorIndex] = max(0.1, min(ratio, 32.0)) // Clamp ratio
        fmEngine.setOperatorRatios(operatorFreqRatios)

        // Update parameter
        do {
            try parameters.updateParameter(id: "operator\(operatorIndex + 1)_ratio", value: Float(ratio))
        } catch {
            // Log error but continue
        }
    }
    
    /// Set output level for an operator
    public func setOperatorLevel(operatorIndex: Int, level: Double) {
        guard operatorIndex >= 0 && operatorIndex < 4 else { return }

        operatorLevels[operatorIndex] = max(0.0, min(level, 1.0)) // Clamp level
        fmEngine.setOperatorLevels(operatorLevels)

        // Update parameter
        do {
            try parameters.updateParameter(id: "operator\(operatorIndex + 1)_level", value: Float(level))
        } catch {
            // Log error but continue
        }
    }
    
    /// Set global modulation index
    public func setGlobalModulationIndex(_ index: Double) {
        let clampedIndex = max(0.0, min(index, 10.0))
        
        // Scale modulation indices proportionally
        for i in 1..<4 { // Skip operator 0 (carrier)
            modulationIndices[i] = clampedIndex * (Double(i) * 0.5)
        }
        
        fmEngine.setModulationIndices(modulationIndices)
        
        // Update parameter
        do {
            try parameters.updateParameter(id: "modulation_index", value: Float(clampedIndex))
        } catch {
            // Log error but continue
        }
    }
    
    /// Set feedback amount
    public func setFeedback(_ amount: Double) {
        feedbackAmount = max(0.0, min(amount, 1.0))
        
        // Update parameter
        do {
            try parameters.updateParameter(id: "feedback", value: Float(feedbackAmount))
        } catch {
            // Log error but continue
        }
    }
    
    // MARK: - Setup
    
    private func setupFMParameters() {
        // Add FM-specific parameters
        parameters.addParameter(Parameter(
            id: "algorithm",
            name: "Algorithm",
            value: 1,
            minValue: 1,
            maxValue: 4,
            defaultValue: 1,
            unit: ""
        ))

        // Operator ratios
        for i in 1...4 {
            parameters.addParameter(Parameter(
                id: "operator\(i)_ratio",
                name: "Op\(i) Ratio",
                value: Float(operatorFreqRatios[i-1]),
                minValue: 0.1,
                maxValue: 32.0,
                defaultValue: Float(operatorFreqRatios[i-1]),
                unit: ""
            ))

            parameters.addParameter(Parameter(
                id: "operator\(i)_level",
                name: "Op\(i) Level",
                value: Float(operatorLevels[i-1]),
                minValue: 0.0,
                maxValue: 1.0,
                defaultValue: Float(operatorLevels[i-1]),
                unit: ""
            ))
        }

        parameters.addParameter(Parameter(
            id: "modulation_index",
            name: "Mod Index",
            value: 2.0,
            minValue: 0.0,
            maxValue: 10.0,
            defaultValue: 2.0,
            unit: ""
        ))

        parameters.addParameter(Parameter(
            id: "feedback",
            name: "Feedback",
            value: 0.0,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.0,
            unit: ""
        ))
    }
    
    // MARK: - Reset Override
    
    public override func reset() {
        super.reset()
        fmEngine.reset()
        
        // Reset FM parameters to defaults
        currentAlgorithm = 1
        operatorFreqRatios = [1.0, 2.0, 3.0, 4.0]
        operatorLevels = [1.0, 0.8, 0.6, 0.4]
        modulationIndices = [0.0, 2.0, 1.5, 1.0]
        feedbackAmount = 0.0
        
        // Apply defaults to engine
        setAlgorithm(1)
        fmEngine.setOperatorRatios(operatorFreqRatios)
        fmEngine.setOperatorLevels(operatorLevels)
        fmEngine.setModulationIndices(modulationIndices)
    }
}
