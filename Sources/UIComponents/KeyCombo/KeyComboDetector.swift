import Foundation
import Combine
import SwiftUI

/// Detects and handles key combinations
public class KeyComboDetector: ObservableObject, @unchecked Sendable {
    
    // MARK: - Published Properties
    
    @Published public var activeModifiers: Set<KeyModifier> = []
    @Published public var isDetectionActive: Bool = false
    @Published public var lastDetectedCombo: KeyCombo?
    
    // MARK: - Properties
    
    public weak var interactor: KeyComboInteractorProtocol?
    
    private var keyPressTimestamps: [Key: Date] = [:]
    private var comboExecutionWindow: TimeInterval = 2.0
    private var debounceInterval: TimeInterval = 0.1
    private var detectionTimer: Timer?
    
    private let queue = DispatchQueue(label: "keycombo.detector", qos: .userInteractive)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init() {
        setupTimerCleanup()
    }
    
    deinit {
        detectionTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Handles a key press event
    public func handleKeyPress(_ key: Key) {
        queue.async { [weak self] in
            self?.processKeyPress(key)
        }
    }
    
    /// Handles a key release event
    public func handleKeyRelease(_ key: Key) {
        queue.async { [weak self] in
            self?.processKeyRelease(key)
        }
    }
    
    /// Resets the detector state
    public func reset() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.activeModifiers.removeAll()
                self.isDetectionActive = false
                self.lastDetectedCombo = nil
            }
            
            self.keyPressTimestamps.removeAll()
            self.detectionTimer?.invalidate()
            self.detectionTimer = nil
        }
    }
    
    /// Configures detection timing
    public func configure(
        executionWindow: TimeInterval = 2.0,
        debounceInterval: TimeInterval = 0.1
    ) {
        queue.async { [weak self] in
            self?.comboExecutionWindow = executionWindow
            self?.debounceInterval = debounceInterval
        }
    }
    
    // MARK: - Private Methods
    
    private func processKeyPress(_ key: Key) {
        let now = Date()
        
        // Check for debouncing
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
    
    private func processKeyRelease(_ key: Key) {
        if let modifier = key.asModifier {
            handleModifierRelease(modifier)
        }
    }
    
    private func handleModifierPress(_ modifier: KeyModifier) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.activeModifiers.insert(modifier)
            self.isDetectionActive = true
            
            // Notify interactor of available combos
            if let interactor = self.interactor {
                let context = interactor.getCurrentContext()
                let availableCombos = interactor.getAvailableCombos(for: context)
                    .filter { $0.modifier == modifier }
                interactor.presenter?.presentAvailableCombos(availableCombos)
            }
        }
        
        startComboDetectionWindow()
    }
    
    private func handleModifierRelease(_ modifier: KeyModifier) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.activeModifiers.remove(modifier)
            
            if self.activeModifiers.isEmpty {
                self.isDetectionActive = false
                self.interactor?.presenter?.presentAvailableCombos([])
            }
        }
        
        if activeModifiers.isEmpty {
            endComboDetectionWindow()
        }
    }
    
    private func handleRegularKeyPress(_ key: Key) {
        guard isDetectionActive, !activeModifiers.isEmpty else { return }
        
        // Try to find and execute combo for each active modifier
        for modifier in activeModifiers {
            if let combo = interactor?.detectKeyCombo(modifier: modifier, key: key) {
                executeCombo(combo)
                break
            }
        }
    }
    
    private func executeCombo(_ combo: KeyCombo) {
        DispatchQueue.main.async { [weak self] in
            self?.lastDetectedCombo = combo
        }
        
        do {
            try interactor?.executeKeyCombo(combo)
        } catch {
            // Error handling is done in the interactor
        }
        
        // Reset detection state after successful combo
        DispatchQueue.main.async { [weak self] in
            self?.activeModifiers.removeAll()
            self?.isDetectionActive = false
        }
        
        endComboDetectionWindow()
    }
    
    private func startComboDetectionWindow() {
        detectionTimer?.invalidate()
        
        detectionTimer = Timer.scheduledTimer(withTimeInterval: comboExecutionWindow, repeats: false) { [weak self] _ in
            self?.handleDetectionTimeout()
        }
    }
    
    private func endComboDetectionWindow() {
        detectionTimer?.invalidate()
        detectionTimer = nil
    }
    
    private func handleDetectionTimeout() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.activeModifiers.removeAll()
            self.isDetectionActive = false
            
            // Notify presenter of timeout
            self.interactor?.presenter?.presentComboFailed(
                KeyCombo.createDefault(),
                error: .detectionTimeout
            )
        }
        
        endComboDetectionWindow()
    }
    
    private func setupTimerCleanup() {
        // Clean up old timestamps periodically
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.cleanupOldTimestamps()
        }
    }
    
    private func cleanupOldTimestamps() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let now = Date()
            let cutoff = now.addingTimeInterval(-30.0) // Remove timestamps older than 30 seconds
            
            self.keyPressTimestamps = self.keyPressTimestamps.filter { _, timestamp in
                timestamp > cutoff
            }
        }
    }
}

// MARK: - Extensions

extension KeyComboDetector {
    /// Returns true if the detector is currently waiting for a key combination
    public var isWaitingForCombo: Bool {
        return isDetectionActive && !activeModifiers.isEmpty
    }
    
    /// Returns the current modifier symbols as a string
    public var activeModifierSymbols: String {
        return activeModifiers.map { $0.symbol }.joined(separator: " + ")
    }
    
    /// Returns true if a specific modifier is currently active
    public func isModifierActive(_ modifier: KeyModifier) -> Bool {
        return activeModifiers.contains(modifier)
    }
}

// MARK: - SwiftUI Integration

extension KeyComboDetector {
    /// Creates a key press handler for SwiftUI views
    public func keyPressHandler(for key: Key) -> () -> Void {
        return { [weak self] in
            self?.handleKeyPress(key)
        }
    }
    
    /// Creates a key release handler for SwiftUI views
    public func keyReleaseHandler(for key: Key) -> () -> Void {
        return { [weak self] in
            self?.handleKeyRelease(key)
        }
    }
}

// MARK: - Hardware Integration

extension KeyComboDetector {
    /// Handles hardware key events (for future hardware integration)
    public func handleHardwareKeyEvent(_ event: HardwareKeyEvent) {
        switch event.type {
        case .keyDown:
            handleKeyPress(event.key)
        case .keyUp:
            handleKeyRelease(event.key)
        }
    }
}

/// Hardware key event structure (for future hardware integration)
public struct HardwareKeyEvent {
    public let key: Key
    public let type: EventType
    public let timestamp: Date
    
    public enum EventType {
        case keyDown
        case keyUp
    }
    
    public init(key: Key, type: EventType, timestamp: Date = Date()) {
        self.key = key
        self.type = type
        self.timestamp = timestamp
    }
}

// MARK: - Debug Support

extension KeyComboDetector {
    /// Returns debug information about the current state
    public var debugInfo: [String: Any] {
        return [
            "isDetectionActive": isDetectionActive,
            "activeModifiers": activeModifiers.map { $0.rawValue },
            "keyPressTimestamps": keyPressTimestamps.mapValues { $0.timeIntervalSinceNow },
            "comboExecutionWindow": comboExecutionWindow,
            "debounceInterval": debounceInterval,
            "lastDetectedCombo": lastDetectedCombo?.id ?? "none"
        ]
    }
    
    /// Logs the current state for debugging
    public func logCurrentState() {
        print("KeyComboDetector State:")
        for (key, value) in debugInfo {
            print("  \(key): \(value)")
        }
    }
}
