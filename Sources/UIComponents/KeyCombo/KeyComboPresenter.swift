import Foundation
import SwiftUI
import Combine

// MARK: - Key Combo View Models

/// View model for displaying a key combo
public struct KeyComboViewModel: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayText: String
    public let description: String
    public let shortDescription: String
    public let isHighlighted: Bool
    public let isEnabled: Bool
    public let category: String
    public let priority: Int
    public let modifierSymbol: String
    public let keySymbol: String
    public let categoryIcon: String
    
    public init(
        id: String,
        displayText: String,
        description: String,
        shortDescription: String,
        isHighlighted: Bool = false,
        isEnabled: Bool = true,
        category: String,
        priority: Int = 5,
        modifierSymbol: String,
        keySymbol: String,
        categoryIcon: String
    ) {
        self.id = id
        self.displayText = displayText
        self.description = description
        self.shortDescription = shortDescription
        self.isHighlighted = isHighlighted
        self.isEnabled = isEnabled
        self.category = category
        self.priority = priority
        self.modifierSymbol = modifierSymbol
        self.keySymbol = keySymbol
        self.categoryIcon = categoryIcon
    }
}

/// View model for combo feedback
public struct KeyComboFeedbackViewModel: Sendable {
    public let combo: KeyComboViewModel
    public let success: Bool
    public let message: String
    public let animationType: AnimationType
    
    public enum AnimationType: Sendable {
        case success
        case failure
        case highlight
        case pulse
    }
    
    public init(combo: KeyComboViewModel, success: Bool, message: String, animationType: AnimationType) {
        self.combo = combo
        self.success = success
        self.message = message
        self.animationType = animationType
    }
}

/// View model for context indicator
public struct KeyComboContextViewModel: Sendable {
    public let mode: String
    public let subMode: String?
    public let icon: String
    public let color: Color
    
    public init(mode: String, subMode: String? = nil, icon: String, color: Color) {
        self.mode = mode
        self.subMode = subMode
        self.icon = icon
        self.color = color
    }
}

// MARK: - Key Combo Presenter

/// Presenter for the Key Combo system
public class KeyComboPresenter: KeyComboPresenterProtocol, ObservableObject, @unchecked Sendable {
    
    // MARK: - Published Properties
    
    @Published public var availableCombos: [KeyComboViewModel] = []
    @Published public var isShowingCombos: Bool = false
    @Published public var currentFeedback: KeyComboFeedbackViewModel?
    @Published public var contextViewModel: KeyComboContextViewModel?
    @Published public var helpCombos: [KeyComboViewModel] = []
    @Published public var isShowingHelp: Bool = false
    
    // MARK: - Properties
    
    public weak var view: KeyComboViewProtocol?
    private var feedbackTimer: Timer?
    
    // MARK: - Initialization
    
    public init() {}
    
    deinit {
        feedbackTimer?.invalidate()
    }
    
    // MARK: - KeyComboPresenterProtocol Implementation
    
    public func presentAvailableCombos(_ combos: [KeyCombo]) {
        let viewModels = combos.map { combo in
            createViewModel(from: combo, isHighlighted: combo.priority > 7)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.availableCombos = viewModels
            self?.isShowingCombos = !viewModels.isEmpty
        }
        
        view?.showAvailableCombos(viewModels)
    }
    
    public func presentComboExecuted(_ combo: KeyCombo, result: KeyComboExecutionResult) {
        let viewModel = createViewModel(from: combo)
        let feedbackViewModel = KeyComboFeedbackViewModel(
            combo: viewModel,
            success: result.success,
            message: result.message,
            animationType: result.success ? .success : .failure
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.currentFeedback = feedbackViewModel
            self?.scheduleFeedbackDismissal()
        }
        
        view?.showComboFeedback(viewModel, success: result.success)
    }
    
    public func presentComboFailed(_ combo: KeyCombo, error: KeyComboError) {
        let viewModel = createViewModel(from: combo)
        let feedbackViewModel = KeyComboFeedbackViewModel(
            combo: viewModel,
            success: false,
            message: error.localizedDescription,
            animationType: .failure
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.currentFeedback = feedbackViewModel
            self?.scheduleFeedbackDismissal()
        }
        
        view?.showComboFeedback(viewModel, success: false)
    }
    
    public func presentComboHelp(_ combos: [KeyCombo]) {
        let viewModels = combos.map { combo in
            createViewModel(from: combo)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.helpCombos = viewModels
            self?.isShowingHelp = true
        }
        
        view?.showComboHelp(viewModels)
    }
    
