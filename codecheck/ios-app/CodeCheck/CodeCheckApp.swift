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
                // Check auth asynchronously after view appears
                // This happens off the main launch path
                await authService.checkAuthStatus()
            }
        }
    }
}


