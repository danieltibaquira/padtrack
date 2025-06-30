//
//  Track+CoreDataClass.swift
//  PadTrack
//
//  Created by PadTrack on 2024.
//

import Foundation
import CoreData

@objc(Track)
public class Track: NSManagedObject {
    
    // MARK: - Convenience Initializers
    
    convenience init(context: NSManagedObjectContext, slotNumber: Int16) {
        self.init(context: context)
        self.trackID = UUID()
        self.slotNumber = slotNumber
        self.volume = 0.8
        self.pan = 0.0
        self.isMuted = false
        self.isSolo = false
        self.reverbSend = 0.0
        self.delaySend = 0.0
        self.createdAt = Date()
        self.lastModified = Date()
    }
    
    // MARK: - Computed Properties
    
    /// Check if track has an assigned machine
    var hasMachine: Bool {
        return machine != nil
    }
    
    /// Check if track is effectively audible (not muted and has machine)
    var isAudible: Bool {
        return hasMachine && !isMuted && !isEffectivelyMuted
    }
    
    /// Check if track is effectively muted due to solo on other tracks
    var isEffectivelyMuted: Bool {
        guard let kit = kit,
              let tracks = kit.tracks as? Set<Track> else { return false }
        
        let soloTracks = tracks.filter { $0.isSolo }
        return !soloTracks.isEmpty && !isSolo
    }
    
    /// Get the display name for this track
    var displayName: String {
        if let machineName = machine?.name, !machineName.isEmpty {
            return "\(slotNumber): \(machineName)"
        }
        return "Track \(slotNumber)"
    }
    
    /// Calculate effective volume considering mute states
    var effectiveVolume: Double {
        if isMuted || isEffectivelyMuted {
            return 0.0
        }
        return volume
    }
    
    /// Check if track has been modified since creation
    var isModified: Bool {
        guard let created = createdAt, let modified = lastModified else { return false }
        return modified > created
    }
    
    /// Get all trigs for this track sorted by step number
    var sortedTrigs: [Trig] {
        guard let trigs = trigs as? Set<Trig> else { return [] }
        return trigs.sorted { $0.stepNumber < $1.stepNumber }
    }
    
    /// Count of active trigs (non-zero velocity)
    var activeTrigCount: Int {
        return sortedTrigs.filter { $0.velocity > 0 }.count
    }
    
    /// Check if track has any active steps
    var hasActiveSteps: Bool {
        return activeTrigCount > 0
    }
    
    // MARK: - Volume and Pan Management
    
    /// Set volume with validation
    func setVolume(_ newVolume: Double) throws {
        guard newVolume >= 0.0 && newVolume <= 1.0 else {
            throw TrackError.invalidVolume(newVolume)
        }
        volume = newVolume
        lastModified = Date()
    }
    
    /// Set pan with validation
    func setPan(_ newPan: Double) throws {
        guard newPan >= -1.0 && newPan <= 1.0 else {
            throw TrackError.invalidPan(newPan)
        }
        pan = newPan
        lastModified = Date()
    }
    
    /// Set reverb send with validation
    func setReverbSend(_ send: Double) throws {
        guard send >= 0.0 && send <= 1.0 else {
            throw TrackError.invalidSendLevel(send)
        }
        reverbSend = send
        lastModified = Date()
    }
    
    /// Set delay send with validation
    func setDelaySend(_ send: Double) throws {
        guard send >= 0.0 && send <= 1.0 else {
            throw TrackError.invalidSendLevel(send)
        }
        delaySend = send
        lastModified = Date()
    }
    
    // MARK: - Mute and Solo Management
    
    /// Toggle mute state
    func toggleMute() {
        isMuted.toggle()
        lastModified = Date()
    }
    
    /// Set mute state explicitly
    func setMute(_ muted: Bool) {
        isMuted = muted
        lastModified = Date()
    }
    
    /// Toggle solo state
    func toggleSolo() {
        isSolo.toggle()
        lastModified = Date()
        
        // Notify kit that solo state changed
        kit?.lastModified = Date()
    }
    
    /// Set solo state explicitly
    func setSolo(_ solo: Bool) {
        isSolo = solo
        lastModified = Date()
        
        // Notify kit that solo state changed
        kit?.lastModified = Date()
    }
    
    /// Clear solo from this track and all other tracks in the kit
    func clearAllSolo() {
        guard let kit = kit,
              let tracks = kit.tracks as? Set<Track> else { return }
        
        for track in tracks {
            track.isSolo = false
        }
        lastModified = Date()
        kit.lastModified = Date()
    }
    
    // MARK: - Machine Management
    
    /// Assign a machine to this track
    func assignMachine(_ newMachine: Machine) {
        // Remove machine from previous track if assigned
        if let previousTrack = newMachine.track {
            previousTrack.machine = nil
            previousTrack.lastModified = Date()
        }
        
        machine = newMachine
        lastModified = Date()
    }
    
    /// Remove machine from this track
    func removeMachine() {
        machine = nil
        lastModified = Date()
    }
    
    /// Get machine type name if available
    var machineTypeName: String? {
        return machine?.typeName
    }
    
    // MARK: - Trig Management
    
    /// Get trig at specific step number
    func trig(at stepNumber: Int16) -> Trig? {
        guard let trigs = trigs as? Set<Trig> else { return nil }
        return trigs.first { $0.stepNumber == stepNumber }
    }
    
