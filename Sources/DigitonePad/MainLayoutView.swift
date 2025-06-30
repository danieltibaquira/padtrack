// MainLayoutView.swift
// DigitonePad - Main Application Layout
//
// Main application layout mimicking the Digitone hardware interface

import SwiftUI
import UIComponents
import Combine

// MARK: - Temporary AppState Definition
// TODO: Move this back to DigitonePadTypes.swift once AppShell issues are resolved
// TEST COMMENT TO VERIFY BUILD IS USING THIS FILE

public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var currentProject: String? // Simplified for now
    @Published public var isProjectSelected: Bool = false
    @Published public var showProjectManagement: Bool = false

    private init() {
        // Simple initialization
        isProjectSelected = false
        showProjectManagement = false
    }

    public func selectProject(_ projectName: String) {
        currentProject = projectName
        showProjectManagement = false
        isProjectSelected = true
    }

    public func showProjectSelection() {
        showProjectManagement = true
    }
}

/// Main application layout view that mimics the Digitone hardware interface
public struct MainLayoutView: View {
    @StateObject private var layoutState = MainLayoutState()
    @StateObject private var appState = AppState.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                DigitonePadTheme.darkHardware.backgroundColor
                    .ignoresSafeArea()
                
                if isLandscape(geometry: geometry) {
                    landscapeLayout(geometry: geometry)
                } else {
                    portraitLayout(geometry: geometry)
                }
            }
        }
        .onAppear {
            layoutState.updateOrientation(isLandscape: horizontalSizeClass == .regular && verticalSizeClass == .compact)
        }
        .onChange(of: horizontalSizeClass) { _ in
            layoutState.updateOrientation(isLandscape: horizontalSizeClass == .regular && verticalSizeClass == .compact)
        }
        .onChange(of: verticalSizeClass) { _ in
            layoutState.updateOrientation(isLandscape: horizontalSizeClass == .regular && verticalSizeClass == .compact)
        }
    }
    
    // MARK: - Layout Variants
    
    @ViewBuilder
    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left side - Main content area
            VStack(spacing: 0) {
                topSection(geometry: geometry, isLandscape: true)
                    .frame(height: geometry.size.height * 0.25)
                
                middleSection(geometry: geometry, isLandscape: true)
                    .frame(height: geometry.size.height * 0.5)
                
                bottomSection(geometry: geometry, isLandscape: true)
                    .frame(height: geometry.size.height * 0.25)
            }
            .frame(width: geometry.size.width * 0.7)
            
            // Right side - Controls
            controlsSection(geometry: geometry, isLandscape: true)
                .frame(width: geometry.size.width * 0.3)
        }
    }
    
    @ViewBuilder
    private func portraitLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            topSection(geometry: geometry, isLandscape: false)
                .frame(height: geometry.size.height * 0.2)
            
            middleSection(geometry: geometry, isLandscape: false)
                .frame(height: geometry.size.height * 0.5)
            
            bottomSection(geometry: geometry, isLandscape: false)
                .frame(height: geometry.size.height * 0.3)
        }
    }
    
    // MARK: - Section Views
    
    @ViewBuilder
    private func topSection(geometry: GeometryProxy, isLandscape: Bool) -> some View {
        HStack {
            // Project menu button
            DigitonePadButton(
                config: ButtonConfig(
                    title: "PROJ",
                    style: .secondary,
                    onTap: { appState.showProjectSelection() }
                ),
                theme: .darkHardware
            )
            .frame(width: 60)

            // LCD Display Area
            HeaderDisplayView(layoutState: layoutState)

            // Transport controls (landscape only)
            if isLandscape {
                transportControls()
                    .padding(.trailing, 16)
            }
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private func middleSection(geometry: GeometryProxy, isLandscape: Bool) -> some View {
        VStack(spacing: 16) {
            // Function buttons row
            HStack(spacing: 12) {
                ForEach(FunctionButton.allCases, id: \.self) { button in
                    DigitonePadButton(
                        config: ButtonConfig(
                            title: button.title,
                            style: layoutState.selectedFunction == button ? .accent : .secondary,
                            onTap: {
                                layoutState.selectFunction(button)
                            }
                        ),
                        theme: .darkHardware
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            
            // Parameter encoders
            ParameterEncoderSection(layoutState: layoutState)
            
            // Main content area (grid or parameter page)
            mainContentArea(geometry: geometry, isLandscape: isLandscape)
        }
        .padding(.vertical, 16)
    }
    
    @ViewBuilder
    private func bottomSection(geometry: GeometryProxy, isLandscape: Bool) -> some View {
        VStack(spacing: 12) {
            if !isLandscape {
                // Transport controls for portrait
                transportControls()
                    .padding(.horizontal, 16)
            }
            
            // 16 step buttons
            StepSequencerGrid(layoutState: layoutState)
            
            // Mode selection buttons
            HStack(spacing: 16) {
                ForEach(SequencerMode.allCases, id: \.self) { mode in
                    DigitonePadButton(
                        config: ButtonConfig(
                            title: mode.rawValue,
                            style: layoutState.currentMode == mode ? .accent : .secondary,
                            onTap: {
                                layoutState.setMode(mode)
                            }
                        ),
                        theme: .darkHardware
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 16)
    }
    
    @ViewBuilder
    private func controlsSection(geometry: GeometryProxy, isLandscape: Bool) -> some View {
        VStack(spacing: 16) {
            // Track selection
            trackSelectionControls()
            
            // Page navigation
            pageNavigationControls()
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DigitonePadTheme.darkHardware.secondaryColor, lineWidth: 1)
                )
        )
        .padding(.trailing, 16)
        .padding(.vertical, 16)
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func transportControls() -> some View {
        HStack(spacing: 12) {
            DigitonePadButton(
                config: ButtonConfig(
                    title: "◀◀",
                    style: .secondary,
                    onTap: { layoutState.rewind() }
                ),
                theme: .darkHardware
            )
            
            DigitonePadButton(
                config: ButtonConfig(
                    title: layoutState.isPlaying ? "⏸" : "▶",
                    style: layoutState.isPlaying ? .accent : .primary,
                    onTap: { layoutState.togglePlayback() }
                ),
                theme: .darkHardware
            )
            
            DigitonePadButton(
                config: ButtonConfig(
                    title: "⏹",
                    style: .secondary,
                    onTap: { layoutState.stop() }
                ),
                theme: .darkHardware
            )
            
            DigitonePadButton(
                config: ButtonConfig(
                    title: "⏺",
                    style: layoutState.isRecording ? .destructive : .secondary,
                    onTap: { layoutState.toggleRecording() }
                ),
                theme: .darkHardware
            )
        }
    }
    

    
    @ViewBuilder
    private func mainContentArea(geometry: GeometryProxy, isLandscape: Bool) -> some View {
        Group {
            switch layoutState.selectedFunction {
            case .grid:
                // Sequencer grid view
                Text("GRID VIEW")
                    .font(.title2)
                    .foregroundColor(DigitonePadTheme.darkHardware.textColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    
            case .parameter:
                // Parameter page view
                ParameterPageView(layoutState: layoutState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
            case .mixer:
                // Mixer view
                Text("MIXER VIEW")
                    .font(.title2)
                    .foregroundColor(DigitonePadTheme.darkHardware.textColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
    }
    


    @ViewBuilder
    private func trackSelectionControls() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRACK")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(DigitonePadTheme.darkHardware.textColor)

            VStack(spacing: 8) {
                ForEach(1...4, id: \.self) { track in
                    DigitonePadButton(
                        config: ButtonConfig(
                            title: "T\(track)",
                            style: layoutState.selectedTrack == track ? .accent : .secondary,
                            onTap: {
                                layoutState.selectTrack(track)
                            }
                        ),
                        theme: .darkHardware
                    )
                    .frame(height: 36)
                }
            }
        }
    }

    @ViewBuilder
    private func pageNavigationControls() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PAGE")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(DigitonePadTheme.darkHardware.textColor)

            VStack(spacing: 8) {
                DigitonePadButton(
                    config: ButtonConfig(
                        title: "▲",
                        style: .secondary,
                        onTap: { layoutState.previousPage() }
                    ),
                    theme: .darkHardware
                )
                .frame(height: 36)

                DigitonePadDisplay(
                    text: "\(layoutState.currentPage)",
                    isActive: true,
                    theme: .darkHardware
                )
                .frame(height: 36)

                DigitonePadButton(
                    config: ButtonConfig(
                        title: "▼",
                        style: .secondary,
                        onTap: { layoutState.nextPage() }
                    ),
                    theme: .darkHardware
                )
                .frame(height: 36)
            }
        }
    }



    // MARK: - Utility Functions

    private func isLandscape(geometry: GeometryProxy) -> Bool {
        return geometry.size.width > geometry.size.height
    }
}


