import CoreData
import Foundation

/// Base class for custom Core Data migration policies
open class BaseMigrationPolicy: NSEntityMigrationPolicy {
    
    // MARK: - Migration Utilities
    
    /// Safely migrates a string attribute with validation
    func migrateStringAttribute(
        from sourceAttribute: String,
        to destinationAttribute: String,
        in sourceInstance: NSManagedObject?,
        defaultValue: String = ""
    ) -> String {
        guard let sourceValue = sourceInstance?.value(forKey: sourceAttribute) as? String else {
            return defaultValue
        }
        return sourceValue.isEmpty ? defaultValue : sourceValue
    }
    
    /// Safely migrates a numeric attribute with validation
    func migrateNumericAttribute<T: Numeric>(
        from sourceAttribute: String,
        in sourceInstance: NSManagedObject?,
        defaultValue: T,
        type: T.Type
    ) -> T {
        guard let sourceValue = sourceInstance?.value(forKey: sourceAttribute) else {
            return defaultValue
        }
        
        if let numericValue = sourceValue as? T {
            return numericValue
        }
        
        return defaultValue
    }
    
    /// Safely migrates a date attribute
    func migrateDateAttribute(
        from sourceAttribute: String,
        in sourceInstance: NSManagedObject?,
        defaultValue: Date = Date()
    ) -> Date {
        guard let sourceValue = sourceInstance?.value(forKey: sourceAttribute) as? Date else {
            return defaultValue
        }
        return sourceValue
    }
    
    /// Migrates relationship data with validation
    func migrateRelationship(
        from sourceRelationship: String,
        in sourceInstance: NSManagedObject?
    ) -> NSManagedObject? {
        return sourceInstance?.value(forKey: sourceRelationship) as? NSManagedObject
    }
    
    // MARK: - Validation Helpers
    
    /// Validates that required attributes are present
    func validateRequiredAttributes(
        _ attributes: [String],
        in instance: NSManagedObject?
    ) -> Bool {
        guard let instance = instance else { return false }
        
        for attribute in attributes {
            if instance.value(forKey: attribute) == nil {
                print("⚠️ Missing required attribute: \(attribute)")
                return false
            }
        }
        
        return true
    }
    
    /// Validates numeric ranges
    func validateNumericRange<T: Comparable>(
        value: T,
        min: T,
        max: T,
        attributeName: String
    ) -> Bool {
        guard value >= min && value <= max else {
            print("⚠️ Value \(value) for \(attributeName) is outside valid range [\(min), \(max)]")
            return false
        }
        return true
    }
    
    // MARK: - Logging Helpers
    
    func logMigrationStart(for entityName: String) {
        print("🔄 Starting migration for entity: \(entityName)")
    }
    
    func logMigrationComplete(for entityName: String) {
        print("✅ Completed migration for entity: \(entityName)")
    }
    
    func logMigrationError(_ error: Error, for entityName: String) {
        print("❌ Migration error for \(entityName): \(error.localizedDescription)")
    }
} 