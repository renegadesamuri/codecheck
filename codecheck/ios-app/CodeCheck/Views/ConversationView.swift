import SwiftUI

struct ConversationView: View {
    @EnvironmentObject var conversationManager: ConversationManager
    @State private var messageText = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(conversationManager.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if isLoading {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Thinking...")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                        }
                    }
                    .padding()
                }
                .onChange(of: conversationManager.messages.count) { _, _ in
                    if let lastMessage = conversationManager.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Quick Action Buttons
            if conversationManager.messages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        QuickActionButton(text: "Stair requirements?", icon: "figure.stairs") {
                            sendMessage("What are the building code requirements for stairs?")
                        }

                        QuickActionButton(text: "Railing height?", icon: "arrow.up.and.down") {
                            sendMessage("What is the required railing height for residential buildings?")
                        }

                        QuickActionButton(text: "Door width?", icon: "door.right.hand.open") {
                            sendMessage("What is the minimum door width required by code?")
                        }

                        QuickActionButton(text: "General help", icon: "questionmark.circle") {
                            sendMessage("How can you help me with building codes?")
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }

            Divider()

            // Message Input
            HStack(spacing: 12) {
                TextField("Ask about building codes...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...5)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                colors: messageText.isEmpty ? [.gray] : [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .disabled(messageText.isEmpty || isLoading)
            }
            .padding()
        }
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    conversationManager.clearConversation()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(conversationManager.messages.isEmpty)
            }
        }
    }

    private func sendMessage(_ text: String? = nil) {
        let content = text ?? messageText
        guard !content.isEmpty else { return }

        // Add user message
        conversationManager.addMessage(Message(role: .user, content: content))

        // Clear input
        if text == nil {
            messageText = ""
        }

        // Send to API
        isLoading = true
        Task {
            await conversationManager.sendMessage(content)
            isLoading = false
        }
    }
}

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 50)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.role == .user ?
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [Color(.systemGray5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.role == .assistant {
                Spacer(minLength: 50)
            }
        }
    }
}

struct QuickActionButton: View {
    let text: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(text)
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ConversationView()
            .environmentObject(ConversationManager())
    }
}


