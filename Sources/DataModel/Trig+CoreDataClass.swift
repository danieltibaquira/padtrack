//
//  Trig+CoreDataClass.swift
//  PadTrack
//
//  Created by PadTrack on 2024.
//

import Foundation
import CoreData

@objc(Trig)
public class Trig: NSManagedObject {
    
    // MARK: - Convenience Initializers
    
    convenience init(context: NSManagedObjectContext, stepNumber: Int16) {
        self.init(context: context)
        self.trigID = UUID()
        self.stepNumber = stepNumber
        self.velocity = 0.0  // Default to off
        self.pitch = 0.0     // Center pitch
        self.duration = 1.0  // Full step duration
        self.probability = 1.0 // Always trigger when active
        self.retrigCount = 1
        self.retrigRate = 16  // 16th note retrigs
        self.microtiming = 0.0 // No timing offset
        self.createdAt = Date()
        self.lastModified = Date()
    }
    
    // MARK: - Computed Properties
    
    /// Check if trig is active (velocity > 0)
    var isActive: Bool {
        return velocity > 0.0
    }
    
    /// Check if trig is off (velocity = 0)
    var isOff: Bool {
        return velocity == 0.0
    }
    
    /// Check if trig has probability less than 100%
    var isProbabilistic: Bool {
        return probability < 1.0
    }
    
    /// Check if trig has retrig enabled
    var hasRetrig: Bool {
        return retrigCount > 1
    }
    
    /// Check if trig has microtiming offset
    var hasMicrotiming: Bool {
        return abs(microtiming) > 0.001
    }
    
    /// Check if trig has parameter locks
    var hasParameterLocks: Bool {
        guard let locks = parameterLocks as? Set<ParameterLock> else { return false }
        return !locks.isEmpty
    }
    
    /// Get parameter locks sorted by parameter name
    var sortedParameterLocks: [ParameterLock] {
        guard let locks = parameterLocks as? Set<ParameterLock> else { return [] }
        return locks.sorted { $0.parameterName ?? "" < $1.parameterName ?? "" }
    }
    
    /// Check if trig has been modified since creation
    var isModified: Bool {
        guard let created = createdAt, let modified = lastModified else { return false }
        return modified > created
    }
    
    /// Get display representation of step number (1-based)
    var displayStepNumber: Int {
        return Int(stepNumber)
    }
    
    /// Calculate effective trigger chance based on probability
    var effectiveTriggerChance: Double {
        return isActive ? probability : 0.0
    }
    
    // MARK: - Parameter Management
    
    /// Set velocity with validation
    func setVelocity(_ newVelocity: Double) throws {
        guard newVelocity >= 0.0 && newVelocity <= 1.0 else {
            throw TrigError.invalidVelocity(newVelocity)
        }
        velocity = newVelocity
        lastModified = Date()
    }
    
    /// Set pitch with validation
    func setPitch(_ newPitch: Double) throws {
        guard newPitch >= -1.0 && newPitch <= 1.0 else {
            throw TrigError.invalidPitch(newPitch)
        }
        pitch = newPitch
        lastModified = Date()
    }
    
    /// Set duration with validation
    func setDuration(_ newDuration: Double) throws {
        guard newDuration > 0.0 && newDuration <= 4.0 else {
            throw TrigError.invalidDuration(newDuration)
        }
        duration = newDuration
        lastModified = Date()
    }
    
    /// Set probability with validation
    func setProbability(_ newProbability: Double) throws {
        guard newProbability >= 0.0 && newProbability <= 1.0 else {
            throw TrigError.invalidProbability(newProbability)
        }
        probability = newProbability
        lastModified = Date()
    }
    
    /// Set retrig count with validation
    func setRetrigCount(_ count: Int16) throws {
        guard count >= 1 && count <= 8 else {
            throw TrigError.invalidRetrigCount(Int(count))
        }
        retrigCount = count
        lastModified = Date()
    }
    
    /// Set retrig rate with validation
    func setRetrigRate(_ rate: Int16) throws {
        let validRates: [Int16] = [4, 8, 16, 32, 64] // Note divisions
        guard validRates.contains(rate) else {
            throw TrigError.invalidRetrigRate(Int(rate))
        }
        retrigRate = rate
        lastModified = Date()
    }
    
