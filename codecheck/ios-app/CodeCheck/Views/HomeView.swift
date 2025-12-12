import SwiftUI

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @State private var showingMeasurement = false
    @State private var showingConversation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CodeCheck")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(GradientCache.bluePurpleHorizontal)

                        Text("Construction Compliance Assistant")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top)

                    // Quick Actions
                    VStack(spacing: 16) {
                        Text("Quick Actions")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            QuickActionCard(
                                title: "Quick Measure",
                                icon: "ruler",
                                gradient: GradientCache.blueCyan
                            ) {
                                showingMeasurement = true
                            }

                            QuickActionCard(
                                title: "AI Assistant",
                                icon: "bubble.left.and.bubble.right.fill",
                                gradient: GradientCache.purplePink
                            ) {
                                showingConversation = true
                            }

                            QuickActionCard(
                                title: "My Projects",
                                icon: "folder.fill",
                                gradient: GradientCache.greenMint
                            ) {
                                // Navigate to projects tab
                            }

                            QuickActionCard(
                                title: "Find Codes",
                                icon: "magnifyingglass",
                                gradient: GradientCache.orangeYellow
                            ) {
                                // Find building codes
                            }
                        }
                    }

                    // Recent Activity
                    if !projectManager.projects.isEmpty {
                        VStack(spacing: 16) {
                            Text("Recent Projects")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(projectManager.projects.prefix(3)) { project in
                                ProjectCard(project: project)
                            }
                        }
                    }

                    // Features Overview
                    VStack(spacing: 16) {
                        Text("Features")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        FeatureRow(icon: "arkit", title: "ARKit Measurements", description: "Precise measurements using LiDAR technology")
                        FeatureRow(icon: "cpu", title: "AI-Powered", description: "Get instant answers about building codes")
                        FeatureRow(icon: "checkmark.shield.fill", title: "Compliance Checking", description: "Verify your work meets local codes")
                        FeatureRow(icon: "map.fill", title: "Multi-Jurisdictional", description: "Automatic location-based code lookup")
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingMeasurement) {
                MeasurementView(project: nil)
            }
            .sheet(isPresented: $showingConversation) {
                NavigationStack {
                    ConversationView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    showingConversation = false
                                }
                            }
                        }
                }
            }
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let gradient: LinearGradient
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(.white)

                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(gradient)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
    }
}

struct ProjectCard: View {
    let project: Project

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)

                Text(project.type.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(project.location)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(GradientCache.bluePurple)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    HomeView()
        .environmentObject(ProjectManager())
}
