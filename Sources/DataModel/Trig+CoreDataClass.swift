//
//  Trig+CoreDataClass.swift
//  DigitonePad
//
//  Auto-generated from Core Data model
//

import Foundation
import CoreData

@objc(Trig)
public class Trig: NSManagedObject, ValidatableEntity {
    
    // MARK: - Validation
    
    public func validateEntity() throws {
        // Validate required fields
        try CoreDataValidation.validateInt16Range(step, fieldName: "step", min: 0, max: 127)
        try CoreDataValidation.validateInt16Range(note, fieldName: "note", min: 0, max: 127)
        try CoreDataValidation.validateInt16Range(velocity, fieldName: "velocity", min: 1, max: 127)
        try CoreDataValidation.validateDuration(Double(duration), fieldName: "duration")
        try CoreDataValidation.validateInt16Range(probability, fieldName: "probability", min: 0, max: 100)
        try CoreDataValidation.validateFloatRange(microTiming, fieldName: "microTiming", min: -50.0, max: 50.0)
        try CoreDataValidation.validateInt16Range(retrigCount, fieldName: "retrigCount", min: 0, max: 8)
        try CoreDataValidation.validateFloatRange(retrigRate, fieldName: "retrigRate", min: 0.1, max: 4.0)
        try CoreDataValidation.validateDateNotFuture(createdAt, fieldName: "createdAt")
        try CoreDataValidation.validateDateNotFuture(updatedAt, fieldName: "updatedAt")
        
        // Validate date order
        try CoreDataValidation.validateDateOrder(createdAt, updatedAt, firstFieldName: "createdAt", secondFieldName: "updatedAt")
        
        // Validate relationships
        try CoreDataValidation.validateRequiredRelationship(track, relationshipName: "track")
        try CoreDataValidation.validateRequiredRelationship(pattern, relationshipName: "pattern")
    }
    
    // MARK: - Business Logic
    
    public func toggle() {
        isActive.toggle()
    }
    
    public func activate() {
        isActive = true
    }
    
    public func deactivate() {
        isActive = false
    }
    
    public func updatePLock(for parameter: String, value: Float) {
        var locks = pLocks as? [String: Float] ?? [:]
        locks[parameter] = value
        pLocks = locks
    }
    
    public func removePLock(for parameter: String) {
        var locks = pLocks as? [String: Float] ?? [:]
        locks.removeValue(forKey: parameter)
        pLocks = locks
    }
    
    // MARK: - Computed Properties
    
    public var hasRetrig: Bool {
        return retrigCount > 0
    }
    
    public var hasPLocks: Bool {
        return (pLocks as? [String: Float])?.isEmpty == false
    }
    
    public var probabilityPercentage: Double {
        return Double(probability) / 100.0
    }
    
    public var velocityNormalized: Float {
        return Float(velocity) / 127.0
    }
    
    public var noteFrequency: Double {
        // Convert MIDI note to frequency (A4 = 440 Hz)
        return 440.0 * pow(2.0, (Double(note) - 69.0) / 12.0)
    }
    
    // MARK: - Lifecycle
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        let now = Date()
        createdAt = now
        updatedAt = now
        
        // Set defaults
        step = 0
        isActive = false
        note = 60 // Middle C
        velocity = 100
        duration = 1.0
        probability = 100
        microTiming = 0.0
        retrigCount = 0
        retrigRate = 0.25
    }
    
    public override func willSave() {
        super.willSave()
        
        if isUpdated {
            updatedAt = Date()
        }
    }
}