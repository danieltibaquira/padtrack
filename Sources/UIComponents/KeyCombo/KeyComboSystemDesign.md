# Key Combo System Design Document

## Overview

The Key Combo System provides hardware-style key combinations for the DigitonePad application, enabling efficient workflow and professional operation similar to dedicated drum machines and synthesizers.

## Architecture

The system follows VIPER architecture principles with clear separation of concerns:

- **Entity**: Data structures for key combos, actions, and contexts
- **Interactor**: Business logic for detection, validation, and execution
- **Presenter**: Data formatting and view model creation
- **View**: SwiftUI components for visual feedback and help
- **Router**: Navigation for help screens and settings

## Core Components

### 1. Entity Layer

#### KeyCombo
```swift
struct KeyCombo: Identifiable, Codable {
    let id: String
    let modifier: KeyModifier
    let key: Key
    let context: KeyComboContext
    let action: KeyComboAction
    let description: String
    let shortDescription: String
    let isEnabled: Bool
    let priority: Int
    let category: KeyComboCategory
}
```

#### KeyModifier
```swift
enum KeyModifier: String, CaseIterable, Codable {
    case func = "FUNC"
    case shift = "SHIFT"
    case alt = "ALT"
    
    var symbol: String {
        switch self {
        case .func: return "⚙️"
        case .shift: return "⇧"
        case .alt: return "⌥"
        }
    }
}
```

#### Key
```swift
enum Key: Codable, Hashable {
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
    
    var symbol: String {
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
        }
    }
    
    var isModifier: Bool {
        return false // Only KeyModifier enum contains modifiers
    }
}
```

#### KeyComboContext
```swift
struct KeyComboContext: Codable {
    let mode: AppMode
    let subMode: String?
    let conditions: [String: String]
    
    enum AppMode: String, CaseIterable, Codable {
        case pattern = "pattern"
        case kit = "kit"
        case song = "song"
        case performance = "performance"
        case settings = "settings"
    }
}
```

#### KeyComboAction
```swift
struct KeyComboAction: Codable {
    let type: ActionType
    let parameters: [String: String]
    let target: String?
    
    enum ActionType: String, CaseIterable, Codable {
        case navigation = "navigation"
        case playback = "playback"
        case recording = "recording"
        case parameter = "parameter"
        case pattern = "pattern"
        case kit = "kit"
        case effect = "effect"
        case system = "system"
    }
}
```

### 2. Interactor Layer

#### KeyComboInteractorProtocol
```swift
protocol KeyComboInteractorProtocol: AnyObject {
    func registerKeyCombo(_ combo: KeyCombo)
    func unregisterKeyCombo(id: String)
    func detectKeyCombo(modifier: KeyModifier, key: Key) -> KeyCombo?
    func executeKeyCombo(_ combo: KeyCombo) throws
    func getAvailableCombos(for context: KeyComboContext) -> [KeyCombo]
    func isComboAvailable(_ combo: KeyCombo) -> Bool
    func updateContext(_ context: KeyComboContext)
    func enableCombo(id: String)
    func disableCombo(id: String)
}
```

#### KeyComboInteractor
```swift
class KeyComboInteractor: KeyComboInteractorProtocol {
    private let registry: KeyComboRegistry
    private let contextProvider: KeyComboContextProvider
    private let actionExecutor: KeyComboActionExecutor
    private weak var presenter: KeyComboPresenterProtocol?
    
    private var currentContext: KeyComboContext
    private var isEnabled: Bool = true
    
    init(
        registry: KeyComboRegistry,
        contextProvider: KeyComboContextProvider,
        actionExecutor: KeyComboActionExecutor,
        presenter: KeyComboPresenterProtocol?
    ) {
        self.registry = registry
        self.contextProvider = contextProvider
        self.actionExecutor = actionExecutor
        self.presenter = presenter
        self.currentContext = contextProvider.getCurrentContext()
    }
    
    // Implementation methods...
}
```

### 3. Presenter Layer

