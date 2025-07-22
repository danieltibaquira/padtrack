//
//  Project+CoreDataClass.swift
//  DigitonePad
//
//  Auto-generated from Core Data model
//

import Foundation
import CoreData

@objc(Project)
public class Project: NSManagedObject, ValidatableEntity {
    
    // MARK: - Validation
    
    public func validateEntity() throws {
        // Validate required fields
        try CoreDataValidation.validateProjectName(name)
        try CoreDataValidation.validateDateNotFuture(createdAt, fieldName: "createdAt")
        try CoreDataValidation.validateDateNotFuture(updatedAt, fieldName: "updatedAt")
        
        // Validate date order
        try CoreDataValidation.validateDateOrder(createdAt, updatedAt, firstFieldName: "createdAt", secondFieldName: "updatedAt")
        
        // Validate relationships
        try CoreDataValidation.validateRelationshipCount(patterns, relationshipName: "patterns", min: 0, max: 100)
        try CoreDataValidation.validateRelationshipCount(kits, relationshipName: "kits", min: 0, max: 50)
        try CoreDataValidation.validateRelationshipCount(presets, relationshipName: "presets", min: 0, max: 200)
    }
    
    // MARK: - Business Logic
    
    public func addPattern(_ pattern: Pattern) {
        addToPatterns(pattern)
    }
    
    public func removePattern(_ pattern: Pattern) {
        removeFromPatterns(pattern)
    }
    
    public func addKit(_ kit: Kit) {
        addToKits(kit)
    }
    
    public func removeKit(_ kit: Kit) {
        removeFromKits(kit)
    }
    
    public func addPreset(_ preset: Preset) {
        addToPresets(preset)
    }
    
    public func removePreset(_ preset: Preset) {
        removeFromPresets(preset)
    }
    
    // MARK: - Lifecycle
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        let now = Date()
        createdAt = now
        updatedAt = now
    }
    
    public override func willSave() {
        super.willSave()
        
        if isUpdated {
            updatedAt = Date()
        }
    }
}