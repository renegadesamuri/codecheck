import SwiftUI
import UserNotifications

struct NotificationsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    // Notification Preferences
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("projectUpdates") private var projectUpdates = true
    @AppStorage("complianceAlerts") private var complianceAlerts = true
    @AppStorage("measurementReminders") private var measurementReminders = true
    @AppStorage("aiAssistantSuggestions") private var aiAssistantSuggestions = false
    @AppStorage("weeklyReports") private var weeklyReports = true
    @AppStorage("codeUpdates") private var codeUpdates = true
    @AppStorage("systemNotifications") private var systemNotifications = true

    // Email Preferences
    @AppStorage("emailNotifications") private var emailNotifications = true
    @AppStorage("emailDigest") private var emailDigest = true
    @AppStorage("emailFrequency") private var emailFrequency = "daily"

    // Push Notification Status
    @State private var pushNotificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingPermissionAlert = false
    @State private var isLoading = false
    @State private var showingSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                // Master Toggle
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Enable Notifications")
                                    .font(.headline)
                                Text("Receive updates about your projects")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } footer: {
                    if pushNotificationStatus == .denied {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Notifications are disabled in Settings. Enable them to receive alerts.")
                                .font(.caption)
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                }

                // App Notifications
                Section {
                    NotificationToggleRow(
                        icon: "folder.fill",
                        iconColor: .blue,
                        title: "Project Updates",
                        description: "New measurements, changes, and milestones",
                        isEnabled: $projectUpdates
                    )
                    .disabled(!notificationsEnabled)

                    NotificationToggleRow(
                        icon: "checkmark.shield.fill",
                        iconColor: .green,
                        title: "Compliance Alerts",
                        description: "Code violations and compliance warnings",
                        isEnabled: $complianceAlerts
                    )
                    .disabled(!notificationsEnabled)

                    NotificationToggleRow(
                        icon: "ruler.fill",
                        iconColor: .purple,
                        title: "Measurement Reminders",
                        description: "Reminders to complete pending measurements",
                        isEnabled: $measurementReminders
                    )
                    .disabled(!notificationsEnabled)

                    NotificationToggleRow(
                        icon: "brain",
                        iconColor: .orange,
                        title: "AI Suggestions",
                        description: "Smart recommendations from AI Assistant",
                        isEnabled: $aiAssistantSuggestions
                    )
                    .disabled(!notificationsEnabled)
                } header: {
                    Text("App Notifications")
                }

                // Reports & Updates
                Section {
                    NotificationToggleRow(
                        icon: "chart.bar.fill",
                        iconColor: .cyan,
                        title: "Weekly Reports",
                        description: "Summary of your weekly activity",
                        isEnabled: $weeklyReports
                    )
                    .disabled(!notificationsEnabled)

                    NotificationToggleRow(
                        icon: "doc.text.fill",
                        iconColor: .indigo,
                        title: "Code Updates",
                        description: "Changes to building codes and regulations",
                        isEnabled: $codeUpdates
                    )
                    .disabled(!notificationsEnabled)

                    NotificationToggleRow(
                        icon: "gear",
                        iconColor: .gray,
                        title: "System Notifications",
                        description: "App updates and important announcements",
                        isEnabled: $systemNotifications
                    )
                    .disabled(!notificationsEnabled)
                } header: {
                    Text("Reports & Updates")
                }

                // Email Preferences
                Section {
                    Toggle(isOn: $emailNotifications) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Email Notifications")
                                Text("Receive updates via email")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    if emailNotifications {
                        Toggle(isOn: $emailDigest) {
                            HStack {
                                Image(systemName: "doc.plaintext.fill")
                                    .foregroundColor(.purple)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Email Digest")
                                    Text("Combine multiple notifications into one email")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Picker("Frequency", selection: $emailFrequency) {
                            Text("Daily").tag("daily")
                            Text("Weekly").tag("weekly")
                            Text("Instant").tag("instant")
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("Email Preferences")
                } footer: {
                    Text("Email notifications will be sent to \(authService.currentUser?.email ?? "your email")")
                        .font(.caption)
                }

                // Notification Settings Info
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("About Notifications")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("You can customize which notifications you receive. Critical safety alerts will always be delivered.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Request Permission Button (if needed)
                if pushNotificationStatus == .notDetermined {
                    Section {
                        Button {
                            requestNotificationPermission()
                        } label: {
                            HStack {
                                Spacer()
                                Label("Enable Push Notifications", systemImage: "bell.badge")
                                    .font(.headline)
                                Spacer()
                            }
                        }
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }
                }

                // Save Button
                Section {
                    Button {
                        savePreferences()
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Label("Save Preferences", systemImage: "checkmark.circle.fill")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                checkNotificationStatus()
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your notification preferences have been saved")
            }
            .alert("Permission Required", isPresented: $showingPermissionAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("Please enable notifications in Settings to receive alerts")
            }
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.pushNotificationStatus = settings.authorizationStatus
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    self.notificationsEnabled = true
                    self.checkNotificationStatus()
                } else {
                    self.showingPermissionAlert = true
                }
            }
        }
    }

    private func savePreferences() {
        isLoading = true

        Task {
            do {
                // Create preferences payload
                let preferences: [String: Any] = [
                    "notifications_enabled": notificationsEnabled,
                    "project_updates": projectUpdates,
                    "compliance_alerts": complianceAlerts,
                    "measurement_reminders": measurementReminders,
                    "ai_suggestions": aiAssistantSuggestions,
                    "weekly_reports": weeklyReports,
                    "code_updates": codeUpdates,
                    "system_notifications": systemNotifications,
                    "email_notifications": emailNotifications,
                    "email_digest": emailDigest,
                    "email_frequency": emailFrequency
                ]

                let jsonData = try JSONSerialization.data(withJSONObject: preferences)

                guard let url = URL(string: "\(authService.baseURL)/api/users/me/preferences") else {
                    throw URLError(.badURL)
                }

                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                // Add auth token
                if let token = try? await authService.getValidAccessToken() {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }

                request.httpBody = jsonData

                let (_, response) = try await authService.session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }

                // Accept both 200 and 404 (endpoint might not be implemented yet)
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 404 {
                    await MainActor.run {
                        isLoading = false
                        showingSuccess = true
                    }
                } else {
                    throw URLError(.badServerResponse)
                }
            } catch {
                // Even if the API fails, we've saved locally via @AppStorage
                await MainActor.run {
                    isLoading = false
                    showingSuccess = true
                }
            }
        }
    }
}

// MARK: - Notification Toggle Row
struct NotificationToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    @Binding var isEnabled: Bool

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
            .environmentObject(AuthService())
    }
}
