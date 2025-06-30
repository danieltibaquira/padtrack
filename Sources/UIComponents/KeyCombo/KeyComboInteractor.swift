import Foundation
import Combine

// MARK: - Protocols

/// Protocol for the Key Combo Interactor
public protocol KeyComboInteractorProtocol: AnyObject {
    var presenter: KeyComboPresenterProtocol? { get set }
    
    func registerKeyCombo(_ combo: KeyCombo)
    func unregisterKeyCombo(id: String)
    func detectKeyCombo(modifier: KeyModifier, key: Key) -> KeyCombo?
    func executeKeyCombo(_ combo: KeyCombo) throws
    func getAvailableCombos(for context: KeyComboContext) -> [KeyCombo]
    func isComboAvailable(_ combo: KeyCombo) -> Bool
    func updateContext(_ context: KeyComboContext)
    func enableCombo(id: String)
    func disableCombo(id: String)
    func getCurrentContext() -> KeyComboContext
}

/// Protocol for the Key Combo Presenter
public protocol KeyComboPresenterProtocol: AnyObject {
    func presentAvailableCombos(_ combos: [KeyCombo])
    func presentComboExecuted(_ combo: KeyCombo, result: KeyComboExecutionResult)
    func presentComboFailed(_ combo: KeyCombo, error: KeyComboError)
    func presentComboHelp(_ combos: [KeyCombo])
    func presentVisualFeedback(for combo: KeyCombo)
    func presentContextChanged(_ context: KeyComboContext)
}

// MARK: - Key Combo Interactor

/// Interactor for handling key combo business logic
public class KeyComboInteractor: KeyComboInteractorProtocol, ObservableObject {
    
    // MARK: - Properties
    
    public weak var presenter: KeyComboPresenterProtocol?
    
    let registry: KeyComboRegistry
    let contextProvider: KeyComboContextProvider
    let actionExecutor: KeyComboActionExecutor
    let detector: KeyComboDetector
    
    @Published private var currentContext: KeyComboContext
    @Published private var isEnabled: Bool = true
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(
        registry: KeyComboRegistry,
        contextProvider: KeyComboContextProvider,
        actionExecutor: KeyComboActionExecutor,
        detector: KeyComboDetector,
        presenter: KeyComboPresenterProtocol? = nil
    ) {
        self.registry = registry
        self.contextProvider = contextProvider
        self.actionExecutor = actionExecutor
        self.detector = detector
        self.presenter = presenter
        self.currentContext = contextProvider.getCurrentContext()
        
        setupContextObservation()
    }
    
    // MARK: - KeyComboInteractorProtocol Implementation
    
    public func registerKeyCombo(_ combo: KeyCombo) {
        registry.register(combo)
    }
    
    public func unregisterKeyCombo(id: String) {
        registry.unregister(id: id)
    }
    
    public func detectKeyCombo(modifier: KeyModifier, key: Key) -> KeyCombo? {
        guard isEnabled else { return nil }
        
        let combo = registry.findCombo(modifier: modifier, key: key)
        
        // Check if combo is available in current context
        if let combo = combo, isComboAvailable(combo) {
            return combo
        }
        
        return nil
    }
    
    public func executeKeyCombo(_ combo: KeyCombo) throws {
        guard isEnabled else {
            throw KeyComboError.comboDisabled
        }
        
        guard combo.isEnabled else {
            presenter?.presentComboFailed(combo, error: .comboDisabled)
            throw KeyComboError.comboDisabled
        }
        
        guard isComboAvailable(combo) else {
            presenter?.presentComboFailed(combo, error: .invalidContext)
            throw KeyComboError.invalidContext
        }
        
        do {
            let result = try actionExecutor.execute(combo)
            presenter?.presentComboExecuted(combo, result: result)
            presenter?.presentVisualFeedback(for: combo)
        } catch {
            let comboError = error as? KeyComboError ?? .actionExecutionFailed(error.localizedDescription)
            presenter?.presentComboFailed(combo, error: comboError)
            throw comboError
        }
    }
    
    public func getAvailableCombos(for context: KeyComboContext) -> [KeyCombo] {
        return registry.getCombos(for: context)
    }
    
    public func isComboAvailable(_ combo: KeyCombo) -> Bool {
        return combo.isAvailable(in: currentContext)
    }
    
    public func updateContext(_ context: KeyComboContext) {
        currentContext = context
        contextProvider.setCurrentContext(context)
        presenter?.presentContextChanged(context)
    }
    
    public func enableCombo(id: String) {
        registry.enableCombo(id: id)
    }
    
    public func disableCombo(id: String) {
        registry.disableCombo(id: id)
    }
    
    public func getCurrentContext() -> KeyComboContext {
        return currentContext
    }
    
    // MARK: - Public Methods
    
    /// Enables or disables the entire key combo system
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    /// Gets all combos in a specific category
    public func getCombos(in category: KeyComboCategory) -> [KeyCombo] {
        return registry.getCombos(in: category)
    }
    
    /// Gets all enabled combos
    public func getEnabledCombos() -> [KeyCombo] {
        return registry.getEnabledCombos()
    }
    
    /// Shows help for all available combos
    public func showComboHelp() {
        let availableCombos = getAvailableCombos(for: currentContext)
        presenter?.presentComboHelp(availableCombos)
    }
    
    // MARK: - Private Methods
    
    private func setupContextObservation() {
        // Observe context changes from the context provider
        contextProvider.contextPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newContext in
                self?.currentContext = newContext
                self?.presenter?.presentContextChanged(newContext)
            }
            .store(in: &cancellables)
    }
}

// MARK: - Key Combo Context Provider

