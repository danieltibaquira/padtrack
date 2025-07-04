// DigitonePadTypes.swift
// DigitonePad - Essential Type Declarations
//
// This file ensures core types are accessible in the correct compilation order

import Foundation
import SwiftUI
import Combine
// import AppShell  // Temporarily commented out due to build issues
import DataLayer

// MARK: - AppState Declaration

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var currentProject: ProjectViewModel?
    @Published public var isProjectSelected: Bool = false
    @Published public var showProjectManagement: Bool = false

    private init() {
        // Simple initialization
        isProjectSelected = false
        showProjectManagement = false
    }

    public func selectProject(_ project: ProjectViewModel) {
        currentProject = project
        showProjectManagement = false
        isProjectSelected = true
    }

    public func showProjectSelection() {
        showProjectManagement = true
    }
}

// ProjectManagementRouter is defined in ProjectManagement/ProjectManagementRouter.swift
