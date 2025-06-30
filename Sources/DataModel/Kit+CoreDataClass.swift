//
//  Kit+CoreDataClass.swift
//  PadTrack
//
//  Created by PadTrack on 2024.
//

import Foundation
import CoreData

@objc(Kit)
public class Kit: NSManagedObject {
    
    // MARK: - Convenience Initializers
    
    convenience init(context: NSManagedObjectContext, name: String) {
        self.init(context: context)
        self.kitID = UUID()
        self.name = name
        self.masterVolume = 0.8
        self.masterPan = 0.0
        self.masterCompression = false
        self.masterReverb = false
        self.masterDelay = false
        self.masterDistortion = false
        self.createdAt = Date()
        self.lastModified = Date()
        
        // Initialize 16 default track slots
        setupDefaultTracks()
    }
    
    // MARK: - Computed Properties
    
    /// Number of tracks in this kit
    var trackCount: Int {
        return tracks?.count ?? 0
    }
    
    /// Number of non-empty tracks (tracks with assigned machines)
    var activeTrackCount: Int {
        guard let tracks = tracks as? Set<Track> else { return 0 }
        return tracks.filter { $0.machine != nil }.count
    }
    
    /// Check if kit has been modified since creation
    var isModified: Bool {
        guard let created = createdAt, let modified = lastModified else { return false }
        return modified > created
    }
    
    /// Calculate kit complexity based on active tracks and effects
    var complexityScore: Int {
        var score = activeTrackCount
        if masterCompression { score += 1 }
        if masterReverb { score += 1 }
        if masterDelay { score += 1 }
        if masterDistortion { score += 1 }
        return min(score, 10) // Cap at 10
    }
    
    /// Get all tracks sorted by slot number
    var sortedTracks: [Track] {
        guard let tracks = tracks as? Set<Track> else { return [] }
        return tracks.sorted { $0.slotNumber < $1.slotNumber }
    }
    
    // MARK: - Track Management
    
    /// Setup 16 default track slots
    private func setupDefaultTracks() {
        guard let context = managedObjectContext else { return }
        
        for slotNumber in 1...16 {
            let track = Track(context: context, slotNumber: Int16(slotNumber))
            track.kit = self
        }
    }
    
    /// Get track by slot number (1-16)
    func track(at slotNumber: Int) -> Track? {
        guard slotNumber >= 1 && slotNumber <= 16 else { return nil }
        guard let tracks = tracks as? Set<Track> else { return nil }
        return tracks.first { $0.slotNumber == slotNumber }
    }
    
    /// Get tracks with assigned machines
    func activeTracks() -> [Track] {
        return sortedTracks.filter { $0.machine != nil }
    }
    
    /// Get tracks without assigned machines
    func emptyTracks() -> [Track] {
        return sortedTracks.filter { $0.machine == nil }
    }
    
    /// Assign machine to track slot
    func assignMachine(_ machine: Machine, to slotNumber: Int) throws {
        guard let track = track(at: slotNumber) else {
            throw KitError.invalidSlotNumber(slotNumber)
        }
        
        // Remove machine from previous track if assigned
        if let previousTrack = machine.track {
            previousTrack.machine = nil
        }
        
        track.machine = machine
        lastModified = Date()
    }
    
    /// Remove machine from track slot
    func removeMachine(from slotNumber: Int) throws {
        guard let track = track(at: slotNumber) else {
            throw KitError.invalidSlotNumber(slotNumber)
        }
        
        track.machine = nil
        lastModified = Date()
    }
    
    /// Swap machines between two track slots
    func swapMachines(from sourceSlot: Int, to destinationSlot: Int) throws {
        guard let sourceTrack = track(at: sourceSlot),
              let destinationTrack = track(at: destinationSlot) else {
            throw KitError.invalidSlotNumber(sourceSlot > 16 ? sourceSlot : destinationSlot)
        }
        
        let sourceMachine = sourceTrack.machine
        let destinationMachine = destinationTrack.machine
        
        sourceTrack.machine = destinationMachine
        destinationTrack.machine = sourceMachine
        
        lastModified = Date()
    }
    
    /// Copy track configuration (machine and settings) to another slot
    func copyTrack(from sourceSlot: Int, to destinationSlot: Int) throws {
        guard let sourceTrack = track(at: sourceSlot),
              let destinationTrack = track(at: destinationSlot),
              let sourceMachine = sourceTrack.machine,
              let context = managedObjectContext else {
            throw KitError.invalidSlotNumber(sourceSlot > 16 ? sourceSlot : destinationSlot)
        }
        
        // Create a copy of the machine
        let copiedMachine = sourceMachine.duplicate(in: context)
        destinationTrack.machine = copiedMachine
        
        // Copy track settings
        destinationTrack.volume = sourceTrack.volume
        destinationTrack.pan = sourceTrack.pan
        destinationTrack.isMuted = sourceTrack.isMuted
        destinationTrack.isSolo = sourceTrack.isSolo
        destinationTrack.reverbSend = sourceTrack.reverbSend
        destinationTrack.delaySend = sourceTrack.delaySend
        
        lastModified = Date()
    }
    
