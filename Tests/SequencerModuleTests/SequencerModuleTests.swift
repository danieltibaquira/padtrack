import XCTest
@testable import SequencerModule

final class SequencerModuleTests: XCTestCase {
    func testSequencerInitialization() throws {
        let sequencer = Sequencer.shared
        XCTAssertNotNil(sequencer)
    }
} 