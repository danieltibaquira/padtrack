import Foundation

// MARK: - Core Key Combo Entities

/// Represents a key combination that can be executed
public struct KeyCombo: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public let modifier: KeyModifier
    public let key: Key
    public var context: KeyComboContext
    public let action: KeyComboAction
    public let description: String
    public let shortDescription: String
    public var isEnabled: Bool
    public let priority: Int
    public let category: KeyComboCategory
    
    public init(
        id: String,
        modifier: KeyModifier,
        key: Key,
        context: KeyComboContext,
        action: KeyComboAction,
        description: String,
        shortDescription: String,
        isEnabled: Bool = true,
        priority: Int = 5,
        category: KeyComboCategory = .general
    ) {
        self.id = id
        self.modifier = modifier
        self.key = key
        self.context = context
        self.action = action
        self.description = description
        self.shortDescription = shortDescription
        self.isEnabled = isEnabled
        self.priority = priority
        self.category = category
    }
    
    /// Returns the display text for this combo
    public var displayText: String {
        return "\(modifier.symbol) + \(key.symbol)"
    }
    
    /// Returns true if this combo is available in the given context
    public func isAvailable(in context: KeyComboContext) -> Bool {
        guard isEnabled else { return false }
        
        // Check mode compatibility
        if self.context.mode != context.mode {
            return false
        }
        
        // Check sub-mode compatibility if specified
        if let requiredSubMode = self.context.subMode,
           let currentSubMode = context.subMode,
           requiredSubMode != currentSubMode {
            return false
        }
        
        // Check conditions
        for (key, value) in self.context.conditions {
            if context.conditions[key] != value {
                return false
            }
        }
        
        return true
    }
}

/// Key modifiers for combinations
public enum KeyModifier: String, CaseIterable, Codable, Hashable, Sendable {
    case `func` = "FUNC"
    case shift = "SHIFT"
    case alt = "ALT"
    
    public var symbol: String {
        switch self {
        case .func: return "⚙️"
        case .shift: return "⇧"
        case .alt: return "⌥"
        }
    }
    
    public var displayName: String {
        return rawValue
    }
}

/// Keys that can be used in combinations
public enum Key: Codable, Hashable, Sendable {
    case pad(Int)           // Pad 1-16
    case play
    case stop
    case record
    case tempo
    case swing
    case level
    case pattern
    case kit
    case song
    case performance
    case menu
    case back
    case `func`               // FUNC key itself (for modifier detection)
    case shift              // SHIFT key itself
    case alt                // ALT key itself
    
    public var symbol: String {
        switch self {
        case .pad(let number): return "P\(number)"
        case .play: return "▶️"
        case .stop: return "⏹️"
        case .record: return "⏺️"
        case .tempo: return "🎵"
        case .swing: return "🎶"
        case .level: return "🔊"
        case .pattern: return "📋"
        case .kit: return "🥁"
        case .song: return "🎼"
        case .performance: return "🎭"
        case .menu: return "☰"
        case .back: return "←"
        case .func: return "⚙️"
        case .shift: return "⇧"
        case .alt: return "⌥"
        }
    }
    
    public var displayName: String {
        switch self {
        case .pad(let number): return "Pad \(number)"
        case .play: return "Play"
        case .stop: return "Stop"
        case .record: return "Record"
        case .tempo: return "Tempo"
        case .swing: return "Swing"
        case .level: return "Level"
        case .pattern: return "Pattern"
        case .kit: return "Kit"
        case .song: return "Song"
        case .performance: return "Performance"
        case .menu: return "Menu"
        case .back: return "Back"
        case .func: return "Function"
        case .shift: return "Shift"
        case .alt: return "Alt"
        }
    }
    
    /// Returns true if this key is a modifier key
    public var isModifier: Bool {
        switch self {
        case .func, .shift, .alt:
            return true
        default:
            return false
        }
    }
    
    /// Converts this key to a modifier if it is one
    public var asModifier: KeyModifier? {
        switch self {
        case .func: return .func
        case .shift: return .shift
        case .alt: return .alt
        default: return nil
        }
    }
}

/// Context in which a key combo is available
public struct KeyComboContext: Codable, Hashable, Sendable {
    public let mode: AppMode
    public let subMode: String?
    public let conditions: [String: String]
    
    public init(mode: AppMode, subMode: String? = nil, conditions: [String: String] = [:]) {
        self.mode = mode
        self.subMode = subMode
        self.conditions = conditions
    }
    
