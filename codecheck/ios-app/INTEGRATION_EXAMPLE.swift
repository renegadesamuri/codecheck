// MARK: - Integration Example: How to Use AuthService in CodeCheck App
// This file demonstrates how to integrate the AuthService into your existing app

import SwiftUI
import Combine

// MARK: - 1. Update App Entry Point
@main
struct CodeCheckApp: App {
    // Initialize AuthService as a StateObject
    @StateObject private var authService = AuthService(environment: .development)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService) // Pass to all views
        }
    }
}

// MARK: - 2. Root Content View with Auth State
struct ContentView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        Group {
            if authService.isAuthenticated {
                // User is logged in - show main app
                AuthenticatedMainView()
            } else {
                // User not logged in - show auth flow
                AuthenticationFlowView()
            }
        }
        .animation(.default, value: authService.isAuthenticated)
    }
}

// MARK: - 3. Authentication Flow (Login/Register)
struct AuthenticationFlowView: View {
    @State private var showRegister = false

    var body: some View {
        NavigationView {
            if showRegister {
                RegisterView(showRegister: $showRegister)
            } else {
                LoginView(showRegister: $showRegister)
            }
        }
    }
}

// MARK: - 4. Login View
struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @Binding var showRegister: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var showBiometricLogin = false

    var body: some View {
        VStack(spacing: 24) {
            // Logo
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding(.bottom, 20)

            Text("CodeCheck")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Email Field
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .padding(.horizontal)

            // Password Field
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            // Error Message
            if let error = authService.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Login Button
            Button {
                Task {
                    await authService.login(email: email, password: password)
                }
            } label: {
                if authService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Login")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .disabled(authService.isLoading || email.isEmpty || password.isEmpty)

            // Biometric Login (if available)
            if authService.canUseBiometrics() && authService.hasBiometricCredentials() {
                Button {
                    Task {
                        do {
                            try await authService.loginWithBiometrics()
                        } catch {
                            // Error is handled by authService.errorMessage
                        }
                    }
                } label: {
                    Label("Login with Face ID", systemImage: "faceid")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }

            // Register Button
            Button("Don't have an account? Register") {
                showRegister = true
            }
            .font(.footnote)
            .padding(.top)
        }
        .padding()
        .navigationTitle("Welcome Back")
        .onAppear {
            showBiometricLogin = authService.canUseBiometrics() &&
                                authService.hasBiometricCredentials()
        }
    }
}

// MARK: - 5. Register View
struct RegisterView: View {
    @EnvironmentObject var authService: AuthService
    @Binding var showRegister: Bool

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("Create Account")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Name Field
            TextField("Name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            // Email Field
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .padding(.horizontal)

            // Password Field
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            // Confirm Password Field
            SecureField("Confirm Password", text: $confirmPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            // Password Match Warning
            if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                Text("Passwords do not match")
                    .foregroundColor(.orange)
                    .font(.caption)
            }

            // Error Message
            if let error = authService.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Register Button
            Button {
                Task {
                    await authService.register(
                        email: email,
                        password: password,
                        name: name.isEmpty ? nil : name
                    )
                }
            } label: {
                if authService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create Account")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .disabled(
                authService.isLoading ||
                email.isEmpty ||
                password.isEmpty ||
                confirmPassword.isEmpty ||
                password != confirmPassword
            )

            // Back to Login
            Button("Already have an account? Login") {
                showRegister = false
            }
            .font(.footnote)
            .padding(.top)
        }
        .padding()
        .navigationTitle("Register")
    }
}

// MARK: - 6. Main Authenticated View
struct AuthenticatedMainView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        TabView {
            HomeTab()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            ProjectsTab()
                .tabItem {
                    Label("Projects", systemImage: "folder.fill")
                }

            ProfileTab()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
    }
}

// MARK: - 7. Profile Tab with User Info and Logout
struct ProfileTab: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingLogoutAlert = false

    var body: some View {
        NavigationView {
            List {
                // User Info Section
                Section("User Information") {
                    if let user = authService.currentUser {
                        HStack {
                            Text("Name")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(user.name ?? "Not set")
                        }

                        HStack {
                            Text("Email")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(user.email)
                        }

                        if let createdAt = user.createdAt {
                            HStack {
                                Text("Member Since")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(createdAt, style: .date)
                            }
                        }
                    }
                }

                // Security Section
                Section("Security") {
                    if authService.canUseBiometrics() {
                        Toggle("Face ID Login", isOn: .constant(authService.hasBiometricCredentials()))
                            .disabled(true)
                    }
                }

                // Actions Section
                Section {
                    Button(role: .destructive) {
                        showingLogoutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Logout")
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .alert("Logout", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    Task {
                        await authService.logout()
                    }
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
        }
    }
}

// MARK: - 8. Example: Making Authenticated API Requests
struct HomeTab: View {
    @EnvironmentObject var authService: AuthService
    @State private var projects: [Project] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading projects...")
                } else if let error = error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await loadProjects() }
                        }
                    }
                    .padding()
                } else {
                    List(projects) { project in
                        VStack(alignment: .leading) {
                            Text(project.name)
                                .font(.headline)
                            Text(project.location)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .task {
                await loadProjects()
            }
        }
    }

    private func loadProjects() async {
        isLoading = true
        error = nil

        do {
            // Make authenticated request
            let data = try await authService.makeAuthenticatedRequest(
                to: "/api/projects",
                method: "GET"
            )

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            projects = try decoder.decode([Project].self, from: data)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - 9. Update CodeLookupService to Use Auth
class AuthenticatedCodeLookupService {
    private let authService: AuthService
    private let baseURL: String

    init(authService: AuthService, baseURL: String = "http://localhost:8000") {
        self.authService = authService
        self.baseURL = baseURL
    }

    func checkCompliance(jurisdictionId: String, metrics: [String: Double]) async throws -> ComplianceResponse {
        let complianceRequest = ComplianceRequest(
            jurisdictionId: jurisdictionId,
            metrics: metrics
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(complianceRequest)

        // Use authenticated request
        let data = try await authService.makeAuthenticatedRequest(
            to: "/check",
            method: "POST",
            body: body
        )

        let decoder = JSONDecoder()
        return try decoder.decode(ComplianceResponse.self, from: data)
    }
}

// MARK: - 10. Usage in a ViewModel
class ProjectViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var isLoading = false
    @Published var error: String?

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    func loadProjects() async {
        isLoading = true
        error = nil

        do {
            let data = try await authService.makeAuthenticatedRequest(
                to: "/api/projects",
                method: "GET"
            )

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            projects = try decoder.decode([Project].self, from: data)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func createProject(_ project: Project) async {
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let body = try encoder.encode(project)

            _ = try await authService.makeAuthenticatedRequest(
                to: "/api/projects",
                method: "POST",
                body: body
            )

            await loadProjects() // Reload after creation
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Placeholder Tabs
struct ProjectsTab: View {
    var body: some View {
        NavigationView {
            Text("Projects View")
                .navigationTitle("Projects")
        }
    }
}
