import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authService: AuthService
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var acceptedTerms = false
    @State private var nameError: String?
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var confirmPasswordError: String?
    @FocusState private var focusedField: Field?

    enum Field {
        case name, email, password, confirmPassword
    }

    var body: some View {
        VStack(spacing: 20) {
            // Full Name Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Full Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 20)

                    TextField("John Doe", text: $fullName)
                        .textContentType(.name)
                        .autocapitalization(.words)
                        .focused($focusedField, equals: .name)
                        .onChange(of: fullName) { _, _ in
                            validateName()
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(nameError != nil ? Color.red : Color.clear, lineWidth: 1)
                )

                if let nameError = nameError {
                    ErrorLabel(message: nameError)
                }
            }
            .padding(.horizontal)

            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 20)

                    TextField("your.email@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .focused($focusedField, equals: .email)
                        .onChange(of: email) { _, _ in
                            validateEmail()
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(emailError != nil ? Color.red : Color.clear, lineWidth: 1)
                )

                if let emailError = emailError {
                    ErrorLabel(message: emailError)
                }
            }
            .padding(.horizontal)

            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 20)

                    if showPassword {
                        TextField("Minimum 8 characters", text: $password)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .onChange(of: password) { _, _ in
                                validatePassword()
                                validateConfirmPassword()
                            }
                    } else {
                        SecureField("Minimum 8 characters", text: $password)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .onChange(of: password) { _, _ in
                                validatePassword()
                                validateConfirmPassword()
                            }
                    }

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(passwordError != nil ? Color.red : Color.clear, lineWidth: 1)
                )

                // Password Strength Indicator
                if !password.isEmpty {
                    PasswordStrengthIndicator(password: password)
                }

                if let passwordError = passwordError {
                    ErrorLabel(message: passwordError)
                }
            }
            .padding(.horizontal)

            // Confirm Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 20)

                    if showConfirmPassword {
                        TextField("Re-enter password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirmPassword)
                            .onChange(of: confirmPassword) { _, _ in
                                validateConfirmPassword()
                            }
                    } else {
                        SecureField("Re-enter password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirmPassword)
                            .onChange(of: confirmPassword) { _, _ in
                                validateConfirmPassword()
                            }
                    }

                    Button {
                        showConfirmPassword.toggle()
                    } label: {
                        Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(confirmPasswordError != nil ? Color.red : Color.clear, lineWidth: 1)
                )

                if let confirmPasswordError = confirmPasswordError {
                    ErrorLabel(message: confirmPasswordError)
                }
            }
            .padding(.horizontal)

            // Terms and Conditions
            Button {
                acceptedTerms.toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: acceptedTerms ? "checkmark.square.fill" : "square")
                        .foregroundStyle(
                            acceptedTerms ?
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [.gray], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .font(.title3)

                    Text("I agree to the Terms and Conditions")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)

            // Register Button
            Button {
                Task {
                    await handleRegister()
                }
            } label: {
                HStack(spacing: 12) {
                    Text("Create Account")
                        .font(.headline)

                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: isFormValid() ? [.blue, .purple] : [.gray],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: isFormValid() ? .blue.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
            }
            .disabled(!isFormValid() || authService.isLoading)
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .animation(.easeInOut(duration: 0.2), value: nameError)
        .animation(.easeInOut(duration: 0.2), value: emailError)
        .animation(.easeInOut(duration: 0.2), value: passwordError)
        .animation(.easeInOut(duration: 0.2), value: confirmPasswordError)
    }

    // MARK: - Validation

    private func validateName() {
        nameError = nil

        guard !fullName.isEmpty else {
            return
        }

        if fullName.count < 2 {
            nameError = "Name must be at least 2 characters"
        }
    }

    private func validateEmail() {
        emailError = nil

        guard !email.isEmpty else {
            return
        }

        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        if !emailPredicate.evaluate(with: email) {
            emailError = "Please enter a valid email address"
        }
    }

    private func validatePassword() {
        passwordError = nil

        guard !password.isEmpty else {
            return
        }

        if password.count < 8 {
            passwordError = "Password must be at least 8 characters"
        } else if !password.contains(where: { $0.isNumber }) {
            passwordError = "Password must contain at least one number"
        } else if !password.contains(where: { $0.isUppercase }) {
            passwordError = "Password must contain at least one uppercase letter"
        }
    }

    private func validateConfirmPassword() {
        confirmPasswordError = nil

        guard !confirmPassword.isEmpty else {
            return
        }

        if confirmPassword != password {
            confirmPasswordError = "Passwords do not match"
        }
    }

    private func isFormValid() -> Bool {
        return !fullName.isEmpty &&
               !email.isEmpty &&
               !password.isEmpty &&
               !confirmPassword.isEmpty &&
               acceptedTerms &&
               nameError == nil &&
               emailError == nil &&
               passwordError == nil &&
               confirmPasswordError == nil
    }

    // MARK: - Actions

    private func handleRegister() async {
        // Final validation
        validateName()
        validateEmail()
        validatePassword()
        validateConfirmPassword()

        guard isFormValid() else {
            return
        }

        // Dismiss keyboard
        focusedField = nil

        // Perform registration
        await authService.register(email: email, password: password, name: fullName)
    }
}

// MARK: - Password Strength Indicator

struct PasswordStrengthIndicator: View {
    let password: String

    private var strength: PasswordStrength {
        calculateStrength(password)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<4) { index in
                    Rectangle()
                        .fill(index < strength.bars ? strength.color : Color(.systemGray5))
                        .frame(height: 4)
                        .cornerRadius(2)
                }
            }

            Text(strength.text)
                .font(.caption)
                .foregroundColor(strength.color)
        }
    }

    private func calculateStrength(_ password: String) -> PasswordStrength {
        var score = 0

        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.contains(where: { $0.isNumber }) { score += 1 }
        if password.contains(where: { $0.isUppercase }) { score += 1 }
        if password.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) }) { score += 1 }

        switch score {
        case 0...1:
            return PasswordStrength(bars: 1, color: .red, text: "Weak")
        case 2:
            return PasswordStrength(bars: 2, color: .orange, text: "Fair")
        case 3:
            return PasswordStrength(bars: 3, color: .yellow, text: "Good")
        case 4...:
            return PasswordStrength(bars: 4, color: .green, text: "Strong")
        default:
            return PasswordStrength(bars: 1, color: .red, text: "Weak")
        }
    }

    struct PasswordStrength {
        let bars: Int
        let color: Color
        let text: String
    }
}

// MARK: - Error Label

struct ErrorLabel: View {
    let message: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
            Text(message)
                .font(.caption)
        }
        .foregroundColor(.red)
        .transition(.opacity)
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthService())
}