    /// Clear all machines from kit
    func clearAllMachines() {
        sortedTracks.forEach { $0.machine = nil }
        lastModified = Date()
    }
    
    // MARK: - Master Effects Management
    
    /// Toggle master compression
    func toggleCompression() {
        masterCompression.toggle()
        lastModified = Date()
    }
    
    /// Toggle master reverb
    func toggleReverb() {
        masterReverb.toggle()
        lastModified = Date()
    }
    
    /// Toggle master delay
    func toggleDelay() {
        masterDelay.toggle()
        lastModified = Date()
    }
    
    /// Toggle master distortion
    func toggleDistortion() {
        masterDistortion.toggle()
        lastModified = Date()
    }
    
    /// Set master volume with validation
    func setMasterVolume(_ volume: Double) throws {
        guard volume >= 0.0 && volume <= 1.0 else {
            throw KitError.invalidVolume(volume)
        }
        masterVolume = volume
        lastModified = Date()
    }
    
    /// Set master pan with validation
    func setMasterPan(_ pan: Double) throws {
        guard pan >= -1.0 && pan <= 1.0 else {
            throw KitError.invalidPan(pan)
        }
        masterPan = pan
        lastModified = Date()
    }
    
    // MARK: - Kit Operations
    
    /// Create a duplicate of this kit
    func duplicate(in context: NSManagedObjectContext, name: String? = nil) -> Kit {
        let duplicatedKit = Kit(context: context, name: name ?? "\(self.name ?? "Kit") Copy")
        
        // Copy master settings
        duplicatedKit.masterVolume = self.masterVolume
        duplicatedKit.masterPan = self.masterPan
        duplicatedKit.masterCompression = self.masterCompression
        duplicatedKit.masterReverb = self.masterReverb
        duplicatedKit.masterDelay = self.masterDelay
        duplicatedKit.masterDistortion = self.masterDistortion
        
        // Copy all tracks and machines
        for track in sortedTracks {
            if let newTrack = duplicatedKit.track(at: Int(track.slotNumber)) {
                newTrack.volume = track.volume
                newTrack.pan = track.pan
                newTrack.isMuted = track.isMuted
                newTrack.isSolo = track.isSolo
                newTrack.reverbSend = track.reverbSend
                newTrack.delaySend = track.delaySend
                
                // Duplicate machine if present
                if let machine = track.machine {
                    newTrack.machine = machine.duplicate(in: context)
                }
            }
        }
        
        return duplicatedKit
    }
    
    /// Reset kit to default state
    func resetToDefaults() {
        masterVolume = 0.8
        masterPan = 0.0
        masterCompression = false
        masterReverb = false
        masterDelay = false
        masterDistortion = false
        
        // Reset all tracks
        sortedTracks.forEach { track in
            track.resetToDefaults()
        }
        
        lastModified = Date()
    }
    
    /// Generate export metadata for kit sharing
    func exportMetadata() -> [String: Any] {
        return [
            "kitID": kitID?.uuidString ?? "",
            "name": name ?? "",
            "trackCount": trackCount,
            "activeTrackCount": activeTrackCount,
            "complexityScore": complexityScore,
            "masterVolume": masterVolume,
            "masterPan": masterPan,
            "masterCompression": masterCompression,
            "masterReverb": masterReverb,
            "masterDelay": masterDelay,
            "masterDistortion": masterDistortion,
            "createdAt": createdAt?.timeIntervalSince1970 ?? 0,
            "lastModified": lastModified?.timeIntervalSince1970 ?? 0
        ]
    }
    
    // MARK: - Validation
    
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateKit()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateKit()
    }
    
    private func validateKit() throws {
        // Validate name
        guard let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw KitError.emptyName
        }
        
        // Validate master volume
        guard masterVolume >= 0.0 && masterVolume <= 1.0 else {
            throw KitError.invalidVolume(masterVolume)
        }
        
        // Validate master pan
        guard masterPan >= -1.0 && masterPan <= 1.0 else {
            throw KitError.invalidPan(masterPan)
        }
        
        // Validate track count (should always be 16)
        guard trackCount == 16 else {
            throw KitError.invalidTrackCount(trackCount)
        }
    }
}

// MARK: - Kit Errors

enum KitError: LocalizedError {
    case emptyName
    case invalidVolume(Double)
    case invalidPan(Double)
    case invalidSlotNumber(Int)
    case invalidTrackCount(Int)
    
    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Kit name cannot be empty"
        case .invalidVolume(let volume):
            return "Invalid volume: \(volume). Must be between 0.0 and 1.0"
        case .invalidPan(let pan):
            return "Invalid pan: \(pan). Must be between -1.0 and 1.0"
        case .invalidSlotNumber(let slot):
            return "Invalid slot number: \(slot). Must be between 1 and 16"
        case .invalidTrackCount(let count):
            return "Invalid track count: \(count). Must be exactly 16"
        }
    }
} 