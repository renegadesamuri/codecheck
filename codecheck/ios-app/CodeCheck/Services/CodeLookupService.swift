import Foundation
import CoreLocation

class CodeLookupService {
    private let baseURL: String
    private let session: URLSession
    private let authService: AuthService?

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
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60  // Increased to allow slower backend responses
        configuration.timeoutIntervalForResource = 120 // Increased for large resource operations
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)
        self.authService = authService
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

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

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

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

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

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

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

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

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
        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return false
        }

        return true
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

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

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

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

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

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

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