#### KeyComboPresenterProtocol
```swift
protocol KeyComboPresenterProtocol: AnyObject {
    func presentAvailableCombos(_ combos: [KeyCombo])
    func presentComboExecuted(_ combo: KeyCombo, result: KeyComboExecutionResult)
    func presentComboFailed(_ combo: KeyCombo, error: KeyComboError)
    func presentComboHelp(_ combos: [KeyCombo])
    func presentVisualFeedback(for combo: KeyCombo)
    func presentContextChanged(_ context: KeyComboContext)
}
```

#### KeyComboViewModel
```swift
struct KeyComboViewModel: Identifiable {
    let id: String
    let displayText: String
    let description: String
    let shortDescription: String
    let isHighlighted: Bool
    let isEnabled: Bool
    let category: String
    let priority: Int
    let modifierSymbol: String
    let keySymbol: String
}
```

### 4. View Layer

#### KeyComboViewProtocol
```swift
protocol KeyComboViewProtocol: AnyObject {
    func showAvailableCombos(_ combos: [KeyComboViewModel])
    func highlightCombo(_ combo: KeyComboViewModel)
    func showComboFeedback(_ combo: KeyComboViewModel, success: Bool)
    func showComboHelp(_ combos: [KeyComboViewModel])
    func hideComboOverlay()
    func updateContextIndicator(_ context: String)
}
```

### 5. Router Layer

#### KeyComboRouterProtocol
```swift
protocol KeyComboRouterProtocol: AnyObject {
    func showComboHelp()
    func showComboSettings()
    func dismissComboHelp()
    func navigateToTarget(_ target: String)
}
```

## Key Detection System

### KeyComboDetector
```swift
class KeyComboDetector: ObservableObject {
    @Published var activeModifiers: Set<KeyModifier> = []
    @Published var isDetectionActive: Bool = false
    
    private var keyPressTimestamps: [Key: Date] = [:]
    private var comboExecutionWindow: TimeInterval = 2.0
    private var debounceInterval: TimeInterval = 0.1
    
    private weak var interactor: KeyComboInteractorProtocol?
    
    func handleKeyPress(_ key: Key) {
        let now = Date()
        
        // Debounce rapid key presses
        if let lastPress = keyPressTimestamps[key],
           now.timeIntervalSince(lastPress) < debounceInterval {
            return
        }
        
        keyPressTimestamps[key] = now
        
        if let modifier = key.asModifier {
            handleModifierPress(modifier)
        } else {
            handleRegularKeyPress(key)
        }
    }
    
    func handleKeyRelease(_ key: Key) {
        if let modifier = key.asModifier {
            handleModifierRelease(modifier)
        }
    }
    
    private func handleModifierPress(_ modifier: KeyModifier) {
        activeModifiers.insert(modifier)
        isDetectionActive = true
        startComboDetectionWindow()
    }
    
    private func handleModifierRelease(_ modifier: KeyModifier) {
        activeModifiers.remove(modifier)
        if activeModifiers.isEmpty {
            isDetectionActive = false
            endComboDetectionWindow()
        }
    }
    
    private func handleRegularKeyPress(_ key: Key) {
        guard isDetectionActive, !activeModifiers.isEmpty else { return }
        
        for modifier in activeModifiers {
            if let combo = interactor?.detectKeyCombo(modifier: modifier, key: key) {
                executeCombo(combo)
                break
            }
        }
    }
}
```

## Default Key Combinations

### Pattern Mode
- FUNC + Pad 1-16: Select pattern
- FUNC + PLAY: Toggle loop mode
- FUNC + STOP: Clear current pattern
- FUNC + REC: Toggle pattern recording
- FUNC + TEMPO: Tap tempo

### Kit Mode
- FUNC + Pad 1-16: Load kit
- FUNC + LEVEL: Master volume
- FUNC + SWING: Adjust swing amount

### Song Mode
- FUNC + Pad 1-16: Chain patterns
- FUNC + PLAY: Play song
- FUNC + STOP: Stop song

### Performance Mode
- FUNC + Pad 1-16: Trigger effects
- FUNC + LEVEL: Performance volume
- FUNC + SWING: Performance swing

## Visual Feedback System

