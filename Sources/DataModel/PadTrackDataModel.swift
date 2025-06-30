import Foundation
import CoreData

// MARK: - Core Data Model Definition for PadTrack

/// Comprehensive Core Data model design for PadTrack application
/// This file defines the entities, attributes, and relationships for the data model

public class PadTrackDataModel {
    
    // MARK: - Entity Names
    
    public enum EntityName: String, CaseIterable {
        case project = "Project"
        case pattern = "Pattern"
        case kit = "Kit"
        case track = "Track"
        case trig = "Trig"
        case preset = "Preset"
        case presetPool = "PresetPool"
        case parameterLock = "ParameterLock"
        case mixerSettings = "MixerSettings"
        case fxSettings = "FXSettings"
        case machine = "Machine"
        case voiceMachine = "VoiceMachine"
        case filterMachine = "FilterMachine"
        case fxMachine = "FXMachine"
    }
    
    // MARK: - Model Configuration
    
    /// Create and configure the Core Data model programmatically
    public static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Create all entities
        let entities = [
            createProjectEntity(),
            createPatternEntity(),
            createKitEntity(),
            createTrackEntity(),
            createTrigEntity(),
            createPresetEntity(),
            createPresetPoolEntity(),
            createParameterLockEntity(),
            createMixerSettingsEntity(),
            createFXSettingsEntity(),
            createMachineEntity(),
            createVoiceMachineEntity(),
            createFilterMachineEntity(),
            createFXMachineEntity()
        ]
        
        model.entities = entities
        
        // Establish relationships after all entities are created
        establishRelationships(entities: entities)
        
