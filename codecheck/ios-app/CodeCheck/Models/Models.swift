import Foundation
import CoreLocation

// MARK: - Project Models
struct Project: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: ProjectType
    var location: String
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date
    var measurements: [Measurement]

    init(id: UUID = UUID(), name: String, type: ProjectType, location: String, latitude: Double? = nil, longitude: Double? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = Date()
        self.measurements = []
    }
}

enum ProjectType: String, Codable, CaseIterable {
    case residential = "Residential"
    case commercial = "Commercial"
    case remodel = "Remodel"
    case addition = "Addition"
    case deck = "Deck/Patio"
    case other = "Other"
}

// MARK: - Measurement Models
struct Measurement: Identifiable, Codable {
    let id: UUID
    var type: MeasurementType
    var value: Double
    var unit: MeasurementUnit
    var isCompliant: Bool?
    var notes: String?
    var takenAt: Date

    init(id: UUID = UUID(), type: MeasurementType, value: Double, unit: MeasurementUnit = .inches, notes: String? = nil) {
        self.id = id
        self.type = type
        self.value = value
        self.unit = unit
        self.notes = notes
        self.takenAt = Date()
    }
}

enum MeasurementType: String, Codable, CaseIterable {
    case stairTread = "Stair Tread"
    case stairRiser = "Stair Riser"
    case doorWidth = "Door Width"
    case railingHeight = "Railing Height"
    case ceilingHeight = "Ceiling Height"
    case custom = "Custom"
}

enum MeasurementUnit: String, Codable {
    case inches = "in"
    case feet = "ft"
    case centimeters = "cm"
    case meters = "m"
}

// MARK: - Conversation Models
struct Message: Identifiable, Codable {
    let id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

// MARK: - API Models
struct JurisdictionResponse: Codable {
    let jurisdictions: [Jurisdiction]
}

struct Jurisdiction: Codable, Identifiable {
    let id: String
    let name: String
    let level: String
    let boundary: String?
}

struct ComplianceRequest: Codable {
    let jurisdictionId: String
    let metrics: [String: Double]

    enum CodingKeys: String, CodingKey {
        case jurisdictionId = "jurisdiction_id"
        case metrics
    }
}

struct ComplianceResponse: Codable {
    let isCompliant: Bool
    let violations: [ComplianceViolation]?
    let recommendations: [String]?
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case isCompliant = "is_compliant"
        case violations
        case recommendations
        case confidence
    }
}

struct ComplianceViolation: Codable, Hashable {
    let ruleId: String
    let sectionRef: String
    let metric: String
    let measuredValue: Double
    let requiredValue: Double
    let unit: String
    let requirementType: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
        case sectionRef = "section_ref"
        case metric
        case measuredValue = "measured_value"
        case requiredValue = "required_value"
        case unit
        case requirementType = "requirement_type"
        case message
    }
}

struct ExplainRequest: Codable {
    let ruleId: String
    let measurementValue: Double?

    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
        case measurementValue = "measurement_value"
    }
}

struct ExplainResponse: Codable {
    let ruleId: String
    let explanation: String
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
        case explanation
        case confidence
    }
}

struct ConversationRequest: Codable {
    let message: String
    let projectType: String?
    let location: String?

    enum CodingKeys: String, CodingKey {
        case message
        case projectType = "project_type"
        case location
    }
}

struct ConversationResponse: Codable {
    let response: String
    let suggestions: [String]?
}

// MARK: - Quick Actions
struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: String
    let action: QuickActionType
}

enum QuickActionType {
    case measure
    case askAI
    case checkCompliance
    case viewProjects
}

// MARK: - Authentication Models
struct User: Codable, Identifiable {
    let id: String
    let email: String
    let name: String?
    let role: String?
    let isActive: Bool?

    // Make createdAt optional and use custom init to handle date parsing gracefully
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name = "full_name"
        case role
        case isActive = "is_active"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        name = try? container.decode(String.self, forKey: .name)
        role = try? container.decode(String.self, forKey: .role)
        isActive = try? container.decode(Bool.self, forKey: .isActive)

        // Try to decode date, but don't fail if it doesn't work
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            createdAt = formatter.date(from: dateString)
        } else {
            createdAt = nil
        }
    }
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
    }
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let name: String?
}

struct RefreshTokenRequest: Codable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct AuthError: Codable {
    let detail: String
}

// MARK: - On-Demand Code Loading Models
struct JurisdictionStatus: Codable {
    let status: String  // "ready", "loading", "not_loaded"
    let ruleCount: Int?
    let progress: Int?
    let message: String

    enum CodingKeys: String, CodingKey {
        case status
        case ruleCount = "rule_count"
        case progress
        case message
    }
}

struct CodeLoadingResponse: Codable {
    let status: String
    let jobId: String?
    let message: String

    enum CodingKeys: String, CodingKey {
        case status
        case jobId = "job_id"
        case message
    }
}

struct JobProgress: Codable {
    let jobId: String
    let status: String
    let progress: Int
    let message: String?

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case progress
        case message
    }
}
