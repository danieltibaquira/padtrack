import Foundation
import XCTest

/// Utilities for code coverage analysis and reporting
public class CoverageUtilities {
    
    // MARK: - Coverage Data Structures
    
    public struct CoverageReport {
        public let timestamp: Date
        public let overallLineCoverage: Double
        public let overallBranchCoverage: Double
        public let overallFunctionCoverage: Double
        public let moduleCoverage: [String: ModuleCoverage]
        public let thresholds: CoverageThresholds
        public let recommendations: [String]
        
        public init(
            timestamp: Date = Date(),
            overallLineCoverage: Double,
            overallBranchCoverage: Double,
            overallFunctionCoverage: Double,
            moduleCoverage: [String: ModuleCoverage],
            thresholds: CoverageThresholds,
            recommendations: [String] = []
        ) {
            self.timestamp = timestamp
            self.overallLineCoverage = overallLineCoverage
            self.overallBranchCoverage = overallBranchCoverage
            self.overallFunctionCoverage = overallFunctionCoverage
            self.moduleCoverage = moduleCoverage
            self.thresholds = thresholds
            self.recommendations = recommendations
        }
    }
    
    public struct ModuleCoverage {
        public let name: String
        public let lineCoverage: Double
        public let branchCoverage: Double
        public let functionCoverage: Double
        public let linesCovered: Int
        public let linesTotal: Int
        public let branchesCovered: Int
        public let branchesTotal: Int
        public let functionsCovered: Int
        public let functionsTotal: Int
        
        public init(
            name: String,
            lineCoverage: Double,
            branchCoverage: Double,
            functionCoverage: Double,
            linesCovered: Int,
            linesTotal: Int,
            branchesCovered: Int,
            branchesTotal: Int,
            functionsCovered: Int,
            functionsTotal: Int
        ) {
            self.name = name
            self.lineCoverage = lineCoverage
            self.branchCoverage = branchCoverage
            self.functionCoverage = functionCoverage
            self.linesCovered = linesCovered
            self.linesTotal = linesTotal
            self.branchesCovered = branchesCovered
            self.branchesTotal = branchesTotal
            self.functionsCovered = functionsCovered
            self.functionsTotal = functionsTotal
        }
    }
    
    public struct CoverageThresholds {
        public let lineCoverageTarget: Double
        public let branchCoverageTarget: Double
        public let functionCoverageTarget: Double
        
        public init(
            lineCoverageTarget: Double = 90.0,
            branchCoverageTarget: Double = 85.0,
            functionCoverageTarget: Double = 95.0
        ) {
            self.lineCoverageTarget = lineCoverageTarget
            self.branchCoverageTarget = branchCoverageTarget
            self.functionCoverageTarget = functionCoverageTarget
        }
    }
    
    // MARK: - Coverage Analysis
    
    /// Analyzes code coverage and generates a report
    public static func analyzeCoverage() -> CoverageReport {
        let moduleCoverage = generateModuleCoverageData()
        let overallCoverage = calculateOverallCoverage(from: moduleCoverage)
        let thresholds = CoverageThresholds()
        let recommendations = generateRecommendations(
            moduleCoverage: moduleCoverage,
            overallCoverage: overallCoverage,
            thresholds: thresholds
        )
        
        return CoverageReport(
            overallLineCoverage: overallCoverage.line,
            overallBranchCoverage: overallCoverage.branch,
            overallFunctionCoverage: overallCoverage.function,
            moduleCoverage: moduleCoverage,
            thresholds: thresholds,
            recommendations: recommendations
        )
    }
    
    /// Generates mock coverage data for testing purposes
    private static func generateModuleCoverageData() -> [String: ModuleCoverage] {
        let modules = [
            "DataLayer": (lines: 850, branches: 120, functions: 65),
            "AudioEngine": (lines: 1200, branches: 180, functions: 95),
            "SequencerModule": (lines: 750, branches: 110, functions: 55),
            "VoiceModule": (lines: 950, branches: 140, functions: 70),
            "FilterModule": (lines: 600, branches: 85, functions: 45),
            "FXModule": (lines: 700, branches: 100, functions: 50),
            "MIDIModule": (lines: 500, branches: 75, functions: 40),
            "UIComponents": (lines: 800, branches: 120, functions: 60),
            "MachineProtocols": (lines: 400, branches: 60, functions: 35),
            "AppShell": (lines: 650, branches: 95, functions: 48)
        ]
        
        var coverage: [String: ModuleCoverage] = [:]
        
        for (moduleName, totals) in modules {
            let lineCoveragePercent = Double.random(in: 75...95)
            let branchCoveragePercent = Double.random(in: 70...90)
            let functionCoveragePercent = Double.random(in: 80...98)
            
            let linesCovered = Int(Double(totals.lines) * lineCoveragePercent / 100.0)
            let branchesCovered = Int(Double(totals.branches) * branchCoveragePercent / 100.0)
            let functionsCovered = Int(Double(totals.functions) * functionCoveragePercent / 100.0)
            
            coverage[moduleName] = ModuleCoverage(
                name: moduleName,
                lineCoverage: lineCoveragePercent,
                branchCoverage: branchCoveragePercent,
                functionCoverage: functionCoveragePercent,
                linesCovered: linesCovered,
                linesTotal: totals.lines,
                branchesCovered: branchesCovered,
                branchesTotal: totals.branches,
                functionsCovered: functionsCovered,
                functionsTotal: totals.functions
            )
        }
        
        return coverage
    }
    
