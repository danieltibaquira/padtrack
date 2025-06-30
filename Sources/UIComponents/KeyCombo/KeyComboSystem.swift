import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

// MARK: - Key Combo System

/// Main system for managing key combinations throughout the app
public class KeyComboSystem: ObservableObject {
    
    // MARK: - Properties
    
    public let module: KeyComboModule
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    @MainActor
    public init(appRouter: AppRouterProtocol? = nil) {
        self.module = KeyComboModuleFactory.createModule(appRouter: appRouter)
        setupDefaultConfiguration()
        setupSystemIntegration()
    }
    
    // MARK: - Public Interface
    
    /// Updates the current application context
    public func updateContext(mode: KeyComboContext.AppMode, subMode: String? = nil, conditions: [String: String] = [:]) {
        let context = KeyComboContext(mode: mode, subMode: subMode, conditions: conditions)
        module.updateContext(context)
    }
    
    /// Handles hardware or software key events
    public func handleKeyEvent(_ key: Key, isPressed: Bool) {
        if isPressed {
            module.handleKeyPress(key)
        } else {
            module.handleKeyRelease(key)
        }
    }
    
    /// Registers a custom key combination
    public func registerCustomCombo(
        id: String,
        modifier: KeyModifier,
        key: Key,
        context: KeyComboContext,
        action: KeyComboAction,
        description: String,
        category: KeyComboCategory = .general
    ) {
        let combo = KeyCombo(
            id: id,
            modifier: modifier,
            key: key,
            context: context,
            action: action,
            description: description,
            shortDescription: description,
            isEnabled: true,
            priority: 5,
            category: category
        )
        
        module.registerCustomCombo(combo)
    }
    
    /// Shows the key combo help overlay
    public func showHelp() {
        module.showHelp()
    }
    
    /// Enables or disables the entire system
    public func setEnabled(_ enabled: Bool) {
        module.setEnabled(enabled)
    }
    
    /// Gets current system statistics
    public var statistics: KeyComboStatistics {
        return module.statistics
    }
    
    /// Creates the main view for embedding in the app
    public func createView() -> some View {
        module.createEmbeddableView()
    }
    
    // MARK: - Configuration
    
    /// Exports the current system configuration
    public func exportConfiguration() -> Data? {
        let config = module.exportConfiguration()
        return try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
    }
    
    /// Imports a system configuration
    public func importConfiguration(from data: Data) throws {
        let config = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let config = config {
            module.importConfiguration(config)
        }
    }
    
    /// Resets to default configuration
    public func resetToDefaults() {
        module.interactor.registry.clear()
        setupDefaultConfiguration()
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultConfiguration() {
        module.configureActionHandlers()
        
        // Register additional system-specific combos
        registerSystemCombos()
    }
    
    private func setupSystemIntegration() {
        // Observe system events and update context accordingly
        // This would integrate with the main app's state management
        
        // Example: Listen for app state changes
        #if os(iOS)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppBecameActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppWillResignActive()
            }
            .store(in: &cancellables)
        #endif
    }
    
    private func registerSystemCombos() {
        // Help combo (available in all contexts)
        let helpCombo = KeyCombo(
            id: "system_help",
            modifier: .func,
            key: .menu,
            context: KeyComboContext(mode: .pattern), // Will be duplicated for other modes
            action: KeyComboAction(type: .system, parameters: ["action": "show_help"]),
            description: "Show key combination help",
            shortDescription: "Help",
            isEnabled: true,
            priority: 10,
            category: .system
        )
        
        // Register for all modes
        for mode in KeyComboContext.AppMode.allCases {
            var modeSpecificCombo = helpCombo
            modeSpecificCombo.id = "system_help_\(mode.rawValue)"
            modeSpecificCombo.context = KeyComboContext(mode: mode)
            module.registerCustomCombo(modeSpecificCombo)
        }
        
        // Quick mode switching combos
        let modeComboData: [(KeyComboContext.AppMode, Key, String)] = [
            (.pattern, .pattern, "Switch to Pattern mode"),
            (.kit, .kit, "Switch to Kit mode"),
            (.song, .song, "Switch to Song mode"),
            (.performance, .performance, "Switch to Performance mode")
        ]
        
        for (mode, key, description) in modeComboData {
            let combo = KeyCombo(
                id: "switch_to_\(mode.rawValue)",
                modifier: .alt,
                key: key,
                context: KeyComboContext(mode: .pattern), // Available from any mode
                action: KeyComboAction(type: .navigation, parameters: ["target": "\(mode.rawValue)_mode"]),
                description: description,
                shortDescription: mode.displayName,
                isEnabled: true,
                priority: 8,
                category: .navigation
            )
            module.registerCustomCombo(combo)
        }
    }
    
