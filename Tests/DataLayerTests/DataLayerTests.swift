import XCTest
@testable import DataLayer

final class DataLayerTests: XCTestCase {
    func testDataLayerManagerInitialization() throws {
        let manager = DataLayerManager.shared
        XCTAssertNotNil(manager)
        
        // Test initialization doesn't throw
        manager.initialize()
    }
    
    func testProjectEntityCreation() throws {
        let project = ProjectEntity(name: "Test Project")
        XCTAssertEqual(project.name, "Test Project")
        XCTAssertNotNil(project.id)
        XCTAssertNotNil(project.createdAt)
    }
} 