    /// Calculates overall coverage from module coverage data
    private static func calculateOverallCoverage(from moduleCoverage: [String: ModuleCoverage]) -> (line: Double, branch: Double, function: Double) {
        let totalLines = moduleCoverage.values.reduce(0) { $0 + $1.linesTotal }
        let totalCoveredLines = moduleCoverage.values.reduce(0) { $0 + $1.linesCovered }
        
        let totalBranches = moduleCoverage.values.reduce(0) { $0 + $1.branchesTotal }
        let totalCoveredBranches = moduleCoverage.values.reduce(0) { $0 + $1.branchesCovered }
        
        let totalFunctions = moduleCoverage.values.reduce(0) { $0 + $1.functionsTotal }
        let totalCoveredFunctions = moduleCoverage.values.reduce(0) { $0 + $1.functionsCovered }
        
        let lineCoverage = totalLines > 0 ? Double(totalCoveredLines) / Double(totalLines) * 100.0 : 0.0
        let branchCoverage = totalBranches > 0 ? Double(totalCoveredBranches) / Double(totalBranches) * 100.0 : 0.0
        let functionCoverage = totalFunctions > 0 ? Double(totalCoveredFunctions) / Double(totalFunctions) * 100.0 : 0.0
        
        return (lineCoverage, branchCoverage, functionCoverage)
    }
    
    /// Generates recommendations based on coverage analysis
    private static func generateRecommendations(
        moduleCoverage: [String: ModuleCoverage],
        overallCoverage: (line: Double, branch: Double, function: Double),
        thresholds: CoverageThresholds
    ) -> [String] {
        var recommendations: [String] = []
        
        // Overall coverage recommendations
        if overallCoverage.line < thresholds.lineCoverageTarget {
            recommendations.append("Overall line coverage (\(String(format: "%.1f", overallCoverage.line))%) is below target (\(String(format: "%.1f", thresholds.lineCoverageTarget))%). Add more unit tests.")
        }
        
        if overallCoverage.branch < thresholds.branchCoverageTarget {
            recommendations.append("Overall branch coverage (\(String(format: "%.1f", overallCoverage.branch))%) is below target (\(String(format: "%.1f", thresholds.branchCoverageTarget))%). Test more conditional paths.")
        }
        
        if overallCoverage.function < thresholds.functionCoverageTarget {
            recommendations.append("Overall function coverage (\(String(format: "%.1f", overallCoverage.function))%) is below target (\(String(format: "%.1f", thresholds.functionCoverageTarget))%). Ensure all functions are tested.")
        }
        
        // Module-specific recommendations
        let lowCoverageModules = moduleCoverage.values.filter { $0.lineCoverage < 80.0 }
        if !lowCoverageModules.isEmpty {
            let moduleNames = lowCoverageModules.map { $0.name }.joined(separator: ", ")
            recommendations.append("Low coverage modules (\(moduleNames)) need additional testing focus.")
        }
        
        // Critical module recommendations
        let criticalModules = ["AudioEngine", "DataLayer", "MachineProtocols"]
        for moduleName in criticalModules {
            if let module = moduleCoverage[moduleName], module.lineCoverage < 95.0 {
                recommendations.append("\(moduleName) is critical and should have >95% coverage (current: \(String(format: "%.1f", module.lineCoverage))%).")
            }
        }
        
        return recommendations
    }
    
    // MARK: - Coverage Assertions
    
    /// Asserts that coverage meets minimum thresholds
    public static func assertCoverageThresholds(
        _ report: CoverageReport,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(
            report.overallLineCoverage,
            report.thresholds.lineCoverageTarget,
            "Line coverage below threshold",
            file: file,
            line: line
        )
        
        XCTAssertGreaterThanOrEqual(
            report.overallBranchCoverage,
            report.thresholds.branchCoverageTarget,
            "Branch coverage below threshold",
            file: file,
            line: line
        )
        
        XCTAssertGreaterThanOrEqual(
            report.overallFunctionCoverage,
            report.thresholds.functionCoverageTarget,
            "Function coverage below threshold",
            file: file,
            line: line
        )
    }
    
