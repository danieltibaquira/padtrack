//
//  CoreDataValidation.swift
//  PadTrack
//
//  Created by PadTrack on 2024.
//

import Foundation
import CoreData

// MARK: - Core Data Validation Framework

/// Comprehensive validation framework for PadTrack Core Data entities
public struct CoreDataValidation {
    
    // MARK: - String Validation
    
    /// Validate string is not empty after trimming whitespace
    static func validateNonEmptyString(_ value: String?, fieldName: String) throws {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            throw ValidationError.emptyRequiredField(fieldName)
        }
    }
    
    /// Validate string length is within bounds
    static func validateStringLength(_ value: String?, fieldName: String, minLength: Int = 1, maxLength: Int = 100) throws {
        guard let value = value else {
            throw ValidationError.emptyRequiredField(fieldName)
        }
        
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minLength else {
            throw ValidationError.stringTooShort(fieldName, minLength)
        }
        
        guard trimmed.count <= maxLength else {
            throw ValidationError.stringTooLong(fieldName, maxLength)
        }
    }
    
    /// Validate string matches pattern
    static func validateStringPattern(_ value: String?, fieldName: String, pattern: String) throws {
        guard let value = value else {
            throw ValidationError.emptyRequiredField(fieldName)
        }
        
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: value.utf16.count)
        let matches = regex.matches(in: value, options: [], range: range)
        
        guard !matches.isEmpty else {
            throw ValidationError.invalidFormat(fieldName, pattern)
        }
    }
    
    // MARK: - Numeric Validation
    
    /// Validate double is within range
    static func validateDoubleRange(_ value: Double, fieldName: String, min: Double, max: Double) throws {
        guard value >= min else {
            throw ValidationError.valueTooLow(fieldName, min)
        }
        
        guard value <= max else {
            throw ValidationError.valueTooHigh(fieldName, max)
        }
    }
    
    /// Validate float is within range
    static func validateFloatRange(_ value: Float, fieldName: String, min: Float, max: Float) throws {
        guard value >= min else {
            throw ValidationError.valueTooLow(fieldName, Double(min))
        }
        
        guard value <= max else {
            throw ValidationError.valueTooHigh(fieldName, Double(max))
        }
    }
    
    /// Validate integer is within range
    static func validateIntRange(_ value: Int, fieldName: String, min: Int, max: Int) throws {
        guard value >= min else {
            throw ValidationError.valueTooLow(fieldName, Double(min))
        }
        
        guard value <= max else {
            throw ValidationError.valueTooHigh(fieldName, Double(max))
        }
    }
    
    /// Validate Int16 is within range
    static func validateInt16Range(_ value: Int16, fieldName: String, min: Int16, max: Int16) throws {
        guard value >= min else {
            throw ValidationError.valueTooLow(fieldName, Double(min))
        }
        
        guard value <= max else {
            throw ValidationError.valueTooHigh(fieldName, Double(max))
        }
    }
    
    /// Validate positive number
    static func validatePositive(_ value: Double, fieldName: String) throws {
        try validateDoubleRange(value, fieldName: fieldName, min: 0.0, max: .greatestFiniteMagnitude)
    }
    
    /// Validate normalized value (0.0 to 1.0)
    static func validateNormalized(_ value: Double, fieldName: String) throws {
        try validateDoubleRange(value, fieldName: fieldName, min: 0.0, max: 1.0)
    }
    
    /// Validate bipolar value (-1.0 to 1.0)
    static func validateBipolar(_ value: Double, fieldName: String) throws {
        try validateDoubleRange(value, fieldName: fieldName, min: -1.0, max: 1.0)
    }
    
    // MARK: - Audio-Specific Validation
    
    /// Validate tempo (BPM)
    static func validateTempo(_ bpm: Double, fieldName: String = "tempo") throws {
        try validateDoubleRange(bpm, fieldName: fieldName, min: 60.0, max: 200.0)
    }
    
    /// Validate frequency (Hz)
    static func validateFrequency(_ frequency: Double, fieldName: String = "frequency") throws {
        try validateDoubleRange(frequency, fieldName: fieldName, min: 20.0, max: 20000.0)
    }
    
    /// Validate pitch (MIDI note number)
    static func validateMidiNote(_ note: Double, fieldName: String = "note") throws {
        try validateDoubleRange(note, fieldName: fieldName, min: 0.0, max: 127.0)
    }
    
    /// Validate velocity (MIDI velocity)
    static func validateVelocity(_ velocity: Double, fieldName: String = "velocity") throws {
        try validateDoubleRange(velocity, fieldName: fieldName, min: 0.0, max: 1.0)
    }
    
    /// Validate duration (in beats)
    static func validateDuration(_ duration: Double, fieldName: String = "duration") throws {
        try validateDoubleRange(duration, fieldName: fieldName, min: 0.0, max: 16.0)
    }
    
    /// Validate probability (0.0 to 1.0)
    static func validateProbability(_ probability: Double, fieldName: String = "probability") throws {
        try validateNormalized(probability, fieldName: fieldName)
    }
    
    /// Validate pan position (-1.0 to 1.0)
    static func validatePan(_ pan: Double, fieldName: String = "pan") throws {
        try validateBipolar(pan, fieldName: fieldName)
    }
    
    /// Validate volume level (0.0 to 1.0)
    static func validateVolume(_ volume: Double, fieldName: String = "volume") throws {
        try validateNormalized(volume, fieldName: fieldName)
    }
    
    /// Validate swing amount (0.0 to 1.0)
    static func validateSwing(_ swing: Double, fieldName: String = "swing") throws {
        try validateNormalized(swing, fieldName: fieldName)
    }
    
    // MARK: - Sequencer-Specific Validation
    
    /// Validate step number (1-based)
    static func validateStepNumber(_ step: Int16, maxSteps: Int16 = 16, fieldName: String = "stepNumber") throws {
        try validateInt16Range(step, fieldName: fieldName, min: 1, max: maxSteps)
    }
    
    /// Validate track number (1-based)
    static func validateTrackNumber(_ track: Int16, maxTracks: Int16 = 16, fieldName: String = "trackNumber") throws {
        try validateInt16Range(track, fieldName: fieldName, min: 1, max: maxTracks)
    }
    
    /// Validate pattern length
    static func validatePatternLength(_ length: Int16, fieldName: String = "length") throws {
        try validateInt16Range(length, fieldName: fieldName, min: 1, max: 64)
    }
    
    /// Validate polyphony
    static func validatePolyphony(_ voices: Int16, fieldName: String = "polyphony") throws {
        try validateInt16Range(voices, fieldName: fieldName, min: 1, max: 32)
    }
    
    /// Validate retrig count
    static func validateRetrigCount(_ count: Int16, fieldName: String = "retrigCount") throws {
        try validateInt16Range(count, fieldName: fieldName, min: 1, max: 8)
    }
    
    /// Validate retrig rate (subdivision)
    static func validateRetrigRate(_ rate: Int16, fieldName: String = "retrigRate") throws {
        let validRates: [Int16] = [4, 8, 16, 32]  // Quarter, eighth, sixteenth, thirty-second notes
        guard validRates.contains(rate) else {
            throw ValidationError.invalidRetrigRate(rate, validRates)
        }
    }
    
    // MARK: - Relationship Validation
    
    /// Validate required relationship exists
    static func validateRequiredRelationship<T: NSManagedObject>(_ object: T?, relationshipName: String) throws {
        guard object != nil else {
            throw ValidationError.missingRequiredRelationship(relationshipName)
        }
    }
    
    /// Validate relationship count is within bounds
    static func validateRelationshipCount(_ objects: NSSet?, relationshipName: String, min: Int = 0, max: Int = Int.max) throws {
        let count = objects?.count ?? 0
        
        guard count >= min else {
            throw ValidationError.relationshipCountTooLow(relationshipName, min)
        }
        
        guard count <= max else {
            throw ValidationError.relationshipCountTooHigh(relationshipName, max)
        }
    }
    
    // MARK: - Date Validation
    
    /// Validate date is not in the future
    static func validateDateNotFuture(_ date: Date?, fieldName: String) throws {
        guard let date = date else {
            throw ValidationError.emptyRequiredField(fieldName)
        }
        
        guard date <= Date() else {
            throw ValidationError.dateInFuture(fieldName)
        }
    }
    
    /// Validate date order (first date should be before or equal to second)
    static func validateDateOrder(_ firstDate: Date?, _ secondDate: Date?, firstFieldName: String, secondFieldName: String) throws {
        guard let first = firstDate, let second = secondDate else {
            return  // Skip validation if either date is nil
        }
        
        guard first <= second else {
            throw ValidationError.invalidDateOrder(firstFieldName, secondFieldName)
        }
    }
    
    // MARK: - UUID Validation
    
    /// Validate UUID is not nil
    static func validateUUID(_ uuid: UUID?, fieldName: String) throws {
        guard uuid != nil else {
            throw ValidationError.emptyRequiredField(fieldName)
        }
    }
    
    // MARK: - Binary Data Validation
    
    /// Validate binary data size
    static func validateBinaryDataSize(_ data: Data?, fieldName: String, maxSize: Int = 1_000_000) throws {
        guard let data = data else {
            return  // Nil data is valid for optional fields
        }
        
        guard data.count <= maxSize else {
            throw ValidationError.binaryDataTooLarge(fieldName, maxSize)
        }
    }
    
    // MARK: - Machine-Specific Validation
    
    /// Validate machine type name
    static func validateMachineType(_ typeName: String?, fieldName: String = "machineType") throws {
        try validateNonEmptyString(typeName, fieldName: fieldName)
        
        guard let typeName = typeName else { return }
        
        let validTypes = ["VoiceMachine", "FilterMachine", "FXMachine", "DrumMachine", "SamplerMachine"]
        guard validTypes.contains(typeName) else {
            throw ValidationError.invalidMachineType(typeName, validTypes)
        }
    }
    
    /// Validate preset name
    static func validatePresetName(_ name: String?, fieldName: String = "presetName") throws {
        try validateStringLength(name, fieldName: fieldName, minLength: 1, maxLength: 50)
    }
    
    /// Validate project name
    static func validateProjectName(_ name: String?, fieldName: String = "projectName") throws {
        try validateStringLength(name, fieldName: fieldName, minLength: 1, maxLength: 100)
    }
    
    /// Validate pattern name
    static func validatePatternName(_ name: String?, fieldName: String = "patternName") throws {
        try validateStringLength(name, fieldName: fieldName, minLength: 1, maxLength: 50)
    }
    
    /// Validate kit name
    static func validateKitName(_ name: String?, fieldName: String = "kitName") throws {
        try validateStringLength(name, fieldName: fieldName, minLength: 1, maxLength: 50)
    }
}

