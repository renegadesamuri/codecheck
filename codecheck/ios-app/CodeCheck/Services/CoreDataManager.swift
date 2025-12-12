//
//  CoreDataManager.swift
//  CodeCheck
//
//  Phase 3 Optimization: Core Data persistence layer
//  Replaces UserDefaults for scalable, offline-capable storage
//

import Foundation
import CoreData

/// Manages Core Data stack and provides CRUD operations for persistent storage
class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()

    /// The Core Data persistent container
    let container: NSPersistentContainer

    /// Main view context for UI operations
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Background context for heavy operations
    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }

    // MARK: - Initialization

    private init() {
        // Create the Core Data model programmatically
        // This allows the app to work without a .xcdatamodeld file
        let model = CoreDataManager.createManagedObjectModel()
        container = NSPersistentContainer(name: "CodeCheck", managedObjectModel: model)

        // Configure container
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
                // In production, you might want to delete and recreate the store
            } else {
                print("Core Data loaded successfully: \(description.url?.path ?? "unknown")")
            }
        }

        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Programmatic Model Definition

    private static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Create ProjectEntity
        let projectEntity = NSEntityDescription()
        projectEntity.name = "ProjectEntity"
        projectEntity.managedObjectClassName = "ProjectEntity"

        let projectId = NSAttributeDescription()
        projectId.name = "id"
        projectId.attributeType = .UUIDAttributeType
        projectId.isOptional = false

        let projectName = NSAttributeDescription()
        projectName.name = "name"
        projectName.attributeType = .stringAttributeType
        projectName.isOptional = false

        let projectType = NSAttributeDescription()
        projectType.name = "type"
        projectType.attributeType = .stringAttributeType
        projectType.isOptional = false

        let projectLocation = NSAttributeDescription()
        projectLocation.name = "location"
        projectLocation.attributeType = .stringAttributeType
        projectLocation.isOptional = true

        let projectLatitude = NSAttributeDescription()
        projectLatitude.name = "latitude"
        projectLatitude.attributeType = .doubleAttributeType
        projectLatitude.isOptional = true

        let projectLongitude = NSAttributeDescription()
        projectLongitude.name = "longitude"
        projectLongitude.attributeType = .doubleAttributeType
        projectLongitude.isOptional = true

        let projectCreatedAt = NSAttributeDescription()
        projectCreatedAt.name = "createdAt"
        projectCreatedAt.attributeType = .dateAttributeType
        projectCreatedAt.isOptional = false

        let projectUpdatedAt = NSAttributeDescription()
        projectUpdatedAt.name = "updatedAt"
        projectUpdatedAt.attributeType = .dateAttributeType
        projectUpdatedAt.isOptional = true

        // Create MeasurementEntity
        let measurementEntity = NSEntityDescription()
        measurementEntity.name = "MeasurementEntity"
        measurementEntity.managedObjectClassName = "MeasurementEntity"

        let measurementId = NSAttributeDescription()
        measurementId.name = "id"
        measurementId.attributeType = .UUIDAttributeType
        measurementId.isOptional = false

        let measurementType = NSAttributeDescription()
        measurementType.name = "type"
        measurementType.attributeType = .stringAttributeType
        measurementType.isOptional = false

        let measurementValue = NSAttributeDescription()
        measurementValue.name = "value"
        measurementValue.attributeType = .doubleAttributeType
        measurementValue.isOptional = false

        let measurementUnit = NSAttributeDescription()
        measurementUnit.name = "unit"
        measurementUnit.attributeType = .stringAttributeType
        measurementUnit.isOptional = false

        let measurementIsCompliant = NSAttributeDescription()
        measurementIsCompliant.name = "isCompliant"
        measurementIsCompliant.attributeType = .booleanAttributeType
        measurementIsCompliant.isOptional = true

        let measurementNotes = NSAttributeDescription()
        measurementNotes.name = "notes"
        measurementNotes.attributeType = .stringAttributeType
        measurementNotes.isOptional = true

        let measurementTakenAt = NSAttributeDescription()
        measurementTakenAt.name = "takenAt"
        measurementTakenAt.attributeType = .dateAttributeType
        measurementTakenAt.isOptional = false

        // Create PhotoEntity
        let photoEntity = NSEntityDescription()
        photoEntity.name = "PhotoEntity"
        photoEntity.managedObjectClassName = "PhotoEntity"

        let photoId = NSAttributeDescription()
        photoId.name = "id"
        photoId.attributeType = .UUIDAttributeType
        photoId.isOptional = false

        let photoImageId = NSAttributeDescription()
        photoImageId.name = "imageId"
        photoImageId.attributeType = .UUIDAttributeType
        photoImageId.isOptional = false

        let photoLocation = NSAttributeDescription()
        photoLocation.name = "location"
        photoLocation.attributeType = .stringAttributeType
        photoLocation.isOptional = true

        let photoNotes = NSAttributeDescription()
        photoNotes.name = "notes"
        photoNotes.attributeType = .stringAttributeType
        photoNotes.isOptional = true

        let photoTimestamp = NSAttributeDescription()
        photoTimestamp.name = "timestamp"
        photoTimestamp.attributeType = .dateAttributeType
        photoTimestamp.isOptional = false

        let photoTags = NSAttributeDescription()
        photoTags.name = "tags"
        photoTags.attributeType = .stringAttributeType  // JSON array stored as string
        photoTags.isOptional = true

        // Define relationships
        let projectToMeasurements = NSRelationshipDescription()
        projectToMeasurements.name = "measurements"
        projectToMeasurements.destinationEntity = measurementEntity
        projectToMeasurements.isOptional = true
        projectToMeasurements.deleteRule = .cascadeDeleteRule

        let measurementToProject = NSRelationshipDescription()
        measurementToProject.name = "project"
        measurementToProject.destinationEntity = projectEntity
        measurementToProject.isOptional = true
        measurementToProject.maxCount = 1

        projectToMeasurements.inverseRelationship = measurementToProject
        measurementToProject.inverseRelationship = projectToMeasurements

        let projectToPhotos = NSRelationshipDescription()
        projectToPhotos.name = "photos"
        projectToPhotos.destinationEntity = photoEntity
        projectToPhotos.isOptional = true
        projectToPhotos.deleteRule = .cascadeDeleteRule

        let photoToProject = NSRelationshipDescription()
        photoToProject.name = "project"
        photoToProject.destinationEntity = projectEntity
        photoToProject.isOptional = true
        photoToProject.maxCount = 1

        projectToPhotos.inverseRelationship = photoToProject
        photoToProject.inverseRelationship = projectToPhotos

        // Assign attributes and relationships
        projectEntity.properties = [
            projectId, projectName, projectType, projectLocation,
            projectLatitude, projectLongitude, projectCreatedAt, projectUpdatedAt,
            projectToMeasurements, projectToPhotos
        ]

        measurementEntity.properties = [
            measurementId, measurementType, measurementValue, measurementUnit,
            measurementIsCompliant, measurementNotes, measurementTakenAt,
            measurementToProject
        ]

        photoEntity.properties = [
            photoId, photoImageId, photoLocation, photoNotes, photoTimestamp, photoTags,
            photoToProject
        ]

        model.entities = [projectEntity, measurementEntity, photoEntity]

        return model
    }

    // MARK: - Save Operations

    /// Save the view context
    func saveContext() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }

    /// Save a background context
    func saveBackgroundContext(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save background context: \(error)")
            }
        }
    }

    // MARK: - Project Operations

    /// Fetch all projects
    func fetchProjects() -> [ProjectEntity] {
        let request = NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ProjectEntity.createdAt, ascending: false)]

        do {
            return try viewContext.fetch(request)
        } catch {
            print("Failed to fetch projects: \(error)")
            return []
        }
    }

    /// Fetch project by ID
    func fetchProject(id: UUID) -> ProjectEntity? {
        let request = NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            return try viewContext.fetch(request).first
        } catch {
            print("Failed to fetch project: \(error)")
            return nil
        }
    }

    /// Create a new project from a Project model
    @discardableResult
    func createProject(from project: Project) -> ProjectEntity {
        let entity = ProjectEntity(context: viewContext)
        entity.id = project.id
        entity.name = project.name
        entity.type = project.type.rawValue
        entity.location = project.location
        entity.latitude = project.latitude ?? 0
        entity.longitude = project.longitude ?? 0
        entity.createdAt = project.createdAt
        entity.updatedAt = Date()

        // Create measurement entities
        for measurement in project.measurements {
            let measurementEntity = MeasurementEntity(context: viewContext)
            measurementEntity.id = measurement.id
            measurementEntity.type = measurement.type.rawValue
            measurementEntity.value = measurement.value
            measurementEntity.unit = measurement.unit.rawValue
            measurementEntity.isCompliant = measurement.isCompliant ?? false
            measurementEntity.notes = measurement.notes
            measurementEntity.takenAt = measurement.takenAt
            measurementEntity.project = entity
        }

        saveContext()
        return entity
    }

    /// Update a project
    func updateProject(_ entity: ProjectEntity, with project: Project) {
        entity.name = project.name
        entity.type = project.type.rawValue
        entity.location = project.location
        entity.latitude = project.latitude ?? 0
        entity.longitude = project.longitude ?? 0
        entity.updatedAt = Date()

        saveContext()
    }

    /// Delete a project and its associated images
    func deleteProject(_ entity: ProjectEntity) {
        // Collect all image IDs from photos before deletion
        if let photos = entity.photos as? Set<PhotoEntity> {
            let imageIds = photos.compactMap { $0.imageId }
            if !imageIds.isEmpty {
                Task {
                    await ImageStorageManager.shared.deleteImages(ids: imageIds)
                }
            }
        }

        viewContext.delete(entity)
        saveContext()
    }

    /// Delete project by ID
    func deleteProject(id: UUID) {
        if let entity = fetchProject(id: id) {
            deleteProject(entity)
        }
    }

    // MARK: - Measurement Operations

    /// Add a measurement to a project
    @discardableResult
    func addMeasurement(_ measurement: Measurement, to projectId: UUID) -> MeasurementEntity? {
        guard let project = fetchProject(id: projectId) else { return nil }

        let entity = MeasurementEntity(context: viewContext)
        entity.id = measurement.id
        entity.type = measurement.type.rawValue
        entity.value = measurement.value
        entity.unit = measurement.unit.rawValue
        entity.isCompliant = measurement.isCompliant ?? false
        entity.notes = measurement.notes
        entity.takenAt = measurement.takenAt
        entity.project = project

        saveContext()
        return entity
    }

    /// Delete a measurement
    func deleteMeasurement(_ entity: MeasurementEntity) {
        viewContext.delete(entity)
        saveContext()
    }

    // MARK: - Photo Operations

    /// Add a photo to a project
    @discardableResult
    func addPhoto(imageId: UUID, to projectId: UUID, location: String? = nil, notes: String? = nil) -> PhotoEntity? {
        guard let project = fetchProject(id: projectId) else { return nil }

        let entity = PhotoEntity(context: viewContext)
        entity.id = UUID()
        entity.imageId = imageId
        entity.location = location
        entity.notes = notes
        entity.timestamp = Date()
        entity.project = project

        saveContext()
        return entity
    }

    /// Delete a photo
    func deletePhoto(_ entity: PhotoEntity) {
        // Also delete the image file
        if let imageId = entity.imageId {
            Task {
                try? await ImageStorageManager.shared.deleteImage(id: imageId)
            }
        }
        viewContext.delete(entity)
        saveContext()
    }

    // MARK: - Bulk Operations

    /// Delete all data (for testing or reset)
    func deleteAllData() {
        let entities = ["ProjectEntity", "MeasurementEntity", "PhotoEntity"]

        for entityName in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

            do {
                try viewContext.execute(deleteRequest)
            } catch {
                print("Failed to delete \(entityName): \(error)")
            }
        }

        saveContext()
    }

    /// Get project count
    func projectCount() -> Int {
        let request = NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
        do {
            return try viewContext.count(for: request)
        } catch {
            return 0
        }
    }

    /// Get all photo image IDs (for orphan cleanup)
    func getAllPhotoImageIds() -> [UUID] {
        let request = NSFetchRequest<PhotoEntity>(entityName: "PhotoEntity")

        do {
            let photos = try viewContext.fetch(request)
            return photos.compactMap { $0.imageId }
        } catch {
            print("Failed to fetch photo image IDs: \(error)")
            return []
        }
    }
}

