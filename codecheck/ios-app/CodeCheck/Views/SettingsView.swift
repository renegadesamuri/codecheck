import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @AppStorage("useCustomServer") private var useCustomServer = false
    @AppStorage("customServerURL") private var customServerURL = ""
    @AppStorage("enableHaptics") private var enableHaptics = true
    @AppStorage("autoSaveProjects") private var autoSaveProjects = true
    @AppStorage("developerMode") private var developerMode = false
    @State private var showingServerAlert = false
    @State private var tempServerURL = ""

    var body: some View {
        Form {
            // Server Configuration
            Section {
                Toggle("Use Custom Server", isOn: $useCustomServer)

                if useCustomServer {
                    HStack {
                        TextField("Server URL", text: $tempServerURL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()

                        Button("Save") {
                            customServerURL = tempServerURL
                            showingServerAlert = true
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(tempServerURL.isEmpty)
                    }

                    Text("Current: \(customServerURL.isEmpty ? "Not set" : customServerURL)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Server")
            } footer: {
                Text("Configure a custom API server for testing or production use. Restart required.")
            }

            // App Preferences
            Section("Preferences") {
                Toggle("Haptic Feedback", isOn: $enableHaptics)
                Toggle("Auto-Save Projects", isOn: $autoSaveProjects)
            }

            // Developer Options
            Section {
                Toggle("Developer Mode", isOn: $developerMode)

                if developerMode {
                    NavigationLink {
                        NetworkDiagnosticsView()
                    } label: {
                        Label("Network Diagnostics", systemImage: "network")
                    }

                    NavigationLink {
                        ConnectionTestView()
                    } label: {
                        Label("Connection Test", systemImage: "antenna.radiowaves.left.and.right")
                    }

                    Button(role: .destructive) {
                        clearCache()
                    } label: {
                        Label("Clear Cache", systemImage: "trash")
                    }
                }
            } header: {
                Text("Developer")
            } footer: {
                if developerMode {
                    Text("Advanced options for debugging and testing")
                }
            }

            // About
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Build")
                    Spacer()
                    Text("2025.12.04")
                        .foregroundColor(.secondary)
                }

                Link(destination: URL(string: "https://github.com/yourusername/codecheck")!) {
                    HStack {
                        Label("GitHub Repository", systemImage: "link")
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                    }
                }

                Link(destination: URL(string: "https://docs.getcodecheck.com")!) {
                    HStack {
                        Label("Documentation", systemImage: "book")
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                    }
                }
            }

            // Legal
            Section("Legal") {
                NavigationLink {
                    Text("Privacy Policy Content")
                        .navigationTitle("Privacy Policy")
                } label: {
                    Text("Privacy Policy")
                }

                NavigationLink {
                    Text("Terms of Service Content")
                        .navigationTitle("Terms of Service")
                } label: {
                    Text("Terms of Service")
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            tempServerURL = customServerURL
        }
        .alert("Server Updated", isPresented: $showingServerAlert) {
            Button("OK") { }
        } message: {
            Text("Custom server URL has been saved. Please restart the app for changes to take effect.")
        }
    }

    private func clearCache() {
        // Clear UserDefaults cache (except authentication)
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()

        // Restore settings
        useCustomServer = false
        customServerURL = ""
        enableHaptics = true
        autoSaveProjects = true
        developerMode = true
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthService())
    }
}
