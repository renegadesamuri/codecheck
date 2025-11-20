import SwiftUI

@main
struct CodeCheckApp: App {
    @StateObject private var projectManager = ProjectManager()
    @StateObject private var conversationManager = ConversationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(projectManager)
                .environmentObject(conversationManager)
        }
    }
}


