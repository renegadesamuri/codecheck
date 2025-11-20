import Foundation
import Combine

class ProjectManager: ObservableObject {
    @Published var projects: [Project] = []

    private let projectsKey = "saved_projects"

    init() {
        loadProjects()
    }

    // MARK: - Project Management
    func addProject(_ project: Project) {
        projects.append(project)
        saveProjects()
    }

    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
            saveProjects()
        }
    }

    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        saveProjects()
    }

    func getProject(by id: UUID) -> Project? {
        return projects.first { $0.id == id }
    }

    // MARK: - Measurement Management
    func addMeasurement(_ measurement: Measurement, to project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else {
            return
        }

        projects[index].measurements.append(measurement)
        saveProjects()
    }

    func updateMeasurement(_ measurement: Measurement, in project: Project) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == project.id }),
              let measurementIndex = projects[projectIndex].measurements.firstIndex(where: { $0.id == measurement.id }) else {
            return
        }

        projects[projectIndex].measurements[measurementIndex] = measurement
        saveProjects()
    }

    func deleteMeasurement(_ measurement: Measurement, from project: Project) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == project.id }) else {
            return
        }

        projects[projectIndex].measurements.removeAll { $0.id == measurement.id }
        saveProjects()
    }

    // MARK: - Persistence
    private func saveProjects() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(projects)
            UserDefaults.standard.set(data, forKey: projectsKey)
        } catch {
            print("Error saving projects: \(error.localizedDescription)")
        }
    }

    private func loadProjects() {
        guard let data = UserDefaults.standard.data(forKey: projectsKey) else {
            // Load sample data for preview/testing
            loadSampleData()
            return
        }

        do {
            let decoder = JSONDecoder()
            projects = try decoder.decode([Project].self, from: data)
        } catch {
            print("Error loading projects: \(error.localizedDescription)")
            loadSampleData()
        }
    }

    private func loadSampleData() {
        // Optionally load sample data for first-time users
        #if DEBUG
        let sampleProject = Project(
            name: "Kitchen Remodel",
            type: .remodel,
            location: "123 Main St, Denver, CO",
            latitude: 39.7392,
            longitude: -104.9903
        )
        projects = [sampleProject]
        #endif
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
}
