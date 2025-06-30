import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - Key Combo View Protocol

/// Protocol for Key Combo views
public protocol KeyComboViewProtocol: AnyObject {
    func showAvailableCombos(_ combos: [KeyComboViewModel])
    func highlightCombo(_ combo: KeyComboViewModel)
    func showComboFeedback(_ combo: KeyComboViewModel, success: Bool)
    func showComboHelp(_ combos: [KeyComboViewModel])
    func hideComboOverlay()
    func updateContextIndicator(_ context: String)
}

// MARK: - Main Key Combo View

/// Main view for displaying key combo overlays and feedback
public struct KeyComboView: View {
    @StateObject private var presenter: KeyComboPresenter
    @StateObject private var detector: KeyComboDetector
    
    public init(presenter: KeyComboPresenter, detector: KeyComboDetector) {
        self._presenter = StateObject(wrappedValue: presenter)
        self._detector = StateObject(wrappedValue: detector)
    }
    
    public var body: some View {
        ZStack {
            // Main content area (transparent)
            Color.clear
            
            // Combo overlay
            if presenter.isShowingCombos {
                KeyComboOverlayView(
                    combos: presenter.availableCombos,
                    activeModifiers: detector.activeModifiers
                )
                .transition(.opacity.combined(with: .scale))
            }
            
            // Feedback overlay
            if let feedback = presenter.currentFeedback {
                KeyComboFeedbackView(feedback: feedback)
                    .transition(.opacity.combined(with: .scale))
            }
            
            // Help overlay
            if presenter.isShowingHelp {
                KeyComboHelpView(
                    combos: presenter.helpCombos,
                    onDismiss: presenter.dismissComboHelp
                )
                .transition(.move(edge: .bottom))
            }
            
            // Context indicator
            VStack {
                HStack {
                    if let context = presenter.contextViewModel {
                        KeyComboContextIndicator(context: context)
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding()
        }
        .animation(.easeInOut(duration: 0.3), value: presenter.isShowingCombos)
        .animation(.easeInOut(duration: 0.2), value: presenter.currentFeedback?.combo.id)
        .animation(.easeInOut(duration: 0.4), value: presenter.isShowingHelp)
    }
}

// MARK: - Key Combo Overlay

/// Overlay showing available key combinations
struct KeyComboOverlayView: View {
    let combos: [KeyComboViewModel]
    let activeModifiers: Set<KeyModifier>
    
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                ForEach(Array(activeModifiers), id: \.self) { modifier in
                    Text(modifier.symbol)
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.8))
                        )
                }
                
                Text("+")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Key")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text("\(combos.count) available")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.8))
            )
            
            // Combo grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(combos.prefix(16)) { combo in
                    KeyComboItemView(combo: combo)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.7))
            )
        }
        .padding()
        .offset(y: animationOffset)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                animationOffset = 0
            }
        }
        .onDisappear {
            animationOffset = -20
        }
    }
}

// MARK: - Key Combo Item

/// Individual key combo item in the overlay
struct KeyComboItemView: View {
    let combo: KeyComboViewModel
    
    @State private var isHighlighted: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            // Key symbol
            Text(combo.keySymbol)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(combo.isEnabled ? .white : .gray)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(borderColor, lineWidth: isHighlighted ? 2 : 1)
                        )
                )
                .scaleEffect(isHighlighted ? 1.1 : 1.0)
            
            // Description
            Text(combo.shortDescription)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .opacity(combo.isEnabled ? 1.0 : 0.6)
        .animation(.easeInOut(duration: 0.2), value: isHighlighted)
        .onReceive(NotificationCenter.default.publisher(for: .keyComboHighlight)) { notification in
            if let comboId = notification.object as? String, comboId == combo.id {
                highlightTemporarily()
            }
        }
    }
    
    private var backgroundColor: Color {
        if combo.isHighlighted {
            return .blue.opacity(0.8)
        } else if combo.isEnabled {
            return .gray.opacity(0.3)
        } else {
            return .gray.opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        if isHighlighted {
            return .white
        } else if combo.isHighlighted {
            return .blue
        } else {
            return .gray.opacity(0.5)
        }
    }
    
    private func highlightTemporarily() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isHighlighted = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isHighlighted = false
            }
        }
    }
}

// MARK: - Key Combo Feedback

