import Foundation
import CoreData

// MARK: - FM Parameter Storage Extension

extension Preset {
    
    /// Stores FM parameter values in the preset's settings data
    /// Uses JSON encoding for flexible parameter storage and future compatibility
    public func setFMParameters(_ parameters: [String: Double]) {
        do {
            let fmData = FMParameterData(parameters: parameters, version: "2.0", timestamp: Date())
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            self.settings = try encoder.encode(fmData)
            self.updatedAt = Date()
        } catch {
            print("Failed to encode FM parameters: \(error)")
        }
    }
    
    /// Retrieves FM parameter values from the preset's settings data
    /// Returns default values if no parameters are stored or decoding fails
    public func getFMParameters() -> [String: Double] {
        guard let settingsData = self.settings else {
            return defaultFMParameters()
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let fmData = try decoder.decode(FMParameterData.self, from: settingsData)
            
            // Migrate from older versions if needed
            if fmData.version != "2.0" {
                return migrateFMParameters(from: fmData.parameters, version: fmData.version)
            }
            
            return fmData.parameters
        } catch {
            print("Failed to decode FM parameters, using defaults: \(error)")
            return defaultFMParameters()
        }
    }
    
    /// Sets a specific FM parameter value
    public func setFMParameter(key: String, value: Double) {
        var currentParameters = getFMParameters()
        currentParameters[key] = value
        setFMParameters(currentParameters)
    }
    
    /// Gets a specific FM parameter value with fallback to default
    public func getFMParameter(key: String) -> Double {
        let parameters = getFMParameters()
        return parameters[key] ?? defaultFMParameters()[key] ?? 0.0
    }
    
    /// Returns true if this preset contains FM parameter data
    public var hasFMParameters: Bool {
        guard let settingsData = self.settings else { return false }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            _ = try decoder.decode(FMParameterData.self, from: settingsData)
            return true
        } catch {
            return false
        }
    }
    
    /// Returns the FM parameter data version
    public var fmParameterVersion: String? {
        guard let settingsData = self.settings else { return nil }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let fmData = try decoder.decode(FMParameterData.self, from: settingsData)
            return fmData.version
        } catch {
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func defaultFMParameters() -> [String: Double] {
        return [
            // Page 1 - Core FM Parameters
            "algorithm": 1.0,
            "operator4_ratio": 1.0,      // Ratio C
            "operator1_ratio": 1.0,      // Ratio A  
            "operator2_ratio": 1.0,      // Ratio B
            "harmony": 0.0,
            "detune": 0.0,
            "feedback": 0.0,
            "mix": 0.5,
            
            // Page 2 - Envelope Parameters
            "attack": 0.01,
            "decay": 0.3,
            "end": 0.5,
            "operator1_envelope_level": 1.0,
            "operator2_envelope_level": 0.8,
            
            // Page 3 - Envelope Behavior
            "delay": 0.0,
            "trig_mode": 0.0,
            "phase_reset": 0.0,
            "key_tracking": 0.5,
            
            // Page 4 - Offsets & Key Tracking
            "operator1_offset": 0.0,
            "operator2_offset": 0.0,
            "velocity_sensitivity": 0.5,
            "scale": 0.0,
            "root": 0.0,
            "tune": 0.0,
            "fine": 0.0,
            
            // Additional parameters
            "modulation_index": 2.0,
            "portamento": 0.0,
            "pitch_bend_range": 2.0,
            "lfo_rate": 2.0,
            "lfo_depth": 0.0,
            "lfo_shape": 0.0,
            "lfo_sync": 0.0,
            "lfo_target": 0.0
        ]
    }
    
    private func migrateFMParameters(from oldParameters: [String: Double], version: String) -> [String: Double] {
        var migratedParameters = defaultFMParameters()
        
        // Copy over existing parameters that match
        for (key, value) in oldParameters {
            if migratedParameters.keys.contains(key) {
                migratedParameters[key] = value
            }
        }
        
        // Version-specific migration logic
        switch version {
        case "1.0":
            // Migrate from version 1.0 parameter names
            if let oldAlgo = oldParameters["algo"] {
                migratedParameters["algorithm"] = oldAlgo
            }
            if let oldRatio1 = oldParameters["ratio1"] {
                migratedParameters["operator1_ratio"] = oldRatio1
            }
            if let oldRatio2 = oldParameters["ratio2"] {
                migratedParameters["operator2_ratio"] = oldRatio2
            }
            if let oldRatio4 = oldParameters["ratio4"] {
                migratedParameters["operator4_ratio"] = oldRatio4
            }
            
        case "1.1":
            // Migration from version 1.1 - minimal changes needed
            break
            
        default:
            // Unknown version, use defaults
            print("Unknown FM parameter version: \(version)")
        }
        
        return migratedParameters
    }
}