// MARK: - Validation Errors

/// Comprehensive validation error types for Core Data entities
public enum ValidationError: LocalizedError {
    // String errors
    case emptyRequiredField(String)
    case stringTooShort(String, Int)
    case stringTooLong(String, Int)
    case invalidFormat(String, String)
    
    // Numeric errors
    case valueTooLow(String, Double)
    case valueTooHigh(String, Double)
    
    // Audio-specific errors
    case invalidMachineType(String, [String])
    case invalidRetrigRate(Int16, [Int16])
    
    // Relationship errors
    case missingRequiredRelationship(String)
    case relationshipCountTooLow(String, Int)
    case relationshipCountTooHigh(String, Int)
    
    // Date errors
    case dateInFuture(String)
    case invalidDateOrder(String, String)
    
    // Data errors
    case binaryDataTooLarge(String, Int)

    // General validation errors (for compatibility with ValidationService)
    case invalidName(String)
    case invalidValue(String)
    case relationshipConstraint(String)
    case businessRuleViolation(String)
    
    public var errorDescription: String? {
        switch self {
        case .emptyRequiredField(let field):
            return "\(field) is required and cannot be empty"
        case .stringTooShort(let field, let minLength):
            return "\(field) must be at least \(minLength) characters long"
        case .stringTooLong(let field, let maxLength):
            return "\(field) cannot be longer than \(maxLength) characters"
        case .invalidFormat(let field, let pattern):
            return "\(field) format is invalid. Expected pattern: \(pattern)"
        case .valueTooLow(let field, let min):
            return "\(field) must be at least \(min)"
        case .valueTooHigh(let field, let max):
            return "\(field) cannot exceed \(max)"
        case .invalidMachineType(let type, let validTypes):
            return "Invalid machine type '\(type)'. Valid types: \(validTypes.joined(separator: ", "))"
        case .invalidRetrigRate(let rate, let validRates):
            return "Invalid retrig rate '\(rate)'. Valid rates: \(validRates.map(String.init).joined(separator: ", "))"
        case .missingRequiredRelationship(let relationship):
            return "Required relationship '\(relationship)' is missing"
        case .relationshipCountTooLow(let relationship, let min):
            return "Relationship '\(relationship)' must have at least \(min) objects"
        case .relationshipCountTooHigh(let relationship, let max):
            return "Relationship '\(relationship)' cannot have more than \(max) objects"
        case .dateInFuture(let field):
            return "\(field) cannot be in the future"
        case .invalidDateOrder(let firstField, let secondField):
            return "\(firstField) must be before or equal to \(secondField)"
        case .binaryDataTooLarge(let field, let maxSize):
            return "\(field) data size exceeds maximum allowed size of \(maxSize) bytes"
        case .invalidName(let message):
            return "Invalid name: \(message)"
        case .invalidValue(let message):
            return "Invalid value: \(message)"
        case .relationshipConstraint(let message):
            return "Relationship constraint: \(message)"
        case .businessRuleViolation(let message):
            return "Business rule violation: \(message)"
        }
    }
    