    /// Set microtiming with validation
    func setMicrotiming(_ timing: Double) throws {
        guard timing >= -0.5 && timing <= 0.5 else {
            throw TrigError.invalidMicrotiming(timing)
        }
        microtiming = timing
        lastModified = Date()
    }
    
    // MARK: - Trig Operations
    
    /// Activate trig with default velocity
    func activate(velocity: Double = 0.8) throws {
        try setVelocity(velocity)
    }
    
    /// Deactivate trig (set velocity to 0)
    func deactivate() {
        velocity = 0.0
        lastModified = Date()
    }
    
    /// Toggle trig active state
    func toggle(defaultVelocity: Double = 0.8) throws {
        if isActive {
            deactivate()
        } else {
            try activate(velocity: defaultVelocity)
        }
    }
    
    /// Copy settings from another trig
    func copySettings(from sourceTrig: Trig) {
        velocity = sourceTrig.velocity
        pitch = sourceTrig.pitch
        duration = sourceTrig.duration
        probability = sourceTrig.probability
        retrigCount = sourceTrig.retrigCount
        retrigRate = sourceTrig.retrigRate
        microtiming = sourceTrig.microtiming
        lastModified = Date()
    }
    
    /// Reset trig to default inactive state
    func resetToDefaults() {
        velocity = 0.0
        pitch = 0.0
        duration = 1.0
        probability = 1.0
        retrigCount = 1
        retrigRate = 16
        microtiming = 0.0
        
        // Clear all parameter locks
        removeAllParameterLocks()
        
        lastModified = Date()
    }
    
    /// Randomize trig parameters
    func randomize(velocityRange: ClosedRange<Double> = 0.3...0.9,
                  pitchRange: ClosedRange<Double> = -0.5...0.5,
                  probabilityRange: ClosedRange<Double> = 0.7...1.0) {
        velocity = Double.random(in: velocityRange)
        pitch = Double.random(in: pitchRange)
        probability = Double.random(in: probabilityRange)
        
        // Occasionally add retrig
        if Double.random(in: 0...1) < 0.1 {
            retrigCount = Int16.random(in: 2...4)
        }
        
        lastModified = Date()
    }
    
    // MARK: - Parameter Lock Management
    
    /// Add parameter lock for specific parameter
    func addParameterLock(parameterName: String, value: Double) throws {
        guard let context = managedObjectContext else {
            throw TrigError.noManagedObjectContext
        }
        
        // Remove existing lock for this parameter
        removeParameterLock(for: parameterName)
        
        // Create new parameter lock
        let parameterLock = ParameterLock(context: context, 
                                        parameterName: parameterName, 
                                        value: value)
        parameterLock.trig = self
        
        lastModified = Date()
    }
    
    /// Remove parameter lock for specific parameter
    func removeParameterLock(for parameterName: String) {
        guard let locks = parameterLocks as? Set<ParameterLock> else { return }
        
        if let lockToRemove = locks.first(where: { $0.parameterName == parameterName }) {
            managedObjectContext?.delete(lockToRemove)
            lastModified = Date()
        }
    }
    
    /// Get parameter lock value for specific parameter
    func parameterLockValue(for parameterName: String) -> Double? {
        guard let locks = parameterLocks as? Set<ParameterLock> else { return nil }
        return locks.first(where: { $0.parameterName == parameterName })?.value
    }
    
    /// Check if parameter has a lock
    func hasParameterLock(for parameterName: String) -> Bool {
        return parameterLockValue(for: parameterName) != nil
    }
    
    /// Remove all parameter locks
    func removeAllParameterLocks() {
        guard let locks = parameterLocks as? Set<ParameterLock>,
              let context = managedObjectContext else { return }
        
        for lock in locks {
            context.delete(lock)
        }
        lastModified = Date()
    }
    
    // MARK: - Timing Calculations
    
    /// Calculate absolute timing position in beats
    func absoluteTimingPosition(stepLength: Double = 0.25) -> Double {
        let basePosition = Double(stepNumber - 1) * stepLength
        return basePosition + (microtiming * stepLength)
    }
    
