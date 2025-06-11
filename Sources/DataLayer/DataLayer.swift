// DataLayer.swift
// DigitonePad - DataLayer Module
//
// This module handles data persistence and Core Data management.

import Foundation
import MachineProtocols

/// Main interface for data persistence operations
public class DataLayerManager {
    public static let shared = DataLayerManager()
    
    private init() {}
    
    /// Initialize the data layer
    public func initialize() {
        // TODO: Initialize Core Data stack
    }
    
    /// Save current context
    public func save() throws {
        // TODO: Implement save functionality
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