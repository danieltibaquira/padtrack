import XCTest
@testable import MachineProtocols

final class MachineProtocolsTests: XCTestCase {
    func testAudioBufferCreation() throws {
        let buffer = AudioBuffer(
            sampleRate: 44100,
            channelCount: 2,
            frameCount: 1024,
            data: Array(repeating: 0.0, count: 2048)
        )
        
        XCTAssertEqual(buffer.sampleRate, 44100)
        XCTAssertEqual(buffer.channelCount, 2)
        XCTAssertEqual(buffer.frameCount, 1024)
        XCTAssertEqual(buffer.data.count, 2048)
    }
    
    func testParameterCreation() throws {
        let param = Parameter(
            name: "Cutoff",
            value: 0.5,
            minValue: 0.0,
            maxValue: 1.0,
            defaultValue: 0.5
        )
        
        XCTAssertEqual(param.name, "Cutoff")
        XCTAssertEqual(param.value, 0.5)
        XCTAssertEqual(param.minValue, 0.0)
        XCTAssertEqual(param.maxValue, 1.0)
    }
} 