    public func presentVisualFeedback(for combo: KeyCombo) {
        let viewModel = createViewModel(from: combo, isHighlighted: true)
        
        DispatchQueue.main.async { [weak self] in
            self?.highlightCombo(viewModel)
        }
        
        view?.highlightCombo(viewModel)
    }
    
    public func presentContextChanged(_ context: KeyComboContext) {
        let contextViewModel = createContextViewModel(from: context)
        
        DispatchQueue.main.async { [weak self] in
            self?.contextViewModel = contextViewModel
        }
        
        view?.updateContextIndicator(context.mode.displayName)
    }
    
    // MARK: - Public Methods
    
    /// Dismisses the combo help
    public func dismissComboHelp() {
        DispatchQueue.main.async { [weak self] in
            self?.isShowingHelp = false
            self?.helpCombos = []
        }
        
        view?.hideComboOverlay()
    }
    
    /// Dismisses current feedback
    public func dismissFeedback() {
        DispatchQueue.main.async { [weak self] in
            self?.currentFeedback = nil
        }
    }
    
    /// Highlights a specific combo
    public func highlightCombo(_ combo: KeyComboViewModel) {
        // Create highlight animation
        let highlightFeedback = KeyComboFeedbackViewModel(
            combo: combo,
            success: true,
            message: "Available",
            animationType: .highlight
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.currentFeedback = highlightFeedback
            
            // Auto-dismiss highlight after short duration
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                self?.currentFeedback = nil
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func createViewModel(from combo: KeyCombo, isHighlighted: Bool = false) -> KeyComboViewModel {
        return KeyComboViewModel(
            id: combo.id,
            displayText: combo.displayText,
            description: combo.description,
            shortDescription: combo.shortDescription,
            isHighlighted: isHighlighted,
            isEnabled: combo.isEnabled,
            category: combo.category.displayName,
            priority: combo.priority,
            modifierSymbol: combo.modifier.symbol,
            keySymbol: combo.key.symbol,
            categoryIcon: combo.category.icon
        )
    }
    
    private func createContextViewModel(from context: KeyComboContext) -> KeyComboContextViewModel {
        let (icon, color) = getContextIconAndColor(for: context.mode)
        
        return KeyComboContextViewModel(
            mode: context.mode.displayName,
            subMode: context.subMode,
            icon: icon,
            color: color
        )
    }
    
    private func getContextIconAndColor(for mode: KeyComboContext.AppMode) -> (String, Color) {
        switch mode {
        case .pattern:
            return ("📋", .blue)
        case .kit:
            return ("🥁", .orange)
        case .song:
            return ("🎼", .green)
        case .performance:
            return ("🎭", .purple)
        case .settings:
            return ("⚙️", .gray)
        }
    }
    
    private func scheduleFeedbackDismissal() {
        feedbackTimer?.invalidate()
        feedbackTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.dismissFeedback()
        }
    }
}

// MARK: - Extensions

extension KeyComboPresenter {
    /// Groups combos by category for organized display
    public func groupCombosByCategory(_ combos: [KeyComboViewModel]) -> [String: [KeyComboViewModel]] {
        return Dictionary(grouping: combos) { $0.category }
    }
    
    /// Sorts combos by priority and name
    public func sortCombos(_ combos: [KeyComboViewModel]) -> [KeyComboViewModel] {
        return combos.sorted { first, second in
            if first.priority != second.priority {
                return first.priority > second.priority
            }
            return first.displayText < second.displayText
        }
    }
    
    /// Filters combos by search text
    public func filterCombos(_ combos: [KeyComboViewModel], searchText: String) -> [KeyComboViewModel] {
        guard !searchText.isEmpty else { return combos }
        
        let lowercaseSearch = searchText.lowercased()
        return combos.filter { combo in
            combo.displayText.lowercased().contains(lowercaseSearch) ||
            combo.description.lowercased().contains(lowercaseSearch) ||
            combo.shortDescription.lowercased().contains(lowercaseSearch)
        }
    }
}

// MARK: - Animation Support

extension KeyComboPresenter {
    /// Creates animation configuration for feedback
    public func animationConfig(for type: KeyComboFeedbackViewModel.AnimationType) -> Animation {
        switch type {
        case .success:
            return .easeInOut(duration: 0.3)
        case .failure:
            return .easeInOut(duration: 0.5).repeatCount(2, autoreverses: true)
        case .highlight:
            return .easeInOut(duration: 0.2)
        case .pulse:
            return .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
        }
    }
    
    /// Gets color for feedback type
    public func feedbackColor(for type: KeyComboFeedbackViewModel.AnimationType) -> Color {
        switch type {
        case .success:
            return .green
        case .failure:
            return .red
        case .highlight:
            return .blue
        case .pulse:
            return .orange
        }
    }
}
