// ParameterPageView.swift
// DigitonePad - Parameter Page Navigation Component
//
// Implements the parameter page navigation system for switching between parameter pages

import SwiftUI
import UIComponents

/// Parameter page view with navigation and parameter display
public struct ParameterPageView: View {
    @ObservedObject private var layoutState: MainLayoutState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    public init(layoutState: MainLayoutState) {
        self.layoutState = layoutState
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Page header with navigation
            pageHeader
            
            // Parameter content area
            parameterContentArea
            
            // Page navigation controls
            pageNavigationControls
        }
        .padding(16)
        .background(pageBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DigitonePadTheme.darkHardware.secondaryColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Page Header
    
    @ViewBuilder
    private var pageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("PARAMETER PAGE")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.textColor)
                
                Text(pageSubtitle)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.secondaryColor)
            }
            
            Spacer()
            
            // Current page indicator
            HStack(spacing: 8) {
                Text("PAGE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.secondaryColor)
                
                DigitonePadDisplay(
                    text: "\(layoutState.currentPage)",
                    isActive: true,
                    theme: .darkHardware
                )
                .frame(width: 40, height: 24)
                
                Text("/ 8")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(DigitonePadTheme.darkHardware.secondaryColor)
            }
        }
    }
    
    // MARK: - Parameter Content Area
    
    @ViewBuilder
    private var parameterContentArea: some View {
        VStack(spacing: 20) {
            // Parameter grid based on current page and context
            parameterGrid
            
            // Parameter value displays
            parameterValueDisplays
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.2))
        )
        .padding(8)
    }
    
    // MARK: - Parameter Grid
    
    @ViewBuilder
    private var parameterGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(0..<8, id: \.self) { index in
                ParameterDisplayCard(
                    index: index,
                    layoutState: layoutState
                )
            }
        }
    }
    
    // MARK: - Parameter Value Displays
    
    @ViewBuilder
    private var parameterValueDisplays: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                VStack(spacing: 4) {
                    Text(layoutState.parameterLabels[index])
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(DigitonePadTheme.darkHardware.textColor)
                        .lineLimit(1)
                    
                    DigitonePadDisplay(
                        text: formattedParameterValue(index),
                        isActive: true,
                        theme: .darkHardware
                    )
                    .frame(height: 20)
                }
                .frame(maxWidth: .infinity)
            }
        }
        
        HStack(spacing: 12) {
            ForEach(4..<8, id: \.self) { index in
                VStack(spacing: 4) {
                    Text(layoutState.parameterLabels[index])
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(DigitonePadTheme.darkHardware.textColor)
                        .lineLimit(1)
                    
                    DigitonePadDisplay(
                        text: formattedParameterValue(index),
                        isActive: true,
                        theme: .darkHardware
                    )
                    .frame(height: 20)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Page Navigation Controls
    
    @ViewBuilder
    private var pageNavigationControls: some View {
        HStack(spacing: 20) {
            // Previous page button
            DigitonePadButton(
                config: ButtonConfig(
                    title: "◀ PREV",
                    style: layoutState.currentPage > 1 ? .secondary : .disabled,
                    onTap: {
                        if layoutState.currentPage > 1 {
                            layoutState.previousPage()
                        }
                    }
                ),
                theme: .darkHardware
            )
            .frame(maxWidth: .infinity)
            
            // Page indicators
            HStack(spacing: 6) {
                ForEach(1...8, id: \.self) { page in
                    Circle()
                        .fill(page == layoutState.currentPage ? 
                              DigitonePadTheme.darkHardware.accentColor : 
                              DigitonePadTheme.darkHardware.secondaryColor.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .onTapGesture {
                            layoutState.setPage(page)
                        }
                }
            }
            .frame(maxWidth: .infinity)
            
            // Next page button
            DigitonePadButton(
                config: ButtonConfig(
                    title: "NEXT ▶",
                    style: layoutState.currentPage < 8 ? .secondary : .disabled,
                    onTap: {
                        if layoutState.currentPage < 8 {
                            layoutState.nextPage()
                        }
                    }
                ),
                theme: .darkHardware
            )
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var pageBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.6),
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.6)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    // MARK: - Computed Properties

    private var isLandscape: Bool {
        return horizontalSizeClass == .regular && verticalSizeClass == .compact
    }

    private var gridColumns: [GridItem] {
        let columns = isLandscape ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: columns)
    }

    private var pageSubtitle: String {
        switch layoutState.selectedFunction {
        case .grid:
            return "STEP PARAMETERS - PAGE \(layoutState.currentPage)"
        case .parameter:
            return "SOUND PARAMETERS - PAGE \(layoutState.currentPage)"
        case .mixer:
            return "MIXER PARAMETERS - PAGE \(layoutState.currentPage)"
        }
    }

    private func formattedParameterValue(_ index: Int) -> String {
        let value = layoutState.parameterValues[index]
        return String(format: "%.0f", value * 127)
    }
}

// MARK: - Parameter Display Card

/// Individual parameter display card
struct ParameterDisplayCard: View {
    let index: Int
    @ObservedObject var layoutState: MainLayoutState

    var body: some View {
        VStack(spacing: 8) {
            // Parameter name
            Text(layoutState.parameterLabels[index])
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(DigitonePadTheme.darkHardware.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Parameter value bar
            VStack(spacing: 4) {
                // Value display
                DigitonePadDisplay(
                    text: formattedValue,
                    isActive: true,
                    theme: .darkHardware
                )
                .frame(height: 24)

                // Value bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background bar
                        RoundedRectangle(cornerRadius: 2)
                            .fill(DigitonePadTheme.darkHardware.secondaryColor.opacity(0.3))
                            .frame(height: 6)

                        // Value bar
                        RoundedRectangle(cornerRadius: 2)
                            .fill(DigitonePadTheme.darkHardware.accentColor)
                            .frame(width: geometry.size.width * CGFloat(layoutState.parameterValues[index]), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DigitonePadTheme.darkHardware.secondaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var formattedValue: String {
        let value = layoutState.parameterValues[index]
        return String(format: "%.0f", value * 127)
    }
}
