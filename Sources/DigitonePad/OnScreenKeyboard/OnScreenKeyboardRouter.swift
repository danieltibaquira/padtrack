import Foundation
import SwiftUI

/// Router handles navigation and module creation for on-screen keyboard
class OnScreenKeyboardRouter: OnScreenKeyboardRouterProtocol {
    
    // MARK: - OnScreenKeyboardRouterProtocol
    
    static func createModule() -> AnyView {
        let view = OnScreenKeyboardView()
        let presenter = OnScreenKeyboardPresenter()
        let interactor = OnScreenKeyboardInteractor()
        let router = OnScreenKeyboardRouter()
        
        // Wire up VIPER components
        // Note: view gets presenter via @EnvironmentObject
        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter
        
        return AnyView(view.environmentObject(presenter))
    }
    
    func showScaleSelector() {
        // This would show a scale selector modal or sheet
        // For now, we'll handle this through the presenter's published properties
        print("Showing scale selector")
    }
    
    func showChordSelector() {
        // This would show a chord selector modal or sheet
        print("Showing chord selector")
    }
    
    func showKeyboardSettings() {
        // This would show keyboard settings (layout, sensitivity, etc.)
        print("Showing keyboard settings")
    }
}

// MARK: - SwiftUI Integration

extension OnScreenKeyboardRouter {
    /// Creates a SwiftUI view for the on-screen keyboard with delegate
    static func createKeyboardView(delegate: OnScreenKeyboardDelegate? = nil) -> some View {
        let presenter = OnScreenKeyboardPresenter()
        let interactor = OnScreenKeyboardInteractor()
        let router = OnScreenKeyboardRouter()
        
        let view = OnScreenKeyboardView()
        
        // Wire up VIPER components
        // Note: SwiftUI view gets presenter via @EnvironmentObject
        presenter.interactor = interactor
        presenter.router = router
        presenter.delegate = delegate
        interactor.presenter = presenter
        
        return view.environmentObject(presenter)
    }
    
    /// Creates a compact keyboard view for limited space
    static func createCompactKeyboardView(delegate: OnScreenKeyboardDelegate? = nil) -> some View {
        let presenter = OnScreenKeyboardPresenter()
        let interactor = OnScreenKeyboardInteractor()
        let router = OnScreenKeyboardRouter()
        
        let view = OnScreenKeyboardView()
        
        // Wire up VIPER components
        // Note: view gets presenter via @EnvironmentObject
        presenter.interactor = interactor
        presenter.router = router
        presenter.delegate = delegate
        interactor.presenter = presenter
        
        // Set compact layout
        presenter.setCompactLayout()
        
        return view.environmentObject(presenter)
    }
    
    /// Creates a keyboard view with custom configuration
    static func createCustomKeyboardView(
        octaveRange: ClosedRange<Int>,
        keySize: CGSize,
        delegate: OnScreenKeyboardDelegate? = nil
    ) -> some View {
        let presenter = OnScreenKeyboardPresenter()
        let interactor = OnScreenKeyboardInteractor()
        let router = OnScreenKeyboardRouter()
        
        let view = OnScreenKeyboardView()
        
        // Wire up VIPER components
        // Note: view gets presenter via @EnvironmentObject
        presenter.interactor = interactor
        presenter.router = router
        presenter.delegate = delegate
        interactor.presenter = presenter
        
        // Set custom layout
        presenter.createCustomLayout(octaveRange: octaveRange, keySize: keySize)
        
        return view.environmentObject(presenter)
    }
}
