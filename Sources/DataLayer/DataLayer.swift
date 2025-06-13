// DataLayer.swift
// DigitonePad - DataLayer Module
//
// This module handles data persistence and Core Data management.

import Foundation
import CoreData
import MachineProtocols

/// Main interface for data persistence operations
public class DataLayerManager {
    @MainActor public static let shared = DataLayerManager()
    
    private let container: NSPersistentContainer
    
    private init() {
        // Correctly locate the model in the DataLayer framework bundle
        guard let modelURL = Bundle(for: DataLayerManager.self).url(forResource: "DigitonePad", withExtension: "momd") else {
            fatalError("Failed to find data model")
        }
        guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to create model from file: \(modelURL)")
        }

        container = NSPersistentContainer(name: "DigitonePad", managedObjectModel: managedObjectModel)
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }
    
    /// The main view context
    public var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    /// Save current context
    public func save() throws {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                throw error
            }
        }
    }
}

/// Placeholder for Core Data entities
public struct ProjectEntity {
    public let id: UUID
    public let name: String
    public let createdAt: Date
    
    public init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
} 