    private func handleAppBecameActive() {
        // Re-enable key combo detection when app becomes active
        setEnabled(true)
    }
    
    private func handleAppWillResignActive() {
        // Disable key combo detection when app goes to background
        setEnabled(false)
        
        // Dismiss any open overlays
        let router = module.router
        Task { @MainActor in
            router.dismissAllOverlays()
        }
    }
}

// MARK: - SwiftUI Integration

/// SwiftUI view modifier for integrating key combo system
public struct KeyComboModifier: ViewModifier {
    @StateObject private var keyComboSystem: KeyComboSystem
    
    public init(appRouter: AppRouterProtocol? = nil) {
        self._keyComboSystem = StateObject(wrappedValue: KeyComboSystem(appRouter: appRouter))
    }
    
    public func body(content: Content) -> some View {
        ZStack {
            content
            
            // Key combo overlay
            keyComboSystem.createView()
        }
        .environmentObject(keyComboSystem)
    }
}

extension View {
    /// Adds key combo support to any view
    public func keyComboSupport(appRouter: AppRouterProtocol? = nil) -> some View {
        modifier(KeyComboModifier(appRouter: appRouter))
    }
}

// MARK: - Hardware Integration Support

/// Protocol for hardware key integration
public protocol HardwareKeyDelegate: AnyObject {
    func hardwareKeyPressed(_ key: Key)
    func hardwareKeyReleased(_ key: Key)
}

extension KeyComboSystem: HardwareKeyDelegate {
    public func hardwareKeyPressed(_ key: Key) {
        handleKeyEvent(key, isPressed: true)
    }
    
    public func hardwareKeyReleased(_ key: Key) {
        handleKeyEvent(key, isPressed: false)
    }
}

// MARK: - Accessibility Support

extension KeyComboSystem {
    /// Configures accessibility features for the key combo system
    public func configureAccessibility() {
        // Register accessibility-specific combos
        let accessibilityCombo = KeyCombo(
            id: "accessibility_announce",
            modifier: .alt,
            key: .menu,
            context: KeyComboContext(mode: .pattern),
            action: KeyComboAction(type: .system, parameters: ["action": "announce_context"]),
            description: "Announce current context and available actions",
            shortDescription: "Announce",
            isEnabled: true,
            priority: 9,
            category: .system
        )
        
        module.registerCustomCombo(accessibilityCombo)
        
        // Configure action handler for accessibility announcements
        module.interactor.actionExecutor.registerHandler(for: .system) { combo in
            if combo.action.parameters["action"] == "announce_context" {
                self.announceCurrentContext()
                return KeyComboExecutionResult(success: true, message: "Context announced")
            }
            
            return KeyComboExecutionResult(success: false, message: "Unknown system action")
        }
    }
    
    private func announceCurrentContext() {
        let context = module.interactor.contextProvider.getCurrentContext()
        let availableCombos = module.interactor.getAvailableCombos(for: context)
        
        let announcement = """
        Current mode: \(context.mode.displayName).
        \(availableCombos.count) key combinations available.
        Press Function plus Menu for help.
        """
        
        // Use iOS accessibility API to announce
        DispatchQueue.main.async {
            #if os(iOS)
            UIAccessibility.post(notification: .announcement, argument: announcement)
            #endif
        }
    }
}

// MARK: - Debug Support

extension KeyComboSystem {
    /// Enables debug mode with additional logging
    public func enableDebugMode() {
        // Add debug logging to key events
        module.interactor.detector.objectWillChange
            .sink { [weak self] in
                self?.logDebugInfo()
            }
            .store(in: &cancellables)
    }
    
    private func logDebugInfo() {
        let debugInfo = module.interactor.detector.debugInfo
        print("KeyComboSystem Debug: \(debugInfo)")
    }
    
    /// Gets comprehensive debug information
    public var debugInfo: [String: Any] {
        return [
            "statistics": [
                "totalCombos": statistics.totalCombos,
                "enabledCombos": statistics.enabledCombos,
                "availableCombos": statistics.availableCombos,
                "currentMode": statistics.currentMode
            ],
            "detector": module.interactor.detector.debugInfo,
            "context": [
                "mode": module.interactor.contextProvider.getCurrentContext().mode.rawValue,
                "subMode": module.interactor.contextProvider.getCurrentContext().subMode ?? "none",
                "conditions": module.interactor.contextProvider.getCurrentContext().conditions
            ]
        ]
    }
}
