import Foundation
import CoreLocation

class CodeLookupService {
    // Configure this to match your API server
    // For local development: use your Mac's IP address (e.g., "http://192.168.1.100:8000")
    // For production: use your server's URL
    private let baseURL = "http://localhost:8000"

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Jurisdiction Resolution
    func resolveJurisdiction(latitude: Double, longitude: Double) async throws -> [Jurisdiction] {
        let endpoint = "\(baseURL)/resolve"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
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

        let complianceRequest = ComplianceRequest(
            jurisdictionId: jurisdictionId,
            metrics: metrics
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(complianceRequest)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ComplianceResponse.self, from: data)
    }

    // MARK: - AI Conversation
    func sendConversation(message: String, projectType: String? = nil, location: String? = nil) async throws -> ConversationResponse {
        let endpoint = "\(baseURL)/conversation"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let conversationRequest = ConversationRequest(
            message: message,
            projectType: projectType,
            location: location
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(conversationRequest)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ConversationResponse.self, from: data)
    }

    // MARK: - Health Check
    func healthCheck() async throws -> Bool {
        let endpoint = "\(baseURL)/"

        let request = URLRequest(url: URL(string: endpoint)!)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return false
        }

        return true
    }
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    case networkError(Error)

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
        }
    }
}