        return model
    }
    
    // MARK: - Entity Creation Methods
    
    private static func createProjectEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.project.rawValue
        entity.managedObjectClassName = "Project"
        
        // Attributes
        entity.properties = [
            createAttribute(name: "id", type: .UUIDAttributeType, optional: false),
            createAttribute(name: "name", type: .stringAttributeType, optional: false),
            createAttribute(name: "createdDate", type: .dateAttributeType, optional: false),
            createAttribute(name: "modifiedDate", type: .dateAttributeType, optional: false),
            createAttribute(name: "version", type: .stringAttributeType, optional: false),
            createAttribute(name: "tempo", type: .floatAttributeType, optional: false, defaultValue: 120.0),
            createAttribute(name: "description", type: .stringAttributeType, optional: true),
            createAttribute(name: "tags", type: .stringAttributeType, optional: true),
            createAttribute(name: "isTemplate", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "colorTheme", type: .stringAttributeType, optional: true),
            createAttribute(name: "masterVolume", type: .floatAttributeType, optional: false, defaultValue: 0.8),
            createAttribute(name: "swingAmount", type: .floatAttributeType, optional: false, defaultValue: 0.0)
        ]
        
        return entity
    }
    
    private static func createPatternEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.pattern.rawValue
        entity.managedObjectClassName = "Pattern"
        
        // Attributes
        entity.properties = [
            createAttribute(name: "id", type: .UUIDAttributeType, optional: false),
            createAttribute(name: "name", type: .stringAttributeType, optional: false),
            createAttribute(name: "length", type: .integer16AttributeType, optional: false, defaultValue: 16),
            createAttribute(name: "resolution", type: .integer16AttributeType, optional: false, defaultValue: 16),
            createAttribute(name: "tempo", type: .floatAttributeType, optional: false, defaultValue: 120.0),
            createAttribute(name: "timeSignatureNumerator", type: .integer16AttributeType, optional: false, defaultValue: 4),
            createAttribute(name: "timeSignatureDenominator", type: .integer16AttributeType, optional: false, defaultValue: 4),
            createAttribute(name: "isPlaying", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "isMuted", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "isSoloed", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "swing", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "shuffle", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "scale", type: .stringAttributeType, optional: true),
            createAttribute(name: "key", type: .stringAttributeType, optional: true),
            createAttribute(name: "createdDate", type: .dateAttributeType, optional: false),
            createAttribute(name: "modifiedDate", type: .dateAttributeType, optional: false)
        ]
        
        return entity
    }
    
    private static func createKitEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.kit.rawValue
        entity.managedObjectClassName = "Kit"
        
        // Attributes
        entity.properties = [
            createAttribute(name: "id", type: .UUIDAttributeType, optional: false),
            createAttribute(name: "name", type: .stringAttributeType, optional: false),
            createAttribute(name: "kitType", type: .stringAttributeType, optional: false, defaultValue: "standard"),
            createAttribute(name: "description", type: .stringAttributeType, optional: true),
            createAttribute(name: "createdDate", type: .dateAttributeType, optional: false),
            createAttribute(name: "modifiedDate", type: .dateAttributeType, optional: false),
            createAttribute(name: "isDefault", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "masterVolume", type: .floatAttributeType, optional: false, defaultValue: 0.8),
            createAttribute(name: "masterTune", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "compressorEnabled", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "reverbEnabled", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "delayEnabled", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "distortionEnabled", type: .booleanAttributeType, optional: false, defaultValue: false)
        ]
        
        return entity
    }
    
    private static func createTrackEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.track.rawValue
        entity.managedObjectClassName = "Track"
        
        // Attributes
        entity.properties = [
            createAttribute(name: "id", type: .UUIDAttributeType, optional: false),
            createAttribute(name: "trackNumber", type: .integer16AttributeType, optional: false),
            createAttribute(name: "name", type: .stringAttributeType, optional: false),
            createAttribute(name: "isMuted", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "isSoloed", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "volume", type: .floatAttributeType, optional: false, defaultValue: 0.8),
            createAttribute(name: "pan", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "pitch", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "length", type: .floatAttributeType, optional: false, defaultValue: 1.0),
            createAttribute(name: "sendLevel1", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "sendLevel2", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "filter", type: .floatAttributeType, optional: false, defaultValue: 1.0),
            createAttribute(name: "lfo", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "amp", type: .floatAttributeType, optional: false, defaultValue: 1.0),
            createAttribute(name: "delay", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "reverb", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "microtiming", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "chance", type: .floatAttributeType, optional: false, defaultValue: 1.0),
            createAttribute(name: "retrig", type: .integer16AttributeType, optional: false, defaultValue: 0),
            createAttribute(name: "condition", type: .stringAttributeType, optional: true)
        ]
        
        return entity
    }
    
    private static func createTrigEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.trig.rawValue
        entity.managedObjectClassName = "Trig"
        
        // Attributes
        entity.properties = [
            createAttribute(name: "id", type: .UUIDAttributeType, optional: false),
            createAttribute(name: "stepNumber", type: .integer16AttributeType, optional: false),
            createAttribute(name: "isActive", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "velocity", type: .floatAttributeType, optional: false, defaultValue: 1.0),
            createAttribute(name: "pitch", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "duration", type: .floatAttributeType, optional: false, defaultValue: 1.0),
            createAttribute(name: "microtiming", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "probability", type: .floatAttributeType, optional: false, defaultValue: 1.0),
            createAttribute(name: "retrigCount", type: .integer16AttributeType, optional: false, defaultValue: 0),
            createAttribute(name: "retrigRate", type: .floatAttributeType, optional: false, defaultValue: 1.0),
            createAttribute(name: "trigCondition", type: .stringAttributeType, optional: true),
            createAttribute(name: "note", type: .integer16AttributeType, optional: true),
            createAttribute(name: "accent", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "slide", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "tie", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "trigLock", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "chromatic", type: .booleanAttributeType, optional: false, defaultValue: false)
        ]
        
        return entity
    }
    
    private static func createPresetEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.preset.rawValue
        entity.managedObjectClassName = "Preset"
        
        // Attributes
        entity.properties = [
            createAttribute(name: "id", type: .UUIDAttributeType, optional: false),
            createAttribute(name: "name", type: .stringAttributeType, optional: false),
            createAttribute(name: "machineType", type: .stringAttributeType, optional: false),
            createAttribute(name: "parameters", type: .binaryDataAttributeType, optional: false),
            createAttribute(name: "version", type: .stringAttributeType, optional: false, defaultValue: "1.0"),
            createAttribute(name: "createdDate", type: .dateAttributeType, optional: false),
            createAttribute(name: "modifiedDate", type: .dateAttributeType, optional: false),
            createAttribute(name: "isDefault", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "category", type: .stringAttributeType, optional: true),
            createAttribute(name: "tags", type: .stringAttributeType, optional: true),
            createAttribute(name: "description", type: .stringAttributeType, optional: true),
            createAttribute(name: "author", type: .stringAttributeType, optional: true),
            createAttribute(name: "tempo", type: .floatAttributeType, optional: true),
            createAttribute(name: "key", type: .stringAttributeType, optional: true),
            createAttribute(name: "usageCount", type: .integer32AttributeType, optional: false, defaultValue: 0),
            createAttribute(name: "rating", type: .floatAttributeType, optional: true),
            createAttribute(name: "isFavorite", type: .booleanAttributeType, optional: false, defaultValue: false)
        ]
        
        return entity
    }
    
    private static func createPresetPoolEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.presetPool.rawValue
        entity.managedObjectClassName = "PresetPool"
        
        // Attributes
        entity.properties = [
            createAttribute(name: "id", type: .UUIDAttributeType, optional: false),
            createAttribute(name: "name", type: .stringAttributeType, optional: false),
            createAttribute(name: "description", type: .stringAttributeType, optional: true),
            createAttribute(name: "createdDate", type: .dateAttributeType, optional: false),
            createAttribute(name: "modifiedDate", type: .dateAttributeType, optional: false),
            createAttribute(name: "isShared", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "poolType", type: .stringAttributeType, optional: false, defaultValue: "user"),
            createAttribute(name: "version", type: .stringAttributeType, optional: false, defaultValue: "1.0")
        ]
        
        return entity
    }
    
    private static func createParameterLockEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.parameterLock.rawValue
        entity.managedObjectClassName = "ParameterLock"
        
        // Attributes
        entity.properties = [
            createAttribute(name: "id", type: .UUIDAttributeType, optional: false),
            createAttribute(name: "parameterName", type: .stringAttributeType, optional: false),
            createAttribute(name: "value", type: .floatAttributeType, optional: false),
            createAttribute(name: "stepNumber", type: .integer16AttributeType, optional: false),
            createAttribute(name: "lockType", type: .stringAttributeType, optional: false, defaultValue: "trig"),
            createAttribute(name: "interpolation", type: .stringAttributeType, optional: false, defaultValue: "none"),
            createAttribute(name: "isActive", type: .booleanAttributeType, optional: false, defaultValue: true),
            createAttribute(name: "smoothing", type: .floatAttributeType, optional: false, defaultValue: 0.0)
        ]
        
        return entity
    }
    
    private static func createMixerSettingsEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.mixerSettings.rawValue
        entity.managedObjectClassName = "MixerSettings"
        
        // Attributes
        entity.properties = [
            createAttribute(name: "id", type: .UUIDAttributeType, optional: false),
            createAttribute(name: "masterVolume", type: .floatAttributeType, optional: false, defaultValue: 0.8),
            createAttribute(name: "masterCompression", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "masterEQHigh", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "masterEQMid", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "masterEQLow", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "send1Level", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "send2Level", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "cueBus", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "headphoneLevel", type: .floatAttributeType, optional: false, defaultValue: 0.8),
            createAttribute(name: "monitorMode", type: .stringAttributeType, optional: false, defaultValue: "stereo"),
            createAttribute(name: "limiterEnabled", type: .booleanAttributeType, optional: false, defaultValue: true),
            createAttribute(name: "limiterThreshold", type: .floatAttributeType, optional: false, defaultValue: 0.95)
        ]
        
        return entity
    }
    
    private static func createFXSettingsEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.fxSettings.rawValue
        entity.managedObjectClassName = "FXSettings"
        
        // Attributes
        entity.properties = [
            createAttribute(name: "id", type: .UUIDAttributeType, optional: false),
            createAttribute(name: "fxType", type: .stringAttributeType, optional: false),
            createAttribute(name: "isEnabled", type: .booleanAttributeType, optional: false, defaultValue: true),
            createAttribute(name: "parameters", type: .binaryDataAttributeType, optional: false),
            createAttribute(name: "wetLevel", type: .floatAttributeType, optional: false, defaultValue: 0.5),
            createAttribute(name: "dryLevel", type: .floatAttributeType, optional: false, defaultValue: 1.0),
            createAttribute(name: "bypassable", type: .booleanAttributeType, optional: false, defaultValue: true),
            createAttribute(name: "position", type: .integer16AttributeType, optional: false, defaultValue: 0),
            createAttribute(name: "routing", type: .stringAttributeType, optional: false, defaultValue: "insert")
        ]
        
        return entity
    }
    
    private static func createMachineEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.machine.rawValue
        entity.managedObjectClassName = "Machine"
        
        // Attributes
        entity.properties = [
            createAttribute(name: "id", type: .UUIDAttributeType, optional: false),
            createAttribute(name: "machineType", type: .stringAttributeType, optional: false),
            createAttribute(name: "name", type: .stringAttributeType, optional: false),
            createAttribute(name: "version", type: .stringAttributeType, optional: false, defaultValue: "1.0"),
            createAttribute(name: "isEnabled", type: .booleanAttributeType, optional: false, defaultValue: true),
            createAttribute(name: "parameters", type: .binaryDataAttributeType, optional: false),
            createAttribute(name: "state", type: .binaryDataAttributeType, optional: true),
            createAttribute(name: "cpuUsage", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "latency", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "sampleRate", type: .floatAttributeType, optional: false, defaultValue: 44100.0),
            createAttribute(name: "bufferSize", type: .integer32AttributeType, optional: false, defaultValue: 512)
        ]
        
        return entity
    }
    
    private static func createVoiceMachineEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.voiceMachine.rawValue
        entity.managedObjectClassName = "VoiceMachine"
        
        // Inherits from Machine
        entity.superentity = createMachineEntity()
        
        // Additional attributes specific to voice machines
        let additionalProperties = [
            createAttribute(name: "polyphony", type: .integer16AttributeType, optional: false, defaultValue: 1),
            createAttribute(name: "voiceMode", type: .stringAttributeType, optional: false, defaultValue: "mono"),
            createAttribute(name: "portamento", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "bendRange", type: .integer16AttributeType, optional: false, defaultValue: 2),
            createAttribute(name: "transpose", type: .integer16AttributeType, optional: false, defaultValue: 0),
            createAttribute(name: "fineTune", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "velocitySensitivity", type: .floatAttributeType, optional: false, defaultValue: 1.0),
            createAttribute(name: "keyTracking", type: .floatAttributeType, optional: false, defaultValue: 0.0)
        ]
        
        entity.properties.append(contentsOf: additionalProperties)
        return entity
    }
    
    private static func createFilterMachineEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.filterMachine.rawValue
        entity.managedObjectClassName = "FilterMachine"
        
        // Inherits from Machine
        entity.superentity = createMachineEntity()
        
        // Additional attributes specific to filter machines
        let additionalProperties = [
            createAttribute(name: "filterType", type: .stringAttributeType, optional: false, defaultValue: "lowpass"),
            createAttribute(name: "cutoff", type: .floatAttributeType, optional: false, defaultValue: 1000.0),
            createAttribute(name: "resonance", type: .floatAttributeType, optional: false, defaultValue: 0.1),
            createAttribute(name: "drive", type: .floatAttributeType, optional: false, defaultValue: 1.0),
            createAttribute(name: "morphPosition", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "keyboardTracking", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "envelopeAmount", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "lfoAmount", type: .floatAttributeType, optional: false, defaultValue: 0.0)
        ]
        
        entity.properties.append(contentsOf: additionalProperties)
        return entity
    }
    
    private static func createFXMachineEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = EntityName.fxMachine.rawValue
        entity.managedObjectClassName = "FXMachine"
        
        // Inherits from Machine
        entity.superentity = createMachineEntity()
        
        // Additional attributes specific to FX machines
        let additionalProperties = [
            createAttribute(name: "effectType", type: .stringAttributeType, optional: false, defaultValue: "reverb"),
            createAttribute(name: "wetLevel", type: .floatAttributeType, optional: false, defaultValue: 0.5),
            createAttribute(name: "dryLevel", type: .floatAttributeType, optional: false, defaultValue: 1.0),
            createAttribute(name: "feedbackAmount", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "delayTime", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "modRate", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "modDepth", type: .floatAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "stereoWidth", type: .floatAttributeType, optional: false, defaultValue: 1.0)
        ]
        
        entity.properties.append(contentsOf: additionalProperties)
        return entity
    }
    
    // MARK: - Helper Methods
    
    private static func createAttribute(
        name: String,
        type: NSAttributeType,
        optional: Bool = true,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        
        if let defaultValue = defaultValue {
            attribute.defaultValue = defaultValue
        }
        
        // Set specific configurations based on type
        switch type {
        case .stringAttributeType:
            attribute.attributeValueClassName = "NSString"
        case .UUIDAttributeType:
            attribute.attributeValueClassName = "NSUUID"
        case .dateAttributeType:
            attribute.attributeValueClassName = "NSDate"
        case .binaryDataAttributeType:
            attribute.allowsExternalBinaryDataStorage = true
        default:
            break
        }
        
        return attribute
    }
    
    private static func createRelationship(
        name: String,
        destinationEntityName: String,
        toMany: Bool = false,
        optional: Bool = true,
        deleteRule: NSDeleteRule = .nullifyDeleteRule,
        inverseName: String? = nil
    ) -> NSRelationshipDescription {
        let relationship = NSRelationshipDescription()
        relationship.name = name
        relationship.isOptional = optional
        relationship.deleteRule = deleteRule
        
        if toMany {
            relationship.maxCount = 0  // 0 means unlimited for to-many
            relationship.minCount = 0
        } else {
            relationship.maxCount = 1
            relationship.minCount = optional ? 0 : 1
        }
        
        // Note: destinationEntity and inverseRelationship will be set in establishRelationships
        return relationship
    }
    
    // MARK: - Relationship Establishment
    
    private static func establishRelationships(entities: [NSEntityDescription]) {
        let entityMap = Dictionary(uniqueKeysWithValues: entities.map { ($0.name!, $0) })
        
        // Project relationships
        if let projectEntity = entityMap[EntityName.project.rawValue] {
            let patternsRelationship = createRelationship(
                name: "patterns",
                destinationEntityName: EntityName.pattern.rawValue,
                toMany: true,
                optional: true,
                deleteRule: .cascadeDeleteRule,
                inverseName: "project"
            )
            patternsRelationship.destinationEntity = entityMap[EntityName.pattern.rawValue]
            
            let presetPoolRelationship = createRelationship(
                name: "presetPool",
                destinationEntityName: EntityName.presetPool.rawValue,
                toMany: false,
                optional: true,
                deleteRule: .cascadeDeleteRule,
                inverseName: "project"
            )
            presetPoolRelationship.destinationEntity = entityMap[EntityName.presetPool.rawValue]
            
            let mixerSettingsRelationship = createRelationship(
                name: "mixerSettings",
                destinationEntityName: EntityName.mixerSettings.rawValue,
                toMany: false,
                optional: true,
                deleteRule: .cascadeDeleteRule,
                inverseName: "project"
            )
            mixerSettingsRelationship.destinationEntity = entityMap[EntityName.mixerSettings.rawValue]
            
            projectEntity.properties.append(contentsOf: [
                patternsRelationship,
                presetPoolRelationship,
                mixerSettingsRelationship
            ])
        }
        
        // Pattern relationships
        if let patternEntity = entityMap[EntityName.pattern.rawValue] {
            let projectRelationship = createRelationship(
                name: "project",
                destinationEntityName: EntityName.project.rawValue,
                toMany: false,
                optional: false,
                deleteRule: .nullifyDeleteRule,
                inverseName: "patterns"
            )
            projectRelationship.destinationEntity = entityMap[EntityName.project.rawValue]
            
            let kitRelationship = createRelationship(
                name: "kit",
                destinationEntityName: EntityName.kit.rawValue,
                toMany: false,
                optional: false,
                deleteRule: .nullifyDeleteRule,
                inverseName: "patterns"
            )
            kitRelationship.destinationEntity = entityMap[EntityName.kit.rawValue]
            
            let tracksRelationship = createRelationship(
                name: "tracks",
                destinationEntityName: EntityName.track.rawValue,
                toMany: true,
                optional: true,
                deleteRule: .cascadeDeleteRule,
                inverseName: "pattern"
            )
            tracksRelationship.destinationEntity = entityMap[EntityName.track.rawValue]
            
            patternEntity.properties.append(contentsOf: [
                projectRelationship,
                kitRelationship,
                tracksRelationship
            ])
        }
        
        // Kit relationships
        if let kitEntity = entityMap[EntityName.kit.rawValue] {
            let patternsRelationship = createRelationship(
                name: "patterns",
                destinationEntityName: EntityName.pattern.rawValue,
                toMany: true,
                optional: true,
                deleteRule: .nullifyDeleteRule,
                inverseName: "kit"
            )
            patternsRelationship.destinationEntity = entityMap[EntityName.pattern.rawValue]
            
            let presetsRelationship = createRelationship(
                name: "presets",
                destinationEntityName: EntityName.preset.rawValue,
                toMany: true,
                optional: true,
                deleteRule: .nullifyDeleteRule,
                inverseName: "kits"
            )
            presetsRelationship.destinationEntity = entityMap[EntityName.preset.rawValue]
            
            let fxSettingsRelationship = createRelationship(
                name: "fxSettings",
                destinationEntityName: EntityName.fxSettings.rawValue,
                toMany: true,
                optional: true,
                deleteRule: .cascadeDeleteRule,
                inverseName: "kit"
            )
            fxSettingsRelationship.destinationEntity = entityMap[EntityName.fxSettings.rawValue]
            
            kitEntity.properties.append(contentsOf: [
                patternsRelationship,
                presetsRelationship,
                fxSettingsRelationship
            ])
        }
        
        // Track relationships
        if let trackEntity = entityMap[EntityName.track.rawValue] {
            let patternRelationship = createRelationship(
                name: "pattern",
                destinationEntityName: EntityName.pattern.rawValue,
                toMany: false,
                optional: false,
                deleteRule: .nullifyDeleteRule,
                inverseName: "tracks"
            )
            patternRelationship.destinationEntity = entityMap[EntityName.pattern.rawValue]
            
            let presetRelationship = createRelationship(
                name: "preset",
                destinationEntityName: EntityName.preset.rawValue,
                toMany: false,
                optional: true,
                deleteRule: .nullifyDeleteRule,
                inverseName: "tracks"
            )
            presetRelationship.destinationEntity = entityMap[EntityName.preset.rawValue]
            
            let trigsRelationship = createRelationship(
                name: "trigs",
                destinationEntityName: EntityName.trig.rawValue,
                toMany: true,
                optional: true,
                deleteRule: .cascadeDeleteRule,
                inverseName: "track"
            )
            trigsRelationship.destinationEntity = entityMap[EntityName.trig.rawValue]
            
            trackEntity.properties.append(contentsOf: [
                patternRelationship,
                presetRelationship,
                trigsRelationship
            ])
        }
        
        // Trig relationships
        if let trigEntity = entityMap[EntityName.trig.rawValue] {
            let trackRelationship = createRelationship(
                name: "track",
                destinationEntityName: EntityName.track.rawValue,
                toMany: false,
                optional: false,
                deleteRule: .nullifyDeleteRule,
                inverseName: "trigs"
            )
            trackRelationship.destinationEntity = entityMap[EntityName.track.rawValue]
            
            let parameterLocksRelationship = createRelationship(
                name: "parameterLocks",
                destinationEntityName: EntityName.parameterLock.rawValue,
                toMany: true,
                optional: true,
                deleteRule: .cascadeDeleteRule,
                inverseName: "trig"
            )
            parameterLocksRelationship.destinationEntity = entityMap[EntityName.parameterLock.rawValue]
            
            trigEntity.properties.append(contentsOf: [
                trackRelationship,
                parameterLocksRelationship
            ])
        }
        
        // Preset relationships
        if let presetEntity = entityMap[EntityName.preset.rawValue] {
            let presetPoolRelationship = createRelationship(
                name: "presetPool",
                destinationEntityName: EntityName.presetPool.rawValue,
                toMany: false,
                optional: true,
                deleteRule: .nullifyDeleteRule,
                inverseName: "presets"
            )
            presetPoolRelationship.destinationEntity = entityMap[EntityName.presetPool.rawValue]
            
            let tracksRelationship = createRelationship(
                name: "tracks",
                destinationEntityName: EntityName.track.rawValue,
                toMany: true,
                optional: true,
                deleteRule: .nullifyDeleteRule,
                inverseName: "preset"
            )
            tracksRelationship.destinationEntity = entityMap[EntityName.track.rawValue]
            
            let kitsRelationship = createRelationship(
                name: "kits",
                destinationEntityName: EntityName.kit.rawValue,
                toMany: true,
                optional: true,
                deleteRule: .nullifyDeleteRule,
                inverseName: "presets"
            )
            kitsRelationship.destinationEntity = entityMap[EntityName.kit.rawValue]
            
            let machineRelationship = createRelationship(
                name: "machine",
                destinationEntityName: EntityName.machine.rawValue,
                toMany: false,
                optional: true,
                deleteRule: .cascadeDeleteRule,
                inverseName: "presets"
            )
            machineRelationship.destinationEntity = entityMap[EntityName.machine.rawValue]
            
            presetEntity.properties.append(contentsOf: [
                presetPoolRelationship,
                tracksRelationship,
                kitsRelationship,
                machineRelationship
            ])
        }
        
        // PresetPool relationships
        if let presetPoolEntity = entityMap[EntityName.presetPool.rawValue] {
            let projectRelationship = createRelationship(
                name: "project",
                destinationEntityName: EntityName.project.rawValue,
                toMany: false,
                optional: true,
                deleteRule: .nullifyDeleteRule,
                inverseName: "presetPool"
            )
            projectRelationship.destinationEntity = entityMap[EntityName.project.rawValue]
            
            let presetsRelationship = createRelationship(
                name: "presets",
                destinationEntityName: EntityName.preset.rawValue,
                toMany: true,
                optional: true,
                deleteRule: .cascadeDeleteRule,
                inverseName: "presetPool"
            )
            presetsRelationship.destinationEntity = entityMap[EntityName.preset.rawValue]
            
            presetPoolEntity.properties.append(contentsOf: [
                projectRelationship,
                presetsRelationship
            ])
        }
        
        // ParameterLock relationships
        if let parameterLockEntity = entityMap[EntityName.parameterLock.rawValue] {
            let trigRelationship = createRelationship(
                name: "trig",
                destinationEntityName: EntityName.trig.rawValue,
                toMany: false,
                optional: false,
                deleteRule: .nullifyDeleteRule,
                inverseName: "parameterLocks"
            )
            trigRelationship.destinationEntity = entityMap[EntityName.trig.rawValue]
            
            parameterLockEntity.properties.append(trigRelationship)
        }
        
        // MixerSettings relationships
        if let mixerSettingsEntity = entityMap[EntityName.mixerSettings.rawValue] {
            let projectRelationship = createRelationship(
                name: "project",
                destinationEntityName: EntityName.project.rawValue,
                toMany: false,
                optional: true,
                deleteRule: .nullifyDeleteRule,
                inverseName: "mixerSettings"
            )
            projectRelationship.destinationEntity = entityMap[EntityName.project.rawValue]
            
            mixerSettingsEntity.properties.append(projectRelationship)
        }
        
        // FXSettings relationships
        if let fxSettingsEntity = entityMap[EntityName.fxSettings.rawValue] {
            let kitRelationship = createRelationship(
                name: "kit",
                destinationEntityName: EntityName.kit.rawValue,
                toMany: false,
                optional: true,
                deleteRule: .nullifyDeleteRule,
                inverseName: "fxSettings"
            )
            kitRelationship.destinationEntity = entityMap[EntityName.kit.rawValue]
            
            fxSettingsEntity.properties.append(kitRelationship)
        }
        
        // Machine relationships
        if let machineEntity = entityMap[EntityName.machine.rawValue] {
            let presetsRelationship = createRelationship(
                name: "presets",
                destinationEntityName: EntityName.preset.rawValue,
                toMany: true,
                optional: true,
                deleteRule: .nullifyDeleteRule,
                inverseName: "machine"
            )
            presetsRelationship.destinationEntity = entityMap[EntityName.preset.rawValue]
            
            machineEntity.properties.append(presetsRelationship)
        }
    }
}

