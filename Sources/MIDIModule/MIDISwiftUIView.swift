// MIDISwiftUIView.swift
// DigitonePad - MIDIModule
//
// SwiftUI-based MIDI interface for cross-platform compatibility

import SwiftUI
import Combine

/// Main SwiftUI view for MIDI module interaction
public struct MIDISwiftUIView: View {
    @StateObject private var viewModel = MIDIViewModel()
    @State private var selectedDevice: MIDIDevice?
    @State private var showingDeviceList = false
    @State private var midiActivity: [MIDIMessage] = []
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // Device Status
                deviceStatusSection
                
                // MIDI Activity Monitor
                midiActivitySection
                
                // Control Panel
                controlPanelSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("MIDI Module")
            .toolbar {
                ToolbarItem(placement: toolbarPlacement) {
                    Button("Devices") {
                        showingDeviceList = true
                    }
                }
            }
            .sheet(isPresented: $showingDeviceList) {
                MIDIDeviceListView(
                    devices: viewModel.availableDevices,
                    connectedDevices: viewModel.connectedDevices,
                    onDeviceSelected: { device in
                        viewModel.connect(to: device)
                        selectedDevice = device
                        showingDeviceList = false
                    },
                    onDeviceDisconnected: { device in
                        viewModel.disconnect(from: device)
                    }
                )
            }
            .onAppear {
                viewModel.initialize()
            }
            .onReceive(viewModel.$lastReceivedMessage) { message in
                if let message = message {
                    midiActivity.insert(message, at: 0)
                    if midiActivity.count > 10 {
                        midiActivity.removeLast()
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("MIDI Interface")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(viewModel.connectionStatus.description)
                .font(.caption)
                .foregroundColor(viewModel.connectionStatus.color)
        }
    }
    
    private var deviceStatusSection: some View {
        GroupBox("Device Status") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Connected Devices:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(viewModel.connectedDevices.count)")
                        .foregroundColor(.secondary)
                }
                
                if viewModel.connectedDevices.isEmpty {
                    Text("No devices connected")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(viewModel.connectedDevices, id: \.id) { device in
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text(device.name)
                            Spacer()
                            Text(device.connectionDirection.rawValue.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var midiActivitySection: some View {
        GroupBox("MIDI Activity") {
            VStack(alignment: .leading, spacing: 4) {
                if midiActivity.isEmpty {
                    Text("No MIDI activity")
                        .foregroundColor(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(Array(midiActivity.enumerated()), id: \.offset) { index, message in
                        MIDIMessageRow(message: message, isRecent: index < 3)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }
    
    private var controlPanelSection: some View {
        GroupBox("Test Controls") {
            VStack(spacing: 12) {
                // Note testing buttons
                HStack {
                    Text("Test Notes:")
                        .fontWeight(.medium)
                    Spacer()
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach([60, 62, 64, 65, 67, 69, 71, 72], id: \.self) { note in
                        Button(action: {
                            viewModel.sendTestNote(note: UInt8(note))
                        }) {
                            VStack {
                                Text(noteNames[note] ?? "?")
                                    .font(.caption2)
                                Text("\(note)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.connectedDevices.isEmpty)
                    }
                }
                
                // Control Change testing
                HStack {
                    Text("Test CC:")
                        .fontWeight(.medium)
                    
                    Button("Volume") {
                        viewModel.sendTestCC(controller: 7, value: 100)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.connectedDevices.isEmpty)
                    
                    Button("Pan") {
                        viewModel.sendTestCC(controller: 10, value: 64)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.connectedDevices.isEmpty)
                    
                    Spacer()
                }
            }
        }
    }
    
    private let noteNames: [Int: String] = [
        60: "C4", 62: "D4", 64: "E4", 65: "F4",
        67: "G4", 69: "A4", 71: "B4", 72: "C5"
    ]
    
    private var toolbarPlacement: ToolbarItemPlacement {
#if os(iOS)
        return .navigationBarTrailing
#else
        return .primaryAction
#endif
    }
}

// MARK: - MIDI Message Row View

struct MIDIMessageRow: View {
    let message: MIDIMessage
    let isRecent: Bool
    
    var body: some View {
        HStack {
            Circle()
                .fill(isRecent ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
            
            Text(message.type.displayName)
                .font(.caption)
                .fontWeight(.medium)
            
            Text("Ch \(message.channel + 1)")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if message.type == .noteOn || message.type == .noteOff {
                Text("Note \(message.data1)")
                    .font(.caption2)
                Text("Vel \(message.data2)")
                    .font(.caption2)
            } else if message.type == .controlChange {
                Text("CC \(message.data1)")
                    .font(.caption2)
                Text("Val \(message.data2)")
                    .font(.caption2)
            }
            
            Spacer()
            
            Text(timeString(from: message.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    private func timeString(from timestamp: UInt64) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: Date())
    }
}

// MARK: - Device List View

struct MIDIDeviceListView: View {
    let devices: [MIDIDevice]
    let connectedDevices: [MIDIDevice]
    let onDeviceSelected: (MIDIDevice) -> Void
    let onDeviceDisconnected: (MIDIDevice) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Available Devices") {
                    if devices.isEmpty {
                        Text("No MIDI devices found")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(devices, id: \.id) { device in
                            MIDIDeviceRow(
                                device: device,
                                isConnected: connectedDevices.contains { $0.id == device.id },
                                onConnect: { onDeviceSelected(device) },
                                onDisconnect: { onDeviceDisconnected(device) }
                            )
                        }
                    }
                }
            }
            .navigationTitle("MIDI Devices")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: toolbarPlacement) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var toolbarPlacement: ToolbarItemPlacement {
#if os(iOS)
        return .navigationBarTrailing
#else
        return .primaryAction
#endif
    }
}

// MARK: - Device Row View

struct MIDIDeviceRow: View {
    let device: MIDIDevice
    let isConnected: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .fontWeight(.medium)
                
                Text("\(device.manufacturer) • \(device.connectionDirection.rawValue.capitalized)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !device.isOnline {
                Text("Offline")
                    .font(.caption)
                    .foregroundColor(.red)
            } else if isConnected {
                Button("Disconnect") {
                    onDisconnect()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button("Connect") {
                    onConnect()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .opacity(device.isOnline ? 1.0 : 0.6)
    }
}

// MARK: - Extensions

extension MIDIConnectionStatus {
    var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error: return "Error"
        }
    }
    
    var color: Color {
        switch self {
        case .disconnected: return .secondary
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
}

extension MIDIMessageType {
    var displayName: String {
        switch self {
        case .noteOff: return "Note Off"
        case .noteOn: return "Note On"
        case .controlChange: return "CC"
        case .programChange: return "PC"
        case .pitchBend: return "Pitch"
        case .systemExclusive: return "SysEx"
        case .timingClock: return "Clock"
        case .start: return "Start"
        case .continue: return "Continue"
        case .stop: return "Stop"
        }
    }
} 