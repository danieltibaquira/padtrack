import Foundation
import Combine

public class ObservableParameterManager: ObservableObject, @unchecked Sendable {
    // MARK: - Published Properties
    @Published public private(set) var parameters: [String: Parameter] = [:]
    @Published public private(set) var lastUpdatedParameterId: String?
    
    // MARK: - Properties
    private var parameterUpdateCallback: ((String, Float) -> Void)?
    public var groups: [String: ParameterGroup] = [:]
    
    // MARK: - Initialization
    public init() {}
    
    // MARK: - Parameter Management
    public func addParameter(_ parameter: Parameter) {
        parameters[parameter.id] = parameter
    }
    
    public func getParameter(id: String) -> Parameter? {
        return parameters[id]
    }
    
    public func getParameterValue(id: String) -> Float? {
        return parameters[id]?.value
    }
    
    public func updateParameter(id: String, value: Float, notifyChange: Bool = true) {
        guard var parameter = parameters[id] else { return }
        parameter.setValue(value, notifyChange: false)
        parameters[id] = parameter
        lastUpdatedParameterId = id

        if notifyChange {
            parameterUpdateCallback?(id, value)
        }
    }
    
    public func getAllValues() -> [String: Float] {
        var values: [String: Float] = [:]
        for (id, parameter) in parameters {
            values[id] = parameter.value
        }
        return values
    }
    
    public func resetAllToDefaults() {
        for (id, parameter) in parameters {
            updateParameter(id: id, value: parameter.defaultValue)
        }
    }
    
    public func setUpdateCallback(_ callback: @escaping (String, Float) -> Void) {
        parameterUpdateCallback = callback
    }
    
    // MARK: - Additional Methods
    public func setValues(_ values: [String: Float], notifyChanges: Bool = true) throws {
        for (id, value) in values {
            updateParameter(id: id, value: value, notifyChange: notifyChanges)
        }
    }
    
    public func validateAllParameters() -> [String] {
        var errors: [String] = []
        for (id, parameter) in parameters {
            if parameter.value < parameter.minValue || parameter.value > parameter.maxValue {
                errors.append("Parameter \(id) value \(parameter.value) is out of range [\(parameter.minValue), \(parameter.maxValue)]")
            }
        }
        return errors
    }
    
    // MARK: - Compatibility Methods for Legacy Code
    
    /// Get all parameters (for compatibility with older code)
    public func getAllParameters() -> [Parameter] {
        return Array(parameters.values)
    }
    
    /// Set parameter value (for compatibility with older code)
    public func setValue(_ parameterID: String, value: Float) {
        updateParameter(id: parameterID, value: value)
    }
    
    /// Get parameter value (for compatibility with older code)
    public func getValue(_ parameterID: String) -> Float? {
        return getParameterValue(id: parameterID)
    }
} 