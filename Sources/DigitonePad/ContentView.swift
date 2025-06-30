// ContentView.swift
// DigitonePad - Main App
//
// Main SwiftUI view for the DigitonePad application

import SwiftUI
// import AppShell  // Temporarily commented out due to build issues
import DataLayer

public struct ContentView: View {
    @State private var showProjectManagement = false
    @State private var isProjectSelected = false

    public init() {}

    public var body: some View {
        Group {
            if isProjectSelected {
                // Show main app interface when project is selected
                VStack {
                    Text("DigitonePad Main Interface")
                        .font(.title)
                        .foregroundColor(.white)

                    Button("Show Project Management") {
                        showProjectManagement = true
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .onAppear {
                    // Initialize the app shell when the view appears
                    // AppShell.shared.initialize()  // Temporarily commented out due to build issues
                    print("App appeared - AppShell initialization temporarily disabled")
                }
            } else {
                // Show project management when no project is selected
                VStack {
                    Text("Project Management")
                        .font(.title)
                        .foregroundColor(.white)

                    Button("Select Project") {
                        isProjectSelected = true
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray)
            }
        }
        .sheet(isPresented: $showProjectManagement) {
            VStack {
                Text("Project Management Sheet")
                    .font(.title)
                    .foregroundColor(.white)

                Button("Close") {
                    showProjectManagement = false
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
    }
}

#Preview {
    ContentView()
}
