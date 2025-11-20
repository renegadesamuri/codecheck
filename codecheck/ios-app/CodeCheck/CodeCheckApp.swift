import SwiftUI

@main
struct CodeCheckApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var projectManager = ProjectManager()
    @StateObject private var conversationManager = ConversationManager()

    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                ContentView()
                    .environmentObject(authService)
                    .environmentObject(projectManager)
                    .environmentObject(conversationManager)
            } else {
                AuthView()
                    .environmentObject(authService)
            }
        }
    }
}


