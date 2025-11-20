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
    let compliant: Bool
    let violations: [String]?
    let warnings: [String]?
    let explanation: String?
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
