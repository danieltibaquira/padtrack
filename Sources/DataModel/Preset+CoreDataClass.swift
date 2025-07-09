//
//  Preset+CoreDataClass.swift
//  DigitonePad
//
//  Auto-generated from Core Data model
//

import Foundation
import CoreData

@objc(Preset)
public class Preset: NSManagedObject, ValidatableEntity {
    
    // MARK: - Validation
    
    public func validateEntity() throws {
        // Validate required fields
        try CoreDataValidation.validatePresetName(name)
        try CoreDataValidation.validateDateNotFuture(createdAt, fieldName: "createdAt")
        try CoreDataValidation.validateDateNotFuture(updatedAt, fieldName: "updatedAt")
        
        // Validate date order
        try CoreDataValidation.validateDateOrder(createdAt, updatedAt, firstFieldName: "createdAt", secondFieldName: "updatedAt")
        
        // Validate relationships
        try CoreDataValidation.validateRequiredRelationship(project, relationshipName: "project")
        try CoreDataValidation.validateRelationshipCount(tracks, relationshipName: "tracks", min: 0, max: 16)
        
        // Validate category if present
        if let category = category, !category.isEmpty {
            try CoreDataValidation.validateStringLength(category, fieldName: "category", minLength: 1, maxLength: 30)
        }
    }
    
    // MARK: - Business Logic
    
    public func addTrack(_ track: Track) {
        addToTracks(track)
    }
    
    public func removeTrack(_ track: Track) {
        removeFromTracks(track)
    }
    
    public func updateSettings(_ newSettings: Any) {
        settings = newSettings
    }
    
    // MARK: - Computed Properties
    
    public var orderedTracks: [Track] {
        guard let tracks = tracks as? Set<Track> else { return [] }
        return tracks.sorted { $0.trackIndex < $1.trackIndex }
    }
    
    public var categoryOrDefault: String {
        return category ?? "Uncategorized"
    }
    
    public var trackCount: Int {
        return tracks?.count ?? 0
    }
    
    // MARK: - Lifecycle
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        let now = Date()
        createdAt = now
        updatedAt = now
        
        // Set defaults
        category = "User"
    }
    
    public override func willSave() {
        super.willSave()
        
        if isUpdated {
            updatedAt = Date()
        }
    }
}