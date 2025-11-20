import Foundation
import LocalAuthentication
import Combine

@MainActor
class AuthService: ObservableObject {
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private Properties
    private let baseURL: String
    private let session: URLSession
    private let keychain: KeychainWrapper
    private var tokenRefreshTask: Task<Void, Never>?
    private var tokenExpirationDate: Date?

    // Token storage keys
    private let accessTokenKey = "com.codecheck.accessToken"
    private let refreshTokenKey = "com.codecheck.refreshToken"
    private let tokenExpirationKey = "com.codecheck.tokenExpiration"

    // MARK: - Initialization
    init(environment: Environment = .development) {
        self.baseURL = environment.baseURL

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)

        self.keychain = KeychainWrapper()

        // Check for existing authentication on init
        Task {
            await checkAuthStatus()
        }
    }

    // MARK: - Authentication Status

    func checkAuthStatus() async {
        // Check if we have tokens stored
        guard let accessToken = keychain.get(accessTokenKey),
              let refreshToken = keychain.get(refreshTokenKey) else {
            return
        }

        // Check token expiration
        if let expirationString = keychain.get(tokenExpirationKey),
           let expirationTimestamp = Double(expirationString) {
            let expirationDate = Date(timeIntervalSince1970: expirationTimestamp)
            self.tokenExpirationDate = expirationDate

            // If token expired, try to refresh
            if expirationDate < Date() {
                do {
                    try await refreshAccessToken(using: refreshToken)
                } catch {
                    await logout()
                    return
                }
            }
        }

        // Try to fetch current user
        do {
            try await fetchCurrentUser()
            self.isAuthenticated = true
            scheduleTokenRefresh()
        } catch {
            await logout()
        }
    }

    // MARK: - Login

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let endpoint = "\(baseURL)/auth/login"

            guard let url = URL(string: endpoint) else {
                throw AuthenticationError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let loginRequest = LoginRequest(email: email, password: password)
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(loginRequest)

            let (data, response) = try await session.data(for: request)
            try handleAuthResponse(data: data, response: response)

            isLoading = false
        } catch let error as AuthenticationError {
            errorMessage = error.errorDescription
            isLoading = false
        } catch {
            errorMessage = AuthenticationError.networkError(error).errorDescription
            isLoading = false
        }
    }

    // MARK: - Register

    func register(email: String, password: String, name: String? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            let endpoint = "\(baseURL)/auth/register"

            guard let url = URL(string: endpoint) else {
                throw AuthenticationError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let registerRequest = RegisterRequest(email: email, password: password, name: name)
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(registerRequest)

            let (data, response) = try await session.data(for: request)
            try handleAuthResponse(data: data, response: response)

            isLoading = false
        } catch let error as AuthenticationError {
            errorMessage = error.errorDescription
            isLoading = false
        } catch {
            errorMessage = AuthenticationError.networkError(error).errorDescription
            isLoading = false
        }
    }

    // MARK: - Logout

    func logout() async {
        // Cancel any pending token refresh
        tokenRefreshTask?.cancel()
        tokenRefreshTask = nil

        // Clear tokens from keychain
        keychain.delete(accessTokenKey)
        keychain.delete(refreshTokenKey)
        keychain.delete(tokenExpirationKey)

        // Clear user state
        self.currentUser = nil
        self.isAuthenticated = false
        self.tokenExpirationDate = nil
        self.errorMessage = nil
    }

    // MARK: - Biometric Authentication

    func loginWithBiometrics() async throws {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw AuthenticationError.biometricsNotAvailable
        }

        // Check if we have stored credentials
        guard let refreshToken = keychain.get(refreshTokenKey) else {
            throw AuthenticationError.noBiometricCredentials
        }

        let reason = "Authenticate to access CodeCheck"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if success {
                try await refreshAccessToken(using: refreshToken)
            } else {
                throw AuthenticationError.biometricsFailed
            }
        } catch {
            throw AuthenticationError.biometricsFailed
        }
    }

    func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func hasBiometricCredentials() -> Bool {
        return keychain.get(refreshTokenKey) != nil
    }

    // MARK: - User Profile

    func fetchCurrentUser() async throws {
        let endpoint = "\(baseURL)/auth/me"

        guard let url = URL(string: endpoint) else {
            throw AuthenticationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add authorization header
        guard let token = try await getValidAccessToken() else {
            throw AuthenticationError.notAuthenticated
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            let user = try decoder.decode(User.self, from: data)
            self.currentUser = user

        case 401:
            // Token invalid, try to refresh
            try await refreshAccessToken()
            try await fetchCurrentUser() // Retry after refresh

        default:
            throw AuthenticationError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Token Management

    /// Get a valid access token (refreshes if needed)
    func getValidAccessToken() async throws -> String? {
        // Check if we have a token
        guard let token = keychain.get(accessTokenKey) else {
            return nil
        }

        // Check if token is expired or will expire soon (within 5 minutes)
        if let expirationDate = tokenExpirationDate,
           expirationDate.timeIntervalSinceNow < 300 {
            // Token expired or expiring soon, refresh it
            try await refreshAccessToken()
            return keychain.get(accessTokenKey)
        }

        return token
    }

    /// Get the access token without validation (for quick checks)
    func getAuthToken() -> String? {
        return keychain.get(accessTokenKey)
    }

    /// Refresh the access token using the refresh token
    private func refreshAccessToken(using refreshToken: String? = nil) async throws {
        let endpoint = "\(baseURL)/auth/refresh"

        guard let url = URL(string: endpoint) else {
            throw AuthenticationError.invalidURL
        }

        let tokenToUse = refreshToken ?? keychain.get(refreshTokenKey)

        guard let validRefreshToken = tokenToUse else {
            throw AuthenticationError.refreshTokenMissing
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let refreshRequest = RefreshTokenRequest(refreshToken: validRefreshToken)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(refreshRequest)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            try handleAuthResponse(data: data, response: response)

        case 401:
            // Refresh token invalid, logout
            await logout()
            throw AuthenticationError.refreshTokenInvalid

        default:
            throw AuthenticationError.serverError(httpResponse.statusCode)
        }
    }

    /// Schedule automatic token refresh before expiration
    private func scheduleTokenRefresh() {
        // Cancel existing task
        tokenRefreshTask?.cancel()

        guard let expirationDate = tokenExpirationDate else { return }

        // Schedule refresh 5 minutes before expiration
        let refreshDate = expirationDate.addingTimeInterval(-300)
        let delay = refreshDate.timeIntervalSinceNow

        guard delay > 0 else {
            // Token already needs refresh
            tokenRefreshTask = Task {
                try? await refreshAccessToken()
            }
            return
        }

        tokenRefreshTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            if !Task.isCancelled {
                try? await refreshAccessToken()
            }
        }
    }

    // MARK: - Authenticated Requests

    /// Make an authenticated API request
    func makeAuthenticatedRequest(to endpoint: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw AuthenticationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authorization header
        guard let token = try await getValidAccessToken() else {
            throw AuthenticationError.notAuthenticated
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let body = body {
            request.httpBody = body
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data

        case 401:
            // Token might be invalid, try to refresh and retry once
            try await refreshAccessToken()

            // Retry request with new token
            guard let newToken = try await getValidAccessToken() else {
                throw AuthenticationError.notAuthenticated
            }
            request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")

            let (retryData, retryResponse) = try await session.data(for: request)

            guard let retryHttpResponse = retryResponse as? HTTPURLResponse,
                  (200...299).contains(retryHttpResponse.statusCode) else {
                throw AuthenticationError.invalidResponse
            }

            return retryData

        default:
            throw AuthenticationError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Private Helper Methods

    /// Handle successful authentication response
    private func handleAuthResponse(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601

            let authResponse = try decoder.decode(AuthResponse.self, from: data)

            // Store tokens securely
            keychain.set(authResponse.accessToken, forKey: accessTokenKey)
            keychain.set(authResponse.refreshToken, forKey: refreshTokenKey)

            // Calculate and store expiration date
            let expirationDate = Date().addingTimeInterval(TimeInterval(authResponse.expiresIn))
            self.tokenExpirationDate = expirationDate
            keychain.set(String(expirationDate.timeIntervalSince1970), forKey: tokenExpirationKey)

            // Update user state
            self.currentUser = authResponse.user
            self.isAuthenticated = true
            self.errorMessage = nil

            // Schedule token refresh
            scheduleTokenRefresh()

        case 400:
            // Try to decode error message
            if let errorResponse = try? JSONDecoder().decode(AuthError.self, from: data) {
                throw AuthenticationError.badRequest(errorResponse.detail)
            } else {
                throw AuthenticationError.badRequest("Invalid request")
            }

        case 401:
            if let errorResponse = try? JSONDecoder().decode(AuthError.self, from: data) {
                throw AuthenticationError.invalidCredentials(errorResponse.detail)
            } else {
                throw AuthenticationError.invalidCredentials("Invalid credentials")
            }

        case 409:
            if let errorResponse = try? JSONDecoder().decode(AuthError.self, from: data) {
                throw AuthenticationError.userAlreadyExists(errorResponse.detail)
            } else {
                throw AuthenticationError.userAlreadyExists("User already exists")
            }

        case 500...599:
            throw AuthenticationError.serverError(httpResponse.statusCode)

        default:
            throw AuthenticationError.unknownError
        }
    }
}

// MARK: - Environment Configuration
extension AuthService {
    enum Environment {
        case development
        case production
        case custom(String)

        var baseURL: String {
            switch self {
            case .development:
                // For iOS Simulator, localhost works
                // For physical device, use your Mac's IP address
                return "http://localhost:8000"
            case .production:
                return "https://api.codecheck.app" // Replace with your production URL
            case .custom(let url):
                return url
            }
        }
    }
}

// MARK: - Authentication Errors
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

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidCredentials(let message):
            return message
        case .userAlreadyExists(let message):
            return message
        case .badRequest(let message):
            return message
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .notAuthenticated:
            return "You are not authenticated. Please log in."
        case .refreshTokenMissing:
            return "Session expired. Please log in again."
        case .refreshTokenInvalid:
            return "Session expired. Please log in again."
        case .biometricsNotAvailable:
            return "Biometric authentication is not available on this device"
        case .biometricsFailed:
            return "Biometric authentication failed"
        case .noBiometricCredentials:
            return "No saved credentials for biometric login"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}

// MARK: - Keychain Wrapper
class KeychainWrapper {
    private let serviceName = "com.codecheck.app"

    /// Save a value to the keychain
    func set(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing item if present
        delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            print("Keychain Error: Failed to save \(key) - Status: \(status)")
        }
    }

    /// Retrieve a value from the keychain
    func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    /// Delete a value from the keychain
    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    /// Clear all keychain items for this service
    func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        SecItemDelete(query as CFDictionary)
    }
}