/// Provides the current application context for key combos
public class KeyComboContextProvider: ObservableObject {
    
    @Published private var currentContext: KeyComboContext
    
    public var contextPublisher: AnyPublisher<KeyComboContext, Never> {
        $currentContext.eraseToAnyPublisher()
    }
    
    public init(initialContext: KeyComboContext = KeyComboContext(mode: .pattern)) {
        self.currentContext = initialContext
    }
    
    public func getCurrentContext() -> KeyComboContext {
        return currentContext
    }
    
    public func setCurrentContext(_ context: KeyComboContext) {
        currentContext = context
    }
    
    public func updateMode(_ mode: KeyComboContext.AppMode) {
        currentContext = KeyComboContext(
            mode: mode,
            subMode: currentContext.subMode,
            conditions: currentContext.conditions
        )
    }
    
    public func updateSubMode(_ subMode: String?) {
        currentContext = KeyComboContext(
            mode: currentContext.mode,
            subMode: subMode,
            conditions: currentContext.conditions
        )
    }
    
    public func updateConditions(_ conditions: [String: String]) {
        currentContext = KeyComboContext(
            mode: currentContext.mode,
            subMode: currentContext.subMode,
            conditions: conditions
        )
    }
}

// MARK: - Key Combo Action Executor

/// Executes key combo actions
public class KeyComboActionExecutor {
    
    private var actionHandlers: [KeyComboAction.ActionType: (KeyCombo) throws -> KeyComboExecutionResult] = [:]
    
    public init() {
        setupDefaultHandlers()
    }
    
    /// Executes a key combo action
    public func execute(_ combo: KeyCombo) throws -> KeyComboExecutionResult {
        guard let handler = actionHandlers[combo.action.type] else {
            throw KeyComboError.actionExecutionFailed("No handler for action type: \(combo.action.type)")
        }
        
        return try handler(combo)
    }
    
    /// Registers a custom action handler
    public func registerHandler(
        for actionType: KeyComboAction.ActionType,
        handler: @escaping (KeyCombo) throws -> KeyComboExecutionResult
    ) {
        actionHandlers[actionType] = handler
    }
    
    /// Unregisters an action handler
    public func unregisterHandler(for actionType: KeyComboAction.ActionType) {
        actionHandlers.removeValue(forKey: actionType)
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultHandlers() {
        // Navigation actions
        actionHandlers[.navigation] = { combo in
            let action = combo.action.parameters["action"] ?? "unknown"
            // In a real implementation, this would trigger navigation
            return KeyComboExecutionResult(
                success: true,
                message: "Navigation action executed: \(action)"
            )
        }
        
        // Playback actions
        actionHandlers[.playback] = { combo in
            let action = combo.action.parameters["action"] ?? "unknown"
            // In a real implementation, this would control playback
            return KeyComboExecutionResult(
                success: true,
                message: "Playback action executed: \(action)"
            )
        }
        
        // Recording actions
        actionHandlers[.recording] = { combo in
            let action = combo.action.parameters["action"] ?? "unknown"
            // In a real implementation, this would control recording
            return KeyComboExecutionResult(
                success: true,
                message: "Recording action executed: \(action)"
            )
        }
        
        // Parameter actions
        actionHandlers[.parameter] = { combo in
            let action = combo.action.parameters["action"] ?? "unknown"
            // In a real implementation, this would modify parameters
            return KeyComboExecutionResult(
                success: true,
                message: "Parameter action executed: \(action)"
            )
        }
        
        // Pattern actions
        actionHandlers[.pattern] = { combo in
            let pattern = combo.action.parameters["pattern"] ?? "unknown"
            // In a real implementation, this would handle pattern operations
            return KeyComboExecutionResult(
                success: true,
                message: "Pattern action executed: \(pattern)"
            )
        }
        
        // Kit actions
        actionHandlers[.kit] = { combo in
            let kit = combo.action.parameters["kit"] ?? "unknown"
            // In a real implementation, this would handle kit operations
            return KeyComboExecutionResult(
                success: true,
                message: "Kit action executed: \(kit)"
            )
        }
        
        // Effect actions
        actionHandlers[.effect] = { combo in
            let effect = combo.action.parameters["effect"] ?? "unknown"
            // In a real implementation, this would handle effect operations
            return KeyComboExecutionResult(
                success: true,
                message: "Effect action executed: \(effect)"
            )
        }
        
        // System actions
        actionHandlers[.system] = { combo in
            let action = combo.action.parameters["action"] ?? "unknown"
            // In a real implementation, this would handle system operations
            return KeyComboExecutionResult(
                success: true,
                message: "System action executed: \(action)"
            )
        }
    }
}

// MARK: - Extensions

extension KeyComboInteractor {
    /// Gets statistics about the key combo system
    public var statistics: KeyComboStatistics {
        let allCombos = registry.getAllCombos()
        let enabledCombos = allCombos.filter { $0.isEnabled }
        let availableCombos = getAvailableCombos(for: currentContext)
        
        return KeyComboStatistics(
            totalCombos: allCombos.count,
            enabledCombos: enabledCombos.count,
            availableCombos: availableCombos.count,
            currentMode: currentContext.mode.displayName
        )
    }
}

/// Statistics about the key combo system
public struct KeyComboStatistics {
    public let totalCombos: Int
    public let enabledCombos: Int
    public let availableCombos: Int
    public let currentMode: String
    
    public init(totalCombos: Int, enabledCombos: Int, availableCombos: Int, currentMode: String) {
        self.totalCombos = totalCombos
        self.enabledCombos = enabledCombos
        self.availableCombos = availableCombos
        self.currentMode = currentMode
    }
}
