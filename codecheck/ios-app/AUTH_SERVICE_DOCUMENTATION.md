# AuthService Documentation

## Overview

The `AuthService` is a comprehensive iOS authentication service for the CodeCheck app that provides secure user authentication, token management, and biometric login support.

## Features

### 1. User Authentication
- User registration with email/password
- User login with email/password
- Automatic session persistence
- User logout

### 2. Secure Token Management
- JWT access and refresh tokens stored in iOS Keychain (secure)
- Automatic token refresh before expiration
- Thread-safe token access
- Token expiration tracking

### 3. Biometric Authentication
- Face ID / Touch ID support
- Secure credential storage for biometric login
- Automatic fallback if biometrics unavailable

### 4. API Integration
- Connects to backend auth endpoints:
  - `POST /auth/register` - User registration
  - `POST /auth/login` - User login
  - `POST /auth/refresh` - Token refresh
  - `GET /auth/me` - Fetch current user

### 5. Security Features
- Keychain wrapper for secure token storage
- HTTPS-only communication
- Automatic retry with token refresh on 401 errors
- Certificate pinning ready (can be added)

### 6. Error Handling
- Comprehensive error types with user-friendly messages
- Network error detection and retry logic
- Token expiration handling
- Server error handling

## Installation

The service is already integrated into your CodeCheck app. No additional dependencies required.

## Configuration

### Environment Setup

The service supports multiple environments:

```swift
// Development (localhost)
let authService = AuthService(environment: .development)

// Production
let authService = AuthService(environment: .production)

// Custom URL
let authService = AuthService(environment: .custom("https://staging.codecheck.app"))
```

### Environment URLs

- **Development**: `http://localhost:8000`
  - For iOS Simulator, localhost works
  - For physical device, replace with your Mac's IP address

- **Production**: `https://api.codecheck.app` (update with your production URL)

## Usage Examples

### 1. Initialize the Service

```swift
import SwiftUI

@main
struct CodeCheckApp: App {
    @StateObject private var authService = AuthService(environment: .development)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}
```

### 2. User Registration

```swift
struct RegisterView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""

    var body: some View {
        VStack(spacing: 20) {
            TextField("Name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(.emailAddress)

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button("Register") {
                Task {
                    await authService.register(
                        email: email,
                        password: password,
                        name: name
                    )
                }
            }
            .disabled(authService.isLoading)

            if let error = authService.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
    }
}
```

### 3. User Login

```swift
struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 20) {
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(.emailAddress)

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button("Login") {
                Task {
                    await authService.login(email: email, password: password)
                }
            }
            .disabled(authService.isLoading)

            if authService.canUseBiometrics() && authService.hasBiometricCredentials() {
                Button("Login with Face ID") {
                    Task {
                        do {
                            try await authService.loginWithBiometrics()
                        } catch {
                            print("Biometric login failed: \(error.localizedDescription)")
                        }
                    }
                }
            }

            if let error = authService.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
    }
}
```

### 4. Biometric Authentication

```swift
// Check if biometrics are available
if authService.canUseBiometrics() {
    // Check if user has saved credentials
    if authService.hasBiometricCredentials() {
        // Login with biometrics
        Task {
            do {
                try await authService.loginWithBiometrics()
                print("Biometric login successful!")
            } catch {
                print("Biometric login failed: \(error.localizedDescription)")
            }
        }
    }
}
```

### 5. Observe Authentication State

```swift
struct ContentView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        Group {
            if authService.isAuthenticated {
                // Show main app interface
                MainTabView()
            } else {
                // Show login/register interface
                LoginView()
            }
        }
    }
}
```

### 6. Display Current User

```swift
struct ProfileView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        VStack(spacing: 20) {
            if let user = authService.currentUser {
                Text("Welcome, \(user.name ?? "User")!")
                    .font(.title)

                Text("Email: \(user.email)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button("Logout") {
                    Task {
                        await authService.logout()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
```

### 7. Make Authenticated API Requests

```swift
// Make an authenticated request to any endpoint
Task {
    do {
        let data = try await authService.makeAuthenticatedRequest(
            to: "/api/projects",
            method: "GET"
        )

        let decoder = JSONDecoder()
        let projects = try decoder.decode([Project].self, from: data)
        print("Projects: \(projects)")
    } catch {
        print("Request failed: \(error.localizedDescription)")
    }
}
```

### 8. Update Other Services to Use Auth Token

Update your existing services to use the auth token:

```swift
class CodeLookupService {
    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    func checkCompliance(jurisdictionId: String, metrics: [String: Double]) async throws -> ComplianceResponse {
        let endpoint = "/check"

        // Create request body
        let complianceRequest = ComplianceRequest(
            jurisdictionId: jurisdictionId,
            metrics: metrics
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(complianceRequest)

        // Use authenticated request
        let data = try await authService.makeAuthenticatedRequest(
            to: endpoint,
            method: "POST",
            body: body
        )

        let decoder = JSONDecoder()
        return try decoder.decode(ComplianceResponse.self, from: data)
    }
}
```

### 9. Handle Logout

```swift
Button("Logout") {
    Task {
        await authService.logout()
    }
}
```

## Published Properties

