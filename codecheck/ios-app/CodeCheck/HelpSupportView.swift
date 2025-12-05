import SwiftUI

struct HelpSupportView: View {
    @State private var showingEmailSheet = false
    
    var body: some View {
        List {
            // Getting Started Section
            Section("Getting Started") {
                NavigationLink {
                    Text("Quick Start Guide")
                        .navigationTitle("Quick Start")
                } label: {
                    Label("Quick Start Guide", systemImage: "play.circle")
                }
                
                NavigationLink {
                    Text("Video Tutorials")
                        .navigationTitle("Tutorials")
                } label: {
                    Label("Video Tutorials", systemImage: "video")
                }
            }
            
            // Help Topics Section
            Section("Help Topics") {
                NavigationLink {
                    Text("Managing Projects")
                        .navigationTitle("Managing Projects")
                } label: {
                    Label("Managing Projects", systemImage: "folder.badge.questionmark")
                }
                
                NavigationLink {
                    Text("Code Analysis")
                        .navigationTitle("Code Analysis")
                } label: {
                    Label("Code Analysis", systemImage: "doc.text.magnifyingglass")
                }
                
                NavigationLink {
                    Text("AI Assistant")
                        .navigationTitle("AI Assistant")
                } label: {
                    Label("AI Assistant", systemImage: "sparkles")
                }
            }
            
            // Support Section
            Section("Support") {
                Link(destination: URL(string: "https://codecheck.com/faq")!) {
                    Label("FAQ", systemImage: "questionmark.circle")
                }
                
                Button {
                    showingEmailSheet = true
                } label: {
                    Label("Contact Support", systemImage: "envelope")
                }
                
                Link(destination: URL(string: "https://codecheck.com/docs")!) {
                    Label("Documentation", systemImage: "book")
                }
            }
            
            // Community Section
            Section("Community") {
                Link(destination: URL(string: "https://github.com/codecheck")!) {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                
                Link(destination: URL(string: "https://twitter.com/codecheck")!) {
                    Label("Twitter", systemImage: "at")
                }
            }
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEmailSheet) {
            NavigationStack {
                EmailSupportView()
            }
        }
    }
}

struct EmailSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subject = ""
    @State private var message = ""
    @State private var showingSuccessAlert = false
    
    var body: some View {
        Form {
            Section("Subject") {
                TextField("What do you need help with?", text: $subject)
            }
            
            Section("Message") {
                TextEditor(text: $message)
                    .frame(minHeight: 150)
            }
            
            Section {
                Button("Send") {
                    // Send email logic
                    showingSuccessAlert = true
                }
                .disabled(subject.isEmpty || message.isEmpty)
            }
        }
        .navigationTitle("Contact Support")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .alert("Message Sent", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Our support team will get back to you soon.")
        }
    }
}

#Preview {
    NavigationStack {
        HelpSupportView()
    }
}
