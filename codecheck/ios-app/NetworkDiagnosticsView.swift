import SwiftUI
import Network

/// Real-time network diagnostics view
struct NetworkDiagnosticsView: View {
    @StateObject private var monitor = NetworkMonitor()
    @State private var showingInstructions = false
    
    var body: some View {
        List {
            // Network Status
            Section("Network Status") {
                HStack {
                    Circle()
                        .fill(monitor.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(monitor.isConnected ? "Connected" : "Disconnected")
                        .font(.headline)
                    
                    Spacer()
                    
                    if monitor.isExpensive {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.orange)
                            .help("Cellular connection")
                    }
                }
                
                if let connectionType = monitor.connectionType {
                    HStack {
                        Text("Connection Type")
                        Spacer()
                        Text(connectionType)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Requirements Check
            Section {
                RequirementRow(
                    requirement: "Network Connection",
                    isMet: monitor.isConnected,
                    details: monitor.isConnected ? "Device is connected to network" : "No network connection detected"
                )
                
                RequirementRow(
                    requirement: "WiFi Connection",
                    isMet: monitor.connectionType == "WiFi",
                    details: monitor.connectionType == "WiFi" ? "Connected to WiFi" : "Not on WiFi - backend won't be reachable"
                )
                
                RequirementRow(
                    requirement: "Low Cost Network",
                    isMet: !monitor.isExpensive,
                    details: !monitor.isExpensive ? "Using WiFi (no cellular charges)" : "Using cellular data - may not reach local server"
                )
            } header: {
                Text("Requirements for Local Backend")
            } footer: {
                Text("To connect to a backend server on your Mac, you must be on WiFi and on the same network as your Mac.")
            }
            
            // System Info
            Section("Device Information") {
                HStack {
                    Text("Device Type")
                    Spacer()
                    #if targetEnvironment(simulator)
                    Text("iOS Simulator")
                        .foregroundColor(.secondary)
                    #else
                    Text("Physical Device")
                        .foregroundColor(.secondary)
                    #endif
                }
                
                HStack {
                    Text("iOS Version")
                    Spacer()
                    Text(UIDevice.current.systemVersion)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Device Model")
                    Spacer()
                    Text(UIDevice.current.model)
                        .foregroundColor(.secondary)
                }
            }
            
            // Instructions
            Section {
                Button {
                    showingInstructions = true
                } label: {
                    Label("View Setup Instructions", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("Network Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingInstructions) {
            SetupInstructionsView()
        }
    }
}

// MARK: - Requirement Row

struct RequirementRow: View {
    let requirement: String
    let isMet: Bool
    let details: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: isMet ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isMet ? .green : .red)
                
                Text(requirement)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            Text(details)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Setup Instructions View

struct SetupInstructionsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Step 1
                    InstructionStep(
                        number: 1,
                        title: "Start Your Backend Server",
                        description: "Make sure your backend server is running on your Mac",
                        code: "# Should see:\nServer running on http://0.0.0.0:8000"
                    )
                    
                    // Step 2
                    InstructionStep(
                        number: 2,
                        title: "Find Your Mac's IP Address",
                        description: "You need your Mac's local network IP address",
                        code: "# Option 1 - Terminal:\nipconfig getifaddr en0\n\n# Option 2 - System Settings:\n# Network → WiFi → Details"
                    )
                    
                    // Step 3
                    InstructionStep(
                        number: 3,
                        title: "Configure the App",
                        description: "Enter your Mac's IP address in Server Settings",
                        code: "# Format:\nhttp://YOUR_MAC_IP:8000\n\n# Example:\nhttp://192.168.1.100:8000"
                    )
                    
                    // Step 4
                    InstructionStep(
                        number: 4,
                        title: "Verify Same Network",
                        description: "Both devices must be on the same WiFi",
                        icon: "wifi"
                    )
                    
                    // Step 5
                    InstructionStep(
                        number: 5,
                        title: "Test Connection",
                        description: "Use the connection test in Server Settings to verify",
                        icon: "network"
                    )
                }
                .padding()
            }
            .navigationTitle("Setup Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let title: String
    let description: String
    var code: String? = nil
    var icon: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                    
                    if let icon = icon {
                        Image(systemName: icon)
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .semibold))
                    } else {
                        Text("\(number)")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                
                Text(title)
                    .font(.headline)
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let code = code {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - Network Monitor

@MainActor
class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = false
    @Published var connectionType: String?
    @Published var isExpensive = false
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
                self?.connectionType = self?.getConnectionType(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
    
    private func getConnectionType(_ path: NWPath) -> String {
        if path.usesInterfaceType(.wifi) {
            return "WiFi"
        } else if path.usesInterfaceType(.cellular) {
            return "Cellular"
        } else if path.usesInterfaceType(.wiredEthernet) {
            return "Ethernet"
        } else {
            return "Unknown"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NetworkDiagnosticsView()
    }
}