// MARK: - Core Data Entity Classes

@objc(ProjectEntity)
public class ProjectEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var type: String?
    @NSManaged public var location: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var measurements: NSSet?
    @NSManaged public var photos: NSSet?

    /// Convert to Project model
    func toProject() -> Project {
        var project = Project(
            id: id ?? UUID(),
            name: name ?? "",
            type: ProjectType(rawValue: type ?? "") ?? .other,
            location: location ?? "",
            latitude: latitude != 0 ? latitude : nil,
            longitude: longitude != 0 ? longitude : nil
        )

        // Add measurements
        if let measurementSet = measurements as? Set<MeasurementEntity> {
            project.measurements = measurementSet.compactMap { $0.toMeasurement() }
                .sorted { $0.takenAt > $1.takenAt }
        }

        return project
    }
}

@objc(MeasurementEntity)
public class MeasurementEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var type: String?
    @NSManaged public var value: Double
    @NSManaged public var unit: String?
    @NSManaged public var isCompliant: Bool
    @NSManaged public var notes: String?
    @NSManaged public var takenAt: Date?
    @NSManaged public var project: ProjectEntity?

    /// Convert to Measurement model
    func toMeasurement() -> Measurement {
        Measurement(
            id: id ?? UUID(),
            type: MeasurementType(rawValue: type ?? "") ?? .custom,
            value: value,
            unit: MeasurementUnit(rawValue: unit ?? "") ?? .inches,
            notes: notes
        )
    }
}

@objc(PhotoEntity)
public class PhotoEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var imageId: UUID?
    @NSManaged public var location: String?
    @NSManaged public var notes: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var tags: String?  // JSON array
    @NSManaged public var project: ProjectEntity?

    /// Get tags as array
    var tagsArray: [String] {
        guard let tagsData = tags?.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: tagsData) else {
            return []
        }
        return decoded
    }

    /// Set tags from array
    func setTags(_ array: [String]) {
        if let encoded = try? JSONEncoder().encode(array),
           let string = String(data: encoded, encoding: .utf8) {
            tags = string
        }
    }
}

// MARK: - Convenience Extensions

extension Array where Element == ProjectEntity {
    /// Convert array of entities to Project models
    func toProjects() -> [Project] {
        compactMap { $0.toProject() }
    }
}
