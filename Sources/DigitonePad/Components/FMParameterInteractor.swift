import Foundation
import VoiceModule

/// Interactor for FM TONE parameter management
public class FMParameterInteractor {
    private weak var fmVoiceMachine: FMVoiceMachine?
    private var parameterValues: [String: Double] = [:]
    
    public init(fmVoiceMachine: FMVoiceMachine? = nil) {
        self.fmVoiceMachine = fmVoiceMachine
        initializeDefaultValues()
    }
    
    /// Get parameter labels for a specific page
    public func getParameterLabels(for page: Int) -> [String] {
        switch page {
        case 1: // Core FM
            return ["ALGO", "RATIO C", "RATIO A", "RATIO B", "HARM", "DTUN", "FDBK", "MIX"]
        case 2: // Envelopes
            return ["ATK A", "DEC A", "END A", "LEV A", "ATK B", "DEC B", "END B", "LEV B"]
        case 3: // Behavior
            return ["DELAY", "TRIG", "PHASE", "VEL", "PRIOR", "PORTA", "LEGATO", "SUST"]
        case 4: // Tracking
            return ["TRACK", "FINE", "OFS A", "OFS B", "TRK A", "TRK B", "DEPTH", "LEVEL"]
        default:
            return Array(repeating: "---", count: 8)
        }
    }
    
    /// Get formatted value for display
    public func getFormattedValue(page: Int, index: Int, normalizedValue: Double) -> String {
        switch page {
        case 1: // Core FM
            switch index {
            case 0: // Algorithm
                return "ALG\(Int(normalizedValue * 4) + 1)"
            case 1, 2, 3: // Ratios
                return String(format: "%.2f", normalizedValue * 32.0)
            case 4: // Harmonic
                return String(format: "%.0f", normalizedValue * 127)
            case 5: // Detune
                return String(format: "%.0f¢", (normalizedValue - 0.5) * 100)
            case 6: // Feedback
                return String(format: "%.0f", normalizedValue * 127)
            case 7: // Mix
                return String(format: "%.0f", normalizedValue * 127)
            default:
                return String(format: "%.0f", normalizedValue * 127)
            }
        case 2: // Envelopes
            return String(format: "%.0f", normalizedValue * 127)
        case 3: // Behavior
            switch index {
            case 1: // Trig Mode
                let modes = ["NORM", "RETRIG", "ONCE", "HOLD"]
                return modes[Int(normalizedValue * 3)]
            case 2, 6, 7: // Phase Reset, Legato, Sustain (boolean)
                return normalizedValue > 0.5 ? "ON" : "OFF"
            case 4: // Note Priority
                let priorities = ["LOW", "HIGH", "LAST"]
                return priorities[Int(normalizedValue * 2)]
            default:
                return String(format: "%.0f", normalizedValue * 127)
            }
        case 4: // Tracking
            switch index {
            case 0, 4, 5: // Tracking parameters
                return String(format: "%.0f%%", (normalizedValue - 0.5) * 200)
            case 1, 2, 3: // Fine tune and offsets
                return String(format: "%.0f¢", (normalizedValue - 0.5) * 100)
            default:
                return String(format: "%.0f", normalizedValue * 127)
            }
        default:
            return String(format: "%.2f", normalizedValue)
        }
    }
    
