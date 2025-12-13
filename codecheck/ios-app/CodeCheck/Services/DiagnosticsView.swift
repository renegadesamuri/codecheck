import SwiftUI

/// A diagnostic view to help troubleshoot connection issues
struct DiagnosticsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var testResults: [(String, Bool, String)] = []
    @State private var isRunning = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("This view will help you diagnose connection and authentication issues.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section("Quick Actions") {
                    Button(action: runDiagnostics) {
                        HStack {
                            if isRunning {
                                ProgressView()
                                    .padding(.trailing, 8)
                            } else {
                                Image(systemName: "stethoscope")
                                    .foregroundColor(.blue)
                            }
                            Text("Run Full Diagnostics")
                            Spacer()
                        }
                    }
                    .disabled(isRunning)
                    
                    Button(action: clearAndRetry) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.orange)
                            Text("Clear Auth & Retry")
                            Spacer()
                        }
                    }
                }
                
                if !testResults.isEmpty {
                    Section("Test Results") {
                        ForEach(testResults, id: \.0) { result in
                            HStack {
                                Image(systemName: result.1 ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.1 ? .green : .red)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.0)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text(result.2)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Section("Current Configuration") {
                    HStack {
                        Text("Authenticated")
                        Spacer()
                        Image(systemName: authService.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(authService.isAuthenticated ? .green : .red)
                    }
                    
                    if let user = authService.currentUser {
                        VStack(alignment: .leading) {
                            Text("User")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(user.email)
                                .font(.subheadline)
                        }
                    }
                    
                    HStack {
                        Text("Has Token")
                        Spacer()
                        Image(systemName: authService.getAuthToken() != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(authService.getAuthToken() != nil ? .green : .red)
                    }
                }
                
                Section("Network Information") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Base URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(getBaseURL())
                            .font(.subheadline)
                            .textSelection(.enabled)
                    }
                    
                    Button("Copy URL") {
                        UIPasteboard.general.string = getBaseURL()
                    }
                }
                
                Section("Troubleshooting Tips") {
                    VStack(alignment: .leading, spacing: 12) {
                        TipRow(
                            icon: "wifi",
                            title: "Same Network",
                            description: "Ensure iPhone and Mac are on the same WiFi"
                        )
                        
                        Divider()
                        
                        TipRow(
                            icon: "server.rack",
                            title: "Backend Running",
                            description: "Verify backend server is running on port 8000"
                        )
                        
                        Divider()
                        
                        TipRow(
                            icon: "network",
                            title: "IP Address",
                            description: "Update IP in code to match your Mac's IP"
                        )
                        
                        Divider()
                        
                        TipRow(
                            icon: "shield.slash",
                            title: "Firewall",
                            description: "Check Mac firewall isn't blocking connections"
                        )
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Diagnostic Functions
    
    private func runDiagnostics() {
        isRunning = true
        testResults.removeAll()
        
        Task {
            // Test 1: Connection to backend
            await addResult(
                "Backend Connectivity",
                test: { await testBackendConnection() }
            )
            
            // Test 2: Authentication status
            await addResult(
                "Authentication Status",
                test: { testAuthenticationStatus() }
            )
            
            // Test 3: Token validity
            await addResult(
                "Token Validity",
                test: { await testTokenValidity() }
            )
            
            // Test 4: Fetch user profile
            await addResult(
                "User Profile Fetch",
                test: { await testUserProfileFetch() }
            )
            
            // Test 5: Code lookup service
            await addResult(
                "Code Lookup Service",
                test: { await testCodeLookupService() }
            )
            
            await MainActor.run {
                isRunning = false
            }
        }
    }
    
    private func addResult(_ name: String, test: @escaping () async -> (Bool, String)) async {
        let (success, message) = await test()
        await MainActor.run {
            testResults.append((name, success, message))
        }
    }
    
    private func testBackendConnection() async -> (Bool, String) {
        let result = await authService.testConnection()
        return (result.success, result.message)
    }
    
    private func testAuthenticationStatus() -> (Bool, String) {
        if authService.isAuthenticated {
            return (true, "Authenticated as \(authService.currentUser?.email ?? "unknown")")
        } else {
            return (false, "Not authenticated")
        }
    }
    
    private func testTokenValidity() async -> (Bool, String) {
        do {
            let token = try await authService.getValidAccessToken()
            if token != nil {
                return (true, "Valid token available")
            } else {
                return (false, "No token available")
            }
        } catch {
            return (false, "Token error: \(error.localizedDescription)")
        }
    }
    
    private func testUserProfileFetch() async -> (Bool, String) {
        do {
            try await authService.fetchCurrentUser()
            return (true, "Successfully fetched user profile")
        } catch {
            return (false, "Failed: \(error.localizedDescription)")
        }
    }
    
    private func testCodeLookupService() async -> (Bool, String) {
        let service = CodeLookupService(authService: authService)
        do {
            let isHealthy = try await service.healthCheck()
            if isHealthy {
                return (true, "Code lookup service is healthy")
            } else {
                return (false, "Service not responding correctly")
            }
        } catch {
            return (false, "Error: \(error.localizedDescription)")
        }
    }
    
    private func clearAndRetry() {
        Task {
            await authService.logout()
            testResults.removeAll()
        }
    }
    
    private func getBaseURL() -> String {
        #if targetEnvironment(simulator)
        return "http://localhost:8000"
        #else
        return "http://10.0.0.214:8000"  // This should match your actual IP
        #endif
    }
}

// MARK: - Supporting Views

struct TipRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DiagnosticsView()
        .environmentObject(AuthService())
}
