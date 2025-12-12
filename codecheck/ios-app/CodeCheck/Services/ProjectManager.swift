import Foundation
import Combine
import CoreData

/// Manages project persistence using Core Data
/// Phase 3 Optimization: Migrated from UserDefaults to Core Data for scalability and offline support
class ProjectManager: ObservableObject {
    @Published var projects: [Project] = []

    /// Flag indicating if data has been loaded
    @Published var isLoaded = false

    /// Reference to Core Data manager
    private let coreDataManager = CoreDataManager.shared

    /// Cancellable for Core Data changes observation
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Observe Core Data context changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: coreDataManager.viewContext)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadProjects()
            }
            .store(in: &cancellables)

        // Initial load
        loadProjects()
    }

    // MARK: - Project Management

    func addProject(_ project: Project) {
        coreDataManager.createProject(from: project)
        reloadProjects()
    }

    func updateProject(_ project: Project) {
        if let entity = coreDataManager.fetchProject(id: project.id) {
            coreDataManager.updateProject(entity, with: project)

            // Update measurements
            if let existingMeasurements = entity.measurements as? Set<MeasurementEntity> {
                // Remove old measurements
                for measurement in existingMeasurements {
                    coreDataManager.viewContext.delete(measurement)
                }
            }

            // Add new measurements
            for measurement in project.measurements {
                coreDataManager.addMeasurement(measurement, to: project.id)
            }

            coreDataManager.saveContext()
            reloadProjects()
        }
    }

    func deleteProject(_ project: Project) {
        coreDataManager.deleteProject(id: project.id)
        reloadProjects()
    }

    func getProject(by id: UUID) -> Project? {
        return projects.first { $0.id == id }
    }

    // MARK: - Measurement Management

    func addMeasurement(_ measurement: Measurement, to project: Project) {
        coreDataManager.addMeasurement(measurement, to: project.id)
        reloadProjects()
    }

    func updateMeasurement(_ measurement: Measurement, in project: Project) {
        // Find and update the measurement entity
        if let projectEntity = coreDataManager.fetchProject(id: project.id),
           let measurementSet = projectEntity.measurements as? Set<MeasurementEntity>,
           let measurementEntity = measurementSet.first(where: { $0.id == measurement.id }) {

            measurementEntity.type = measurement.type.rawValue
            measurementEntity.value = measurement.value
            measurementEntity.unit = measurement.unit.rawValue
            measurementEntity.isCompliant = measurement.isCompliant ?? false
            measurementEntity.notes = measurement.notes

            coreDataManager.saveContext()
            reloadProjects()
        }
    }

    func deleteMeasurement(_ measurement: Measurement, from project: Project) {
        if let projectEntity = coreDataManager.fetchProject(id: project.id),
           let measurementSet = projectEntity.measurements as? Set<MeasurementEntity>,
           let measurementEntity = measurementSet.first(where: { $0.id == measurement.id }) {

            coreDataManager.deleteMeasurement(measurementEntity)
            reloadProjects()
        }
    }

    // MARK: - Persistence

    private func loadProjects() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            // Load from Core Data
            let projectEntities = self.coreDataManager.fetchProjects()
            let loadedProjects = projectEntities.toProjects()

            // Update UI on main thread
            await MainActor.run {
                self.projects = loadedProjects
                self.isLoaded = true

                // If no projects and this is first run, optionally load sample data
                if loadedProjects.isEmpty && !DataMigrator.isMigrationCompleted {
                    self.loadSampleData()
                }
            }
        }
    }

    private func reloadProjects() {
        let projectEntities = coreDataManager.fetchProjects()
        projects = projectEntities.toProjects()
    }

    private func loadSampleData() {
        #if DEBUG
        let sampleProject = Project(
            name: "Kitchen Remodel",
            type: .remodel,
            location: "123 Main St, Denver, CO",
            latitude: 39.7392,
            longitude: -104.9903
        )
        addProject(sampleProject)
        #endif
    }

    // MARK: - Sync Status (for future offline support)

    /// Check if there are unsaved changes
    var hasUnsavedChanges: Bool {
        coreDataManager.viewContext.hasChanges
    }

    /// Force save any pending changes
    func forceSave() {
        coreDataManager.saveContext()
    }

    // MARK: - Export

    func exportProject(_ project: Project) -> String {
        var export = """
        Project: \(project.name)
        Type: \(project.type.rawValue)
        Location: \(project.location)
        Created: \(project.createdAt.formatted(date: .long, time: .shortened))

        Measurements:
        """

        if project.measurements.isEmpty {
            export += "\nNo measurements recorded"
        } else {
            for measurement in project.measurements {
                export += """

                - \(measurement.type.rawValue): \(String(format: "%.2f", measurement.value)) \(measurement.unit.rawValue)
                  Taken: \(measurement.takenAt.formatted(date: .abbreviated, time: .shortened))
                """
                if let notes = measurement.notes {
                    export += "\n  Notes: \(notes)"
                }
                if let isCompliant = measurement.isCompliant {
                    export += "\n  Compliant: \(isCompliant ? "Yes" : "No")"
                }
            }
        }

        return export
    }

    // MARK: - Migration Support

    /// Check if legacy data needs migration
    var needsMigration: Bool {
        DataMigrator.needsMigration
    }

    /// Perform migration from UserDefaults to Core Data
    @MainActor
    func migrateIfNeeded() async {
        await DataMigrator.migrateIfNeeded()
        reloadProjects()
    }
}

// MARK: - Legacy Support (deprecated, for backward compatibility)

extension ProjectManager {
    /// Legacy UserDefaults key (for migration)
    private static let legacyProjectsKey = "saved_projects"

    /// Check if legacy data exists
    var hasLegacyData: Bool {
        UserDefaults.standard.data(forKey: Self.legacyProjectsKey) != nil
    }
}
