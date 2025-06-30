// HighPrecisionTimerCoreTests.swift
// DigitonePad - AudioEngineTests
//
// Comprehensive test suite for High-Precision Timer Core

import XCTest
@testable import AudioEngine

final class HighPrecisionTimerCoreTests: XCTestCase {
    
    var timer: HighPrecisionTimerCore!
    let sampleRate: Double = 44100.0
    let bufferSize = 512
    
    override func setUp() {
        super.setUp()
        var config = HighPrecisionTimerConfig()
        config.sampleRate = sampleRate
        config.bufferSize = bufferSize
        timer = HighPrecisionTimerCore(config: config)
    }
    
    override func tearDown() {
        timer = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialization() {
        XCTAssertNotNil(timer)
        
        let timing = timer.getCurrentTiming()
        XCTAssertEqual(timing.samplePosition, 0)
        XCTAssertEqual(timing.fractionalPosition, 0.0, accuracy: 0.001)
        XCTAssertEqual(timing.bpm, 120.0, accuracy: 0.1)
        XCTAssertEqual(timing.timeSignature.numerator, 4)
        XCTAssertEqual(timing.timeSignature.denominator, 4)
    }
    
    func testTimerStartStop() {
        // Test start
        timer.start()
        let timing1 = timer.getCurrentTiming()
        XCTAssertEqual(timing1.samplePosition, 0)
        
        // Process a buffer
        let hostTime = mach_absolute_time()
        let timing2 = timer.processBuffer(hostTime: hostTime, bufferSize: bufferSize)
        XCTAssertEqual(timing2.samplePosition, UInt64(bufferSize))
        
        // Test stop
        timer.stop()
        let timing3 = timer.getCurrentTiming()
        XCTAssertEqual(timing3.samplePosition, UInt64(bufferSize))
    }
    
    func testTimerPauseResume() {
        timer.start()
        
        // Process a buffer
        let hostTime1 = mach_absolute_time()
        _ = timer.processBuffer(hostTime: hostTime1, bufferSize: bufferSize)
        
        // Pause
        timer.pause()
        let pausedPosition = timer.getCurrentTiming().samplePosition
        
        // Process another buffer while paused
        let hostTime2 = mach_absolute_time()
        _ = timer.processBuffer(hostTime: hostTime2, bufferSize: bufferSize)
        
        // Position should not advance while paused
        XCTAssertEqual(timer.getCurrentTiming().samplePosition, pausedPosition)
        
        // Resume
        timer.resume()
        let hostTime3 = mach_absolute_time()
        _ = timer.processBuffer(hostTime: hostTime3, bufferSize: bufferSize)
        
        // Position should advance after resume
        XCTAssertGreaterThan(timer.getCurrentTiming().samplePosition, pausedPosition)
    }
    
    // MARK: - Musical Timing Tests
    
    func testTempoControl() {
        // Test tempo setting
        timer.setTempo(140.0)
        let timing = timer.getCurrentTiming()
        XCTAssertEqual(timing.bpm, 140.0, accuracy: 0.1)
        
        // Test tempo bounds
        timer.setTempo(30.0)  // Below minimum
        XCTAssertGreaterThanOrEqual(timer.getCurrentTiming().bpm, 60.0)
        
        timer.setTempo(300.0)  // Above maximum
        XCTAssertLessThanOrEqual(timer.getCurrentTiming().bpm, 200.0)
    }
    
    func testTimeSignature() {
        // Test time signature setting
        timer.setTimeSignature(numerator: 3, denominator: 4)
        let timing = timer.getCurrentTiming()
        XCTAssertEqual(timing.timeSignature.numerator, 3)
        XCTAssertEqual(timing.timeSignature.denominator, 4)
        
        // Test bounds
        timer.setTimeSignature(numerator: 0, denominator: 0)
        let boundedTiming = timer.getCurrentTiming()
        XCTAssertGreaterThanOrEqual(boundedTiming.timeSignature.numerator, 1)
        XCTAssertGreaterThanOrEqual(boundedTiming.timeSignature.denominator, 1)
    }
    
    func testMusicalPositionCalculation() {
        timer.setTempo(120.0)  // 120 BPM = 2 beats per second
        timer.setTimeSignature(numerator: 4, denominator: 4)
        timer.start()
        
        // Process enough samples for one beat
        let samplesPerBeat = Int(sampleRate / 2.0)  // 2 beats per second
        let hostTime = mach_absolute_time()
        
        let timing = timer.processBuffer(hostTime: hostTime, bufferSize: samplesPerBeat)
        
        // Should be approximately at beat 2
        XCTAssertEqual(timing.musicalPosition.bar, 1)
        XCTAssertGreaterThan(timing.musicalPosition.totalBeats, 0.9)
        XCTAssertLessThan(timing.musicalPosition.totalBeats, 1.1)
    }
    
    func testTickCalculation() {
        timer.setTicksPerQuarterNote(480)  // Standard MIDI resolution
        timer.setTempo(120.0)
        timer.start()
        
        let hostTime = mach_absolute_time()
        let timing = timer.processBuffer(hostTime: hostTime, bufferSize: bufferSize)
        
        // Should have valid tick information
        XCTAssertGreaterThanOrEqual(timing.musicalPosition.tick, 0)
        XCTAssertLessThan(timing.musicalPosition.tick, 480)
        XCTAssertGreaterThanOrEqual(timing.musicalPosition.tickFraction, 0.0)
        XCTAssertLessThan(timing.musicalPosition.tickFraction, 1.0)
    }
    
    // MARK: - Precision and Accuracy Tests
    
    func testSubSampleAccuracy() {
        var config = HighPrecisionTimerConfig()
        config.accuracyMode = .ultra
        config.sampleRate = sampleRate
        timer = HighPrecisionTimerCore(config: config)
        
        timer.start()
        let hostTime = mach_absolute_time()
        let timing = timer.processBuffer(hostTime: hostTime, bufferSize: 1)
        
        // Should have fractional position information
        XCTAssertGreaterThanOrEqual(timing.fractionalPosition, 0.0)
        XCTAssertLessThan(timing.fractionalPosition, 1.0)
    }
    
    func testAccuracyModes() {
        let modes: [TimingAccuracyMode] = [.standard, .high, .ultra]
        
        for mode in modes {
            var config = HighPrecisionTimerConfig()
            config.accuracyMode = mode
            config.sampleRate = sampleRate
            
            let testTimer = HighPrecisionTimerCore(config: config)
            testTimer.start()
            
            let hostTime = mach_absolute_time()
            let timing = testTimer.processBuffer(hostTime: hostTime, bufferSize: bufferSize)
            
            // Should process without errors
            XCTAssertEqual(timing.samplePosition, UInt64(bufferSize))
            
            // Clock resolution should match mode
            XCTAssertEqual(testTimer.config.clockResolution, mode.clockResolution, accuracy: 0.001)
        }
    }
    
    func testJitterCompensation() {
        var config = HighPrecisionTimerConfig()
        config.jitterCompensation = true
        config.maxJitterTolerance = 2.0
        config.sampleRate = sampleRate
        timer = HighPrecisionTimerCore(config: config)
        
        timer.start()
        
        // Process multiple buffers to build jitter history
        for _ in 0..<10 {
            let hostTime = mach_absolute_time()
            let timing = timer.processBuffer(hostTime: hostTime, bufferSize: bufferSize)
            
            // Should have accuracy metrics
            XCTAssertGreaterThanOrEqual(timing.accuracyMetrics.stability, 0.0)
            XCTAssertLessThanOrEqual(timing.accuracyMetrics.stability, 100.0)
        }
    }
    
    // MARK: - Synchronization Tests
    
    func testExternalSyncEnable() {
        // Test enabling external sync
        timer.enableExternalSync(source: .midi)
        let timing = timer.getCurrentTiming()
        
        XCTAssertEqual(timing.syncStatus.source, .midi)
        XCTAssertTrue(timing.syncStatus.enabled)
        XCTAssertFalse(timing.syncStatus.locked)  // Not locked until correction applied
    }
    
    func testExternalSyncCorrection() {
        timer.enableExternalSync(source: .external)
        
        // Apply sync correction within tolerance
        timer.applyExternalSyncCorrection(offset: 2.0)
        let timing = timer.getCurrentTiming()
        
        XCTAssertTrue(timing.syncStatus.locked)
        XCTAssertEqual(timing.syncStatus.offset, 2.0, accuracy: 0.1)
        XCTAssertGreaterThan(timing.syncStatus.quality, 0.0)
    }
    
    func testExternalSyncTolerance() {
        timer.enableExternalSync(source: .external)
        
        // Apply sync correction outside tolerance
        timer.applyExternalSyncCorrection(offset: 10.0)  // Exceeds default tolerance
        let timing = timer.getCurrentTiming()
        
        XCTAssertFalse(timing.syncStatus.locked)  // Should not lock with large offset
    }
    
    func testSyncDisable() {
        timer.enableExternalSync(source: .link)
        timer.disableExternalSync()
        
        let timing = timer.getCurrentTiming()
        XCTAssertFalse(timing.syncStatus.enabled)
        XCTAssertEqual(timing.syncStatus.source, .internal)
    }
    
    // MARK: - Performance Tests
    
    func testProcessingPerformance() {
        timer.start()
        
        measure {
            for _ in 0..<1000 {
                let hostTime = mach_absolute_time()
                _ = timer.processBuffer(hostTime: hostTime, bufferSize: bufferSize)
            }
        }
    }
    
    func testTimingInfoCreationPerformance() {
        timer.start()
        
        measure {
            for _ in 0..<10000 {
                _ = timer.getCurrentTiming()
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testLargeBufferSizes() {
        let largeBufferSizes = [1024, 2048, 4096, 8192]
        
        for bufferSize in largeBufferSizes {
            timer.start()
            let hostTime = mach_absolute_time()
            let timing = timer.processBuffer(hostTime: hostTime, bufferSize: bufferSize)
            
            XCTAssertEqual(timing.samplePosition, UInt64(bufferSize))
            timer.stop()
        }
    }
    
    func testSmallBufferSizes() {
        let smallBufferSizes = [1, 2, 4, 8, 16, 32, 64]
        
        for bufferSize in smallBufferSizes {
            timer.start()
            let hostTime = mach_absolute_time()
            let timing = timer.processBuffer(hostTime: hostTime, bufferSize: bufferSize)
            
            XCTAssertEqual(timing.samplePosition, UInt64(bufferSize))
            timer.stop()
        }
    }
    
    func testExtremeTempo() {
        // Test very slow tempo
        timer.setTempo(60.0)
        timer.start()
        let hostTime1 = mach_absolute_time()
        let timing1 = timer.processBuffer(hostTime: hostTime1, bufferSize: bufferSize)
        XCTAssertEqual(timing1.bpm, 60.0, accuracy: 0.1)
        
        // Test very fast tempo
        timer.setTempo(200.0)
        let hostTime2 = mach_absolute_time()
        let timing2 = timer.processBuffer(hostTime: hostTime2, bufferSize: bufferSize)
        XCTAssertEqual(timing2.bpm, 200.0, accuracy: 0.1)
    }
    
    func testMusicalPositionReset() {
        timer.start()
        
        // Advance position
        let hostTime1 = mach_absolute_time()
        _ = timer.processBuffer(hostTime: hostTime1, bufferSize: bufferSize * 10)
        
        let positionBefore = timer.getCurrentTiming().musicalPosition.totalBeats
        XCTAssertGreaterThan(positionBefore, 0.0)
        
        // Reset position
        timer.resetMusicalPosition()
        
        let positionAfter = timer.getCurrentTiming().musicalPosition.totalBeats
        XCTAssertEqual(positionAfter, 0.0, accuracy: 0.001)
        XCTAssertEqual(timer.getCurrentTiming().samplePosition, 0)
    }
    
    // MARK: - Configuration Tests
    
    func testConfigurationUpdate() {
        var newConfig = HighPrecisionTimerConfig()
        newConfig.accuracyMode = .ultra
        newConfig.jitterCompensation = false
        newConfig.driftCompensation = false
        
        timer.config = newConfig
        
        XCTAssertEqual(timer.config.accuracyMode, .ultra)
        XCTAssertFalse(timer.config.jitterCompensation)
        XCTAssertFalse(timer.config.driftCompensation)
    }
    
    func testOptimizationLevels() {
        let levels: [OptimizationLevel] = [.quality, .balanced, .performance]
        
        for level in levels {
            var config = HighPrecisionTimerConfig()
            config.optimizationLevel = level
            
            let testTimer = HighPrecisionTimerCore(config: config)
            testTimer.start()
            
            let hostTime = mach_absolute_time()
            let timing = testTimer.processBuffer(hostTime: hostTime, bufferSize: bufferSize)
            
            // Should process successfully with all optimization levels
            XCTAssertEqual(timing.samplePosition, UInt64(bufferSize))
        }
    }
}