    /// Update FM parameter
    public func updateFMParameter(page: Int, index: Int, normalizedValue: Double) throws {
        // Store the normalized value
        let key = "\(page).\(index)"
        parameterValues[key] = normalizedValue
        
        guard let fmVoiceMachine = fmVoiceMachine else { return }
        
        switch page {
        case 1: // Core FM
            switch index {
            case 0: // Algorithm
                let algorithmValue = Int(normalizedValue * 4) + 1
                try fmVoiceMachine.updateParameter(key: "algorithm", value: algorithmValue)
            case 1: // Ratio C
                let ratioValue = 0.25 + (normalizedValue * 31.75) // 0.25 to 32.0
                try fmVoiceMachine.updateParameter(key: "operator4_ratio", value: ratioValue)
            case 2: // Ratio A
                let ratioValue = 0.25 + (normalizedValue * 31.75)
                try fmVoiceMachine.updateParameter(key: "operator1_ratio", value: ratioValue)
            case 3: // Ratio B
                let ratioValue = 0.25 + (normalizedValue * 31.75)
                try fmVoiceMachine.updateParameter(key: "operator2_ratio", value: ratioValue)
            case 4: // Harmonic
                try fmVoiceMachine.updateParameter(key: "harmonic", value: normalizedValue * 127)
            case 5: // Detune
                let detuneValue = (normalizedValue - 0.5) * 100 // -50 to +50 cents
                try fmVoiceMachine.updateParameter(key: "detune", value: detuneValue)
            case 6: // Feedback
                try fmVoiceMachine.updateParameter(key: "feedback", value: normalizedValue * 127)
            case 7: // Mix
                try fmVoiceMachine.updateParameter(key: "mix", value: normalizedValue * 127)
            default:
                break
            }
            
        case 2: // Envelopes
            switch index {
            case 0: // ATK A
                try fmVoiceMachine.updateParameter(key: "operator1_attack", value: normalizedValue * 127)
            case 1: // DEC A
                try fmVoiceMachine.updateParameter(key: "operator1_decay", value: normalizedValue * 127)
            case 2: // END A
                try fmVoiceMachine.updateParameter(key: "operator1_end", value: normalizedValue * 127)
            case 3: // LEV A
                try fmVoiceMachine.updateParameter(key: "operator1_level", value: normalizedValue * 127)
            case 4: // ATK B
                try fmVoiceMachine.updateParameter(key: "operator2_attack", value: normalizedValue * 127)
            case 5: // DEC B
                try fmVoiceMachine.updateParameter(key: "operator2_decay", value: normalizedValue * 127)
            case 6: // END B
                try fmVoiceMachine.updateParameter(key: "operator2_end", value: normalizedValue * 127)
            case 7: // LEV B
                try fmVoiceMachine.updateParameter(key: "operator2_level", value: normalizedValue * 127)
            default:
                break
            }
            
        case 3: // Behavior
            switch index {
            case 0: // Delay
                try fmVoiceMachine.updateParameter(key: "envelope_delay", value: normalizedValue * 127)
            case 1: // Trig Mode
                try fmVoiceMachine.updateParameter(key: "trig_mode", value: Int(normalizedValue * 3))
            case 2: // Phase Reset
                try fmVoiceMachine.updateParameter(key: "phase_reset", value: normalizedValue > 0.5 ? 1 : 0)
            case 3: // Velocity
                try fmVoiceMachine.updateParameter(key: "velocity_sensitivity", value: normalizedValue * 127)
            case 4: // Note Priority
                try fmVoiceMachine.updateParameter(key: "note_priority", value: Int(normalizedValue * 2))
            case 5: // Porta Time
                try fmVoiceMachine.updateParameter(key: "porta_time", value: normalizedValue * 127)
            case 6: // Legato
                try fmVoiceMachine.updateParameter(key: "legato", value: normalizedValue > 0.5 ? 1 : 0)
            case 7: // Sustain
                try fmVoiceMachine.updateParameter(key: "sustain_mode", value: normalizedValue > 0.5 ? 1 : 0)
            default:
                break
            }
            
        case 4: // Tracking
            switch index {
            case 0: // Key Track
                let trackValue = (normalizedValue - 0.5) * 200 // -100% to +100%
                try fmVoiceMachine.updateParameter(key: "key_tracking", value: trackValue)
            case 1: // Fine Tune
                let fineValue = (normalizedValue - 0.5) * 100 // -50 to +50 cents
                try fmVoiceMachine.updateParameter(key: "fine_tune", value: fineValue)
            case 2: // Offset A
                let offsetValue = (normalizedValue - 0.5) * 100
                try fmVoiceMachine.updateParameter(key: "operator1_offset", value: offsetValue)
            case 3: // Offset B
                let offsetValue = (normalizedValue - 0.5) * 100
                try fmVoiceMachine.updateParameter(key: "operator2_offset", value: offsetValue)
            case 4: // Track A
                let trackValue = (normalizedValue - 0.5) * 200
                try fmVoiceMachine.updateParameter(key: "operator1_tracking", value: trackValue)
            case 5: // Track B
                let trackValue = (normalizedValue - 0.5) * 200
                try fmVoiceMachine.updateParameter(key: "operator2_tracking", value: trackValue)
            case 6: // Mod Depth
                try fmVoiceMachine.updateParameter(key: "modulation_depth", value: normalizedValue * 127)
            case 7: // Global Level
                try fmVoiceMachine.updateParameter(key: "global_level", value: normalizedValue * 127)
            default:
                break
            }
            
        default:
            break
        }
    }
    
    /// Get current parameter value
    public func getParameterValue(page: Int, index: Int) -> Double {
        let key = "\(page).\(index)"
        return parameterValues[key] ?? getDefaultValue(page: page, index: index)
    }
    
    /// Reset all parameters to defaults
    public func resetParameters() {
        parameterValues.removeAll()
        initializeDefaultValues()
        
        // Update all parameters in the voice machine
        for page in 1...4 {
            for index in 0..<8 {
                let defaultValue = getDefaultValue(page: page, index: index)
                try? updateFMParameter(page: page, index: index, normalizedValue: defaultValue)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func initializeDefaultValues() {
        // Set reasonable defaults for all parameters
        for page in 1...4 {
            for index in 0..<8 {
                let key = "\(page).\(index)"
                parameterValues[key] = getDefaultValue(page: page, index: index)
            }
        }
    }
    
    private func getDefaultValue(page: Int, index: Int) -> Double {
        switch page {
        case 1: // Core FM defaults
            switch index {
            case 0: return 0.0  // Algorithm 1
            case 1, 2, 3: return 0.03125  // Ratios (1.0 out of 32.0)
            case 4: return 0.0  // Harmonic
            case 5: return 0.5  // Detune (centered)
            case 6: return 0.0  // Feedback
            case 7: return 1.0  // Mix (full)
            default: return 0.5
            }
        case 2: // Envelope defaults
            switch index {
            case 0, 4: return 0.0  // Attack (instant)
            case 1, 5: return 0.5  // Decay (medium)
            case 2, 6: return 0.0  // End (zero)
            case 3, 7: return 1.0  // Level (full)
            default: return 0.5
            }
        case 3: // Behavior defaults
            switch index {
            case 0: return 0.0  // Delay
            case 1: return 0.0  // Trig Mode (normal)
            case 2: return 0.0  // Phase Reset (off)
            case 3: return 0.5  // Velocity (medium)
            case 4: return 0.0  // Note Priority (low)
            case 5: return 0.0  // Porta Time
            case 6: return 0.0  // Legato (off)
            case 7: return 0.0  // Sustain (off)
            default: return 0.0
            }
        case 4: // Tracking defaults
            switch index {
            case 0, 4, 5: return 0.5  // Tracking (centered)
            case 1, 2, 3: return 0.5  // Fine/Offsets (centered)
            case 6: return 0.5  // Mod Depth (medium)
            case 7: return 1.0  // Global Level (full)
            default: return 0.5
            }
        default:
            return 0.5
        }
    }
} 