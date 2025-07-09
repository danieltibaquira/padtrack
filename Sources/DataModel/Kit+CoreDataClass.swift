//
//  Kit+CoreDataClass.swift
//  DigitonePad
//
//  Auto-generated from Core Data model
//

import Foundation
import CoreData

@objc(Kit)
public class Kit: NSManagedObject, ValidatableEntity {
    
    // MARK: - Validation
    
    public func validateEntity() throws {
        // Validate required fields
        try CoreDataValidation.validateKitName(name)
        try CoreDataValidation.validateDateNotFuture(createdAt, fieldName: "createdAt")
        try CoreDataValidation.validateDateNotFuture(updatedAt, fieldName: "updatedAt")
        
        // Validate date order
        try CoreDataValidation.validateDateOrder(createdAt, updatedAt, firstFieldName: "createdAt", secondFieldName: "updatedAt")
        
        // Validate relationships
        try CoreDataValidation.validateRequiredRelationship(project, relationshipName: "project")
        try CoreDataValidation.validateRelationshipCount(patterns, relationshipName: "patterns", min: 0, max: 100)
        try CoreDataValidation.validateRelationshipCount(tracks, relationshipName: "tracks", min: 0, max: 16)
        
        // Validate sound files array
        if let soundFiles = soundFiles, soundFiles.count > 16 {
            throw ValidationError.relationshipCountTooHigh("soundFiles", 16)
        }
    }
    
    // MARK: - Business Logic
    
    public func addPattern(_ pattern: Pattern) {
        addToPatterns(pattern)
    }
    
    public func removePattern(_ pattern: Pattern) {
        removeFromPatterns(pattern)
    }
    
    public func addTrack(_ track: Track) {
        addToTracks(track)
    }
    
    public func removeTrack(_ track: Track) {
        removeFromTracks(track)
    }
    
    public func addSoundFile(_ filePath: String) {
        var files = soundFiles ?? []
        if !files.contains(filePath) {
            files.append(filePath)
            soundFiles = files
        }
    }
    
    public func removeSoundFile(_ filePath: String) {
        var files = soundFiles ?? []
        files.removeAll { $0 == filePath }
        soundFiles = files
    }
    
    // MARK: - Computed Properties
    
    public var orderedTracks: [Track] {
        guard let tracks = tracks as? Set<Track> else { return [] }
        return tracks.sorted { $0.trackIndex < $1.trackIndex }
    }
    
    public var soundFileCount: Int {
        return soundFiles?.count ?? 0
    }
    
    // MARK: - Lifecycle
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        let now = Date()
        createdAt = now
        updatedAt = now
        
        // Set defaults
        soundFiles = []
    }
    
    public override func willSave() {
        super.willSave()
        
        if isUpdated {
            updatedAt = Date()
        }
    }
}