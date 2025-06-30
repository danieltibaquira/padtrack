import Foundation
import CoreData
@testable import DataLayer
@testable import MachineProtocols

/// Mock implementation of DataLayerManager for testing
public class MockDataLayerManager: DataLayerManagerProtocol {
    
    // MARK: - Properties
    
    public var isInitialized: Bool = false
    public var mockProjects: [MockProject] = []
    public var mockPatterns: [MockPattern] = []
    public var mockKits: [MockKit] = []
    public var mockPresets: [MockPreset] = []
    
    private var shouldFailOperations: Bool = false
    private var operationDelay: TimeInterval = 0.0
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Configuration
    
    /// Configure the mock to simulate operation failures
    public func setShouldFailOperations(_ shouldFail: Bool) {
        self.shouldFailOperations = shouldFail
    }
    
    /// Configure the mock to simulate operation delays
    public func setOperationDelay(_ delay: TimeInterval) {
        self.operationDelay = delay
    }
    
    // MARK: - DataLayerManagerProtocol Implementation
    
    public func initialize() throws {
        if shouldFailOperations {
            throw DataLayerError.configurationError("Mock initialization failure")
        }
        
        if operationDelay > 0 {
            Thread.sleep(forTimeInterval: operationDelay)
        }
        
        isInitialized = true
    }
    
    public func shutdown() {
        isInitialized = false
        mockProjects.removeAll()
        mockPatterns.removeAll()
        mockKits.removeAll()
        mockPresets.removeAll()
    }
    
    // MARK: - Project Operations
    
    public func createProject(name: String, bpm: Float) throws -> MockProject {
        if shouldFailOperations {
            throw DataLayerError.saveError(NSError(domain: "MockError", code: 1, userInfo: nil))
        }
        
        let project = MockProject(
            id: UUID(),
            name: name,
            bpm: bpm,
            createdAt: Date(),
            modifiedAt: Date()
        )
        
        mockProjects.append(project)
        return project
    }
    
    public func fetchProjects() throws -> [MockProject] {
        if shouldFailOperations {
            throw DataLayerError.fetchError(NSError(domain: "MockError", code: 2, userInfo: nil))
        }
        
        return mockProjects
    }
    
    public func updateProject(_ project: MockProject) throws {
        if shouldFailOperations {
            throw DataLayerError.saveError(NSError(domain: "MockError", code: 3, userInfo: nil))
        }
        
        if let index = mockProjects.firstIndex(where: { $0.id == project.id }) {
            mockProjects[index] = project
        }
    }
    
    public func deleteProject(_ project: MockProject) throws {
        if shouldFailOperations {
            throw DataLayerError.deleteError(NSError(domain: "MockError", code: 4, userInfo: nil))
        }
        
        mockProjects.removeAll { $0.id == project.id }
    }
    
    // MARK: - Pattern Operations
    
    public func createPattern(name: String, projectId: UUID) throws -> MockPattern {
        if shouldFailOperations {
            throw DataLayerError.saveError(NSError(domain: "MockError", code: 5, userInfo: nil))
        }
        
        let pattern = MockPattern(
            id: UUID(),
            name: name,
            projectId: projectId,
            length: 16,
            steps: Array(repeating: MockStep(), count: 64)
        )
        
        mockPatterns.append(pattern)
        return pattern
    }
    
    public func fetchPatterns(for projectId: UUID) throws -> [MockPattern] {
        if shouldFailOperations {
            throw DataLayerError.fetchError(NSError(domain: "MockError", code: 6, userInfo: nil))
        }
        
        return mockPatterns.filter { $0.projectId == projectId }
    }
    
    // MARK: - Kit Operations
    
    public func createKit(name: String) throws -> MockKit {
        if shouldFailOperations {
            throw DataLayerError.saveError(NSError(domain: "MockError", code: 7, userInfo: nil))
        }
        
        let kit = MockKit(
            id: UUID(),
            name: name,
            sounds: []
        )
        
        mockKits.append(kit)
        return kit
    }
    
    public func fetchKits() throws -> [MockKit] {
        if shouldFailOperations {
            throw DataLayerError.fetchError(NSError(domain: "MockError", code: 8, userInfo: nil))
        }
        
        return mockKits
    }
    
    // MARK: - Preset Operations
    
    public func createPreset(name: String, parameters: [String: Any]) throws -> MockPreset {
        if shouldFailOperations {
            throw DataLayerError.saveError(NSError(domain: "MockError", code: 9, userInfo: nil))
        }
        
        let preset = MockPreset(
            id: UUID(),
            name: name,
            parameters: parameters
        )
        
        mockPresets.append(preset)
        return preset
    }
    
    public func fetchPresets() throws -> [MockPreset] {
        if shouldFailOperations {
            throw DataLayerError.fetchError(NSError(domain: "MockError", code: 10, userInfo: nil))
        }
        
        return mockPresets
    }
}

// MARK: - Mock Data Models

public struct MockProject: Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var bpm: Float
    public let createdAt: Date
    public var modifiedAt: Date
    
    public init(id: UUID, name: String, bpm: Float, createdAt: Date, modifiedAt: Date) {
        self.id = id
        self.name = name
        self.bpm = bpm
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public struct MockPattern: Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public let projectId: UUID
    public var length: Int
    public var steps: [MockStep]

    public init(id: UUID, name: String, projectId: UUID, length: Int, steps: [MockStep]) {
        self.id = id
        self.name = name
        self.projectId = projectId
        self.length = length
        self.steps = steps
    }

    public static func == (lhs: MockPattern, rhs: MockPattern) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name && lhs.projectId == rhs.projectId
    }
}

public struct MockStep: Equatable {
    public var isEnabled: Bool = false
    public var velocity: Float = 0.8
    public var note: Int = 60
    public var parameters: [String: Float] = [:]

    public init(isEnabled: Bool = false, velocity: Float = 0.8, note: Int = 60) {
        self.isEnabled = isEnabled
        self.velocity = velocity
        self.note = note
    }

    public static func == (lhs: MockStep, rhs: MockStep) -> Bool {
        return lhs.isEnabled == rhs.isEnabled &&
               lhs.velocity == rhs.velocity &&
               lhs.note == rhs.note
    }
}

public struct MockKit: Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var sounds: [String]
    
    public init(id: UUID, name: String, sounds: [String]) {
        self.id = id
        self.name = name
        self.sounds = sounds
    }
}

public struct MockPreset: Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var parameters: [String: Any]
    
    public init(id: UUID, name: String, parameters: [String: Any]) {
        self.id = id
        self.name = name
        self.parameters = parameters
    }
    
    public static func == (lhs: MockPreset, rhs: MockPreset) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name
    }
}

// MARK: - Protocol Extensions

/// Protocol for mock data layer manager
public protocol DataLayerManagerProtocol {
    func initialize() throws
    func shutdown()
    func createProject(name: String, bpm: Float) throws -> MockProject
    func fetchProjects() throws -> [MockProject]
    func updateProject(_ project: MockProject) throws
    func deleteProject(_ project: MockProject) throws
    func createPattern(name: String, projectId: UUID) throws -> MockPattern
    func fetchPatterns(for projectId: UUID) throws -> [MockPattern]
    func createKit(name: String) throws -> MockKit
    func fetchKits() throws -> [MockKit]
    func createPreset(name: String, parameters: [String: Any]) throws -> MockPreset
    func fetchPresets() throws -> [MockPreset]
}
