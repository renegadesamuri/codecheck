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
                        .accessibilityHidden(true)

                    TextField("your.email@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .focused($focusedField, equals: .email)
                        .onChange(of: email) { _, _ in
                            validateEmail()
                        }
                        .accessibilityLabel("Email")
                        .accessibilityHint("Enter your email address")
                        .accessibilityValue(email.isEmpty ? "Empty" : email)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(emailError != nil ? Color.red : Color.clear, lineWidth: 1)
                )
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(emailError != nil ? .isSelected : [])

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
                        .accessibilityHidden(true)

                    if showPassword {
                        TextField("Enter your password", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .onChange(of: password) { _, _ in
                                validatePassword()
                            }
                            .accessibilityLabel("Password")
                            .accessibilityHint("Enter your password. Currently visible as plain text.")
                    } else {
                        SecureField("Enter your password", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .onChange(of: password) { _, _ in
                                validatePassword()
                            }
                            .accessibilityLabel("Password")
                            .accessibilityHint("Enter your password. Currently hidden.")
                    }

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                    .accessibilityHint("Toggles password visibility")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(passwordError != nil ? Color.red : Color.clear, lineWidth: 1)
                )
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(passwordError != nil ? .isSelected : [])

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
                    .foregroundStyle(GradientCache.bluePurpleHorizontal)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal)
            .accessibilityLabel("Forgot Password")
            .accessibilityHint("Opens password recovery")

            // Login Button
            Button {
                Task {
                    await handleLogin()
                }
            } label: {
                HStack(spacing: 12) {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Text("Sign In")
                            .font(.headline)

                        Image(systemName: "arrow.right")
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    isFormValid() 
                        ? GradientCache.bluePurpleHorizontal 
                        : GradientCache.grayDisabled
                )
                .cornerRadius(16)
                .shadow(color: isFormValid() ? .blue.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
            }
            .disabled(!isFormValid() || authService.isLoading)
            .padding(.horizontal)
            .padding(.top, 8)
            .accessibilityLabel(authService.isLoading ? "Signing in" : "Sign In")
            .accessibilityHint(isFormValid() ? "Submits your login credentials" : "Please complete the form to sign in")
            .accessibilityAddTraits(authService.isLoading ? .updatesFrequently : [])

            // Error Message Display
            if let errorMessage = authService.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .accessibilityHidden(true)
                    Text(errorMessage)
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                }
                .foregroundColor(.red)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Error: \(errorMessage)")
                .accessibilityAddTraits(.isStaticText)
            }

            // Demo Mode Button
            Button {
                authService.loginAsDemo()
            } label: {
                Text("Skip Login (Demo Mode)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
            .accessibilityLabel("Demo Mode")
            .accessibilityHint("Skip login and use the app in demo mode")
        }
        .animation(.easeInOut(duration: 0.2), value: emailError)
        .animation(.easeInOut(duration: 0.2), value: passwordError)
        .animation(.easeInOut(duration: 0.2), value: authService.isLoading)
        .animation(.easeInOut(duration: 0.2), value: authService.errorMessage)
    }

    // MARK: - Validation

    private func validateEmail() {
        emailError = nil
        
        // Clear auth error when user starts typing
        if authService.errorMessage != nil {
            authService.errorMessage = nil
        }

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
        
        // Clear auth error when user starts typing
        if authService.errorMessage != nil {
            authService.errorMessage = nil
        }

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