/// Feedback view for combo execution results
struct KeyComboFeedbackView: View {
    let feedback: KeyComboFeedbackViewModel
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon
            Image(systemName: feedback.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(feedback.success ? .green : .red)
            
            // Combo display
            HStack(spacing: 4) {
                Text(feedback.combo.modifierSymbol)
                    .font(.title3)
                Text("+")
                    .font(.title3)
                Text(feedback.combo.keySymbol)
                    .font(.title3)
            }
            .foregroundColor(.white)
            
            // Message
            Text(feedback.message)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.8))
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - Key Combo Help

/// Help view showing all available combos
struct KeyComboHelpView: View {
    let combos: [KeyComboViewModel]
    let onDismiss: () -> Void
    
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "All"
    
    private var categories: [String] {
        let allCategories = Set(combos.map { $0.category })
        return ["All"] + Array(allCategories).sorted()
    }
    
    private var filteredCombos: [KeyComboViewModel] {
        var filtered = combos
        
        // Filter by category
        if selectedCategory != "All" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            let lowercaseSearch = searchText.lowercased()
            filtered = filtered.filter { combo in
                combo.displayText.lowercased().contains(lowercaseSearch) ||
                combo.description.lowercased().contains(lowercaseSearch)
            }
        }
        
        return filtered.sorted { $0.priority > $1.priority }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Key Combinations")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Done", action: onDismiss)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color.black.opacity(0.9))
            
            // Search and filter
            VStack(spacing: 12) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search combinations...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.white)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                )
                
                // Category picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { category in
                            Button(category) {
                                selectedCategory = category
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selectedCategory == category ? Color.blue : Color.gray.opacity(0.3))
                            )
                            .foregroundColor(.white)
                            .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .background(Color.black.opacity(0.8))
            
            // Combo list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredCombos) { combo in
                        KeyComboHelpItemView(combo: combo)
                    }
                }
                .padding()
            }
            .background(Color.black.opacity(0.7))
        }
        .background(Color.black.opacity(0.9))
        .cornerRadius(16, corners: [.topLeft, .topRight])
    }
}

// MARK: - Key Combo Help Item

/// Individual item in the help list
struct KeyComboHelpItemView: View {
    let combo: KeyComboViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Text(combo.categoryIcon)
                .font(.title3)
            
            // Combo display
            HStack(spacing: 4) {
                Text(combo.modifierSymbol)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.8))
                    )
                
                Text("+")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(combo.keySymbol)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                    )
            }
            .foregroundColor(.white)
            
            // Description
            VStack(alignment: .leading, spacing: 2) {
                Text(combo.description)
                    .font(.body)
                    .foregroundColor(.white)
                
                Text(combo.category)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Enabled indicator
            if !combo.isEnabled {
                Text("Disabled")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red.opacity(0.2))
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
        .opacity(combo.isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Context Indicator

/// Shows the current app context
struct KeyComboContextIndicator: View {
    let context: KeyComboContextViewModel
    
    var body: some View {
        HStack(spacing: 6) {
            Text(context.icon)
                .font(.caption)
            
            Text(context.mode)
                .font(.caption)
                .fontWeight(.medium)
            
            if let subMode = context.subMode {
                Text("•")
                    .font(.caption)
                    .opacity(0.6)
                
                Text(subMode)
                    .font(.caption)
                    .opacity(0.8)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(context.color.opacity(0.8))
        )
    }
}

// MARK: - Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let tl = corners.contains(.topLeft)
        let tr = corners.contains(.topRight)
        let bl = corners.contains(.bottomLeft)
        let br = corners.contains(.bottomRight)
        
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: tl ? radius : 0, y: 0))
        path.addLine(to: CGPoint(x: width - (tr ? radius : 0), y: 0))
        if tr { path.addArc(center: CGPoint(x: width - radius, y: radius), radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false) }
        path.addLine(to: CGPoint(x: width, y: height - (br ? radius : 0)))
        if br { path.addArc(center: CGPoint(x: width - radius, y: height - radius), radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false) }
        path.addLine(to: CGPoint(x: bl ? radius : 0, y: height))
        if bl { path.addArc(center: CGPoint(x: radius, y: height - radius), radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false) }
        path.addLine(to: CGPoint(x: 0, y: tl ? radius : 0))
        if tl { path.addArc(center: CGPoint(x: radius, y: radius), radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false) }
        path.closeSubpath()
        
        return path
    }
}

struct RectCorner: OptionSet {
    let rawValue: Int
    
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

// MARK: - Notifications

extension Notification.Name {
    static let keyComboHighlight = Notification.Name("keyComboHighlight")
}
