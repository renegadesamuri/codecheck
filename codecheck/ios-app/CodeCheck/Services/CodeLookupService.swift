import Foundation
import CoreLocation

class CodeLookupService {
    private let baseURL: String
    private let authService: AuthService?

    /// Retry configuration for network requests
    private let retryConfig = RetryHandler.Configuration.default

    init(authService: AuthService? = nil) {
        // Use the same base URL configuration as AuthService
        let useCustomServer = UserDefaults.standard.bool(forKey: "useCustomServer")
        let customServerURL = UserDefaults.standard.string(forKey: "customServerURL")

        if useCustomServer, let customURL = customServerURL, !customURL.isEmpty {
            self.baseURL = customURL
        } else {
            // Match the AuthService environment settings
            #if targetEnvironment(simulator)
            self.baseURL = "http://localhost:8000"
            #else
            // For physical device - IMPORTANT: Update this with your Mac's IP address
            self.baseURL = "http://10.0.0.214:8000"  // Changed from port 8001 to 8000
            #endif
        }

        self.authService = authService
    }

    // MARK: - Network Execution with Deduplication and Retry

    /// Execute a network request with deduplication and automatic retry
    /// - Parameters:
    ///   - request: The URLRequest to execute
    ///   - useRetry: Whether to use retry logic (default: true)
    ///   - useDedup: Whether to use request deduplication (default: true)
    /// - Returns: The response data and HTTP response
    private func executeRequest(
        _ request: URLRequest,
        useRetry: Bool = true,
        useDedup: Bool = true
    ) async throws -> (Data, HTTPURLResponse) {
        if useRetry && useDedup {
            // Use both deduplication and retry
            return try await RetryHandler.execute(with: retryConfig) {
                let data = try await RequestDeduplicator.shared.execute(
                    request: request,
                    using: NetworkManager.shared.session
                )
                // Create synthetic response for deduplicated requests
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (data, response)
            }
        } else if useRetry {
            // Retry only
            return try await RetryHandler.executeRequest(
                request,
                using: NetworkManager.shared.session,
                config: retryConfig
            )
        } else if useDedup {
            // Deduplication only
            let data = try await RequestDeduplicator.shared.execute(
                request: request,
                using: NetworkManager.shared.session
            )
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response)
        } else {
            // Neither - standard request
            let (data, response) = try await NetworkManager.shared.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            return (data, httpResponse)
        }
    }

    // MARK: - Authentication
    private func addAuthHeader(to request: inout URLRequest) async throws {
        // Try to get token from AuthService first
        if let authService = authService {
            guard let token = try await authService.getValidAccessToken() else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            // Fallback to checking UserDefaults (for backward compatibility)
            guard let token = UserDefaults.standard.string(forKey: "auth_token") else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    // MARK: - Jurisdiction Resolution
    func resolveJurisdiction(latitude: Double, longitude: Double) async throws -> [Jurisdiction] {
        let endpoint = "\(baseURL)/resolve"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)

        let body: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Check cache first - can save 60% of network requests
        if let cachedData = NetworkCache.shared.get(for: request) {
            let decoder = JSONDecoder()
            let result = try decoder.decode(JurisdictionResponse.self, from: cachedData)
            return result.jurisdictions
        }

        // Cache miss - fetch with deduplication and retry
        let (data, httpResponse) = try await executeRequest(request)

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        // Cache successful response
        NetworkCache.shared.set(data, for: request)

        let decoder = JSONDecoder()
        let result = try decoder.decode(JurisdictionResponse.self, from: data)
        return result.jurisdictions
    }

    // MARK: - Compliance Checking
    func checkCompliance(jurisdictionId: String, metrics: [String: Double]) async throws -> ComplianceResponse {
        let endpoint = "\(baseURL)/check"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)

        let complianceRequest = ComplianceRequest(
            jurisdictionId: jurisdictionId,
            metrics: metrics
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(complianceRequest)

        // Check cache first - compliance checks can be cached for 5 minutes
        if let cachedData = NetworkCache.shared.get(for: request) {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(ComplianceResponse.self, from: cachedData)
        }

        // Cache miss - fetch with deduplication and retry
        let (data, httpResponse) = try await executeRequest(request)

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        // Cache successful response
        NetworkCache.shared.set(data, for: request)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ComplianceResponse.self, from: data)
    }

    // MARK: - Rule Explanation
    func explainRule(ruleId: String, measurementValue: Double? = nil) async throws -> ExplainResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/explain")!
        urlComponents.queryItems = [
            URLQueryItem(name: "rule_id", value: ruleId)
        ]
        if let value = measurementValue {
            urlComponents.queryItems?.append(URLQueryItem(name: "measurement_value", value: String(value)))
        }

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)

        // Rule explanations use retry but not deduplication (unique content)
        let (data, httpResponse) = try await executeRequest(request, useDedup: false)

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ExplainResponse.self, from: data)
    }

    // MARK: - AI Conversation
    func sendConversation(message: String, projectType: String? = nil, location: String? = nil) async throws -> ConversationResponse {
        let endpoint = "\(baseURL)/conversation"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)

        let conversationRequest = ConversationRequest(
            message: message,
            projectType: projectType,
            location: location
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(conversationRequest)

        // Conversations use retry but not deduplication (unique responses expected)
        let (data, httpResponse) = try await executeRequest(request, useDedup: false)

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ConversationResponse.self, from: data)
    }

    // MARK: - Health Check
    func healthCheck() async throws -> Bool {
        let endpoint = "\(baseURL)/"

        let request = URLRequest(url: URL(string: endpoint)!)

        // Health checks use retry with conservative config
        do {
            let (_, httpResponse) = try await executeRequest(
                request,
                useRetry: true,
                useDedup: true
            )
            return (200...299).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }

    // MARK: - On-Demand Code Loading
    func checkJurisdictionStatus(jurisdictionId: String) async throws -> JurisdictionStatus {
        guard let url = URL(string: "\(baseURL)/jurisdictions/\(jurisdictionId)/status") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)

        // Check cache first - status checks cached for 1 minute
        if let cachedData = NetworkCache.shared.get(for: request) {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(JurisdictionStatus.self, from: cachedData)
        }

        // Cache miss - fetch with deduplication and retry
        let (data, httpResponse) = try await executeRequest(request)

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        // Cache successful response
        NetworkCache.shared.set(data, for: request)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(JurisdictionStatus.self, from: data)
    }

    func triggerCodeLoading(jurisdictionId: String) async throws -> CodeLoadingResponse {
        guard let url = URL(string: "\(baseURL)/jurisdictions/\(jurisdictionId)/load-codes") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)

        // Code loading triggers use retry but not deduplication (side effects)
        let (data, httpResponse) = try await executeRequest(request, useDedup: false)

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(CodeLoadingResponse.self, from: data)
    }

    func getJobProgress(jobId: String) async throws -> JobProgress {
        guard let url = URL(string: "\(baseURL)/jobs/\(jobId)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeader(to: &request)

        // Job progress uses both deduplication and retry
        let (data, httpResponse) = try await executeRequest(request)

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(JobProgress.self, from: data)
    }
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    case networkError(Error)
    case unauthorized
    case noJurisdictionFound
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Authentication required. Please log in."
        case .noJurisdictionFound:
            return "No jurisdiction found for your location"
        case .timeout:
            return "Code loading timed out. Please try again."
        }
    }
}
