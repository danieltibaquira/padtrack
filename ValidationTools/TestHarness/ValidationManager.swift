import Foundation
import SwiftUI
import Combine
import CoreData
import os.log

// Import all modules to validate
import AppShell
import DataLayer
import AudioEngine
import SequencerModule
import VoiceModule
import FilterModule
import FXModule
import MIDIModule
import UIComponents
import MachineProtocols

@MainActor
class ValidationManager: ObservableObject {
    @Published var isRunning = false
    @Published var results: [ValidationResult] = []
    @Published var currentStep = ""
    
    private let logger = Logger(subsystem: "com.digitonepad.validation", category: "ValidationManager")
    private var deviceInfo: DeviceInfo
    
    init() {
        self.deviceInfo = DeviceInfo()
    }
    
    func runFullValidation() async {
        isRunning = true
        results.removeAll()
        
        logger.info("Starting full validation process")
        
        // Run all validation categories
        await validateDeviceInfo()
        await validateBuildSystem()
        await validateProtocolCompilation()
        await validateCoreDataStack()
        await validateModuleIntegration()
        await validateMemoryBaseline()
        await validatePerformanceMetrics()
        
        isRunning = false
        logger.info("Validation process completed")
    }
    
    // MARK: - Device Information Validation
    
    private func validateDeviceInfo() async {
        currentStep = "Validating Device Information"
        
        let deviceModel = deviceInfo.deviceModel
        let osVersion = deviceInfo.osVersion
        let availableMemory = deviceInfo.availableMemory
        
        let message = "Device: \(deviceModel), iOS: \(osVersion)"
        let details = "Available Memory: \(String(format: "%.1f", availableMemory)) MB"
        let metrics = [
            "memory_mb": availableMemory,
            "ios_version": Double(osVersion.components(separatedBy: ".").first ?? "0") ?? 0
        ]
        
        results.append(ValidationResult(
            category: "Device Info",
            status: .passed,
            message: message,
            details: details,
            metrics: metrics
        ))
    }
    
    // MARK: - Build System Validation
    
    private func validateBuildSystem() async {
        currentStep = "Validating Build System"
        
        do {
            // Test Swift compilation
            let swiftVersion = await getSwiftVersion()
            
            // Test module imports
            let importResults = await testModuleImports()
            
            let allImportsSuccessful = importResults.allSatisfy { $0.value }
            let status: ValidationStatus = allImportsSuccessful ? .passed : .failed
            
            let failedImports = importResults.filter { !$0.value }.map { $0.key }
            let message = allImportsSuccessful ? 
                "All modules imported successfully" : 
                "Failed to import: \(failedImports.joined(separator: ", "))"
            
            results.append(ValidationResult(
                category: "Build System",
                status: status,
                message: message,
                details: "Swift Version: \(swiftVersion)"
            ))
            
        } catch {
            results.append(ValidationResult(
                category: "Build System",
                status: .failed,
                message: "Build validation failed",
                details: error.localizedDescription
            ))
        }
    }
    
    // MARK: - Protocol Compilation Validation
    
    private func validateProtocolCompilation() async {
        currentStep = "Validating Protocol Compilation"
        
        do {
            // Test protocol instantiation
            let protocolTests = await runProtocolTests()
            
            let allTestsPassed = protocolTests.allSatisfy { $0.value }
            let status: ValidationStatus = allTestsPassed ? .passed : .failed
            
            let failedTests = protocolTests.filter { !$0.value }.map { $0.key }
            let message = allTestsPassed ? 
                "All protocols compile and instantiate correctly" : 
                "Failed protocol tests: \(failedTests.joined(separator: ", "))"
            
            results.append(ValidationResult(
                category: "Protocol Compilation",
                status: status,
                message: message,
                details: "Tested \(protocolTests.count) protocol implementations"
            ))
            
        } catch {
            results.append(ValidationResult(
                category: "Protocol Compilation",
                status: .failed,
                message: "Protocol validation failed",
                details: error.localizedDescription
            ))
        }
    }
    
    // MARK: - Core Data Validation
    
