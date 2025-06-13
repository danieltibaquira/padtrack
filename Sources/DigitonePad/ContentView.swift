// ContentView.swift
// DigitonePad - Main App
//
// Main SwiftUI view for the DigitonePad application

import SwiftUI
import AppShell

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("DigitonePad")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Elektron-style FM Synthesizer")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .onAppear {
            // Initialize the app shell when the view appears
            AppShell.shared.initialize()
        }
    }
}

#Preview {
    ContentView()
}
