import SwiftUI

struct NotificationsView: View {
    @State private var pushNotificationsEnabled = true
    @State private var emailNotificationsEnabled = true
    @State private var projectUpdates = true
    @State private var aiResponses = true
    @State private var weeklyDigest = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Push Notifications", isOn: $pushNotificationsEnabled)
                Toggle("Email Notifications", isOn: $emailNotificationsEnabled)
            } header: {
                Text("General")
            } footer: {
                Text("Receive notifications about activity in your account")
            }
            
            Section("Activity") {
                Toggle("Project Updates", isOn: $projectUpdates)
                    .disabled(!pushNotificationsEnabled && !emailNotificationsEnabled)
                
                Toggle("AI Assistant Responses", isOn: $aiResponses)
                    .disabled(!pushNotificationsEnabled && !emailNotificationsEnabled)
            }
            
            Section("Digest") {
                Toggle("Weekly Summary", isOn: $weeklyDigest)
                    .disabled(!emailNotificationsEnabled)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
}