    public var failureReason: String? {
        return errorDescription
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .emptyRequiredField:
            return "Please provide a valid value for this field"
        case .stringTooShort:
            return "Please enter a longer value"
        case .stringTooLong:
            return "Please enter a shorter value"
        case .invalidFormat:
            return "Please check the format and try again"
        case .valueTooLow, .valueTooHigh:
            return "Please enter a value within the valid range"
        case .invalidMachineType:
            return "Please select a valid machine type from the list"
        case .invalidRetrigRate:
            return "Please select a valid retrig rate from the available options"
        case .missingRequiredRelationship:
            return "Please establish the required relationship before saving"
        case .relationshipCountTooLow, .relationshipCountTooHigh:
            return "Please adjust the number of related objects"
        case .dateInFuture:
            return "Please select a date that is today or in the past"
        case .invalidDateOrder:
            return "Please ensure dates are in the correct order"
        case .binaryDataTooLarge:
            return "Please reduce the size of the data or use external storage"
        case .invalidName:
            return "Please provide a valid name following the specified format and length requirements."
        case .invalidValue:
            return "Please ensure the value is within the valid range and format."
        case .relationshipConstraint:
            return "Please ensure all required relationships are properly established."
        case .businessRuleViolation:
            return "Please review and correct the data to comply with business rules."
        }
    }
}

// MARK: - Validation Result

/// Result type for validation operations
public enum ValidationResult {
    case success
    case failure([ValidationError])
    
    var isValid: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    var errors: [ValidationError] {
        switch self {
        case .success:
            return []
        case .failure(let errors):
            return errors
        }
    }
}

// MARK: - Validation Protocol

/// Protocol for entities that support comprehensive validation
public protocol ValidatableEntity {
    func validateEntity() throws
    func validateEntityAndCollectErrors() -> ValidationResult
}

// MARK: - Default Implementation

public extension ValidatableEntity where Self: NSManagedObject {
    
    /// Validate entity and collect all errors
    func validateEntityAndCollectErrors() -> ValidationResult {
        var errors: [ValidationError] = []
        
        do {
            try validateEntity()
        } catch let error as ValidationError {
            errors.append(error)
        } catch {
            // Convert other errors to validation errors
            errors.append(.emptyRequiredField("Unknown field: \(error.localizedDescription)"))
        }
        
        return errors.isEmpty ? .success : .failure(errors)
    }
} 