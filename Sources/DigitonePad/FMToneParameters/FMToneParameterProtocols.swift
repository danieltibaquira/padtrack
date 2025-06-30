import Foundation
import SwiftUI
import Combine
import VoiceModule

// MARK: - VIPER Protocols for FM Tone Parameter Management

/// View Protocol - Defines what the View can do
protocol FMToneParameterViewProtocol: AnyObject {
    var presenter: FMToneParameterPresenterProtocol? { get set }
    
    func updateParameterValue(at index: Int, value: Double)
    func updatePageLabels(_ labels: [String])
    func showParameterError(_ error: Error)
    func updateParameterDisplay(at index: Int, formattedValue: String)
}

/// Presenter Protocol - Defines what the Presenter can do
protocol FMToneParameterPresenterProtocol: AnyObject {
    var view: FMToneParameterViewProtocol? { get set }
    var interactor: FMToneParameterInteractorProtocol? { get set }
    var router: FMToneParameterRouterProtocol? { get set }
    
    func viewDidLoad()
    func pageChanged(to page: Int)
    func parameterChanged(at index: Int, value: Double)
    func resetParametersToDefault()
    func loadPreset(preset: FMTonePreset)
}

/// Interactor Protocol - Defines what the Interactor can do
protocol FMToneParameterInteractorProtocol: AnyObject {
    var presenter: FMToneParameterPresenterProtocol? { get set }
    
    func getParameterLabels(for page: Int) -> [String]
    func updateParameter(at index: Int, page: Int, normalizedValue: Double)
    func getParameterValue(at index: Int, page: Int) -> Double
    func resetAllParameters()
    func validateParameterValue(_ value: Double, for parameter: FMToneParameter) -> Bool
    func applyPreset(_ preset: FMTonePreset)
}

/// Router Protocol - Defines what the Router can do
protocol FMToneParameterRouterProtocol: AnyObject {
    static func createModule(fmVoiceMachine: FMVoiceMachine?) -> AnyView
    
    func navigateToPresetSelection()
    func showParameterHelp(for parameter: FMToneParameter)
}

// MARK: - Data Models

/// FM TONE parameter definition
public struct FMToneParameter {
    let id: String
    let name: String
    let shortName: String
    let page: Int
    let index: Int
    let minValue: Double
    let maxValue: Double
    let defaultValue: Double
    let unit: String?
    let isDiscrete: Bool
    
    public init(id: String, name: String, shortName: String, page: Int, index: Int, 
                minValue: Double, maxValue: Double, defaultValue: Double, 
                unit: String? = nil, isDiscrete: Bool = false) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.page = page
        self.index = index
        self.minValue = minValue
        self.maxValue = maxValue
        self.defaultValue = defaultValue
        self.unit = unit
        self.isDiscrete = isDiscrete
    }
}

/// FM TONE preset definition
public struct FMTonePreset {
    let id: UUID
    let name: String
    let parameters: [String: Double]
    let createdAt: Date
    
    public init(id: UUID = UUID(), name: String, parameters: [String: Double], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.parameters = parameters
        self.createdAt = createdAt
    }
}

/// Page layout information
public struct FMTonePageLayout {
    let pageNumber: Int
    let title: String
    let parameters: [FMToneParameter]
    
    public init(pageNumber: Int, title: String, parameters: [FMToneParameter]) {
        self.pageNumber = pageNumber
        self.title = title
        self.parameters = parameters
    }
}

// MARK: - Errors

enum FMToneParameterError: LocalizedError {
    case invalidParameterIndex
    case invalidParameterValue
    case parameterUpdateFailed
    case voiceMachineNotAvailable
    case presetLoadFailed
    case invalidPageNumber
    
    var errorDescription: String? {
        switch self {
        case .invalidParameterIndex:
            return "Invalid parameter index"
        case .invalidParameterValue:
            return "Invalid parameter value"
        case .parameterUpdateFailed:
            return "Failed to update parameter"
        case .voiceMachineNotAvailable:
            return "FM voice machine not available"
        case .presetLoadFailed:
            return "Failed to load preset"
        case .invalidPageNumber:
            return "Invalid page number"
        }
    }
}

// MARK: - Constants

public struct FMToneParameterConstants {
    public static let totalPages = 4
    public static let parametersPerPage = 8
    
    public static let pageNames = [
        "CORE FM",      // Page 1
        "ENVELOPES",    // Page 2  
        "BEHAVIOR",     // Page 3
        "TRACKING"      // Page 4
    ]
} 