import Foundation

/// Simple parameter smoother for audio parameter interpolation
public final class ParameterSmoother: @unchecked Sendable {
    private var currentValue: Float = 0.0
    private var targetValue: Float = 0.0
    private var smoothingCoeff: Float = 0.0
    private let sampleRate: Float
    
    public init(sampleRate: Float, smoothingTime: Float) {
        self.sampleRate = sampleRate
        self.smoothingCoeff = exp(-1.0 / (smoothingTime * sampleRate))
    }
    
    public func setTarget(_ value: Float) {
        targetValue = value
    }
    
    public func process() -> Float {
        currentValue = targetValue + smoothingCoeff * (currentValue - targetValue)
        return currentValue
    }
    
    public func reset(_ value: Float = 0.0) {
        currentValue = value
        targetValue = value
    }
    
    public var value: Float {
        return currentValue
    }
}
