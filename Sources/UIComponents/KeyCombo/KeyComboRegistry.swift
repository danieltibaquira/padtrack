import Foundation
import Combine

/// Registry for managing key combinations
public class KeyComboRegistry: ObservableObject, @unchecked Sendable {
    
    // MARK: - Properties
    
    @Published private var combos: [String: KeyCombo] = [:]
    @Published private var combosByKeys: [ComboKey: KeyCombo] = [:]
    
    private let queue = DispatchQueue(label: "keycombo.registry", qos: .userInteractive)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init() {
        setupDefaultCombos()
    }
    
    // MARK: - Public Methods
    
    /// Registers a key combo in the registry
    public func register(_ combo: KeyCombo) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let comboKey = ComboKey(modifier: combo.modifier, key: combo.key)
            
            DispatchQueue.main.async {
                self.combos[combo.id] = combo
                self.combosByKeys[comboKey] = combo
            }
        }
    }
    
    /// Unregisters a key combo from the registry
    public func unregister(id: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let combo = self.combos.removeValue(forKey: id) {
                    let comboKey = ComboKey(modifier: combo.modifier, key: combo.key)
                    self.combosByKeys.removeValue(forKey: comboKey)
                }
            }
        }
    }
    
    /// Gets a combo by its ID
    public func getCombo(id: String) -> KeyCombo? {
        return combos[id]
    }
    
    /// Finds a combo by modifier and key
    public func findCombo(modifier: KeyModifier, key: Key) -> KeyCombo? {
        let comboKey = ComboKey(modifier: modifier, key: key)
        return combosByKeys[comboKey]
    }
    
    /// Gets all combos for a specific context
    public func getCombos(for context: KeyComboContext) -> [KeyCombo] {
        return combos.values.filter { combo in
            combo.isAvailable(in: context)
        }.sorted { $0.priority > $1.priority }
    }
    
    /// Gets all combos in a specific category
    public func getCombos(in category: KeyComboCategory) -> [KeyCombo] {
        return combos.values.filter { $0.category == category }
            .sorted { $0.priority > $1.priority }
    }
    
    /// Gets all enabled combos
    public func getEnabledCombos() -> [KeyCombo] {
        return combos.values.filter { $0.isEnabled }
            .sorted { $0.priority > $1.priority }
    }
    
    /// Gets all registered combos
    public func getAllCombos() -> [KeyCombo] {
        return Array(combos.values).sorted { $0.priority > $1.priority }
    }
    
    /// Enables a combo
    public func enableCombo(id: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if var combo = self.combos[id] {
                    combo.isEnabled = true
                    self.combos[id] = combo
                    
                    let comboKey = ComboKey(modifier: combo.modifier, key: combo.key)
                    self.combosByKeys[comboKey] = combo
                }
            }
        }
    }
    
    /// Disables a combo
    public func disableCombo(id: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if var combo = self.combos[id] {
                    combo.isEnabled = false
                    self.combos[id] = combo
                    
                    let comboKey = ComboKey(modifier: combo.modifier, key: combo.key)
                    self.combosByKeys[comboKey] = combo
                }
            }
        }
    }
    
    /// Checks if a combo exists
    public func hasCombo(id: String) -> Bool {
        return combos[id] != nil
    }
    
    /// Checks if a combo exists for the given keys
    public func hasCombo(modifier: KeyModifier, key: Key) -> Bool {
        let comboKey = ComboKey(modifier: modifier, key: key)
        return combosByKeys[comboKey] != nil
    }
    
    /// Clears all combos
    public func clear() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.combos.removeAll()
                self.combosByKeys.removeAll()
            }
        }
    }
    
    /// Gets combo count
    public var count: Int {
        return combos.count
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultCombos() {
        // Pattern Mode Combos
        for i in 1...16 {
            let combo = KeyCombo(
                id: "func_pad\(i)_pattern",
                modifier: .func,
                key: .pad(i),
                context: KeyComboContext(mode: .pattern),
                action: KeyComboAction(type: .pattern, parameters: ["pattern": "\(i)"]),
                description: "Select pattern \(i)",
                shortDescription: "Pattern \(i)",
                isEnabled: true,
                priority: 8,
                category: .pattern
            )
            register(combo)
        }
        
        // Playback Combos
        let playCombo = KeyCombo(
            id: "func_play",
            modifier: .func,
            key: .play,
            context: KeyComboContext(mode: .pattern),
            action: KeyComboAction(type: .playback, parameters: ["action": "toggle_loop"]),
            description: "Toggle loop mode",
            shortDescription: "Loop",
            isEnabled: true,
            priority: 9,
            category: .playback
        )
        register(playCombo)
        
        let stopCombo = KeyCombo(
            id: "func_stop",
            modifier: .func,
            key: .stop,
            context: KeyComboContext(mode: .pattern),
            action: KeyComboAction(type: .playback, parameters: ["action": "clear_all"]),
            description: "Clear all patterns",
            shortDescription: "Clear All",
            isEnabled: true,
            priority: 9,
            category: .playback
        )
        register(stopCombo)
        
        // Recording Combos
        let recordCombo = KeyCombo(
            id: "func_record",
            modifier: .func,
            key: .record,
            context: KeyComboContext(mode: .pattern),
            action: KeyComboAction(type: .recording, parameters: ["action": "toggle_mode"]),
            description: "Toggle recording mode",
            shortDescription: "Rec Mode",
            isEnabled: true,
            priority: 9,
            category: .recording
        )
        register(recordCombo)
        
        // Tempo Combo
        let tempoCombo = KeyCombo(
            id: "func_tempo",
            modifier: .func,
            key: .tempo,
            context: KeyComboContext(mode: .pattern),
            action: KeyComboAction(type: .parameter, parameters: ["action": "tap_tempo"]),
            description: "Tap tempo",
            shortDescription: "Tap Tempo",
            isEnabled: true,
            priority: 7,
            category: .system
        )
        register(tempoCombo)
        
        // Kit Mode Combos
        for i in 1...16 {
            let combo = KeyCombo(
                id: "func_pad\(i)_kit",
                modifier: .func,
                key: .pad(i),
                context: KeyComboContext(mode: .kit),
                action: KeyComboAction(type: .kit, parameters: ["kit": "\(i)"]),
                description: "Load kit \(i)",
                shortDescription: "Kit \(i)",
                isEnabled: true,
                priority: 8,
                category: .kit
            )
            register(combo)
        }
        
        // Level Combo
        let levelCombo = KeyCombo(
            id: "func_level",
            modifier: .func,
            key: .level,
            context: KeyComboContext(mode: .kit),
            action: KeyComboAction(type: .parameter, parameters: ["action": "master_volume"]),
            description: "Master volume control",
            shortDescription: "Volume",
            isEnabled: true,
            priority: 7,
            category: .system
        )
        register(levelCombo)
        
        // Song Mode Combos
        for i in 1...16 {
            let combo = KeyCombo(
                id: "func_pad\(i)_song",
                modifier: .func,
                key: .pad(i),
                context: KeyComboContext(mode: .song),
                action: KeyComboAction(type: .pattern, parameters: ["action": "chain", "pattern": "\(i)"]),
                description: "Chain pattern \(i)",
                shortDescription: "Chain \(i)",
                isEnabled: true,
                priority: 8,
                category: .pattern
            )
            register(combo)
        }
        
        // Performance Mode Combos
        for i in 1...16 {
            let combo = KeyCombo(
                id: "func_pad\(i)_performance",
                modifier: .func,
                key: .pad(i),
                context: KeyComboContext(mode: .performance),
                action: KeyComboAction(type: .effect, parameters: ["effect": "\(i)"]),
                description: "Trigger effect \(i)",
                shortDescription: "FX \(i)",
                isEnabled: true,
                priority: 8,
                category: .effects
            )
            register(combo)
        }
        
        // Navigation Combos (available in all modes)
        let menuCombo = KeyCombo(
            id: "func_menu",
            modifier: .func,
            key: .menu,
            context: KeyComboContext(mode: .pattern), // Will be duplicated for other modes
            action: KeyComboAction(type: .navigation, parameters: ["action": "main_menu"]),
            description: "Open main menu",
            shortDescription: "Menu",
            isEnabled: true,
            priority: 6,
            category: .navigation
        )
        register(menuCombo)
    }
}

// MARK: - Supporting Types

/// Key for indexing combos by modifier and key
private struct ComboKey: Hashable {
    let modifier: KeyModifier
    let key: Key
    
    init(modifier: KeyModifier, key: Key) {
        self.modifier = modifier
        self.key = key
    }
}

// MARK: - Extensions

extension KeyComboRegistry {
    /// Exports all combos to a dictionary for persistence
    public func exportCombos() -> [String: Any] {
        let encoder = JSONEncoder()
        var exported: [String: Any] = [:]
        
        for (id, combo) in combos {
            if let data = try? encoder.encode(combo),
               let dict = try? JSONSerialization.jsonObject(with: data) {
                exported[id] = dict
            }
        }
        
        return exported
    }
    
    /// Imports combos from a dictionary
    public func importCombos(from data: [String: Any]) {
        let decoder = JSONDecoder()
        
        for (id, comboData) in data {
            if let dictData = comboData as? [String: Any],
               let jsonData = try? JSONSerialization.data(withJSONObject: dictData),
               let combo = try? decoder.decode(KeyCombo.self, from: jsonData) {
                register(combo)
            }
        }
    }
}