// MARK: - Entity Documentation

/*
 Core Data Model Documentation for PadTrack
 
 Entity Hierarchy:
 
 Project (Root Entity)
 ├── Patterns (1:many)
 │   ├── Kit (many:1)
 │   │   ├── Presets (many:many)
 │   │   └── FXSettings (1:many)
 │   └── Tracks (1:many)
 │       ├── Preset (many:1)
 │       └── Trigs (1:many)
 │           └── ParameterLocks (1:many)
 ├── PresetPool (1:1)
 │   └── Presets (1:many)
 │       └── Machine (1:1)
 │           ├── VoiceMachine (subclass)
 │           ├── FilterMachine (subclass)
 │           └── FXMachine (subclass)
 └── MixerSettings (1:1)
 
 Key Design Decisions:
 
 1. Project is the root container that holds everything for a complete musical project
 2. Patterns contain the sequence data and reference a Kit for sound sources
 3. Kits contain 16 preset slots plus FX/mixer settings
 4. Tracks contain Trigs (step sequencer data) and reference a Preset for sound generation
 5. Trigs can have ParameterLocks (pLocks) for per-step parameter automation
 6. Presets contain all parameters for a Machine and can be shared between projects via PresetPool
 7. Machines are polymorphic (Voice, Filter, FX) and contain the actual audio processing logic
 8. Binary data storage is used for complex parameter sets and machine state
 9. Cascade delete rules ensure proper cleanup when deleting projects/patterns
 10. Many-to-many relationships allow preset sharing and kit reuse
 
 Performance Considerations:
 
 - Binary data attributes allow external storage for large parameter sets
 - Indexes should be added on frequently queried attributes (name, date, machineType)
 - Fetch batching should be used when loading large numbers of patterns/presets
 - Lazy loading relationships help with memory management
 - Proper delete rules prevent orphaned data
 
 Migration Strategy:
 
 - Version 1.0 baseline model established
 - Future versions should use lightweight migration when possible
 - Complex migrations may require heavyweight migration with mapping models
 - Data validation rules help ensure data integrity during migrations
 */ 