import SwiftUI

/// A diagnostic view to test and troubleshoot backend connectivity
struct ConnectionTestView: View {
    @EnvironmentObject var authService: AuthService
    @State private var testResult: TestResult?
    @State private var isTesting = false
    @State private var showingDetails = false
    
    var body: some View {
        NavigationStack {
            List {
                // Current Configuration Section
                Section("Current Configuration") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Backend URL:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(getBaseURL())
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Device Type:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        #if targetEnvironment(simulator)
                        Text("iOS Simulator")
                            .foregroundColor(.blue)
                        #else
                        Text("Physical Device")
                            .foregroundColor(.green)
                        #endif
                    }
                    .padding(.vertical, 4)
                }
                
                // Test Connection Section
                Section {
                    Button {
                        Task {
                            await runConnectionTest()
                        }
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isTesting ? "Testing..." : "Test Connection")
                        }
                    }
                    .disabled(isTesting)
                } header: {
                    Text("Connection Test")
                } footer: {
                    Text("This will attempt to connect to your backend server")
                }
                
                // Results Section
                if let result = testResult {
                    Section("Test Results") {
                        HStack {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.success ? .green : .red)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.message)
                                    .font(.headline)
                                
                                if !result.details.isEmpty {
                                    Text(result.details)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(showingDetails ? nil : 2)
                                }
                            }
                            
                            Spacer()
                            
                            if !result.details.isEmpty {
                                Button {
                                    showingDetails.toggle()
                                } label: {
                                    Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Troubleshooting Tips
                Section("Troubleshooting Tips") {
                    VStack(alignment: .leading, spacing: 12) {
                        TipView(
                            icon: "1.circle.fill",
                            color: .blue,
                            title: "Check Backend Server",
                            description: "Make sure your backend server is running on the correct port"
                        )
                        
                        TipView(
                            icon: "2.circle.fill",
                            color: .purple,
                            title: "Verify IP Address",
                            description: "On physical device, ensure IP matches your Mac's address. Find it in System Settings → Network or run 'ipconfig getifaddr en0' in Terminal"
                        )
                        
                        TipView(
                            icon: "3.circle.fill",
                            color: .orange,
                            title: "Same WiFi Network",
                            description: "Your iPhone and Mac must be on the same WiFi network"
                        )
                        
                        TipView(
                            icon: "4.circle.fill",
                            color: .green,
                            title: "Check Firewall",
                            description: "Mac firewall may block incoming connections. Check System Settings → Network → Firewall"
                        )
                        
                        TipView(
                            icon: "5.circle.fill",
                            color: .red,
                            title: "App Transport Security",
                            description: "For HTTP connections, ensure Info.plist has NSAppTransportSecurity with NSAllowsLocalNetworking = YES"
                        )
                    }
                    .padding(.vertical, 4)
                }
                
                // Quick Actions
                Section("Quick Actions") {
                    Button {
                        if let url = URL(string: "App-Prefs:root=WIFI") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open WiFi Settings", systemImage: "wifi")
                    }
                    
                    Button {
                        UIPasteboard.general.string = getBaseURL()
                    } label: {
                        Label("Copy Server URL", systemImage: "doc.on.doc")
                    }
                }
            }
            .navigationTitle("Connection Test")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getBaseURL() -> String {
        let useCustomServer = UserDefaults.standard.bool(forKey: "useCustomServer")
        let customServerURL = UserDefaults.standard.string(forKey: "customServerURL")
        
        if useCustomServer, let customURL = customServerURL, !customURL.isEmpty {
            return customURL
        }
        
        #if targetEnvironment(simulator)
        return "http://localhost:8000"
        #else
        return "http://10.0.0.214:8000"
        #endif
    }
    
    private func runConnectionTest() async {
        isTesting = true
        showingDetails = false
        
        let result = await authService.testConnection()
        testResult = TestResult(
            success: result.success,
            message: result.message,
            details: result.details
        )
        
        isTesting = false
    }
}

// MARK: - Supporting Types

struct TestResult {
    let success: Bool
    let message: String
    let details: String
}

struct TipView: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ConnectionTestView()
            .environmentObject(AuthService())
    }
}
