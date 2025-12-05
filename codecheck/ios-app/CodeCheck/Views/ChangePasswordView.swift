import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false

    // Password visibility toggles
    @State private var showCurrentPassword = false
    @State private var showNewPassword = false
    @State private var showConfirmPassword = false

    var body: some View {
        NavigationStack {
            Form {
                // Instructions
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text("Password Security")
                                .font(.headline)
                        }

                        Text("Choose a strong password to keep your account secure")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Current Password
                Section {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.blue)
                            .frame(width: 30)

                        if showCurrentPassword {
                            TextField("Current Password", text: $currentPassword)
                        } else {
                            SecureField("Current Password", text: $currentPassword)
                        }

                        Button {
                            showCurrentPassword.toggle()
                        } label: {
                            Image(systemName: showCurrentPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("Current Password")
                } footer: {
                    Text("Enter your current password to verify your identity")
                        .font(.caption)
                }

                // New Password
                Section {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.purple)
                            .frame(width: 30)

                        if showNewPassword {
                            TextField("New Password", text: $newPassword)
                        } else {
                            SecureField("New Password", text: $newPassword)
                        }

                        Button {
                            showNewPassword.toggle()
                        } label: {
                            Image(systemName: showNewPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.gray)
                        }
                    }

                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                            .frame(width: 30)

                        if showConfirmPassword {
                            TextField("Confirm New Password", text: $confirmPassword)
                        } else {
                            SecureField("Confirm New Password", text: $confirmPassword)
                        }

                        Button {
                            showConfirmPassword.toggle()
                        } label: {
                            Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("New Password")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password Requirements:")
                            .fontWeight(.semibold)
                        Text("• At least 8 characters")
                        Text("• Mix of uppercase and lowercase letters")
                        Text("• At least one number")
                        Text("• At least one special character (!@#$%^&*)")
                    }
                    .font(.caption)
                }

                // Password Strength Indicator
                if !newPassword.isEmpty {
                    Section {
                        PasswordStrengthIndicator(password: newPassword)
                    }
                }

                // Validation Messages
                if !newPassword.isEmpty || !confirmPassword.isEmpty {
                    Section {
                        ValidationMessageView(
                            icon: newPassword.count >= 8 ? "checkmark.circle.fill" : "xmark.circle.fill",
                            text: "At least 8 characters",
                            isValid: newPassword.count >= 8
                        )

                        ValidationMessageView(
                            icon: newPassword.contains(where: { $0.isUppercase }) && newPassword.contains(where: { $0.isLowercase }) ? "checkmark.circle.fill" : "xmark.circle.fill",
                            text: "Uppercase and lowercase letters",
                            isValid: newPassword.contains(where: { $0.isUppercase }) && newPassword.contains(where: { $0.isLowercase })
                        )

                        ValidationMessageView(
                            icon: newPassword.contains(where: { $0.isNumber }) ? "checkmark.circle.fill" : "xmark.circle.fill",
                            text: "At least one number",
                            isValid: newPassword.contains(where: { $0.isNumber })
                        )

                        ValidationMessageView(
                            icon: newPassword.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) }) ? "checkmark.circle.fill" : "xmark.circle.fill",
                            text: "At least one special character",
                            isValid: newPassword.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) })
                        )

                        ValidationMessageView(
                            icon: !confirmPassword.isEmpty && newPassword == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill",
                            text: "Passwords match",
                            isValid: !confirmPassword.isEmpty && newPassword == confirmPassword
                        )
                    } header: {
                        Text("Password Validation")
                    }
                }

                // Change Password Button
                Section {
                    Button {
                        changePassword()
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Label("Change Password", systemImage: "lock.rotation")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading || !isPasswordValid())
                    .foregroundStyle(
                        LinearGradient(
                            colors: isPasswordValid() ? [.blue, .purple] : [.gray],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your password has been changed successfully. Please use your new password for future logins.")
            }
        }
    }

    private func isPasswordValid() -> Bool {
        guard !currentPassword.isEmpty,
              !newPassword.isEmpty,
              !confirmPassword.isEmpty else {
            return false
        }

        // Check password requirements
        guard newPassword.count >= 8,
              newPassword.contains(where: { $0.isUppercase }),
              newPassword.contains(where: { $0.isLowercase }),
              newPassword.contains(where: { $0.isNumber }),
              newPassword.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) }),
              newPassword == confirmPassword else {
            return false
        }

        return true
    }

    private func changePassword() {
        isLoading = true

        Task {
            do {
                let updateData: [String: Any] = [
                    "current_password": currentPassword,
                    "new_password": newPassword
                ]

                let jsonData = try JSONSerialization.data(withJSONObject: updateData)

                guard let url = URL(string: "\(authService.baseURL)/api/users/me/password") else {
                    throw URLError(.badURL)
                }

                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                // Add auth token
                if let token = try? await authService.getValidAccessToken() {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }

                request.httpBody = jsonData

                let (data, response) = try await authService.session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }

                if httpResponse.statusCode == 200 {
                    await MainActor.run {
                        isLoading = false
                        showingSuccess = true
                        // Clear password fields
                        currentPassword = ""
                        newPassword = ""
                        confirmPassword = ""
                    }
                } else {
                    // Try to parse error message
                    if let errorResponse = try? JSONDecoder().decode(AuthError.self, from: data) {
                        throw NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.detail])
                    } else {
                        throw URLError(.badServerResponse)
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Password Strength Indicator
struct PasswordStrengthIndicator: View {
    let password: String

    private var strength: PasswordStrength {
        let length = password.count
        let hasUpper = password.contains(where: { $0.isUppercase })
        let hasLower = password.contains(where: { $0.isLowercase })
        let hasNumber = password.contains(where: { $0.isNumber })
        let hasSpecial = password.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) })

        let criteriaCount = [hasUpper, hasLower, hasNumber, hasSpecial].filter { $0 }.count

        if length < 8 {
            return .weak
        } else if length >= 8 && criteriaCount >= 2 {
            return .medium
        } else if length >= 12 && criteriaCount >= 3 {
            return .strong
        } else if length >= 16 && criteriaCount == 4 {
            return .veryStrong
        } else {
            return .weak
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Password Strength:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(strength.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(strength.color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(strength.color)
                        .frame(width: geometry.size.width * strength.percentage, height: 8)
                        .cornerRadius(4)
                        .animation(.easeInOut, value: strength)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
    }

    enum PasswordStrength: String {
        case weak = "Weak"
        case medium = "Medium"
        case strong = "Strong"
        case veryStrong = "Very Strong"

        var color: Color {
            switch self {
            case .weak: return .red
            case .medium: return .orange
            case .strong: return .green
            case .veryStrong: return .blue
            }
        }

        var percentage: CGFloat {
            switch self {
            case .weak: return 0.25
            case .medium: return 0.5
            case .strong: return 0.75
            case .veryStrong: return 1.0
            }
        }
    }
}

// MARK: - Validation Message View
struct ValidationMessageView: View {
    let icon: String
    let text: String
    let isValid: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isValid ? .green : .red)
            Text(text)
                .font(.caption)
                .foregroundColor(isValid ? .green : .secondary)
        }
    }
}

#Preview {
    NavigationStack {
        ChangePasswordView()
            .environmentObject(AuthService())
    }
}
