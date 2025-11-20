import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @State private var showingNewProject = false
    @State private var searchText = ""

    var filteredProjects: [Project] {
        if searchText.isEmpty {
            return projectManager.projects
        } else {
            return projectManager.projects.filter { project in
                project.name.localizedCaseInsensitiveContains(searchText) ||
                project.location.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if projectManager.projects.isEmpty {
                    EmptyProjectsView {
                        showingNewProject = true
                    }
                } else {
                    List {
                        ForEach(filteredProjects) { project in
                            NavigationLink(destination: ProjectDetailView(project: project)) {
                                ProjectRowView(project: project)
                            }
                        }
                        .onDelete(perform: deleteProjects)
                    }
                    .searchable(text: $searchText, prompt: "Search projects")
                }
            }
            .navigationTitle("My Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewProject) {
                NewProjectView()
            }
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            let project = filteredProjects[index]
            projectManager.deleteProject(project)
        }
    }
}

struct EmptyProjectsView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("No Projects Yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Create your first project to start tracking measurements and compliance")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: action) {
                Label("Create Project", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

struct ProjectRowView: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(project.name)
                    .font(.headline)

                Spacer()

                Text(project.type.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }

            HStack {
                Label(project.location, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if !project.measurements.isEmpty {
                    Label("\(project.measurements.count)", systemImage: "ruler")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(project.createdAt, style: .date)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct NewProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectManager: ProjectManager

    @State private var name = ""
    @State private var selectedType: ProjectType = .residential
    @State private var location = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Project Name", text: $name)

                    Picker("Type", selection: $selectedType) {
                        ForEach(ProjectType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    TextField("Location", text: $location)
                }

                Section {
                    Button("Create Project") {
                        createProject()
                    }
                    .disabled(name.isEmpty || location.isEmpty)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func createProject() {
        let project = Project(
            name: name,
            type: selectedType,
            location: location
        )

        projectManager.addProject(project)
        dismiss()
    }
}

struct ProjectDetailView: View {
    let project: Project
    @EnvironmentObject var projectManager: ProjectManager
    @State private var showingMeasurement = false

    var body: some View {
        List {
            Section("Details") {
                HStack {
                    Text("Type")
                    Spacer()
                    Text(project.type.rawValue)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Location")
                    Spacer()
                    Text(project.location)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Created")
                    Spacer()
                    Text(project.createdAt, style: .date)
                        .foregroundColor(.secondary)
                }
            }

            Section("Measurements") {
                if project.measurements.isEmpty {
                    Text("No measurements yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(project.measurements) { measurement in
                        MeasurementRow(measurement: measurement)
                    }
                }

                Button {
                    showingMeasurement = true
                } label: {
                    Label("Add Measurement", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingMeasurement) {
            MeasurementView(project: project)
        }
    }
}

struct MeasurementRow: View {
    let measurement: Measurement

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(measurement.type.rawValue)
                    .font(.headline)

                Spacer()

                Text(String(format: "%.2f %@", measurement.value, measurement.unit.rawValue))
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            if let notes = measurement.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(measurement.takenAt, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProjectsView()
        .environmentObject(ProjectManager())
}