    /// Application modes
    public enum AppMode: String, CaseIterable, Codable, Hashable, Sendable {
        case pattern = "pattern"
        case kit = "kit"
        case song = "song"
        case performance = "performance"
        case settings = "settings"
        
        public var displayName: String {
            return rawValue.capitalized
        }
    }
}

/// Action to be executed when a key combo is triggered
public struct KeyComboAction: Codable, Hashable, Sendable {
    public let type: ActionType
    public let parameters: [String: String]
    public let target: String?
    
    public init(type: ActionType, parameters: [String: String] = [:], target: String? = nil) {
        self.type = type
        self.parameters = parameters
        self.target = target
    }
    
    /// Types of actions that can be executed
    public enum ActionType: String, CaseIterable, Codable, Hashable, Sendable {
        case navigation = "navigation"
        case playback = "playback"
        case recording = "recording"
        case parameter = "parameter"
        case pattern = "pattern"
        case kit = "kit"
        case effect = "effect"
        case system = "system"
        
        public var displayName: String {
            return rawValue.capitalized
        }
    }
}

/// Categories for organizing key combos
public enum KeyComboCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case general = "general"
    case pattern = "pattern"
    case kit = "kit"
    case playback = "playback"
    case recording = "recording"
    case navigation = "navigation"
    case system = "system"
    case effects = "effects"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var icon: String {
        switch self {
        case .general: return "⚙️"
        case .pattern: return "📋"
        case .kit: return "🥁"
        case .playback: return "▶️"
        case .recording: return "⏺️"
        case .navigation: return "🧭"
        case .system: return "💻"
        case .effects: return "✨"
        }
    }
}

/// Result of executing a key combo action
public struct KeyComboExecutionResult: Codable {
    public let success: Bool
    public let message: String
    public let data: [String: String]?
    
    public init(success: Bool, message: String, data: [String: String]? = nil) {
        self.success = success
        self.message = message
        self.data = data
    }
}

/// Errors that can occur during key combo operations
public enum KeyComboError: Error, LocalizedError, Equatable {
    case comboNotFound
    case comboDisabled
    case invalidContext
    case actionExecutionFailed(String)
    case detectionTimeout
    case invalidModifier
    case invalidKey
    case registrationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .comboNotFound:
            return "Key combination not recognized"
        case .comboDisabled:
            return "Key combination is currently disabled"
        case .invalidContext:
            return "Key combination not available in current mode"
        case .actionExecutionFailed(let message):
            return "Failed to execute action: \(message)"
        case .detectionTimeout:
            return "Key combination timed out"
        case .invalidModifier:
            return "Invalid modifier key"
        case .invalidKey:
            return "Invalid key"
        case .registrationFailed(let message):
            return "Failed to register key combination: \(message)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .comboNotFound:
            return "Check the available key combinations in the help menu"
        case .comboDisabled:
            return "Enable the key combination in settings"
        case .invalidContext:
            return "Switch to the appropriate mode for this combination"
        case .actionExecutionFailed:
            return "Try the action again or check system status"
        case .detectionTimeout:
            return "Press the key combination more quickly"
        case .invalidModifier, .invalidKey:
            return "Use a valid key combination"
        case .registrationFailed:
            return "Check for duplicate key combinations"
        }
    }
}

// MARK: - Extensions

extension KeyCombo {
    /// Creates a default key combo for testing
    public static func createDefault(
        id: String = "default",
        modifier: KeyModifier = .func,
        key: Key = .pad(1)
    ) -> KeyCombo {
        return KeyCombo(
            id: id,
            modifier: modifier,
            key: key,
            context: KeyComboContext(mode: .pattern),
            action: KeyComboAction(type: .pattern),
            description: "Default key combo",
            shortDescription: "Default",
            isEnabled: true,
            priority: 5,
            category: .general
        )
    }
}

extension KeyComboContext {
    /// Creates a default context for testing
    public static func createDefault(mode: AppMode = .pattern) -> KeyComboContext {
        return KeyComboContext(mode: mode, subMode: nil, conditions: [:])
    }
}

extension KeyComboAction {
    /// Creates a default action for testing
    public static func createDefault(type: ActionType = .pattern) -> KeyComboAction {
        return KeyComboAction(type: type, parameters: [:], target: nil)
    }
}
