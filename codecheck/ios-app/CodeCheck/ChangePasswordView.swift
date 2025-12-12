import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        Form {
            Section("Current Password") {
                SecureField("Current Password", text: $currentPassword)
                    .textContentType(.password)
            }
            
            Section("New Password") {
                SecureField("New Password", text: $newPassword)
                    .textContentType(.newPassword)
                
                SecureField("Confirm New Password", text: $confirmPassword)
                    .textContentType(.newPassword)
            }
            
            Section {
                Button("Change Password") {
                    changePassword()
                }
                .frame(maxWidth: .infinity)
                .disabled(!isValidInput)
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Change Password", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {
                if alertMessage.contains("success") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isValidInput: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword.count >= 6
    }
    
    private func changePassword() {
        guard newPassword == confirmPassword else {
            alertMessage = "New passwords do not match"
            showingAlert = true
            return
        }
        
        // TODO: Implement password change logic
        alertMessage = "Password changed successfully!"
        showingAlert = true
    }
}

#Preview {
    NavigationStack {
        ChangePasswordView()
    }
}