// MARK: - FM Parameter Data Structure

/// Data structure for storing FM parameters with versioning support
public struct FMParameterData: Codable {
    public let parameters: [String: Double]
    public let version: String
    public let timestamp: Date
    
    public init(parameters: [String: Double], version: String, timestamp: Date) {
        self.parameters = parameters
        self.version = version
        self.timestamp = timestamp
    }
}

// MARK: - Preset Factory Methods

extension Preset {
    
    /// Creates a new FM preset with the given parameters
    public static func createFMPreset(
        context: NSManagedObjectContext,
        name: String,
        category: String = "FM Synthesis",
        parameters: [String: Double]
    ) -> Preset {
        let preset = Preset(context: context)
        preset.name = name
        preset.category = category
        preset.createdAt = Date()
        preset.updatedAt = Date()
        preset.setFMParameters(parameters)
        
        return preset
    }
    
    /// Duplicates this preset with a new name
    public func duplicate(context: NSManagedObjectContext, newName: String) -> Preset {
        let duplicatedPreset = Preset(context: context)
        duplicatedPreset.name = newName
        duplicatedPreset.category = self.category
        duplicatedPreset.createdAt = Date()
        duplicatedPreset.updatedAt = Date()
        
        // Copy FM parameters if they exist
        if hasFMParameters {
            duplicatedPreset.setFMParameters(getFMParameters())
        }
        
        return duplicatedPreset
    }
}

// MARK: - Query Extensions

extension Preset {
    
    /// Fetches all FM presets
    public static func fetchFMPresets(context: NSManagedObjectContext) -> [Preset] {
        let request: NSFetchRequest<Preset> = Preset.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", "FM Synthesis")
        request.sortDescriptors = [
            NSSortDescriptor(key: "updatedAt", ascending: false),
            NSSortDescriptor(key: "name", ascending: true)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch FM presets: \(error)")
            return []
        }
    }
    
    /// Searches for presets containing a specific parameter value
    public static func searchFMPresets(
        context: NSManagedObjectContext,
        parameterKey: String,
        value: Double,
        tolerance: Double = 0.1
    ) -> [Preset] {
        let allFMPresets = fetchFMPresets(context: context)
        
        return allFMPresets.filter { preset in
            let parameterValue = preset.getFMParameter(key: parameterKey)
            return abs(parameterValue - value) <= tolerance
        }
    }
    
    /// Searches for presets by name
    public static func searchFMPresets(
        context: NSManagedObjectContext,
        nameContaining searchText: String
    ) -> [Preset] {
        let request: NSFetchRequest<Preset> = Preset.fetchRequest()
        request.predicate = NSPredicate(
            format: "category == %@ AND name CONTAINS[cd] %@",
            "FM Synthesis", searchText
        )
        request.sortDescriptors = [
            NSSortDescriptor(key: "name", ascending: true)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to search FM presets: \(error)")
            return []
        }
    }
}

// MARK: - Export/Import Support

extension Preset {
    
    /// Exports preset data for backup or sharing
    public func exportFMPreset() -> Data? {
        guard hasFMParameters else { return nil }
        
        let exportData = FMPresetExportData(
            name: name ?? "Untitled",
            category: category ?? "FM Synthesis",
            parameters: getFMParameters(),
            version: "2.0",
            exportDate: Date()
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(exportData)
        } catch {
            print("Failed to export FM preset: \(error)")
            return nil
        }
    }
    
    /// Imports preset data from backup or sharing
    public static func importFMPreset(
        context: NSManagedObjectContext,
        from data: Data
    ) -> Preset? {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let importData = try decoder.decode(FMPresetExportData.self, from: data)
            
            let preset = createFMPreset(
                context: context,
                name: importData.name,
                category: importData.category,
                parameters: importData.parameters
            )
            
            return preset
        } catch {
            print("Failed to import FM preset: \(error)")
            return nil
        }
    }
}

// MARK: - Export Data Structure

/// Data structure for exporting/importing FM presets
public struct FMPresetExportData: Codable {
    public let name: String
    public let category: String
    public let parameters: [String: Double]
    public let version: String
    public let exportDate: Date
    
    public init(name: String, category: String, parameters: [String: Double], version: String, exportDate: Date) {
        self.name = name
        self.category = category
        self.parameters = parameters
        self.version = version
        self.exportDate = exportDate
    }
}