    private func validateCoreDataStack() async {
        currentStep = "Validating Core Data Stack"
        
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Initialize Core Data stack
            let coreDataStack = CoreDataStack.shared
            
            // Test entity creation
            let entityTests = await testCoreDataEntities(stack: coreDataStack)
            
            let initTime = CFAbsoluteTimeGetCurrent() - startTime
            
            let allTestsPassed = entityTests.allSatisfy { $0.value }
            let status: ValidationStatus = allTestsPassed ? .passed : .failed
            
            let failedTests = entityTests.filter { !$0.value }.map { $0.key }
            let message = allTestsPassed ? 
                "Core Data stack initialized and tested successfully" : 
                "Failed Core Data tests: \(failedTests.joined(separator: ", "))"
            
            let metrics = [
                "init_time_ms": initTime * 1000,
                "entities_tested": Double(entityTests.count)
            ]
            
            results.append(ValidationResult(
                category: "Core Data",
                status: status,
                message: message,
                details: "Initialization time: \(String(format: "%.2f", initTime * 1000))ms",
                metrics: metrics
            ))
            
        } catch {
            results.append(ValidationResult(
                category: "Core Data",
                status: .failed,
                message: "Core Data validation failed",
                details: error.localizedDescription
            ))
        }
    }
    
    // MARK: - Module Integration Validation
    
    private func validateModuleIntegration() async {
        currentStep = "Validating Module Integration"
        
        do {
            let integrationTests = await runModuleIntegrationTests()
            
            let allTestsPassed = integrationTests.allSatisfy { $0.value }
            let status: ValidationStatus = allTestsPassed ? .passed : .failed
            
            let failedTests = integrationTests.filter { !$0.value }.map { $0.key }
            let message = allTestsPassed ? 
                "All modules integrate correctly" : 
                "Failed integration tests: \(failedTests.joined(separator: ", "))"
            
            results.append(ValidationResult(
                category: "Module Integration",
                status: status,
                message: message,
                details: "Tested \(integrationTests.count) module integrations"
            ))
            
        } catch {
            results.append(ValidationResult(
                category: "Module Integration",
                status: .failed,
                message: "Module integration validation failed",
                details: error.localizedDescription
            ))
        }
    }
    
    // MARK: - Memory Baseline Validation
    
    private func validateMemoryBaseline() async {
        currentStep = "Establishing Memory Baseline"
        
        let memoryInfo = deviceInfo.getMemoryInfo()
        
        let status: ValidationStatus = memoryInfo.availableMemory > 100 ? .passed : .warning
        let message = "Memory baseline established"
        let details = "Used: \(String(format: "%.1f", memoryInfo.usedMemory))MB, Available: \(String(format: "%.1f", memoryInfo.availableMemory))MB"
        
        let metrics = [
            "used_memory_mb": memoryInfo.usedMemory,
            "available_memory_mb": memoryInfo.availableMemory,
            "total_memory_mb": memoryInfo.totalMemory
        ]
        
        results.append(ValidationResult(
            category: "Memory Baseline",
            status: status,
            message: message,
            details: details,
            metrics: metrics
        ))
    }
    
    // MARK: - Performance Metrics Validation
    
    private func validatePerformanceMetrics() async {
        currentStep = "Measuring Performance Metrics"
        
        let performanceMetrics = await measurePerformanceMetrics()
        
        let status: ValidationStatus = performanceMetrics["cpu_usage"] ?? 0 < 80 ? .passed : .warning
        let message = "Performance metrics captured"
        
        results.append(ValidationResult(
            category: "Performance",
            status: status,
            message: message,
            details: "CPU, Memory, and I/O metrics captured",
            metrics: performanceMetrics
        ))
    }
    
    // MARK: - Export Report
    
    func exportReport() {
        let report = ValidationReport(
            deviceInfo: deviceInfo,
            results: results,
            timestamp: Date()
        )
        
        // Save report to documents directory
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let reportPath = documentsPath.appendingPathComponent("validation_report_\(Int(Date().timeIntervalSince1970)).json")
            
            do {
                let data = try JSONEncoder().encode(report)
                try data.write(to: reportPath)
                logger.info("Validation report exported to: \(reportPath.path)")
            } catch {
                logger.error("Failed to export report: \(error.localizedDescription)")
            }
        }
    }
}
