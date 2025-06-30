import SwiftUI
import Combine

// MARK: - Key Combo Router Protocol

/// Protocol for Key Combo routing
public protocol KeyComboRouterProtocol: AnyObject {
    func showComboHelp()
    func showComboSettings()
    func dismissComboHelp()
    func navigateToTarget(_ target: String)
    func showComboCustomization()
    func showComboTutorial()
}

// MARK: - Key Combo Router

/// Router for handling Key Combo navigation
@MainActor
public class KeyComboRouter: KeyComboRouterProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isShowingHelp: Bool = false
    @Published public var isShowingSettings: Bool = false
    @Published public var isShowingCustomization: Bool = false
    @Published public var isShowingTutorial: Bool = false
    @Published public var navigationTarget: String = ""
    
    // MARK: - Properties
    
    public weak var presenter: KeyComboPresenter?
    private weak var appRouter: AppRouterProtocol?
    
    // MARK: - Initialization
    
    public init(appRouter: AppRouterProtocol? = nil) {
        self.appRouter = appRouter
    }
    
    // MARK: - KeyComboRouterProtocol Implementation
    
    nonisolated public func showComboHelp() {
        Task { @MainActor in
            isShowingHelp = true
        }
    }
    
    nonisolated public func showComboSettings() {
        Task { @MainActor in
            isShowingSettings = true
        }
    }
    
    nonisolated public func dismissComboHelp() {
        Task { @MainActor in
            isShowingHelp = false
        }
    }
    
    nonisolated public func navigateToTarget(_ target: String) {
        Task { @MainActor in
            navigationTarget = target
        }
    }
    
    nonisolated public func showComboCustomization() {
        Task { @MainActor in
            isShowingCustomization = true
        }
    }
    
    nonisolated public func showComboTutorial() {
        Task { @MainActor in
            isShowingTutorial = true
        }
    }
    
    // MARK: - Public Methods
    
    /// Dismisses all overlays
    public func dismissAllOverlays() {
        isShowingHelp = false
        isShowingSettings = false
        isShowingCustomization = false
        isShowingTutorial = false
    }
    
    /// Shows context-specific help
    public func showContextHelp(for context: KeyComboContext) {
        // This would show help specific to the current context
        showComboHelp()
    }
}

// MARK: - App Router Protocol

/// Protocol for the main app router (to be implemented by the main app)
public protocol AppRouterProtocol: AnyObject {
    func navigateToMainMenu()
    func navigateToPatternMode()
    func navigateToKitMode()
    func navigateToSongMode()
    func navigateToPerformanceMode()
    func navigateToSettings()
}

// MARK: - Key Combo Module Factory

/// Factory for creating Key Combo VIPER components
public enum KeyComboModuleFactory {
    
    /// Creates a complete Key Combo module with all VIPER components
    @MainActor
    public static func createModule(
        appRouter: AppRouterProtocol? = nil,
        initialContext: KeyComboContext = KeyComboContext(mode: .pattern)
    ) -> KeyComboModule {
        
        // Create components
        let router = KeyComboRouter(appRouter: appRouter)
        let presenter = KeyComboPresenter()
        let registry = KeyComboRegistry()
        let contextProvider = KeyComboContextProvider(initialContext: initialContext)
        let actionExecutor = KeyComboActionExecutor()
        let detector = KeyComboDetector()
        let interactor = KeyComboInteractor(
            registry: registry,
            contextProvider: contextProvider,
            actionExecutor: actionExecutor,
            detector: detector,
            presenter: presenter
        )
        let view = KeyComboView(presenter: presenter, detector: detector)
        
        return KeyComboModule(
            view: view,
            interactor: interactor,
            presenter: presenter,
            router: router
        )
    }
}

// MARK: - Key Combo Module

/// Complete Key Combo module containing all VIPER components
public struct KeyComboModule {
    public let view: KeyComboView
    public let interactor: KeyComboInteractor
    public let presenter: KeyComboPresenter
    public let router: KeyComboRouter
    
    public init(
        view: KeyComboView,
        interactor: KeyComboInteractor,
        presenter: KeyComboPresenter,
        router: KeyComboRouter
    ) {
        self.view = view
        self.interactor = interactor
        self.presenter = presenter
        self.router = router
    }
    
    /// Configures the module with custom action handlers
    public func configureActionHandlers() {
        // Example: Register custom action handlers
        interactor.actionExecutor.registerHandler(for: .navigation) { combo in
            // Handle navigation actions
            return KeyComboExecutionResult(
                success: true,
                message: "Navigation executed: \(combo.action.parameters["action"] ?? "unknown")"
            )
        }
        
        interactor.actionExecutor.registerHandler(for: .playback) { combo in
            // Handle playback actions
            return KeyComboExecutionResult(
                success: true,
                message: "Playback action executed: \(combo.action.parameters["action"] ?? "unknown")"
            )
        }
        
        // Add more custom handlers as needed
    }
    
    /// Updates the current context
    public func updateContext(_ context: KeyComboContext) {
        interactor.updateContext(context)
    }
    
    /// Enables or disables the key combo system
    public func setEnabled(_ enabled: Bool) {
        interactor.setEnabled(enabled)
    }
    
    /// Registers a custom key combo
    public func registerCustomCombo(_ combo: KeyCombo) {
        interactor.registerKeyCombo(combo)
    }
    
    /// Shows the help overlay
    public func showHelp() {
        router.showComboHelp()
    }
    
    /// Handles a key press event
    public func handleKeyPress(_ key: Key) {
        interactor.detector.handleKeyPress(key)
    }
    
    /// Handles a key release event
    public func handleKeyRelease(_ key: Key) {
        interactor.detector.handleKeyRelease(key)
    }
}

// MARK: - Extensions

extension KeyComboModule {
    /// Creates a SwiftUI view that can be embedded in the app
    public func createEmbeddableView() -> some View {
        view
            .environmentObject(interactor)
            .environmentObject(presenter)
            .environmentObject(router)
    }
    
    /// Gets the current statistics
    public var statistics: KeyComboStatistics {
        return interactor.statistics
    }
    
    /// Exports the current configuration
    public func exportConfiguration() -> [String: Any] {
        return [
            "combos": interactor.registry.exportCombos(),
            "context": [
                "mode": interactor.contextProvider.getCurrentContext().mode.rawValue,
                "subMode": interactor.contextProvider.getCurrentContext().subMode ?? "",
                "conditions": interactor.contextProvider.getCurrentContext().conditions
            ]
        ]
    }
    
    /// Imports a configuration
    public func importConfiguration(_ config: [String: Any]) {
        if let combos = config["combos"] as? [String: Any] {
            interactor.registry.importCombos(from: combos)
        }
        
        if let contextData = config["context"] as? [String: Any],
           let modeString = contextData["mode"] as? String,
           let mode = KeyComboContext.AppMode(rawValue: modeString) {
            let subMode = contextData["subMode"] as? String
            let conditions = contextData["conditions"] as? [String: String] ?? [:]
            
            let context = KeyComboContext(mode: mode, subMode: subMode, conditions: conditions)
            updateContext(context)
        }
    }
}
