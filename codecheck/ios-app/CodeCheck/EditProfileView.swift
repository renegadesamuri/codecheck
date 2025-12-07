import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var showingSaveAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        Form {
            Section("Personal Information") {
                TextField("Name", text: $name)
                    .textContentType(.name)
                
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            Section {
                Button("Save Changes") {
                    saveProfile()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentProfile()
        }
        .alert("Profile", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadCurrentProfile() {
        name = authService.currentUser?.name ?? ""
        email = authService.currentUser?.email ?? ""
    }
    
    private func saveProfile() {
        // TODO: Implement profile update logic
        alertMessage = "Profile updated successfully!"
        showingSaveAlert = true
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(AuthService())
    }
}
