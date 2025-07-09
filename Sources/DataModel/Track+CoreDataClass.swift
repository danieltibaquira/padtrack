//
//  Track+CoreDataClass.swift
//  DigitonePad
//
//  Auto-generated from Core Data model
//

import Foundation
import CoreData

@objc(Track)
public class Track: NSManagedObject, ValidatableEntity {
    
    // MARK: - Validation
    
    public func validateEntity() throws {
        // Validate required fields
        try CoreDataValidation.validateNonEmptyString(name, fieldName: "name")
        try CoreDataValidation.validateVolume(Double(volume), fieldName: "volume")
        try CoreDataValidation.validatePan(Double(pan), fieldName: "pan")
        try CoreDataValidation.validateInt16Range(trackIndex, fieldName: "trackIndex", min: 0, max: 15)
        try CoreDataValidation.validateDateNotFuture(createdAt, fieldName: "createdAt")
        try CoreDataValidation.validateDateNotFuture(updatedAt, fieldName: "updatedAt")
        
        // Validate date order
        try CoreDataValidation.validateDateOrder(createdAt, updatedAt, firstFieldName: "createdAt", secondFieldName: "updatedAt")
        
        // Validate relationships
        try CoreDataValidation.validateRequiredRelationship(pattern, relationshipName: "pattern")
        try CoreDataValidation.validateRequiredRelationship(kit, relationshipName: "kit")
        try CoreDataValidation.validateRelationshipCount(trigs, relationshipName: "trigs", min: 0, max: 64)
    }
    
    // MARK: - Business Logic
    
    public func addTrig(_ trig: Trig) {
        addToTrigs(trig)
    }
    
    public func removeTrig(_ trig: Trig) {
        removeFromTrigs(trig)
    }
    
    public func toggleMute() {
        isMuted.toggle()
    }
    
    public func toggleSolo() {
        isSolo.toggle()
    }
    
    // MARK: - Computed Properties
    
    public var orderedTrigs: [Trig] {
        guard let trigs = trigs as? Set<Trig> else { return [] }
        return trigs.sorted { $0.step < $1.step }
    }
    
    public var isActive: Bool {
        return !isMuted && (trigs?.count ?? 0) > 0
    }
    
    // MARK: - Lifecycle
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        let now = Date()
        createdAt = now
        updatedAt = now
        
        // Set defaults
        name = "Track"
        volume = 0.75
        pan = 0.0
        isMuted = false
        isSolo = false
        trackIndex = 0
    }
    
    public override func willSave() {
        super.willSave()
        
        if isUpdated {
            updatedAt = Date()
        }
    }
}