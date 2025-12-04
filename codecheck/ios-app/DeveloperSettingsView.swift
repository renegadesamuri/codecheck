import SwiftUI

struct DeveloperSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @AppStorage("useCustomServer") private var useCustomServer = false
    @AppStorage("customServerURL") private var customServerURL = ""
    
    @State private var tempServerURL: String = ""
    @State private var showingSaveAlert = false
    @State private var showingTestView = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Server Configuration
                Section {
                    Toggle("Use Custom Server", isOn: $useCustomServer)
                    
                    if useCustomServer {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Server URL", text: $tempServerURL)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                            
                            Text("Example: http://192.168.1.100:8000")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Save Server URL") {
                            saveServerURL()
                        }
                        .disabled(tempServerURL.isEmpty)
                    }
                } header: {
                    Text("Server Configuration")
                } footer: {
                    Text(currentServerDescription)
                }
                
                // Quick Presets
                Section("Quick Presets") {
                    Button {
                        setPreset(url: "http://localhost:8000", customEnabled: false)
                    } label: {
                        HStack {
                            Image(systemName: "laptopcomputer")
                            Text("Simulator (localhost)")
                            Spacer()
                            if !useCustomServer {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Button {
                        setPreset(url: "http://10.0.0.214:8000", customEnabled: true)
                    } label: {
                        HStack {
                            Image(systemName: "iphone")
                            Text("Physical Device (10.0.0.214)")
                            Spacer()
                            if useCustomServer && customServerURL == "http://10.0.0.214:8000" {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Button {
                        setPreset(url: "http://192.168.1.1:8000", customEnabled: true)
                    } label: {
                        HStack {
                            Image(systemName: "network")
                            Text("Local Network (192.168.1.x)")
                        }
                    }
                }
                
                // Testing
                Section {
                    NavigationLink {
                        ConnectionTestView()
                            .environmentObject(authService)
                    } label: {
                        Label("Test Connection", systemImage: "network")
                    }
                    
                    NavigationLink {
                        NetworkDiagnosticsView()
                    } label: {
                        Label("Network Diagnostics", systemImage: "antenna.radiowaves.left.and.right")
                    }
                } header: {
                    Text("Testing & Diagnostics")
                } footer: {
                    Text("Test your connection and check network status")
                }
                
                // Network Information
                Section("Current Network Info") {
                    HStack {
                        Text("Device Type")
                        Spacer()
                        #if targetEnvironment(simulator)
                        Text("Simulator")
                            .foregroundColor(.secondary)
                        #else
                        Text("Physical Device")
                            .foregroundColor(.secondary)
                        #endif
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Server URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(getCurrentServerURL())
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                }
                
                // Help
                Section {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("For Simulator:")
                                .font(.headline)
                            Text("Use 'http://localhost:8000'")
                                .font(.system(.caption, design: .monospaced))
                            
                            Divider()
                            
                            Text("For Physical Device:")
                                .font(.headline)
                            Text("1. Find your Mac's IP address:")
                                .font(.caption)
                            Text("   • System Settings → Network")
                                .font(.system(.caption, design: .monospaced))
                            Text("   • Terminal: ipconfig getifaddr en0")
                                .font(.system(.caption, design: .monospaced))
                            
                            Text("2. Use format: http://YOUR_MAC_IP:8000")
                                .font(.caption)
                            
                            Text("3. Make sure iPhone and Mac are on the same WiFi")
                                .font(.caption)
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Label("Setup Guide", systemImage: "questionmark.circle")
                    }
                }
            }
            .navigationTitle("Developer Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                tempServerURL = customServerURL
            }
            .alert("Server URL Saved", isPresented: $showingSaveAlert) {
                Button("OK") { }
            } message: {
                Text("The app will use the new server URL. You may need to log in again.")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var currentServerDescription: String {
        if useCustomServer {
            return "Currently using: \(customServerURL.isEmpty ? "Not set" : customServerURL)"
        } else {
            #if targetEnvironment(simulator)
            return "Currently using: http://localhost:8000 (default for Simulator)"
            #else
            return "Currently using: http://10.0.0.214:8000 (default for Device)"
            #endif
        }
    }
    
    private func getCurrentServerURL() -> String {
        if useCustomServer && !customServerURL.isEmpty {
            return customServerURL
        }
        #if targetEnvironment(simulator)
        return "http://localhost:8000"
        #else
        return "http://10.0.0.214:8000"
        #endif
    }
    
    private func saveServerURL() {
        customServerURL = tempServerURL
        showingSaveAlert = true
    }
    
    private func setPreset(url: String, customEnabled: Bool) {
        tempServerURL = url
        customServerURL = url
        useCustomServer = customEnabled
    }
}

#Preview {
    DeveloperSettingsView()
        .environmentObject(AuthService())
}
