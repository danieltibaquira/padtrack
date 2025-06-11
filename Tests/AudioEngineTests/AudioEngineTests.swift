import XCTest
@testable import AudioEngine

final class AudioEngineTests: XCTestCase {
    func testAudioEngineInitialization() throws {
        let engine = AudioEngine.shared
        XCTAssertNotNil(engine)
    }
} 