    /// Calculate retrig timing positions
    func retrigTimingPositions(stepLength: Double = 0.25) -> [Double] {
        guard hasRetrig else { return [absoluteTimingPosition(stepLength: stepLength)] }
        
        var positions: [Double] = []
        let retrigInterval = stepLength / Double(retrigCount)
        let basePosition = absoluteTimingPosition(stepLength: stepLength)
        
        for i in 0..<retrigCount {
            positions.append(basePosition + (Double(i) * retrigInterval))
        }
        
        return positions
    }
    
    // MARK: - Export and Metadata
    
    /// Generate export metadata
    func exportMetadata() -> [String: Any] {
        return [
            "trigID": trigID?.uuidString ?? "",
            "stepNumber": stepNumber,
            "velocity": velocity,
            "pitch": pitch,
            "duration": duration,
            "probability": probability,
            "retrigCount": retrigCount,
            "retrigRate": retrigRate,
            "microtiming": microtiming,
            "isActive": isActive,
            "hasRetrig": hasRetrig,
            "hasMicrotiming": hasMicrotiming,
            "hasParameterLocks": hasParameterLocks,
            "parameterLockCount": sortedParameterLocks.count,
            "createdAt": createdAt?.timeIntervalSince1970 ?? 0,
            "lastModified": lastModified?.timeIntervalSince1970 ?? 0
        ]
    }
    
    // MARK: - Validation
    
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateTrig()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateTrig()
    }
    
    private func validateTrig() throws {
        // Validate step number
        guard stepNumber >= 1 && stepNumber <= 64 else {
            throw TrigError.invalidStepNumber(Int(stepNumber))
        }
        
        // Validate velocity
        guard velocity >= 0.0 && velocity <= 1.0 else {
            throw TrigError.invalidVelocity(velocity)
        }
        
        // Validate pitch
        guard pitch >= -1.0 && pitch <= 1.0 else {
            throw TrigError.invalidPitch(pitch)
        }
        
        // Validate duration
        guard duration > 0.0 && duration <= 4.0 else {
            throw TrigError.invalidDuration(duration)
        }
        
        // Validate probability
        guard probability >= 0.0 && probability <= 1.0 else {
            throw TrigError.invalidProbability(probability)
        }
        
        // Validate retrig count
        guard retrigCount >= 1 && retrigCount <= 8 else {
            throw TrigError.invalidRetrigCount(Int(retrigCount))
        }
        
        // Validate microtiming
        guard microtiming >= -0.5 && microtiming <= 0.5 else {
            throw TrigError.invalidMicrotiming(microtiming)
        }
    }
}

// MARK: - Trig Errors

enum TrigError: LocalizedError {
    case invalidStepNumber(Int)
    case invalidVelocity(Double)
    case invalidPitch(Double)
    case invalidDuration(Double)
    case invalidProbability(Double)
    case invalidRetrigCount(Int)
    case invalidRetrigRate(Int)
    case invalidMicrotiming(Double)
    case noManagedObjectContext
    
    var errorDescription: String? {
        switch self {
        case .invalidStepNumber(let step):
            return "Invalid step number: \(step). Must be between 1 and 64"
        case .invalidVelocity(let velocity):
            return "Invalid velocity: \(velocity). Must be between 0.0 and 1.0"
        case .invalidPitch(let pitch):
            return "Invalid pitch: \(pitch). Must be between -1.0 and 1.0"
        case .invalidDuration(let duration):
            return "Invalid duration: \(duration). Must be between 0.0 and 4.0"
        case .invalidProbability(let probability):
            return "Invalid probability: \(probability). Must be between 0.0 and 1.0"
        case .invalidRetrigCount(let count):
            return "Invalid retrig count: \(count). Must be between 1 and 8"
        case .invalidRetrigRate(let rate):
            return "Invalid retrig rate: \(rate). Must be 4, 8, 16, 32, or 64"
        case .invalidMicrotiming(let timing):
            return "Invalid microtiming: \(timing). Must be between -0.5 and 0.5"
        case .noManagedObjectContext:
            return "No managed object context available"
        }
    }
} 