The service publishes the following properties that you can observe:

```swift
@Published var isAuthenticated: Bool      // User authentication status
@Published var currentUser: User?         // Current logged-in user
@Published var isLoading: Bool            // Loading state for API calls
@Published var errorMessage: String?      // Last error message
```

## Public Methods

### Authentication Methods

```swift
// Register a new user
func register(email: String, password: String, name: String? = nil) async

// Login with credentials
func login(email: String, password: String) async

// Logout current user
func logout() async

// Login with biometrics (Face ID / Touch ID)
func loginWithBiometrics() async throws

// Check authentication status
func checkAuthStatus() async

// Fetch current user from server
func fetchCurrentUser() async throws
```

### Biometric Support

```swift
// Check if biometrics are available on device
func canUseBiometrics() -> Bool

// Check if user has saved credentials for biometric login
func hasBiometricCredentials() -> Bool
```

### Token Management

```swift
// Get a valid access token (auto-refreshes if needed)
func getValidAccessToken() async throws -> String?

// Get access token without validation
func getAuthToken() -> String?
```

### Authenticated Requests

```swift
// Make an authenticated API request
func makeAuthenticatedRequest(
    to endpoint: String,
    method: String = "GET",
    body: Data? = nil
) async throws -> Data
```

## Error Handling

The service defines comprehensive error types:

```swift
enum AuthenticationError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidCredentials(String)
    case userAlreadyExists(String)
    case badRequest(String)
    case networkError(Error)
    case serverError(Int)
    case notAuthenticated
    case refreshTokenMissing
    case refreshTokenInvalid
    case biometricsNotAvailable
    case biometricsFailed
    case noBiometricCredentials
    case unknownError
}
```

### Example Error Handling

```swift
Task {
    await authService.login(email: email, password: password)

    if let error = authService.errorMessage {
        // Display error to user
        showAlert(message: error)
    }
}
```

## Security Considerations

### 1. Keychain Storage
- All tokens are stored in iOS Keychain, not UserDefaults
- Keychain items are encrypted by the system
- Accessibility set to `kSecAttrAccessibleAfterFirstUnlock`

### 2. Token Management
- Access tokens auto-refresh 5 minutes before expiration
- Refresh tokens stored securely in Keychain
- Tokens cleared on logout

### 3. HTTPS Communication
- All API requests use HTTPS in production
- Development allows HTTP for localhost testing

### 4. Biometric Security
- Biometric authentication requires device passcode/password
- Refresh token only accessible after biometric verification

### 5. Thread Safety
- `@MainActor` ensures all UI updates happen on main thread
- Token refresh operations are synchronized

## Backend Requirements

Your backend should implement these endpoints:

### POST /auth/register
```json
Request:
{
  "email": "user@example.com",
  "password": "securePassword123",
  "name": "John Doe"
}

Response:
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "token_type": "bearer",
  "expires_in": 3600,
  "user": {
    "id": "user-uuid",
    "email": "user@example.com",
    "name": "John Doe",
    "created_at": "2025-01-19T12:00:00Z",
    "email_verified": false
  }
}
```

### POST /auth/login
```json
Request:
{
  "email": "user@example.com",
  "password": "securePassword123"
}

Response: (same as register)
```

### POST /auth/refresh
```json
Request:
{
  "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}

Response: (same as register)
```

### GET /auth/me
```json
Request Headers:
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc...

Response:
{
  "id": "user-uuid",
  "email": "user@example.com",
  "name": "John Doe",
  "created_at": "2025-01-19T12:00:00Z",
  "email_verified": false
}
```

## Troubleshooting

### Issue: Tokens not persisting after app restart
**Solution**: Ensure Keychain entitlements are enabled in your Xcode project.

### Issue: Cannot connect to localhost on physical device
**Solution**:
1. Use your Mac's IP address instead of localhost
2. Update the development URL: `http://192.168.1.XXX:8000`
3. Ensure your device and Mac are on the same network

### Issue: Biometric authentication not working
**Solution**:
1. Check that Face ID/Touch ID is enabled in Settings
2. Verify that user has logged in at least once (biometric needs saved credentials)
3. Ensure proper Info.plist entries for biometric usage

### Issue: Token refresh fails
**Solution**:
1. Check that backend refresh endpoint is working
2. Verify refresh token hasn't expired on backend
3. Check network connectivity

## Best Practices

1. **Always use EnvironmentObject**: Pass `AuthService` through the SwiftUI environment
2. **Handle errors gracefully**: Display user-friendly error messages
3. **Check authentication state**: Use `isAuthenticated` to show/hide UI
4. **Use async/await**: All auth methods are async - use Task blocks
5. **Logout on critical errors**: If token refresh fails, logout user
6. **Test on physical device**: Test biometrics on real device, not simulator

## Future Enhancements

- [ ] Certificate pinning for production
- [ ] Social login (Google, Apple Sign In)
- [ ] Two-factor authentication (2FA)
- [ ] Password reset flow
- [ ] Email verification flow
- [ ] Session management across multiple devices
- [ ] Offline authentication support

## Support

For issues or questions, refer to:
- Backend API documentation
- iOS Keychain Services documentation
- Local Authentication framework documentation
