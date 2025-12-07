import SwiftUI

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedTab = 0
    @State private var loadedTabs: Set<Int> = [0]  // Home loaded by default

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home - always loaded
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            // Projects - lazy loaded
            Group {
                if loadedTabs.contains(1) {
                    ProjectsView()
                } else {
                    ProgressView()
                }
            }
            .tabItem {
                Label("Projects", systemImage: "folder.fill")
            }
            .tag(1)

            // AI Assistant - lazy loaded
            Group {
                if loadedTabs.contains(2) {
                    ConversationView()
                } else {
                    ProgressView()
                }
            }
            .tabItem {
                Label("AI Assistant", systemImage: "bubble.left.and.bubble.right.fill")
            }
            .tag(2)

            // Profile - lazy loaded
            Group {
                if loadedTabs.contains(3) {
                    ProfileView()
                } else {
                    ProgressView()
                }
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(3)
        }
        .onChange(of: selectedTab) { _, newTab in
            // Load tab on first access
            loadedTabs.insert(newTab)
        }
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingLogoutAlert = false

    var body: some View {
        NavigationStack {
            List {
                // User Info Section
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text((authService.currentUser?.name?.prefix(1) ?? authService.currentUser?.email.prefix(1) ?? "U").uppercased())
                                    .font(.title)
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(authService.currentUser?.name ?? authService.currentUser?.email.components(separatedBy: "@").first?.capitalized ?? "User")
                                .font(.headline)

                            Text(authService.currentUser?.email ?? "No email")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Account Section
                Section("Account") {
                    NavigationLink {
                        EditProfileView()
                    } label: {
                        Label("Edit Profile", systemImage: "person.circle")
                    }

                    NavigationLink {
                        ChangePasswordView()
                    } label: {
                        Label("Change Password", systemImage: "lock")
                    }

                    NavigationLink {
                        NotificationsView()
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                }

                // App Section
                Section("App") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }

                    NavigationLink {
                        HelpSupportView()
                    } label: {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }

                // Logout Section
                Section {
                    Button(role: .destructive) {
                        showingLogoutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "arrow.right.square")
                    }
                }
            }
            .navigationTitle("Profile")
            .alert("Sign Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authService.logout()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
        .environmentObject(ProjectManager())
        .environmentObject(ConversationManager())
}
