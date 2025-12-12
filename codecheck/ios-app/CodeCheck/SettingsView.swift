import SwiftUI

struct SettingsView: View {
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("enableBiometrics") private var enableBiometrics = false
    @AppStorage("selectedTheme") private var selectedTheme = "System"
    @AppStorage("autoSyncProjects") private var autoSyncProjects = true
    
    var body: some View {
        List {
            // Notifications Section
            Section {
                Toggle("Enable Notifications", isOn: $enableNotifications)
            } header: {
                Text("Notifications")
            } footer: {
                Text("Receive push notifications for code reviews and project updates")
            }
            
            // Security Section
            Section {
                Toggle("Use Face ID / Touch ID", isOn: $enableBiometrics)
            } header: {
                Text("Security")
            } footer: {
                Text("Use biometric authentication to unlock the app")
            }
            
            // Appearance Section
            Section("Appearance") {
                Picker("Theme", selection: $selectedTheme) {
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                    Text("System").tag("System")
                }
            }
            
            // Sync Section
            Section {
                Toggle("Auto-sync Projects", isOn: $autoSyncProjects)
            } header: {
                Text("Sync")
            } footer: {
                Text("Automatically sync projects when changes are detected")
            }
            
            // Data & Storage Section
            Section("Data & Storage") {
                Button(action: {
                    // Clear cache action
                }) {
                    HStack {
                        Text("Clear Cache")
                        Spacer()
                        Text("0 MB")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
