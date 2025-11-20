import Foundation
import Combine

@MainActor
class ConversationManager: ObservableObject {
    @Published var messages: [Message] = []
    private let apiService = CodeLookupService()

    init() {
        // Add welcome message
        addMessage(Message(
            role: .assistant,
            content: "Hi! I'm your CodeCheck AI assistant. I can help you understand building codes, check compliance, and answer questions about construction requirements. How can I help you today?"
        ))
    }

    func addMessage(_ message: Message) {
        messages.append(message)
    }

    func sendMessage(_ content: String) async {
        do {
            let response = try await apiService.sendConversation(message: content)
            addMessage(Message(role: .assistant, content: response.response))

            // Add suggestions if available
            if let suggestions = response.suggestions, !suggestions.isEmpty {
                let suggestionsText = "You might also want to know:\n" + suggestions.map { "• \($0)" }.joined(separator: "\n")
                addMessage(Message(role: .system, content: suggestionsText))
            }
        } catch {
            addMessage(Message(
                role: .system,
                content: "Sorry, I encountered an error: \(error.localizedDescription). Please make sure the CodeCheck API is running."
            ))
        }
    }

    func clearConversation() {
        messages.removeAll()
        // Re-add welcome message
        addMessage(Message(
            role: .assistant,
            content: "Conversation cleared. How can I help you?"
        ))
    }

    func exportConversation() -> String {
        messages.map { message in
            let role = message.role.rawValue.capitalized
            let timestamp = message.timestamp.formatted(date: .abbreviated, time: .shortened)
            return "[\(timestamp)] \(role): \(message.content)"
        }.joined(separator: "\n\n")
    }
}
