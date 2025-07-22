//
//  Pattern+CoreDataClass.swift
//  DigitonePad
//
//  Auto-generated from Core Data model
//

import Foundation
import CoreData

@objc(Pattern)
public class Pattern: NSManagedObject, ValidatableEntity {
    
    // MARK: - Validation
    
    public func validateEntity() throws {
        // Validate required fields
        try CoreDataValidation.validatePatternName(name)
        try CoreDataValidation.validatePatternLength(length)
        try CoreDataValidation.validateTempo(tempo)
        try CoreDataValidation.validateDateNotFuture(createdAt, fieldName: "createdAt")
        try CoreDataValidation.validateDateNotFuture(updatedAt, fieldName: "updatedAt")
        
        // Validate date order
        try CoreDataValidation.validateDateOrder(createdAt, updatedAt, firstFieldName: "createdAt", secondFieldName: "updatedAt")
        
        // Validate relationships
        try CoreDataValidation.validateRequiredRelationship(project, relationshipName: "project")
        try CoreDataValidation.validateRelationshipCount(tracks, relationshipName: "tracks", min: 0, max: 16)
        try CoreDataValidation.validateRelationshipCount(trigs, relationshipName: "trigs", min: 0, max: 1024) // 64 steps * 16 tracks max
    }
    
    // MARK: - Business Logic
    
    public func addTrack(_ track: Track) {
        addToTracks(track)
    }
    
    public func removeTrack(_ track: Track) {
        removeFromTracks(track)
    }
    
    public func addTrig(_ trig: Trig) {
        addToTrigs(trig)
    }
    
    public func removeTrig(_ trig: Trig) {
        removeFromTrigs(trig)
    }
    
    // MARK: - Computed Properties
    
    public var orderedTracks: [Track] {
        guard let tracks = tracks as? Set<Track> else { return [] }
        return tracks.sorted { $0.trackIndex < $1.trackIndex }
    }
    
    public var orderedTrigs: [Trig] {
        guard let trigs = trigs as? Set<Trig> else { return [] }
        return trigs.sorted { $0.step < $1.step }
    }
    
    // MARK: - Lifecycle
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        let now = Date()
        createdAt = now
        updatedAt = now
        
        // Set defaults
        length = 64
        tempo = 120.0
    }
    
    public override func willSave() {
        super.willSave()
        
        if isUpdated {
            updatedAt = Date()
        }
    }
}