    /// Create or update trig at step
    func setTrig(at stepNumber: Int16, velocity: Double = 0.8, pitch: Double = 0.0, duration: Double = 1.0) throws {
        guard let context = managedObjectContext else {
            throw TrackError.noManagedObjectContext
        }
        
        // Validate step number
        guard stepNumber >= 1 && stepNumber <= 64 else {
            throw TrackError.invalidStepNumber(Int(stepNumber))
        }
        
        // Get or create trig
        let targetTrig: Trig
        if let existingTrig = trig(at: stepNumber) {
            targetTrig = existingTrig
        } else {
            targetTrig = Trig(context: context, stepNumber: stepNumber)
            targetTrig.track = self
        }
        
        // Set trig parameters
        try targetTrig.setVelocity(velocity)
        try targetTrig.setPitch(pitch)
        try targetTrig.setDuration(duration)
        
        lastModified = Date()
    }
    
    /// Clear trig at step (set velocity to 0)
    func clearTrig(at stepNumber: Int16) {
        if let targetTrig = trig(at: stepNumber) {
            targetTrig.velocity = 0.0
            targetTrig.lastModified = Date()
            lastModified = Date()
        }
    }
    
    /// Clear all trigs on this track
    func clearAllTrigs() {
        sortedTrigs.forEach { trig in
            trig.velocity = 0.0
            trig.lastModified = Date()
        }
        lastModified = Date()
    }
    
    /// Randomize trig pattern
    func randomizeTrigs(density: Double = 0.3, velocityRange: ClosedRange<Double> = 0.3...0.9) {
        guard density >= 0.0 && density <= 1.0 else { return }
        
        for trig in sortedTrigs {
            if Double.random(in: 0...1) < density {
                trig.velocity = Double.random(in: velocityRange)
                trig.pitch = Double.random(in: -1.0...1.0)
            } else {
                trig.velocity = 0.0
            }
            trig.lastModified = Date()
        }
        lastModified = Date()
    }
    
    // MARK: - Track Operations
    
    /// Copy settings from another track
    func copySettings(from sourceTrack: Track) {
        volume = sourceTrack.volume
        pan = sourceTrack.pan
        isMuted = sourceTrack.isMuted
        isSolo = sourceTrack.isSolo
        reverbSend = sourceTrack.reverbSend
        delaySend = sourceTrack.delaySend
        lastModified = Date()
    }
    
    /// Reset track to default settings
    func resetToDefaults() {
        volume = 0.8
        pan = 0.0
        isMuted = false
        isSolo = false
        reverbSend = 0.0
        delaySend = 0.0
        
        // Clear all trigs
        clearAllTrigs()
        
        lastModified = Date()
    }
    
    /// Duplicate track with same settings but no machine
    func duplicateSettings(in context: NSManagedObjectContext, slotNumber: Int16) -> Track {
        let duplicatedTrack = Track(context: context, slotNumber: slotNumber)
        duplicatedTrack.copySettings(from: self)
        return duplicatedTrack
    }
    
    /// Generate export metadata
    func exportMetadata() -> [String: Any] {
        return [
            "trackID": trackID?.uuidString ?? "",
            "slotNumber": slotNumber,
            "volume": volume,
            "pan": pan,
            "isMuted": isMuted,
            "isSolo": isSolo,
            "reverbSend": reverbSend,
            "delaySend": delaySend,
            "hasMachine": hasMachine,
            "machineType": machine?.typeName ?? "",
            "activeTrigCount": activeTrigCount,
            "hasActiveSteps": hasActiveSteps,
            "createdAt": createdAt?.timeIntervalSince1970 ?? 0,
            "lastModified": lastModified?.timeIntervalSince1970 ?? 0
        ]
    }
    
    // MARK: - Performance Helpers
    
    /// Calculate track activity score for UI indicators
    var activityScore: Double {
        let trigDensity = Double(activeTrigCount) / Double(max(sortedTrigs.count, 1))
        let volumeContribution = effectiveVolume
        return min(trigDensity * volumeContribution, 1.0)
    }
    
    /// Check if track contributes to mix (has machine and active steps)
    var contributesToMix: Bool {
        return hasMachine && hasActiveSteps && !isEffectivelyMuted
    }
    
    // MARK: - Validation
    
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateTrack()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateTrack()
    }
    
    private func validateTrack() throws {
        // Validate slot number
        guard slotNumber >= 1 && slotNumber <= 16 else {
            throw TrackError.invalidSlotNumber(Int(slotNumber))
        }
        
        // Validate volume
        guard volume >= 0.0 && volume <= 1.0 else {
            throw TrackError.invalidVolume(volume)
        }
        
        // Validate pan
        guard pan >= -1.0 && pan <= 1.0 else {
            throw TrackError.invalidPan(pan)
        }
        
        // Validate send levels
        guard reverbSend >= 0.0 && reverbSend <= 1.0 else {
            throw TrackError.invalidSendLevel(reverbSend)
        }
        
        guard delaySend >= 0.0 && delaySend <= 1.0 else {
            throw TrackError.invalidSendLevel(delaySend)
        }
    }
}

// MARK: - Track Errors

enum TrackError: LocalizedError {
    case invalidSlotNumber(Int)
    case invalidVolume(Double)
    case invalidPan(Double)
    case invalidSendLevel(Double)
    case invalidStepNumber(Int)
    case noManagedObjectContext
    
    var errorDescription: String? {
        switch self {
        case .invalidSlotNumber(let slot):
            return "Invalid slot number: \(slot). Must be between 1 and 16"
        case .invalidVolume(let volume):
            return "Invalid volume: \(volume). Must be between 0.0 and 1.0"
        case .invalidPan(let pan):
            return "Invalid pan: \(pan). Must be between -1.0 and 1.0"
        case .invalidSendLevel(let level):
            return "Invalid send level: \(level). Must be between 0.0 and 1.0"
        case .invalidStepNumber(let step):
            return "Invalid step number: \(step). Must be between 1 and 64"
        case .noManagedObjectContext:
            return "No managed object context available"
        }
    }
} 