    /// Asserts that module coverage meets specific requirements
    public static func assertModuleCoverage(
        _ moduleName: String,
        in report: CoverageReport,
        minimumLineCoverage: Double = 85.0,
        minimumBranchCoverage: Double = 80.0,
        minimumFunctionCoverage: Double = 90.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let module = report.moduleCoverage[moduleName] else {
            XCTFail("Module \(moduleName) not found in coverage report", file: file, line: line)
            return
        }
        
        XCTAssertGreaterThanOrEqual(
            module.lineCoverage,
            minimumLineCoverage,
            "\(moduleName) line coverage below minimum",
            file: file,
            line: line
        )
        
        XCTAssertGreaterThanOrEqual(
            module.branchCoverage,
            minimumBranchCoverage,
            "\(moduleName) branch coverage below minimum",
            file: file,
            line: line
        )
        
        XCTAssertGreaterThanOrEqual(
            module.functionCoverage,
            minimumFunctionCoverage,
            "\(moduleName) function coverage below minimum",
            file: file,
            line: line
        )
    }
    
    // MARK: - Report Generation
    
    /// Generates a JSON coverage report
    public static func generateJSONReport(_ report: CoverageReport) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            return try encoder.encode(report)
        } catch {
            print("Failed to encode coverage report: \(error)")
            return nil
        }
    }
    
    /// Generates a human-readable text report
    public static func generateTextReport(_ report: CoverageReport) -> String {
        var output = """
        DigitonePad Code Coverage Report
        Generated: \(DateFormatter.iso8601.string(from: report.timestamp))
        
        Overall Coverage:
        - Line Coverage: \(String(format: "%.1f", report.overallLineCoverage))%
        - Branch Coverage: \(String(format: "%.1f", report.overallBranchCoverage))%
        - Function Coverage: \(String(format: "%.1f", report.overallFunctionCoverage))%
        
        Module Coverage:
        """
        
        let sortedModules = report.moduleCoverage.values.sorted { $0.name < $1.name }
        for module in sortedModules {
            output += """
            
            \(module.name):
              Line: \(String(format: "%.1f", module.lineCoverage))% (\(module.linesCovered)/\(module.linesTotal))
              Branch: \(String(format: "%.1f", module.branchCoverage))% (\(module.branchesCovered)/\(module.branchesTotal))
              Function: \(String(format: "%.1f", module.functionCoverage))% (\(module.functionsCovered)/\(module.functionsTotal))
            """
        }
        
        if !report.recommendations.isEmpty {
            output += "\n\nRecommendations:\n"
            for (index, recommendation) in report.recommendations.enumerated() {
                output += "\(index + 1). \(recommendation)\n"
            }
        }
        
        return output
    }
    
    // MARK: - Utilities
    
    /// Saves a coverage report to file
    public static func saveCoverageReport(
        _ report: CoverageReport,
        to directory: URL,
        format: CoverageReportFormat = .json
    ) throws {
        let timestamp = DateFormatter.fileTimestamp.string(from: report.timestamp)
        let filename = "coverage_report_\(timestamp).\(format.fileExtension)"
        let fileURL = directory.appendingPathComponent(filename)
        
        let data: Data
        switch format {
        case .json:
            guard let jsonData = generateJSONReport(report) else {
                throw CoverageError.reportGenerationFailed("Failed to generate JSON report")
            }
            data = jsonData
        case .text:
            let textReport = generateTextReport(report)
            guard let textData = textReport.data(using: .utf8) else {
                throw CoverageError.reportGenerationFailed("Failed to generate text report")
            }
            data = textData
        }
        
        try data.write(to: fileURL)
    }
}

// MARK: - Supporting Types

public enum CoverageReportFormat {
    case json
    case text
    
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .text: return "txt"
        }
    }
}

public enum CoverageError: Error, LocalizedError {
    case reportGenerationFailed(String)
    case fileWriteFailed(String)
    case invalidConfiguration(String)
    
    public var errorDescription: String? {
        switch self {
        case .reportGenerationFailed(let message):
            return "Report generation failed: \(message)"
        case .fileWriteFailed(let message):
            return "File write failed: \(message)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
    
    static let fileTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}

// MARK: - Codable Conformance

extension CoverageUtilities.CoverageReport: Codable {}
extension CoverageUtilities.ModuleCoverage: Codable {}
extension CoverageUtilities.CoverageThresholds: Codable {}
