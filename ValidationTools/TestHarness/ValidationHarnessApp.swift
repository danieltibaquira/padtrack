import SwiftUI
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

@main
struct ValidationHarnessApp: App {
    @StateObject private var validationManager = ValidationManager()
    
    var body: some Scene {
        WindowGroup {
            ValidationHarnessView()
                .environmentObject(validationManager)
                .onAppear {
                    Task {
                        await validationManager.runFullValidation()
                    }
                }
        }
    }
}

struct ValidationHarnessView: View {
    @EnvironmentObject var validationManager: ValidationManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("DigitonePad Validation Harness")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                if validationManager.isRunning {
                    ProgressView("Running Validation...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                } else {
                    ValidationResultsView()
                }
                
                Spacer()
                
                HStack {
                    Button("Run Validation") {
                        Task {
                            await validationManager.runFullValidation()
                        }
                    }
                    .disabled(validationManager.isRunning)
                    .buttonStyle(.borderedProminent)
                    
                    Button("Export Report") {
                        validationManager.exportReport()
                    }
                    .disabled(validationManager.results.isEmpty)
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Validation")
        }
    }
}

struct ValidationResultsView: View {
    @EnvironmentObject var validationManager: ValidationManager
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(validationManager.results, id: \.category) { result in
                    ValidationResultCard(result: result)
                }
            }
            .padding()
        }
    }
}

struct ValidationResultCard: View {
    let result: ValidationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.status.iconName)
                    .foregroundColor(result.status.color)
                Text(result.category)
                    .font(.headline)
                Spacer()
                Text(result.status.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(result.status.color.opacity(0.2))
                    .cornerRadius(8)
            }
            
            Text(result.message)
                .font(.body)
                .foregroundColor(.secondary)
            
            if let details = result.details, !details.isEmpty {
                Text(details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            
            if let metrics = result.metrics {
                HStack {
                    ForEach(Array(metrics.keys.sorted()), id: \.self) { key in
                        VStack {
                            Text(key)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f", metrics[key] ?? 0))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Supporting Types

enum ValidationStatus: String, CaseIterable {
    case passed = "passed"
    case failed = "failed"
    case warning = "warning"
    case running = "running"
    
    var color: Color {
        switch self {
        case .passed: return .green
        case .failed: return .red
        case .warning: return .orange
        case .running: return .blue
        }
    }
    
    var iconName: String {
        switch self {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .running: return "clock.fill"
        }
    }
}

struct ValidationResult {
    let category: String
    let status: ValidationStatus
    let message: String
    let details: String?
    let metrics: [String: Double]?
    let timestamp: Date
    
    init(category: String, status: ValidationStatus, message: String, details: String? = nil, metrics: [String: Double]? = nil) {
        self.category = category
        self.status = status
        self.message = message
        self.details = details
        self.metrics = metrics
        self.timestamp = Date()
    }
}
