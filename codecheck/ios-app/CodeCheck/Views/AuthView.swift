import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingLogin = true
    @State private var showingBiometricPrompt = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 40)

                    // Logo and Title
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("CodeCheck")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("Construction Compliance Assistant")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 24)

                    // Authentication Forms
                    VStack(spacing: 24) {
                        // Toggle between Login and Register
                        Picker("", selection: $showingLogin) {
                            Text("Login").tag(true)
                            Text("Register").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        // Animated transition between views
                        if showingLogin {
                            LoginView()
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                        } else {
                            RegisterView()
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: showingLogin)

                    // Biometric authentication option
                    if authService.canUseBiometrics() && authService.hasBiometricCredentials() && showingLogin {
                        VStack(spacing: 16) {
                            HStack {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(height: 1)

                                Text("OR")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Rectangle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(height: 1)
                            }
                            .padding(.horizontal)

                            Button {
                                Task {
                                    do {
                                        try await authService.loginWithBiometrics()
                                    } catch {
                                        // Error is handled by authService
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "faceid")
                                        .font(.title2)

                                    Text("Sign in with Face ID")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }

                    // Error message display
                    if let errorMessage = authService.errorMessage {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)

                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()
                }
            }
            .scrollDismissesKeyboard(.interactively)

            // Loading overlay
            if authService.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)

                    Text(showingLogin ? "Signing in..." : "Creating account...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(32)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .shadow(radius: 20)
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthService())
}
