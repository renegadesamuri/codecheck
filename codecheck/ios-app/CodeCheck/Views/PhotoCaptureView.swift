import SwiftUI
import PhotosUI

struct PhotoCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var showingCamera = false
    @State private var showingAnnotation = false
    @State private var photoNote = ""
    @State private var photoLocation = ""
    @State private var photoTags: Set<String> = []

    let project: Project?
    let measurement: Measurement?
    let onSave: (PhotoDocumentation) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let image = capturedImage {
                    // Photo Preview with Annotations
                    ScrollView {
                        VStack(spacing: 20) {
                            // Image
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(12)
                                .shadow(radius: 5)

                            // Photo Details
                            VStack(spacing: 16) {
                                // Location/Title
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Location/Title")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    TextField("e.g., Living Room Stairs", text: $photoLocation)
                                        .textFieldStyle(.roundedBorder)
                                }

                                // Notes
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Notes")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    TextEditor(text: $photoNote)
                                        .frame(height: 100)
                                        .padding(8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }

                                // Tags
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Tags")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack {
                                            ForEach(["Compliance", "Violation", "Complete", "In Progress", "Pending"], id: \.self) { tag in
                                                TagButton(tag: tag, isSelected: photoTags.contains(tag)) {
                                                    if photoTags.contains(tag) {
                                                        photoTags.remove(tag)
                                                    } else {
                                                        photoTags.insert(tag)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Project Info
                                if let project = project {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Project")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        HStack {
                                            Image(systemName: "folder.fill")
                                                .foregroundColor(.blue)
                                            Text(project.name)
                                            Spacer()
                                            Text(project.type.rawValue)
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(8)
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                }

                                // Measurement Info
                                if let measurement = measurement {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Measurement")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        HStack {
                                            Image(systemName: "ruler")
                                                .foregroundColor(.purple)
                                            Text(measurement.type.rawValue)
                                            Spacer()
                                            Text("\(String(format: "%.2f", measurement.value)) \(measurement.unit.rawValue)")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(measurement.isCompliant == true ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                                .foregroundColor(measurement.isCompliant == true ? .green : .red)
                                                .cornerRadius(8)
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                }

                                // Save Button
                                Button {
                                    savePhoto()
                                } label: {
                                    Label("Save Photo", systemImage: "checkmark.circle.fill")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                                .disabled(photoLocation.isEmpty)
                            }
                            .padding()
                        }
                        .padding()
                    }
                } else {
                    // Camera/Photo Picker Selection
                    VStack(spacing: 32) {
                        Spacer()

                        VStack(spacing: 16) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Text("Add Photo Documentation")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Take a photo or choose from library to document your measurements and compliance checks")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        VStack(spacing: 16) {
                            Button {
                                showingCamera = true
                            } label: {
                                Label("Take Photo", systemImage: "camera")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }

                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Choose from Library", systemImage: "photo.on.rectangle")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .foregroundColor(.primary)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 32)

                        Spacer()
                    }
                }
            }
            .navigationTitle("Photo Documentation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView { image in
                    capturedImage = image
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                // Move image loading to background thread to avoid UI blocking
                Task.detached(priority: .userInitiated) {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            capturedImage = image
                        }
                    }
                }
            }
        }
    }

    private func savePhoto() {
        guard let image = capturedImage else { return }

        let photo = PhotoDocumentation(
            id: UUID(),
            image: image,
            location: photoLocation,
            notes: photoNote,
            tags: Array(photoTags),
            projectId: project?.id,
            measurementId: measurement?.id,
            timestamp: Date()
        )

        onSave(photo)
        dismiss()
    }
}

struct TagButton: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [Color(.systemGray5)], startPoint: .leading, endPoint: .trailing))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

// Camera View using UIImagePickerController
struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// Photo Documentation Model
struct PhotoDocumentation: Identifiable, Codable {
    let id: UUID
    var imageData: Data?
    var location: String
    var notes: String
    var tags: [String]
    var projectId: UUID?
    var measurementId: UUID?
    var timestamp: Date

    // Transient property for UI
    var image: UIImage? {
        get {
            guard let data = imageData else { return nil }
            return UIImage(data: data)
        }
        set {
            // Compression happens synchronously in setter (used rarely)
            // For init, use async compression via compressImageAsync()
            imageData = newValue?.jpegData(compressionQuality: 0.8)
        }
    }

    init(id: UUID, image: UIImage, location: String, notes: String, tags: [String], projectId: UUID?, measurementId: UUID?, timestamp: Date) {
        self.id = id
        self.location = location
        self.notes = notes
        self.tags = tags
        self.projectId = projectId
        self.measurementId = measurementId
        self.timestamp = timestamp

        // TODO: Future optimization - make this async with factory method
        // For now, keep synchronous for compatibility (called infrequently)
        self.imageData = image.jpegData(compressionQuality: 0.8)
    }
}

#Preview {
    PhotoCaptureView(project: nil, measurement: nil) { _ in }
}