### Overlay Components
1. **Combo Indicator**: Shows current modifier state
2. **Available Combos**: Highlights available targets
3. **Execution Feedback**: Success/failure animations
4. **Help System**: Searchable combo reference

### Animation States
- **Modifier Active**: Subtle glow on modifier key
- **Target Highlight**: Pulse animation on available targets
- **Execution Success**: Green flash and checkmark
- **Execution Failure**: Red flash and X mark
- **Help Overlay**: Slide-in animation with combo list

## Integration Points

### With Existing Modules
- **SequencerModule**: Pattern and playback control
- **VoiceModule**: Kit and voice parameter control
- **DataLayer**: Combo preferences and custom combos
- **AppShell**: Context detection and state management
- **UIComponents**: Visual feedback and help system

### Event Flow
1. User interaction → KeyComboDetector
2. Key detection → KeyComboInteractor
3. Combo validation → KeyComboActionExecutor
4. Action execution → Target module
5. Result feedback → KeyComboPresenter
6. Visual update → KeyComboView

## Testing Strategy

### Unit Tests
- KeyCombo entity validation
- Interactor business logic
- Presenter view model creation
- Action executor functionality

### Integration Tests
- Key detection timing
- Context switching
- Cross-module action execution
- Visual feedback coordination

### UI Tests
- Combo help system navigation
- Visual feedback animations
- Accessibility compliance
- Multi-touch scenarios

### Performance Tests
- Rapid combo execution
- Memory usage during detection
- Animation performance
- Large combo registry handling

## Error Handling

### KeyComboError
```swift
enum KeyComboError: Error, LocalizedError {
    case comboNotFound
    case comboDisabled
    case invalidContext
    case actionExecutionFailed(String)
    case detectionTimeout
    
    var errorDescription: String? {
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
        }
    }
}
```

## Configuration and Customization

### User Preferences
- Enable/disable specific combos
- Customize combo timing
- Visual feedback preferences
- Help system behavior

### Developer Configuration
- Register custom combos
- Define context-specific behavior
- Extend action types
- Customize visual themes

## Sequence Diagrams

### 1. Basic Key Combo Execution Flow

```
User                KeyComboDetector    KeyComboInteractor    KeyComboPresenter    KeyComboView
 |                        |                    |                    |                |
 |--[Press FUNC]--------->|                    |                    |                |
 |                        |--[Modifier Active]->|                    |                |
 |                        |                    |--[Get Available]--->|                |
 |                        |                    |                    |--[Show Overlay]->|
 |--[Press Pad 1]-------->|                    |                    |                |
 |                        |--[Detect Combo]--->|                    |                |
 |                        |                    |--[Execute Action]-->|                |
 |                        |                    |                    |--[Show Success]->|
 |--[Release FUNC]------->|                    |                    |                |
 |                        |--[End Detection]-->|                    |                |
 |                        |                    |                    |--[Hide Overlay]->|
```

### 2. Context-Sensitive Combo Flow

```
AppShell            ContextProvider    KeyComboInteractor    KeyComboPresenter    KeyComboView
 |                        |                    |                    |                |
 |--[Mode Change]-------->|                    |                    |                |
 |                        |--[Update Context]->|                    |                |
 |                        |                    |--[Refresh Combos]->|                |
 |                        |                    |                    |--[Update UI]--->|
 |                        |                    |                    |                |
 |                        |<--[Context Query]--|                    |                |
 |                        |--[Current Context]->|                    |                |
```

### 3. Error Handling Flow

```
User                KeyComboDetector    KeyComboInteractor    KeyComboPresenter    KeyComboView
 |                        |                    |                    |                |
 |--[Invalid Combo]------>|                    |                    |                |
 |                        |--[Detect Combo]--->|                    |                |
 |                        |                    |--[Validation Fail]->|                |
 |                        |                    |                    |--[Show Error]-->|
 |                        |                    |<--[Error Handled]---|                |
 |                        |<--[Reset State]----|                    |                |
```

This design provides a comprehensive, extensible key combo system that integrates seamlessly with the DigitonePad application while maintaining professional drum machine workflow patterns.
