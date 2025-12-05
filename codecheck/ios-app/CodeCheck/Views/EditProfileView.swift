import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                // Avatar Section
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            // Avatar Display
                            if let image = avatarImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            } else {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Text((fullName.prefix(1).uppercased().isEmpty ? email.prefix(1) : fullName.prefix(1)).uppercased())
                                            .font(.system(size: 40, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }

                            // Photo Picker
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Change Photo", systemImage: "camera.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Profile Photo")
                }

                // Personal Information
                Section {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        TextField("Full Name", text: $fullName)
                    }

                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.purple)
                            .frame(width: 30)
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                } header: {
                    Text("Personal Information")
                } footer: {
                    Text("Your email is used for login and notifications")
                        .font(.caption)
                }

                // Account Info
                Section {
                    HStack {
                        Text("Account ID")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(authService.currentUser?.id ?? "N/A")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let role = authService.currentUser?.role {
                        HStack {
                            Text("Role")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(role.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                    }

                    if let createdAt = authService.currentUser?.createdAt {
                        HStack {
                            Text("Member Since")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(createdAt.formatted(date: .long, time: .omitted))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Account Information")
                }

                // Save Button
                Section {
                    Button {
                        saveProfile()
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Label("Save Changes", systemImage: "checkmark.circle.fill")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading || !hasChanges())
                    .foregroundStyle(
                        LinearGradient(
                            colors: hasChanges() ? [.blue, .purple] : [.gray],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentData()
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        avatarImage = image
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
                Text("Your profile has been updated successfully")
            }
        }
    }

    private func loadCurrentData() {
        if let user = authService.currentUser {
            fullName = user.name ?? ""
            email = user.email
        }
    }

    private func hasChanges() -> Bool {
        guard let user = authService.currentUser else { return false }

        let nameChanged = fullName != (user.name ?? "")
        let emailChanged = email != user.email
        let photoChanged = avatarImage != nil

        return nameChanged || emailChanged || photoChanged
    }

    private func saveProfile() {
        isLoading = true

        Task {
            do {
                // Create update request
                let updateData: [String: Any] = [
                    "full_name": fullName,
                    "email": email
                ]

                let jsonData = try JSONSerialization.data(withJSONObject: updateData)

                guard let url = URL(string: "\(authService.baseURL)/api/users/me") else {
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
                    // Parse updated user
                    let updatedUser = try JSONDecoder().decode(User.self, from: data)

                    // Update the current user in auth service
                    await MainActor.run {
                        authService.currentUser = updatedUser
                        isLoading = false
                        showingSuccess = true
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

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(AuthService())
    }
}
