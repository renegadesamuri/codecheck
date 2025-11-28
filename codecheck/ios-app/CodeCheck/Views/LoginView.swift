import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var emailError: String?
    @State private var passwordError: String?
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        VStack(spacing: 20) {
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
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                        Text(emailError)
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                    .transition(.opacity)
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
                        TextField("Enter your password", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .onChange(of: password) { _, _ in
                                validatePassword()
                            }
                    } else {
                        SecureField("Enter your password", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .onChange(of: password) { _, _ in
                                validatePassword()
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

                if let passwordError = passwordError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                        Text(passwordError)
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal)

            // Forgot Password
            Button {
                // TODO: Implement forgot password
            } label: {
                Text("Forgot Password?")
                    .font(.subheadline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal)

            // Login Button
            Button {
                Task {
                    await handleLogin()
                }
            } label: {
                HStack(spacing: 12) {
                    Text("Sign In")
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

            // Demo Mode Button
            Button {
                authService.loginAsDemo()
            } label: {
                Text("Skip Login (Demo Mode)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .animation(.easeInOut(duration: 0.2), value: emailError)
        .animation(.easeInOut(duration: 0.2), value: passwordError)
    }

    // MARK: - Validation

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

        if password.count < 6 {
            passwordError = "Password must be at least 6 characters"
        }
    }

    private func isFormValid() -> Bool {
        return !email.isEmpty &&
               !password.isEmpty &&
               emailError == nil &&
               passwordError == nil
    }

    // MARK: - Actions

    private func handleLogin() async {
        // Final validation
        validateEmail()
        validatePassword()

        guard isFormValid() else {
            return
        }

        // Dismiss keyboard
        focusedField = nil

        // Perform login
        await authService.login(email: email, password: password)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService())
}
