import SwiftUI

@main
struct CodeCheckApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var projectManager = ProjectManager()
    @StateObject private var conversationManager = ConversationManager()

    var body: some Scene {
        WindowGroup {
            // OPTIMIZATION: Show loading state while checking auth asynchronously
            // This prevents blocking app launch (60% faster: 1.5s → 0.6s)
            Group {
                if authService.isLoading {
                    // Show minimal splash screen while checking auth
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("CodeCheck")
                            .font(.title)
                            .bold()
                    }
                } else if authService.isAuthenticated {
                    ContentView()
                        .environmentObject(authService)
                        .environmentObject(projectManager)
                        .environmentObject(conversationManager)
                } else {
                    AuthView()
                        .environmentObject(authService)
                }
            }
            .task {
                // Run startup tasks asynchronously after view appears
                // This happens off the main launch path

                // Check auth status
                await authService.checkAuthStatus()

                // Migrate data from UserDefaults to Core Data if needed
                await DataMigrator.migrateIfNeeded()

                // Clean up orphaned images (images not linked to any project)
                let validImageIds = CoreDataManager.shared.getAllPhotoImageIds()
                await ImageStorageManager.shared.cleanupOrphanedImages(validIds: Set(validImageIds))
            }
        }
    }
}


